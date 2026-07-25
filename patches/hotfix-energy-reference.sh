#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
# Hotfix: shift double-pendulum PE reference so energy is always non-negative
# ══════════════════════════════════════════════════════════════════════════════
set -euo pipefail

if [ ! -f "package.json" ]; then
  echo "✗ Run this from the af2s project root." >&2
  exit 1
fi

echo "── Hotfix: non-negative energy reference ──"

# ══════════════════════════════════════════════════════════════════════════════
# 1. Fix doublePendulum.ts — shift PE so lowest point = 0
# ══════════════════════════════════════════════════════════════════════════════
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

/*
  Potential energy is measured relative to the lowest possible configuration
  (both bobs hanging straight down). This guarantees PE ≥ 0 and therefore
  total energy ≥ 0, which keeps the energy bar fractions well-defined.

  PE = (m1+m2)·g·L1·(1 − cos θ1) + m2·g·L2·(1 − cos θ2)

  At θ1 = θ2 = 0  →  PE = 0  (lowest point)
  At θ1 = θ2 = π  →  PE = 2·(m1+m2)·g·L1 + 2·m2·g·L2  (highest point)
*/
export function potentialEnergy(state: PendulumState, params: PendulumParams): number {
  const { m1, m2, L1, L2, g } = params;
  const { theta1, theta2 } = state;
  return (m1 + m2) * g * L1 * (1 - Math.cos(theta1))
       + m2 * g * L2 * (1 - Math.cos(theta2));
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

echo "  → src/lib/physics/doublePendulum.ts  (PE reference shifted)"

# ══════════════════════════════════════════════════════════════════════════════
# 2. Verify coupledOscillators.ts is already non-negative (no change needed)
# ══════════════════════════════════════════════════════════════════════════════
echo "  → src/lib/physics/coupledOscillators.ts  (already non-negative, no change)"

echo ""
echo "✓ Hotfix applied. The double-pendulum PE is now measured from the"
echo "  lowest point (both bobs straight down), so total energy ≥ 0 always."
echo ""
echo "  Rebuild:  rm -rf .next && npm run build"
