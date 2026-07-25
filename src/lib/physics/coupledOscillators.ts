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
