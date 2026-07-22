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

export interface InclineResult {
  N: number;
  gravityAlong: number;   // mg sinθ (down-slope)
  staticMax: number;      // μs·mg·cosθ
  friction: number;
  acceleration: number;   // down-slope, 0 if static
  sliding: boolean;
  reposeAngle: number;    // tan⁻¹(μs) in degrees
}

export function inclineFriction(mass: number, thetaDeg: number, muS: number, muK: number): InclineResult {
  const th = (thetaDeg * Math.PI) / 180;
  const N = mass * G * Math.cos(th);
  const along = mass * G * Math.sin(th);
  const staticMax = muS * N;
  const reposeAngle = (Math.atan(muS) * 180) / Math.PI;
  if (along <= staticMax) {
    return { N, gravityAlong: along, staticMax, friction: along, acceleration: 0, sliding: false, reposeAngle };
  }
  const kinetic = muK * N;
  return {
    N, gravityAlong: along, staticMax, friction: kinetic,
    acceleration: (along - kinetic) / mass, sliding: true, reposeAngle,
  };
}

// Friction-vs-applied-force curve: the classic ramp-then-plateau graph.
export function frictionCurve(mass: number, muS: number, muK: number, fMax: number, points = 100) {
  return Array.from({ length: points + 1 }, (_, i) => {
    const F = (i / points) * fMax;
    return { F: +F.toFixed(2), f: +flatFriction(mass, F, muS, muK).friction.toFixed(2) };
  });
}
