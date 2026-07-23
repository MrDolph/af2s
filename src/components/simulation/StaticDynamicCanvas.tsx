'use client';
import { useRef, useEffect, useCallback } from 'react';
import { checkBalance } from '@/lib/physics/equilibrium';

interface Props {
  scenario: 'static' | 'dynamic';
  f1: number; f2: number; // opposing horizontal forces, N
  mass: number;
  isRunning: boolean; isPaused: boolean;
  onTick?: (v: number, x: number) => void;
  width?: number; height?: number;
}

function forceArrow(ctx: CanvasRenderingContext2D, x: number, y: number, len: number, dir: 1 | -1, color: string, label: string) {
  if (len < 2) return;
  const ex = x + dir * len;
  ctx.save();
  ctx.strokeStyle = color; ctx.lineWidth = 2.5;
  ctx.beginPath(); ctx.moveTo(x, y); ctx.lineTo(ex, y); ctx.stroke();
  ctx.fillStyle = color;
  ctx.beginPath(); ctx.moveTo(ex, y);
  ctx.lineTo(ex - dir * 9, y - 6); ctx.lineTo(ex - dir * 9, y + 6);
  ctx.closePath(); ctx.fill();
  ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
  ctx.fillText(label, x + dir * len / 2, y - 10);
  ctx.restore();
}

export function StaticDynamicCanvas({ scenario, f1, f2, mass, isRunning, isPaused, onTick, width = 660, height = 240 }: Props) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const rafRef = useRef<number>(0);
  const lastFrameRef = useRef<number | null>(null);
  const x = useRef(0);
  const v = useRef(0);
  const simRef = useRef({ scenario, f1, f2, mass, isRunning, isPaused, onTick });
  simRef.current = { scenario, f1, f2, mass, isRunning, isPaused, onTick };

  const INITIAL_V = 1.6; // m/s — the "already moving" starting speed for the dynamic scenario

  useEffect(() => {
    x.current = 0;
    v.current = scenario === 'dynamic' ? INITIAL_V : 0;
    lastFrameRef.current = null;
  }, [scenario, f1, f2, mass]);

  const draw = useCallback((timestamp?: number) => {
    const canvas = canvasRef.current; if (!canvas) return;
    const ctx = canvas.getContext('2d'); if (!ctx) return;
    const s = simRef.current;
    const W = canvas.width, H = canvas.height;
    const groundY = H - 50;

    const bal = checkBalance(s.f1, s.f2);
    const a = bal.netForce / s.mass; // + = rightward net force

    let dt = 0;
    if (s.isRunning && !s.isPaused && timestamp !== undefined) {
      if (lastFrameRef.current !== null) {
        dt = Math.min((timestamp - lastFrameRef.current) / 1000, 0.1);
      }
      lastFrameRef.current = timestamp;
    } else {
      lastFrameRef.current = timestamp ?? null;
    }
    if (dt > 0) {
      v.current += a * dt;
      x.current += v.current * dt;
      // Wrap so a genuinely unbalanced / constant-velocity block never
      // just runs off-screen forever.
      const wrapRange = 140;
      if (x.current > wrapRange) x.current = -wrapRange;
      if (x.current < -wrapRange) x.current = wrapRange;
    }
    s.onTick?.(v.current, x.current);

    ctx.clearRect(0, 0, W, H);
    ctx.fillStyle = '#f8fafc'; ctx.fillRect(0, 0, W, groundY);
    ctx.fillStyle = '#e2e8f0'; ctx.fillRect(0, groundY, W, H - groundY);
    ctx.strokeStyle = '#94a3b8'; ctx.lineWidth = 2;
    ctx.beginPath(); ctx.moveTo(0, groundY); ctx.lineTo(W, groundY); ctx.stroke();

    const cx = W / 2 + x.current;
    const bw = 64, bh = 48;
    const by = groundY - bh;
    const midY = by + bh / 2;

    ctx.fillStyle = bal.equilibrium ? '#6366f1' : '#f59e0b';
    ctx.beginPath(); ctx.roundRect(cx - bw / 2, by, bw, bh, 6); ctx.fill();
    ctx.fillStyle = 'white'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
    ctx.fillText(`${s.mass}kg`, cx, midY + 4);

    // Force arrows — right-pulling f1 (green), left-pulling f2 (red)
    forceArrow(ctx, cx + bw / 2, midY, Math.min(s.f1 * 3, 130), 1, '#10b981', `F₁=${s.f1}N`);
    forceArrow(ctx, cx - bw / 2, midY, Math.min(s.f2 * 3, 130), -1, '#ef4444', `F₂=${s.f2}N`);

    ctx.font = 'bold 11px system-ui'; ctx.textAlign = 'center';
    if (bal.equilibrium) {
      ctx.fillStyle = '#059669';
      ctx.fillText(
        s.scenario === 'static'
          ? 'ΣF = 0 — STATIC EQUILIBRIUM: at rest, and stays at rest'
          : `ΣF = 0 — DYNAMIC EQUILIBRIUM: moving at a constant ${INITIAL_V.toFixed(1)} m/s`,
        W / 2, 24,
      );
    } else {
      ctx.fillStyle = '#f59e0b';
      ctx.fillText(`NOT in equilibrium — ΣF = ${bal.netForce.toFixed(1)}N, a = ${a.toFixed(2)} m/s²`, W / 2, 24);
    }
    ctx.fillStyle = '#64748b'; ctx.font = '10px system-ui'; ctx.textAlign = 'left';
    ctx.fillText(`v = ${v.current.toFixed(2)} m/s`, 8, H - 10);

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
