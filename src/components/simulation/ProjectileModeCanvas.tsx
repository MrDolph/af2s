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
