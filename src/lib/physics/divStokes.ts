// ── Divergence and Stokes' / Green's Theorem, 2-D demo (PHY 403 §3–4) ──────
// A draggable disk: boundary flux/circulation vs. interior area integrals,
// computed completely independently, always agreeing.

export interface VectorField2D {
  name: string;
  fx: (x: number, y: number) => number;
  fy: (x: number, y: number) => number;
}

export const FIELDS: VectorField2D[] = [
  { name: 'Source: F=(x,y)', fx: (x) => x, fy: (_x, y) => y },
  { name: 'Rotation: F=(−y,x)', fx: (_x, y) => -y, fy: (x) => x },
  { name: 'Mixed: F=(x−y, x+y)', fx: (x, y) => x - y, fy: (x, y) => x + y },
  { name: 'Variable: F=(x², y²)', fx: (x) => x * x, fy: (_x, y) => y * y },
  { name: 'Saddle: F=(x, −y)', fx: (x) => x, fy: (_x, y) => -y },
];

export function boundaryIntegrals(f: VectorField2D, cx: number, cy: number, r: number, N = 720) {
  let circulation = 0, flux = 0;
  const dtheta = (2 * Math.PI) / N;
  for (let i = 0; i < N; i++) {
    const th = i * dtheta;
    const x = cx + r * Math.cos(th), y = cy + r * Math.sin(th);
    const Fx = f.fx(x, y), Fy = f.fy(x, y);
    const tx = -Math.sin(th), ty = Math.cos(th);
    const nx = Math.cos(th), ny = Math.sin(th);
    const ds = r * dtheta;
    circulation += (Fx * tx + Fy * ty) * ds;
    flux += (Fx * nx + Fy * ny) * ds;
  }
  return { circulation, flux };
}

export function areaIntegrals(f: VectorField2D, cx: number, cy: number, r: number, M = 90) {
  let sumDiv = 0, sumCurl = 0;
  const h = (2 * r) / M, eps = 1e-4;
  for (let i = 0; i < M; i++) {
    for (let j = 0; j < M; j++) {
      const x = cx - r + (i + 0.5) * h, y = cy - r + (j + 0.5) * h;
      if ((x - cx) * (x - cx) + (y - cy) * (y - cy) > r * r) continue;
      const dFxdx = (f.fx(x + eps, y) - f.fx(x - eps, y)) / (2 * eps);
      const dFydy = (f.fy(x, y + eps) - f.fy(x, y - eps)) / (2 * eps);
      const dFydx = (f.fy(x + eps, y) - f.fy(x - eps, y)) / (2 * eps);
      const dFxdy = (f.fx(x, y + eps) - f.fx(x, y - eps)) / (2 * eps);
      sumDiv += (dFxdx + dFydy) * h * h;
      sumCurl += (dFydx - dFxdy) * h * h;
    }
  }
  return { divIntegral: sumDiv, curlIntegral: sumCurl };
}
