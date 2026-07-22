// ── De Broglie hypothesis ─────────────────────────────────────────────────────
// Every moving particle has an associated matter wave:
//   λ = h / p = h / (mv)
// Electron accelerated through potential V:
//   λ = h / √(2 m e V)

export const H = 6.626e-34;
export const E_CHARGE = 1.602e-19;
export const M_ELECTRON = 9.109e-31;

export interface ParticlePreset {
  name: string;
  mass: number;       // kg
  vMin: number; vMax: number; vDefault: number; // m/s slider range
  emoji: string;
}

export const PARTICLES: ParticlePreset[] = [
  { name: 'Electron',     mass: 9.109e-31, vMin: 1e5,  vMax: 1e7,  vDefault: 2e6,  emoji: '⚛️' },
  { name: 'Proton',       mass: 1.673e-27, vMin: 1e4,  vMax: 1e6,  vDefault: 1e5,  emoji: '🔴' },
  { name: 'Alpha particle', mass: 6.645e-27, vMin: 1e4, vMax: 1e6, vDefault: 1e5,  emoji: '🟠' },
  { name: 'Cricket ball (160g)', mass: 0.16, vMin: 5, vMax: 45, vDefault: 30, emoji: '🏏' },
];

export function deBroglieLambda(mass: number, v: number) {
  return v > 0 ? H / (mass * v) : Infinity;
}
export function momentum(mass: number, v: number) {
  return mass * v;
}
export function lambdaFromVoltage(V: number) {
  return H / Math.sqrt(2 * M_ELECTRON * E_CHARGE * V);
}
// Human-readable length with sensible unit.
export function formatLambda(lambda: number): string {
  if (!isFinite(lambda)) return '∞';
  if (lambda >= 1e-3) return (lambda * 1e3).toPrecision(3) + ' mm';
  if (lambda >= 1e-6) return (lambda * 1e6).toPrecision(3) + ' µm';
  if (lambda >= 1e-9) return (lambda * 1e9).toPrecision(3) + ' nm';
  if (lambda >= 1e-12) return (lambda * 1e12).toPrecision(3) + ' pm';
  if (lambda >= 1e-15) return (lambda * 1e15).toPrecision(3) + ' fm';
  return lambda.toExponential(2) + ' m';
}
