export const G = 9.81;

// ── Static vs dynamic equilibrium ────────────────────────────────────────────
// Both are defined by the SAME condition — net force = zero — the only
// difference is whether the body happens to be at rest (static) or moving
// at constant velocity (dynamic). A common exam trap: students assume
// "equilibrium" always means "not moving".
export interface ForceBalance { netForce: number; equilibrium: boolean; }
export function checkBalance(f1: number, f2: number): ForceBalance {
  const net = f1 - f2;
  return { netForce: +net.toFixed(3), equilibrium: Math.abs(net) < 0.05 };
}

// ── Concurrent (non-parallel) coplanar forces ────────────────────────────────
export interface Vec2 { x: number; y: number; }
export function forceComponents(mag: number, angleDeg: number): Vec2 {
  const rad = (angleDeg * Math.PI) / 180;
  return { x: mag * Math.cos(rad), y: mag * Math.sin(rad) };
}
export function resultant(forces: Vec2[]): Vec2 {
  return forces.reduce((acc, f) => ({ x: acc.x + f.x, y: acc.y + f.y }), { x: 0, y: 0 });
}
export function vecMagnitude(v: Vec2): number {
  return Math.sqrt(v.x * v.x + v.y * v.y);
}
export function vecAngleDeg(v: Vec2): number {
  return (Math.atan2(v.y, v.x) * 180) / Math.PI;
}
// The single extra force that would bring a set of forces into equilibrium
// — equal in magnitude, opposite in direction to their resultant.
export function equilibrant(forces: Vec2[]): Vec2 {
  const r = resultant(forces);
  return { x: -r.x, y: -r.y };
}

// ── Parallel coplanar forces / moments ───────────────────────────────────────
// position: signed distance from the pivot along the beam (m), negative =
// left of pivot, positive = right. force: magnitude acting downward (N).
export interface Weight { force: number; position: number; }
export function momentOf(w: Weight): number {
  return w.force * w.position; // + = clockwise (right side), − = anticlockwise (left side)
}
export function netMoment(weights: Weight[]): number {
  return weights.reduce((sum, w) => sum + momentOf(w), 0);
}
export function isBalanced(weights: Weight[], tolerance = 0.15): boolean {
  return Math.abs(netMoment(weights)) < tolerance;
}
// The force needed at a given position to balance a set of other weights —
// the classic "principle of moments" exam question, rearranged to solve
// for the unknown.
export function balancingForce(weights: Weight[], atPosition: number): number {
  if (Math.abs(atPosition) < 1e-6) return 0;
  return -netMoment(weights) / atPosition;
}

// ── Floating bodies — density, relative density, Archimedes' principle ──────
export const LIQUIDS = [
  { name: 'Water',     density: 1000 },
  { name: 'Seawater',  density: 1025 },
  { name: 'Oil',       density: 800 },
  { name: 'Glycerin',  density: 1260 },
  { name: 'Mercury',   density: 13600 },
] as const;

export function relativeDensity(objDensity: number, referenceDensity = 1000): number {
  return objDensity / referenceDensity;
}
// Fraction of the object's volume submerged at equilibrium — from
// Archimedes' principle, weight = upthrust: ρ_obj·V·g = ρ_liquid·V_sub·g,
// so V_sub/V = ρ_obj/ρ_liquid. Clamped at 1 (a denser object simply sinks
// to the bottom rather than "submerging more than 100%").
export function submergedFraction(objDensity: number, liquidDensity: number): number {
  return Math.min(1, objDensity / liquidDensity);
}
export function upthrust(liquidDensity: number, submergedVolume: number): number {
  return liquidDensity * G * submergedVolume;
}
export function willFloat(objDensity: number, liquidDensity: number): boolean {
  return objDensity < liquidDensity;
}
// Terminal sinking acceleration for an object denser than the liquid —
// gravity reduced by the constant upthrust once fully submerged:
// a = g(1 − ρ_liquid/ρ_object).
export function sinkingAcceleration(objDensity: number, liquidDensity: number): number {
  return G * (1 - liquidDensity / objDensity);
}

// ── Shared damped step-response (used by both the parallel-forces beam and
// the floating-body bob) ─────────────────────────────────────────────────────
// The step response of a critically-tunable damped 2nd-order system settling
// from 0 to a target value — physically genuine for a floating body (small
// vertical displacements from equilibrium behave like SHM restored by
// buoyancy, effective stiffness k = ρ_liquid·g·A) and a reasonable, honest
// approximation for a beam settling under net torque.
export function dampedStepResponse(t: number, target: number, k: number, mass: number, zeta = 0.35): number {
  if (mass <= 0 || k <= 0 || t <= 0) return 0;
  const omega = Math.sqrt(k / mass);
  if (zeta >= 1) return target * (1 - Math.exp(-omega * t));
  const omegaD = omega * Math.sqrt(1 - zeta * zeta);
  return target * (1 - Math.exp(-zeta * omega * t) * (Math.cos(omegaD * t) + (zeta * omega / omegaD) * Math.sin(omegaD * t)));
}
