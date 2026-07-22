// ── Friction ──────────────────────────────────────────────────────────────────
// Static:  F_s ≤ μs·N  (matches the applied force until the limit)
// Kinetic: F_k = μk·N  (constant once sliding; μk < μs)
// On an incline the block slips when tanθ > μs  →  angle of repose θr = tan⁻¹μs.

export const G = 9.81;

export interface FlatResult {
  N: number;
  staticMax: number;
  friction: number;     // actual friction force right now
  netForce: number;
  acceleration: number;
  moving: boolean;
}

export function flatFriction(mass: number, applied: number, muS: number, muK: number): FlatResult {
  const N = mass * G;
  const staticMax = muS * N;
  if (applied <= staticMax) {
    // Static regime: friction exactly balances the applied force.
    return { N, staticMax, friction: applied, netForce: 0, acceleration: 0, moving: false };
  }
  const kinetic = muK * N;
  const net = applied - kinetic;
  return { N, staticMax, friction: kinetic, netForce: net, acceleration: net / mass, moving: true };
}

// ── Incline (bidirectional) ─────────────────────────────────────────────────────
// Positive direction = UP the slope throughout. An optional applied force
// (also up-slope-positive) lets the block be pushed UP against gravity, not
// just slide down under its own weight — friction automatically flips to
// whichever side opposes the actual (or impending) motion.
export interface InclineDynamicsResult {
  N: number;
  gravityAlong: number;   // mg sinθ — magnitude of weight's down-slope component
  gravityPerp: number;    // mg cosθ — magnitude of weight's into-slope component (== N at equilibrium)
  weight: number;         // mg — full weight magnitude
  appliedForce: number;   // signed, up-slope positive (as given)
  friction: number;       // signed, up-slope positive
  netForce: number;       // signed, up-slope positive
  acceleration: number;   // signed, up-slope positive
  moving: boolean;
  direction: 'up' | 'down' | 'static';
  staticMax: number;
  reposeAngle: number;    // tan⁻¹(μs) in degrees — the F=0 slipping threshold
}

export function inclineDynamics(
  mass: number, thetaDeg: number, muS: number, muK: number, appliedForce: number, v: number
): InclineDynamicsResult {
  const th = (thetaDeg * Math.PI) / 180;
  const weight = mass * G;
  const N = weight * Math.cos(th);
  const gravityAlong = weight * Math.sin(th);   // always pulls down-slope
  const gravityPerp = N;
  const maxStatic = muS * N;
  const reposeAngle = (Math.atan(muS) * 180) / Math.PI;
  const nonFriction = appliedForce - gravityAlong; // net of applied (up +) and gravity (down −), excluding friction

  if (v === 0) {
    if (Math.abs(nonFriction) <= maxStatic) {
      return {
        N, gravityAlong, gravityPerp, weight, appliedForce, friction: -nonFriction, netForce: 0,
        acceleration: 0, moving: false, direction: 'static', staticMax: maxStatic, reposeAngle,
      };
    }
    const friction = -Math.sign(nonFriction) * maxStatic;
    const netForce = nonFriction + friction;
    const acceleration = netForce / mass;
    return {
      N, gravityAlong, gravityPerp, weight, appliedForce, friction, netForce, acceleration,
      moving: true, direction: acceleration > 0 ? 'up' : 'down', staticMax: maxStatic, reposeAngle,
    };
  }
  const friction = -Math.sign(v) * muK * N;
  const netForce = nonFriction + friction;
  const acceleration = netForce / mass;
  return {
    N, gravityAlong, gravityPerp, weight, appliedForce, friction, netForce, acceleration,
    moving: true, direction: v > 0 ? 'up' : 'down', staticMax: maxStatic, reposeAngle,
  };
}

// Friction-vs-applied-force curve: the classic ramp-then-plateau graph
// (flat-surface version, used by the flat-mode f–F graph).
export function frictionCurve(mass: number, muS: number, muK: number, fMax: number, points = 100) {
  return Array.from({ length: points + 1 }, (_, i) => {
    const F = (i / points) * fMax;
    return { F: +F.toFixed(2), f: +flatFriction(mass, F, muS, muK).friction.toFixed(2) };
  });
}
