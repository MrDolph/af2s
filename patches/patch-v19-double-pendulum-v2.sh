#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
# A-Factor STEM Studio — patch v19: new "Double Pendulum" module (FIXED v2)
#
#   A classic undergraduate demonstration of chaotic dynamics in classical
#   mechanics. Two pendulum bobs connected in series, with the motion
#   governed by the full nonlinear Lagrangian equations — no small-angle
#   approximation.
#
#   The simulation uses a 4th-order Runge-Kutta integrator for numerical
#   stability, with adaptive time-stepping. The trail renderer shows the
#   path of the second bob. A real-time energy monitor verifies that
#   total mechanical energy is conserved (within integration error) in
#   the frictionless case.
#
# Run from the af2s project root (Git Bash):   bash patches/patch-v19-double-pendulum.sh
# ══════════════════════════════════════════════════════════════════════════════
set -euo pipefail

if [ ! -f "package.json" ]; then
  echo "✗ Run this from the af2s project root (package.json not found)." >&2
  exit 1
fi

echo "── A-Factor patch v19: new Double Pendulum module ──"
mkdir -p "src/app/embed/double-pendulum" "src/app/simulations/double-pendulum" "src/components/simulation" "src/lib/physics"

echo "  → src/lib/physics/doublePendulum.ts"
cat > "src/lib/physics/doublePendulum.ts" << 'AFEOF'
export const G = 9.81;

export interface PendulumState {
  theta1: number; omega1: number;
  theta2: number; omega2: number;
}

export interface PendulumParams {
  m1: number; m2: number;
  L1: number; L2: number;
  g: number;
  damping: number;
}

function derivatives(state: PendulumState, params: PendulumParams): [number, number, number, number] {
  const { m1, m2, L1, L2, g, damping } = params;
  const { theta1, omega1, theta2, omega2 } = state;

  const delta = theta2 - theta1;
  const sinDelta = Math.sin(delta);
  const cosDelta = Math.cos(delta);

  const den1 = (m1 + m2) * L1 - m2 * L1 * cosDelta * cosDelta;
  const den2 = (L2 / L1) * den1;

  const num1 = m2 * L1 * omega1 * omega1 * sinDelta * cosDelta
             + m2 * g * Math.sin(theta2) * cosDelta
             + m2 * L2 * omega2 * omega2 * sinDelta
             - (m1 + m2) * g * Math.sin(theta1);
  const alpha1 = num1 / den1 - damping * omega1;

  const num2 = -m2 * L2 * omega2 * omega2 * sinDelta * cosDelta
             + (m1 + m2) * (g * Math.sin(theta1) * cosDelta - L1 * omega1 * omega1 * sinDelta - g * Math.sin(theta2));
  const alpha2 = num2 / den2 - damping * omega2;

  return [omega1, alpha1, omega2, alpha2];
}

export function rk4Step(state: PendulumState, params: PendulumParams, dt: number): PendulumState {
  const s = state;
  const [k1_t1, k1_w1, k1_t2, k1_w2] = derivatives(s, params);

  const s2: PendulumState = {
    theta1: s.theta1 + 0.5 * dt * k1_t1,
    omega1: s.omega1 + 0.5 * dt * k1_w1,
    theta2: s.theta2 + 0.5 * dt * k1_t2,
    omega2: s.omega2 + 0.5 * dt * k1_w2,
  };
  const [k2_t1, k2_w1, k2_t2, k2_w2] = derivatives(s2, params);

  const s3: PendulumState = {
    theta1: s.theta1 + 0.5 * dt * k2_t1,
    omega1: s.omega1 + 0.5 * dt * k2_w1,
    theta2: s.theta2 + 0.5 * dt * k2_t2,
    omega2: s.omega2 + 0.5 * dt * k2_w2,
  };
  const [k3_t1, k3_w1, k3_t2, k3_w2] = derivatives(s3, params);

  const s4: PendulumState = {
    theta1: s.theta1 + dt * k3_t1,
    omega1: s.omega1 + dt * k3_w1,
    theta2: s.theta2 + dt * k3_t2,
    omega2: s.omega2 + dt * k3_w2,
  };
  const [k4_t1, k4_w1, k4_t2, k4_w2] = derivatives(s4, params);

  return {
    theta1: s.theta1 + (dt / 6) * (k1_t1 + 2 * k2_t1 + 2 * k3_t1 + k4_t1),
    omega1: s.omega1 + (dt / 6) * (k1_w1 + 2 * k2_w1 + 2 * k3_w1 + k4_w1),
    theta2: s.theta2 + (dt / 6) * (k1_t2 + 2 * k2_t2 + 2 * k3_t2 + k4_t2),
    omega2: s.omega2 + (dt / 6) * (k1_w2 + 2 * k2_w2 + 2 * k3_w2 + k4_w2),
  };
}

export function getPositions(state: PendulumState, params: PendulumParams) {
  const { L1, L2 } = params;
  const { theta1, theta2 } = state;
  const x1 = L1 * Math.sin(theta1);
  const y1 = -L1 * Math.cos(theta1);
  const x2 = x1 + L2 * Math.sin(theta2);
  const y2 = y1 - L2 * Math.cos(theta2);
  return { x1, y1, x2, y2 };
}

export function kineticEnergy(state: PendulumState, params: PendulumParams): number {
  const { m1, m2, L1, L2 } = params;
  const { theta1, omega1, theta2, omega2 } = state;
  const delta = theta2 - theta1;
  const v1sq = L1 * L1 * omega1 * omega1;
  const v2sq = L1 * L1 * omega1 * omega1
             + L2 * L2 * omega2 * omega2
             + 2 * L1 * L2 * omega1 * omega2 * Math.cos(delta);
  return 0.5 * m1 * v1sq + 0.5 * m2 * v2sq;
}

export function potentialEnergy(state: PendulumState, params: PendulumParams): number {
  const { m1, m2, L1, L2, g } = params;
  const { theta1, theta2 } = state;
  const y1 = -L1 * Math.cos(theta1);
  const y2 = y1 - L2 * Math.cos(theta2);
  return m1 * g * y1 + m2 * g * y2;
}

export function totalEnergy(state: PendulumState, params: PendulumParams): number {
  return kineticEnergy(state, params) + potentialEnergy(state, params);
}

export interface Preset {
  name: string;
  description: string;
  theta1Deg: number;
  theta2Deg: number;
  omega1: number;
  omega2: number;
  m1: number;
  m2: number;
  L1: number;
  L2: number;
  damping: number;
}

export const PRESETS: Preset[] = [
  {
    name: 'Small oscillations',
    description: 'Regular, nearly periodic motion — the linear approximation works well here.',
    theta1Deg: 10, theta2Deg: 10, omega1: 0, omega2: 0,
    m1: 1, m2: 1, L1: 1, L2: 1, damping: 0,
  },
  {
    name: 'Chaos demo',
    description: 'The classic chaotic double pendulum — large angles produce unpredictable, sensitive motion.',
    theta1Deg: 90, theta2Deg: 90, omega1: 0, omega2: 0,
    m1: 1, m2: 1, L1: 1, L2: 1, damping: 0,
  },
  {
    name: 'Butterfly effect',
    description: 'Two nearly identical starts diverge — demonstrates extreme sensitivity to initial conditions.',
    theta1Deg: 90, theta2Deg: 90.1, omega1: 0, omega2: 0,
    m1: 1, m2: 1, L1: 1, L2: 1, damping: 0,
  },
  {
    name: 'Heavy second bob',
    description: 'A much heavier second bob dominates the motion — more regular, less chaotic.',
    theta1Deg: 120, theta2Deg: 60, omega1: 0, omega2: 0,
    m1: 0.5, m2: 2, L1: 1, L2: 1, damping: 0,
  },
  {
    name: 'Damped motion',
    description: 'With air resistance, the chaotic energy eventually dissipates into regular decay.',
    theta1Deg: 120, theta2Deg: 120, omega1: 0, omega2: 0,
    m1: 1, m2: 1, L1: 1, L2: 1, damping: 0.1,
  },
  {
    name: 'Long second rod',
    description: 'A longer second rod creates complex, looping trajectories.',
    theta1Deg: 60, theta2Deg: 120, omega1: 0, omega2: 0,
    m1: 1, m2: 1, L1: 0.8, L2: 1.5, damping: 0,
  },
];

export interface TrailPoint { x: number; y: number; age: number; }

export function addTrailPoint(trail: TrailPoint[], x: number, y: number, maxAge: number): TrailPoint[] {
  const newTrail = [...trail, { x, y, age: 0 }];
  return newTrail.filter(p => p.age < maxAge).map(p => ({ ...p, age: p.age + 1 }));
}
AFEOF

echo "  → src/components/simulation/DoublePendulumCanvas.tsx"
cat > "src/components/simulation/DoublePendulumCanvas.tsx" << 'AFEOF'
'use client';
import { useRef, useEffect, useCallback } from 'react';
import {
  PendulumState, PendulumParams, rk4Step, getPositions,
  kineticEnergy, potentialEnergy,
  addTrailPoint, TrailPoint,
} from '@/lib/physics/doublePendulum';

interface Props {
  theta1Deg: number; omega1Init: number;
  theta2Deg: number; omega2Init: number;
  params: PendulumParams;
  isRunning: boolean;
  isPaused: boolean;
  showTrail: boolean;
  showEnergy: boolean;
  trailLength: number;
  onTick?: (state: PendulumState, energy: { ke: number; pe: number; total: number }) => void;
  width?: number;
  height?: number;
}

export function DoublePendulumCanvas({
  theta1Deg, omega1Init, theta2Deg, omega2Init,
  params,
  isRunning,
  isPaused,
  showTrail,
  showEnergy,
  trailLength,
  onTick,
  width = 660,
  height = 420,
}: Props) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const rafRef = useRef<number>(0);
  const lastFrameRef = useRef<number | null>(null);

  // Mutable physics state — NEVER reset during a run, only on mount or when user clicks Reset
  const stateRef = useRef<PendulumState>({
    theta1: (theta1Deg * Math.PI) / 180,
    omega1: omega1Init,
    theta2: (theta2Deg * Math.PI) / 180,
    omega2: omega2Init,
  });
  const trailRef = useRef<TrailPoint[]>([]);

  // Store latest prop values in a ref so draw() always reads current values
  // without re-triggering the animation loop
  const propsRef = useRef({ params, isRunning, isPaused, showTrail, showEnergy, trailLength, onTick });
  propsRef.current = { params, isRunning, isPaused, showTrail, showEnergy, trailLength, onTick };

  // Only reset physics state when the INITIAL prop values change (user clicked Reset or preset)
  // We compare the numeric values, not the objects
  const initRef = useRef({ theta1Deg, omega1Init, theta2Deg, omega2Init });
  useEffect(() => {
    const prev = initRef.current;
    if (prev.theta1Deg !== theta1Deg || prev.omega1Init !== omega1Init ||
        prev.theta2Deg !== theta2Deg || prev.omega2Init !== omega2Init) {
      stateRef.current = {
        theta1: (theta1Deg * Math.PI) / 180,
        omega1: omega1Init,
        theta2: (theta2Deg * Math.PI) / 180,
        omega2: omega2Init,
      };
      trailRef.current = [];
      lastFrameRef.current = null;
      initRef.current = { theta1Deg, omega1Init, theta2Deg, omega2Init };
    }
  }, [theta1Deg, omega1Init, theta2Deg, omega2Init]);

  const draw = useCallback((timestamp?: number) => {
    const canvas = canvasRef.current; if (!canvas) return;
    const ctx = canvas.getContext('2d'); if (!ctx) return;
    const s = propsRef.current;
    const W = canvas.width, H = canvas.height;

    // ── Physics step ───────────────────────────────────────────────────────
    let dt = 0;
    if (s.isRunning && !s.isPaused && timestamp !== undefined) {
      if (lastFrameRef.current !== null) {
        dt = Math.min((timestamp - lastFrameRef.current) / 1000, 0.05);
      }
      lastFrameRef.current = timestamp;
    } else {
      lastFrameRef.current = timestamp ?? null;
    }

    if (dt > 0) {
      // Sub-stepping for stability
      const subSteps = Math.max(4, Math.ceil(dt * 200));
      const subDt = dt / subSteps;
      for (let i = 0; i < subSteps; i++) {
        stateRef.current = rk4Step(stateRef.current, s.params, subDt);
      }

      const pos = getPositions(stateRef.current, s.params);
      if (s.showTrail) {
        trailRef.current = addTrailPoint(trailRef.current, pos.x2, pos.y2, s.trailLength);
      }

      const ke = kineticEnergy(stateRef.current, s.params);
      const pe = potentialEnergy(stateRef.current, s.params);
      s.onTick?.(stateRef.current, { ke, pe, total: ke + pe });
    }

    // ── Rendering ──────────────────────────────────────────────────────────
    ctx.clearRect(0, 0, W, H);
    ctx.fillStyle = '#0f172a'; ctx.fillRect(0, 0, W, H);

    const totalLen = s.params.L1 + s.params.L2;
    const margin = 60;
    const scale = Math.min((W - 2 * margin) / (totalLen * 2.2), (H - 2 * margin) / (totalLen * 2.2));
    const pivotX = W / 2;
    const pivotY = H * 0.15;

    const pos = getPositions(stateRef.current, s.params);
    const sx1 = pivotX + pos.x1 * scale;
    const sy1 = pivotY - pos.y1 * scale;
    const sx2 = pivotX + pos.x2 * scale;
    const sy2 = pivotY - pos.y2 * scale;

    // Grid circles
    ctx.strokeStyle = 'rgba(148, 163, 184, 0.15)';
    ctx.lineWidth = 1;
    for (let r = 0.5; r <= totalLen; r += 0.5) {
      ctx.beginPath();
      ctx.arc(pivotX, pivotY, r * scale, 0, Math.PI * 2);
      ctx.stroke();
    }

    // Trail
    if (s.showTrail && trailRef.current.length > 1) {
      for (let i = 1; i < trailRef.current.length; i++) {
        const p0 = trailRef.current[i - 1];
        const p1 = trailRef.current[i];
        const alpha = 1 - p1.age / s.trailLength;
        ctx.strokeStyle = `rgba(244, 63, 94, ${alpha * 0.6})`;
        ctx.lineWidth = 2;
        ctx.beginPath();
        ctx.moveTo(pivotX + p0.x * scale, pivotY - p0.y * scale);
        ctx.lineTo(pivotX + p1.x * scale, pivotY - p1.y * scale);
        ctx.stroke();
      }
    }

    // Rods
    ctx.strokeStyle = '#94a3b8'; ctx.lineWidth = 2;
    ctx.beginPath(); ctx.moveTo(pivotX, pivotY); ctx.lineTo(sx1, sy1); ctx.stroke();
    ctx.strokeStyle = '#cbd5e1'; ctx.lineWidth = 1.5;
    ctx.beginPath(); ctx.moveTo(sx1, sy1); ctx.lineTo(sx2, sy2); ctx.stroke();

    // Pivot
    ctx.fillStyle = '#f8fafc';
    ctx.beginPath(); ctx.arc(pivotX, pivotY, 5, 0, Math.PI * 2); ctx.fill();
    ctx.strokeStyle = '#64748b'; ctx.lineWidth = 2;
    ctx.beginPath(); ctx.arc(pivotX, pivotY, 5, 0, Math.PI * 2); ctx.stroke();

    // Bob 1
    const r1 = 8 + Math.min(s.params.m1, 3) * 4;
    ctx.fillStyle = '#6366f1';
    ctx.beginPath(); ctx.arc(sx1, sy1, r1, 0, Math.PI * 2); ctx.fill();
    ctx.strokeStyle = '#4338ca'; ctx.lineWidth = 2;
    ctx.beginPath(); ctx.arc(sx1, sy1, r1, 0, Math.PI * 2); ctx.stroke();
    ctx.fillStyle = 'white'; ctx.font = 'bold 9px system-ui'; ctx.textAlign = 'center';
    ctx.fillText(`${s.params.m1.toFixed(1)}kg`, sx1, sy1 + 3);

    // Bob 2
    const r2 = 8 + Math.min(s.params.m2, 3) * 4;
    ctx.fillStyle = '#f59e0b';
    ctx.beginPath(); ctx.arc(sx2, sy2, r2, 0, Math.PI * 2); ctx.fill();
    ctx.strokeStyle = '#d97706'; ctx.lineWidth = 2;
    ctx.beginPath(); ctx.arc(sx2, sy2, r2, 0, Math.PI * 2); ctx.stroke();
    ctx.fillStyle = 'white'; ctx.font = 'bold 9px system-ui'; ctx.textAlign = 'center';
    ctx.fillText(`${s.params.m2.toFixed(1)}kg`, sx2, sy2 + 3);

    // Angle readouts
    ctx.fillStyle = '#64748b'; ctx.font = '10px system-ui'; ctx.textAlign = 'left';
    const t1deg = (stateRef.current.theta1 * 180 / Math.PI).toFixed(1);
    const t2deg = (stateRef.current.theta2 * 180 / Math.PI).toFixed(1);
    ctx.fillText(`θ₁ = ${t1deg}°`, 12, H - 36);
    ctx.fillText(`θ₂ = ${t2deg}°`, 12, H - 22);
    ctx.fillText(`ω₁ = ${stateRef.current.omega1.toFixed(2)} rad/s`, 12, H - 8);

    // Energy bar
    if (s.showEnergy) {
      const ke = kineticEnergy(stateRef.current, s.params);
      const pe = potentialEnergy(stateRef.current, s.params);
      const total = ke + pe;
      const barW = 120; const barH = 8;
      const barX = W - barW - 16; const barY = H - 40;
      const keFrac = ke / Math.max(total, 0.001);
      const peFrac = pe / Math.max(total, 0.001);

      ctx.fillStyle = 'rgba(30, 41, 59, 0.8)';
      ctx.fillRect(barX - 4, barY - 18, barW + 8, 36);
      ctx.fillStyle = '#64748b'; ctx.font = '9px system-ui'; ctx.textAlign = 'left';
      ctx.fillText('Energy', barX, barY - 4);

      ctx.fillStyle = '#ef4444';
      ctx.fillRect(barX, barY, barW * keFrac, barH);
      ctx.fillStyle = '#3b82f6';
      ctx.fillRect(barX + barW * keFrac, barY, barW * peFrac, barH);

      ctx.fillStyle = '#94a3b8'; ctx.font = '8px system-ui';
      ctx.fillText(`KE`, barX, barY + barH + 10);
      ctx.fillText(`PE`, barX + barW * keFrac + 4, barY + barH + 10);
      ctx.fillText(`${total.toFixed(2)}J`, barX + barW - 30, barY + barH + 10);
    }

    // Status
    ctx.font = 'bold 11px system-ui'; ctx.textAlign = 'center';
    if (!s.isRunning) {
      ctx.fillStyle = '#94a3b8';
      ctx.fillText('Press Run to start the simulation', W / 2, 24);
    } else if (s.isPaused) {
      ctx.fillStyle = '#f59e0b';
      ctx.fillText('⏸ Paused', W / 2, 24);
    } else {
      ctx.fillStyle = '#10b981';
      ctx.fillText('● Running', W / 2, 24);
    }

    rafRef.current = requestAnimationFrame(draw);
  }, []);

  useEffect(() => {
    rafRef.current = requestAnimationFrame(draw);
    return () => cancelAnimationFrame(afRef.current);
  }, [draw]);

  return (
    <canvas ref={canvasRef} width={width} height={height}
      className="w-full rounded-xl border border-gray-700 bg-slate-900" style={{ display: 'block' }} />
  );
}
AFEOF

echo "  → src/app/simulations/double-pendulum/page.tsx"
cat > "src/app/simulations/double-pendulum/page.tsx" << 'AFEOF'
'use client';
import { useState, useCallback, useRef } from 'react';
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

export default function DoublePendulumPage() {
  const [isRunning, setIsRunning] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const [resetKey, setResetKey] = useState(0);
  const [openEx, setOpenEx] = useState<number | null>(null);
  const [activeCurricula, setActiveCurricula] = useState(['IGCSE', 'SAT', 'JUPEB']);
  const [showTrail, setShowTrail] = useState(true);
  const [showEnergy, setShowEnergy] = useState(true);
  const [trailLength, setTrailLength] = useState(300);

  // Parameters
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

  const params: PendulumParams = { m1, m2, L1, L2, g: 9.81, damping };

  const applyPreset = useCallback((preset: Preset) => {
    setM1(preset.m1); setM2(preset.m2); setL1(preset.L1); setL2(preset.L2);
    setTheta1Deg(preset.theta1Deg); setTheta2Deg(preset.theta2Deg);
    setOmega1(preset.omega1); setOmega2(preset.omega2); setDamping(preset.damping);
    setIsRunning(false); setIsPaused(false);
    setResetKey(k => k + 1);
    setLiveEnergy({ ke: 0, pe: 0, total: 0 });
    setLiveState({ theta1: 0, theta2: 0, omega1: 0, omega2: 0 });
  }, []);

  const reset = useCallback(() => {
    setIsRunning(false); setIsPaused(false);
    setResetKey(k => k + 1);
    setLiveEnergy({ ke: 0, pe: 0, total: 0 });
    setLiveState({ theta1: 0, theta2: 0, omega1: 0, omega2: 0 });
  }, []);

  const canvasBoxRef = useRef<HTMLDivElement>(null);
  const canvasSize = useResponsiveCanvasSize(canvasBoxRef, 660, 420, 900);

  const lastTickRef = useRef(0);
  const handleTick = useCallback((state: PendulumState, energy: { ke: number; pe: number; total: number }) => {
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
  }, []);

  const initialState: PendulumState = {
    theta1: (theta1Deg * Math.PI) / 180,
    omega1,
    theta2: (theta2Deg * Math.PI) / 180,
    omega2,
  };
  const initialTotalEnergy = totalEnergy(initialState, params);

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

          {/* Presets */}
          <div className="flex gap-2 overflow-x-auto pb-1">
            {PRESETS.map((preset, i) => (
              <button key={i} onClick={() => applyPreset(preset)}
                className="shrink-0 rounded-xl border border-gray-200 bg-white px-3 py-2 text-left hover:border-indigo-300 hover:shadow-sm transition min-w-[180px]">
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
AFEOF

echo "  → src/app/embed/double-pendulum/page.tsx"
cat > "src/app/embed/double-pendulum/page.tsx" << 'AFEOF'
'use client';
import { Suspense, useState, useCallback, useRef } from 'react';
import { useSearchParams } from 'next/navigation';
import { DoublePendulumCanvas } from '@/components/simulation/DoublePendulumCanvas';
import { SimulationControls } from '@/components/simulation/SimulationControls';
import { PendulumParams } from '@/lib/physics/doublePendulum';

function num(sp: URLSearchParams, key: string, fallback: number, min: number, max: number) {
  const v = Number(sp.get(key));
  return Number.isFinite(v) && sp.get(key) !== null ? Math.min(max, Math.max(min, v)) : fallback;
}

function Slider({ label, unit, value, min, max, step, set, color }: {
  label: string; unit: string; value: number; min: number; max: number;
  step: number; set: (v: number) => void; color: string;
}) {
  return (
    <div className="space-y-1">
      <div className="flex justify-between text-xs">
        <span className="text-gray-500">{label}</span>
        <span className="font-medium tabular-nums text-gray-800">{value} <span className="font-normal text-gray-400">{unit}</span></span>
      </div>
      <input type="range" min={min} max={max} step={step} value={value}
        onChange={e => set(Number(e.target.value))} className="w-full" style={{ accentColor: color }} />
    </div>
  );
}

function PoweredBy() {
  return (
    <p className="text-center text-[10px] text-gray-400">
      Powered by{' '}
      <a href="/" target="_blank" rel="noopener noreferrer" className="font-medium text-indigo-500 hover:text-indigo-600">
        A-Factor STEM Studio
      </a>
    </p>
  );
}

function DoublePendulumEmbedInner() {
  const sp = useSearchParams();
  const showControls = sp.get('controls') !== '0';

  const [m1, setM1] = useState(() => num(sp, 'm1', 1, 0.1, 3));
  const [m2, setM2] = useState(() => num(sp, 'm2', 1, 0.1, 3));
  const [L1, setL1] = useState(() => num(sp, 'L1', 1, 0.3, 2));
  const [L2, setL2] = useState(() => num(sp, 'L2', 1, 0.3, 2));
  const [theta1Deg, setTheta1Deg] = useState(() => num(sp, 't1', 90, -180, 180));
  const [theta2Deg, setTheta2Deg] = useState(() => num(sp, 't2', 90, -180, 180));
  const [omega1, setOmega1] = useState(() => num(sp, 'w1', 0, -5, 5));
  const [omega2, setOmega2] = useState(() => num(sp, 'w2', 0, -5, 5));
  const [damping, setDamping] = useState(() => num(sp, 'damping', 0, 0, 0.5));
  const [trailLength, setTrailLength] = useState(() => Math.round(num(sp, 'trail', 300, 0, 800)));
  const [showTrail, setShowTrail] = useState(true);
  const [showEnergy, setShowEnergy] = useState(true);

  const params: PendulumParams = { m1, m2, L1, L2, g: 9.81, damping };

  const [isRunning, setIsRunning] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const [resetKey, setResetKey] = useState(0);
  const reset = useCallback(() => { setIsRunning(false); setIsPaused(false); setResetKey(k => k + 1); }, []);

  return (
    <div className="mx-auto max-w-2xl space-y-3 p-3 sm:p-4">
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
        width={640}
        height={400}
      />
      <SimulationControls isRunning={isRunning} isPaused={isPaused}
        onRun={() => { setIsRunning(true); setIsPaused(false); }}
        onPause={() => setIsPaused(p => !p)} onReset={reset} />
      {showControls && (
        <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm space-y-3">
          <p className="text-xs font-medium uppercase tracking-wide text-gray-400">Parameters</p>
          <Slider label="Mass m₁" unit="kg" value={m1} min={0.1} max={3} step={0.1} set={setM1} color="#6366f1" />
          <Slider label="Mass m₂" unit="kg" value={m2} min={0.1} max={3} step={0.1} set={setM2} color="#f59e0b" />
          <Slider label="Length L₁" unit="m" value={L1} min={0.3} max={2} step={0.1} set={setL1} color="#818cf8" />
          <Slider label="Length L₂" unit="m" value={L2} min={0.3} max={2} step={0.1} set={setL2} color="#fbbf24" />
          <Slider label="Angle θ₁" unit="°" value={theta1Deg} min={-180} max={180} step={1} set={setTheta1Deg} color="#a78bfa" />
          <Slider label="Angle θ₂" unit="°" value={theta2Deg} min={-180} max={180} step={1} set={setTheta2Deg} color="#fcd34d" />
          <Slider label="Damping" unit="" value={damping} min={0} max={0.5} step={0.01} set={setDamping} color="#ef4444" />
          <Slider label="Trail" unit="frames" value={trailLength} min={0} max={800} step={10} set={setTrailLength} color="#f43f5e" />
          <div className="flex gap-3">
            <label className="flex items-center gap-2 text-xs text-gray-600 cursor-pointer">
              <input type="checkbox" checked={showTrail} onChange={e => setShowTrail(e.target.checked)} className="rounded" />
              Show trail
            </label>
            <label className="flex items-center gap-2 text-xs text-gray-600 cursor-pointer">
              <input type="checkbox" checked={showEnergy} onChange={e => setShowEnergy(e.target.checked)} className="rounded" />
              Show energy
            </label>
          </div>
        </div>
      )}
      <PoweredBy />
    </div>
  );
}

export default function DoublePendulumEmbedPage() {
  return (
    <Suspense fallback={<div className="p-8 text-center text-xs text-gray-400">Loading simulation…</div>}>
      <DoublePendulumEmbedInner />
    </Suspense>
  );
}
AFEOF

echo ""
echo "✓ Patch v19 applied — 4 files written."
echo ""
echo "Next steps:"
echo "  rm -rf .next"
echo "  npm run dev"
echo ""
echo "Check: /simulations/double-pendulum"
echo "  - Try the presets: Small oscillations, Chaos demo, Butterfly effect"
echo "  - Enable trail to see the chaotic trajectory of the second bob"
echo "  - Enable energy bar to watch KE/PE trade-off in real time"
echo "  - Add damping to see chaos decay into regular motion"
echo ""
echo "REMINDER: Add the simulation to src/app/simulations/page.tsx SIMULATIONS array:"
echo '  {'
echo '    slug: '"'"'double-pendulum'"'"','
echo '    href: '"'"'/simulations/double-pendulum'"'"','
echo '    title: '"'"'Double pendulum'"'"','
echo '    description: '"'"'Explore deterministic chaos with a coupled nonlinear oscillator. Trail, energy monitor, and presets included.'"'"','
echo '    icon: '"'"'🌀'"'"','
echo '    tags: ['"'"'IGCSE'"'"', '"'"'SAT'"'"', '"'"'JUPEB'"'"'],'
echo '    topic: '"'"'Mechanics'"'"','
echo '    status: '"'"'live'"'"','
echo '  },'
