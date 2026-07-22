'use client';
import { useRef, useEffect, useCallback } from 'react';
import { deBroglieLambda, formatLambda } from '@/lib/physics/debroglie';

interface Props {
  mass: number;         // kg
  velocity: number;     // m/s
  particleName: string;
  isRunning: boolean; isPaused: boolean;
  width?: number; height?: number;
}

// The real wavelengths span ~30 orders of magnitude, so the on-screen
// wavelength is a LOG mapping of the true λ — the number shown is exact,
// the picture just keeps everything visible.
function screenLambda(lambda: number): number {
  if (!isFinite(lambda)) return 400;
  const logL = Math.log10(lambda); // e.g. −10 for 0.1nm, −34 for a ball
  // Map log10(λ) ∈ [−36, −6] → [14, 220] px
  const t = Math.min(1, Math.max(0, (logL + 36) / 30));
  return 14 + t * 206;
}

export function DeBroglieCanvas({ mass, velocity, particleName, isRunning, isPaused, width = 640, height = 280 }: Props) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const rafRef = useRef<number>(0);
  const tRef = useRef(0);
  const lastFrameRef = useRef<number | null>(null);
  const sim = useRef({ mass, velocity, particleName, isRunning, isPaused });
  sim.current = { mass, velocity, particleName, isRunning, isPaused };

  useEffect(() => { tRef.current = 0; lastFrameRef.current = null; }, [mass, velocity]);

  const draw = useCallback((timestamp?: number) => {
    const canvas = canvasRef.current; if (!canvas) return;
    const ctx = canvas.getContext('2d'); if (!ctx) return;
    const s = sim.current;
    const W = canvas.width, H = canvas.height;

    if (s.isRunning && !s.isPaused && timestamp !== undefined) {
      if (lastFrameRef.current !== null) {
        tRef.current += Math.min((timestamp - lastFrameRef.current) / 1000, 0.1);
      }
      lastFrameRef.current = timestamp;
    } else {
      lastFrameRef.current = timestamp ?? null;
    }
    const t = tRef.current;

    const lambda = deBroglieLambda(s.mass, s.velocity);
    const sl = screenLambda(lambda);
    const midY = H / 2;
    const px = ((t * 90) % (W + 120)) - 60; // particle drifts across, wraps

    ctx.clearRect(0, 0, W, H);
    ctx.fillStyle = '#f8fafc'; ctx.fillRect(0, 0, W, H);

    // Direction of travel
    ctx.strokeStyle = '#e2e8f0'; ctx.setLineDash([4, 4]);
    ctx.beginPath(); ctx.moveTo(0, midY); ctx.lineTo(W, midY); ctx.stroke();
    ctx.setLineDash([]);

    // Matter wave: a wave packet centred on the particle
    ctx.save();
    ctx.strokeStyle = '#6366f1'; ctx.lineWidth = 2;
    ctx.beginPath();
    const k = (2 * Math.PI) / sl;
    for (let x = 0; x <= W; x += 2) {
      const envelope = Math.exp(-((x - px) ** 2) / (2 * (sl * 2.2) ** 2)); // packet
      const y = midY - Math.sin(k * (x - px)) * 44 * envelope;
      if (x === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
    }
    ctx.stroke();
    ctx.restore();

    // Particle
    ctx.save();
    const r = Math.max(6, Math.min(16, 6 + Math.log10(s.mass / 9.109e-31)));
    const grad = ctx.createRadialGradient(px - 2, midY - 2, 1, px, midY, r);
    grad.addColorStop(0, '#a5b4fc'); grad.addColorStop(1, '#4f46e5');
    ctx.beginPath(); ctx.arc(px, midY, r, 0, Math.PI * 2);
    ctx.fillStyle = grad; ctx.fill();
    ctx.restore();

    // λ bracket (only meaningful when packet fits nicely)
    if (sl < W / 2) {
      const bx = px + sl * 0.75, by = midY + 58;
      if (bx > 0 && bx + sl < W) {
        ctx.save();
        ctx.strokeStyle = '#10b981'; ctx.lineWidth = 1.5;
        ctx.beginPath(); ctx.moveTo(bx, by); ctx.lineTo(bx + sl, by); ctx.stroke();
        [bx, bx + sl].forEach(x => {
          ctx.beginPath(); ctx.moveTo(x, by - 4); ctx.lineTo(x, by + 4); ctx.stroke();
        });
        ctx.fillStyle = '#059669'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
        ctx.fillText(`λ = ${formatLambda(lambda)}`, bx + sl / 2, by + 14);
        ctx.restore();
      }
    }

    // Caption
    ctx.fillStyle = '#334155'; ctx.font = 'bold 11px system-ui'; ctx.textAlign = 'center';
    ctx.fillText(`${s.particleName}:  λ = h/mv = ${formatLambda(lambda)}`, W / 2, 24);
    ctx.fillStyle = '#94a3b8'; ctx.font = '9px system-ui';
    ctx.fillText('(wave drawn on a log scale so it stays visible — the value shown is exact)', W / 2, 38);

    ctx.fillStyle = '#64748b'; ctx.font = '10px system-ui'; ctx.textAlign = 'left';
    ctx.fillText(`m = ${s.mass.toExponential(2)} kg   v = ${s.velocity.toExponential(2)} m/s   p = mv = ${(s.mass * s.velocity).toExponential(2)} kg·m/s`, 8, H - 10);

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
