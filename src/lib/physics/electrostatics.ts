// ── Electrostatics ──────────────────────────────────────────────────────────
export const COULOMB_K = 8.99e9;   // N·m²/C² (= 1/4πε₀)
export const EPSILON_0 = 8.85e-12; // F/m — permittivity of free space
export const ELEMENTARY_CHARGE = 1.602e-19; // C

// ── Coulomb's law ────────────────────────────────────────────────────────────
// Force magnitude between two point charges.
export function coulombForce(q1: number, q2: number, r: number): number {
  if (r <= 0) return 0;
  return (COULOMB_K * Math.abs(q1 * q2)) / (r * r);
}
// Signed version: positive = repulsive (like charges), negative = attractive.
export function coulombForceSigned(q1: number, q2: number, r: number): number {
  if (r <= 0) return 0;
  return (COULOMB_K * q1 * q2) / (r * r);
}

// ── Electric field ────────────────────────────────────────────────────────────
// Field strength at distance r from a point charge q.
export function electricFieldPoint(q: number, r: number): number {
  if (r <= 0) return 0;
  return (COULOMB_K * Math.abs(q)) / (r * r);
}
// E = F/q — field strength from the force it exerts on a test charge.
export function electricFieldFromForce(force: number, testCharge: number): number {
  return testCharge !== 0 ? force / testCharge : 0;
}
// Uniform field between parallel plates.
export function uniformFieldStrength(voltage: number, separation: number): number {
  return separation > 0 ? voltage / separation : 0;
}

// ── Electric potential & potential energy ────────────────────────────────────
// Potential at distance r from a point charge q (defining V=0 at infinity).
export function electricPotentialPoint(q: number, r: number): number {
  if (r <= 0) return 0;
  return (COULOMB_K * q) / r;
}
// Potential energy of a pair of point charges separated by r.
export function electricPotentialEnergy(q1: number, q2: number, r: number): number {
  if (r <= 0) return 0;
  return (COULOMB_K * q1 * q2) / r;
}
// Work done moving a charge q through a potential difference V: W = qV.
export function workDoneByPotentialDiff(charge: number, voltage: number): number {
  return charge * voltage;
}

// ── Capacitors ────────────────────────────────────────────────────────────────
export function parallelPlateCapacitance(areaM2: number, separationM: number, relativePermittivity = 1): number {
  if (separationM <= 0) return 0;
  return (EPSILON_0 * relativePermittivity * areaM2) / separationM;
}
export function capacitorCharge(capacitance: number, voltage: number): number {
  return capacitance * voltage;
}
export function capacitorEnergy(capacitance: number, voltage: number): number {
  return 0.5 * capacitance * voltage * voltage;
}
// Charging/discharging through a resistor follows an exponential approach —
// used to animate a capacitor's voltage climbing (or falling) over time,
// with the standard RC time constant.
export function capacitorChargingVoltage(t: number, V0: number, R: number, C: number): number {
  const tau = R * C;
  if (tau <= 0) return V0;
  return V0 * (1 - Math.exp(-t / tau));
}
export function capacitorDischargingVoltage(t: number, V0: number, R: number, C: number): number {
  const tau = R * C;
  if (tau <= 0) return 0;
  return V0 * Math.exp(-t / tau);
}

// ── Gold-leaf electroscope ───────────────────────────────────────────────────
// Simplified model for this level: leaf divergence angle is proportional to
// the magnitude of charge on the electroscope, saturating at a realistic
// maximum before the leaves would touch the case.
export function electroscopeDivergenceAngle(chargeMagnitude: number, maxCharge: number, maxAngleDeg = 40): number {
  if (maxCharge <= 0) return 0;
  const frac = Math.min(1, Math.abs(chargeMagnitude) / maxCharge);
  return frac * maxAngleDeg;
}
