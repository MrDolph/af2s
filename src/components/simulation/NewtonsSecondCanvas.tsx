'use client';
import { useRef, useEffect, useCallback } from 'react';
import { stepSecondLaw, SecondLawState, SecondLawParams } from '@/lib/physics/newtons-laws';

interface Props {
  params: SecondLawParams;
  isRunning: boolean; isPaused: boolean;
  onTick?: (s: SecondLawState) => void;
  onComplete?: () => void;
  width?: number; height?: number;
}

const TRACK_LEN = 12; // metres shown

export function NewtonsSecondCanvas({ params, isRunning, isPaused, onTick, onComplete, width = 680, height = 240 }: Props) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const rafRef = useRef<number>(0);
  const stateRef = useRef<SecondLawState>({ x: 0, v: 0, a: 0, time: 0, frictionForce: 0, netForce: 0 });
  const doneRef = useRef(false);
  const simRef = useRef({ params, isRunning, isPaused, onTick, onComplete });
  simRef.current = { params, isRunning, isPaused, onTick, onComplete };

  useEffect(() => {
    stateRef.current = { x: 0, v: 0, a: 0, time: 0, frictionForce: 0, netForce: 0 };
    doneRef.current = false;
  }, [params]);

  const draw = useCallback(() => {
    const canvas = canvasRef.current; if (!canvas) return;
    const ctx = canvas.getContext('2d'); if (!ctx) return;
    const { isRunning: r, isPaused: p, params: pm, onTick: ot, onComplete: oc } = simRef.current;
    const W = canvas.width, H = canvas.height;
    const state = stateRef.current;

    if (r && !p && !doneRef.current) {
      const next = stepSecondLaw(state, pm, 0.016);
      stateRef.current = next;
      ot?.(next);
      if (next.x >= TRACK_LEN) { doneRef.current = true; oc?.(); }
    }

    ctx.clearRect(0, 0, W, H);

    // Track
    const groundY = H - 55;
    ctx.fillStyle = '#f8fafc'; ctx.fillRect(0, 0, W, groundY);
    ctx.fillStyle = '#e2e8f0'; ctx.fillRect(0, groundY, W, H - groundY);
    ctx.beginPath(); ctx.moveTo(0, groundY); ctx.lineTo(W, groundY);
    ctx.strokeStyle = '#94a3b8'; ctx.lineWidth = 2; ctx.stroke();

    // Track scale marks
    const scale = (W - 80) / TRACK_LEN;
    ctx.fillStyle = '#94a3b8'; ctx.font = '10px system-ui'; ctx.textAlign = 'center';
    for (let i = 0; i <= TRACK_LEN; i += 2) {
      const tx = 40 + i * scale;
      ctx.fillText(`${i}m`, tx, H - 8);
      ctx.beginPath(); ctx.moveTo(tx, groundY); ctx.lineTo(tx, groundY + 5);
      ctx.strokeStyle = '#cbd5e1'; ctx.lineWidth = 1; ctx.stroke();
    }

    // Friction texture
    if (pm.friction > 0.05) {
      for (let x = 0; x < W; x += 18) {
        ctx.beginPath(); ctx.moveTo(x, groundY); ctx.lineTo(x + 9, groundY + 7);
        ctx.strokeStyle = `rgba(148,163,184,${Math.min(pm.friction, 0.5)})`;
        ctx.lineWidth = 1; ctx.stroke();
      }
    }

    // Block
    const BLOCK_W = 56, BLOCK_H = 44;
    const bx = 40 + Math.min(state.x, TRACK_LEN) * scale - BLOCK_W / 2;
    const by = groundY - BLOCK_H;

    ctx.fillStyle = 'rgba(0,0,0,0.07)';
    ctx.fillRect(bx + 4, groundY - 4, BLOCK_W, 8);

    const bg = ctx.createLinearGradient(bx, by, bx, by + BLOCK_H);
    bg.addColorStop(0, '#818cf8'); bg.addColorStop(1, '#4f46e5');
    ctx.fillStyle = bg;
    ctx.beginPath(); ctx.roundRect(bx, by, BLOCK_W, BLOCK_H, 6); ctx.fill();
    ctx.strokeStyle = '#3730a3'; ctx.lineWidth = 1.5;
    ctx.beginPath(); ctx.roundRect(bx, by, BLOCK_W, BLOCK_H, 6); ctx.stroke();
    ctx.fillStyle = 'white'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
    ctx.fillText(`${pm.mass}kg`, bx + BLOCK_W / 2, by + BLOCK_H / 2 + 4);

    const midY = by + BLOCK_H / 2;

    // Applied force arrow (green, rightward)
    if (pm.appliedForce > 0) {
      const fLen = Math.min(pm.appliedForce * 1.5, 90);
      const ax = bx + BLOCK_W;
      ctx.save();
      ctx.beginPath(); ctx.moveTo(ax, midY); ctx.lineTo(ax + fLen, midY);
      ctx.strokeStyle = '#10b981'; ctx.lineWidth = 3; ctx.stroke();
      ctx.beginPath(); ctx.moveTo(ax + fLen, midY);
      ctx.lineTo(ax + fLen - 10, midY - 6); ctx.lineTo(ax + fLen - 10, midY + 6);
      ctx.closePath(); ctx.fillStyle = '#10b981'; ctx.fill();
      ctx.fillStyle = '#10b981'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
      ctx.fillText(`F=${pm.appliedForce}N`, ax + fLen / 2, midY - 10);
      ctx.restore();
    }

    // Friction arrow (red, leftward) — only when moving
    if (state.v > 0.01 && pm.friction > 0) {
      const fLen = Math.min(pm.friction * pm.mass * 9.81 * 1.2, 70);
      const ax = bx;
      ctx.save();
      ctx.beginPath(); ctx.moveTo(ax, midY + 14); ctx.lineTo(ax - fLen, midY + 14);
      ctx.strokeStyle = '#ef4444'; ctx.lineWidth = 2.5; ctx.stroke();
      ctx.beginPath(); ctx.moveTo(ax - fLen, midY + 14);
      ctx.lineTo(ax - fLen + 9, midY + 8); ctx.lineTo(ax - fLen + 9, midY + 20);
      ctx.closePath(); ctx.fillStyle = '#ef4444'; ctx.fill();
      ctx.fillStyle = '#ef4444'; ctx.font = '10px system-ui'; ctx.textAlign = 'center';
      ctx.fillText(`f=${(pm.friction * pm.mass * 9.81).toFixed(1)}N`, ax - fLen / 2, midY + 30);
      ctx.restore();
    }

    // Net force label
    const netF = state.netForce;
    ctx.fillStyle = '#6366f1'; ctx.font = 'bold 11px monospace'; ctx.textAlign = 'left';
    ctx.fillText(`F_net=${netF.toFixed(1)}N  a=${state.a.toFixed(2)}m/s²  v=${state.v.toFixed(2)}m/s`, 10, 22);

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
