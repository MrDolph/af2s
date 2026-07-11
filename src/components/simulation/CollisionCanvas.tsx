'use client';
import { useRef, useEffect, useCallback } from 'react';
import { CollisionParams, solveCollision } from '@/lib/physics/consequences';

interface Props {
  params: CollisionParams;
  isRunning: boolean; isPaused: boolean;
  onComplete?: (result: ReturnType<typeof solveCollision>) => void;
  width?: number; height?: number;
}

export function CollisionCanvas({ params, isRunning, isPaused, onComplete, width = 680, height = 220 }: Props) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const rafRef = useRef<number>(0);
  const phase = useRef<'before' | 'impact' | 'after'>('before');
  const x1Ref = useRef(80);
  const x2Ref = useRef(500);
  const collidedRef = useRef(false);
  const result = useRef(solveCollision(params));
  const simRef = useRef({ params, isRunning, isPaused, onComplete });
  simRef.current = { params, isRunning, isPaused, onComplete };

  const BW = 64;

  useEffect(() => {
    phase.current = 'before';
    x1Ref.current = 80;
    x2Ref.current = 500;
    collidedRef.current = false;
    result.current = solveCollision(params);
  }, [params]);

  const draw = useCallback(() => {
    const canvas = canvasRef.current; if (!canvas) return;
    const ctx = canvas.getContext('2d'); if (!ctx) return;
    const { params: p, isRunning: r, isPaused: pa, onComplete: oc } = simRef.current;
    const W = canvas.width, H = canvas.height;
    const groundY = H - 50;

    if (r && !pa) {
      if (phase.current === 'before') {
        x1Ref.current += p.u1 * 0.8;
        x2Ref.current += p.u2 * 0.8;
        // Check collision
        if (x1Ref.current + BW >= x2Ref.current && !collidedRef.current) {
          collidedRef.current = true;
          phase.current = 'impact';
          result.current = solveCollision(p);
          setTimeout(() => { phase.current = 'after'; oc?.(result.current); }, 300);
        }
      } else if (phase.current === 'after') {
        x1Ref.current += result.current.v1 * 0.8;
        x2Ref.current += result.current.v2 * 0.8;
      }
    }

    ctx.clearRect(0, 0, W, H);
    ctx.fillStyle = '#f8fafc'; ctx.fillRect(0, 0, W, groundY);
    ctx.fillStyle = '#e2e8f0'; ctx.fillRect(0, groundY, W, H - groundY);
    ctx.beginPath(); ctx.moveTo(0, groundY); ctx.lineTo(W, groundY);
    ctx.strokeStyle = '#94a3b8'; ctx.lineWidth = 2; ctx.stroke();

    const by = groundY - 56;
    const midY = by + 28;

    // Impact flash
    if (phase.current === 'impact') {
      ctx.fillStyle = 'rgba(251,191,36,0.35)';
      ctx.beginPath(); ctx.arc(x1Ref.current + BW / 2, midY, 50, 0, Math.PI * 2); ctx.fill();
      ctx.fillStyle = '#f59e0b'; ctx.font = 'bold 14px system-ui'; ctx.textAlign = 'center';
      ctx.fillText('IMPACT!', x1Ref.current + BW / 2, midY - 55);
    }

    // Block 1
    const bg1 = ctx.createLinearGradient(x1Ref.current, by, x1Ref.current, by + 56);
    bg1.addColorStop(0, '#818cf8'); bg1.addColorStop(1, '#4f46e5');
    ctx.fillStyle = bg1;
    ctx.beginPath(); ctx.roundRect(x1Ref.current, by, BW, 56, 6); ctx.fill();
    ctx.strokeStyle = '#3730a3'; ctx.lineWidth = 1.5;
    ctx.beginPath(); ctx.roundRect(x1Ref.current, by, BW, 56, 6); ctx.stroke();
    ctx.fillStyle = 'white'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
    ctx.fillText(`${p.m1}kg`, x1Ref.current + BW / 2, midY - 6);
    ctx.font = '9px system-ui';
    ctx.fillText(phase.current === 'before' ? `u=${p.u1} m/s` : `v=${result.current.v1.toFixed(1)} m/s`, x1Ref.current + BW / 2, midY + 10);

    // Block 2
    const bg2 = ctx.createLinearGradient(x2Ref.current, by, x2Ref.current, by + 56);
    bg2.addColorStop(0, '#34d399'); bg2.addColorStop(1, '#059669');
    ctx.fillStyle = bg2;
    ctx.beginPath(); ctx.roundRect(x2Ref.current, by, BW, 56, 6); ctx.fill();
    ctx.strokeStyle = '#047857'; ctx.lineWidth = 1.5;
    ctx.beginPath(); ctx.roundRect(x2Ref.current, by, BW, 56, 6); ctx.stroke();
    ctx.fillStyle = 'white'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
    ctx.fillText(`${p.m2}kg`, x2Ref.current + BW / 2, midY - 6);
    ctx.font = '9px system-ui';
    ctx.fillText(phase.current === 'before' ? `u=${p.u2} m/s` : `v=${result.current.v2.toFixed(1)} m/s`, x2Ref.current + BW / 2, midY + 10);

    // Velocity arrows before impact
    if (phase.current === 'before') {
      [{ x: x1Ref.current, v: p.u1, w: BW }, { x: x2Ref.current, v: p.u2, w: BW }].forEach(b => {
        if (Math.abs(b.v) < 0.01) return;
        const dir = Math.sign(b.v);
        const ax = dir > 0 ? b.x + b.w : b.x;
        const arrowLen = Math.min(Math.abs(b.v) * 10, 60);
        ctx.save();
        ctx.strokeStyle = '#f59e0b'; ctx.lineWidth = 2;
        ctx.beginPath(); ctx.moveTo(ax, midY - 30); ctx.lineTo(ax + dir * arrowLen, midY - 30); ctx.stroke();
        ctx.fillStyle = '#f59e0b';
        ctx.beginPath(); ctx.moveTo(ax + dir * arrowLen, midY - 30);
        ctx.lineTo(ax + dir * arrowLen - dir * 8, midY - 35);
        ctx.lineTo(ax + dir * arrowLen - dir * 8, midY - 25);
        ctx.closePath(); ctx.fill();
        ctx.restore();
      });
    }

    // Type label
    ctx.fillStyle = '#6366f1'; ctx.font = '10px system-ui'; ctx.textAlign = 'left';
    ctx.fillText(`${p.type} collision`, 10, 18);
    if (phase.current === 'after') {
      ctx.fillStyle = '#10b981';
      ctx.fillText(`p: ${result.current.momentumBefore.toFixed(1)} → ${result.current.momentumAfter.toFixed(1)} kg·m/s  |  KE lost: ${result.current.keLost.toFixed(1)} J`, 10, H - 12);
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
