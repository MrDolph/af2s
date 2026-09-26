// ── Gradient & Directional Derivative (PHY 403 §1–2) ───────────────────────
// D_â φ = ∇φ · â — the whole payoff of Chapter 2, replacing Chapter 1's slow
// limit-definition calculation with a single dot product.

export interface ScalarField {
  name: string;
  f: (x: number, y: number) => number;
  gx: (x: number, y: number) => number; // ∂φ/∂x
  gy: (x: number, y: number) => number; // ∂φ/∂y
  levels: number[];
}

export const FIELDS: ScalarField[] = [
  {
    name: 'Bowl: x²+y²',
    f: (x, y) => x * x + y * y,
    gx: (x) => 2 * x,
    gy: (y) => 2 * y,
    levels: [0.3, 0.7, 1.2, 1.8, 2.5, 3.3],
  },
  {
    name: 'Saddle: x²−y²',
    f: (x, y) => x * x - y * y,
    gx: (x) => 2 * x,
    gy: (y) => -2 * y,
    levels: [-2.5, -1.5, -0.6, 0, 0.6, 1.5, 2.5],
  },
  {
    name: 'Ellipse: x²+4y²',
    f: (x, y) => x * x + 4 * y * y,
    gx: (x) => 2 * x,
    gy: (y) => 8 * y,
    levels: [0.5, 1.2, 2.2, 3.5, 5, 7],
  },
  {
    name: 'Hyperbolic: xy',
    f: (x, y) => x * y,
    gx: (_x, y) => y,
    gy: (x) => x,
    levels: [-2, -1.2, -0.5, 0.5, 1.2, 2],
  },
];

/** Marching-squares contour extraction — returns line segments per level. */
export function computeContours(
  field: ScalarField,
  xmin: number, xmax: number, ymin: number, ymax: number, n = 70
) {
  const dx = (xmax - xmin) / n, dy = (ymax - ymin) / n;
  const grid: number[][] = [];
  for (let j = 0; j <= n; j++) {
    const row: number[] = [];
    for (let i = 0; i <= n; i++) row.push(field.f(xmin + i * dx, ymin + j * dy));
    grid.push(row);
  }
  const allSegs: [number, number][][] = [];
  field.levels.forEach(level => {
    for (let j = 0; j < n; j++) {
      for (let i = 0; i < n; i++) {
        const x0 = xmin + i * dx, x1 = xmin + (i + 1) * dx, y0 = ymin + j * dy, y1 = ymin + (j + 1) * dy;
        const v = [grid[j][i], grid[j][i + 1], grid[j + 1][i + 1], grid[j + 1][i]];
        let idx = 0;
        if (v[0] > level) idx |= 1; if (v[1] > level) idx |= 2;
        if (v[2] > level) idx |= 4; if (v[3] > level) idx |= 8;
        if (idx === 0 || idx === 15) continue;
        const interp = (a: [number, number], b: [number, number], va: number, vb: number): [number, number] => {
          const t = (level - va) / (vb - va);
          return [a[0] + t * (b[0] - a[0]), a[1] + t * (b[1] - a[1])];
        };
        const P: [number, number] = [x0, y0], Q: [number, number] = [x1, y0],
          R: [number, number] = [x1, y1], S: [number, number] = [x0, y1];
        const eT = interp(P, Q, v[0], v[1]), eR = interp(Q, R, v[1], v[2]),
          eB = interp(R, S, v[2], v[3]), eL = interp(S, P, v[3], v[0]);
        const table: Record<number, [number, number][][]> = {
          1: [[eL, eT]], 2: [[eT, eR]], 3: [[eL, eR]], 4: [[eR, eB]],
          5: [[eL, eT], [eR, eB]], 6: [[eT, eB]], 7: [[eL, eB]], 8: [[eL, eB]],
          9: [[eT, eB]], 10: [[eT, eR], [eL, eB]], 11: [[eR, eB]], 12: [[eL, eR]],
          13: [[eT, eR]], 14: [[eL, eT]],
        };
        const pairs = table[idx];
        if (pairs) allSegs.push(...pairs);
      }
    }
  });
  return allSegs;
}
