'use client';
import { useState, useCallback, useRef, useEffect } from 'react';
import { AppHeader } from '@/components/layout/AppHeader';
import { SimulationControls } from '@/components/simulation/SimulationControls';
import { EmbedButton } from '@/components/ui/EmbedButton';
import { DampedOscillatorCanvas } from '@/components/simulation/DampedOscillatorCanvas';
import { DampedOscillatorGraph } from '@/components/simulation/DampedOscillatorGraph';
import { useResponsiveCanvasSize } from '@/hooks/useResponsiveCanvasSize';
import { dampingRegime, dampedSecondaryFreq } from '@/lib/physics/dampedOscillator';

const TEACHER_NOTES = [
  "y'' + 2γy' + ω₀²y = 0 models a car's suspension, a door closer, a voltmeter needle settling — anything that relaxes back to equilibrium after a disturbance, with some form of friction/resistance present.",
  "Chapter 15's method: take ℒ of both sides, solve the resulting algebraic equation for Y(s), then invert. The differential equation becomes ordinary algebra.",
  "The three regimes come from the sign of ω₀²−γ² inside the square root: positive → real oscillation frequency ω_d (underdamped); zero → critical damping; negative → real hyperbolic frequency ω_h (overdamped, no oscillation at all).",
  "Critical damping (γ=ω₀) is the fastest possible return to equilibrium WITHOUT overshooting — this is why shock absorbers and galvanometers are deliberately designed to sit at (or just past) this exact point.",
  "The dashed envelope curve is ±amplitude·e^(−γt) — every regime decays inside this envelope; only the underdamped case actually touches it periodically.",
];

const EXERCISES: { q: string; a: string }[] = [
  {
    q: 'A system has γ=1, ω₀=3, y(0)=2, y′(0)=0. Find ω_d and classify the regime.',
    a: 'ω₀²−γ²=9−1=8>0 → underdamped. ω_d=√8≈2.83 rad/s.',
  },
  {
    q: 'Using the values above, write down y(t) in closed form (no need to evaluate numerically).',
    a: "y(t)=e^(−t)[2cos(2.83t) + ((0+1×2)/2.83)sin(2.83t)] = e^(−t)[2cos(2.83t) + 0.707sin(2.83t)]",
  },
  {
    q: 'For what value of γ (given ω₀=5) does the system become critically damped?',
    a: 'γ=ω₀=5 exactly — this is the definition of critical damping.',
  },
  {
    q: 'A system has γ=4, ω₀=2. Is it under-, critically, or overdamped? Find ω_h.',
    a: 'γ>ω₀ → overdamped. ω_h=√(γ²−ω₀²)=√(16−4)=√12≈3.46.',
  },
  {
    q: "Explain, without solving the ODE, why the critically damped case can't be found by simply setting ω_d=0 in the underdamped formula.",
    a: "Setting ω_d=0 makes the (b/ω_d)sin(ω_d t) term divide by zero. The critically-damped solution isn't a limiting case you can just plug into the underdamped formula — it comes from a genuinely different partial-fraction decomposition of Y(s), because (s+γ)²+ω_d² becomes a repeated root (s+γ)² when ω_d=0, which inverts to a t·e^(−γt) term instead of a sine.",
  },
];

function Slider({ label, unit, value, min, max, step, set, color, note }: {
  label: string; unit: string; value: number; min: number; max: number;
  step: number; set: (v: number) => void; color: string; note?: string;
}) {
  return (
    <div className="space-y-1.5">
      <div className="flex justify-between text-xs">
        <span className="text-gray-500">{label}</span>
        <span className="font-medium tabular-nums text-gray-800">{value} <span className="text-gray-400 font-normal">{unit}</span></span>
      </div>
      <input type="range" min={min} max={max} step={step} value={value}
        onChange={e => set(Number(e.target.value))} className="w-full" style={{ accentColor: color }} />
      {note && <p className="text-[10px] text-gray-400">{note}</p>}
    </div>
  );
}

const REGIME_META: Record<string, { label: string; color: string }> = {
  underdamped: { label: 'Underdamped — oscillates', color: 'bg-indigo-100 text-indigo-700' },
  critical: { label: 'Critically damped', color: 'bg-amber-100 text-amber-700' },
  overdamped: { label: 'Overdamped — no oscillation', color: 'bg-rose-100 text-rose-700' },
};

export default function DampedOscillatorPage() {
  const [isRunning, setIsRunning] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const [resetKey, setResetKey] = useState(0);
  const [openEx, setOpenEx] = useState<number | null>(null);
  const [currentT, setCurrentT] = useState(0);

  const [gamma, setGamma] = useState(0.8);
  const [omega0, setOmega0] = useState(2.0);
  const [y0, setY0] = useState(1.0);
  const [yp0, setYp0] = useState(0.0);

  const regime = dampingRegime(gamma, omega0);
  const secondaryFreq = dampedSecondaryFreq(gamma, omega0);

  const resetTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const reset = useCallback(() => {
    setIsRunning(false); setIsPaused(false);
    setResetKey(k => k + 1); setCurrentT(0);
  }, []);

  useEffect(() => {
    if (resetTimer.current) clearTimeout(resetTimer.current);
    resetTimer.current = setTimeout(reset, 100);
  }, [gamma, omega0, y0, yp0, reset]);

  // Throttled to ~25fps — see project conventions: updating React state every
  // animation frame stutters the Recharts graph re-render.
  const lastTickRef = useRef(0);
  const handleTick = useCallback((t: number) => {
    const now = performance.now();
    if (now - lastTickRef.current > 40) {
      lastTickRef.current = now;
      setCurrentT(t);
    }
  }, []);

  const canvasBoxRef = useRef<HTMLDivElement>(null);
  const canvasSize = useResponsiveCanvasSize(canvasBoxRef, 380, 300, 500);

  return (
    <>
      <AppHeader />
      <main className="min-h-screen bg-gray-50">
        <section className="border-b border-gray-200 bg-white">
          <div className="mx-auto max-w-[100rem] px-4 sm:px-6 py-4">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
              <div>
                <p className="text-xs text-gray-400 mb-0.5">PHY 403 — Chapters 14–15</p>
                <h1 className="text-lg font-semibold text-gray-900">Damped Oscillator (Laplace Transform)</h1>
              </div>
              <span className={`text-xs px-3 py-1.5 rounded-full font-medium ${REGIME_META[regime].color}`}>
                {REGIME_META[regime].label}
              </span>
            </div>
          </div>
        </section>

        <div className="mx-auto max-w-[100rem] px-4 sm:px-6 py-4 space-y-4">

          {/* Equation banner */}
          <div className="flex flex-wrap items-center gap-3 rounded-xl border border-gray-200 bg-white px-4 py-2.5">
            <span className="text-xs text-gray-400">Governing equation</span>
            <span className="text-sm font-semibold font-mono text-gray-900">y&apos;&apos; + 2γy&apos; + ω₀²y = 0</span>
            <span className="text-xs text-gray-400 ml-2">
              {regime === 'underdamped' && `ω_d = ${secondaryFreq.toFixed(3)} rad/s`}
              {regime === 'overdamped' && `ω_h = ${secondaryFreq.toFixed(3)} rad/s`}
              {regime === 'critical' && 'y(t) = e^(−γt)[y₀ + (y′₀+γy₀)t]'}
            </span>
          </div>

          {/* Main grid */}
          <div className="grid grid-cols-1 lg:grid-cols-[1fr_220px] xl:grid-cols-[1fr_220px_260px] gap-4">

            <div className="space-y-3 min-w-0">
              {/* Canvas */}
              <div ref={canvasBoxRef} className="rounded-2xl border border-gray-200 bg-white p-3 shadow-sm">
                <DampedOscillatorCanvas key={resetKey}
                  gamma={gamma} omega0={omega0} y0={y0} yp0={yp0}
                  isRunning={isRunning} isPaused={isPaused}
                  onTick={handleTick}
                  width={canvasSize.width} height={canvasSize.height} />
              </div>

              {/* Controls */}
              <div className="flex flex-wrap items-center justify-between gap-3 rounded-2xl border border-gray-200 bg-white p-3 shadow-sm">
                <SimulationControls
                  isRunning={isRunning} isPaused={isPaused}
                  onRun={() => { setIsRunning(true); setIsPaused(false); }}
                  onPause={() => setIsPaused(p => !p)}
                  onReset={reset}
                />
                <EmbedButton
                  path="/embed/damped-oscillator"
                  params={{ gamma, omega0, y0, yp0 }}
                  title="Damped Oscillator (Laplace Transform)"
                />
              </div>

              {/* Graph */}
              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                <p className="text-xs font-medium text-gray-500 uppercase tracking-wide mb-2">y(t) vs time</p>
                <DampedOscillatorGraph gamma={gamma} omega0={omega0} y0={y0} yp0={yp0} currentT={currentT} />
              </div>
            </div>

            {/* Sliders + stats */}
            <div className="space-y-3">
              <div className="rounded-2xl border border-gray-100 bg-white p-4 space-y-4">
                <p className="text-xs font-medium uppercase tracking-wide text-gray-400">Parameters</p>
                <Slider label="Damping γ" unit="1/s" value={gamma} min={0} max={6} step={0.05}
                  set={setGamma} color="#f59e0b" note="Larger γ = more friction/resistance" />
                <Slider label="Natural frequency ω₀" unit="rad/s" value={omega0} min={0.5} max={6} step={0.05}
                  set={setOmega0} color="#6366f1" note="What it would oscillate at with zero damping" />
                <Slider label="Initial displacement y(0)" unit="" value={y0} min={-2} max={2} step={0.1}
                  set={setY0} color="#10b981" />
                <Slider label="Initial velocity y'(0)" unit="/s" value={yp0} min={-4} max={4} step={0.1}
                  set={setYp0} color="#ec4899" />
              </div>

              <div className="rounded-2xl border border-gray-100 bg-white p-4 space-y-2">
                <p className="text-xs font-medium uppercase tracking-wide text-gray-400 mb-2">Calculated values</p>
                {[
                  { l: 'Regime', v: REGIME_META[regime].label, c: 'text-gray-700' },
                  { l: regime === 'overdamped' ? 'ω_h' : 'ω_d', v: `${secondaryFreq.toFixed(3)} rad/s`, c: 'text-indigo-600' },
                  { l: 'y at t=3s', v: '', c: 'text-emerald-600' },
                ].filter(r => r.v).map(r => (
                  <div key={r.l} className="flex justify-between items-center rounded-lg bg-gray-50 px-3 py-2">
                    <span className="text-xs text-gray-500">{r.l}</span>
                    <span className={`text-xs font-semibold tabular-nums ${r.c}`}>{r.v}</span>
                  </div>
                ))}
              </div>
            </div>

            {/* Teacher notes + exercises */}
            <div className="space-y-3 lg:col-span-2 xl:col-span-1">
              <div className="rounded-2xl border border-amber-100 bg-amber-50 p-4">
                <p className="text-xs font-medium text-amber-700 uppercase tracking-wide mb-3">📋 Teacher notes</p>
                <ul className="space-y-2">
                  {TEACHER_NOTES.map((n, i) => (
                    <li key={i} className="text-xs text-amber-900 leading-relaxed flex gap-2">
                      <span className="text-amber-400 shrink-0 mt-0.5">•</span>{n}
                    </li>
                  ))}
                </ul>
              </div>

              <div className="rounded-2xl border border-gray-200 bg-white p-4">
                <p className="text-xs font-medium text-gray-500 uppercase tracking-wide mb-3">✏️ Exercises</p>
                <div className="space-y-2">
                  {EXERCISES.map((ex, i) => (
                    <div key={i} className="rounded-xl border border-gray-100 overflow-hidden">
                      <button onClick={() => setOpenEx(openEx === i ? null : i)}
                        className="w-full text-left px-3 py-2.5 text-xs text-gray-700 leading-relaxed hover:bg-gray-50 transition flex justify-between gap-2">
                        <span><span className="font-medium text-indigo-600">Q{i + 1}.</span> {ex.q}</span>
                        <span className="text-gray-300 shrink-0 text-sm">{openEx === i ? '▲' : '▼'}</span>
                      </button>
                      {openEx === i && (
                        <div className="px-3 py-2.5 bg-emerald-50 border-t border-gray-100 text-xs text-emerald-800 leading-relaxed">
                          <span className="font-medium">Answer: </span>{ex.a}
                        </div>
                      )}
                    </div>
                  ))}
                </div>
              </div>
            </div>

          </div>
        </div>
      </main>
    </>
  );
}
