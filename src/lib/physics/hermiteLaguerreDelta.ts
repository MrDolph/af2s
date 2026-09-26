// ── Hermite, Laguerre Polynomials, and the Dirac Delta (PHY 403 §11) ───────

export function hermiteAll(x: number, maxN: number): number[] {
  const H = [1, 2 * x];
  for (let n = 1; n < maxN; n++) H.push(2 * x * H[n] - 2 * n * H[n - 1]);
  return H;
}
export function laguerreAll(x: number, maxN: number): number[] {
  const L = [1, 1 - x];
  for (let n = 1; n < maxN; n++) L.push(((2 * n + 1 - x) * L[n] - n * L[n - 1]) / (n + 1));
  return L;
}

export function generateHermiteCurve(n: number, points = 250) {
  const xmax = 2.6, xmin = -2.6, maxOrd = 6;
  const data: { x: number; y: number }[] = [];
  for (let i = 0; i <= points; i++) {
    const x = xmin + (i / points) * (xmax - xmin);
    const vals = hermiteAll(x, maxOrd);
    // mild scale-down for high n keeps all curves visible on one axis
    const scale = n > 2 ? Math.pow(2, n * 0.6) : 1;
    data.push({ x, y: Math.max(-13, Math.min(13, vals[n] / scale)) });
  }
  return data;
}
export function generateLaguerreCurve(n: number, points = 250) {
  const xmax = 10, xmin = 0, maxOrd = 5;
  const data: { x: number; y: number }[] = [];
  for (let i = 0; i <= points; i++) {
    const x = xmin + (i / points) * (xmax - xmin);
    const vals = laguerreAll(x, maxOrd);
    data.push({ x, y: Math.max(-13, Math.min(13, vals[n] * 3)) });
  }
  return data;
}

export function testFn(name: string, x: number): number {
  if (name === 'quad') return x * x * 0.15 + 1;
  if (name === 'sin') return Math.sin(x) * 0.8 + 2;
  return 0.02 * x * x * x - 0.15 * x + 2; // cube
}

export function pulse(eps: number, x: number): number {
  return (1 / (eps * Math.sqrt(Math.PI))) * Math.exp(-(x * x) / (eps * eps));
}

/** Numerically integrates the pulse's area and the sifting integral ∫f·pulse dx. */
export function deltaIntegrals(eps: number, fname: string) {
  const L = Math.max(30 * eps, 8);
  const M = 4000, h = (2 * L) / M;
  let area = 0, sift = 0;
  for (let i = 0; i <= M; i++) {
    const x = -L + i * h;
    const w = i === 0 || i === M ? 1 : i % 2 === 1 ? 4 : 2;
    area += w * pulse(eps, x);
    sift += w * pulse(eps, x) * testFn(fname, x);
  }
  return { area: (area * h) / 3, sift: (sift * h) / 3 };
}
