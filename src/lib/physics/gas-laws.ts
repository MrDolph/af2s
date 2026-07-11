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

// Pressure Law (Gay-Lussac): P1/T1 = P2/T2 (constant V, n)
export function pressureLawNewPressure(p1: number, t1: number, t2: number): number {
  return (p1 * t2) / t1;
}
export function pressureLawNewTemperature(p1: number, t1: number, p2: number): number {
  return (p2 * t1) / p1;
}

// Ideal gas: PV = nRT
export function idealGasPressure(n: number, t: number, v: number): number {
  return (n * R * t) / (v * 0.001); // v in L → m³
}

// Boyle's curve: P vs V at constant T
export function boyleCurve(
  n: number, temperature: number, vMin = 0.5, vMax = 10, steps = 60
): { v: number; p: number }[] {
  return Array.from({ length: steps + 1 }, (_, i) => {
    const v = vMin + (i / steps) * (vMax - vMin);
    return { v: +v.toFixed(3), p: +(idealGasPressure(n, temperature, v) / 1000).toFixed(2) };
  });
}

// Charles' curve: V vs T at constant P
export function charlesCurve(
  n: number, pressure: number, tMin = 100, tMax = 600, steps = 60
): { t: number; v: number }[] {
  return Array.from({ length: steps + 1 }, (_, i) => {
    const t = tMin + (i / steps) * (tMax - tMin);
    const v = (n * R * t) / (pressure * 1000) * 1000;
    return { t: +t.toFixed(0), v: +v.toFixed(3) };
  });
}

// Pressure Law curve: P vs T at constant V
export function pressureLawCurve(
  n: number, volume: number, tMin = 100, tMax = 600, steps = 60
): { t: number; p: number }[] {
  return Array.from({ length: steps + 1 }, (_, i) => {
    const t = tMin + (i / steps) * (tMax - tMin);
    const p = idealGasPressure(n, t, volume) / 1000;
    return { t: +t.toFixed(0), p: +p.toFixed(2) };
  });
}

// Particle speed proxy from temperature
export function particleSpeed(temperature: number, molarMass = 0.029): number {
  return Math.sqrt((3 * R * temperature) / molarMass);
}
