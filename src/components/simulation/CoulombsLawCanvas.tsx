'use client';
import { useRef, useEffect, useCallback } from 'react';
import { coulombForceSigned } from '@/lib/physics/electrostatics';

interface Props {
  q1nC: number; q2nC: number;  // signed charge, nanocoulombs
  initialSeparationCm: number;
  isRunning: boolean; isPaused: boolean;
  onTick?: (separationCm: number, forceN: number) => void;
  width?: number; height?: number;
}

const MASS_KG = 0.001;       // 1g — a light charged pith ball, for a watchable release animation
const PX_PER_M = 600;
const MIN_SEP_M = 0.01;      // 1cm — treat as "contact" below this

function drawCharge(ctx: CanvasRenderingContext2D, x: number, y: number, sign: 1 | -1, magnitude: number) {
  const r = 14 + Math.min(10, Math.abs(magnitude) * 0.3);
  const grad = ctx.createRadialGradient(x - 3, y - 3, 1, x, y, r);
  if (sign > 0) { grad.addColorStop(0, '#fca5a5'); grad.addColorStop(1, '#dc2626'); }
  else { grad.addColorStop(0, '#93c5fd'); grad.addColorStop(1, '#2563eb'); }
  ctx.fillStyle = grad;
  ctx.beginPath(); ctx.arc(x, y, r, 0, Math.PI * 2); ctx.fill();
  ctx.strokeStyle = 'white'; ctx.lineWidth = 2;
  ctx.beginPath(); ctx.moveTo(x - r * 0.5, y); ctx.lineTo(x + r * 0.5, y); ctx.stroke();
  if (sign > 0) { ctx.beginPath(); ctx.moveTo(x, y - r * 0.5); ctx.lineTo(x, y + r * 0.5); ctx.stroke(); }
}

function arrow(ctx: CanvasRenderingContext2D, x1: number, y1: number, x2: number, y2: number, color: string) {
  if (Math.hypot(x2 - x1, y2 - y1) < 2) return;
  ctx.save();
  ctx.strokeStyle = color; ctx.lineWidth = 3;
  ctx.beginPath(); ctx.moveTo(x1, y1); ctx.lineTo(x2, y2); ctx.stroke();
  const ang = Math.atan2(y2 - y1, x2 - x1);
  ctx.fillStyle = color;
  ctx.beginPath(); ctx.moveTo(x2, y2);
  ctx.lineTo(x2 - 10 * Math.cos(ang - 0.4), y2 - 10 * Math.sin(ang - 0.4));
  ctx.lineTo(x2 - 10 * Math.cos(ang + 0.4), y2 - 10 * Math.sin(ang + 0.4));
  ctx.closePath(); ctx.fill();
  ctx.restore();
}

export function CoulombsLawCanvas({ q1nC, q2nC, initialSeparationCm, isRunning, isPaused, onTick, width = 660, height = 260 }: Props) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const rafRef = useRef<number>(0);
  const lastFrameRef = useRef<number | null>(null);
  const sepM = useRef(0);
  const velM = useRef(0);
  const contactMade = useRef(false);
  const sim = useRef({ q1nC, q2nC, initialSeparationCm, isRunning, isPaused, onTick });
  sim.current = { q1nC, q2nC, initialSeparationCm, isRunning, isPaused, onTick };

  useEffect(() => {
    sepM.current = initialSeparationCm / 100;
    velM.current = 0;
    contactMade.current = false;
    lastFrameRef.current = null;
  }, [q1nC, q2nC, initialSeparationCm]);

  const draw = useCallback((timestamp?: number) => {
    const canvas = canvasRef.current; if (!canvas) return;
    const ctx = canvas.getContext('2d'); if (!ctx) return;
    const s = sim.current;
    const W = canvas.width, H = canvas.height;
    const midY = H / 2;

    const q1 = s.q1nC * 1e-9, q2 = s.q2nC * 1e-9;
    const running = s.isRunning && !s.isPaused;
    if (running && timestamp !== undefined && !contactMade.current) {
      if (lastFrameRef.current !== null) {
        const dt = Math.min((timestamp - lastFrameRef.current) / 1000, 0.02);
        // Sub-step for stability, since force changes quickly at close range
        const steps = 4;
        for (let i = 0; i < steps; i++) {
          const F = coulombForceSigned(q1, q2, Math.max(sepM.current, MIN_SEP_M / 2)); // + repel, - attract
          const a = F / MASS_KG;
          velM.current += a * (dt / steps);
          sepM.current += velM.current * (dt / steps);
          if (sepM.current <= MIN_SEP_M) { sepM.current = MIN_SEP_M; velM.current = 0; contactMade.current = true; break; }
          if (sepM.current > 1.2) { sepM.current = 1.2; velM.current = 0; break; } // off comfortable viewing range
        }
      }
      lastFrameRef.current = timestamp;
    } else {
      lastFrameRef.current = timestamp ?? null;
    }
    if (!s.isRunning) { sepM.current = s.initialSeparationCm / 100; contactMade.current = false; }

    const forceN = coulombForceSigned(q1, q2, sepM.current);
    s.onTick?.(sepM.current * 100, forceN);

    ctx.clearRect(0, 0, W, H);
    ctx.fillStyle = '#f8fafc'; ctx.fillRect(0, 0, W, H);

    const sepPx = Math.min(sepM.current * PX_PER_M, W - 80);
    const x1 = W / 2 - sepPx / 2, x2 = W / 2 + sepPx / 2;

    // Force vectors (drawn first so charges sit on top)
    const repulsive = forceN > 0;
    const arrowLen = Math.min(70, Math.abs(forceN) * 4e5 + 12);
    if (Math.abs(forceN) > 1e-9) {
      if (repulsive) {
        arrow(ctx, x1, midY - 40, x1 - arrowLen, midY - 40, '#f59e0b');
        arrow(ctx, x2, midY - 40, x2 + arrowLen, midY - 40, '#f59e0b');
      } else {
        arrow(ctx, x1 - arrowLen - 20, midY - 40, x1 - 20, midY - 40, '#10b981');
        arrow(ctx, x2 + arrowLen + 20, midY - 40, x2 + 20, midY - 40, '#10b981');
      }
    }

    drawCharge(ctx, x1, midY, s.q1nC >= 0 ? 1 : -1, s.q1nC);
    drawCharge(ctx, x2, midY, s.q2nC >= 0 ? 1 : -1, s.q2nC);
    ctx.fillStyle = '#334155'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
    ctx.fillText(`${s.q1nC >= 0 ? '+' : ''}${s.q1nC}nC`, x1, midY + 34);
    ctx.fillText(`${s.q2nC >= 0 ? '+' : ''}${s.q2nC}nC`, x2, midY + 34);

    ctx.font = 'bold 11px system-ui'; ctx.textAlign = 'center';
    ctx.fillStyle = contactMade.current ? '#dc2626' : repulsive ? '#f59e0b' : '#10b981';
    ctx.fillText(
      contactMade.current ? 'Charges have come into contact — the point-charge model breaks down here'
        : `${repulsive ? 'REPULSIVE' : 'ATTRACTIVE'} — F = ${Math.abs(forceN) < 1e-3 ? (Math.abs(forceN) * 1e6).toFixed(1) + ' µN' : (Math.abs(forceN) * 1e3).toFixed(2) + ' mN'}`,
      W / 2, 24,
    );
    ctx.fillStyle = '#64748b'; ctx.font = '10px system-ui'; ctx.textAlign = 'left';
    ctx.fillText(`separation r = ${(sepM.current * 100).toFixed(1)} cm`, 8, H - 10);

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
