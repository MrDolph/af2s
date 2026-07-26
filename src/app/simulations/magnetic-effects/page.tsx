'use client';
import { useState, useCallback, useEffect, useRef } from 'react';
import { AppHeader } from '@/components/layout/AppHeader';
import { SimulationControls } from '@/components/simulation/SimulationControls';
import { MagneticFieldCanvas, MagneticMode } from '@/components/simulation/MagneticFieldCanvas';
import { EmbedButton } from '@/components/ui/EmbedButton';
import { fieldStraightWire, fieldSolenoid, forceOnConductor, forcePerLengthParallelWires } from '@/lib/physics/electromagnetism';
import { useResponsiveCanvasSize } from '@/hooks/useResponsiveCanvasSize';

type Topic = 'straight-wire' | 'solenoid' | 'motor-effect';

const CURRICULA = ['WAEC', 'NECO', 'IGCSE', 'SAT', 'JUPEB', 'Undergraduate'];
const CC: Record<string, string> = {
  WAEC: 'bg-indigo-100 text-indigo-700', NECO: 'bg-pink-100 text-pink-700',
  IGCSE: 'bg-emerald-100 text-emerald-700', SAT: 'bg-orange-100 text-orange-700',
  JUPEB: 'bg-purple-100 text-purple-700', Undergraduate: 'bg-slate-200 text-slate-700',
};

const TOPIC_META: Record<Topic, { title: string; icon: string; sub: string; eq: string }> = {
  'straight-wire': { title: 'Field of a straight wire', icon: '⚡', sub: "Right-hand grip rule",     eq: 'B = μ₀I/2πr' },
  solenoid:        { title: 'Field of a solenoid',       icon: '🌀', sub: "Coil acts like a magnet", eq: 'B = μ₀nI' },
  'motor-effect':  { title: 'Force on a conductor',      icon: '🧲', sub: "Fleming's left-hand rule", eq: 'F = BIL sinθ' },
};

const TEACHER_NOTES: Record<Topic, string[]> = {
  'straight-wire': [
    'A current-carrying wire is always surrounded by a magnetic field — the field lines form CONCENTRIC CIRCLES centred on the wire, in a plane perpendicular to it.',
    'Right-hand GRIP rule: point your right thumb in the direction of conventional current flow; your curled fingers show the direction of the field.',
    'Field strength B = μ₀I/2πr decreases with distance from the wire — double the distance, half the field.',
    'μ₀ = 4π×10⁻⁷ T·m/A is the permeability of free space — it sets how strongly current produces a magnetic field in a vacuum (or air, to a very good approximation).',
    'Undergraduate note: this is the direct result of Ampère\u2019s circuital law, ∮B·dl = μ₀I_enc, applied to a circular path around the wire — the field magnitude is constant on that path by symmetry, which is exactly why it simplifies to B(2πr) = μ₀I.',
  ],
  solenoid: [
    'A solenoid (a long coil of wire) produces a field just like a bar magnet: strong and uniform INSIDE, weaker and looping round from one end to the other OUTSIDE.',
    'Right-hand rule for a solenoid: curl the fingers of your right hand in the direction the current flows around the loops — your thumb points toward the NORTH pole.',
    'Field strength inside: B = μ₀nI, where n is the number of turns per metre (N/length) — more turns per metre, or more current, means a stronger field.',
    'This is the working principle of an electromagnet: unlike a permanent magnet, its strength (and even its polarity) can be controlled just by adjusting the current.',
    'Undergraduate note: B = μ₀nI is the IDEAL (infinitely long) solenoid result from Ampère\u2019s law; a real, finite solenoid has a somewhat weaker field near its ends — about half the central value right at the opening.',
  ],
  'motor-effect': [
    'A current-carrying conductor placed in an external magnetic field experiences a force — this is the MOTOR EFFECT, the basis of every electric motor and loudspeaker.',
    "Fleming's LEFT-hand rule (for force, distinct from the right-hand rules used for field direction): thu​Mb = Motion (force), First finger = Field, seCond finger = Current.",
    'Force magnitude: F = BIL sinθ, where θ is the angle between the current and the field — force is greatest (F=BIL) when the wire is perpendicular to the field, and zero when parallel to it.',
    'Reversing EITHER the current OR the field reverses the force direction; reversing BOTH leaves it unchanged.',
    'Undergraduate note: this is the magnetic part of the Lorentz force, F = qv×B, integrated over all the moving charges in the wire — for a straight wire this reduces exactly to F = IL×B, with the direction given by the vector cross product (equivalent to Fleming\u2019s rule).',
  ],
};

const EXERCISES: Record<Topic, { q: string; a: string }[]> = {
  'straight-wire': [
    { q: 'Find the magnetic field strength 5cm from a straight wire carrying 8A. (μ₀ = 4π×10⁻⁷ T·m/A)', a: 'B = μ₀I/2πr = (4π×10⁻⁷×8)/(2π×0.05) = (2×10⁻⁷×8)/0.05 = 3.2×10⁻⁵ T = 32 µT.' },
    { q: 'A compass is placed above a wire carrying current from south to north. If the current is reversed, what happens to the compass needle?', a: 'The needle swings to point in the opposite direction — reversing the current reverses the magnetic field direction at every point around the wire.' },
    { q: 'The distance from a wire is tripled. By what factor does the field strength change?', a: 'B ∝ 1/r, so tripling the distance reduces the field to one third of its original value.' },
  ],
  solenoid: [
    { q: 'A solenoid of length 0.4m has 800 turns and carries 3A. Find the field strength inside.', a: 'n = N/length = 800/0.4 = 2000 turns/m. B = μ₀nI = 4π×10⁻⁷×2000×3 ≈ 7.54×10⁻³ T = 7.54 mT.' },
    { q: 'How could you increase the strength of an electromagnet without changing the current?', a: 'Add more turns per metre (wind the coil more tightly or use more loops), or insert a soft-iron core, which greatly increases the field for the same current.' },
    { q: 'Why is soft iron (not steel) normally used as the core of an electromagnet?', a: 'Soft iron magnetises strongly when current flows but loses its magnetism almost immediately when the current stops — exactly the temporary, on/off magnetism an electromagnet needs. Steel would stay magnetised (retain the field) even after the current is switched off.' },
  ],
  'motor-effect': [
    { q: 'A wire of length 0.3m carries a current of 4A perpendicular to a magnetic field of 0.6T. Find the force on it.', a: 'F = BIL sinθ = 0.6×4×0.3×sin90° = 0.72 N.' },
    { q: 'A wire carries current parallel to a magnetic field. What force does it experience, and why?', a: 'Zero force — F = BIL sinθ, and sin(0°) = 0. A current parallel to the field has no component of current perpendicular to the field, so there is no motor-effect force.' },
    { q: 'In a simple DC motor, why does the coil keep spinning in the same direction instead of oscillating back and forth?', a: 'The commutator reverses the current in the coil every half-turn, which reverses the force direction on each side at exactly the right moment to keep the torque acting the same rotational way, sustaining continuous rotation instead of the coil settling into equilibrium.' },
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

export default function MagneticEffectsPage() {
  const [topic, setTopic] = useState<Topic>('straight-wire');
  const [isRunning, setIsRunning] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const [resetKey, setResetKey] = useState(0);
  const [openEx, setOpenEx] = useState<number | null>(null);
  const [activeCurricula, setActiveCurricula] = useState(['WAEC', 'IGCSE', 'SAT']);

  const [current, setCurrent] = useState(5);
  const [currentOut, setCurrentOut] = useState(true);
  const [testDistanceCm, setTestDistanceCm] = useState(4);

  const [turnsPerMetre, setTurnsPerMetre] = useState(1000);

  const [fieldB, setFieldB] = useState(0.5);
  const [wireLengthCm, setWireLengthCm] = useState(10);

  const [liveField, setLiveField] = useState(0);

  const reset = useCallback(() => { setIsRunning(false); setIsPaused(false); setResetKey(k => k + 1); }, []);
  const resetTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  useEffect(() => {
    if (resetTimer.current) clearTimeout(resetTimer.current);
    resetTimer.current = setTimeout(reset, 100);
  }, [topic, current, currentOut, turnsPerMetre, fieldB, reset]);

  const canvasBoxRef = useRef<HTMLDivElement>(null);
  const canvasSize = useResponsiveCanvasSize(canvasBoxRef, 660, 320, 980);

  const asMode: MagneticMode = topic;
  const testFieldStatic = fieldStraightWire(current, testDistanceCm / 100);
  const solenoidFieldStatic = fieldSolenoid(current, turnsPerMetre);
  const forceStatic = forceOnConductor(fieldB, current, wireLengthCm / 100, 90);

  return (
    <>
      <AppHeader />
      <main className="min-h-screen bg-gray-50">
        <section className="border-b border-gray-200 bg-white">
          <div className="mx-auto max-w-[100rem] px-4 sm:px-6 py-4">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
              <div>
                <p className="text-xs text-gray-400 mb-0.5">Electricity · Electromagnetism</p>
                <h1 className="text-lg font-semibold text-gray-900">Magnetic Effects of Current</h1>
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
                <MagneticFieldCanvas key={resetKey} mode={asMode} current={current} currentOut={currentOut}
                  turnsPerMetre={turnsPerMetre} fieldB={fieldB}
                  isRunning={isRunning} isPaused={isPaused} onTick={setLiveField}
                  width={canvasSize.width} height={canvasSize.height} />
              </div>

              <div className="flex flex-wrap items-center justify-between gap-2">
                <SimulationControls isRunning={isRunning} isPaused={isPaused}
                  onRun={() => { setIsRunning(true); setIsPaused(false); }}
                  onPause={() => setIsPaused(p => !p)} onReset={reset} />
                <EmbedButton path="/embed/magnetic-effects"
                  title={`${TOPIC_META[topic].title} — A-Factor STEM Studio`}
                  params={{ topic, current, out: currentOut ? 1 : 0, turns: turnsPerMetre, field: fieldB }} />
              </div>

              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm space-y-4">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide">Parameters</p>

                {topic === 'straight-wire' && <>
                  <Slider label="Current" unit="A" value={current} min={1} max={20} step={1} set={setCurrent} color="#6366f1" />
                  <div className="flex gap-2">
                    {([true, false] as const).map(v => (
                      <button key={String(v)} onClick={() => setCurrentOut(v)}
                        className={`flex-1 rounded-lg border px-2 py-2 text-xs font-medium transition ${
                          currentOut === v ? 'border-indigo-300 bg-indigo-50 text-indigo-700' : 'border-gray-200 bg-white text-gray-500'
                        }`}>{v ? 'Out of page ⊙' : 'Into page ⊗'}</button>
                    ))}
                  </div>
                  <Slider label="Test point distance" unit="cm" value={testDistanceCm} min={2} max={8} step={0.5} set={setTestDistanceCm} color="#f59e0b" />
                </>}

                {topic === 'solenoid' && <>
                  <Slider label="Current" unit="A" value={current} min={1} max={20} step={1} set={setCurrent} color="#6366f1" />
                  <div className="flex gap-2">
                    {([true, false] as const).map(v => (
                      <button key={String(v)} onClick={() => setCurrentOut(v)}
                        className={`flex-1 rounded-lg border px-2 py-2 text-xs font-medium transition ${
                          currentOut === v ? 'border-indigo-300 bg-indigo-50 text-indigo-700' : 'border-gray-200 bg-white text-gray-500'
                        }`}>{v ? 'Top: out ⊙' : 'Top: in ⊗'}</button>
                    ))}
                  </div>
                  <Slider label="Turns per metre" unit="n/m" value={turnsPerMetre} min={200} max={3000} step={100} set={setTurnsPerMetre} color="#f59e0b" />
                </>}

                {topic === 'motor-effect' && <>
                  <Slider label="Current" unit="A" value={current} min={1} max={20} step={1} set={setCurrent} color="#6366f1" />
                  <Slider label="Field strength B" unit="T" value={fieldB} min={0.1} max={2} step={0.1} set={setFieldB} color="#f59e0b" />
                  <Slider label="Wire length" unit="cm" value={wireLengthCm} min={5} max={30} step={1} set={setWireLengthCm} color="#8b5cf6" />
                  <div className="flex gap-2">
                    {([true, false] as const).map(v => (
                      <button key={String(v)} onClick={() => setCurrentOut(v)}
                        className={`flex-1 rounded-lg border px-2 py-2 text-xs font-medium transition ${
                          currentOut === v ? 'border-indigo-300 bg-indigo-50 text-indigo-700' : 'border-gray-200 bg-white text-gray-500'
                        }`}>{v ? 'Out of page ⊙' : 'Into page ⊗'}</button>
                    ))}
                  </div>
                </>}
              </div>
            </div>

            <div className="space-y-3">
              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide mb-3">Calculated</p>
                <div className="space-y-2">
                  {topic === 'straight-wire' && <>
                    <StatRow label="B at test point" value={(testFieldStatic * 1e6).toFixed(1)} unit="µT" color="text-indigo-600" />
                    <StatRow label="Live B (canvas)" value={(liveField * 1e6).toFixed(1)} unit="µT" color="text-emerald-600" />
                    <StatRow label="Field direction" value={currentOut ? 'counterclockwise' : 'clockwise'} unit="" color="text-amber-600" />
                  </>}
                  {topic === 'solenoid' && <>
                    <StatRow label="B inside (centre)" value={(solenoidFieldStatic * 1000).toFixed(2)} unit="mT" color="text-indigo-600" />
                    <StatRow label="N pole" value={currentOut ? 'right end' : 'left end'} unit="" color="text-red-600" />
                  </>}
                  {topic === 'motor-effect' && <>
                    <StatRow label="Force F = BIL" value={forceStatic.toFixed(3)} unit="N" color="text-indigo-600" />
                    <StatRow label="Direction" value={currentOut ? 'upward' : 'downward'} unit="" color="text-emerald-600" />
                    <StatRow label="Parallel-wires check" value={forcePerLengthParallelWires(current, current, 0.05).toFixed(4)} unit="N/m" color="text-purple-600" />
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
