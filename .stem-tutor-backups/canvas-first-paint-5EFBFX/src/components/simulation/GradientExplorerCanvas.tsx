'use client';
import { useRef, useEffect, useCallback } from 'react';
import { FIELDS, computeContours, type ScalarField } from '@/lib/physics/gradientField';

interface Props {
  fieldIndex: number;
  point: { x: number; y: number };
  angleDeg: number;
  onPointChange: (p: { x: number; y: number }) => void;
  onAngleChange: (deg: number) => void;
  width?: number; height?: number;
}

const SCALE = 70;
const XMAX = 3.3;

export function GradientExplorerCanvas({
  fieldIndex, point, angleDeg, onPointChange, onAngleChange, width = 480, height = 480,
}: Props) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const dragRef = useRef<'pt' | 'dir' | null>(null);
  const sim = useRef({ fieldIndex, point, angleDeg });
  sim.current = { fieldIndex, point, angleDeg };

  const toCanvas = useCallback((x: number, y: number, W: number, H: number) => {
    const cx = W / 2, cy = H / 2;
    return [cx + x * SCALE, cy - y * SCALE];
  }, []);
  const fromCanvas = useCallback((px: number, py: number, W: number, H: number) => {
    const cx = W / 2, cy = H / 2;
    return [(px - cx) / SCALE, -(py - cy) / SCALE];
  }, []);

  const draw = useCallback(() => {
    const canvas = canvasRef.current; if (!canvas) return;
    const ctx = canvas.getContext('2d'); if (!ctx) return;
    const { fieldIndex: fi, point: pt, angleDeg: ang } = sim.current;
    const field: ScalarField = FIELDS[fi];
    const W = canvas.width, H = canvas.height;

    ctx.clearRect(0, 0, W, H);
    ctx.fillStyle = '#f8fafc'; ctx.fillRect(0, 0, W, H);

    // grid
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

    // level curves
    const segs = computeContours(field, -XMAX, XMAX, -XMAX, XMAX);
    ctx.strokeStyle = '#6366f1'; ctx.lineWidth = 1.6; ctx.globalAlpha = 0.55;
    segs.forEach(([a, b]) => {
      const [ax, ay] = toCanvas(a[0], a[1], W, H);
      const [bx, by] = toCanvas(b[0], b[1], W, H);
      ctx.beginPath(); ctx.moveTo(ax, ay); ctx.lineTo(bx, by); ctx.stroke();
    });
    ctx.globalAlpha = 1;

    // gradient vector
    const gx = field.gx(pt.x, pt.y), gy = field.gy(pt.x, pt.y);
    const gmag = Math.hypot(gx, gy) || 1e-9;
    const [px, py] = toCanvas(pt.x, pt.y, W, H);
    const gEndX = pt.x + (gx / gmag) * 1.4, gEndY = pt.y + (gy / gmag) * 1.4;
    const [gex, gey] = toCanvas(gEndX, gEndY, W, H);
    drawArrow(ctx, px, py, gex, gey, '#10b981', 3);

    // direction handle
    const rad = (ang * Math.PI) / 180;
    const ax2 = Math.cos(rad), ay2 = Math.sin(rad);
    const dEndX = pt.x + ax2 * 1.4, dEndY = pt.y + ay2 * 1.4;
    const [dex, dey] = toCanvas(dEndX, dEndY, W, H);
    ctx.setLineDash([4, 3]);
    drawArrow(ctx, px, py, dex, dey, '#d97706', 3);
    ctx.setLineDash([]);

    // point + direction handle grabber
    ctx.fillStyle = '#6366f1';
    ctx.beginPath(); ctx.arc(px, py, 7, 0, 2 * Math.PI); ctx.fill();
    ctx.strokeStyle = 'white'; ctx.lineWidth = 2; ctx.stroke();

    ctx.fillStyle = '#d97706';
    ctx.beginPath(); ctx.arc(dex, dey, 8, 0, 2 * Math.PI); ctx.fill();
    ctx.strokeStyle = 'white'; ctx.lineWidth = 2; ctx.stroke();
  }, [toCanvas]);

  useEffect(() => { draw(); }, [draw, fieldIndex, point, angleDeg]);

  const handlePointer = useCallback((clientX: number, clientY: number, isDown: boolean) => {
    const canvas = canvasRef.current; if (!canvas) return;
    const rect = canvas.getBoundingClientRect();
    const scaleX = canvas.width / rect.width, scaleY = canvas.height / rect.height;
    const px = (clientX - rect.left) * scaleX, py = (clientY - rect.top) * scaleY;
    const [wx, wy] = fromCanvas(px, py, canvas.width, canvas.height);

    if (isDown) {
      const { point: pt, angleDeg: ang } = sim.current;
      const [dpx, dpy] = toCanvas(pt.x, pt.y, canvas.width, canvas.height);
      const rad = (ang * Math.PI) / 180;
      const [dhx, dhy] = toCanvas(pt.x + Math.cos(rad) * 1.4, pt.y + Math.sin(rad) * 1.4, canvas.width, canvas.height);
      const distPt = Math.hypot(px - dpx, py - dpy);
      const distDir = Math.hypot(px - dhx, py - dhy);
      dragRef.current = distDir < 20 && distDir < distPt ? 'dir' : 'pt';
    }

    if (dragRef.current === 'pt') {
      onPointChange({ x: Math.max(-3, Math.min(3, wx)), y: Math.max(-3, Math.min(3, wy)) });
    } else if (dragRef.current === 'dir') {
      const { point: pt } = sim.current;
      const dx = wx - pt.x, dy = wy - pt.y;
      onAngleChange((Math.atan2(dy, dx) * 180) / Math.PI);
    }
  }, [fromCanvas, toCanvas, onPointChange, onAngleChange]);

  return (
    <canvas
      ref={canvasRef} width={width} height={height} className="rounded-xl cursor-grab active:cursor-grabbing touch-none"
      onPointerDown={e => { (e.target as HTMLCanvasElement).setPointerCapture(e.pointerId); handlePointer(e.clientX, e.clientY, true); }}
      onPointerMove={e => { if (dragRef.current) handlePointer(e.clientX, e.clientY, false); }}
      onPointerUp={() => { dragRef.current = null; }}
    />
  );
}

function drawArrow(ctx: CanvasRenderingContext2D, x1: number, y1: number, x2: number, y2: number, color: string, width: number) {
  ctx.strokeStyle = color; ctx.lineWidth = width;
  ctx.beginPath(); ctx.moveTo(x1, y1); ctx.lineTo(x2, y2); ctx.stroke();
  const angle = Math.atan2(y2 - y1, x2 - x1);
  const headLen = 10;
  ctx.fillStyle = color;
  ctx.beginPath();
  ctx.moveTo(x2, y2);
  ctx.lineTo(x2 - headLen * Math.cos(angle - Math.PI / 7), y2 - headLen * Math.sin(angle - Math.PI / 7));
  ctx.lineTo(x2 - headLen * Math.cos(angle + Math.PI / 7), y2 - headLen * Math.sin(angle + Math.PI / 7));
  ctx.closePath(); ctx.fill();
}
