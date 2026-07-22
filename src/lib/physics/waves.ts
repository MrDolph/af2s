// ── Wave motion ───────────────────────────────────────────────────────────────
// v = fλ,  ω = 2πf,  k = 2π/λ,  T = 1/f
// Travelling wave:  y(x, t) = A sin(kx − ωt)   (moving in +x)

export function waveSpeed(f: number, lambda: number) { return f * lambda; }
export function angularFreq(f: number) { return 2 * Math.PI * f; }
export function waveNumber(lambda: number) { return (2 * Math.PI) / lambda; }
export function period(f: number) { return f > 0 ? 1 / f : 0; }

export function travellingY(A: number, k: number, omega: number, x: number, t: number, phi = 0, dir: 1 | -1 = 1) {
  return A * Math.sin(k * x - dir * omega * t + phi);
}

// Superposition of two waves (same string): y = y1 + y2
export function superposedY(
  A1: number, A2: number, k1: number, k2: number,
  omega1: number, omega2: number, x: number, t: number, phi2 = 0,
) {
  return travellingY(A1, k1, omega1, x, t) + travellingY(A2, k2, omega2, x, t, phi2);
}

// Standing wave from two identical opposite-travelling waves:
// y = A sin(kx − ωt) + A sin(kx + ωt) = 2A sin(kx) cos(ωt)
export function standingY(A: number, k: number, omega: number, x: number, t: number) {
  return 2 * A * Math.sin(k * x) * Math.cos(omega * t);
}

// Node positions of a standing wave in [0, L]: x = nλ/2
export function standingNodes(lambda: number, L: number) {
  const nodes: number[] = [];
  for (let n = 0; n * lambda / 2 <= L + 1e-9; n++) nodes.push(n * lambda / 2);
  return nodes;
}
