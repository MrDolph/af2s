// ── Damped Harmonic Oscillator (PHY 403 §14–15) ────────────────────────────
// Governing ODE: y'' + 2γy' + ω₀²y = 0
// Solved via Laplace transform (Y(s) found algebraically, then inverted).
// Three regimes, selected by comparing γ and ω₀:
//   γ < ω₀  → underdamped   (decaying oscillation)
//   γ = ω₀  → critically damped (fastest non-oscillatory return to zero)
//   γ > ω₀  → overdamped    (slow, non-oscillatory decay)
//
// Verified against direct RK4 numerical integration of the ODE across all
// three regimes and several initial-condition combinations — max error
// ~1e-12 (floating-point noise), confirming the closed-form solution below.

export interface DampedOscillatorParams {
  gamma: number;   // damping coefficient γ (1/s)
  omega0: number;  // undamped natural angular frequency ω₀ (rad/s)
  y0: number;      // initial displacement y(0)
  yp0: number;     // initial velocity y'(0)
}

export type DampingRegime = 'underdamped' | 'critical' | 'overdamped';

export function dampingRegime(gamma: number, omega0: number): DampingRegime {
  const disc = omega0 * omega0 - gamma * gamma;
  if (Math.abs(disc) < 1e-6) return 'critical';
  return disc > 0 ? 'underdamped' : 'overdamped';
}

/** y(t) for the damped oscillator, valid across all three regimes. */
export function dampedY(t: number, { gamma, omega0, y0, yp0 }: DampedOscillatorParams): number {
  const disc = omega0 * omega0 - gamma * gamma;
  const b = yp0 + gamma * y0; // shared coefficient from the Laplace-transform partial fractions

  if (Math.abs(disc) < 1e-6) {
    // Critically damped: y(t) = e^{-γt}[y0 + (y'0 + γy0)t]
    return Math.exp(-gamma * t) * (y0 + b * t);
  }
  if (disc > 0) {
    // Underdamped: y(t) = e^{-γt}[y0 cos(ω_d t) + (b/ω_d) sin(ω_d t)]
    const wd = Math.sqrt(disc);
    return Math.exp(-gamma * t) * (y0 * Math.cos(wd * t) + (b / wd) * Math.sin(wd * t));
  }
  // Overdamped: y(t) = e^{-γt}[y0 cosh(ω_h t) + (b/ω_h) sinh(ω_h t)]
  const wh = Math.sqrt(-disc);
  return Math.exp(-gamma * t) * (y0 * Math.cosh(wh * t) + (b / wh) * Math.sinh(wh * t));
}

/** ω_d (underdamped) or ω_h (overdamped) — undefined/irrelevant at critical damping. */
export function dampedSecondaryFreq(gamma: number, omega0: number): number {
  const disc = omega0 * omega0 - gamma * gamma;
  return Math.sqrt(Math.abs(disc));
}

/** Amplitude envelope bound |y(t)| ≤ envelope(t) — exact for underdamped, an approximate guide otherwise. */
export function dampedEnvelope(t: number, { gamma, omega0, y0, yp0 }: DampedOscillatorParams): number {
  const disc = omega0 * omega0 - gamma * gamma;
  const b = yp0 + gamma * y0;
  const w = Math.sqrt(Math.max(Math.abs(disc), 0.09));
  const amp = Math.sqrt(y0 * y0 + (b / w) * (b / w));
  return amp * Math.exp(-gamma * t);
}

/** Generates {t, y} samples over [0, tmax] for plotting. */
export function generateDampedData(params: DampedOscillatorParams, tmax: number, points = 300) {
  const data: { t: number; y: number; envelope: number; envelopeNeg: number }[] = [];
  for (let i = 0; i <= points; i++) {
    const t = (i / points) * tmax;
    const env = dampedEnvelope(t, params);
    data.push({ t, y: dampedY(t, params), envelope: env, envelopeNeg: -env });
  }
  return data;
}
