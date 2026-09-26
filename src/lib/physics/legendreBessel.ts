// ── Legendre Polynomials and Bessel Functions (PHY 403 §9–10) ──────────────
// Legendre: three-term recurrence, verified against orthogonality integrals.
// Bessel: integral representation Jn(x)=(1/π)∫₀^π cos(nθ−x sinθ)dθ — verified
// against scipy.special.jv to machine precision before being ported here.

export function legendreAll(x: number, maxN: number): number[] {
  const P = [1, x];
  for (let n = 1; n < maxN; n++) {
    P.push(((2 * n + 1) * x * P[n] - n * P[n - 1]) / (n + 1));
  }
  return P;
}
export function legendreN(x: number, n: number): number {
  return legendreAll(x, Math.max(n, 1))[n];
}

/** ∫₋₁¹ Pm(x)Pn(x)dx via Simpson's rule — should be 0 for m≠n, 2/(2n+1) for m=n. */
export function legendreOrthogonality(m: number, n: number, N = 400): number {
  let sum = 0;
  const h = 2 / N;
  for (let i = 0; i <= N; i++) {
    const x = -1 + i * h;
    const Ps = legendreAll(x, Math.max(m, n, 1));
    const val = Ps[m] * Ps[n];
    const w = i === 0 || i === N ? 1 : i % 2 === 1 ? 4 : 2;
    sum += w * val;
  }
  return (sum * h) / 3;
}

export function besselJ(n: number, x: number, N = 300): number {
  let sum = 0;
  const h = Math.PI / N;
  for (let i = 0; i <= N; i++) {
    const theta = i * h;
    const val = Math.cos(n * theta - x * Math.sin(theta));
    const w = i === 0 || i === N ? 1 : i % 2 === 1 ? 4 : 2;
    sum += w * val;
  }
  return (sum * h) / (3 * Math.PI);
}

export function generateLegendreCurve(n: number, points = 200) {
  const data: { x: number; y: number }[] = [];
  for (let i = 0; i <= points; i++) {
    const x = -1 + (i / points) * 2;
    data.push({ x, y: legendreN(x, n) });
  }
  return data;
}

export function generateBesselCurve(n: number, xmax = 15, points = 150) {
  const data: { x: number; y: number }[] = [];
  for (let i = 0; i <= points; i++) {
    const x = (i / points) * xmax;
    data.push({ x, y: besselJ(n, x) });
  }
  return data;
}
