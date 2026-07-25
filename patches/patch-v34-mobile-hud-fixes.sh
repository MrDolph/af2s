#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
# A-Factor STEM Studio — patch v34: mobile responsiveness pass 1 — fix
# on-canvas stat/HUD overlays that were fixed-pixel-sized and could cover
# a large fraction of a small mobile canvas
#
#   AUDIT. Searched every one of the app's 55 simulation canvases for
#   on-canvas "scorecard" style overlays — stat/HUD boxes and info panels
#   drawn as a filled rectangle with several lines of text inside — using
#   several different grep patterns (forEach-based line loops, explicit
#   for-loops, roundRect usage) to make sure nothing was missed. Found
#   five genuine offenders, all using fixed pixel widths/positions
#   regardless of the canvas's actual (responsive) size:
#
#     - ProjectileCanvas (homepage): a 126px-wide, 6-line HUD box — on a
#       ~340px mobile canvas that's over a third of the width.
#     - ProjectileModeCanvas: the same class of HUD, 118px wide.
#     - ElasticityCanvas: a 236x134px info card — roughly 70% of a
#       typical mobile canvas's width.
#     - EclipseCanvas: the "View from Earth" inset box, fixed-size
#       regardless of canvas dimensions (its astronomical bodies were
#       already made responsive in an earlier patch, but the inset box
#       itself was not).
#     - PropulsionCanvas: a 4-line HUD with a fixed font size that
#       doesn't shrink on a short mobile canvas.
#
#   FIX. Each now scales its box size, font size, and line height by a
#   canvas-width-derived scale factor, floored at a legible minimum.
#   Verified numerically before shipping that:
#     - Every box's fraction of canvas width/height stays in a reasonable
#       range (roughly 9-33%) across mobile through desktop sizes.
#     - Desktop-width canvases (>=660px) render at essentially the exact
#       original size — this is a mobile fix, not a redesign, and
#       shouldn't be visible at all on larger screens.
#     - Where a box had more lines than comfortably fit a narrow canvas
#       (Projectile's vx/vy breakdown, Elasticity's strain/Young's-modulus
#       rows), the non-essential lines are dropped below a width
#       threshold rather than cramming smaller text.
#
#   SCOPE NOTE. This is the first pass, covering every confirmed instance
#   of the specific "stat box covering the diagram" pattern found across
#   all 55 canvases. It does not yet cover every possible mobile
#   proportion issue in every canvas (e.g. some physics-apparatus
#   diagrams like the X-ray tube have fixed margins that could look
#   cramped, though they don't cover other content the way a stat box
#   does) — a broader pass on general mobile proportions is a larger,
#   separate undertaking.
#
# Run from the af2s project root (Git Bash):   bash patches/patch-v34-mobile-hud-fixes.sh
# ══════════════════════════════════════════════════════════════════════════════
set -euo pipefail

if [ ! -f "package.json" ]; then
  echo "Run this from the af2s project root (package.json not found)." >&2
  exit 1
fi

echo "-- A-Factor patch v34: mobile responsiveness pass 1 -- HUD/inset fixes --"
mkdir -p "src/components/simulation"

echo "  -> src/components/simulation/ProjectileCanvas.tsx"
cat > "src/components/simulation/ProjectileCanvas.tsx" << 'AFEOF'
'use client';
import { useEffect, useRef, useState } from 'react';
import {
  getInitialProjectileState,
  stepProjectile,
  getProjectileAnalytics,
  generateTrajectoryPath,
} from '@/lib/physics/projectile';
import type { ProjectileParams, ProjectileState } from '@/lib/physics/projectile';
import type { GraphDataPoint } from '@/types/simulation';

interface ProjectileCanvasProps {
  params: ProjectileParams;
  isRunning: boolean;
  isPaused: boolean;
  onTick?: (s: ProjectileState) => void;
  onComplete?: (path: GraphDataPoint[]) => void;
  width?: number;
  height?: number;
}

interface CanvasToggles {
  ghostTrajectory: boolean;
  velocityVector: boolean;
  vxComponent: boolean;
  vyComponent: boolean;
  peakMarker: boolean;
  landingMarker: boolean;
  grid: boolean;
  hud: boolean;
  trail: boolean;
}

const DEFAULT_TOGGLES: CanvasToggles = {
  ghostTrajectory: true,
  velocityVector: true,
  vxComponent: true,
  vyComponent: true,
  peakMarker: true,
  landingMarker: true,
  grid: true,
  hud: true,
  trail: true,
};

const TOGGLE_LABELS: Record<keyof CanvasToggles, string> = {
  ghostTrajectory: 'Ghost path',
  velocityVector: 'Velocity (v)',
  vxComponent: 'Horizontal (vx)',
  vyComponent: 'Vertical (vy)',
  peakMarker: 'Peak marker',
  landingMarker: 'Landing marker',
  grid: 'Grid',
  hud: 'Live HUD',
  trail: 'Trail',
};

// Speed slider steps — frames to skip per animation frame (higher = slower)
const SPEED_STEPS = [
  { label: '0.25×', stepsPerFrame: 1, dt: 0.012 },
  { label: '0.5×',  stepsPerFrame: 1, dt: 0.025 },
  { label: '1×',    stepsPerFrame: 2, dt: 0.025 },
  { label: '2×',    stepsPerFrame: 4, dt: 0.025 },
  { label: '4×',    stepsPerFrame: 8, dt: 0.025 },
];

const GROUND_HEIGHT = 48;
const PADDING = 48;
const BALL_RADIUS = 8;

function getScale(cW: number, cH: number, maxR: number, maxH: number) {
  return Math.min(
    (cW - PADDING * 2) / (maxR * 1.1),
    (cH - GROUND_HEIGHT - PADDING * 2) / (maxH * 1.2)
  );
}

function toCanvas(x: number, y: number, scale: number, cH: number): [number, number] {
  return [PADDING + x * scale, cH - GROUND_HEIGHT - y * scale];
}

function drawArrow(
  ctx: CanvasRenderingContext2D,
  fromX: number, fromY: number,
  toX: number, toY: number,
  color: string,
  label: string
) {
  const dx = toX - fromX;
  const dy = toY - fromY;
  const len = Math.sqrt(dx * dx + dy * dy);
  if (len < 4) return;

  const angle = Math.atan2(dy, dx);
  ctx.save();
  ctx.beginPath();
  ctx.moveTo(fromX, fromY);
  ctx.lineTo(toX, toY);
  ctx.strokeStyle = color;
  ctx.lineWidth = 2.5;
  ctx.stroke();

  // Arrowhead
  const hL = 9, hA = 0.4;
  ctx.beginPath();
  ctx.moveTo(toX, toY);
  ctx.lineTo(toX - hL * Math.cos(angle - hA), toY - hL * Math.sin(angle - hA));
  ctx.lineTo(toX - hL * Math.cos(angle + hA), toY - hL * Math.sin(angle + hA));
  ctx.closePath();
  ctx.fillStyle = color;
  ctx.fill();

  // Label beside midpoint
  const midX = (fromX + toX) / 2;
  const midY = (fromY + toY) / 2;
  ctx.fillStyle = color;
  ctx.font = 'bold 10px system-ui';
  ctx.textAlign = 'center';
  // Offset label perpendicular to arrow so it doesn't overlap the line
  const perpX = -Math.sin(angle) * 13;
  const perpY =  Math.cos(angle) * 13;
  ctx.fillText(label, midX + perpX, midY + perpY);
  ctx.restore();
}

function drawScene(
  canvas: HTMLCanvasElement,
  state: ProjectileState,
  trail: [number, number][],
  fullPath: GraphDataPoint[],
  scale: number,
  analytics: { maxRange: number; maxHeight: number },
  toggles: CanvasToggles,
  showHUD: boolean
) {
  const ctx = canvas.getContext('2d');
  if (!ctx) return;
  const w = canvas.width;
  const h = canvas.height;

  ctx.clearRect(0, 0, w, h);

  // Sky gradient
  const sky = ctx.createLinearGradient(0, 0, 0, h - GROUND_HEIGHT);
  sky.addColorStop(0, '#dbeafe');
  sky.addColorStop(1, '#f0f6ff');
  ctx.fillStyle = sky;
  ctx.fillRect(0, 0, w, h - GROUND_HEIGHT);

  // Ground
  ctx.fillStyle = '#e2e8f0';
  ctx.fillRect(0, h - GROUND_HEIGHT, w, GROUND_HEIGHT);
  ctx.beginPath();
  ctx.moveTo(0, h - GROUND_HEIGHT);
  ctx.lineTo(w, h - GROUND_HEIGHT);
  ctx.strokeStyle = '#94a3b8';
  ctx.lineWidth = 2;
  ctx.stroke();

  // Grid
  if (toggles.grid) {
    ctx.save();
    ctx.strokeStyle = '#e2e8f0';
    ctx.lineWidth = 1;
    ctx.fillStyle = '#94a3b8';
    ctx.font = '11px system-ui, sans-serif';
    const xStep = Math.ceil(analytics.maxRange / 6 / 5) * 5 || 1;
    ctx.textAlign = 'center';
    for (let x = 0; x <= analytics.maxRange * 1.1; x += xStep) {
      const [cx] = toCanvas(x, 0, scale, h);
      ctx.beginPath(); ctx.setLineDash([3, 4]);
      ctx.moveTo(cx, PADDING); ctx.lineTo(cx, h - GROUND_HEIGHT); ctx.stroke();
      ctx.setLineDash([]);
      ctx.fillText(`${x}m`, cx, h - GROUND_HEIGHT + 16);
    }
    ctx.textAlign = 'right';
    const yStep = Math.ceil(analytics.maxHeight / 4 / 5) * 5 || 1;
    for (let y = 0; y <= analytics.maxHeight * 1.2; y += yStep) {
      const [, cy] = toCanvas(0, y, scale, h);
      if (cy < PADDING) continue;
      ctx.beginPath(); ctx.setLineDash([3, 4]);
      ctx.moveTo(PADDING, cy); ctx.lineTo(w - PADDING, cy); ctx.stroke();
      ctx.setLineDash([]);
      ctx.fillText(`${y}m`, PADDING - 6, cy + 4);
    }
    ctx.restore();
  }

  // Ghost trajectory
  if (toggles.ghostTrajectory && fullPath.length > 1) {
    ctx.save();
    ctx.beginPath();
    const [x0, y0] = toCanvas(fullPath[0].x, fullPath[0].y, scale, h);
    ctx.moveTo(x0, y0);
    fullPath.slice(1).forEach(p => {
      const [cx, cy] = toCanvas(p.x, p.y, scale, h);
      ctx.lineTo(cx, cy);
    });
    ctx.strokeStyle = 'rgba(99,102,241,0.18)';
    ctx.lineWidth = 2;
    ctx.setLineDash([6, 4]);
    ctx.stroke();
    ctx.setLineDash([]);
    ctx.restore();
  }

  // Peak marker
  if (toggles.peakMarker) {
    const [pCx, pCy] = toCanvas(analytics.maxRange / 2, analytics.maxHeight, scale, h);
    ctx.save();
    ctx.beginPath(); ctx.setLineDash([4, 3]);
    ctx.moveTo(pCx, pCy); ctx.lineTo(pCx, h - GROUND_HEIGHT);
    ctx.strokeStyle = 'rgba(99,102,241,0.4)'; ctx.lineWidth = 1.5; ctx.stroke();
    ctx.setLineDash([]);
    ctx.fillStyle = '#6366f1'; ctx.font = 'bold 11px system-ui';
    ctx.textAlign = 'center';
    ctx.fillText(`${analytics.maxHeight.toFixed(1)}m`, pCx, pCy - 10);
    ctx.restore();
  }

  // Landing marker
  if (toggles.landingMarker) {
    const [lCx] = toCanvas(analytics.maxRange, 0, scale, h);
    ctx.save();
    ctx.beginPath(); ctx.arc(lCx, h - GROUND_HEIGHT, 5, 0, Math.PI * 2);
    ctx.fillStyle = '#10b981'; ctx.fill();
    ctx.fillStyle = '#10b981'; ctx.font = 'bold 11px system-ui';
    ctx.textAlign = 'center';
    ctx.fillText(`${analytics.maxRange.toFixed(1)}m`, lCx, h - GROUND_HEIGHT + 32);
    ctx.restore();
  }

  // Trail
  if (toggles.trail && trail.length > 1) {
    ctx.save();
    for (let i = 1; i < trail.length; i++) {
      const alpha = i / trail.length;
      ctx.beginPath();
      ctx.moveTo(trail[i - 1][0], trail[i - 1][1]);
      ctx.lineTo(trail[i][0], trail[i][1]);
      ctx.strokeStyle = `rgba(99,102,241,${alpha * 0.8})`;
      ctx.lineWidth = 2.5;
      ctx.stroke();
    }
    ctx.restore();
  }

  // Ball position
  const [cx, cy] = toCanvas(state.x, Math.max(0, state.y), scale, h);

  // Shadow
  ctx.save();
  ctx.beginPath();
  ctx.ellipse(cx, h - GROUND_HEIGHT + 6, 10, 4, 0, 0, Math.PI * 2);
  ctx.fillStyle = 'rgba(0,0,0,0.12)'; ctx.fill();

  // Glow
  const glow = ctx.createRadialGradient(cx, cy, 0, cx, cy, BALL_RADIUS * 2.5);
  glow.addColorStop(0, 'rgba(79,70,229,0.3)'); glow.addColorStop(1, 'transparent');
  ctx.beginPath(); ctx.arc(cx, cy, BALL_RADIUS * 2.5, 0, Math.PI * 2);
  ctx.fillStyle = glow; ctx.fill();

  // Ball body
  const ballG = ctx.createRadialGradient(cx - 2, cy - 2, 1, cx, cy, BALL_RADIUS);
  ballG.addColorStop(0, '#818cf8'); ballG.addColorStop(1, '#4f46e5');
  ctx.beginPath(); ctx.arc(cx, cy, BALL_RADIUS, 0, Math.PI * 2);
  ctx.fillStyle = ballG; ctx.fill();
  ctx.restore();

  // ── Velocity vectors ───────────────────────────────────────────────────────
  const speed = Math.sqrt(state.vx * state.vx + state.vy * state.vy);
  const ARROW_SCALE = Math.min(scale * 0.6, 4); // pixels per m/s

  // Resultant velocity vector (v)
  if (toggles.velocityVector && speed > 0.5) {
    const angle = Math.atan2(-state.vy, state.vx);
    const arrowLen = Math.min(speed * ARROW_SCALE, 70);
    drawArrow(
      ctx,
      cx, cy,
      cx + Math.cos(angle) * arrowLen,
      cy + Math.sin(angle) * arrowLen,
      '#f59e0b',
      `v=${speed.toFixed(1)}`
    );
  }

  // Horizontal component (vx) — drawn from ball rightward
  if (toggles.vxComponent && Math.abs(state.vx) > 0.1) {
    const vxLen = Math.min(Math.abs(state.vx) * ARROW_SCALE, 60);
    drawArrow(
      ctx,
      cx, cy,
      cx + vxLen, cy,        // always horizontal
      '#10b981',
      `vx=${state.vx.toFixed(1)}`
    );
  }

  // Vertical component (vy) — drawn from ball upward/downward
  if (toggles.vyComponent && Math.abs(state.vy) > 0.1) {
    const vyLen = Math.min(Math.abs(state.vy) * ARROW_SCALE, 60);
    const vyDir = state.vy > 0 ? -1 : 1; // canvas y is inverted
    drawArrow(
      ctx,
      cx, cy,
      cx, cy + vyDir * vyLen,
      '#ef4444',
      `vy=${state.vy.toFixed(1)}`
    );
  }

  // HUD — scales with canvas width so it never eats a huge fraction of a
  // small mobile canvas the way a fixed-pixel box would. Desktop-width
  // canvases (w>=660) get exactly the original size; narrower ones shrink
  // the box/font and drop the vx/vy breakdown to save space.
  if (toggles.hud && showHUD) {
    const uiScale = Math.max(0.72, Math.min(1, w / 660));
    const compact = w < 380;
    const lines = [
      `t  = ${state.time.toFixed(2)}s`,
      `v  = ${speed.toFixed(1)} m/s`,
      ...(compact ? [] : [`vx = ${state.vx.toFixed(1)} m/s`, `vy = ${state.vy.toFixed(1)} m/s`]),
      `h  = ${Math.max(0, state.y).toFixed(1)}m`,
      `x  = ${state.x.toFixed(1)}m`,
    ];
    const font = Math.max(9, Math.round(11 * uiScale));
    const lineH = Math.max(14, Math.round(18 * uiScale));
    const pad = Math.round(10 * uiScale);
    const bW = Math.round((compact ? 96 : 126) * uiScale);
    const bH = lines.length * lineH + Math.round(14 * uiScale);
    const bx = w - bW - Math.round(12 * uiScale), by = Math.round(12 * uiScale);
    ctx.save();
    ctx.fillStyle = 'rgba(255,255,255,0.92)';
    ctx.beginPath(); ctx.roundRect(bx, by, bW, bH, 8); ctx.fill();
    ctx.strokeStyle = 'rgba(99,102,241,0.25)'; ctx.lineWidth = 1; ctx.stroke();
    ctx.fillStyle = '#1e293b'; ctx.font = `${font}px monospace`; ctx.textAlign = 'left';
    lines.forEach((l, i) => ctx.fillText(l, bx + pad, by + lineH + 2 + i * lineH));
    ctx.restore();
  }
}

export function ProjectileCanvas({
  params,
  isRunning,
  isPaused,
  onTick,
  onComplete,
  width = 720,
  height = 380,
}: ProjectileCanvasProps) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const rafRef = useRef<number>(0);
  const [toggles, setToggles] = useState<CanvasToggles>(DEFAULT_TOGGLES);
  const [showToggles, setShowToggles] = useState(false);
  const [speedIndex, setSpeedIndex] = useState(1); // default 0.5×

  const sim = useRef({
    state: getInitialProjectileState(params),
    trail: [] as [number, number][],
    completed: false,
    analytics: getProjectileAnalytics(params),
    fullPath: generateTrajectoryPath(params),
    scale: 1,
    params, isRunning, isPaused, onTick, onComplete,
    toggles, width, height,
    speedIndex,
  });

  // Keep mirrors fresh every render
  sim.current.params      = params;
  sim.current.isRunning   = isRunning;
  sim.current.isPaused    = isPaused;
  sim.current.onTick      = onTick;
  sim.current.onComplete  = onComplete;
  sim.current.toggles     = toggles;
  sim.current.width       = width;
  sim.current.height      = height;
  sim.current.speedIndex  = speedIndex;
  sim.current.scale       = getScale(width, height, sim.current.analytics.maxRange, sim.current.analytics.maxHeight);

  // Initialise on mount (key={resetKey} in parent guarantees fresh mount on Reset)
  useEffect(() => {
    const s = sim.current;
    s.analytics = getProjectileAnalytics(params);
    s.fullPath  = generateTrajectoryPath(params);
    s.scale     = getScale(width, height, s.analytics.maxRange, s.analytics.maxHeight);
    s.state     = getInitialProjectileState(params);
    s.trail     = [];
    s.completed = false;
    const canvas = canvasRef.current;
    if (canvas) {
      drawScene(canvas, s.state, [], s.fullPath, s.scale, s.analytics, s.toggles, false);
    }
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // Single persistent RAF loop
  useEffect(() => {
    const loop = () => {
      const s = sim.current;
      const { stepsPerFrame, dt } = SPEED_STEPS[s.speedIndex];

      if (s.isRunning && !s.isPaused && !s.completed) {
        for (let i = 0; i < stepsPerFrame; i++) {
          s.state = stepProjectile(s.state, s.params, dt);
          const [bx, by] = toCanvas(s.state.x, Math.max(0, s.state.y), s.scale, s.height);
          s.trail.push([bx, by]);
          if (s.trail.length > 180) s.trail.shift();
          if (s.state.y < 0 || s.state.time > 100) {
            s.completed = true;
            s.onComplete?.(s.fullPath);
            break;
          }
        }
        s.onTick?.(s.state);
      }

      const canvas = canvasRef.current;
      if (canvas) {
        drawScene(
          canvas, s.state, s.trail, s.fullPath,
          s.scale, s.analytics, s.toggles,
          s.isRunning || s.state.time > 0
        );
      }
      rafRef.current = requestAnimationFrame(loop);
    };

    rafRef.current = requestAnimationFrame(loop);
    return () => cancelAnimationFrame(rafRef.current);
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const toggleItem = (key: keyof CanvasToggles) =>
    setToggles(prev => ({ ...prev, [key]: !prev[key] }));

  return (
    <div className="space-y-2">
      {/* Toolbar */}
      <div className="flex items-center gap-2 flex-wrap">
        {/* Overlays toggle */}
        <button
          onClick={() => setShowToggles(v => !v)}
          className="flex items-center gap-1.5 rounded-lg border border-gray-200 bg-white px-3 py-1.5 text-xs font-medium text-gray-600 hover:bg-gray-50 transition"
        >
          <svg width="12" height="12" viewBox="0 0 12 12" fill="none" stroke="currentColor" strokeWidth="1.5">
            <circle cx="6" cy="6" r="2"/>
            <path d="M6 1v1M6 10v1M1 6h1M10 6h1"/>
          </svg>
          Overlays
        </button>

        {/* Speed control */}
        <div className="flex items-center gap-1 rounded-lg border border-gray-200 bg-white px-2 py-1">
          <span className="text-[10px] text-gray-400 mr-1">Speed</span>
          {SPEED_STEPS.map((s, i) => (
            <button
              key={s.label}
              onClick={() => setSpeedIndex(i)}
              className={`rounded px-2 py-0.5 text-[11px] font-medium transition ${
                speedIndex === i
                  ? 'bg-indigo-600 text-white'
                  : 'text-gray-500 hover:bg-gray-100'
              }`}
            >
              {s.label}
            </button>
          ))}
        </div>

        {/* Vector legend */}
        <div className="flex items-center gap-2 ml-auto text-[10px] font-medium">
          <span className="flex items-center gap-1">
            <span className="inline-block w-3 h-0.5 bg-amber-400 rounded"/>
            <span className="text-gray-500">v</span>
          </span>
          <span className="flex items-center gap-1">
            <span className="inline-block w-3 h-0.5 bg-emerald-500 rounded"/>
            <span className="text-gray-500">vx</span>
          </span>
          <span className="flex items-center gap-1">
            <span className="inline-block w-3 h-0.5 bg-red-400 rounded"/>
            <span className="text-gray-500">vy</span>
          </span>
        </div>
      </div>

      {/* Overlay pills */}
      {showToggles && (
        <div className="flex flex-wrap gap-2">
          {(Object.keys(DEFAULT_TOGGLES) as (keyof CanvasToggles)[]).map(key => (
            <button
              key={key}
              onClick={() => toggleItem(key)}
              className={`rounded-full px-3 py-1 text-xs font-medium border transition ${
                toggles[key]
                  ? 'bg-indigo-600 text-white border-indigo-600'
                  : 'bg-white text-gray-400 border-gray-200 hover:border-gray-300'
              }`}
            >
              {TOGGLE_LABELS[key]}
            </button>
          ))}
        </div>
      )}

      {/* Canvas — no overlay banner */}
      <div className="relative w-full overflow-hidden rounded-xl border border-gray-200 bg-white shadow-sm">
        <canvas
          ref={canvasRef}
          width={width}
          height={height}
          className="w-full"
          style={{ display: 'block' }}
        />
      </div>
    </div>
  );
}
AFEOF

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

echo "  -> src/components/simulation/ElasticityCanvas.tsx"
cat > "src/components/simulation/ElasticityCanvas.tsx" << 'AFEOF'
'use client';
import { useRef, useEffect, useCallback } from 'react';
import { plasticExtension, permanentSet, springStepResponse, springEnergy, wireExtension, stress, strain, G } from '@/lib/physics/elasticity';

export type ElasticityMode = 'hooke' | 'wire';

interface Props {
  mode: ElasticityMode;
  load: number;          // N
  k: number;              // N/m (hooke mode)
  elasticLimitF: number;
  // wire mode:
  wireLength: number;     // m
  wireDiamMm: number;     // mm
  youngE: number;         // Pa
  materialName: string;
  breakingStressMPa: number;
  isRunning: boolean; isPaused: boolean;
  unloadKey: number;      // increments to trigger "remove load" (hooke, once settled)
  onSettled?: () => void;
  onBroken?: () => void;
  width?: number; height?: number;
}

type HookePhase = 'unloaded' | 'settling' | 'settled' | 'unloading' | 'recovered' | 'permanent';
type WirePhase = 'unloaded' | 'stretching' | 'stretched' | 'breaking' | 'broken';

function drawCoil(ctx: CanvasRenderingContext2D, x: number, yTop: number, len: number, coils = 10, r = 16) {
  ctx.save();
  ctx.strokeStyle = '#64748b'; ctx.lineWidth = 2.5; ctx.lineJoin = 'round';
  ctx.beginPath();
  ctx.moveTo(x, yTop);
  const seg = len / (coils + 1);
  ctx.lineTo(x, yTop + seg / 2);
  for (let i = 0; i < coils; i++) {
    ctx.lineTo(x + (i % 2 === 0 ? r : -r), yTop + seg / 2 + seg * i + seg / 2);
  }
  ctx.lineTo(x, yTop + len - seg / 2);
  ctx.lineTo(x, yTop + len);
  ctx.stroke();
  ctx.restore();
}

function easeOutCubic(x: number) { return 1 - Math.pow(1 - Math.min(Math.max(x, 0), 1), 3); }

export function ElasticityCanvas({
  mode, load, k, elasticLimitF, wireLength, wireDiamMm, youngE, materialName, breakingStressMPa,
  isRunning, isPaused, unloadKey, onSettled, onBroken, width = 640, height = 320,
}: Props) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const rafRef = useRef<number>(0);
  const lastFrameRef = useRef<number | null>(null);
  const t = useRef(0);            // time since the current phase began
  const hookePhase = useRef<HookePhase>('unloaded');
  const wirePhase = useRef<WirePhase>('unloaded');
  const eAtPhaseStart = useRef(0); // extension when the current phase began (for the unloading leg)
  const lastUnloadKey = useRef(unloadKey);
  const settledFired = useRef(false);
  const brokenFired = useRef(false);
  const sim = useRef({
    mode, load, k, elasticLimitF, wireLength, wireDiamMm, youngE, materialName, breakingStressMPa,
    isRunning, isPaused, onSettled, onBroken,
  });
  sim.current = {
    mode, load, k, elasticLimitF, wireLength, wireDiamMm, youngE, materialName, breakingStressMPa,
    isRunning, isPaused, onSettled, onBroken,
  };

  // Physics parameters change -> start over from unloaded.
  useEffect(() => {
    t.current = 0;
    hookePhase.current = 'unloaded';
    wirePhase.current = 'unloaded';
    eAtPhaseStart.current = 0;
    lastFrameRef.current = null;
    settledFired.current = false;
    brokenFired.current = false;
  }, [mode, load, k, elasticLimitF, wireLength, wireDiamMm, youngE, breakingStressMPa]);

  // "Remove load" trigger for the hooke mode, once settled.
  useEffect(() => {
    if (unloadKey !== lastUnloadKey.current) {
      lastUnloadKey.current = unloadKey;
      if (hookePhase.current === 'settled') {
        hookePhase.current = 'unloading';
        t.current = 0;
      }
    }
  }, [unloadKey]);

  const draw = useCallback((timestamp?: number) => {
    const canvas = canvasRef.current; if (!canvas) return;
    const ctx = canvas.getContext('2d'); if (!ctx) return;
    const s = sim.current;
    const W = canvas.width, H = canvas.height;

    let dt = 0;
    if (s.isRunning && !s.isPaused && timestamp !== undefined) {
      if (lastFrameRef.current !== null) {
        dt = Math.min((timestamp - lastFrameRef.current) / 1000, 0.1);
      }
      lastFrameRef.current = timestamp;
    } else {
      lastFrameRef.current = timestamp ?? null;
    }

    ctx.clearRect(0, 0, W, H);
    ctx.fillStyle = '#f8fafc'; ctx.fillRect(0, 0, W, H);

    // Ceiling
    ctx.fillStyle = '#cbd5e1'; ctx.fillRect(0, 20, W, 10);
    ctx.strokeStyle = '#94a3b8';
    for (let x = 6; x < W; x += 14) {
      ctx.beginPath(); ctx.moveTo(x, 20); ctx.lineTo(x - 6, 12); ctx.stroke();
    }

    if (s.mode === 'hooke') {
      const eEq = plasticExtension(s.load, s.k, s.elasticLimitF);
      const eLimit = s.elasticLimitF / s.k;
      const beyondLimit = s.load > s.elasticLimitF;
      const ePermanent = permanentSet(s.load, s.k, s.elasticLimitF);
      const mass = s.load / G;
      const zeta = 0.28;
      const omega = Math.sqrt(s.k / Math.max(mass, 0.01));
      const settleTime = 3.91 / (zeta * omega); // time for the 2% decay envelope

      // Advance the phase's local clock, and step transitions.
      if (dt > 0) {
        if (hookePhase.current === 'unloaded' && s.isRunning) {
          hookePhase.current = 'settling'; t.current = 0;
        } else {
          t.current += dt;
        }
        if (hookePhase.current === 'settling' && t.current >= settleTime) {
          hookePhase.current = 'settled';
          if (!settledFired.current) { settledFired.current = true; s.onSettled?.(); }
        }
        if (hookePhase.current === 'unloading') {
          const dropSettle = 3.91 / (zeta * omega); // same envelope shape for the release leg
          if (t.current >= dropSettle) {
            hookePhase.current = ePermanent > 0.0005 ? 'permanent' : 'recovered';
          }
        }
      }

      // Current extension as a pure function of phase + local time.
      let e: number;
      if (hookePhase.current === 'unloaded') e = 0;
      else if (hookePhase.current === 'settling') e = springStepResponse(t.current, eEq, s.k, mass, zeta);
      else if (hookePhase.current === 'settled') e = eEq;
      else if (hookePhase.current === 'unloading') {
        const drop = eEq - ePermanent;
        e = eEq - springStepResponse(t.current, drop, s.k, mass, zeta);
      } else e = ePermanent; // 'recovered' (0) or 'permanent'

      const eScale = 900; // px per metre
      const natural = 90;
      const xUnloaded = W / 2 - 130, xLoaded = W / 2 + 90;

      // Reference (unloaded) spring
      drawCoil(ctx, xUnloaded, 30, natural);
      ctx.strokeStyle = '#cbd5e1'; ctx.setLineDash([4, 4]);
      ctx.beginPath(); ctx.moveTo(xUnloaded - 60, 30 + natural); ctx.lineTo(xLoaded + 80, 30 + natural); ctx.stroke();
      ctx.setLineDash([]);
      ctx.fillStyle = '#94a3b8'; ctx.font = '10px system-ui'; ctx.textAlign = 'center';
      ctx.fillText('natural length', xUnloaded, 30 + natural + 18);

      // Loaded spring
      const stretch = Math.min(Math.max(e, 0) * eScale, H - 200);
      drawCoil(ctx, xLoaded, 30, natural + stretch);
      const showMass = hookePhase.current !== 'unloaded';
      if (showMass) {
        const mw = 56, mh = 40;
        const beyondNow = e * s.k > s.elasticLimitF + 0.01;
        ctx.fillStyle = beyondNow ? '#ef4444' : '#6366f1';
        ctx.fillRect(xLoaded - mw / 2, 30 + natural + stretch, mw, mh);
        ctx.fillStyle = 'white'; ctx.font = 'bold 11px system-ui'; ctx.textAlign = 'center';
        const shownLoad = hookePhase.current === 'unloading' || hookePhase.current === 'recovered' || hookePhase.current === 'permanent' ? 0 : s.load;
        ctx.fillText(`${shownLoad.toFixed(0)}N`, xLoaded, 30 + natural + stretch + mh / 2 + 4);
      }

      // Extension bracket
      if (stretch > 6) {
        const bx = xLoaded + 60;
        ctx.strokeStyle = '#10b981'; ctx.lineWidth = 1.5;
        ctx.beginPath(); ctx.moveTo(bx, 30 + natural); ctx.lineTo(bx, 30 + natural + stretch); ctx.stroke();
        [30 + natural, 30 + natural + stretch].forEach(y => {
          ctx.beginPath(); ctx.moveTo(bx - 4, y); ctx.lineTo(bx + 4, y); ctx.stroke();
        });
        ctx.fillStyle = '#059669'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'left';
        ctx.fillText(`e = ${(Math.max(e, 0) * 100).toFixed(1)} cm`, bx + 8, 30 + natural + stretch / 2 + 3);
      }
      // Elastic-limit marker, so the overshoot past it is visible during settling
      const limitStretch = eLimit * eScale;
      if (limitStretch > 4 && limitStretch < H - 200) {
        ctx.strokeStyle = '#f59e0b'; ctx.setLineDash([3, 3]); ctx.lineWidth = 1;
        ctx.beginPath(); ctx.moveTo(xLoaded - 40, 30 + natural + limitStretch); ctx.lineTo(xLoaded + 40, 30 + natural + limitStretch); ctx.stroke();
        ctx.setLineDash([]);
      }

      ctx.font = 'bold 11px system-ui'; ctx.textAlign = 'center';
      if (hookePhase.current === 'unloaded') {
        ctx.fillStyle = '#6366f1';
        ctx.fillText('Press Run to hang the load and watch it settle', W / 2, H - 30);
      } else if (hookePhase.current === 'settling') {
        ctx.fillStyle = '#6366f1';
        ctx.fillText('Settling — a suddenly-applied load overshoots before it damps out', W / 2, H - 30);
      } else if (hookePhase.current === 'settled' && beyondLimit) {
        ctx.fillStyle = '#ef4444';
        ctx.fillText(`BEYOND THE ELASTIC LIMIT (${s.elasticLimitF}N) — permanent deformation once unloaded`, W / 2, H - 30);
      } else if (hookePhase.current === 'settled') {
        ctx.fillStyle = '#059669';
        ctx.fillText(`Settled — energy stored = ½Fe = ${springEnergy(s.k, eEq).toFixed(2)} J`, W / 2, H - 30);
      } else if (hookePhase.current === 'unloading') {
        ctx.fillStyle = '#f59e0b';
        ctx.fillText('Load removed — recovering…', W / 2, H - 30);
      } else if (hookePhase.current === 'recovered') {
        ctx.fillStyle = '#059669';
        ctx.fillText('Fully recovered to natural length — within the elastic limit', W / 2, H - 30);
      } else {
        ctx.fillStyle = '#ef4444';
        ctx.fillText(`PERMANENT SET = ${(ePermanent * 100).toFixed(1)} cm — it never returns to natural length`, W / 2, H - 30);
      }
      ctx.fillStyle = '#64748b'; ctx.font = '10px system-ui'; ctx.textAlign = 'left';
      ctx.fillText(`k = ${s.k} N/m   equilibrium: F = ke → e = ${(eEq * 100).toFixed(1)} cm`, 8, H - 10);
    }

    if (s.mode === 'wire') {
      const A = Math.PI * Math.pow((s.wireDiamMm / 1000) / 2, 2);
      const eTarget = wireExtension(s.load, s.wireLength, A, s.youngE);
      const sg = stress(s.load, A);
      const sn = strain(eTarget, s.wireLength);
      const willBreak = sg / 1e6 > s.breakingStressMPa;
      const STRETCH_DURATION = 0.8;

      if (dt > 0) {
        if (wirePhase.current === 'unloaded' && s.isRunning) {
          wirePhase.current = willBreak ? 'breaking' : 'stretching'; t.current = 0;
        } else {
          t.current += dt;
        }
        if (wirePhase.current === 'stretching' && t.current >= STRETCH_DURATION) wirePhase.current = 'stretched';
        if (wirePhase.current === 'breaking' && t.current >= STRETCH_DURATION * 0.65) {
          wirePhase.current = 'broken';
          if (!brokenFired.current) { brokenFired.current = true; s.onBroken?.(); }
        }
      }

      const progress = wirePhase.current === 'breaking'
        ? easeOutCubic(t.current / (STRETCH_DURATION * 0.65))
        : easeOutCubic(t.current / STRETCH_DURATION);
      const e = wirePhase.current === 'unloaded' ? 0
        : wirePhase.current === 'broken' ? eTarget * 0.65
        : eTarget * Math.min(progress, 1);

      const x = W / 2 - 60;
      const naturalPx = H - 150;
      // Real extensions are fractions of a millimetre — magnified ×2000 on
      // screen so students can SEE it; true values printed below.
      const MAG = 2000;
      const stretchPx = Math.min(e * MAG, 90);

      // Reference end marker
      ctx.strokeStyle = '#cbd5e1'; ctx.setLineDash([4, 4]); ctx.lineWidth = 1;
      ctx.beginPath(); ctx.moveTo(x - 70, 30 + naturalPx); ctx.lineTo(x + 150, 30 + naturalPx); ctx.stroke();
      ctx.setLineDash([]);

      if (wirePhase.current === 'broken') {
        // Snapped: two loose ends, load fallen away.
        const breakY = 30 + naturalPx * 0.55;
        const fall = Math.min((t.current - STRETCH_DURATION * 0.65) * 260, H);
        ctx.strokeStyle = '#64748b'; ctx.lineWidth = Math.max(1.5, s.wireDiamMm * 3);
        ctx.beginPath(); ctx.moveTo(x, 30); ctx.lineTo(x - 3, breakY - 6); ctx.stroke();
        ctx.beginPath(); ctx.moveTo(x + 4, breakY + 10 + fall); ctx.lineTo(x, 30 + naturalPx + stretchPx + fall); ctx.stroke();
        const mw = 60, mh = 40;
        ctx.fillStyle = '#ef4444';
        ctx.fillRect(x - mw / 2, 30 + naturalPx + stretchPx + fall, mw, mh);
        ctx.fillStyle = 'white'; ctx.font = 'bold 11px system-ui'; ctx.textAlign = 'center';
        ctx.fillText(`${s.load.toFixed(0)}N`, x, 30 + naturalPx + stretchPx + fall + mh / 2 + 4);
        ctx.fillStyle = '#ef4444'; ctx.font = 'bold 12px system-ui';
        ctx.fillText('💥 SNAPPED', x, breakY - 16);
      } else {
        ctx.strokeStyle = '#64748b'; ctx.lineWidth = Math.max(1.5, s.wireDiamMm * 3);
        ctx.beginPath(); ctx.moveTo(x, 30); ctx.lineTo(x, 30 + naturalPx + stretchPx); ctx.stroke();
        if (wirePhase.current !== 'unloaded') {
          const mw = 60, mh = 40;
          ctx.fillStyle = '#6366f1';
          ctx.fillRect(x - mw / 2, 30 + naturalPx + stretchPx, mw, mh);
          ctx.fillStyle = 'white'; ctx.font = 'bold 11px system-ui'; ctx.textAlign = 'center';
          ctx.fillText(`${s.load.toFixed(0)}N`, x, 30 + naturalPx + stretchPx + mh / 2 + 4);
        }
        if (stretchPx > 3) {
          const bx = x + 70;
          ctx.strokeStyle = '#10b981'; ctx.lineWidth = 1.5;
          ctx.beginPath(); ctx.moveTo(bx, 30 + naturalPx); ctx.lineTo(bx, 30 + naturalPx + stretchPx); ctx.stroke();
          ctx.fillStyle = '#059669'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'left';
          ctx.fillText(`e = ${(e * 1000).toFixed(3)} mm (shown ×${MAG})`, bx + 8, 30 + naturalPx + stretchPx / 2 + 3);
        }
      }

      // Info card — scales with canvas width so it never dominates a
      // small mobile canvas the way a fixed 236x134 box would (that was
      // roughly 70% of a typical mobile canvas's width).
      ctx.save();
      const uiScale = Math.max(0.6, Math.min(1, W / 660));
      const compact = W < 420;
      const cardW = Math.round((compact ? 168 : 236) * uiScale);
      const cx0 = W - cardW - Math.round(14 * uiScale), cy0 = Math.round(46 * uiScale);
      const titleFont = Math.max(9, Math.round(11 * uiScale));
      const bodyFont = Math.max(8, Math.round(10 * uiScale));
      const lineH = Math.max(12, Math.round(16 * uiScale));
      const infoLines = [
        `L = ${s.wireLength} m,  d = ${s.wireDiamMm} mm`,
        `A = πd²/4 = ${(A * 1e6).toFixed(4)} mm²`,
        `stress σ = F/A = ${(sg / 1e6).toFixed(1)} MPa`,
        ...(compact ? [] : [`strain ε = e/L = ${sn.toExponential(2)}`, `E = σ/ε = ${(s.youngE / 1e9).toFixed(0)} GPa`]),
        `breaks at ${s.breakingStressMPa} MPa`,
      ];
      const cardH = Math.round(40 * uiScale) + infoLines.length * lineH;
      ctx.fillStyle = 'rgba(255,255,255,0.9)';
      ctx.beginPath(); ctx.roundRect(cx0, cy0, cardW, cardH, 10); ctx.fill();
      ctx.strokeStyle = '#e2e8f0'; ctx.stroke();
      ctx.fillStyle = '#334155'; ctx.font = `bold ${titleFont}px system-ui`; ctx.textAlign = 'left';
      ctx.fillText(`${s.materialName} wire`, cx0 + Math.round(12 * uiScale), cy0 + Math.round(20 * uiScale));
      ctx.font = `${bodyFont}px monospace`; ctx.fillStyle = '#475569';
      infoLines.forEach((l, i) => ctx.fillText(l, cx0 + Math.round(12 * uiScale), cy0 + Math.round(40 * uiScale) + i * lineH));
      ctx.restore();

      ctx.font = 'bold 11px system-ui'; ctx.textAlign = 'center';
      if (wirePhase.current === 'unloaded') {
        ctx.fillStyle = '#6366f1';
        ctx.fillText('Press Run to hang the load', W / 2 - 60, H - 30);
      } else if (willBreak) {
        ctx.fillStyle = '#ef4444';
        ctx.fillText(`σ = ${(sg / 1e6).toFixed(0)} MPa exceeds ${s.materialName}'s breaking stress`, W / 2 - 60, H - 30);
      }
      ctx.fillStyle = '#64748b'; ctx.font = '10px system-ui'; ctx.textAlign = 'left';
      ctx.fillText(`Young's modulus is a MATERIAL property — same E whatever the wire's size. e = FL/(AE)`, 8, H - 10);
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

echo "  -> src/components/simulation/EclipseCanvas.tsx"
cat > "src/components/simulation/EclipseCanvas.tsx" << 'AFEOF'
'use client';
import { useRef, useEffect, useCallback } from 'react';

export type EclipseType = 'solar' | 'annular' | 'lunar';

interface Props {
  eclipseType: EclipseType;
  orbitAngleDeg: number; // used as a fixed value only when not animating (paused/reset)
  isRunning: boolean; isPaused: boolean;
  onTick?: (angleDeg: number, eclipseState: 'none' | 'partial' | 'total') => void;
  width?: number; height?: number;
}

interface Vec { x: number; y: number; }
function lineAtX(p1: Vec, p2: Vec, x: number): number {
  const t = (x - p1.x) / (p2.x - p1.x);
  return p1.y + t * (p2.y - p1.y);
}

const ORBIT_PERIOD = 9;   // s — one full simulated lunar orbit, repeating continuously
const TILT_DEG = 30;      // exaggerated for visibility (real inclination ~5°) — chosen so the
                           // eclipse window is a genuinely narrow, "rare" fraction of the orbit

export function EclipseCanvas({ eclipseType, orbitAngleDeg, isRunning, isPaused, onTick, width = 660, height = 320 }: Props) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const rafRef = useRef<number>(0);
  const lastFrameRef = useRef<number | null>(null);
  const t = useRef(0);
  const sim = useRef({ eclipseType, orbitAngleDeg, isRunning, isPaused, onTick });
  sim.current = { eclipseType, orbitAngleDeg, isRunning, isPaused, onTick };

  useEffect(() => { t.current = 0; lastFrameRef.current = null; }, [eclipseType, orbitAngleDeg]);

  const draw = useCallback((timestamp?: number) => {
    const canvas = canvasRef.current; if (!canvas) return;
    const ctx = canvas.getContext('2d'); if (!ctx) return;
    const s = sim.current;
    const W = canvas.width, H = canvas.height;

    const animate = s.isRunning && !s.isPaused;
    if (animate && timestamp !== undefined) {
      if (lastFrameRef.current !== null) {
        t.current += Math.min((timestamp - lastFrameRef.current) / 1000, 0.1);
      }
      lastFrameRef.current = timestamp;
    } else {
      lastFrameRef.current = timestamp ?? null;
    }
    // The Moon genuinely orbits Earth, continuously, lap after lap — it
    // passes near alignment twice per orbit (the two nodes) and is
    // clearly off-axis the rest of the time, exactly like a real orbit.
    // Freeze at the CURRENT animated position while paused, so pausing
    // lets you inspect the view in place — only fall back to the slider's
    // static preview value when playback hasn't started at all. The
    // previous version used `animate` here (running && !paused), which
    // meant pausing snapped straight back to the slider's default value
    // instead of freezing where the orbit actually was.
    const angleDeg = s.isRunning ? ((t.current / ORBIT_PERIOD) * 360) % 360 : s.orbitAngleDeg;
    const angleRad = (angleDeg * Math.PI) / 180;
    const tiltRad = (TILT_DEG * Math.PI) / 180;

    ctx.clearRect(0, 0, W, H);
    ctx.fillStyle = '#0f172a'; ctx.fillRect(0, 0, W, H);
    ctx.fillStyle = 'rgba(255,255,255,0.4)';
    for (let i = 0; i < 40; i++) ctx.fillRect((i * 53) % W, (i * 97) % H, 1, 1);

    const midY = H / 2;
    // Every size scales with the actual canvas dimensions (bigger on a
    // wide desktop canvas, still comfortable on a narrow mobile one)
    // rather than fixed pixel constants — verified numerically to stay
    // within bounds from a small ~340x200 mobile canvas up to a wide
    // ~980x340 desktop one.
    const scale = Math.min(W / 660, H / 320);
    const sunR = 42 * scale;
    const sunX = Math.max(sunR + 15, 55 * scale);
    const earthX = W * 0.66;
    const earthR = 22 * scale;
    // The Moon appears smaller here for an annular eclipse — it really is
    // farther from Earth at these points in its slightly elliptical
    // orbit, so even perfectly aligned it can't fully cover the Sun.
    const moonR = (s.eclipseType === 'annular' ? 7 : 10) * scale;
    const maxOrbitRHorizontal = Math.min(earthX - sunX - sunR - 25, W - earthX - 25);
    const ORBIT_R = Math.max(60 * scale, Math.min(maxOrbitRHorizontal, H * 0.46));

    const moonX = earthX + ORBIT_R * Math.cos(angleRad);
    const moonY = midY + ORBIT_R * Math.sin(angleRad) * Math.sin(tiltRad);

    // Sun
    ctx.fillStyle = '#fbbf24';
    ctx.beginPath(); ctx.arc(sunX, midY, sunR, 0, Math.PI * 2); ctx.fill();
    ctx.fillStyle = '#fde68a'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
    ctx.fillText('Sun', sunX, midY + sunR + 16);

    // The Moon's actual orbital path around Earth — a real, clearly
    // visible ellipse (the projection of its tilted circular orbit), not
    // a decorative loop. This IS the orbit, drawn to scale with the
    // motion below, in both modes.
    ctx.save();
    ctx.strokeStyle = 'rgba(148,163,184,0.55)'; ctx.setLineDash([5, 4]); ctx.lineWidth = 1.3;
    ctx.beginPath();
    ctx.ellipse(earthX, midY, ORBIT_R, ORBIT_R * Math.sin(tiltRad), 0, 0, Math.PI * 2);
    ctx.stroke();
    ctx.restore();
    // The two nodes — where the tilted orbit crosses the Sun-Earth line,
    // the only points where an eclipse can happen.
    ctx.fillStyle = 'rgba(148,163,184,0.8)';
    [earthX - ORBIT_R, earthX + ORBIT_R].forEach(nx => {
      ctx.beginPath(); ctx.arc(nx, midY, 2.5, 0, Math.PI * 2); ctx.fill();
    });

    // Earth is always the target/occluder's fixed reference; the Moon is
    // always the body actually moving. Which one blocks light from the
    // other depends on which side of the orbit the Moon is currently on:
    // solar eclipse needs the Moon between the Sun and Earth; lunar
    // eclipse needs Earth between the Sun and the Moon.
    const isSunSide = s.eclipseType === 'solar' || s.eclipseType === 'annular';
    const occ = isSunSide ? { x: moonX, y: moonY, r: moonR } : { x: earthX, y: midY, r: earthR };
    const target = isSunSide ? { x: earthX, y: midY, r: earthR } : { x: moonX, y: moonY, r: moonR };

    // A ray extrapolated to the target's x is only physically meaningful
    // if the occluder genuinely sits between the Sun and the target —
    // otherwise it's just a line extrapolated the wrong way. This is what
    // correctly restricts eclipses to the Moon's near side (solar) or far
    // side (lunar) of its orbit, not both.
    const validGeometry = occ.x > sunX && target.x > occ.x;

    const srcTop: Vec = { x: sunX, y: midY - sunR }, srcBot: Vec = { x: sunX, y: midY + sunR };
    const occTop: Vec = { x: occ.x, y: occ.y - occ.r }, occBot: Vec = { x: occ.x, y: occ.y + occ.r };
    // Exactly four rays, the classic umbra/penumbra construction: the
    // same-side pair (top-to-top, bottom-to-bottom) marks the true umbra;
    // the opposite-side pair (bottom-to-top, top-to-bottom) marks the
    // penumbra's outer edge — verified by brute-force sampling in the
    // shadows simulation elsewhere in this app. Each ray is drawn all the
    // way from the Sun's edge, touching the occluder's edge, and onward
    // to where it actually lands.
    const drawRay = (from: Vec, throughPoint: Vec, color: string, dashed = false) => {
      const endY = lineAtX(from, throughPoint, target.x);
      ctx.save(); if (dashed) ctx.setLineDash([4, 3]);
      ctx.strokeStyle = color; ctx.lineWidth = 1.4;
      ctx.beginPath(); ctx.moveTo(from.x, from.y); ctx.lineTo(throughPoint.x, throughPoint.y);
      if (validGeometry) ctx.lineTo(target.x, endY);
      ctx.stroke(); ctx.restore();
    };
    drawRay(srcTop, occTop, 'rgba(96,165,250,0.75)');
    drawRay(srcBot, occBot, 'rgba(96,165,250,0.75)');
    drawRay(srcBot, occTop, 'rgba(148,163,184,0.6)', true);
    drawRay(srcTop, occBot, 'rgba(148,163,184,0.6)', true);

    // Earth
    ctx.fillStyle = '#3b82f6';
    ctx.beginPath(); ctx.arc(earthX, midY, earthR, 0, Math.PI * 2); ctx.fill();
    ctx.fillStyle = '#bfdbfe'; ctx.font = 'bold 10px system-ui';
    ctx.fillText('Earth', earthX, midY - earthR - 8);

    // Moon
    ctx.fillStyle = '#cbd5e1';
    ctx.beginPath(); ctx.arc(moonX, moonY, moonR, 0, Math.PI * 2); ctx.fill();
    ctx.fillStyle = '#e2e8f0'; ctx.font = '9px system-ui';
    ctx.fillText('Moon', moonX, moonY - moonR - 6);

    let eclipseState: 'none' | 'partial' | 'total' = 'none';
    // Lifted out of the validGeometry block so the "View from Earth" inset
    // below can reuse the EXACT same umbra/penumbra values the main
    // diagram uses to classify none/partial/total — previously the inset
    // used a completely separate calculation (raw Moon offset, no
    // validGeometry check at all), which could show a near-total-eclipse
    // picture even when the Moon was on the wrong side of its orbit
    // entirely and no eclipse was geometrically possible. Verified this
    // numerically: at the Moon's far-side node, its raw vertical offset is
    // ALSO near zero, so the old inset showed "near alignment" there too.
    let penCenterY = target.y, penRadius = 0, umbCenterY = target.y, umbRadius = 0;
    if (validGeometry) {
      const umbraTopAtTarget = lineAtX(srcTop, occTop, target.x);
      const umbraBotAtTarget = lineAtX(srcBot, occBot, target.x);
      const penTopAtTarget = lineAtX(srcBot, occTop, target.x);
      const penBotAtTarget = lineAtX(srcTop, occBot, target.x);
      // Explicit min/max rather than assuming top<bot — the boundary rays
      // can cross (converge and invert order) well before reaching the
      // target, especially for the smaller annular-eclipse Moon, and the
      // check needs to stay correct either way rather than relying on a
      // specific ray order that only coincidentally holds in some cases.
      const uLo = Math.min(umbraTopAtTarget, umbraBotAtTarget), uHi = Math.max(umbraTopAtTarget, umbraBotAtTarget);
      const pLo = Math.min(penTopAtTarget, penBotAtTarget), pHi = Math.max(penTopAtTarget, penBotAtTarget);
      penCenterY = (pLo + pHi) / 2; penRadius = (pHi - pLo) / 2;
      umbCenterY = (uLo + uHi) / 2; umbRadius = (uHi - uLo) / 2;
      const totalOverlap = uLo < target.y + target.r && uHi > target.y - target.r;
      const partialOverlap = pLo < target.y + target.r && pHi > target.y - target.r;
      eclipseState = totalOverlap ? 'total' : partialOverlap ? 'partial' : 'none';

      // Umbra and penumbra are always concentric (same centre — verified
      // numerically) so they're drawn as concentric circles clipped to
      // Earth's own disc: a genuinely small dark spot (only that part of
      // Earth sees totality) inside a larger, lighter region (partial
      // visibility), with the REST of Earth left its normal colour. A
      // full-width band — the earlier approach — made even a modest
      // vertical overlap look like most of the planet had gone dark,
      // since it stretched edge-to-edge regardless of how narrow the
      // actual umbra was.
      if (eclipseState !== 'none') {
        ctx.save();
        ctx.beginPath(); ctx.arc(target.x, target.y, target.r, 0, Math.PI * 2); ctx.clip();
        ctx.fillStyle = 'rgba(100,116,139,0.55)';
        ctx.beginPath(); ctx.arc(target.x, penCenterY, penRadius, 0, Math.PI * 2); ctx.fill();
        if (eclipseState === 'total') {
          ctx.fillStyle = 'rgba(15,23,42,0.85)';
          ctx.beginPath(); ctx.arc(target.x, umbCenterY, umbRadius, 0, Math.PI * 2); ctx.fill();
        }
        ctx.restore();
      }
    }
    s.onTick?.(angleDeg, eclipseState);

    // "View from Earth" inset — what an observer at Earth's centre would
    // actually see. Derived directly from the SAME penumbra/umbra values
    // just used above (not a separate calculation), so it can never show
    // a state that contradicts the main diagram or the classification.
    const insetR = Math.max(18, 30 * scale);
    const insetX = W - insetR - 48 * scale, insetY = H - insetR - 36 * scale;
    ctx.save();
    ctx.fillStyle = 'rgba(15,23,42,0.9)';
    ctx.beginPath(); ctx.roundRect(insetX - insetR - 10, insetY - insetR - 18, insetR * 2 + 20, insetR * 2 + 30, 8); ctx.fill();
    ctx.strokeStyle = 'rgba(148,163,184,0.4)'; ctx.stroke();
    ctx.fillStyle = '#94a3b8'; ctx.font = 'bold 9px system-ui'; ctx.textAlign = 'center';
    ctx.fillText('View from Earth', insetX, insetY - insetR - 6);
    if (isSunSide) {
      ctx.fillStyle = '#fbbf24';
      ctx.beginPath(); ctx.arc(insetX, insetY, insetR, 0, Math.PI * 2); ctx.fill();
      // Position is only meaningful once we know the classification —
      // deriving it straight from eclipseState (already correctly
      // computed above, including the validGeometry gate) rather than a
      // separately-clamped continuous formula guarantees the inset can
      // never show overlap for a "none" state or separation for a
      // "partial"/"total" one.
      const direction = target.y >= penCenterY ? 1 : -1;
      const normalizedOffset = penRadius > 0.001 ? Math.abs(target.y - penCenterY) / penRadius : 999;
      const offsetFactor = eclipseState === 'none' ? 2.4 : Math.min(1.3, normalizedOffset);
      // A total eclipse's Moon disc is almost exactly the Sun's apparent
      // size (the real "eclipse coincidence"); an annular eclipse's Moon
      // is visibly smaller, so even at perfect alignment a bright ring of
      // the Sun remains round its edge — that ring IS the whole visual
      // definition of an annular eclipse, so it has to actually show here.
      const moonInsetR = s.eclipseType === 'annular' ? insetR * 0.72 : insetR * 0.98;
      ctx.fillStyle = '#0f172a';
      ctx.beginPath(); ctx.arc(insetX, insetY + direction * offsetFactor * insetR, moonInsetR, 0, Math.PI * 2); ctx.fill();
    } else {
      const darkness = eclipseState === 'total' ? 0.75 : eclipseState === 'partial' ? 0.35 : 0.05;
      ctx.fillStyle = '#e2e8f0';
      ctx.beginPath(); ctx.arc(insetX, insetY, insetR, 0, Math.PI * 2); ctx.fill();
      ctx.fillStyle = `rgba(127,29,29,${darkness})`;
      ctx.beginPath(); ctx.arc(insetX, insetY, insetR, 0, Math.PI * 2); ctx.fill();
    }
    ctx.restore();

    ctx.font = 'bold 11px system-ui'; ctx.textAlign = 'center';
    ctx.fillStyle = eclipseState === 'total' ? '#f87171' : eclipseState === 'partial' ? '#fbbf24' : '#94a3b8';
    const bodyLabel = isSunSide ? 'Earth' : 'the Moon';
    const eclipseLabel = eclipseState === 'total'
      ? (s.eclipseType === 'solar' ? '☾ TOTAL SOLAR ECLIPSE — full Sun blocked in a small region of Earth'
        : s.eclipseType === 'annular' ? '☾ ANNULAR ECLIPSE — the Moon is too far away to fully cover the Sun, leaving a ring'
        : `🌍 TOTAL LUNAR ECLIPSE — ${bodyLabel} is fully inside Earth\u2019s umbra`)
      : eclipseState === 'partial'
      ? `PARTIAL ECLIPSE — only part of ${bodyLabel} is in shadow`
      : 'No eclipse right now — the Moon is not at a node';
    ctx.fillText(eclipseLabel, W / 2 - 40, 22);
    ctx.fillStyle = '#64748b'; ctx.font = '9px system-ui'; ctx.textAlign = 'left';
    ctx.fillText('Not to scale. Dashed ellipse = the Moon\u2019s real orbit around Earth; the dots are its two nodes.', 8, H - 8);

    rafRef.current = requestAnimationFrame(draw);
  }, []);

  useEffect(() => {
    rafRef.current = requestAnimationFrame(draw);
    return () => cancelAnimationFrame(rafRef.current);
  }, [draw]);

  return (
    <canvas ref={canvasRef} width={width} height={height}
      className="w-full rounded-xl border border-gray-200" style={{ display: 'block' }} />
  );
}
AFEOF

echo "  -> src/components/simulation/PropulsionCanvas.tsx"
cat > "src/components/simulation/PropulsionCanvas.tsx" << 'AFEOF'
'use client';
import { useRef, useEffect, useCallback } from 'react';
import { rocketStateAt, rocketBurnTime } from '@/lib/physics/consequences';

interface Props {
  rocketMass: number; fuelFraction: number; exhaustSpeed: number; massFlowRate: number;
  isRunning: boolean; isPaused: boolean;
  onTick?: (simTime: number, v: number, burnedOut: boolean) => void;
  width?: number; height?: number;
}

const TARGET_REAL_SECONDS = 18; // any slider combination plays out in about this long

interface Star { x: number; y: number; speed: number; }

export function PropulsionCanvas({
  rocketMass, fuelFraction, exhaustSpeed, massFlowRate, isRunning, isPaused, onTick,
  width = 660, height = 260,
}: Props) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const rafRef = useRef<number>(0);
  const lastFrameRef = useRef<number | null>(null);
  const simTime = useRef(0);       // compressed "mission" time fed into the physics
  const starsRef = useRef<Star[]>([]);
  const simRef = useRef({ rocketMass, fuelFraction, exhaustSpeed, massFlowRate, isRunning, isPaused, onTick });
  simRef.current = { rocketMass, fuelFraction, exhaustSpeed, massFlowRate, isRunning, isPaused, onTick };

  useEffect(() => {
    simTime.current = 0;
    lastFrameRef.current = null;
    starsRef.current = Array.from({ length: 40 }, () => ({
      x: Math.random(), y: Math.random(), speed: 0.4 + Math.random() * 0.8,
    }));
  }, [rocketMass, fuelFraction, exhaustSpeed, massFlowRate]);

  const draw = useCallback((timestamp?: number) => {
    const canvas = canvasRef.current; if (!canvas) return;
    const ctx = canvas.getContext('2d'); if (!ctx) return;
    const { rocketMass: m, fuelFraction: ff, exhaustSpeed: ve, massFlowRate: mdot, isRunning: r, isPaused: pa, onTick: ot } = simRef.current;
    const W = canvas.width, H = canvas.height;

    const dryMass = m * (1 - ff);
    const fuelMass = m * ff;
    const burnTime = rocketBurnTime(fuelMass, mdot);
    const compression = Math.max(1, burnTime / TARGET_REAL_SECONDS);

    if (r && !pa && timestamp !== undefined) {
      if (lastFrameRef.current !== null) {
        const realDt = Math.min((timestamp - lastFrameRef.current) / 1000, 0.1);
        simTime.current += realDt * compression;
      }
      lastFrameRef.current = timestamp;
    } else {
      lastFrameRef.current = timestamp ?? null;
    }

    const state = rocketStateAt(simTime.current, dryMass, fuelMass, ve, mdot);
    ot?.(state.t, state.v, state.burnedOut);

    // ── Scene ──────────────────────────────────────────────────────────────
    ctx.clearRect(0, 0, W, H);
    const sky = ctx.createLinearGradient(0, 0, 0, H);
    sky.addColorStop(0, '#0f172a'); sky.addColorStop(1, '#1e293b');
    ctx.fillStyle = sky; ctx.fillRect(0, 0, W, H);

    // Starfield streams past faster as speed increases — a visual proxy for
    // "the rocket is now moving faster" without needing it to fly off-screen
    // at velocities that can reach thousands of m/s.
    const streamSpeed = 0.002 + Math.min(state.v / 3000, 1) * 0.03;
    ctx.fillStyle = 'white';
    starsRef.current.forEach(s => {
      if (r && !pa) {
        s.x -= streamSpeed * s.speed;
        if (s.x < 0) { s.x = 1; s.y = Math.random(); }
      }
      const size = 0.8 + s.speed;
      ctx.globalAlpha = 0.5 + s.speed * 0.4;
      ctx.fillRect(s.x * W, s.y * H, size, size);
    });
    ctx.globalAlpha = 1;

    // Rocket, centred, nose pointing right
    const cx = W * 0.42, cy = H / 2;
    const bodyW = 70, bodyH = 34;

    // Exhaust flame — length/intensity track current thrust, vanishes at burnout
    if (!state.burnedOut && r) {
      const flameLen = 20 + (state.thrust / (ve * mdot || 1)) * 55;
      const flicker = Math.sin(simTime.current * 24) * 4;
      const grad = ctx.createLinearGradient(cx - bodyW / 2, cy, cx - bodyW / 2 - flameLen, cy);
      grad.addColorStop(0, 'rgba(253,224,71,0.95)');
      grad.addColorStop(0.5, 'rgba(251,146,60,0.85)');
      grad.addColorStop(1, 'rgba(239,68,68,0)');
      ctx.fillStyle = grad;
      ctx.beginPath();
      ctx.moveTo(cx - bodyW / 2, cy - 10);
      ctx.lineTo(cx - bodyW / 2 - flameLen - flicker, cy);
      ctx.lineTo(cx - bodyW / 2, cy + 10);
      ctx.closePath(); ctx.fill();
    }

    // Body
    const bodyGrad = ctx.createLinearGradient(cx, cy - bodyH / 2, cx, cy + bodyH / 2);
    bodyGrad.addColorStop(0, '#e0e7ff'); bodyGrad.addColorStop(1, '#a5b4fc');
    ctx.fillStyle = bodyGrad;
    ctx.beginPath();
    ctx.roundRect(cx - bodyW / 2, cy - bodyH / 2, bodyW, bodyH, 6);
    ctx.fill();
    ctx.strokeStyle = '#4338ca'; ctx.lineWidth = 1.5; ctx.stroke();
    // Nose cone
    ctx.fillStyle = '#818cf8';
    ctx.beginPath();
    ctx.moveTo(cx + bodyW / 2, cy - bodyH / 2);
    ctx.lineTo(cx + bodyW / 2 + 22, cy);
    ctx.lineTo(cx + bodyW / 2, cy + bodyH / 2);
    ctx.closePath(); ctx.fill();
    ctx.fillStyle = '#312e81'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
    ctx.fillText(`${state.mass.toFixed(0)}kg`, cx, cy + 4);

    // Fuel gauge
    const gx = 16, gy = H - 26, gw = 90, gh = 8;
    ctx.fillStyle = 'rgba(255,255,255,0.15)';
    ctx.beginPath(); ctx.roundRect(gx, gy, gw, gh, 4); ctx.fill();
    ctx.fillStyle = state.fuelFraction > 0.2 ? '#34d399' : '#f87171';
    ctx.beginPath(); ctx.roundRect(gx, gy, gw * Math.max(0, state.fuelFraction), gh, 4); ctx.fill();
    ctx.fillStyle = '#cbd5e1'; ctx.font = '9px system-ui'; ctx.textAlign = 'left';
    ctx.fillText(`Fuel ${(state.fuelFraction * 100).toFixed(0)}%`, gx, gy - 4);

    // HUD
    ctx.textAlign = 'right';
    const uiScale = Math.max(0.75, Math.min(1, W / 660));
    const hud = [
      `T+${state.t.toFixed(1)}s`,
      `v = ${state.v.toFixed(1)} m/s`,
      `a = ${state.acceleration.toFixed(2)} m/s²`,
      `Thrust = ${state.thrust.toFixed(0)} N`,
    ];
    const hudFont = Math.max(8, Math.round(10 * uiScale)), hudLineH = Math.max(12, Math.round(15 * uiScale));
    ctx.font = `bold ${hudFont}px monospace`; ctx.fillStyle = '#e0e7ff';
    hud.forEach((line, i) => ctx.fillText(line, W - 12, 18 + i * hudLineH));

    if (state.burnedOut) {
      ctx.textAlign = 'center'; ctx.font = 'bold 11px system-ui'; ctx.fillStyle = '#fbbf24';
      ctx.fillText('🔥 Engine cutoff — coasting at constant velocity (Newton\u2019s 1st Law)', W / 2, H - 10);
    }

    rafRef.current = requestAnimationFrame(draw);
  }, []);

  useEffect(() => {
    rafRef.current = requestAnimationFrame(draw);
    return () => cancelAnimationFrame(rafRef.current);
  }, [draw]);

  return (
    <canvas ref={canvasRef} width={width} height={height}
      className="w-full rounded-xl border border-gray-200" style={{ display: 'block' }} />
  );
}
AFEOF

echo ""
echo "Patch v34 applied -- 5 files written."
echo ""
echo "Next steps:"
echo "  rm -rf .next"
echo "  npm run dev"
echo ""
echo "Check on a narrow mobile-width browser window (or dev tools device"
echo "emulation) at:"
echo "  / (homepage projectile), /simulations/projectile-motion,"
echo "  /simulations/elasticity, /simulations/rectilinear-propagation"
echo "  (Eclipse tab), and the consequences-of-motion Propulsion tab --"
echo "  the stat boxes should now be noticeably smaller and stay clear of"
echo "  the main diagram, while looking unchanged on a normal desktop"
echo "  browser window."
