'use client';
import { useRef, useEffect, useCallback } from 'react';
import { pendulumOmega, pendulumAngle } from '@/lib/physics/shm';

interface Props {
  length: number; amplitude: number; gravity: number; mass: number;
  isRunning: boolean; isPaused: boolean;
  onTick?: (t: number, x: number, v: number) => void;
  width?: number; height?: number;
}

export function PendulumCanvas({ length, amplitude, gravity, mass, isRunning, isPaused, onTick, width = 380, height = 320 }: Props) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const rafRef = useRef<number>(0);
  const tRef = useRef(0);
  const lastFrameRef = useRef<number | null>(null);
  const trailRef = useRef<[number, number][]>([]);
  const sim = useRef({ length, amplitude, gravity, mass, isRunning, isPaused, onTick });
  sim.current = { length, amplitude, gravity, mass, isRunning, isPaused, onTick };

  useEffect(() => { tRef.current = 0; lastFrameRef.current = null; trailRef.current = []; }, [length, amplitude, gravity, mass]);

  const draw = useCallback((timestamp?: number) => {
    const canvas = canvasRef.current; if (!canvas) return;
    const ctx = canvas.getContext('2d'); if (!ctx) return;
    const { length: L, amplitude: A_deg, gravity: grav, mass: m, isRunning: r, isPaused: p, onTick: ot } = sim.current;
    const W = canvas.width, H = canvas.height;
    const A_rad = A_deg * Math.PI / 180;
    const omega = pendulumOmega(L, grav);

    // Advance simulation time by REAL elapsed wall-clock time, not a fixed
    // per-frame step. A fixed += 0.016 assumes 60fps: on 120Hz screens the
    // animation ran 2× fast, which is why the canvas drifted out of sync
    // with the graph (whose time axis is in true seconds).
    if (r && !p && timestamp !== undefined) {
      if (lastFrameRef.current !== null) {
        tRef.current += Math.min((timestamp - lastFrameRef.current) / 1000, 0.1);
      }
      lastFrameRef.current = timestamp;
    } else {
      lastFrameRef.current = timestamp ?? null;
    }

    const theta = pendulumAngle(A_rad, omega, tRef.current);
    const pivotX = W / 2, pivotY = 40;
    const scale = Math.min((H - 80) / L, 280);
    const bobX = pivotX + Math.sin(theta) * L * scale;
    const bobY = pivotY + Math.cos(theta) * L * scale;
    const v = -A_rad * omega * Math.sin(omega * tRef.current);
    ot?.(tRef.current, theta, v);

    // Trail
    trailRef.current.push([bobX, bobY]);
    if (trailRef.current.length > 80) trailRef.current.shift();

    ctx.clearRect(0, 0, W, H);

    // Background
    ctx.fillStyle = '#f8fafc'; ctx.fillRect(0, 0, W, H);

    // Ceiling mount
    ctx.fillStyle = '#64748b'; ctx.fillRect(pivotX - 30, 0, 60, 12);
    ctx.fillStyle = '#94a3b8';
    ctx.beginPath(); ctx.arc(pivotX, 12, 6, 0, Math.PI * 2); ctx.fill();

    // Trail
    if (trailRef.current.length > 1) {
      ctx.save();
      for (let i = 1; i < trailRef.current.length; i++) {
        const alpha = i / trailRef.current.length;
        ctx.beginPath();
        ctx.moveTo(trailRef.current[i-1][0], trailRef.current[i-1][1]);
        ctx.lineTo(trailRef.current[i][0], trailRef.current[i][1]);
        ctx.strokeStyle = `rgba(99,102,241,${alpha * 0.5})`;
        ctx.lineWidth = 1.5; ctx.stroke();
      }
      ctx.restore();
    }

    // String
    ctx.beginPath(); ctx.moveTo(pivotX, 12); ctx.lineTo(bobX, bobY);
    ctx.strokeStyle = '#64748b'; ctx.lineWidth = 1.5; ctx.stroke();

    // Bob shadow
    ctx.beginPath(); ctx.ellipse(bobX + 3, bobY + 3, 14, 5, 0, 0, Math.PI * 2);
    ctx.fillStyle = 'rgba(0,0,0,0.08)'; ctx.fill();

    // Bob
    const bobR = Math.max(8, Math.min(m * 3, 18));
    const bobG = ctx.createRadialGradient(bobX - 3, bobY - 3, 1, bobX, bobY, bobR);
    bobG.addColorStop(0, '#818cf8'); bobG.addColorStop(1, '#4f46e5');
    ctx.beginPath(); ctx.arc(bobX, bobY, bobR, 0, Math.PI * 2);
    ctx.fillStyle = bobG; ctx.fill();
    ctx.strokeStyle = '#3730a3'; ctx.lineWidth = 1; ctx.stroke();

    // Velocity arrow
    if (Math.abs(v) > 0.01) {
      const vScale = Math.min(Math.abs(v) * 30, 50);
      const vx = Math.cos(theta) * Math.sign(v) * vScale;
      const vy = -Math.sin(theta) * Math.sign(v) * vScale;
      ctx.save();
      ctx.strokeStyle = '#f59e0b'; ctx.lineWidth = 2;
      ctx.beginPath(); ctx.moveTo(bobX, bobY); ctx.lineTo(bobX + vx, bobY + vy); ctx.stroke();
      ctx.fillStyle = '#f59e0b';
      const angle = Math.atan2(vy, vx);
      ctx.beginPath(); ctx.moveTo(bobX + vx, bobY + vy);
      ctx.lineTo(bobX + vx - 7 * Math.cos(angle - 0.4), bobY + vy - 7 * Math.sin(angle - 0.4));
      ctx.lineTo(bobX + vx - 7 * Math.cos(angle + 0.4), bobY + vy - 7 * Math.sin(angle + 0.4));
      ctx.closePath(); ctx.fill();
      ctx.restore();
    }

    // Equilibrium line
    ctx.setLineDash([4, 4]);
    ctx.beginPath(); ctx.moveTo(pivotX, 12); ctx.lineTo(pivotX, pivotY + L * scale);
    ctx.strokeStyle = 'rgba(148,163,184,0.5)'; ctx.lineWidth = 1; ctx.stroke();
    ctx.setLineDash([]);

    // Labels
    ctx.fillStyle = '#64748b'; ctx.font = '10px system-ui'; ctx.textAlign = 'left';
    ctx.fillText(`L=${L}m  A=${A_deg}°  T=${(2*Math.PI/omega).toFixed(2)}s`, 8, H - 8);
    ctx.fillText(`θ=${(theta * 180 / Math.PI).toFixed(1)}°`, 8, H - 22);

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
