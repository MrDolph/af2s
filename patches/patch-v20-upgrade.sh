#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
# A-Factor STEM Studio — patch v20: Double-Pendulum upgrades + Coupled Springs
# ══════════════════════════════════════════════════════════════════════════════
set -euo pipefail

if [ ! -f "package.json" ]; then
  echo "✗ Run this from the af2s project root (package.json not found)." >&2
  exit 1
fi

echo "── A-Factor patch v20: DP upgrades + Coupled Springs ──"
mkdir -p "src/app/embed/coupled-oscillators" "src/app/simulations/coupled-oscillators" "src/components/simulation" "src/lib/physics"

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

/* ═════════════════════════════════════════════════════════════════════════════
   Real-time decay analysis — Q-factor & bandwidth from motion
   ═════════════════════════════════════════════════════════════════════════════ */

export interface DecayAnalysis {
  qFactor: number;
  bandwidth: number;
  decayRate: number;
  valid: boolean;
}

export interface DecayPoint {
  t: number;
  e: number;
  signal: number;
}

export function analyzeDecay(history: DecayPoint[]): DecayAnalysis {
  if (history.length < 24) {
    return { qFactor: 0, bandwidth: 0, decayRate: 0, valid: false };
  }
  const pts = history.filter(p => p.e > 1e-6 && Number.isFinite(p.e));
  if (pts.length < 20) {
    return { qFactor: 0, bandwidth: 0, decayRate: 0, valid: false };
  }
  let sumT = 0, sumLnE = 0, sumT2 = 0, sumTLnE = 0, n = 0;
  for (const p of pts) {
    const lnE = Math.log(p.e);
    sumT += p.t;
    sumLnE += lnE;
    sumT2 += p.t * p.t;
    sumTLnE += p.t * lnE;
    n++;
  }
  const meanT = sumT / n;
  const meanLnE = sumLnE / n;
  const denom = sumT2 - n * meanT * meanT;
  if (Math.abs(denom) < 1e-12) {
    return { qFactor: 0, bandwidth: 0, decayRate: 0, valid: false };
  }
  const slope = (sumTLnE - n * meanT * meanLnE) / denom;
  const gamma = -slope;

  const crossings: number[] = [];
  for (let i = 1; i < pts.length; i++) {
    const prev = pts[i - 1];
    const curr = pts[i];
    if (prev.signal * curr.signal < 0 && prev.signal !== 0) {
      const frac = Math.abs(prev.signal) / (Math.abs(prev.signal) + Math.abs(curr.signal));
      const tc = prev.t + (curr.t - prev.t) * frac;
      crossings.push(tc);
    }
  }

  if (crossings.length < 2) {
    if (gamma <= 0.001) {
      return { qFactor: Infinity, bandwidth: 0, decayRate: gamma, valid: true };
    }
    return { qFactor: 0, bandwidth: 0, decayRate: gamma, valid: false };
  }

  let totalHalfPeriod = 0;
  for (let i = 1; i < crossings.length; i++) {
    totalHalfPeriod += crossings[i] - crossings[i - 1];
  }
  const avgHalfPeriod = totalHalfPeriod / (crossings.length - 1);
  const period = avgHalfPeriod * 2;
  const omega = (2 * Math.PI) / period;

  if (gamma <= 0.001) {
    return { qFactor: Infinity, bandwidth: 0, decayRate: gamma, valid: true };
  }
  const q = omega / gamma;
  if (!Number.isFinite(q) || q < 0) {
    return { qFactor: 0, bandwidth: 0, decayRate: gamma, valid: false };
  }
  return { qFactor: q, bandwidth: gamma, decayRate: gamma, valid: true };
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
  analyzeDecay, DecayAnalysis,
} from '@/lib/physics/doublePendulum';

interface TickMeta {
  qFactor: number;
  bandwidth: number;
  decayRate: number;
  valid: boolean;
  chartHistory: Array<{ t: number; e: number }>;
}

interface Props {
  theta1Deg: number; omega1Init: number;
  theta2Deg: number; omega2Init: number;
  params: PendulumParams;
  isRunning: boolean;
  isPaused: boolean;
  showTrail: boolean;
  showEnergy: boolean;
  trailLength: number;
  onTick?: (state: PendulumState, energy: { ke: number; pe: number; total: number }, meta: TickMeta) => void;
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
  const simTimeRef = useRef(0);
  const energyHistoryRef = useRef<Array<{ t: number; e: number; signal: number }>>([]);
  const analysisRef = useRef<DecayAnalysis>({ qFactor: 0, bandwidth: 0, decayRate: 0, valid: false });
  const lastAnalysisRef = useRef(0);
  const chartHistoryRef = useRef<Array<{ t: number; e: number }>>([]);

  const stateRef = useRef<PendulumState>({
    theta1: (theta1Deg * Math.PI) / 180,
    omega1: omega1Init,
    theta2: (theta2Deg * Math.PI) / 180,
    omega2: omega2Init,
  });
  const trailRef = useRef<TrailPoint[]>([]);

  const propsRef = useRef({ params, isRunning, isPaused, showTrail, showEnergy, trailLength, onTick });
  propsRef.current = { params, isRunning, isPaused, showTrail, showEnergy, trailLength, onTick };

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
      simTimeRef.current = 0;
      energyHistoryRef.current = [];
      chartHistoryRef.current = [];
      analysisRef.current = { qFactor: 0, bandwidth: 0, decayRate: 0, valid: false };
      lastAnalysisRef.current = 0;
      initRef.current = { theta1Deg, omega1Init, theta2Deg, omega2Init };
    }
  }, [theta1Deg, omega1Init, theta2Deg, omega2Init]);

  const draw = useCallback((timestamp?: number) => {
    const canvas = canvasRef.current; if (!canvas) return;
    const ctx = canvas.getContext('2d'); if (!ctx) return;
    const s = propsRef.current;
    const W = canvas.width, H = canvas.height;

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
      const subSteps = Math.max(4, Math.ceil(dt * 200));
      const subDt = dt / subSteps;
      for (let i = 0; i < subSteps; i++) {
        stateRef.current = rk4Step(stateRef.current, s.params, subDt);
        simTimeRef.current += subDt;
      }

      const pos = getPositions(stateRef.current, s.params);
      if (s.showTrail) {
        trailRef.current = addTrailPoint(trailRef.current, pos.x2, pos.y2, s.trailLength);
      }

      const ke = kineticEnergy(stateRef.current, s.params);
      const pe = potentialEnergy(stateRef.current, s.params);
      const total = ke + pe;

      energyHistoryRef.current.push({
        t: simTimeRef.current,
        e: total,
        signal: stateRef.current.theta1,
      });
      const cutoff = simTimeRef.current - 5;
      energyHistoryRef.current = energyHistoryRef.current.filter(p => p.t > cutoff);

      const lastChart = chartHistoryRef.current[chartHistoryRef.current.length - 1];
      if (!lastChart || simTimeRef.current - lastChart.t > 0.12) {
        chartHistoryRef.current.push({ t: simTimeRef.current, e: total });
      }
      const chartCutoff = simTimeRef.current - 10;
      chartHistoryRef.current = chartHistoryRef.current.filter(p => p.t > chartCutoff);

      if (simTimeRef.current - lastAnalysisRef.current > 0.5 && energyHistoryRef.current.length > 40) {
        analysisRef.current = analyzeDecay(energyHistoryRef.current);
        lastAnalysisRef.current = simTimeRef.current;
      }

      s.onTick?.(stateRef.current, { ke, pe, total }, {
        qFactor: analysisRef.current.qFactor,
        bandwidth: analysisRef.current.bandwidth,
        decayRate: analysisRef.current.decayRate,
        valid: analysisRef.current.valid,
        chartHistory: [...chartHistoryRef.current],
      });
    }

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

    ctx.strokeStyle = 'rgba(148, 163, 184, 0.15)';
    ctx.lineWidth = 1;
    for (let r = 0.5; r <= totalLen; r += 0.5) {
      ctx.beginPath();
      ctx.arc(pivotX, pivotY, r * scale, 0, Math.PI * 2);
      ctx.stroke();
    }

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

    ctx.strokeStyle = '#94a3b8'; ctx.lineWidth = 2;
    ctx.beginPath(); ctx.moveTo(pivotX, pivotY); ctx.lineTo(sx1, sy1); ctx.stroke();
    ctx.strokeStyle = '#cbd5e1'; ctx.lineWidth = 1.5;
    ctx.beginPath(); ctx.moveTo(sx1, sy1); ctx.lineTo(sx2, sy2); ctx.stroke();

    ctx.fillStyle = '#f8fafc';
    ctx.beginPath(); ctx.arc(pivotX, pivotY, 5, 0, Math.PI * 2); ctx.fill();
    ctx.strokeStyle = '#64748b'; ctx.lineWidth = 2;
    ctx.beginPath(); ctx.arc(pivotX, pivotY, 5, 0, Math.PI * 2); ctx.stroke();

    const r1 = 8 + Math.min(s.params.m1, 3) * 4;
    ctx.fillStyle = '#6366f1';
    ctx.beginPath(); ctx.arc(sx1, sy1, r1, 0, Math.PI * 2); ctx.fill();
    ctx.strokeStyle = '#4338ca'; ctx.lineWidth = 2;
    ctx.beginPath(); ctx.arc(sx1, sy1, r1, 0, Math.PI * 2); ctx.stroke();
    ctx.fillStyle = 'white'; ctx.font = 'bold 9px system-ui'; ctx.textAlign = 'center';
    ctx.fillText(`${s.params.m1.toFixed(1)}kg`, sx1, sy1 + 3);

    const r2 = 8 + Math.min(s.params.m2, 3) * 4;
    ctx.fillStyle = '#f59e0b';
    ctx.beginPath(); ctx.arc(sx2, sy2, r2, 0, Math.PI * 2); ctx.fill();
    ctx.strokeStyle = '#d97706'; ctx.lineWidth = 2;
    ctx.beginPath(); ctx.arc(sx2, sy2, r2, 0, Math.PI * 2); ctx.stroke();
    ctx.fillStyle = 'white'; ctx.font = 'bold 9px system-ui'; ctx.textAlign = 'center';
    ctx.fillText(`${s.params.m2.toFixed(1)}kg`, sx2, sy2 + 3);

    ctx.fillStyle = '#64748b'; ctx.font = '10px system-ui'; ctx.textAlign = 'left';
    const t1deg = (stateRef.current.theta1 * 180 / Math.PI).toFixed(1);
    const t2deg = (stateRef.current.theta2 * 180 / Math.PI).toFixed(1);
    ctx.fillText(`θ₁ = ${t1deg}°`, 12, H - 36);
    ctx.fillText(`θ₂ = ${t2deg}°`, 12, H - 22);
    ctx.fillText(`ω₁ = ${stateRef.current.omega1.toFixed(2)} rad/s`, 12, H - 8);

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
    return () => cancelAnimationFrame(rafRef.current);
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

function DampingCurve({ history }: { history: Array<{ t: number; e: number }> }) {
  if (history.length < 3) return (
    <div className="rounded-lg bg-slate-900 border border-gray-700 h-24 flex items-center justify-center">
      <span className="text-[10px] text-gray-500">Run simulation to see decay curve</span>
    </div>
  );
  const W = 220;
  const H = 96;
  const pad = 10;
  const times = history.map(h => h.t);
  const minT = times[0];
  const maxT = times[times.length - 1];
  const rangeT = maxT - minT || 1;
  const logEs = history.map(h => Math.log(Math.max(h.e, 1e-6)));
  const minE = Math.min(...logEs);
  const maxE = Math.max(...logEs);
  const rangeE = maxE - minE || 1;
  const pts = history.map((h, i) => {
    const x = pad + ((h.t - minT) / rangeT) * (W - 2 * pad);
    const y = H - pad - ((logEs[i] - minE) / rangeE) * (H - 2 * pad);
    return `${x},${y}`;
  }).join(' ');
  return (
    <div className="rounded-lg bg-slate-900 border border-gray-700 overflow-hidden">
      <svg width={W} height={H} viewBox={`0 0 ${W} ${H}`} className="block">
        <polyline points={pts} fill="none" stroke="#10b981" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" />
        <text x={pad} y={pad + 8} fill="#94a3b8" fontSize="8" fontFamily="system-ui">ln(E) vs time</text>
        <line x1={pad} y1={H - pad} x2={W - pad} y2={H - pad} stroke="#334155" strokeWidth="0.5" />
        <line x1={pad} y1={pad} x2={pad} y2={H - pad} stroke="#334155" strokeWidth="0.5" />
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

          <div className="flex gap-2 overflow-x-auto pb-1">
            {PRESETS.map((preset, i) => (
              <button key={i} onClick={() => applyPreset(preset, i)}
                className={`shrink-0 rounded-xl border px-3 py-2 text-left transition min-w-[180px] ${
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
AFEOF

echo "  → src/lib/physics/coupledOscillators.ts"
cat > "src/lib/physics/coupledOscillators.ts" << 'AFEOF'
export interface OscillatorState {
  x1: number; v1: number;
  x2: number; v2: number;
}

export interface OscillatorParams {
  m1: number; m2: number;
  k1: number; k2: number; k3: number;
  damping1: number; damping2: number;
}

function derivatives(state: OscillatorState, params: OscillatorParams): [number, number, number, number] {
  const { m1, m2, k1, k2, k3, damping1, damping2 } = params;
  const { x1, v1, x2, v2 } = state;
  const f1 = -k1 * x1 - k2 * (x1 - x2) - damping1 * v1;
  const f2 = -k3 * x2 - k2 * (x2 - x1) - damping2 * v2;
  return [v1, f1 / m1, v2, f2 / m2];
}

export function rk4Step(state: OscillatorState, params: OscillatorParams, dt: number): OscillatorState {
  const s = state;
  const [k1_x1, k1_v1, k1_x2, k1_v2] = derivatives(s, params);
  const s2: OscillatorState = {
    x1: s.x1 + 0.5 * dt * k1_x1,
    v1: s.v1 + 0.5 * dt * k1_v1,
    x2: s.x2 + 0.5 * dt * k1_x2,
    v2: s.v2 + 0.5 * dt * k1_v2,
  };
  const [k2_x1, k2_v1, k2_x2, k2_v2] = derivatives(s2, params);
  const s3: OscillatorState = {
    x1: s.x1 + 0.5 * dt * k2_x1,
    v1: s.v1 + 0.5 * dt * k2_v1,
    x2: s.x2 + 0.5 * dt * k2_x2,
    v2: s.v2 + 0.5 * dt * k2_v2,
  };
  const [k3_x1, k3_v1, k3_x2, k3_v2] = derivatives(s3, params);
  const s4: OscillatorState = {
    x1: s.x1 + dt * k3_x1,
    v1: s.v1 + dt * k3_v1,
    x2: s.x2 + dt * k3_x2,
    v2: s.v2 + dt * k3_v2,
  };
  const [k4_x1, k4_v1, k4_x2, k4_v2] = derivatives(s4, params);
  return {
    x1: s.x1 + (dt / 6) * (k1_x1 + 2 * k2_x1 + 2 * k3_x1 + k4_x1),
    v1: s.v1 + (dt / 6) * (k1_v1 + 2 * k2_v1 + 2 * k3_v1 + k4_v1),
    x2: s.x2 + (dt / 6) * (k1_x2 + 2 * k2_x2 + 2 * k3_x2 + k4_x2),
    v2: s.v2 + (dt / 6) * (k1_v2 + 2 * k2_v2 + 2 * k3_v2 + k4_v2),
  };
}

export function kineticEnergy(state: OscillatorState, params: OscillatorParams): number {
  return 0.5 * params.m1 * state.v1 * state.v1 + 0.5 * params.m2 * state.v2 * state.v2;
}

export function potentialEnergy(state: OscillatorState, params: OscillatorParams): number {
  const { k1, k2, k3 } = params;
  const { x1, x2 } = state;
  return 0.5 * k1 * x1 * x1 + 0.5 * k2 * (x1 - x2) * (x1 - x2) + 0.5 * k3 * x2 * x2;
}

export function totalEnergy(state: OscillatorState, params: OscillatorParams): number {
  return kineticEnergy(state, params) + potentialEnergy(state, params);
}

export interface OscillatorPreset {
  name: string;
  description: string;
  x1: number; x2: number;
  v1: number; v2: number;
  m1: number; m2: number;
  k1: number; k2: number; k3: number;
  damping1: number; damping2: number;
}

export const PRESETS: OscillatorPreset[] = [
  {
    name: 'In-phase mode',
    description: 'Both masses displaced equally — they oscillate together as one. The coupling spring is never stretched.',
    x1: 0.1, x2: 0.1, v1: 0, v2: 0,
    m1: 1, m2: 1, k1: 1, k2: 0.2, k3: 1, damping1: 0, damping2: 0,
  },
  {
    name: 'Out-of-phase mode',
    description: 'Masses displaced oppositely — they oscillate in mirror motion. The coupling spring stretches and compresses maximally.',
    x1: 0.1, x2: -0.1, v1: 0, v2: 0,
    m1: 1, m2: 1, k1: 1, k2: 0.2, k3: 1, damping1: 0, damping2: 0,
  },
  {
    name: 'Beats',
    description: 'Start one mass moving, the other at rest. Energy sloshes back and forth between the two masses — the hallmark of weak coupling.',
    x1: 0.2, x2: 0, v1: 0, v2: 0,
    m1: 1, m2: 1, k1: 1, k2: 0.1, k3: 1, damping1: 0, damping2: 0,
  },
  {
    name: 'Heavy second mass',
    description: 'A much heavier second mass barely moves, acting like a fixed anchor for the first.',
    x1: 0.2, x2: 0, v1: 0, v2: 0,
    m1: 1, m2: 5, k1: 1, k2: 0.5, k3: 1, damping1: 0, damping2: 0,
  },
  {
    name: 'Damped decay',
    description: 'With friction, the oscillations die away. The energy envelope decays exponentially.',
    x1: 0.2, x2: 0, v1: 0, v2: 0,
    m1: 1, m2: 1, k1: 1, k2: 0.2, k3: 1, damping1: 0.1, damping2: 0.1,
  },
  {
    name: 'Strong coupling',
    description: 'A stiff coupling spring forces the masses to move nearly as a single rigid body.',
    x1: 0.1, x2: 0, v1: 0, v2: 0,
    m1: 1, m2: 1, k1: 0.5, k2: 2, k3: 0.5, damping1: 0, damping2: 0,
  },
];

export interface TrailPoint { x1: number; x2: number; t: number; }

export function addTrailPoint(trail: TrailPoint[], x1: number, x2: number, simT: number, maxAge: number): TrailPoint[] {
  const newTrail = [...trail, { x1, x2, t: simT }];
  return newTrail.filter(p => simT - p.t < maxAge);
}

/* Re-use the same decay analysis interface / logic from doublePendulum.ts */
export interface DecayAnalysis {
  qFactor: number;
  bandwidth: number;
  decayRate: number;
  valid: boolean;
}

export interface DecayPoint {
  t: number;
  e: number;
  signal: number;
}

export function analyzeDecay(history: DecayPoint[]): DecayAnalysis {
  if (history.length < 24) {
    return { qFactor: 0, bandwidth: 0, decayRate: 0, valid: false };
  }
  const pts = history.filter(p => p.e > 1e-6 && Number.isFinite(p.e));
  if (pts.length < 20) {
    return { qFactor: 0, bandwidth: 0, decayRate: 0, valid: false };
  }
  let sumT = 0, sumLnE = 0, sumT2 = 0, sumTLnE = 0, n = 0;
  for (const p of pts) {
    const lnE = Math.log(p.e);
    sumT += p.t;
    sumLnE += lnE;
    sumT2 += p.t * p.t;
    sumTLnE += p.t * lnE;
    n++;
  }
  const meanT = sumT / n;
  const meanLnE = sumLnE / n;
  const denom = sumT2 - n * meanT * meanT;
  if (Math.abs(denom) < 1e-12) {
    return { qFactor: 0, bandwidth: 0, decayRate: 0, valid: false };
  }
  const slope = (sumTLnE - n * meanT * meanLnE) / denom;
  const gamma = -slope;

  const crossings: number[] = [];
  for (let i = 1; i < pts.length; i++) {
    const prev = pts[i - 1];
    const curr = pts[i];
    if (prev.signal * curr.signal < 0 && prev.signal !== 0) {
      const frac = Math.abs(prev.signal) / (Math.abs(prev.signal) + Math.abs(curr.signal));
      const tc = prev.t + (curr.t - prev.t) * frac;
      crossings.push(tc);
    }
  }

  if (crossings.length < 2) {
    if (gamma <= 0.001) {
      return { qFactor: Infinity, bandwidth: 0, decayRate: gamma, valid: true };
    }
    return { qFactor: 0, bandwidth: 0, decayRate: gamma, valid: false };
  }

  let totalHalfPeriod = 0;
  for (let i = 1; i < crossings.length; i++) {
    totalHalfPeriod += crossings[i] - crossings[i - 1];
  }
  const avgHalfPeriod = totalHalfPeriod / (crossings.length - 1);
  const period = avgHalfPeriod * 2;
  const omega = (2 * Math.PI) / period;

  if (gamma <= 0.001) {
    return { qFactor: Infinity, bandwidth: 0, decayRate: gamma, valid: true };
  }
  const q = omega / gamma;
  if (!Number.isFinite(q) || q < 0) {
    return { qFactor: 0, bandwidth: 0, decayRate: gamma, valid: false };
  }
  return { qFactor: q, bandwidth: gamma, decayRate: gamma, valid: true };
}
AFEOF

echo "  → src/components/simulation/CoupledOscillatorsCanvas.tsx"
cat > "src/components/simulation/CoupledOscillatorsCanvas.tsx" << 'AFEOF'
'use client';
import { useRef, useEffect, useCallback } from 'react';
import {
  OscillatorState, OscillatorParams, rk4Step,
  kineticEnergy, potentialEnergy,
  addTrailPoint, TrailPoint,
  analyzeDecay, DecayAnalysis,
} from '@/lib/physics/coupledOscillators';

interface TickMeta {
  qFactor: number;
  bandwidth: number;
  decayRate: number;
  valid: boolean;
  chartHistory: Array<{ t: number; e: number }>;
}

interface Props {
  x1Init: number; v1Init: number;
  x2Init: number; v2Init: number;
  params: OscillatorParams;
  isRunning: boolean;
  isPaused: boolean;
  showTrail: boolean;
  showEnergy: boolean;
  trailLength: number;
  onTick?: (state: OscillatorState, energy: { ke: number; pe: number; total: number }, meta: TickMeta) => void;
  width?: number;
  height?: number;
}

export function CoupledOscillatorsCanvas({
  x1Init, v1Init, x2Init, v2Init,
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
  const simTimeRef = useRef(0);
  const energyHistoryRef = useRef<Array<{ t: number; e: number; signal: number }>>([]);
  const analysisRef = useRef<DecayAnalysis>({ qFactor: 0, bandwidth: 0, decayRate: 0, valid: false });
  const lastAnalysisRef = useRef(0);
  const chartHistoryRef = useRef<Array<{ t: number; e: number }>>([]);

  const stateRef = useRef<OscillatorState>({ x1: x1Init, v1: v1Init, x2: x2Init, v2: v2Init });
  const trailRef = useRef<TrailPoint[]>([]);

  const propsRef = useRef({ params, isRunning, isPaused, showTrail, showEnergy, trailLength, onTick });
  propsRef.current = { params, isRunning, isPaused, showTrail, showEnergy, trailLength, onTick };

  const initRef = useRef({ x1Init, v1Init, x2Init, v2Init });
  useEffect(() => {
    const prev = initRef.current;
    if (prev.x1Init !== x1Init || prev.v1Init !== v1Init ||
        prev.x2Init !== x2Init || prev.v2Init !== v2Init) {
      stateRef.current = { x1: x1Init, v1: v1Init, x2: x2Init, v2: v2Init };
      trailRef.current = [];
      lastFrameRef.current = null;
      simTimeRef.current = 0;
      energyHistoryRef.current = [];
      chartHistoryRef.current = [];
      analysisRef.current = { qFactor: 0, bandwidth: 0, decayRate: 0, valid: false };
      lastAnalysisRef.current = 0;
      initRef.current = { x1Init, v1Init, x2Init, v2Init };
    }
  }, [x1Init, v1Init, x2Init, v2Init]);

  const draw = useCallback((timestamp?: number) => {
    const canvas = canvasRef.current; if (!canvas) return;
    const ctx = canvas.getContext('2d'); if (!ctx) return;
    const s = propsRef.current;
    const W = canvas.width, H = canvas.height;

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
      const subSteps = Math.max(4, Math.ceil(dt * 300));
      const subDt = dt / subSteps;
      for (let i = 0; i < subSteps; i++) {
        stateRef.current = rk4Step(stateRef.current, s.params, subDt);
        simTimeRef.current += subDt;
      }

      if (s.showTrail) {
        trailRef.current = addTrailPoint(trailRef.current, stateRef.current.x1, stateRef.current.x2, simTimeRef.current, s.trailLength);
      }

      const ke = kineticEnergy(stateRef.current, s.params);
      const pe = potentialEnergy(stateRef.current, s.params);
      const total = ke + pe;

      energyHistoryRef.current.push({
        t: simTimeRef.current,
        e: total,
        signal: stateRef.current.x1,
      });
      const cutoff = simTimeRef.current - 5;
      energyHistoryRef.current = energyHistoryRef.current.filter(p => p.t > cutoff);

      const lastChart = chartHistoryRef.current[chartHistoryRef.current.length - 1];
      if (!lastChart || simTimeRef.current - lastChart.t > 0.12) {
        chartHistoryRef.current.push({ t: simTimeRef.current, e: total });
      }
      const chartCutoff = simTimeRef.current - 10;
      chartHistoryRef.current = chartHistoryRef.current.filter(p => p.t > chartCutoff);

      if (simTimeRef.current - lastAnalysisRef.current > 0.5 && energyHistoryRef.current.length > 40) {
        analysisRef.current = analyzeDecay(energyHistoryRef.current);
        lastAnalysisRef.current = simTimeRef.current;
      }

      s.onTick?.(stateRef.current, { ke, pe, total }, {
        qFactor: analysisRef.current.qFactor,
        bandwidth: analysisRef.current.bandwidth,
        decayRate: analysisRef.current.decayRate,
        valid: analysisRef.current.valid,
        chartHistory: [...chartHistoryRef.current],
      });
    }

    // ── Rendering ──────────────────────────────────────────────────────────
    ctx.clearRect(0, 0, W, H);
    ctx.fillStyle = '#0f172a'; ctx.fillRect(0, 0, W, H);

    const worldLeft = -0.4;
    const worldRight = 0.4;
    const worldWidth = worldRight - worldLeft;
    const trackY = H * 0.35;
    const wallX1 = W * 0.08;
    const wallX2 = W * 0.92;
    const screenWidth = wallX2 - wallX1;
    const scale = screenWidth / worldWidth;

    function worldToScreen(x: number) {
      return wallX1 + ((x - worldLeft) / worldWidth) * screenWidth;
    }

    // Track line
    ctx.strokeStyle = '#334155'; ctx.lineWidth = 2;
    ctx.beginPath(); ctx.moveTo(wallX1, trackY); ctx.lineTo(wallX2, trackY); ctx.stroke();

    // Walls
    ctx.fillStyle = '#475569';
    ctx.fillRect(wallX1 - 10, trackY - 50, 10, 100);
    ctx.fillRect(wallX2, trackY - 50, 10, 100);

    // Spring zig-zag helper
    function drawSpring(xA: number, xB: number, y: number, coils: number, amp: number, color: string) {
      const len = xB - xA;
      const seg = len / (coils * 2);
      ctx.strokeStyle = color;
      ctx.lineWidth = 2;
      ctx.lineJoin = 'round';
      ctx.beginPath();
      ctx.moveTo(xA, y);
      for (let i = 0; i < coils * 2; i++) {
        const x = xA + (i + 1) * seg;
        const yOff = (i % 2 === 0 ? -1 : 1) * amp;
        ctx.lineTo(x - seg / 2, y + yOff);
        ctx.lineTo(x, y);
      }
      ctx.stroke();
    }

    const sx1 = worldToScreen(stateRef.current.x1);
    const sx2 = worldToScreen(stateRef.current.x2);
    const mW1 = 18 + Math.min(s.params.m1, 5) * 10;
    const mW2 = 18 + Math.min(s.params.m2, 5) * 10;

    // Springs
    drawSpring(wallX1, sx1 - mW1 / 2, trackY, 10, 12, '#6366f1');
    drawSpring(sx1 + mW1 / 2, sx2 - mW2 / 2, trackY, 10, 12, '#f59e0b');
    drawSpring(sx2 + mW2 / 2, wallX2, trackY, 10, 12, '#10b981');

    // Mass 1
    ctx.fillStyle = '#6366f1';
    ctx.fillRect(sx1 - mW1 / 2, trackY - 22, mW1, 44);
    ctx.strokeStyle = '#4338ca'; ctx.lineWidth = 2;
    ctx.strokeRect(sx1 - mW1 / 2, trackY - 22, mW1, 44);
    ctx.fillStyle = 'white'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
    ctx.fillText(`${s.params.m1.toFixed(1)}`, sx1, trackY + 4);

    // Mass 2
    ctx.fillStyle = '#f59e0b';
    ctx.fillRect(sx2 - mW2 / 2, trackY - 22, mW2, 44);
    ctx.strokeStyle = '#d97706'; ctx.lineWidth = 2;
    ctx.strokeRect(sx2 - mW2 / 2, trackY - 22, mW2, 44);
    ctx.fillStyle = 'white';
    ctx.fillText(`${s.params.m2.toFixed(1)}`, sx2, trackY + 4);

    // Position readouts
    ctx.fillStyle = '#64748b'; ctx.font = '10px system-ui'; ctx.textAlign = 'left';
    ctx.fillText(`x₁ = ${stateRef.current.x1.toFixed(3)} m`, 12, H - 36);
    ctx.fillText(`x₂ = ${stateRef.current.x2.toFixed(3)} m`, 12, H - 22);
    ctx.fillText(`v₁ = ${stateRef.current.v1.toFixed(2)} m/s`, 12, H - 8);

    // Strip chart (position history)
    const chartH = 90;
    const chartY = H - chartH - 8;
    const chartW = W - 20;
    const chartX = 10;
    ctx.fillStyle = 'rgba(15, 23, 42, 0.6)';
    ctx.fillRect(chartX, chartY, chartW, chartH);
    ctx.strokeStyle = '#334155'; ctx.lineWidth = 1;
    ctx.strokeRect(chartX, chartY, chartW, chartH);

    // Center line
    ctx.strokeStyle = '#1e293b'; ctx.lineWidth = 1;
    ctx.beginPath(); ctx.moveTo(chartX, chartY + chartH / 2); ctx.lineTo(chartX + chartW, chartY + chartH / 2); ctx.stroke();

    if (trailRef.current.length > 1) {
      const tWindow = 6;
      const maxX = Math.max(0.25, ...trailRef.current.map(p => Math.max(Math.abs(p.x1), Math.abs(p.x2))));

      // x1 trace
      ctx.strokeStyle = '#6366f1'; ctx.lineWidth = 1.5;
      ctx.beginPath();
      let first = true;
      for (const p of trailRef.current) {
        const age = simTimeRef.current - p.t;
        if (age > tWindow) continue;
        const x = chartX + chartW * (1 - age / tWindow);
        const y = chartY + chartH / 2 - (p.x1 / maxX) * (chartH / 2 - 6);
        if (first) { ctx.moveTo(x, y); first = false; }
        else { ctx.lineTo(x, y); }
      }
      ctx.stroke();

      // x2 trace
      ctx.strokeStyle = '#f59e0b'; ctx.lineWidth = 1.5;
      ctx.beginPath();
      first = true;
      for (const p of trailRef.current) {
        const age = simTimeRef.current - p.t;
        if (age > tWindow) continue;
        const x = chartX + chartW * (1 - age / tWindow);
        const y = chartY + chartH / 2 - (p.x2 / maxX) * (chartH / 2 - 6);
        if (first) { ctx.moveTo(x, y); first = false; }
        else { ctx.lineTo(x, y); }
      }
      ctx.stroke();

      ctx.fillStyle = '#94a3b8'; ctx.font = '8px system-ui'; ctx.textAlign = 'left';
      ctx.fillText('x₁', chartX + 4, chartY + 12);
      ctx.fillText('x₂', chartX + 4, chartY + 22);
      ctx.fillStyle = '#6366f1'; ctx.fillRect(chartX + 22, chartY + 7, 8, 3);
      ctx.fillStyle = '#f59e0b'; ctx.fillRect(chartX + 22, chartY + 17, 8, 3);
    }

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
      ctx.fillText(`${total.toFixed(3)}J`, barX + barW - 38, barY + barH + 10);
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
    return () => cancelAnimationFrame(rafRef.current);
  }, [draw]);

  return (
    <canvas ref={canvasRef} width={width} height={height}
      className="w-full rounded-xl border border-gray-700 bg-slate-900" style={{ display: 'block' }} />
  );
}
AFEOF

echo "  → src/app/simulations/coupled-oscillators/page.tsx"
cat > "src/app/simulations/coupled-oscillators/page.tsx" << 'AFEOF'
'use client';
import { useState, useCallback, useRef, useEffect } from 'react';
import { AppHeader } from '@/components/layout/AppHeader';
import { SimulationControls } from '@/components/simulation/SimulationControls';
import { CoupledOscillatorsCanvas } from '@/components/simulation/CoupledOscillatorsCanvas';
import { EmbedButton } from '@/components/ui/EmbedButton';
import { useResponsiveCanvasSize } from '@/hooks/useResponsiveCanvasSize';
import {
  OscillatorState, OscillatorParams, totalEnergy,
  PRESETS, OscillatorPreset,
} from '@/lib/physics/coupledOscillators';

const CURRICULA = ['WAEC', 'NECO', 'IGCSE', 'SAT', 'JUPEB'];
const CC: Record<string, string> = {
  WAEC: 'bg-indigo-100 text-indigo-700', NECO: 'bg-pink-100 text-pink-700',
  IGCSE: 'bg-emerald-100 text-emerald-700', SAT: 'bg-orange-100 text-orange-700',
  JUPEB: 'bg-purple-100 text-purple-700',
};

const TEACHER_NOTES = [
  'Coupled oscillators are the linear counterpart to the double pendulum. Instead of chaos, we get superposition of normal modes.',
  'The system has two normal modes: in-phase (both masses move together) and out-of-phase (they move oppositely). Any motion is a sum of these two modes.',
  'When the coupling is weak and the two individual oscillators have nearly the same frequency, you see beats — periodic transfer of energy from one mass to the other.',
  'The beat frequency is the difference between the two normal-mode frequencies: f_beat = |ω₂ − ω₁| / (2π).',
  'Damping removes energy from the system. The Q-factor tells you how many oscillations occur before the energy drops significantly: Q ≈ 2π × (energy stored) / (energy lost per cycle).',
  'In the damped case, the motion eventually settles into the slower normal mode because higher frequencies are damped more strongly.',
];

const EXERCISES = [
  {
    q: 'Run the "Beats" preset and watch the strip chart. How many seconds does one complete beat cycle take?',
    a: 'For the default parameters (k₁=k₃=1, k₂=0.1, m=1), the normal-mode frequencies are ω₁≈1.00 rad/s and ω₂≈1.10 rad/s. The beat period is 2π/|ω₂−ω₁| ≈ 63 s. You will see roughly one full exchange in about 60–65 seconds.',
  },
  {
    q: 'Compare the "In-phase" and "Out-of-phase" presets. Which one has the higher frequency? Why?',
    a: 'Out-of-phase has the higher frequency because the coupling spring is stretched and adds an effective restoring force. For symmetric springs, ω_out² = (k + 2k_c)/m  versus  ω_in² = k/m.',
  },
  {
    q: 'Increase the coupling spring constant k₂ to 2.0 and run "Beats". What happens to the beat pattern?',
    a: 'Strong coupling increases the frequency splitting, so the beat period becomes shorter and the energy transfer happens faster. If k₂ is very large, the two masses are forced to move almost as a single rigid body.',
  },
  {
    q: 'Enable damping and observe the Q-factor. Does Q stay constant as the motion decays?',
    a: 'For linear damping, Q should remain roughly constant if the frequency does not change much. However, numerical noise at very small amplitudes can make Q fluctuate at the end.',
  },
  {
    q: 'Set m₂ = 5 kg and run "Heavy second mass". Why does the first mass oscillate while the second barely moves?',
    a: 'The heavy mass has large inertia, so the coupling force barely accelerates it. It acts almost like a fixed wall, and m₁ oscillates with a frequency close to √( (k₁+k₂)/m₁ ).',
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

function DampingCurve({ history }: { history: Array<{ t: number; e: number }> }) {
  if (history.length < 3) return (
    <div className="rounded-lg bg-slate-900 border border-gray-700 h-24 flex items-center justify-center">
      <span className="text-[10px] text-gray-500">Run simulation to see decay curve</span>
    </div>
  );
  const W = 220;
  const H = 96;
  const pad = 10;
  const times = history.map(h => h.t);
  const minT = times[0];
  const maxT = times[times.length - 1];
  const rangeT = maxT - minT || 1;
  const logEs = history.map(h => Math.log(Math.max(h.e, 1e-6)));
  const minE = Math.min(...logEs);
  const maxE = Math.max(...logEs);
  const rangeE = maxE - minE || 1;
  const pts = history.map((h, i) => {
    const x = pad + ((h.t - minT) / rangeT) * (W - 2 * pad);
    const y = H - pad - ((logEs[i] - minE) / rangeE) * (H - 2 * pad);
    return `${x},${y}`;
  }).join(' ');
  return (
    <div className="rounded-lg bg-slate-900 border border-gray-700 overflow-hidden">
      <svg width={W} height={H} viewBox={`0 0 ${W} ${H}`} className="block">
        <polyline points={pts} fill="none" stroke="#10b981" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" />
        <text x={pad} y={pad + 8} fill="#94a3b8" fontSize="8" fontFamily="system-ui">ln(E) vs time</text>
        <line x1={pad} y1={H - pad} x2={W - pad} y2={H - pad} stroke="#334155" strokeWidth="0.5" />
        <line x1={pad} y1={pad} x2={pad} y2={H - pad} stroke="#334155" strokeWidth="0.5" />
      </svg>
    </div>
  );
}

export default function CoupledOscillatorsPage() {
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
  const [k1, setK1] = useState(1);
  const [k2, setK2] = useState(0.2);
  const [k3, setK3] = useState(1);
  const [x1, setX1] = useState(0.1);
  const [x2, setX2] = useState(0.1);
  const [v1, setV1] = useState(0);
  const [v2, setV2] = useState(0);
  const [damping1, setDamping1] = useState(0);
  const [damping2, setDamping2] = useState(0);

  const [liveEnergy, setLiveEnergy] = useState({ ke: 0, pe: 0, total: 0 });
  const [liveState, setLiveState] = useState({ x1: 0, x2: 0, v1: 0, v2: 0 });
  const [liveMeta, setLiveMeta] = useState({ qFactor: 0, bandwidth: 0, decayRate: 0, valid: false });
  const [chartHistory, setChartHistory] = useState<Array<{ t: number; e: number }>>([]);

  const params: OscillatorParams = { m1, m2, k1, k2, k3, damping1, damping2 };

  useEffect(() => {
    const idx = PRESETS.findIndex(p =>
      Math.abs(p.m1 - m1) < 0.05 && Math.abs(p.m2 - m2) < 0.05 &&
      Math.abs(p.k1 - k1) < 0.05 && Math.abs(p.k2 - k2) < 0.05 && Math.abs(p.k3 - k3) < 0.05 &&
      Math.abs(p.x1 - x1) < 0.005 && Math.abs(p.x2 - x2) < 0.005 &&
      Math.abs(p.v1 - v1) < 0.05 && Math.abs(p.v2 - v2) < 0.05 &&
      Math.abs(p.damping1 - damping1) < 0.005 && Math.abs(p.damping2 - damping2) < 0.005
    );
    setActivePreset(idx >= 0 ? idx : null);
  }, [m1, m2, k1, k2, k3, x1, x2, v1, v2, damping1, damping2]);

  const applyPreset = useCallback((preset: OscillatorPreset, index: number) => {
    setM1(preset.m1); setM2(preset.m2); setK1(preset.k1); setK2(preset.k2); setK3(preset.k3);
    setX1(preset.x1); setX2(preset.x2); setV1(preset.v1); setV2(preset.v2);
    setDamping1(preset.damping1); setDamping2(preset.damping2);
    setIsRunning(false); setIsPaused(false);
    setResetKey(k => k + 1);
    setLiveEnergy({ ke: 0, pe: 0, total: 0 });
    setLiveState({ x1: 0, x2: 0, v1: 0, v2: 0 });
    setLiveMeta({ qFactor: 0, bandwidth: 0, decayRate: 0, valid: false });
    setChartHistory([]);
    setActivePreset(index);
  }, []);

  const reset = useCallback(() => {
    setIsRunning(false); setIsPaused(false);
    setResetKey(k => k + 1);
    setLiveEnergy({ ke: 0, pe: 0, total: 0 });
    setLiveState({ x1: 0, x2: 0, v1: 0, v2: 0 });
    setLiveMeta({ qFactor: 0, bandwidth: 0, decayRate: 0, valid: false });
    setChartHistory([]);
  }, []);

  const canvasBoxRef = useRef<HTMLDivElement>(null);
  const canvasSize = useResponsiveCanvasSize(canvasBoxRef, 660, 420, 900);

  const lastTickRef = useRef(0);
  const handleTick = useCallback((state: OscillatorState, energy: { ke: number; pe: number; total: number }, meta: { qFactor: number; bandwidth: number; decayRate: number; valid: boolean; chartHistory: Array<{ t: number; e: number }> }) => {
    const now = performance.now();
    if (now - lastTickRef.current < 80) return;
    lastTickRef.current = now;
    setLiveState({ x1: state.x1, x2: state.x2, v1: state.v1, v2: state.v2 });
    setLiveEnergy(energy);
    setLiveMeta({ qFactor: meta.qFactor, bandwidth: meta.bandwidth, decayRate: meta.decayRate, valid: meta.valid });
    setChartHistory(meta.chartHistory);
  }, []);

  const initialState: OscillatorState = { x1, v1, x2, v2 };
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
                <p className="text-xs text-gray-400 mb-0.5">Mechanics — Linear Systems</p>
                <h1 className="text-lg font-semibold text-gray-900">Coupled oscillators</h1>
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
            <span className="text-xs text-gray-400">Linear coupled oscillators — normal modes & beats</span>
            <span className="text-sm font-semibold font-mono text-gray-900">F = −kx − c v</span>
          </div>

          <div className="flex gap-2 overflow-x-auto pb-1">
            {PRESETS.map((preset, i) => (
              <button key={i} onClick={() => applyPreset(preset, i)}
                className={`shrink-0 rounded-xl border px-3 py-2 text-left transition min-w-[180px] ${
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
                <CoupledOscillatorsCanvas
                  key={resetKey}
                  x1Init={x1}
                  v1Init={v1}
                  x2Init={x2}
                  v2Init={v2}
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
                <EmbedButton path="/embed/coupled-oscillators"
                  title="Coupled Oscillators — A-Factor STEM Studio"
                  params={{ m1, m2, k1, k2, k3, x1, x2, v1, v2, d1: damping1, d2: damping2, trail: trailLength }}
                />
              </div>

              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm space-y-4">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide">Parameters</p>
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                  <div className="space-y-3">
                    <p className="text-[10px] font-medium text-indigo-600 uppercase tracking-wide">First mass</p>
                    <Slider label="Mass m₁" unit="kg" value={m1} min={0.1} max={5} step={0.1} set={setM1} color="#6366f1" />
                    <Slider label="Spring k₁" unit="N/m" value={k1} min={0.1} max={5} step={0.1} set={setK1} color="#818cf8" />
                    <Slider label="Initial x₁" unit="m" value={x1} min={-0.3} max={0.3} step={0.01} set={setX1} color="#a78bfa" />
                    <Slider label="Initial v₁" unit="m/s" value={v1} min={-2} max={2} step={0.05} set={setV1} color="#c4b5fd" />
                    <Slider label="Damping c₁" unit="" value={damping1} min={0} max={1} step={0.01} set={setDamping1} color="#ef4444" />
                  </div>
                  <div className="space-y-3">
                    <p className="text-[10px] font-medium text-amber-600 uppercase tracking-wide">Second mass</p>
                    <Slider label="Mass m₂" unit="kg" value={m2} min={0.1} max={5} step={0.1} set={setM2} color="#f59e0b" />
                    <Slider label="Spring k₃" unit="N/m" value={k3} min={0.1} max={5} step={0.1} set={setK3} color="#fbbf24" />
                    <Slider label="Initial x₂" unit="m" value={x2} min={-0.3} max={0.3} step={0.01} set={setX2} color="#fcd34d" />
                    <Slider label="Initial v₂" unit="m/s" value={v2} min={-2} max={2} step={0.05} set={setV2} color="#fde68a" />
                    <Slider label="Damping c₂" unit="" value={damping2} min={0} max={1} step={0.01} set={setDamping2} color="#ef4444" />
                  </div>
                </div>
                <div className="border-t border-gray-100 pt-3 space-y-3">
                  <Slider label="Coupling k₂" unit="N/m" value={k2} min={0} max={5} step={0.05} set={setK2} color="#10b981" note="Spring between the two masses" />
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
                  <StatRow label="Initial total E" value={initialTotalEnergy.toFixed(4)} unit="J" color="text-indigo-600" />
                  <StatRow label="Live kinetic E" value={liveEnergy.ke.toFixed(4)} unit="J" color="text-rose-500" />
                  <StatRow label="Live potential E" value={liveEnergy.pe.toFixed(4)} unit="J" color="text-blue-500" />
                  <StatRow label="Live total E" value={liveEnergy.total.toFixed(4)} unit="J" color="text-emerald-600" />
                  <StatRow label="x₁" value={liveState.x1.toFixed(3)} unit="m" color="text-purple-600" />
                  <StatRow label="x₂" value={liveState.x2.toFixed(3)} unit="m" color="text-amber-600" />
                  <StatRow label="v₁" value={liveState.v1.toFixed(2)} unit="m/s" color="text-indigo-500" />
                  <StatRow label="v₂" value={liveState.v2.toFixed(2)} unit="m/s" color="text-amber-500" />
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
AFEOF

echo "  → src/app/embed/coupled-oscillators/page.tsx"
cat > "src/app/embed/coupled-oscillators/page.tsx" << 'AFEOF'
'use client';
import { Suspense, useState, useCallback, useRef } from 'react';
import { useSearchParams } from 'next/navigation';
import { CoupledOscillatorsCanvas } from '@/components/simulation/CoupledOscillatorsCanvas';
import { SimulationControls } from '@/components/simulation/SimulationControls';
import { OscillatorParams } from '@/lib/physics/coupledOscillators';

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

function CoupledOscillatorsEmbedInner() {
  const sp = useSearchParams();
  const showControls = sp.get('controls') !== '0';

  const [m1, setM1] = useState(() => num(sp, 'm1', 1, 0.1, 5));
  const [m2, setM2] = useState(() => num(sp, 'm2', 1, 0.1, 5));
  const [k1, setK1] = useState(() => num(sp, 'k1', 1, 0.1, 5));
  const [k2, setK2] = useState(() => num(sp, 'k2', 0.2, 0, 5));
  const [k3, setK3] = useState(() => num(sp, 'k3', 1, 0.1, 5));
  const [x1, setX1] = useState(() => num(sp, 'x1', 0.1, -0.3, 0.3));
  const [x2, setX2] = useState(() => num(sp, 'x2', 0.1, -0.3, 0.3));
  const [v1, setV1] = useState(() => num(sp, 'v1', 0, -2, 2));
  const [v2, setV2] = useState(() => num(sp, 'v2', 0, -2, 2));
  const [damping1, setDamping1] = useState(() => num(sp, 'd1', 0, 0, 1));
  const [damping2, setDamping2] = useState(() => num(sp, 'd2', 0, 0, 1));
  const [trailLength, setTrailLength] = useState(() => Math.round(num(sp, 'trail', 300, 0, 800)));
  const [showTrail, setShowTrail] = useState(true);
  const [showEnergy, setShowEnergy] = useState(true);

  const params: OscillatorParams = { m1, m2, k1, k2, k3, damping1, damping2 };

  const [isRunning, setIsRunning] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const [resetKey, setResetKey] = useState(0);
  const reset = useCallback(() => { setIsRunning(false); setIsPaused(false); setResetKey(k => k + 1); }, []);

  return (
    <div className="mx-auto max-w-2xl space-y-3 p-3 sm:p-4">
      <CoupledOscillatorsCanvas
        key={resetKey}
        x1Init={x1}
        v1Init={v1}
        x2Init={x2}
        v2Init={v2}
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
          <Slider label="Mass m₁" unit="kg" value={m1} min={0.1} max={5} step={0.1} set={setM1} color="#6366f1" />
          <Slider label="Mass m₂" unit="kg" value={m2} min={0.1} max={5} step={0.1} set={setM2} color="#f59e0b" />
          <Slider label="Spring k₁" unit="N/m" value={k1} min={0.1} max={5} step={0.1} set={setK1} color="#818cf8" />
          <Slider label="Coupling k₂" unit="N/m" value={k2} min={0} max={5} step={0.05} set={setK2} color="#10b981" />
          <Slider label="Spring k₃" unit="N/m" value={k3} min={0.1} max={5} step={0.1} set={setK3} color="#fbbf24" />
          <Slider label="Damping c₁" unit="" value={damping1} min={0} max={1} step={0.01} set={setDamping1} color="#ef4444" />
          <Slider label="Damping c₂" unit="" value={damping2} min={0} max={1} step={0.01} set={setDamping2} color="#ef4444" />
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

export default function CoupledOscillatorsEmbedPage() {
  return (
    <Suspense fallback={<div className="p-8 text-center text-xs text-gray-400">Loading simulation…</div>}>
      <CoupledOscillatorsEmbedInner />
    </Suspense>
  );
}
AFEOF

echo ""
echo "✓ Patch v20 applied — 6 files written."
echo ""
echo "Next steps:"
echo "  rm -rf .next"
echo "  npm run dev"
echo ""
echo "Check: /simulations/double-pendulum"
echo "  • Presets now highlight when active (and auto-detect if you manually match sliders)."
echo "  • Q-factor & bandwidth are computed live from the energy envelope."
echo "  • Damping curve (ln E vs t) appears in the sidebar once running."
echo ""
echo "Check: /simulations/coupled-oscillators  (NEW)"
echo "  • Two masses + three springs on a horizontal track."
echo "  • Strip chart shows x₁(t) and x₂(t) in real time."
echo "  • Same Q/BW analysis, energy monitor, presets, and embed support."
echo ""
echo "REMINDER: Add both simulations to src/app/simulations/page.tsx SIMULATIONS array:"
echo '  // (double-pendulum should already be there from v19)'
echo '  {'
echo '    slug: '"'"'coupled-oscillators'"'"','
echo '    href: '"'"'/simulations/coupled-oscillators'"'"','
echo '    title: '"'"'Coupled oscillators'"'"','
echo '    description: '"'"'Explore normal modes, beats, and energy transfer in a linear coupled spring–mass system.'"'"','
echo '    icon: '"'"'🔘'"'"','
echo '    tags: ['"'"'IGCSE'"'"', '"'"'SAT'"'"', '"'"'JUPEB'"'"'],'
echo '    topic: '"'"'Mechanics'"'"','
echo '    status: '"'"'live'"'"','
echo '  },'
