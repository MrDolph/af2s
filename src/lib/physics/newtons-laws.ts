export const g = 9.81; // m/s²

// ── First Law ─────────────────────────────────────────────────────────────────
export interface FirstLawState {
  x: number;       // position m
  v: number;       // velocity m/s
  time: number;
}
export function stepFirstLaw(
  state: FirstLawState,
  appliedForce: number,  // N (0 = inertia demo)
  mass: number,
  friction: number,      // coefficient 0–1
  dt: number
): FirstLawState {
  const normalForce = mass * g;
  const frictionForce = friction * normalForce * (state.v !== 0 ? -Math.sign(state.v) : 0);
  const netF = appliedForce + frictionForce;
  const a = netF / mass;
  const newV = state.v + a * dt;
  // Stop if friction kills motion and no force applied
  const stopped = appliedForce === 0 && Math.abs(newV) < 0.01 && Math.abs(state.v) < 0.5;
  return {
    x: state.x + (stopped ? 0 : state.v) * dt,
    v: stopped ? 0 : newV,
    time: state.time + dt,
  };
}

// ── Second Law ────────────────────────────────────────────────────────────────
export interface SecondLawParams {
  mass: number;          // kg
  appliedForce: number;  // N
  friction: number;      // coefficient 0–1
}
export interface SecondLawState {
  x: number; v: number; a: number; time: number;
  frictionForce: number; netForce: number;
}
export function getSecondLawAcceleration(p: SecondLawParams, v: number): number {
  const frictionF = p.friction * p.mass * g * (v !== 0 ? -Math.sign(v) : (p.appliedForce > 0 ? -1 : 1));
  const netF = p.appliedForce + frictionF;
  // Only apply friction if moving, or if static friction can't resist applied force
  const staticFrictionMax = p.friction * p.mass * g;
  if (v === 0 && Math.abs(p.appliedForce) <= staticFrictionMax) return 0;
  return netF / p.mass;
}
export function stepSecondLaw(
  state: SecondLawState, params: SecondLawParams, dt: number
): SecondLawState {
  const a = getSecondLawAcceleration(params, state.v);
  const newV = Math.max(0, state.v + a * dt); // block doesn't go backward in this demo
  const frictionF = params.friction * params.mass * g * (state.v !== 0 ? -1 : 0);
  return {
    x: state.x + state.v * dt,
    v: newV,
    a,
    time: state.time + dt,
    frictionForce: frictionF,
    netForce: params.appliedForce + frictionF,
  };
}
export function secondLawAnalytics(p: SecondLawParams) {
  const frictionF = p.friction * p.mass * g;
  const netF = Math.max(0, p.appliedForce - frictionF);
  const a = netF / p.mass;
  return { acceleration: +a.toFixed(3), netForce: +netF.toFixed(2), frictionForce: +frictionF.toFixed(2) };
}

// ── Third Law ─────────────────────────────────────────────────────────────────
export interface ThirdLawScenario {
  type: 'push' | 'rocket' | 'collision';
  mass1: number; mass2: number;
  force: number; // N
}
export function thirdLawAnalytics(s: ThirdLawScenario) {
  const a1 = s.force / s.mass1;
  const a2 = s.force / s.mass2;
  return { a1: +a1.toFixed(3), a2: +a2.toFixed(3), force: s.force };
}
