#!/bin/bash
# Fix: projectile animation + mobile responsive
# Run inside af2s/: bash projectile-fix.sh
set -e
echo "Fixing projectile canvas and mobile layout..."

cat > src/components/simulation/ProjectileModeCanvas.tsx << 'EOF'
'use client';
import { useEffect, useRef, useState } from 'react';
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

type PathPoint = { t: number; x?: number; y: number };

const PAD = 44;
const GROUND_H = 40;
const BALL_R = 7;
const DT = 0.03;

function toC(
  wx: number, wy: number,
  xMin: number, xMax: number,
  yMin: number, yMax: number,
  W: number, H: number
): [number, number] {
  const safeXRange = xMax - xMin || 1;
  const safeYRange = yMax - yMin || 1;
  return [
    PAD + ((wx - xMin) / safeXRange) * (W - PAD * 2),
    H - GROUND_H - ((wy - yMin) / safeYRange) * (H - GROUND_H - PAD),
  ];
}

function getExtents(path: PathPoint[]) {
  const xs = path.map(p => p.x ?? 0);
  const ys = path.map(p => p.y);
  return {
    xMin: 0,
    xMax: Math.max(...xs, 1) * 1.15,
    yMin: 0,
    yMax: Math.max(...ys, 1) * 1.25,
  };
}

function drawFrame(
  canvas: HTMLCanvasElement,
  path: PathPoint[],
  stepIdx: number,
  trail: [number, number][],
  mode: ProjectileMode,
  params: { standard?: StandardParams; horizontal?: HorizontalParams; vertical?: VerticalParams; inclined?: InclinedParams },
  toggles: { trail: boolean; vector: boolean; grid: boolean },
  showHUD: boolean
) {
  const ctx = canvas.getContext('2d');
  if (!ctx) return;
  const W = canvas.width, H = canvas.height;
  const ext = getExtents(path);
  const tc = (wx: number, wy: number) => toC(wx, wy, ext.xMin, ext.xMax, ext.yMin, ext.yMax, W, H);

  ctx.clearRect(0, 0, W, H);

  // Sky
  const sky = ctx.createLinearGradient(0, 0, 0, H - GROUND_H);
  sky.addColorStop(0, '#dbeafe'); sky.addColorStop(1, '#f0f6ff');
  ctx.fillStyle = sky; ctx.fillRect(0, 0, W, H - GROUND_H);

  // Ground
  ctx.fillStyle = '#e2e8f0'; ctx.fillRect(0, H - GROUND_H, W, GROUND_H);
  ctx.beginPath(); ctx.moveTo(0, H - GROUND_H); ctx.lineTo(W, H - GROUND_H);
  ctx.strokeStyle = '#94a3b8'; ctx.lineWidth = 2; ctx.stroke();

  // Platform / cliff
  const h0 = mode === 'standard' ? (params.standard?.h0 ?? 0) :
             mode === 'horizontal' ? (params.horizontal?.h ?? 0) : 0;
  if (h0 > 0) {
    const [, byPlat] = tc(0, h0);
    ctx.fillStyle = '#94a3b8';
    ctx.fillRect(0, byPlat, PAD + 4, H - GROUND_H - byPlat);
    ctx.strokeStyle = '#64748b'; ctx.lineWidth = 1.5;
    ctx.strokeRect(0, byPlat, PAD + 4, H - GROUND_H - byPlat);
    ctx.fillStyle = '#475569'; ctx.font = 'bold 10px system-ui';
    ctx.textAlign = 'center';
    ctx.fillText(`${h0}m`, (PAD + 4) / 2, byPlat - 5);
  }

  // Inclined surface
  if (mode === 'inclined' && params.inclined) {
    const beta = params.inclined.beta * Math.PI / 180;
    const totalX = Math.max(...path.map(p => p.x ?? 0)) * 1.2;
    const [x0, y0] = tc(0, 0);
    const [x1, y1] = tc(totalX, totalX * Math.tan(beta));
    ctx.beginPath(); ctx.moveTo(x0, y0); ctx.lineTo(x1, y1);
    ctx.strokeStyle = '#64748b'; ctx.lineWidth = 3; ctx.stroke();
    ctx.fillStyle = '#94a3b8'; ctx.font = '10px system-ui'; ctx.textAlign = 'center';
    ctx.fillText(`β=${params.inclined.beta}°`, (x0 + x1) / 2, (y0 + y1) / 2 + 14);
  }

  // Grid
  if (toggles.grid) {
    ctx.save();
    ctx.strokeStyle = '#e2e8f0'; ctx.lineWidth = 1;
    ctx.fillStyle = '#94a3b8'; ctx.font = '10px system-ui';
    const xStep = Math.ceil(ext.xMax / 5 / 5) * 5 || 1;
    ctx.textAlign = 'center';
    for (let x = 0; x <= ext.xMax; x += xStep) {
      const [cx] = tc(x, 0);
      ctx.beginPath(); ctx.setLineDash([3, 4]);
      ctx.moveTo(cx, PAD); ctx.lineTo(cx, H - GROUND_H); ctx.stroke();
      ctx.setLineDash([]);
      if (mode !== 'vertical') ctx.fillText(`${x}m`, cx, H - GROUND_H + 13);
    }
    ctx.textAlign = 'right';
    const yStep = Math.ceil(ext.yMax / 4 / 5) * 5 || 1;
    for (let y = 0; y <= ext.yMax; y += yStep) {
      const [, cy] = tc(0, y);
      if (cy < PAD) continue;
      ctx.beginPath(); ctx.setLineDash([3, 4]);
      ctx.moveTo(PAD, cy); ctx.lineTo(W - PAD, cy); ctx.stroke();
      ctx.setLineDash([]);
      ctx.fillText(`${y}m`, PAD - 3, cy + 4);
    }
    ctx.restore();
  }

  // Ghost trajectory
  if (path.length > 1) {
    ctx.save(); ctx.beginPath();
    const [x0, y0] = tc(path[0].x ?? 0, path[0].y);
    ctx.moveTo(x0, y0);
    path.slice(1).forEach(pt => { const [cx, cy] = tc(pt.x ?? 0, pt.y); ctx.lineTo(cx, cy); });
    ctx.strokeStyle = 'rgba(99,102,241,0.18)'; ctx.lineWidth = 2;
    ctx.setLineDash([6, 4]); ctx.stroke(); ctx.setLineDash([]); ctx.restore();
  }

  // Trail
  if (toggles.trail && trail.length > 1) {
    ctx.save();
    for (let i = 1; i < trail.length; i++) {
      const alpha = i / trail.length;
      ctx.beginPath();
      ctx.moveTo(trail[i-1][0], trail[i-1][1]);
      ctx.lineTo(trail[i][0], trail[i][1]);
      ctx.strokeStyle = `rgba(99,102,241,${alpha * 0.8})`;
      ctx.lineWidth = 2.5; ctx.stroke();
    }
    ctx.restore();
  }

  // Ball
  const cur = path[Math.min(stepIdx, path.length - 1)];
  const [bx, by] = tc(cur.x ?? 0, Math.max(0, cur.y));

  ctx.save();
  ctx.beginPath();
  const [, gy] = tc(0, 0);
  ctx.ellipse(bx, gy + 4, 10, 4, 0, 0, Math.PI * 2);
  ctx.fillStyle = 'rgba(0,0,0,0.1)'; ctx.fill();
  const glow = ctx.createRadialGradient(bx, by, 0, bx, by, BALL_R * 2.5);
  glow.addColorStop(0, 'rgba(79,70,229,0.3)'); glow.addColorStop(1, 'transparent');
  ctx.beginPath(); ctx.arc(bx, by, BALL_R * 2.5, 0, Math.PI * 2);
  ctx.fillStyle = glow; ctx.fill();
  const ballG = ctx.createRadialGradient(bx - 2, by - 2, 1, bx, by, BALL_R);
  ballG.addColorStop(0, '#818cf8'); ballG.addColorStop(1, '#4f46e5');
  ctx.beginPath(); ctx.arc(bx, by, BALL_R, 0, Math.PI * 2);
  ctx.fillStyle = ballG; ctx.fill();
  ctx.restore();

  // Velocity vector
  if (toggles.vector && stepIdx < path.length - 2) {
    const next = path[Math.min(stepIdx + 3, path.length - 1)];
    const dtv = Math.max(next.t - cur.t, 0.001);
    const vx = ((next.x ?? 0) - (cur.x ?? 0)) / dtv;
    const vy = (next.y - cur.y) / dtv;
    const speed = Math.sqrt(vx * vx + vy * vy);
    if (speed > 0.3) {
      const [nx] = tc(cur.x ?? 0 + vx * 0.5, 0);
      const [bx0] = tc(cur.x ?? 0, 0);
      const pxPerMs = (nx - bx0);
      const arrowLen = Math.min(Math.abs(pxPerMs) * 2, 60);
      const angle = Math.atan2(-vy, vx + 0.001);
      const ex = bx + Math.cos(angle) * arrowLen;
      const ey = by + Math.sin(angle) * arrowLen;
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
  if (showHUD && cur.t > 0) {
    const lines = [
      `t = ${cur.t.toFixed(2)}s`,
      mode !== 'vertical' ? `x = ${(cur.x ?? 0).toFixed(1)}m` : '',
      `y = ${Math.max(0, cur.y).toFixed(1)}m`,
    ].filter(Boolean);
    const bw = 108, bh = lines.length * 18 + 14, bhx = W - bw - 8;
    ctx.save();
    ctx.fillStyle = 'rgba(255,255,255,0.92)';
    ctx.beginPath(); ctx.roundRect(bhx, 8, bw, bh, 8); ctx.fill();
    ctx.strokeStyle = 'rgba(99,102,241,0.2)'; ctx.lineWidth = 1; ctx.stroke();
    ctx.fillStyle = '#1e293b'; ctx.font = '11px monospace'; ctx.textAlign = 'left';
    lines.forEach((l, i) => ctx.fillText(l, bhx + 8, 24 + i * 18));
    ctx.restore();
  }
}

export function ProjectileModeCanvas({
  mode, standard, horizontal, vertical, inclined,
  isRunning, isPaused, onComplete, onTick,
  width = 680, height = 300,
}: Props) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const rafRef = useRef<number>(0);
  const stepRef = useRef(0);
  const trailRef = useRef<[number, number][]>([]);
  const doneRef = useRef(false);
  const pathRef = useRef<PathPoint[]>([]);
  const [toggles, setToggles] = useState({ trail: true, vector: true, grid: true });
  const [showToggles, setShowToggles] = useState(false);

  const simRef = useRef({ mode, standard, horizontal, vertical, inclined, isRunning, isPaused, onComplete, onTick, toggles, width, height });
  simRef.current = { mode, standard, horizontal, vertical, inclined, isRunning, isPaused, onComplete, onTick, toggles, width, height };

  // Rebuild path when params change
  useEffect(() => {
    cancelAnimationFrame(rafRef.current);
    let path: PathPoint[] = [];
    if (mode === 'standard' && standard) path = standardPath(standard) as PathPoint[];
    else if (mode === 'horizontal' && horizontal) path = horizontalPath(horizontal) as PathPoint[];
    else if (mode === 'vertical' && vertical) path = verticalPath(vertical).map(p => ({ ...p, x: 0 }));
    else if (mode === 'inclined' && inclined) path = inclinedPath(inclined) as PathPoint[];
    pathRef.current = path.length ? path : [{ t: 0, x: 0, y: 0 }];
    stepRef.current = 0;
    trailRef.current = [];
    doneRef.current = false;
    const canvas = canvasRef.current;
    if (canvas) {
      drawFrame(canvas, pathRef.current, 0, [], mode,
        { standard, horizontal, vertical, inclined },
        simRef.current.toggles, false);
    }
  }, [mode, standard, horizontal, vertical, inclined]); // eslint-disable-line

  // Single RAF loop
  useEffect(() => {
    const loop = () => {
      const { isRunning: r, isPaused: p, onTick: ot, onComplete: oc, toggles: tog } = simRef.current;
      const path = pathRef.current;
      const canvas = canvasRef.current;

      if (r && !p && !doneRef.current && path.length > 1) {
        stepRef.current = Math.min(stepRef.current + 1, path.length - 1);
        const cur = path[stepRef.current];

        // Add to trail
        if (canvas) {
          const ext = getExtents(path);
          const [bx, by] = toC(cur.x ?? 0, Math.max(0, cur.y),
            ext.xMin, ext.xMax, ext.yMin, ext.yMax,
            simRef.current.width, simRef.current.height);
          trailRef.current.push([bx, by]);
          if (trailRef.current.length > 160) trailRef.current.shift();
        }

        ot?.(cur.t, cur.x ?? 0, Math.max(0, cur.y));

        if (stepRef.current >= path.length - 1) {
          doneRef.current = true;
          oc?.();
        }
      }

      if (canvas) {
        drawFrame(canvas, path, stepRef.current, trailRef.current,
          simRef.current.mode,
          { standard: simRef.current.standard, horizontal: simRef.current.horizontal, vertical: simRef.current.vertical, inclined: simRef.current.inclined },
          tog, r || stepRef.current > 0);
      }

      rafRef.current = requestAnimationFrame(loop);
    };
    rafRef.current = requestAnimationFrame(loop);
    return () => cancelAnimationFrame(rafRef.current);
  }, []); // eslint-disable-line

  const toggleItem = (k: 'trail' | 'vector' | 'grid') =>
    setToggles(t => ({ ...t, [k]: !t[k] }));

  return (
    <div className="space-y-2">
      <div className="flex items-center gap-2 flex-wrap">
        <button onClick={() => setShowToggles(v => !v)}
          className={`flex items-center gap-1.5 rounded-lg border px-3 py-1.5 text-xs font-medium transition ${
            showToggles ? 'border-indigo-300 bg-indigo-50 text-indigo-700' : 'border-gray-200 bg-white text-gray-600 hover:bg-gray-50'
          }`}>
          <svg width="12" height="12" viewBox="0 0 12 12" fill="none" stroke="currentColor" strokeWidth="1.5">
            <circle cx="6" cy="6" r="2"/><path d="M6 1v1M6 10v1M1 6h1M10 6h1"/>
          </svg>
          Overlays
        </button>
        {showToggles && (['trail', 'vector', 'grid'] as const).map(k => (
          <button key={k} onClick={() => toggleItem(k)}
            className={`rounded-full px-3 py-1 text-xs font-medium border transition ${
              toggles[k] ? 'bg-indigo-600 text-white border-indigo-600' : 'bg-white text-gray-400 border-gray-200'
            }`}>
            {k === 'trail' ? 'Trail' : k === 'vector' ? 'Velocity vector' : 'Grid'}
          </button>
        ))}
      </div>
      <div className="relative w-full overflow-hidden rounded-xl border border-gray-200 bg-white shadow-sm">
        <canvas ref={canvasRef} width={width} height={height}
          className="w-full" style={{ display: 'block' }} />
      </div>
    </div>
  );
}
EOF

# ── Updated page with proper mobile layout ────────────────────────────────────
cat > src/app/simulations/projectile-motion/page.tsx << 'EOF'
'use client';
import { useState, useCallback, useEffect, useRef } from 'react';
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

  const std: StandardParams   = { v0, angle, g, h0 };
  const hrz: HorizontalParams = { v0: hV0, h: hH, g };
  const vtc: VerticalParams   = { v0: vV0, h0: vH0, g };
  const inc: InclinedParams   = { v0: iV0, alpha: iAlpha, beta: iBeta, g };

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
  }, [mode, v0, angle, g, h0, hV0, hH, vV0, vH0, iV0, iAlpha, iBeta, reset]);

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
                    <StatRow label="Height above slope" value={incA.maxHeightAboveIncline} unit="m" color="text-rose-500" />
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
EOF

echo ""
echo "✅ Projectile fix complete!"
echo "   Animation: step-based (no recalculation per frame)"
echo "   Mobile: single column → 2-col lg → 3-col xl"
echo ""
echo "Visit: http://localhost:3000/simulations/projectile-motion"
