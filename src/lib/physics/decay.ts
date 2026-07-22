// ── Radioactive decay ─────────────────────────────────────────────────────────
// N(t) = N₀ · e^(−λt) = N₀ · 2^(−t/T½)
// λ = ln2 / T½          (decay constant)
// A = λN                (activity, decays per second)

export const LN2 = Math.LN2;

export function decayConstant(halfLife: number) {
  return halfLife > 0 ? LN2 / halfLife : 0;
}
export function remaining(N0: number, halfLife: number, t: number) {
  return N0 * Math.pow(2, -t / halfLife);
}
export function activity(N: number, halfLife: number) {
  return decayConstant(halfLife) * N;
}
// Probability that a single nucleus decays during a small interval dt.
export function decayProbability(halfLife: number, dt: number) {
  return 1 - Math.pow(2, -dt / halfLife);
}
// Time for N₀ to fall to N: t = T½ · log2(N₀/N)
export function timeToReach(N0: number, N: number, halfLife: number) {
  return N > 0 ? halfLife * Math.log2(N0 / N) : Infinity;
}

// Analytic decay curve for the graph.
export function decayCurve(N0: number, halfLife: number, tMax: number, points = 120) {
  return Array.from({ length: points + 1 }, (_, i) => {
    const t = (i / points) * tMax;
    return { t: +t.toFixed(3), n: +remaining(N0, halfLife, t).toFixed(2) };
  });
}
