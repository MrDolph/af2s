// ── Elasticity ────────────────────────────────────────────────────────────────
// Hooke's law:  F = ke   (up to the elastic limit / limit of proportionality)
// Energy stored (elastic PE): E = ½Fe = ½ke²
// For a wire:
//   stress σ = F/A,  strain ε = e/L,  Young's modulus E = σ/ε = FL/(Ae)

export const G = 9.81;

export function extension(F: number, k: number) {
  return k > 0 ? F / k : 0;
}
export function springEnergy(k: number, e: number) {
  return 0.5 * k * e * e;
}
export function stress(F: number, A: number) {
  return A > 0 ? F / A : 0;
}
export function strain(e: number, L: number) {
  return L > 0 ? e / L : 0;
}
export function youngModulus(F: number, A: number, e: number, L: number) {
  const s = strain(e, L);
  return s > 0 ? stress(F, A) / s : 0;
}
// Wire extension from Young's modulus: e = FL/(AE)
export function wireExtension(F: number, L: number, A: number, E: number) {
  return A > 0 && E > 0 ? (F * L) / (A * E) : 0;
}

// Extension including the plastic region beyond the elastic limit — same
// shape used by forceExtensionCurve, exposed directly as a function of F so
// canvases can evaluate a single target extension without sampling a curve.
export function plasticExtension(F: number, k: number, elasticLimitF: number): number {
  const eLimit = elasticLimitF / k;
  if (F <= elasticLimitF) return F / k;
  const dF = F - elasticLimitF;
  return eLimit + (dF / k) * (1 + 3 * (dF / elasticLimitF));
}

// The permanent "set" left behind after a plastically-deformed spring is
// unloaded. Unloading follows a path parallel to the original elastic
// slope (the standard simplified model for this level) — elastic recovery
// removes exactly the elastic limit's worth of extension, leaving the rest
// as permanent deformation.
export function permanentSet(F: number, k: number, elasticLimitF: number): number {
  if (F <= elasticLimitF) return 0;
  return plasticExtension(F, k, elasticLimitF) - elasticLimitF / k;
}

// Damped step response of a spring suddenly loaded with mass m = F/g: this
// is what you actually see if you hang a weight on a spring and let go —
// it overshoots past the eventual equilibrium and settles with decaying
// oscillation, not a smooth glide straight to eEq. ω is derived from the
// real implied mass, so the oscillation frequency is physically genuine,
// not just a stylised animation.
export function springStepResponse(t: number, eEq: number, k: number, mass: number, zeta = 0.28): number {
  if (mass <= 0 || k <= 0 || t <= 0) return 0;
  const omega = Math.sqrt(k / mass);
  if (zeta >= 1) return eEq * (1 - Math.exp(-omega * t)); // overdamped fallback
  const omegaD = omega * Math.sqrt(1 - zeta * zeta);
  return eEq * (1 - Math.exp(-zeta * omega * t) * (Math.cos(omegaD * t) + (zeta * omega / omegaD) * Math.sin(omegaD * t)));
}

export const WIRE_MATERIALS = [
  { name: 'Steel',     E: 200e9,  breakingStressMPa: 400 },
  { name: 'Copper',    E: 117e9,  breakingStressMPa: 220 },
  { name: 'Brass',     E: 100e9,  breakingStressMPa: 350 },
  { name: 'Aluminium', E: 69e9,   breakingStressMPa: 150 },
  { name: 'Glass',     E: 70e9,   breakingStressMPa: 50 },
  { name: 'Rubber',    E: 0.05e9, breakingStressMPa: 20 },
] as const;

// Force–extension curve: linear (Hooke) up to the elastic limit, then a
// flattening plastic region — the classic exam graph.
export function forceExtensionCurve(k: number, elasticLimitF: number, fMax: number, points = 100) {
  return Array.from({ length: points + 1 }, (_, i) => {
    const F = (i / points) * fMax;
    return { e: +(plasticExtension(F, k, elasticLimitF) * 100).toFixed(3), F: +F.toFixed(2) }; // e in cm for the graph
  });
}
