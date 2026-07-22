#!/bin/bash
# ============================================================
# A-Factor STEM Studio — patch v2: interactive embeds,
# perfect SHM sync (live dot on curve), inclined-top physics
# Run inside af2s/ folder: bash patch-embed-shm-inclined-v2.sh
# (Supersedes patch-embed-shm-inclined.sh — includes everything
#  from v1 plus the additions below.)
#
# 1. EMBEDS ARE NOW FULLY INTERACTIVE
#    - /embed/projectile and /embed/oscillations now include the
#      parameter sliders (per mode/topic). Query params seed the
#      initial values; viewers can then explore freely.
#    - Add &controls=0 to the embed URL for a locked, view-only
#      embed with no sliders.
#
# 2. PERFECT SHM SYNC — LIVE DOT ON THE CURVE
#    - SHMGraph now renders a moving dot ON the curve at the
#      current time, alongside the red dashed line, for every
#      graph mode: x–t, v–t, a–t, Energy (dots on both KE and
#      PE), and Phase (dot at the live (x, v) point).
#    - The dot is computed from the SAME closed-form equations
#      that drive both the canvas and the plotted curve, at the
#      same t — so it sits exactly on the curve, exactly where
#      the bob/mass/rod is, at any frame rate.
#    - ALL five oscillation canvases (pendulum, spring, conical,
#      physical, bifilar/cantilever) now advance time by REAL
#      wall-clock dt instead of a fixed +=0.016 per frame.
#    - Physical pendulum + bifilar/cantilever now report onTick,
#      so their graphs get the marker + dot too (previously the
#      marker never moved for those topics).
#    - Page graph now uses the TRUE pivot-dependent I and d for
#      the physical pendulum (I = mL²/12 + md²) — matching the
#      canvas exactly, so the dot tracks the rod even when the
#      pivot slider moves.
#    - Bifilar/cantilever animation switched from sin to cos so
#      it starts at +A exactly like the plotted x = A·cos(ωt).
#    - Marker updates throttled to ~25fps (was 12fps) for a
#      smoother dot without re-rendering Recharts at 60fps.
#
# 3. INCLINED PLANE — TOP LAUNCH (from v1)
#    - "Top" = launched down the slope at α above the surface,
#      landing at the BASE of the incline. Same
#      tFlight = 2v₀sinα/(g cosβ); g sinβ accelerates along the
#      slope. Canvas draws the filled hill; Euler animation
#      verified against the closed-form landing point.
#
# Verified: tsc --noEmit clean; eslint clean on all touched
# files (only pre-existing rAF-pattern advisories remain).
# ============================================================
set -e
echo "✍️  Applying interactive-embeds + perfect-SHM-sync patch..."

mkdir -p src/app/embed
mkdir -p src/app/embed/oscillations
mkdir -p src/app/embed/projectile
mkdir -p src/app/simulations/oscillations
mkdir -p src/app/simulations/projectile-motion
mkdir -p src/components/simulation
mkdir -p src/components/ui
mkdir -p src/lib/physics

# --- src/lib/physics/projectile-modes.ts ---
cat > src/lib/physics/projectile-modes.ts << 'AFEOF'
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
  alpha: number;    // angle of projection above the inclined SURFACE (degrees)
  beta: number;     // angle of incline to horizontal (degrees)
  g: number;        // m/s²
  // Both cases are local-frame (s, n) problems that terminate back ON the
  // incline surface — never in open air:
  // 'base': launched from the foot of the incline, UP the slope.
  //         Along-slope gravity component (g sinβ) DECELERATES the motion.
  // 'top':  launched from the top of the incline, DOWN the slope.
  //         Along-slope gravity component (g sinβ) ACCELERATES the motion.
  // The perpendicular dynamics are identical in both cases, so
  // tFlight = 2·v₀·sinα / (g·cosβ) for base and top alike.
  launchFrom: 'base' | 'top';
}

export function inclinedAnalytics(p: InclinedParams) {
  const { v0, alpha, beta, g, launchFrom } = p;
  const a = alpha * DEG;
  const b = beta * DEG;
  const gAlong = g * Math.sin(b);   // down-slope component of g
  const gPerp  = g * Math.cos(b);   // into-surface component of g

  // Perpendicular motion is symmetric for both launch directions:
  // n(t) = v₀ sinα · t − ½ g cosβ · t²  →  n = 0 again at:
  const tFlight = (2 * v0 * Math.sin(a)) / gPerp;
  const maxHeightPerp = (v0 * v0 * Math.sin(a) * Math.sin(a)) / (2 * gPerp);

  // Along-slope: decelerated going up (base), accelerated going down (top).
  const sign = launchFrom === 'base' ? -1 : +1;
  const rangeAlongIncline =
    v0 * Math.cos(a) * tFlight + sign * 0.5 * gAlong * tFlight * tFlight;

  const rangeHorizontal = rangeAlongIncline * Math.cos(b);
  const verticalDrop = rangeAlongIncline * Math.sin(b); // height of top above base

  return {
    tFlight: +tFlight.toFixed(3),
    range: +rangeHorizontal.toFixed(3),
    rangeAlongIncline: +rangeAlongIncline.toFixed(3),
    rangeHorizontal: +rangeHorizontal.toFixed(3),
    maxHeight: +maxHeightPerp.toFixed(3),
    maxHeightAboveIncline: +maxHeightPerp.toFixed(3),
    // For 'top': height of the launch point above the landing point (= base).
    // For 'base': height of the landing point above the launch point.
    verticalDrop: +verticalDrop.toFixed(3),
  };
}

// World-frame launch state for the canvas.
// base: start at origin (foot of incline), slope rises to the right.
//       Launch angle above horizontal = α + β.
// top:  start at (0, H) where H = R·sinβ (top of incline), slope falls to
//       the right down to the base at (R·cosβ, 0).
//       Launch angle above horizontal = α − β.
export function inclinedSetup(p: InclinedParams) {
  const { v0, alpha, beta, launchFrom } = p;
  const a = alpha * DEG;
  const b = beta * DEG;
  if (launchFrom === 'base') {
    return {
      x0: 0, y0: 0,
      vx0: v0 * Math.cos(a + b),
      vy0: v0 * Math.sin(a + b),
      topHeight: 0,
    };
  }
  const A = inclinedAnalytics(p);
  const H = A.rangeAlongIncline * Math.sin(b);
  return {
    x0: 0, y0: +H.toFixed(4),
    vx0: v0 * Math.cos(a - b),
    vy0: v0 * Math.sin(a - b),
    topHeight: +H.toFixed(4),
  };
}

export function inclinedPath(p: InclinedParams, steps = 100) {
  const { v0, alpha, beta, g, launchFrom } = p;
  const a = alpha * DEG;
  const b = beta * DEG;
  const gPerp = g * Math.cos(b), gAlong = g * Math.sin(b);
  const tFlight = (2 * v0 * Math.sin(a)) / gPerp;
  const cosB = Math.cos(b), sinB = Math.sin(b);
  const sign = launchFrom === 'base' ? -1 : +1;
  const { y0 } = inclinedSetup(p);

  // Local frame: s along the slope (up-slope for base, down-slope for top),
  // n perpendicular to the surface. Valid for t ∈ [0, tFlight] — the moment
  // it returns to the incline surface (n = 0).
  return Array.from({ length: steps + 1 }, (_, i) => {
    const t = (i / steps) * tFlight;
    const s = v0 * Math.cos(a) * t + sign * 0.5 * gAlong * t * t;
    const n = v0 * Math.sin(a) * t - 0.5 * gPerp * t * t;
    // World coords from local (s, n):
    // base: slope direction (cosβ, +sinβ), normal (−sinβ, cosβ)… using the
    //       original convention x = s·cosβ − n·sinβ kept for continuity.
    // top:  slope direction (cosβ, −sinβ), outward normal (sinβ, cosβ).
    const x = launchFrom === 'base' ? s * cosB - n * sinB : s * cosB + n * sinB;
    const y = launchFrom === 'base' ? s * sinB + n * cosB : y0 - s * sinB + n * cosB;
    return { t: +t.toFixed(3), x: +x.toFixed(3), y: +Math.max(0, y).toFixed(3) };
  });
}
AFEOF

# --- src/components/simulation/ProjectileModeCanvas.tsx ---
cat > src/components/simulation/ProjectileModeCanvas.tsx << 'AFEOF'
'use client';
import { useEffect, useRef, useState, useCallback, useMemo } from 'react';
import {
  standardPath, horizontalPath, verticalPath, inclinedPath, inclinedSetup,
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
  topHeight?: number;               // height of incline top above base (top mode)
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
    const b = p.inclined.beta * Math.PI / 180;
    const launchFrom = p.inclined.launchFrom ?? 'base';
    // Both cases are free flight that terminates back ON the incline
    // surface. inclinedSetup() gives the world-frame launch point and
    // velocity: base → angle (α+β) above horizontal from the foot;
    // top → angle (α−β) above horizontal from the summit, height H = R·sinβ.
    const s = inclinedSetup({ ...p.inclined, launchFrom });
    return {
      x0: s.x0, y0: s.y0, vx0: s.vx0, vy0: s.vy0,
      g: p.inclined.g, h0: 0,
      beta: b, launchFrom, topHeight: s.topHeight,
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
  beta?: number, launchFrom?: 'base' | 'top', topHeight?: number,
) {
  const ctx = canvas.getContext('2d');
  if (!ctx) return;
  const W = canvas.width, H = canvas.height;

  // For inclined mode, the "ground" the object lands on is the sloped
  // incline surface — base: y = x·tanβ (rising to the right); top:
  // y = H − x·tanβ (falling to the right, clamped at ground level beyond
  // the base). Every other mode lands on flat ground (y = 0).
  const onIncline = mode === 'inclined';
  const floorAt = (xv: number) => {
    if (!onIncline) return 0;
    const tb = Math.tan(beta ?? 0);
    return launchFrom === 'top'
      ? Math.max(0, (topHeight ?? 0) - xv * tb)
      : xv * tb;
  };

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

  // Inclined surface — the ball lands back on this in both launch modes.
  if (onIncline && beta !== undefined) {
    const maxXPt = maxX * 1.25;
    ctx.save();
    ctx.beginPath();
    if (launchFrom === 'top') {
      // Slope descends from (0, H) to the base at x = H/tanβ, flat after.
      const th = topHeight ?? 0;
      const baseX = Math.tan(beta) > 1e-6 ? th / Math.tan(beta) : maxXPt;
      const [x0c, y0c] = toCanvas(0, th, scale, H);
      const [x1c, y1c] = toCanvas(Math.min(baseX, maxXPt), floorAt(Math.min(baseX, maxXPt)), scale, H);
      ctx.moveTo(x0c, y0c); ctx.lineTo(x1c, y1c);
      // Fill the hill body
      ctx.strokeStyle = '#64748b'; ctx.lineWidth = 3; ctx.stroke();
      ctx.beginPath();
      ctx.moveTo(x0c, y0c); ctx.lineTo(x1c, y1c);
      const [xg, yg] = toCanvas(0, 0, scale, H);
      ctx.lineTo(xg, yg); ctx.closePath();
      ctx.fillStyle = 'rgba(148,163,184,0.25)'; ctx.fill();
    } else {
      const [x0c, y0c] = toCanvas(0, 0, scale, H);
      const [x1c, y1c] = toCanvas(maxXPt, maxXPt * Math.tan(beta), scale, H);
      ctx.moveTo(x0c, y0c); ctx.lineTo(x1c, y1c);
      ctx.strokeStyle = '#64748b'; ctx.lineWidth = 3; ctx.stroke();
    }
    ctx.restore();
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
      setup.beta, setup.launchFrom, setup.topHeight,
    );
  }, [path, scale, maxX, maxY, mode, setup.h0, setup.beta, setup.launchFrom, setup.topHeight, isRunning, showGrid, showTrail, showVec, showComp]);

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
        // Inclined trajectories land back on the sloped surface in BOTH
        // launch modes: base → y = x·tanβ; top → y = H − x·tanβ (clamped
        // to ground level). Everything else lands at y = 0.
        let floor = 0;
        if (mode === 'inclined') {
          const tb = Math.tan(setup.beta ?? 0);
          floor = setup.launchFrom === 'top'
            ? Math.max(0, (setup.topHeight ?? 0) - ns.x * tb)
            : ns.x * tb;
        }
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
  }, [isRunning, isPaused, speedIdx, scale, height, mode, setup.beta, setup.launchFrom, setup.topHeight, draw, onTick, onComplete]);

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
AFEOF

# --- src/app/simulations/projectile-motion/page.tsx ---
cat > src/app/simulations/projectile-motion/page.tsx << 'AFEOF'
'use client';
import { useState, useCallback, useEffect, useRef, useMemo } from 'react';
import { AppHeader } from '@/components/layout/AppHeader';
import { PromptBar } from '@/components/ai/PromptBar';
import { ProjectileModeCanvas, ProjectileMode } from '@/components/simulation/ProjectileModeCanvas';
import { SimulationControls } from '@/components/simulation/SimulationControls';
import { EmbedButton } from '@/components/ui/EmbedButton';
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
    'Down-the-slope launch: same flight time t = 2v₀sinα/(g cosβ), but g sinβ now ACCELERATES the motion, so the range along the slope is longer than the same launch going up.',
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

  // Memoized so these keep a stable object identity across renders that don't
  // actually change their values (e.g. the per-frame re-render from handleTick
  // updating livePos). Without this, ProjectileModeCanvas sees a "new" params
  // object on every animation frame and resets itself mid-flight.
  const std: StandardParams   = useMemo(() => ({ v0, angle, g, h0 }), [v0, angle, g, h0]);
  const hrz: HorizontalParams = useMemo(() => ({ v0: hV0, h: hH, g }), [hV0, hH, g]);
  const vtc: VerticalParams   = useMemo(() => ({ v0: vV0, h0: vH0, g }), [vV0, vH0, g]);
  const inc: InclinedParams   = useMemo(
    () => ({ v0: iV0, alpha: iAlpha, beta: iBeta, g, launchFrom: iLaunchFrom }),
    [iV0, iAlpha, iBeta, g, iLaunchFrom]
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
  }, [mode, v0, angle, g, h0, hV0, hH, vV0, vH0, iV0, iAlpha, iBeta, iLaunchFrom, reset]);

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
                <div className="flex items-center gap-2">
                  {isComplete && <span className="text-xs font-medium text-emerald-600">✓ Complete — Reset to go again</span>}
                  <EmbedButton
                    path="/embed/projectile"
                    title={`Projectile motion (${mode}) — A-Factor STEM Studio`}
                    params={
                      mode === 'standard'   ? { mode, v0, angle, g, h0 } :
                      mode === 'horizontal' ? { mode, v0: hV0, h: hH, g } :
                      mode === 'vertical'   ? { mode, v0: vV0, h0: vH0, g } :
                      { mode, v0: iV0, alpha: iAlpha, beta: iBeta, g, launch: iLaunchFrom }
                    }
                  />
                </div>
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
                          {v === 'base' ? 'Base — up the slope' : 'Top — down the slope'}
                        </button>
                      ))}
                    </div>
                    <p className="text-[10px] text-gray-400">
                      {iLaunchFrom === 'base'
                        ? 'Launched up the slope at α above the surface — lands back on the incline. Gravity component g sinβ decelerates it along the slope.'
                        : 'Launched down the slope at α above the surface — lands at the base of the incline. Gravity component g sinβ accelerates it along the slope, so it travels farther than the same launch going up.'}
                    </p>
                  </div>
                  <Slider label="Initial velocity" unit="m/s" value={iV0} min={1} max={60} step={1} set={setIV0} color="#6366f1" />
                  <Slider label="α — angle above slope" unit="°" value={iAlpha} min={1} max={89} step={1} set={setIAlpha} color="#f59e0b" />
                  <Slider label="β — slope angle" unit="°" value={iBeta} min={5} max={60} step={1} set={setIBeta} color="#ef4444" />
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
                  {mode === 'inclined' && <>
                    <StatRow label="Flight time" value={incA.tFlight} unit="s" color="text-indigo-600" />
                    <StatRow label="Range along slope" value={incA.rangeAlongIncline} unit="m" color="text-emerald-600" />
                    <StatRow label="Horizontal range" value={incA.rangeHorizontal} unit="m" color="text-amber-600" />
                    <StatRow label="Max height ⊥ slope" value={incA.maxHeightAboveIncline} unit="m" color="text-rose-500" />
                    <StatRow
                      label={iLaunchFrom === 'top' ? 'Vertical drop' : 'Vertical rise'}
                      value={incA.verticalDrop} unit="m" color="text-purple-600" />
                  </>}
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
AFEOF

# --- src/components/simulation/PendulumCanvas.tsx ---
cat > src/components/simulation/PendulumCanvas.tsx << 'AFEOF'
'use client';
import { useRef, useEffect, useCallback } from 'react';
import { pendulumOmega, pendulumAngle } from '@/lib/physics/shm';

interface Props {
  length: number; amplitude: number; gravity: number; mass: number;
  isRunning: boolean; isPaused: boolean;
  onTick?: (t: number, x: number, v: number) => void;
  width?: number; height?: number;
}

export function PendulumCanvas({ length, amplitude, gravity, mass, isRunning, isPaused, onTick, width = 380, height = 320 }: Props) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const rafRef = useRef<number>(0);
  const tRef = useRef(0);
  const lastFrameRef = useRef<number | null>(null);
  const trailRef = useRef<[number, number][]>([]);
  const sim = useRef({ length, amplitude, gravity, mass, isRunning, isPaused, onTick });
  sim.current = { length, amplitude, gravity, mass, isRunning, isPaused, onTick };

  useEffect(() => { tRef.current = 0; lastFrameRef.current = null; trailRef.current = []; }, [length, amplitude, gravity, mass]);

  const draw = useCallback((timestamp?: number) => {
    const canvas = canvasRef.current; if (!canvas) return;
    const ctx = canvas.getContext('2d'); if (!ctx) return;
    const { length: L, amplitude: A_deg, gravity: grav, mass: m, isRunning: r, isPaused: p, onTick: ot } = sim.current;
    const W = canvas.width, H = canvas.height;
    const A_rad = A_deg * Math.PI / 180;
    const omega = pendulumOmega(L, grav);

    // Advance simulation time by REAL elapsed wall-clock time, not a fixed
    // per-frame step. A fixed += 0.016 assumes 60fps: on 120Hz screens the
    // animation ran 2× fast, which is why the canvas drifted out of sync
    // with the graph (whose time axis is in true seconds).
    if (r && !p && timestamp !== undefined) {
      if (lastFrameRef.current !== null) {
        tRef.current += Math.min((timestamp - lastFrameRef.current) / 1000, 0.1);
      }
      lastFrameRef.current = timestamp;
    } else {
      lastFrameRef.current = timestamp ?? null;
    }

    const theta = pendulumAngle(A_rad, omega, tRef.current);
    const pivotX = W / 2, pivotY = 40;
    const scale = Math.min((H - 80) / L, 280);
    const bobX = pivotX + Math.sin(theta) * L * scale;
    const bobY = pivotY + Math.cos(theta) * L * scale;
    const v = -A_rad * omega * Math.sin(omega * tRef.current);
    ot?.(tRef.current, theta, v);

    // Trail
    trailRef.current.push([bobX, bobY]);
    if (trailRef.current.length > 80) trailRef.current.shift();

    ctx.clearRect(0, 0, W, H);

    // Background
    ctx.fillStyle = '#f8fafc'; ctx.fillRect(0, 0, W, H);

    // Ceiling mount
    ctx.fillStyle = '#64748b'; ctx.fillRect(pivotX - 30, 0, 60, 12);
    ctx.fillStyle = '#94a3b8';
    ctx.beginPath(); ctx.arc(pivotX, 12, 6, 0, Math.PI * 2); ctx.fill();

    // Trail
    if (trailRef.current.length > 1) {
      ctx.save();
      for (let i = 1; i < trailRef.current.length; i++) {
        const alpha = i / trailRef.current.length;
        ctx.beginPath();
        ctx.moveTo(trailRef.current[i-1][0], trailRef.current[i-1][1]);
        ctx.lineTo(trailRef.current[i][0], trailRef.current[i][1]);
        ctx.strokeStyle = `rgba(99,102,241,${alpha * 0.5})`;
        ctx.lineWidth = 1.5; ctx.stroke();
      }
      ctx.restore();
    }

    // String
    ctx.beginPath(); ctx.moveTo(pivotX, 12); ctx.lineTo(bobX, bobY);
    ctx.strokeStyle = '#64748b'; ctx.lineWidth = 1.5; ctx.stroke();

    // Bob shadow
    ctx.beginPath(); ctx.ellipse(bobX + 3, bobY + 3, 14, 5, 0, 0, Math.PI * 2);
    ctx.fillStyle = 'rgba(0,0,0,0.08)'; ctx.fill();

    // Bob
    const bobR = Math.max(8, Math.min(m * 3, 18));
    const bobG = ctx.createRadialGradient(bobX - 3, bobY - 3, 1, bobX, bobY, bobR);
    bobG.addColorStop(0, '#818cf8'); bobG.addColorStop(1, '#4f46e5');
    ctx.beginPath(); ctx.arc(bobX, bobY, bobR, 0, Math.PI * 2);
    ctx.fillStyle = bobG; ctx.fill();
    ctx.strokeStyle = '#3730a3'; ctx.lineWidth = 1; ctx.stroke();

    // Velocity arrow
    if (Math.abs(v) > 0.01) {
      const vScale = Math.min(Math.abs(v) * 30, 50);
      const vx = Math.cos(theta) * Math.sign(v) * vScale;
      const vy = -Math.sin(theta) * Math.sign(v) * vScale;
      ctx.save();
      ctx.strokeStyle = '#f59e0b'; ctx.lineWidth = 2;
      ctx.beginPath(); ctx.moveTo(bobX, bobY); ctx.lineTo(bobX + vx, bobY + vy); ctx.stroke();
      ctx.fillStyle = '#f59e0b';
      const angle = Math.atan2(vy, vx);
      ctx.beginPath(); ctx.moveTo(bobX + vx, bobY + vy);
      ctx.lineTo(bobX + vx - 7 * Math.cos(angle - 0.4), bobY + vy - 7 * Math.sin(angle - 0.4));
      ctx.lineTo(bobX + vx - 7 * Math.cos(angle + 0.4), bobY + vy - 7 * Math.sin(angle + 0.4));
      ctx.closePath(); ctx.fill();
      ctx.restore();
    }

    // Equilibrium line
    ctx.setLineDash([4, 4]);
    ctx.beginPath(); ctx.moveTo(pivotX, 12); ctx.lineTo(pivotX, pivotY + L * scale);
    ctx.strokeStyle = 'rgba(148,163,184,0.5)'; ctx.lineWidth = 1; ctx.stroke();
    ctx.setLineDash([]);

    // Labels
    ctx.fillStyle = '#64748b'; ctx.font = '10px system-ui'; ctx.textAlign = 'left';
    ctx.fillText(`L=${L}m  A=${A_deg}°  T=${(2*Math.PI/omega).toFixed(2)}s`, 8, H - 8);
    ctx.fillText(`θ=${(theta * 180 / Math.PI).toFixed(1)}°`, 8, H - 22);

    rafRef.current = requestAnimationFrame(draw);
  }, []);

  useEffect(() => {
    rafRef.current = requestAnimationFrame(draw);
    return () => cancelAnimationFrame(rafRef.current);
  }, [draw]);

  return (
    <canvas ref={canvasRef} width={width} height={height}
      className="w-full rounded-xl border border-gray-200 bg-white" style={{ display: 'block' }} />
  );
}
AFEOF

# --- src/components/simulation/SpringCanvas.tsx ---
cat > src/components/simulation/SpringCanvas.tsx << 'AFEOF'
'use client';
import { useRef, useEffect, useCallback } from 'react';
import { springOmega, shmDisplacement, shmVelocity, springStaticExtension } from '@/lib/physics/shm';

interface Props {
  k: number; mass: number; amplitude: number;
  isRunning: boolean; isPaused: boolean;
  onTick?: (t: number, x: number, v: number) => void;
  width?: number; height?: number;
}

function drawSpring(ctx: CanvasRenderingContext2D, x: number, y1: number, y2: number, coils = 10) {
  const coilW = 18;
  const segH = (y2 - y1) / (coils * 2 + 2);
  ctx.beginPath();
  ctx.moveTo(x, y1);
  ctx.lineTo(x, y1 + segH);
  for (let i = 0; i < coils; i++) {
    ctx.lineTo(x + coilW, y1 + segH + (2 * i + 1) * segH);
    ctx.lineTo(x - coilW, y1 + segH + (2 * i + 2) * segH);
  }
  ctx.lineTo(x, y2 - segH);
  ctx.lineTo(x, y2);
  ctx.strokeStyle = '#64748b'; ctx.lineWidth = 1.5; ctx.stroke();
}

export function SpringCanvas({ k, mass, amplitude, isRunning, isPaused, onTick, width = 280, height = 340 }: Props) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const rafRef = useRef<number>(0);
  const tRef = useRef(0);
  const lastFrameRef = useRef<number | null>(null);
  const trailRef = useRef<number[]>([]);
  const sim = useRef({ k, mass, amplitude, isRunning, isPaused, onTick });
  sim.current = { k, mass, amplitude, isRunning, isPaused, onTick };

  useEffect(() => { tRef.current = 0; lastFrameRef.current = null; trailRef.current = []; }, [k, mass, amplitude]);

  const draw = useCallback((timestamp?: number) => {
    const canvas = canvasRef.current; if (!canvas) return;
    const ctx = canvas.getContext('2d'); if (!ctx) return;
    const { k: K, mass: m, amplitude: A, isRunning: r, isPaused: p, onTick: ot } = sim.current;
    const W = canvas.width, H = canvas.height;
    const omega = springOmega(K, m);
    const staticExt = springStaticExtension(m, K);

    // Real wall-clock dt (see PendulumCanvas) — keeps canvas time equal to
    // the true seconds shown on the graph's time axis at any refresh rate.
    if (r && !p && timestamp !== undefined) {
      if (lastFrameRef.current !== null) {
        tRef.current += Math.min((timestamp - lastFrameRef.current) / 1000, 0.1);
      }
      lastFrameRef.current = timestamp;
    } else {
      lastFrameRef.current = timestamp ?? null;
    }

    const x = shmDisplacement(A, omega, tRef.current); // displacement from equilibrium
    const v = shmVelocity(A, omega, tRef.current);
    ot?.(tRef.current, x, v);

    trailRef.current.push(x);
    if (trailRef.current.length > 60) trailRef.current.shift();

    ctx.clearRect(0, 0, W, H);
    ctx.fillStyle = '#f8fafc'; ctx.fillRect(0, 0, W, H);

    const cx = W / 2;
    const ceilingY = 20;
    const equilY = H / 2 + 20;
    const scale = 100; // px per metre

    // Ceiling
    ctx.fillStyle = '#64748b'; ctx.fillRect(cx - 35, 0, 70, 12);

    // Spring
    const springBottom = equilY + x * scale;
    drawSpring(ctx, cx, ceilingY + 12, springBottom - 30);

    // Equilibrium line
    ctx.setLineDash([4, 4]);
    ctx.beginPath(); ctx.moveTo(cx - 50, equilY); ctx.lineTo(cx + 50, equilY);
    ctx.strokeStyle = 'rgba(99,102,241,0.35)'; ctx.lineWidth = 1; ctx.stroke();
    ctx.setLineDash([]);
    ctx.fillStyle = '#6366f1'; ctx.font = '9px system-ui'; ctx.textAlign = 'left';
    ctx.fillText('equilibrium', cx + 36, equilY + 4);

    // Mass block
    const blockW = 60, blockH = 44;
    const bx = cx - blockW / 2;
    const by = springBottom - 20;
    const bg = ctx.createLinearGradient(bx, by, bx, by + blockH);
    bg.addColorStop(0, '#818cf8'); bg.addColorStop(1, '#4f46e5');
    ctx.fillStyle = bg;
    ctx.beginPath(); ctx.roundRect(bx, by, blockW, blockH, 6); ctx.fill();
    ctx.strokeStyle = '#3730a3'; ctx.lineWidth = 1.5;
    ctx.beginPath(); ctx.roundRect(bx, by, blockW, blockH, 6); ctx.stroke();
    ctx.fillStyle = 'white'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
    ctx.fillText(`${m}kg`, cx, by + blockH / 2 + 4);

    // Displacement arrow
    if (Math.abs(x) > 0.005) {
      const arrowX = cx + blockW / 2 + 16;
      const startY = equilY;
      const endY = by + blockH / 2;
      ctx.save();
      ctx.strokeStyle = '#ef4444'; ctx.lineWidth = 1.5;
      ctx.beginPath(); ctx.moveTo(arrowX, startY); ctx.lineTo(arrowX, endY); ctx.stroke();
      const dir = Math.sign(x);
      ctx.fillStyle = '#ef4444';
      ctx.beginPath(); ctx.moveTo(arrowX, endY);
      ctx.lineTo(arrowX - 4, endY - dir * 8); ctx.lineTo(arrowX + 4, endY - dir * 8);
      ctx.closePath(); ctx.fill();
      ctx.font = '9px system-ui'; ctx.textAlign = 'left';
      ctx.fillText(`x=${x.toFixed(3)}m`, arrowX + 6, (startY + endY) / 2);
      ctx.restore();
    }

    // Velocity arrow
    if (Math.abs(v) > 0.01) {
      const vLen = Math.min(Math.abs(v) * 40, 50);
      const dir = Math.sign(v);
      const vy1 = by + blockH / 2;
      ctx.save();
      ctx.strokeStyle = '#f59e0b'; ctx.lineWidth = 2;
      ctx.beginPath(); ctx.moveTo(cx - blockW / 2 - 14, vy1);
      ctx.lineTo(cx - blockW / 2 - 14, vy1 + dir * vLen); ctx.stroke();
      ctx.fillStyle = '#f59e0b';
      ctx.beginPath(); ctx.moveTo(cx - blockW / 2 - 14, vy1 + dir * vLen);
      ctx.lineTo(cx - blockW / 2 - 20, vy1 + dir * (vLen - 8));
      ctx.lineTo(cx - blockW / 2 - 8, vy1 + dir * (vLen - 8));
      ctx.closePath(); ctx.fill();
      ctx.restore();
    }

    // Info
    ctx.fillStyle = '#64748b'; ctx.font = '10px system-ui'; ctx.textAlign = 'center';
    ctx.fillText(`k=${K} N/m  T=${(2*Math.PI/omega).toFixed(2)}s`, cx, H - 8);

    // Mini trail (right side waveform)
    if (trailRef.current.length > 2) {
      ctx.save();
      const trailX = W - 35;
      const trailScale = 25;
      ctx.strokeStyle = 'rgba(99,102,241,0.6)'; ctx.lineWidth = 1.5;
      ctx.beginPath();
      trailRef.current.forEach((tx, i) => {
        const ty = equilY + tx * trailScale;
        const px = trailX - (trailRef.current.length - 1 - i) * 0.5;
        if (i === 0) ctx.moveTo(px, ty); else ctx.lineTo(px, ty);
      });
      ctx.stroke();
      ctx.restore();
    }

    rafRef.current = requestAnimationFrame(draw);
  }, []);

  useEffect(() => {
    rafRef.current = requestAnimationFrame(draw);
    return () => cancelAnimationFrame(rafRef.current);
  }, [draw]);

  return (
    <canvas ref={canvasRef} width={width} height={height}
      className="w-full rounded-xl border border-gray-200 bg-white" style={{ display: 'block' }} />
  );
}
AFEOF

# --- src/components/simulation/ConicalPendulumCanvas.tsx ---
cat > src/components/simulation/ConicalPendulumCanvas.tsx << 'AFEOF'
'use client';
import { useRef, useEffect, useCallback } from 'react';
import { conicalPendulumOmega, conicalPendulumRadius, conicalPendulumTension } from '@/lib/physics/shm';

interface Props {
  length: number; theta_deg: number; mass: number;
  isRunning: boolean; isPaused: boolean;
  width?: number; height?: number;
}

export function ConicalPendulumCanvas({ length, theta_deg, mass, isRunning, isPaused, width = 380, height = 320 }: Props) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const rafRef = useRef<number>(0);
  const phiRef = useRef(0);
  const lastFrameRef = useRef<number | null>(null);
  const sim = useRef({ length, theta_deg, mass, isRunning, isPaused });
  sim.current = { length, theta_deg, mass, isRunning, isPaused };

  const draw = useCallback((timestamp?: number) => {
    const canvas = canvasRef.current; if (!canvas) return;
    const ctx = canvas.getContext('2d'); if (!ctx) return;
    const { length: L, theta_deg: th, mass: m, isRunning: r, isPaused: p } = sim.current;
    const W = canvas.width, H = canvas.height;
    const theta = th * Math.PI / 180;
    const omega = conicalPendulumOmega(L, theta);
    const r_circ = conicalPendulumRadius(L, theta);
    const T = conicalPendulumTension(m, theta);

    // Real wall-clock dt — the orbital period on screen now equals the
    // calculated T exactly, at any display refresh rate.
    if (r && !p && timestamp !== undefined) {
      if (lastFrameRef.current !== null) {
        phiRef.current += omega * Math.min((timestamp - lastFrameRef.current) / 1000, 0.1);
      }
      lastFrameRef.current = timestamp;
    } else {
      lastFrameRef.current = timestamp ?? null;
    }

    const cx = W / 2, cy = 50;
    const scale = Math.min((H - 100) / L, 200);
    const vertLen = L * Math.cos(theta) * scale;
    const bobX = cx + r_circ * scale * Math.cos(phiRef.current);
    const bobY = cy + vertLen;

    ctx.clearRect(0, 0, W, H);
    ctx.fillStyle = '#f8fafc'; ctx.fillRect(0, 0, W, H);

    // Ceiling
    ctx.fillStyle = '#64748b'; ctx.fillRect(cx - 35, 0, 70, 12);
    ctx.fillStyle = '#94a3b8'; ctx.beginPath(); ctx.arc(cx, 12, 5, 0, Math.PI * 2); ctx.fill();

    // Orbit circle (ellipse for perspective)
    ctx.save();
    ctx.strokeStyle = 'rgba(99,102,241,0.2)'; ctx.lineWidth = 1; ctx.setLineDash([4, 4]);
    ctx.beginPath();
    ctx.ellipse(cx, bobY, r_circ * scale, r_circ * scale * 0.25, 0, 0, Math.PI * 2);
    ctx.stroke(); ctx.setLineDash([]); ctx.restore();

    // Shadow on orbit
    const shadowX = cx + r_circ * scale * Math.cos(phiRef.current);
    ctx.beginPath(); ctx.ellipse(shadowX, bobY + 4, 10, 4, 0, 0, Math.PI * 2);
    ctx.fillStyle = 'rgba(0,0,0,0.08)'; ctx.fill();

    // String
    ctx.beginPath(); ctx.moveTo(cx, 12); ctx.lineTo(bobX, bobY);
    ctx.strokeStyle = '#64748b'; ctx.lineWidth = 1.5; ctx.stroke();

    // Vertical dashed line
    ctx.setLineDash([4, 4]);
    ctx.beginPath(); ctx.moveTo(cx, 12); ctx.lineTo(cx, bobY + 20);
    ctx.strokeStyle = 'rgba(148,163,184,0.5)'; ctx.lineWidth = 1; ctx.stroke();
    ctx.setLineDash([]);

    // Angle arc
    ctx.beginPath();
    ctx.arc(cx, 12, 28, Math.PI / 2, Math.PI / 2 + theta);
    ctx.strokeStyle = '#f59e0b'; ctx.lineWidth = 1.5; ctx.stroke();
    ctx.fillStyle = '#f59e0b'; ctx.font = '10px system-ui'; ctx.textAlign = 'left';
    ctx.fillText(`θ=${th}°`, cx + 6, 12 + 38);

    // Bob
    const bobG = ctx.createRadialGradient(bobX - 2, bobY - 2, 1, bobX, bobY, 12);
    bobG.addColorStop(0, '#818cf8'); bobG.addColorStop(1, '#4f46e5');
    ctx.beginPath(); ctx.arc(bobX, bobY, 12, 0, Math.PI * 2);
    ctx.fillStyle = bobG; ctx.fill();
    ctx.strokeStyle = '#3730a3'; ctx.lineWidth = 1; ctx.stroke();

    // Force vectors (from bob)
    // Tension component (along string, upward-inward)
    const Tscale = Math.min(T * 8, 55);
    const Tx = cx - bobX; const Ty = cy + 12 - bobY;
    const Tmag = Math.sqrt(Tx * Tx + Ty * Ty);
    ctx.save();
    ctx.strokeStyle = '#10b981'; ctx.lineWidth = 2;
    ctx.beginPath(); ctx.moveTo(bobX, bobY);
    ctx.lineTo(bobX + Tx / Tmag * Tscale, bobY + Ty / Tmag * Tscale); ctx.stroke();
    ctx.fillStyle = '#10b981'; ctx.font = '9px system-ui'; ctx.textAlign = 'center';
    ctx.fillText(`T=${T.toFixed(1)}N`, bobX + Tx / Tmag * Tscale * 0.6, bobY + Ty / Tmag * Tscale * 0.6 - 6);
    ctx.restore();

    // Weight (downward)
    const W_n = m * 9.81;
    const Wscale = Math.min(W_n * 8, 45);
    ctx.save();
    ctx.strokeStyle = '#ef4444'; ctx.lineWidth = 2;
    ctx.beginPath(); ctx.moveTo(bobX, bobY); ctx.lineTo(bobX, bobY + Wscale); ctx.stroke();
    ctx.fillStyle = '#ef4444';
    ctx.beginPath(); ctx.moveTo(bobX, bobY + Wscale);
    ctx.lineTo(bobX - 4, bobY + Wscale - 7); ctx.lineTo(bobX + 4, bobY + Wscale - 7);
    ctx.closePath(); ctx.fill();
    ctx.font = '9px system-ui'; ctx.textAlign = 'left';
    ctx.fillText(`mg=${W_n.toFixed(1)}N`, bobX + 6, bobY + Wscale / 2);
    ctx.restore();

    // Info
    ctx.fillStyle = '#64748b'; ctx.font = '10px system-ui'; ctx.textAlign = 'center';
    ctx.fillText(`r=${r_circ.toFixed(2)}m  T_period=${(2*Math.PI/omega).toFixed(2)}s`, cx, H - 8);

    rafRef.current = requestAnimationFrame(draw);
  }, []);

  useEffect(() => {
    rafRef.current = requestAnimationFrame(draw);
    return () => cancelAnimationFrame(rafRef.current);
  }, [draw]);

  return (
    <canvas ref={canvasRef} width={width} height={height}
      className="w-full rounded-xl border border-gray-200 bg-white" style={{ display: 'block' }} />
  );
}
AFEOF

# --- src/components/simulation/PhysicalPendulumCanvas.tsx ---
cat > src/components/simulation/PhysicalPendulumCanvas.tsx << 'AFEOF'
'use client';
import { useRef, useEffect, useCallback } from 'react';
import { physicalPendulumPeriod, pendulumPeriod } from '@/lib/physics/shm';

interface Props {
  length: number; mass: number; pivotFraction: number;
  isRunning: boolean; isPaused: boolean;
  onTick?: (t: number) => void;
  width?: number; height?: number;
}

export function PhysicalPendulumCanvas({ length, mass, pivotFraction, isRunning, isPaused, onTick, width = 380, height = 320 }: Props) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const rafRef = useRef<number>(0);
  const tRef = useRef(0);
  const lastFrameRef = useRef<number | null>(null);
  const sim = useRef({ length, mass, pivotFraction, isRunning, isPaused, onTick });
  sim.current = { length, mass, pivotFraction, isRunning, isPaused, onTick };

  useEffect(() => { tRef.current = 0; lastFrameRef.current = null; }, [length, mass, pivotFraction]);

  const draw = useCallback((timestamp?: number) => {
    const canvas = canvasRef.current; if (!canvas) return;
    const ctx = canvas.getContext('2d'); if (!ctx) return;
    const { length: L, mass: m, pivotFraction: pf, isRunning: r, isPaused: p, onTick: ot } = sim.current;
    const W = canvas.width, H = canvas.height;

    // Pivot at fraction pf along rod from top
    const d = L * (0.5 - pf) + L * pf; // distance from pivot to CoM
    const dFromTop = pf * L; // pivot position from top of rod
    const dToCoM = L / 2 - dFromTop; // pivot to CoM (positive = CoM below pivot)
    const d_actual = Math.abs(dToCoM) < 0.001 ? 0.001 : Math.abs(dToCoM);
    // I about pivot = mL²/12 + m*d²
    const I_cm = m * L * L / 12;
    const I_pivot = I_cm + m * d_actual * d_actual;
    const T_phys = physicalPendulumPeriod(I_pivot, m, d_actual);
    const T_simple = pendulumPeriod(L);
    const omega_phys = 2 * Math.PI / T_phys;

    // Real wall-clock dt — keeps the rod's motion equal to true seconds so
    // the period shown on screen matches T_phys exactly at any refresh rate,
    // and the graph's time marker stays perfectly in sync.
    if (r && !p && timestamp !== undefined) {
      if (lastFrameRef.current !== null) {
        tRef.current += Math.min((timestamp - lastFrameRef.current) / 1000, 0.1);
      }
      lastFrameRef.current = timestamp;
    } else {
      lastFrameRef.current = timestamp ?? null;
    }
    ot?.(tRef.current);

    const A_rad = 0.25; // fixed amplitude
    const theta = A_rad * Math.cos(omega_phys * tRef.current);

    const pivotX = W / 2, pivotY = 60;
    const scale = Math.min((H - 100) / L, 180);

    ctx.clearRect(0, 0, W, H);
    ctx.fillStyle = '#f8fafc'; ctx.fillRect(0, 0, W, H);

    // Ceiling
    ctx.fillStyle = '#64748b'; ctx.fillRect(pivotX - 30, 0, 60, 12);

    // Rod (rotated)
    const rodTopX = pivotX - Math.sin(theta) * dFromTop * scale;
    const rodTopY = pivotY - Math.cos(theta) * dFromTop * scale;
    const rodBotX = pivotX + Math.sin(theta) * (L - dFromTop) * scale;
    const rodBotY = pivotY + Math.cos(theta) * (L - dFromTop) * scale;

    ctx.save();
    // Rod body
    ctx.strokeStyle = '#4f46e5'; ctx.lineWidth = 12;
    ctx.lineCap = 'round';
    ctx.beginPath(); ctx.moveTo(rodTopX, rodTopY); ctx.lineTo(rodBotX, rodBotY); ctx.stroke();
    // CoM dot
    const comX = pivotX + Math.sin(theta) * dToCoM * scale;
    const comY = pivotY + Math.cos(theta) * dToCoM * scale;
    ctx.fillStyle = '#f59e0b';
    ctx.beginPath(); ctx.arc(comX, comY, 5, 0, Math.PI * 2); ctx.fill();
    // Pivot point
    ctx.fillStyle = '#ef4444';
    ctx.beginPath(); ctx.arc(pivotX, pivotY, 6, 0, Math.PI * 2); ctx.fill();
    ctx.fillStyle = 'white';
    ctx.beginPath(); ctx.arc(pivotX, pivotY, 3, 0, Math.PI * 2); ctx.fill();
    ctx.restore();

    // Equilibrium line
    ctx.setLineDash([4, 4]);
    ctx.beginPath(); ctx.moveTo(pivotX, pivotY - 10); ctx.lineTo(pivotX, H - 20);
    ctx.strokeStyle = 'rgba(148,163,184,0.4)'; ctx.lineWidth = 1; ctx.stroke();
    ctx.setLineDash([]);

    // Legend
    ctx.fillStyle = '#f59e0b'; ctx.font = '9px system-ui'; ctx.textAlign = 'left';
    ctx.fillText('● Centre of mass', 8, H - 36);
    ctx.fillStyle = '#ef4444'; ctx.fillText('● Pivot point', 8, H - 24);
    ctx.fillStyle = '#64748b';
    ctx.fillText(`T_physical=${T_phys.toFixed(3)}s  T_simple=${T_simple.toFixed(3)}s`, 8, H - 8);

    rafRef.current = requestAnimationFrame(draw);
  }, []);

  useEffect(() => {
    rafRef.current = requestAnimationFrame(draw);
    return () => cancelAnimationFrame(rafRef.current);
  }, [draw]);

  return (
    <canvas ref={canvasRef} width={width} height={height}
      className="w-full rounded-xl border border-gray-200 bg-white" style={{ display: 'block' }} />
  );
}
AFEOF

# --- src/components/simulation/BifilarCanvas.tsx ---
cat > src/components/simulation/BifilarCanvas.tsx << 'AFEOF'
'use client';
import { useRef, useEffect, useCallback } from 'react';
import { bifilarPeriodSimple, cantileverStiffness } from '@/lib/physics/shm';

type Mode = 'bifilar' | 'cantilever';

interface Props {
  mode: Mode; mass: number; rodLength: number;
  wireLength: number; separation: number;
  beamLength: number; beamWidth: number; beamHeight: number;
  youngModulus: number; load: number;
  isRunning: boolean; isPaused: boolean;
  onTick?: (t: number) => void;
  width?: number; height?: number;
}

export function BifilarCanvas({
  mode, mass, rodLength, wireLength, separation,
  beamLength, beamWidth, beamHeight, youngModulus, load,
  isRunning, isPaused, onTick, width = 380, height = 300
}: Props) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const rafRef = useRef<number>(0);
  const tRef = useRef(0);
  const lastFrameRef = useRef<number | null>(null);
  const sim = useRef({ mode, mass, rodLength, wireLength, separation, beamLength, beamWidth, beamHeight, youngModulus, load, isRunning, isPaused, onTick });
  sim.current = { mode, mass, rodLength, wireLength, separation, beamLength, beamWidth, beamHeight, youngModulus, load, isRunning, isPaused, onTick };

  useEffect(() => { tRef.current = 0; lastFrameRef.current = null; }, [mode, mass, rodLength, wireLength, separation, beamLength, beamHeight, youngModulus, load]);

  const draw = useCallback((timestamp?: number) => {
    const canvas = canvasRef.current; if (!canvas) return;
    const ctx = canvas.getContext('2d'); if (!ctx) return;
    const s = sim.current;
    const W = canvas.width, H = canvas.height;

    // Real wall-clock dt (see PendulumCanvas) — animation time == true
    // seconds at any refresh rate, so the graph marker stays in sync.
    if (s.isRunning && !s.isPaused && timestamp !== undefined) {
      if (lastFrameRef.current !== null) {
        tRef.current += Math.min((timestamp - lastFrameRef.current) / 1000, 0.1);
      }
      lastFrameRef.current = timestamp;
    } else {
      lastFrameRef.current = timestamp ?? null;
    }
    s.onTick?.(tRef.current);

    ctx.clearRect(0, 0, W, H);
    ctx.fillStyle = '#f8fafc'; ctx.fillRect(0, 0, W, H);

    if (s.mode === 'bifilar') {
      const T = bifilarPeriodSimple(s.mass, s.rodLength, s.wireLength, s.separation / 2);
      const omega = 2 * Math.PI / T;
      // cos, not sin — matches the graph's x = A·cos(ωt) convention, so the
      // rod starts at maximum twist exactly where the plotted curve starts at +A.
      const phi = 0.3 * Math.cos(omega * tRef.current); // torsion angle

      const cx = W / 2, ceilY = 20;
      const rodY = ceilY + s.wireLength * 80;
      const rodHalfL = s.rodLength * 60;

      // Ceiling
      ctx.fillStyle = '#64748b'; ctx.fillRect(cx - 60, 0, 120, 12);

      // Wires (twisted perspective)
      const w1x = cx - s.separation * 40 * Math.cos(phi);
      const w2x = cx + s.separation * 40 * Math.cos(phi);
      const rodLeft  = cx - rodHalfL * Math.cos(phi);
      const rodRight = cx + rodHalfL * Math.cos(phi);

      ctx.strokeStyle = '#94a3b8'; ctx.lineWidth = 1.5;
      ctx.beginPath(); ctx.moveTo(cx - s.separation * 40, ceilY + 12); ctx.lineTo(rodLeft, rodY); ctx.stroke();
      ctx.beginPath(); ctx.moveTo(cx + s.separation * 40, ceilY + 12); ctx.lineTo(rodRight, rodY); ctx.stroke();

      // Attachment points on ceiling
      ctx.fillStyle = '#475569';
      ctx.beginPath(); ctx.arc(cx - s.separation * 40, ceilY + 12, 4, 0, Math.PI * 2); ctx.fill();
      ctx.beginPath(); ctx.arc(cx + s.separation * 40, ceilY + 12, 4, 0, Math.PI * 2); ctx.fill();

      // Rod (rotating)
      const rodThick = 10;
      ctx.save();
      ctx.fillStyle = '#4f46e5';
      ctx.beginPath();
      ctx.moveTo(rodLeft, rodY - rodThick / 2);
      ctx.lineTo(rodRight, rodY - rodThick / 2);
      ctx.lineTo(rodRight, rodY + rodThick / 2);
      ctx.lineTo(rodLeft, rodY + rodThick / 2);
      ctx.closePath(); ctx.fill();
      ctx.strokeStyle = '#3730a3'; ctx.lineWidth = 1; ctx.stroke();
      // Mass label
      ctx.fillStyle = 'white'; ctx.font = 'bold 9px system-ui'; ctx.textAlign = 'center';
      ctx.fillText(`${s.mass}kg`, cx, rodY + 4);
      ctx.restore();

      // Angle indicator
      ctx.fillStyle = '#f59e0b'; ctx.font = '10px system-ui'; ctx.textAlign = 'center';
      ctx.fillText(`φ=${(phi * 180 / Math.PI).toFixed(1)}°`, cx, rodY + 30);
      ctx.fillStyle = '#64748b';
      ctx.fillText(`T=${T.toFixed(3)}s  I=mL²/12=${(s.mass * s.rodLength ** 2 / 12).toFixed(3)} kg·m²`, cx, H - 8);

    } else {
      // Cantilever
      const k = cantileverStiffness(s.youngModulus * 1e9, s.beamWidth / 100, s.beamHeight / 100, s.beamLength);
      const deflection = s.load / k; // metres
      const dispPx = Math.min(deflection * 2000, 80); // pixels
      const omega_c = Math.sqrt(k / s.mass);

      // Static + dynamic deflection
      const dynamicPx = s.isRunning ? dispPx + 0.3 * dispPx * Math.cos(omega_c * tRef.current) : dispPx;

      const wallX = 40, beamY = H / 2 - 10;
      const beamLenPx = W - 100;
      const beamThPx = Math.max(8, s.beamHeight * 8);

      // Wall
      ctx.fillStyle = '#94a3b8';
      ctx.fillRect(0, beamY - 40, wallX, 80);
      for (let y = beamY - 40; y < beamY + 40; y += 10) {
        ctx.strokeStyle = '#64748b'; ctx.lineWidth = 1;
        ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(wallX - 5, y + 5); ctx.stroke();
      }

      // Beam (slightly curved for deflection)
      ctx.save();
      ctx.beginPath();
      ctx.moveTo(wallX, beamY);
      const tipX = wallX + beamLenPx;
      const tipY = beamY + dynamicPx;
      // Cubic Bezier for beam deflection shape
      ctx.bezierCurveTo(
        wallX + beamLenPx * 0.6, beamY,
        wallX + beamLenPx * 0.9, beamY + dynamicPx * 0.7,
        tipX, tipY
      );
      ctx.lineTo(tipX, tipY + beamThPx);
      ctx.bezierCurveTo(
        wallX + beamLenPx * 0.9, beamY + dynamicPx * 0.7 + beamThPx,
        wallX + beamLenPx * 0.6, beamY + beamThPx,
        wallX, beamY + beamThPx
      );
      ctx.closePath();
      const beamGrad = ctx.createLinearGradient(0, beamY, 0, beamY + beamThPx);
      beamGrad.addColorStop(0, '#818cf8'); beamGrad.addColorStop(1, '#4f46e5');
      ctx.fillStyle = beamGrad; ctx.fill();
      ctx.strokeStyle = '#3730a3'; ctx.lineWidth = 1; ctx.stroke();
      ctx.restore();

      // Load (hanging weight)
      if (s.load > 0) {
        ctx.strokeStyle = '#64748b'; ctx.lineWidth = 1.5;
        ctx.beginPath(); ctx.moveTo(tipX, tipY + beamThPx); ctx.lineTo(tipX, tipY + beamThPx + 25); ctx.stroke();
        ctx.fillStyle = '#ef4444';
        ctx.beginPath(); ctx.roundRect(tipX - 20, tipY + beamThPx + 25, 40, 28, 4); ctx.fill();
        ctx.fillStyle = 'white'; ctx.font = 'bold 9px system-ui'; ctx.textAlign = 'center';
        ctx.fillText(`${s.load}N`, tipX, tipY + beamThPx + 42);
      }

      // Deflection arrow
      ctx.strokeStyle = '#f59e0b'; ctx.lineWidth = 1.5; ctx.setLineDash([3, 3]);
      ctx.beginPath(); ctx.moveTo(tipX + 18, beamY); ctx.lineTo(tipX + 18, tipY); ctx.stroke();
      ctx.setLineDash([]);
      ctx.fillStyle = '#f59e0b'; ctx.font = '9px system-ui'; ctx.textAlign = 'left';
      ctx.fillText(`δ=${deflection.toFixed(4)}m`, tipX + 22, (beamY + tipY) / 2 + 4);

      // Fixed end label
      ctx.fillStyle = '#64748b'; ctx.font = '9px system-ui'; ctx.textAlign = 'center';
      ctx.fillText('Fixed end', wallX / 2, beamY - 50);
      ctx.fillText(`k=${k.toFixed(0)} N/m  T=${(2*Math.PI/omega_c).toFixed(3)}s`, W / 2, H - 8);
    }

    rafRef.current = requestAnimationFrame(draw);
  }, []);

  useEffect(() => {
    rafRef.current = requestAnimationFrame(draw);
    return () => cancelAnimationFrame(rafRef.current);
  }, [draw]);

  return (
    <canvas ref={canvasRef} width={width} height={height}
      className="w-full rounded-xl border border-gray-200 bg-white" style={{ display: 'block' }} />
  );
}
AFEOF

# --- src/components/simulation/SHMGraph.tsx ---
cat > src/components/simulation/SHMGraph.tsx << 'AFEOF'
'use client';
import { useMemo } from 'react';
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer, Label, ReferenceLine, ReferenceDot } from 'recharts';
import { generateSHMData, shmDisplacement, shmVelocity, shmAcceleration, shmKE, shmPE } from '@/lib/physics/shm';

const CYCLES = 3;

type GraphMode = 'displacement' | 'velocity' | 'acceleration' | 'energy' | 'phase';

interface Props {
  A: number; omega: number; m: number; k: number;
  mode: GraphMode; currentT?: number;
}

export function SHMGraph({ A, omega, m, k, mode, currentT = 0 }: Props) {
  // Memoized — regenerating 200 points on every animation tick was wasted
  // work; the curve only changes when the physics parameters change.
  const data = useMemo(() => generateSHMData(A, omega, m, k, CYCLES), [A, omega, m, k]);

  // The graph shows exactly CYCLES periods. SHM is periodic, so wrap the
  // live time marker back onto the visible window instead of letting it
  // run off the right edge and vanish (which looked like the graph had
  // fallen out of sync with the animation).
  const totalTime = CYCLES * (2 * Math.PI) / omega;
  const markerT = currentT > 0 ? currentT % totalTime : 0;

  // Live values at the marker time — computed from the SAME closed-form
  // equations that drive both the canvas animation and the plotted curve,
  // so the moving dot sits exactly ON the curve, perfectly in sync with
  // the mass/bob, at any frame rate.
  const liveX = shmDisplacement(A, omega, markerT);
  const liveV = shmVelocity(A, omega, markerT);
  const liveA = shmAcceleration(A, omega, markerT);
  const liveKE = shmKE(m, liveV);
  const livePE = shmPE(k, liveX);

  if (mode === 'phase') {
    // Phase space: v vs x
    return (
      <ResponsiveContainer width="100%" height={200}>
        <LineChart data={data} margin={{ top: 8, right: 16, left: 10, bottom: 28 }}>
          <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
          <XAxis dataKey="x" type="number" tick={{ fontSize: 10 }} domain={[-A * 1.1, A * 1.1]}>
            <Label value="Displacement x (m)" position="insideBottom" offset={-16} style={{ fontSize: 10, fill: '#94a3b8' }} />
          </XAxis>
          <YAxis tick={{ fontSize: 10 }}>
            <Label value="Velocity v (m/s)" angle={-90} position="insideLeft" offset={12} style={{ fontSize: 10, fill: '#94a3b8' }} />
          </YAxis>
          <Tooltip formatter={(v: unknown) => [Number(v).toFixed(3)]} />
          <Line type="monotone" dataKey="v" stroke="#6366f1" strokeWidth={2} dot={false} />
          <ReferenceLine x={0} stroke="#e2e8f0" />
          <ReferenceLine y={0} stroke="#e2e8f0" />
          {markerT > 0 && (
            <ReferenceDot x={liveX} y={liveV} r={6} fill="#ef4444" stroke="#fff" strokeWidth={2} />
          )}
        </LineChart>
      </ResponsiveContainer>
    );
  }

  if (mode === 'energy') {
    return (
      <ResponsiveContainer width="100%" height={200}>
        <LineChart data={data} margin={{ top: 8, right: 16, left: 10, bottom: 28 }}>
          <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
          <XAxis dataKey="t" type="number" tick={{ fontSize: 10 }}>
            <Label value="Time (s)" position="insideBottom" offset={-16} style={{ fontSize: 10, fill: '#94a3b8' }} />
          </XAxis>
          <YAxis tick={{ fontSize: 10 }}>
            <Label value="Energy (J)" angle={-90} position="insideLeft" offset={12} style={{ fontSize: 10, fill: '#94a3b8' }} />
          </YAxis>
          <Tooltip formatter={(v: unknown) => [Number(v).toFixed(4), '']} labelFormatter={t => `t=${Number(t).toFixed(2)}s`} />
          <Legend wrapperStyle={{ fontSize: 10 }} />
          <Line type="monotone" dataKey="ke" stroke="#f59e0b" strokeWidth={2} dot={false} name="KE" />
          <Line type="monotone" dataKey="pe" stroke="#6366f1" strokeWidth={2} dot={false} name="PE" />
          <Line type="monotone" dataKey="te" stroke="#10b981" strokeWidth={1.5} dot={false} strokeDasharray="5 3" name="Total E" />
          {markerT > 0 && <>
            <ReferenceLine x={markerT} stroke="#ef4444" strokeDasharray="3 3" />
            <ReferenceDot x={markerT} y={liveKE} r={5} fill="#f59e0b" stroke="#fff" strokeWidth={2} />
            <ReferenceDot x={markerT} y={livePE} r={5} fill="#6366f1" stroke="#fff" strokeWidth={2} />
          </>}
        </LineChart>
      </ResponsiveContainer>
    );
  }

  const keyMap = { displacement: 'x', velocity: 'v', acceleration: 'a' };
  const colorMap = { displacement: '#6366f1', velocity: '#10b981', acceleration: '#f59e0b' };
  const labelMap = { displacement: 'Displacement (m)', velocity: 'Velocity (m/s)', acceleration: 'Acceleration (m/s²)' };
  const dataKey = keyMap[mode as keyof typeof keyMap];
  const color = colorMap[mode as keyof typeof colorMap];

  return (
    <ResponsiveContainer width="100%" height={200}>
      <LineChart data={data} margin={{ top: 8, right: 16, left: 10, bottom: 28 }}>
        <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
        <XAxis dataKey="t" type="number" tick={{ fontSize: 10 }}>
          <Label value="Time (s)" position="insideBottom" offset={-16} style={{ fontSize: 10, fill: '#94a3b8' }} />
        </XAxis>
        <YAxis tick={{ fontSize: 10 }}>
          <Label value={labelMap[mode as keyof typeof labelMap]} angle={-90} position="insideLeft" offset={12} style={{ fontSize: 10, fill: '#94a3b8' }} />
        </YAxis>
        <Tooltip formatter={(v: unknown) => [Number(v).toFixed(4)]} labelFormatter={t => `t=${Number(t).toFixed(2)}s`} />
        <ReferenceLine y={0} stroke="#e2e8f0" />
        <Line type="monotone" dataKey={dataKey} stroke={color} strokeWidth={2} dot={false} />
        {markerT > 0 && <>
          <ReferenceLine x={markerT} stroke="#ef4444" strokeDasharray="3 3" />
          <ReferenceDot
            x={markerT}
            y={mode === 'displacement' ? liveX : mode === 'velocity' ? liveV : liveA}
            r={6} fill={color} stroke="#fff" strokeWidth={2} 
          />
        </>}
      </LineChart>
    </ResponsiveContainer>
  );
}
AFEOF

# --- src/app/simulations/oscillations/page.tsx ---
cat > src/app/simulations/oscillations/page.tsx << 'AFEOF'
'use client';
import { useState, useCallback, useRef, useEffect } from 'react';
import { AppHeader } from '@/components/layout/AppHeader';
import { SimulationControls } from '@/components/simulation/SimulationControls';
import { EmbedButton } from '@/components/ui/EmbedButton';
import { PendulumCanvas } from '@/components/simulation/PendulumCanvas';
import { SpringCanvas } from '@/components/simulation/SpringCanvas';
import { ConicalPendulumCanvas } from '@/components/simulation/ConicalPendulumCanvas';
import { PhysicalPendulumCanvas } from '@/components/simulation/PhysicalPendulumCanvas';
import { BifilarCanvas } from '@/components/simulation/BifilarCanvas';
import { SHMGraph } from '@/components/simulation/SHMGraph';
import {
  pendulumOmega, pendulumPeriod,
  springOmega, springPeriod, springStaticExtension,
  conicalPendulumOmega, conicalPendulumPeriod, conicalPendulumTension, conicalPendulumSpeed,
  physicalPendulumPeriod, rodPendulumPeriod,
  bifilarPeriodSimple, cantileverStiffness, cantileverDeflection, cantileverPeriod,
} from '@/lib/physics/shm';

type Topic = 'pendulum' | 'spring' | 'conical' | 'physical' | 'bifilar';
type GraphMode = 'displacement' | 'velocity' | 'acceleration' | 'energy' | 'phase';

const CURRICULA = ['WAEC', 'NECO', 'IGCSE', 'SAT', 'JUPEB'];
const CC: Record<string, string> = {
  WAEC: 'bg-indigo-100 text-indigo-700', NECO: 'bg-pink-100 text-pink-700',
  IGCSE: 'bg-emerald-100 text-emerald-700', SAT: 'bg-orange-100 text-orange-700',
  JUPEB: 'bg-purple-100 text-purple-700',
};

const TOPIC_META: Record<Topic, { title: string; icon: string; sub: string; eq: string }> = {
  pendulum: { title: 'Simple pendulum',       icon: '⏱️', sub: 'SHM for small angles', eq: 'T = 2π√(L/g)' },
  spring:   { title: 'Loaded spring',         icon: '🌀', sub: 'Mass-spring system',    eq: 'T = 2π√(m/k)' },
  conical:  { title: 'Conical pendulum',      icon: '🔄', sub: 'Circular motion + tension', eq: 'ω² = g/(L cosθ)' },
  physical: { title: 'Physical pendulum',     icon: '📏', sub: 'Extended rigid body',   eq: 'T = 2π√(I/mgd)' },
  bifilar:  { title: 'Bifilar / Cantilever',  icon: '🏗️', sub: 'Torsion & beam flexure', eq: 'T = 2π√(Il/mgd²)' },
};

const TEACHER_NOTES: Record<Topic, string[]> = {
  pendulum: [
    "Period T = 2π√(L/g) is INDEPENDENT of mass and amplitude (for small angles < 15°).",
    "This independence of mass is why a pendulum makes a good clock — it keeps time regardless of the bob.",
    "For large amplitudes, the period increases — the small-angle approximation (sinθ ≈ θ) breaks down.",
    "On the Moon (g=1.6 m/s²), the same pendulum runs ~2.5× slower. The gravity slider demonstrates this.",
    "A seconds pendulum (T=2s) has length L = g/π² ≈ 0.993m — almost exactly 1 metre.",
  ],
  spring: [
    "T = 2π√(m/k): period increases with mass, decreases with spring stiffness. Mass affects it; length does not.",
    "The static extension x₀ = mg/k gives the equilibrium position. SHM occurs about this point.",
    "Hooke's Law F = kx and SHM are directly linked: F = −kx gives a = −(k/m)x → ω² = k/m.",
    "Energy: at equilibrium (x=0) all energy is KE. At amplitude (x=A) all energy is PE. Total E = ½mω²A² always.",
    "The phase space graph (v vs x) is an ellipse — a perfect circle if axes are scaled to same range.",
  ],
  conical: [
    "The bob moves in a horizontal circle — this is NOT SHM, but links circular motion to pendulums.",
    "Key equations: T cosθ = mg (vertical), T sinθ = mω²r (horizontal). Dividing: tanθ = ω²r/g.",
    "As ω increases, θ increases (bob rises). As θ → 90°, r → L and ω → ∞ (impossible in practice).",
    "Period decreases as angle increases: T = 2π√(L cosθ / g). Faster spin = shorter period.",
    "Good link to centripetal force: the horizontal component of tension provides centripetal force.",
  ],
  physical: [
    "A physical pendulum uses the full rigid-body rotation: T = 2π√(I/mgd) where I is about the pivot.",
    "For a uniform rod pivoted at the end: I = mL²/3, d = L/2 → T = 2π√(2L/3g). Compare to simple T = 2π√(L/g).",
    "The physical pendulum always has a longer period than the simple pendulum of the same length.",
    "There are two pivot points that give the same period — the 'centre of oscillation' concept used in precision timing.",
    "The equivalent simple pendulum length L_eq = I/(md). This is what IGCSE/JUPEB exam questions test.",
  ],
  bifilar: [
    "Bifilar suspension: a rod hung by two parallel wires undergoes TORSIONAL oscillation (twisting).",
    "T = (2π/d)√(Il/mg) where d = half wire separation, l = wire length, I = moment of inertia.",
    "Used to measure moment of inertia experimentally: measure T, know l and d, solve for I.",
    "Cantilever beam: one end fixed, free end deflects under load. Stiffness k = 3EI/L³.",
    "Cantilever vibration period T = 2π√(m_eff/k). The effective mass ≈ 0.24 × beam mass + tip mass.",
  ],
};

const EXERCISES: Record<Topic, { q: string; a: string }[]> = {
  pendulum: [
    { q: "A pendulum has period 2s on Earth (g=9.81 m/s²). Find its length.", a: "T=2π√(L/g) → L=g(T/2π)²=9.81×(2/2π)²=9.81×0.1013=0.993m ≈ 1m" },
    { q: "A 2m pendulum is taken to a planet where g=4 m/s². Find the new period.", a: "T=2π√(L/g)=2π√(2/4)=2π×0.707=4.44s" },
    { q: "Why does doubling the mass of a pendulum bob not change its period?", a: "Both restoring force and inertia scale with mass, so they cancel in the period equation T=2π√(L/g) — mass doesn't appear." },
  ],
  spring: [
    { q: "A 0.5kg mass on a spring of k=200 N/m. Find period and frequency.", a: "T=2π√(m/k)=2π√(0.5/200)=2π×0.05=0.314s. f=1/T=3.18Hz" },
    { q: "A spring extends 0.05m under a 2kg load (g=10 m/s²). Find k and the SHM period.", a: "k=F/x=mg/x=20/0.05=400 N/m. T=2π√(2/400)=2π×0.0707=0.444s" },
    { q: "A spring-mass system has total energy 0.4J and amplitude 0.1m. Find the spring constant k.", a: "E=½kA² → k=2E/A²=2×0.4/0.01=80 N/m" },
  ],
  conical: [
    { q: "A conical pendulum of length 0.5m makes angle 30° with vertical. Find ω and period. (g=10)", a: "ω=√(g/Lcosθ)=√(10/0.5×cos30°)=√(10/0.433)=√23.1=4.81 rad/s. T=2π/ω=1.31s" },
    { q: "Find the tension in the string of a 0.2kg bob at θ=45°. (g=10)", a: "T=mg/cosθ=0.2×10/cos45°=2/0.707=2.83N" },
    { q: "As the angular velocity of a conical pendulum increases, what happens to the angle θ?", a: "θ increases — the bob rises outward. Since ω²=g/(Lcosθ), larger ω requires smaller cosθ, meaning larger θ." },
  ],
  physical: [
    { q: "A uniform rod of length 1.2m and mass 0.5kg is pivoted at one end. Find the period. (g=9.81)", a: "I=mL²/3=0.5×1.44/3=0.24 kg·m². d=L/2=0.6m. T=2π√(I/mgd)=2π√(0.24/0.5×9.81×0.6)=2π×0.285=1.79s" },
    { q: "Compare this to a simple pendulum of the same length.", a: "T_simple=2π√(1.2/9.81)=2π×0.350=2.20s. The physical pendulum (1.79s) is FASTER — its effective length is 2L/3=0.8m, shorter than L." },
    { q: "What is the equivalent simple pendulum length for a uniform rod pivoted at one end?", a: "L_eq=I/(md)=(mL²/3)/(m×L/2)=2L/3. For L=1.2m: L_eq=0.8m." },
  ],
  bifilar: [
    { q: "A 2kg rod (L=0.6m) hangs on wires of length 1m, separation 0.4m. Find the period.", a: "I=mL²/12=2×0.36/12=0.06 kg·m². T=2π√(Il/mgd²)=2π√(0.06×1/2×9.81×0.04)=2π√(0.0765)=2π×0.277=1.74s" },
    { q: "A cantilever beam: E=200GPa, b=30mm, h=5mm, L=0.5m. Find stiffness k.", a: "I_beam=bh³/12=0.03×(0.005)³/12=3.125×10⁻¹⁰m⁴. k=3EI/L³=3×200×10⁹×3.125×10⁻¹⁰/0.125=1500 N/m" },
    { q: "Why is bifilar suspension used to measure moment of inertia experimentally?", a: "The period T=(2π/d)√(Il/mg) can be rearranged to I=mgd²T²/(4π²l). By measuring T and knowing all other quantities, I is found without needing to integrate over the shape." },
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
        onChange={e => set(Number(e.target.value))} className="w-full" style={{ accentColor: color }} />
      {note && <p className="text-[10px] text-gray-400">{note}</p>}
    </div>
  );
}

export default function OscillationsPage() {
  const [topic, setTopic] = useState<Topic>('pendulum');
  const [isRunning, setIsRunning] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const [resetKey, setResetKey] = useState(0);
  const [openEx, setOpenEx] = useState<number | null>(null);
  const [activeCurricula, setActiveCurricula] = useState(['WAEC', 'IGCSE', 'JUPEB']);
  const [graphMode, setGraphMode] = useState<GraphMode>('displacement');
  const [currentT, setCurrentT] = useState(0);

  // Pendulum params
  const [pendL, setPendL] = useState(1.0);
  const [pendA, setPendA] = useState(15);
  const [pendG, setPendG] = useState(9.81);
  const [pendM, setPendM] = useState(0.5);

  // Spring params
  const [spK, setSpK] = useState(50);
  const [spM, setSpM] = useState(1.0);
  const [spA, setSpA] = useState(0.1);

  // Conical params
  const [conL, setConL] = useState(0.8);
  const [conTheta, setConTheta] = useState(30);
  const [conM, setConM] = useState(0.3);

  // Physical pendulum params
  const [physL, setPhysL] = useState(1.0);
  const [physM, setPhysM] = useState(0.5);
  const [physPF, setPhysPF] = useState(0); // pivot fraction from top (0=top end, 0.5=centre)

  // Bifilar/Cantilever params
  const [bifMode, setBifMode] = useState<'bifilar' | 'cantilever'>('bifilar');
  const [bifM, setBifM] = useState(2);
  const [bifL, setBifL] = useState(0.6);
  const [bifWire, setBifWire] = useState(1.0);
  const [bifSep, setBifSep] = useState(0.3);
  const [cantL, setCantL] = useState(0.5);
  const [cantH, setCantH] = useState(10); // mm
  const [cantLoad, setCantLoad] = useState(5);

  // Derived analytics
  const pendOmega = pendulumOmega(pendL, pendG);
  const pendT = pendulumPeriod(pendL, pendG);
  const spOmega = springOmega(spK, spM);
  const spT = springPeriod(spK, spM);
  const spStaticX = springStaticExtension(spM, spK);
  const conOmega = conicalPendulumOmega(conL, conTheta * Math.PI / 180);
  const conT = conicalPendulumPeriod(conL, conTheta * Math.PI / 180);
  const conTens = conicalPendulumTension(conM, conTheta * Math.PI / 180);
  const conSpeed = conicalPendulumSpeed(conL, conTheta * Math.PI / 180);
  // Pivot-dependent — must mirror PhysicalPendulumCanvas exactly, otherwise
  // the graph's ω differs from the canvas's ω whenever the pivot slider moves
  // and the live dot drifts off the rod's motion.
  const physD = Math.max(Math.abs(physL / 2 - physPF * physL), 0.001);
  const physI = physM * physL * physL / 12 + physM * physD * physD;
  const physT_actual = physicalPendulumPeriod(physI, physM, physD);
  const physT_simple = rodPendulumPeriod(physL);
  const bifT = bifilarPeriodSimple(bifM, bifL, bifWire, bifSep / 2);
  const cantK = cantileverStiffness(200e9, 0.03, cantH / 1000, cantL);
  const cantDef = cantileverDeflection(cantLoad, 200e9, 0.03, cantH / 1000, cantL);
  const cantT = cantileverPeriod(1, 200e9, 0.03, cantH / 1000, cantL);

  // Graph data — omega/A must match what the canvas actually animates so the
  // live dot on the curve tracks the mass/bob/rod exactly.
  const bifOmega = bifMode === 'bifilar' ? 2 * Math.PI / bifT : 2 * Math.PI / cantT;
  const graphA = topic === 'pendulum' ? pendA * Math.PI / 180 * pendL :
                 topic === 'spring' ? spA :
                 topic === 'physical' ? 0.25 :          // rad — canvas uses A_rad = 0.25
                 bifMode === 'bifilar' ? 0.3 :           // rad — bifilar canvas uses 0.3
                 0.3 * cantDef;                          // m — cantilever tip oscillates ±0.3·δ
  const graphOmega = topic === 'pendulum' ? pendOmega :
                     topic === 'spring' ? spOmega :
                     topic === 'physical' ? 2 * Math.PI / physT_actual :
                     bifOmega;
  const graphM = topic === 'pendulum' ? pendM : topic === 'spring' ? spM :
                 topic === 'physical' ? physM : bifM;
  const graphK = topic === 'pendulum' ? pendM * pendOmega * pendOmega :
                 topic === 'spring' ? spK :
                 graphM * graphOmega * graphOmega;

  const resetTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const reset = useCallback(() => {
    setIsRunning(false); setIsPaused(false);
    setResetKey(k => k + 1); setCurrentT(0);
  }, []);

  useEffect(() => {
    if (resetTimer.current) clearTimeout(resetTimer.current);
    resetTimer.current = setTimeout(reset, 100);
  }, [topic, pendL, pendA, pendG, pendM, spK, spM, spA, conL, conTheta, conM, physL, physM, physPF, bifM, bifL, bifWire, bifSep, cantL, cantH, cantLoad, bifMode, reset]);

  // Throttle marker updates to ~12fps. Updating React state on every
  // animation frame re-rendered the whole page (and the Recharts graph)
  // 60+ times a second — the graph would visibly stutter and lag behind
  // the canvas. The canvas itself animates via its own rAF loop and is
  // unaffected by this throttle.
  const lastTickRef = useRef(0);
  const handleTick = useCallback((t: number) => {
    const now = performance.now();
    if (now - lastTickRef.current > 40) {
      lastTickRef.current = now;
      setCurrentT(t);
    }
  }, []);

  return (
    <>
      <AppHeader />
      <main className="min-h-screen bg-gray-50">
        <section className="border-b border-gray-200 bg-white">
          <div className="mx-auto max-w-7xl px-4 sm:px-6 py-4">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
              <div>
                <p className="text-xs text-gray-400 mb-0.5">Mechanics — Oscillations</p>
                <h1 className="text-lg font-semibold text-gray-900">Simple Harmonic Motion</h1>
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

          {/* Topic tabs */}
          <div className="flex gap-1 bg-gray-100 p-1 rounded-xl overflow-x-auto">
            {(Object.keys(TOPIC_META) as Topic[]).map(t => (
              <button key={t} onClick={() => { setTopic(t); setOpenEx(null); setGraphMode('displacement'); }}
                className={`shrink-0 flex items-center gap-1.5 px-3 py-2 rounded-lg text-xs font-medium transition ${
                  topic === t ? 'bg-white text-indigo-700 shadow-sm' : 'text-gray-500 hover:text-gray-700'
                }`}>
                <span>{TOPIC_META[t].icon}</span>
                <span className="hidden sm:inline">{TOPIC_META[t].title}</span>
                <span className="sm:hidden">{TOPIC_META[t].icon}</span>
              </button>
            ))}
          </div>

          {/* Equation banner */}
          <div className="flex flex-wrap items-center gap-3 rounded-xl border border-gray-200 bg-white px-4 py-2.5">
            <span className="text-xs text-gray-400">{TOPIC_META[topic].sub}</span>
            <span className="text-sm font-semibold font-mono text-gray-900">{TOPIC_META[topic].eq}</span>
            {topic !== 'conical' && (
              <span className="text-xs text-gray-400 ml-2">a = −ω²x &nbsp;|&nbsp; x = A cos(ωt)</span>
            )}
          </div>

          {/* Main grid */}
          <div className="grid grid-cols-1 lg:grid-cols-[1fr_220px] xl:grid-cols-[1fr_220px_260px] gap-4">

            {/* Canvas + graph + controls + sliders */}
            <div className="space-y-3 min-w-0">

              {/* Canvas */}
              <div className="rounded-2xl border border-gray-200 bg-white p-3 shadow-sm">
                {topic === 'pendulum' && (
                  <PendulumCanvas key={resetKey} length={pendL} amplitude={pendA}
                    gravity={pendG} mass={pendM}
                    isRunning={isRunning} isPaused={isPaused}
                    onTick={(t) => handleTick(t)}
                    width={380} height={300} />
                )}
                {topic === 'spring' && (
                  <SpringCanvas key={resetKey} k={spK} mass={spM} amplitude={spA}
                    isRunning={isRunning} isPaused={isPaused}
                    onTick={(t) => handleTick(t)}
                    width={280} height={320} />
                )}
                {topic === 'conical' && (
                  <ConicalPendulumCanvas key={resetKey} length={conL} theta_deg={conTheta}
                    mass={conM} isRunning={isRunning} isPaused={isPaused}
                    width={380} height={300} />
                )}
                {topic === 'physical' && (
                  <PhysicalPendulumCanvas key={resetKey} length={physL} mass={physM}
                    pivotFraction={physPF} isRunning={isRunning} isPaused={isPaused}
                    onTick={(t) => handleTick(t)}
                    width={380} height={300} />
                )}
                {topic === 'bifilar' && (
                  <div className="space-y-2">
                    <div className="flex gap-1 bg-gray-100 p-1 rounded-xl w-fit">
                      {(['bifilar', 'cantilever'] as const).map(m => (
                        <button key={m} onClick={() => setBifMode(m)}
                          className={`px-4 py-1.5 rounded-lg text-xs font-medium transition capitalize ${
                            bifMode === m ? 'bg-white text-indigo-700 shadow-sm' : 'text-gray-500'
                          }`}>{m}</button>
                      ))}
                    </div>
                    <BifilarCanvas key={`${resetKey}-${bifMode}`}
                      mode={bifMode} mass={bifM} rodLength={bifL}
                      wireLength={bifWire} separation={bifSep}
                      beamLength={cantL} beamWidth={30} beamHeight={cantH}
                      youngModulus={200} load={cantLoad}
                      isRunning={isRunning} isPaused={isPaused}
                      onTick={(t) => handleTick(t)}
                      width={380} height={280} />
                  </div>
                )}
              </div>

              {/* Controls */}
              <div className="flex flex-wrap items-center justify-between gap-2">
                <SimulationControls
                  isRunning={isRunning} isPaused={isPaused}
                  onRun={() => { setIsRunning(true); setIsPaused(false); }}
                  onPause={() => setIsPaused(p => !p)}
                  onReset={reset}
                />
                {topic !== 'bifilar' && (
                  <EmbedButton
                    path="/embed/oscillations"
                    title={`${TOPIC_META[topic].title} — A-Factor STEM Studio`}
                    params={
                      topic === 'pendulum' ? { topic, L: pendL, A: pendA, g: pendG, m: pendM } :
                      topic === 'spring'   ? { topic, k: spK, m: spM, A: spA } :
                      topic === 'conical'  ? { topic, L: conL, theta: conTheta, m: conM } :
                      { topic, L: physL, m: physM, pf: physPF }
                    }
                  />
                )}
              </div>

              {/* Graph */}
              {topic !== 'conical' && (
                <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                  <div className="flex items-center justify-between mb-3 flex-wrap gap-2">
                    <p className="text-xs font-medium text-gray-400 uppercase tracking-wide">Graph</p>
                    <div className="flex gap-1 bg-gray-100 p-0.5 rounded-lg overflow-x-auto">
                      {(['displacement', 'velocity', 'acceleration', 'energy', 'phase'] as GraphMode[]).map(gm => (
                        <button key={gm} onClick={() => setGraphMode(gm)}
                          className={`shrink-0 px-2.5 py-1 rounded-md text-[10px] font-medium transition ${
                            graphMode === gm ? 'bg-white text-indigo-700 shadow-sm' : 'text-gray-500'
                          }`}>
                          {gm === 'displacement' ? 'x–t' : gm === 'velocity' ? 'v–t' : gm === 'acceleration' ? 'a–t' : gm === 'energy' ? 'Energy' : 'Phase (v–x)'}
                        </button>
                      ))}
                    </div>
                  </div>
                  <SHMGraph A={graphA} omega={graphOmega} m={graphM} k={graphK}
                    mode={graphMode} currentT={currentT} />
                  <p className="text-[10px] text-gray-400 mt-2 text-center">
                    {graphMode === 'displacement' && 'Cosine wave — starts at +A, returns to +A each period T'}
                    {graphMode === 'velocity' && 'Sine wave — 90° ahead of displacement. Maximum at x=0'}
                    {graphMode === 'acceleration' && 'Cosine wave — always opposite to displacement (a = −ω²x)'}
                    {graphMode === 'energy' && 'KE and PE exchange; total energy E = ½mω²A² = constant (dashed)'}
                    {graphMode === 'phase' && 'Ellipse in phase space — SHM traces a closed orbit'}
                  </p>
                </div>
              )}

              {/* Sliders */}
              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm space-y-4">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide">Parameters</p>

                {topic === 'pendulum' && <>
                  <Slider label="Length" unit="m" value={pendL} min={0.1} max={3} step={0.05} set={setPendL} color="#6366f1" />
                  <Slider label="Amplitude" unit="°" value={pendA} min={2} max={30} step={1} set={setPendA} color="#f59e0b" note="Keep < 15° for accurate SHM" />
                  <Slider label="Mass" unit="kg" value={pendM} min={0.1} max={2} step={0.1} set={setPendM} color="#94a3b8" note="Does not affect period" />
                  <Slider label="Gravity" unit="m/s²" value={pendG} min={1.6} max={25} step={0.1} set={setPendG} color="#10b981" note="Moon=1.6  Earth=9.81  Jupiter=24.8" />
                </>}

                {topic === 'spring' && <>
                  <Slider label="Spring constant k" unit="N/m" value={spK} min={5} max={500} step={5} set={setSpK} color="#6366f1" />
                  <Slider label="Mass" unit="kg" value={spM} min={0.1} max={5} step={0.1} set={setSpM} color="#f59e0b" />
                  <Slider label="Amplitude" unit="m" value={spA} min={0.01} max={0.3} step={0.01} set={setSpA} color="#10b981" note="Must be less than static extension" />
                </>}

                {topic === 'conical' && <>
                  <Slider label="String length" unit="m" value={conL} min={0.2} max={2} step={0.05} set={setConL} color="#6366f1" />
                  <Slider label="Half-angle θ" unit="°" value={conTheta} min={5} max={75} step={1} set={setConTheta} color="#f59e0b" />
                  <Slider label="Mass" unit="kg" value={conM} min={0.1} max={1} step={0.05} set={setConM} color="#10b981" />
                </>}

                {topic === 'physical' && <>
                  <Slider label="Rod length" unit="m" value={physL} min={0.2} max={2} step={0.05} set={setPhysL} color="#6366f1" />
                  <Slider label="Mass" unit="kg" value={physM} min={0.1} max={2} step={0.1} set={setPhysM} color="#f59e0b" />
                  <Slider label="Pivot position (fraction from top)" unit="" value={physPF} min={0} max={0.45} step={0.05} set={setPhysPF} color="#10b981" note="0 = top end, 0.5 = centre (infinite period)" />
                </>}

                {topic === 'bifilar' && bifMode === 'bifilar' && <>
                  <Slider label="Rod mass" unit="kg" value={bifM} min={0.5} max={5} step={0.1} set={setBifM} color="#6366f1" />
                  <Slider label="Rod length" unit="m" value={bifL} min={0.2} max={1.5} step={0.05} set={setBifL} color="#f59e0b" />
                  <Slider label="Wire length" unit="m" value={bifWire} min={0.3} max={2} step={0.05} set={setBifWire} color="#10b981" />
                  <Slider label="Wire separation (2d)" unit="m" value={bifSep} min={0.1} max={0.8} step={0.02} set={setBifSep} color="#8b5cf6" />
                </>}

                {topic === 'bifilar' && bifMode === 'cantilever' && <>
                  <Slider label="Beam length" unit="m" value={cantL} min={0.1} max={1} step={0.05} set={setCantL} color="#6366f1" />
                  <Slider label="Beam height (thickness)" unit="mm" value={cantH} min={2} max={20} step={1} set={setCantH} color="#f59e0b" />
                  <Slider label="End load" unit="N" value={cantLoad} min={0} max={50} step={1} set={setCantLoad} color="#ef4444" />
                </>}
              </div>
            </div>

            {/* Analytics */}
            <div className="space-y-3">
              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide mb-3">Calculated</p>
                <div className="space-y-2">
                  {topic === 'pendulum' && [
                    { l: 'Angular freq ω', v: `${pendOmega.toFixed(3)} rad/s`, c: 'text-indigo-600' },
                    { l: 'Period T', v: `${pendT.toFixed(3)} s`, c: 'text-emerald-600' },
                    { l: 'Frequency f', v: `${(1/pendT).toFixed(3)} Hz`, c: 'text-amber-600' },
                    { l: 'Max velocity', v: `${(pendA * Math.PI/180 * pendL * pendOmega).toFixed(3)} m/s`, c: 'text-rose-500' },
                    { l: 'Max acceleration', v: `${(pendA * Math.PI/180 * pendL * pendOmega**2).toFixed(3)} m/s²`, c: 'text-purple-600' },
                  ].map(r => (
                    <div key={r.l} className="flex justify-between items-center rounded-lg bg-gray-50 px-3 py-2">
                      <span className="text-xs text-gray-500">{r.l}</span>
                      <span className={`text-xs font-semibold tabular-nums ${r.c}`}>{r.v}</span>
                    </div>
                  ))}

                  {topic === 'spring' && [
                    { l: 'Angular freq ω', v: `${spOmega.toFixed(3)} rad/s`, c: 'text-indigo-600' },
                    { l: 'Period T', v: `${spT.toFixed(3)} s`, c: 'text-emerald-600' },
                    { l: 'Static extension', v: `${spStaticX.toFixed(3)} m`, c: 'text-amber-600' },
                    { l: 'Max velocity', v: `${(spA * spOmega).toFixed(3)} m/s`, c: 'text-rose-500' },
                    { l: 'Total energy', v: `${(0.5 * spK * spA * spA).toFixed(4)} J`, c: 'text-purple-600' },
                    { l: 'Max KE = Max PE', v: `${(0.5 * spK * spA * spA).toFixed(4)} J`, c: 'text-gray-600' },
                  ].map(r => (
                    <div key={r.l} className="flex justify-between items-center rounded-lg bg-gray-50 px-3 py-2">
                      <span className="text-xs text-gray-500">{r.l}</span>
                      <span className={`text-xs font-semibold tabular-nums ${r.c}`}>{r.v}</span>
                    </div>
                  ))}

                  {topic === 'conical' && [
                    { l: 'Angular velocity ω', v: `${conOmega.toFixed(3)} rad/s`, c: 'text-indigo-600' },
                    { l: 'Period T', v: `${conT.toFixed(3)} s`, c: 'text-emerald-600' },
                    { l: 'Orbital radius r', v: `${(conL * Math.sin(conTheta*Math.PI/180)).toFixed(3)} m`, c: 'text-amber-600' },
                    { l: 'String tension T', v: `${conTens.toFixed(3)} N`, c: 'text-rose-500' },
                    { l: 'Orbital speed v', v: `${conSpeed.toFixed(3)} m/s`, c: 'text-purple-600' },
                    { l: 'Vertical height', v: `${(conL * Math.cos(conTheta*Math.PI/180)).toFixed(3)} m`, c: 'text-gray-600' },
                  ].map(r => (
                    <div key={r.l} className="flex justify-between items-center rounded-lg bg-gray-50 px-3 py-2">
                      <span className="text-xs text-gray-500">{r.l}</span>
                      <span className={`text-xs font-semibold tabular-nums ${r.c}`}>{r.v}</span>
                    </div>
                  ))}

                  {topic === 'physical' && [
                    { l: 'I (about pivot)', v: `${physI.toFixed(4)} kg·m²`, c: 'text-indigo-600' },
                    { l: 'Period (physical)', v: `${physT_actual.toFixed(3)} s`, c: 'text-emerald-600' },
                    { l: 'Period (simple, same L)', v: `${physT_simple.toFixed(3)} s`, c: 'text-amber-600' },
                    { l: 'Equiv. simple length', v: `${(physI/(physM*physD)).toFixed(3)} m`, c: 'text-rose-500' },
                    { l: 'Ratio T_phys/T_simple', v: `${(physT_actual/physT_simple).toFixed(3)}`, c: 'text-purple-600' },
                  ].map(r => (
                    <div key={r.l} className="flex justify-between items-center rounded-lg bg-gray-50 px-3 py-2">
                      <span className="text-xs text-gray-500">{r.l}</span>
                      <span className={`text-xs font-semibold tabular-nums ${r.c}`}>{r.v}</span>
                    </div>
                  ))}

                  {topic === 'bifilar' && bifMode === 'bifilar' && [
                    { l: 'I (rod)', v: `${(bifM*bifL**2/12).toFixed(4)} kg·m²`, c: 'text-indigo-600' },
                    { l: 'Period T', v: `${bifT.toFixed(3)} s`, c: 'text-emerald-600' },
                    { l: 'Frequency f', v: `${(1/bifT).toFixed(3)} Hz`, c: 'text-amber-600' },
                  ].map(r => (
                    <div key={r.l} className="flex justify-between items-center rounded-lg bg-gray-50 px-3 py-2">
                      <span className="text-xs text-gray-500">{r.l}</span>
                      <span className={`text-xs font-semibold tabular-nums ${r.c}`}>{r.v}</span>
                    </div>
                  ))}

                  {topic === 'bifilar' && bifMode === 'cantilever' && [
                    { l: 'Stiffness k', v: `${cantK.toFixed(0)} N/m`, c: 'text-indigo-600' },
                    { l: 'Deflection δ', v: `${(cantDef*1000).toFixed(2)} mm`, c: 'text-emerald-600' },
                    { l: 'Nat. frequency', v: `${(1/cantT).toFixed(2)} Hz`, c: 'text-amber-600' },
                    { l: 'Period T', v: `${cantT.toFixed(3)} s`, c: 'text-rose-500' },
                  ].map(r => (
                    <div key={r.l} className="flex justify-between items-center rounded-lg bg-gray-50 px-3 py-2">
                      <span className="text-xs text-gray-500">{r.l}</span>
                      <span className={`text-xs font-semibold tabular-nums ${r.c}`}>{r.v}</span>
                    </div>
                  ))}
                </div>
              </div>

              {/* Curriculum */}
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

            {/* Teacher notes + exercises */}
            <div className="space-y-3 lg:col-span-2 xl:col-span-1">
              <div className="rounded-2xl border border-amber-100 bg-amber-50 p-4">
                <p className="text-xs font-medium text-amber-700 uppercase tracking-wide mb-3">📋 Teacher notes</p>
                <ul className="space-y-2">
                  {TEACHER_NOTES[topic].map((n, i) => (
                    <li key={i} className="text-xs text-amber-900 leading-relaxed flex gap-2">
                      <span className="text-amber-400 shrink-0 mt-0.5">•</span>{n}
                    </li>
                  ))}
                </ul>
              </div>

              <div className="rounded-2xl border border-gray-200 bg-white p-4">
                <p className="text-xs font-medium text-gray-500 uppercase tracking-wide mb-3">✏️ Exercises</p>
                <div className="space-y-2">
                  {EXERCISES[topic].map((ex, i) => (
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
AFEOF

# --- src/components/ui/EmbedButton.tsx ---
cat > src/components/ui/EmbedButton.tsx << 'AFEOF'
'use client';
import { useState, useMemo } from 'react';

interface EmbedButtonProps {
  /** Embed route path, e.g. '/embed/projectile' */
  path: string;
  /** Query params baked into the embed URL (current simulation settings). */
  params?: Record<string, string | number>;
  /** Accessible title for the iframe. */
  title: string;
  width?: number;
  height?: number;
}

export function EmbedButton({ path, params = {}, title, width = 760, height = 520 }: EmbedButtonProps) {
  const [open, setOpen] = useState(false);
  const [copied, setCopied] = useState(false);

  const embedUrl = useMemo(() => {
    const origin =
      typeof window !== 'undefined'
        ? window.location.origin
        : process.env.NEXT_PUBLIC_APP_URL ?? '';
    const qs = new URLSearchParams(
      Object.fromEntries(Object.entries(params).map(([k, v]) => [k, String(v)]))
    ).toString();
    return `${origin}${path}${qs ? `?${qs}` : ''}`;
  }, [path, params]);

  const snippet = `<iframe src="${embedUrl}" width="${width}" height="${height}" style="border:1px solid #e5e7eb;border-radius:12px;max-width:100%;" loading="lazy" allowfullscreen title="${title}"></iframe>`;

  const copy = async () => {
    try {
      await navigator.clipboard.writeText(snippet);
      setCopied(true);
      setTimeout(() => setCopied(false), 1800);
    } catch {
      // Clipboard API unavailable — user can still select + copy manually.
    }
  };

  return (
    <>
      <button
        onClick={() => setOpen(true)}
        className="flex items-center gap-1.5 rounded-lg border border-gray-200 bg-white px-3 py-1.5 text-xs font-medium text-gray-600 transition hover:border-indigo-300 hover:text-indigo-700"
      >
        <svg width="12" height="12" viewBox="0 0 12 12" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
          <path d="M4.5 3L1.5 6l3 3M7.5 3l3 3-3 3" />
        </svg>
        Embed
      </button>

      {open && (
        <div
          className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4"
          onClick={() => setOpen(false)}
        >
          <div
            className="w-full max-w-lg rounded-2xl bg-white p-5 shadow-xl"
            onClick={e => e.stopPropagation()}
          >
            <div className="mb-3 flex items-start justify-between gap-4">
              <div>
                <h3 className="text-sm font-semibold text-gray-900">Embed this simulation</h3>
                <p className="mt-0.5 text-xs text-gray-400">
                  Paste this HTML into any website, LMS page, or blog. The embed uses the
                  current parameter values as its starting state.
                </p>
              </div>
              <button onClick={() => setOpen(false)} className="text-gray-300 transition hover:text-gray-500">
                <svg width="16" height="16" viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round">
                  <path d="M4 4l8 8M12 4l-8 8" />
                </svg>
              </button>
            </div>

            <textarea
              readOnly
              value={snippet}
              rows={5}
              onFocus={e => e.target.select()}
              className="w-full resize-none rounded-xl border border-gray-200 bg-gray-50 p-3 font-mono text-[11px] leading-relaxed text-gray-700 outline-none focus:border-indigo-300"
            />

            <div className="mt-3 flex items-center justify-between gap-2">
              <a
                href={embedUrl}
                target="_blank"
                rel="noopener noreferrer"
                className="text-xs font-medium text-indigo-600 hover:text-indigo-700"
              >
                Preview embed →
              </a>
              <button
                onClick={copy}
                className={`rounded-lg px-4 py-2 text-xs font-medium text-white transition ${
                  copied ? 'bg-emerald-500' : 'bg-indigo-600 hover:bg-indigo-700'
                }`}
              >
                {copied ? '✓ Copied' : 'Copy HTML'}
              </button>
            </div>
          </div>
        </div>
      )}
    </>
  );
}
AFEOF

# --- src/app/embed/layout.tsx ---
cat > src/app/embed/layout.tsx << 'AFEOF'
import type { Metadata } from 'next';

export const metadata: Metadata = {
  title: 'A-Factor STEM Studio — Embedded simulation',
  robots: { index: false }, // embeds shouldn't compete with the real pages in search
};

// Deliberately minimal: no AppHeader, no site navigation. This layout wraps
// only the /embed/* routes, which are designed to live inside an <iframe>
// on someone else's page.
export default function EmbedLayout({ children }: { children: React.ReactNode }) {
  return <div className="min-h-screen bg-white">{children}</div>;
}
AFEOF

# --- src/app/embed/projectile/page.tsx ---
cat > src/app/embed/projectile/page.tsx << 'AFEOF'
'use client';
import { Suspense, useState, useMemo, useCallback, useEffect, useRef } from 'react';
import { useSearchParams } from 'next/navigation';
import { ProjectileModeCanvas, ProjectileMode } from '@/components/simulation/ProjectileModeCanvas';
import { SimulationControls } from '@/components/simulation/SimulationControls';
import type {
  StandardParams, HorizontalParams, VerticalParams, InclinedParams,
} from '@/lib/physics/projectile-modes';

// Reads a numeric query param with clamping so a hand-edited embed URL can't
// produce a broken simulation.
function num(sp: URLSearchParams, key: string, fallback: number, min: number, max: number) {
  const v = Number(sp.get(key));
  return Number.isFinite(v) && sp.get(key) !== null ? Math.min(max, Math.max(min, v)) : fallback;
}

function Slider({ label, unit, value, min, max, step, set, color }: {
  label: string; unit: string; value: number; min: number; max: number;
  step: number; set: (v: number) => void; color: string;
}) {
  return (
    <div className="space-y-1">
      <div className="flex justify-between text-xs">
        <span className="text-gray-500">{label}</span>
        <span className="font-medium tabular-nums text-gray-800">{value} <span className="font-normal text-gray-400">{unit}</span></span>
      </div>
      <input type="range" min={min} max={max} step={step} value={value}
        onChange={e => set(Number(e.target.value))} className="w-full" style={{ accentColor: color }} />
    </div>
  );
}

function ProjectileEmbedInner() {
  const sp = useSearchParams();

  const mode = ((): ProjectileMode => {
    const m = sp.get('mode');
    return m === 'horizontal' || m === 'vertical' || m === 'inclined' ? m : 'standard';
  })();

  // Hide the parameter panel with &controls=0 for a locked, view-only embed.
  const showControls = sp.get('controls') !== '0';

  // Query params seed the INITIAL values; the sliders below make the embed
  // fully interactive so viewers can explore, not just watch.
  const [g, setG] = useState(() => num(sp, 'g', 9.81, 1, 25));
  const [v0, setV0] = useState(() => num(sp, 'v0', mode === 'standard' ? 25 : mode === 'horizontal' ? 20 : mode === 'vertical' ? 15 : 20, mode === 'vertical' ? -30 : 1, mode === 'inclined' ? 60 : mode === 'vertical' ? 50 : 100));
  const [angle, setAngle] = useState(() => num(sp, 'angle', 45, 1, 89));
  const [h0, setH0] = useState(() => num(sp, 'h0', 0, 0, 200));
  const [hH, setHH] = useState(() => num(sp, 'h', 30, 1, 200));
  const [iAlpha, setIAlpha] = useState(() => num(sp, 'alpha', 30, 1, 89));
  const [iBeta, setIBeta] = useState(() => num(sp, 'beta', 30, 5, 60));
  const [launchFrom, setLaunchFrom] = useState<'base' | 'top'>(() => (sp.get('launch') === 'top' ? 'top' : 'base'));

  const std: StandardParams   = useMemo(() => ({ v0, angle, g, h0 }), [v0, angle, g, h0]);
  const hrz: HorizontalParams = useMemo(() => ({ v0, h: hH, g }), [v0, hH, g]);
  const vtc: VerticalParams   = useMemo(() => ({ v0, h0, g }), [v0, h0, g]);
  const inc: InclinedParams   = useMemo(
    () => ({ v0, alpha: iAlpha, beta: iBeta, g, launchFrom }),
    [v0, iAlpha, iBeta, g, launchFrom]
  );

  const [isRunning, setIsRunning] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const [isComplete, setIsComplete] = useState(false);
  const [resetKey, setResetKey] = useState(0);

  const reset = useCallback(() => {
    setIsRunning(false); setIsPaused(false); setIsComplete(false);
    setResetKey(k => k + 1);
  }, []);
  const handleComplete = useCallback(() => { setIsComplete(true); setIsRunning(false); }, []);

  // Changing any parameter stops the current run and resets — same behaviour
  // as the full simulation page.
  const resetTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  useEffect(() => {
    if (resetTimer.current) clearTimeout(resetTimer.current);
    resetTimer.current = setTimeout(reset, 80);
  }, [v0, angle, g, h0, hH, iAlpha, iBeta, launchFrom, reset]);

  return (
    <div className="mx-auto max-w-3xl space-y-3 p-3 sm:p-4">
      <ProjectileModeCanvas
        key={resetKey}
        mode={mode}
        standard={std} horizontal={hrz} vertical={vtc} inclined={inc}
        isRunning={isRunning} isPaused={isPaused}
        onComplete={handleComplete}
        width={720} height={340}
      />
      <div className="flex flex-wrap items-center justify-between gap-2">
        <SimulationControls
          isRunning={isRunning && !isComplete} isPaused={isPaused}
          onRun={() => { setIsRunning(true); setIsPaused(false); setIsComplete(false); }}
          onPause={() => setIsPaused(p => !p)}
          onReset={reset}
        />
        {isComplete && <span className="text-xs font-medium text-emerald-600">✓ Complete</span>}
      </div>

      {showControls && (
        <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
          <p className="mb-3 text-xs font-medium uppercase tracking-wide text-gray-400">Parameters</p>
          <div className="grid grid-cols-1 gap-x-6 gap-y-3 sm:grid-cols-2">
            <Slider label="Gravity" unit="m/s²" value={g} min={1} max={25} step={0.1} set={setG} color="#10b981" />
            {mode === 'standard' && <>
              <Slider label="Initial velocity" unit="m/s" value={v0} min={1} max={100} step={1} set={setV0} color="#6366f1" />
              <Slider label="Launch angle" unit="°" value={angle} min={1} max={89} step={1} set={setAngle} color="#f59e0b" />
              <Slider label="Platform height" unit="m" value={h0} min={0} max={120} step={1} set={setH0} color="#8b5cf6" />
            </>}
            {mode === 'horizontal' && <>
              <Slider label="Horizontal speed" unit="m/s" value={v0} min={1} max={100} step={1} set={setV0} color="#6366f1" />
              <Slider label="Launch height" unit="m" value={hH} min={1} max={200} step={1} set={setHH} color="#8b5cf6" />
            </>}
            {mode === 'vertical' && <>
              <Slider label="Initial velocity (↑ +)" unit="m/s" value={v0} min={-30} max={50} step={1} set={setV0} color="#6366f1" />
              <Slider label="Initial height" unit="m" value={h0} min={0} max={200} step={1} set={setH0} color="#8b5cf6" />
            </>}
            {mode === 'inclined' && <>
              <Slider label="Initial velocity" unit="m/s" value={v0} min={1} max={60} step={1} set={setV0} color="#6366f1" />
              <Slider label="α — angle above slope" unit="°" value={iAlpha} min={1} max={89} step={1} set={setIAlpha} color="#f59e0b" />
              <Slider label="β — slope angle" unit="°" value={iBeta} min={5} max={60} step={1} set={setIBeta} color="#ef4444" />
              <div className="space-y-1">
                <span className="text-xs text-gray-500">Launched from</span>
                <div className="flex gap-2">
                  {(['base', 'top'] as const).map(v => (
                    <button key={v} onClick={() => setLaunchFrom(v)}
                      className={`flex-1 rounded-lg border px-2 py-1.5 text-xs font-medium transition ${
                        launchFrom === v ? 'border-indigo-300 bg-indigo-50 text-indigo-700' : 'border-gray-200 bg-white text-gray-500'
                      }`}>
                      {v === 'base' ? 'Base — up' : 'Top — down'}
                    </button>
                  ))}
                </div>
              </div>
            </>}
          </div>
        </div>
      )}

      <p className="text-center text-[10px] text-gray-400">
        Powered by{' '}
        <a href="/" target="_blank" rel="noopener noreferrer" className="font-medium text-indigo-500 hover:text-indigo-600">
          A-Factor STEM Studio
        </a>
      </p>
    </div>
  );
}

export default function ProjectileEmbedPage() {
  return (
    <Suspense fallback={<div className="p-8 text-center text-xs text-gray-400">Loading simulation…</div>}>
      <ProjectileEmbedInner />
    </Suspense>
  );
}
AFEOF

# --- src/app/embed/oscillations/page.tsx ---
cat > src/app/embed/oscillations/page.tsx << 'AFEOF'
'use client';
import { Suspense, useState, useRef, useEffect, useCallback } from 'react';
import { useSearchParams } from 'next/navigation';
import { PendulumCanvas } from '@/components/simulation/PendulumCanvas';
import { SpringCanvas } from '@/components/simulation/SpringCanvas';
import { ConicalPendulumCanvas } from '@/components/simulation/ConicalPendulumCanvas';
import { PhysicalPendulumCanvas } from '@/components/simulation/PhysicalPendulumCanvas';
import { SimulationControls } from '@/components/simulation/SimulationControls';
import { SHMGraph } from '@/components/simulation/SHMGraph';
import { pendulumOmega, springOmega, physicalPendulumPeriod } from '@/lib/physics/shm';

type Topic = 'pendulum' | 'spring' | 'conical' | 'physical';
type GraphMode = 'displacement' | 'velocity' | 'acceleration' | 'energy' | 'phase';

function num(sp: URLSearchParams, key: string, fallback: number, min: number, max: number) {
  const v = Number(sp.get(key));
  return Number.isFinite(v) && sp.get(key) !== null ? Math.min(max, Math.max(min, v)) : fallback;
}

function Slider({ label, unit, value, min, max, step, set, color }: {
  label: string; unit: string; value: number; min: number; max: number;
  step: number; set: (v: number) => void; color: string;
}) {
  return (
    <div className="space-y-1">
      <div className="flex justify-between text-xs">
        <span className="text-gray-500">{label}</span>
        <span className="font-medium tabular-nums text-gray-800">{value} <span className="font-normal text-gray-400">{unit}</span></span>
      </div>
      <input type="range" min={min} max={max} step={step} value={value}
        onChange={e => set(Number(e.target.value))} className="w-full" style={{ accentColor: color }} />
    </div>
  );
}

function OscillationsEmbedInner() {
  const sp = useSearchParams();
  const topic = ((): Topic => {
    const t = sp.get('topic');
    return t === 'spring' || t === 'conical' || t === 'physical' ? t : 'pendulum';
  })();
  const showGraph = sp.get('graph') !== '0' && topic !== 'conical';
  // Hide the parameter panel with &controls=0 for a locked, view-only embed.
  const showControls = sp.get('controls') !== '0';
  const initialGraphMode = ((): GraphMode => {
    const gmode = sp.get('gmode');
    return gmode === 'velocity' || gmode === 'acceleration' || gmode === 'energy' || gmode === 'phase'
      ? gmode : 'displacement';
  })();

  // Query params seed the INITIAL values; the sliders make the embed fully
  // interactive so viewers can explore, not just watch.
  const [pendL, setPendL] = useState(() => num(sp, 'L', 1.0, 0.1, 3));
  const [pendA, setPendA] = useState(() => num(sp, 'A', 15, 2, 30));
  const [pendG, setPendG] = useState(() => num(sp, 'g', 9.81, 1.6, 25));
  const [pendM, setPendM] = useState(() => num(sp, 'm', 0.5, 0.1, 2));
  const [spK, setSpK] = useState(() => num(sp, 'k', 50, 5, 500));
  const [spM, setSpM] = useState(() => num(sp, 'm', 1.0, 0.1, 5));
  const [spA, setSpA] = useState(() => num(sp, 'A', 0.1, 0.01, 0.3));
  const [conL, setConL] = useState(() => num(sp, 'L', 0.8, 0.2, 2));
  const [conTheta, setConTheta] = useState(() => num(sp, 'theta', 30, 5, 75));
  const [conM, setConM] = useState(() => num(sp, 'm', 0.3, 0.1, 1));
  const [physL, setPhysL] = useState(() => num(sp, 'L', 1.0, 0.2, 2));
  const [physM, setPhysM] = useState(() => num(sp, 'm', 0.5, 0.1, 2));
  const [physPF, setPhysPF] = useState(() => num(sp, 'pf', 0, 0, 0.45));

  const [isRunning, setIsRunning] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const [resetKey, setResetKey] = useState(0);
  const [graphMode, setGraphMode] = useState<GraphMode>(initialGraphMode);
  const [currentT, setCurrentT] = useState(0);

  const lastTickRef = useRef(0);
  const handleTick = (t: number) => {
    const now = performance.now();
    if (now - lastTickRef.current > 40) {
      lastTickRef.current = now;
      setCurrentT(t);
    }
  };

  const reset = useCallback(() => {
    setIsRunning(false); setIsPaused(false);
    setResetKey(k => k + 1); setCurrentT(0);
  }, []);

  // Changing any parameter stops the current run and resets.
  const resetTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  useEffect(() => {
    if (resetTimer.current) clearTimeout(resetTimer.current);
    resetTimer.current = setTimeout(reset, 80);
  }, [pendL, pendA, pendG, pendM, spK, spM, spA, conL, conTheta, conM, physL, physM, physPF, reset]);

  // Graph omega/A must match what the canvas actually animates so the live
  // dot on the curve tracks the bob/mass/rod exactly (see oscillations page).
  const physD = Math.abs(physL / 2 - physPF * physL) < 0.001 ? 0.001 : Math.abs(physL / 2 - physPF * physL);
  const physI = physM * physL * physL / 12 + physM * physD * physD;
  const physT = physicalPendulumPeriod(physI, physM, physD);
  const graphA = topic === 'pendulum' ? pendA * Math.PI / 180 * pendL :
                 topic === 'spring' ? spA :
                 topic === 'physical' ? 0.25 : 0.2;
  const graphOmega = topic === 'pendulum' ? pendulumOmega(pendL, pendG) :
                     topic === 'spring' ? springOmega(spK, spM) :
                     topic === 'physical' ? 2 * Math.PI / physT : 2;
  const graphM = topic === 'pendulum' ? pendM : topic === 'spring' ? spM :
                 topic === 'physical' ? physM : 1;
  const graphK = topic === 'pendulum' ? pendM * graphOmega * graphOmega :
                 topic === 'spring' ? spK :
                 graphM * graphOmega * graphOmega;

  return (
    <div className="mx-auto max-w-2xl space-y-3 p-3 sm:p-4">
      <div className="rounded-2xl border border-gray-200 bg-white p-3 shadow-sm">
        {topic === 'pendulum' && (
          <PendulumCanvas key={resetKey} length={pendL} amplitude={pendA} gravity={pendG} mass={pendM}
            isRunning={isRunning} isPaused={isPaused} onTick={handleTick} width={380} height={280} />
        )}
        {topic === 'spring' && (
          <SpringCanvas key={resetKey} k={spK} mass={spM} amplitude={spA}
            isRunning={isRunning} isPaused={isPaused} onTick={handleTick} width={280} height={300} />
        )}
        {topic === 'conical' && (
          <ConicalPendulumCanvas key={resetKey} length={conL} theta_deg={conTheta} mass={conM}
            isRunning={isRunning} isPaused={isPaused} width={380} height={280} />
        )}
        {topic === 'physical' && (
          <PhysicalPendulumCanvas key={resetKey} length={physL} mass={physM} pivotFraction={physPF}
            isRunning={isRunning} isPaused={isPaused} onTick={handleTick} width={380} height={280} />
        )}
      </div>

      <SimulationControls
        isRunning={isRunning} isPaused={isPaused}
        onRun={() => { setIsRunning(true); setIsPaused(false); }}
        onPause={() => setIsPaused(p => !p)}
        onReset={reset}
      />

      {showControls && (
        <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
          <p className="mb-3 text-xs font-medium uppercase tracking-wide text-gray-400">Parameters</p>
          <div className="grid grid-cols-1 gap-x-6 gap-y-3 sm:grid-cols-2">
            {topic === 'pendulum' && <>
              <Slider label="Length" unit="m" value={pendL} min={0.1} max={3} step={0.05} set={setPendL} color="#6366f1" />
              <Slider label="Amplitude" unit="°" value={pendA} min={2} max={30} step={1} set={setPendA} color="#f59e0b" />
              <Slider label="Mass" unit="kg" value={pendM} min={0.1} max={2} step={0.1} set={setPendM} color="#94a3b8" />
              <Slider label="Gravity" unit="m/s²" value={pendG} min={1.6} max={25} step={0.1} set={setPendG} color="#10b981" />
            </>}
            {topic === 'spring' && <>
              <Slider label="Spring constant k" unit="N/m" value={spK} min={5} max={500} step={5} set={setSpK} color="#6366f1" />
              <Slider label="Mass" unit="kg" value={spM} min={0.1} max={5} step={0.1} set={setSpM} color="#f59e0b" />
              <Slider label="Amplitude" unit="m" value={spA} min={0.01} max={0.3} step={0.01} set={setSpA} color="#10b981" />
            </>}
            {topic === 'conical' && <>
              <Slider label="String length" unit="m" value={conL} min={0.2} max={2} step={0.05} set={setConL} color="#6366f1" />
              <Slider label="Half-angle θ" unit="°" value={conTheta} min={5} max={75} step={1} set={setConTheta} color="#f59e0b" />
              <Slider label="Mass" unit="kg" value={conM} min={0.1} max={1} step={0.05} set={setConM} color="#10b981" />
            </>}
            {topic === 'physical' && <>
              <Slider label="Rod length" unit="m" value={physL} min={0.2} max={2} step={0.05} set={setPhysL} color="#6366f1" />
              <Slider label="Mass" unit="kg" value={physM} min={0.1} max={2} step={0.1} set={setPhysM} color="#f59e0b" />
              <Slider label="Pivot (fraction from top)" unit="" value={physPF} min={0} max={0.45} step={0.05} set={setPhysPF} color="#10b981" />
            </>}
          </div>
        </div>
      )}

      {showGraph && (
        <div className="rounded-2xl border border-gray-200 bg-white p-3 shadow-sm">
          <div className="mb-2 flex gap-1 overflow-x-auto rounded-lg bg-gray-100 p-0.5">
            {(['displacement', 'velocity', 'acceleration', 'energy', 'phase'] as GraphMode[]).map(gm => (
              <button key={gm} onClick={() => setGraphMode(gm)}
                className={`shrink-0 rounded-md px-2.5 py-1 text-[10px] font-medium transition ${
                  graphMode === gm ? 'bg-white text-indigo-700 shadow-sm' : 'text-gray-500'
                }`}>
                {gm === 'displacement' ? 'x–t' : gm === 'velocity' ? 'v–t' : gm === 'acceleration' ? 'a–t' : gm === 'energy' ? 'Energy' : 'Phase'}
              </button>
            ))}
          </div>
          <SHMGraph A={graphA} omega={graphOmega} m={graphM} k={graphK} mode={graphMode} currentT={currentT} />
        </div>
      )}

      <p className="text-center text-[10px] text-gray-400">
        Powered by{' '}
        <a href="/" target="_blank" rel="noopener noreferrer" className="font-medium text-indigo-500 hover:text-indigo-600">
          A-Factor STEM Studio
        </a>
      </p>
    </div>
  );
}

export default function OscillationsEmbedPage() {
  return (
    <Suspense fallback={<div className="p-8 text-center text-xs text-gray-400">Loading simulation…</div>}>
      <OscillationsEmbedInner />
    </Suspense>
  );
}
AFEOF

echo ""
echo "✅ Patch v2 applied!"
echo ""
echo "Next steps:"
echo "  1. rm -rf .next"
echo "  2. npm run dev"
echo "  3. SHM: run the pendulum — the coloured dot rides the curve with the"
echo "     red dashed line, in sync with the bob. Try v–t, a–t, Energy, Phase."
echo "  4. Embed: click Embed on a sim → Preview — sliders are now included."
echo "     Append &controls=0 to the URL for a view-only embed."
