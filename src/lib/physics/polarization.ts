// ── Polarization ─────────────────────────────────────────────────────────────
// Light is a transverse wave; "unpolarized" light vibrates in every
// direction perpendicular to its travel. A polarizer only transmits the
// component of vibration along its transmission axis, producing light that
// vibrates in a single plane — "plane-polarized" light.

// Malus's law: once light is already plane-polarized, the intensity that
// passes through a second polarizer (the "analyser") set at angle θ to the
// first depends on cos²θ.
export function malusIntensity(I0: number, angleDeg: number): number {
  const rad = (angleDeg * Math.PI) / 180;
  return I0 * Math.pow(Math.cos(rad), 2);
}

// Fraction of unpolarized light transmitted by a single ideal polarizer —
// exactly half, regardless of the transmission axis's orientation (there is
// no "angle" for the first polarizer to be measured against yet).
export const UNPOLARIZED_TRANSMISSION_FRACTION = 0.5;

export function malusCurve(I0: number, points = 90) {
  return Array.from({ length: points + 1 }, (_, i) => {
    const angle = (i / points) * 180;
    return { angle: +angle.toFixed(1), I: +malusIntensity(I0, angle).toFixed(3) };
  });
}
