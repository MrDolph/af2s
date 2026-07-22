'use client';
import { useState, useCallback, useRef, useEffect } from 'react';
import { AppHeader } from '@/components/layout/AppHeader';
import { SimulationControls } from '@/components/simulation/SimulationControls';
import { EmbedButton } from '@/components/ui/EmbedButton';
import { PendulumCanvas } from '@/components/simulation/PendulumCanvas';
import { SpringCanvas } from '@/components/simulation/SpringCanvas';
import { ConicalPendulumCanvas } from '@/components/simulation/ConicalPendulumCanvas';
import { PhysicalPendulumCanvas } from '@/components/simulation/PhysicalPendulumCanvas';
import { BifilarCanvas } from '@/components/simulation/BifilarCanvas';
import { useResponsiveCanvasSize } from '@/hooks/useResponsiveCanvasSize';
import { SHMGraph } from '@/components/simulation/SHMGraph';
import {
  pendulumOmega, pendulumPeriod,
  springOmega, springPeriod, springStaticExtension,
  conicalPendulumOmega, conicalPendulumPeriod, conicalPendulumTension, conicalPendulumSpeed,
  physicalPendulumPeriod, rodPendulumPeriod,
  bifilarPeriodSimple, cantileverStiffness, cantileverDeflection, cantileverPeriod,
} from '@/lib/physics/shm';

type Topic = 'pendulum' | 'spring' | 'conical' | 'physical' | 'bifilar';
type GraphMode = 'displacement' | 'velocity' | 'acceleration' | 'energy' | 'phase';

const CURRICULA = ['WAEC', 'NECO', 'IGCSE', 'SAT', 'JUPEB'];
const CC: Record<string, string> = {
  WAEC: 'bg-indigo-100 text-indigo-700', NECO: 'bg-pink-100 text-pink-700',
  IGCSE: 'bg-emerald-100 text-emerald-700', SAT: 'bg-orange-100 text-orange-700',
  JUPEB: 'bg-purple-100 text-purple-700',
};

const TOPIC_META: Record<Topic, { title: string; icon: string; sub: string; eq: string }> = {
  pendulum: { title: 'Simple pendulum',       icon: '⏱️', sub: 'SHM for small angles', eq: 'T = 2π√(L/g)' },
  spring:   { title: 'Loaded spring',         icon: '🌀', sub: 'Mass-spring system',    eq: 'T = 2π√(m/k)' },
  conical:  { title: 'Conical pendulum',      icon: '🔄', sub: 'Circular motion + tension', eq: 'ω² = g/(L cosθ)' },
  physical: { title: 'Physical pendulum',     icon: '📏', sub: 'Extended rigid body',   eq: 'T = 2π√(I/mgd)' },
  bifilar:  { title: 'Bifilar / Cantilever',  icon: '🏗️', sub: 'Torsion & beam flexure', eq: 'T = 2π√(Il/mgd²)' },
};

const TEACHER_NOTES: Record<Topic, string[]> = {
  pendulum: [
    "Period T = 2π√(L/g) is INDEPENDENT of mass and amplitude (for small angles < 15°).",
    "This independence of mass is why a pendulum makes a good clock — it keeps time regardless of the bob.",
    "For large amplitudes, the period increases — the small-angle approximation (sinθ ≈ θ) breaks down.",
    "On the Moon (g=1.6 m/s²), the same pendulum runs ~2.5× slower. The gravity slider demonstrates this.",
    "A seconds pendulum (T=2s) has length L = g/π² ≈ 0.993m — almost exactly 1 metre.",
  ],
  spring: [
    "T = 2π√(m/k): period increases with mass, decreases with spring stiffness. Mass affects it; length does not.",
    "The static extension x₀ = mg/k gives the equilibrium position. SHM occurs about this point.",
    "Hooke's Law F = kx and SHM are directly linked: F = −kx gives a = −(k/m)x → ω² = k/m.",
    "Energy: at equilibrium (x=0) all energy is KE. At amplitude (x=A) all energy is PE. Total E = ½mω²A² always.",
    "The phase space graph (v vs x) is an ellipse — a perfect circle if axes are scaled to same range.",
  ],
  conical: [
    "The bob moves in a horizontal circle — this is NOT SHM, but links circular motion to pendulums.",
    "Key equations: T cosθ = mg (vertical), T sinθ = mω²r (horizontal). Dividing: tanθ = ω²r/g.",
    "As ω increases, θ increases (bob rises). As θ → 90°, r → L and ω → ∞ (impossible in practice).",
    "Period decreases as angle increases: T = 2π√(L cosθ / g). Faster spin = shorter period.",
    "Good link to centripetal force: the horizontal component of tension provides centripetal force.",
  ],
  physical: [
    "A physical pendulum uses the full rigid-body rotation: T = 2π√(I/mgd) where I is about the pivot.",
    "For a uniform rod pivoted at the end: I = mL²/3, d = L/2 → T = 2π√(2L/3g). Compare to simple T = 2π√(L/g).",
    "The physical pendulum always has a longer period than the simple pendulum of the same length.",
    "There are two pivot points that give the same period — the 'centre of oscillation' concept used in precision timing.",
    "The equivalent simple pendulum length L_eq = I/(md). This is what IGCSE/JUPEB exam questions test.",
  ],
  bifilar: [
    "Bifilar suspension: a rod hung by two parallel wires undergoes TORSIONAL oscillation (twisting).",
    "T = (2π/d)√(Il/mg) where d = half wire separation, l = wire length, I = moment of inertia.",
    "Used to measure moment of inertia experimentally: measure T, know l and d, solve for I.",
    "Cantilever beam: one end fixed, free end deflects under load. Stiffness k = 3EI/L³.",
    "Cantilever vibration period T = 2π√(m_eff/k). The effective mass ≈ 0.24 × beam mass + tip mass.",
  ],
};

const EXERCISES: Record<Topic, { q: string; a: string }[]> = {
  pendulum: [
    { q: "A pendulum has period 2s on Earth (g=9.81 m/s²). Find its length.", a: "T=2π√(L/g) → L=g(T/2π)²=9.81×(2/2π)²=9.81×0.1013=0.993m ≈ 1m" },
    { q: "A 2m pendulum is taken to a planet where g=4 m/s². Find the new period.", a: "T=2π√(L/g)=2π√(2/4)=2π×0.707=4.44s" },
    { q: "Why does doubling the mass of a pendulum bob not change its period?", a: "Both restoring force and inertia scale with mass, so they cancel in the period equation T=2π√(L/g) — mass doesn't appear." },
  ],
  spring: [
    { q: "A 0.5kg mass on a spring of k=200 N/m. Find period and frequency.", a: "T=2π√(m/k)=2π√(0.5/200)=2π×0.05=0.314s. f=1/T=3.18Hz" },
    { q: "A spring extends 0.05m under a 2kg load (g=10 m/s²). Find k and the SHM period.", a: "k=F/x=mg/x=20/0.05=400 N/m. T=2π√(2/400)=2π×0.0707=0.444s" },
    { q: "A spring-mass system has total energy 0.4J and amplitude 0.1m. Find the spring constant k.", a: "E=½kA² → k=2E/A²=2×0.4/0.01=80 N/m" },
  ],
  conical: [
    { q: "A conical pendulum of length 0.5m makes angle 30° with vertical. Find ω and period. (g=10)", a: "ω=√(g/Lcosθ)=√(10/0.5×cos30°)=√(10/0.433)=√23.1=4.81 rad/s. T=2π/ω=1.31s" },
    { q: "Find the tension in the string of a 0.2kg bob at θ=45°. (g=10)", a: "T=mg/cosθ=0.2×10/cos45°=2/0.707=2.83N" },
    { q: "As the angular velocity of a conical pendulum increases, what happens to the angle θ?", a: "θ increases — the bob rises outward. Since ω²=g/(Lcosθ), larger ω requires smaller cosθ, meaning larger θ." },
  ],
  physical: [
    { q: "A uniform rod of length 1.2m and mass 0.5kg is pivoted at one end. Find the period. (g=9.81)", a: "I=mL²/3=0.5×1.44/3=0.24 kg·m². d=L/2=0.6m. T=2π√(I/mgd)=2π√(0.24/0.5×9.81×0.6)=2π×0.285=1.79s" },
    { q: "Compare this to a simple pendulum of the same length.", a: "T_simple=2π√(1.2/9.81)=2π×0.350=2.20s. The physical pendulum (1.79s) is FASTER — its effective length is 2L/3=0.8m, shorter than L." },
    { q: "What is the equivalent simple pendulum length for a uniform rod pivoted at one end?", a: "L_eq=I/(md)=(mL²/3)/(m×L/2)=2L/3. For L=1.2m: L_eq=0.8m." },
  ],
  bifilar: [
    { q: "A 2kg rod (L=0.6m) hangs on wires of length 1m, separation 0.4m. Find the period.", a: "I=mL²/12=2×0.36/12=0.06 kg·m². T=2π√(Il/mgd²)=2π√(0.06×1/2×9.81×0.04)=2π√(0.0765)=2π×0.277=1.74s" },
    { q: "A cantilever beam: E=200GPa, b=30mm, h=5mm, L=0.5m. Find stiffness k.", a: "I_beam=bh³/12=0.03×(0.005)³/12=3.125×10⁻¹⁰m⁴. k=3EI/L³=3×200×10⁹×3.125×10⁻¹⁰/0.125=1500 N/m" },
    { q: "Why is bifilar suspension used to measure moment of inertia experimentally?", a: "The period T=(2π/d)√(Il/mg) can be rearranged to I=mgd²T²/(4π²l). By measuring T and knowing all other quantities, I is found without needing to integrate over the shape." },
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

export default function OscillationsPage() {
  const [topic, setTopic] = useState<Topic>('pendulum');
  const [isRunning, setIsRunning] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const [resetKey, setResetKey] = useState(0);
  const [openEx, setOpenEx] = useState<number | null>(null);
  const [activeCurricula, setActiveCurricula] = useState(['WAEC', 'IGCSE', 'JUPEB']);
  const [graphMode, setGraphMode] = useState<GraphMode>('displacement');
  const [currentT, setCurrentT] = useState(0);

  // Pendulum params
  const [pendL, setPendL] = useState(1.0);
  const [pendA, setPendA] = useState(15);
  const [pendG, setPendG] = useState(9.81);
  const [pendM, setPendM] = useState(0.5);

  // Spring params
  const [spK, setSpK] = useState(50);
  const [spM, setSpM] = useState(1.0);
  const [spA, setSpA] = useState(0.1);

  // Conical params
  const [conL, setConL] = useState(0.8);
  const [conTheta, setConTheta] = useState(30);
  const [conM, setConM] = useState(0.3);

  // Physical pendulum params
  const [physL, setPhysL] = useState(1.0);
  const [physM, setPhysM] = useState(0.5);
  const [physPF, setPhysPF] = useState(0); // pivot fraction from top (0=top end, 0.5=centre)

  // Bifilar/Cantilever params
  const [bifMode, setBifMode] = useState<'bifilar' | 'cantilever'>('bifilar');
  const [bifM, setBifM] = useState(2);
  const [bifL, setBifL] = useState(0.6);
  const [bifWire, setBifWire] = useState(1.0);
  const [bifSep, setBifSep] = useState(0.3);
  const [cantL, setCantL] = useState(0.5);
  const [cantH, setCantH] = useState(10); // mm
  const [cantLoad, setCantLoad] = useState(5);

  // Derived analytics
  const pendOmega = pendulumOmega(pendL, pendG);
  const pendT = pendulumPeriod(pendL, pendG);
  const spOmega = springOmega(spK, spM);
  const spT = springPeriod(spK, spM);
  const spStaticX = springStaticExtension(spM, spK);
  const conOmega = conicalPendulumOmega(conL, conTheta * Math.PI / 180);
  const conT = conicalPendulumPeriod(conL, conTheta * Math.PI / 180);
  const conTens = conicalPendulumTension(conM, conTheta * Math.PI / 180);
  const conSpeed = conicalPendulumSpeed(conL, conTheta * Math.PI / 180);
  // Pivot-dependent — must mirror PhysicalPendulumCanvas exactly, otherwise
  // the graph's ω differs from the canvas's ω whenever the pivot slider moves
  // and the live dot drifts off the rod's motion.
  const physD = Math.max(Math.abs(physL / 2 - physPF * physL), 0.001);
  const physI = physM * physL * physL / 12 + physM * physD * physD;
  const physT_actual = physicalPendulumPeriod(physI, physM, physD);
  const physT_simple = rodPendulumPeriod(physL);
  const bifT = bifilarPeriodSimple(bifM, bifL, bifWire, bifSep / 2);
  const cantK = cantileverStiffness(200e9, 0.03, cantH / 1000, cantL);
  const cantDef = cantileverDeflection(cantLoad, 200e9, 0.03, cantH / 1000, cantL);
  const cantT = cantileverPeriod(1, 200e9, 0.03, cantH / 1000, cantL);

  // Graph data — omega/A must match what the canvas actually animates so the
  // live dot on the curve tracks the mass/bob/rod exactly.
  const bifOmega = bifMode === 'bifilar' ? 2 * Math.PI / bifT : 2 * Math.PI / cantT;
  const graphA = topic === 'pendulum' ? pendA * Math.PI / 180 * pendL :
                 topic === 'spring' ? spA :
                 topic === 'physical' ? 0.25 :          // rad — canvas uses A_rad = 0.25
                 bifMode === 'bifilar' ? 0.3 :           // rad — bifilar canvas uses 0.3
                 0.3 * cantDef;                          // m — cantilever tip oscillates ±0.3·δ
  const graphOmega = topic === 'pendulum' ? pendOmega :
                     topic === 'spring' ? spOmega :
                     topic === 'physical' ? 2 * Math.PI / physT_actual :
                     bifOmega;
  const graphM = topic === 'pendulum' ? pendM : topic === 'spring' ? spM :
                 topic === 'physical' ? physM : bifM;
  const graphK = topic === 'pendulum' ? pendM * pendOmega * pendOmega :
                 topic === 'spring' ? spK :
                 graphM * graphOmega * graphOmega;

  const resetTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const reset = useCallback(() => {
    setIsRunning(false); setIsPaused(false);
    setResetKey(k => k + 1); setCurrentT(0);
  }, []);

  useEffect(() => {
    if (resetTimer.current) clearTimeout(resetTimer.current);
    resetTimer.current = setTimeout(reset, 100);
  }, [topic, pendL, pendA, pendG, pendM, spK, spM, spA, conL, conTheta, conM, physL, physM, physPF, bifM, bifL, bifWire, bifSep, cantL, cantH, cantLoad, bifMode, reset]);

  // Throttle marker updates to ~12fps. Updating React state on every
  // animation frame re-rendered the whole page (and the Recharts graph)
  // 60+ times a second — the graph would visibly stutter and lag behind
  // the canvas. The canvas itself animates via its own rAF loop and is
  // unaffected by this throttle.
  const lastTickRef = useRef(0);
  const handleTick = useCallback((t: number) => {
    const now = performance.now();
    if (now - lastTickRef.current > 40) {
      lastTickRef.current = now;
      setCurrentT(t);
    }
  }, []);

  // Each topic was tuned with its own aspect ratio (spring is a tall,
  // portrait-ish demo; the others are wider) — pick the matching base
  // before scaling it up to fill the available width.
  const oscBase = topic === 'spring' ? { w: 280, h: 320 }
    : topic === 'bifilar' ? { w: 380, h: 280 }
    : { w: 380, h: 300 };
  const canvasBoxRef = useRef<HTMLDivElement>(null);
  const canvasSize = useResponsiveCanvasSize(canvasBoxRef, oscBase.w, oscBase.h, 650);

  return (
    <>
      <AppHeader />
      <main className="min-h-screen bg-gray-50">
        <section className="border-b border-gray-200 bg-white">
          <div className="mx-auto max-w-[100rem] px-4 sm:px-6 py-4">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
              <div>
                <p className="text-xs text-gray-400 mb-0.5">Mechanics — Oscillations</p>
                <h1 className="text-lg font-semibold text-gray-900">Simple Harmonic Motion</h1>
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

          {/* Topic tabs */}
          <div className="flex gap-1 bg-gray-100 p-1 rounded-xl overflow-x-auto">
            {(Object.keys(TOPIC_META) as Topic[]).map(t => (
              <button key={t} onClick={() => { setTopic(t); setOpenEx(null); setGraphMode('displacement'); }}
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
            <span className="text-sm font-semibold font-mono text-gray-900">{TOPIC_META[topic].eq}</span>
            {topic !== 'conical' && (
              <span className="text-xs text-gray-400 ml-2">a = −ω²x &nbsp;|&nbsp; x = A cos(ωt)</span>
            )}
          </div>

          {/* Main grid */}
          <div className="grid grid-cols-1 lg:grid-cols-[1fr_220px] xl:grid-cols-[1fr_220px_260px] gap-4">

            {/* Canvas + graph + controls + sliders */}
            <div className="space-y-3 min-w-0">

              {/* Canvas */}
              <div ref={canvasBoxRef} className="rounded-2xl border border-gray-200 bg-white p-3 shadow-sm">
                {topic === 'pendulum' && (
                  <PendulumCanvas key={resetKey} length={pendL} amplitude={pendA}
                    gravity={pendG} mass={pendM}
                    isRunning={isRunning} isPaused={isPaused}
                    onTick={(t) => handleTick(t)}
                    width={canvasSize.width} height={canvasSize.height} />
                )}
                {topic === 'spring' && (
                  <SpringCanvas key={resetKey} k={spK} mass={spM} amplitude={spA}
                    isRunning={isRunning} isPaused={isPaused}
                    onTick={(t) => handleTick(t)}
                    width={canvasSize.width} height={canvasSize.height} />
                )}
                {topic === 'conical' && (
                  <ConicalPendulumCanvas key={resetKey} length={conL} theta_deg={conTheta}
                    mass={conM} isRunning={isRunning} isPaused={isPaused}
                    width={canvasSize.width} height={canvasSize.height} />
                )}
                {topic === 'physical' && (
                  <PhysicalPendulumCanvas key={resetKey} length={physL} mass={physM}
                    pivotFraction={physPF} isRunning={isRunning} isPaused={isPaused}
                    onTick={(t) => handleTick(t)}
                    width={canvasSize.width} height={canvasSize.height} />
                )}
                {topic === 'bifilar' && (
                  <div className="space-y-2">
                    <div className="flex gap-1 bg-gray-100 p-1 rounded-xl w-fit">
                      {(['bifilar', 'cantilever'] as const).map(m => (
                        <button key={m} onClick={() => setBifMode(m)}
                          className={`px-4 py-1.5 rounded-lg text-xs font-medium transition capitalize ${
                            bifMode === m ? 'bg-white text-indigo-700 shadow-sm' : 'text-gray-500'
                          }`}>{m}</button>
                      ))}
                    </div>
                    <BifilarCanvas key={`${resetKey}-${bifMode}`}
                      mode={bifMode} mass={bifM} rodLength={bifL}
                      wireLength={bifWire} separation={bifSep}
                      beamLength={cantL} beamWidth={30} beamHeight={cantH}
                      youngModulus={200} load={cantLoad}
                      isRunning={isRunning} isPaused={isPaused}
                      onTick={(t) => handleTick(t)}
                      width={canvasSize.width} height={canvasSize.height} />
                  </div>
                )}
              </div>

              {/* Controls */}
              <div className="flex flex-wrap items-center justify-between gap-2">
                <SimulationControls
                  isRunning={isRunning} isPaused={isPaused}
                  onRun={() => { setIsRunning(true); setIsPaused(false); }}
                  onPause={() => setIsPaused(p => !p)}
                  onReset={reset}
                />
                {topic !== 'bifilar' && (
                  <EmbedButton
                    path="/embed/oscillations"
                    title={`${TOPIC_META[topic].title} — A-Factor STEM Studio`}
                    params={
                      topic === 'pendulum' ? { topic, L: pendL, A: pendA, g: pendG, m: pendM } :
                      topic === 'spring'   ? { topic, k: spK, m: spM, A: spA } :
                      topic === 'conical'  ? { topic, L: conL, theta: conTheta, m: conM } :
                      { topic, L: physL, m: physM, pf: physPF }
                    }
                  />
                )}
              </div>

              {/* Graph */}
              {topic !== 'conical' && (
                <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                  <div className="flex items-center justify-between mb-3 flex-wrap gap-2">
                    <p className="text-xs font-medium text-gray-400 uppercase tracking-wide">Graph</p>
                    <div className="flex gap-1 bg-gray-100 p-0.5 rounded-lg overflow-x-auto">
                      {(['displacement', 'velocity', 'acceleration', 'energy', 'phase'] as GraphMode[]).map(gm => (
                        <button key={gm} onClick={() => setGraphMode(gm)}
                          className={`shrink-0 px-2.5 py-1 rounded-md text-[10px] font-medium transition ${
                            graphMode === gm ? 'bg-white text-indigo-700 shadow-sm' : 'text-gray-500'
                          }`}>
                          {gm === 'displacement' ? 'x–t' : gm === 'velocity' ? 'v–t' : gm === 'acceleration' ? 'a–t' : gm === 'energy' ? 'Energy' : 'Phase (v–x)'}
                        </button>
                      ))}
                    </div>
                  </div>
                  <SHMGraph A={graphA} omega={graphOmega} m={graphM} k={graphK}
                    mode={graphMode} currentT={currentT} />
                  <p className="text-[10px] text-gray-400 mt-2 text-center">
                    {graphMode === 'displacement' && 'Cosine wave — starts at +A, returns to +A each period T'}
                    {graphMode === 'velocity' && 'Sine wave — 90° ahead of displacement. Maximum at x=0'}
                    {graphMode === 'acceleration' && 'Cosine wave — always opposite to displacement (a = −ω²x)'}
                    {graphMode === 'energy' && 'KE and PE exchange; total energy E = ½mω²A² = constant (dashed)'}
                    {graphMode === 'phase' && 'Ellipse in phase space — SHM traces a closed orbit'}
                  </p>
                </div>
              )}

              {/* Sliders */}
              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm space-y-4">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide">Parameters</p>

                {topic === 'pendulum' && <>
                  <Slider label="Length" unit="m" value={pendL} min={0.1} max={3} step={0.05} set={setPendL} color="#6366f1" />
                  <Slider label="Amplitude" unit="°" value={pendA} min={2} max={30} step={1} set={setPendA} color="#f59e0b" note="Keep < 15° for accurate SHM" />
                  <Slider label="Mass" unit="kg" value={pendM} min={0.1} max={2} step={0.1} set={setPendM} color="#94a3b8" note="Does not affect period" />
                  <Slider label="Gravity" unit="m/s²" value={pendG} min={1.6} max={25} step={0.1} set={setPendG} color="#10b981" note="Moon=1.6  Earth=9.81  Jupiter=24.8" />
                </>}

                {topic === 'spring' && <>
                  <Slider label="Spring constant k" unit="N/m" value={spK} min={5} max={500} step={5} set={setSpK} color="#6366f1" />
                  <Slider label="Mass" unit="kg" value={spM} min={0.1} max={5} step={0.1} set={setSpM} color="#f59e0b" />
                  <Slider label="Amplitude" unit="m" value={spA} min={0.01} max={0.3} step={0.01} set={setSpA} color="#10b981" note="Must be less than static extension" />
                </>}

                {topic === 'conical' && <>
                  <Slider label="String length" unit="m" value={conL} min={0.2} max={2} step={0.05} set={setConL} color="#6366f1" />
                  <Slider label="Half-angle θ" unit="°" value={conTheta} min={5} max={75} step={1} set={setConTheta} color="#f59e0b" />
                  <Slider label="Mass" unit="kg" value={conM} min={0.1} max={1} step={0.05} set={setConM} color="#10b981" />
                </>}

                {topic === 'physical' && <>
                  <Slider label="Rod length" unit="m" value={physL} min={0.2} max={2} step={0.05} set={setPhysL} color="#6366f1" />
                  <Slider label="Mass" unit="kg" value={physM} min={0.1} max={2} step={0.1} set={setPhysM} color="#f59e0b" />
                  <Slider label="Pivot position (fraction from top)" unit="" value={physPF} min={0} max={0.45} step={0.05} set={setPhysPF} color="#10b981" note="0 = top end, 0.5 = centre (infinite period)" />
                </>}

                {topic === 'bifilar' && bifMode === 'bifilar' && <>
                  <Slider label="Rod mass" unit="kg" value={bifM} min={0.5} max={5} step={0.1} set={setBifM} color="#6366f1" />
                  <Slider label="Rod length" unit="m" value={bifL} min={0.2} max={1.5} step={0.05} set={setBifL} color="#f59e0b" />
                  <Slider label="Wire length" unit="m" value={bifWire} min={0.3} max={2} step={0.05} set={setBifWire} color="#10b981" />
                  <Slider label="Wire separation (2d)" unit="m" value={bifSep} min={0.1} max={0.8} step={0.02} set={setBifSep} color="#8b5cf6" />
                </>}

                {topic === 'bifilar' && bifMode === 'cantilever' && <>
                  <Slider label="Beam length" unit="m" value={cantL} min={0.1} max={1} step={0.05} set={setCantL} color="#6366f1" />
                  <Slider label="Beam height (thickness)" unit="mm" value={cantH} min={2} max={20} step={1} set={setCantH} color="#f59e0b" />
                  <Slider label="End load" unit="N" value={cantLoad} min={0} max={50} step={1} set={setCantLoad} color="#ef4444" />
                </>}
              </div>
            </div>

            {/* Analytics */}
            <div className="space-y-3">
              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide mb-3">Calculated</p>
                <div className="space-y-2">
                  {topic === 'pendulum' && [
                    { l: 'Angular freq ω', v: `${pendOmega.toFixed(3)} rad/s`, c: 'text-indigo-600' },
                    { l: 'Period T', v: `${pendT.toFixed(3)} s`, c: 'text-emerald-600' },
                    { l: 'Frequency f', v: `${(1/pendT).toFixed(3)} Hz`, c: 'text-amber-600' },
                    { l: 'Max velocity', v: `${(pendA * Math.PI/180 * pendL * pendOmega).toFixed(3)} m/s`, c: 'text-rose-500' },
                    { l: 'Max acceleration', v: `${(pendA * Math.PI/180 * pendL * pendOmega**2).toFixed(3)} m/s²`, c: 'text-purple-600' },
                  ].map(r => (
                    <div key={r.l} className="flex justify-between items-center rounded-lg bg-gray-50 px-3 py-2">
                      <span className="text-xs text-gray-500">{r.l}</span>
                      <span className={`text-xs font-semibold tabular-nums ${r.c}`}>{r.v}</span>
                    </div>
                  ))}

                  {topic === 'spring' && [
                    { l: 'Angular freq ω', v: `${spOmega.toFixed(3)} rad/s`, c: 'text-indigo-600' },
                    { l: 'Period T', v: `${spT.toFixed(3)} s`, c: 'text-emerald-600' },
                    { l: 'Static extension', v: `${spStaticX.toFixed(3)} m`, c: 'text-amber-600' },
                    { l: 'Max velocity', v: `${(spA * spOmega).toFixed(3)} m/s`, c: 'text-rose-500' },
                    { l: 'Total energy', v: `${(0.5 * spK * spA * spA).toFixed(4)} J`, c: 'text-purple-600' },
                    { l: 'Max KE = Max PE', v: `${(0.5 * spK * spA * spA).toFixed(4)} J`, c: 'text-gray-600' },
                  ].map(r => (
                    <div key={r.l} className="flex justify-between items-center rounded-lg bg-gray-50 px-3 py-2">
                      <span className="text-xs text-gray-500">{r.l}</span>
                      <span className={`text-xs font-semibold tabular-nums ${r.c}`}>{r.v}</span>
                    </div>
                  ))}

                  {topic === 'conical' && [
                    { l: 'Angular velocity ω', v: `${conOmega.toFixed(3)} rad/s`, c: 'text-indigo-600' },
                    { l: 'Period T', v: `${conT.toFixed(3)} s`, c: 'text-emerald-600' },
                    { l: 'Orbital radius r', v: `${(conL * Math.sin(conTheta*Math.PI/180)).toFixed(3)} m`, c: 'text-amber-600' },
                    { l: 'String tension T', v: `${conTens.toFixed(3)} N`, c: 'text-rose-500' },
                    { l: 'Orbital speed v', v: `${conSpeed.toFixed(3)} m/s`, c: 'text-purple-600' },
                    { l: 'Vertical height', v: `${(conL * Math.cos(conTheta*Math.PI/180)).toFixed(3)} m`, c: 'text-gray-600' },
                  ].map(r => (
                    <div key={r.l} className="flex justify-between items-center rounded-lg bg-gray-50 px-3 py-2">
                      <span className="text-xs text-gray-500">{r.l}</span>
                      <span className={`text-xs font-semibold tabular-nums ${r.c}`}>{r.v}</span>
                    </div>
                  ))}

                  {topic === 'physical' && [
                    { l: 'I (about pivot)', v: `${physI.toFixed(4)} kg·m²`, c: 'text-indigo-600' },
                    { l: 'Period (physical)', v: `${physT_actual.toFixed(3)} s`, c: 'text-emerald-600' },
                    { l: 'Period (simple, same L)', v: `${physT_simple.toFixed(3)} s`, c: 'text-amber-600' },
                    { l: 'Equiv. simple length', v: `${(physI/(physM*physD)).toFixed(3)} m`, c: 'text-rose-500' },
                    { l: 'Ratio T_phys/T_simple', v: `${(physT_actual/physT_simple).toFixed(3)}`, c: 'text-purple-600' },
                  ].map(r => (
                    <div key={r.l} className="flex justify-between items-center rounded-lg bg-gray-50 px-3 py-2">
                      <span className="text-xs text-gray-500">{r.l}</span>
                      <span className={`text-xs font-semibold tabular-nums ${r.c}`}>{r.v}</span>
                    </div>
                  ))}

                  {topic === 'bifilar' && bifMode === 'bifilar' && [
                    { l: 'I (rod)', v: `${(bifM*bifL**2/12).toFixed(4)} kg·m²`, c: 'text-indigo-600' },
                    { l: 'Period T', v: `${bifT.toFixed(3)} s`, c: 'text-emerald-600' },
                    { l: 'Frequency f', v: `${(1/bifT).toFixed(3)} Hz`, c: 'text-amber-600' },
                  ].map(r => (
                    <div key={r.l} className="flex justify-between items-center rounded-lg bg-gray-50 px-3 py-2">
                      <span className="text-xs text-gray-500">{r.l}</span>
                      <span className={`text-xs font-semibold tabular-nums ${r.c}`}>{r.v}</span>
                    </div>
                  ))}

                  {topic === 'bifilar' && bifMode === 'cantilever' && [
                    { l: 'Stiffness k', v: `${cantK.toFixed(0)} N/m`, c: 'text-indigo-600' },
                    { l: 'Deflection δ', v: `${(cantDef*1000).toFixed(2)} mm`, c: 'text-emerald-600' },
                    { l: 'Nat. frequency', v: `${(1/cantT).toFixed(2)} Hz`, c: 'text-amber-600' },
                    { l: 'Period T', v: `${cantT.toFixed(3)} s`, c: 'text-rose-500' },
                  ].map(r => (
                    <div key={r.l} className="flex justify-between items-center rounded-lg bg-gray-50 px-3 py-2">
                      <span className="text-xs text-gray-500">{r.l}</span>
                      <span className={`text-xs font-semibold tabular-nums ${r.c}`}>{r.v}</span>
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
