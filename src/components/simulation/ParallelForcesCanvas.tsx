'use client';
import { useRef, useEffect, useCallback } from 'react';
import { netMoment, isBalanced, dampedStepResponse, Weight } from '@/lib/physics/equilibrium';

interface Props {
  weights: Weight[]; // position in metres from pivot, force in N
  isRunning: boolean; isPaused: boolean;
  onTick?: (angleDeg: number, netM: number) => void;
  width?: number; height?: number;
}

const MAX_TILT_DEG = 26; // the beam physically stops here (hits the ground/supports)
const BEAM_HALF_LEN_M = 2.2; // metres represented by the beam's visible half-length

export function ParallelForcesCanvas({ weights, isRunning, isPaused, onTick, width = 660, height = 280 }: Props) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const rafRef = useRef<number>(0);
  const lastFrameRef = useRef<number | null>(null);
  const t = useRef(0);
  const simRef = useRef({ weights, isRunning, isPaused, onTick });
  simRef.current = { weights, isRunning, isPaused, onTick };

  useEffect(() => { t.current = 0; lastFrameRef.current = null; }, [weights]);

  const draw = useCallback((timestamp?: number) => {
    const canvas = canvasRef.current; if (!canvas) return;
    const ctx = canvas.getContext('2d'); if (!ctx) return;
    const s = simRef.current;
    const W = canvas.width, H = canvas.height;

    if (s.isRunning && !s.isPaused && timestamp !== undefined) {
      if (lastFrameRef.current !== null) {
        t.current += Math.min((timestamp - lastFrameRef.current) / 1000, 0.1);
      }
      lastFrameRef.current = timestamp;
    } else {
      lastFrameRef.current = timestamp ?? null;
    }

    const netM = netMoment(s.weights);
    const balanced = isBalanced(s.weights);
    // Beam settles toward its rotational limit (or stays level if balanced)
    // with the same damped 2nd-order response used for the floating body —
    // "mass"/"stiffness" here are just pacing constants tuned to settle in
    // under a second, not literal moment-of-inertia values.
    const targetDeg = balanced ? 0 : Math.sign(netM) * MAX_TILT_DEG;
    const angleDeg = s.isRunning
      ? dampedStepResponse(t.current, targetDeg, 40, 1, 0.55)
      : 0;
    s.onTick?.(angleDeg, netM);

    ctx.clearRect(0, 0, W, H);
    ctx.fillStyle = '#f8fafc'; ctx.fillRect(0, 0, W, H);

    const pivotX = W / 2, pivotY = H * 0.62;
    const pxPerM = Math.min((W / 2 - 40) / BEAM_HALF_LEN_M, 110);
    const angleRad = (angleDeg * Math.PI) / 180;

    // Fulcrum (triangle support)
    ctx.fillStyle = '#64748b';
    ctx.beginPath();
    ctx.moveTo(pivotX, pivotY);
    ctx.lineTo(pivotX - 22, pivotY + 40);
    ctx.lineTo(pivotX + 22, pivotY + 40);
    ctx.closePath(); ctx.fill();
    ctx.fillStyle = '#94a3b8'; ctx.fillRect(pivotX - 60, pivotY + 40, 120, 8);

    // Beam, rotated about the pivot
    const beamHalfPx = BEAM_HALF_LEN_M * pxPerM;
    const x1 = pivotX - Math.cos(angleRad) * beamHalfPx, y1 = pivotY - Math.sin(angleRad) * beamHalfPx;
    const x2 = pivotX + Math.cos(angleRad) * beamHalfPx, y2 = pivotY + Math.sin(angleRad) * beamHalfPx;
    ctx.strokeStyle = '#92400e'; ctx.lineWidth = 10; ctx.lineCap = 'round';
    ctx.beginPath(); ctx.moveTo(x1, y1); ctx.lineTo(x2, y2); ctx.stroke();
    ctx.strokeStyle = '#b45309'; ctx.lineWidth = 3;
    ctx.beginPath(); ctx.moveTo(x1, y1); ctx.lineTo(x2, y2); ctx.stroke();

    // Metre scale ticks
    ctx.fillStyle = '#94a3b8'; ctx.font = '9px system-ui'; ctx.textAlign = 'center';
    for (let m = -2; m <= 2; m++) {
      if (m === 0) continue;
      const bx = pivotX + Math.cos(angleRad) * m * pxPerM;
      const by = pivotY + Math.sin(angleRad) * m * pxPerM;
      ctx.fillText(`${m}m`, bx, by - 12);
    }

    // Weights hanging at their positions along the beam
    s.weights.forEach((w, i) => {
      const bx = pivotX + Math.cos(angleRad) * w.position * pxPerM;
      const by = pivotY + Math.sin(angleRad) * w.position * pxPerM;
      const hookLen = 22;
      ctx.strokeStyle = '#475569'; ctx.lineWidth = 1.5;
      ctx.beginPath(); ctx.moveTo(bx, by); ctx.lineTo(bx, by + hookLen); ctx.stroke();
      const r = 12 + Math.min(w.force, 40) * 0.25;
      const color = ['#6366f1', '#10b981', '#f59e0b'][i % 3];
      ctx.fillStyle = color;
      ctx.beginPath(); ctx.arc(bx, by + hookLen + r, r, 0, Math.PI * 2); ctx.fill();
      ctx.fillStyle = 'white'; ctx.font = 'bold 9px system-ui'; ctx.textAlign = 'center';
      ctx.fillText(`${w.force}N`, bx, by + hookLen + r + 3);
      ctx.fillStyle = '#334155'; ctx.font = '9px system-ui';
      ctx.fillText(`${w.position >= 0 ? '+' : ''}${w.position}m`, bx, by + hookLen + 2 * r + 14);
    });

    // Status
    ctx.font = 'bold 11px system-ui'; ctx.textAlign = 'center';
    if (balanced) {
      ctx.fillStyle = '#059669';
      ctx.fillText('BALANCED — sum of clockwise moments = sum of anticlockwise moments', W / 2, 20);
    } else {
      ctx.fillStyle = '#f59e0b';
      ctx.fillText(`UNBALANCED — net moment = ${netM.toFixed(2)} N·m (tips ${netM > 0 ? 'clockwise ↷' : 'anticlockwise ↶'})`, W / 2, 20);
    }
    ctx.fillStyle = '#64748b'; ctx.font = '10px system-ui'; ctx.textAlign = 'left';
    ctx.fillText(`Σ(F × d): ${s.weights.map(w => `${w.force}×${w.position}`).join(' + ')} = ${netM.toFixed(2)} N·m`, 8, H - 10);

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
