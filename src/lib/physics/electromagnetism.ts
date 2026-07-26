// ── Electromagnetism ──────────────────────────────────────────────────────────
export const MU_0 = 4 * Math.PI * 1e-7; // permeability of free space, T·m/A

// ── Magnetic fields due to current ───────────────────────────────────────────
// Long straight wire (right-hand grip rule): field circles the wire.
export function fieldStraightWire(current: number, distance: number): number {
  if (distance <= 0) return 0;
  return (MU_0 * current) / (2 * Math.PI * distance);
}
// Centre of a circular loop of N turns, radius r.
export function fieldCircularLoop(current: number, radius: number, turns = 1): number {
  if (radius <= 0) return 0;
  return (MU_0 * turns * current) / (2 * radius);
}
// Inside a long solenoid: n = turns per metre (N/length).
export function fieldSolenoid(current: number, turnsPerMetre: number): number {
  return MU_0 * turnsPerMetre * current;
}

// ── Force on a current-carrying conductor (motor effect) ────────────────────
// F = BIL sin(theta) — Fleming's left-hand rule gives the direction.
export function forceOnConductor(B: number, current: number, length: number, angleDeg = 90): number {
  return B * current * length * Math.sin((angleDeg * Math.PI) / 180);
}
// Force per unit length between two parallel current-carrying wires.
export function forcePerLengthParallelWires(i1: number, i2: number, distance: number): number {
  if (distance <= 0) return 0;
  return (MU_0 * i1 * i2) / (2 * Math.PI * distance);
}
// Torque on a current-carrying coil in a uniform field (motor/galvanometer).
export function torqueOnCoil(B: number, current: number, area: number, turns: number, angleDeg: number): number {
  return turns * B * current * area * Math.sin((angleDeg * Math.PI) / 180);
}

// ── Electromagnetic induction ─────────────────────────────────────────────────
// Faraday's law: EMF = -N dΦ/dt — the sign (Lenz's law) says the induced EMF
// opposes the change that produced it; magnitude only, here.
export function magneticFlux(B: number, area: number, angleDeg = 0): number {
  return B * area * Math.cos((angleDeg * Math.PI) / 180);
}
export function inducedEmfFromFluxChange(turns: number, deltaFlux: number, deltaTime: number): number {
  if (deltaTime <= 0) return 0;
  return Math.abs((turns * deltaFlux) / deltaTime);
}
// Motional EMF: a rod of length L sweeping through field B at speed v.
export function motionalEmf(B: number, length: number, velocity: number): number {
  return B * length * velocity;
}
// AC generator: a coil of N turns, area A, spinning at angular speed omega
// in field B produces a sinusoidal EMF.
export function generatorPeakEmf(turns: number, B: number, area: number, omega: number): number {
  return turns * B * area * omega;
}
export function generatorEmfAt(turns: number, B: number, area: number, omega: number, t: number): number {
  return generatorPeakEmf(turns, B, area, omega) * Math.sin(omega * t);
}
// Transformer equation: Vs/Vp = Ns/Np (ideal, lossless).
export function transformerSecondaryVoltage(vPrimary: number, nPrimary: number, nSecondary: number): number {
  if (nPrimary <= 0) return 0;
  return (vPrimary * nSecondary) / nPrimary;
}
export function transformerSecondaryCurrent(iPrimary: number, nPrimary: number, nSecondary: number): number {
  if (nSecondary <= 0) return 0;
  return (iPrimary * nPrimary) / nSecondary;
}

// ── AC circuits ───────────────────────────────────────────────────────────────
export function angularFrequency(frequencyHz: number): number {
  return 2 * Math.PI * frequencyHz;
}
export function rmsFromPeak(peak: number): number {
  return peak / Math.SQRT2;
}
export function peakFromRms(rms: number): number {
  return rms * Math.SQRT2;
}
// Reactance of an inductor and a capacitor.
export function inductiveReactance(omega: number, inductance: number): number {
  return omega * inductance;
}
export function capacitiveReactance(omega: number, capacitance: number): number {
  return omega * capacitance > 0 ? 1 / (omega * capacitance) : Infinity;
}
// Impedance of a series R-L-C circuit.
export function seriesRLCImpedance(R: number, XL: number, XC: number): number {
  return Math.sqrt(R * R + (XL - XC) * (XL - XC));
}
export function seriesRLCPhaseAngleDeg(R: number, XL: number, XC: number): number {
  if (R === 0) return XL - XC >= 0 ? 90 : -90;
  return (Math.atan2(XL - XC, R) * 180) / Math.PI;
}
// Resonant angular frequency of a series RLC circuit (XL = XC).
export function resonantAngularFrequency(inductance: number, capacitance: number): number {
  if (inductance <= 0 || capacitance <= 0) return 0;
  return 1 / Math.sqrt(inductance * capacitance);
}
