'use client';
import { useRef, useEffect, useCallback } from 'react';
import { CollisionParams, solveCollision } from '@/lib/physics/consequences';

interface Props {
  params: CollisionParams;
  isRunning: boolean; isPaused: boolean;
  onComplete?: (result: ReturnType<typeof solveCollision>) => void;
  width?: number; height?: number;
}

const BW = 64;
const X1_START = 80;
const X2_START = 500;
const IMPACT_FLASH_DURATION = 0.3; // s — bodies stay visually in contact for this long
// px per (m/s) per second of wall-clock time — tuned to match the pacing of
// the original frame-based animation (which moved u*0.8px every frame,
// ~48px/s at 60fps) now that motion is driven by real elapsed time instead.
const PX_PER_MPS = 48;

type Phase = 'before' | 'impact' | 'after';

export function CollisionCanvas({ params, isRunning, isPaused, onComplete, width = 680, height = 220 }: Props) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const rafRef = useRef<number>(0);
  const lastFrameRef = useRef<number | null>(null);
  const t = useRef(0);           // wall-clock time since this run started/reset
  const tImpact = useRef(0);     // the value of t at the moment of impact
  const phase = useRef<Phase>('before');
  const completedRef = useRef(false);
  const result = useRef(solveCollision(params));
  const simRef = useRef({ params, isRunning, isPaused, onComplete });
  simRef.current = { params, isRunning, isPaused, onComplete };

  useEffect(() => {
    phase.current = 'before';
    t.current = 0;
    tImpact.current = 0;
    completedRef.current = false;
    lastFrameRef.current = null;
    result.current = solveCollision(params);
  }, [params]);

  const draw = useCallback((timestamp?: number) => {
    const canvas = canvasRef.current; if (!canvas) return;
    const ctx = canvas.getContext('2d'); if (!ctx) return;
    const { params: p, isRunning: r, isPaused: pa, onComplete: oc } = simRef.current;
    const W = canvas.width, H = canvas.height;
    const groundY = H - 50;

    // Real wall-clock dt, gated on running/paused exactly like every other
    // canvas in the app — this also means the impact flash duration and the
    // moment onComplete fires both correctly freeze while paused, instead of
    // the old setTimeout (which kept counting down regardless of pause and
    // was the root of the sequence "skipping ahead" unpredictably).
    let dt = 0;
    if (r && !pa && timestamp !== undefined) {
      if (lastFrameRef.current !== null) {
        dt = Math.min((timestamp - lastFrameRef.current) / 1000, 0.1);
        t.current += dt;
      }
      lastFrameRef.current = timestamp;
    } else {
      lastFrameRef.current = timestamp ?? null;
    }

    // Position is always a pure function of elapsed time (not an
    // accumulator), so there's no drift and pausing/resuming is exact.
    let x1: number, x2: number;
    if (phase.current === 'before') {
      x1 = X1_START + p.u1 * PX_PER_MPS * t.current;
      x2 = X2_START + p.u2 * PX_PER_MPS * t.current;
      if (dt > 0 && x1 + BW >= x2) {
        phase.current = 'impact';
        tImpact.current = t.current;
        result.current = solveCollision(p);
        // Clamp to the exact contact point so the flash starts flush against
        // both bodies rather than with a visible last-frame overlap.
        x2 = x1 + BW;
      }
    } else if (phase.current === 'impact') {
      x1 = X1_START + p.u1 * PX_PER_MPS * tImpact.current;
      x2 = x1 + BW; // frozen in contact during the flash
      if (t.current - tImpact.current >= IMPACT_FLASH_DURATION) {
        phase.current = 'after';
        if (!completedRef.current) { completedRef.current = true; oc?.(result.current); }
      }
    } else {
      const tAfter = t.current - tImpact.current - IMPACT_FLASH_DURATION;
      const xImpact = X1_START + p.u1 * PX_PER_MPS * tImpact.current + BW; // shared contact point
      x1 = xImpact - BW + result.current.v1 * PX_PER_MPS * tAfter;
      x2 = xImpact + result.current.v2 * PX_PER_MPS * tAfter;
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
      ctx.beginPath(); ctx.arc(x1 + BW / 2, midY, 50, 0, Math.PI * 2); ctx.fill();
      ctx.fillStyle = '#f59e0b'; ctx.font = 'bold 14px system-ui'; ctx.textAlign = 'center';
      ctx.fillText('IMPACT!', x1 + BW / 2, midY - 55);
    }

    // Block 1
    const bg1 = ctx.createLinearGradient(x1, by, x1, by + 56);
    bg1.addColorStop(0, '#818cf8'); bg1.addColorStop(1, '#4f46e5');
    ctx.fillStyle = bg1;
    ctx.beginPath(); ctx.roundRect(x1, by, BW, 56, 6); ctx.fill();
    ctx.strokeStyle = '#3730a3'; ctx.lineWidth = 1.5;
    ctx.beginPath(); ctx.roundRect(x1, by, BW, 56, 6); ctx.stroke();
    ctx.fillStyle = 'white'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
    ctx.fillText(`${p.m1}kg`, x1 + BW / 2, midY - 6);
    ctx.font = '9px system-ui';
    ctx.fillText(phase.current === 'before' ? `u=${p.u1} m/s` : `v=${result.current.v1.toFixed(1)} m/s`, x1 + BW / 2, midY + 10);

    // Block 2
    const bg2 = ctx.createLinearGradient(x2, by, x2, by + 56);
    bg2.addColorStop(0, '#34d399'); bg2.addColorStop(1, '#059669');
    ctx.fillStyle = bg2;
    ctx.beginPath(); ctx.roundRect(x2, by, BW, 56, 6); ctx.fill();
    ctx.strokeStyle = '#047857'; ctx.lineWidth = 1.5;
    ctx.beginPath(); ctx.roundRect(x2, by, BW, 56, 6); ctx.stroke();
    ctx.fillStyle = 'white'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
    ctx.fillText(`${p.m2}kg`, x2 + BW / 2, midY - 6);
    ctx.font = '9px system-ui';
    ctx.fillText(phase.current === 'before' ? `u=${p.u2} m/s` : `v=${result.current.v2.toFixed(1)} m/s`, x2 + BW / 2, midY + 10);

    // Velocity arrows before impact
    if (phase.current === 'before') {
      [{ x: x1, v: p.u1, w: BW }, { x: x2, v: p.u2, w: BW }].forEach(b => {
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

      // Warn if the bodies are not actually on a collision course, so the
      // "before" phase doesn't just run forever with no explanation.
      if (p.u1 - p.u2 <= 0) {
        ctx.fillStyle = '#dc2626'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
        ctx.fillText('Not closing — body 1 is not catching up to body 2 (raise u₁ or lower u₂)', W / 2, 20);
      }
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
