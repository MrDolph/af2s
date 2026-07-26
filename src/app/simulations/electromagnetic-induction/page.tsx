'use client';
import { useState, useCallback, useEffect, useRef } from 'react';
import { AppHeader } from '@/components/layout/AppHeader';
import { SimulationControls } from '@/components/simulation/SimulationControls';
import { InductionCanvas, InductionMode } from '@/components/simulation/InductionCanvas';
import { EmbedButton } from '@/components/ui/EmbedButton';
import { generatorPeakEmf, rmsFromPeak, transformerSecondaryVoltage, transformerSecondaryCurrent } from '@/lib/physics/electromagnetism';
import { useResponsiveCanvasSize } from '@/hooks/useResponsiveCanvasSize';

type Topic = 'faraday-lenz' | 'ac-generator' | 'transformer';

const CURRICULA = ['WAEC', 'NECO', 'IGCSE', 'SAT', 'JUPEB', 'Undergraduate'];
const CC: Record<string, string> = {
  WAEC: 'bg-indigo-100 text-indigo-700', NECO: 'bg-pink-100 text-pink-700',
  IGCSE: 'bg-emerald-100 text-emerald-700', SAT: 'bg-orange-100 text-orange-700',
  JUPEB: 'bg-purple-100 text-purple-700', Undergraduate: 'bg-slate-200 text-slate-700',
};

const TOPIC_META: Record<Topic, { title: string; icon: string; sub: string; eq: string }> = {
  'faraday-lenz': { title: "Faraday's & Lenz's Law", icon: '🧲', sub: 'Moving magnet induces EMF', eq: 'EMF = -N dΦ/dt' },
  'ac-generator': { title: 'AC Generator',            icon: '🔄', sub: 'Rotating coil in a field',  eq: 'e = NBAω sin(ωt)' },
  transformer:    { title: 'Transformer',              icon: '🔌', sub: 'Changing flux, linked coils', eq: 'Vs/Vp = Ns/Np' },
};

const TEACHER_NOTES: Record<Topic, string[]> = {
  'faraday-lenz': [
    "Faraday's law: an EMF is induced in a circuit whenever the magnetic flux linking it CHANGES — no change, no EMF, even if the field itself is strong.",
    'The size of the induced EMF depends on the RATE of change of flux — move the magnet faster, or use more turns, and the galvanometer deflects further.',
    "Lenz's law gives the DIRECTION: the induced current always flows to OPPOSE the change that created it. An approaching magnet induces a current that makes the coil repel it; a receding magnet induces a current that makes the coil attract it back.",
    "Lenz's law is really a statement of energy conservation — if the induced current instead ASSISTED the motion, you'd get free energy from nothing, which is impossible. The opposing force is exactly why you feel resistance pushing a magnet into a coil.",
    'Undergraduate note: EMF = -N dΦ/dt is Faraday\u2019s law in its general (integral) form; the minus sign IS Lenz\u2019s law, encoded directly into the equation rather than argued separately.',
  ],
  'ac-generator': [
    'An AC generator converts mechanical rotation into electrical energy by rotating a coil inside a magnetic field (or, equivalently, rotating the magnet around a fixed coil).',
    'The output is sinusoidal: e = e₀sin(ωt), because the RATE at which the coil cuts field lines varies smoothly as it turns — fastest when the coil plane is parallel to the field, zero for an instant when it is perpendicular.',
    'Peak EMF e₀ = NBAω — more turns, a stronger field, a bigger coil, or spinning faster all increase the output.',
    'Slip rings (continuous contact) let an AC generator deliver alternating current to an external circuit; a DC generator instead uses a split-ring commutator to reverse the connections every half turn, converting the output to a bumpy one-directional DC.',
    'Undergraduate note: RMS values (used for practical AC ratings, e.g. "230V mains") are e₀/√2 — the DC-equivalent value that would deliver the same average power, since a sine wave\u2019s average power is half its peak power.',
  ],
  transformer: [
    'A transformer uses electromagnetic induction to change AC voltage: an alternating current in the primary coil creates a constantly CHANGING flux in the shared iron core, which induces an EMF in the secondary coil.',
    'Ideal transformer equation: Vs/Vp = Ns/Np — more turns on the secondary than the primary steps the voltage UP; fewer turns steps it DOWN.',
    'A transformer only works on AC — a steady DC current produces a constant (non-changing) flux, so no EMF is induced in the secondary at all.',
    'Power is conserved in an ideal transformer (VpIp = VsIs), so stepping voltage UP necessarily steps current DOWN by the same factor, and vice versa — a transformer cannot create extra power.',
    'Undergraduate note: real transformers lose some energy to resistive heating in the windings and to hysteresis/eddy-current losses in the core — laminating the core (thin insulated sheets instead of one solid block) is specifically to reduce eddy-current losses.',
  ],
};

const EXERCISES: Record<Topic, { q: string; a: string }[]> = {
  'faraday-lenz': [
    { q: 'A magnet is pushed INTO a coil, north pole first. What pole does the coil face present toward the magnet, and why?', a: 'By Lenz\u2019s law, the coil opposes the increasing flux by presenting a NORTH pole toward the approaching magnet — like poles repel, resisting the push.' },
    { q: 'The same magnet is now pulled OUT of the coil. How does the induced current direction compare to when it was pushed in?', a: 'It reverses — the coil now presents a SOUTH pole to attract the receding magnet and oppose its departure, meaning the current flows in the opposite direction around the coil.' },
    { q: 'Why is there no induced EMF when the magnet is held stationary inside the coil?', a: 'Flux is only changing while there is RELATIVE MOTION between the magnet and coil — a stationary magnet produces a constant flux, and dΦ/dt = 0 means no induced EMF.' },
  ],
  'ac-generator': [
    { q: 'A generator coil of 200 turns, area 0.03m², spins at 60 rad/s in a 0.4T field. Find the peak EMF.', a: 'e₀ = NBAω = 200×0.4×0.03×60 = 144 V.' },
    { q: 'At what point in the rotation is the induced EMF exactly zero, and why?', a: 'When the coil plane is perpendicular to the field (the coil face pointing directly along the field lines) — at that instant the coil sides are momentarily moving PARALLEL to the field, cutting no field lines at all.' },
    { q: 'A generator\u2019s peak EMF is 340V. Find the RMS voltage (the value you would measure with a standard AC voltmeter).', a: 'RMS = peak/√2 = 340/1.414 ≈ 240V — very close to the UK/Nigeria mains RMS voltage.' },
  ],
  transformer: [
    { q: 'A step-down transformer has 1000 turns on the primary and 50 on the secondary, with 240V AC input. Find the output voltage.', a: 'Vs = Vp×(Ns/Np) = 240×(50/1000) = 12 V.' },
    { q: 'The same transformer draws a primary current of 0.5A. Find the secondary current (assume 100% efficiency).', a: 'Power is conserved: VpIp = VsIs, so Is = VpIp/Vs = (240×0.5)/12 = 10 A.' },
    { q: 'Why won\u2019t a transformer work if you connect its primary to a battery (DC) instead of AC?', a: 'A steady DC current produces a constant magnetic flux in the core. Since Faraday\u2019s law requires a CHANGING flux to induce an EMF, a constant flux induces nothing in the secondary — except for the brief instants the DC is switched on or off.' },
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

export default function ElectromagneticInductionPage() {
  const [topic, setTopic] = useState<Topic>('faraday-lenz');
  const [isRunning, setIsRunning] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const [resetKey, setResetKey] = useState(0);
  const [openEx, setOpenEx] = useState<number | null>(null);
  const [activeCurricula, setActiveCurricula] = useState(['WAEC', 'IGCSE', 'SAT']);

  const [turns, setTurns] = useState(8);
  const [speed, setSpeed] = useState(2);
  const [magnetPoleOut, setMagnetPoleOut] = useState(true);

  const [genTurns, setGenTurns] = useState(50);
  const [genFieldB, setGenFieldB] = useState(0.3);
  const [genArea, setGenArea] = useState(0.02);
  const [genOmega, setGenOmega] = useState(3);

  const [primaryTurns, setPrimaryTurns] = useState(500);
  const [secondaryTurns, setSecondaryTurns] = useState(100);
  const [primaryVoltage, setPrimaryVoltage] = useState(240);

  const [liveValue, setLiveValue] = useState(0);

  const reset = useCallback(() => { setIsRunning(false); setIsPaused(false); setResetKey(k => k + 1); }, []);
  const resetTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  useEffect(() => {
    if (resetTimer.current) clearTimeout(resetTimer.current);
    resetTimer.current = setTimeout(reset, 100);
  }, [topic, turns, speed, magnetPoleOut, genTurns, genFieldB, genArea, genOmega, primaryTurns, secondaryTurns, primaryVoltage, reset]);

  const canvasBoxRef = useRef<HTMLDivElement>(null);
  const canvasSize = useResponsiveCanvasSize(canvasBoxRef, 660, 320, 980);

  const peakEmf = generatorPeakEmf(genTurns, genFieldB, genArea, genOmega);
  const vs = transformerSecondaryVoltage(primaryVoltage, primaryTurns, secondaryTurns);
  const isPer1A = transformerSecondaryCurrent(1, primaryTurns, secondaryTurns);

  return (
    <>
      <AppHeader />
      <main className="min-h-screen bg-gray-50">
        <section className="border-b border-gray-200 bg-white">
          <div className="mx-auto max-w-[100rem] px-4 sm:px-6 py-4">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
              <div>
                <p className="text-xs text-gray-400 mb-0.5">Electricity · Electromagnetism</p>
                <h1 className="text-lg font-semibold text-gray-900">Electromagnetic Induction</h1>
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
            {(Object.keys(TOPIC_META) as Topic[]).map(t => (
              <button key={t} onClick={() => { setTopic(t); setOpenEx(null); }}
                className={`shrink-0 flex items-center gap-1.5 px-3 py-2 rounded-lg text-xs font-medium transition ${
                  topic === t ? 'bg-white text-indigo-700 shadow-sm' : 'text-gray-500 hover:text-gray-700'
                }`}>
                <span>{TOPIC_META[t].icon}</span><span>{TOPIC_META[t].title}</span>
              </button>
            ))}
          </div>

          <div className="flex flex-wrap items-center gap-3 rounded-xl border border-gray-200 bg-white px-4 py-2.5">
            <span className="text-xs text-gray-400">{TOPIC_META[topic].sub}</span>
            <span className="text-sm font-semibold font-mono text-gray-900">{TOPIC_META[topic].eq}</span>
          </div>

          <div className="grid grid-cols-1 lg:grid-cols-[1fr_220px] xl:grid-cols-[1fr_220px_260px] gap-4">
            <div className="space-y-3 min-w-0">
              <div ref={canvasBoxRef} className="rounded-2xl border border-gray-200 bg-white p-3 shadow-sm">
                <InductionCanvas key={resetKey} mode={topic as InductionMode}
                  turns={turns} speed={speed} magnetPoleOut={magnetPoleOut}
                  fieldB={genFieldB} coilArea={genArea} omega={genOmega}
                  primaryTurns={primaryTurns} secondaryTurns={secondaryTurns} primaryVoltage={primaryVoltage}
                  isRunning={isRunning} isPaused={isPaused} onTick={setLiveValue}
                  width={canvasSize.width} height={canvasSize.height} />
              </div>

              <div className="flex flex-wrap items-center justify-between gap-2">
                <SimulationControls isRunning={isRunning} isPaused={isPaused}
                  onRun={() => { setIsRunning(true); setIsPaused(false); }}
                  onPause={() => setIsPaused(p => !p)} onReset={reset} />
                <EmbedButton path="/embed/electromagnetic-induction"
                  title={`${TOPIC_META[topic].title} — A-Factor STEM Studio`}
                  params={{ topic }} />
              </div>

              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm space-y-4">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide">Parameters</p>

                {topic === 'faraday-lenz' && <>
                  <Slider label="Coil turns" unit="" value={turns} min={2} max={20} step={1} set={setTurns} color="#6366f1" />
                  <Slider label="Oscillation speed" unit="rad/s" value={speed} min={0.5} max={5} step={0.5} set={setSpeed} color="#f59e0b" />
                  <div className="flex gap-2">
                    {([true, false] as const).map(v => (
                      <button key={String(v)} onClick={() => setMagnetPoleOut(v)}
                        className={`flex-1 rounded-lg border px-2 py-2 text-xs font-medium transition ${
                          magnetPoleOut === v ? 'border-indigo-300 bg-indigo-50 text-indigo-700' : 'border-gray-200 bg-white text-gray-500'
                        }`}>{v ? 'N faces coil' : 'S faces coil'}</button>
                    ))}
                  </div>
                </>}

                {topic === 'ac-generator' && <>
                  <Slider label="Coil turns" unit="" value={genTurns} min={10} max={200} step={10} set={setGenTurns} color="#6366f1" />
                  <Slider label="Field strength" unit="T" value={genFieldB} min={0.1} max={1} step={0.05} set={setGenFieldB} color="#f59e0b" />
                  <Slider label="Coil area" unit="m²" value={genArea} min={0.005} max={0.05} step={0.005} set={setGenArea} color="#8b5cf6" />
                  <Slider label="Angular speed ω" unit="rad/s" value={genOmega} min={1} max={10} step={0.5} set={setGenOmega} color="#8b5cf6" />
                </>}

                {topic === 'transformer' && <>
                  <Slider label="Primary voltage (peak)" unit="V" value={primaryVoltage} min={12} max={240} step={12} set={setPrimaryVoltage} color="#dc2626" />
                  <Slider label="Primary turns" unit="" value={primaryTurns} min={50} max={1000} step={50} set={setPrimaryTurns} color="#6366f1" />
                  <Slider label="Secondary turns" unit="" value={secondaryTurns} min={50} max={1000} step={50} set={setSecondaryTurns} color="#2563eb" />
                </>}
              </div>
            </div>

            <div className="space-y-3">
              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide mb-3">Calculated</p>
                <div className="space-y-2">
                  {topic === 'faraday-lenz' && <>
                    <StatRow label="Live EMF" value={liveValue.toFixed(2)} unit="(arb. units)" color="text-indigo-600" />
                    <StatRow label="Lenz's law" value="opposes the change" unit="always" color="text-emerald-600" />
                  </>}
                  {topic === 'ac-generator' && <>
                    <StatRow label="Peak EMF e₀" value={peakEmf.toFixed(1)} unit="V" color="text-indigo-600" />
                    <StatRow label="RMS EMF" value={rmsFromPeak(peakEmf).toFixed(1)} unit="V" color="text-emerald-600" />
                    <StatRow label="Frequency" value={(genOmega / (2 * Math.PI)).toFixed(2)} unit="Hz" color="text-amber-600" />
                  </>}
                  {topic === 'transformer' && <>
                    <StatRow label="Secondary voltage" value={vs.toFixed(1)} unit="V" color="text-indigo-600" />
                    <StatRow label="Turns ratio Ns/Np" value={(secondaryTurns / primaryTurns).toFixed(2)} unit="" color="text-amber-600" />
                    <StatRow label="Is per 1A primary" value={isPer1A.toFixed(2)} unit="A" color="text-purple-600" />
                    <StatRow label="Type" value={secondaryTurns > primaryTurns ? 'step-up' : secondaryTurns < primaryTurns ? 'step-down' : 'isolation'} unit="" color="text-emerald-600" />
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
                  {TEACHER_NOTES[topic].map((n, i) => (
                    <li key={i} className="text-xs text-amber-900 leading-relaxed flex gap-2">
                      <span className="text-amber-400 shrink-0 mt-0.5">•</span>{n}
                    </li>
                  ))}
                </ul>
              </div>

              <div className="rounded-2xl border border-gray-200 bg-white p-4">
                <p className="text-xs font-medium text-gray-500 uppercase tracking-wide mb-3">✏️ Exercises</p>
                <div className="space-y-2">
                  {EXERCISES[topic].map((ex, i) => (
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
