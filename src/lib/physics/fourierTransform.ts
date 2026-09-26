// ── Fourier Transform Pairs (PHY 403 §13) ───────────────────────────────────
// Three pairs, each F(k) verified by direct numerical integration against
// its closed-form transform before being ported here.

export interface TransformPair {
  name: string;
  f: (x: number, a: number) => number;
  F: (k: number, a: number) => number;
  formula: string;
}

export const PAIRS: TransformPair[] = [
  {
    name: 'Rectangular pulse',
    f: (x, a) => Math.abs(x) < a ? 1 : 0,
    F: (k, a) => k === 0 ? 2 * a : (2 * Math.sin(k * a)) / k,
    formula: 'f(x)=1 for |x|<a  ↔  F(k)=2sin(ka)/k',
  },
  {
    name: 'Gaussian',
    f: (x, a) => Math.exp(-(x * x) / (2 * a * a)),
    F: (k, a) => a * Math.sqrt(2 * Math.PI) * Math.exp((-a * a * k * k) / 2),
    formula: 'f(x)=e^(−x²/2a²)  ↔  F(k)=a√(2π)e^(−a²k²/2)',
  },
  {
    name: 'Decaying exponential',
    f: (x, a) => Math.exp(-Math.abs(x) / a),
    F: (k, a) => (2 / a) / (1 / (a * a) + k * k),
    formula: 'f(x)=e^(−|x|/a)  ↔  F(k)=2a/(1+a²k²)',
  },
];

export function generatePairData(pair: TransformPair, a: number, xmax: number, points = 400) {
  const data: { x: number; y: number }[] = [];
  let maxAbs = 0;
  for (let i = 0; i <= points; i++) {
    const x = -xmax + (i / points) * 2 * xmax;
    const y = pair.f(x, a);
    if (Math.abs(y) > maxAbs) maxAbs = Math.abs(y);
    data.push({ x, y });
  }
  return { data: data.map(d => ({ x: d.x, y: maxAbs > 0 ? d.y / maxAbs : d.y })), maxAbs };
}

export function generateTransformData(pair: TransformPair, a: number, kmax: number, points = 400) {
  const data: { x: number; y: number }[] = [];
  let maxAbs = 0;
  for (let i = 0; i <= points; i++) {
    const k = -kmax + (i / points) * 2 * kmax;
    const y = pair.F(k, a);
    if (Math.abs(y) > maxAbs) maxAbs = Math.abs(y);
    data.push({ x: k, y });
  }
  return { data: data.map(d => ({ x: d.x, y: maxAbs > 0 ? d.y / maxAbs : d.y })), maxAbs };
}
