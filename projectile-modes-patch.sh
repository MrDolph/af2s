#!/bin/bash
# A-Factor STEM Studio — Projectile motion modes patch
# Run inside af2s/ folder: bash projectile-modes-patch.sh
set -e
echo "Adding projectile motion modes..."

mkdir -p src/lib/physics
mkdir -p src/components/simulation
mkdir -p src/app/simulations/projectile-motion

# ── 1. Extended projectile physics ────────────────────────────────────────────
cat > src/lib/physics/projectile-modes.ts << 'EOF'
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
}
export function inclinedAnalytics(p: InclinedParams) {
  const { v0, alpha, beta, g } = p;
  const a = alpha * DEG;
  const b = beta * DEG;
  // g along incline (down) = g sinβ, g perpendicular (into surface) = g cosβ
  const gAlong = g * Math.sin(b);
  const gPerp  = g * Math.cos(b);
  // Launch: v along incline = v0 cosα, v perpendicular = v0 sinα
  const tFlight = (2 * v0 * Math.sin(a)) / gPerp;
  const rangeAlongIncline = v0 * Math.cos(a) * tFlight - 0.5 * gAlong * tFlight * tFlight;
  const maxHeightPerp = (v0 * v0 * Math.sin(a) * Math.sin(a)) / (2 * gPerp);
  return {
    tFlight: +tFlight.toFixed(3),
    rangeAlongIncline: +rangeAlongIncline.toFixed(3),
    rangeHorizontal: +(rangeAlongIncline * Math.cos(b)).toFixed(3),
    maxHeightAboveIncline: +maxHeightPerp.toFixed(3),
  };
}
export function inclinedPath(p: InclinedParams, steps = 100) {
  const { v0, alpha, beta, g } = p;
  const a = alpha * DEG;
  const b = beta * DEG;
  const gPerp = g * Math.cos(b);
  const gAlong = g * Math.sin(b);
  const tFlight = (2 * v0 * Math.sin(a)) / gPerp;
  // In inclined frame: s (along), n (perp)
  // Convert to world x,y coordinates
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
EOF

# ── 2. Multi-mode Canvas ──────────────────────────────────────────────────────
cat > src/components/simulation/ProjectileModeCanvas.tsx << 'EOF'
'use client';
import { useEffect, useRef, useCallback, useState } from 'react';
import {
  standardPath, horizontalPath, verticalPath, inclinedPath,
  standardAnalytics, horizontalAnalytics, verticalAnalytics, inclinedAnalytics,
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

const PAD = 50;
const GROUND_H = 44;
const BALL_R = 7;
const DT = 0.016;

function worldToCanvas(
  wx: number, wy: number,
  xMin: number, xMax: number,
  yMin: number, yMax: number,
  W: number, H: number
): [number, number] {
  const cx = PAD + ((wx - xMin) / (xMax - xMin)) * (W - PAD * 2);
  const cy = H - GROUND_H - ((wy - yMin) / (yMax - yMin)) * (H - GROUND_H - PAD);
  return [cx, cy];
}

export function ProjectileModeCanvas({
  mode, standard, horizontal, vertical, inclined,
  isRunning, isPaused, onComplete, onTick,
  width = 680, height = 320,
}: Props) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const rafRef = useRef<number>(0);
  const tRef = useRef(0);
  const trailRef = useRef<[number, number][]>([]);
  const doneRef = useRef(false);

  const [toggles, setToggles] = useState({ trail: true, vector: true, grid: true });
  const [showToggles, setShowToggles] = useState(false);
  const simRef = useRef({ mode, standard, horizontal, vertical, inclined, isRunning, isPaused, onComplete, onTick, toggles });
  simRef.current = { mode, standard, horizontal, vertical, inclined, isRunning, isPaused, onComplete, onTick, toggles };

  // Get full path for current mode
  const getPath = useCallback(() => {
    const s = simRef.current;
    if (s.mode === 'standard' && s.standard) return standardPath(s.standard);
    if (s.mode === 'horizontal' && s.horizontal) return horizontalPath(s.horizontal);
    if (s.mode === 'vertical' && s.vertical) return verticalPath(s.vertical);
    if (s.mode === 'inclined' && s.inclined) return inclinedPath(s.inclined);
    return [];
  }, []);

  const getExtents = useCallback((path: { x?: number; y: number }[]) => {
    const xs = path.map(p => (p as { x?: number }).x ?? 0);
    const ys = path.map(p => p.y);
    return {
      xMin: 0, xMax: Math.max(Math.max(...xs) * 1.15, 1),
      yMin: 0, yMax: Math.max(Math.max(...ys) * 1.2, 1),
    };
  }, []);

  const draw = useCallback((path: ReturnType<typeof getPath>, t: number) => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;
    const { mode: m, toggles: tog } = simRef.current;
    const W = canvas.width, H = canvas.height;
    const ext = getExtents(path as { x?: number; y: number }[]);

    const toC = (wx: number, wy: number) =>
      worldToCanvas(wx, wy, ext.xMin, ext.xMax, ext.yMin, ext.yMax, W, H);

    ctx.clearRect(0, 0, W, H);

    // Sky
    const sky = ctx.createLinearGradient(0, 0, 0, H - GROUND_H);
    sky.addColorStop(0, '#dbeafe'); sky.addColorStop(1, '#f0f6ff');
    ctx.fillStyle = sky; ctx.fillRect(0, 0, W, H - GROUND_H);

    // Ground / surface
    ctx.fillStyle = '#e2e8f0'; ctx.fillRect(0, H - GROUND_H, W, GROUND_H);
    ctx.strokeStyle = '#94a3b8'; ctx.lineWidth = 2;
    ctx.beginPath(); ctx.moveTo(0, H - GROUND_H); ctx.lineTo(W, H - GROUND_H); ctx.stroke();

    // Inclined plane surface
    if (m === 'inclined' && simRef.current.inclined) {
      const beta = simRef.current.inclined.beta;
      const analytics = inclinedAnalytics(simRef.current.inclined);
      const inclineLen = analytics.rangeHorizontal * 1.3;
      const [x0, y0] = toC(0, 0);
      const [x1, y1] = toC(inclineLen, inclineLen * Math.tan(beta * Math.PI / 180));
      ctx.beginPath(); ctx.moveTo(x0, y0); ctx.lineTo(x1, y1);
      ctx.strokeStyle = '#64748b'; ctx.lineWidth = 3; ctx.stroke();
      ctx.fillStyle = '#94a3b8'; ctx.font = 'bold 11px system-ui'; ctx.textAlign = 'center';
      ctx.fillText(`β = ${beta}°`, (x0 + x1) / 2, (y0 + y1) / 2 + 18);
    }

    // Platform / building
    if ((m === 'standard' && simRef.current.standard && simRef.current.standard.h0 > 0) ||
        m === 'horizontal') {
      const h0 = m === 'standard' ? (simRef.current.standard?.h0 ?? 0) : (simRef.current.horizontal?.h ?? 0);
      const [bx, by] = toC(0, h0);
      ctx.fillStyle = '#94a3b8';
      ctx.fillRect(0, by, PAD + 8, H - GROUND_H - by);
      ctx.strokeStyle = '#64748b'; ctx.lineWidth = 1.5;
      ctx.strokeRect(0, by, PAD + 8, H - GROUND_H - by);
      ctx.fillStyle = '#64748b'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
      ctx.fillText(`${h0}m`, PAD / 2, by - 6);
    }

    // Grid
    if (tog.grid) {
      ctx.save();
      ctx.strokeStyle = '#e2e8f0'; ctx.lineWidth = 1;
      ctx.fillStyle = '#94a3b8'; ctx.font = '10px system-ui';
      const xStep = Math.ceil(ext.xMax / 5 / 5) * 5 || 1;
      ctx.textAlign = 'center';
      for (let x = 0; x <= ext.xMax; x += xStep) {
        const [cx] = toC(x, 0);
        ctx.beginPath(); ctx.setLineDash([3, 4]);
        ctx.moveTo(cx, PAD); ctx.lineTo(cx, H - GROUND_H); ctx.stroke();
        ctx.setLineDash([]); ctx.fillText(`${x}m`, cx, H - GROUND_H + 14);
      }
      ctx.textAlign = 'right';
      const yStep = Math.ceil(ext.yMax / 4 / 5) * 5 || 1;
      for (let y = 0; y <= ext.yMax; y += yStep) {
        const [, cy] = toC(0, y);
        if (cy < PAD) continue;
        ctx.beginPath(); ctx.setLineDash([3, 4]);
        ctx.moveTo(PAD, cy); ctx.lineTo(W - PAD, cy); ctx.stroke();
        ctx.setLineDash([]); ctx.fillText(`${y}m`, PAD - 4, cy + 4);
      }
      ctx.restore();
    }

    // Ghost trajectory
    if (path.length > 1) {
      ctx.save(); ctx.beginPath();
      const [x0, y0] = toC((path[0] as {x?:number; y:number}).x ?? 0, path[0].y);
      ctx.moveTo(x0, y0);
      path.slice(1).forEach(pt => {
        const [cx, cy] = toC((pt as {x?:number; y:number}).x ?? 0, pt.y);
        ctx.lineTo(cx, cy);
      });
      ctx.strokeStyle = 'rgba(99,102,241,0.18)'; ctx.lineWidth = 2;
      ctx.setLineDash([6, 4]); ctx.stroke(); ctx.setLineDash([]); ctx.restore();
    }

    // Live trail
    if (tog.trail && trailRef.current.length > 1) {
      ctx.save();
      for (let i = 1; i < trailRef.current.length; i++) {
        const alpha = i / trailRef.current.length;
        ctx.beginPath();
        ctx.moveTo(trailRef.current[i-1][0], trailRef.current[i-1][1]);
        ctx.lineTo(trailRef.current[i][0], trailRef.current[i][1]);
        ctx.strokeStyle = `rgba(99,102,241,${alpha * 0.8})`;
        ctx.lineWidth = 2.5; ctx.stroke();
      }
      ctx.restore();
    }

    // Current ball position
    const idx = Math.min(Math.round(t / (path[path.length-1]?.t ?? 1) * path.length), path.length - 1);
    const cur = path[idx] ?? path[path.length - 1];
    const [bx, by] = toC((cur as {x?:number;y:number}).x ?? 0, Math.max(0, cur.y));

    // Shadow
    const [, gy] = toC(0, 0);
    ctx.beginPath(); ctx.ellipse(bx, gy + 4, 10, 4, 0, 0, Math.PI * 2);
    ctx.fillStyle = 'rgba(0,0,0,0.1)'; ctx.fill();

    // Glow
    const glow = ctx.createRadialGradient(bx, by, 0, bx, by, BALL_R * 2.5);
    glow.addColorStop(0, 'rgba(79,70,229,0.3)'); glow.addColorStop(1, 'transparent');
    ctx.beginPath(); ctx.arc(bx, by, BALL_R * 2.5, 0, Math.PI * 2);
    ctx.fillStyle = glow; ctx.fill();

    // Ball
    const ballG = ctx.createRadialGradient(bx - 2, by - 2, 1, bx, by, BALL_R);
    ballG.addColorStop(0, '#818cf8'); ballG.addColorStop(1, '#4f46e5');
    ctx.beginPath(); ctx.arc(bx, by, BALL_R, 0, Math.PI * 2);
    ctx.fillStyle = ballG; ctx.fill();

    // Velocity vector
    if (tog.vector && idx < path.length - 1) {
      const next = path[Math.min(idx + 2, path.length - 1)];
      const dt2 = Math.max(next.t - cur.t, 0.001);
      const vx2 = m === 'vertical' ? 0 : (((next as {x?:number}).x ?? 0) - ((cur as {x?:number}).x ?? 0)) / dt2;
      const vy2 = (next.y - cur.y) / dt2;
      const speed = Math.sqrt(vx2 * vx2 + vy2 * vy2);
      if (speed > 0.5) {
        const scale = Math.min(speed * 0.8, 55);
        const angle = Math.atan2(-vy2 / (ext.yMax), vx2 / (ext.xMax || 1));
        const ex = bx + Math.cos(angle) * scale;
        const ey = by + Math.sin(angle) * scale;
        ctx.save();
        ctx.beginPath(); ctx.moveTo(bx, by); ctx.lineTo(ex, ey);
        ctx.strokeStyle = '#f59e0b'; ctx.lineWidth = 2.5; ctx.stroke();
        const hL = 8, hA = 0.4;
        ctx.beginPath(); ctx.moveTo(ex, ey);
        ctx.lineTo(ex - hL * Math.cos(angle - hA), ey - hL * Math.sin(angle - hA));
        ctx.lineTo(ex - hL * Math.cos(angle + hA), ey - hL * Math.sin(angle + hA));
        ctx.closePath(); ctx.fillStyle = '#f59e0b'; ctx.fill();
        ctx.restore();
      }
    }

    // HUD
    if (t > 0) {
      const xVal = (cur as {x?:number}).x ?? 0;
      const lines = [`t = ${t.toFixed(2)}s`, `x = ${xVal.toFixed(1)}m`, `y = ${Math.max(0, cur.y).toFixed(1)}m`];
      const bw = 110, bh = lines.length * 18 + 14, bxh = W - bw - 10;
      ctx.save();
      ctx.fillStyle = 'rgba(255,255,255,0.9)';
      ctx.beginPath(); ctx.roundRect(bxh, 10, bw, bh, 8); ctx.fill();
      ctx.strokeStyle = 'rgba(99,102,241,0.2)'; ctx.lineWidth = 1; ctx.stroke();
      ctx.fillStyle = '#1e293b'; ctx.font = '11px monospace'; ctx.textAlign = 'left';
      lines.forEach((l, i) => ctx.fillText(l, bxh + 8, 26 + i * 18));
      ctx.restore();
    }
  }, [getExtents, getPath]);

  // Reset on key change
  useEffect(() => {
    cancelAnimationFrame(rafRef.current);
    tRef.current = 0;
    trailRef.current = [];
    doneRef.current = false;
    const path = getPath();
    draw(path, 0);
  }, [mode, standard, horizontal, vertical, inclined, draw, getPath]);

  // Animation loop
  useEffect(() => {
    const loop = () => {
      const { isRunning: r, isPaused: p } = simRef.current;
      const path = getPath();
      const maxT = path[path.length - 1]?.t ?? 1;

      if (r && !p && !doneRef.current) {
        tRef.current += DT;
        const cur = path[Math.min(Math.round(tRef.current / maxT * path.length), path.length - 1)];
        const [bx, by] = worldToCanvas(
          (cur as {x?:number}).x ?? 0, Math.max(0, cur.y),
          0, Math.max(...path.map(pt => (pt as {x?:number}).x ?? 0), 1),
          0, Math.max(...path.map(pt => pt.y), 1),
          width, height
        );
        trailRef.current.push([bx, by]);
        if (trailRef.current.length > 150) trailRef.current.shift();
        simRef.current.onTick?.(tRef.current, (cur as {x?:number}).x ?? 0, cur.y);
        if (tRef.current >= maxT) {
          doneRef.current = true;
          simRef.current.onComplete?.();
        }
      }
      draw(path, tRef.current);
      rafRef.current = requestAnimationFrame(loop);
    };
    rafRef.current = requestAnimationFrame(loop);
    return () => cancelAnimationFrame(rafRef.current);
  }, [draw, getPath, width, height]);

  return (
    <div className="space-y-2">
      {/* Toggle bar */}
      <div className="flex items-center gap-2 flex-wrap">
        <button onClick={() => setShowToggles(v => !v)}
          className={`flex items-center gap-1.5 rounded-lg border px-3 py-1.5 text-xs font-medium transition ${
            showToggles ? 'border-indigo-300 bg-indigo-50 text-indigo-700' : 'border-gray-200 bg-white text-gray-600 hover:bg-gray-50'
          }`}>
          <svg width="12" height="12" viewBox="0 0 12 12" fill="none" stroke="currentColor" strokeWidth="1.5"><circle cx="6" cy="6" r="2"/><path d="M6 1v1M6 10v1M1 6h1M10 6h1"/></svg>
          Overlays
        </button>
        {showToggles && (
          <>
            {(['trail', 'vector', 'grid'] as const).map(k => (
              <button key={k} onClick={() => setToggles(t => ({ ...t, [k]: !t[k] }))}
                className={`rounded-full px-3 py-1 text-xs font-medium border transition ${
                  toggles[k] ? 'bg-indigo-600 text-white border-indigo-600' : 'bg-white text-gray-400 border-gray-200'
                }`}>
                {k === 'trail' ? 'Trail' : k === 'vector' ? 'Velocity vector' : 'Grid'}
              </button>
            ))}
          </>
        )}
      </div>

      {/* Canvas */}
      <div className="relative w-full overflow-hidden rounded-xl border border-gray-200 bg-white shadow-sm">
        <canvas ref={canvasRef} width={width} height={height} className="w-full" style={{ display: 'block' }} />
      </div>
    </div>
  );
}
EOF

# ── 3. Full upgraded projectile page ──────────────────────────────────────────
cat > src/app/simulations/projectile-motion/page.tsx << 'EOF'
'use client';
import { useState, useCallback, useEffect } from 'react';
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
const CURRICULUM_COLORS: Record<string, string> = {
  WAEC: 'bg-indigo-100 text-indigo-700', NECO: 'bg-pink-100 text-pink-700',
  IGCSE: 'bg-emerald-100 text-emerald-700', SAT: 'bg-orange-100 text-orange-700',
  JUPEB: 'bg-purple-100 text-purple-700',
};

const MODE_META: Record<ProjectileMode, { title: string; subtitle: string; icon: string; equations: string[] }> = {
  standard:   { title: 'Standard projectile',     subtitle: 'Launched at angle θ from height h', icon: '🎯', equations: ['R = vₓ × t', 'H = h + vy²/2g', 'T: solve h + vy₀t − ½gt² = 0'] },
  horizontal: { title: 'Horizontal projection',   subtitle: 'Launched horizontally from height h', icon: '🏗️', equations: ['t = √(2h/g)', 'R = v₀ × t', 'v_land = √(v₀² + (gt)²)'] },
  vertical:   { title: 'Vertical projection',     subtitle: 'Thrown upward or dropped', icon: '⬆️', equations: ['H_max = h₀ + v₀²/2g', 't_max = v₀/g', 'v_land = √(v₀² + 2gh₀)'] },
  inclined:   { title: 'Inclined plane',          subtitle: 'Launched along a slope at angle β', icon: '📐', equations: ['t = 2v₀sinα / gcosβ', 'R = v₀cosα·t − ½gsinβ·t²', 'H = v₀²sin²α / 2gcosβ'] },
};

const TEACHER_NOTES: Record<ProjectileMode, string[]> = {
  standard: [
    "Standard projectile motion: vx is constant, vy changes at rate g. These are completely independent.",
    "When launched from a height (h > 0), the landing range increases because the ball has more time in the air.",
    "Complementary angles (e.g. 30° and 60°) give the same range on flat ground — not when h > 0.",
    "Max range from height h occurs at angle less than 45° — the optimal angle decreases as h increases.",
    "Use the platform height slider to show how a ball thrown from a building travels much farther.",
  ],
  horizontal: [
    "Horizontal projection: the initial vertical velocity is ZERO. Only horizontal velocity is given.",
    "Time of flight depends only on the height: t = √(2h/g). The horizontal speed doesn't affect how long it takes to fall.",
    "The landing velocity always points below horizontal — the angle steepens with taller drops.",
    "Classic exam scenario: stone thrown horizontally from a cliff, or bomb released from a horizontal aircraft.",
    "The path is a parabola opening downward — it starts horizontally and curves increasingly downward.",
  ],
  vertical: [
    "Pure vertical motion: no horizontal component. Ball goes straight up and comes straight down.",
    "At maximum height, vertical velocity = 0. Time to reach max = v₀/g.",
    "Free fall (v₀ = 0): ball accelerates downward from rest. v = gt at any time t.",
    "Symmetry: time going up = time coming down (when returning to same height). Speed at launch = speed at landing.",
    "Set v₀ negative to simulate a ball thrown downward or dropped with initial downward velocity.",
  ],
  inclined: [
    "On an inclined plane, gravity has two components: g sinβ (along slope, decelerating) and g cosβ (perpendicular, like effective gravity).",
    "The effective gravity perpendicular to slope is g cosβ — less than g. So the ball stays in the air longer than on flat ground.",
    "Maximum range along slope occurs at α = 45° − β/2 (not 45° as on flat ground).",
    "This is a challenging WAEC and IGCSE topic — the key is setting up axes along and perpendicular to the slope.",
    "The range along the slope ≠ horizontal range. Use the analytics panel to compare both.",
  ],
};

const EXERCISES: Record<ProjectileMode, { q: string; a: string }[]> = {
  standard: [
    { q: "A ball is thrown at 20 m/s at 45° from a 20m building. Find its range. (g = 10 m/s²)", a: "vx=14.14, vy₀=14.14. Solve: 20 + 14.14t − 5t² = 0 → t ≈ 3.83s. R = 14.14 × 3.83 ≈ 54.1m" },
    { q: "Why does launching from a height change the optimal angle below 45°?", a: "With extra height, the ball has more time to travel horizontally. A shallower angle sacrifices some vertical distance but gains more horizontal time — the optimum shifts below 45°." },
    { q: "A projectile is launched at 30 m/s at 60° from ground level. Find max height and range. (g = 10 m/s²)", a: "H = v²sin²θ/2g = 900×0.75/20 = 33.75m. R = v²sin2θ/g = 900×0.866/10 = 77.9m" },
  ],
  horizontal: [
    { q: "A stone is thrown horizontally at 15 m/s from a 45m cliff. How far from the base does it land? (g = 10 m/s²)", a: "t = √(2h/g) = √9 = 3s. R = 15 × 3 = 45m from base." },
    { q: "A ball is projected horizontally from a table 1.25m high. If it lands 2.5m away, find initial speed. (g = 10 m/s²)", a: "t = √(2×1.25/10) = 0.5s. v₀ = R/t = 2.5/0.5 = 5 m/s" },
    { q: "A bomb is released from a plane flying horizontally at 100 m/s at 500m altitude. How far ahead of target should it be released? (g = 10 m/s²)", a: "t = √(2×500/10) = 10s. R = 100×10 = 1000m ahead." },
  ],
  vertical: [
    { q: "A ball is thrown upward at 20 m/s from the ground. Find max height and time to return. (g = 10 m/s²)", a: "H = v²/2g = 400/20 = 20m. t_up = v/g = 2s. Total = 4s." },
    { q: "A ball is dropped from 80m. Find speed at impact and time to fall. (g = 10 m/s²)", a: "v = √(2gh) = √1600 = 40 m/s. t = √(2h/g) = 4s." },
    { q: "A ball thrown upward at 25 m/s from a 20m platform. Find max height above ground. (g = 10 m/s²)", a: "H_above_launch = v²/2g = 625/20 = 31.25m. Max height above ground = 20 + 31.25 = 51.25m" },
  ],
  inclined: [
    { q: "A ball is launched at 20 m/s at α = 30° above a slope inclined at β = 30°. Find time of flight. (g = 10 m/s²)", a: "t = 2v₀sinα/(gcosβ) = 2×20×0.5/(10×0.866) = 20/8.66 ≈ 2.31s" },
    { q: "Why is the range along the slope different from horizontal range?", a: "The slope itself rises — the landing point is higher than the foot. Range along slope measures distance along the inclined surface; horizontal range is the horizontal distance only." },
    { q: "On an inclined plane of β = 45°, what launch angle α gives maximum range along the slope?", a: "Optimal α = 45° − β/2 = 45° − 22.5° = 22.5° above the slope surface." },
  ],
};

export default function ProjectileMotionPage() {
  const [mode, setMode] = useState<ProjectileMode>('standard');
  const [isRunning, setIsRunning] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const [isComplete, setIsComplete] = useState(false);
  const [resetKey, setResetKey] = useState(0);
  const [openEx, setOpenEx] = useState<number | null>(null);
  const [activeCurricula, setActiveCurricula] = useState(['WAEC', 'IGCSE', 'SAT']);
  const [livePos, setLivePos] = useState({ t: 0, x: 0, y: 0 });

  // Standard
  const [v0, setV0] = useState(25);
  const [angle, setAngle] = useState(45);
  const [g, setG] = useState(9.81);
  const [h0, setH0] = useState(0);
  // Horizontal
  const [hV0, setHV0] = useState(20);
  const [hH, setHH] = useState(30);
  // Vertical
  const [vV0, setVV0] = useState(15);
  const [vH0, setVH0] = useState(0);
  // Inclined
  const [iV0, setIV0] = useState(20);
  const [iAlpha, setIAlpha] = useState(30);
  const [iBeta, setIBeta] = useState(30);

  const stdParams: StandardParams = { v0, angle, g, h0 };
  const hrzParams: HorizontalParams = { v0: hV0, h: hH, g };
  const vtcParams: VerticalParams = { v0: vV0, h0: vH0, g };
  const incParams: InclinedParams = { v0: iV0, alpha: iAlpha, beta: iBeta, g };

  const stdAn = standardAnalytics(stdParams);
  const hrzAn = horizontalAnalytics(hrzParams);
  const vtcAn = verticalAnalytics(vtcParams);
  const incAn = inclinedAnalytics(incParams);

  const reset = useCallback(() => {
    setIsRunning(false); setIsPaused(false);
    setIsComplete(false); setResetKey(k => k + 1);
    setLivePos({ t: 0, x: 0, y: 0 });
  }, []);

  useEffect(() => { reset(); }, [mode, v0, angle, g, h0, hV0, hH, vV0, vH0, iV0, iAlpha, iBeta, reset]);

  const handleTick = useCallback((t: number, x: number, y: number) => setLivePos({ t, x, y }), []);
  const handleComplete = useCallback(() => setIsComplete(true), []);
  const handleAIResult = useCallback((r: AIPromptResponse) => {
    if (r.simulationType === 'projectile_motion') {
      const p = r.params as Record<string, number>;
      if (p.initialVelocity) setV0(p.initialVelocity);
      if (p.angle) setAngle(p.angle);
      if (p.gravity) setG(p.gravity);
      if (p.h0) { setH0(p.h0); setMode('standard'); }
    }
    reset();
  }, [reset]);

  const meta = MODE_META[mode];

  return (
    <>
      <AppHeader />
      <main className="min-h-screen bg-gray-50">
        <section className="border-b border-gray-200 bg-white">
          <div className="mx-auto max-w-7xl px-4 sm:px-6 py-5">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
              <div>
                <p className="text-xs text-gray-400 mb-1">Mechanics</p>
                <h1 className="text-lg sm:text-xl font-semibold text-gray-900">Projectile motion</h1>
              </div>
              <div className="flex gap-1.5 flex-wrap">
                {CURRICULA.map(c => (
                  <button key={c}
                    onClick={() => setActiveCurricula(p => p.includes(c) ? p.filter(x => x !== c) : [...p, c])}
                    className={`text-xs px-2.5 py-1 rounded-full border font-medium transition ${
                      activeCurricula.includes(c) ? CURRICULUM_COLORS[c] + ' border-transparent' : 'bg-white text-gray-400 border-gray-200'
                    }`}>{c}</button>
                ))}
              </div>
            </div>
          </div>
        </section>

        <div className="mx-auto max-w-7xl px-4 sm:px-6 py-5 space-y-4">

          {/* AI prompt */}
          <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
            <p className="text-xs font-medium text-gray-400 uppercase tracking-wide mb-3">AI prompt</p>
            <PromptBar onResult={handleAIResult} />
          </div>

          {/* Mode tabs */}
          <div className="flex gap-1 bg-gray-100 p-1 rounded-xl overflow-x-auto">
            {(Object.keys(MODE_META) as ProjectileMode[]).map(m => (
              <button key={m} onClick={() => setMode(m)}
                className={`shrink-0 flex items-center gap-1.5 px-3 sm:px-4 py-2 rounded-lg text-xs font-medium transition ${
                  mode === m ? 'bg-white text-indigo-700 shadow-sm' : 'text-gray-500 hover:text-gray-700'
                }`}>
                <span>{MODE_META[m].icon}</span>
                <span className="hidden sm:inline">{MODE_META[m].title}</span>
                <span className="sm:hidden">{MODE_META[m].icon === '🎯' ? 'Standard' : MODE_META[m].icon === '🏗️' ? 'Horizontal' : MODE_META[m].icon === '⬆️' ? 'Vertical' : 'Inclined'}</span>
              </button>
            ))}
          </div>

          {/* Mode subtitle + equations */}
          <div className="flex flex-wrap items-center gap-3">
            <span className="text-xs text-gray-500">{meta.subtitle}</span>
            {meta.equations.map(eq => (
              <span key={eq} className="rounded-lg border border-gray-200 bg-white px-3 py-1 text-xs font-mono text-gray-700">{eq}</span>
            ))}
          </div>

          {/* Main grid */}
          <div className="grid grid-cols-1 xl:grid-cols-[1fr_1fr_260px] gap-4">

            {/* Canvas + controls + sliders */}
            <div className="space-y-3">
              <div className="rounded-2xl border border-gray-200 bg-white p-3 shadow-sm">
                <ProjectileModeCanvas
                  key={resetKey}
                  mode={mode}
                  standard={stdParams}
                  horizontal={hrzParams}
                  vertical={vtcParams}
                  inclined={incParams}
                  isRunning={isRunning}
                  isPaused={isPaused}
                  onTick={handleTick}
                  onComplete={handleComplete}
                  width={660}
                  height={300}
                />
              </div>

              <div className="flex flex-wrap items-center gap-3 justify-between">
                <SimulationControls
                  isRunning={isRunning && !isComplete}
                  isPaused={isPaused}
                  onRun={() => { setIsRunning(true); setIsPaused(false); setIsComplete(false); }}
                  onPause={() => setIsPaused(p => !p)}
                  onReset={reset}
                />
                {isComplete && <span className="text-xs font-medium text-emerald-600">✓ Complete — Reset to go again</span>}
              </div>

              {/* Sliders per mode */}
              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide mb-4">Parameters</p>

                {/* Common gravity slider */}
                <div className="space-y-1.5 mb-4">
                  <div className="flex justify-between text-xs"><span className="text-gray-500">Gravity</span><span className="font-medium tabular-nums">{g} m/s²</span></div>
                  <input type="range" min="1" max="25" step="0.1" value={g} onChange={e => setG(Number(e.target.value))} className="w-full" style={{ accentColor: '#10b981' }} />
                  <div className="flex justify-between text-[10px] text-gray-300"><span>1 m/s² (low g)</span><span>25 m/s²</span></div>
                </div>

                {mode === 'standard' && (
                  <div className="space-y-4">
                    {[
                      { label: 'Initial velocity', unit: 'm/s', val: v0, min: 1, max: 100, step: 1, set: setV0, color: '#6366f1' },
                      { label: 'Launch angle', unit: '°', val: angle, min: 1, max: 89, step: 1, set: setAngle, color: '#f59e0b' },
                      { label: 'Platform height', unit: 'm', val: h0, min: 0, max: 100, step: 1, set: setH0, color: '#8b5cf6' },
                    ].map(sl => (
                      <div key={sl.label} className="space-y-1.5">
                        <div className="flex justify-between text-xs"><span className="text-gray-500">{sl.label}</span><span className="font-medium tabular-nums">{sl.val} {sl.unit}</span></div>
                        <input type="range" min={sl.min} max={sl.max} step={sl.step} value={sl.val} onChange={e => sl.set(Number(e.target.value))} className="w-full" style={{ accentColor: sl.color }} />
                      </div>
                    ))}
                  </div>
                )}

                {mode === 'horizontal' && (
                  <div className="space-y-4">
                    {[
                      { label: 'Horizontal speed', unit: 'm/s', val: hV0, min: 1, max: 100, step: 1, set: setHV0, color: '#6366f1' },
                      { label: 'Launch height', unit: 'm', val: hH, min: 1, max: 200, step: 1, set: setHH, color: '#8b5cf6' },
                    ].map(sl => (
                      <div key={sl.label} className="space-y-1.5">
                        <div className="flex justify-between text-xs"><span className="text-gray-500">{sl.label}</span><span className="font-medium tabular-nums">{sl.val} {sl.unit}</span></div>
                        <input type="range" min={sl.min} max={sl.max} step={sl.step} value={sl.val} onChange={e => sl.set(Number(e.target.value))} className="w-full" style={{ accentColor: sl.color }} />
                      </div>
                    ))}
                  </div>
                )}

                {mode === 'vertical' && (
                  <div className="space-y-4">
                    {[
                      { label: 'Initial vertical speed', unit: 'm/s', val: vV0, min: -30, max: 50, step: 1, set: setVV0, color: '#6366f1', hint: 'Negative = downward throw' },
                      { label: 'Initial height', unit: 'm', val: vH0, min: 0, max: 200, step: 1, set: setVH0, color: '#8b5cf6', hint: '' },
                    ].map(sl => (
                      <div key={sl.label} className="space-y-1.5">
                        <div className="flex justify-between text-xs"><span className="text-gray-500">{sl.label}</span><span className="font-medium tabular-nums">{sl.val} {sl.unit}</span></div>
                        <input type="range" min={sl.min} max={sl.max} step={sl.step} value={sl.val} onChange={e => sl.set(Number(e.target.value))} className="w-full" style={{ accentColor: sl.color }} />
                        {sl.hint && <p className="text-[10px] text-gray-400">{sl.hint}</p>}
                      </div>
                    ))}
                  </div>
                )}

                {mode === 'inclined' && (
                  <div className="space-y-4">
                    {[
                      { label: 'Initial velocity', unit: 'm/s', val: iV0, min: 1, max: 60, step: 1, set: setIV0, color: '#6366f1' },
                      { label: 'Launch angle α (above slope)', unit: '°', val: iAlpha, min: 1, max: 89, step: 1, set: setIAlpha, color: '#f59e0b' },
                      { label: 'Slope angle β', unit: '°', val: iBeta, min: 5, max: 60, step: 1, set: setIBeta, color: '#ef4444' },
                    ].map(sl => (
                      <div key={sl.label} className="space-y-1.5">
                        <div className="flex justify-between text-xs"><span className="text-gray-500">{sl.label}</span><span className="font-medium tabular-nums">{sl.val} {sl.unit}</span></div>
                        <input type="range" min={sl.min} max={sl.max} step={sl.step} value={sl.val} onChange={e => sl.set(Number(e.target.value))} className="w-full" style={{ accentColor: sl.color }} />
                      </div>
                    ))}
                  </div>
                )}
              </div>
            </div>

            {/* Analytics panel */}
            <div className="space-y-3">
              {/* Calculated values */}
              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide mb-3">Calculated values</p>
                <div className="space-y-2">
                  {mode === 'standard' && [
                    { label: 'Time of flight', value: stdAn.tFlight, unit: 's', color: 'text-indigo-600' },
                    { label: 'Max range', value: stdAn.range, unit: 'm', color: 'text-emerald-600' },
                    { label: 'Max height', value: stdAn.maxHeight, unit: 'm', color: 'text-amber-600' },
                    { label: 'Horizontal vx', value: stdAn.vx, unit: 'm/s', color: 'text-gray-600' },
                    { label: 'Initial vy', value: stdAn.vy0, unit: 'm/s', color: 'text-rose-500' },
                  ].map(s => (
                    <div key={s.label} className="flex justify-between items-center rounded-lg bg-gray-50 px-3 py-2">
                      <span className="text-xs text-gray-500">{s.label}</span>
                      <span className={`text-sm font-semibold tabular-nums ${s.color}`}>{s.value} <span className="text-xs font-normal text-gray-400">{s.unit}</span></span>
                    </div>
                  ))}
                  {mode === 'horizontal' && [
                    { label: 'Time of flight', value: hrzAn.tFlight, unit: 's', color: 'text-indigo-600' },
                    { label: 'Range', value: hrzAn.range, unit: 'm', color: 'text-emerald-600' },
                    { label: 'Landing speed', value: hrzAn.vLand, unit: 'm/s', color: 'text-amber-600' },
                    { label: 'Landing angle', value: hrzAn.angleLand, unit: '° below horizontal', color: 'text-rose-500' },
                  ].map(s => (
                    <div key={s.label} className="flex justify-between items-center rounded-lg bg-gray-50 px-3 py-2">
                      <span className="text-xs text-gray-500">{s.label}</span>
                      <span className={`text-sm font-semibold tabular-nums ${s.color}`}>{s.value} <span className="text-xs font-normal text-gray-400">{s.unit}</span></span>
                    </div>
                  ))}
                  {mode === 'vertical' && [
                    { label: 'Max height', value: vtcAn.maxHeight, unit: 'm', color: 'text-indigo-600' },
                    { label: 'Time to max height', value: vtcAn.timeToMax, unit: 's', color: 'text-amber-600' },
                    { label: 'Total flight time', value: vtcAn.tFlight, unit: 's', color: 'text-emerald-600' },
                    { label: 'Landing speed', value: vtcAn.vLand, unit: 'm/s', color: 'text-rose-500' },
                  ].map(s => (
                    <div key={s.label} className="flex justify-between items-center rounded-lg bg-gray-50 px-3 py-2">
                      <span className="text-xs text-gray-500">{s.label}</span>
                      <span className={`text-sm font-semibold tabular-nums ${s.color}`}>{s.value} <span className="text-xs font-normal text-gray-400">{s.unit}</span></span>
                    </div>
                  ))}
                  {mode === 'inclined' && [
                    { label: 'Time of flight', value: incAn.tFlight, unit: 's', color: 'text-indigo-600' },
                    { label: 'Range along slope', value: incAn.rangeAlongIncline, unit: 'm', color: 'text-emerald-600' },
                    { label: 'Horizontal range', value: incAn.rangeHorizontal, unit: 'm', color: 'text-amber-600' },
                    { label: 'Max height above slope', value: incAn.maxHeightAboveIncline, unit: 'm', color: 'text-rose-500' },
                  ].map(s => (
                    <div key={s.label} className="flex justify-between items-center rounded-lg bg-gray-50 px-3 py-2">
                      <span className="text-xs text-gray-500">{s.label}</span>
                      <span className={`text-sm font-semibold tabular-nums ${s.color}`}>{s.value} <span className="text-xs font-normal text-gray-400">{s.unit}</span></span>
                    </div>
                  ))}
                </div>
              </div>

              {/* Live values */}
              {livePos.t > 0 && (
                <div className="rounded-2xl border border-indigo-100 bg-indigo-50 p-4">
                  <p className="text-xs font-medium text-indigo-400 uppercase tracking-wide mb-2">Live position</p>
                  <div className="grid grid-cols-3 gap-2">
                    {[
                      { label: 'Time', value: livePos.t.toFixed(2), unit: 's' },
                      { label: mode === 'vertical' ? 'Height' : 'x', value: mode === 'vertical' ? livePos.y.toFixed(1) : livePos.x.toFixed(1), unit: 'm' },
                      { label: 'Height y', value: livePos.y.toFixed(1), unit: 'm' },
                    ].map(v => (
                      <div key={v.label} className="rounded-xl bg-white border border-indigo-100 p-2 text-center">
                        <p className="text-[10px] text-indigo-300 mb-0.5">{v.label}</p>
                        <p className="text-sm font-semibold text-indigo-700 tabular-nums">{v.value}</p>
                        <p className="text-[10px] text-indigo-300">{v.unit}</p>
                      </div>
                    ))}
                  </div>
                </div>
              )}

              {/* Curriculum */}
              <div className="rounded-2xl border border-gray-200 bg-white p-4">
                <p className="text-xs text-gray-400 mb-2">Curriculum</p>
                <div className="flex flex-wrap gap-1.5">
                  {CURRICULA.map(c => (
                    <span key={c} className={`text-xs font-medium px-2 py-0.5 rounded-full ${
                      activeCurricula.includes(c) ? CURRICULUM_COLORS[c] : 'bg-gray-100 text-gray-400'
                    }`}>{c}</span>
                  ))}
                </div>
              </div>
            </div>

            {/* Teacher notes + exercises */}
            <div className="space-y-3">
              <div className="rounded-2xl border border-amber-100 bg-amber-50 p-4">
                <p className="text-xs font-medium text-amber-700 uppercase tracking-wide mb-3">📋 Teacher notes</p>
                <ul className="space-y-2">
                  {TEACHER_NOTES[mode].map((note, i) => (
                    <li key={i} className="text-xs text-amber-900 leading-relaxed flex gap-2">
                      <span className="text-amber-400 shrink-0 mt-0.5">•</span>{note}
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
                        <span><span className="font-medium text-indigo-600">Q{i + 1}.</span> {ex.q}</span>
                        <span className="text-gray-300 shrink-0 text-base leading-none">{openEx === i ? '▲' : '▼'}</span>
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
EOF

echo ""
echo "✅ Projectile motion modes complete!"
echo ""
echo "Files written:"
echo "  src/lib/physics/projectile-modes.ts"
echo "  src/components/simulation/ProjectileModeCanvas.tsx"
echo "  src/app/simulations/projectile-motion/page.tsx"
echo ""
echo "Four modes available:"
echo "  🎯 Standard     — launched at angle from height"
echo "  🏗️  Horizontal   — horizontal throw from cliff/building"
echo "  ⬆️  Vertical     — up/down throw or free fall"
echo "  📐 Inclined     — launched along a slope"
echo ""
echo "Visit: http://localhost:3000/simulations/projectile-motion"
