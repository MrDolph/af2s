'use client';
import { useRef, useEffect, useCallback } from 'react';
import { dampedY, type DampedOscillatorParams } from '@/lib/physics/dampedOscillator';

interface Props extends DampedOscillatorParams {
  isRunning: boolean; isPaused: boolean;
  onTick?: (t: number) => void;
  width?: number; height?: number;
}

function drawSpring(ctx: CanvasRenderingContext2D, x: number, y1: number, y2: number, coils = 8) {
  const coilW = 16;
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

// Dashpot (damper) symbol: a piston inside a cylinder — visually communicates
// "this is what γ represents" alongside the spring, which only represents ω₀.
function drawDamper(ctx: CanvasRenderingContext2D, x: number, y1: number, y2: number, pistonY: number) {
  const w = 14;
  ctx.strokeStyle = '#94a3b8'; ctx.lineWidth = 1.5;
  ctx.strokeRect(x - w / 2, y1, w, (y2 - y1) * 0.55);
  ctx.beginPath();
  ctx.moveTo(x, y1); ctx.lineTo(x, pistonY);
  ctx.moveTo(x - w / 2 + 2, pistonY); ctx.lineTo(x + w / 2 - 2, pistonY);
  ctx.moveTo(x, pistonY); ctx.lineTo(x, y2);
  ctx.stroke();
}

export function DampedOscillatorCanvas({
  gamma, omega0, y0, yp0, isRunning, isPaused, onTick, width = 380, height = 300,
}: Props) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const rafRef = useRef<number>(0);
  const tRef = useRef(0);
  const lastFrameRef = useRef<number | null>(null);
  const trailRef = useRef<number[]>([]);
  // Ref-mirror pattern (see project conventions) — avoids stale closures
  // capturing prop values from the render that scheduled the rAF loop.
  const sim = useRef({ gamma, omega0, y0, yp0, isRunning, isPaused, onTick });
  sim.current = { gamma, omega0, y0, yp0, isRunning, isPaused, onTick };

  useEffect(() => { tRef.current = 0; lastFrameRef.current = null; trailRef.current = []; }, [gamma, omega0, y0, yp0]);

  const draw = useCallback((timestamp?: number) => {
    const canvas = canvasRef.current; if (!canvas) return;
    const ctx = canvas.getContext('2d'); if (!ctx) return;
    const { gamma: g, omega0: w0, y0: Y0, yp0: Yp0, isRunning: r, isPaused: p, onTick: ot } = sim.current;
    const W = canvas.width, H = canvas.height;

    if (r && !p && timestamp !== undefined) {
      if (lastFrameRef.current !== null) {
        tRef.current += Math.min((timestamp - lastFrameRef.current) / 1000, 0.1);
      }
      lastFrameRef.current = timestamp;
    } else {
      lastFrameRef.current = timestamp ?? null;
    }

    const y = dampedY(tRef.current, { gamma: g, omega0: w0, y0: Y0, yp0: Yp0 });
    ot?.(tRef.current);

    trailRef.current.push(y);
    if (trailRef.current.length > 50) trailRef.current.shift();

    ctx.clearRect(0, 0, W, H);
    ctx.fillStyle = '#f8fafc'; ctx.fillRect(0, 0, W, H);

    const cx = W / 2 - 25;
    const dx = W / 2 + 30;
    const ceilingY = 20;
    const equilY = H / 2 + 10;
    const scale = 80; // px per unit of y

    // Ceiling
    ctx.fillStyle = '#64748b'; ctx.fillRect(cx - 40, 0, 90, 12);

    const massY = equilY + y * scale;

    drawSpring(ctx, cx, ceilingY + 12, massY - 22);
    drawDamper(ctx, dx, ceilingY + 12, massY + 20, ceilingY + 12 + (massY - ceilingY - 12) * 0.5);

    // Equilibrium line
    ctx.setLineDash([4, 4]);
    ctx.strokeStyle = '#cbd5e1'; ctx.lineWidth = 1;
    ctx.beginPath(); ctx.moveTo(30, equilY); ctx.lineTo(W - 30, equilY); ctx.stroke();
    ctx.setLineDash([]);

    // Trail
    ctx.beginPath();
    trailRef.current.forEach((yy, i) => {
      const px = cx - 60 - (trailRef.current.length - i) * 1.5;
      const py = equilY + yy * scale;
      if (i === 0) ctx.moveTo(px, py); else ctx.lineTo(px, py);
    });
    ctx.strokeStyle = 'rgba(99,102,241,0.25)'; ctx.lineWidth = 2; ctx.stroke();

    // Mass block (spans both the spring and damper attachment points)
    ctx.fillStyle = '#6366f1';
    ctx.beginPath();
    ctx.roundRect(cx - 45, massY - 18, 140, 36, 8);
    ctx.fill();
    ctx.fillStyle = 'white'; ctx.font = '11px sans-serif'; ctx.textAlign = 'center';
    ctx.fillText('m', cx + 25, massY + 4);

    if (isRunning && !isPaused) {
      rafRef.current = requestAnimationFrame(draw);
    }
  }, [isRunning, isPaused]);

  useEffect(() => {
    if (isRunning && !isPaused) {
      rafRef.current = requestAnimationFrame(draw);
    } else {
      draw(lastFrameRef.current ?? undefined);
    }
    return () => cancelAnimationFrame(rafRef.current);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [isRunning, isPaused, draw, gamma, omega0, y0, yp0]);

  return <canvas ref={canvasRef} width={width} height={height} className="rounded-xl" />;
}
