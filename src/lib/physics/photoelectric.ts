// ── Photoelectric effect ──────────────────────────────────────────────────────
// Einstein's equation:  hf = φ + KEmax
//   E = hf              photon energy
//   φ                   work function of the metal
//   f₀ = φ/h            threshold frequency (no emission below it)
//   eVs = KEmax         stopping potential
// Intensity changes the NUMBER of photons (→ current), never their energy.

export const H = 6.626e-34;       // Planck constant (J·s)
export const E_CHARGE = 1.602e-19; // electron charge (C)
export const C_LIGHT = 3e8;       // speed of light (m/s)

// Frequencies handled in units of 10¹⁴ Hz for friendly slider numbers.
export function photonEnergyEV(f14: number) {
  return (H * f14 * 1e14) / E_CHARGE;
}
export function thresholdF14(phiEV: number) {
  return (phiEV * E_CHARGE) / H / 1e14;
}
export function keMaxEV(f14: number, phiEV: number) {
  return Math.max(0, photonEnergyEV(f14) - phiEV);
}
export function stoppingPotential(f14: number, phiEV: number) {
  return keMaxEV(f14, phiEV); // volts, numerically equal to KEmax in eV
}
export function wavelengthNm(f14: number) {
  return (C_LIGHT / (f14 * 1e14)) * 1e9;
}
// Electron speed from KE (non-relativistic, fine below ~10 eV scale here).
export function electronSpeed(keEV: number) {
  const me = 9.109e-31;
  return Math.sqrt((2 * keEV * E_CHARGE) / me);
}

export const METALS = [
  { name: 'Caesium',  phi: 2.10 },
  { name: 'Sodium',   phi: 2.28 },
  { name: 'Calcium',  phi: 2.87 },
  { name: 'Zinc',     phi: 4.30 },
  { name: 'Copper',   phi: 4.70 },
  { name: 'Platinum', phi: 6.35 },
] as const;

// KEmax–f line for the graph: straight line, slope h/e, intercept −φ/e.
export function keLine(phiEV: number, f14Max: number, points = 60) {
  return Array.from({ length: points + 1 }, (_, i) => {
    const f = (i / points) * f14Max;
    return { f: +f.toFixed(3), ke: +keMaxEV(f, phiEV).toFixed(4) };
  });
}

// Rough visible-spectrum colour for the beam (f in 10¹⁴ Hz).
export function lightColor(f14: number): string {
  if (f14 < 4.0) return '#b91c1c';        // infrared → deep red
  if (f14 < 4.8) return '#ef4444';        // red
  if (f14 < 5.3) return '#f59e0b';        // orange/yellow
  if (f14 < 6.0) return '#22c55e';        // green
  if (f14 < 6.7) return '#3b82f6';        // blue
  if (f14 < 7.9) return '#8b5cf6';        // violet
  return '#c4b5fd';                        // ultraviolet (shown pale violet)
}
