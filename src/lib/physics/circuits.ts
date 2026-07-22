// ── Ohm's law & DC circuits ───────────────────────────────────────────────────
// V = IR.  P = VI = I²R = V²/R.

export function ohmCurrent(V: number, R: number) {
  return R > 0 ? V / R : 0;
}
export function power(V: number, I: number) {
  return V * I;
}

// ── Series: same current everywhere, voltages add ─────────────────────────────
export function seriesTotal(resistors: number[]) {
  return resistors.reduce((a, r) => a + r, 0);
}
export function seriesAnalysis(V: number, resistors: number[]) {
  const Rtotal = seriesTotal(resistors);
  const I = ohmCurrent(V, Rtotal);
  return {
    Rtotal,
    I,
    drops: resistors.map(R => I * R),   // voltage divider: V_i = I·R_i
    powers: resistors.map(R => I * I * R),
    Ptotal: V * I,
  };
}

// ── Parallel: same voltage everywhere, currents add ───────────────────────────
export function parallelTotal(resistors: number[]) {
  const invSum = resistors.reduce((a, r) => a + (r > 0 ? 1 / r : 0), 0);
  return invSum > 0 ? 1 / invSum : 0;
}
export function parallelAnalysis(V: number, resistors: number[]) {
  const Rtotal = parallelTotal(resistors);
  const branches = resistors.map(R => ohmCurrent(V, R)); // current divider: I_i = V/R_i
  const I = branches.reduce((a, i) => a + i, 0);
  return {
    Rtotal,
    I,
    branches,
    powers: resistors.map(R => (V * V) / R),
    Ptotal: V * I,
  };
}

// I–V characteristic points for a fixed resistance (straight line, slope 1/R).
export function ivLine(R: number, vMax: number, points = 50) {
  return Array.from({ length: points + 1 }, (_, i) => {
    const v = (i / points) * vMax;
    return { v: +v.toFixed(3), i: +ohmCurrent(v, R).toFixed(4) };
  });
}
