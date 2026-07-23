'use client';
import { useRef, useEffect, useCallback } from 'react';
import { malusIntensity } from '@/lib/physics/polarization';

export type PolarizationMode = 'single' | 'malus';

interface Props {
  mode: PolarizationMode;
  polarizerAngle: number;  // single mode: transmission axis, degrees from vertical
  analyzerAngle: number;   // malus mode: angle of the 2nd polarizer relative to the 1st
  isRunning: boolean; isPaused: boolean;
  width?: number; height?: number;
}

// Draws a short "vibration" tick oscillating perpendicular to the beam at
// the given angle (0° = vertical), amplitude modulated over time.
function vibrationTick(ctx: CanvasRenderingContext2D, x: number, y: number, angleDeg: number, amp: number, color: string) {
  const rad = (angleDeg * Math.PI) / 180;
  const dx = Math.sin(rad) * amp, dy = -Math.cos(rad) * amp;
  ctx.strokeStyle = color; ctx.lineWidth = 1.6;
  ctx.beginPath(); ctx.moveTo(x - dx, y - dy); ctx.lineTo(x + dx, y + dy); ctx.stroke();
}

function drawPolarizer(ctx: CanvasRenderingContext2D, x: number, midY: number, halfH: number, axisAngleDeg: number, label: string) {
  ctx.save();
  ctx.strokeStyle = '#334155'; ctx.lineWidth = 2;
  ctx.beginPath(); ctx.moveTo(x, midY - halfH); ctx.lineTo(x, midY + halfH); ctx.stroke();
  // Transmission-axis hatching
  const rad = (axisAngleDeg * Math.PI) / 180;
  const dx = Math.sin(rad) * 7, dy = -Math.cos(rad) * 7;
  ctx.strokeStyle = '#6366f1'; ctx.lineWidth = 1.2;
  for (let y = midY - halfH + 6; y <= midY + halfH - 6; y += 10) {
    ctx.beginPath(); ctx.moveTo(x - dx, y - dy); ctx.lineTo(x + dx, y + dy); ctx.stroke();
  }
  ctx.fillStyle = '#475569'; ctx.font = 'bold 9px system-ui'; ctx.textAlign = 'center';
  ctx.fillText(label, x, midY + halfH + 16);
  ctx.restore();
}

export function PolarizationCanvas({ mode, polarizerAngle, analyzerAngle, isRunning, isPaused, width = 660, height = 260 }: Props) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const rafRef = useRef<number>(0);
  const lastFrameRef = useRef<number | null>(null);
  const t = useRef(0);
  const lastWobble = useRef(1);
  const simRef = useRef({ mode, polarizerAngle, analyzerAngle, isRunning, isPaused });
  simRef.current = { mode, polarizerAngle, analyzerAngle, isRunning, isPaused };

  useEffect(() => { t.current = 0; lastWobble.current = 1; lastFrameRef.current = null; }, [mode, polarizerAngle, analyzerAngle]);

  const draw = useCallback((timestamp?: number) => {
    const canvas = canvasRef.current; if (!canvas) return;
    const ctx = canvas.getContext('2d'); if (!ctx) return;
    const s = simRef.current;
    const W = canvas.width, H = canvas.height;

    const animate = s.isRunning && !s.isPaused;
    if (animate && timestamp !== undefined) {
      if (lastFrameRef.current !== null) {
        t.current += Math.min((timestamp - lastFrameRef.current) / 1000, 0.1);
      }
      lastFrameRef.current = timestamp;
      lastWobble.current = Math.sin(t.current * 6);
    } else {
      lastFrameRef.current = timestamp ?? null;
    }
    // Holds at whatever it last was while paused/stopped, rather than
    // snapping to a different fixed amplitude.
    const wobble = lastWobble.current;

    ctx.clearRect(0, 0, W, H);
    ctx.fillStyle = '#f8fafc'; ctx.fillRect(0, 0, W, H);

    const midY = H / 2;
    const UNPOLARIZED_ANGLES = [0, 22.5, 45, 67.5, 90, 112.5, 135, 157.5];

    if (s.mode === 'single') {
      const polX = W * 0.55;
      ctx.strokeStyle = '#cbd5e1'; ctx.lineWidth = 1;
      ctx.beginPath(); ctx.moveTo(20, midY); ctx.lineTo(W - 20, midY); ctx.stroke();

      // Unpolarized: many vibration directions, before the polarizer
      for (let x = 40; x < polX - 20; x += 26) {
        UNPOLARIZED_ANGLES.forEach(a => vibrationTick(ctx, x, midY, a, 16 * wobble, 'rgba(99,102,241,0.55)'));
      }

      drawPolarizer(ctx, polX, midY, 70, s.polarizerAngle, 'Polarizer');

      // After the polarizer: only the transmission-axis direction survives
      for (let x = polX + 26; x < W - 30; x += 26) {
        vibrationTick(ctx, x, midY, s.polarizerAngle, 16 * wobble, '#10b981');
      }

      ctx.fillStyle = '#334155'; ctx.font = 'bold 11px system-ui'; ctx.textAlign = 'center';
      ctx.fillText('Unpolarized (all directions) → plane-polarized (one direction only)', W / 2, 24);
      ctx.fillStyle = '#64748b'; ctx.font = '10px system-ui'; ctx.textAlign = 'left';
      ctx.fillText(`Transmission axis at ${s.polarizerAngle}° from vertical`, 8, H - 10);
      rafRef.current = requestAnimationFrame(draw);
      return;
    }

    // ── Malus's law: two polarizers ─────────────────────────────────────────
    const p1X = W * 0.34, p2X = W * 0.66;
    const I = malusIntensity(1, s.analyzerAngle);

    ctx.strokeStyle = '#cbd5e1'; ctx.lineWidth = 1;
    ctx.beginPath(); ctx.moveTo(20, midY); ctx.lineTo(W - 20, midY); ctx.stroke();

    for (let x = 30; x < p1X - 20; x += 26) {
      UNPOLARIZED_ANGLES.forEach(a => vibrationTick(ctx, x, midY, a, 15 * wobble, 'rgba(99,102,241,0.5)'));
    }
    drawPolarizer(ctx, p1X, midY, 65, 0, 'Polarizer');
    for (let x = p1X + 24; x < p2X - 20; x += 24) {
      vibrationTick(ctx, x, midY, 0, 15 * wobble, '#6366f1');
    }
    drawPolarizer(ctx, p2X, midY, 65, s.analyzerAngle, 'Analyser');
    // Transmitted amplitude scales with √I (amplitude), brightness with I —
    // both shrink to nothing as the analyser approaches 90° (crossed).
    const ampScale = Math.sqrt(Math.max(I, 0));
    for (let x = p2X + 24; x < W - 24; x += 24) {
      vibrationTick(ctx, x, midY, s.analyzerAngle, 15 * wobble * ampScale, `rgba(16,185,129,${0.3 + I * 0.7})`);
    }

    ctx.fillStyle = '#334155'; ctx.font = 'bold 11px system-ui'; ctx.textAlign = 'center';
    ctx.fillText(
      s.analyzerAngle > 85 && s.analyzerAngle < 95 ? 'Crossed polarizers — no light gets through' : `Malus's law: I = I₀cos²θ = ${(I * 100).toFixed(0)}% of I₀`,
      W / 2, 24,
    );
    ctx.fillStyle = '#64748b'; ctx.font = '10px system-ui'; ctx.textAlign = 'left';
    ctx.fillText(`θ = ${s.analyzerAngle}° between the two transmission axes`, 8, H - 10);

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
