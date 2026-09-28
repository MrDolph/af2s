// ── Unit Circle Trigonometry ────────────────────────────────────────────────
// Pure helpers: angle conversion, common reference angles (with their exact
// radian fractions for display), and quadrant lookup.

export const deg2rad = (deg: number) => (deg * Math.PI) / 180;
export const rad2deg = (rad: number) => (rad * 180) / Math.PI;

export interface CommonAngle {
  deg: number;
  radLabel: string; // exact fraction, e.g. "π/6"
}

// The 16 standard reference angles shown around the circle (every 15°/30°
// depending on quadrant, matching the conventional unit-circle diagram).
export const COMMON_ANGLES: CommonAngle[] = [
  { deg: 0, radLabel: '0' },
  { deg: 30, radLabel: 'π/6' },
  { deg: 45, radLabel: 'π/4' },
  { deg: 60, radLabel: 'π/3' },
  { deg: 90, radLabel: 'π/2' },
  { deg: 120, radLabel: '2π/3' },
  { deg: 135, radLabel: '3π/4' },
  { deg: 150, radLabel: '5π/6' },
  { deg: 180, radLabel: 'π' },
  { deg: 210, radLabel: '7π/6' },
  { deg: 225, radLabel: '5π/4' },
  { deg: 240, radLabel: '4π/3' },
  { deg: 270, radLabel: '3π/2' },
  { deg: 300, radLabel: '5π/3' },
  { deg: 315, radLabel: '7π/4' },
  { deg: 330, radLabel: '11π/6' },
];

export function quadrantOf(deg: number): 1 | 2 | 3 | 4 {
  const d = ((deg % 360) + 360) % 360;
  if (d < 90) return 1;
  if (d < 180) return 2;
  if (d < 270) return 3;
  return 4;
}

export const QUADRANT_SIGNS: Record<1 | 2 | 3 | 4, { sin: string; cos: string }> = {
  1: { sin: '+', cos: '+' },
  2: { sin: '+', cos: '−' },
  3: { sin: '−', cos: '−' },
  4: { sin: '−', cos: '+' },
};

/** Generates {deg, sin, cos} samples over [0, 360] for the graphs below the circle. */
export function generateTrigCurve(points = 361) {
  const data: { deg: number; sin: number; cos: number }[] = [];
  for (let i = 0; i < points; i++) {
    const deg = (i / (points - 1)) * 360;
    const rad = deg2rad(deg);
    data.push({ deg, sin: Math.sin(rad), cos: Math.cos(rad) });
  }
  return data;
}
