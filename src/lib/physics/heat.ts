// ── Modes of heat transfer ────────────────────────────────────────────────────
// Conduction (solids): energy passed particle-to-particle, no bulk movement.
//   Rate:  Q/t = kAΔT / L      (k = thermal conductivity)
// Convection (fluids): warm fluid expands, becomes less dense, rises — a
//   circulation current carries the energy.
// Radiation: electromagnetic (infrared) waves, needs NO medium.
//   Stefan–Boltzmann: P = εσAT⁴

export const SIGMA = 5.67e-8; // Stefan–Boltzmann constant (W·m⁻²·K⁻⁴)

export const MATERIALS = [
  { name: 'Copper',    k: 385 },
  { name: 'Aluminium', k: 205 },
  { name: 'Steel',     k: 50 },
  { name: 'Glass',     k: 0.8 },
  { name: 'Brick',     k: 0.6 },
  { name: 'Wood',      k: 0.13 },
  { name: 'Air',       k: 0.024 },
] as const;

// Q/t in watts: k (W/mK), A (m²), ΔT (K), L (m)
export function conductionRate(k: number, A: number, dT: number, L: number) {
  return L > 0 ? (k * A * dT) / L : 0;
}

// Radiated power P = εσAT⁴ (T in kelvin)
export function radiatedPower(emissivity: number, A: number, T: number) {
  return emissivity * SIGMA * A * Math.pow(T, 4);
}

// Net radiation exchange with surroundings at T0
export function netRadiation(emissivity: number, A: number, T: number, T0: number) {
  return emissivity * SIGMA * A * (Math.pow(T, 4) - Math.pow(T0, 4));
}

export function celsiusToKelvin(c: number) { return c + 273.15; }
