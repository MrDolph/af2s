#!/bin/bash
# Projectile motion — live-step canvas (same engine as homepage)
# Run inside af2s/: bash projectile-final2.sh
set -e
echo "Rewriting ProjectileModeCanvas with live-step physics..."

cat > src/components/simulation/ProjectileModeCanvas.tsx << 'EOF'
'use client';
import { useEffect, useRef, useState } from 'react';
import {
  standardPath, horizontalPath, verticalPath, inclinedPath,
  standardAnalytics, horizontalAnalytics, verticalAnalytics,
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

// ── Speed steps ────────────────────────────────────────────────────────────────
const SPEEDS = [
  { label: '0.25×', dt: 0.016, steps: 1, skip: 4  },
  { label: '0.5×',  dt: 0.016, steps: 1, skip: 2  },
  { label: '1×',    dt: 0.016, steps: 1, skip: 1  },
  { label: '2×',    dt: 0.016, steps: 2, skip: 1  },
  { label: '4×',    dt: 0.016, steps: 4, skip: 1  },
];
const DEFAULT_SPEED = 1; // index into SPEEDS

const PAD = 44;
const GH  = 44;
const BR  = 8;

// ── Helpers ────────────────────────────────────────────────────────────────────
function getScale(
  cW: number, cH: number, maxR: number, maxH: number
): number {
  return Math.min(
    (cW - PAD * 2) / (maxR * 1.15),
    (cH - GH - PAD) / (maxH * 1.25)
  );
}

function toC(wx: number, wy: number, scale: number, W: number, H: number, xOff = 0): [number, number] {
  return [
    PAD + (wx - xOff) * scale,
    H - GH - wy * scale,
  ];
}

// ── Draw ───────────────────────────────────────────────────────────────────────
function drawScene(
  canvas: HTMLCanvasElement,
  path: Pt[],
  curX: number, curY: number, curT: number,
  vx: number, vy: number,
  trail: [number, number][],
  scale: number,
  maxRange: number, maxHeight: number,
  mode: ProjectileMode,
  params: Props,
  showGrid: boolean, showTrail: boolean, showVec: boolean,
  showHUD: boolean,
  h0: number,
) {
  const ctx = canvas.getContext('2d');
  if (!ctx) return;
  const W = canvas.width, H = canvas.height;

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
  if (h0 > 0) {
    const [, byP] = toC(0, h0, scale, W, H);
    ctx.fillStyle = '#94a3b8';
    ctx.fillRect(0, byP, PAD + 4, H - GH - byP);
    ctx.strokeStyle = '#64748b'; ctx.lineWidth = 1.5;
    ctx.strokeRect(0, byP, PAD + 4, H - GH - byP);
    ctx.fillStyle = '#475569'; ctx.font = 'bold 10px system-ui';
    ctx.textAlign = 'center';
    ctx.fillText(`${h0}m`, (PAD + 4) / 2, byP - 6);
  }

  // Inclined surface
  if (mode === 'inclined' && params.inclined) {
    const beta = params.inclined.beta * Math.PI / 180;
    const [x0c, y0c] = toC(0, 0, scale, W, H);
    const [x1c, y1c] = toC(maxRange * 1.25, maxRange * 1.25 * Math.tan(beta), scale, W, H);
    ctx.beginPath(); ctx.moveTo(x0c, y0c); ctx.lineTo(x1c, y1c);
    ctx.strokeStyle = '#64748b'; ctx.lineWidth = 3; ctx.stroke();
    ctx.fillStyle = '#94a3b8'; ctx.font = '10px system-ui'; ctx.textAlign = 'center';
    ctx.fillText(`β=${params.inclined.beta}°`, (x0c + x1c) / 2, (y0c + y1c) / 2 + 14);
  }

  // Grid
  if (showGrid) {
    ctx.save();
    ctx.strokeStyle = '#e2e8f0'; ctx.lineWidth = 1;
    ctx.fillStyle = '#94a3b8'; ctx.font = '10px system-ui';
    const xStep = Math.ceil(maxRange / 5 / 5) * 5 || 1;
    ctx.textAlign = 'center';
    for (let x = 0; x <= maxRange * 1.15; x += xStep) {
      const [cx2] = toC(x, 0, scale, W, H);
      ctx.beginPath(); ctx.setLineDash([3, 4]);
      ctx.moveTo(cx2, PAD); ctx.lineTo(cx2, H - GH); ctx.stroke();
      ctx.setLineDash([]);
      if (mode !== 'vertical') ctx.fillText(`${x}m`, cx2, H - GH + 14);
    }
    ctx.textAlign = 'right';
    const yStep = Math.ceil(maxHeight / 4 / 5) * 5 || 1;
    for (let y = 0; y <= maxHeight * 1.25; y += yStep) {
      const [, cy2] = toC(0, y, scale, W, H);
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
    const [gx0, gy0] = toC(path[0].x ?? 0, path[0].y, scale, W, H);
    ctx.moveTo(gx0, gy0);
    path.slice(1).forEach(pt => {
      const [cx2, cy2] = toC(pt.x ?? 0, pt.y, scale, W, H);
      ctx.lineTo(cx2, cy2);
    });
    ctx.strokeStyle = 'rgba(99,102,241,0.18)'; ctx.lineWidth = 2;
    ctx.setLineDash([6, 4]); ctx.stroke(); ctx.setLineDash([]); ctx.restore();
  }

  // Peak marker
  if (maxHeight > 0.5) {
    const [pCx, pCy] = toC(maxRange / 2, maxHeight, scale, W, H);
    ctx.save();
    ctx.beginPath(); ctx.setLineDash([4, 3]);
    ctx.moveTo(pCx, pCy); ctx.lineTo(pCx, H - GH);
    ctx.strokeStyle = 'rgba(99,102,241,0.4)'; ctx.lineWidth = 1.5; ctx.stroke();
    ctx.setLineDash([]);
    ctx.fillStyle = '#6366f1'; ctx.font = 'bold 11px system-ui'; ctx.textAlign = 'center';
    ctx.fillText(`${maxHeight.toFixed(1)}m`, pCx, pCy - 8);
    ctx.restore();
  }

  // Landing marker
  const [lCx] = toC(maxRange, 0, scale, W, H);
  ctx.save();
  ctx.beginPath(); ctx.arc(lCx, H - GH, 5, 0, Math.PI * 2);
  ctx.fillStyle = '#10b981'; ctx.fill();
  ctx.fillStyle = '#10b981'; ctx.font = 'bold 11px system-ui'; ctx.textAlign = 'center';
  ctx.fillText(`${maxRange.toFixed(1)}m`, lCx, H - GH + 32);
  ctx.restore();

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
  const [bx, by] = toC(curX, Math.max(0, curY), scale, W, H);

  // Shadow
  const [, groundY] = toC(0, 0, scale, W, H);
  ctx.beginPath(); ctx.ellipse(bx, groundY + 5, 10, 4, 0, 0, Math.PI * 2);
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
  const speed = Math.sqrt(vx * vx + vy * vy);
  if (showVec && speed > 0.3) {
    const arrowLen = Math.min(speed * scale * 0.3, 65);
    const angle = Math.atan2(-vy, vx);
    const ex = bx + Math.cos(angle) * arrowLen;
    const ey = by + Math.sin(angle) * arrowLen;
    ctx.save();
    ctx.beginPath(); ctx.moveTo(bx, by); ctx.lineTo(ex, ey);
    ctx.strokeStyle = '#f59e0b'; ctx.lineWidth = 2.5; ctx.stroke();
    const hL = 9, hA = 0.4;
    ctx.beginPath(); ctx.moveTo(ex, ey);
    ctx.lineTo(ex - hL * Math.cos(angle - hA), ey - hL * Math.sin(angle - hA));
    ctx.lineTo(ex - hL * Math.cos(angle + hA), ey - hL * Math.sin(angle + hA));
    ctx.closePath(); ctx.fillStyle = '#f59e0b'; ctx.fill();
    ctx.restore();
  }

  // HUD
  if (showHUD && curT > 0) {
    const lines = [
      `t  = ${curT.toFixed(2)}s`,
      ...(mode !== 'vertical' ? [`x  = ${curX.toFixed(1)}m`] : []),
      `y  = ${Math.max(0, curY).toFixed(1)}m`,
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

// ── Component ──────────────────────────────────────────────────────────────────
export function ProjectileModeCanvas({
  mode, standard, horizontal, vertical, inclined,
  isRunning, isPaused, onComplete, onTick,
  width = 680, height = 300,
}: Props) {
  const canvasRef  = useRef<HTMLCanvasElement | null>(null);
  const rafRef     = useRef<number>(0);

  // Physics state — all mutable, lives in refs to avoid re-render
  const stateRef = useRef({ x: 0, y: 0, vx: 0, vy: 0, t: 0 });
  const trailRef = useRef<[number, number][]>([]);
  const doneRef  = useRef(false);
  const skipCtr  = useRef(0); // for slow-motion frame skipping

  // Pre-computed ghost path + analytics
  const pathRef    = useRef<Pt[]>([]);
  const scaleRef   = useRef(1);
  const maxRangeRef  = useRef(1);
  const maxHeightRef = useRef(1);
  const h0Ref        = useRef(0);

  // Live prop mirrors — updated every render, read inside RAF
  const live = useRef({
    mode, standard, horizontal, vertical, inclined,
    isRunning, isPaused, onComplete, onTick, width, height,
  });
  live.current = { mode, standard, horizontal, vertical, inclined,
    isRunning, isPaused, onComplete, onTick, width, height };

  // Toggles
  const [showGrid,  setShowGrid]  = useState(true);
  const [showTrail, setShowTrail] = useState(true);
  const [showVec,   setShowVec]   = useState(true);
  const [showOvl,   setShowOvl]   = useState(false);
  const [speedIdx,  setSpeedIdx]  = useState(DEFAULT_SPEED);
  const togRef = useRef({ showGrid, showTrail, showVec, speedIdx });
  togRef.current = { showGrid, showTrail, showVec, speedIdx };

  // ── Reset helper ──────────────────────────────────────────────────────────
  const doReset = () => {
    const lv = live.current;
    // Initial state depends on mode
    if (lv.mode === 'standard' && lv.standard) {
      const a = lv.standard.angle * Math.PI / 180;
      stateRef.current = {
        x: 0, y: lv.standard.h0,
        vx: lv.standard.v0 * Math.cos(a),
        vy: lv.standard.v0 * Math.sin(a),
        t: 0,
      };
      const an = standardAnalytics(lv.standard);
      maxRangeRef.current  = Math.max(an.range, 0.1);
      maxHeightRef.current = Math.max(an.maxHeight, lv.standard.h0 + 0.1);
      h0Ref.current = lv.standard.h0;
      pathRef.current = standardPath(lv.standard) as Pt[];
    } else if (lv.mode === 'horizontal' && lv.horizontal) {
      stateRef.current = { x: 0, y: lv.horizontal.h, vx: lv.horizontal.v0, vy: 0, t: 0 };
      const an = horizontalAnalytics(lv.horizontal);
      maxRangeRef.current  = Math.max(an.range, 0.1);
      maxHeightRef.current = Math.max(lv.horizontal.h, 0.1);
      h0Ref.current = lv.horizontal.h;
      pathRef.current = horizontalPath(lv.horizontal) as Pt[];
    } else if (lv.mode === 'vertical' && lv.vertical) {
      stateRef.current = { x: 0, y: lv.vertical.h0, vx: 0, vy: lv.vertical.v0, t: 0 };
      const an = verticalAnalytics(lv.vertical);
      maxRangeRef.current  = 1;
      maxHeightRef.current = Math.max(an.maxHeight, 0.1);
      h0Ref.current = lv.vertical.h0;
      pathRef.current = verticalPath(lv.vertical).map(p => ({ ...p, x: 0 }));
    } else if (lv.mode === 'inclined' && lv.inclined) {
      const a = lv.inclined.alpha * Math.PI / 180;
      const b = lv.inclined.beta  * Math.PI / 180;
      stateRef.current = {
        x: 0, y: 0,
        vx: lv.inclined.v0 * (Math.cos(a) * Math.cos(b) - Math.sin(a) * Math.sin(b)),
        vy: lv.inclined.v0 * (Math.cos(a) * Math.sin(b) + Math.sin(a) * Math.cos(b)),
        t: 0,
      };
      const path = inclinedPath(lv.inclined) as Pt[];
      const maxX = Math.max(...path.map(p => p.x ?? 0), 0.1);
      const maxY = Math.max(...path.map(p => p.y), 0.1);
      maxRangeRef.current  = maxX;
      maxHeightRef.current = maxY;
      h0Ref.current = 0;
      pathRef.current = path;
    }
    scaleRef.current = getScale(lv.width, lv.height, maxRangeRef.current, maxHeightRef.current);
    trailRef.current = [];
    doneRef.current  = false;
    skipCtr.current  = 0;
  };

  // ── Rebuild on param change ───────────────────────────────────────────────
  useEffect(() => {
    doReset();
    // Draw initial frame
    const canvas = canvasRef.current;
    if (canvas) {
      const s = stateRef.current;
      drawScene(canvas, pathRef.current, s.x, s.y, 0, s.vx, s.vy, [],
        scaleRef.current, maxRangeRef.current, maxHeightRef.current,
        mode,
        { mode, standard, horizontal, vertical, inclined, isRunning: false, isPaused: false },
        togRef.current.showGrid, false, false, false, h0Ref.current);
    }
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [mode, standard, horizontal, vertical, inclined]);

  // ── Single RAF loop ───────────────────────────────────────────────────────
  useEffect(() => {
    const loop = () => {
      const lv  = live.current;
      const tog = togRef.current;
      const spd = SPEEDS[tog.speedIdx];

      if (lv.isRunning && !lv.isPaused && !doneRef.current) {
        // Frame-skip for slow motion
        skipCtr.current++;
        if (skipCtr.current < spd.skip) {
          rafRef.current = requestAnimationFrame(loop);
          return;
        }
        skipCtr.current = 0;

        // Step physics N times per frame
        for (let i = 0; i < spd.steps; i++) {
          const s = stateRef.current;
          const g = (lv.standard?.g ?? lv.horizontal?.g ?? lv.vertical?.g ?? lv.inclined?.g ?? 9.81);

          // Euler step — same as homepage
          stateRef.current = {
            x: s.x + s.vx * spd.dt,
            y: s.y + s.vy * spd.dt - 0.5 * g * spd.dt * spd.dt,
            vx: s.vx,
            vy: s.vy - g * spd.dt,
            t: s.t + spd.dt,
          };

          // Trail
          const ns = stateRef.current;
          const [tbx, tby] = toC(ns.x, Math.max(0, ns.y), scaleRef.current, lv.width, lv.height);
          trailRef.current.push([tbx, tby]);
          if (trailRef.current.length > 140) trailRef.current.shift();

          lv.onTick?.(ns.t, ns.x, Math.max(0, ns.y));

          // Check completion
          if (ns.y < 0 || ns.t > 120) {
            doneRef.current = true;
            lv.onComplete?.();
            break;
          }
        }
      }

      // Draw
      const canvas = canvasRef.current;
      if (canvas) {
        const s = stateRef.current;
        drawScene(
          canvas, pathRef.current, s.x, Math.max(0, s.y), s.t, s.vx, s.vy,
          trailRef.current, scaleRef.current,
          maxRangeRef.current, maxHeightRef.current,
          lv.mode,
          { mode: lv.mode, standard: lv.standard, horizontal: lv.horizontal,
            vertical: lv.vertical, inclined: lv.inclined,
            isRunning: lv.isRunning, isPaused: lv.isPaused },
          tog.showGrid, tog.showTrail, tog.showVec,
          lv.isRunning || s.t > 0,
          h0Ref.current,
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
        {/* Overlays */}
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
              <button key={label} onClick={() => setter(!on)}
                className={`rounded-full px-3 py-1 text-xs font-medium border transition ${
                  on ? 'bg-indigo-600 text-white border-indigo-600'
                     : 'bg-white text-gray-400 border-gray-200 hover:border-gray-300'
                }`}>{label}</button>
            ))}
          </>
        )}

        {/* Speed */}
        <div className="flex items-center gap-1 rounded-lg border border-gray-200 bg-white px-2 py-1 ml-auto">
          <span className="text-[10px] text-gray-400 mr-1 select-none">Speed</span>
          {SPEEDS.map((s, i) => (
            <button key={s.label} onClick={() => setSpeedIdx(i)}
              className={`rounded px-2 py-0.5 text-[11px] font-medium transition ${
                speedIdx === i ? 'bg-indigo-600 text-white' : 'text-gray-500 hover:bg-gray-100'
              }`}>{s.label}</button>
          ))}
        </div>
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

echo "✅ Done! Same physics engine as homepage."
echo "Run: npm run dev -- --webpack"
echo "Visit: http://localhost:3000/simulations/projectile-motion"
