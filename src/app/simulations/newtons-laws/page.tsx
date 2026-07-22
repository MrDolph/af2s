'use client';
import { useState, useCallback, useMemo, useRef, useEffect } from 'react';
import { AppHeader } from '@/components/layout/AppHeader';
import { NewtonsFirstCanvas } from '@/components/simulation/NewtonsFirstCanvas';
import { NewtonsSecondCanvas } from '@/components/simulation/NewtonsSecondCanvas';
import { NewtonsThirdCanvas } from '@/components/simulation/NewtonsThirdCanvas';
import { useResponsiveCanvasSize } from '@/hooks/useResponsiveCanvasSize';
import { NewtonsGraph } from '@/components/simulation/NewtonsGraph';
import { ThirdLawGraph } from '@/components/simulation/ThirdLawGraph';
import { SimulationControls } from '@/components/simulation/SimulationControls';
import {
  secondLawAnalytics, thirdLawAnalytics, firstLawTrajectory, secondLawTrajectory, thirdLawTrajectory,
  firstLawAcceleration, ROCKET_GRAPH_DURATION, FirstLawState, SecondLawState,
} from '@/lib/physics/newtons-laws';

type Law = '1st' | '2nd' | '3rd';
type GraphType = 'v' | 'a' | 'x';
type Scenario3 = 'push' | 'rocket' | 'collision';

const CURRICULA = ['WAEC', 'NECO', 'IGCSE', 'SAT', 'JUPEB'];
const CC: Record<string, string> = {
  WAEC: 'bg-indigo-100 text-indigo-700', NECO: 'bg-pink-100 text-pink-700',
  IGCSE: 'bg-emerald-100 text-emerald-700', SAT: 'bg-orange-100 text-orange-700',
  JUPEB: 'bg-purple-100 text-purple-700',
};

const LAW_META = {
  '1st': { title: "Newton's 1st law", sub: 'Law of inertia', eq: 'ΣF = 0 → v = constant', color: '#6366f1' },
  '2nd': { title: "Newton's 2nd law", sub: 'Law of acceleration', eq: 'F = ma', color: '#10b981' },
  '3rd': { title: "Newton's 3rd law", sub: 'Law of action & reaction', eq: 'F₁₂ = −F₂₁', color: '#f59e0b' },
};

const TEACHER_NOTES: Record<Law, string[]> = {
  '1st': [
    "An object stays at rest or moves at constant velocity unless a net external force acts on it.",
    "Inertia is the resistance to change in motion — heavier objects have more inertia.",
    "On a frictionless surface (μ=0), a moving block never stops. On Earth, friction provides the net force.",
    "Common misconception: students think a moving object needs a continuous force to keep moving. It doesn't — only to accelerate it.",
    "Demonstrate: set initial velocity, then toggle friction on/off mid-animation to show inertia.",
  ],
  '2nd': [
    "F = ma: net force equals mass times acceleration. Doubling force doubles acceleration; doubling mass halves it.",
    "Net force, not applied force, causes acceleration. Subtract friction: F_net = F_applied − μmg.",
    "The F-a relationship is linear — the graph of a vs F (constant m) is a straight line through the origin.",
    "Unit check: 1 Newton = 1 kg·m/s². If m=2kg and a=3m/s², F_net=6N.",
    "Show students: with enough friction, a block won't move even with applied force (static friction ≥ F_applied).",
  ],
  '3rd': [
    "For every action there is an equal and opposite reaction — the forces act on DIFFERENT objects.",
    "Common exam trap: students cancel action-reaction pairs. They can't — they act on different bodies.",
    "Rocket propulsion: hot gas is pushed backward (action), rocket is pushed forward (reaction).",
    "The forces are always equal in magnitude — but accelerations differ because masses differ (a = F/m).",
    "Walking: you push the ground backward (action), the ground pushes you forward (reaction).",
  ],
};

const EXERCISES: Record<Law, { q: string; a: string }[]> = {
  '1st': [
    { q: "A 5kg block moves at 10 m/s on a frictionless surface. What net force is needed to maintain this speed?", a: "Zero — by Newton's 1st law, no net force is needed to maintain constant velocity. ΣF = 0." },
    { q: "A 10kg block is pushed at 4 m/s and then released on a surface with μ = 0.3. Find the deceleration. (g=10 m/s²)", a: "Friction = μmg = 0.3×10×10 = 30N. a = F/m = 30/10 = 3 m/s² deceleration." },
    { q: "Why do passengers lurch forward when a bus brakes suddenly?", a: "Passengers tend to continue moving at the bus's original speed (inertia) while the bus decelerates. The seat provides no forward force, so they lurch forward relative to the bus." },
  ],
  '2nd': [
    { q: "A 4kg block is pushed with 20N on a surface with μ = 0.25. Find the acceleration. (g=10 m/s²)", a: "Friction = 0.25×4×10 = 10N. F_net = 20−10 = 10N. a = 10/4 = 2.5 m/s²" },
    { q: "A force of 30N gives a 6kg object an acceleration of 4 m/s². Find the frictional force.", a: "F_net = ma = 6×4 = 24N. Friction = F_applied − F_net = 30−24 = 6N" },
    { q: "How long does it take a 3kg block to reach 12 m/s if pushed with 15N on a frictionless surface?", a: "a = F/m = 15/3 = 5 m/s². t = v/a = 12/5 = 2.4s" },
  ],
  '3rd': [
    { q: "A 70kg person stands on a 500kg boat and pushes the boat with 100N. Find both accelerations.", a: "Both experience 100N. Person: a=100/70=1.43 m/s² backward. Boat: a=100/500=0.2 m/s² forward." },
    { q: "A rocket of mass 2000kg expels gas producing 40,000N thrust. Find the rocket's acceleration.", a: "a = F/m = 40000/2000 = 20 m/s². (Ignoring gravity and changing mass for simplicity.)" },
    { q: "Why does a gun recoil when fired? Use Newton's 3rd Law.", a: "The gun exerts force on bullet (action, bullet moves forward). Bullet exerts equal and opposite force on gun (reaction, gun recoils backward). Forces equal, but gun's larger mass means smaller acceleration." },
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

export default function NewtonsLawsPage() {
  const [law, setLaw] = useState<Law>('1st');
  const [isRunning, setIsRunning] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const [isComplete, setIsComplete] = useState(false);
  const [resetKey, setResetKey] = useState(0);
  const [openEx, setOpenEx] = useState<number | null>(null);
  const [activeCurricula, setActiveCurricula] = useState(['WAEC', 'IGCSE', 'SAT']);
  const [graphType, setGraphType] = useState<GraphType>('v');
  // Live marker position only — the curve itself is precomputed up front
  // (see the ghost-trajectory useMemos below) and shown in full immediately,
  // so this just tracks "where on that curve are we right now".
  const [live1st, setLive1st] = useState({ t: 0, v: 0, a: 0, x: 0 });
  const [live2nd, setLive2nd] = useState({ t: 0, v: 0, a: 0, x: 0 });
  const [live3rd, setLive3rd] = useState({ t: 0, v1: 0, v2: 0 });

  // 1st law params
  const [mass1, setMass1] = useState(5);
  const [friction1, setFriction1] = useState(0);
  const [initV, setInitV] = useState(5);
  const [forceOn, setForceOn] = useState(false);
  const [force1, setForce1] = useState(10);

  // 2nd law params
  const [mass2, setMass2] = useState(5);
  const [applied, setApplied] = useState(30);
  const [friction2, setFriction2] = useState(0.2);

  // 3rd law params
  const [mass3a, setMass3a] = useState(5);
  const [mass3b, setMass3b] = useState(10);
  const [force3, setForce3] = useState(20);
  const [scenario3, setScenario3] = useState<Scenario3>('push');

  const secAnalytics = secondLawAnalytics({ mass: mass2, appliedForce: applied, friction: friction2 });
  const thdAnalytics = thirdLawAnalytics({ type: scenario3, mass1: mass3a, mass2: mass3b, force: force3 });

  // Stable object identity: without this, every graph tick (setGraphData)
  // re-renders the page and recreates this object as a new reference, which
  // re-triggers NewtonsSecondCanvas's reset effect on every single frame —
  // snapping the block back to the start each tick ("vibrating on the
  // spot") and collapsing the graph's time axis back near 0 repeatedly.
  const secondLawParams = useMemo(
    () => ({ mass: mass2, appliedForce: applied, friction: friction2 }),
    [mass2, applied, friction2]
  );

  // Precomputed "ghost" curves — the whole predicted picture, available the
  // instant a slider changes, before Run is ever pressed.
  const firstLawGhost = useMemo(
    () => firstLawTrajectory(mass1, friction1, initV, forceOn, force1),
    [mass1, friction1, initV, forceOn, force1]
  );
  const secondLawGhost = useMemo(() => secondLawTrajectory(secondLawParams), [secondLawParams]);
  const thirdLawGhost = useMemo(
    () => thirdLawTrajectory(scenario3, mass3a, mass3b, force3),
    [scenario3, mass3a, mass3b, force3]
  );

  const resetTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const lastTickRef = useRef(0);
  const reset = useCallback(() => {
    setIsRunning(false); setIsPaused(false);
    setIsComplete(false); setResetKey(k => k + 1);
    setLive1st({ t: 0, v: 0, a: 0, x: 0 });
    setLive2nd({ t: 0, v: 0, a: 0, x: 0 });
    setLive3rd({ t: 0, v1: 0, v2: 0 });
    lastTickRef.current = 0;
  }, []);

  useEffect(() => {
    if (resetTimer.current) clearTimeout(resetTimer.current);
    resetTimer.current = setTimeout(reset, 100);
  }, [law, mass1, friction1, initV, force1, mass2, applied, friction2, mass3a, mass3b, force3, scenario3, reset]);

  const handle1stTick = useCallback((s: FirstLawState) => {
    const now = performance.now();
    if (now - lastTickRef.current < 40) return;
    lastTickRef.current = now;
    const a = firstLawAcceleration(s.v, mass1, friction1, forceOn ? force1 : 0);
    setLive1st({ t: s.time, v: s.v, a, x: s.x });
  }, [mass1, friction1, forceOn, force1]);

  const handle2ndTick = useCallback((s: SecondLawState) => {
    const now = performance.now();
    if (now - lastTickRef.current < 40) return;
    lastTickRef.current = now;
    setLive2nd({ t: s.time, v: s.v, a: s.a, x: s.x });
  }, []);

  const handle3rdTick = useCallback((t: number, v1: number, v2: number) => {
    const now = performance.now();
    if (now - lastTickRef.current < 40) return;
    lastTickRef.current = now;
    setLive3rd({ t, v1, v2 });
  }, []);

  const canvasBoxRef = useRef<HTMLDivElement>(null);
  const canvasSize = useResponsiveCanvasSize(canvasBoxRef, 660, 210, 980);

  return (
    <>
      <AppHeader />
      <main className="min-h-screen bg-gray-50">
        <section className="border-b border-gray-200 bg-white">
          <div className="mx-auto max-w-[100rem] px-4 sm:px-6 py-4">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
              <div>
                <p className="text-xs text-gray-400 mb-0.5">Mechanics</p>
                <h1 className="text-lg font-semibold text-gray-900">Newton&apos;s laws of motion</h1>
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

        <div className="mx-auto max-w-[100rem] px-4 sm:px-6 py-4 space-y-4">

          {/* Law tabs */}
          <div className="flex gap-1 bg-gray-100 p-1 rounded-xl overflow-x-auto">
            {(['1st', '2nd', '3rd'] as Law[]).map(l => (
              <button key={l} onClick={() => { setLaw(l); setOpenEx(null); }}
                className={`shrink-0 px-4 py-2 rounded-lg text-xs font-medium transition ${
                  law === l ? 'bg-white text-indigo-700 shadow-sm' : 'text-gray-500 hover:text-gray-700'
                }`}>
                {LAW_META[l].title}
              </button>
            ))}
          </div>

          {/* Equation banner */}
          <div className="flex flex-wrap items-center gap-3 rounded-xl border border-gray-200 bg-white px-4 py-2.5">
            <span className="text-xs text-gray-400">{LAW_META[law].sub}</span>
            <span className="text-sm font-semibold font-mono text-gray-900">{LAW_META[law].eq}</span>
          </div>

          {/* Main layout */}
          <div className="grid grid-cols-1 lg:grid-cols-[1fr_220px] xl:grid-cols-[1fr_220px_260px] gap-4">

            {/* Col 1: Canvas + controls + sliders */}
            <div className="space-y-3 min-w-0">
              <div ref={canvasBoxRef} className="rounded-2xl border border-gray-200 bg-white p-3 shadow-sm">
                {law === '1st' && (
                  <NewtonsFirstCanvas
                    key={resetKey} mass={mass1} friction={friction1}
                    initialVelocity={initV} forceOn={forceOn} appliedForce={force1}
                    isRunning={isRunning} isPaused={isPaused} onTick={handle1stTick}
                    width={canvasSize.width} height={canvasSize.height}
                  />
                )}
                {law === '2nd' && (
                  <NewtonsSecondCanvas
                    key={resetKey} params={secondLawParams}
                    isRunning={isRunning} isPaused={isPaused} onTick={handle2ndTick}
                    onComplete={() => { setIsComplete(true); setIsRunning(false); }}
                    width={canvasSize.width} height={canvasSize.height}
                  />
                )}
                {law === '3rd' && (
                  <NewtonsThirdCanvas
                    key={resetKey} mass1={mass3a} mass2={mass3b} force={force3}
                    scenario={scenario3} isRunning={isRunning} isPaused={isPaused}
                    onTick={handle3rdTick}
                    width={canvasSize.width} height={canvasSize.height}
                  />
                )}
              </div>

              <div className="flex flex-wrap items-center justify-between gap-2">
                <SimulationControls
                  isRunning={isRunning && !isComplete} isPaused={isPaused}
                  onRun={() => { setIsRunning(true); setIsPaused(false); setIsComplete(false); }}
                  onPause={() => setIsPaused(p => !p)}
                  onReset={reset}
                />
                {isComplete && <span className="text-xs font-medium text-emerald-600">✓ Complete — Reset to go again</span>}
              </div>

              {/* Live graph — full predicted curve shown immediately, with a
                  live marker riding along it as the animation plays. */}
              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                <div className="flex items-center justify-between mb-3">
                  <p className="text-xs font-medium text-gray-400 uppercase tracking-wide">
                    {law === '3rd' ? 'Velocity graph' : 'Live graph'}
                  </p>
                  {law !== '3rd' && (
                    <div className="flex gap-1 bg-gray-100 p-0.5 rounded-lg">
                      {(['v', 'a', 'x'] as GraphType[]).map(g => (
                        <button key={g} onClick={() => setGraphType(g)}
                          className={`px-3 py-1 rounded-md text-xs font-medium transition ${
                            graphType === g ? 'bg-white text-indigo-700 shadow-sm' : 'text-gray-500'
                          }`}>{g === 'v' ? 'Velocity' : g === 'a' ? 'Acceleration' : 'Displacement'}</button>
                      ))}
                    </div>
                  )}
                </div>
                {law === '1st' && (
                  <NewtonsGraph data={firstLawGhost} show={graphType} liveT={live1st.t} liveValue={live1st[graphType]} />
                )}
                {law === '2nd' && (
                  <NewtonsGraph data={secondLawGhost} show={graphType} liveT={live2nd.t} liveValue={live2nd[graphType]} />
                )}
                {law === '3rd' && (() => {
                  const rocketA = force3 / mass3a;
                  const wrappedT = scenario3 === 'rocket' ? live3rd.t % ROCKET_GRAPH_DURATION : live3rd.t;
                  const wrappedV1 = scenario3 === 'rocket' ? rocketA * wrappedT : live3rd.v1;
                  return (
                    <ThirdLawGraph data={thirdLawGhost} scenario={scenario3}
                      liveT={wrappedT} liveV1={wrappedV1} liveV2={live3rd.v2} />
                  );
                })()}
              </div>

              {law === '3rd' && (
                <p className="text-[10px] text-gray-400 -mt-2 px-1">
                  {scenario3 === 'rocket'
                    ? 'Rocket velocity keeps climbing as fuel burns — this graph loops to show the same constant-acceleration shape each cycle.'
                    : 'Same force, different acceleration: the lighter object always reaches a larger speed by the time contact ends.'}
                </p>
              )}

              {/* Sliders */}
              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm space-y-4">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide">Parameters</p>

                {law === '1st' && (
                  <>
                    <Slider label="Mass" unit="kg" value={mass1} min={1} max={20} step={0.5} set={setMass1} color="#6366f1" />
                    <Slider label="Initial velocity" unit="m/s" value={initV} min={0} max={20} step={0.5} set={setInitV} color="#f59e0b" />
                    <Slider label="Friction coefficient μ" unit="" value={friction1} min={0} max={0.8} step={0.01} set={setFriction1} color="#ef4444" note="0 = frictionless surface" />
                    <div className="flex items-center justify-between rounded-xl border border-gray-100 bg-gray-50 px-4 py-3">
                      <div>
                        <p className="text-xs font-medium text-gray-700">Applied force</p>
                        <p className="text-[10px] text-gray-400">Toggle to show Newton&apos;s 1st law</p>
                      </div>
                      <button onClick={() => setForceOn(f => !f)}
                        className={`relative w-11 h-6 rounded-full transition ${forceOn ? 'bg-indigo-600' : 'bg-gray-200'}`}>
                        <span className={`absolute top-0.5 left-0.5 w-5 h-5 rounded-full bg-white shadow transition-transform ${forceOn ? 'translate-x-5' : ''}`} />
                      </button>
                    </div>
                    {forceOn && (
                      <Slider label="Force" unit="N" value={force1} min={1} max={50} step={1} set={setForce1} color="#10b981" />
                    )}
                  </>
                )}

                {law === '2nd' && (
                  <>
                    <Slider label="Mass" unit="kg" value={mass2} min={1} max={20} step={0.5} set={setMass2} color="#6366f1" />
                    <Slider label="Applied force" unit="N" value={applied} min={1} max={100} step={1} set={setApplied} color="#10b981" />
                    <Slider label="Friction coefficient μ" unit="" value={friction2} min={0} max={0.8} step={0.01} set={setFriction2} color="#ef4444" note="0 = frictionless" />
                  </>
                )}

                {law === '3rd' && (
                  <>
                    <div className="grid grid-cols-3 gap-1 bg-gray-100 p-1 rounded-xl">
                      {(['push', 'rocket', 'collision'] as Scenario3[]).map(s => (
                        <button key={s} onClick={() => setScenario3(s)}
                          className={`py-1.5 rounded-lg text-xs font-medium capitalize transition ${
                            scenario3 === s ? 'bg-white text-indigo-700 shadow-sm' : 'text-gray-500'
                          }`}>{s}</button>
                      ))}
                    </div>
                    <Slider label="Object 1 mass" unit="kg" value={mass3a} min={1} max={50} step={1} set={setMass3a} color="#6366f1" />
                    <Slider label="Object 2 mass" unit="kg" value={mass3b} min={1} max={50} step={1} set={setMass3b} color="#10b981" />
                    <Slider label="Interaction force" unit="N" value={force3} min={5} max={100} step={5} set={setForce3} color="#f59e0b" />
                  </>
                )}
              </div>
            </div>

            {/* Col 2: Analytics */}
            <div className="space-y-3">
              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide mb-3">Calculated</p>
                <div className="space-y-2">
                  {law === '1st' && [
                    { l: 'Mass', v: `${mass1} kg`, c: 'text-indigo-600' },
                    { l: 'Initial velocity', v: `${initV} m/s`, c: 'text-amber-600' },
                    { l: 'Friction (μ)', v: friction1.toFixed(2), c: 'text-red-500' },
                    { l: 'Friction force', v: `${(friction1 * mass1 * 9.81).toFixed(1)} N`, c: 'text-red-400' },
                    { l: 'Net force', v: forceOn ? `${(force1 - friction1 * mass1 * 9.81).toFixed(1)} N` : `${(friction1 * mass1 * 9.81 * -1).toFixed(1)} N`, c: 'text-gray-700' },
                  ].map(r => (
                    <div key={r.l} className="flex justify-between items-center rounded-lg bg-gray-50 px-3 py-2">
                      <span className="text-xs text-gray-500">{r.l}</span>
                      <span className={`text-sm font-semibold ${r.c}`}>{r.v}</span>
                    </div>
                  ))}

                  {law === '2nd' && [
                    { l: 'Applied force', v: `${applied} N`, c: 'text-emerald-600' },
                    { l: 'Friction force', v: `${secAnalytics.frictionForce} N`, c: 'text-red-500' },
                    { l: 'Net force', v: `${secAnalytics.netForce} N`, c: 'text-indigo-600' },
                    { l: 'Acceleration', v: `${secAnalytics.acceleration} m/s²`, c: 'text-amber-600' },
                    { l: 'F = ma check', v: `${secAnalytics.netForce} = ${mass2}×${secAnalytics.acceleration}`, c: 'text-gray-600' },
                  ].map(r => (
                    <div key={r.l} className="flex justify-between items-center rounded-lg bg-gray-50 px-3 py-2">
                      <span className="text-xs text-gray-500">{r.l}</span>
                      <span className={`text-sm font-semibold ${r.c}`}>{r.v}</span>
                    </div>
                  ))}

                  {law === '3rd' && [
                    { l: 'Action force', v: `${force3} N`, c: 'text-emerald-600' },
                    { l: 'Reaction force', v: `−${force3} N`, c: 'text-red-500' },
                    { l: `a₁ (${mass3a}kg)`, v: `${thdAnalytics.a1.toFixed(2)} m/s²`, c: 'text-indigo-600' },
                    { l: `a₂ (${mass3b}kg)`, v: `${thdAnalytics.a2.toFixed(2)} m/s²`, c: 'text-amber-600' },
                    { l: 'Force equal?', v: 'Yes — always', c: 'text-emerald-600' },
                  ].map(r => (
                    <div key={r.l} className="flex justify-between items-center rounded-lg bg-gray-50 px-3 py-2">
                      <span className="text-xs text-gray-500">{r.l}</span>
                      <span className={`text-sm font-semibold ${r.c}`}>{r.v}</span>
                    </div>
                  ))}
                </div>
              </div>

              {/* Curriculum */}
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

            {/* Col 3: Teacher notes + exercises */}
            <div className="space-y-3 lg:col-span-2 xl:col-span-1">
              <div className="rounded-2xl border border-amber-100 bg-amber-50 p-4">
                <p className="text-xs font-medium text-amber-700 uppercase tracking-wide mb-3">📋 Teacher notes</p>
                <ul className="space-y-2">
                  {TEACHER_NOTES[law].map((n, i) => (
                    <li key={i} className="text-xs text-amber-900 leading-relaxed flex gap-2">
                      <span className="text-amber-400 shrink-0 mt-0.5">•</span>{n}
                    </li>
                  ))}
                </ul>
              </div>

              <div className="rounded-2xl border border-gray-200 bg-white p-4">
                <p className="text-xs font-medium text-gray-500 uppercase tracking-wide mb-3">✏️ Exercises</p>
                <div className="space-y-2">
                  {EXERCISES[law].map((ex, i) => (
                    <div key={i} className="rounded-xl border border-gray-100 overflow-hidden">
                      <button onClick={() => setOpenEx(openEx === i ? null : i)}
                        className="w-full text-left px-3 py-2.5 text-xs text-gray-700 leading-relaxed hover:bg-gray-50 transition flex justify-between gap-2">
                        <span><span className="font-medium text-indigo-600">Q{i+1}.</span> {ex.q}</span>
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
