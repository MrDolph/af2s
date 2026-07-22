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

export const WIRE_MATERIALS = [
  { name: 'Steel',     E: 200e9 },
  { name: 'Copper',    E: 117e9 },
  { name: 'Brass',     E: 100e9 },
  { name: 'Aluminium', E: 69e9 },
  { name: 'Glass',     E: 70e9 },
  { name: 'Rubber',    E: 0.05e9 },
] as const;

// Force–extension curve: linear (Hooke) up to the elastic limit, then a
// flattening plastic region — the classic exam graph.
export function forceExtensionCurve(k: number, elasticLimitF: number, fMax: number, points = 100) {
  const eLimit = elasticLimitF / k;
  return Array.from({ length: points + 1 }, (_, i) => {
    const F = (i / points) * fMax;
    let e: number;
    if (F <= elasticLimitF) {
      e = F / k;
    } else {
      // Plastic: extension grows much faster per unit force.
      const dF = F - elasticLimitF;
      e = eLimit + (dF / k) * (1 + 3 * (dF / elasticLimitF));
    }
    return { e: +(e * 100).toFixed(3), F: +F.toFixed(2) }; // e in cm for the graph
  });
}
