// ── Ohm's law & DC circuits ───────────────────────────────────────────────────
// V = IR.  P = VI = I²R = V²/R.

export function ohmCurrent(V: number, R: number) {
  return R > 0 ? V / R : 0;
}
export function power(V: number, I: number) {
  return V * I;
}

// ── Series: same current everywhere, voltages add ─────────────────────────────
export function seriesTotal(resistors: number[]) {
  return resistors.reduce((a, r) => a + r, 0);
}
export function seriesAnalysis(V: number, resistors: number[]) {
  const Rtotal = seriesTotal(resistors);
  const I = ohmCurrent(V, Rtotal);
  return {
    Rtotal,
    I,
    drops: resistors.map(R => I * R),   // voltage divider: V_i = I·R_i
    powers: resistors.map(R => I * I * R),
    Ptotal: V * I,
  };
}

// ── Parallel: same voltage everywhere, currents add ───────────────────────────
export function parallelTotal(resistors: number[]) {
  const invSum = resistors.reduce((a, r) => a + (r > 0 ? 1 / r : 0), 0);
  return invSum > 0 ? 1 / invSum : 0;
}
export function parallelAnalysis(V: number, resistors: number[]) {
  const Rtotal = parallelTotal(resistors);
  const branches = resistors.map(R => ohmCurrent(V, R)); // current divider: I_i = V/R_i
  const I = branches.reduce((a, i) => a + i, 0);
  return {
    Rtotal,
    I,
    branches,
    powers: resistors.map(R => (V * V) / R),
    Ptotal: V * I,
  };
}

// I–V characteristic points for a fixed resistance (straight line, slope 1/R).
export function ivLine(R: number, vMax: number, points = 50) {
  return Array.from({ length: points + 1 }, (_, i) => {
    const v = (i / points) * vMax;
    return { v: +v.toFixed(3), i: +ohmCurrent(v, R).toFixed(4) };
  });
}

// ── Non-ohmic conductors ──────────────────────────────────────────────────────
// These use simplified but always-monotonic, numerically-stable models
// (a power law for the lamp/thermistor, the standard exponential diode
// equation) chosen specifically to reliably reproduce the correct
// QUALITATIVE shape taught at this level — a curved, concave-down or
// concave-up I–V graph rather than a straight ohmic line — while
// remaining safe to invert and animate. An earlier resistance-vs-current
// model for the thermistor (R falling as 1/(1+kI²)) was tried and
// rejected: verified numerically that it has a genuine negative-
// resistance region beyond a critical current, making V(I) non-monotonic
// and impossible to invert reliably for a live demo.
export type NonOhmicDevice = 'filament' | 'diode' | 'thermistor';

// Filament lamp: resistance RISES as it self-heats, so current grows
// SLOWER than linearly with voltage (concave down).
export function filamentLampCurrent(V: number, c: number): number {
  return V > 0 ? c * Math.pow(V, 0.55) : 0;
}
// Thermistor (NTC): resistance FALLS as it self-heats, so current grows
// FASTER than linearly with voltage (concave up).
export function thermistorCurrent(V: number, c: number): number {
  return V > 0 ? c * Math.pow(V, 1.5) : 0;
}
// Diode: negligible current below the threshold voltage, then a sharp
// exponential rise (the standard Shockley diode equation). Reverse bias
// (V<0) is treated as an ideal block (I=0) for this teaching demo.
export function diodeCurrent(V: number, Is = 1e-9, n = 1.8, Vt = 0.026): number {
  if (V <= 0) return 0;
  return Is * (Math.exp(V / (n * Vt)) - 1);
}
// A single reference constant so the lamp/thermistor curves cross the
// ohmic reference line at a shared, fair comparison point.
export function nonOhmicCalibration(refR: number, refV: number) {
  const refI = ohmCurrent(refV, refR);
  return {
    cLamp: refI / Math.pow(refV, 0.55),
    cTherm: refI / Math.pow(refV, 1.5),
  };
}
export function nonOhmicCurrent(device: NonOhmicDevice, V: number, cLamp: number, cTherm: number): number {
  if (device === 'filament') return filamentLampCurrent(V, cLamp);
  if (device === 'thermistor') return thermistorCurrent(V, cTherm);
  return diodeCurrent(V);
}
export function nonOhmicIVLine(device: NonOhmicDevice, vMax: number, cLamp: number, cTherm: number, points = 60) {
  return Array.from({ length: points + 1 }, (_, i) => {
    const v = (i / points) * vMax;
    return { v: +v.toFixed(3), i: +nonOhmicCurrent(device, v, cLamp, cTherm).toFixed(6) };
  });
}
