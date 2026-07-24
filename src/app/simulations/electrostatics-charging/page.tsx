'use client';
import { useState, useCallback, useEffect, useRef } from 'react';
import { AppHeader } from '@/components/layout/AppHeader';
import { SimulationControls } from '@/components/simulation/SimulationControls';
import { ChargingMethodsCanvas, ChargingMethod } from '@/components/simulation/ChargingMethodsCanvas';
import { ElectroscopeCanvas, ElectroscopeMode } from '@/components/simulation/ElectroscopeCanvas';
import { ElectrophorusCanvas } from '@/components/simulation/ElectrophorusCanvas';
import { EmbedButton } from '@/components/ui/EmbedButton';
import { useResponsiveCanvasSize } from '@/hooks/useResponsiveCanvasSize';

type Topic = 'production' | 'electroscope' | 'electrophorus';

const CURRICULA = ['WAEC', 'NECO', 'IGCSE', 'SAT', 'JUPEB'];
const CC: Record<string, string> = {
  WAEC: 'bg-indigo-100 text-indigo-700', NECO: 'bg-pink-100 text-pink-700',
  IGCSE: 'bg-emerald-100 text-emerald-700', SAT: 'bg-orange-100 text-orange-700',
  JUPEB: 'bg-purple-100 text-purple-700',
};

const TOPIC_META: Record<Topic, { title: string; icon: string; sub: string; eq: string }> = {
  production:    { title: 'Production of charges', icon: '⚡', sub: 'Friction, conduction, induction', eq: 'like charges repel, unlike attract' },
  electroscope:  { title: 'Gold-leaf electroscope', icon: '🍂', sub: 'Detecting & testing charge',      eq: 'divergence ∝ charge' },
  electrophorus: { title: 'Electrophorus',          icon: '🔌', sub: 'Repeatable charging by induction', eq: 'induced charge is opposite the slab' },
};

const TEACHER_NOTES: Record<Topic, string[]> = {
  production: [
    'Charging by FRICTION: rubbing two different insulators transfers electrons from one to the other. Whichever material holds electrons less strongly ends up positive; the other ends up negative — equal and opposite charges.',
    'Charging by CONDUCTION (contact): touching a charged object to a neutral conductor lets charge (the same sign) spread onto it. The originally-charged object loses some of its charge in the process.',
    'Charging by INDUCTION: bringing a charged object NEAR (not touching) a conductor separates its charges — no contact, no net charge change yet. Earthing the conductor while the inducing charge is still present lets the repelled charge escape, leaving a net charge OPPOSITE to the inducing object once the earth connection and the object are both removed (in that order).',
    'A key exam distinction: conduction leaves the object with the SAME sign of charge as the charging body; induction leaves it with the OPPOSITE sign.',
    'The order of steps matters for induction: the earth connection must be broken BEFORE the charged rod is taken away — if the rod is removed first, the separated charges simply recombine and no net charge is left behind.',
  ],
  electroscope: [
    'A gold-leaf electroscope detects and estimates charge: charge spreads down the cap, rod, and onto the two thin leaves, which — carrying the same sign — repel each other and diverge.',
    'Charging BY CONTACT: touch a charged rod to the cap; some charge transfers on, spreads through the instrument, and the leaves diverge and STAY diverged once the rod is removed.',
    'TESTING the sign of an unknown charge: bring it near the cap of an already-charged electroscope (no contact). If the leaves diverge FURTHER, the unknown charge has the SAME sign as the electroscope. If the leaves diverge LESS, it has the OPPOSITE sign.',
    'This works by induction at the cap: a like charge repels the electroscope\u2019s own charge further down toward the leaves (more divergence); an unlike charge attracts it back up toward the cap (less divergence).',
    'An electroscope can also be charged BY INDUCTION (earthing the case while a charged rod is held near the cap, then removing the earth before the rod) — giving it a charge opposite to the rod, the same principle as the electrophorus.',
  ],
  electrophorus: [
    'An electrophorus is a device for producing charge repeatedly from a SINGLE charging of an insulating slab — the slab itself is charged once (by friction) and never touched again.',
    'Sequence: place the metal disc on the charged slab (induction separates its charges) → touch the disc briefly to earth it (the repelled charge escapes) → lift the disc by its INSULATING handle.',
    'The disc lifts away carrying a net charge OPPOSITE to the slab\u2019s charge — if the slab is negative, the disc becomes positive.',
    'Because the slab\u2019s own charge is never used up (only induction happens, no charge transfers to or from the slab), this process can be repeated many times from a single rubbing of the slab.',
    'The insulating handle is essential — touching the metal disc directly (instead of through the handle) would earth it through your hand at the wrong moment and prevent it from carrying charge away.',
  ],
};

const EXERCISES: Record<Topic, { q: string; a: string }[]> = {
  production: [
    { q: 'An ebonite rod is rubbed with fur and becomes negatively charged. What happens to the fur, and why?', a: 'The fur becomes positively charged. Rubbing transfers electrons from the fur to the rod (since the rod holds electrons more strongly here), leaving the fur short of electrons — positively charged — while the rod gains the electrons and becomes negative.' },
    { q: 'A positively charged rod touches a neutral metal sphere on an insulating stand. State the sign of charge left on the sphere.', a: 'Positive — the same sign as the charging rod, since conduction transfers charge of the same sign onto the object touched.' },
    { q: 'Describe how to charge a metal sphere negatively using a POSITIVELY charged rod, without ever touching the rod to the sphere.', a: 'Bring the positive rod close to the sphere (inducing separation of charge — the near side becomes negative, the far side positive). Earth the sphere while the rod is still near, letting the repelled positive charge flow to earth. Disconnect the earth first, THEN remove the rod. The sphere is left with a net negative charge — opposite to the rod.' },
  ],
  electroscope: [
    { q: 'A charged electroscope has its leaves diverged. An unknown charged rod is brought near the cap and the leaves diverge further. What can you conclude about the rod\u2019s charge?', a: 'The rod carries the SAME sign of charge as the electroscope — a like charge repels the electroscope\u2019s charge further down onto the leaves, increasing the divergence.' },
    { q: 'Explain why the leaves of an electroscope diverge when it is charged.', a: 'Charge spreads through the cap, rod, and onto both leaves. Since both leaves carry the same sign, they repel each other and swing apart.' },
    { q: 'A student touches a charged rod to the cap of a neutral electroscope, then removes the rod. Describe and explain what is observed.', a: 'The leaves diverge as the rod touches (charge spreading onto them) and REMAIN diverged after the rod is removed, since the electroscope has now genuinely been charged by contact and retains that charge.' },
  ],
  electrophorus: [
    { q: 'Explain why the metal disc of an electrophorus becomes charged even though it never touches the (already charged) slab with a bare conducting path carrying charge from the slab.', a: 'The disc becomes charged by INDUCTION, not by charge transfer from the slab. The slab\u2019s fixed charge polarises the disc (separates its own charges); earthing the disc lets the repelled charge escape, leaving the disc with an induced charge of its own once the earth and then the slab contact are removed.' },
    { q: 'Why can an electrophorus be used repeatedly without re-charging the insulating slab?', a: 'The slab\u2019s charge is never transferred away — it only induces a redistribution of charge on the disc each time. Since the slab\u2019s own charge is untouched, the same slab can induce a fresh charge on the disc again and again.' },
    { q: 'State the correct order of steps for using an electrophorus, and explain why the order matters.', a: 'Lower the disc onto the slab → earth the disc (e.g., touch it) → remove the earth connection → THEN lift the disc away. If the disc were lifted before removing the earth connection, charge would simply flow back from earth as it left, and the disc would end up uncharged.' },
  ],
};

function StatRow({ label, value, unit, color }: { label: string; value: string; unit: string; color: string }) {
  return (
    <div className="flex justify-between items-center rounded-lg bg-gray-50 px-3 py-2">
      <span className="text-xs text-gray-500">{label}</span>
      <span className={`text-xs font-semibold tabular-nums ${color}`}>{value} <span className="text-gray-400 font-normal">{unit}</span></span>
    </div>
  );
}

export default function ElectrostaticsChargingPage() {
  const [topic, setTopic] = useState<Topic>('production');
  const [isRunning, setIsRunning] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const [resetKey, setResetKey] = useState(0);
  const [openEx, setOpenEx] = useState<number | null>(null);
  const [activeCurricula, setActiveCurricula] = useState(['WAEC', 'IGCSE', 'SAT']);

  const [method, setMethod] = useState<ChargingMethod>('friction');
  const [chargingPhaseLabel, setChargingPhaseLabel] = useState('');

  const [electroscopeMode, setElectroscopeMode] = useState<ElectroscopeMode>('charging');
  const [rodSign, setRodSign] = useState<1 | -1>(-1);
  const [electroscopeSign, setElectroscopeSign] = useState<1 | -1>(-1);
  const [liveDivergence, setLiveDivergence] = useState(0);

  const [electrophorusCycle, setElectrophorusCycle] = useState(0);

  const reset = useCallback(() => {
    setIsRunning(false); setIsPaused(false); setResetKey(k => k + 1);
    setElectrophorusCycle(0);
  }, []);
  const resetTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  useEffect(() => {
    if (resetTimer.current) clearTimeout(resetTimer.current);
    resetTimer.current = setTimeout(reset, 100);
  }, [topic, method, electroscopeMode, rodSign, electroscopeSign, reset]);

  const canvasBoxRef = useRef<HTMLDivElement>(null);
  const canvasSize = useResponsiveCanvasSize(canvasBoxRef, 660, 320, 980);

  return (
    <>
      <AppHeader />
      <main className="min-h-screen bg-gray-50">
        <section className="border-b border-gray-200 bg-white">
          <div className="mx-auto max-w-[100rem] px-4 sm:px-6 py-4">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
              <div>
                <p className="text-xs text-gray-400 mb-0.5">Electricity · Electrostatics</p>
                <h1 className="text-lg font-semibold text-gray-900">Charging Objects</h1>
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
                {topic === 'production' && (
                  <ChargingMethodsCanvas key={resetKey} method={method}
                    isRunning={isRunning} isPaused={isPaused} onPhaseChange={setChargingPhaseLabel}
                    width={canvasSize.width} height={canvasSize.height} />
                )}
                {topic === 'electroscope' && (
                  <ElectroscopeCanvas key={resetKey} mode={electroscopeMode} rodSign={rodSign} electroscopeSign={electroscopeSign}
                    isRunning={isRunning} isPaused={isPaused} onTick={setLiveDivergence}
                    width={canvasSize.width} height={canvasSize.height} />
                )}
                {topic === 'electrophorus' && (
                  <ElectrophorusCanvas key={resetKey} isRunning={isRunning} isPaused={isPaused}
                    cycleCount={electrophorusCycle} onCycleComplete={() => setElectrophorusCycle(c => c + 1)}
                    width={canvasSize.width} height={canvasSize.height} />
                )}
              </div>

              <div className="flex flex-wrap items-center justify-between gap-2">
                <SimulationControls isRunning={isRunning} isPaused={isPaused}
                  onRun={() => { setIsRunning(true); setIsPaused(false); }}
                  onPause={() => setIsPaused(p => !p)} onReset={reset} />
                <EmbedButton path="/embed/electrostatics-charging"
                  title={`${TOPIC_META[topic].title} — A-Factor STEM Studio`}
                  params={
                    topic === 'production' ? { topic, method }
                    : topic === 'electroscope' ? { topic, mode: electroscopeMode, rod: rodSign, es: electroscopeSign }
                    : { topic }
                  } />
              </div>

              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm space-y-4">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide">Parameters</p>

                {topic === 'production' && (
                  <div className="flex flex-col gap-2">
                    {(['friction', 'conduction', 'induction'] as const).map(m => (
                      <button key={m} onClick={() => setMethod(m)}
                        className={`rounded-lg border px-3 py-2 text-xs font-medium capitalize text-left transition ${
                          method === m ? 'border-indigo-300 bg-indigo-50 text-indigo-700' : 'border-gray-200 bg-white text-gray-500'
                        }`}>{m}</button>
                    ))}
                  </div>
                )}

                {topic === 'electroscope' && <>
                  <div className="flex gap-2">
                    {(['charging', 'testing'] as const).map(m => (
                      <button key={m} onClick={() => setElectroscopeMode(m)}
                        className={`flex-1 rounded-lg border px-2 py-2 text-xs font-medium capitalize transition ${
                          electroscopeMode === m ? 'border-indigo-300 bg-indigo-50 text-indigo-700' : 'border-gray-200 bg-white text-gray-500'
                        }`}>{m}</button>
                    ))}
                  </div>
                  {electroscopeMode === 'testing' && (
                    <div className="space-y-1.5">
                      <span className="text-xs text-gray-500">Electroscope&apos;s existing charge</span>
                      <div className="flex gap-2">
                        {([1, -1] as const).map(sgn => (
                          <button key={sgn} onClick={() => setElectroscopeSign(sgn)}
                            className={`flex-1 rounded-lg border px-2 py-2 text-xs font-medium transition ${
                              electroscopeSign === sgn ? 'border-indigo-300 bg-indigo-50 text-indigo-700' : 'border-gray-200 bg-white text-gray-500'
                            }`}>{sgn > 0 ? 'Positive (+)' : 'Negative (−)'}</button>
                        ))}
                      </div>
                    </div>
                  )}
                  <div className="space-y-1.5">
                    <span className="text-xs text-gray-500">{electroscopeMode === 'charging' ? 'Charging rod' : 'Test rod'}</span>
                    <div className="flex gap-2">
                      {([1, -1] as const).map(sgn => (
                        <button key={sgn} onClick={() => setRodSign(sgn)}
                          className={`flex-1 rounded-lg border px-2 py-2 text-xs font-medium transition ${
                            rodSign === sgn ? 'border-indigo-300 bg-indigo-50 text-indigo-700' : 'border-gray-200 bg-white text-gray-500'
                          }`}>{sgn > 0 ? 'Positive (+)' : 'Negative (−)'}</button>
                      ))}
                    </div>
                  </div>
                </>}

                {topic === 'electrophorus' && (
                  <p className="text-xs text-gray-500 leading-relaxed">Press Run to lower the disc, earth it, and lift it away. Press Run again afterwards to repeat the cycle from the same charged slab.</p>
                )}
              </div>
            </div>

            <div className="space-y-3">
              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide mb-3">Calculated</p>
                <div className="space-y-2">
                  {topic === 'production' && <>
                    <StatRow label="Method" value={method} unit="" color="text-indigo-600" />
                    <StatRow label="Current phase" value={chargingPhaseLabel || '—'} unit="" color="text-emerald-600" />
                  </>}
                  {topic === 'electroscope' && <>
                    <StatRow label="Mode" value={electroscopeMode} unit="" color="text-indigo-600" />
                    <StatRow label="Live divergence" value={liveDivergence.toFixed(0)} unit="°" color="text-emerald-600" />
                    {electroscopeMode === 'testing' && (
                      <StatRow label="Relationship" value={rodSign === electroscopeSign ? 'same sign → more' : 'opposite sign → less'} unit="" color="text-amber-600" />
                    )}
                  </>}
                  {topic === 'electrophorus' && <>
                    <StatRow label="Cycles completed" value={electrophorusCycle.toString()} unit="" color="text-indigo-600" />
                    <StatRow label="Slab charge used" value="none — reusable" unit="" color="text-emerald-600" />
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
