'use client';
import { useState, useCallback, useEffect, useRef, useMemo } from 'react';
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, Label, ReferenceDot } from 'recharts';
import { AppHeader } from '@/components/layout/AppHeader';
import { SimulationControls } from '@/components/simulation/SimulationControls';
import { PolarizationCanvas, PolarizationMode } from '@/components/simulation/PolarizationCanvas';
import { EmbedButton } from '@/components/ui/EmbedButton';
import { malusIntensity, malusCurve } from '@/lib/physics/polarization';
import { useResponsiveCanvasSize } from '@/hooks/useResponsiveCanvasSize';

const CURRICULA = ['WAEC', 'NECO', 'IGCSE', 'SAT', 'JUPEB'];
const CC: Record<string, string> = {
  WAEC: 'bg-indigo-100 text-indigo-700', NECO: 'bg-pink-100 text-pink-700',
  IGCSE: 'bg-emerald-100 text-emerald-700', SAT: 'bg-orange-100 text-orange-700',
  JUPEB: 'bg-purple-100 text-purple-700',
};

const MODE_META: Record<PolarizationMode, { title: string; icon: string; sub: string; eq: string }> = {
  single: { title: 'A single polarizer', icon: '🕶️', sub: 'Unpolarized → plane-polarized', eq: 'transmits one plane of vibration' },
  malus:  { title: "Malus's law",        icon: '📐', sub: 'Two polarizers at an angle',     eq: 'I = I₀cos²θ' },
};

const TEACHER_NOTES: Record<PolarizationMode, string[]> = {
  single: [
    'Light is a TRANSVERSE wave — it vibrates perpendicular to its direction of travel. "Unpolarized" light vibrates in every possible perpendicular direction at once.',
    'A polarizer has a transmission axis — it only lets through the component of vibration ALONG that axis, blocking the rest.',
    'Only transverse waves can be polarized. Sound is a LONGITUDINAL wave (vibrates along its direction of travel) and cannot be polarized — a useful way to distinguish the two in an exam.',
    'Polarizing sunglasses reduce glare because reflected light off water or glass becomes partially polarized (mostly horizontal) — a vertically-oriented lens blocks much of that reflected glare.',
    'LCD screens work by controlling the polarization of light passing through liquid crystals sandwiched between two polarizing filters.',
  ],
  malus: [
    "Malus's law applies to ALREADY plane-polarized light passing through a second polarizer (the \"analyser\"): I = I₀cos²θ, where θ is the angle between the two transmission axes.",
    'At θ=0° (parallel axes): cos²0°=1, full transmission. At θ=90° (crossed axes): cos²90°=0, no light gets through at all.',
    'At θ=45°, exactly HALF the intensity is transmitted (cos²45°=0.5) — a commonly tested value.',
    'Two crossed polarizers block all light — but inserting a THIRD polarizer at 45° between them actually lets some light back through. This surprising result is a classic demonstration and exam favourite.',
    'Malus\u2019s law only describes the SECOND polarizer onward. The first polarizer, acting on unpolarized light, always transmits exactly half the original intensity, regardless of its axis orientation (there\u2019s no "angle" to measure against yet).',
  ],
};

const EXERCISES: Record<PolarizationMode, { q: string; a: string }[]> = {
  single: [
    { q: 'Explain why sound waves cannot be polarized but light waves can.', a: 'Polarization only applies to transverse waves, where the vibration direction can be restricted to one plane. Sound is longitudinal (vibrates along its direction of travel), so there is no perpendicular direction to restrict.' },
    { q: 'Unpolarized light of intensity 40 W/m² passes through a single ideal polarizer. Find the transmitted intensity.', a: 'A single polarizer transmits exactly half of unpolarized light: 40/2 = 20 W/m².' },
    { q: 'State one practical use of polarizing filters.', a: 'Any of: polarizing sunglasses (reduce glare from reflected light), LCD screens, photography filters (reduce reflections/enhance sky contrast), stress analysis in transparent plastics.' },
  ],
  malus: [
    { q: 'Polarized light of intensity 60 W/m² passes through an analyser at 30° to its plane of polarization. Find the transmitted intensity.', a: 'I = I₀cos²θ = 60×cos²30° = 60×0.75 = 45 W/m².' },
    { q: 'At what angle between two polarizers is the transmitted intensity exactly half the incoming polarized intensity?', a: 'cos²θ=0.5 → cosθ=1/√2 → θ=45°.' },
    { q: 'Two polarizers are crossed (90° apart) so no light passes. Explain what happens if a third polarizer is inserted between them at 45° to both.', a: 'The first polarizer transmits light polarized at 0°. The middle (45°) polarizer transmits cos²45°=50% of that, now polarized at 45°. The final (90°) polarizer then transmits cos²45°=50% of THAT (since it is 45° from the middle one\u2019s output) — so some light gets through overall, even though the outer two alone would block everything.' },
  ],
};

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

function MalusGraph({ analyzerAngle }: { analyzerAngle: number }) {
  const data = useMemo(() => malusCurve(100), []);
  const I = malusIntensity(100, analyzerAngle);
  return (
    <ResponsiveContainer width="100%" height={190}>
      <LineChart data={data} margin={{ top: 8, right: 16, left: 10, bottom: 28 }}>
        <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
        <XAxis dataKey="angle" type="number" domain={[0, 180]} tick={{ fontSize: 10 }}>
          <Label value="θ between polarizers (°)" position="insideBottom" offset={-16} style={{ fontSize: 10, fill: '#94a3b8' }} />
        </XAxis>
        <YAxis tick={{ fontSize: 10 }}>
          <Label value="Transmitted I (% of I₀)" angle={-90} position="insideLeft" offset={12} style={{ fontSize: 10, fill: '#94a3b8' }} />
        </YAxis>
        <Tooltip formatter={(v: unknown) => [Number(v).toFixed(1) + '%', 'I']} labelFormatter={a => `θ=${a}°`} />
        <Line type="monotone" dataKey="I" stroke="#6366f1" strokeWidth={2} dot={false} isAnimationActive={false} />
        <ReferenceDot x={analyzerAngle} y={I} r={6} fill="#ef4444" stroke="#fff" strokeWidth={2} />
      </LineChart>
    </ResponsiveContainer>
  );
}

export default function PolarizationPage() {
  const [mode, setMode] = useState<PolarizationMode>('single');
  const [isRunning, setIsRunning] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const [resetKey, setResetKey] = useState(0);
  const [openEx, setOpenEx] = useState<number | null>(null);
  const [activeCurricula, setActiveCurricula] = useState(['WAEC', 'IGCSE', 'SAT']);

  const [polarizerAngle, setPolarizerAngle] = useState(30);
  const [analyzerAngle, setAnalyzerAngle] = useState(45);

  const reset = useCallback(() => { setIsRunning(false); setIsPaused(false); setResetKey(k => k + 1); }, []);
  const resetTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  useEffect(() => {
    if (resetTimer.current) clearTimeout(resetTimer.current);
    resetTimer.current = setTimeout(reset, 100);
  }, [mode, polarizerAngle, analyzerAngle, reset]);

  const canvasBoxRef = useRef<HTMLDivElement>(null);
  const canvasSize = useResponsiveCanvasSize(canvasBoxRef, 660, 260, 980);

  const transmitted = malusIntensity(100, analyzerAngle);

  return (
    <>
      <AppHeader />
      <main className="min-h-screen bg-gray-50">
        <section className="border-b border-gray-200 bg-white">
          <div className="mx-auto max-w-[100rem] px-4 sm:px-6 py-4">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
              <div>
                <p className="text-xs text-gray-400 mb-0.5">Waves</p>
                <h1 className="text-lg font-semibold text-gray-900">Polarization</h1>
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
          <div className="flex gap-1 bg-gray-100 p-1 rounded-xl overflow-x-auto">
            {(Object.keys(MODE_META) as PolarizationMode[]).map(m => (
              <button key={m} onClick={() => { setMode(m); setOpenEx(null); }}
                className={`shrink-0 flex items-center gap-1.5 px-3 py-2 rounded-lg text-xs font-medium transition ${
                  mode === m ? 'bg-white text-indigo-700 shadow-sm' : 'text-gray-500 hover:text-gray-700'
                }`}>
                <span>{MODE_META[m].icon}</span><span>{MODE_META[m].title}</span>
              </button>
            ))}
          </div>

          <div className="flex flex-wrap items-center gap-3 rounded-xl border border-gray-200 bg-white px-4 py-2.5">
            <span className="text-xs text-gray-400">{MODE_META[mode].sub}</span>
            <span className="text-sm font-semibold font-mono text-gray-900">{MODE_META[mode].eq}</span>
          </div>

          <div className="grid grid-cols-1 lg:grid-cols-[1fr_220px] xl:grid-cols-[1fr_220px_260px] gap-4">
            <div className="space-y-3 min-w-0">
              <div ref={canvasBoxRef} className="rounded-2xl border border-gray-200 bg-white p-3 shadow-sm">
                <PolarizationCanvas key={resetKey} mode={mode} polarizerAngle={polarizerAngle} analyzerAngle={analyzerAngle}
                  isRunning={isRunning} isPaused={isPaused}
                  width={canvasSize.width} height={canvasSize.height} />
              </div>

              <div className="flex flex-wrap items-center justify-between gap-2">
                <SimulationControls isRunning={isRunning} isPaused={isPaused}
                  onRun={() => { setIsRunning(true); setIsPaused(false); }}
                  onPause={() => setIsPaused(p => !p)} onReset={reset} />
                <EmbedButton path="/embed/polarization"
                  title={`${MODE_META[mode].title} — A-Factor STEM Studio`}
                  params={mode === 'single' ? { mode, angle: polarizerAngle } : { mode, angle: analyzerAngle }} />
              </div>

              {mode === 'malus' && (
                <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                  <p className="text-xs font-medium text-gray-400 uppercase tracking-wide mb-2">Transmitted intensity vs angle</p>
                  <MalusGraph analyzerAngle={analyzerAngle} />
                  <p className="text-[10px] text-gray-400 mt-2 text-center">I = I₀cos²θ — full transmission at 0°, zero at 90° (crossed)</p>
                </div>
              )}

              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm space-y-4">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide">Parameters</p>
                {mode === 'single' && (
                  <Slider label="Transmission axis" unit="°" value={polarizerAngle} min={0} max={180} step={5} set={setPolarizerAngle} color="#6366f1" note="Measured from vertical" />
                )}
                {mode === 'malus' && (
                  <Slider label="Analyser angle θ" unit="°" value={analyzerAngle} min={0} max={180} step={1} set={setAnalyzerAngle} color="#6366f1" note="Angle between the two polarizers" />
                )}
              </div>
            </div>

            <div className="space-y-3">
              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide mb-3">Calculated</p>
                <div className="space-y-2">
                  {mode === 'single' && <>
                    <StatRow label="Transmission axis" value={polarizerAngle.toString()} unit="°" color="text-indigo-600" />
                    <StatRow label="Through 1 polarizer" value="50" unit="% of I₀" color="text-emerald-600" />
                    <StatRow label="Result" value="plane-polarized" unit="" color="text-purple-600" />
                  </>}
                  {mode === 'malus' && <>
                    <StatRow label="Angle θ" value={analyzerAngle.toString()} unit="°" color="text-indigo-600" />
                    <StatRow label="cos²θ" value={Math.pow(Math.cos(analyzerAngle * Math.PI / 180), 2).toFixed(3)} unit="" color="text-emerald-600" />
                    <StatRow label="Transmitted I" value={transmitted.toFixed(1)} unit="% of I₀" color="text-amber-600" />
                    <StatRow label="State" value={analyzerAngle < 5 ? 'aligned — max' : analyzerAngle > 85 && analyzerAngle < 95 ? 'crossed — zero' : 'partial'} unit="" color="text-rose-500" />
                  </>}
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
                  {TEACHER_NOTES[mode].map((n, i) => (
                    <li key={i} className="text-xs text-amber-900 leading-relaxed flex gap-2">
                      <span className="text-amber-400 shrink-0 mt-0.5">•</span>{n}
                    </li>
                  ))}
                </ul>
              </div>

              <div className="rounded-2xl border border-gray-200 bg-white p-4">
                <p className="text-xs font-medium text-gray-500 uppercase tracking-wide mb-3">✏️ Exercises</p>
                <div className="space-y-2">
                  {EXERCISES[mode].map((ex, i) => (
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
