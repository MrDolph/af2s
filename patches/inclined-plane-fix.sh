#!/bin/bash
# ============================================================
# Fix: inclined-plane projectile terminates correctly
#   - Launched from the base: lands back on the incline surface
#   - Launched from the top: lands on the ground below the platform
# Run inside af2s/ folder: bash inclined-plane-fix.sh
# ============================================================
set -e
echo "🔧 Patching inclined-plane physics + rendering..."

# --- src/lib/physics/projectile-modes.ts ---
cat > src/lib/physics/projectile-modes.ts << 'PATCHEOF'
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
PATCHEOF

# --- src/components/simulation/ProjectileModeCanvas.tsx ---
cat > src/components/simulation/ProjectileModeCanvas.tsx << 'PATCHEOF'
'use client';
import { useEffect, useRef, useState, useCallback, useMemo } from 'react';
import {
  standardPath, horizontalPath, verticalPath, inclinedPath,
  StandardParams, HorizontalParams, VerticalParams, InclinedParams,
} from '@/lib/physics/projectile-modes';

export type ProjectileMode = 'standard' | 'horizontal' | 'vertical' | 'inclined';

interface Props {
  mode: ProjectileMode;
  standard?: StandardParams;
  horizontal?: HorizontalParams;
  vertical?: VerticalParams;
  inclined?: InclinedParams;
  isRunning: boolean;
  isPaused: boolean;
  onComplete?: () => void;
  onTick?: (t: number, x: number, y: number) => void;
  width?: number;
  height?: number;
}

type Pt = { t: number; x: number; y: number };

// ── Speed ─────────────────────────────────────────────────────────────────────
const SPEEDS = [
  { label: '0.25×', dt: 0.004 },
  { label: '0.5×',  dt: 0.008 },
  { label: '1×',    dt: 0.016 },
  { label: '2×',    dt: 0.032 },
  { label: '4×',    dt: 0.064 },
];

const PAD = 44, GH = 44, BR = 8;
const DT_BASE = 0.016;

// ── Physics helpers ───────────────────────────────────────────────────────────
interface Setup {
  x0: number; y0: number; vx0: number; vy0: number; g: number; h0: number;
  beta?: number;                    // incline angle (radians) — inclined mode only
  launchFrom?: 'base' | 'top';      // inclined mode only
}

function getSetup(mode: ProjectileMode, p: Props): Setup {
  if (mode === 'standard' && p.standard) {
    const a = p.standard.angle * Math.PI / 180;
    return {
      x0: 0, y0: p.standard.h0 ?? 0,
      vx0: p.standard.v0 * Math.cos(a),
      vy0: p.standard.v0 * Math.sin(a),
      g: p.standard.g,
      h0: p.standard.h0 ?? 0,
    };
  }
  if (mode === 'horizontal' && p.horizontal) {
    return { x0: 0, y0: p.horizontal.h, vx0: p.horizontal.v0, vy0: 0, g: p.horizontal.g, h0: p.horizontal.h };
  }
  if (mode === 'vertical' && p.vertical) {
    return { x0: 0, y0: p.vertical.h0 ?? 0, vx0: 0, vy0: p.vertical.v0, g: p.vertical.g, h0: p.vertical.h0 ?? 0 };
  }
  if (mode === 'inclined' && p.inclined) {
    const a = p.inclined.alpha * Math.PI / 180;
    const b = p.inclined.beta  * Math.PI / 180;
    const launchFrom = p.inclined.launchFrom ?? 'base';
    const top = launchFrom === 'top';
    const h0 = top ? (p.inclined.height ?? 0) : 0;
    // Whether launched from the base or the top, the object is in free
    // flight under gravity g the whole time — the launch angle above
    // horizontal is simply (alpha + beta). What differs between the two
    // scenarios is only the starting height and where it's allowed to land
    // (handled below via `beta`/`launchFrom` in the termination check).
    return {
      x0: 0, y0: h0,
      vx0: p.inclined.v0 * Math.cos(a + b),
      vy0: p.inclined.v0 * Math.sin(a + b),
      g: p.inclined.g, h0,
      beta: b, launchFrom,
    };
  }
  return { x0: 0, y0: 0, vx0: 10, vy0: 10, g: 9.81, h0: 0 };
}

function buildPath(mode: ProjectileMode, p: Props): Pt[] {
  if (mode === 'standard'   && p.standard)   return standardPath(p.standard)   as Pt[];
  if (mode === 'horizontal' && p.horizontal) return horizontalPath(p.horizontal) as Pt[];
  if (mode === 'vertical'   && p.vertical)   return verticalPath(p.vertical).map(q => ({ t: q.t, x: 0, y: q.y }));
  if (mode === 'inclined'   && p.inclined)   return inclinedPath(p.inclined)   as Pt[];
  return [{ t: 0, x: 0, y: 0 }];
}

function toCanvas(x: number, y: number, scale: number, H: number): [number, number] {
  return [PAD + x * scale, H - GH - y * scale];
}

function getScale(path: Pt[], W: number, H: number) {
  const maxX = Math.max(...path.map(p => p.x), 1);
  const maxY = Math.max(...path.map(p => p.y), 1);
  return {
    scale: Math.min((W - PAD * 2) / (maxX * 1.15), (H - GH - PAD) / (maxY * 1.25)),
    maxX, maxY,
  };
}

// ── Draw ──────────────────────────────────────────────────────────────────────
function drawAll(
  canvas: HTMLCanvasElement,
  path: Pt[], scale: number, maxX: number, maxY: number,
  x: number, y: number, t: number, vx: number, vy: number,
  trail: [number, number][],
  mode: ProjectileMode, h0: number,
  showHUD: boolean, showGrid: boolean, showTrail: boolean, showVec: boolean, showComp: boolean,
  beta?: number, launchFrom?: 'base' | 'top',
) {
  const ctx = canvas.getContext('2d');
  if (!ctx) return;
  const W = canvas.width, H = canvas.height;

  // For an inclined launch from the base, the "ground" the object lands on
  // is the sloped incline surface (y = x·tanβ), not world y = 0. Every other
  // mode — and the inclined-from-top mode — lands on flat ground (y = 0).
  const onIncline = mode === 'inclined' && launchFrom === 'base';
  const floorAt = (xv: number) => (onIncline ? xv * Math.tan(beta ?? 0) : 0);

  ctx.clearRect(0, 0, W, H);

  // Sky
  const sky = ctx.createLinearGradient(0, 0, 0, H - GH);
  sky.addColorStop(0, '#dbeafe'); sky.addColorStop(1, '#f0f6ff');
  ctx.fillStyle = sky; ctx.fillRect(0, 0, W, H - GH);

  // Ground
  ctx.fillStyle = '#e2e8f0'; ctx.fillRect(0, H - GH, W, GH);
  ctx.beginPath(); ctx.moveTo(0, H - GH); ctx.lineTo(W, H - GH);
  ctx.strokeStyle = '#94a3b8'; ctx.lineWidth = 2; ctx.stroke();

  // Platform
  if (h0 > 0) {
    const [, py] = toCanvas(0, h0, scale, H);
    ctx.fillStyle = '#94a3b8'; ctx.fillRect(0, py, PAD + 4, H - GH - py);
    ctx.strokeStyle = '#64748b'; ctx.lineWidth = 1.5; ctx.strokeRect(0, py, PAD + 4, H - GH - py);
    ctx.fillStyle = '#475569'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
    ctx.fillText(`${h0}m`, (PAD + 4) / 2, py - 6);
  }

  // Inclined surface — only for a base launch (the ball lands back on this).
  // A top launch instead shows the "Platform" block above (h0 = height).
  if (onIncline && beta !== undefined) {
    const maxXPt = maxX * 1.25;
    const [x0c, y0c] = toCanvas(0, 0, scale, H);
    const [x1c, y1c] = toCanvas(maxXPt, maxXPt * Math.tan(beta), scale, H);
    ctx.beginPath(); ctx.moveTo(x0c, y0c); ctx.lineTo(x1c, y1c);
    ctx.strokeStyle = '#64748b'; ctx.lineWidth = 3; ctx.stroke();
  }

  // Grid
  if (showGrid) {
    ctx.save();
    ctx.strokeStyle = '#e2e8f0'; ctx.lineWidth = 1;
    ctx.fillStyle = '#94a3b8'; ctx.font = '10px system-ui';
    const xStep = Math.ceil(maxX / 5 / 5) * 5 || 1;
    ctx.textAlign = 'center';
    for (let gx = 0; gx <= maxX * 1.15; gx += xStep) {
      const [cx2] = toCanvas(gx, 0, scale, H);
      ctx.beginPath(); ctx.setLineDash([3, 4]); ctx.moveTo(cx2, PAD); ctx.lineTo(cx2, H - GH); ctx.stroke();
      ctx.setLineDash([]);
      if (mode !== 'vertical') ctx.fillText(`${gx}m`, cx2, H - GH + 14);
    }
    ctx.textAlign = 'right';
    const yStep = Math.ceil(maxY / 4 / 5) * 5 || 1;
    for (let gy = 0; gy <= maxY * 1.25; gy += yStep) {
      const [, cy2] = toCanvas(0, gy, scale, H);
      if (cy2 < PAD) continue;
      ctx.beginPath(); ctx.setLineDash([3, 4]); ctx.moveTo(PAD, cy2); ctx.lineTo(W - PAD, cy2); ctx.stroke();
      ctx.setLineDash([]); ctx.fillText(`${gy}m`, PAD - 3, cy2 + 4);
    }
    ctx.restore();
  }

  // Ghost path
  if (path.length > 1) {
    ctx.save(); ctx.beginPath();
    const [gx0, gy0] = toCanvas(path[0].x, path[0].y, scale, H);
    ctx.moveTo(gx0, gy0);
    path.slice(1).forEach(p => { const [cx2, cy2] = toCanvas(p.x, p.y, scale, H); ctx.lineTo(cx2, cy2); });
    ctx.strokeStyle = 'rgba(99,102,241,0.18)'; ctx.lineWidth = 2;
    ctx.setLineDash([6, 4]); ctx.stroke(); ctx.setLineDash([]); ctx.restore();
  }

  // Peak + landing markers
  const [pCx, pCy] = toCanvas(maxX / 2, maxY, scale, H);
  const [, pFloorY] = toCanvas(maxX / 2, floorAt(maxX / 2), scale, H);
  ctx.save();
  ctx.beginPath(); ctx.setLineDash([4, 3]);
  ctx.moveTo(pCx, pCy); ctx.lineTo(pCx, pFloorY);
  ctx.strokeStyle = 'rgba(99,102,241,0.4)'; ctx.lineWidth = 1.5; ctx.stroke(); ctx.setLineDash([]);
  ctx.fillStyle = '#6366f1'; ctx.font = 'bold 11px system-ui'; ctx.textAlign = 'center';
  ctx.fillText(`${maxY.toFixed(1)}m`, pCx, pCy - 8); ctx.restore();

  const [lCx, lCy] = toCanvas(maxX, floorAt(maxX), scale, H);
  ctx.save();
  ctx.beginPath(); ctx.arc(lCx, lCy, 5, 0, Math.PI * 2);
  ctx.fillStyle = '#10b981'; ctx.fill();
  ctx.fillStyle = '#10b981'; ctx.font = 'bold 11px system-ui'; ctx.textAlign = 'center';
  ctx.fillText(`${maxX.toFixed(1)}m`, lCx, lCy + (onIncline ? -10 : 32)); ctx.restore();

  // Trail
  if (showTrail && trail.length > 1) {
    ctx.save();
    for (let i = 1; i < trail.length; i++) {
      const alpha = i / trail.length;
      ctx.beginPath(); ctx.moveTo(trail[i-1][0], trail[i-1][1]); ctx.lineTo(trail[i][0], trail[i][1]);
      ctx.strokeStyle = `rgba(99,102,241,${alpha * 0.8})`; ctx.lineWidth = 2.5; ctx.stroke();
    }
    ctx.restore();
  }

  // Ball
  const [bx, by] = toCanvas(x, Math.max(floorAt(x), y), scale, H);
  const [, groundY] = toCanvas(x, floorAt(x), scale, H);
  ctx.beginPath(); ctx.ellipse(bx, groundY + 5, 10, 4, 0, 0, Math.PI * 2);
  ctx.fillStyle = 'rgba(0,0,0,0.1)'; ctx.fill();
  const glow = ctx.createRadialGradient(bx, by, 0, bx, by, BR * 2.5);
  glow.addColorStop(0, 'rgba(79,70,229,0.3)'); glow.addColorStop(1, 'transparent');
  ctx.beginPath(); ctx.arc(bx, by, BR * 2.5, 0, Math.PI * 2); ctx.fillStyle = glow; ctx.fill();
  const ballG = ctx.createRadialGradient(bx - 2, by - 2, 1, bx, by, BR);
  ballG.addColorStop(0, '#818cf8'); ballG.addColorStop(1, '#4f46e5');
  ctx.beginPath(); ctx.arc(bx, by, BR, 0, Math.PI * 2); ctx.fillStyle = ballG; ctx.fill();

  // Velocity vector — resultant plus horizontal/vertical components
  const speed = Math.sqrt(vx * vx + vy * vy);
  if ((showVec || showComp) && speed > 0.3 && t > 0) {
    // Same px-per-(m/s) factor for the resultant and its components, so the
    // triangle they form is geometrically consistent even when the resultant
    // arrow length is capped.
    const k = Math.min(scale * 0.28, 65 / speed);
    const exR = bx + vx * k, eyR = by - vy * k; // resultant tip (canvas space)

    const drawArrowhead = (fromX: number, fromY: number, toX: number, toY: number, color: string, width: number) => {
      const ang = Math.atan2(toY - fromY, toX - fromX);
      ctx.save();
      ctx.beginPath(); ctx.moveTo(fromX, fromY); ctx.lineTo(toX, toY);
      ctx.strokeStyle = color; ctx.lineWidth = width; ctx.stroke();
      const hL = 8, hA = 0.4;
      ctx.beginPath(); ctx.moveTo(toX, toY);
      ctx.lineTo(toX - hL * Math.cos(ang - hA), toY - hL * Math.sin(ang - hA));
      ctx.lineTo(toX - hL * Math.cos(ang + hA), toY - hL * Math.sin(ang + hA));
      ctx.closePath(); ctx.fillStyle = color; ctx.fill();
      ctx.restore();
    };

    if (showComp) {
      const exH = bx + vx * k, eyH = by;       // horizontal component tip
      const exV = bx,          eyV = by - vy * k; // vertical component tip

      // Dashed guide lines completing the triangle
      ctx.save();
      ctx.strokeStyle = 'rgba(100,116,139,0.5)'; ctx.lineWidth = 1; ctx.setLineDash([3, 3]);
      ctx.beginPath(); ctx.moveTo(exH, eyH); ctx.lineTo(exR, eyR); ctx.stroke();
      ctx.beginPath(); ctx.moveTo(exV, eyV); ctx.lineTo(exR, eyR); ctx.stroke();
      ctx.setLineDash([]); ctx.restore();

      if (Math.abs(vx * k) > 4) {
        drawArrowhead(bx, by, exH, eyH, '#10b981', 2);
        ctx.save();
        ctx.fillStyle = '#059669'; ctx.font = 'bold 10px system-ui';
        ctx.textAlign = vx >= 0 ? 'left' : 'right';
        ctx.fillText(`vx=${vx.toFixed(1)}`, exH + (vx >= 0 ? 4 : -4), eyH + (eyH > by ? 12 : -6));
        ctx.restore();
      }
      if (Math.abs(vy * k) > 4) {
        drawArrowhead(bx, by, exV, eyV, '#3b82f6', 2);
        ctx.save();
        ctx.fillStyle = '#2563eb'; ctx.font = 'bold 10px system-ui';
        ctx.textAlign = 'left';
        ctx.fillText(`vy=${vy.toFixed(1)}`, exV + 4, eyV - (vy >= 0 ? 4 : -10));
        ctx.restore();
      }
    }

    if (showVec) drawArrowhead(bx, by, exR, eyR, '#f59e0b', 2.5);
  }

  // HUD
  if (showHUD && t > 0) {
    const lines = [
      `t  = ${t.toFixed(2)}s`,
      ...(mode !== 'vertical' ? [`x  = ${x.toFixed(1)}m`] : []),
      `y  = ${Math.max(floorAt(x), y).toFixed(1)}m`,
      `v  = ${speed.toFixed(1)} m/s`,
    ];
    const bw = 118, bh = lines.length * 18 + 14, bhx = W - bw - 8;
    ctx.save();
    ctx.fillStyle = 'rgba(255,255,255,0.92)';
    ctx.beginPath(); ctx.roundRect(bhx, 8, bw, bh, 8); ctx.fill();
    ctx.strokeStyle = 'rgba(99,102,241,0.2)'; ctx.lineWidth = 1; ctx.stroke();
    ctx.fillStyle = '#1e293b'; ctx.font = '11px monospace'; ctx.textAlign = 'left';
    lines.forEach((l, i) => ctx.fillText(l, bhx + 8, 24 + i * 18));
    ctx.restore();
  }
}

// ── Component — mirrors homepage ProjectileCanvas exactly ─────────────────────
export function ProjectileModeCanvas({
  mode, standard, horizontal, vertical, inclined,
  isRunning, isPaused, onComplete, onTick,
  width = 680, height = 300,
}: Props) {
  const canvasRef    = useRef<HTMLCanvasElement | null>(null);
  const rafRef       = useRef<number>(0);
  const stateRef     = useRef({ x: 0, y: 0, vx: 0, vy: 0, t: 0, g: 9.81 });
  const trailRef     = useRef<[number, number][]>([]);
  const completedRef = useRef(false);

  const [speedIdx,  setSpeedIdx]  = useState(2);
  const [showGrid,  setShowGrid]  = useState(true);
  const [showTrail, setShowTrail] = useState(true);
  const [showVec,   setShowVec]   = useState(true);
  const [showComp,  setShowComp]  = useState(true);
  const [showOvl,   setShowOvl]   = useState(false);

  // setup/path/scale are memoized on the actual physics inputs only (not on
  // isRunning/isPaused, and not on a freshly-built `props` object literal).
  // Recomputing these on every render — including the per-frame re-renders
  // that come from the parent's onTick(t, x, y) -> setState — was giving
  // `draw` a new identity every animation frame, which re-triggered the
  // "reset when params change" effect below and snapped the ball back to
  // its starting position every frame (the "vibrating ball" bug).
  const setup = useMemo(
    () => getSetup(mode, { mode, standard, horizontal, vertical, inclined, isRunning: false, isPaused: false }),
    [mode, standard, horizontal, vertical, inclined]
  );
  const path = useMemo(
    () => buildPath(mode, { mode, standard, horizontal, vertical, inclined, isRunning: false, isPaused: false }),
    [mode, standard, horizontal, vertical, inclined]
  );
  const { scale, maxX, maxY } = useMemo(() => getScale(path, width, height), [path, width, height]);

  // draw — same pattern as homepage: useCallback with deps
  const draw = useCallback((st: typeof stateRef.current) => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    drawAll(
      canvas, path, scale, maxX, maxY,
      st.x, st.y, st.t, st.vx, st.vy,
      trailRef.current, mode, setup.h0,
      isRunning || st.t > 0,
      showGrid, showTrail, showVec, showComp,
      setup.beta, setup.launchFrom,
    );
  }, [path, scale, maxX, maxY, mode, setup.h0, setup.beta, setup.launchFrom, isRunning, showGrid, showTrail, showVec, showComp]);

  // Keep a ref to the latest `draw` so the reset effect below doesn't need
  // `draw` itself in its dependency array. `draw`'s identity changes with
  // isRunning (used for the HUD condition) and the overlay toggles — if the
  // reset effect depended on `draw` directly, then simply finishing the run
  // (isRunning: true -> false) or toggling an overlay mid-flight would count
  // as a "params changed" event and snap the ball back to the launch point.
  const drawRef = useRef(draw);
  useEffect(() => { drawRef.current = draw; }, [draw]);

  // Reset when the actual physics params change (mode/velocity/angle/gravity/etc)
  useEffect(() => {
    cancelAnimationFrame(rafRef.current);
    stateRef.current = { x: setup.x0, y: setup.y0, vx: setup.vx0, vy: setup.vy0, t: 0, g: setup.g };
    trailRef.current = [];
    completedRef.current = false;
    drawRef.current(stateRef.current);
  }, [setup.x0, setup.y0, setup.vx0, setup.vy0, setup.g]);

  // Animation loop — isRunning in deps, same as homepage
  useEffect(() => {
    if (!isRunning || isPaused || completedRef.current) return;
    const dt = SPEEDS[speedIdx].dt;
    let lastTime: number | null = null;
    const loop = (timestamp: number) => {
      if (lastTime === null) lastTime = timestamp;
      const elapsed = (timestamp - lastTime) / 1000;
      lastTime = timestamp;
      const steps = Math.max(1, Math.round(elapsed / DT_BASE));
      for (let i = 0; i < steps; i++) {
        const s = stateRef.current;
        stateRef.current = {
          x:  s.x  + s.vx * dt,
          y:  s.y  + s.vy * dt - 0.5 * s.g * dt * dt,
          vx: s.vx,
          vy: s.vy - s.g * dt,
          t:  s.t  + dt,
          g:  s.g,
        };
        const ns = stateRef.current;
        // A base-launched inclined trajectory lands back on the sloped
        // surface (y = x·tanβ), not on flat ground (y = 0) — everything
        // else (including an inclined launch from the top) lands at y = 0.
        const onIncline = mode === 'inclined' && setup.launchFrom === 'base';
        const floor = onIncline ? ns.x * Math.tan(setup.beta ?? 0) : 0;
        const [tbx, tby] = toCanvas(ns.x, Math.max(floor, ns.y), scale, height);
        trailRef.current.push([tbx, tby]);
        if (trailRef.current.length > 140) trailRef.current.shift();
        onTick?.(ns.t, ns.x, Math.max(floor, ns.y));
        if (ns.y <= floor || ns.t > 120) {
          completedRef.current = true;
          onComplete?.();
          draw(stateRef.current);
          return;
        }
      }
      draw(stateRef.current);
      rafRef.current = requestAnimationFrame(loop);
    };
    rafRef.current = requestAnimationFrame(loop);
    return () => cancelAnimationFrame(rafRef.current);
  }, [isRunning, isPaused, speedIdx, scale, height, mode, setup.beta, setup.launchFrom, draw, onTick, onComplete]);

  return (
    <div className="space-y-2">
      <div className="flex items-center gap-2 flex-wrap">
        <button onClick={() => setShowOvl(v => !v)}
          className={`flex items-center gap-1.5 rounded-lg border px-3 py-1.5 text-xs font-medium transition ${
            showOvl ? 'border-indigo-300 bg-indigo-50 text-indigo-700' : 'border-gray-200 bg-white text-gray-600'
          }`}>
          <svg width="12" height="12" viewBox="0 0 12 12" fill="none" stroke="currentColor" strokeWidth="1.5">
            <circle cx="6" cy="6" r="2"/><path d="M6 1v1M6 10v1M1 6h1M10 6h1"/>
          </svg>
          Overlays
        </button>
        {showOvl && (
          [['Grid', showGrid, setShowGrid], ['Trail', showTrail, setShowTrail], ['Velocity', showVec, setShowVec], ['Components', showComp, setShowComp]] as [string, boolean, (v:boolean)=>void][]
        ).map(([label, on, setter]) => (
          <button key={label} onClick={() => setter(!on)}
            className={`rounded-full px-3 py-1 text-xs font-medium border transition ${
              on ? 'bg-indigo-600 text-white border-indigo-600' : 'bg-white text-gray-400 border-gray-200'
            }`}>{label}</button>
        ))}
        <div className="flex items-center gap-1 rounded-lg border border-gray-200 bg-white px-2 py-1 ml-auto">
          <span className="text-[10px] text-gray-400 mr-1">Speed</span>
          {SPEEDS.map((s, i) => (
            <button key={s.label} onClick={() => setSpeedIdx(i)}
              className={`rounded px-2 py-0.5 text-[11px] font-medium transition ${
                speedIdx === i ? 'bg-indigo-600 text-white' : 'text-gray-500 hover:bg-gray-100'
              }`}>{s.label}</button>
          ))}
        </div>
      </div>
      <div className="relative w-full overflow-hidden rounded-xl border border-gray-200 bg-white shadow-sm">
        <canvas ref={canvasRef} width={width} height={height}
          className="w-full" style={{ display: 'block' }} />
      </div>
    </div>
  );
}
PATCHEOF

# --- src/app/simulations/projectile-motion/page.tsx ---
cat > src/app/simulations/projectile-motion/page.tsx << 'PATCHEOF'
'use client';
import { useState, useCallback, useEffect, useRef, useMemo } from 'react';
import { AppHeader } from '@/components/layout/AppHeader';
import { PromptBar } from '@/components/ai/PromptBar';
import { ProjectileModeCanvas, ProjectileMode } from '@/components/simulation/ProjectileModeCanvas';
import { SimulationControls } from '@/components/simulation/SimulationControls';
import type { AIPromptResponse } from '@/types/ai';
import {
  standardAnalytics, horizontalAnalytics, verticalAnalytics, inclinedAnalytics,
  StandardParams, HorizontalParams, VerticalParams, InclinedParams,
} from '@/lib/physics/projectile-modes';

const CURRICULA = ['WAEC', 'NECO', 'IGCSE', 'SAT', 'JUPEB'];
const CC: Record<string, string> = {
  WAEC: 'bg-indigo-100 text-indigo-700', NECO: 'bg-pink-100 text-pink-700',
  IGCSE: 'bg-emerald-100 text-emerald-700', SAT: 'bg-orange-100 text-orange-700',
  JUPEB: 'bg-purple-100 text-purple-700',
};

const MODE_META: Record<ProjectileMode, { title: string; icon: string; sub: string; eqs: string[] }> = {
  standard:   { title: 'Standard', icon: '🎯', sub: 'Angle θ, optional height h', eqs: ['R = vₓ × T', 'H = h + vy₀²/2g'] },
  horizontal: { title: 'Horizontal', icon: '🏗️', sub: 'Launched horizontally from height', eqs: ['t = √(2h/g)', 'R = v₀t'] },
  vertical:   { title: 'Vertical', icon: '⬆️', sub: 'Thrown up/down or dropped', eqs: ['H_max = h₀ + v₀²/2g', 't = v₀/g'] },
  inclined:   { title: 'Inclined', icon: '📐', sub: 'Launched along a slope β', eqs: ['t = 2v₀sinα/gcosβ'] },
};

const TEACHER_NOTES: Record<ProjectileMode, string[]> = {
  standard: [
    'vx is constant throughout — no horizontal force acts on the projectile.',
    'When h₀ > 0, the optimal angle for max range drops below 45°.',
    'Complementary angles give equal range only when launched from ground level.',
    'Platform height slider — drag it up to simulate a cliff or tall building.',
    'Use the gravity slider to explore projectile behaviour on the Moon (1.6 m/s²) or Mars (3.7 m/s²).',
  ],
  horizontal: [
    'Horizontal projection: initial vertical velocity is ZERO. Only horizontal speed is given at launch.',
    'Time of flight depends only on height — t = √(2h/g). Horizontal speed does not affect fall time.',
    'The landing velocity always has a downward component: v_land = √(v₀² + (gt)²).',
    'Classic exam scenario: stone thrown from a cliff, ball rolling off a table, bomb from a horizontal aircraft.',
    'The path curves — it starts horizontal and steepens continuously until landing.',
  ],
  vertical: [
    'Pure vertical motion — no horizontal displacement at all.',
    'At maximum height, vy = 0. Time to reach max = v₀/g.',
    'Symmetry: time rising = time falling (when returning to same height).',
    'Set v₀ = 0 and h₀ > 0 for free fall. Set v₀ negative for a downward throw.',
    'Landing speed: v = √(v₀² + 2gh₀) — same regardless of direction of initial throw from same height.',
  ],
  inclined: [
    'Key insight: resolve gravity into components along the slope (g sinβ) and perpendicular (g cosβ).',
    'The effective gravity perpendicular to slope is g cosβ — less than g, so flight time is longer than on flat ground.',
    'Optimal launch angle for max range along slope = 45° − β/2, not 45°.',
    'Range along slope ≠ horizontal range — understand which the exam question is asking for.',
    'This is one of the hardest WAEC/IGCSE topics: always set up axes along and perpendicular to the slope.',
  ],
};

const EXERCISES: Record<ProjectileMode, { q: string; a: string }[]> = {
  standard: [
    { q: 'A ball is thrown at 25 m/s at 37° from a 20m building. Find the range. (g = 10 m/s², sin37°=0.6, cos37°=0.8)', a: 'vx=20, vy₀=15. Solve 20+15t−5t²=0 → t≈3+, R=20×3.56=71.2m' },
    { q: 'Complementary angles 30° and 60° give the same range. Does this still hold when launched from a height?', a: 'No — when h₀ > 0 the symmetry breaks. The ball launched at the shallower angle has more horizontal time and travels farther.' },
    { q: 'Find the angle for max range when v₀=20 m/s from a 15m platform. (g=10 m/s²)', a: 'The optimal angle is less than 45° and requires calculus or numerical methods. Try angles around 38°–42° in the simulator.' },
  ],
  horizontal: [
    { q: 'A stone is thrown horizontally at 12 m/s from a 45m cliff. Find range and landing speed. (g=10 m/s²)', a: 't=√(2×45/10)=3s. R=12×3=36m. vy=gt=30m/s. v=√(144+900)=√1044≈32.3m/s' },
    { q: 'A ball rolls off a 1.25m table and lands 2m away. Find its speed at the table edge. (g=10 m/s²)', a: 't=√(2×1.25/10)=0.5s. v₀=R/t=2/0.5=4m/s' },
    { q: 'Why does doubling the horizontal speed double the range but not the time of flight?', a: 'Time depends only on height (t=√(2h/g)) which is unchanged. With double speed, the ball covers twice the horizontal distance in the same time.' },
  ],
  vertical: [
    { q: 'A ball is thrown upward at 30 m/s from the ground. Find max height and total flight time. (g=10 m/s²)', a: 'H=v²/2g=900/20=45m. t_up=30/10=3s. Total=6s.' },
    { q: 'A ball is dropped from 80m. Find speed at impact. (g=10 m/s²)', a: 'v=√(2gh)=√(2×10×80)=√1600=40 m/s' },
    { q: 'A ball thrown upward at 20 m/s from a 30m tower. Find max height above ground. (g=10 m/s²)', a: 'H_above_launch=v²/2g=400/20=20m. Max above ground=30+20=50m.' },
  ],
  inclined: [
    { q: 'v₀=20 m/s, α=30° above slope, β=30° slope. Find time of flight. (g=10 m/s²)', a: 't=2v₀sinα/(gcosβ)=2×20×0.5/(10×0.866)=20/8.66≈2.31s' },
    { q: 'At what α is range along slope maximised when β=30°?', a: 'Optimal α = 45° − β/2 = 45° − 15° = 30° above the slope surface.' },
    { q: 'Why is range along slope different from horizontal range?', a: 'The landing point is on the slope, higher than the foot of the incline. Slope range = distance along the surface; horizontal range = horizontal distance only.' },
  ],
};

function Slider({ label, unit, value, min, max, step, set, color, note }: {
  label: string; unit: string; value: number; min: number; max: number;
  step: number; set: (v: number) => void; color: string; note?: string;
}) {
  return (
    <div className="space-y-1.5">
      <div className="flex justify-between text-xs">
        <span className="text-gray-500">{label}</span>
        <span className="font-medium tabular-nums text-gray-800">{value} <span className="text-gray-400 font-normal">{unit}</span></span>
      </div>
      <input type="range" min={min} max={max} step={step} value={value}
        onChange={e => set(Number(e.target.value))}
        className="w-full" style={{ accentColor: color }} />
      {note && <p className="text-[10px] text-gray-400">{note}</p>}
    </div>
  );
}

function StatRow({ label, value, unit, color }: { label: string; value: number | string; unit: string; color: string }) {
  return (
    <div className="flex justify-between items-center rounded-lg bg-gray-50 px-3 py-2">
      <span className="text-xs text-gray-500">{label}</span>
      <span className={`text-sm font-semibold tabular-nums ${color}`}>
        {typeof value === 'number' ? value.toFixed(2) : value}
        <span className="text-xs font-normal text-gray-400 ml-1">{unit}</span>
      </span>
    </div>
  );
}

export default function ProjectileMotionPage() {
  const [mode, setMode] = useState<ProjectileMode>('standard');
  const [isRunning, setIsRunning] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const [isComplete, setIsComplete] = useState(false);
  const [resetKey, setResetKey] = useState(0);
  const [openEx, setOpenEx] = useState<number | null>(null);
  const [activeCurricula, setActiveCurricula] = useState(['WAEC', 'IGCSE', 'SAT']);
  const [livePos, setLivePos] = useState({ t: 0, x: 0, y: 0 });

  // Params
  const [v0, setV0] = useState(25); const [angle, setAngle] = useState(45);
  const [g, setG] = useState(9.81); const [h0, setH0] = useState(0);
  const [hV0, setHV0] = useState(20); const [hH, setHH] = useState(30);
  const [vV0, setVV0] = useState(15); const [vH0, setVH0] = useState(0);
  const [iV0, setIV0] = useState(20); const [iAlpha, setIAlpha] = useState(30); const [iBeta, setIBeta] = useState(30);
  const [iLaunchFrom, setILaunchFrom] = useState<'base' | 'top'>('base');
  const [iHeight, setIHeight] = useState(20);

  // Memoized so these keep a stable object identity across renders that don't
  // actually change their values (e.g. the per-frame re-render from handleTick
  // updating livePos). Without this, ProjectileModeCanvas sees a "new" params
  // object on every animation frame and resets itself mid-flight.
  const std: StandardParams   = useMemo(() => ({ v0, angle, g, h0 }), [v0, angle, g, h0]);
  const hrz: HorizontalParams = useMemo(() => ({ v0: hV0, h: hH, g }), [hV0, hH, g]);
  const vtc: VerticalParams   = useMemo(() => ({ v0: vV0, h0: vH0, g }), [vV0, vH0, g]);
  const inc: InclinedParams   = useMemo(
    () => ({ v0: iV0, alpha: iAlpha, beta: iBeta, g, launchFrom: iLaunchFrom, height: iHeight }),
    [iV0, iAlpha, iBeta, g, iLaunchFrom, iHeight]
  );

  const stdA = standardAnalytics(std);
  const hrzA = horizontalAnalytics(hrz);
  const vtcA = verticalAnalytics(vtc);
  const incA = inclinedAnalytics(inc);

  // Debounced reset on param change
  const resetTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const reset = useCallback(() => {
    setIsRunning(false); setIsPaused(false);
    setIsComplete(false); setResetKey(k => k + 1);
    setLivePos({ t: 0, x: 0, y: 0 });
  }, []);

  useEffect(() => {
    if (resetTimer.current) clearTimeout(resetTimer.current);
    resetTimer.current = setTimeout(reset, 80);
  }, [mode, v0, angle, g, h0, hV0, hH, vV0, vH0, iV0, iAlpha, iBeta, iLaunchFrom, iHeight, reset]);

  const handleTick = useCallback((t: number, x: number, y: number) => setLivePos({ t, x, y }), []);
  const handleComplete = useCallback(() => { setIsComplete(true); setIsRunning(false); }, []);
  const handleAIResult = useCallback((r: AIPromptResponse) => {
    if (r.simulationType === 'projectile_motion') {
      const p = r.params as Record<string, number>;
      if (p.initialVelocity) setV0(p.initialVelocity);
      if (p.angle) setAngle(p.angle);
      if (p.gravity) setG(p.gravity);
      if (p.h0) setH0(p.h0);
      setMode('standard');
    }
    setTimeout(reset, 100);
  }, [reset]);

  return (
    <>
      <AppHeader />
      <main className="min-h-screen bg-gray-50">

        {/* Page header */}
        <section className="border-b border-gray-200 bg-white">
          <div className="mx-auto max-w-7xl px-4 sm:px-6 py-4">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
              <div>
                <p className="text-xs text-gray-400 mb-0.5">Mechanics</p>
                <h1 className="text-lg font-semibold text-gray-900">Projectile motion</h1>
              </div>
              <div className="flex gap-1.5 flex-wrap">
                {CURRICULA.map(c => (
                  <button key={c}
                    onClick={() => setActiveCurricula(p => p.includes(c) ? p.filter(x => x !== c) : [...p, c])}
                    className={`text-xs px-2.5 py-1 rounded-full border font-medium transition ${
                      activeCurricula.includes(c) ? CC[c] + ' border-transparent' : 'bg-white text-gray-400 border-gray-200'
                    }`}>{c}</button>
                ))}
              </div>
            </div>
          </div>
        </section>

        <div className="mx-auto max-w-7xl px-4 sm:px-6 py-4 space-y-4">

          {/* AI prompt */}
          <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
            <p className="text-xs font-medium text-gray-400 uppercase tracking-wide mb-3">AI prompt</p>
            <PromptBar onResult={handleAIResult} />
          </div>

          {/* Mode tabs */}
          <div className="flex gap-1 bg-gray-100 p-1 rounded-xl overflow-x-auto">
            {(Object.keys(MODE_META) as ProjectileMode[]).map(m => (
              <button key={m} onClick={() => setMode(m)}
                className={`shrink-0 flex items-center gap-1.5 px-3 py-2 rounded-lg text-xs font-medium transition ${
                  mode === m ? 'bg-white text-indigo-700 shadow-sm' : 'text-gray-500 hover:text-gray-700'
                }`}>
                <span>{MODE_META[m].icon}</span>
                <span>{MODE_META[m].title}</span>
              </button>
            ))}
          </div>

          {/* Sub + equations */}
          <div className="flex flex-wrap items-center gap-2">
            <span className="text-xs text-gray-500">{MODE_META[mode].sub}</span>
            {MODE_META[mode].eqs.map(eq => (
              <span key={eq} className="rounded-lg border border-gray-200 bg-white px-2.5 py-1 text-xs font-mono text-gray-700">{eq}</span>
            ))}
          </div>

          {/* ── MOBILE: stack everything; DESKTOP: 3-col ── */}
          <div className="grid grid-cols-1 lg:grid-cols-[1fr_220px] xl:grid-cols-[1fr_220px_260px] gap-4">

            {/* Col 1: canvas + controls + sliders */}
            <div className="space-y-3 min-w-0">
              <div className="rounded-2xl border border-gray-200 bg-white p-3 shadow-sm">
                <ProjectileModeCanvas
                  key={resetKey}
                  mode={mode}
                  standard={std} horizontal={hrz} vertical={vtc} inclined={inc}
                  isRunning={isRunning} isPaused={isPaused}
                  onTick={handleTick} onComplete={handleComplete}
                  width={660} height={290}
                />
              </div>

              <div className="flex flex-wrap items-center justify-between gap-2">
                <SimulationControls
                  isRunning={isRunning && !isComplete} isPaused={isPaused}
                  onRun={() => { setIsRunning(true); setIsPaused(false); setIsComplete(false); }}
                  onPause={() => setIsPaused(p => !p)}
                  onReset={reset}
                />
                {isComplete && <span className="text-xs font-medium text-emerald-600">✓ Complete — Reset to go again</span>}
              </div>

              {/* Sliders */}
              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm space-y-4">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide">Parameters</p>
                <Slider label="Gravity" unit="m/s²" value={g} min={1} max={25} step={0.1} set={setG} color="#10b981" />

                {mode === 'standard' && <>
                  <Slider label="Initial velocity" unit="m/s" value={v0} min={1} max={100} step={1} set={setV0} color="#6366f1" />
                  <Slider label="Launch angle" unit="°" value={angle} min={1} max={89} step={1} set={setAngle} color="#f59e0b" />
                  <Slider label="Platform height" unit="m" value={h0} min={0} max={120} step={1} set={setH0} color="#8b5cf6" note="0 = ground level" />
                </>}

                {mode === 'horizontal' && <>
                  <Slider label="Horizontal speed" unit="m/s" value={hV0} min={1} max={100} step={1} set={setHV0} color="#6366f1" />
                  <Slider label="Launch height" unit="m" value={hH} min={1} max={200} step={1} set={setHH} color="#8b5cf6" />
                </>}

                {mode === 'vertical' && <>
                  <Slider label="Initial velocity (↑ positive)" unit="m/s" value={vV0} min={-30} max={50} step={1} set={setVV0} color="#6366f1" note="Negative = thrown downward" />
                  <Slider label="Initial height" unit="m" value={vH0} min={0} max={200} step={1} set={setVH0} color="#8b5cf6" />
                </>}

                {mode === 'inclined' && <>
                  <div className="space-y-1.5">
                    <span className="text-xs text-gray-500">Launched from</span>
                    <div className="flex gap-2">
                      {(['base', 'top'] as const).map(v => (
                        <button key={v} onClick={() => setILaunchFrom(v)}
                          className={`flex-1 rounded-lg border px-2 py-1.5 text-xs font-medium transition ${
                            iLaunchFrom === v ? 'border-indigo-300 bg-indigo-50 text-indigo-700' : 'border-gray-200 bg-white text-gray-500'
                          }`}>
                          {v === 'base' ? 'Base — up the slope' : 'Top — out over the edge'}
                        </button>
                      ))}
                    </div>
                    <p className="text-[10px] text-gray-400">
                      {iLaunchFrom === 'base'
                        ? 'Lands back on the incline surface.'
                        : 'Launched off a raised platform — lands on the ground below.'}
                    </p>
                  </div>
                  <Slider label="Initial velocity" unit="m/s" value={iV0} min={1} max={60} step={1} set={setIV0} color="#6366f1" />
                  <Slider label="α — angle above slope" unit="°" value={iAlpha} min={1} max={89} step={1} set={setIAlpha} color="#f59e0b" />
                  <Slider label="β — slope angle" unit="°" value={iBeta} min={5} max={60} step={1} set={setIBeta} color="#ef4444" />
                  {iLaunchFrom === 'top' && (
                    <Slider label="Platform height" unit="m" value={iHeight} min={1} max={100} step={1} set={setIHeight} color="#8b5cf6" />
                  )}
                </>}
              </div>
            </div>

            {/* Col 2: analytics */}
            <div className="space-y-3">
              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide mb-3">Calculated</p>
                <div className="space-y-2">
                  {mode === 'standard' && <>
                    <StatRow label="Time of flight" value={stdA.tFlight} unit="s" color="text-indigo-600" />
                    <StatRow label="Max range" value={stdA.range} unit="m" color="text-emerald-600" />
                    <StatRow label="Max height" value={stdA.maxHeight} unit="m" color="text-amber-600" />
                    <StatRow label="vx" value={stdA.vx} unit="m/s" color="text-gray-600" />
                    <StatRow label="vy₀" value={stdA.vy0} unit="m/s" color="text-rose-500" />
                  </>}
                  {mode === 'horizontal' && <>
                    <StatRow label="Time of flight" value={hrzA.tFlight} unit="s" color="text-indigo-600" />
                    <StatRow label="Range" value={hrzA.range} unit="m" color="text-emerald-600" />
                    <StatRow label="Landing speed" value={hrzA.vLand} unit="m/s" color="text-amber-600" />
                    <StatRow label="Landing angle" value={hrzA.angleLand} unit="°↓" color="text-rose-500" />
                  </>}
                  {mode === 'vertical' && <>
                    <StatRow label="Max height" value={vtcA.maxHeight} unit="m" color="text-indigo-600" />
                    <StatRow label="Time to peak" value={vtcA.timeToMax} unit="s" color="text-amber-600" />
                    <StatRow label="Flight time" value={vtcA.tFlight} unit="s" color="text-emerald-600" />
                    <StatRow label="Landing speed" value={vtcA.vLand} unit="m/s" color="text-rose-500" />
                  </>}
                  {mode === 'inclined' && (iLaunchFrom === 'base' ? <>
                    <StatRow label="Flight time" value={incA.tFlight} unit="s" color="text-indigo-600" />
                    <StatRow label="Range along slope" value={incA.rangeAlongIncline ?? 0} unit="m" color="text-emerald-600" />
                    <StatRow label="Horizontal range" value={incA.rangeHorizontal} unit="m" color="text-amber-600" />
                    <StatRow label="Height above slope" value={incA.maxHeightAboveIncline ?? 0} unit="m" color="text-rose-500" />
                  </> : <>
                    <StatRow label="Flight time" value={incA.tFlight} unit="s" color="text-indigo-600" />
                    <StatRow label="Range" value={incA.range} unit="m" color="text-emerald-600" />
                    <StatRow label="Max height" value={incA.maxHeight} unit="m" color="text-amber-600" />
                  </>)}
                </div>
              </div>

              {livePos.t > 0 && (
                <div className="rounded-2xl border border-indigo-100 bg-indigo-50 p-4">
                  <p className="text-xs font-medium text-indigo-400 uppercase tracking-wide mb-2">Live</p>
                  <div className="space-y-1.5">
                    {[
                      { l: 't', v: livePos.t.toFixed(2), u: 's' },
                      ...(mode !== 'vertical' ? [{ l: 'x', v: livePos.x.toFixed(1), u: 'm' }] : []),
                      { l: 'y', v: livePos.y.toFixed(1), u: 'm' },
                    ].map(r => (
                      <div key={r.l} className="flex justify-between rounded-lg bg-white/70 px-3 py-1.5">
                        <span className="text-xs text-indigo-400 font-mono">{r.l}</span>
                        <span className="text-xs font-semibold text-indigo-700 tabular-nums">{r.v} <span className="font-normal text-indigo-300">{r.u}</span></span>
                      </div>
                    ))}
                  </div>
                </div>
              )}

              <div className="rounded-2xl border border-gray-100 bg-white p-4">
                <p className="text-xs text-gray-400 mb-2">Curriculum</p>
                <div className="flex flex-wrap gap-1.5">
                  {CURRICULA.map(c => (
                    <span key={c} className={`text-xs font-medium px-2 py-0.5 rounded-full ${
                      activeCurricula.includes(c) ? CC[c] : 'bg-gray-100 text-gray-400'
                    }`}>{c}</span>
                  ))}
                </div>
              </div>
            </div>

            {/* Col 3: teacher notes + exercises — full width on mobile, col on xl */}
            <div className="space-y-3 lg:col-span-2 xl:col-span-1">
              <div className="rounded-2xl border border-amber-100 bg-amber-50 p-4">
                <p className="text-xs font-medium text-amber-700 uppercase tracking-wide mb-3">📋 Teacher notes</p>
                <ul className="space-y-2">
                  {TEACHER_NOTES[mode].map((n, i) => (
                    <li key={i} className="text-xs text-amber-900 leading-relaxed flex gap-2">
                      <span className="text-amber-400 shrink-0 mt-0.5">•</span>{n}
                    </li>
                  ))}
                </ul>
              </div>

              <div className="rounded-2xl border border-gray-200 bg-white p-4">
                <p className="text-xs font-medium text-gray-500 uppercase tracking-wide mb-3">✏️ Exercises</p>
                <div className="space-y-2">
                  {EXERCISES[mode].map((ex, i) => (
                    <div key={i} className="rounded-xl border border-gray-100 overflow-hidden">
                      <button onClick={() => setOpenEx(openEx === i ? null : i)}
                        className="w-full text-left px-3 py-2.5 text-xs text-gray-700 leading-relaxed hover:bg-gray-50 transition flex justify-between gap-2">
                        <span><span className="font-medium text-indigo-600">Q{i+1}.</span> {ex.q}</span>
                        <span className="text-gray-300 shrink-0 text-sm">{openEx === i ? '▲' : '▼'}</span>
                      </button>
                      {openEx === i && (
                        <div className="px-3 py-2.5 bg-emerald-50 border-t border-gray-100 text-xs text-emerald-800 leading-relaxed">
                          <span className="font-medium">Answer: </span>{ex.a}
                        </div>
                      )}
                    </div>
                  ))}
                </div>
              </div>
            </div>

          </div>
        </div>
      </main>
    </>
  );
}
PATCHEOF

echo ""
echo "✅ Patch applied!"
echo ""
echo "Restart your dev server (Ctrl+C then npm run dev) and hard-refresh the page."
echo "New: a 'Launched from' toggle (Base / Top) on the Inclined tab, plus a"
echo "Platform height slider when launching from the top."
