'use client';
import { useRef, useEffect, useCallback } from 'react';
import { angularFreq, waveNumber, travellingY, superposedY, standingY, standingNodes } from '@/lib/physics/waves';

export type WaveMode = 'transverse' | 'longitudinal' | 'superposition' | 'standing';

interface Props {
  mode: WaveMode;
  amplitude: number;    // m (display metres)
  frequency: number;    // Hz
  wavelength: number;   // m
  // superposition second wave:
  amplitude2?: number;
  frequency2?: number;
  phase2?: number;      // degrees
  isRunning: boolean; isPaused: boolean;
  onTick?: (t: number) => void;
  width?: number; height?: number;
}

const DOMAIN = 8; // metres of string shown

export function WaveCanvas({
  mode, amplitude, frequency, wavelength,
  amplitude2 = 0.5, frequency2 = 1, phase2 = 0,
  isRunning, isPaused, onTick, width = 660, height = 300,
}: Props) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const rafRef = useRef<number>(0);
  const tRef = useRef(0);
  const lastFrameRef = useRef<number | null>(null);
  const sim = useRef({ mode, amplitude, frequency, wavelength, amplitude2, frequency2, phase2, isRunning, isPaused, onTick });
  sim.current = { mode, amplitude, frequency, wavelength, amplitude2, frequency2, phase2, isRunning, isPaused, onTick };

  useEffect(() => { tRef.current = 0; lastFrameRef.current = null; }, [mode, amplitude, frequency, wavelength, amplitude2, frequency2, phase2]);

  const draw = useCallback((timestamp?: number) => {
    const canvas = canvasRef.current; if (!canvas) return;
    const ctx = canvas.getContext('2d'); if (!ctx) return;
    const s = sim.current;
    const W = canvas.width, H = canvas.height;

    // Real wall-clock dt — one on-screen period equals the true T = 1/f
    // at any refresh rate.
    if (s.isRunning && !s.isPaused && timestamp !== undefined) {
      if (lastFrameRef.current !== null) {
        tRef.current += Math.min((timestamp - lastFrameRef.current) / 1000, 0.1);
      }
      lastFrameRef.current = timestamp;
    } else {
      lastFrameRef.current = timestamp ?? null;
    }
    const t = tRef.current;
    s.onTick?.(t);

    const omega = angularFreq(s.frequency);
    const k = waveNumber(s.wavelength);
    const midY = H / 2 - 10;
    const xScale = W / DOMAIN;
    const yScale = Math.min(70, (H / 2 - 40) / Math.max(s.amplitude + (s.mode === 'superposition' ? s.amplitude2 : 0), s.mode === 'standing' ? 2 * s.amplitude : s.amplitude));

    ctx.clearRect(0, 0, W, H);
    ctx.fillStyle = '#f8fafc'; ctx.fillRect(0, 0, W, H);

    // Equilibrium line
    ctx.strokeStyle = '#e2e8f0'; ctx.lineWidth = 1; ctx.setLineDash([4, 4]);
    ctx.beginPath(); ctx.moveTo(0, midY); ctx.lineTo(W, midY); ctx.stroke();
    ctx.setLineDash([]);

    if (s.mode === 'longitudinal') {
      // Columns of particles displaced ALONG x — compressions & rarefactions.
      const cols = 60, rowsN = 7;
      for (let c = 0; c < cols; c++) {
        const x0 = (c / cols) * DOMAIN;
        const dx = travellingY(s.amplitude * 0.35, k, omega, x0, t); // longitudinal displacement
        const px = (x0 + dx) * xScale;
        for (let r = 0; r < rowsN; r++) {
          const py = midY - 48 + r * 16;
          ctx.beginPath(); ctx.arc(px, py, 2.4, 0, Math.PI * 2);
          ctx.fillStyle = '#6366f1'; ctx.fill();
        }
      }
      // Label a compression: where displacement gradient is most negative
      ctx.fillStyle = '#64748b'; ctx.font = '10px system-ui'; ctx.textAlign = 'left';
      ctx.fillText('compressions ↔ rarefactions travel at v = fλ', 8, H - 26);
    } else {
      // Curve(s)
      const plot = (fn: (x: number) => number, color: string, lw = 2, dash: number[] = []) => {
        ctx.save();
        ctx.strokeStyle = color; ctx.lineWidth = lw; ctx.setLineDash(dash);
        ctx.beginPath();
        for (let px = 0; px <= W; px += 2) {
          const x = px / xScale;
          const y = midY - fn(x) * yScale;
          if (px === 0) ctx.moveTo(px, y); else ctx.lineTo(px, y);
        }
        ctx.stroke(); ctx.restore();
      };

      if (s.mode === 'transverse') {
        plot(x => travellingY(s.amplitude, k, omega, x, t), '#6366f1', 2.5);
        // Marked particle at x = 2m — shows a particle moves only UP/DOWN
        // while the wave PATTERN moves right.
        const xp = 2;
        const yp = midY - travellingY(s.amplitude, k, omega, xp, t) * yScale;
        ctx.beginPath(); ctx.arc(xp * xScale, yp, 6, 0, Math.PI * 2);
        ctx.fillStyle = '#ef4444'; ctx.fill();
        ctx.strokeStyle = '#fff'; ctx.lineWidth = 2; ctx.stroke();
        ctx.setLineDash([3, 3]); ctx.strokeStyle = 'rgba(239,68,68,0.4)'; ctx.lineWidth = 1;
        ctx.beginPath(); ctx.moveTo(xp * xScale, midY - s.amplitude * yScale); ctx.lineTo(xp * xScale, midY + s.amplitude * yScale); ctx.stroke();
        ctx.setLineDash([]);
        // Wavelength bracket
        ctx.strokeStyle = '#10b981'; ctx.lineWidth = 1.5;
        const bx = 0.5 * xScale, bw = s.wavelength * xScale, by = midY + s.amplitude * yScale + 14;
        ctx.beginPath(); ctx.moveTo(bx, by); ctx.lineTo(bx + bw, by); ctx.stroke();
        ctx.beginPath(); ctx.moveTo(bx, by - 4); ctx.lineTo(bx, by + 4); ctx.stroke();
        ctx.beginPath(); ctx.moveTo(bx + bw, by - 4); ctx.lineTo(bx + bw, by + 4); ctx.stroke();
        ctx.fillStyle = '#059669'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
        ctx.fillText(`λ = ${s.wavelength}m`, bx + bw / 2, by + 14);
      }

      if (s.mode === 'superposition') {
        const omega2 = angularFreq(s.frequency2);
        const k2 = waveNumber(s.wavelength); // same medium ⇒ same v; λ2 = v/f2
        const v = s.frequency * s.wavelength;
        const lambda2 = s.frequency2 > 0 ? v / s.frequency2 : s.wavelength;
        const k2b = waveNumber(lambda2);
        const phi2 = s.phase2 * Math.PI / 180;
        plot(x => travellingY(s.amplitude, k, omega, x, t), 'rgba(99,102,241,0.45)', 1.5, [5, 4]);
        plot(x => travellingY(s.amplitude2, k2b, omega2, x, t, phi2), 'rgba(16,185,129,0.45)', 1.5, [5, 4]);
        plot(x => superposedY(s.amplitude, s.amplitude2, k, k2b, omega, omega2, x, t, phi2), '#ef4444', 2.5);
        void k2;
        ctx.fillStyle = '#64748b'; ctx.font = '10px system-ui'; ctx.textAlign = 'left';
        ctx.fillText('— resultant = y₁ + y₂ (principle of superposition)', 8, H - 26);
      }

      if (s.mode === 'standing') {
        plot(x => standingY(s.amplitude, k, omega, x, t), '#6366f1', 2.5);
        // Envelope
        plot(x => 2 * s.amplitude * Math.sin(k * x), 'rgba(99,102,241,0.2)', 1, [4, 4]);
        plot(x => -2 * s.amplitude * Math.sin(k * x), 'rgba(99,102,241,0.2)', 1, [4, 4]);
        // Nodes
        standingNodes(s.wavelength, DOMAIN).forEach(x => {
          ctx.beginPath(); ctx.arc(x * xScale, midY, 4, 0, Math.PI * 2);
          ctx.fillStyle = '#ef4444'; ctx.fill();
        });
        ctx.fillStyle = '#ef4444'; ctx.font = '10px system-ui'; ctx.textAlign = 'left';
        ctx.fillText('● nodes every λ/2 — no energy is transported', 8, H - 26);
      }
    }

    // HUD
    const v = s.frequency * s.wavelength;
    ctx.fillStyle = '#64748b'; ctx.font = '10px system-ui'; ctx.textAlign = 'left';
    ctx.fillText(`v = fλ = ${s.frequency}×${s.wavelength} = ${v.toFixed(2)} m/s   T = ${(1 / s.frequency).toFixed(2)}s   t = ${t.toFixed(1)}s`, 8, H - 10);

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
