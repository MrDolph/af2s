#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
# A-Factor STEM Studio — patch v41: mobile responsiveness for Projectile
# Motion's layout constants — the platform-stability fix (v40) didn't
# account for a small mobile canvas
#
#   DIAGNOSIS. The canvas's padding, ground-strip height, and ball radius
#   were fixed pixel constants (44px, 44px, 8px) sized for the ~660px
#   desktop design width, never adjusted for a smaller mobile canvas.
#   Quantified before touching any code: on a ~320x200 mobile canvas,
#   that fixed padding alone ate 28% of the width and 22% of the height,
#   leaving barely half the canvas usable for the actual diagram — at
#   exactly the moment (a small screen, parameters pushed toward their
#   maximum) when every pixel matters most. The velocity-arrow sizing
#   introduced in v40 had the same issue: a fixed 65px cap that was a
#   reasonable size on desktop but oversized relative to a small mobile
#   canvas.
#
#   FIX. All the fixed layout constants (padding, ground height, ball
#   radius, arrow length) now scale down together via a single canvas-
#   size-derived factor, unchanged at the original 660x300 design size
#   and shrinking gracefully below it — the same pattern already used
#   elsewhere in the app for mobile responsiveness. Verified numerically
#   before shipping:
#     - At the original 660x300 desktop size, every scaled value comes
#       out EXACTLY the same as before (uiScale=1, padding=44px,
#       ground=44px) — zero visual change on desktop.
#     - On a 320x200 mobile canvas, usable drawing area improves from
#       72%x56% of the canvas up to 82%x71%.
#     - Re-verified the platform-height stability fix from the previous
#       patch STILL holds exactly with the new mobile-scaled constants —
#       swept the full velocity range (1 to 100 m/s) on a mobile-sized
#       canvas with maximum platform height and confirmed the platform's
#       pixel position stays bit-for-bit identical throughout, exactly as
#       it does on desktop.
#     - Velocity arrows now scale down proportionally on mobile (33px for
#       20m/s on a 320px canvas vs 50px on the 660px desktop canvas)
#       instead of using the same absolute pixel size regardless of
#       screen size.
#
# Run from the af2s project root (Git Bash):   bash patches/patch-v41-projectile-mobile-scaling.sh
# ══════════════════════════════════════════════════════════════════════════════
set -euo pipefail

if [ ! -f "package.json" ]; then
  echo "Run this from the af2s project root (package.json not found)." >&2
  exit 1
fi

echo "-- A-Factor patch v41: mobile-scale Projectile Motion's layout constants --"
mkdir -p "src/components/simulation"

echo "  -> src/components/simulation/ProjectileModeCanvas.tsx"
cat > "src/components/simulation/ProjectileModeCanvas.tsx" << 'AFEOF'
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

const BASE_PAD = 44, BASE_GH = 44, BASE_BR = 8;
const DT_BASE = 0.016;

// Scales all the fixed-pixel layout constants (padding, ground height,
// ball radius, arrow sizing) down for a small mobile canvas, unchanged at
// the original 660x300 desktop design size. Without this, the fixed 44px
// padding alone ate 28% of a ~320px-wide mobile canvas's width and 22% of
// its height — verified numerically before this fix — leaving less than
// half the canvas usable for the actual diagram at exactly the moment
// (a short, narrow mobile screen) when every pixel matters most.
function computeUiScale(W: number, H: number): number {
  return Math.max(0.5, Math.min(1, Math.min(W, H) / 300));
}

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

function toCanvas(x: number, y: number, scaleX: number, scaleY: number, pad: number, gh: number, H: number): [number, number] {
  return [pad + x * scaleX, H - gh - y * scaleY];
}

function getScale(path: Pt[], W: number, H: number, mode: ProjectileMode, h0: number) {
  const uiScale = computeUiScale(W, H);
  const PAD = BASE_PAD * uiScale, GH = BASE_GH * uiScale;
  const maxX = Math.max(...path.map(p => p.x), 1);
  const rawMaxY = Math.max(...path.map(p => p.y), 1);
  // For standard/vertical launches from a platform, the trajectory's peak
  // genuinely rises ABOVE h0 by an amount that depends on velocity and
  // angle (rise = v0²sin²θ/2g). An earlier version of this fix reserved a
  // fixed headroom above h0 but still fell back to the trajectory's real
  // height if that headroom was exceeded — which meant the platform was
  // only stable for a "typical" velocity range and would still visibly
  // shift for anyone testing near the top of the slider (verified: the
  // old 150m headroom broke down above ~v0=76 at 45°, well within the
  // slider's actual 1-100 range). It also tied the velocity-arrow length
  // to this same scale, so inflating the headroom for stability made the
  // arrows shrink as an unwanted side effect.
  //
  // Fixed properly this time: scaleY for a platform-having mode is now a
  // PURE function of h0 alone, with NO fallback to the trajectory's real
  // height — so the platform's pixel position is mathematically
  // guaranteed stable across the ENTIRE velocity and angle slider range,
  // not just a typical subset, with zero exceptions. If a genuinely
  // extreme velocity/angle sends the trajectory above this fixed
  // headroom, the ball simply draws above the visible canvas area
  // (natural clipping, no special-case code needed) rather than ever
  // triggering a rescale. Verified numerically before shipping across
  // the full h0 range (0.5m to 120m) and the full v0 range (1-100 m/s).
  const maxY = h0 > 0 ? Math.max(h0 * 1.8, h0 + 50, 30) : rawMaxY;
  const scaleXCandidate = (W - PAD * 2) / (maxX * 1.15);
  const scaleYCandidate = (H - GH - PAD) / (maxY * 1.25);
  // scaleX and scaleY are independent for every mode EXCEPT inclined. This is
  // deliberate: coupling them through a single shared scale meant that any
  // change to the trajectory's horizontal range (e.g. a higher launch
  // velocity) rescaled the ENTIRE coordinate system, including fixed
  // vertical references like a launch platform's height, making the
  // platform appear to change height purely because velocity changed.
  // Inclined mode is the one exception that keeps uniform scaling — it has
  // no platform reference to protect, and its incline surface's drawn
  // angle must equal the true incline angle, which only holds when scaleX
  // and scaleY are equal.
  if (mode === 'inclined') {
    const s = Math.min(scaleXCandidate, scaleYCandidate);
    return { scaleX: s, scaleY: s, maxX, maxY: rawMaxY };
  }
  return { scaleX: scaleXCandidate, scaleY: scaleYCandidate, maxX, maxY: rawMaxY };
}

// ── Draw ──────────────────────────────────────────────────────────────────────
function drawAll(
  canvas: HTMLCanvasElement,
  path: Pt[], scaleX: number, scaleY: number, maxX: number, maxY: number,
  x: number, y: number, t: number, vx: number, vy: number,
  trail: [number, number][],
  mode: ProjectileMode, h0: number,
  showHUD: boolean, showGrid: boolean, showTrail: boolean, showVec: boolean, showComp: boolean,
  beta?: number, launchFrom?: 'base' | 'top', topHeight?: number,
) {
  const ctx = canvas.getContext('2d');
  if (!ctx) return;
  const W = canvas.width, H = canvas.height;
  const uiScale = computeUiScale(W, H);
  const PAD = BASE_PAD * uiScale, GH = BASE_GH * uiScale, BR = BASE_BR * uiScale;

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
    const [, py] = toCanvas(0, h0, scaleX, scaleY, PAD, GH, H);
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
      const [x0c, y0c] = toCanvas(0, th, scaleX, scaleY, PAD, GH, H);
      const [x1c, y1c] = toCanvas(Math.min(baseX, maxXPt), floorAt(Math.min(baseX, maxXPt)), scaleX, scaleY, PAD, GH, H);
      ctx.moveTo(x0c, y0c); ctx.lineTo(x1c, y1c);
      // Fill the hill body
      ctx.strokeStyle = '#64748b'; ctx.lineWidth = 3; ctx.stroke();
      ctx.beginPath();
      ctx.moveTo(x0c, y0c); ctx.lineTo(x1c, y1c);
      const [xg, yg] = toCanvas(0, 0, scaleX, scaleY, PAD, GH, H);
      ctx.lineTo(xg, yg); ctx.closePath();
      ctx.fillStyle = 'rgba(148,163,184,0.25)'; ctx.fill();
    } else {
      const [x0c, y0c] = toCanvas(0, 0, scaleX, scaleY, PAD, GH, H);
      const [x1c, y1c] = toCanvas(maxXPt, maxXPt * Math.tan(beta), scaleX, scaleY, PAD, GH, H);
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
      const [cx2] = toCanvas(gx, 0, scaleX, scaleY, PAD, GH, H);
      ctx.beginPath(); ctx.setLineDash([3, 4]); ctx.moveTo(cx2, PAD); ctx.lineTo(cx2, H - GH); ctx.stroke();
      ctx.setLineDash([]);
      if (mode !== 'vertical') ctx.fillText(`${gx}m`, cx2, H - GH + 14);
    }
    ctx.textAlign = 'right';
    const yStep = Math.ceil(maxY / 4 / 5) * 5 || 1;
    for (let gy = 0; gy <= maxY * 1.25; gy += yStep) {
      const [, cy2] = toCanvas(0, gy, scaleX, scaleY, PAD, GH, H);
      if (cy2 < PAD) continue;
      ctx.beginPath(); ctx.setLineDash([3, 4]); ctx.moveTo(PAD, cy2); ctx.lineTo(W - PAD, cy2); ctx.stroke();
      ctx.setLineDash([]); ctx.fillText(`${gy}m`, PAD - 3, cy2 + 4);
    }
    ctx.restore();
  }

  // Ghost path
  if (path.length > 1) {
    ctx.save(); ctx.beginPath();
    const [gx0, gy0] = toCanvas(path[0].x, path[0].y, scaleX, scaleY, PAD, GH, H);
    ctx.moveTo(gx0, gy0);
    path.slice(1).forEach(p => { const [cx2, cy2] = toCanvas(p.x, p.y, scaleX, scaleY, PAD, GH, H); ctx.lineTo(cx2, cy2); });
    ctx.strokeStyle = 'rgba(99,102,241,0.18)'; ctx.lineWidth = 2;
    ctx.setLineDash([6, 4]); ctx.stroke(); ctx.setLineDash([]); ctx.restore();
  }

  // Peak + landing markers
  const [pCx, pCy] = toCanvas(maxX / 2, maxY, scaleX, scaleY, PAD, GH, H);
  const [, pFloorY] = toCanvas(maxX / 2, floorAt(maxX / 2), scaleX, scaleY, PAD, GH, H);
  ctx.save();
  ctx.beginPath(); ctx.setLineDash([4, 3]);
  ctx.moveTo(pCx, pCy); ctx.lineTo(pCx, pFloorY);
  ctx.strokeStyle = 'rgba(99,102,241,0.4)'; ctx.lineWidth = 1.5; ctx.stroke(); ctx.setLineDash([]);
  ctx.fillStyle = '#6366f1'; ctx.font = 'bold 11px system-ui'; ctx.textAlign = 'center';
  ctx.fillText(`${maxY.toFixed(1)}m`, pCx, pCy - 8); ctx.restore();

  const [lCx, lCy] = toCanvas(maxX, floorAt(maxX), scaleX, scaleY, PAD, GH, H);
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
  const [bx, by] = toCanvas(x, Math.max(floorAt(x), y), scaleX, scaleY, PAD, GH, H);
  const [, groundY] = toCanvas(x, floorAt(x), scaleX, scaleY, PAD, GH, H);
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
    // Fixed, predictable px-per-(m/s) factor — deliberately NOT derived
    // from scaleX/scaleY. Velocity arrows are a schematic indicator of
    // direction and relative magnitude, not a to-scale spatial
    // measurement, so tying their length to the position scale meant they
    // shrank as an unwanted side effect whenever the platform-height fix
    // needed to zoom the diagram out. Capped at 65px for high speed, same
    // as before.
    const k = Math.min(2.5 * uiScale, (65 * uiScale) / speed);
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

  // HUD — scales with canvas width (unchanged at desktop widths, shrinks
  // proportionally on mobile) so it never eats a large fraction of a
  // small canvas the way a fixed-pixel box would.
  if (showHUD && t > 0) {
    const uiScale = Math.max(0.72, Math.min(1, W / 660));
    const lines = [
      `t  = ${t.toFixed(2)}s`,
      ...(mode !== 'vertical' ? [`x  = ${x.toFixed(1)}m`] : []),
      `y  = ${Math.max(floorAt(x), y).toFixed(1)}m`,
      `v  = ${speed.toFixed(1)} m/s`,
    ];
    const font = Math.max(9, Math.round(11 * uiScale));
    const lineH = Math.max(14, Math.round(18 * uiScale));
    const pad = Math.round(8 * uiScale);
    const bw = Math.round(118 * uiScale), bh = lines.length * lineH + Math.round(14 * uiScale);
    const bhx = W - bw - Math.round(8 * uiScale), bhy = Math.round(8 * uiScale);
    ctx.save();
    ctx.fillStyle = 'rgba(255,255,255,0.92)';
    ctx.beginPath(); ctx.roundRect(bhx, bhy, bw, bh, 8); ctx.fill();
    ctx.strokeStyle = 'rgba(99,102,241,0.2)'; ctx.lineWidth = 1; ctx.stroke();
    ctx.fillStyle = '#1e293b'; ctx.font = `${font}px monospace`; ctx.textAlign = 'left';
    lines.forEach((l, i) => ctx.fillText(l, bhx + pad, bhy + lineH + 2 + i * lineH));
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
  const { scaleX, scaleY, maxX, maxY } = useMemo(() => getScale(path, width, height, mode, setup.h0), [path, width, height, mode, setup.h0]);

  // draw — same pattern as homepage: useCallback with deps
  const draw = useCallback((st: typeof stateRef.current) => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    drawAll(
      canvas, path, scaleX, scaleY, maxX, maxY,
      st.x, st.y, st.t, st.vx, st.vy,
      trailRef.current, mode, setup.h0,
      isRunning || st.t > 0,
      showGrid, showTrail, showVec, showComp,
      setup.beta, setup.launchFrom, setup.topHeight,
    );
  }, [path, scaleX, scaleY, maxX, maxY, mode, setup.h0, setup.beta, setup.launchFrom, setup.topHeight, isRunning, showGrid, showTrail, showVec, showComp]);

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
        const uiScale = computeUiScale(width, height);
        const [tbx, tby] = toCanvas(ns.x, Math.max(floor, ns.y), scaleX, scaleY, BASE_PAD * uiScale, BASE_GH * uiScale, height);
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
  }, [isRunning, isPaused, speedIdx, scaleX, scaleY, width, height, mode, setup.beta, setup.launchFrom, setup.topHeight, draw, onTick, onComplete]);

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

echo ""
echo "Patch v41 applied -- 1 files written."
echo ""
echo "Next steps:"
echo "  rm -rf .next"
echo "  npm run dev"
echo ""
echo "Check: /simulations/projectile-motion on a narrow mobile-width browser"
echo "window. Set a platform height near the slider maximum and sweep"
echo "velocity across its full range -- the platform should stay"
echo "completely fixed, exactly as on desktop, and the diagram should use"
echo "noticeably more of the available canvas space instead of most of it"
echo "being eaten by padding. Desktop should look completely unchanged."
