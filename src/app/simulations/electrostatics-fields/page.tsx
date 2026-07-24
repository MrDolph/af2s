'use client';
import { useState, useCallback, useEffect, useRef } from 'react';
import { AppHeader } from '@/components/layout/AppHeader';
import { SimulationControls } from '@/components/simulation/SimulationControls';
import { CoulombsLawCanvas } from '@/components/simulation/CoulombsLawCanvas';
import { ElectricFieldCanvas, FieldConfiguration } from '@/components/simulation/ElectricFieldCanvas';
import { EmbedButton } from '@/components/ui/EmbedButton';
import { coulombForceSigned } from '@/lib/physics/electrostatics';
import { useResponsiveCanvasSize } from '@/hooks/useResponsiveCanvasSize';

type Topic = 'coulomb' | 'field';

const CURRICULA = ['WAEC', 'NECO', 'IGCSE', 'SAT', 'JUPEB'];
const CC: Record<string, string> = {
  WAEC: 'bg-indigo-100 text-indigo-700', NECO: 'bg-pink-100 text-pink-700',
  IGCSE: 'bg-emerald-100 text-emerald-700', SAT: 'bg-orange-100 text-orange-700',
  JUPEB: 'bg-purple-100 text-purple-700',
};

const TOPIC_META: Record<Topic, { title: string; icon: string; sub: string; eq: string }> = {
  coulomb: { title: "Coulomb's law", icon: '🧲', sub: 'Force between two point charges', eq: 'F = kQ₁Q₂/r²' },
  field:   { title: 'Electric field', icon: '🌐', sub: 'Field lines & field strength',     eq: 'E = kQ/r² = F/q' },
};

const TEACHER_NOTES: Record<Topic, string[]> = {
  coulomb: [
    "Coulomb's law: F = kQ₁Q₂/r², where k ≈ 8.99×10⁹ N·m²/C² (often written 1/4πε₀).",
    'Like charges REPEL (positive force by the sign convention here), unlike charges ATTRACT — the direction follows automatically from the signs of Q₁ and Q₂ in the formula.',
    'The force obeys an INVERSE-SQUARE law: doubling the separation cuts the force to a quarter, not a half — a very commonly tested numeric trap.',
    "Coulomb's law has the same mathematical FORM as Newton's law of gravitation (F=Gm₁m₂/r²) — both are inverse-square laws — but electric forces can be attractive OR repulsive, while gravity is always attractive.",
    'The released charges shown here accelerate because force causes acceleration (F=ma) — as they separate, the force (and so the acceleration) drops rapidly, which is why the motion visibly slows down even though the charges keep moving apart.',
  ],
  field: [
    'Electric field strength E at a point is the force per unit positive charge placed there: E = F/q. It is a vector — it has both magnitude and direction.',
    'For a point charge, E = kQ/r² — the same inverse-square dependence as Coulomb\u2019s law, since E is just the force ONE unit of charge would feel.',
    'Field line rules: they point in the direction a small POSITIVE test charge would move; they start on positive charges (or infinity) and end on negative charges (or infinity); they never cross; closer lines mean a stronger field.',
    'Around a single charge, field lines are straight and radial — outward from a positive charge, inward toward a negative one.',
    'Between two EQUAL like charges, there is a NULL POINT exactly at the midpoint where the two fields cancel exactly to zero — a test charge placed there feels no net force at all.',
  ],
};

const EXERCISES: Record<Topic, { q: string; a: string }[]> = {
  coulomb: [
    { q: 'Two point charges of +3μC and +5μC are 0.2m apart. Find the force between them.', a: 'F = kQ₁Q₂/r² = (8.99×10⁹ × 3×10⁻⁶ × 5×10⁻⁶) / (0.2)² = 134.9/0.04 = 3.37N (repulsive, since both charges are positive).' },
    { q: 'The distance between two charges is tripled. By what factor does the force between them change?', a: 'F ∝ 1/r², so tripling r reduces F by a factor of 1/3² = 1/9 — the new force is one-ninth of the original.' },
    { q: 'A +2μC charge and a −4μC charge are 0.1m apart. Find the magnitude and nature of the force between them.', a: 'F = kQ₁Q₂/r² = (8.99×10⁹ × 2×10⁻⁶ × 4×10⁻⁶) / (0.1)² = 71.9/0.01 = 7.19N. Since the charges have opposite signs, the force is attractive.' },
  ],
  field: [
    { q: 'Find the electric field strength at a point 0.3m from a +6μC charge.', a: 'E = kQ/r² = (8.99×10⁹ × 6×10⁻⁶) / (0.3)² = 53940/0.09 = 599,333 N/C (directed away from the charge, since it is positive).' },
    { q: 'A charge of +2μC placed at a point experiences a force of 0.5N. Find the electric field strength at that point.', a: 'E = F/q = 0.5 / (2×10⁻⁶) = 250,000 N/C.' },
    { q: 'Explain why field lines can never cross one another.', a: 'The field at any point has one definite direction. If two field lines crossed, the field at that crossing point would have two different directions at once, which is impossible — so field lines never cross.' },
    { q: 'Two equal positive point charges sit 10cm apart. Describe the field at the point exactly midway between them.', a: 'The field is zero at that midpoint — a null point. Each charge pushes a test charge there with equal magnitude but exactly opposite direction (both charges repel a positive test charge away from themselves, i.e. toward the other charge and away from itself simultaneously), so the two contributions cancel exactly.' },
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

export default function ElectrostaticsFieldsPage() {
  const [topic, setTopic] = useState<Topic>('coulomb');
  const [isRunning, setIsRunning] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const [resetKey, setResetKey] = useState(0);
  const [openEx, setOpenEx] = useState<number | null>(null);
  const [activeCurricula, setActiveCurricula] = useState(['WAEC', 'IGCSE', 'SAT']);

  const [q1nC, setQ1nC] = useState(20);
  const [q2nC, setQ2nC] = useState(20);
  const [separationCm, setSeparationCm] = useState(10);
  const [liveCoulomb, setLiveCoulomb] = useState({ sep: 10, force: 0 });

  const [fieldConfig, setFieldConfig] = useState<FieldConfiguration>('single-positive');
  const [testX, setTestX] = useState(0.75);
  const [testY, setTestY] = useState(0.3);
  const [liveField, setLiveField] = useState(0);

  const reset = useCallback(() => { setIsRunning(false); setIsPaused(false); setResetKey(k => k + 1); }, []);
  const resetTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  useEffect(() => {
    if (resetTimer.current) clearTimeout(resetTimer.current);
    resetTimer.current = setTimeout(reset, 100);
  }, [topic, q1nC, q2nC, separationCm, fieldConfig, reset]);

  const canvasBoxRef = useRef<HTMLDivElement>(null);
  const canvasSize = useResponsiveCanvasSize(canvasBoxRef, 660, 300, 980);

  const staticForceN = coulombForceSigned(q1nC * 1e-9, q2nC * 1e-9, separationCm / 100);

  return (
    <>
      <AppHeader />
      <main className="min-h-screen bg-gray-50">
        <section className="border-b border-gray-200 bg-white">
          <div className="mx-auto max-w-[100rem] px-4 sm:px-6 py-4">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
              <div>
                <p className="text-xs text-gray-400 mb-0.5">Electricity · Electrostatics</p>
                <h1 className="text-lg font-semibold text-gray-900">Coulomb&apos;s Law &amp; Electric Fields</h1>
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
                {topic === 'coulomb' && (
                  <CoulombsLawCanvas key={resetKey} q1nC={q1nC} q2nC={q2nC} initialSeparationCm={separationCm}
                    isRunning={isRunning} isPaused={isPaused} onTick={(sep, force) => setLiveCoulomb({ sep, force })}
                    width={canvasSize.width} height={canvasSize.height} />
                )}
                {topic === 'field' && (
                  <ElectricFieldCanvas key={resetKey} configuration={fieldConfig} testX={testX} testY={testY}
                    isRunning={isRunning} isPaused={isPaused} onTick={setLiveField}
                    width={canvasSize.width} height={canvasSize.height} />
                )}
              </div>

              <div className="flex flex-wrap items-center justify-between gap-2">
                <SimulationControls isRunning={isRunning} isPaused={isPaused}
                  onRun={() => { setIsRunning(true); setIsPaused(false); }}
                  onPause={() => setIsPaused(p => !p)} onReset={reset} />
                <EmbedButton path="/embed/electrostatics-fields"
                  title={`${TOPIC_META[topic].title} — A-Factor STEM Studio`}
                  params={
                    topic === 'coulomb' ? { topic, q1: q1nC, q2: q2nC, sep: separationCm }
                    : { topic, config: fieldConfig }
                  } />
              </div>

              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm space-y-4">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide">Parameters</p>

                {topic === 'coulomb' && <>
                  <Slider label="Charge Q₁" unit="nC" value={q1nC} min={-50} max={50} step={5} set={setQ1nC} color="#dc2626" note="Negative = negative charge" />
                  <Slider label="Charge Q₂" unit="nC" value={q2nC} min={-50} max={50} step={5} set={setQ2nC} color="#2563eb" />
                  <Slider label="Initial separation" unit="cm" value={separationCm} min={5} max={30} step={1} set={setSeparationCm} color="#6366f1"
                    note="Press Run to release the charges and watch them respond to the force" />
                </>}

                {topic === 'field' && <>
                  <div className="grid grid-cols-2 gap-2">
                    {([
                      ['single-positive', 'Single +'], ['single-negative', 'Single −'],
                      ['dipole', 'Dipole (+/−)'], ['like-charges', 'Like charges (+/+)'],
                    ] as [FieldConfiguration, string][]).map(([cfg, label]) => (
                      <button key={cfg} onClick={() => setFieldConfig(cfg)}
                        className={`rounded-lg border px-2 py-2 text-xs font-medium transition ${
                          fieldConfig === cfg ? 'border-indigo-300 bg-indigo-50 text-indigo-700' : 'border-gray-200 bg-white text-gray-500'
                        }`}>{label}</button>
                    ))}
                  </div>
                  <Slider label="Test point — horizontal" unit="" value={testX} min={0.05} max={0.95} step={0.01} set={setTestX} color="#f59e0b" />
                  <Slider label="Test point — vertical" unit="" value={testY} min={0.1} max={0.9} step={0.01} set={setTestY} color="#f59e0b"
                    note="Drag to explore the field strength and direction at different points" />
                </>}
              </div>
            </div>

            <div className="space-y-3">
              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide mb-3">Calculated</p>
                <div className="space-y-2">
                  {topic === 'coulomb' && <>
                    <StatRow label="Force (at slider r)" value={Math.abs(staticForceN) < 1e-3 ? (Math.abs(staticForceN) * 1e6).toFixed(2) : (Math.abs(staticForceN) * 1e3).toFixed(3)} unit={Math.abs(staticForceN) < 1e-3 ? 'µN' : 'mN'} color="text-indigo-600" />
                    <StatRow label="Nature" value={staticForceN > 0 ? 'repulsive' : staticForceN < 0 ? 'attractive' : 'none'} unit="" color={staticForceN > 0 ? 'text-amber-600' : 'text-emerald-600'} />
                    <StatRow label="Live separation" value={liveCoulomb.sep.toFixed(1)} unit="cm" color="text-purple-600" />
                    <StatRow label="Live force" value={Math.abs(liveCoulomb.force) < 1e-3 ? (Math.abs(liveCoulomb.force) * 1e6).toFixed(2) : (Math.abs(liveCoulomb.force) * 1e3).toFixed(3)} unit={Math.abs(liveCoulomb.force) < 1e-3 ? 'µN' : 'mN'} color="text-rose-500" />
                  </>}
                  {topic === 'field' && <>
                    <StatRow label="Configuration" value={fieldConfig.replace('-', ' ')} unit="" color="text-indigo-600" />
                    <StatRow label="Relative field at test point" value={liveField.toFixed(4)} unit="" color="text-amber-600" />
                    <StatRow label="Field direction" value="shown by the amber arrow" unit="" color="text-emerald-600" />
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
