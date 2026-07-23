'use client';
import { useRef, useEffect, useCallback } from 'react';
import { freeFallDistance } from '@/lib/physics/consequences';

interface Props {
  mass: number;      // kg
  gValue: number;     // m/s² — local gravity at the selected altitude
  isRunning: boolean; isPaused: boolean;
  onTick?: (t: number, distance: number) => void;
  width?: number; height?: number;
}

function drawChamber(
  ctx: CanvasRenderingContext2D, x: number, y: number, w: number, h: number,
  fallOffset: number, scaleReading: number, label: string, weightless: boolean,
) {
  // Shaft
  ctx.strokeStyle = '#cbd5e1'; ctx.lineWidth = 1.5;
  ctx.strokeRect(x, y, w, h);
  ctx.fillStyle = '#f8fafc'; ctx.fillRect(x, y, w, h);

  const boxW = w * 0.6, boxH = 60;
  const bx = x + (w - boxW) / 2;
  const by = y + 10 + fallOffset;

  // Cabin
  ctx.fillStyle = weightless ? '#fee2e2' : '#e0e7ff';
  ctx.strokeStyle = weightless ? '#ef4444' : '#6366f1';
  ctx.lineWidth = 2;
  ctx.beginPath(); ctx.roundRect(bx, by, boxW, boxH, 6); ctx.fill(); ctx.stroke();

  // Person: floats mid-cabin if weightless, stands on the scale otherwise
  const px = bx + boxW / 2;
  const py = weightless ? by + boxH / 2 - 6 : by + boxH - 26;
  ctx.fillStyle = '#4f46e5';
  ctx.beginPath(); ctx.ellipse(px, py, 7, 12, 0, 0, Math.PI * 2); ctx.fill();
  ctx.fillStyle = '#f9a8d4';
  ctx.beginPath(); ctx.arc(px, py - 17, 8, 0, Math.PI * 2); ctx.fill();
  // Arms out if floating, at sides if standing
  ctx.strokeStyle = '#4f46e5'; ctx.lineWidth = 2;
  ctx.beginPath();
  if (weightless) {
    ctx.moveTo(px, py - 4); ctx.lineTo(px - 16, py - 12);
    ctx.moveTo(px, py - 4); ctx.lineTo(px + 16, py - 12);
  } else {
    ctx.moveTo(px, py - 4); ctx.lineTo(px - 9, py + 6);
    ctx.moveTo(px, py - 4); ctx.lineTo(px + 9, py + 6);
  }
  ctx.stroke();

  // Scale, fixed to the cabin floor
  const sy = by + boxH - 10;
  ctx.fillStyle = '#1e293b';
  ctx.beginPath(); ctx.roundRect(bx + boxW / 2 - 16, sy, 32, 8, 3); ctx.fill();
  ctx.fillStyle = weightless ? '#ef4444' : '#059669';
  ctx.font = 'bold 9px system-ui'; ctx.textAlign = 'center';
  ctx.fillText(`${scaleReading.toFixed(0)}N`, bx + boxW / 2, sy + 20);

  ctx.fillStyle = '#64748b'; ctx.font = 'bold 10px system-ui';
  ctx.fillText(label, x + w / 2, y - 6);
  if (weightless && fallOffset > 2) {
    ctx.fillStyle = '#ef4444'; ctx.font = 'bold 9px system-ui';
    ctx.fillText('WEIGHTLESS', x + w / 2, by - 4);
  }
}

export function WeightlessnessCanvas({ mass, gValue, isRunning, isPaused, onTick, width = 660, height = 260 }: Props) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const rafRef = useRef<number>(0);
  const lastFrameRef = useRef<number | null>(null);
  const t = useRef(0);
  const landed = useRef(false);
  const simRef = useRef({ mass, gValue, isRunning, isPaused, onTick });
  simRef.current = { mass, gValue, isRunning, isPaused, onTick };

  useEffect(() => { t.current = 0; landed.current = false; lastFrameRef.current = null; }, [mass, gValue]);

  const draw = useCallback((timestamp?: number) => {
    const canvas = canvasRef.current; if (!canvas) return;
    const ctx = canvas.getContext('2d'); if (!ctx) return;
    const { mass: m, gValue: gv, isRunning: r, isPaused: pa, onTick: ot } = simRef.current;
    const W = canvas.width, H = canvas.height;

    if (r && !pa && !landed.current && timestamp !== undefined) {
      if (lastFrameRef.current !== null) {
        t.current += Math.min((timestamp - lastFrameRef.current) / 1000, 0.1);
      }
      lastFrameRef.current = timestamp;
    } else {
      lastFrameRef.current = timestamp ?? null;
    }

    const chamberH = H - 30;
    const maxDropPx = chamberH - 80;
    const dropDistanceM = freeFallDistance(t.current, gv);
    // Visual pixel scale chosen so a representative drop (Earth g, ~2s) just
    // about reaches the bottom of the shaft — purely for legibility, not a
    // literal 1:1 metre mapping.
    const pxPerMetre = maxDropPx / Math.max(freeFallDistance(2.2, 9.81), 1);
    const fallOffset = Math.min(dropDistanceM * pxPerMetre, maxDropPx);
    if (fallOffset >= maxDropPx && !landed.current) landed.current = true;

    ot?.(t.current, dropDistanceM);

    ctx.clearRect(0, 0, W, H);
    ctx.fillStyle = '#ffffff'; ctx.fillRect(0, 0, W, H);

    const gap = 16;
    const chamberW = (W - gap * 3) / 2;

    // Left: stationary reference — always shows true weight.
    drawChamber(ctx, gap, 24, chamberW, chamberH, 0, m * 9.81, 'Stationary (on Earth)', false);

    // Right: free-falling — reads 0N the instant it starts moving, by
    // definition of free fall, regardless of how large gv is.
    const falling = t.current > 0;
    drawChamber(ctx, gap * 2 + chamberW, 24, chamberW, chamberH, fallOffset, falling ? 0 : m * 9.81,
      landed.current ? 'Landed' : 'Free falling', falling && !landed.current);

    // Context readout
    ctx.fillStyle = '#475569'; ctx.font = '10px system-ui'; ctx.textAlign = 'left';
    ctx.fillText(`g at this altitude = ${gv.toFixed(2)} m/s²  (${(gv / 9.81 * 100).toFixed(0)}% of Earth surface)`, 10, H - 6);
    ctx.textAlign = 'right';
    ctx.fillText(`fallen ${dropDistanceM.toFixed(1)} m in ${t.current.toFixed(1)}s`, W - 10, H - 6);

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
