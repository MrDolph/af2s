'use client';
import { useRef, useEffect, useCallback } from 'react';
import { conicalPendulumOmega, conicalPendulumRadius, conicalPendulumTension } from '@/lib/physics/shm';

interface Props {
  length: number; theta_deg: number; mass: number;
  isRunning: boolean; isPaused: boolean;
  width?: number; height?: number;
}

export function ConicalPendulumCanvas({ length, theta_deg, mass, isRunning, isPaused, width = 380, height = 320 }: Props) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const rafRef = useRef<number>(0);
  const phiRef = useRef(0);
  const sim = useRef({ length, theta_deg, mass, isRunning, isPaused });
  sim.current = { length, theta_deg, mass, isRunning, isPaused };

  const draw = useCallback(() => {
    const canvas = canvasRef.current; if (!canvas) return;
    const ctx = canvas.getContext('2d'); if (!ctx) return;
    const { length: L, theta_deg: th, mass: m, isRunning: r, isPaused: p } = sim.current;
    const W = canvas.width, H = canvas.height;
    const theta = th * Math.PI / 180;
    const omega = conicalPendulumOmega(L, theta);
    const r_circ = conicalPendulumRadius(L, theta);
    const T = conicalPendulumTension(m, theta);

    if (r && !p) phiRef.current += omega * 0.016;

    const cx = W / 2, cy = 50;
    const scale = Math.min((H - 100) / L, 200);
    const vertLen = L * Math.cos(theta) * scale;
    const bobX = cx + r_circ * scale * Math.cos(phiRef.current);
    const bobY = cy + vertLen;

    ctx.clearRect(0, 0, W, H);
    ctx.fillStyle = '#f8fafc'; ctx.fillRect(0, 0, W, H);

    // Ceiling
    ctx.fillStyle = '#64748b'; ctx.fillRect(cx - 35, 0, 70, 12);
    ctx.fillStyle = '#94a3b8'; ctx.beginPath(); ctx.arc(cx, 12, 5, 0, Math.PI * 2); ctx.fill();

    // Orbit circle (ellipse for perspective)
    ctx.save();
    ctx.strokeStyle = 'rgba(99,102,241,0.2)'; ctx.lineWidth = 1; ctx.setLineDash([4, 4]);
    ctx.beginPath();
    ctx.ellipse(cx, bobY, r_circ * scale, r_circ * scale * 0.25, 0, 0, Math.PI * 2);
    ctx.stroke(); ctx.setLineDash([]); ctx.restore();

    // Shadow on orbit
    const shadowX = cx + r_circ * scale * Math.cos(phiRef.current);
    ctx.beginPath(); ctx.ellipse(shadowX, bobY + 4, 10, 4, 0, 0, Math.PI * 2);
    ctx.fillStyle = 'rgba(0,0,0,0.08)'; ctx.fill();

    // String
    ctx.beginPath(); ctx.moveTo(cx, 12); ctx.lineTo(bobX, bobY);
    ctx.strokeStyle = '#64748b'; ctx.lineWidth = 1.5; ctx.stroke();

    // Vertical dashed line
    ctx.setLineDash([4, 4]);
    ctx.beginPath(); ctx.moveTo(cx, 12); ctx.lineTo(cx, bobY + 20);
    ctx.strokeStyle = 'rgba(148,163,184,0.5)'; ctx.lineWidth = 1; ctx.stroke();
    ctx.setLineDash([]);

    // Angle arc
    ctx.beginPath();
    ctx.arc(cx, 12, 28, Math.PI / 2, Math.PI / 2 + theta);
    ctx.strokeStyle = '#f59e0b'; ctx.lineWidth = 1.5; ctx.stroke();
    ctx.fillStyle = '#f59e0b'; ctx.font = '10px system-ui'; ctx.textAlign = 'left';
    ctx.fillText(`θ=${th}°`, cx + 6, 12 + 38);

    // Bob
    const bobG = ctx.createRadialGradient(bobX - 2, bobY - 2, 1, bobX, bobY, 12);
    bobG.addColorStop(0, '#818cf8'); bobG.addColorStop(1, '#4f46e5');
    ctx.beginPath(); ctx.arc(bobX, bobY, 12, 0, Math.PI * 2);
    ctx.fillStyle = bobG; ctx.fill();
    ctx.strokeStyle = '#3730a3'; ctx.lineWidth = 1; ctx.stroke();

    // Force vectors (from bob)
    // Tension component (along string, upward-inward)
    const Tscale = Math.min(T * 8, 55);
    const Tx = cx - bobX; const Ty = cy + 12 - bobY;
    const Tmag = Math.sqrt(Tx * Tx + Ty * Ty);
    ctx.save();
    ctx.strokeStyle = '#10b981'; ctx.lineWidth = 2;
    ctx.beginPath(); ctx.moveTo(bobX, bobY);
    ctx.lineTo(bobX + Tx / Tmag * Tscale, bobY + Ty / Tmag * Tscale); ctx.stroke();
    ctx.fillStyle = '#10b981'; ctx.font = '9px system-ui'; ctx.textAlign = 'center';
    ctx.fillText(`T=${T.toFixed(1)}N`, bobX + Tx / Tmag * Tscale * 0.6, bobY + Ty / Tmag * Tscale * 0.6 - 6);
    ctx.restore();

    // Weight (downward)
    const W_n = m * 9.81;
    const Wscale = Math.min(W_n * 8, 45);
    ctx.save();
    ctx.strokeStyle = '#ef4444'; ctx.lineWidth = 2;
    ctx.beginPath(); ctx.moveTo(bobX, bobY); ctx.lineTo(bobX, bobY + Wscale); ctx.stroke();
    ctx.fillStyle = '#ef4444';
    ctx.beginPath(); ctx.moveTo(bobX, bobY + Wscale);
    ctx.lineTo(bobX - 4, bobY + Wscale - 7); ctx.lineTo(bobX + 4, bobY + Wscale - 7);
    ctx.closePath(); ctx.fill();
    ctx.font = '9px system-ui'; ctx.textAlign = 'left';
    ctx.fillText(`mg=${W_n.toFixed(1)}N`, bobX + 6, bobY + Wscale / 2);
    ctx.restore();

    // Info
    ctx.fillStyle = '#64748b'; ctx.font = '10px system-ui'; ctx.textAlign = 'center';
    ctx.fillText(`r=${r_circ.toFixed(2)}m  T_period=${(2*Math.PI/omega).toFixed(2)}s`, cx, H - 8);

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
