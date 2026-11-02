'use client';
import { useRef, useEffect, useCallback } from 'react';
import { FIELDS, type VectorField2D } from '@/lib/physics/divStokes';

interface Props {
  fieldIndex: number;
  disk: { cx: number; cy: number; r: number };
  onDiskChange: (d: { cx: number; cy: number; r: number }) => void;
  width?: number; height?: number;
}

const SCALE = 70;

export function DivStokesCanvas({ fieldIndex, disk, onDiskChange, width = 480, height = 480 }: Props) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const draggingRef = useRef(false);
  const sim = useRef({ fieldIndex, disk });
  sim.current = { fieldIndex, disk };

  const toCanvas = useCallback((x: number, y: number, W: number, H: number): [number, number] => {
    const cx = W / 2, cy = H / 2;
    return [cx + x * SCALE, cy - y * SCALE];
  }, []);
  const fromCanvas = useCallback((px: number, py: number, W: number, H: number): [number, number] => {
    const cx = W / 2, cy = H / 2;
    return [(px - cx) / SCALE, -(py - cy) / SCALE];
  }, []);

  const draw = useCallback(() => {
    const canvas = canvasRef.current; if (!canvas) return;
    const ctx = canvas.getContext('2d'); if (!ctx) return;
    const { fieldIndex: fi, disk: d } = sim.current;
    const field: VectorField2D = FIELDS[fi];
    const W = canvas.width, H = canvas.height;

    ctx.clearRect(0, 0, W, H);
    ctx.fillStyle = '#f8fafc'; ctx.fillRect(0, 0, W, H);

    ctx.strokeStyle = '#e2e8f0'; ctx.lineWidth = 1;
    for (let gx = -3; gx <= 3; gx++) {
      const [sx] = toCanvas(gx, 0, W, H);
      ctx.beginPath(); ctx.moveTo(sx, 0); ctx.lineTo(sx, H); ctx.stroke();
    }
    for (let gy = -3; gy <= 3; gy++) {
      const [, sy] = toCanvas(0, gy, W, H);
      ctx.beginPath(); ctx.moveTo(0, sy); ctx.lineTo(W, sy); ctx.stroke();
    }
    ctx.strokeStyle = '#94a3b8'; ctx.lineWidth = 1.5;
    const [ox, oy] = toCanvas(0, 0, W, H);
    ctx.beginPath(); ctx.moveTo(0, oy); ctx.lineTo(W, oy); ctx.moveTo(ox, 0); ctx.lineTo(ox, H); ctx.stroke();

    // field arrows
    ctx.strokeStyle = '#94a3b8'; ctx.globalAlpha = 0.55;
    for (let gx = -3; gx <= 3; gx += 0.75) {
      for (let gy = -3; gy <= 3; gy += 0.75) {
        const Fx = field.fx(gx, gy), Fy = field.fy(gx, gy);
        const mag = Math.hypot(Fx, Fy) || 1e-9;
        const len = Math.min(0.28, 0.1 + 0.05 * mag);
        const ex = gx + (Fx / mag) * len, ey = gy + (Fy / mag) * len;
        const [sx1, sy1] = toCanvas(gx, gy, W, H);
        const [sx2, sy2] = toCanvas(ex, ey, W, H);
        ctx.beginPath(); ctx.moveTo(sx1, sy1); ctx.lineTo(sx2, sy2); ctx.stroke();
      }
    }
    ctx.globalAlpha = 1;

    // disk
    const [ccx, ccy] = toCanvas(d.cx, d.cy, W, H);
    ctx.fillStyle = 'rgba(37,99,235,0.10)';
    ctx.strokeStyle = '#2563eb'; ctx.lineWidth = 2.4;
    ctx.beginPath(); ctx.arc(ccx, ccy, d.r * SCALE, 0, 2 * Math.PI); ctx.fill(); ctx.stroke();
    ctx.fillStyle = '#2563eb';
    ctx.beginPath(); ctx.arc(ccx, ccy, 6, 0, 2 * Math.PI); ctx.fill();
    ctx.strokeStyle = 'white'; ctx.lineWidth = 1.5; ctx.stroke();
  }, [toCanvas]);

  useEffect(() => { draw(); }, [draw, fieldIndex, disk]);

  const moveDisk = useCallback((clientX: number, clientY: number) => {
    const canvas = canvasRef.current; if (!canvas) return;
    const rect = canvas.getBoundingClientRect();
    const scaleX = canvas.width / rect.width, scaleY = canvas.height / rect.height;
    const px = (clientX - rect.left) * scaleX, py = (clientY - rect.top) * scaleY;
    const [wx, wy] = fromCanvas(px, py, canvas.width, canvas.height);
    const { disk: d } = sim.current;
    onDiskChange({ ...d, cx: Math.max(-2.5, Math.min(2.5, wx)), cy: Math.max(-2.5, Math.min(2.5, wy)) });
  }, [fromCanvas, onDiskChange]);

  return (
    <canvas
      ref={canvasRef} width={width} height={height} className="rounded-xl cursor-grab active:cursor-grabbing touch-none"
      onPointerDown={e => { (e.target as HTMLCanvasElement).setPointerCapture(e.pointerId); draggingRef.current = true; moveDisk(e.clientX, e.clientY); }}
      onPointerMove={e => { if (draggingRef.current) moveDisk(e.clientX, e.clientY); }}
      onPointerUp={() => { draggingRef.current = false; }}
    />
  );
}
