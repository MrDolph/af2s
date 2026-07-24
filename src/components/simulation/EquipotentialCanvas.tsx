'use client';
import { useRef, useEffect, useCallback } from 'react';

export type EquipotentialConfig = 'single-positive' | 'single-negative' | 'dipole' | 'like-charges';

interface Props {
  configuration: EquipotentialConfig;
  width?: number; height?: number;
}

interface Vec { x: number; y: number; }
interface Charge extends Vec { q: number; }

const GRID_STEP = 6;
const BAND_STEP = 0.06; // potential units per colour band — tuned for a readable number of contours

function potentialAt(p: Vec, charges: Charge[]): number {
  let v = 0;
  for (const c of charges) {
    const r = Math.hypot(p.x - c.x, p.y - c.y);
    if (r < 6) return c.q > 0 ? 50 : -50; // clamp near a charge rather than diverge to infinity
    v += c.q / r;
  }
  return v;
}
function fieldAt(p: Vec, charges: Charge[]): Vec {
  let ex = 0, ey = 0;
  for (const c of charges) {
    const dx = p.x - c.x, dy = p.y - c.y;
    const r2 = dx * dx + dy * dy;
    if (r2 < 36) continue;
    const r = Math.sqrt(r2);
    const mag = c.q / r2;
    ex += mag * (dx / r); ey += mag * (dy / r);
  }
  return { x: ex, y: ey };
}
function traceFieldLine(start: Vec, charges: Charge[], W: number, H: number): Vec[] {
  const points: Vec[] = [start];
  let p = { ...start };
  for (let i = 0; i < 400; i++) {
    const e = fieldAt(p, charges);
    const emag = Math.hypot(e.x, e.y);
    if (emag < 1e-9) break;
    p = { x: p.x + (e.x / emag) * 5, y: p.y + (e.y / emag) * 5 };
    points.push(p);
    if (p.x < -20 || p.x > W + 20 || p.y < -20 || p.y > H + 20) break;
    if (charges.some(c => Math.hypot(p.x - c.x, p.y - c.y) < 16)) break;
  }
  return points;
}

function getCharges(config: EquipotentialConfig, W: number, H: number): Charge[] {
  const midY = H / 2;
  switch (config) {
    case 'single-positive': return [{ x: W / 2, y: midY, q: 1 }];
    case 'single-negative': return [{ x: W / 2, y: midY, q: -1 }];
    case 'dipole': return [{ x: W / 2 - 80, y: midY, q: 1 }, { x: W / 2 + 80, y: midY, q: -1 }];
    case 'like-charges': return [{ x: W / 2 - 80, y: midY, q: 1 }, { x: W / 2 + 80, y: midY, q: 1 }];
  }
}

function bandColor(v: number): string {
  const band = Math.round(v / BAND_STEP);
  if (band === 0) return '#f8fafc';
  const t = Math.min(1, Math.abs(band) / 8);
  if (band > 0) {
    // white -> red
    const g = Math.round(226 - t * 190), b = Math.round(232 - t * 210);
    return `rgb(254,${g},${b})`;
  }
  const g = Math.round(226 - t * 130), r = Math.round(226 - t * 200);
  return `rgb(${r},${g},254)`;
}

export function EquipotentialCanvas({ configuration, width = 660, height = 320 }: Props) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const sim = useRef({ configuration });
  sim.current = { configuration };

  const draw = useCallback(() => {
    const canvas = canvasRef.current; if (!canvas) return;
    const ctx = canvas.getContext('2d'); if (!ctx) return;
    const s = sim.current;
    const W = canvas.width, H = canvas.height;
    ctx.clearRect(0, 0, W, H);

    const charges = getCharges(s.configuration, W, H);

    // Colour-banded potential map — the boundary between any two bands IS
    // an equipotential line, by construction, rather than a separately
    // computed/approximated contour.
    for (let gx = 0; gx < W; gx += GRID_STEP) {
      for (let gy = 0; gy < H; gy += GRID_STEP) {
        const v = potentialAt({ x: gx, y: gy }, charges);
        ctx.fillStyle = bandColor(v);
        ctx.fillRect(gx, gy, GRID_STEP, GRID_STEP);
      }
    }

    // Field lines overlaid — always perpendicular to the equipotential
    // bands beneath them.
    const hasPositive = charges.some(c => c.q > 0);
    const startPoints: Vec[] = [];
    const N = 10;
    if (hasPositive) {
      charges.filter(c => c.q > 0).forEach(c => {
        for (let i = 0; i < N; i++) {
          const a = (i / N) * Math.PI * 2;
          startPoints.push({ x: c.x + Math.cos(a) * 18, y: c.y + Math.sin(a) * 18 });
        }
      });
    } else {
      const c = charges[0];
      const R = Math.min(W, H) * 0.42;
      for (let i = 0; i < N; i++) {
        const a = (i / N) * Math.PI * 2;
        startPoints.push({ x: c.x + Math.cos(a) * R, y: c.y + Math.sin(a) * R });
      }
    }
    ctx.strokeStyle = 'rgba(30,41,59,0.55)'; ctx.lineWidth = 1.3;
    startPoints.forEach(sp => {
      const line = traceFieldLine(sp, charges, W, H);
      if (line.length < 2) return;
      ctx.beginPath(); ctx.moveTo(line[0].x, line[0].y);
      for (let i = 1; i < line.length; i++) ctx.lineTo(line[i].x, line[i].y);
      ctx.stroke();
    });

    // Charges
    charges.forEach(c => {
      const r = 15;
      ctx.fillStyle = c.q > 0 ? '#dc2626' : '#2563eb';
      ctx.beginPath(); ctx.arc(c.x, c.y, r, 0, Math.PI * 2); ctx.fill();
      ctx.strokeStyle = 'white'; ctx.lineWidth = 2;
      ctx.beginPath(); ctx.moveTo(c.x - r * 0.5, c.y); ctx.lineTo(c.x + r * 0.5, c.y); ctx.stroke();
      if (c.q > 0) { ctx.beginPath(); ctx.moveTo(c.x, c.y - r * 0.5); ctx.lineTo(c.x, c.y + r * 0.5); ctx.stroke(); }
    });

    ctx.fillStyle = '#1e293b'; ctx.font = 'bold 11px system-ui'; ctx.textAlign = 'center';
    ctx.fillText('Colour bands = equipotential surfaces. Field lines always cross them at right angles.', W / 2, 20);
    ctx.fillStyle = '#64748b'; ctx.font = '10px system-ui'; ctx.textAlign = 'left';
    ctx.fillText('red = higher potential   blue = lower potential   white = zero', 8, H - 10);
  }, []);

  useEffect(() => { draw(); }, [draw]);

  return (
    <canvas ref={canvasRef} width={width} height={height}
      className="w-full rounded-xl border border-gray-200" style={{ display: 'block' }} />
  );
}
