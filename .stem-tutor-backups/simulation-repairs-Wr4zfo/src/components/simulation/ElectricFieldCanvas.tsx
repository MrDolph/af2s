'use client';
import { useRef, useEffect, useCallback } from 'react';

export type FieldConfiguration = 'single-positive' | 'single-negative' | 'dipole' | 'like-charges';

interface Props {
  configuration: FieldConfiguration;
  testX: number; testY: number; // 0..1 fractional canvas position of the movable test point
  isRunning: boolean; isPaused: boolean;
  onTick?: (fieldStrengthRelative: number) => void;
  width?: number; height?: number;
}

interface Vec { x: number; y: number; }
interface Charge extends Vec { q: number; } // q sign only matters; magnitude is normalised for the line-tracer

function fieldAt(p: Vec, charges: Charge[]): Vec {
  let ex = 0, ey = 0;
  for (const c of charges) {
    const dx = p.x - c.x, dy = p.y - c.y;
    const r2 = dx * dx + dy * dy;
    if (r2 < 4) continue;
    const r = Math.sqrt(r2);
    const mag = c.q / r2;
    ex += mag * (dx / r);
    ey += mag * (dy / r);
  }
  return { x: ex, y: ey };
}

function traceFieldLine(start: Vec, charges: Charge[], W: number, H: number): Vec[] {
  const points: Vec[] = [start];
  let p = { ...start };
  const stepSize = 5;
  for (let i = 0; i < 400; i++) {
    const e = fieldAt(p, charges);
    const emag = Math.hypot(e.x, e.y);
    if (emag < 1e-9) break;
    p = { x: p.x + (e.x / emag) * stepSize, y: p.y + (e.y / emag) * stepSize };
    points.push(p);
    if (p.x < -20 || p.x > W + 20 || p.y < -20 || p.y > H + 20) break;
    // Terminate once close to any charge (its own start charge, or a
    // nearby opposite one the line has flowed into).
    if (charges.some(c => Math.hypot(p.x - c.x, p.y - c.y) < 16)) break;
  }
  return points;
}

function getCharges(config: FieldConfiguration, W: number, H: number): Charge[] {
  const midY = H / 2;
  switch (config) {
    case 'single-positive': return [{ x: W / 2, y: midY, q: 1 }];
    case 'single-negative': return [{ x: W / 2, y: midY, q: -1 }];
    case 'dipole': return [{ x: W / 2 - 80, y: midY, q: 1 }, { x: W / 2 + 80, y: midY, q: -1 }];
    case 'like-charges': return [{ x: W / 2 - 80, y: midY, q: 1 }, { x: W / 2 + 80, y: midY, q: 1 }];
  }
}

function drawCharge(ctx: CanvasRenderingContext2D, c: Charge) {
  const r = 16;
  ctx.fillStyle = c.q > 0 ? '#dc2626' : '#2563eb';
  ctx.beginPath(); ctx.arc(c.x, c.y, r, 0, Math.PI * 2); ctx.fill();
  ctx.strokeStyle = 'white'; ctx.lineWidth = 2;
  ctx.beginPath(); ctx.moveTo(c.x - r * 0.5, c.y); ctx.lineTo(c.x + r * 0.5, c.y); ctx.stroke();
  if (c.q > 0) { ctx.beginPath(); ctx.moveTo(c.x, c.y - r * 0.5); ctx.lineTo(c.x, c.y + r * 0.5); ctx.stroke(); }
}

export function ElectricFieldCanvas({ configuration, testX, testY, isRunning, isPaused, onTick, width = 660, height = 320 }: Props) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const rafRef = useRef<number>(0);
  const lastFrameRef = useRef<number | null>(null);
  const t = useRef(0);
  const sim = useRef({ configuration, testX, testY, isRunning, isPaused, onTick });
  sim.current = { configuration, testX, testY, isRunning, isPaused, onTick };

  useEffect(() => { t.current = 0; lastFrameRef.current = null; }, [configuration]);

  const draw = useCallback((timestamp?: number) => {
    const canvas = canvasRef.current; if (!canvas) return;
    const ctx = canvas.getContext('2d'); if (!ctx) return;
    const s = sim.current;
    const W = canvas.width, H = canvas.height;

    if (s.isRunning && !s.isPaused && timestamp !== undefined) {
      if (lastFrameRef.current !== null) t.current += (timestamp - lastFrameRef.current) / 1000;
      lastFrameRef.current = timestamp;
    } else {
      lastFrameRef.current = timestamp ?? null;
    }

    ctx.clearRect(0, 0, W, H);
    ctx.fillStyle = '#f8fafc'; ctx.fillRect(0, 0, W, H);

    const charges = getCharges(s.configuration, W, H);
    const hasPositive = charges.some(c => c.q > 0);
    const startPoints: Vec[] = [];
    const N = 12;
    if (hasPositive) {
      charges.filter(c => c.q > 0).forEach(c => {
        for (let i = 0; i < N; i++) {
          const a = (i / N) * Math.PI * 2;
          startPoints.push({ x: c.x + Math.cos(a) * 18, y: c.y + Math.sin(a) * 18 });
        }
      });
    } else {
      // Only a negative charge on the canvas: start lines on a large ring
      // so they flow inward, converging on it.
      const c = charges[0];
      const R = Math.min(W, H) * 0.42;
      for (let i = 0; i < N; i++) {
        const a = (i / N) * Math.PI * 2;
        startPoints.push({ x: c.x + Math.cos(a) * R, y: c.y + Math.sin(a) * R });
      }
    }

    ctx.strokeStyle = 'rgba(99,102,241,0.55)'; ctx.lineWidth = 1.4;
    startPoints.forEach(sp => {
      const line = traceFieldLine(sp, charges, W, H);
      if (line.length < 2) return;
      ctx.beginPath(); ctx.moveTo(line[0].x, line[0].y);
      for (let i = 1; i < line.length; i++) ctx.lineTo(line[i].x, line[i].y);
      ctx.stroke();
      // Arrowhead partway along, showing direction of travel
      const mid = line[Math.floor(line.length * 0.55)];
      const next = line[Math.min(line.length - 1, Math.floor(line.length * 0.55) + 2)];
      if (mid && next) {
        const ang = Math.atan2(next.y - mid.y, next.x - mid.x);
        ctx.save();
        ctx.fillStyle = 'rgba(99,102,241,0.8)';
        ctx.beginPath(); ctx.moveTo(mid.x, mid.y);
        ctx.lineTo(mid.x - 7 * Math.cos(ang - 0.4), mid.y - 7 * Math.sin(ang - 0.4));
        ctx.lineTo(mid.x - 7 * Math.cos(ang + 0.4), mid.y - 7 * Math.sin(ang + 0.4));
        ctx.closePath(); ctx.fill();
        ctx.restore();
      }
    });

    charges.forEach(c => drawCharge(ctx, c));

    // Movable test point, showing local field strength (relative units)
    const tx = s.testX * W, ty = s.testY * H;
    const e = fieldAt({ x: tx, y: ty }, charges);
    const emag = Math.hypot(e.x, e.y);
    s.onTick?.(emag);
    if (emag > 1e-9) {
      const dirx = e.x / emag, diry = e.y / emag;
      const arrowLen = Math.min(60, emag * 300 + 10);
      ctx.strokeStyle = '#f59e0b'; ctx.lineWidth = 3;
      ctx.beginPath(); ctx.moveTo(tx, ty); ctx.lineTo(tx + dirx * arrowLen, ty + diry * arrowLen); ctx.stroke();
      const ang = Math.atan2(diry, dirx);
      ctx.fillStyle = '#f59e0b';
      const ex2 = tx + dirx * arrowLen, ey2 = ty + diry * arrowLen;
      ctx.beginPath(); ctx.moveTo(ex2, ey2);
      ctx.lineTo(ex2 - 9 * Math.cos(ang - 0.4), ey2 - 9 * Math.sin(ang - 0.4));
      ctx.lineTo(ex2 - 9 * Math.cos(ang + 0.4), ey2 - 9 * Math.sin(ang + 0.4));
      ctx.closePath(); ctx.fill();
    }
    ctx.fillStyle = '#78350f';
    ctx.beginPath(); ctx.arc(tx, ty, 5, 0, Math.PI * 2); ctx.fill();
    ctx.fillStyle = '#334155'; ctx.font = 'bold 9px system-ui'; ctx.textAlign = 'center';
    ctx.fillText('test point', tx, ty - 12);

    const labels: Record<FieldConfiguration, string> = {
      'single-positive': 'Field lines point OUTWARD from a positive charge',
      'single-negative': 'Field lines point INWARD toward a negative charge',
      dipole: 'Field lines curve from the positive charge to the negative one',
      'like-charges': 'Field lines repel each other — a null point sits exactly between two equal like charges',
    };
    ctx.fillStyle = '#334155'; ctx.font = 'bold 11px system-ui'; ctx.textAlign = 'center';
    ctx.fillText(labels[s.configuration], W / 2, 20);

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
