'use client';
import { useState, useCallback, useRef, useEffect } from 'react';
import { AppHeader } from '@/components/layout/AppHeader';
import { SimulationControls } from '@/components/simulation/SimulationControls';
import { DoublePendulumCanvas } from '@/components/simulation/DoublePendulumCanvas';
import { EmbedButton } from '@/components/ui/EmbedButton';
import { useResponsiveCanvasSize } from '@/hooks/useResponsiveCanvasSize';
import {
  PendulumState, PendulumParams, totalEnergy,
  PRESETS, Preset,
} from '@/lib/physics/doublePendulum';

const CURRICULA = ['WAEC', 'NECO', 'IGCSE', 'SAT', 'JUPEB'];
const CC: Record<string, string> = {
  WAEC: 'bg-indigo-100 text-indigo-700', NECO: 'bg-pink-100 text-pink-700',
  IGCSE: 'bg-emerald-100 text-emerald-700', SAT: 'bg-orange-100 text-orange-700',
  JUPEB: 'bg-purple-100 text-purple-700',
};

const TEACHER_NOTES = [
  'The double pendulum is one of the simplest systems that exhibits deterministic chaos — the motion is governed by exact equations, yet long-term behaviour is effectively unpredictable.',
  'Chaos arises from the nonlinearity of the equations, NOT from randomness or noise. Given the same initial conditions, the trajectory is perfectly repeatable.',
  'The system is extremely sensitive to initial conditions: a change of 0.01° in starting angle produces a completely different trajectory after just a few seconds — the "butterfly effect".',
  'Energy is conserved in the ideal (frictionless) case. The red/blue energy bar shows kinetic and potential energy trading back and forth. With damping, total energy slowly decreases.',
  'For small angles (θ < 15°), the motion is approximately regular and periodic — the linearised equations decouple into two normal modes.',
  'The trail of the second bob (orange) is the most vivid visual signature of chaos: ordered motion produces smooth, repeating curves; chaotic motion fills an irregular, tangled region of space.',
  'In real experiments, friction and air resistance eventually damp the motion. The "Damped motion" preset shows how chaos gives way to regular decay as energy dissipates.',
  'Q-factor and bandwidth are extracted live from the energy envelope. Q = ω/γ  where γ is the exponential decay constant of total energy.',
];

const EXERCISES = [
  {
    q: 'Run the "Chaos demo" preset for 10 seconds, then reset and run it again. Are the two trajectories identical? What does this tell you about the system?',
    a: 'Yes, they are identical — the double pendulum is deterministic. The same initial conditions always produce the same trajectory. Chaos does NOT mean randomness.',
  },
  {
    q: 'Compare the "Small oscillations" and "Chaos demo" presets. Why does one look regular and the other chaotic?',
    a: 'Small angles allow the sine terms in the equations to be approximated as sin(θ) ≈ θ, making the equations linear and solvable as two independent harmonic oscillators. Large angles keep the full nonlinearity, which couples the two pendulums and produces chaos.',
  },
  {
    q: 'Set both masses to 3kg and both lengths to 1.5m. Start at θ₁=90°, θ₂=90°. Is the motion more or less chaotic than the default 1kg/1m case? Explain.',
    a: 'The motion is similar in character — chaos depends primarily on the angles and the geometry (length ratio), not the absolute scale. However, larger masses mean more inertia, so the motion is slower but still chaotic.',
  },
  {
    q: 'Enable the energy monitor and run the frictionless case. What do you observe about total energy? Then add damping and observe again.',
    a: 'Without damping, total energy stays nearly constant (tiny variations are integration error). With damping, energy decreases monotonically as work is done against the resistive force — the pendulum eventually comes to rest.',
  },
  {
    q: 'The "Butterfly effect" preset starts with θ₂ = 90.1° instead of 90°. Run it alongside the "Chaos demo" (90°). How long before the two orange trails look completely different?',
    a: 'Usually within 3–5 seconds the trails diverge visibly. After 10 seconds they are completely uncorrelated — this is the hallmark of sensitive dependence on initial conditions.',
  },
  {
    q: 'With damping enabled, watch the Q-factor readout. Why does Q drop as the motion progresses?',
    a: 'Q = ω/γ. As energy decays, the amplitude shrinks and the system may settle into a lower-frequency regime. More importantly, once the motion becomes very small, numerical noise in the energy envelope makes the regression less stable, causing Q to fluctuate.',
  },
];

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
      <input
        type="range"
        min={min}
        max={max}
        step={step}
        value={value}
        onChange={e => set(Number(e.target.value))}
        className="w-full h-6 py-2 cursor-pointer"
        style={{ accentColor: color }}
      />
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

function DampingCurve({ history }: { history: Array<{ t: number; e: number }> }) {
  if (history.length < 3) return (
    <div className="rounded-lg bg-slate-900 border border-gray-700 h-24 flex items-center justify-center">
      <span className="text-[10px] text-gray-500">Run simulation to see decay curve</span>
    </div>
  );
  const logEs = history.map(h => Math.log(Math.max(h.e, 1e-6)));
  const minE = Math.min(...logEs);
  const maxE = Math.max(...logEs);
  const rangeE = maxE - minE || 1;
  const minT = history[0].t;
  const maxT = history[history.length - 1].t;
  const rangeT = maxT - minT || 1;

  const pts = history.map((h, i) => {
    const x = ((h.t - minT) / rangeT) * 100;
    const y = 100 - ((logEs[i] - minE) / rangeE) * 100;
    return `${x},${y}`;
  }).join(' ');

  return (
    <div className="rounded-lg bg-slate-900 border border-gray-700 overflow-hidden">
      <svg viewBox="0 0 100 100" preserveAspectRatio="none" className="w-full h-24 block">
        <polyline
          points={pts}
          fill="none"
          stroke="#10b981"
          strokeWidth="1.5"
          strokeLinecap="round"
          strokeLinejoin="round"
          vectorEffect="non-scaling-stroke"
        />
        <text x="4" y="12" fill="#94a3b8" fontSize="8" fontFamily="system-ui">ln(E) vs time</text>
        <line x1="0" y1="100" x2="100" y2="100" stroke="#334155" strokeWidth="0.5" />
        <line x1="0" y1="0" x2="0" y2="100" stroke="#334155" strokeWidth="0.5" />
      </svg>
    </div>
  );
}

export default function DoublePendulumPage() {
  const [isRunning, setIsRunning] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const [resetKey, setResetKey] = useState(0);
  const [openEx, setOpenEx] = useState<number | null>(null);
  const [activeCurricula, setActiveCurricula] = useState(['IGCSE', 'SAT', 'JUPEB']);
  const [showTrail, setShowTrail] = useState(true);
  const [showEnergy, setShowEnergy] = useState(true);
  const [trailLength, setTrailLength] = useState(300);
  const [activePreset, setActivePreset] = useState<number | null>(null);

  const [m1, setM1] = useState(1);
  const [m2, setM2] = useState(1);
  const [L1, setL1] = useState(1);
  const [L2, setL2] = useState(1);
  const [theta1Deg, setTheta1Deg] = useState(90);
  const [theta2Deg, setTheta2Deg] = useState(90);
  const [omega1, setOmega1] = useState(0);
  const [omega2, setOmega2] = useState(0);
  const [damping, setDamping] = useState(0);

  const [liveEnergy, setLiveEnergy] = useState({ ke: 0, pe: 0, total: 0 });
  const [liveState, setLiveState] = useState({ theta1: 0, theta2: 0, omega1: 0, omega2: 0 });
  const [liveMeta, setLiveMeta] = useState({ qFactor: 0, bandwidth: 0, decayRate: 0, valid: false });
  const [chartHistory, setChartHistory] = useState<Array<{ t: number; e: number }>>([]);

  const params: PendulumParams = { m1, m2, L1, L2, g: 9.81, damping };

  useEffect(() => {
    const idx = PRESETS.findIndex(p =>
      Math.abs(p.m1 - m1) < 0.05 && Math.abs(p.m2 - m2) < 0.05 &&
      Math.abs(p.L1 - L1) < 0.05 && Math.abs(p.L2 - L2) < 0.05 &&
      Math.abs(p.theta1Deg - theta1Deg) < 0.5 && Math.abs(p.theta2Deg - theta2Deg) < 0.5 &&
      Math.abs(p.omega1 - omega1) < 0.05 && Math.abs(p.omega2 - omega2) < 0.05 &&
      Math.abs(p.damping - damping) < 0.005
    );
    setActivePreset(idx >= 0 ? idx : null);
  }, [m1, m2, L1, L2, theta1Deg, theta2Deg, omega1, omega2, damping]);

  const applyPreset = useCallback((preset: Preset, index: number) => {
    setM1(preset.m1); setM2(preset.m2); setL1(preset.L1); setL2(preset.L2);
    setTheta1Deg(preset.theta1Deg); setTheta2Deg(preset.theta2Deg);
    setOmega1(preset.omega1); setOmega2(preset.omega2); setDamping(preset.damping);
    setIsRunning(false); setIsPaused(false);
    setResetKey(k => k + 1);
    setLiveEnergy({ ke: 0, pe: 0, total: 0 });
    setLiveState({ theta1: 0, theta2: 0, omega1: 0, omega2: 0 });
    setLiveMeta({ qFactor: 0, bandwidth: 0, decayRate: 0, valid: false });
    setChartHistory([]);
    setActivePreset(index);
  }, []);

  const reset = useCallback(() => {
    setIsRunning(false); setIsPaused(false);
    setResetKey(k => k + 1);
    setLiveEnergy({ ke: 0, pe: 0, total: 0 });
    setLiveState({ theta1: 0, theta2: 0, omega1: 0, omega2: 0 });
    setLiveMeta({ qFactor: 0, bandwidth: 0, decayRate: 0, valid: false });
    setChartHistory([]);
  }, []);

  const canvasBoxRef = useRef<HTMLDivElement>(null);
  const canvasSize = useResponsiveCanvasSize(canvasBoxRef, 660, 420, 900);

  const lastTickRef = useRef(0);
  const handleTick = useCallback((state: PendulumState, energy: { ke: number; pe: number; total: number }, meta: { qFactor: number; bandwidth: number; decayRate: number; valid: boolean; chartHistory: Array<{ t: number; e: number }> }) => {
    const now = performance.now();
    if (now - lastTickRef.current < 80) return;
    lastTickRef.current = now;
    setLiveState({
      theta1: state.theta1,
      theta2: state.theta2,
      omega1: state.omega1,
      omega2: state.omega2,
    });
    setLiveEnergy(energy);
    setLiveMeta({ qFactor: meta.qFactor, bandwidth: meta.bandwidth, decayRate: meta.decayRate, valid: meta.valid });
    setChartHistory(meta.chartHistory);
  }, []);

  const initialState: PendulumState = {
    theta1: (theta1Deg * Math.PI) / 180,
    omega1,
    theta2: (theta2Deg * Math.PI) / 180,
    omega2,
  };
  const initialTotalEnergy = totalEnergy(initialState, params);

  const qDisplay = !liveMeta.valid ? '—' :
    liveMeta.qFactor === Infinity ? '∞ (undamped)' :
    liveMeta.qFactor > 999 ? '> 999' :
    liveMeta.qFactor.toFixed(1);

  const bwDisplay = !liveMeta.valid ? '—' :
    liveMeta.bandwidth < 0.001 ? '~0' :
    liveMeta.bandwidth.toFixed(3);

  return (
    <>
      <AppHeader />
      <main className="min-h-screen bg-gray-50">
        <section className="border-b border-gray-200 bg-white">
          <div className="mx-auto max-w-[100rem] px-4 sm:px-6 py-4">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
              <div>
                <p className="text-xs text-gray-400 mb-0.5">Mechanics — Advanced</p>
                <h1 className="text-lg font-semibold text-gray-900">Double pendulum</h1>
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
          <div className="flex flex-wrap items-center gap-3 rounded-xl border border-gray-200 bg-white px-4 py-2.5">
            <span className="text-xs text-gray-400">Nonlinear coupled oscillators — deterministic chaos</span>
            <span className="text-sm font-semibold font-mono text-gray-900">L = T − V</span>
          </div>

          {/* Presets — snap-scroll for mobile */}
          <div className="flex gap-2 overflow-x-auto pb-2 snap-x snap-mandatory scroll-smooth">
            {PRESETS.map((preset, i) => (
              <button key={i} onClick={() => applyPreset(preset, i)}
                className={`shrink-0 rounded-xl border px-3 py-2 text-left transition snap-start min-w-[180px] ${
                  activePreset === i
                    ? 'border-indigo-500 bg-indigo-50 shadow-sm ring-1 ring-indigo-300'
                    : 'border-gray-200 bg-white hover:border-indigo-300 hover:shadow-sm'
                }`}>
                <p className="text-xs font-medium text-indigo-700">{preset.name}</p>
                <p className="text-[10px] text-gray-400 mt-0.5 leading-relaxed">{preset.description}</p>
              </button>
            ))}
          </div>

          <div className="grid grid-cols-1 lg:grid-cols-[1fr_220px] xl:grid-cols-[1fr_220px_260px] gap-4">
            <div className="space-y-3 min-w-0">
              <div ref={canvasBoxRef} className="rounded-2xl border border-gray-200 bg-white p-3 shadow-sm">
                <DoublePendulumCanvas
                  key={resetKey}
                  theta1Deg={theta1Deg}
                  omega1Init={omega1}
                  theta2Deg={theta2Deg}
                  omega2Init={omega2}
                  params={params}
                  isRunning={isRunning}
                  isPaused={isPaused}
                  showTrail={showTrail}
                  showEnergy={showEnergy}
                  trailLength={trailLength}
                  onTick={handleTick}
                  width={canvasSize.width}
                  height={canvasSize.height}
                />
              </div>

              <div className="flex flex-wrap items-center justify-between gap-2">
                <SimulationControls isRunning={isRunning} isPaused={isPaused}
                  onRun={() => { setIsRunning(true); setIsPaused(false); }}
                  onPause={() => setIsPaused(p => !p)} onReset={reset} />
                <EmbedButton path="/embed/double-pendulum"
                  title="Double Pendulum — A-Factor STEM Studio"
                  params={{ m1, m2, L1, L2, t1: theta1Deg, t2: theta2Deg, w1: omega1, w2: omega2, damping, trail: trailLength }}
                />
              </div>

              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm space-y-4">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide">Parameters</p>
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                  <div className="space-y-3">
                    <p className="text-[10px] font-medium text-indigo-600 uppercase tracking-wide">First pendulum</p>
                    <Slider label="Mass m₁" unit="kg" value={m1} min={0.1} max={3} step={0.1} set={setM1} color="#6366f1" />
                    <Slider label="Length L₁" unit="m" value={L1} min={0.3} max={2} step={0.1} set={setL1} color="#818cf8" />
                    <Slider label="Initial angle θ₁" unit="°" value={theta1Deg} min={-180} max={180} step={1} set={setTheta1Deg} color="#a78bfa" />
                    <Slider label="Initial ω₁" unit="rad/s" value={omega1} min={-5} max={5} step={0.1} set={setOmega1} color="#c4b5fd" note="Initial angular velocity" />
                  </div>
                  <div className="space-y-3">
                    <p className="text-[10px] font-medium text-amber-600 uppercase tracking-wide">Second pendulum</p>
                    <Slider label="Mass m₂" unit="kg" value={m2} min={0.1} max={3} step={0.1} set={setM2} color="#f59e0b" />
                    <Slider label="Length L₂" unit="m" value={L2} min={0.3} max={2} step={0.1} set={setL2} color="#fbbf24" />
                    <Slider label="Initial angle θ₂" unit="°" value={theta2Deg} min={-180} max={180} step={1} set={setTheta2Deg} color="#fcd34d" />
                    <Slider label="Initial ω₂" unit="rad/s" value={omega2} min={-5} max={5} step={0.1} set={setOmega2} color="#fde68a" note="Initial angular velocity" />
                  </div>
                </div>
                <div className="border-t border-gray-100 pt-3 space-y-3">
                  <Slider label="Damping" unit="" value={damping} min={0} max={0.5} step={0.01} set={setDamping} color="#ef4444" note="0 = frictionless (energy conserved), higher = more air resistance" />
                  <Slider label="Trail length" unit="frames" value={trailLength} min={0} max={800} step={10} set={setTrailLength} color="#f43f5e" />
                  <div className="flex gap-3">
                    <label className="flex items-center gap-2 text-xs text-gray-600 cursor-pointer">
                      <input type="checkbox" checked={showTrail} onChange={e => setShowTrail(e.target.checked)} className="rounded" />
                      Show trail
                    </label>
                    <label className="flex items-center gap-2 text-xs text-gray-600 cursor-pointer">
                      <input type="checkbox" checked={showEnergy} onChange={e => setShowEnergy(e.target.checked)} className="rounded" />
                      Show energy bar
                    </label>
                  </div>
                </div>
              </div>
            </div>

            <div className="space-y-3">
              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide mb-3">Calculated</p>
                <div className="space-y-2">
                  <StatRow label="Initial total E" value={initialTotalEnergy.toFixed(3)} unit="J" color="text-indigo-600" />
                  <StatRow label="Live kinetic E" value={liveEnergy.ke.toFixed(3)} unit="J" color="text-rose-500" />
                  <StatRow label="Live potential E" value={liveEnergy.pe.toFixed(3)} unit="J" color="text-blue-500" />
                  <StatRow label="Live total E" value={liveEnergy.total.toFixed(3)} unit="J" color="text-emerald-600" />
                  <StatRow label="θ₁" value={(liveState.theta1 * 180 / Math.PI).toFixed(1)} unit="°" color="text-purple-600" />
                  <StatRow label="θ₂" value={(liveState.theta2 * 180 / Math.PI).toFixed(1)} unit="°" color="text-amber-600" />
                  <StatRow label="ω₁" value={liveState.omega1.toFixed(2)} unit="rad/s" color="text-indigo-500" />
                  <StatRow label="ω₂" value={liveState.omega2.toFixed(2)} unit="rad/s" color="text-amber-500" />
                  <StatRow label="Q factor" value={qDisplay} unit="" color="text-pink-600" />
                  <StatRow label="Bandwidth" value={bwDisplay} unit="rad/s" color="text-cyan-600" />
                </div>
              </div>

              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide mb-2">Damping curve</p>
                <DampingCurve history={chartHistory} />
                <p className="text-[10px] text-gray-400 mt-1.5 leading-relaxed">
                  Log-energy vs time. A straight line confirms exponential decay (linear damping).
                </p>
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
                  {TEACHER_NOTES.map((n, i) => (
                    <li key={i} className="text-xs text-amber-900 leading-relaxed flex gap-2">
                      <span className="text-amber-400 shrink-0 mt-0.5">•</span>{n}
                    </li>
                  ))}
                </ul>
              </div>

              <div className="rounded-2xl border border-gray-200 bg-white p-4">
                <p className="text-xs font-medium text-gray-500 uppercase tracking-wide mb-3">✏️ Exercises</p>
                <div className="space-y-2">
                  {EXERCISES.map((ex, i) => (
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
