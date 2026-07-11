export interface GasState {
  pressure: number;    // kPa
  volume: number;      // L
  temperature: number; // K
  moles: number;
}

export const R = 8.314; // J/(mol·K)

// ── Simple gas laws ───────────────────────────────────────────────────────────
export function boyleNewVolume(p1: number, v1: number, p2: number): number { return (p1 * v1) / p2; }
export function charlesNewVolume(v1: number, t1: number, t2: number): number { return (v1 * t2) / t1; }
export function pressureLawNewPressure(p1: number, t1: number, t2: number): number { return (p1 * t2) / t1; }

// ── Ideal gas law: PV = nRT ───────────────────────────────────────────────────
export function idealGasPressure(n: number, t: number, vLitres: number): number {
  return (n * R * t) / (vLitres * 0.001); // Pa
}
export function idealGasVolume(n: number, t: number, pKpa: number): number {
  return (n * R * t) / (pKpa * 1000) * 1000; // L
}
export function idealGasMoles(pKpa: number, vLitres: number, t: number): number {
  return (pKpa * 1000 * vLitres * 0.001) / (R * t);
}
export function idealGasTemperature(pKpa: number, vLitres: number, n: number): number {
  return (pKpa * 1000 * vLitres * 0.001) / (n * R);
}

// ── Van der Waals constants for real gases ────────────────────────────────────
export interface GasConstants { a: number; b: number; name: string; formula: string; }
export const VAN_DER_WAALS: Record<string, GasConstants> = {
  ideal: { a: 0,     b: 0,       name: 'Ideal gas',       formula: '—' },
  He:    { a: 0.034, b: 0.02370, name: 'Helium',          formula: 'He' },
  H2:    { a: 0.244, b: 0.02661, name: 'Hydrogen',        formula: 'H₂' },
  N2:    { a: 1.370, b: 0.03870, name: 'Nitrogen',        formula: 'N₂' },
  O2:    { a: 1.382, b: 0.03186, name: 'Oxygen',          formula: 'O₂' },
  CO2:   { a: 3.640, b: 0.04267, name: 'Carbon dioxide',  formula: 'CO₂' },
  NH3:   { a: 4.170, b: 0.03707, name: 'Ammonia',         formula: 'NH₃' },
  H2O:   { a: 5.536, b: 0.03049, name: 'Water vapour',    formula: 'H₂O' },
};

// Van der Waals pressure: (P + an²/V²)(V - nb) = nRT
export function vdwPressure(n: number, t: number, vLitres: number, gas: string): number {
  const { a, b } = VAN_DER_WAALS[gas];
  const V = vLitres * 0.001; // m³
  const p = (n * R * t) / (V - n * b) - a * (n * n) / (V * V);
  return Math.max(0, p); // Pa
}

// ── Curve generators ──────────────────────────────────────────────────────────
export function boyleCurve(n: number, t: number, vMin = 0.5, vMax = 10, steps = 60) {
  return Array.from({ length: steps + 1 }, (_, i) => {
    const v = vMin + (i / steps) * (vMax - vMin);
    return { v: +v.toFixed(3), p: +(idealGasPressure(n, t, v) / 1000).toFixed(2) };
  });
}
export function charlesCurve(n: number, p: number, tMin = 100, tMax = 600, steps = 60) {
  return Array.from({ length: steps + 1 }, (_, i) => {
    const t = tMin + (i / steps) * (tMax - tMin);
    return { t: +t.toFixed(0), v: +((n * R * t) / (p * 1000) * 1000).toFixed(3) };
  });
}
export function pressureLawCurve(n: number, vLitres: number, tMin = 100, tMax = 600, steps = 60) {
  return Array.from({ length: steps + 1 }, (_, i) => {
    const t = tMin + (i / steps) * (tMax - tMin);
    return { t: +t.toFixed(0), p: +(idealGasPressure(n, t, vLitres) / 1000).toFixed(2) };
  });
}

// Ideal vs real comparison: PV/nRT (compressibility factor Z) vs P
export function compressibilityCurve(
  n: number, t: number, gas: string, pMinKpa = 100, pMaxKpa = 20000, steps = 80
) {
  return Array.from({ length: steps + 1 }, (_, i) => {
    const pKpa = pMinKpa + (i / steps) * (pMaxKpa - pMinKpa);
    const vIdeal = idealGasVolume(n, t, pKpa);
    // For real gas Z: solve vdw numerically — use ideal V as starting point
    let vReal = vIdeal;
    for (let iter = 0; iter < 20; iter++) {
      const pCalc = vdwPressure(n, t, vReal, gas) / 1000;
      const dv = (pCalc - pKpa) * 0.00001;
      vReal -= dv;
      if (vReal <= 0.001) { vReal = 0.001; break; }
    }
    const Z = (pKpa * 1000 * vReal * 0.001) / (n * R * t);
    return { p: +pKpa.toFixed(0), z: +Z.toFixed(4), zIdeal: 1 };
  });
}

// P-V isotherms for ideal vs real
export function pvIsotherm(n: number, t: number, gas: string, vMin = 0.5, vMax = 15, steps = 80) {
  return Array.from({ length: steps + 1 }, (_, i) => {
    const v = vMin + (i / steps) * (vMax - vMin);
    const pIdeal = +(idealGasPressure(n, t, v) / 1000).toFixed(2);
    const pReal  = +(vdwPressure(n, t, v, gas) / 1000).toFixed(2);
    return { v: +v.toFixed(3), pIdeal: Math.min(pIdeal, 5000), pReal: Math.max(0, Math.min(pReal, 5000)) };
  });
}
