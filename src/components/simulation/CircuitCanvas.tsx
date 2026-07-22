'use client';
import { useRef, useEffect, useCallback } from 'react';
import { seriesAnalysis, parallelAnalysis, ohmCurrent } from '@/lib/physics/circuits';

export type CircuitMode = 'ohm' | 'series' | 'parallel';

interface Props {
  mode: CircuitMode;
  voltage: number;
  r1: number; r2: number; r3: number;
  isRunning: boolean; isPaused: boolean;
  width?: number; height?: number;
}

// Draw a resistor zig-zag along a horizontal segment.
function drawResistor(ctx: CanvasRenderingContext2D, x: number, y: number, len: number, label: string, value: number, vertical = false) {
  const teeth = 6, amp = 7;
  ctx.save();
  ctx.translate(x, y);
  if (vertical) ctx.rotate(Math.PI / 2);
  ctx.strokeStyle = '#475569'; ctx.lineWidth = 2;
  ctx.beginPath(); ctx.moveTo(0, 0);
  const seg = len / (teeth + 1);
  ctx.lineTo(seg / 2, 0);
  for (let i = 0; i < teeth; i++) {
    ctx.lineTo(seg / 2 + seg * i + seg / 2, i % 2 === 0 ? -amp : amp);
  }
  ctx.lineTo(len - seg / 2, 0); ctx.lineTo(len, 0);
  ctx.stroke();
  ctx.restore();
  ctx.save();
  ctx.fillStyle = '#334155'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
  if (vertical) ctx.fillText(`${label}=${value}Ω`, x + 24, y + len / 2 + 3);
  else ctx.fillText(`${label}=${value}Ω`, x + len / 2, y - 14);
  ctx.restore();
}

function drawBattery(ctx: CanvasRenderingContext2D, x: number, y: number, V: number) {
  ctx.save();
  ctx.strokeStyle = '#475569'; ctx.lineWidth = 2;
  // long plate (+) and short plate (−)
  ctx.beginPath(); ctx.moveTo(x, y - 16); ctx.lineTo(x, y + 16); ctx.stroke();
  ctx.lineWidth = 4;
  ctx.beginPath(); ctx.moveTo(x + 10, y - 8); ctx.lineTo(x + 10, y + 8); ctx.stroke();
  ctx.fillStyle = '#334155'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
  ctx.fillText('+', x - 8, y - 20);
  ctx.fillText('−', x + 18, y - 20);
  ctx.fillText(`${V}V`, x + 5, y + 32);
  ctx.restore();
}

// A wire path is a list of points; electrons travel along it, distance
// parameterised by arc length so their SPEED on screen ∝ actual current.
type Path = { pts: [number, number][]; length: number; segLens: number[] };
function makePath(pts: [number, number][]): Path {
  const segLens: number[] = [];
  let length = 0;
  for (let i = 1; i < pts.length; i++) {
    const dx = pts[i][0] - pts[i - 1][0], dy = pts[i][1] - pts[i - 1][1];
    const l = Math.hypot(dx, dy);
    segLens.push(l); length += l;
  }
  return { pts, length, segLens };
}
function pointAt(path: Path, dist: number): [number, number] {
  let d = ((dist % path.length) + path.length) % path.length;
  for (let i = 0; i < path.segLens.length; i++) {
    if (d <= path.segLens[i]) {
      const f = path.segLens[i] === 0 ? 0 : d / path.segLens[i];
      const [x1, y1] = path.pts[i], [x2, y2] = path.pts[i + 1];
      return [x1 + (x2 - x1) * f, y1 + (y2 - y1) * f];
    }
    d -= path.segLens[i];
  }
  return path.pts[path.pts.length - 1];
}
function drawWire(ctx: CanvasRenderingContext2D, path: Path) {
  ctx.save();
  ctx.strokeStyle = '#94a3b8'; ctx.lineWidth = 2; ctx.lineJoin = 'round';
  ctx.beginPath();
  ctx.moveTo(path.pts[0][0], path.pts[0][1]);
  path.pts.slice(1).forEach(p => ctx.lineTo(p[0], p[1]));
  ctx.stroke();
  ctx.restore();
}
function drawElectrons(ctx: CanvasRenderingContext2D, path: Path, t: number, current: number, count: number) {
  if (current <= 0) return;
  // px/s proportional to current, capped for readability.
  const speed = Math.min(30 + current * 22, 170);
  ctx.save();
  for (let i = 0; i < count; i++) {
    const d = t * speed + (i / count) * path.length;
    const [x, y] = pointAt(path, d);
    ctx.beginPath(); ctx.arc(x, y, 3, 0, Math.PI * 2);
    ctx.fillStyle = '#f59e0b'; ctx.fill();
  }
  ctx.restore();
}

export function CircuitCanvas({ mode, voltage, r1, r2, r3, isRunning, isPaused, width = 640, height = 300 }: Props) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const rafRef = useRef<number>(0);
  const tRef = useRef(0);
  const lastFrameRef = useRef<number | null>(null);
  const sim = useRef({ mode, voltage, r1, r2, r3, isRunning, isPaused });
  sim.current = { mode, voltage, r1, r2, r3, isRunning, isPaused };

  useEffect(() => { tRef.current = 0; lastFrameRef.current = null; }, [mode, voltage, r1, r2, r3]);

  const draw = useCallback((timestamp?: number) => {
    const canvas = canvasRef.current; if (!canvas) return;
    const ctx = canvas.getContext('2d'); if (!ctx) return;
    const s = sim.current;
    const W = canvas.width, H = canvas.height;

    // Real wall-clock dt — electron drift speed on screen stays proportional
    // to the actual current at any display refresh rate.
    if (s.isRunning && !s.isPaused && timestamp !== undefined) {
      if (lastFrameRef.current !== null) {
        tRef.current += Math.min((timestamp - lastFrameRef.current) / 1000, 0.1);
      }
      lastFrameRef.current = timestamp;
    } else {
      lastFrameRef.current = timestamp ?? null;
    }
    const t = tRef.current;

    ctx.clearRect(0, 0, W, H);
    ctx.fillStyle = '#f8fafc'; ctx.fillRect(0, 0, W, H);

    const L = 70, R = W - 70, T = 60, B = H - 50;

    if (s.mode === 'ohm') {
      const I = ohmCurrent(s.voltage, s.r1);
      const rLen = 130, rX = (W - rLen) / 2;
      const loop = makePath([[L, B], [L, T], [rX, T], [rX + rLen, T], [R, T], [R, B], [(R + L) / 2 + 20, B], [L, B]]);
      drawWire(ctx, loop);
      drawResistor(ctx, rX, T, rLen, 'R', s.r1);
      drawBattery(ctx, (R + L) / 2 - 5, B, s.voltage);
      drawElectrons(ctx, loop, t, I, 14);
      // Ammeter bubble
      ctx.save();
      ctx.fillStyle = 'white'; ctx.strokeStyle = '#6366f1'; ctx.lineWidth = 2;
      ctx.beginPath(); ctx.arc(L, (T + B) / 2, 18, 0, Math.PI * 2); ctx.fill(); ctx.stroke();
      ctx.fillStyle = '#4338ca'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
      ctx.fillText('A', L, (T + B) / 2 - 2);
      ctx.font = '9px system-ui';
      ctx.fillText(`${I.toFixed(2)}A`, L, (T + B) / 2 + 10);
      ctx.restore();
    }

    if (s.mode === 'series') {
      const a = seriesAnalysis(s.voltage, [s.r1, s.r2, s.r3]);
      const rLen = 90, gap = (R - L - 3 * rLen) / 4;
      const xs = [L + gap, L + gap * 2 + rLen, L + gap * 3 + rLen * 2];
      const loop = makePath([[L, B], [L, T], ...xs.flatMap((x): [number, number][] => [[x, T], [x + rLen, T]]), [R, T], [R, B], [L, B]]);
      drawWire(ctx, loop);
      drawResistor(ctx, xs[0], T, rLen, 'R₁', s.r1);
      drawResistor(ctx, xs[1], T, rLen, 'R₂', s.r2);
      drawResistor(ctx, xs[2], T, rLen, 'R₃', s.r3);
      drawBattery(ctx, (R + L) / 2 - 5, B, s.voltage);
      drawElectrons(ctx, loop, t, a.I, 18);
      // Voltage drop labels under each resistor — the divider in action.
      ctx.save();
      ctx.fillStyle = '#059669'; ctx.font = '9px system-ui'; ctx.textAlign = 'center';
      xs.forEach((x, i) => ctx.fillText(`${a.drops[i].toFixed(2)}V`, x + rLen / 2, T + 22));
      ctx.restore();
    }

    if (s.mode === 'parallel') {
      const a = parallelAnalysis(s.voltage, [s.r1, s.r2, s.r3]);
      const bx1 = L + 90, bx2 = R - 90;
      const rows = [T, (T + B) / 2 - 10, B - 60];
      const rLen = bx2 - bx1 - 60;
      // Main loop through the top branch, plus each branch loop.
      const branchPaths = rows.map(y => makePath([
        [L, B], [L, y], [bx1, y], [bx1 + 30, y], [bx1 + 30 + rLen, y], [bx2, y], [R, y], [R, B], [L, B],
      ]));
      // Rails
      ctx.save(); ctx.strokeStyle = '#94a3b8'; ctx.lineWidth = 2;
      ctx.beginPath(); ctx.moveTo(L, B); ctx.lineTo(L, rows[0]); ctx.stroke();
      ctx.beginPath(); ctx.moveTo(R, B); ctx.lineTo(R, rows[0]); ctx.stroke();
      ctx.beginPath(); ctx.moveTo(L, B); ctx.lineTo(R, B); ctx.stroke();
      rows.forEach(y => { ctx.beginPath(); ctx.moveTo(L, y); ctx.lineTo(R, y); ctx.stroke(); });
      ctx.restore();
      const labels = ['R₁', 'R₂', 'R₃'], vals = [s.r1, s.r2, s.r3];
      rows.forEach((y, i) => {
        drawResistor(ctx, bx1 + 30, y, rLen, labels[i], vals[i]);
        // Electrons per branch — speed ∝ branch current, showing the
        // current divider: the smallest resistor gets the fastest flow.
        drawElectrons(ctx, branchPaths[i], t, a.branches[i], 10);
        ctx.save();
        ctx.fillStyle = '#059669'; ctx.font = '9px system-ui'; ctx.textAlign = 'left';
        ctx.fillText(`${a.branches[i].toFixed(2)}A`, bx2 + 6, y - 6);
        ctx.restore();
      });
      drawBattery(ctx, (R + L) / 2 - 5, B, s.voltage);
    }

    ctx.fillStyle = '#64748b'; ctx.font = '10px system-ui'; ctx.textAlign = 'left';
    ctx.fillText('● electron flow (speed ∝ current)', 8, H - 8);

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
