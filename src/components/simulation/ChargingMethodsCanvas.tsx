'use client';
import { useRef, useEffect, useCallback } from 'react';

export type ChargingMethod = 'friction' | 'conduction' | 'induction';

interface Props {
  method: ChargingMethod;
  isRunning: boolean; isPaused: boolean;
  onPhaseChange?: (phase: string) => void;
  width?: number; height?: number;
}

function drawCharge(ctx: CanvasRenderingContext2D, x: number, y: number, sign: 1 | -1, r = 7) {
  ctx.save();
  ctx.fillStyle = sign > 0 ? '#ef4444' : '#3b82f6';
  ctx.beginPath(); ctx.arc(x, y, r, 0, Math.PI * 2); ctx.fill();
  ctx.strokeStyle = 'white'; ctx.lineWidth = 1.5;
  ctx.beginPath(); ctx.moveTo(x - r * 0.5, y); ctx.lineTo(x + r * 0.5, y); ctx.stroke();
  if (sign > 0) { ctx.beginPath(); ctx.moveTo(x, y - r * 0.5); ctx.lineTo(x, y + r * 0.5); ctx.stroke(); }
  ctx.restore();
}

// Phase durations (s) for each method's animated sequence
const DURATIONS: Record<ChargingMethod, number[]> = {
  friction: [1.2, 1.8, 1.2],                 // approach, rub, separate
  conduction: [1.2, 1.4, 1.2],               // approach, touch/transfer, separate
  induction: [1.0, 1.4, 1.2, 0.8, 1.2],      // approach, polarize, ground, disconnect, remove
};
const PHASE_LABELS: Record<ChargingMethod, string[]> = {
  friction: ['Rod and cloth, both neutral', 'Rubbing transfers electrons rod → cloth', 'Rod is left positive, cloth negative'],
  conduction: ['Charged rod approaches a neutral sphere', 'Contact — electrons spread onto the sphere', 'Sphere keeps the SAME sign as the rod, rod\u2019s charge is reduced'],
  induction: [
    'Charged rod approaches — sphere still neutral overall',
    'Polarisation: charges separate, but total charge is still zero',
    'Earthing: the repelled charge escapes to ground',
    'Ground wire disconnected — sphere now has a net charge',
    'Rod removed — induced charge is OPPOSITE to the rod, spread evenly',
  ],
};

export function ChargingMethodsCanvas({ method, isRunning, isPaused, onPhaseChange, width = 660, height = 300 }: Props) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const rafRef = useRef<number>(0);
  const lastFrameRef = useRef<number | null>(null);
  const t = useRef(0);
  const lastPhaseIdx = useRef(-1);
  const sim = useRef({ method, isRunning, isPaused, onPhaseChange });
  sim.current = { method, isRunning, isPaused, onPhaseChange };

  useEffect(() => { t.current = 0; lastFrameRef.current = null; lastPhaseIdx.current = -1; }, [method]);

  const draw = useCallback((timestamp?: number) => {
    const canvas = canvasRef.current; if (!canvas) return;
    const ctx = canvas.getContext('2d'); if (!ctx) return;
    const s = sim.current;
    const W = canvas.width, H = canvas.height;
    const durations = DURATIONS[s.method];
    const totalDuration = durations.reduce((a, b) => a + b, 0);

    if (s.isRunning && !s.isPaused && timestamp !== undefined) {
      if (lastFrameRef.current !== null) {
        t.current = Math.min(t.current + (timestamp - lastFrameRef.current) / 1000, totalDuration);
      }
      lastFrameRef.current = timestamp;
    } else {
      lastFrameRef.current = timestamp ?? null;
    }

    // Which phase are we in, and how far through it (0..1)?
    let acc = 0, phaseIdx = 0, phaseT = 0;
    for (let i = 0; i < durations.length; i++) {
      if (t.current < acc + durations[i] || i === durations.length - 1) {
        phaseIdx = i; phaseT = Math.min(1, (t.current - acc) / durations[i]); break;
      }
      acc += durations[i];
    }
    if (!s.isRunning) { phaseIdx = 0; phaseT = 0; }
    if (phaseIdx !== lastPhaseIdx.current) { lastPhaseIdx.current = phaseIdx; s.onPhaseChange?.(PHASE_LABELS[s.method][phaseIdx]); }

    ctx.clearRect(0, 0, W, H);
    ctx.fillStyle = '#f8fafc'; ctx.fillRect(0, 0, W, H);

    const midY = H / 2;

    if (s.method === 'friction') {
      // approach(0) -> rub(1) -> separate(2)
      const approach = phaseIdx === 0 ? phaseT : 1;
      const rubProgress = phaseIdx === 1 ? phaseT : phaseIdx > 1 ? 1 : 0;
      const separate = phaseIdx === 2 ? phaseT : 0;
      const gap = 120 * (1 - approach) - separate * 100;
      const rodX = W / 2 - 60 - gap / 2, clothX = W / 2 + 60 + gap / 2;
      const wobble = phaseIdx === 1 ? Math.sin(t.current * 18) * 10 : 0;

      // Rod (glass)
      ctx.fillStyle = '#c7d2fe'; ctx.fillRect(rodX - 8 + wobble, midY - 60, 16, 120);
      ctx.strokeStyle = '#6366f1'; ctx.strokeRect(rodX - 8 + wobble, midY - 60, 16, 120);
      ctx.fillStyle = '#334155'; ctx.font = '10px system-ui'; ctx.textAlign = 'center';
      ctx.fillText('glass rod', rodX + wobble, midY - 70);

      // Cloth (silk)
      ctx.fillStyle = '#fecaca'; ctx.fillRect(clothX - 26 - wobble, midY - 50, 52, 100);
      ctx.strokeStyle = '#ef4444'; ctx.strokeRect(clothX - 26 - wobble, midY - 50, 52, 100);
      ctx.fillText('silk cloth', clothX - wobble, midY - 60);

      // Electrons transferring during rub phase
      if (phaseIdx === 1) {
        for (let i = 0; i < 5; i++) {
          const ex = rodX + wobble + (clothX - wobble - (rodX + wobble)) * Math.min(1, rubProgress * 1.4 - i * 0.08);
          if (ex > rodX + wobble && ex < clothX - wobble) drawCharge(ctx, ex, midY - 30 + i * 15, -1, 5);
        }
      }
      const netCharge = phaseIdx >= 1 ? Math.min(1, rubProgress) : 0;
      if (netCharge > 0.05 || phaseIdx === 2) {
        drawCharge(ctx, rodX + wobble, midY + 50, 1, 6);
        drawCharge(ctx, clothX - wobble, midY + 50, -1, 6);
      }
    } else if (s.method === 'conduction') {
      const approach = phaseIdx === 0 ? phaseT : 1;
      const separate = phaseIdx === 2 ? phaseT : 0;
      const gap = 100 * (1 - approach) + separate * 90;
      const sphereX = W / 2 + 90;
      const rodTipX = sphereX - 60 - gap;

      ctx.fillStyle = '#93c5fd'; ctx.fillRect(rodTipX - 90, midY - 8, 90, 16);
      ctx.strokeStyle = '#2563eb'; ctx.strokeRect(rodTipX - 90, midY - 8, 90, 16);
      ctx.fillStyle = '#334155'; ctx.font = '10px system-ui'; ctx.textAlign = 'center';
      ctx.fillText('negatively charged rod', rodTipX - 45, midY - 20);
      for (let i = 0; i < 5; i++) drawCharge(ctx, rodTipX - 12 - i * 16, midY, -1, 5);

      ctx.fillStyle = '#e2e8f0';
      ctx.beginPath(); ctx.arc(sphereX, midY, 34, 0, Math.PI * 2); ctx.fill();
      ctx.strokeStyle = '#94a3b8'; ctx.stroke();
      ctx.fillText('neutral sphere', sphereX, midY - 46);

      if (phaseIdx >= 1) {
        const n = Math.round((phaseIdx === 1 ? phaseT : 1) * 4);
        for (let i = 0; i < n; i++) {
          const a = (i / 4) * Math.PI * 2;
          drawCharge(ctx, sphereX + Math.cos(a) * 20, midY + Math.sin(a) * 20, -1, 5);
        }
      }
      if (phaseIdx === 2) {
        ctx.fillStyle = '#1e293b'; ctx.font = 'bold 10px system-ui';
        ctx.fillText('rod: reduced (–)   sphere: (–), same sign as rod', W / 2, H - 16);
      }
    } else {
      // induction: approach(0) polarise(1) ground(2) disconnect(3) remove(4)
      const approach = phaseIdx === 0 ? phaseT : 1;
      const remove = phaseIdx === 4 ? phaseT : 0;
      const gap = 130 * (1 - approach) + remove * 160;
      const sphereX = W / 2 + 60;
      const rodTipX = sphereX - 70 - gap;

      ctx.fillStyle = '#93c5fd'; ctx.fillRect(rodTipX - 90, midY - 100, 16, 100);
      ctx.strokeStyle = '#2563eb'; ctx.strokeRect(rodTipX - 90, midY - 100, 16, 100);
      ctx.fillStyle = '#334155'; ctx.font = '10px system-ui'; ctx.textAlign = 'center';
      ctx.fillText('negative rod', rodTipX - 82, midY - 110);
      for (let i = 0; i < 4; i++) drawCharge(ctx, rodTipX - 82, midY - 90 + i * 25, -1, 5);

      ctx.fillStyle = '#e2e8f0';
      ctx.beginPath(); ctx.arc(sphereX, midY, 34, 0, Math.PI * 2); ctx.fill();
      ctx.strokeStyle = '#94a3b8'; ctx.stroke();

      const polarised = phaseIdx >= 1;
      const grounded = phaseIdx === 2 || phaseIdx === 3;
      const groundProgress = phaseIdx === 2 ? phaseT : phaseIdx > 2 ? 1 : 0;
      const finalCharge = phaseIdx === 4;

      if (grounded) {
        ctx.strokeStyle = '#64748b'; ctx.lineWidth = 2;
        ctx.beginPath(); ctx.moveTo(sphereX + 34, midY); ctx.lineTo(sphereX + 80, midY); ctx.lineTo(sphereX + 80, midY + 60); ctx.stroke();
        for (let i = -1; i <= 1; i++) { ctx.beginPath(); ctx.moveTo(sphereX + 72 + i * 6, midY + 60); ctx.lineTo(sphereX + 66 + i * 6, midY + 70); ctx.stroke(); }
        ctx.fillStyle = '#64748b'; ctx.font = '9px system-ui'; ctx.fillText('ground', sphereX + 80, midY + 84);
      }

      if (polarised) {
        // near side (left, toward rod) positive; far side negative, fading as it's earthed away
        for (let i = 0; i < 3; i++) drawCharge(ctx, sphereX - 16, midY - 16 + i * 16, 1, 5);
        const farAlpha = grounded ? Math.max(0, 1 - groundProgress) : 1;
        if (farAlpha > 0.05 && !finalCharge) {
          ctx.save(); ctx.globalAlpha = farAlpha;
          for (let i = 0; i < 3; i++) drawCharge(ctx, sphereX + 16, midY - 16 + i * 16, -1, 5);
          ctx.restore();
        }
      }
      if (finalCharge) {
        // Net positive, spread evenly
        for (let i = 0; i < 4; i++) {
          const a = (i / 4) * Math.PI * 2;
          drawCharge(ctx, sphereX + Math.cos(a) * 20, midY + Math.sin(a) * 20, 1, 5);
        }
        ctx.fillStyle = '#1e293b'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
        ctx.fillText('Sphere left with a net POSITIVE charge — opposite to the rod', W / 2, H - 16);
      }
    }

    ctx.fillStyle = '#334155'; ctx.font = 'bold 11px system-ui'; ctx.textAlign = 'center';
    ctx.fillText(PHASE_LABELS[s.method][phaseIdx] ?? '', W / 2, 24);

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
