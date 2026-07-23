// ── Diffraction ───────────────────────────────────────────────────────────────
// Diffraction is the spreading of a wave as it passes through a gap or
// around an obstacle. It becomes pronounced when the gap width is
// comparable to (or smaller than) the wavelength — this is why sound
// (wavelengths of metres) diffracts noticeably around doorways while light
// (wavelengths of hundreds of nanometres) barely seems to at everyday gaps.

// Angle to the first minimum either side of the central maximum for a
// single slit of width `a`, wavelength `lambda` (consistent units):
// sinθ = λ/a. Returns degrees; null if λ > a (no minimum exists — the
// central maximum spreads across the whole far side).
export function firstMinimumAngle(wavelength: number, slitWidth: number): number | null {
  if (slitWidth <= 0) return null;
  const s = wavelength / slitWidth;
  if (s > 1) return null;
  return (Math.asin(s) * 180) / Math.PI;
}

// A simple, honest visual proxy for "how much the wave spreads out" — not
// a literal intensity calculation, just a monotonic 0..1 measure of how
// wide the diffracted wavefront's angular spread should be drawn, based on
// the wavelength-to-slit-width ratio. Narrow slit (ratio → large) spreads
// close to a full half-plane; wide slit (ratio → 0) stays close to a
// forward beam.
export function spreadFraction(wavelength: number, slitWidth: number): number {
  if (slitWidth <= 0) return 1;
  const ratio = wavelength / slitWidth;
  return Math.min(1, ratio);
}

// ── Diffraction grating ──────────────────────────────────────────────────────
// Grating equation: d·sinθ = n·λ — bright fringes (maxima) form where light
// from every slit arrives in phase. d = slit spacing, n = order (0, ±1, ±2…).
export function gratingMaximumAngle(wavelength: number, slitSpacing: number, order: number): number | null {
  if (slitSpacing <= 0) return null;
  const s = (order * wavelength) / slitSpacing;
  if (Math.abs(s) > 1) return null; // this order does not exist at this λ, d
  return (Math.asin(s) * 180) / Math.PI;
}
// Highest order that actually appears for a given wavelength and spacing.
export function maxGratingOrder(wavelength: number, slitSpacing: number): number {
  if (slitSpacing <= 0 || wavelength <= 0) return 0;
  return Math.floor(slitSpacing / wavelength);
}
