export const DEG = Math.PI / 180;

// ── Standard projectile (launched from height h) ──────────────────────────────
export interface StandardParams {
  v0: number;       // m/s
  angle: number;    // degrees above horizontal
  g: number;        // m/s²
  h0: number;       // launch height (m) — 0 for ground, >0 for platform/building
}
export function standardAnalytics(p: StandardParams) {
  const { v0, angle, g, h0 } = p;
  const a = angle * DEG;
  const vx = v0 * Math.cos(a);
  const vy0 = v0 * Math.sin(a);
  // Time to land: h0 + vy0*t - 0.5*g*t² = 0
  const disc = vy0 * vy0 + 2 * g * h0;
  const tFlight = (vy0 + Math.sqrt(disc)) / g;
  const maxH = h0 + (vy0 * vy0) / (2 * g);
  const range = vx * tFlight;
  return {
    tFlight: +tFlight.toFixed(3),
    maxHeight: +maxH.toFixed(3),
    range: +range.toFixed(3),
    vx: +vx.toFixed(3),
    vy0: +vy0.toFixed(3),
  };
}
export function standardPath(p: StandardParams, steps = 100) {
  const { v0, angle, g, h0 } = p;
  const a = angle * DEG;
  const vx = v0 * Math.cos(a);
  const vy0 = v0 * Math.sin(a);
  const disc = vy0 * vy0 + 2 * g * h0;
  const tFlight = (vy0 + Math.sqrt(Math.max(0, disc))) / g;
  return Array.from({ length: steps + 1 }, (_, i) => {
    const t = (i / steps) * tFlight;
    return { t: +t.toFixed(3), x: +(vx * t).toFixed(3), y: +(h0 + vy0 * t - 0.5 * g * t * t).toFixed(3) };
  }).filter(pt => pt.y >= 0);
}

// ── Horizontal projection (from height, angle = 0) ───────────────────────────
export interface HorizontalParams {
  v0: number;   // m/s (horizontal speed only)
  h: number;    // launch height (m)
  g: number;    // m/s²
}
export function horizontalAnalytics(p: HorizontalParams) {
  const { v0, h, g } = p;
  const tFlight = Math.sqrt(2 * h / g);
  const range = v0 * tFlight;
  const vLand = Math.sqrt(v0 * v0 + (g * tFlight) * (g * tFlight));
  const angleLand = Math.atan((g * tFlight) / v0) / DEG;
  return {
    tFlight: +tFlight.toFixed(3),
    range: +range.toFixed(3),
    vLand: +vLand.toFixed(3),
    angleLand: +angleLand.toFixed(1),
  };
}
export function horizontalPath(p: HorizontalParams, steps = 100) {
  const { v0, h, g } = p;
  const tFlight = Math.sqrt(2 * h / g);
  return Array.from({ length: steps + 1 }, (_, i) => {
    const t = (i / steps) * tFlight;
    return { t: +t.toFixed(3), x: +(v0 * t).toFixed(3), y: +(h - 0.5 * g * t * t).toFixed(3) };
  });
}

// ── Vertical projection (up or free fall) ────────────────────────────────────
export interface VerticalParams {
  v0: number;    // m/s (positive = upward, negative = downward, 0 = free fall)
  h0: number;    // initial height (m)
  g: number;     // m/s²
}
export function verticalAnalytics(p: VerticalParams) {
  const { v0, h0, g } = p;
  const maxH = v0 >= 0 ? h0 + (v0 * v0) / (2 * g) : h0;
  const disc = v0 * v0 + 2 * g * h0;
  const tFlight = v0 >= 0
    ? (v0 + Math.sqrt(Math.max(0, disc))) / g
    : Math.sqrt(2 * h0 / g);
  const vLand = Math.sqrt(Math.max(0, disc));
  return {
    maxHeight: +maxH.toFixed(3),
    tFlight: +tFlight.toFixed(3),
    vLand: +vLand.toFixed(3),
    timeToMax: +(v0 / g).toFixed(3),
  };
}
export function verticalPath(p: VerticalParams, steps = 100) {
  const { v0, h0, g } = p;
  const disc = v0 * v0 + 2 * g * h0;
  const tFlight = v0 >= 0
    ? (v0 + Math.sqrt(Math.max(0, disc))) / g
    : Math.sqrt(2 * h0 / g);
  return Array.from({ length: steps + 1 }, (_, i) => {
    const t = (i / steps) * tFlight;
    const y = h0 + v0 * t - 0.5 * g * t * t;
    return { t: +t.toFixed(3), y: +Math.max(0, y).toFixed(3) };
  });
}

// ── Inclined plane projection ─────────────────────────────────────────────────
export interface InclinedParams {
  v0: number;       // m/s
  alpha: number;    // angle of projection above inclined surface (degrees)
  beta: number;     // angle of incline to horizontal (degrees)
  g: number;        // m/s²
  // 'base': launched from the foot of the incline, up along the slope —
  //         terminates back on the incline surface (n = 0 in the local frame).
  // 'top':  launched from the top of a raised incline/platform, out into
  //         open air beyond it — terminates at ground level, like a
  //         standard projectile launched from height `height`.
  launchFrom: 'base' | 'top';
  height?: number;  // platform height (m) — only used when launchFrom === 'top'
}

export function inclinedAnalytics(p: InclinedParams) {
  const { v0, alpha, beta, g, launchFrom } = p;
  const a = alpha * DEG;
  const b = beta * DEG;

  if (launchFrom === 'top') {
    // Free flight from height h at (alpha+beta)° above horizontal — same
    // shape as standardAnalytics(), just re-expressed via alpha/beta.
    const h = p.height ?? 0;
    const vx0 = v0 * Math.cos(a + b);
    const vy0 = v0 * Math.sin(a + b);
    const disc = vy0 * vy0 + 2 * g * h;
    const tFlight = (vy0 + Math.sqrt(Math.max(0, disc))) / g;
    const maxHeight = h + Math.max(0, (vy0 * vy0) / (2 * g));
    const range = vx0 * tFlight;
    return {
      tFlight: +tFlight.toFixed(3),
      range: +range.toFixed(3),
      rangeHorizontal: +range.toFixed(3),
      maxHeight: +maxHeight.toFixed(3),
      rangeAlongIncline: undefined as number | undefined,
      maxHeightAboveIncline: undefined as number | undefined,
    };
  }

  // Launched from the base, up the slope — lands back on the incline.
  // g along incline (down-slope) = g sinβ, g perpendicular (into surface) = g cosβ
  const gAlong = g * Math.sin(b);
  const gPerp  = g * Math.cos(b);
  const tFlight = (2 * v0 * Math.sin(a)) / gPerp;
  const rangeAlongIncline = v0 * Math.cos(a) * tFlight - 0.5 * gAlong * tFlight * tFlight;
  const maxHeightPerp = (v0 * v0 * Math.sin(a) * Math.sin(a)) / (2 * gPerp);
  return {
    tFlight: +tFlight.toFixed(3),
    range: +(rangeAlongIncline * Math.cos(b)).toFixed(3),
    rangeAlongIncline: +rangeAlongIncline.toFixed(3),
    rangeHorizontal: +(rangeAlongIncline * Math.cos(b)).toFixed(3),
    maxHeight: +maxHeightPerp.toFixed(3),
    maxHeightAboveIncline: +maxHeightPerp.toFixed(3),
  };
}

export function inclinedPath(p: InclinedParams, steps = 100) {
  const { v0, alpha, beta, g, launchFrom } = p;
  const a = alpha * DEG;
  const b = beta * DEG;

  if (launchFrom === 'top') {
    const h = p.height ?? 0;
    const vx0 = v0 * Math.cos(a + b);
    const vy0 = v0 * Math.sin(a + b);
    const disc = vy0 * vy0 + 2 * g * h;
    const tFlight = (vy0 + Math.sqrt(Math.max(0, disc))) / g;
    return Array.from({ length: steps + 1 }, (_, i) => {
      const t = (i / steps) * tFlight;
      return { t: +t.toFixed(3), x: +(vx0 * t).toFixed(3), y: +(h + vy0 * t - 0.5 * g * t * t).toFixed(3) };
    }).filter(pt => pt.y >= 0);
  }

  const gPerp = g * Math.cos(b), gAlong = g * Math.sin(b);
  const tFlight = (2 * v0 * Math.sin(a)) / gPerp;
  // In inclined frame: s (along), n (perp) — this trajectory is only valid
  // for t in [0, tFlight], i.e. up until it returns to the incline surface.
  const cosB = Math.cos(b), sinB = Math.sin(b);
  return Array.from({ length: steps + 1 }, (_, i) => {
    const t = (i / steps) * tFlight;
    const s = v0 * Math.cos(a) * t - 0.5 * gAlong * t * t;
    const n = v0 * Math.sin(a) * t - 0.5 * gPerp * t * t;
    // World coords: start at origin, incline goes up-right
    const x = s * cosB - n * sinB;
    const y = s * sinB + n * cosB;
    return { t: +t.toFixed(3), x: +x.toFixed(3), y: +Math.max(0, y).toFixed(3) };
  });
}
