// ── Eigenvectors and Linear Transformations (PHY 403 §6) ───────────────────

export interface Matrix2x2 { a: number; b: number; c: number; d: number; }

export interface MatrixPreset { name: string; m: Matrix2x2; }

export const PRESETS: MatrixPreset[] = [
  { name: 'Identity', m: { a: 1, b: 0, c: 0, d: 1 } },
  { name: 'Symmetric (Ex 6.12)', m: { a: 2, b: 1, c: 1, d: 2 } },
  { name: 'Non-symmetric (Ex 6.8)', m: { a: 4, b: 1, c: 2, d: 3 } },
  { name: 'Pure rotation 40°', m: {
    a: Math.cos((40 * Math.PI) / 180), b: -Math.sin((40 * Math.PI) / 180),
    c: Math.sin((40 * Math.PI) / 180), d: Math.cos((40 * Math.PI) / 180),
  } },
  { name: 'Shear', m: { a: 1, b: 0.8, c: 0, d: 1 } },
  { name: 'Scale (2×, 0.5×)', m: { a: 2, b: 0, c: 0, d: 0.5 } },
];

export interface EigenResult {
  complex: boolean;
  l1?: number; l2?: number;
  v1?: [number, number]; v2?: [number, number];
  trace: number; det: number;
}

export function eigen({ a, b, c, d }: Matrix2x2): EigenResult {
  const trace = a + d, det = a * d - b * c;
  const disc = trace * trace - 4 * det;
  if (disc < 0) return { complex: true, trace, det };
  const s = Math.sqrt(disc);
  const l1 = (trace + s) / 2, l2 = (trace - s) / 2;
  const norm = (v: [number, number]): [number, number] => {
    const m = Math.hypot(v[0], v[1]) || 1;
    return [v[0] / m, v[1] / m];
  };
  const vecFor = (l: number): [number, number] => {
    if (Math.abs(b) > 1e-9) return norm([b, l - a]);
    if (Math.abs(c) > 1e-9) return norm([l - d, c]);
    return Math.abs(a - l) < 1e-6 ? [1, 0] : [0, 1];
  };
  return { complex: false, l1, l2, v1: vecFor(l1), v2: vecFor(l2), trace, det };
}

/** Linear interpolation from identity (t=0) to the full matrix (t=1). */
export function matAt({ a, b, c, d }: Matrix2x2, t: number): Matrix2x2 {
  return { a: 1 + t * (a - 1), b: t * b, c: t * c, d: 1 + t * (d - 1) };
}
