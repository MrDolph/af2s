'use client';
import { useState, useMemo } from 'react';
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, Label, ReferenceDot, ReferenceLine } from 'recharts';
import { AppHeader } from '@/components/layout/AppHeader';
import { ElasticityCanvas, ElasticityMode } from '@/components/simulation/ElasticityCanvas';
import { EmbedButton } from '@/components/ui/EmbedButton';
import { extension, springEnergy, forceExtensionCurve, wireExtension, stress, strain, youngModulus, WIRE_MATERIALS } from '@/lib/physics/elasticity';

const CURRICULA = ['WAEC', 'NECO', 'IGCSE', 'SAT', 'JUPEB'];
const CC: Record<string, string> = {
  WAEC: 'bg-indigo-100 text-indigo-700', NECO: 'bg-pink-100 text-pink-700',
  IGCSE: 'bg-emerald-100 text-emerald-700', SAT: 'bg-orange-100 text-orange-700',
  JUPEB: 'bg-purple-100 text-purple-700',
};

const MODE_META: Record<ElasticityMode, { title: string; icon: string; sub: string; eq: string }> = {
  hooke: { title: "Hooke's law", icon: '🌀', sub: 'A loaded spring',       eq: 'F = ke' },
  wire:  { title: 'Young modulus', icon: '🧵', sub: 'Stretching a wire', eq: 'E = σ/ε = FL/(Ae)' },
};

const TEACHER_NOTES: Record<ElasticityMode, string[]> = {
  hooke: [
    "Hooke's law: extension is directly proportional to the applied force, e ∝ F, i.e. F = ke — but only up to the ELASTIC LIMIT.",
    'Beyond the elastic limit the spring deforms PERMANENTLY: it will not return to its natural length when the load is removed, and F = ke no longer applies.',
    'The spring constant k (N/m) measures stiffness: a bigger k means a stiffer spring that stretches less for the same force.',
    'Energy stored in a stretched (or compressed) spring: E = ½Fe = ½ke² — the area under a force–extension graph, used in catapults, archery bows, and pogo sticks.',
    'Springs in series share the load but each stretches independently (softer overall); springs in parallel share the extension (stiffer overall) — a nice follow-up demonstration.',
  ],
  wire: [
    'Stress σ = F/A (force per unit cross-sectional area) and strain ε = e/L (extension per unit original length) — both are needed because a thick wire stretches less than a thin one under the same force.',
    "Young's modulus E = σ/ε is a property of the MATERIAL only — steel always has the same E, whatever the wire's length or thickness.",
    'Real wire extensions under normal loads are tiny (often fractions of a millimetre) — this simulation magnifies the extension so you can see it; the true value is always shown in the info card.',
    'A stress–strain graph for a ductile material (like copper) shows a straight (Hookean) region, then plastic deformation, then a breaking point — steel and glass behave very differently here.',
    'Practical use: engineers select materials by their E value — steel cables for bridges need high E (stiff, minimal sag) while rubber seals need low E (flexible).',
  ],
};

const EXERCISES: Record<ElasticityMode, { q: string; a: string }[]> = {
  hooke: [
    { q: 'A spring stretches 4cm under a 20N load. Find its spring constant k.', a: 'k = F/e = 20/0.04 = 500 N/m.' },
    { q: 'A spring of k=250 N/m is stretched by 6cm. Find the elastic energy stored.', a: 'E = ½ke² = ½×250×0.06² = 0.45 J.' },
    { q: 'A spring obeys Hooke\'s law up to 30N, extending 10cm at that load. What extension would 45N (beyond the limit) roughly NOT follow, and why?', a: 'It would NOT simply extend to 15cm proportionally — beyond the elastic limit the material deforms plastically and extension grows faster than F for a given increase in load, and the deformation becomes permanent.' },
  ],
  wire: [
    { q: 'A steel wire (E=200 GPa) of length 2m and cross-sectional area 1×10⁻⁶ m² carries a 100N load. Find its extension.', a: 'e = FL/(AE) = (100×2)/(1e-6×200e9) = 200/200000 = 1×10⁻³ m = 1mm.' },
    { q: 'A wire of diameter 0.5mm stretches 0.8mm under a 50N load over 1.5m. Find the stress and strain.', a: 'A=π(0.00025)²≈1.96×10⁻⁷m². σ=F/A=50/1.96e-7≈2.55×10⁸ Pa. ε=e/L=0.0008/1.5≈5.33×10⁻⁴.' },
    { q: 'Using the previous answer, find the Young\'s modulus.', a: 'E=σ/ε=2.55×10⁸/5.33×10⁻⁴≈4.78×10¹¹ Pa ≈ 478 GPa.' },
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

function ForceExtensionGraph({ k, elasticLimitF, load }: { k: number; elasticLimitF: number; load: number }) {
  const fMax = elasticLimitF * 2.2;
  const data = useMemo(() => forceExtensionCurve(k, elasticLimitF, fMax), [k, elasticLimitF, fMax]);
  const e = extension(Math.min(load, elasticLimitF), k) * 100;
  const eLimitCm = (elasticLimitF / k) * 100;
  return (
    <ResponsiveContainer width="100%" height={190}>
      <LineChart data={data} margin={{ top: 8, right: 16, left: 10, bottom: 28 }}>
        <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
        <XAxis dataKey="e" type="number" tick={{ fontSize: 10 }}>
          <Label value="Extension e (cm)" position="insideBottom" offset={-16} style={{ fontSize: 10, fill: '#94a3b8' }} />
        </XAxis>
        <YAxis dataKey="F" tick={{ fontSize: 10 }}>
          <Label value="Force F (N)" angle={-90} position="insideLeft" offset={12} style={{ fontSize: 10, fill: '#94a3b8' }} />
        </YAxis>
        <Tooltip formatter={(v: unknown) => [Number(v).toFixed(2) + ' N', 'F']} labelFormatter={e => `e=${Number(e).toFixed(2)}cm`} />
        <Line type="linear" dataKey="F" stroke="#6366f1" strokeWidth={2} dot={false} isAnimationActive={false} />
        <ReferenceLine x={eLimitCm} stroke="#f59e0b" strokeDasharray="4 4"
          label={{ value: 'elastic limit', position: 'top', fontSize: 9, fill: '#d97706' }} />
        <ReferenceDot x={e} y={Math.min(load, elasticLimitF)} r={6} fill="#ef4444" stroke="#fff" strokeWidth={2} />
      </LineChart>
    </ResponsiveContainer>
  );
}

export default function ElasticityPage() {
  const [mode, setMode] = useState<ElasticityMode>('hooke');
  const [openEx, setOpenEx] = useState<number | null>(null);
  const [activeCurricula, setActiveCurricula] = useState(['WAEC', 'IGCSE', 'SAT']);

  const [load, setLoad] = useState(8);
  const [k, setK] = useState(200);
  const [elasticLimitF, setElasticLimitF] = useState(15);

  const [wireLength, setWireLength] = useState(2);
  const [wireDiamMm, setWireDiamMm] = useState(0.5);
  const [matIdx, setMatIdx] = useState(0);
  const [wireLoad, setWireLoad] = useState(60);
  const material = WIRE_MATERIALS[matIdx];

  const A = Math.PI * Math.pow((wireDiamMm / 1000) / 2, 2);
  const e = wireExtension(wireLoad, wireLength, A, material.E);

  return (
    <>
      <AppHeader />
      <main className="min-h-screen bg-gray-50">
        <section className="border-b border-gray-200 bg-white">
          <div className="mx-auto max-w-7xl px-4 sm:px-6 py-4">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
              <div>
                <p className="text-xs text-gray-400 mb-0.5">Mechanics</p>
                <h1 className="text-lg font-semibold text-gray-900">Elasticity</h1>
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
          <div className="flex gap-1 bg-gray-100 p-1 rounded-xl overflow-x-auto">
            {(Object.keys(MODE_META) as ElasticityMode[]).map(m => (
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
              <div className="rounded-2xl border border-gray-200 bg-white p-3 shadow-sm">
                <ElasticityCanvas mode={mode}
                  load={mode === 'hooke' ? load : wireLoad} k={k} elasticLimitF={elasticLimitF}
                  wireLength={wireLength} wireDiamMm={wireDiamMm} youngE={material.E} materialName={material.name}
                  width={640} height={320} />
              </div>

              <div className="flex justify-end">
                <EmbedButton path="/embed/elasticity"
                  title={`${MODE_META[mode].title} — A-Factor STEM Studio`}
                  params={mode === 'hooke' ? { mode, load, k, limit: elasticLimitF } : { mode, mat: matIdx, L: wireLength, d: wireDiamMm, F: wireLoad }} />
              </div>

              {mode === 'hooke' && (
                <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                  <p className="text-xs font-medium text-gray-400 uppercase tracking-wide mb-2">Force–extension graph</p>
                  <ForceExtensionGraph k={k} elasticLimitF={elasticLimitF} load={load} />
                  <p className="text-[10px] text-gray-400 mt-2 text-center">
                    Linear (Hooke) region, then plastic deformation beyond the elastic limit
                  </p>
                </div>
              )}

              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm space-y-4">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide">Parameters</p>
                {mode === 'hooke' && <>
                  <Slider label="Load F" unit="N" value={load} min={0} max={30} step={0.5} set={setLoad} color="#6366f1" />
                  <Slider label="Spring constant k" unit="N/m" value={k} min={50} max={500} step={10} set={setK} color="#f59e0b" />
                  <Slider label="Elastic limit" unit="N" value={elasticLimitF} min={5} max={25} step={1} set={setElasticLimitF} color="#ef4444" />
                </>}
                {mode === 'wire' && <>
                  <div className="flex flex-wrap gap-1.5">
                    {WIRE_MATERIALS.map((m, i) => (
                      <button key={m.name} onClick={() => setMatIdx(i)}
                        className={`rounded-full border px-2.5 py-1 text-[11px] font-medium transition ${
                          matIdx === i ? 'border-indigo-300 bg-indigo-50 text-indigo-700' : 'border-gray-200 bg-white text-gray-500 hover:border-indigo-200'
                        }`}>{m.name}</button>
                    ))}
                  </div>
                  <Slider label="Load F" unit="N" value={wireLoad} min={5} max={200} step={5} set={setWireLoad} color="#6366f1" />
                  <Slider label="Wire length L" unit="m" value={wireLength} min={0.5} max={5} step={0.1} set={setWireLength} color="#10b981" />
                  <Slider label="Wire diameter" unit="mm" value={wireDiamMm} min={0.1} max={2} step={0.05} set={setWireDiamMm} color="#8b5cf6" />
                </>}
              </div>
            </div>

            <div className="space-y-3">
              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide mb-3">Calculated</p>
                <div className="space-y-2">
                  {mode === 'hooke' && <>
                    <StatRow label="Extension e" value={(extension(Math.min(load, elasticLimitF), k) * 100).toFixed(2)} unit="cm" color="text-indigo-600" />
                    <StatRow label="Energy stored" value={springEnergy(k, extension(Math.min(load, elasticLimitF), k)).toFixed(3)} unit="J" color="text-emerald-600" />
                    <StatRow label="Within limit?" value={load <= elasticLimitF ? 'yes' : 'NO — plastic'} unit="" color="text-amber-600" />
                  </>}
                  {mode === 'wire' && <>
                    <StatRow label="Cross-section A" value={(A * 1e6).toFixed(4)} unit="mm²" color="text-indigo-600" />
                    <StatRow label="Stress σ" value={(stress(wireLoad, A) / 1e6).toFixed(1)} unit="MPa" color="text-emerald-600" />
                    <StatRow label="Strain ε" value={strain(e, wireLength).toExponential(2)} unit="" color="text-amber-600" />
                    <StatRow label="Extension e" value={(e * 1000).toFixed(3)} unit="mm" color="text-rose-500" />
                    <StatRow label="Young modulus" value={(youngModulus(wireLoad, A, e, wireLength) / 1e9).toFixed(0)} unit="GPa" color="text-purple-600" />
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
