export const g = 9.81;

// ── Elevator ──────────────────────────────────────────────────────────────────
export type ElevatorState = 'rest' | 'accel-up' | 'constant-up' | 'decel-up' | 'accel-down' | 'constant-down' | 'decel-down' | 'freefall';

export function apparentWeight(mass: number, acceleration: number): number {
  return mass * (g + acceleration); // N, acceleration positive=up
}

export function elevatorAcceleration(state: ElevatorState, a: number): number {
  switch (state) {
    case 'accel-up':    return +a;
    case 'decel-up':    return -a;
    case 'accel-down':  return -a;
    case 'decel-down':  return +a;
    case 'freefall':    return -g;
    default:            return 0;
  }
}

// ── Collision ─────────────────────────────────────────────────────────────────
export interface CollisionParams {
  m1: number; u1: number; // mass kg, initial velocity m/s
  m2: number; u2: number;
  type: 'elastic' | 'inelastic' | 'perfectly-inelastic';
  e?: number; // coefficient of restitution (0-1)
}

export function solveCollision(p: CollisionParams) {
  const { m1, u1, m2, u2, type } = p;
  const e = type === 'elastic' ? 1 : type === 'perfectly-inelastic' ? 0 : (p.e ?? 0.5);

  // Conservation of momentum: m1u1 + m2u2 = m1v1 + m2v2
  // Coefficient of restitution: e = (v2 - v1) / (u1 - u2)
  const v2 = (m1 * u1 * (1 + e) + u2 * (m2 - e * m1)) / (m1 + m2);
  const v1 = e * (u2 - u1) + v2;

  const keBefore = 0.5 * m1 * u1 * u1 + 0.5 * m2 * u2 * u2;
  const keAfter  = 0.5 * m1 * v1 * v1 + 0.5 * m2 * v2 * v2;
  const momentumBefore = m1 * u1 + m2 * u2;
  const momentumAfter  = m1 * v1 + m2 * v2;

  return {
    v1: +v1.toFixed(3), v2: +v2.toFixed(3),
    keBefore: +keBefore.toFixed(2), keAfter: +keAfter.toFixed(2),
    keLost: +(keBefore - keAfter).toFixed(2),
    momentumBefore: +momentumBefore.toFixed(3),
    momentumAfter: +momentumAfter.toFixed(3),
    impulse: +(m1 * (v1 - u1)).toFixed(3),
  };
}

// ── Propulsion ────────────────────────────────────────────────────────────────
export function rocketAnalytics(m: number, exhaustSpeed: number, massFlowRate: number) {
  const thrust = exhaustSpeed * massFlowRate; // N
  const a = thrust / m;
  return { thrust: +thrust.toFixed(1), acceleration: +a.toFixed(3) };
}

// ── Impulse ───────────────────────────────────────────────────────────────────
export function impulse(force: number, time: number) {
  return force * time;
}
export function impulseMomentum(mass: number, u: number, v: number) {
  return mass * (v - u); // = impulse
}
