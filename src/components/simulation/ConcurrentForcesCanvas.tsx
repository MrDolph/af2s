'use client';
import { useRef, useEffect, useCallback } from 'react';
import { forceComponents, resultant, equilibrant, vecMagnitude, vecAngleDeg, Vec2 } from '@/lib/physics/equilibrium';

interface Props {
  magA: number; angleA: number;
  magB: number; angleB: number;
  isRunning: boolean; isPaused: boolean;
  width?: number; height?: number;
}

const BUILD_DURATION = 1.6; // s — time to animate drawing the force triangle

function drawArrow(ctx: CanvasRenderingContext2D, x1: number, y1: number, x2: number, y2: number, color: string, lw = 2.5, dashed = false) {
  const len = Math.hypot(x2 - x1, y2 - y1);
  if (len < 2) return;
  ctx.save();
  if (dashed) ctx.setLineDash([5, 4]);
  ctx.strokeStyle = color; ctx.lineWidth = lw;
  ctx.beginPath(); ctx.moveTo(x1, y1); ctx.lineTo(x2, y2); ctx.stroke();
  ctx.setLineDash([]);
  const ang = Math.atan2(y2 - y1, x2 - x1);
  ctx.fillStyle = color;
  ctx.beginPath(); ctx.moveTo(x2, y2);
  ctx.lineTo(x2 - 9 * Math.cos(ang - 0.4), y2 - 9 * Math.sin(ang - 0.4));
  ctx.lineTo(x2 - 9 * Math.cos(ang + 0.4), y2 - 9 * Math.sin(ang + 0.4));
  ctx.closePath(); ctx.fill();
  ctx.restore();
}

export function ConcurrentForcesCanvas({ magA, angleA, magB, angleB, isRunning, isPaused, width = 660, height = 300 }: Props) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const rafRef = useRef<number>(0);
  const lastFrameRef = useRef<number | null>(null);
  const t = useRef(0);
  const simRef = useRef({ magA, angleA, magB, angleB, isRunning, isPaused });
  simRef.current = { magA, angleA, magB, angleB, isRunning, isPaused };

  useEffect(() => { t.current = 0; lastFrameRef.current = null; }, [magA, angleA, magB, angleB]);

  const draw = useCallback((timestamp?: number) => {
    const canvas = canvasRef.current; if (!canvas) return;
    const ctx = canvas.getContext('2d'); if (!ctx) return;
    const s = simRef.current;
    const W = canvas.width, H = canvas.height;

    if (s.isRunning && !s.isPaused && timestamp !== undefined) {
      if (lastFrameRef.current !== null) {
        t.current = Math.min(t.current + (timestamp - lastFrameRef.current) / 1000, BUILD_DURATION);
      }
      lastFrameRef.current = timestamp;
    } else {
      lastFrameRef.current = timestamp ?? null;
    }
    const progress = s.isRunning ? t.current / BUILD_DURATION : 1; // fully built when idle, so it's never blank

    ctx.clearRect(0, 0, W, H);
    ctx.fillStyle = '#f8fafc'; ctx.fillRect(0, 0, W, H);

    // Screen y is flipped (down = positive) vs standard maths convention,
    // so negate y components consistently when converting to pixels.
    const PX_PER_N = 6;
    const A: Vec2 = forceComponents(s.magA, s.angleA);
    const B: Vec2 = forceComponents(s.magB, s.angleB);
    const R = resultant([A, B]);
    const Eq = equilibrant([A, B]);

    // ── Left panel: forces drawn from a common point of application ────────
    const originL = { x: W * 0.27, y: H * 0.6 };
    ctx.fillStyle = '#0f172a';
    ctx.beginPath(); ctx.arc(originL.x, originL.y, 4, 0, Math.PI * 2); ctx.fill();
    ctx.fillStyle = '#475569'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
    ctx.fillText('Body', originL.x, originL.y + 22);

    const seg1 = Math.min(progress / 0.4, 1);
    drawArrow(ctx, originL.x, originL.y, originL.x + A.x * PX_PER_N * seg1, originL.y - A.y * PX_PER_N * seg1, '#6366f1');
    if (seg1 > 0.3) {
      ctx.fillStyle = '#4338ca'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
      ctx.fillText(`A=${s.magA}N`, originL.x + A.x * PX_PER_N * 0.55, originL.y - A.y * PX_PER_N * 0.55 - 10);
    }
    const seg2 = Math.min(Math.max((progress - 0.4) / 0.4, 0), 1);
    drawArrow(ctx, originL.x, originL.y, originL.x + B.x * PX_PER_N * seg2, originL.y - B.y * PX_PER_N * seg2, '#10b981');
    if (seg2 > 0.3) {
      ctx.fillStyle = '#059669'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
      ctx.fillText(`B=${s.magB}N`, originL.x + B.x * PX_PER_N * 0.55, originL.y - B.y * PX_PER_N * 0.55 - 10);
    }
    const seg3 = Math.min(Math.max((progress - 0.8) / 0.2, 0), 1);
    if (seg3 > 0) {
      drawArrow(ctx, originL.x, originL.y, originL.x + Eq.x * PX_PER_N * seg3, originL.y - Eq.y * PX_PER_N * seg3, '#ef4444');
    }
    if (progress >= 1) {
      ctx.fillStyle = '#dc2626'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
      ctx.fillText(`Equilibrant=${vecMagnitude(Eq).toFixed(1)}N`, originL.x + Eq.x * PX_PER_N * 0.55, originL.y - Eq.y * PX_PER_N * 0.55 + 16);
    }

    // ── Right panel: the force TRIANGLE (tip-to-tail construction) ─────────
    const originR = { x: W * 0.68, y: H * 0.32 };
    ctx.fillStyle = '#94a3b8'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'left';
    ctx.fillText('Force triangle (tip-to-tail):', originR.x - 90, 22);

    const aTip = { x: originR.x + A.x * PX_PER_N, y: originR.y - A.y * PX_PER_N };
    const abTip = { x: aTip.x + B.x * PX_PER_N, y: aTip.y - B.y * PX_PER_N };

    const tSeg1 = Math.min(progress / 0.4, 1);
    drawArrow(ctx, originR.x, originR.y, originR.x + A.x * PX_PER_N * tSeg1, originR.y - A.y * PX_PER_N * tSeg1, '#6366f1');
    const tSeg2 = Math.min(Math.max((progress - 0.4) / 0.4, 0), 1);
    drawArrow(ctx, aTip.x, aTip.y, aTip.x + B.x * PX_PER_N * tSeg2, aTip.y - B.y * PX_PER_N * tSeg2, '#10b981');
    const tSeg3 = Math.min(Math.max((progress - 0.8) / 0.2, 0), 1);
    if (tSeg3 > 0) {
      drawArrow(ctx, abTip.x, abTip.y, abTip.x + (originR.x - abTip.x) * tSeg3, abTip.y + (originR.y - abTip.y) * tSeg3, '#ef4444');
    }
    if (progress >= 1) {
      ctx.fillStyle = '#475569'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
      ctx.fillText('Closes exactly back to the start —', originR.x, H - 34);
      ctx.fillText('this is what "in equilibrium" looks like', originR.x, H - 20);
    }

    // Caption
    ctx.fillStyle = '#334155'; ctx.font = 'bold 11px system-ui'; ctx.textAlign = 'center';
    ctx.fillText(
      `Resultant of A+B = ${vecMagnitude(R).toFixed(1)}N at ${vecAngleDeg(R).toFixed(0)}°  →  Equilibrant = ${vecMagnitude(Eq).toFixed(1)}N at ${vecAngleDeg(Eq).toFixed(0)}°`,
      W / 2, H - 8,
    );

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
