'use client';
import { useState, useCallback, useEffect, useRef, useMemo } from 'react';
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, Label, ReferenceDot, ReferenceLine } from 'recharts';
import { AppHeader } from '@/components/layout/AppHeader';
import { SimulationControls } from '@/components/simulation/SimulationControls';
import { PhotoelectricCanvas } from '@/components/simulation/PhotoelectricCanvas';
import { EmbedButton } from '@/components/ui/EmbedButton';
import { METALS, keMaxEV, thresholdF14, stoppingPotential, photonEnergyEV, wavelengthNm, keLine } from '@/lib/physics/photoelectric';

const CURRICULA = ['WAEC', 'NECO', 'IGCSE', 'SAT', 'JUPEB'];
const CC: Record<string, string> = {
  WAEC: 'bg-indigo-100 text-indigo-700', NECO: 'bg-pink-100 text-pink-700',
  IGCSE: 'bg-emerald-100 text-emerald-700', SAT: 'bg-orange-100 text-orange-700',
  JUPEB: 'bg-purple-100 text-purple-700',
};

const TEACHER_NOTES = [
  'The killer observation classical physics could NOT explain: below the threshold frequency f₀ = φ/h, NO electrons are emitted no matter how intense the light. Try it — set red light on zinc and crank the intensity.',
  'Light arrives as PHOTONS of energy E = hf. One photon frees at most one electron: hf = φ + KEmax (Einstein, Nobel Prize 1921).',
  'Intensity controls the NUMBER of photons → the photocurrent. Frequency controls the ENERGY of each electron. Watch: more intensity = more electrons, not faster ones.',
  'The KEmax–f graph is a straight line with slope h/e (the same for every metal!) and x-intercept f₀. Different metals shift the line, never tilt it.',
  'Stopping potential Vs: the reverse voltage that just stops the fastest electrons — eVs = KEmax, so Vs in volts equals KEmax in eV.',
];

const EXERCISES = [
  { q: 'Light of frequency 7×10¹⁴ Hz falls on sodium (φ = 2.28 eV). Find the photon energy and KEmax. (h = 6.63×10⁻³⁴ Js, e = 1.6×10⁻¹⁹ C)', a: 'E = hf = 6.63e-34 × 7e14 = 4.64e-19 J = 2.90 eV. KEmax = 2.90 − 2.28 = 0.62 eV ≈ 1.0×10⁻¹⁹ J.' },
  { q: 'The threshold wavelength of a metal is 500 nm. Find its work function in eV.', a: 'φ = hc/λ₀ = (6.63e-34 × 3e8)/5e-7 = 3.98e-19 J ≈ 2.48 eV.' },
  { q: 'Doubling the intensity of light on a photocell does what to (a) the current, (b) the KEmax?', a: '(a) Current doubles — twice as many photons free twice as many electrons. (b) KEmax is unchanged — each photon still carries the same energy hf.' },
  { q: 'For caesium (φ = 2.1 eV) lit at f = 8×10¹⁴ Hz, find the stopping potential.', a: 'E = hf = 3.31 eV. KEmax = 3.31 − 2.1 = 1.21 eV, so Vs = 1.21 V.' },
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

// KEmax vs f graph: straight line of universal slope h/e, x-intercept f₀.
function KEGraph({ phiEV, f14 }: { phiEV: number; f14: number }) {
  const fMax = 14;
  const data = useMemo(() => keLine(phiEV, fMax), [phiEV]);
  const f0 = thresholdF14(phiEV);
  const ke = keMaxEV(f14, phiEV);
  return (
    <ResponsiveContainer width="100%" height={200}>
      <LineChart data={data} margin={{ top: 8, right: 16, left: 10, bottom: 28 }}>
        <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
        <XAxis dataKey="f" type="number" tick={{ fontSize: 10 }} domain={[0, fMax]}>
          <Label value="Frequency f (×10¹⁴ Hz)" position="insideBottom" offset={-16} style={{ fontSize: 10, fill: '#94a3b8' }} />
        </XAxis>
        <YAxis tick={{ fontSize: 10 }}>
          <Label value="KEmax (eV)" angle={-90} position="insideLeft" offset={12} style={{ fontSize: 10, fill: '#94a3b8' }} />
        </YAxis>
        <Tooltip formatter={(v: unknown) => [Number(v).toFixed(2) + ' eV', 'KEmax']} labelFormatter={f => `f = ${f}×10¹⁴ Hz`} />
        <Line type="linear" dataKey="ke" stroke="#6366f1" strokeWidth={2} dot={false} isAnimationActive={false} />
        <ReferenceLine x={f0} stroke="#f59e0b" strokeDasharray="4 4"
          label={{ value: 'f₀', position: 'top', fontSize: 10, fill: '#d97706' }} />
        <ReferenceDot x={Math.min(f14, fMax)} y={ke} r={6} fill="#ef4444" stroke="#fff" strokeWidth={2} />
      </LineChart>
    </ResponsiveContainer>
  );
}

export default function PhotoelectricPage() {
  const [isRunning, setIsRunning] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const [openEx, setOpenEx] = useState<number | null>(null);
  const [activeCurricula, setActiveCurricula] = useState(['WAEC', 'IGCSE', 'JUPEB']);

  const [metalIdx, setMetalIdx] = useState(0);
  const [f14, setF14] = useState(6.0);
  const [intensity, setIntensity] = useState(5);

  const metal = METALS[metalIdx];
  const reset = useCallback(() => { setIsRunning(false); setIsPaused(false); }, []);
  const resetTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  useEffect(() => {
    if (resetTimer.current) clearTimeout(resetTimer.current);
    resetTimer.current = setTimeout(reset, 80);
  }, [metalIdx, f14, intensity, reset]);

  const ke = keMaxEV(f14, metal.phi);
  const f0 = thresholdF14(metal.phi);

  return (
    <>
      <AppHeader />
      <main className="min-h-screen bg-gray-50">
        <section className="border-b border-gray-200 bg-white">
          <div className="mx-auto max-w-7xl px-4 sm:px-6 py-4">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
              <div>
                <p className="text-xs text-gray-400 mb-0.5">Modern physics</p>
                <h1 className="text-lg font-semibold text-gray-900">Photoelectric effect</h1>
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

        <div className="mx-auto max-w-7xl px-4 sm:px-6 py-4 space-y-4">
          <div className="flex flex-wrap items-center gap-3 rounded-xl border border-gray-200 bg-white px-4 py-2.5">
            <span className="text-xs text-gray-400">Einstein&apos;s photoelectric equation</span>
            <span className="text-sm font-semibold font-mono text-gray-900">hf = φ + KEmax</span>
            <span className="text-xs text-gray-400 ml-2">f₀ = φ/h &nbsp;|&nbsp; eVs = KEmax</span>
          </div>

          <div className="grid grid-cols-1 lg:grid-cols-[1fr_220px] xl:grid-cols-[1fr_220px_260px] gap-4">
            <div className="space-y-3 min-w-0">
              <div className="rounded-2xl border border-gray-200 bg-white p-3 shadow-sm">
                <PhotoelectricCanvas f14={f14} intensity={intensity} phiEV={metal.phi} metalName={metal.name}
                  isRunning={isRunning} isPaused={isPaused} width={640} height={300} />
              </div>

              <div className="flex flex-wrap items-center justify-between gap-2">
                <SimulationControls isRunning={isRunning} isPaused={isPaused}
                  onRun={() => { setIsRunning(true); setIsPaused(false); }}
                  onPause={() => setIsPaused(p => !p)} onReset={reset} />
                <EmbedButton path="/embed/photoelectric"
                  title="Photoelectric effect — A-Factor STEM Studio"
                  params={{ metal: metalIdx, f: f14, i: intensity }} />
              </div>

              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide mb-2">KEmax against frequency</p>
                <KEGraph phiEV={metal.phi} f14={f14} />
                <p className="text-[10px] text-gray-400 mt-2 text-center">
                  Slope = h/e for EVERY metal · x-intercept = threshold f₀ · red dot = your current light
                </p>
              </div>

              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm space-y-4">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide">Parameters</p>
                <div className="flex flex-wrap gap-1.5">
                  {METALS.map((m, i) => (
                    <button key={m.name} onClick={() => setMetalIdx(i)}
                      className={`rounded-full border px-2.5 py-1 text-[11px] font-medium transition ${
                        metalIdx === i ? 'border-indigo-300 bg-indigo-50 text-indigo-700' : 'border-gray-200 bg-white text-gray-500 hover:border-indigo-200'
                      }`}>{m.name} ({m.phi} eV)</button>
                  ))}
                </div>
                <Slider label="Light frequency" unit="×10¹⁴ Hz" value={f14} min={2} max={14} step={0.1} set={setF14} color="#6366f1"
                  note={`Threshold for ${metal.name}: f₀ = ${f0.toFixed(2)}×10¹⁴ Hz — drop below it and emission stops`} />
                <Slider label="Intensity" unit="" value={intensity} min={1} max={10} step={1} set={setIntensity} color="#f59e0b"
                  note="Changes how MANY electrons per second — never their energy" />
              </div>
            </div>

            <div className="space-y-3">
              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide mb-3">Calculated</p>
                <div className="space-y-2">
                  <StatRow label="Photon energy hf" value={photonEnergyEV(f14).toFixed(2)} unit="eV" color="text-indigo-600" />
                  <StatRow label="Wavelength λ" value={wavelengthNm(f14).toFixed(0)} unit="nm" color="text-emerald-600" />
                  <StatRow label="Work function φ" value={metal.phi.toFixed(2)} unit="eV" color="text-amber-600" />
                  <StatRow label="Threshold f₀" value={f0.toFixed(2)} unit="×10¹⁴ Hz" color="text-rose-500" />
                  <StatRow label="KEmax" value={ke.toFixed(2)} unit="eV" color="text-purple-600" />
                  <StatRow label="Stopping potential" value={stoppingPotential(f14, metal.phi).toFixed(2)} unit="V" color="text-gray-600" />
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
