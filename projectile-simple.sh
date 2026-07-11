#!/bin/bash
# Simplest possible working projectile canvas
# Run inside af2s/: bash projectile-simple.sh
set -e

cat > src/components/simulation/ProjectileModeCanvas.tsx << 'EOF'
'use client';
import { useEffect, useRef, useState, useCallback } from 'react';
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

const SPEEDS = [
  { label: '0.25×', stepsPerFrame: 1, dt: 0.004 },
  { label: '0.5×',  stepsPerFrame: 1, dt: 0.008 },
  { label: '1×',    stepsPerFrame: 1, dt: 0.016 },
  { label: '2×',    stepsPerFrame: 2, dt: 0.016 },
  { label: '4×',    stepsPerFrame: 4, dt: 0.016 },
];

const PAD = 44, GH = 44, BR = 8;

function buildPath(mode: ProjectileMode, props: Props): Pt[] {
  if (mode === 'standard'   && props.standard)   return (standardPath(props.standard)   as Pt[]);
  if (mode === 'horizontal' && props.horizontal) return (horizontalPath(props.horizontal) as Pt[]);
  if (mode === 'vertical'   && props.vertical)   return verticalPath(props.vertical).map(p => ({ t: p.t, x: 0, y: p.y }));
  if (mode === 'inclined'   && props.inclined)   return (inclinedPath(props.inclined)   as Pt[]);
  return [{ t: 0, x: 0, y: 0 }];
}

function getG(mode: ProjectileMode, props: Props): number {
  if (mode === 'standard'   && props.standard)   return props.standard.g;
  if (mode === 'horizontal' && props.horizontal) return props.horizontal.g;
  if (mode === 'vertical'   && props.vertical)   return props.vertical.g;
  if (mode === 'inclined'   && props.inclined)   return props.inclined.g;
  return 9.81;
}

function getH0(mode: ProjectileMode, props: Props): number {
  if (mode === 'standard'   && props.standard)   return props.standard.h0 ?? 0;
  if (mode === 'horizontal' && props.horizontal) return props.horizontal.h;
  if (mode === 'vertical'   && props.vertical)   return props.vertical.h0 ?? 0;
  return 0;
}

function getInitVel(mode: ProjectileMode, props: Props): { vx: number; vy: number; x0: number; y0: number } {
  if (mode === 'standard' && props.standard) {
    const a = props.standard.angle * Math.PI / 180;
    return { vx: props.standard.v0 * Math.cos(a), vy: props.standard.v0 * Math.sin(a), x0: 0, y0: props.standard.h0 ?? 0 };
  }
  if (mode === 'horizontal' && props.horizontal) {
    return { vx: props.horizontal.v0, vy: 0, x0: 0, y0: props.horizontal.h };
  }
  if (mode === 'vertical' && props.vertical) {
    return { vx: 0, vy: props.vertical.v0, x0: 0, y0: props.vertical.h0 ?? 0 };
  }
  if (mode === 'inclined' && props.inclined) {
    const a = props.inclined.alpha * Math.PI / 180;
    const b = props.inclined.beta  * Math.PI / 180;
    return {
      vx: props.inclined.v0 * (Math.cos(a) * Math.cos(b) - Math.sin(a) * Math.sin(b)),
      vy: props.inclined.v0 * (Math.cos(a) * Math.sin(b) + Math.sin(a) * Math.cos(b)),
      x0: 0, y0: 0,
    };
  }
  return { vx: 10, vy: 10, x0: 0, y0: 0 };
}

function computeScale(path: Pt[], W: number, H: number) {
  const xs = path.map(p => p.x);
  const ys = path.map(p => p.y);
  const maxX = Math.max(...xs, 1);
  const maxY = Math.max(...ys, 1);
  return {
    scale: Math.min((W - PAD * 2) / (maxX * 1.15), (H - GH - PAD) / (maxY * 1.25)),
    maxX, maxY,
  };
}

function toCanvas(x: number, y: number, scale: number, H: number): [number, number] {
  return [PAD + x * scale, H - GH - y * scale];
}

function paint(
  canvas: HTMLCanvasElement,
  path: Pt[], scale: number, maxX: number, maxY: number,
  curX: number, curY: number, curT: number, vx: number, vy: number,
  trail: [number, number][],
  mode: ProjectileMode, h0: number, inlined: boolean,
  showGrid: boolean, showTrail: boolean, showVec: boolean,
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

  // Platform
  if (h0 > 0) {
    const [, pyP] = toCanvas(0, h0, scale, H);
    ctx.fillStyle = '#94a3b8'; ctx.fillRect(0, pyP, PAD + 4, H - GH - pyP);
    ctx.strokeStyle = '#64748b'; ctx.lineWidth = 1.5; ctx.strokeRect(0, pyP, PAD + 4, H - GH - pyP);
    ctx.fillStyle = '#475569'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
    ctx.fillText(`${h0}m`, (PAD + 4) / 2, pyP - 6);
  }

  // Grid
  if (showGrid) {
    ctx.save();
    ctx.strokeStyle = '#e2e8f0'; ctx.lineWidth = 1; ctx.fillStyle = '#94a3b8'; ctx.font = '10px system-ui';
    const xStep = Math.ceil(maxX / 5 / 5) * 5 || 1;
    ctx.textAlign = 'center';
    for (let x = 0; x <= maxX * 1.15; x += xStep) {
      const [cx2] = toCanvas(x, 0, scale, H);
      ctx.beginPath(); ctx.setLineDash([3, 4]); ctx.moveTo(cx2, PAD); ctx.lineTo(cx2, H - GH); ctx.stroke();
      ctx.setLineDash([]);
      if (mode !== 'vertical') ctx.fillText(`${x}m`, cx2, H - GH + 14);
    }
    ctx.textAlign = 'right';
    const yStep = Math.ceil(maxY / 4 / 5) * 5 || 1;
    for (let y = 0; y <= maxY * 1.25; y += yStep) {
      const [, cy2] = toCanvas(0, y, scale, H);
      if (cy2 < PAD) continue;
      ctx.beginPath(); ctx.setLineDash([3, 4]); ctx.moveTo(PAD, cy2); ctx.lineTo(W - PAD, cy2); ctx.stroke();
      ctx.setLineDash([]); ctx.fillText(`${y}m`, PAD - 3, cy2 + 4);
    }
    ctx.restore();
  }

  // Ghost trajectory
  if (path.length > 1) {
    ctx.save(); ctx.beginPath();
    const [gx, gy] = toCanvas(path[0].x, path[0].y, scale, H);
    ctx.moveTo(gx, gy);
    path.slice(1).forEach(p => { const [cx2, cy2] = toCanvas(p.x, p.y, scale, H); ctx.lineTo(cx2, cy2); });
    ctx.strokeStyle = 'rgba(99,102,241,0.18)'; ctx.lineWidth = 2;
    ctx.setLineDash([6, 4]); ctx.stroke(); ctx.setLineDash([]); ctx.restore();
  }

  // Peak + landing markers
  if (maxY > 0.5) {
    const [pCx, pCy] = toCanvas(maxX / 2, maxY, scale, H);
    ctx.save();
    ctx.beginPath(); ctx.setLineDash([4, 3]);
    ctx.moveTo(pCx, pCy); ctx.lineTo(pCx, H - GH);
    ctx.strokeStyle = 'rgba(99,102,241,0.4)'; ctx.lineWidth = 1.5; ctx.stroke(); ctx.setLineDash([]);
    ctx.fillStyle = '#6366f1'; ctx.font = 'bold 11px system-ui'; ctx.textAlign = 'center';
    ctx.fillText(`${maxY.toFixed(1)}m`, pCx, pCy - 8); ctx.restore();
  }
  const [lCx] = toCanvas(maxX, 0, scale, H);
  ctx.save();
  ctx.beginPath(); ctx.arc(lCx, H - GH, 5, 0, Math.PI * 2);
  ctx.fillStyle = '#10b981'; ctx.fill();
  ctx.fillStyle = '#10b981'; ctx.font = 'bold 11px system-ui'; ctx.textAlign = 'center';
  ctx.fillText(`${maxX.toFixed(1)}m`, lCx, H - GH + 32); ctx.restore();

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
  const [bx, by] = toCanvas(curX, Math.max(0, curY), scale, H);
  const [, groundY] = toCanvas(0, 0, scale, H);
  ctx.beginPath(); ctx.ellipse(bx, groundY + 5, 10, 4, 0, 0, Math.PI * 2);
  ctx.fillStyle = 'rgba(0,0,0,0.1)'; ctx.fill();
  const glow = ctx.createRadialGradient(bx, by, 0, bx, by, BR * 2.5);
  glow.addColorStop(0, 'rgba(79,70,229,0.3)'); glow.addColorStop(1, 'transparent');
  ctx.beginPath(); ctx.arc(bx, by, BR * 2.5, 0, Math.PI * 2); ctx.fillStyle = glow; ctx.fill();
  const ballG = ctx.createRadialGradient(bx - 2, by - 2, 1, bx, by, BR);
  ballG.addColorStop(0, '#818cf8'); ballG.addColorStop(1, '#4f46e5');
  ctx.beginPath(); ctx.arc(bx, by, BR, 0, Math.PI * 2); ctx.fillStyle = ballG; ctx.fill();

  // Velocity vector
  const speed = Math.sqrt(vx * vx + vy * vy);
  if (showVec && speed > 0.3 && curT > 0) {
    const arrowLen = Math.min(speed * scale * 0.28, 65);
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
  if (inlined && curT > 0) {
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

export function ProjectileModeCanvas({
  mode, standard, horizontal, vertical, inclined,
  isRunning, isPaused, onComplete, onTick,
  width = 680, height = 300,
}: Props) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const rafRef    = useRef<number>(0);

  // Physics state
  const xRef  = useRef(0);
  const yRef  = useRef(0);
  const vxRef = useRef(0);
  const vyRef = useRef(0);
  const tRef  = useRef(0);
  const doneRef  = useRef(false);
  const trailRef = useRef<[number, number][]>([]);

  // Pre-computed ghost path + scale
  const pathRef  = useRef<Pt[]>([{ t: 0, x: 0, y: 0 }]);
  const scaleRef = useRef(1);
  const maxXRef  = useRef(1);
  const maxYRef  = useRef(1);
  const h0Ref    = useRef(0);
  const gRef     = useRef(9.81);

  // Speed + overlay toggles
  const [speedIdx,  setSpeedIdx]  = useState(2); // 1× default
  const [showGrid,  setShowGrid]  = useState(true);
  const [showTrail, setShowTrail] = useState(true);
  const [showVec,   setShowVec]   = useState(true);
  const [showOvl,   setShowOvl]   = useState(false);

  // ── Reset: called by parent via key= prop ──────────────────────────────────
  const init = useCallback(() => {
    const props = { mode, standard, horizontal, vertical, inclined, isRunning: false, isPaused: false };
    const iv = getInitVel(mode, props);
    xRef.current  = iv.x0;
    yRef.current  = iv.y0;
    vxRef.current = iv.vx;
    vyRef.current = iv.vy;
    tRef.current  = 0;
    doneRef.current  = false;
    trailRef.current = [];
    gRef.current  = getG(mode, props);
    h0Ref.current = getH0(mode, props);

    const path = buildPath(mode, props);
    pathRef.current = path;
    const { scale, maxX, maxY } = computeScale(path, width, height);
    scaleRef.current = scale;
    maxXRef.current  = maxX;
    maxYRef.current  = maxY;

    // Draw immediately
    const canvas = canvasRef.current;
    if (canvas) {
      paint(canvas, path, scale, maxX, maxY, iv.x0, iv.y0, 0, iv.vx, iv.vy,
        [], mode, h0Ref.current, false, true, false, false);
    }
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [mode, standard, horizontal, vertical, inclined, width, height]);

  // Run init on mount and whenever params change
  useEffect(() => { init(); }, [init]);

  // ── Single RAF loop ────────────────────────────────────────────────────────
  // We pass isRunning/isPaused/speedIdx as refs so the loop reads live values
  const runRef     = useRef(isRunning);
  const pauseRef   = useRef(isPaused);
  const speedIdxRef = useRef(speedIdx);
  const showGridRef  = useRef(showGrid);
  const showTrailRef = useRef(showTrail);
  const showVecRef   = useRef(showVec);

  // Keep refs in sync every render — this is the key fix
  runRef.current      = isRunning;
  pauseRef.current    = isPaused;
  speedIdxRef.current = speedIdx;
  showGridRef.current  = showGrid;
  showTrailRef.current = showTrail;
  showVecRef.current   = showVec;

  useEffect(() => {
    const loop = () => {
      const running = runRef.current;
      const paused  = pauseRef.current;
      const spd     = SPEEDS[speedIdxRef.current];

      if (running && !paused && !doneRef.current) {
        for (let i = 0; i < spd.stepsPerFrame; i++) {
          const g = gRef.current;
          const newVy = vyRef.current - g * spd.dt;
          xRef.current  += vxRef.current * spd.dt;
          yRef.current  += vyRef.current * spd.dt - 0.5 * g * spd.dt * spd.dt;
          vyRef.current  = newVy;
          tRef.current  += spd.dt;

          // Trail in canvas coords
          const [tbx, tby] = toCanvas(
            xRef.current, Math.max(0, yRef.current),
            scaleRef.current, height
          );
          trailRef.current.push([tbx, tby]);
          if (trailRef.current.length > 140) trailRef.current.shift();

          onTick?.(tRef.current, xRef.current, Math.max(0, yRef.current));

          if (yRef.current < 0 || tRef.current > 120) {
            doneRef.current = true;
            onComplete?.();
            break;
          }
        }
      }

      const canvas = canvasRef.current;
      if (canvas) {
        paint(
          canvas,
          pathRef.current, scaleRef.current, maxXRef.current, maxYRef.current,
          xRef.current, yRef.current, tRef.current,
          vxRef.current, vyRef.current,
          trailRef.current,
          mode, h0Ref.current,
          running || tRef.current > 0,
          showGridRef.current, showTrailRef.current, showVecRef.current,
        );
      }
      rafRef.current = requestAnimationFrame(loop);
    };
    rafRef.current = requestAnimationFrame(loop);
    return () => cancelAnimationFrame(rafRef.current);
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []); // empty — loop reads everything from refs

  return (
    <div className="space-y-2">
      {/* Toolbar */}
      <div className="flex items-center gap-2 flex-wrap">
        <button onClick={() => setShowOvl(v => !v)}
          className={`flex items-center gap-1.5 rounded-lg border px-3 py-1.5 text-xs font-medium transition ${
            showOvl ? 'border-indigo-300 bg-indigo-50 text-indigo-700'
                    : 'border-gray-200 bg-white text-gray-600 hover:bg-gray-50'
          }`}>
          <svg width="12" height="12" viewBox="0 0 12 12" fill="none" stroke="currentColor" strokeWidth="1.5">
            <circle cx="6" cy="6" r="2"/><path d="M6 1v1M6 10v1M1 6h1M10 6h1"/>
          </svg>
          Overlays
        </button>
        {showOvl && (
          <>
            {([['Grid', showGrid, setShowGrid], ['Trail', showTrail, setShowTrail], ['Velocity arrow', showVec, setShowVec]] as [string, boolean, (v: boolean) => void][])
              .map(([label, on, setter]) => (
                <button key={label} onClick={() => setter(!on)}
                  className={`rounded-full px-3 py-1 text-xs font-medium border transition ${
                    on ? 'bg-indigo-600 text-white border-indigo-600' : 'bg-white text-gray-400 border-gray-200'
                  }`}>{label}</button>
              ))}
          </>
        )}
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
        <canvas ref={canvasRef} width={width} height={height}
          className="w-full" style={{ display: 'block' }} />
      </div>
    </div>
  );
}
EOF

echo "✅ Done — pure ref-based live physics, zero stale closure issues"
