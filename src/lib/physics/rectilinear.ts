// ── Rectilinear propagation of light ─────────────────────────────────────────
// Light travels in straight lines through a uniform medium. Every effect in
// this module — shadows, eclipses, the pinhole camera — is a direct
// geometric consequence of that single fact, provable by similar triangles.

// Distance beyond an opaque object at which the umbra (the fully-dark
// shadow core) converges to a point, for an extended source. Similar
// triangles: umbraLength/objectRadius = (sourceToObjectDist+umbraLength)/sourceRadius.
// Returns null if the source is the same size as (or smaller than) the
// object — the umbra then never converges within a finite distance.
export function umbraLength(sourceRadius: number, objectRadius: number, sourceToObjectDist: number): number | null {
  if (sourceRadius <= objectRadius) return null;
  return (objectRadius * sourceToObjectDist) / (sourceRadius - objectRadius);
}

// Apparent angular diameter of an object of true diameter `diameter` seen
// from distance `distance` (same units) — small-angle-free exact form,
// returned in degrees.
export function angularDiameter(diameter: number, distance: number): number {
  return (2 * Math.atan(diameter / (2 * distance)) * 180) / Math.PI;
}

// ── Pinhole camera ────────────────────────────────────────────────────────────
// Image height by similar triangles: hImage/v = hObject/u, where u = object
// to pinhole distance, v = pinhole to screen distance. The image is always
// real (formed on a screen) and always inverted — a direct, unavoidable
// consequence of light travelling in straight lines through a single point.
export function pinholeImageHeight(objectHeight: number, u: number, v: number): number {
  return objectHeight * (v / u);
}
export function pinholeMagnification(u: number, v: number): number {
  return v / u;
}

// ── Real astronomical data, for the eclipse mode ─────────────────────────────
// Approximate mean values (km). The Sun is about 400× the Moon's diameter
// AND about 400× farther away — nearly cancelling out, which is why the Sun
// and Moon have almost the same apparent size in the sky and total solar
// eclipses are possible at all. This is a genuine, well-known coincidence
// of the current solar system, not a physical law.
export const SUN_DIAMETER_KM = 1_391_000;
export const SUN_DISTANCE_KM = 149_600_000;
export const MOON_DIAMETER_KM = 3474;
export const MOON_DISTANCE_KM = 384_400;
export const EARTH_DIAMETER_KM = 12_742;

export const SUN_ANGULAR_DIAMETER_DEG = angularDiameter(SUN_DIAMETER_KM, SUN_DISTANCE_KM);
export const MOON_ANGULAR_DIAMETER_DEG = angularDiameter(MOON_DIAMETER_KM, MOON_DISTANCE_KM);
