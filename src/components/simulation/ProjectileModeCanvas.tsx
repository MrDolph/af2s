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
