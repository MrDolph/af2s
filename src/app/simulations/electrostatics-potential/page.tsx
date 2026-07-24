'use client';
import { useState, useCallback, useEffect, useRef } from 'react';
import { AppHeader } from '@/components/layout/AppHeader';
import { SimulationControls } from '@/components/simulation/SimulationControls';
import { PotentialCanvas } from '@/components/simulation/PotentialCanvas';
import { EquipotentialCanvas, EquipotentialConfig } from '@/components/simulation/EquipotentialCanvas';
import { CapacitorCanvas } from '@/components/simulation/CapacitorCanvas';
import { EmbedButton } from '@/components/ui/EmbedButton';
import { electricPotentialEnergy, parallelPlateCapacitance, capacitorCharge, capacitorEnergy } from '@/lib/physics/electrostatics';
import { useResponsiveCanvasSize } from '@/hooks/useResponsiveCanvasSize';

type Topic = 'potential' | 'equipotential' | 'capacitor';

const CURRICULA = ['WAEC', 'NECO', 'IGCSE', 'SAT', 'JUPEB'];
const CC: Record<string, string> = {
  WAEC: 'bg-indigo-100 text-indigo-700', NECO: 'bg-pink-100 text-pink-700',
  IGCSE: 'bg-emerald-100 text-emerald-700', SAT: 'bg-orange-100 text-orange-700',
  JUPEB: 'bg-purple-100 text-purple-700',
};

const TOPIC_META: Record<Topic, { title: string; icon: string; sub: string; eq: string }> = {
  potential:     { title: 'Potential & potential energy', icon: '🔺', sub: 'Work done moving charge', eq: 'V = kQ/r,  U = kQ₁Q₂/r' },
  equipotential: { title: 'Equipotential surfaces',        icon: '🗺️', sub: 'Field ⊥ equipotentials', eq: 'no work done moving along a surface' },
  capacitor:     { title: 'Capacitors',                    icon: '🔋', sub: 'Charging & discharging',  eq: 'Q = CV,  E = ½CV²' },
};

const TEACHER_NOTES: Record<Topic, string[]> = {
  potential: [
    'Electric potential V at a point is the potential energy per unit positive charge placed there: V = kQ/r for a point charge, defining V = 0 at infinity.',
    'Electric potential ENERGY U of a pair of charges is U = kQ₁Q₂/r — this is the energy of the SYSTEM, not of either charge alone.',
    'For unlike charges (attractive), U is NEGATIVE — the system loses potential energy as the charges get closer, and that lost PE becomes kinetic energy, exactly like a ball falling under gravity.',
    'For like charges (repulsive), U is POSITIVE — pushing them together stores energy, which is released as kinetic energy if they are let go and fly apart.',
    'Work done moving a charge q through a potential difference V is W = qV — this is the same principle used to define the volt (1V = 1 joule per coulomb) and underlies how batteries and circuits are analysed.',
  ],
  equipotential: [
    'An equipotential surface is a surface on which every point has the SAME electric potential — for a single point charge, these are concentric spheres (circles in a 2D cross-section) centred on the charge.',
    'NO work is done moving a charge along an equipotential surface, since W = qΔV and ΔV = 0 by definition on that surface.',
    'Electric field lines are always PERPENDICULAR to equipotential surfaces at every point they cross — this is a direct mathematical consequence of E being the (negative) gradient of V, not a coincidence.',
    'Equipotentials are closely spaced where the field is strong (near a charge) and widely spaced where the field is weak (far from a charge) — exactly mirroring how contour lines on a map are closer together on steep terrain.',
    'The surface of any charged CONDUCTOR is always an equipotential surface in electrostatic equilibrium — if it weren\u2019t, charge would keep flowing along the surface until it became one.',
  ],
  capacitor: [
    'A capacitor stores charge (and therefore energy) on two separated conductors — commonly two parallel plates. Charge Q on a capacitor is proportional to the voltage across it: Q = CV, where C is the capacitance (in farads).',
    'Parallel-plate capacitance: C = ε₀A/d, where A is the plate area and d is the separation — bigger plates or a smaller gap both increase capacitance.',
    'When charging through a resistor, the voltage does NOT rise instantly — it follows an exponential curve, reaching about 63% of the final voltage after one time constant τ = RC, and is considered "fully" charged after about 5τ.',
    'Energy stored in a charged capacitor: E = ½CV² = ½QV — this is genuinely stored energy, which is why a charged capacitor can still deliver a shock even after being disconnected from its charging source.',
    'Discharging follows the mirror-image exponential decay, falling to about 37% of its starting voltage after one time constant.',
  ],
};

const EXERCISES: Record<Topic, { q: string; a: string }[]> = {
  potential: [
    { q: 'Find the electric potential at a point 0.2m from a +4μC charge.', a: 'V = kQ/r = (8.99×10⁹ × 4×10⁻⁶) / 0.2 = 179,800 V.' },
    { q: 'Two point charges, +3μC and −5μC, are 0.15m apart. Find the potential energy of the system.', a: 'U = kQ₁Q₂/r = (8.99×10⁹ × 3×10⁻⁶ × −5×10⁻⁶) / 0.15 = −8.99N (negative, since the charges attract).' },
    { q: 'How much work is done moving a +2μC charge through a potential difference of 500V?', a: 'W = qV = 2×10⁻⁶ × 500 = 1×10⁻³ J = 1mJ.' },
  ],
  equipotential: [
    { q: 'Explain why no work is done moving a charge along an equipotential surface.', a: 'Work done is W = qΔV. Since every point on an equipotential surface has the same potential, ΔV = 0 between any two points on it, so W = 0 regardless of the path taken along the surface.' },
    { q: 'State the relationship between the direction of electric field lines and equipotential surfaces.', a: 'Electric field lines are always perpendicular to equipotential surfaces at every point.' },
    { q: 'Explain why the surface of a charged conductor must be an equipotential surface.', a: 'If two points on the surface had different potentials, the potential difference would drive charge to flow between them until the difference disappeared — so in electrostatic equilibrium (no charge flowing), every point on the surface must already be at the same potential.' },
  ],
  capacitor: [
    { q: 'A parallel-plate capacitor has plates of area 0.02m² separated by 0.5mm of air. Find its capacitance.', a: 'C = ε₀A/d = (8.85×10⁻¹² × 0.02) / 0.0005 = 3.54×10⁻¹⁰ F = 354pF.' },
    { q: 'A 100μF capacitor is charged to 12V. Find the charge stored and the energy stored.', a: 'Q = CV = 100×10⁻⁶ × 12 = 1.2×10⁻³ C = 1.2mC. Energy = ½CV² = 0.5 × 100×10⁻⁶ × 12² = 7.2×10⁻³ J = 7.2mJ.' },
    { q: 'A capacitor charges through a 2000Ω resistor with a time constant of 0.4s. Find its capacitance.', a: 'τ = RC, so C = τ/R = 0.4/2000 = 2×10⁻⁴ F = 200μF.' },
    { q: 'Explain why a capacitor never reaches its full charge in a finite time when charging through a resistor, even though it gets very close.', a: 'The charging voltage follows V(t) = V₀(1 − e^(−t/τ)), an exponential approach to V₀. Since e^(−t/τ) only reaches exactly zero as t → ∞, the capacitor mathematically only approaches full charge asymptotically — in practice it is considered fully charged after about 5 time constants, when it is over 99% charged.' },
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

export default function ElectrostaticsPotentialPage() {
  const [topic, setTopic] = useState<Topic>('potential');
  const [isRunning, setIsRunning] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const [resetKey, setResetKey] = useState(0);
  const [openEx, setOpenEx] = useState<number | null>(null);
  const [activeCurricula, setActiveCurricula] = useState(['WAEC', 'IGCSE', 'SAT']);

  const [q1nC, setQ1nC] = useState(20);
  const [q2nC, setQ2nC] = useState(-20);
  const [separationCm, setSeparationCm] = useState(10);
  const [liveEnergy, setLiveEnergy] = useState({ KE: 0, PE: 0, sep: 10 });

  const [equipConfig, setEquipConfig] = useState<EquipotentialConfig>('single-positive');

  const [voltageV, setVoltageV] = useState(9);
  const [resistanceOhm, setResistanceOhm] = useState(2000);
  const [capacitanceUf, setCapacitanceUf] = useState(100);
  const [dischargeKey, setDischargeKey] = useState(0);
  const [liveCapacitor, setLiveCapacitor] = useState({ v: 0, phase: 'charging' as 'charging' | 'discharging' });

  // Parallel-plate geometric calculator (independent of the RC animation sliders)
  const [plateAreaCm2, setPlateAreaCm2] = useState(200);
  const [plateSepMm, setPlateSepMm] = useState(1);

  const reset = useCallback(() => {
    setIsRunning(false); setIsPaused(false); setResetKey(k => k + 1); setDischargeKey(0);
  }, []);
  const resetTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  useEffect(() => {
    if (resetTimer.current) clearTimeout(resetTimer.current);
    resetTimer.current = setTimeout(reset, 100);
  }, [topic, q1nC, q2nC, separationCm, equipConfig, voltageV, resistanceOhm, capacitanceUf, reset]);

  const canvasBoxRef = useRef<HTMLDivElement>(null);
  const canvasSize = useResponsiveCanvasSize(canvasBoxRef, 660, 300, 980);

  const staticPE = electricPotentialEnergy(q1nC * 1e-9, q2nC * 1e-9, separationCm / 100);
  const plateCapacitanceF = parallelPlateCapacitance((plateAreaCm2 / 1e4), plateSepMm / 1000);

  return (
    <>
      <AppHeader />
      <main className="min-h-screen bg-gray-50">
        <section className="border-b border-gray-200 bg-white">
          <div className="mx-auto max-w-[100rem] px-4 sm:px-6 py-4">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
              <div>
                <p className="text-xs text-gray-400 mb-0.5">Electricity · Electrostatics</p>
                <h1 className="text-lg font-semibold text-gray-900">Potential, Equipotentials &amp; Capacitors</h1>
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
                {topic === 'potential' && (
                  <PotentialCanvas key={resetKey} q1nC={q1nC} q2nC={q2nC} initialSeparationCm={separationCm}
                    isRunning={isRunning} isPaused={isPaused}
                    onTick={(KE, PE, sep) => setLiveEnergy({ KE, PE, sep })}
                    width={canvasSize.width} height={canvasSize.height} />
                )}
                {topic === 'equipotential' && (
                  <EquipotentialCanvas configuration={equipConfig}
                    width={canvasSize.width} height={canvasSize.height} />
                )}
                {topic === 'capacitor' && (
                  <CapacitorCanvas key={resetKey} voltageV={voltageV} resistanceOhm={resistanceOhm} capacitanceUf={capacitanceUf}
                    isRunning={isRunning} isPaused={isPaused} dischargeKey={dischargeKey}
                    onTick={(v, ph) => setLiveCapacitor({ v, phase: ph })}
                    width={canvasSize.width} height={canvasSize.height} />
                )}
              </div>

              <div className="flex flex-wrap items-center justify-between gap-2">
                {topic !== 'equipotential' ? (
                  <SimulationControls isRunning={isRunning} isPaused={isPaused}
                    onRun={() => { setIsRunning(true); setIsPaused(false); }}
                    onPause={() => setIsPaused(p => !p)} onReset={reset} />
                ) : <span />}
                {topic === 'capacitor' && isRunning && liveCapacitor.phase === 'charging' && (
                  <button onClick={() => setDischargeKey(k => k + 1)}
                    className="rounded-lg border border-gray-200 bg-white px-4 py-2 text-sm font-medium text-gray-600 transition hover:bg-gray-50">
                    Discharge
                  </button>
                )}
                <EmbedButton path="/embed/electrostatics-potential"
                  title={`${TOPIC_META[topic].title} — A-Factor STEM Studio`}
                  params={
                    topic === 'potential' ? { topic, q1: q1nC, q2: q2nC, sep: separationCm }
                    : topic === 'equipotential' ? { topic, config: equipConfig }
                    : { topic, v: voltageV, r: resistanceOhm, c: capacitanceUf }
                  } />
              </div>

              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm space-y-4">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide">Parameters</p>

                {topic === 'potential' && <>
                  <Slider label="Charge Q₁" unit="nC" value={q1nC} min={-50} max={50} step={5} set={setQ1nC} color="#dc2626" />
                  <Slider label="Charge Q₂" unit="nC" value={q2nC} min={-50} max={50} step={5} set={setQ2nC} color="#2563eb" />
                  <Slider label="Initial separation" unit="cm" value={separationCm} min={5} max={25} step={1} set={setSeparationCm} color="#6366f1" />
                </>}

                {topic === 'equipotential' && (
                  <div className="grid grid-cols-2 gap-2">
                    {([
                      ['single-positive', 'Single +'], ['single-negative', 'Single −'],
                      ['dipole', 'Dipole (+/−)'], ['like-charges', 'Like charges (+/+)'],
                    ] as [EquipotentialConfig, string][]).map(([cfg, label]) => (
                      <button key={cfg} onClick={() => setEquipConfig(cfg)}
                        className={`rounded-lg border px-2 py-2 text-xs font-medium transition ${
                          equipConfig === cfg ? 'border-indigo-300 bg-indigo-50 text-indigo-700' : 'border-gray-200 bg-white text-gray-500'
                        }`}>{label}</button>
                    ))}
                  </div>
                )}

                {topic === 'capacitor' && <>
                  <Slider label="Supply voltage" unit="V" value={voltageV} min={1} max={20} step={1} set={setVoltageV} color="#6366f1" />
                  <Slider label="Resistance" unit="Ω" value={resistanceOhm} min={500} max={5000} step={100} set={setResistanceOhm} color="#f59e0b" />
                  <Slider label="Capacitance" unit="µF" value={capacitanceUf} min={50} max={500} step={10} set={setCapacitanceUf} color="#8b5cf6"
                    note="τ = RC — larger R or C makes charging slower" />
                  <div className="pt-2 border-t border-gray-100 space-y-3">
                    <p className="text-[10px] font-medium uppercase tracking-wide text-gray-400">Parallel-plate calculator</p>
                    <Slider label="Plate area" unit="cm²" value={plateAreaCm2} min={20} max={500} step={10} set={setPlateAreaCm2} color="#10b981" />
                    <Slider label="Plate separation" unit="mm" value={plateSepMm} min={0.2} max={5} step={0.1} set={setPlateSepMm} color="#10b981" />
                  </div>
                </>}
              </div>
            </div>

            <div className="space-y-3">
              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide mb-3">Calculated</p>
                <div className="space-y-2">
                  {topic === 'potential' && <>
                    <StatRow label="Initial PE" value={(staticPE * 1e6).toFixed(2)} unit="µJ" color="text-indigo-600" />
                    <StatRow label="Live KE" value={(liveEnergy.KE * 1e6).toFixed(2)} unit="µJ" color="text-amber-600" />
                    <StatRow label="Live PE" value={(liveEnergy.PE * 1e6).toFixed(2)} unit="µJ" color="text-emerald-600" />
                    <StatRow label="Live separation" value={liveEnergy.sep.toFixed(1)} unit="cm" color="text-purple-600" />
                  </>}
                  {topic === 'equipotential' && <>
                    <StatRow label="Configuration" value={equipConfig.replace('-', ' ')} unit="" color="text-indigo-600" />
                    <StatRow label="Field vs equipotential" value="always perpendicular" unit="" color="text-emerald-600" />
                  </>}
                  {topic === 'capacitor' && <>
                    <StatRow label="Time constant τ=RC" value={(resistanceOhm * capacitanceUf * 1e-6).toFixed(3)} unit="s" color="text-indigo-600" />
                    <StatRow label="Live voltage" value={liveCapacitor.v.toFixed(2)} unit="V" color="text-amber-600" />
                    <StatRow label="Live charge Q=CV" value={(capacitorCharge(capacitanceUf * 1e-6, liveCapacitor.v) * 1e6).toFixed(2)} unit="µC" color="text-emerald-600" />
                    <StatRow label="Live energy" value={(capacitorEnergy(capacitanceUf * 1e-6, liveCapacitor.v) * 1e6).toFixed(2)} unit="µJ" color="text-purple-600" />
                    <StatRow label="Parallel-plate C" value={(plateCapacitanceF * 1e12).toFixed(1)} unit="pF" color="text-rose-500" />
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
