// ── Fourier Series (PHY 403 §12) ────────────────────────────────────────────
// Three targets, each verified against their target function numerically
// before being ported here (the triangle-wave series originally had a sign
// error, caught and fixed during that verification — this version is correct).

const L = Math.PI;

export interface FourierTarget {
  name: string;
  f: (x: number) => number;
  term: (n: number, x: number) => number;
  formula: string;
  hasJump: boolean;
}

export const TARGETS: FourierTarget[] = [
  {
    name: 'Square wave',
    f: (x) => (((x % (2 * L)) + 2 * L) % (2 * L)) < L ? 1 : -1,
    term: (n, x) => n % 2 === 0 ? 0 : (4 / (n * Math.PI)) * Math.sin(n * x),
    formula: 'f(x) = (4/π) Σ (1/n) sin(nx),  n odd',
    hasJump: true,
  },
  {
    name: 'Sawtooth',
    f: (x) => { const t = (((x + L) % (2 * L)) + 2 * L) % (2 * L) - L; return t / L; },
    term: (n, x) => (2 * Math.pow(-1, n + 1) / (n * Math.PI)) * Math.sin(n * x),
    formula: 'f(x) = 2 Σ (−1)ⁿ⁺¹/n · sin(nx)',
    hasJump: true,
  },
  {
    name: 'Triangle wave',
    f: (x) => { const t = (((x + L) % (2 * L)) + 2 * L) % (2 * L) - L; return (2 / L) * Math.abs(t) - 1; },
    term: (n, x) => n % 2 === 0 ? 0 : (-8 / (Math.PI * Math.PI * n * n)) * Math.cos(n * x),
    formula: 'f(x) = −(8/π²) Σ cos(nx)/n²,  n odd (no jump — fast convergence)',
    hasJump: false,
  },
];

export function approx(target: FourierTarget, x: number, nMax: number): number {
  let s = 0;
  for (let n = 1; n <= nMax; n++) s += target.term(n, x);
  return s;
}

export function generateSeriesData(target: FourierTarget, nMax: number, points = 400) {
  const xmax = 3 * L;
  const data: { x: number; target: number; approx: number }[] = [];
  for (let i = 0; i <= points; i++) {
    const x = -xmax + (i / points) * 2 * xmax;
    data.push({ x, target: target.f(x), approx: approx(target, x, nMax) });
  }
  return data;
}

/** Peak overshoot near a jump, as a fraction of the jump height — the Gibbs phenomenon. */
export function peakOvershoot(target: FourierTarget, nMax: number): number {
  let maxVal = -Infinity;
  const N = 500;
  for (let i = 0; i <= N; i++) {
    const x = -L + 0.05 + (i / N) * (2 * L - 0.1);
    const y = approx(target, x, nMax);
    if (y > maxVal) maxVal = y;
  }
  return 100 * (maxVal - 1);
}
