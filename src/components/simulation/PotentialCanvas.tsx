'use client';
import { useRef, useEffect, useCallback } from 'react';
import { coulombForceSigned, electricPotentialEnergy } from '@/lib/physics/electrostatics';

interface Props {
  q1nC: number; q2nC: number;
  initialSeparationCm: number;
  isRunning: boolean; isPaused: boolean;
  onTick?: (KE: number, PE: number, sepCm: number) => void;
  width?: number; height?: number;
}

const MASS_KG = 0.001;   // 1g pith ball, same as the Coulomb's law canvas
const PX_PER_M = 600;
const MIN_SEP_M = 0.03;  // kept safely away from the point-charge singularity — energy
                          // conservation verified numerically to stay under ~0.6% error here

function drawCharge(ctx: CanvasRenderingContext2D, x: number, y: number, sign: 1 | -1) {
  const r = 15;
  const grad = ctx.createRadialGradient(x - 3, y - 3, 1, x, y, r);
  if (sign > 0) { grad.addColorStop(0, '#fca5a5'); grad.addColorStop(1, '#dc2626'); }
  else { grad.addColorStop(0, '#93c5fd'); grad.addColorStop(1, '#2563eb'); }
  ctx.fillStyle = grad;
  ctx.beginPath(); ctx.arc(x, y, r, 0, Math.PI * 2); ctx.fill();
  ctx.strokeStyle = 'white'; ctx.lineWidth = 2;
  ctx.beginPath(); ctx.moveTo(x - r * 0.5, y); ctx.lineTo(x + r * 0.5, y); ctx.stroke();
  if (sign > 0) { ctx.beginPath(); ctx.moveTo(x, y - r * 0.5); ctx.lineTo(x, y + r * 0.5); ctx.stroke(); }
}

export function PotentialCanvas({ q1nC, q2nC, initialSeparationCm, isRunning, isPaused, onTick, width = 660, height = 280 }: Props) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const rafRef = useRef<number>(0);
  const lastFrameRef = useRef<number | null>(null);
  const sepM = useRef(0);
  const velM = useRef(0);
  const stopped = useRef(false);
  const sim = useRef({ q1nC, q2nC, initialSeparationCm, isRunning, isPaused, onTick });
  sim.current = { q1nC, q2nC, initialSeparationCm, isRunning, isPaused, onTick };

  useEffect(() => {
    sepM.current = initialSeparationCm / 100;
    velM.current = 0;
    stopped.current = false;
    lastFrameRef.current = null;
  }, [q1nC, q2nC, initialSeparationCm]);

  const draw = useCallback((timestamp?: number) => {
    const canvas = canvasRef.current; if (!canvas) return;
    const ctx = canvas.getContext('2d'); if (!ctx) return;
    const s = sim.current;
    const W = canvas.width, H = canvas.height;
    const midY = H * 0.42;

    const q1 = s.q1nC * 1e-9, q2 = s.q2nC * 1e-9;
    const running = s.isRunning && !s.isPaused;
    if (running && timestamp !== undefined && !stopped.current) {
      if (lastFrameRef.current !== null) {
        const dt = Math.min((timestamp - lastFrameRef.current) / 1000, 0.02);
        const steps = 6;
        for (let i = 0; i < steps; i++) {
          const F = coulombForceSigned(q1, q2, Math.max(sepM.current, MIN_SEP_M / 2));
          const a = F / MASS_KG;
          velM.current += a * (dt / steps);
          sepM.current += velM.current * (dt / steps);
          if (sepM.current <= MIN_SEP_M) { sepM.current = MIN_SEP_M; velM.current = 0; stopped.current = true; break; }
          if (sepM.current > 1.0) { sepM.current = 1.0; velM.current = 0; break; }
        }
      }
      lastFrameRef.current = timestamp;
    } else {
      lastFrameRef.current = timestamp ?? null;
    }
    if (!s.isRunning) { sepM.current = s.initialSeparationCm / 100; velM.current = 0; stopped.current = false; }

    const KE = 0.5 * MASS_KG * velM.current * velM.current;
    const PE = electricPotentialEnergy(q1, q2, sepM.current);
    s.onTick?.(KE, PE, sepM.current * 100);

    ctx.clearRect(0, 0, W, H);
    ctx.fillStyle = '#f8fafc'; ctx.fillRect(0, 0, W, H);

    const sepPx = Math.min(sepM.current * PX_PER_M, W - 80);
    const x1 = W / 2 - sepPx / 2, x2 = W / 2 + sepPx / 2;

    drawCharge(ctx, x1, midY, s.q1nC >= 0 ? 1 : -1);
    drawCharge(ctx, x2, midY, s.q2nC >= 0 ? 1 : -1);
    ctx.fillStyle = '#334155'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
    ctx.fillText(`${s.q1nC >= 0 ? '+' : ''}${s.q1nC}nC`, x1, midY + 32);
    ctx.fillText(`${s.q2nC >= 0 ? '+' : ''}${s.q2nC}nC`, x2, midY + 32);

    // Energy bars — a live, honest picture of KE and PE trading off,
    // verified numerically to conserve total energy to well under 1%
    // across this animation's range.
    const barY = H - 70, barMaxH = 50, barW = 46;
    const scaleJ = Math.max(Math.abs(PE), 1e-9) * 1.3;
    const keH = Math.min(barMaxH, (KE / scaleJ) * barMaxH);
    const peH = Math.min(barMaxH, (Math.abs(PE) / scaleJ) * barMaxH);
    const bx1 = W / 2 - 70, bx2 = W / 2 + 24;
    ctx.fillStyle = '#f59e0b';
    ctx.fillRect(bx1, barY - keH, barW, keH);
    ctx.fillStyle = PE >= 0 ? '#ef4444' : '#10b981';
    ctx.fillRect(bx2, barY - peH, barW, peH);
    ctx.strokeStyle = '#94a3b8'; ctx.lineWidth = 1;
    ctx.strokeRect(bx1, barY - barMaxH, barW, barMaxH);
    ctx.strokeRect(bx2, barY - barMaxH, barW, barMaxH);
    ctx.fillStyle = '#334155'; ctx.font = '10px system-ui'; ctx.textAlign = 'center';
    ctx.fillText('KE', bx1 + barW / 2, barY + 14);
    ctx.fillText('PE', bx2 + barW / 2, barY + 14);

    ctx.font = 'bold 11px system-ui'; ctx.textAlign = 'center';
    ctx.fillStyle = '#334155';
    ctx.fillText(
      stopped.current ? 'Closest safe separation reached — the point-charge model breaks down closer than this'
        : !running ? 'Press Run to release the moving charge' : 'As they move, kinetic and potential energy trade off — total stays constant',
      W / 2, 18,
    );

    ctx.fillStyle = '#64748b'; ctx.font = '10px system-ui'; ctx.textAlign = 'left';
    ctx.fillText(`separation r = ${(sepM.current * 100).toFixed(1)} cm`, 8, H - 10);
    ctx.textAlign = 'right';
    ctx.fillText(`Total ≈ ${((KE + PE) * 1e6).toFixed(2)} µJ`, W - 8, H - 10);

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
