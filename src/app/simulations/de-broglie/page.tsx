'use client';
import { useState, useCallback, useEffect, useRef } from 'react';
import { AppHeader } from '@/components/layout/AppHeader';
import { SimulationControls } from '@/components/simulation/SimulationControls';
import { DeBroglieCanvas } from '@/components/simulation/DeBroglieCanvas';
import { EmbedButton } from '@/components/ui/EmbedButton';
import { PARTICLES, deBroglieLambda, momentum, formatLambda, lambdaFromVoltage } from '@/lib/physics/debroglie';
import { useResponsiveCanvasSize } from '@/hooks/useResponsiveCanvasSize';

const CURRICULA = ['WAEC', 'NECO', 'IGCSE', 'SAT', 'JUPEB'];
const CC: Record<string, string> = {
  WAEC: 'bg-indigo-100 text-indigo-700', NECO: 'bg-pink-100 text-pink-700',
  IGCSE: 'bg-emerald-100 text-emerald-700', SAT: 'bg-orange-100 text-orange-700',
  JUPEB: 'bg-purple-100 text-purple-700',
};

const TEACHER_NOTES = [
  'De Broglie (1924): if light waves can behave as particles (photons), then particles should behave as waves — λ = h/mv. Confirmed by Davisson–Germer electron diffraction in 1927.',
  'The key comparison: an electron at 2×10⁶ m/s has λ ≈ 0.36 nm (atom-sized → diffracts off crystals) while a cricket ball has λ ≈ 10⁻³⁴ m — unimaginably smaller than a nucleus, so we never see cricket balls diffract.',
  'Larger momentum → shorter wavelength. Switch particles and watch λ collapse: mass in the denominator is why wave behaviour is invisible for everyday objects.',
  'Electron microscopes exploit this: electrons accelerated through kilovolts get λ far below visible light (400–700 nm), resolving individual atoms.',
  'For an electron accelerated through voltage V: λ = h/√(2meV) ≈ 1.23/√V nm — a favourite exam derivation (KE = eV = p²/2m).',
];

const EXERCISES = [
  { q: 'Find the de Broglie wavelength of an electron (m = 9.11×10⁻³¹ kg) moving at 2×10⁶ m/s.', a: 'λ = h/mv = 6.63e-34 / (9.11e-31 × 2e6) = 3.6×10⁻¹⁰ m = 0.36 nm.' },
  { q: 'A 0.16 kg cricket ball travels at 30 m/s. Find λ and explain why we never observe its wave nature.', a: 'λ = 6.63e-34/(0.16×30) ≈ 1.4×10⁻³⁴ m — about 10¹⁹ times smaller than a nucleus, far too small for any slit or detector.' },
  { q: 'An electron is accelerated from rest through 100 V. Find its de Broglie wavelength.', a: 'λ = h/√(2meV) = 6.63e-34/√(2×9.11e-31×1.6e-19×100) ≈ 1.23×10⁻¹⁰ m ≈ 0.123 nm.' },
  { q: 'A proton and an electron have the SAME speed. Which has the longer wavelength and by what factor?', a: 'λ ∝ 1/m at fixed v, so the electron: longer by mp/me ≈ 1836 times.' },
];

function Slider({ label, unit, value, min, max, step, set, color, note }: {
  label: string; unit: string; value: number; min: number; max: number;
  step: number; set: (v: number) => void; color: string; note?: string;
}) {
  return (
    <div className="space-y-1.5">
      <div className="flex justify-between text-xs">
        <span className="text-gray-500">{label}</span>
        <span className="font-medium tabular-nums text-gray-800">{value.toExponential(2)} <span className="text-gray-400 font-normal">{unit}</span></span>
      </div>
      <input type="range" min={min} max={max} step={step} value={value}
        onChange={e => set(Number(e.target.value))} className="w-full" style={{ accentColor: color }} />
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

export default function DeBrogliePage() {
  const [isRunning, setIsRunning] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const [openEx, setOpenEx] = useState<number | null>(null);
  const [activeCurricula, setActiveCurricula] = useState(['WAEC', 'IGCSE', 'JUPEB']);

  const [pIdx, setPIdx] = useState(0);
  const particle = PARTICLES[pIdx];
  const [velocity, setVelocity] = useState(particle.vDefault);
  const [accelV, setAccelV] = useState(100);

  const selectParticle = (i: number) => { setPIdx(i); setVelocity(PARTICLES[i].vDefault); };

  const reset = useCallback(() => { setIsRunning(false); setIsPaused(false); }, []);
  const resetTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  useEffect(() => {
    if (resetTimer.current) clearTimeout(resetTimer.current);
    resetTimer.current = setTimeout(reset, 80);
  }, [pIdx, velocity, reset]);

  const lambda = deBroglieLambda(particle.mass, velocity);

  const canvasBoxRef = useRef<HTMLDivElement>(null);
  const canvasSize = useResponsiveCanvasSize(canvasBoxRef, 640, 280, 980);

  return (
    <>
      <AppHeader />
      <main className="min-h-screen bg-gray-50">
        <section className="border-b border-gray-200 bg-white">
          <div className="mx-auto max-w-[100rem] px-4 sm:px-6 py-4">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
              <div>
                <p className="text-xs text-gray-400 mb-0.5">Modern physics</p>
                <h1 className="text-lg font-semibold text-gray-900">De Broglie hypothesis</h1>
              </div>
              <div className="flex gap-1.5 flex-wrap">
                {CURRICULA.map(c => (
                  <button key={c}
                    onClick={() => setActiveCurricula(p => p.includes(c) ? p.filter(x => x !== c) : [...p, c])}
                    className={`text-xs px-2.5 py-1 rounded-full border font-medium transition ${
                      activeCurricula.includes(c) ? CC[c] + ' border-transparent' : 'bg-white text-gray-400 border-gray-200'
                    }`}>{c}</button>
                ))}
              </div>
            </div>
          </div>
        </section>

        <div className="mx-auto max-w-[100rem] px-4 sm:px-6 py-4 space-y-4">
          <div className="flex flex-wrap items-center gap-3 rounded-xl border border-gray-200 bg-white px-4 py-2.5">
            <span className="text-xs text-gray-400">Matter waves</span>
            <span className="text-sm font-semibold font-mono text-gray-900">λ = h/mv = h/p</span>
            <span className="text-xs text-gray-400 ml-2">accelerated electron: λ = h/√(2meV)</span>
          </div>

          <div className="grid grid-cols-1 lg:grid-cols-[1fr_220px] xl:grid-cols-[1fr_220px_260px] gap-4">
            <div className="space-y-3 min-w-0">
              <div ref={canvasBoxRef} className="rounded-2xl border border-gray-200 bg-white p-3 shadow-sm">
                <DeBroglieCanvas mass={particle.mass} velocity={velocity} particleName={particle.name}
                  isRunning={isRunning} isPaused={isPaused} width={canvasSize.width} height={canvasSize.height} />
              </div>

              <div className="flex flex-wrap items-center justify-between gap-2">
                <SimulationControls isRunning={isRunning} isPaused={isPaused}
                  onRun={() => { setIsRunning(true); setIsPaused(false); }}
                  onPause={() => setIsPaused(p => !p)} onReset={reset} />
                <EmbedButton path="/embed/debroglie"
                  title="De Broglie wavelength — A-Factor STEM Studio"
                  params={{ p: pIdx, v: velocity }} />
              </div>

              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm space-y-4">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide">Parameters</p>
                <div className="flex flex-wrap gap-1.5">
                  {PARTICLES.map((p, i) => (
                    <button key={p.name} onClick={() => selectParticle(i)}
                      className={`rounded-full border px-2.5 py-1 text-[11px] font-medium transition ${
                        pIdx === i ? 'border-indigo-300 bg-indigo-50 text-indigo-700' : 'border-gray-200 bg-white text-gray-500 hover:border-indigo-200'
                      }`}>{p.emoji} {p.name}</button>
                  ))}
                </div>
                <Slider label="Speed v" unit="m/s" value={velocity} min={particle.vMin} max={particle.vMax}
                  step={(particle.vMax - particle.vMin) / 200} set={setVelocity} color="#6366f1"
                  note="Faster → more momentum → SHORTER wavelength" />
                <div className="rounded-xl bg-indigo-50 border border-indigo-100 p-3 space-y-2">
                  <p className="text-[11px] font-medium text-indigo-700">Electron gun calculator: λ = h/√(2meV)</p>
                  <Slider label="Accelerating voltage" unit="V" value={accelV} min={10} max={10000} step={10} set={setAccelV} color="#8b5cf6" />
                  <p className="text-xs text-indigo-800 font-mono">
                    V = {accelV} V → λ = {formatLambda(lambdaFromVoltage(accelV))}
                  </p>
                </div>
              </div>
            </div>

            <div className="space-y-3">
              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide mb-3">Calculated</p>
                <div className="space-y-2">
                  <StatRow label="Mass m" value={particle.mass.toExponential(2)} unit="kg" color="text-indigo-600" />
                  <StatRow label="Momentum p" value={momentum(particle.mass, velocity).toExponential(2)} unit="kg·m/s" color="text-emerald-600" />
                  <StatRow label="Wavelength λ" value={formatLambda(lambda)} unit="" color="text-amber-600" />
                  <StatRow label="vs atom (0.1nm)" value={(lambda / 1e-10).toExponential(1)} unit="×" color="text-rose-500" />
                </div>
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
