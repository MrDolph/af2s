export const HBAR = 1;
export const MASS = 1;
export const OMEGA = 1;
// In these natural units: characteristic length a = sqrt(HBAR/(MASS*OMEGA)) = 1
// Energy unit = HBAR * OMEGA = 1

export interface WavefunctionResult {
  re: number;
  im: number;
  prob: number;
}

export interface QHOParams {
  speed: number;
  xMax: number;
  eMax: number;
  nMax: number;
  showPotential: boolean;
  showEnergyLevels: boolean;
  showProbability: boolean;
  showReal: boolean;
  showImaginary: boolean;
  showClassicalTurning: boolean;
}

export interface QHOPreset {
  color: string;
  name: string;
  description: string;
  coeffs: number[];
  speed: number;
  xMax: number;
  eMax: number;
  nMax: number;
  showPotential: boolean;
  showEnergyLevels: boolean;
  showProbability: boolean;
  showReal: boolean;
  showImaginary: boolean;
  showClassicalTurning: boolean;
}

/** Hermite polynomial H_n(x) via recurrence relation. */
export function hermite(n: number, x: number): number {
  if (n === 0) return 1;
  if (n === 1) return 2 * x;
  let h0 = 1;
  let h1 = 2 * x;
  for (let i = 2; i <= n; i++) {
    const h2 = 2 * x * h1 - 2 * (i - 1) * h0;
    h0 = h1;
    h1 = h2;
  }
  return h1;
}

/** Factorial for small integers (n ≤ 10). */
export function factorial(n: number): number {
  let r = 1;
  for (let i = 2; i <= n; i++) r *= i;
  return r;
}

/** Stationary-state wavefunction ψ_n(x) for the 1-D QHO in natural units. */
export function stationaryPsi(n: number, x: number): number {
  const norm = 1 / Math.sqrt(Math.pow(2, n) * factorial(n) * Math.sqrt(Math.PI));
  return norm * hermite(n, x) * Math.exp(-x * x / 2);
}

/** Normalise a coefficient array so that Σ|c_n|² = 1. */
export function normalize(coeffs: number[]): number[] {
  const norm = Math.sqrt(coeffs.reduce((sum, c) => sum + c * c, 0));
  return norm > 1e-12 ? coeffs.map(c => c / norm) : coeffs.map(() => 0);
}

/** Time-evolved wavefunction ψ(x,t) = Σ c_n ψ_n(x) e^{-i n t} (global phase removed). */
export function wavefunction(x: number, coeffs: number[], time: number): WavefunctionResult {
  let re = 0;
  let im = 0;
  for (let n = 0; n < coeffs.length; n++) {
    if (coeffs[n] === 0) continue;
    const psi_n = stationaryPsi(n, x);
    const phase = -n * time;
    const c = coeffs[n];
    re += c * psi_n * Math.cos(phase);
    im += c * psi_n * Math.sin(phase);
  }
  return { re, im, prob: re * re + im * im };
}

/** Energy expectation value ⟨E⟩ = Σ c_n² (n + ½). */
export function energyExpectation(coeffs: number[]): number {
  return coeffs.reduce((sum, c, n) => sum + c * c * (n + 0.5), 0);
}

/** Classical turning points for a given energy: x = ±√(2E). */
export function classicalTurningPoints(energy: number): { left: number; right: number } {
  const x = Math.sqrt(2 * energy);
  return { left: -x, right: x };
}

/** Numerical expectation values computed from a spatial grid. */
export function computeExpectations(
  points: { x: number; re: number; im: number; prob: number }[]
): { x: number; x2: number; p: number; p2: number } {
  const N = points.length;
  if (N < 3) return { x: 0, x2: 0, p: 0, p2: 0 };

  const dx = points[1].x - points[0].x;
  let sumProb = 0;
  let sumX = 0;
  let sumX2 = 0;
  let sumP = 0;
  let sumP2 = 0;

  for (let i = 0; i < N; i++) {
    const { x, re, im, prob } = points[i];

    let dRedx = 0;
    let dImdx = 0;
    if (i === 0) {
      dRedx = (points[1].re - points[0].re) / dx;
      dImdx = (points[1].im - points[0].im) / dx;
    } else if (i === N - 1) {
      dRedx = (points[N - 1].re - points[N - 2].re) / dx;
      dImdx = (points[N - 1].im - points[N - 2].im) / dx;
    } else {
      dRedx = (points[i + 1].re - points[i - 1].re) / (2 * dx);
      dImdx = (points[i + 1].im - points[i - 1].im) / (2 * dx);
    }

    const pVal = re * dImdx - im * dRedx;
    const p2Val = dRedx * dRedx + dImdx * dImdx;
    const w = i === 0 || i === N - 1 ? 0.5 : 1.0;

    sumProb += w * prob;
    sumX += w * x * prob;
    sumX2 += w * x * x * prob;
    sumP += w * pVal;
    sumP2 += w * p2Val;
  }

  const norm = sumProb * dx;
  if (norm < 1e-12) return { x: 0, x2: 0, p: 0, p2: 0 };

  return {
    x: (sumX * dx) / norm,
    x2: (sumX2 * dx) / norm,
    p: (sumP * dx) / norm,
    p2: (sumP2 * dx) / norm,
  };
}

function coherentCoeffs(alpha: number): number[] {
  const raw: number[] = [];
  let sum = 0;
  for (let n = 0; n < 6; n++) {
    const c = Math.pow(alpha, n) / Math.sqrt(factorial(n));
    raw.push(c);
    sum += c * c;
  }
  const norm = Math.sqrt(sum);
  return raw.map(c => c / norm);
}

export const PRESETS: QHOPreset[] = [
  {
    name: 'Ground state',
    color: '#10b981',
    description: 'The n=0 Gaussian — minimum uncertainty, no nodes, probability peaks at the centre.',
    coeffs: [1, 0, 0, 0, 0, 0],
    speed: 1, xMax: 5, eMax: 4.5, nMax: 5,
    showPotential: true, showEnergyLevels: true, showProbability: true,
    showReal: false, showImaginary: false, showClassicalTurning: true,
  },
  {
    name: 'First excited',
    color: '#6366f1',
    description: 'n=1 has a single node at x=0 and odd symmetry. The particle is never found at the centre.',
    coeffs: [0, 1, 0, 0, 0, 0],
    speed: 1, xMax: 5, eMax: 4.5, nMax: 5,
    showPotential: true, showEnergyLevels: true, showProbability: true,
    showReal: false, showImaginary: false, showClassicalTurning: true,
  },
  {
    name: 'Second excited',
    color: '#8b5cf6',
    description: 'n=2 has two nodes and even symmetry. The probability density shows three distinct peaks.',
    coeffs: [0, 0, 1, 0, 0, 0],
    speed: 1, xMax: 6, eMax: 4.5, nMax: 5,
    showPotential: true, showEnergyLevels: true, showProbability: true,
    showReal: false, showImaginary: false, showClassicalTurning: true,
  },
  {
    name: '0+1 superposition',
    color: '#f97316',
    description: 'An equal mix of ground and first excited states. Watch the probability "slosh" left and right — the quantum analogue of classical oscillation.',
    coeffs: [0.7071, 0.7071, 0, 0, 0, 0],
    speed: 1, xMax: 6, eMax: 4.5, nMax: 5,
    showPotential: true, showEnergyLevels: true, showProbability: true,
    showReal: true, showImaginary: true, showClassicalTurning: true,
  },
  {
    name: '0+2 superposition',
    color: '#f43f5e',
    description: 'Ground plus second excited. The probability "breathes" in place — expanding and contracting while staying centred.',
    coeffs: [0.7071, 0, 0.7071, 0, 0, 0],
    speed: 1, xMax: 6, eMax: 4.5, nMax: 5,
    showPotential: true, showEnergyLevels: true, showProbability: true,
    showReal: true, showImaginary: true, showClassicalTurning: true,
  },
  {
    name: 'Coherent state (α=2)',
    color: '#06b6d4',
    description: 'A minimum-uncertainty wave packet that oscillates back and forth like a classical particle while keeping its shape.',
    coeffs: coherentCoeffs(2),
    speed: 1, xMax: 8, eMax: 5.5, nMax: 6,
    showPotential: true, showEnergyLevels: true, showProbability: true,
    showReal: true, showImaginary: false, showClassicalTurning: true,
  },
  {
    name: 'Coherent state (α=3)',
    color: '#3b82f6',
    description: 'A larger coherent state with higher energy. The wave packet swings further from the centre with greater amplitude.',
    coeffs: coherentCoeffs(3),
    speed: 1, xMax: 10, eMax: 6.5, nMax: 7,
    showPotential: true, showEnergyLevels: true, showProbability: true,
    showReal: true, showImaginary: false, showClassicalTurning: true,
  },
];
