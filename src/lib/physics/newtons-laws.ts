export const g = 9.81; // m/s²

// ── First Law ─────────────────────────────────────────────────────────────────
export interface FirstLawState {
  x: number;       // position m
  v: number;       // velocity m/s
  time: number;
}

export function firstLawAcceleration(v: number, mass: number, friction: number, appliedForce: number): number {
  const maxStaticFriction = friction * mass * g;
  if (v === 0) {
    // At rest: static friction balances the applied force exactly, up to
    // its limit — it does NOT jump straight to its maximum value.
    return Math.abs(appliedForce) <= maxStaticFriction
      ? 0
      : (appliedForce - Math.sign(appliedForce) * maxStaticFriction) / mass;
  }
  return (appliedForce - maxStaticFriction * Math.sign(v)) / mass;
}

export function stepFirstLaw(
  state: FirstLawState,
  appliedForce: number,  // N (0 = inertia demo)
  mass: number,
  friction: number,      // coefficient 0–1
  dt: number
): FirstLawState {
  const a = firstLawAcceleration(state.v, mass, friction, appliedForce);
  let newV = state.v + a * dt;
  // Friction can never reverse the direction of motion in one step — it
  // can only bring the object to rest.
  if ((state.v > 0 && newV < 0) || (state.v < 0 && newV > 0)) newV = 0;
  // Trapezoidal integration for smoother position updates at larger dt.
  const x = state.x + (state.v + newV) / 2 * dt;
  return { x, v: newV, time: state.time + dt };
}

export interface FirstLawTrajectoryPoint { t: number; v: number; a: number; x: number; }

// Precomputes the full v/a/x-against-t curve up front (reusing the exact
// same stepper as the live simulation, so the "ghost" curve and the live
// animation can never diverge) so the graph can show the whole predicted
// picture immediately — not build up point by point as the animation plays.
export function firstLawTrajectory(
  mass: number, friction: number, initV: number, forceOn: boolean, appliedForce: number,
  points = 140
): FirstLawTrajectoryPoint[] {
  const F = forceOn ? appliedForce : 0;
  const a0 = firstLawAcceleration(initV, mass, friction, F);

  // Choose a sensible preview window: if the block is decelerating to a
  // stop, show exactly that (plus a short settled tail); otherwise use a
  // fixed window (covers both "constant velocity forever" and "constant
  // acceleration" cases, which have no natural endpoint).
  let duration = 6;
  if (a0 !== 0 && initV !== 0 && Math.sign(a0) !== Math.sign(initV)) {
    const tStop = Math.abs(initV / a0);
    duration = Math.min(9, tStop + 0.6);
  }

  const dt = duration / points;
  const path: FirstLawTrajectoryPoint[] = [];
  let state: FirstLawState = { x: 0, v: initV, time: 0 };
  for (let i = 0; i <= points; i++) {
    const a = firstLawAcceleration(state.v, mass, friction, F);
    path.push({ t: +state.time.toFixed(3), v: +state.v.toFixed(4), a: +a.toFixed(4), x: +state.x.toFixed(4) });
    state = stepFirstLaw(state, F, mass, friction, dt);
  }
  return path;
}

// ── Second Law ────────────────────────────────────────────────────────────────
export const SECOND_LAW_TRACK_LEN = 12; // metres — track length shown on the 2nd-law canvas

export interface SecondLawParams {
  mass: number;          // kg
  appliedForce: number;  // N
  friction: number;      // coefficient 0–1
}
export interface SecondLawState {
  x: number; v: number; a: number; time: number;
  frictionForce: number; netForce: number;
}

// Single source of truth for second-law dynamics, used identically by the
// step function and the analytics panel so the displayed numbers (friction,
// net force, acceleration) are always mutually consistent — e.g. when the
// applied force can't overcome static friction, friction force EXACTLY
// cancels it (not the maximum static value) and net force reads 0, matching
// the 0 m/s² shown for acceleration.
function secondLawDynamics(p: SecondLawParams, v: number) {
  const maxStaticFriction = p.friction * p.mass * g;
  if (v <= 0) {
    if (Math.abs(p.appliedForce) <= maxStaticFriction) {
      return { a: 0, frictionForce: -p.appliedForce, netForce: 0 };
    }
    const frictionForce = -Math.sign(p.appliedForce) * maxStaticFriction;
    const netForce = p.appliedForce + frictionForce;
    return { a: netForce / p.mass, frictionForce, netForce };
  }
  // Already moving forward: kinetic friction opposes the motion.
  const frictionForce = -maxStaticFriction;
  const netForce = p.appliedForce + frictionForce;
  return { a: netForce / p.mass, frictionForce, netForce };
}

export function stepSecondLaw(
  state: SecondLawState, params: SecondLawParams, dt: number
): SecondLawState {
  const { a, frictionForce, netForce } = secondLawDynamics(params, state.v);
  let newV = state.v + a * dt;
  if (newV < 0) newV = 0; // block only ever travels forward in this demo
  const avgV = (state.v + newV) / 2;
  return {
    x: state.x + avgV * dt,
    v: newV,
    a,
    time: state.time + dt,
    frictionForce,
    netForce,
  };
}

export function secondLawAnalytics(p: SecondLawParams) {
  const { a, frictionForce, netForce } = secondLawDynamics(p, 0);
  return { acceleration: +a.toFixed(3), netForce: +netForce.toFixed(2), frictionForce: +frictionForce.toFixed(2) };
}

const EMPTY_SECOND_LAW_STATE: SecondLawState = { x: 0, v: 0, a: 0, time: 0, frictionForce: 0, netForce: 0 };

// Precomputes the full v/a/x-against-t curve for the 2nd-law block, up to
// the moment it crosses the track (or a short flat window if it never
// overcomes static friction), so the graph shows the whole predicted run
// immediately rather than building up as the animation plays.
export function secondLawTrajectory(params: SecondLawParams, points = 140): FirstLawTrajectoryPoint[] {
  const maxDuration = 8;
  const coarseDt = 0.02;
  let probe = EMPTY_SECOND_LAW_STATE;
  let duration = maxDuration;
  for (let i = 0; i < maxDuration / coarseDt; i++) {
    probe = stepSecondLaw(probe, params, coarseDt);
    if (probe.x >= SECOND_LAW_TRACK_LEN) { duration = probe.time; break; }
  }
  if (probe.x < 0.05) duration = 3; // never overcomes static friction — short flat preview

  const dt = duration / points;
  const path: FirstLawTrajectoryPoint[] = [];
  let s = EMPTY_SECOND_LAW_STATE;
  for (let i = 0; i <= points; i++) {
    path.push({ t: +s.time.toFixed(3), v: +s.v.toFixed(4), a: +s.a.toFixed(4), x: +s.x.toFixed(4) });
    s = stepSecondLaw(s, params, dt);
  }
  return path;
}

// ── Third Law ─────────────────────────────────────────────────────────────────
// Timing constants for the contact-based animations. These are fixed demo
// pacing values (not exposed as sliders) chosen so the "push" and
// "collision" scenarios always look physically sensible: bodies only ever
// interact while genuinely touching, and never draw as overlapping or
// pushing apart from a distance.
export const THIRD_LAW_TIMING = {
  pushDuration: 0.45,   // s — how long hands/surfaces stay in contact while pushing off
  approachSpeed: 2.2,   // m/s — closing speed for the collision demo's approach phase
  approachGap: 5,       // m — initial gap between facing edges before they meet
};

export interface BodyKinematics { x: number; v: number; a: number; }
export type ThirdLawPhase = 'approach' | 'contact' | 'separated';

export interface ThirdLawMotion {
  obj1: BodyKinematics;
  obj2: BodyKinematics;
  phase: ThirdLawPhase;
}

// Two bodies start TOUCHING (x1 = x2 = 0, the contact point) and push apart
// under the equal-and-opposite force pair. Object 1 is pushed in the
// negative direction, object 2 in the positive direction. Because both
// start from the same point and accelerate monotonically outward, they can
// never be drawn overlapping — verified for the full slider range.
export function pushMotion(t: number, mass1: number, mass2: number, force: number): ThirdLawMotion {
  const T = THIRD_LAW_TIMING.pushDuration;
  const a1 = force / mass1, a2 = force / mass2;
  if (t <= T) {
    return {
      obj1: { x: -0.5 * a1 * t * t, v: -a1 * t, a: -a1 },
      obj2: { x: 0.5 * a2 * t * t, v: a2 * t, a: a2 },
      phase: 'contact',
    };
  }
  const v1 = -a1 * T, v2 = a2 * T;
  const x1 = -0.5 * a1 * T * T, x2 = 0.5 * a2 * T * T;
  const dt = t - T;
  return {
    obj1: { x: x1 + v1 * dt, v: v1, a: 0 },
    obj2: { x: x2 + v2 * dt, v: v2, a: 0 },
    phase: 'separated',
  };
}

// Two bodies approach each other at a constant closing speed, meet at the
// contact point (x = 0 for both), and — from that instant — separate using
// exactly the push-scenario physics above. This keeps the reaction phase
// provably non-overlapping (it's the same proven-safe kinematics) while
// still showing a genuine approach-and-collide sequence rather than forces
// acting between two bodies that are still apart.
export function collisionMotion(t: number, mass1: number, mass2: number, force: number): ThirdLawMotion & { tContact: number } {
  const { approachSpeed: v0, approachGap } = THIRD_LAW_TIMING;
  const halfGap = approachGap / 2;
  const tContact = halfGap / v0;

  if (t <= tContact) {
    return {
      obj1: { x: -halfGap + v0 * t, v: v0, a: 0 },
      obj2: { x: halfGap - v0 * t, v: -v0, a: 0 },
      phase: 'approach',
      tContact,
    };
  }
  const post = pushMotion(t - tContact, mass1, mass2, force);
  return { ...post, tContact };
}

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

export interface ThirdLawTrajectoryPoint { t: number; v1: number; v2: number; }

// Precomputes the full velocity-against-t curve(s) for the 3rd-law scenarios
// up front, exactly like the other two laws — the graph shows the whole
// predicted picture (approach, contact, separation) immediately, with a
// live marker riding along it as the animation plays.
export const ROCKET_GRAPH_DURATION = 5; // s — fixed preview window for the rocket scenario's v–t graph

export function thirdLawTrajectory(
  scenario: 'push' | 'rocket' | 'collision', mass1: number, mass2: number, force: number, points = 140
): ThirdLawTrajectoryPoint[] {
  if (scenario === 'rocket') {
    const a = force / mass1;
    const duration = ROCKET_GRAPH_DURATION;
    return Array.from({ length: points + 1 }, (_, i) => {
      const t = (i / points) * duration;
      return { t: +t.toFixed(3), v1: +(a * t).toFixed(4), v2: 0 };
    });
  }
  const duration = scenario === 'push'
    ? THIRD_LAW_TIMING.pushDuration + 1.5
    : THIRD_LAW_TIMING.approachGap / 2 / THIRD_LAW_TIMING.approachSpeed + THIRD_LAW_TIMING.pushDuration + 1.5;
  const motionFn = scenario === 'push' ? pushMotion : collisionMotion;
  return Array.from({ length: points + 1 }, (_, i) => {
    const t = (i / points) * duration;
    const m = motionFn(t, mass1, mass2, force);
    return { t: +t.toFixed(3), v1: +m.obj1.v.toFixed(4), v2: +m.obj2.v.toFixed(4) };
  });
}
