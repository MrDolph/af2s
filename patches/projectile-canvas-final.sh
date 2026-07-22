#!/bin/bash
# Final projectile canvas fix — clean single-loop approach
# Run inside af2s/: bash projectile-canvas-final.sh
set -e
echo "Writing final ProjectileModeCanvas..."

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

type Pt = { t: number; x?: number; y: number };

const PAD = 44;
const GH  = 40;   // ground height px
const BR  = 7;    // ball radius

// ── coordinate helpers ────────────────────────────────────────────────────────
function extents(path: Pt[]) {
  const xs = path.map(p => p.x ?? 0);
  const ys = path.map(p => p.y);
  return {
    xMin: 0, xMax: Math.max(...xs, 1) * 1.15,
    yMin: 0, yMax: Math.max(...ys, 1) * 1.25,
  };
}

function toC(
  wx: number, wy: number,
  xMin: number, xMax: number,
  yMin: number, yMax: number,
  W: number, H: number
): [number, number] {
  return [
    PAD + ((wx - xMin) / (xMax - xMin || 1)) * (W - PAD * 2),
    H - GH - ((wy - yMin) / (yMax - yMin || 1)) * (H - GH - PAD),
  ];
}

// ── drawing ───────────────────────────────────────────────────────────────────
function render(
  canvas: HTMLCanvasElement,
  path: Pt[],
  idx: number,
  trail: [number, number][],
  mode: ProjectileMode,
  params: Props,
  showGrid: boolean,
  showTrail: boolean,
  showVec: boolean,
  showHUD: boolean,
) {
  const ctx = canvas.getContext('2d');
  if (!ctx || !path.length) return;
  const W = canvas.width, H = canvas.height;
  const ext = extents(path);
  const tc = (wx: number, wy: number) =>
    toC(wx, wy, ext.xMin, ext.xMax, ext.yMin, ext.yMax, W, H);

  ctx.clearRect(0, 0, W, H);

  // Sky
  const sky = ctx.createLinearGradient(0, 0, 0, H - GH);
  sky.addColorStop(0, '#dbeafe'); sky.addColorStop(1, '#f0f6ff');
  ctx.fillStyle = sky; ctx.fillRect(0, 0, W, H - GH);

  // Ground
  ctx.fillStyle = '#e2e8f0'; ctx.fillRect(0, H - GH, W, GH);
  ctx.beginPath(); ctx.moveTo(0, H - GH); ctx.lineTo(W, H - GH);
  ctx.strokeStyle = '#94a3b8'; ctx.lineWidth = 2; ctx.stroke();

  // Platform / cliff
  const h0 = mode === 'standard'   ? (params.standard?.h0    ?? 0)
           : mode === 'horizontal' ? (params.horizontal?.h   ?? 0)
           : mode === 'vertical'   ? (params.vertical?.h0    ?? 0) : 0;
  if (h0 > 0) {
    const [, byP] = tc(0, h0);
    ctx.fillStyle = '#94a3b8';
    ctx.fillRect(0, byP, PAD + 4, H - GH - byP);
    ctx.strokeStyle = '#64748b'; ctx.lineWidth = 1.5;
    ctx.strokeRect(0, byP, PAD + 4, H - GH - byP);
    ctx.fillStyle = '#475569'; ctx.font = 'bold 10px system-ui';
    ctx.textAlign = 'center';
    ctx.fillText(`${h0}m`, (PAD + 4) / 2, byP - 5);
  }

  // Inclined surface
  if (mode === 'inclined' && params.inclined) {
    const beta = params.inclined.beta * Math.PI / 180;
    const maxX = Math.max(...path.map(p => p.x ?? 0)) * 1.3;
    const [x0, y0] = tc(0, 0);
    const [x1, y1] = tc(maxX, maxX * Math.tan(beta));
    ctx.beginPath(); ctx.moveTo(x0, y0); ctx.lineTo(x1, y1);
    ctx.strokeStyle = '#64748b'; ctx.lineWidth = 3; ctx.stroke();
    ctx.fillStyle = '#94a3b8'; ctx.font = '10px system-ui'; ctx.textAlign = 'center';
    ctx.fillText(`β=${params.inclined.beta}°`, (x0 + x1) / 2, (y0 + y1) / 2 + 14);
  }

  // Grid
  if (showGrid) {
    ctx.save();
    ctx.strokeStyle = '#e2e8f0'; ctx.lineWidth = 1;
    ctx.fillStyle = '#94a3b8'; ctx.font = '10px system-ui';
    const xStep = Math.ceil(ext.xMax / 5 / 5) * 5 || 1;
    ctx.textAlign = 'center';
    for (let x = 0; x <= ext.xMax; x += xStep) {
      const [cx2] = tc(x, 0);
      ctx.beginPath(); ctx.setLineDash([3, 4]);
      ctx.moveTo(cx2, PAD); ctx.lineTo(cx2, H - GH); ctx.stroke();
      ctx.setLineDash([]);
      if (mode !== 'vertical') ctx.fillText(`${x}m`, cx2, H - GH + 13);
    }
    ctx.textAlign = 'right';
    const yStep = Math.ceil(ext.yMax / 4 / 5) * 5 || 1;
    for (let y = 0; y <= ext.yMax; y += yStep) {
      const [, cy2] = tc(0, y);
      if (cy2 < PAD) continue;
      ctx.beginPath(); ctx.setLineDash([3, 4]);
      ctx.moveTo(PAD, cy2); ctx.lineTo(W - PAD, cy2); ctx.stroke();
      ctx.setLineDash([]);
      ctx.fillText(`${y}m`, PAD - 3, cy2 + 4);
    }
    ctx.restore();
  }

  // Ghost trajectory
  if (path.length > 1) {
    ctx.save(); ctx.beginPath();
    const [gx0, gy0] = tc(path[0].x ?? 0, path[0].y);
    ctx.moveTo(gx0, gy0);
    path.slice(1).forEach(pt => {
      const [cx2, cy2] = tc(pt.x ?? 0, pt.y);
      ctx.lineTo(cx2, cy2);
    });
    ctx.strokeStyle = 'rgba(99,102,241,0.18)'; ctx.lineWidth = 2;
    ctx.setLineDash([6, 4]); ctx.stroke(); ctx.setLineDash([]); ctx.restore();
  }

  // Trail
  if (showTrail && trail.length > 1) {
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
  const cur = path[Math.min(idx, path.length - 1)];
  const [bx, by] = tc(cur.x ?? 0, Math.max(0, cur.y));

  // Shadow
  const [, gy] = tc(0, 0);
  ctx.beginPath(); ctx.ellipse(bx, gy + 4, 10, 4, 0, 0, Math.PI * 2);
  ctx.fillStyle = 'rgba(0,0,0,0.1)'; ctx.fill();

  // Glow
  const glow = ctx.createRadialGradient(bx, by, 0, bx, by, BR * 2.5);
  glow.addColorStop(0, 'rgba(79,70,229,0.3)'); glow.addColorStop(1, 'transparent');
  ctx.beginPath(); ctx.arc(bx, by, BR * 2.5, 0, Math.PI * 2);
  ctx.fillStyle = glow; ctx.fill();

  // Ball body
  const ballG = ctx.createRadialGradient(bx - 2, by - 2, 1, bx, by, BR);
  ballG.addColorStop(0, '#818cf8'); ballG.addColorStop(1, '#4f46e5');
  ctx.beginPath(); ctx.arc(bx, by, BR, 0, Math.PI * 2);
  ctx.fillStyle = ballG; ctx.fill();

  // Velocity vector
  if (showVec && idx > 0 && idx < path.length - 2) {
    const next = path[Math.min(idx + 3, path.length - 1)];
    const prev = path[Math.max(idx - 1, 0)];
    const dt = Math.max(next.t - prev.t, 0.001);
    const vx = ((next.x ?? 0) - (prev.x ?? 0)) / dt;
    const vy = (next.y - prev.y) / dt;
    const spd = Math.sqrt(vx * vx + vy * vy);
    if (spd > 0.3) {
      const [nx] = tc((cur.x ?? 0) + vx * 0.5, 0);
      const [bx0] = tc(cur.x ?? 0, 0);
      const scl = Math.min(Math.abs(nx - bx0) * 2.5, 65);
      const ang = Math.atan2(-vy / (ext.yMax || 1), vx / (ext.xMax || 1));
      const ex = bx + Math.cos(ang) * scl;
      const ey = by + Math.sin(ang) * scl;
      ctx.save();
      ctx.beginPath(); ctx.moveTo(bx, by); ctx.lineTo(ex, ey);
      ctx.strokeStyle = '#f59e0b'; ctx.lineWidth = 2.5; ctx.stroke();
      const hL = 8, hA = 0.4;
      ctx.beginPath(); ctx.moveTo(ex, ey);
      ctx.lineTo(ex - hL * Math.cos(ang - hA), ey - hL * Math.sin(ang - hA));
      ctx.lineTo(ex - hL * Math.cos(ang + hA), ey - hL * Math.sin(ang + hA));
      ctx.closePath(); ctx.fillStyle = '#f59e0b'; ctx.fill();
      ctx.restore();
    }
  }

  // HUD
  if (showHUD && cur.t > 0) {
    const lines = [
      `t = ${cur.t.toFixed(2)}s`,
      ...(mode !== 'vertical' ? [`x = ${(cur.x ?? 0).toFixed(1)}m`] : []),
      `y = ${Math.max(0, cur.y).toFixed(1)}m`,
    ];
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

// ── Component ─────────────────────────────────────────────────────────────────
export function ProjectileModeCanvas({
  mode, standard, horizontal, vertical, inclined,
  isRunning, isPaused, onComplete, onTick,
  width = 680, height = 300,
}: Props) {
  const canvasRef   = useRef<HTMLCanvasElement | null>(null);
  const rafRef      = useRef<number>(0);
  const pathRef     = useRef<Pt[]>([]);
  const idxRef      = useRef(0);
  const trailRef    = useRef<[number,number][]>([]);
  const doneRef     = useRef(false);
  // live copies of props — updated every render, no re-subscription needed
  const liveRef = useRef({ isRunning, isPaused, onComplete, onTick,
    mode, standard, horizontal, vertical, inclined, width, height });
  liveRef.current = { isRunning, isPaused, onComplete, onTick,
    mode, standard, horizontal, vertical, inclined, width, height };

  const [showGrid,  setShowGrid]  = useState(true);
  const [showTrail, setShowTrail] = useState(true);
  const [showVec,   setShowVec]   = useState(true);
  const [showOvl,   setShowOvl]   = useState(false);
  // keep toggles accessible inside RAF
  const togRef = useRef({ showGrid, showTrail, showVec });
  togRef.current = { showGrid, showTrail, showVec };

  // ── Rebuild path when key props change ────────────────────────────────────
  useEffect(() => {
    let path: Pt[] = [];
    if (mode === 'standard'   && standard)   path = standardPath(standard)   as Pt[];
    if (mode === 'horizontal' && horizontal) path = horizontalPath(horizontal) as Pt[];
    if (mode === 'vertical'   && vertical)   path = verticalPath(vertical).map(p => ({ ...p, x: 0 }));
    if (mode === 'inclined'   && inclined)   path = inclinedPath(inclined)   as Pt[];

    // Normalise to ~300 points so animation is neither too fast nor too slow
    if (path.length > 400) {
      const step = Math.ceil(path.length / 300);
      path = path.filter((_, i) => i % step === 0 || i === path.length - 1);
    }
    if (path.length < 5) path = [{ t: 0, x: 0, y: 0 }];

    pathRef.current   = path;
    idxRef.current    = 0;
    trailRef.current  = [];
    doneRef.current   = false;

    // Draw frame 0 immediately so canvas isn't blank
    const canvas = canvasRef.current;
    if (canvas) {
      render(canvas, path, 0, [], mode,
        { mode, standard, horizontal, vertical, inclined, isRunning: false, isPaused: false },
        togRef.current.showGrid, false, false, false);
    }
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [mode, standard, horizontal, vertical, inclined]);

  // ── Single RAF loop — starts on mount, never restarts ─────────────────────
  useEffect(() => {
    const loop = () => {
      const lv = liveRef.current;
      const tog = togRef.current;
      const path = pathRef.current;
      const canvas = canvasRef.current;

      // Advance index
      if (lv.isRunning && !lv.isPaused && !doneRef.current && path.length > 1) {
        idxRef.current = Math.min(idxRef.current + 1, path.length - 1);
        const cur = path[idxRef.current];
        const ext = extents(path);

        // Trail point in canvas coords
        const [tbx, tby] = toC(
          cur.x ?? 0, Math.max(0, cur.y),
          ext.xMin, ext.xMax, ext.yMin, ext.yMax,
          lv.width, lv.height
        );
        trailRef.current.push([tbx, tby]);
        if (trailRef.current.length > 180) trailRef.current.shift();

        lv.onTick?.(cur.t, cur.x ?? 0, Math.max(0, cur.y));

        if (idxRef.current >= path.length - 1) {
          doneRef.current = true;
          lv.onComplete?.();
        }
      }

      // Always draw (even when paused — so param changes show immediately)
      if (canvas) {
        render(
          canvas, path, idxRef.current, trailRef.current,
          lv.mode,
          { mode: lv.mode, standard: lv.standard, horizontal: lv.horizontal,
            vertical: lv.vertical, inclined: lv.inclined,
            isRunning: lv.isRunning, isPaused: lv.isPaused },
          tog.showGrid, tog.showTrail, tog.showVec,
          lv.isRunning || idxRef.current > 0
        );
      }

      rafRef.current = requestAnimationFrame(loop);
    };

    rafRef.current = requestAnimationFrame(loop);
    return () => cancelAnimationFrame(rafRef.current);
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  return (
    <div className="space-y-2">
      {/* Toolbar */}
      <div className="flex items-center gap-2 flex-wrap">
        <button
          onClick={() => setShowOvl(v => !v)}
          className={`flex items-center gap-1.5 rounded-lg border px-3 py-1.5 text-xs font-medium transition ${
            showOvl ? 'border-indigo-300 bg-indigo-50 text-indigo-700'
                    : 'border-gray-200 bg-white text-gray-600 hover:bg-gray-50'
          }`}
        >
          <svg width="12" height="12" viewBox="0 0 12 12" fill="none"
            stroke="currentColor" strokeWidth="1.5">
            <circle cx="6" cy="6" r="2"/>
            <path d="M6 1v1M6 10v1M1 6h1M10 6h1"/>
          </svg>
          Overlays
        </button>

        {showOvl && (
          <>
            {([
              ['Grid',           showGrid,  setShowGrid],
              ['Trail',          showTrail, setShowTrail],
              ['Velocity arrow', showVec,   setShowVec],
            ] as [string, boolean, (v: boolean) => void][]).map(([label, on, setter]) => (
              <button
                key={label}
                onClick={() => setter(!on)}
                className={`rounded-full px-3 py-1 text-xs font-medium border transition ${
                  on ? 'bg-indigo-600 text-white border-indigo-600'
                     : 'bg-white text-gray-400 border-gray-200 hover:border-gray-300'
                }`}
              >
                {label}
              </button>
            ))}
          </>
        )}
      </div>

      {/* Canvas */}
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
EOF

echo "✅ ProjectileModeCanvas rewritten!"
echo "Run: npm run dev -- --webpack"
echo "Visit: http://localhost:3000/simulations/projectile-motion"
