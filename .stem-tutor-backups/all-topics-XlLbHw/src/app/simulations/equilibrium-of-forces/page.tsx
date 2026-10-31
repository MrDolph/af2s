'use client';
import { useState, useCallback, useEffect, useRef } from 'react';
import { AppHeader } from '@/components/layout/AppHeader';
import { SimulationControls } from '@/components/simulation/SimulationControls';
import { StaticDynamicCanvas } from '@/components/simulation/StaticDynamicCanvas';
import { ConcurrentForcesCanvas } from '@/components/simulation/ConcurrentForcesCanvas';
import { ParallelForcesCanvas } from '@/components/simulation/ParallelForcesCanvas';
import { FloatingBodyCanvas, BLOCK_WIDTH_M } from '@/components/simulation/FloatingBodyCanvas';
import { EmbedButton } from '@/components/ui/EmbedButton';
import { useResponsiveCanvasSize } from '@/hooks/useResponsiveCanvasSize';
import {
  checkBalance, forceComponents, resultant, equilibrant, vecMagnitude, vecAngleDeg,
  netMoment, isBalanced, relativeDensity, submergedFraction, willFloat, upthrust,
  LIQUIDS, Weight,
} from '@/lib/physics/equilibrium';

type Topic = 'static-dynamic' | 'concurrent' | 'parallel' | 'floating';

const CURRICULA = ['WAEC', 'NECO', 'IGCSE', 'SAT', 'JUPEB'];
const CC: Record<string, string> = {
  WAEC: 'bg-indigo-100 text-indigo-700', NECO: 'bg-pink-100 text-pink-700',
  IGCSE: 'bg-emerald-100 text-emerald-700', SAT: 'bg-orange-100 text-orange-700',
  JUPEB: 'bg-purple-100 text-purple-700',
};

const TOPIC_META: Record<Topic, { title: string; icon: string; sub: string; eq: string }> = {
  'static-dynamic': { title: 'Static & dynamic', icon: '⚖️', sub: 'Equilibrium at rest vs at constant velocity', eq: 'ΣF = 0' },
  concurrent:       { title: 'Concurrent forces', icon: '📐', sub: 'Non-parallel coplanar forces on a point', eq: 'ΣFx = 0, ΣFy = 0' },
  parallel:         { title: 'Parallel forces',   icon: '⚡', sub: 'Moments — the principle of moments', eq: 'Σ(clockwise M) = Σ(anticlockwise M)' },
  floating:         { title: 'Floating bodies',   icon: '🛟', sub: 'Density, relative density, upthrust', eq: 'Upthrust = weight of fluid displaced' },
};

const TEACHER_NOTES: Record<Topic, string[]> = {
  'static-dynamic': [
    'Equilibrium means the resultant (net) force is zero — it does NOT mean the object is at rest. A common exam trap.',
    'STATIC equilibrium: net force = 0 AND the object is at rest (stays at rest).',
    'DYNAMIC equilibrium: net force = 0 but the object is already moving — it continues at constant velocity (Newton\u2019s 1st law).',
    'If the forces are unbalanced, the object accelerates — it does not matter whether it started at rest or already moving.',
    'Real examples of dynamic equilibrium: a car at cruising speed (driving force = resistive forces), a skydiver at terminal velocity (weight = air resistance).',
  ],
  concurrent: [
    'Concurrent forces act through the SAME point. For equilibrium, they must form a CLOSED polygon when drawn tip-to-tail — if there\u2019s a gap, that gap IS the resultant.',
    'Equivalently: resolve every force into x and y components — for equilibrium, ΣFx = 0 AND ΣFy = 0 separately.',
    'The equilibrant is the single extra force that would balance the others — equal in magnitude, exactly opposite in direction to the resultant.',
    'For just TWO forces in equilibrium: they must be equal in magnitude and exactly opposite in direction (180° apart) — the simplest case of the polygon rule.',
    'For THREE concurrent forces in equilibrium, a very common WAEC technique is Lami\u2019s theorem: each force is proportional to the sine of the angle between the other two.',
  ],
  parallel: [
    'The principle of moments: for equilibrium, the sum of clockwise moments about any point equals the sum of anticlockwise moments about that same point.',
    'Moment (torque) = force × perpendicular distance from the pivot. Bigger force OR bigger distance both increase the turning effect — this is why a spanner with a longer handle needs less force.',
    'A see-saw balances when W1×d1 = W2×d2 — a heavier person must sit closer to the pivot to balance a lighter person farther away.',
    'For a beam to be in COMPLETE equilibrium, moments must balance AND the total upward force (from the pivot/supports) must equal the total downward force (the weights) — two separate conditions.',
    'Choosing WHICH point to take moments about is a free choice in the maths — but choosing the pivot (or an unknown force\u2019s point of application) often eliminates an unknown and simplifies the equation.',
  ],
  floating: [
    'Archimedes\u2019 principle: the upthrust on a body in a fluid equals the weight of the fluid it displaces.',
    'A floating object displaces EXACTLY its own weight of fluid — that\u2019s why upthrust = weight for a floating body, giving zero net force (equilibrium).',
    'Relative density = density of a substance ÷ density of water. It has no units, and is numerically identical to density measured in g/cm³.',
    'An object floats if its density is LESS than the liquid\u2019s density, and sinks if its density is GREATER — equal densities give neutral buoyancy (stays wherever placed, fully submerged).',
    'Ships made of steel float because their overall SHAPE (hollow hull) gives them a low average density, even though steel itself is far denser than water — density of the whole object matters, not the material alone.',
  ],
};

const EXERCISES: Record<Topic, { q: string; a: string }[]> = {
  'static-dynamic': [
    { q: 'A car travels at a constant 60 km/h on a straight, flat road. What can you say about the resultant force on it?', a: 'It is zero — constant velocity means the car is in dynamic equilibrium, so the driving force exactly equals the total resistive forces (friction + air resistance).' },
    { q: 'A book rests on a table. Name the two forces in equilibrium and state their relationship.', a: 'Weight (down) and the normal reaction from the table (up). They are equal in magnitude and opposite in direction, giving a zero resultant — static equilibrium.' },
    { q: 'Explain why "equilibrium" and "at rest" are not the same thing, using an example.', a: 'Equilibrium only requires zero resultant force. A parachutist falling at terminal velocity is in equilibrium (weight = air resistance) but is clearly not at rest — this is dynamic equilibrium.' },
  ],
  concurrent: [
    { q: 'Two forces of 6N and 8N act at right angles to each other at a point. Find their resultant.', a: 'R = √(6²+8²) = √(36+64) = √100 = 10N (a 3-4-5 triangle scaled up).' },
    { q: 'A force of 10N acts at 0° and a second force of 10N acts at 180°. Are they in equilibrium? Explain.', a: 'Yes — equal magnitude, exactly opposite direction, so their resultant is zero. This is the equilibrium condition for two concurrent forces.' },
    { q: 'Three forces of equal magnitude act on a point, all in equilibrium. What must be true about the angles between them?', a: 'They must be arranged symmetrically at 120° to each other (like the letter Y) — this is the only way three equal forces can form a closed triangle.' },
  ],
  parallel: [
    { q: 'A 40N weight sits 0.6m from a pivot on one side of a beam. Find the weight needed 0.8m from the pivot on the other side to balance it.', a: 'Principle of moments: 40×0.6 = W×0.8. W = 24/0.8 = 30N.' },
    { q: 'A spanner has a handle 0.25m long. What force is needed to produce a moment of 15N·m on a bolt?', a: 'M = F×d, so F = M/d = 15/0.25 = 60N.' },
    { q: 'Two children sit on a see-saw: a 300N child 1.5m from the pivot, and a 450N child on the other side. How far from the pivot must the second child sit to balance?', a: '300×1.5 = 450×d. d = 450/450 = 1m.' },
  ],
  floating: [
    { q: 'A block of density 800 kg/m³ floats in water (1000 kg/m³). What fraction of its volume is submerged?', a: 'Fraction submerged = ρ_object/ρ_liquid = 800/1000 = 0.8 = 80%.' },
    { q: 'An object has a relative density of 2.7. What is its actual density?', a: 'Relative density = density/density of water, so density = 2.7×1000 = 2700 kg/m³ (this is aluminium).' },
    { q: 'A 500 cm³ block of wood (density 600 kg/m³) floats in water. Find the upthrust acting on it.', a: 'At equilibrium, upthrust = weight = mg = (0.6 kg/m³ × 0.0005 m³ shortcut: mass=600×0.0005=0.3kg) × 9.81 ≈ 2.94N.' },
    { q: 'Explain, using density, why a steel ship floats but a solid steel block sinks.', a: 'The ship\u2019s hollow hull encloses a large volume of air, giving the ship as a whole a much lower AVERAGE density than solid steel — low enough to be less than water\u2019s density, so it floats. A solid steel block has no such air space, so its density (about 7800 kg/m³) stays far above water\u2019s and it sinks.' },
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

export default function EquilibriumOfForcesPage() {
  const [topic, setTopic] = useState<Topic>('static-dynamic');
  const [isRunning, setIsRunning] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const [resetKey, setResetKey] = useState(0);
  const [openEx, setOpenEx] = useState<number | null>(null);
  const [activeCurricula, setActiveCurricula] = useState(['WAEC', 'IGCSE', 'SAT']);

  // Static / dynamic
  const [scenario, setScenario] = useState<'static' | 'dynamic'>('static');
  const [sdF1, setSdF1] = useState(15);
  const [sdF2, setSdF2] = useState(15);
  const [sdMass, setSdMass] = useState(5);
  const [liveSd, setLiveSd] = useState({ v: 0 });

  // Concurrent
  const [magA, setMagA] = useState(10);
  const [angleA, setAngleA] = useState(0);
  const [magB, setMagB] = useState(10);
  const [angleB, setAngleB] = useState(90);

  // Parallel / moments
  const [w1Force, setW1Force] = useState(20);
  const [w1Pos, setW1Pos] = useState(-0.6);
  const [w2Force, setW2Force] = useState(20);
  const [w2Pos, setW2Pos] = useState(0.6);
  const weights: Weight[] = [{ force: w1Force, position: w1Pos }, { force: w2Force, position: w2Pos }];
  const [liveTilt, setLiveTilt] = useState(0);

  // Floating
  const [objDensity, setObjDensity] = useState(600);
  const [liqIdx, setLiqIdx] = useState(0);
  const [blockHeight, setBlockHeight] = useState(0.2);
  const liquid = LIQUIDS[liqIdx];
  const [liveSubmerged, setLiveSubmerged] = useState(0);

  const reset = useCallback(() => {
    setIsRunning(false); setIsPaused(false); setResetKey(k => k + 1);
    setLiveSd({ v: 0 }); setLiveTilt(0); setLiveSubmerged(0);
  }, []);

  const resetTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  useEffect(() => {
    if (resetTimer.current) clearTimeout(resetTimer.current);
    resetTimer.current = setTimeout(reset, 100);
  }, [topic, scenario, sdF1, sdF2, sdMass, magA, angleA, magB, angleB, w1Force, w1Pos, w2Force, w2Pos, objDensity, liqIdx, blockHeight, reset]);

  const canvasBoxRef = useRef<HTMLDivElement>(null);
  const canvasSize = useResponsiveCanvasSize(canvasBoxRef, 660, topic === 'floating' ? 300 : topic === 'concurrent' ? 300 : 260, 900);

  const lastTickRef = useRef(0);
  const handleSdTick = useCallback((v: number) => {
    const now = performance.now();
    if (now - lastTickRef.current < 60) return;
    lastTickRef.current = now;
    setLiveSd({ v });
  }, []);
  const handleTiltTick = useCallback((angleDeg: number) => {
    const now = performance.now();
    if (now - lastTickRef.current < 60) return;
    lastTickRef.current = now;
    setLiveTilt(angleDeg);
  }, []);
  const handleFloatTick = useCallback((frac: number) => {
    const now = performance.now();
    if (now - lastTickRef.current < 60) return;
    lastTickRef.current = now;
    setLiveSubmerged(frac);
  }, []);

  const sdBal = checkBalance(sdF1, sdF2);
  const A = forceComponents(magA, angleA);
  const B = forceComponents(magB, angleB);
  const R = resultant([A, B]);
  const Eq = equilibrant([A, B]);
  const netM = netMoment(weights);
  const balanced = isBalanced(weights);

  return (
    <>
      <AppHeader />
      <main className="min-h-screen bg-gray-50">
        <section className="border-b border-gray-200 bg-white">
          <div className="mx-auto max-w-[100rem] px-4 sm:px-6 py-4">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
              <div>
                <p className="text-xs text-gray-400 mb-0.5">Mechanics</p>
                <h1 className="text-lg font-semibold text-gray-900">Equilibrium of forces</h1>
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
                {topic === 'static-dynamic' && (
                  <StaticDynamicCanvas key={resetKey} scenario={scenario} f1={sdF1} f2={sdF2} mass={sdMass}
                    isRunning={isRunning} isPaused={isPaused} onTick={handleSdTick}
                    width={canvasSize.width} height={canvasSize.height} />
                )}
                {topic === 'concurrent' && (
                  <ConcurrentForcesCanvas key={resetKey} magA={magA} angleA={angleA} magB={magB} angleB={angleB}
                    isRunning={isRunning} isPaused={isPaused}
                    width={canvasSize.width} height={canvasSize.height} />
                )}
                {topic === 'parallel' && (
                  <ParallelForcesCanvas key={resetKey} weights={weights}
                    isRunning={isRunning} isPaused={isPaused} onTick={handleTiltTick}
                    width={canvasSize.width} height={canvasSize.height} />
                )}
                {topic === 'floating' && (
                  <FloatingBodyCanvas key={resetKey} objDensity={objDensity} liquidDensity={liquid.density}
                    liquidName={liquid.name} blockHeight={blockHeight}
                    isRunning={isRunning} isPaused={isPaused} onTick={handleFloatTick}
                    width={canvasSize.width} height={canvasSize.height} />
                )}
              </div>

              <div className="flex flex-wrap items-center justify-between gap-2">
                <SimulationControls isRunning={isRunning} isPaused={isPaused}
                  onRun={() => { setIsRunning(true); setIsPaused(false); }}
                  onPause={() => setIsPaused(p => !p)} onReset={reset} />
                <EmbedButton path="/embed/equilibrium"
                  title={`${TOPIC_META[topic].title} — A-Factor STEM Studio`}
                  params={
                    topic === 'static-dynamic' ? { topic, scenario, f1: sdF1, f2: sdF2, mass: sdMass }
                    : topic === 'concurrent' ? { topic, magA, angleA, magB, angleB }
                    : topic === 'parallel' ? { topic, w1f: w1Force, w1p: w1Pos, w2f: w2Force, w2p: w2Pos }
                    : { topic, density: objDensity, liquid: liqIdx, h: blockHeight }
                  } />
              </div>

              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm space-y-4">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide">Parameters</p>

                {topic === 'static-dynamic' && <>
                  <div className="flex gap-2">
                    {(['static', 'dynamic'] as const).map(sc => (
                      <button key={sc} onClick={() => setScenario(sc)}
                        className={`flex-1 rounded-lg border px-2 py-2 text-xs font-medium capitalize transition ${
                          scenario === sc ? 'border-indigo-300 bg-indigo-50 text-indigo-700' : 'border-gray-200 bg-white text-gray-500'
                        }`}>{sc}</button>
                    ))}
                  </div>
                  <Slider label="Force F₁ (right-pulling)" unit="N" value={sdF1} min={0} max={30} step={0.5} set={setSdF1} color="#10b981" />
                  <Slider label="Force F₂ (left-pulling)" unit="N" value={sdF2} min={0} max={30} step={0.5} set={setSdF2} color="#ef4444" />
                  <Slider label="Mass" unit="kg" value={sdMass} min={1} max={20} step={0.5} set={setSdMass} color="#6366f1" />
                </>}

                {topic === 'concurrent' && <>
                  <Slider label="Force A" unit="N" value={magA} min={1} max={20} step={0.5} set={setMagA} color="#6366f1" />
                  <Slider label="Angle A" unit="°" value={angleA} min={0} max={359} step={1} set={setAngleA} color="#818cf8" />
                  <Slider label="Force B" unit="N" value={magB} min={1} max={20} step={0.5} set={setMagB} color="#10b981" />
                  <Slider label="Angle B" unit="°" value={angleB} min={0} max={359} step={1} set={setAngleB} color="#34d399" note="0° = along +x axis, measured anticlockwise" />
                </>}

                {topic === 'parallel' && <>
                  <Slider label="Weight 1" unit="N" value={w1Force} min={0} max={50} step={1} set={setW1Force} color="#6366f1" />
                  <Slider label="Position 1" unit="m" value={w1Pos} min={-2} max={2} step={0.1} set={setW1Pos} color="#818cf8" note="Negative = left of pivot" />
                  <Slider label="Weight 2" unit="N" value={w2Force} min={0} max={50} step={1} set={setW2Force} color="#10b981" />
                  <Slider label="Position 2" unit="m" value={w2Pos} min={-2} max={2} step={0.1} set={setW2Pos} color="#34d399" note="Positive = right of pivot" />
                </>}

                {topic === 'floating' && <>
                  <div className="flex flex-wrap gap-1.5">
                    {LIQUIDS.map((l, i) => (
                      <button key={l.name} onClick={() => setLiqIdx(i)}
                        className={`rounded-full border px-2.5 py-2 text-[11px] font-medium transition ${
                          liqIdx === i ? 'border-indigo-300 bg-indigo-50 text-indigo-700' : 'border-gray-200 bg-white text-gray-500 hover:border-indigo-200'
                        }`}>{l.name} ({l.density})</button>
                    ))}
                  </div>
                  <Slider label="Object density" unit="kg/m³" value={objDensity} min={100} max={12000} step={50} set={setObjDensity} color="#a78bfa" />
                  <Slider label="Block height" unit="m" value={blockHeight} min={0.05} max={0.4} step={0.01} set={setBlockHeight} color="#f59e0b" />
                </>}
              </div>
            </div>

            <div className="space-y-3">
              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide mb-3">Calculated</p>
                <div className="space-y-2">
                  {topic === 'static-dynamic' && <>
                    <StatRow label="Net force" value={sdBal.netForce.toFixed(1)} unit="N" color="text-indigo-600" />
                    <StatRow label="State" value={sdBal.equilibrium ? 'equilibrium' : 'unbalanced'} unit="" color={sdBal.equilibrium ? 'text-emerald-600' : 'text-amber-600'} />
                    <StatRow label="Acceleration" value={(sdBal.netForce / sdMass).toFixed(2)} unit="m/s²" color="text-rose-500" />
                    <StatRow label="Live speed" value={liveSd.v.toFixed(2)} unit="m/s" color="text-purple-600" />
                  </>}
                  {topic === 'concurrent' && <>
                    <StatRow label="Resultant |R|" value={vecMagnitude(R).toFixed(2)} unit="N" color="text-indigo-600" />
                    <StatRow label="Resultant angle" value={vecAngleDeg(R).toFixed(1)} unit="°" color="text-emerald-600" />
                    <StatRow label="Equilibrant |E|" value={vecMagnitude(Eq).toFixed(2)} unit="N" color="text-rose-500" />
                    <StatRow label="Equilibrant angle" value={vecAngleDeg(Eq).toFixed(1)} unit="°" color="text-purple-600" />
                  </>}
                  {topic === 'parallel' && <>
                    <StatRow label="Net moment" value={netM.toFixed(2)} unit="N·m" color="text-indigo-600" />
                    <StatRow label="State" value={balanced ? 'balanced' : 'unbalanced'} unit="" color={balanced ? 'text-emerald-600' : 'text-amber-600'} />
                    <StatRow label="Live tilt" value={liveTilt.toFixed(1)} unit="°" color="text-purple-600" />
                  </>}
                  {topic === 'floating' && <>
                    <StatRow label="Relative density" value={relativeDensity(objDensity).toFixed(2)} unit="" color="text-indigo-600" />
                    <StatRow label="Will it float?" value={willFloat(objDensity, liquid.density) ? 'yes' : 'no — sinks'} unit="" color={willFloat(objDensity, liquid.density) ? 'text-emerald-600' : 'text-red-500'} />
                    <StatRow label="Submerged fraction" value={(submergedFraction(objDensity, liquid.density) * 100).toFixed(0)} unit="%" color="text-purple-600" />
                    <StatRow label="Live submerged" value={(liveSubmerged * 100).toFixed(0)} unit="%" color="text-amber-600" />
                    <StatRow label="Upthrust (floating)" value={upthrust(liquid.density, BLOCK_WIDTH_M * blockHeight * submergedFraction(objDensity, liquid.density)).toFixed(1)} unit="N" color="text-rose-500" />
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
