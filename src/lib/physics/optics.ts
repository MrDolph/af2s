// ── Geometrical optics ────────────────────────────────────────────────────────
const DEG = Math.PI / 180;

// Snell's law: n1 sinθ1 = n2 sinθ2. Returns θ2 in degrees, or null for TIR.
export function snellTheta2(n1: number, n2: number, theta1Deg: number): number | null {
  const s = (n1 / n2) * Math.sin(theta1Deg * DEG);
  if (Math.abs(s) > 1) return null; // total internal reflection
  return Math.asin(s) / DEG;
}

// Critical angle (only exists going from dense → less dense, n1 > n2).
export function criticalAngle(n1: number, n2: number): number | null {
  if (n1 <= n2) return null;
  return Math.asin(n2 / n1) / DEG;
}

// ── Thin lens / spherical mirror ──────────────────────────────────────────────
// "Real is positive" convention (the one WAEC/NECO/IGCSE mark schemes use):
//   1/f = 1/u + 1/v
//   f > 0 : converging lens / concave mirror
//   f < 0 : diverging lens / convex mirror
//   u > 0 : real object
//   v > 0 : real image,  v < 0 : virtual image
// Magnification m = v/u  (m > 0 inverted-real for lens diagrams below,
// interpreted per device in the UI).
export interface ImageResult {
  v: number;          // image distance (signed)
  m: number;          // |magnification|
  real: boolean;
  inverted: boolean;
  atInfinity: boolean;
}

export function thinLensImage(u: number, f: number): ImageResult {
  // 1/v = 1/f − 1/u  →  v = uf/(u − f)
  if (Math.abs(u - f) < 1e-9) {
    return { v: Infinity, m: Infinity, real: true, inverted: true, atInfinity: true };
  }
  const v = (u * f) / (u - f);
  const m = Math.abs(v / u);
  const real = v > 0;
  // Converging lens: real image is inverted, virtual image is upright.
  // Diverging lens (f < 0): image always virtual + upright.
  const inverted = real;
  return { v, m, real, inverted, atInfinity: false };
}

// Same formula holds for mirrors in real-is-positive convention.
export const mirrorImage = thinLensImage;

// Power of a lens in dioptres (f in metres).
export function lensPower(f_m: number) { return f_m !== 0 ? 1 / f_m : 0; }
