export const g = 9.81;

// ── Core SHM equations ────────────────────────────────────────────────────────
// x(t) = A cos(ωt + φ)
// v(t) = -Aω sin(ωt + φ)
// a(t) = -Aω² cos(ωt + φ) = -ω²x

export function shmDisplacement(A: number, omega: number, t: number, phi = 0) {
  return A * Math.cos(omega * t + phi);
}
export function shmVelocity(A: number, omega: number, t: number, phi = 0) {
  return -A * omega * Math.sin(omega * t + phi);
}
export function shmAcceleration(A: number, omega: number, t: number, phi = 0) {
  return -A * omega * omega * Math.cos(omega * t + phi);
}
export function shmKE(m: number, v: number) { return 0.5 * m * v * v; }
export function shmPE(k: number, x: number) { return 0.5 * k * x * x; }
export function shmTE(m: number, A: number, omega: number) { return 0.5 * m * A * A * omega * omega; }

// ── Simple Pendulum ───────────────────────────────────────────────────────────
export function pendulumOmega(L: number, grav = g) { return Math.sqrt(grav / L); }
export function pendulumPeriod(L: number, grav = g) { return 2 * Math.PI * Math.sqrt(L / grav); }
export function pendulumAngle(A_rad: number, omega: number, t: number) {
  return A_rad * Math.cos(omega * t);
}

// ── Loaded Spring ─────────────────────────────────────────────────────────────
export function springOmega(k: number, m: number) { return Math.sqrt(k / m); }
export function springPeriod(k: number, m: number) { return 2 * Math.PI * Math.sqrt(m / k); }
export function springStaticExtension(m: number, k: number) { return (m * g) / k; }

// ── Conical Pendulum ──────────────────────────────────────────────────────────
export function conicalPendulumOmega(L: number, theta_rad: number) {
  // T cosθ = mg, T sinθ = mω²r, r = L sinθ → ω² = g/(L cosθ)
  return Math.sqrt(g / (L * Math.cos(theta_rad)));
}
export function conicalPendulumPeriod(L: number, theta_rad: number) {
  return 2 * Math.PI / conicalPendulumOmega(L, theta_rad);
}
export function conicalPendulumTension(m: number, theta_rad: number) {
  return (m * g) / Math.cos(theta_rad);
}
export function conicalPendulumRadius(L: number, theta_rad: number) {
  return L * Math.sin(theta_rad);
}
export function conicalPendulumSpeed(L: number, theta_rad: number) {
  const r = conicalPendulumRadius(L, theta_rad);
  const omega = conicalPendulumOmega(L, theta_rad);
  return r * omega;
}

// ── Physical Pendulum ─────────────────────────────────────────────────────────
// T = 2π√(I/mgd) where I = moment of inertia about pivot, d = distance pivot to CoM
export function physicalPendulumPeriod(I: number, m: number, d: number) {
  return 2 * Math.PI * Math.sqrt(I / (m * g * d));
}
// Uniform rod pivoted at one end: I = mL²/3, d = L/2
export function rodPendulumPeriod(L: number) {
  const I = (1 / 3) * 1 * L * L; // m=1 for ratio
  return 2 * Math.PI * Math.sqrt(I / (1 * g * L / 2));
}
// Equivalent simple pendulum length: L_eq = I/(md)
export function equivalentLength(I: number, m: number, d: number) {
  return I / (m * d);
}

// ── Bifilar Suspension ────────────────────────────────────────────────────────
// T = 2π × (l/d) × √(2I/mg) where l=wire length, d=half-separation, I=moment about vertical axis
// For uniform rod: I = mL²/12
export function bifilarPeriod(l: number, d: number, m: number, I: number) {
  return (2 * Math.PI * l / d) * Math.sqrt(I / (m * g * l));
  // simplified: T = 2π√(Il/(mgd²))  → T = (2π/d)√(Il/(mg))
}
export function bifilarPeriodSimple(m: number, L_rod: number, l_wire: number, d_sep: number) {
  const I = m * L_rod * L_rod / 12;
  return 2 * Math.PI * Math.sqrt(I * l_wire / (m * g * d_sep * d_sep));
}

// ── Cantilever ────────────────────────────────────────────────────────────────
// Deflection: y = WL³/(3EI) where E=Young's modulus, I=second moment of area
// For rectangular beam: I_beam = bh³/12
// Period of vibration: T = 2π√(m_eff/k_beam), k_beam = 3EI/L³
export function cantileverStiffness(E: number, b: number, h: number, L: number) {
  const I_beam = (b * h * h * h) / 12;
  return (3 * E * I_beam) / (L * L * L);
}
export function cantileverDeflection(W: number, E: number, b: number, h: number, L: number) {
  return W / cantileverStiffness(E, b, h, L);
}
export function cantileverPeriod(m: number, E: number, b: number, h: number, L: number) {
  const k = cantileverStiffness(E, b, h, L);
  return 2 * Math.PI * Math.sqrt(m / k);
}

// ── Generate SHM graph data ───────────────────────────────────────────────────
export function generateSHMData(
  A: number, omega: number, m: number, k: number,
  cycles = 3, points = 200
) {
  const T = (2 * Math.PI) / omega;
  const totalTime = cycles * T;
  return Array.from({ length: points + 1 }, (_, i) => {
    const t = (i / points) * totalTime;
    const x = shmDisplacement(A, omega, t);
    const v = shmVelocity(A, omega, t);
    const a = shmAcceleration(A, omega, t);
    const ke = shmKE(m, v);
    const pe = shmPE(k, x);
    return { t: +t.toFixed(3), x: +x.toFixed(4), v: +v.toFixed(4), a: +a.toFixed(4), ke: +ke.toFixed(4), pe: +pe.toFixed(4), te: +(ke + pe).toFixed(4) };
  });
}
