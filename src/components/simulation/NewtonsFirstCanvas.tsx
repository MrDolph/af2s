'use client';
import { useRef, useEffect, useCallback } from 'react';
import { stepFirstLaw, FirstLawState } from '@/lib/physics/newtons-laws';

interface Props {
  mass: number; friction: number; initialVelocity: number;
  forceOn: boolean; appliedForce: number;
  isRunning: boolean; isPaused: boolean;
  onTick?: (s: FirstLawState) => void;
  width?: number; height?: number;
}

export function NewtonsFirstCanvas({
  mass, friction, initialVelocity, forceOn, appliedForce,
  isRunning, isPaused, onTick, width = 680, height = 220,
}: Props) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const rafRef = useRef<number>(0);
  const stateRef = useRef<FirstLawState>({ x: 0, v: initialVelocity, time: 0 });
  const simRef = useRef({ mass, friction, initialVelocity, forceOn, appliedForce, isRunning, isPaused, onTick, width, height });
  simRef.current = { mass, friction, initialVelocity, forceOn, appliedForce, isRunning, isPaused, onTick, width, height };

  useEffect(() => {
    stateRef.current = { x: 0, v: initialVelocity, time: 0 };
  }, [initialVelocity, mass, friction, appliedForce]);

  const draw = useCallback(() => {
    const canvas = canvasRef.current; if (!canvas) return;
    const ctx = canvas.getContext('2d'); if (!ctx) return;
    const { isRunning: r, isPaused: p, forceOn, appliedForce: F, mass: m, friction: mu, onTick: ot } = simRef.current;
    const W = canvas.width, H = canvas.height;

    if (r && !p) {
      stateRef.current = stepFirstLaw(stateRef.current, forceOn ? F : 0, m, mu, 0.016);
      ot?.(stateRef.current);
    }

    const state = stateRef.current;
    ctx.clearRect(0, 0, W, H);

    // Ground
    const groundY = H - 50;
    ctx.fillStyle = '#f8fafc'; ctx.fillRect(0, 0, W, groundY);
    ctx.fillStyle = '#e2e8f0'; ctx.fillRect(0, groundY, W, H - groundY);
    ctx.beginPath(); ctx.moveTo(0, groundY); ctx.lineTo(W, groundY);
    ctx.strokeStyle = '#94a3b8'; ctx.lineWidth = 2; ctx.stroke();

    // Surface texture (friction indicator)
    if (mu > 0.05) {
      ctx.save();
      for (let x = 0; x < W; x += 20) {
        ctx.beginPath(); ctx.moveTo(x, groundY); ctx.lineTo(x + 10, groundY + 8);
        ctx.strokeStyle = `rgba(148,163,184,${Math.min(mu * 1.5, 0.6)})`;
        ctx.lineWidth = 1; ctx.stroke();
      }
      ctx.restore();
    }

    // Friction label
    ctx.fillStyle = '#94a3b8'; ctx.font = '10px system-ui'; ctx.textAlign = 'left';
    ctx.fillText(`μ = ${mu.toFixed(2)} ${mu === 0 ? '(frictionless)' : mu < 0.2 ? '(low friction)' : '(high friction)'}`, 10, H - 10);

    // Block position (wrap around canvas)
    const BLOCK_W = 60, BLOCK_H = 44;
    const rawX = (state.x * 60) % (W + BLOCK_W);
    const bx = rawX < -BLOCK_W ? W + rawX : rawX;
    const by = groundY - BLOCK_H;

    // Block shadow
    ctx.fillStyle = 'rgba(0,0,0,0.08)';
    ctx.fillRect(bx + 4, groundY - 4, BLOCK_W, 8);

    // Block body
    const blockGrad = ctx.createLinearGradient(bx, by, bx, by + BLOCK_H);
    blockGrad.addColorStop(0, '#818cf8'); blockGrad.addColorStop(1, '#4f46e5');
    ctx.fillStyle = blockGrad;
    ctx.beginPath(); ctx.roundRect(bx, by, BLOCK_W, BLOCK_H, 6); ctx.fill();
    ctx.strokeStyle = '#3730a3'; ctx.lineWidth = 1.5;
    ctx.beginPath(); ctx.roundRect(bx, by, BLOCK_W, BLOCK_H, 6); ctx.stroke();

    // Mass label on block
    ctx.fillStyle = 'white'; ctx.font = 'bold 11px system-ui'; ctx.textAlign = 'center';
    ctx.fillText(`${m} kg`, bx + BLOCK_W / 2, by + BLOCK_H / 2 + 4);

    // Applied force arrow
    if (forceOn && F > 0) {
      const arrowLen = Math.min(F * 1.2, 80);
      const ax = bx + BLOCK_W, ay = by + BLOCK_H / 2;
      ctx.save();
      ctx.beginPath(); ctx.moveTo(ax, ay); ctx.lineTo(ax + arrowLen, ay);
      ctx.strokeStyle = '#10b981'; ctx.lineWidth = 3; ctx.stroke();
      ctx.beginPath(); ctx.moveTo(ax + arrowLen, ay);
      ctx.lineTo(ax + arrowLen - 10, ay - 6); ctx.lineTo(ax + arrowLen - 10, ay + 6);
      ctx.closePath(); ctx.fillStyle = '#10b981'; ctx.fill();
      ctx.fillStyle = '#10b981'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
      ctx.fillText(`F=${F}N`, ax + arrowLen / 2, ay - 8);
      ctx.restore();
    }

    // Velocity arrow
    if (Math.abs(state.v) > 0.1) {
      const arrowLen = Math.min(Math.abs(state.v) * 8, 70);
      const dir = Math.sign(state.v);
      const ax = bx + (dir > 0 ? BLOCK_W : 0), ay = by - 10;
      ctx.save();
      ctx.beginPath(); ctx.moveTo(ax, ay); ctx.lineTo(ax + dir * arrowLen, ay);
      ctx.strokeStyle = '#f59e0b'; ctx.lineWidth = 2; ctx.stroke();
      ctx.beginPath(); ctx.moveTo(ax + dir * arrowLen, ay);
      ctx.lineTo(ax + dir * (arrowLen - 8), ay - 5);
      ctx.lineTo(ax + dir * (arrowLen - 8), ay + 5);
      ctx.closePath(); ctx.fillStyle = '#f59e0b'; ctx.fill();
      ctx.fillStyle = '#f59e0b'; ctx.font = '10px system-ui'; ctx.textAlign = 'center';
      ctx.fillText(`v=${state.v.toFixed(1)} m/s`, ax + dir * arrowLen / 2, ay - 10);
      ctx.restore();
    }

    // State info
    ctx.fillStyle = '#475569'; ctx.font = '11px monospace'; ctx.textAlign = 'right';
    ctx.fillText(`t=${state.time.toFixed(1)}s  v=${state.v.toFixed(2)}m/s`, W - 10, 20);

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
