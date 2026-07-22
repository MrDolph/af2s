'use client';
import { useRef, useEffect, useCallback } from 'react';
import { springOmega, shmDisplacement, shmVelocity, springStaticExtension } from '@/lib/physics/shm';

interface Props {
  k: number; mass: number; amplitude: number;
  isRunning: boolean; isPaused: boolean;
  onTick?: (t: number, x: number, v: number) => void;
  width?: number; height?: number;
}

function drawSpring(ctx: CanvasRenderingContext2D, x: number, y1: number, y2: number, coils = 10) {
  const coilW = 18;
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

export function SpringCanvas({ k, mass, amplitude, isRunning, isPaused, onTick, width = 280, height = 340 }: Props) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const rafRef = useRef<number>(0);
  const tRef = useRef(0);
  const lastFrameRef = useRef<number | null>(null);
  const trailRef = useRef<number[]>([]);
  const sim = useRef({ k, mass, amplitude, isRunning, isPaused, onTick });
  sim.current = { k, mass, amplitude, isRunning, isPaused, onTick };

  useEffect(() => { tRef.current = 0; lastFrameRef.current = null; trailRef.current = []; }, [k, mass, amplitude]);

  const draw = useCallback((timestamp?: number) => {
    const canvas = canvasRef.current; if (!canvas) return;
    const ctx = canvas.getContext('2d'); if (!ctx) return;
    const { k: K, mass: m, amplitude: A, isRunning: r, isPaused: p, onTick: ot } = sim.current;
    const W = canvas.width, H = canvas.height;
    const omega = springOmega(K, m);
    const staticExt = springStaticExtension(m, K);

    // Real wall-clock dt (see PendulumCanvas) — keeps canvas time equal to
    // the true seconds shown on the graph's time axis at any refresh rate.
    if (r && !p && timestamp !== undefined) {
      if (lastFrameRef.current !== null) {
        tRef.current += Math.min((timestamp - lastFrameRef.current) / 1000, 0.1);
      }
      lastFrameRef.current = timestamp;
    } else {
      lastFrameRef.current = timestamp ?? null;
    }

    const x = shmDisplacement(A, omega, tRef.current); // displacement from equilibrium
    const v = shmVelocity(A, omega, tRef.current);
    ot?.(tRef.current, x, v);

    trailRef.current.push(x);
    if (trailRef.current.length > 60) trailRef.current.shift();

    ctx.clearRect(0, 0, W, H);
    ctx.fillStyle = '#f8fafc'; ctx.fillRect(0, 0, W, H);

    const cx = W / 2;
    const ceilingY = 20;
    const equilY = H / 2 + 20;
    const scale = 100; // px per metre

    // Ceiling
    ctx.fillStyle = '#64748b'; ctx.fillRect(cx - 35, 0, 70, 12);

    // Spring
    const springBottom = equilY + x * scale;
    drawSpring(ctx, cx, ceilingY + 12, springBottom - 30);

    // Equilibrium line
    ctx.setLineDash([4, 4]);
    ctx.beginPath(); ctx.moveTo(cx - 50, equilY); ctx.lineTo(cx + 50, equilY);
    ctx.strokeStyle = 'rgba(99,102,241,0.35)'; ctx.lineWidth = 1; ctx.stroke();
    ctx.setLineDash([]);
    ctx.fillStyle = '#6366f1'; ctx.font = '9px system-ui'; ctx.textAlign = 'left';
    ctx.fillText('equilibrium', cx + 36, equilY + 4);

    // Mass block
    const blockW = 60, blockH = 44;
    const bx = cx - blockW / 2;
    const by = springBottom - 20;
    const bg = ctx.createLinearGradient(bx, by, bx, by + blockH);
    bg.addColorStop(0, '#818cf8'); bg.addColorStop(1, '#4f46e5');
    ctx.fillStyle = bg;
    ctx.beginPath(); ctx.roundRect(bx, by, blockW, blockH, 6); ctx.fill();
    ctx.strokeStyle = '#3730a3'; ctx.lineWidth = 1.5;
    ctx.beginPath(); ctx.roundRect(bx, by, blockW, blockH, 6); ctx.stroke();
    ctx.fillStyle = 'white'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
    ctx.fillText(`${m}kg`, cx, by + blockH / 2 + 4);

    // Displacement arrow
    if (Math.abs(x) > 0.005) {
      const arrowX = cx + blockW / 2 + 16;
      const startY = equilY;
      const endY = by + blockH / 2;
      ctx.save();
      ctx.strokeStyle = '#ef4444'; ctx.lineWidth = 1.5;
      ctx.beginPath(); ctx.moveTo(arrowX, startY); ctx.lineTo(arrowX, endY); ctx.stroke();
      const dir = Math.sign(x);
      ctx.fillStyle = '#ef4444';
      ctx.beginPath(); ctx.moveTo(arrowX, endY);
      ctx.lineTo(arrowX - 4, endY - dir * 8); ctx.lineTo(arrowX + 4, endY - dir * 8);
      ctx.closePath(); ctx.fill();
      ctx.font = '9px system-ui'; ctx.textAlign = 'left';
      ctx.fillText(`x=${x.toFixed(3)}m`, arrowX + 6, (startY + endY) / 2);
      ctx.restore();
    }

    // Velocity arrow
    if (Math.abs(v) > 0.01) {
      const vLen = Math.min(Math.abs(v) * 40, 50);
      const dir = Math.sign(v);
      const vy1 = by + blockH / 2;
      ctx.save();
      ctx.strokeStyle = '#f59e0b'; ctx.lineWidth = 2;
      ctx.beginPath(); ctx.moveTo(cx - blockW / 2 - 14, vy1);
      ctx.lineTo(cx - blockW / 2 - 14, vy1 + dir * vLen); ctx.stroke();
      ctx.fillStyle = '#f59e0b';
      ctx.beginPath(); ctx.moveTo(cx - blockW / 2 - 14, vy1 + dir * vLen);
      ctx.lineTo(cx - blockW / 2 - 20, vy1 + dir * (vLen - 8));
      ctx.lineTo(cx - blockW / 2 - 8, vy1 + dir * (vLen - 8));
      ctx.closePath(); ctx.fill();
      ctx.restore();
    }

    // Info
    ctx.fillStyle = '#64748b'; ctx.font = '10px system-ui'; ctx.textAlign = 'center';
    ctx.fillText(`k=${K} N/m  T=${(2*Math.PI/omega).toFixed(2)}s`, cx, H - 8);

    // Mini trail (right side waveform)
    if (trailRef.current.length > 2) {
      ctx.save();
      const trailX = W - 35;
      const trailScale = 25;
      ctx.strokeStyle = 'rgba(99,102,241,0.6)'; ctx.lineWidth = 1.5;
      ctx.beginPath();
      trailRef.current.forEach((tx, i) => {
        const ty = equilY + tx * trailScale;
        const px = trailX - (trailRef.current.length - 1 - i) * 0.5;
        if (i === 0) ctx.moveTo(px, ty); else ctx.lineTo(px, ty);
      });
      ctx.stroke();
      ctx.restore();
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
