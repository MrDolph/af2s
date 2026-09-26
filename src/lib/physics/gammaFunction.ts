// ── The Gamma Function (PHY 403 §8) ─────────────────────────────────────────
// Lanczos approximation, g=7 — verified against known values (n!, Γ(½)=√π,
// Γ(−½)=−2√π) to floating-point precision before this was ported here.

const G = 7;
const COEFFS = [
  0.99999999999980993, 676.5203681218851, -1259.1392167224028, 771.32342877765313,
  -176.61502916214059, 12.507343278686905, -0.13857109526572012,
  9.9843695780195716e-6, 1.5056327351493116e-7,
];

export function gamma(x: number): number {
  if (x < 0.5) {
    const s = Math.sin(Math.PI * x);
    if (Math.abs(s) < 1e-10) return NaN; // pole at non-positive integers
    return Math.PI / (s * gamma(1 - x));
  }
  const xm1 = x - 1;
  let a = COEFFS[0];
  const t = xm1 + G + 0.5;
  for (let i = 1; i < G + 2; i++) a += COEFFS[i] / (xm1 + i);
  return Math.sqrt(2 * Math.PI) * Math.pow(t, xm1 + 0.5) * Math.exp(-t) * a;
}

export function factorial(n: number): number {
  let r = 1;
  for (let i = 2; i <= n; i++) r *= i;
  return r;
}

/** Generates {x, gamma} samples over a continuous branch, breaking at poles. */
export function generateGammaBranch(xmin: number, xmax: number, points = 400) {
  const data: { x: number; gamma: number | null }[] = [];
  for (let i = 0; i <= points; i++) {
    const x = xmin + (i / points) * (xmax - xmin);
    const g = gamma(x);
    const nearPole = Math.abs(x - Math.round(x)) < 0.01 && x <= 0.01;
    data.push({ x, gamma: !isFinite(g) || nearPole || Math.abs(g) > 30 ? null : g });
  }
  return data;
}
