'use client';
import { useState, useCallback, useRef, useEffect } from 'react';
import { AppHeader } from '@/components/layout/AppHeader';
import { SimulationControls } from '@/components/simulation/SimulationControls';
import { ElevatorCanvas } from '@/components/simulation/ElevatorCanvas';
import { WalkingCanvas } from '@/components/simulation/WalkingCanvas';
import { CollisionCanvas } from '@/components/simulation/CollisionCanvas';
import {
  apparentWeight, solveCollision, rocketAnalytics,
  ElevatorState, CollisionParams, g,
} from '@/lib/physics/consequences';

type Topic = 'elevator' | 'weightlessness' | 'walking' | 'propulsion' | 'collision';

const CURRICULA = ['WAEC', 'NECO', 'IGCSE', 'SAT', 'JUPEB'];
const CC: Record<string, string> = {
  WAEC: 'bg-indigo-100 text-indigo-700', NECO: 'bg-pink-100 text-pink-700',
  IGCSE: 'bg-emerald-100 text-emerald-700', SAT: 'bg-orange-100 text-orange-700',
  JUPEB: 'bg-purple-100 text-purple-700',
};

const TOPIC_META: Record<Topic, { title: string; icon: string; sub: string; law: string }> = {
  elevator:       { title: 'Elevator / Lift',      icon: '🛗', sub: 'Apparent weight and Newton\'s 2nd Law', law: 'R = m(g + a)' },
  weightlessness: { title: 'Weightlessness',        icon: '🚀', sub: 'Zero apparent weight in free fall and orbit', law: 'W_app = 0 when a = −g' },
  walking:        { title: 'Walking',               icon: '🚶', sub: 'Newton\'s 3rd Law — action and reaction', law: 'F_foot = −F_ground' },
  propulsion:     { title: 'Propulsion',            icon: '🛸', sub: 'Rockets, jets — momentum conservation', law: 'Thrust = v_e × ṁ' },
  collision:      { title: 'Collision & Impact',    icon: '💥', sub: 'Elastic vs inelastic — impulse-momentum', law: 'J = Δp = FΔt' },
};

const TEACHER_NOTES: Record<Topic, string[]> = {
  elevator: [
    "Apparent weight = R = m(g + a). When a > 0 (accelerating up), R > mg — person feels heavier.",
    "When a < 0 (accelerating down), R < mg — person feels lighter. When a = −g (free fall), R = 0.",
    "The scale reads apparent weight, not true weight. This is what WAEC/IGCSE questions actually ask for.",
    "Common exam trap: during constant speed (a=0), the person feels exactly their true weight regardless of how fast they're going.",
    "Deceleration at the top of an upward journey = acceleration downward → lighter feeling, not heavier.",
  ],
  weightlessness: [
    "True weightlessness only exists at infinite distance from all masses. Everything else is apparent weightlessness.",
    "Astronauts in the ISS aren't weightless — they're in constant free fall (orbiting). g ≈ 8.8 m/s² at ISS altitude.",
    "An object in free fall experiences zero apparent weight because both the person and the scale accelerate at g.",
    "Apparent weightlessness can be experienced in a falling lift, a parabolic flight path, or orbital trajectory.",
    "JUPEB/IGCSE: distinguish carefully between 'gravitational field strength', 'weight', and 'apparent weight'.",
  ],
  walking: [
    "Walking is entirely powered by Newton's 3rd Law. Your foot pushes backward on the ground; ground pushes you forward.",
    "Without friction, there is no reaction force and you cannot walk — demonstrated by trying to walk on ice.",
    "The forward force on a person is the ground's reaction — it's an external force that accelerates the person.",
    "Common misconception: students think the push from the foot makes you move. It's the ground's reaction that moves you.",
    "Swimming: hand/foot pushes water backward (action), water pushes swimmer forward (reaction). Same principle.",
  ],
  propulsion: [
    "Rocket thrust = exhaust speed × mass flow rate (T = v_e × ṁ). Nothing to 'push against' — momentum conservation.",
    "As fuel burns, rocket mass decreases → same thrust gives increasing acceleration (a = T/m, m decreasing).",
    "Jet engines work in atmosphere (air provides reaction mass). Rockets carry their own oxidiser — work in vacuum.",
    "Specific impulse: efficiency measure for rockets. Higher exhaust velocity = more efficient propulsion.",
    "Conservation of momentum: before = 0 (at rest). After = rocket momentum + exhaust momentum. Always sums to 0.",
  ],
  collision: [
    "Momentum is always conserved in collisions (no external forces). Kinetic energy may or may not be conserved.",
    "Elastic collision: KE conserved (e=1). Inelastic: KE lost (e<1). Perfectly inelastic: objects stick together (e=0).",
    "Impulse = change in momentum = FΔt. Increasing contact time (crumple zones, airbags) reduces peak force.",
    "The impulse-momentum theorem is why cars have airbags — same Δp, longer Δt, smaller F on passenger.",
    "WAEC exam: most collision questions just apply p_before = p_after. Check if KE is asked separately.",
  ],
};

const EXERCISES: Record<Topic, { q: string; a: string }[]> = {
  elevator: [
    { q: "A 60kg person stands in a lift accelerating upward at 2 m/s². Find their apparent weight. (g=10)", a: "R = m(g+a) = 60×(10+2) = 60×12 = 720 N. True weight = 600 N." },
    { q: "A 70kg person is in a lift decelerating at 3 m/s² while moving upward. Find apparent weight. (g=10)", a: "Decelerating upward means a = −3 m/s². R = 70×(10−3) = 70×7 = 490 N." },
    { q: "A scale reads 0 N for a 50kg person in a lift. What is happening?", a: "The lift is in free fall (a = −g = −10 m/s²). R = m(g + a) = 50×(10−10) = 0 N. Apparent weightlessness." },
  ],
  weightlessness: [
    { q: "Why do astronauts in the ISS float, even though gravity still acts on them?", a: "The ISS is in continuous free fall (orbiting). Both astronauts and station fall toward Earth at the same rate, so there's no normal force between them — apparent weightlessness." },
    { q: "A 80kg person is in a freely falling lift. What does a scale beneath them read?", a: "0 N — both person and scale fall at g, so no contact force exists between them." },
    { q: "Is there gravity on the Moon? Explain apparent weightlessness vs true weightlessness.", a: "Yes — g_moon ≈ 1.6 m/s². Astronauts have weight on the Moon but feel about 1/6 of Earth weight. True weightlessness only exists at infinite distance from all masses." },
  ],
  walking: [
    { q: "Explain why you cannot walk on a perfectly frictionless surface using Newton's Laws.", a: "When you push your foot backward, the ground needs friction to push back. Without friction, no reaction force acts forward on you, so by Newton's 1st Law, you don't move." },
    { q: "A 70kg person accelerates from rest to 2 m/s in 1s while walking. Find the average forward friction force.", a: "F = ma = 70 × (2/1) = 140 N forward (provided by ground friction as reaction to foot's push)." },
    { q: "Swimming: identify the action and reaction forces when a swimmer pushes off a wall.", a: "Action: swimmer pushes wall backward with force F. Reaction: wall pushes swimmer forward with equal force F. Swimmer accelerates; wall (attached to Earth) doesn't noticeably move." },
  ],
  propulsion: [
    { q: "A rocket of mass 5000 kg ejects gas at 2000 m/s at a rate of 10 kg/s. Find thrust and initial acceleration.", a: "Thrust = v_e × ṁ = 2000 × 10 = 20,000 N. a = F/m = 20000/5000 = 4 m/s²." },
    { q: "Why do rockets work in the vacuum of space but car engines don't?", a: "Rockets carry their own fuel AND oxidiser, ejecting exhaust backward. Cars need atmospheric oxygen to combust fuel. In vacuum, no air = no combustion for a car engine." },
    { q: "A 2 kg toy rocket is at rest. It ejects 0.5 kg of gas at 40 m/s. Find the rocket's speed after.", a: "Momentum conservation: 0 = 1.5 × v_rocket − 0.5 × 40. v_rocket = 20/1.5 ≈ 13.3 m/s." },
  ],
  collision: [
    { q: "A 3kg ball at 6 m/s hits a stationary 1kg ball. They stick together. Find their common velocity.", a: "Perfectly inelastic: (3×6 + 1×0) = (3+1)×v. v = 18/4 = 4.5 m/s." },
    { q: "A 0.1kg bullet at 400 m/s embeds in a 4.9kg block at rest. Find the block's velocity after.", a: "(0.1×400) = (0.1+4.9)×v. v = 40/5 = 8 m/s." },
    { q: "An airbag increases impact time from 0.01s to 0.1s for a 70kg person decelerating from 15 m/s to 0. Compare forces.", a: "Impulse = Δp = 70×15 = 1050 N·s. Without bag: F = 1050/0.01 = 105,000 N. With bag: F = 1050/0.1 = 10,500 N — 10× less force." },
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

export default function ConsequencesPage() {
  const [topic, setTopic] = useState<Topic>('elevator');
  const [isRunning, setIsRunning] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const [isComplete, setIsComplete] = useState(false);
  const [resetKey, setResetKey] = useState(0);
  const [openEx, setOpenEx] = useState<number | null>(null);
  const [activeCurricula, setActiveCurricula] = useState(['WAEC', 'IGCSE', 'SAT']);

  // Elevator params
  const [elevMass, setElevMass] = useState(60);
  const [elevState, setElevState] = useState<ElevatorState>('rest');
  const [elevAccel, setElevAccel] = useState(3);

  // Weightlessness
  const [wlHeight, setWlHeight] = useState(400); // km orbit

  // Walking
  const [frictionEnabled, setFrictionEnabled] = useState(true);

  // Propulsion
  const [rocketMass, setRocketMass] = useState(5000);
  const [exhaustSpeed, setExhaustSpeed] = useState(2000);
  const [massFlowRate, setMassFlowRate] = useState(10);

  // Collision
  const [collM1, setCollM1] = useState(3);
  const [collM2, setCollM2] = useState(2);
  const [collU1, setCollU1] = useState(6);
  const [collU2, setCollU2] = useState(0);
  const [collType, setCollType] = useState<CollisionParams['type']>('perfectly-inelastic');
  const [collE, setCollE] = useState(0.6);
  const [collResult, setCollResult] = useState<ReturnType<typeof solveCollision> | null>(null);

  const collParams: CollisionParams = { m1: collM1, m2: collM2, u1: collU1, u2: collU2, type: collType, e: collE };
  const rocketA = rocketAnalytics(rocketMass, exhaustSpeed, massFlowRate);
  const elevAppW = apparentWeight(elevMass, elevState === 'freefall' ? -g : elevState.includes('up') ? (elevState.includes('accel') ? elevAccel : elevState.includes('decel') ? -elevAccel : 0) : elevState.includes('down') ? (elevState.includes('accel') ? -elevAccel : elevState.includes('decel') ? elevAccel : 0) : 0);
  const collRes = solveCollision(collParams);

  // Orbit g
  const orbitG = g * Math.pow(6371 / (6371 + wlHeight), 2);

  const resetTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const reset = useCallback(() => {
    setIsRunning(false); setIsPaused(false);
    setIsComplete(false); setResetKey(k => k + 1);
    setCollResult(null);
  }, []);

  useEffect(() => {
    if (resetTimer.current) clearTimeout(resetTimer.current);
    resetTimer.current = setTimeout(reset, 100);
  }, [topic, elevMass, elevState, elevAccel, frictionEnabled, rocketMass, exhaustSpeed, massFlowRate, collM1, collM2, collU1, collU2, collType, collE, reset]);

  return (
    <>
      <AppHeader />
      <main className="min-h-screen bg-gray-50">
        <section className="border-b border-gray-200 bg-white">
          <div className="mx-auto max-w-7xl px-4 sm:px-6 py-4">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
              <div>
                <p className="text-xs text-gray-400 mb-0.5">Applications of Newton's Laws</p>
                <h1 className="text-lg font-semibold text-gray-900">Consequences of motion</h1>
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

          {/* Topic tabs — scrollable on mobile */}
          <div className="flex gap-1 bg-gray-100 p-1 rounded-xl overflow-x-auto">
            {(Object.keys(TOPIC_META) as Topic[]).map(t => (
              <button key={t} onClick={() => { setTopic(t); setOpenEx(null); }}
                className={`shrink-0 flex items-center gap-1.5 px-3 py-2 rounded-lg text-xs font-medium transition ${
                  topic === t ? 'bg-white text-indigo-700 shadow-sm' : 'text-gray-500 hover:text-gray-700'
                }`}>
                <span>{TOPIC_META[t].icon}</span>
                <span className="hidden sm:inline">{TOPIC_META[t].title}</span>
                <span className="sm:hidden">{TOPIC_META[t].icon}</span>
              </button>
            ))}
          </div>

          {/* Equation banner */}
          <div className="flex flex-wrap items-center gap-3 rounded-xl border border-gray-200 bg-white px-4 py-2.5">
            <span className="text-xs text-gray-400">{TOPIC_META[topic].sub}</span>
            <span className="text-sm font-semibold font-mono text-gray-900">{TOPIC_META[topic].law}</span>
          </div>

          {/* Main grid */}
          <div className="grid grid-cols-1 lg:grid-cols-[1fr_220px] xl:grid-cols-[1fr_220px_260px] gap-4">

            {/* Canvas + controls + params */}
            <div className="space-y-3 min-w-0">
              <div className="rounded-2xl border border-gray-200 bg-white p-3 shadow-sm">

                {topic === 'elevator' && (
                  <ElevatorCanvas key={resetKey} mass={elevMass} elevState={elevState}
                    manualAccel={elevAccel} isRunning={isRunning} isPaused={isPaused}
                    width={500} height={320} />
                )}

                {topic === 'weightlessness' && (
                  <div className="space-y-4 p-4">
                    <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
                      {[
                        { label: 'On Earth surface', g: 9.81, color: 'bg-red-50 border-red-200', textColor: 'text-red-700', icon: '🌍' },
                        { label: `At ${wlHeight}km orbit`, g: orbitG, color: 'bg-blue-50 border-blue-200', textColor: 'text-blue-700', icon: '🛸' },
                        { label: 'In free fall', g: 0, color: 'bg-purple-50 border-purple-200', textColor: 'text-purple-700', icon: '🪂' },
                      ].map(s => (
                        <div key={s.label} className={`rounded-xl border ${s.color} p-4 text-center`}>
                          <span className="text-2xl block mb-2">{s.icon}</span>
                          <p className="text-xs text-gray-500 mb-1">{s.label}</p>
                          <p className={`text-lg font-bold ${s.textColor}`}>{s.g.toFixed(2)} m/s²</p>
                          <p className="text-xs text-gray-400 mt-1">
                            Apparent weight: {(elevMass * Math.max(0, s.g - (s.g === 0 ? 9.81 : 0))).toFixed(0)} N
                          </p>
                          <p className="text-xs font-medium mt-2 text-gray-600">
                            {s.g === 0 ? '✓ Weightless' : s.g < 5 ? 'Near weightless' : 'Normal weight'}
                          </p>
                        </div>
                      ))}
                    </div>
                    <div className="rounded-xl border border-indigo-100 bg-indigo-50 p-4 text-center">
                      <p className="text-xs text-indigo-500 mb-1">Key insight</p>
                      <p className="text-sm text-indigo-800 leading-relaxed">
                        At {wlHeight}km altitude, g = {orbitG.toFixed(2)} m/s² — gravity is still {(orbitG/9.81*100).toFixed(0)}% of Earth surface gravity.
                        Astronauts float not because gravity is absent, but because they are in continuous free fall (orbit).
                      </p>
                    </div>
                    <div className="grid grid-cols-2 sm:grid-cols-4 gap-3 text-center">
                      {[
                        { label: 'ISS orbit', h: 400 }, { label: 'GPS orbit', h: 20200 },
                        { label: 'GEO orbit', h: 35786 }, { label: 'Moon orbit', h: 384400 },
                      ].map(o => (
                        <button key={o.label} onClick={() => setWlHeight(o.h)}
                          className={`rounded-xl border p-3 transition text-xs ${wlHeight === o.h ? 'bg-indigo-600 text-white border-indigo-600' : 'bg-white border-gray-200 text-gray-600 hover:border-gray-300'}`}>
                          <p className="font-medium">{o.label}</p>
                          <p className="opacity-70">{o.h < 1000 ? `${o.h}km` : `${(o.h/1000).toFixed(0)}k km`}</p>
                        </button>
                      ))}
                    </div>
                  </div>
                )}

                {topic === 'walking' && (
                  <WalkingCanvas key={resetKey} isRunning={isRunning} isPaused={isPaused}
                    frictionEnabled={frictionEnabled} surfaceMass={70}
                    width={660} height={200} />
                )}

                {topic === 'propulsion' && (
                  <div className="p-4 space-y-4">
                    {/* Rocket diagram */}
                    <div className="relative h-44 rounded-xl border border-gray-100 bg-gradient-to-b from-slate-900 to-slate-800 overflow-hidden">
                      {/* Stars */}
                      {Array.from({ length: 30 }, (_, i) => (
                        <div key={i} className="absolute w-0.5 h-0.5 bg-white rounded-full opacity-60"
                          style={{ left: `${(i * 37) % 100}%`, top: `${(i * 53) % 100}%` }} />
                      ))}
                      {/* Rocket */}
                      <div className="absolute left-1/2 top-1/2 -translate-x-1/2 -translate-y-1/2 flex items-center gap-0">
                        {/* Exhaust */}
                        <div className="flex flex-col gap-0.5 mr-1">
                          {[...Array(4)].map((_, i) => (
                            <div key={i} className="h-1.5 rounded-full bg-orange-400 opacity-80"
                              style={{ width: `${20 + i * 12}px`, marginLeft: `${i * 4}px` }} />
                          ))}
                        </div>
                        {/* Body */}
                        <div className="w-20 h-12 bg-indigo-400 rounded-lg flex items-center justify-center">
                          <span className="text-white text-xs font-bold">{rocketMass}kg</span>
                        </div>
                        {/* Nose */}
                        <div className="w-0 h-0 border-t-[24px] border-t-transparent border-b-[24px] border-b-transparent border-l-[20px] border-l-indigo-500" />
                      </div>
                      {/* Labels */}
                      <div className="absolute bottom-2 left-0 right-0 flex justify-between px-4">
                        <span className="text-red-400 text-xs">← Exhaust (reaction)</span>
                        <span className="text-emerald-400 text-xs">Thrust → motion (action)</span>
                      </div>
                    </div>
                    {/* Analytics */}
                    <div className="grid grid-cols-2 gap-3">
                      {[
                        { l: 'Thrust', v: `${rocketA.thrust.toFixed(0)} N`, c: 'text-amber-600' },
                        { l: 'Acceleration', v: `${rocketA.acceleration.toFixed(2)} m/s²`, c: 'text-indigo-600' },
                        { l: 'Exhaust speed', v: `${exhaustSpeed} m/s`, c: 'text-emerald-600' },
                        { l: 'Mass flow rate', v: `${massFlowRate} kg/s`, c: 'text-rose-500' },
                      ].map(s => (
                        <div key={s.l} className="rounded-xl bg-gray-50 border border-gray-100 px-3 py-2.5 text-center">
                          <p className="text-xs text-gray-400 mb-0.5">{s.l}</p>
                          <p className={`text-sm font-semibold ${s.c}`}>{s.v}</p>
                        </div>
                      ))}
                    </div>
                    <div className="rounded-xl border border-indigo-100 bg-indigo-50 p-3 text-xs text-indigo-800">
                      <p className="font-medium mb-1">Momentum conservation</p>
                      <p>Before launch: total momentum = 0. After ejecting exhaust backward at {exhaustSpeed} m/s, rocket gains equal momentum forward. No external force needed — rockets work in vacuum.</p>
                    </div>
                  </div>
                )}

                {topic === 'collision' && (
                  <CollisionCanvas key={resetKey} params={collParams}
                    isRunning={isRunning} isPaused={isPaused}
                    onComplete={r => { setCollResult(r); setIsComplete(true); setIsRunning(false); }}
                    width={660} height={200} />
                )}
              </div>

              {/* Controls */}
              {topic !== 'weightlessness' && topic !== 'propulsion' && (
                <div className="flex flex-wrap items-center justify-between gap-2">
                  <SimulationControls
                    isRunning={isRunning && !isComplete} isPaused={isPaused}
                    onRun={() => { setIsRunning(true); setIsPaused(false); setIsComplete(false); }}
                    onPause={() => setIsPaused(p => !p)}
                    onReset={reset}
                  />
                  {isComplete && <span className="text-xs font-medium text-emerald-600">✓ Complete — Reset to go again</span>}
                </div>
              )}

              {/* Params */}
              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm space-y-4">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide">Parameters</p>

                {topic === 'elevator' && (
                  <>
                    <Slider label="Mass" unit="kg" value={elevMass} min={10} max={150} step={5} set={setElevMass} color="#6366f1" />
                    <Slider label="Acceleration magnitude" unit="m/s²" value={elevAccel} min={0.5} max={9.8} step={0.1} set={setElevAccel} color="#f59e0b" />
                    <div>
                      <p className="text-xs text-gray-500 mb-2">Elevator state</p>
                      <div className="grid grid-cols-2 gap-1.5">
                        {([
                          ['rest', 'At rest'], ['accel-up', 'Accelerating ↑'],
                          ['constant-up', 'Constant speed ↑'], ['decel-up', 'Decelerating ↑'],
                          ['accel-down', 'Accelerating ↓'], ['constant-down', 'Constant speed ↓'],
                          ['decel-down', 'Decelerating ↓'], ['freefall', '🆘 Free fall'],
                        ] as [ElevatorState, string][]).map(([s, l]) => (
                          <button key={s} onClick={() => setElevState(s)}
                            className={`px-2 py-1.5 rounded-lg text-xs font-medium border transition ${
                              elevState === s
                                ? s === 'freefall' ? 'bg-red-500 text-white border-red-500' : 'bg-indigo-600 text-white border-indigo-600'
                                : 'bg-white text-gray-600 border-gray-200 hover:border-gray-300'
                            }`}>{l}</button>
                        ))}
                      </div>
                    </div>
                  </>
                )}

                {topic === 'weightlessness' && (
                  <>
                    <Slider label="Person mass" unit="kg" value={elevMass} min={40} max={120} step={5} set={setElevMass} color="#6366f1" />
                    <Slider label="Orbit altitude" unit="km" value={wlHeight} min={200} max={400000} step={100} set={setWlHeight} color="#8b5cf6" />
                  </>
                )}

                {topic === 'walking' && (
                  <div className="flex items-center justify-between rounded-xl border border-gray-100 bg-gray-50 px-4 py-3">
                    <div>
                      <p className="text-xs font-medium text-gray-700">Ground friction</p>
                      <p className="text-[10px] text-gray-400">{frictionEnabled ? 'Normal ground — walking works' : 'Frictionless ice — cannot walk'}</p>
                    </div>
                    <button onClick={() => setFrictionEnabled(f => !f)}
                      className={`relative w-11 h-6 rounded-full transition ${frictionEnabled ? 'bg-indigo-600' : 'bg-gray-200'}`}>
                      <span className={`absolute top-0.5 left-0.5 w-5 h-5 rounded-full bg-white shadow transition-transform ${frictionEnabled ? 'translate-x-5' : ''}`} />
                    </button>
                  </div>
                )}

                {topic === 'propulsion' && (
                  <>
                    <Slider label="Rocket mass" unit="kg" value={rocketMass} min={500} max={50000} step={500} set={setRocketMass} color="#6366f1" />
                    <Slider label="Exhaust speed" unit="m/s" value={exhaustSpeed} min={200} max={5000} step={100} set={setExhaustSpeed} color="#f59e0b" />
                    <Slider label="Mass flow rate" unit="kg/s" value={massFlowRate} min={1} max={100} step={1} set={setMassFlowRate} color="#10b981" />
                  </>
                )}

                {topic === 'collision' && (
                  <>
                    <div className="grid grid-cols-3 gap-1 bg-gray-100 p-1 rounded-xl">
                      {(['elastic', 'inelastic', 'perfectly-inelastic'] as CollisionParams['type'][]).map(t => (
                        <button key={t} onClick={() => setCollType(t)}
                          className={`py-1.5 rounded-lg text-[10px] font-medium transition ${
                            collType === t ? 'bg-white text-indigo-700 shadow-sm' : 'text-gray-500'
                          }`}>{t === 'perfectly-inelastic' ? 'Stick together' : t.charAt(0).toUpperCase() + t.slice(1)}</button>
                      ))}
                    </div>
                    <Slider label="Mass 1 (blue)" unit="kg" value={collM1} min={0.5} max={10} step={0.5} set={setCollM1} color="#6366f1" />
                    <Slider label="Velocity 1" unit="m/s" value={collU1} min={-10} max={20} step={0.5} set={setCollU1} color="#6366f1" />
                    <Slider label="Mass 2 (green)" unit="kg" value={collM2} min={0.5} max={10} step={0.5} set={setCollM2} color="#10b981" />
                    <Slider label="Velocity 2" unit="m/s" value={collU2} min={-10} max={10} step={0.5} set={setCollU2} color="#10b981" note="Negative = moving left" />
                    {collType === 'inelastic' && (
                      <Slider label="Coefficient of restitution (e)" unit="" value={collE} min={0.01} max={0.99} step={0.01} set={setCollE} color="#f59e0b" note="0 = stick together, 1 = elastic" />
                    )}
                  </>
                )}
              </div>
            </div>

            {/* Analytics */}
            <div className="space-y-3">
              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide mb-3">Results</p>
                <div className="space-y-2">
                  {topic === 'elevator' && [
                    { l: 'True weight', v: `${(elevMass * g).toFixed(1)} N`, c: 'text-gray-600' },
                    { l: 'Apparent weight', v: `${elevAppW.toFixed(1)} N`, c: elevAppW > elevMass * g ? 'text-emerald-600' : elevAppW < elevMass * g ? 'text-red-500' : 'text-indigo-600' },
                    { l: 'Difference', v: `${(elevAppW - elevMass * g).toFixed(1)} N`, c: 'text-amber-600' },
                    { l: 'Scale reads', v: `${(elevAppW / g).toFixed(2)} kg`, c: 'text-purple-600' },
                  ].map(r => (
                    <div key={r.l} className="flex justify-between items-center rounded-lg bg-gray-50 px-3 py-2">
                      <span className="text-xs text-gray-500">{r.l}</span>
                      <span className={`text-sm font-semibold ${r.c}`}>{r.v}</span>
                    </div>
                  ))}

                  {topic === 'weightlessness' && [
                    { l: 'True weight (Earth)', v: `${(elevMass * 9.81).toFixed(0)} N`, c: 'text-gray-600' },
                    { l: `g at ${wlHeight}km`, v: `${orbitG.toFixed(2)} m/s²`, c: 'text-indigo-600' },
                    { l: 'Weight at altitude', v: `${(elevMass * orbitG).toFixed(0)} N`, c: 'text-amber-600' },
                    { l: 'Apparent (orbit)', v: '0 N (free fall)', c: 'text-red-500' },
                  ].map(r => (
                    <div key={r.l} className="flex justify-between items-center rounded-lg bg-gray-50 px-3 py-2">
                      <span className="text-xs text-gray-500">{r.l}</span>
                      <span className={`text-sm font-semibold ${r.c}`}>{r.v}</span>
                    </div>
                  ))}

                  {topic === 'walking' && [
                    { l: 'Reaction force', v: frictionEnabled ? 'Present ✓' : 'None ✗', c: frictionEnabled ? 'text-emerald-600' : 'text-red-500' },
                    { l: 'Locomotion', v: frictionEnabled ? 'Possible ✓' : 'Impossible ✗', c: frictionEnabled ? 'text-emerald-600' : 'text-red-500' },
                    { l: 'Action', v: 'Foot pushes back', c: 'text-gray-600' },
                    { l: 'Reaction', v: frictionEnabled ? 'Ground pushes forward' : 'No reaction', c: frictionEnabled ? 'text-emerald-600' : 'text-red-500' },
                  ].map(r => (
                    <div key={r.l} className="flex justify-between items-center rounded-lg bg-gray-50 px-3 py-2">
                      <span className="text-xs text-gray-500">{r.l}</span>
                      <span className={`text-sm font-semibold ${r.c}`}>{r.v}</span>
                    </div>
                  ))}

                  {topic === 'propulsion' && [
                    { l: 'Thrust', v: `${rocketA.thrust.toFixed(0)} N`, c: 'text-amber-600' },
                    { l: 'Acceleration', v: `${rocketA.acceleration.toFixed(3)} m/s²`, c: 'text-indigo-600' },
                    { l: 'T = v_e × ṁ', v: `${exhaustSpeed}×${massFlowRate}=${rocketA.thrust.toFixed(0)}`, c: 'text-gray-600' },
                  ].map(r => (
                    <div key={r.l} className="flex justify-between items-center rounded-lg bg-gray-50 px-3 py-2">
                      <span className="text-xs text-gray-500">{r.l}</span>
                      <span className={`text-sm font-semibold ${r.c}`}>{r.v}</span>
                    </div>
                  ))}

                  {topic === 'collision' && [
                    { l: 'v₁ after', v: `${collRes.v1.toFixed(2)} m/s`, c: 'text-indigo-600' },
                    { l: 'v₂ after', v: `${collRes.v2.toFixed(2)} m/s`, c: 'text-emerald-600' },
                    { l: 'p before', v: `${collRes.momentumBefore.toFixed(2)} kg·m/s`, c: 'text-gray-600' },
                    { l: 'p after', v: `${collRes.momentumAfter.toFixed(2)} kg·m/s`, c: 'text-gray-600' },
                    { l: 'KE lost', v: `${collRes.keLost.toFixed(2)} J`, c: collRes.keLost < 0.01 ? 'text-emerald-600' : 'text-red-500' },
                    { l: 'Impulse', v: `${collRes.impulse.toFixed(2)} N·s`, c: 'text-amber-600' },
                  ].map(r => (
                    <div key={r.l} className="flex justify-between items-center rounded-lg bg-gray-50 px-3 py-2">
                      <span className="text-xs text-gray-500">{r.l}</span>
                      <span className={`text-sm font-semibold ${r.c}`}>{r.v}</span>
                    </div>
                  ))}
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

            {/* Teacher notes + exercises */}
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
