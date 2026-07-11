export interface GasState {
  pressure: number;    // kPa
  volume: number;      // L
  temperature: number; // K
  moles: number;       // mol
}

export const R = 8.314; // J/(mol·K)

// Boyle's Law: P1V1 = P2V2 (constant T, n)
export function boyleNewPressure(p1: number, v1: number, v2: number): number {
  return (p1 * v1) / v2;
}
export function boyleNewVolume(p1: number, v1: number, p2: number): number {
  return (p1 * v1) / p2;
}

// Charles' Law: V1/T1 = V2/T2 (constant P, n)
export function charlesNewVolume(v1: number, t1: number, t2: number): number {
  return (v1 * t2) / t1;
}

// Ideal gas: PV = nRT
export function idealGasPressure(n: number, t: number, v: number): number {
  return (n * R * t) / (v * 0.001); // v in L → m³
}

// Generate Boyle's curve: P vs V at constant T
export function boyleCurve(
  n: number,
  temperature: number,
  vMin = 0.5,
  vMax = 10,
  steps = 60
): { v: number; p: number }[] {
  const points = [];
  for (let i = 0; i <= steps; i++) {
    const v = vMin + (i / steps) * (vMax - vMin);
    const p = idealGasPressure(n, temperature, v) / 1000; // Pa → kPa
    points.push({ v, p });
  }
  return points;
}

// Generate Charles' curve: V vs T at constant P
export function charlesCurve(
  n: number,
  pressure: number, // kPa
  tMin = 100,
  tMax = 600,
  steps = 60
): { t: number; v: number }[] {
  const points = [];
  for (let i = 0; i <= steps; i++) {
    const t = tMin + (i / steps) * (tMax - tMin);
    const v = (n * R * t) / (pressure * 1000) * 1000; // m³ → L
    points.push({ t, v });
  }
  return points;
}

// Particle speed from temperature (Maxwell-Boltzmann proxy)
export function particleSpeed(temperature: number, molarMass = 0.029): number {
  return Math.sqrt((3 * R * temperature) / molarMass);
}
