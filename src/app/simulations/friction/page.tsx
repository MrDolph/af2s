'use client';
import { useState, useCallback, useEffect, useRef, useMemo } from 'react';
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, Label, ReferenceDot, ReferenceLine } from 'recharts';
import { AppHeader } from '@/components/layout/AppHeader';
import { SimulationControls } from '@/components/simulation/SimulationControls';
import { FrictionCanvas, FrictionMode } from '@/components/simulation/FrictionCanvas';
import { EmbedButton } from '@/components/ui/EmbedButton';
import { flatFriction, inclineFriction, frictionCurve } from '@/lib/physics/friction';

const CURRICULA = ['WAEC', 'NECO', 'IGCSE', 'SAT', 'JUPEB'];
const CC: Record<string, string> = {
  WAEC: 'bg-indigo-100 text-indigo-700', NECO: 'bg-pink-100 text-pink-700',
  IGCSE: 'bg-emerald-100 text-emerald-700', SAT: 'bg-orange-100 text-orange-700',
  JUPEB: 'bg-purple-100 text-purple-700',
};

const MODE_META: Record<FrictionMode, { title: string; icon: string; sub: string; eq: string }> = {
  flat:    { title: 'Flat surface', icon: '➡️', sub: 'Push a block along the ground', eq: 'f ≤ μsN,  f = μkN once sliding' },
  incline: { title: 'Inclined plane', icon: '⛰️', sub: 'A block on a slope',           eq: 'tanθr = μs' },
};

const TEACHER_NOTES: Record<FrictionMode, string[]> = {
  flat: [
    'Static friction is NOT fixed — it exactly matches the applied force, up to a maximum of μsN. Push harder within that limit and friction grows to match; nothing moves.',
    'Once the applied force exceeds μsN, the block breaks free and KINETIC friction takes over — μk is always a little LESS than μs, which is why things "jerk" into motion.',
    'Friction is independent of the contact area and (to a good approximation) of speed — but always proportional to the normal reaction N.',
    'N = mg only holds here because the surface is flat and the push is horizontal — on a slope, or with an angled push, N changes.',
    'Real applications: brake pads (want HIGH μ), ice skates and ball bearings (want LOW μ), why worn tyres skid more easily.',
  ],
  incline: [
    'The angle at which a block JUST starts to slide is the angle of repose θr, where tanθr = μs — a clean way to measure friction experimentally.',
    'On the slope, gravity splits into two components: mg sinθ (down the slope, drives sliding) and mg cosθ (into the slope, creates the normal reaction N).',
    'Below θr the block is static and friction exactly balances mg sinθ. Above it, friction is capped at μkN and the block accelerates: a = g(sinθ − μk cosθ).',
    'This is literally how a plumb-line/tilt-table experiment measures μs for sand, wood, or rubber in a school lab.',
    'A steeper slope always needs a HIGHER μ to prevent sliding — this is why steep roofs need rougher tiles.',
  ],
};

const EXERCISES: Record<FrictionMode, { q: string; a: string }[]> = {
  flat: [
    { q: 'A 10kg block has μs=0.4. What is the maximum static friction force before it starts to slide?', a: 'N=mg=10×9.81=98.1N. F_s,max=μsN=0.4×98.1=39.2N.' },
    { q: 'A 5kg box needs 20N to start moving and 15N to keep it moving at constant velocity. Find μs and μk.', a: 'N=5×9.81=49.05N. μs=20/49.05=0.41. μk=15/49.05=0.31.' },
    { q: 'A 2kg block slides with μk=0.25 under a 15N push. Find its acceleration.', a: 'f=μkN=0.25×2×9.81=4.9N. Net=15−4.9=10.1N. a=10.1/2=5.05 m/s².' },
  ],
  incline: [
    { q: 'A block just begins to slide on a slope at 22°. Find μs.', a: 'μs = tan22° ≈ 0.40.' },
    { q: 'A 4kg block sits on a 35° slope with μs=0.5. Does it slide? Show your working.', a: 'mg sinθ = 4×9.81×sin35° ≈ 22.5N. μs·mg cosθ = 0.5×4×9.81×cos35° ≈ 16.1N. Since 22.5N > 16.1N, YES it slides.' },
    { q: 'A block slides down a 40° slope with μk=0.2. Find its acceleration.', a: 'a = g(sinθ − μk cosθ) = 9.81(sin40° − 0.2cos40°) ≈ 9.81(0.643−0.153) ≈ 4.81 m/s².' },
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

function FrictionGraph({ mass, muS, muK, applied }: { mass: number; muS: number; muK: number; applied: number }) {
  const fMax = mass * 9.81 * muS * 2.2;
  const data = useMemo(() => frictionCurve(mass, muS, muK, fMax), [mass, muS, muK, fMax]);
  const r = flatFriction(mass, applied, muS, muK);
  const staticLimit = muS * mass * 9.81;
  return (
    <ResponsiveContainer width="100%" height={190}>
      <LineChart data={data} margin={{ top: 8, right: 16, left: 10, bottom: 28 }}>
        <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
        <XAxis dataKey="F" type="number" tick={{ fontSize: 10 }} domain={[0, fMax]}>
          <Label value="Applied force F (N)" position="insideBottom" offset={-16} style={{ fontSize: 10, fill: '#94a3b8' }} />
        </XAxis>
        <YAxis tick={{ fontSize: 10 }}>
          <Label value="Friction f (N)" angle={-90} position="insideLeft" offset={12} style={{ fontSize: 10, fill: '#94a3b8' }} />
        </YAxis>
        <Tooltip formatter={(v: unknown) => [Number(v).toFixed(2) + ' N', 'f']} labelFormatter={f => `F=${Number(f).toFixed(1)}N`} />
        <Line type="linear" dataKey="f" stroke="#6366f1" strokeWidth={2} dot={false} isAnimationActive={false} />
        <ReferenceLine x={staticLimit} stroke="#f59e0b" strokeDasharray="4 4"
          label={{ value: 'μsN', position: 'top', fontSize: 9, fill: '#d97706' }} />
        <ReferenceDot x={Math.min(applied, fMax)} y={r.friction} r={6} fill="#ef4444" stroke="#fff" strokeWidth={2} />
      </LineChart>
    </ResponsiveContainer>
  );
}

export default function FrictionPage() {
  const [mode, setMode] = useState<FrictionMode>('flat');
  const [isRunning, setIsRunning] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const [resetKey, setResetKey] = useState(0);
  const [openEx, setOpenEx] = useState<number | null>(null);
  const [activeCurricula, setActiveCurricula] = useState(['WAEC', 'IGCSE', 'SAT']);

  const [mass, setMass] = useState(5);
  const [applied, setApplied] = useState(15);
  const [angle, setAngle] = useState(20);
  const [muS, setMuS] = useState(0.4);
  const [muK, setMuK] = useState(0.3);

  const resetTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const reset = useCallback(() => { setIsRunning(false); setIsPaused(false); setResetKey(k => k + 1); }, []);
  useEffect(() => {
    if (resetTimer.current) clearTimeout(resetTimer.current);
    resetTimer.current = setTimeout(reset, 80);
  }, [mode, mass, applied, angle, muS, muK, reset]);

  const flat = flatFriction(mass, applied, muS, muK);
  const inc = inclineFriction(mass, angle, muS, muK);

  return (
    <>
      <AppHeader />
      <main className="min-h-screen bg-gray-50">
        <section className="border-b border-gray-200 bg-white">
          <div className="mx-auto max-w-7xl px-4 sm:px-6 py-4">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
              <div>
                <p className="text-xs text-gray-400 mb-0.5">Mechanics</p>
                <h1 className="text-lg font-semibold text-gray-900">Friction</h1>
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
            {(Object.keys(MODE_META) as FrictionMode[]).map(m => (
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
                <FrictionCanvas key={resetKey} mode={mode} mass={mass} applied={applied} angle={angle}
                  muS={muS} muK={muK} isRunning={isRunning} isPaused={isPaused} resetKey={resetKey}
                  width={640} height={300} />
              </div>

              <div className="flex flex-wrap items-center justify-between gap-2">
                <SimulationControls isRunning={isRunning} isPaused={isPaused}
                  onRun={() => { setIsRunning(true); setIsPaused(false); }}
                  onPause={() => setIsPaused(p => !p)} onReset={reset} />
                <EmbedButton path="/embed/friction"
                  title={`${MODE_META[mode].title} friction — A-Factor STEM Studio`}
                  params={{ mode, mass, applied, angle, muS, muK }} />
              </div>

              {mode === 'flat' && (
                <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                  <p className="text-xs font-medium text-gray-400 uppercase tracking-wide mb-2">Friction vs applied force</p>
                  <FrictionGraph mass={mass} muS={muS} muK={muK} applied={applied} />
                  <p className="text-[10px] text-gray-400 mt-2 text-center">
                    Friction RISES to match F (static), then plateaus at μkN once sliding
                  </p>
                </div>
              )}

              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm space-y-4">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide">Parameters</p>
                <Slider label="Mass" unit="kg" value={mass} min={1} max={20} step={0.5} set={setMass} color="#6366f1" />
                {mode === 'flat' && (
                  <Slider label="Applied force" unit="N" value={applied} min={0} max={80} step={1} set={setApplied} color="#f59e0b" />
                )}
                {mode === 'incline' && (
                  <Slider label="Incline angle" unit="°" value={angle} min={0} max={60} step={1} set={setAngle} color="#f59e0b" />
                )}
                <Slider label="Static μs" unit="" value={muS} min={0.05} max={1} step={0.01} set={v => setMuS(Math.max(v, muK))} color="#10b981" />
                <Slider label="Kinetic μk" unit="" value={muK} min={0.05} max={1} step={0.01} set={v => setMuK(Math.min(v, muS))} color="#8b5cf6" note="μk is kept ≤ μs, as it always is physically" />
              </div>
            </div>

            <div className="space-y-3">
              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide mb-3">Calculated</p>
                <div className="space-y-2">
                  {mode === 'flat' && <>
                    <StatRow label="Normal reaction N" value={flat.N.toFixed(1)} unit="N" color="text-indigo-600" />
                    <StatRow label="Max static friction" value={flat.staticMax.toFixed(1)} unit="N" color="text-emerald-600" />
                    <StatRow label="Current friction" value={flat.friction.toFixed(1)} unit="N" color="text-amber-600" />
                    <StatRow label="State" value={flat.moving ? 'sliding' : 'static'} unit="" color="text-rose-500" />
                    <StatRow label="Acceleration" value={flat.acceleration.toFixed(2)} unit="m/s²" color="text-purple-600" />
                  </>}
                  {mode === 'incline' && <>
                    <StatRow label="Normal reaction N" value={inc.N.toFixed(1)} unit="N" color="text-indigo-600" />
                    <StatRow label="mg sinθ" value={inc.gravityAlong.toFixed(1)} unit="N" color="text-emerald-600" />
                    <StatRow label="Max static friction" value={inc.staticMax.toFixed(1)} unit="N" color="text-amber-600" />
                    <StatRow label="Angle of repose" value={inc.reposeAngle.toFixed(1)} unit="°" color="text-rose-500" />
                    <StatRow label="State" value={inc.sliding ? 'sliding' : 'static'} unit="" color="text-purple-600" />
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
