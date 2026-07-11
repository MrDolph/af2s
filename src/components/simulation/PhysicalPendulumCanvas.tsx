'use client';
import { useRef, useEffect, useCallback } from 'react';
import { physicalPendulumPeriod, pendulumPeriod } from '@/lib/physics/shm';

interface Props {
  length: number; mass: number; pivotFraction: number;
  isRunning: boolean; isPaused: boolean;
  width?: number; height?: number;
}

export function PhysicalPendulumCanvas({ length, mass, pivotFraction, isRunning, isPaused, width = 380, height = 320 }: Props) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const rafRef = useRef<number>(0);
  const tRef = useRef(0);
  const sim = useRef({ length, mass, pivotFraction, isRunning, isPaused });
  sim.current = { length, mass, pivotFraction, isRunning, isPaused };

  useEffect(() => { tRef.current = 0; }, [length, mass, pivotFraction]);

  const draw = useCallback(() => {
    const canvas = canvasRef.current; if (!canvas) return;
    const ctx = canvas.getContext('2d'); if (!ctx) return;
    const { length: L, mass: m, pivotFraction: pf, isRunning: r, isPaused: p } = sim.current;
    const W = canvas.width, H = canvas.height;

    // Pivot at fraction pf along rod from top
    const d = L * (0.5 - pf) + L * pf; // distance from pivot to CoM
    const dFromTop = pf * L; // pivot position from top of rod
    const dToCoM = L / 2 - dFromTop; // pivot to CoM (positive = CoM below pivot)
    const d_actual = Math.abs(dToCoM) < 0.001 ? 0.001 : Math.abs(dToCoM);
    // I about pivot = mL²/12 + m*d²
    const I_cm = m * L * L / 12;
    const I_pivot = I_cm + m * d_actual * d_actual;
    const T_phys = physicalPendulumPeriod(I_pivot, m, d_actual);
    const T_simple = pendulumPeriod(L);
    const omega_phys = 2 * Math.PI / T_phys;

    if (r && !p) tRef.current += 0.016;

    const A_rad = 0.25; // fixed amplitude
    const theta = A_rad * Math.cos(omega_phys * tRef.current);

    const pivotX = W / 2, pivotY = 60;
    const scale = Math.min((H - 100) / L, 180);

    ctx.clearRect(0, 0, W, H);
    ctx.fillStyle = '#f8fafc'; ctx.fillRect(0, 0, W, H);

    // Ceiling
    ctx.fillStyle = '#64748b'; ctx.fillRect(pivotX - 30, 0, 60, 12);

    // Rod (rotated)
    const rodTopX = pivotX - Math.sin(theta) * dFromTop * scale;
    const rodTopY = pivotY - Math.cos(theta) * dFromTop * scale;
    const rodBotX = pivotX + Math.sin(theta) * (L - dFromTop) * scale;
    const rodBotY = pivotY + Math.cos(theta) * (L - dFromTop) * scale;

    ctx.save();
    // Rod body
    ctx.strokeStyle = '#4f46e5'; ctx.lineWidth = 12;
    ctx.lineCap = 'round';
    ctx.beginPath(); ctx.moveTo(rodTopX, rodTopY); ctx.lineTo(rodBotX, rodBotY); ctx.stroke();
    // CoM dot
    const comX = pivotX + Math.sin(theta) * dToCoM * scale;
    const comY = pivotY + Math.cos(theta) * dToCoM * scale;
    ctx.fillStyle = '#f59e0b';
    ctx.beginPath(); ctx.arc(comX, comY, 5, 0, Math.PI * 2); ctx.fill();
    // Pivot point
    ctx.fillStyle = '#ef4444';
    ctx.beginPath(); ctx.arc(pivotX, pivotY, 6, 0, Math.PI * 2); ctx.fill();
    ctx.fillStyle = 'white';
    ctx.beginPath(); ctx.arc(pivotX, pivotY, 3, 0, Math.PI * 2); ctx.fill();
    ctx.restore();

    // Equilibrium line
    ctx.setLineDash([4, 4]);
    ctx.beginPath(); ctx.moveTo(pivotX, pivotY - 10); ctx.lineTo(pivotX, H - 20);
    ctx.strokeStyle = 'rgba(148,163,184,0.4)'; ctx.lineWidth = 1; ctx.stroke();
    ctx.setLineDash([]);

    // Legend
    ctx.fillStyle = '#f59e0b'; ctx.font = '9px system-ui'; ctx.textAlign = 'left';
    ctx.fillText('● Centre of mass', 8, H - 36);
    ctx.fillStyle = '#ef4444'; ctx.fillText('● Pivot point', 8, H - 24);
    ctx.fillStyle = '#64748b';
    ctx.fillText(`T_physical=${T_phys.toFixed(3)}s  T_simple=${T_simple.toFixed(3)}s`, 8, H - 8);

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
