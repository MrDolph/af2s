'use client';
import { useState, useCallback, useRef, useEffect } from 'react';
import { AppHeader } from '@/components/layout/AppHeader';
import { SimulationControls } from '@/components/simulation/SimulationControls';
import { CoupledOscillatorsCanvas } from '@/components/simulation/CoupledOscillatorsCanvas';
import { EmbedButton } from '@/components/ui/EmbedButton';
import { useResponsiveCanvasSize } from '@/hooks/useResponsiveCanvasSize';
import {
  OscillatorState, OscillatorParams, totalEnergy,
  PRESETS, OscillatorPreset,
} from '@/lib/physics/coupledOscillators';

const CURRICULA = ['WAEC', 'NECO', 'IGCSE', 'SAT', 'JUPEB'];
const CC: Record<string, string> = {
  WAEC: 'bg-indigo-100 text-indigo-700', NECO: 'bg-pink-100 text-pink-700',
  IGCSE: 'bg-emerald-100 text-emerald-700', SAT: 'bg-orange-100 text-orange-700',
  JUPEB: 'bg-purple-100 text-purple-700',
};

const TEACHER_NOTES = [
  'Coupled oscillators are the linear counterpart to the double pendulum. Instead of chaos, we get superposition of normal modes.',
  'The system has two normal modes: in-phase (both masses move together) and out-of-phase (they move oppositely). Any motion is a sum of these two modes.',
  'When the coupling is weak and the two individual oscillators have nearly the same frequency, you see beats — periodic transfer of energy from one mass to the other.',
  'The beat frequency is the difference between the two normal-mode frequencies: f_beat = |ω₂ − ω₁| / (2π).',
  'Damping removes energy from the system. The Q-factor tells you how many oscillations occur before the energy drops significantly: Q ≈ 2π × (energy stored) / (energy lost per cycle).',
  'In the damped case, the motion eventually settles into the slower normal mode because higher frequencies are damped more strongly.',
];

const EXERCISES = [
  {
    q: 'Run the "Beats" preset and watch the strip chart. How many seconds does one complete beat cycle take?',
    a: 'For the default parameters (k₁=k₃=1, k₂=0.1, m=1), the normal-mode frequencies are ω₁≈1.00 rad/s and ω₂≈1.10 rad/s. The beat period is 2π/|ω₂−ω₁| ≈ 63 s. You will see roughly one full exchange in about 60–65 seconds.',
  },
  {
    q: 'Compare the "In-phase" and "Out-of-phase" presets. Which one has the higher frequency? Why?',
    a: 'Out-of-phase has the higher frequency because the coupling spring is stretched and adds an effective restoring force. For symmetric springs, ω_out² = (k + 2k_c)/m  versus  ω_in² = k/m.',
  },
  {
    q: 'Increase the coupling spring constant k₂ to 2.0 and run "Beats". What happens to the beat pattern?',
    a: 'Strong coupling increases the frequency splitting, so the beat period becomes shorter and the energy transfer happens faster. If k₂ is very large, the two masses are forced to move almost as a single rigid body.',
  },
  {
    q: 'Enable damping and observe the Q-factor. Does Q stay constant as the motion decays?',
    a: 'For linear damping, Q should remain roughly constant if the frequency does not change much. However, numerical noise at very small amplitudes can make Q fluctuate at the end.',
  },
  {
    q: 'Set m₂ = 5 kg and run "Heavy second mass". Why does the first mass oscillate while the second barely moves?',
    a: 'The heavy mass has large inertia, so the coupling force barely accelerates it. It acts almost like a fixed wall, and m₁ oscillates with a frequency close to √( (k₁+k₂)/m₁ ).',
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
      <input
        type="range"
        min={min}
        max={max}
        step={step}
        value={value}
        onChange={e => set(Number(e.target.value))}
        className="w-full h-6 py-2 cursor-pointer"
        style={{ accentColor: color }}
      />
      {note && <p className="text-[10px] text-gray-400">{note}</p>}
    </div>
  );
}

function StatRow({ label, value, unit, color }: { label: string; value: string; unit: string; color: string }) {
  return (
    <div className="flex justify-between items-center rounded-lg bg-gray-50 px-3 py-2">
      <span className="text-xs text-gray-500">{label}</span>
      <span className={`text-xs font-semibold tabular-nums ${color}`}>{value} <span className="text-gray-400 font-normal">{unit}</span></span>
    </div>
  );
}

function DampingCurve({ history }: { history: Array<{ t: number; e: number }> }) {
  if (history.length < 3) return (
    <div className="rounded-lg bg-slate-900 border border-gray-700 h-24 flex items-center justify-center">
      <span className="text-[10px] text-gray-500">Run simulation to see decay curve</span>
    </div>
  );
  const logEs = history.map(h => Math.log(Math.max(h.e, 1e-6)));
  const minE = Math.min(...logEs);
  const maxE = Math.max(...logEs);
  const rangeE = maxE - minE || 1;
  const minT = history[0].t;
  const maxT = history[history.length - 1].t;
  const rangeT = maxT - minT || 1;

  const pts = history.map((h, i) => {
    const x = ((h.t - minT) / rangeT) * 100;
    const y = 100 - ((logEs[i] - minE) / rangeE) * 100;
    return `${x},${y}`;
  }).join(' ');

  return (
    <div className="rounded-lg bg-slate-900 border border-gray-700 overflow-hidden">
      <svg viewBox="0 0 100 100" preserveAspectRatio="none" className="w-full h-24 block">
        <polyline
          points={pts}
          fill="none"
          stroke="#10b981"
          strokeWidth="1.5"
          strokeLinecap="round"
          strokeLinejoin="round"
          vectorEffect="non-scaling-stroke"
        />
        <text x="4" y="12" fill="#94a3b8" fontSize="8" fontFamily="system-ui">ln(E) vs time</text>
        <line x1="0" y1="100" x2="100" y2="100" stroke="#334155" strokeWidth="0.5" />
        <line x1="0" y1="0" x2="0" y2="100" stroke="#334155" strokeWidth="0.5" />
      </svg>
    </div>
  );
}

export default function CoupledOscillatorsPage() {
  const [isRunning, setIsRunning] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const [resetKey, setResetKey] = useState(0);
  const [openEx, setOpenEx] = useState<number | null>(null);
  const [activeCurricula, setActiveCurricula] = useState(['IGCSE', 'SAT', 'JUPEB']);
  const [showTrail, setShowTrail] = useState(true);
  const [showEnergy, setShowEnergy] = useState(true);
  const [trailLength, setTrailLength] = useState(300);
  const [activePreset, setActivePreset] = useState<number | null>(null);

  const [m1, setM1] = useState(1);
  const [m2, setM2] = useState(1);
  const [k1, setK1] = useState(1);
  const [k2, setK2] = useState(0.2);
  const [k3, setK3] = useState(1);
  const [x1, setX1] = useState(0.1);
  const [x2, setX2] = useState(0.1);
  const [v1, setV1] = useState(0);
  const [v2, setV2] = useState(0);
  const [damping1, setDamping1] = useState(0);
  const [damping2, setDamping2] = useState(0);

  const [liveEnergy, setLiveEnergy] = useState({ ke: 0, pe: 0, total: 0 });
  const [liveState, setLiveState] = useState({ x1: 0, x2: 0, v1: 0, v2: 0 });
  const [liveMeta, setLiveMeta] = useState({ qFactor: 0, bandwidth: 0, decayRate: 0, valid: false });
  const [chartHistory, setChartHistory] = useState<Array<{ t: number; e: number }>>([]);

  const params: OscillatorParams = { m1, m2, k1, k2, k3, damping1, damping2 };

  useEffect(() => {
    const idx = PRESETS.findIndex(p =>
      Math.abs(p.m1 - m1) < 0.05 && Math.abs(p.m2 - m2) < 0.05 &&
      Math.abs(p.k1 - k1) < 0.05 && Math.abs(p.k2 - k2) < 0.05 && Math.abs(p.k3 - k3) < 0.05 &&
      Math.abs(p.x1 - x1) < 0.005 && Math.abs(p.x2 - x2) < 0.005 &&
      Math.abs(p.v1 - v1) < 0.05 && Math.abs(p.v2 - v2) < 0.05 &&
      Math.abs(p.damping1 - damping1) < 0.005 && Math.abs(p.damping2 - damping2) < 0.005
    );
    setActivePreset(idx >= 0 ? idx : null);
  }, [m1, m2, k1, k2, k3, x1, x2, v1, v2, damping1, damping2]);

  const applyPreset = useCallback((preset: OscillatorPreset, index: number) => {
    setM1(preset.m1); setM2(preset.m2); setK1(preset.k1); setK2(preset.k2); setK3(preset.k3);
    setX1(preset.x1); setX2(preset.x2); setV1(preset.v1); setV2(preset.v2);
    setDamping1(preset.damping1); setDamping2(preset.damping2);
    setIsRunning(false); setIsPaused(false);
    setResetKey(k => k + 1);
    setLiveEnergy({ ke: 0, pe: 0, total: 0 });
    setLiveState({ x1: 0, x2: 0, v1: 0, v2: 0 });
    setLiveMeta({ qFactor: 0, bandwidth: 0, decayRate: 0, valid: false });
    setChartHistory([]);
    setActivePreset(index);
  }, []);

  const reset = useCallback(() => {
    setIsRunning(false); setIsPaused(false);
    setResetKey(k => k + 1);
    setLiveEnergy({ ke: 0, pe: 0, total: 0 });
    setLiveState({ x1: 0, x2: 0, v1: 0, v2: 0 });
    setLiveMeta({ qFactor: 0, bandwidth: 0, decayRate: 0, valid: false });
    setChartHistory([]);
  }, []);

  const canvasBoxRef = useRef<HTMLDivElement>(null);
  const canvasSize = useResponsiveCanvasSize(canvasBoxRef, 660, 420, 900);

  const lastTickRef = useRef(0);
  const handleTick = useCallback((state: OscillatorState, energy: { ke: number; pe: number; total: number }, meta: { qFactor: number; bandwidth: number; decayRate: number; valid: boolean; chartHistory: Array<{ t: number; e: number }> }) => {
    const now = performance.now();
    if (now - lastTickRef.current < 80) return;
    lastTickRef.current = now;
    setLiveState({ x1: state.x1, x2: state.x2, v1: state.v1, v2: state.v2 });
    setLiveEnergy(energy);
    setLiveMeta({ qFactor: meta.qFactor, bandwidth: meta.bandwidth, decayRate: meta.decayRate, valid: meta.valid });
    setChartHistory(meta.chartHistory);
  }, []);

  const initialState: OscillatorState = { x1, v1, x2, v2 };
  const initialTotalEnergy = totalEnergy(initialState, params);

  const qDisplay = !liveMeta.valid ? '—' :
    liveMeta.qFactor === Infinity ? '∞ (undamped)' :
    liveMeta.qFactor > 999 ? '> 999' :
    liveMeta.qFactor.toFixed(1);

  const bwDisplay = !liveMeta.valid ? '—' :
    liveMeta.bandwidth < 0.001 ? '~0' :
    liveMeta.bandwidth.toFixed(3);

  return (
    <>
      <AppHeader />
      <main className="min-h-screen bg-gray-50">
        <section className="border-b border-gray-200 bg-white">
          <div className="mx-auto max-w-[100rem] px-4 sm:px-6 py-4">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
              <div>
                <p className="text-xs text-gray-400 mb-0.5">Mechanics — Linear Systems</p>
                <h1 className="text-lg font-semibold text-gray-900">Coupled oscillators</h1>
              </div>
              <div className="flex gap-1.5 flex-wrap">
                {CURRICULA.map(c => (
                  <button key={c}
                    onClick={() => setActiveCurricula(p => p.includes(c) ? p.filter(x => x !== c) : [...p, c])}
                    className={`text-xs px-2.5 py-2 rounded-full border font-medium transition ${
                      activeCurricula.includes(c) ? CC[c] + ' border-transparent' : 'bg-white text-gray-400 border-gray-200'
                    }`}>{c}</button>
                ))}
              </div>
            </div>
          </div>
        </section>

        <div className="mx-auto max-w-[100rem] px-4 sm:px-6 py-4 space-y-4">
          <div className="flex flex-wrap items-center gap-3 rounded-xl border border-gray-200 bg-white px-4 py-2.5">
            <span className="text-xs text-gray-400">Linear coupled oscillators — normal modes & beats</span>
            <span className="text-sm font-semibold font-mono text-gray-900">F = −kx − c v</span>
          </div>

          <div className="flex gap-2 overflow-x-auto pb-2 snap-x snap-mandatory scroll-smooth">
            {PRESETS.map((preset, i) => (
              <button key={i} onClick={() => applyPreset(preset, i)}
                className={`shrink-0 rounded-xl border px-3 py-2 text-left transition snap-start min-w-[180px] ${
                  activePreset === i
                    ? 'border-indigo-500 bg-indigo-50 shadow-sm ring-1 ring-indigo-300'
                    : 'border-gray-200 bg-white hover:border-indigo-300 hover:shadow-sm'
                }`}>
                <p className="text-xs font-medium text-indigo-700">{preset.name}</p>
                <p className="text-[10px] text-gray-400 mt-0.5 leading-relaxed">{preset.description}</p>
              </button>
            ))}
          </div>

          <div className="grid grid-cols-1 lg:grid-cols-[1fr_220px] xl:grid-cols-[1fr_220px_260px] gap-4">
            <div className="space-y-3 min-w-0">
              <div ref={canvasBoxRef} className="rounded-2xl border border-gray-200 bg-white p-3 shadow-sm">
                <CoupledOscillatorsCanvas
                  key={resetKey}
                  x1Init={x1}
                  v1Init={v1}
                  x2Init={x2}
                  v2Init={v2}
                  params={params}
                  isRunning={isRunning}
                  isPaused={isPaused}
                  showTrail={showTrail}
                  showEnergy={showEnergy}
                  trailLength={trailLength}
                  onTick={handleTick}
                  width={canvasSize.width}
                  height={canvasSize.height}
                />
              </div>

              <div className="flex flex-wrap items-center justify-between gap-2">
                <SimulationControls isRunning={isRunning} isPaused={isPaused}
                  onRun={() => { setIsRunning(true); setIsPaused(false); }}
                  onPause={() => setIsPaused(p => !p)} onReset={reset} />
                <EmbedButton path="/embed/coupled-oscillators"
                  title="Coupled Oscillators — A-Factor STEM Studio"
                  params={{ m1, m2, k1, k2, k3, x1, x2, v1, v2, d1: damping1, d2: damping2, trail: trailLength }}
                />
              </div>

              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm space-y-4">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide">Parameters</p>
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                  <div className="space-y-3">
                    <p className="text-[10px] font-medium text-indigo-600 uppercase tracking-wide">First mass</p>
                    <Slider label="Mass m₁" unit="kg" value={m1} min={0.1} max={5} step={0.1} set={setM1} color="#6366f1" />
                    <Slider label="Spring k₁" unit="N/m" value={k1} min={0.1} max={5} step={0.1} set={setK1} color="#818cf8" />
                    <Slider label="Initial x₁" unit="m" value={x1} min={-0.3} max={0.3} step={0.01} set={setX1} color="#a78bfa" />
                    <Slider label="Initial v₁" unit="m/s" value={v1} min={-2} max={2} step={0.05} set={setV1} color="#c4b5fd" />
                    <Slider label="Damping c₁" unit="" value={damping1} min={0} max={1} step={0.01} set={setDamping1} color="#ef4444" />
                  </div>
                  <div className="space-y-3">
                    <p className="text-[10px] font-medium text-amber-600 uppercase tracking-wide">Second mass</p>
                    <Slider label="Mass m₂" unit="kg" value={m2} min={0.1} max={5} step={0.1} set={setM2} color="#f59e0b" />
                    <Slider label="Spring k₃" unit="N/m" value={k3} min={0.1} max={5} step={0.1} set={setK3} color="#fbbf24" />
                    <Slider label="Initial x₂" unit="m" value={x2} min={-0.3} max={0.3} step={0.01} set={setX2} color="#fcd34d" />
                    <Slider label="Initial v₂" unit="m/s" value={v2} min={-2} max={2} step={0.05} set={setV2} color="#fde68a" />
                    <Slider label="Damping c₂" unit="" value={damping2} min={0} max={1} step={0.01} set={setDamping2} color="#ef4444" />
                  </div>
                </div>
                <div className="border-t border-gray-100 pt-3 space-y-3">
                  <Slider label="Coupling k₂" unit="N/m" value={k2} min={0} max={5} step={0.05} set={setK2} color="#10b981" note="Spring between the two masses" />
                  <Slider label="Trail length" unit="frames" value={trailLength} min={0} max={800} step={10} set={setTrailLength} color="#f43f5e" />
                  <div className="flex gap-3">
                    <label className="flex items-center gap-2 text-xs text-gray-600 cursor-pointer">
                      <input type="checkbox" checked={showTrail} onChange={e => setShowTrail(e.target.checked)} className="rounded" />
                      Show trail
                    </label>
                    <label className="flex items-center gap-2 text-xs text-gray-600 cursor-pointer">
                      <input type="checkbox" checked={showEnergy} onChange={e => setShowEnergy(e.target.checked)} className="rounded" />
                      Show energy bar
                    </label>
                  </div>
                </div>
              </div>
            </div>

            <div className="space-y-3">
              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide mb-3">Calculated</p>
                <div className="space-y-2">
                  <StatRow label="Initial total E" value={initialTotalEnergy.toFixed(4)} unit="J" color="text-indigo-600" />
                  <StatRow label="Live kinetic E" value={liveEnergy.ke.toFixed(4)} unit="J" color="text-rose-500" />
                  <StatRow label="Live potential E" value={liveEnergy.pe.toFixed(4)} unit="J" color="text-blue-500" />
                  <StatRow label="Live total E" value={liveEnergy.total.toFixed(4)} unit="J" color="text-emerald-600" />
                  <StatRow label="x₁" value={liveState.x1.toFixed(3)} unit="m" color="text-purple-600" />
                  <StatRow label="x₂" value={liveState.x2.toFixed(3)} unit="m" color="text-amber-600" />
                  <StatRow label="v₁" value={liveState.v1.toFixed(2)} unit="m/s" color="text-indigo-500" />
                  <StatRow label="v₂" value={liveState.v2.toFixed(2)} unit="m/s" color="text-amber-500" />
                  <StatRow label="Q factor" value={qDisplay} unit="" color="text-pink-600" />
                  <StatRow label="Bandwidth" value={bwDisplay} unit="rad/s" color="text-cyan-600" />
                </div>
              </div>

              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide mb-2">Damping curve</p>
                <DampingCurve history={chartHistory} />
                <p className="text-[10px] text-gray-400 mt-1.5 leading-relaxed">
                  Log-energy vs time. A straight line confirms exponential decay (linear damping).
                </p>
              </div>

              <div className="rounded-2xl border border-gray-100 bg-white p-4">
                <p className="text-xs text-gray-400 mb-2">Curriculum</p>
                <div className="flex flex-wrap gap-1.5">
                  {CURRICULA.map(c => (
                    <span key={c} className={`text-xs font-medium px-2 py-0.5 rounded-full ${
                      activeCurricula.includes(c) ? CC[c] : 'bg-gray-100 text-gray-400'
                    }`}>{c}</span>
                  ))}
                </div>
              </div>
            </div>

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
