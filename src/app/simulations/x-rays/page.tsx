'use client';
import { useState, useCallback, useEffect, useRef, useMemo } from 'react';
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, Label, ReferenceLine } from 'recharts';
import { AppHeader } from '@/components/layout/AppHeader';
import { SimulationControls } from '@/components/simulation/SimulationControls';
import { XrayCanvas } from '@/components/simulation/XrayCanvas';
import { EmbedButton } from '@/components/ui/EmbedButton';
import { lambdaMinNm, maxPhotonEnergyKeV, xraySpectrum, MO_K_ALPHA_NM, MO_K_BETA_NM, MO_EXCITATION_KV } from '@/lib/physics/xrays';
import { useResponsiveCanvasSize } from '@/hooks/useResponsiveCanvasSize';

const CURRICULA = ['WAEC', 'NECO', 'IGCSE', 'SAT', 'JUPEB'];
const CC: Record<string, string> = {
  WAEC: 'bg-indigo-100 text-indigo-700', NECO: 'bg-pink-100 text-pink-700',
  IGCSE: 'bg-emerald-100 text-emerald-700', SAT: 'bg-orange-100 text-orange-700',
  JUPEB: 'bg-purple-100 text-purple-700',
};

const TEACHER_NOTES = [
  'X-ray production is the photoelectric effect in REVERSE: fast electrons in, photons out. Electrons accelerated through kV strike a metal target; ~99% of their energy becomes heat, ~1% becomes X-rays (which is why anodes are cooled or rotated).',
  'The continuous (bremsstrahlung = "braking radiation") spectrum has a sharp cutoff λmin = hc/eV — the Duane–Hunt limit. An electron cannot give a photon more than its whole kinetic energy eV.',
  'Raise the tube voltage: λmin slides LEFT (shorter, more penetrating "harder" X-rays). Raise the filament current: MORE X-rays (taller spectrum), same λmin.',
  'The sharp Kα/Kβ characteristic lines appear only when electrons can knock out inner-shell electrons of the target (Mo: above ~20 kV). Their wavelengths identify the target element — the basis of X-ray spectroscopy.',
  'Properties for exams: travel in straight lines, not deflected by electric/magnetic fields (uncharged), ionise gases, penetrate matter (absorbed by dense material like bone/lead), affect photographic film.',
];

const EXERCISES = [
  { q: 'An X-ray tube runs at 50 kV. Find the minimum wavelength produced. (h = 6.63×10⁻³⁴ Js, c = 3×10⁸ m/s, e = 1.6×10⁻¹⁹ C)', a: 'λmin = hc/eV = (6.63e-34 × 3e8)/(1.6e-19 × 5e4) = 2.49×10⁻¹¹ m ≈ 0.025 nm.' },
  { q: 'What is the maximum photon energy (in keV) from a 80 kV tube, and why is it a maximum?', a: '80 keV — a photon cannot carry more than the full kinetic energy eV of one electron; most electrons give up their energy in stages (heat + softer photons).' },
  { q: 'Doubling the filament current does what to (a) the spectrum height, (b) λmin?', a: '(a) Doubles the intensity everywhere — twice as many electrons. (b) λmin unchanged: it depends only on the tube voltage.' },
  { q: 'Why do the Kα and Kβ lines disappear when the tube voltage drops below 20 kV (Mo target)?', a: 'Below 20 kV the electrons lack the energy to eject a K-shell electron from molybdenum, so no inner-shell vacancies form and no characteristic photons are emitted.' },
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

function StatRow({ label, value, unit, color }: { label: string; value: string; unit: string; color: string }) {
  return (
    <div className="flex justify-between items-center rounded-lg bg-gray-50 px-3 py-2">
      <span className="text-xs text-gray-500">{label}</span>
      <span className={`text-xs font-semibold tabular-nums ${color}`}>{value} <span className="text-gray-400 font-normal">{unit}</span></span>
    </div>
  );
}

function SpectrumGraph({ kV, current }: { kV: number; current: number }) {
  const data = useMemo(() => xraySpectrum(kV, current), [kV, current]);
  const lMin = lambdaMinNm(kV);
  return (
    <ResponsiveContainer width="100%" height={210}>
      <LineChart data={data} margin={{ top: 8, right: 16, left: 10, bottom: 28 }}>
        <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
        <XAxis dataKey="lambda" type="number" tick={{ fontSize: 10 }} domain={[0, 0.14]}>
          <Label value="Wavelength λ (nm)" position="insideBottom" offset={-16} style={{ fontSize: 10, fill: '#94a3b8' }} />
        </XAxis>
        <YAxis tick={{ fontSize: 10 }}>
          <Label value="Intensity" angle={-90} position="insideLeft" offset={12} style={{ fontSize: 10, fill: '#94a3b8' }} />
        </YAxis>
        <Tooltip formatter={(v: unknown) => [Number(v).toFixed(2), 'I']} labelFormatter={l => `λ=${Number(l).toFixed(3)}nm`} />
        <Line type="linear" dataKey="i" stroke="#8b5cf6" strokeWidth={2} dot={false} isAnimationActive={false} />
        <ReferenceLine x={lMin} stroke="#ef4444" strokeDasharray="4 4"
          label={{ value: 'λmin', position: 'top', fontSize: 10, fill: '#dc2626' }} />
        {kV >= MO_EXCITATION_KV && <>
          <ReferenceLine x={MO_K_ALPHA_NM} stroke="#e2e8f0"
            label={{ value: 'Kα', position: 'top', fontSize: 9, fill: '#94a3b8' }} />
          <ReferenceLine x={MO_K_BETA_NM} stroke="#e2e8f0"
            label={{ value: 'Kβ', position: 'top', fontSize: 9, fill: '#94a3b8' }} />
        </>}
      </LineChart>
    </ResponsiveContainer>
  );
}

export default function XraysPage() {
  const [isRunning, setIsRunning] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const [openEx, setOpenEx] = useState<number | null>(null);
  const [activeCurricula, setActiveCurricula] = useState(['WAEC', 'IGCSE', 'JUPEB']);

  const [kV, setKV] = useState(35);
  const [current, setCurrent] = useState(5);

  const reset = useCallback(() => { setIsRunning(false); setIsPaused(false); }, []);
  const resetTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  useEffect(() => {
    if (resetTimer.current) clearTimeout(resetTimer.current);
    resetTimer.current = setTimeout(reset, 80);
  }, [kV, current, reset]);

  const canvasBoxRef = useRef<HTMLDivElement>(null);
  const canvasSize = useResponsiveCanvasSize(canvasBoxRef, 640, 300, 980);

  return (
    <>
      <AppHeader />
      <main className="min-h-screen bg-gray-50">
        <section className="border-b border-gray-200 bg-white">
          <div className="mx-auto max-w-[100rem] px-4 sm:px-6 py-4">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
              <div>
                <p className="text-xs text-gray-400 mb-0.5">Modern physics</p>
                <h1 className="text-lg font-semibold text-gray-900">X-rays</h1>
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
            <span className="text-xs text-gray-400">Duane–Hunt limit</span>
            <span className="text-sm font-semibold font-mono text-gray-900">λmin = hc/eV</span>
            <span className="text-xs text-gray-400 ml-2">max photon energy = eV</span>
          </div>

          <div className="grid grid-cols-1 lg:grid-cols-[1fr_220px] xl:grid-cols-[1fr_220px_260px] gap-4">
            <div className="space-y-3 min-w-0">
              <div ref={canvasBoxRef} className="rounded-2xl border border-gray-200 bg-white p-3 shadow-sm">
                <XrayCanvas kV={kV} current={current}
                  isRunning={isRunning} isPaused={isPaused} width={canvasSize.width} height={canvasSize.height} />
              </div>

              <div className="flex flex-wrap items-center justify-between gap-2">
                <SimulationControls isRunning={isRunning} isPaused={isPaused}
                  onRun={() => { setIsRunning(true); setIsPaused(false); }}
                  onPause={() => setIsPaused(p => !p)} onReset={reset} />
                <EmbedButton path="/embed/xrays"
                  title="X-ray tube — A-Factor STEM Studio"
                  params={{ kV, i: current }} />
              </div>

              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide mb-2">X-ray spectrum (Mo target)</p>
                <SpectrumGraph kV={kV} current={current} />
                <p className="text-[10px] text-gray-400 mt-2 text-center">
                  Continuous bremsstrahlung with sharp cutoff at λmin — Kα/Kβ characteristic lines above {MO_EXCITATION_KV} kV
                </p>
              </div>

              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm space-y-4">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide">Parameters</p>
                <Slider label="Tube voltage" unit="kV" value={kV} min={5} max={100} step={1} set={setKV} color="#6366f1"
                  note="Higher V → shorter λmin → harder, more penetrating X-rays" />
                <Slider label="Filament current" unit="" value={current} min={1} max={10} step={1} set={setCurrent} color="#f59e0b"
                  note="More electrons → more X-rays, but λmin does not move" />
              </div>
            </div>

            <div className="space-y-3">
              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide mb-3">Calculated</p>
                <div className="space-y-2">
                  <StatRow label="λmin" value={lambdaMinNm(kV).toFixed(4)} unit="nm" color="text-indigo-600" />
                  <StatRow label="Max photon energy" value={maxPhotonEnergyKeV(kV).toFixed(0)} unit="keV" color="text-emerald-600" />
                  <StatRow label="Electron KE" value={kV.toFixed(0)} unit="keV" color="text-amber-600" />
                  <StatRow label="K lines" value={kV >= MO_EXCITATION_KV ? 'visible' : 'absent'} unit="" color="text-rose-500" />
                  <StatRow label="Energy → heat" value="~99" unit="%" color="text-purple-600" />
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
