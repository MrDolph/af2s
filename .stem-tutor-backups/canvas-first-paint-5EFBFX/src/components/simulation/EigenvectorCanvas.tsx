'use client';
import { useRef, useEffect, useCallback } from 'react';
import { matAt, eigen, type Matrix2x2 } from '@/lib/physics/eigen';

interface Props {
  matrix: Matrix2x2;
  t: number;
  width?: number; height?: number;
}

const SCALE = 60;

export function EigenvectorCanvas({ matrix, t, width = 460, height = 460 }: Props) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);

  const toCanvas = useCallback((x: number, y: number, W: number, H: number) => {
    const cx = W / 2, cy = H / 2;
    return [cx + x * SCALE, cy - y * SCALE];
  }, []);

  const draw = useCallback(() => {
    const canvas = canvasRef.current; if (!canvas) return;
    const ctx = canvas.getContext('2d'); if (!ctx) return;
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

    const M = matAt(matrix, t);
    const apply = (x: number, y: number): [number, number] => [M.a * x + M.b * y, M.c * x + M.d * y];

    // original (dashed) unit circle
    ctx.strokeStyle = '#2563eb'; ctx.lineWidth = 1.6; ctx.setLineDash([4, 3]); ctx.globalAlpha = 0.6;
    ctx.beginPath();
    for (let i = 0; i <= 72; i++) {
      const th = (i / 72) * 2 * Math.PI;
      const [sx, sy] = toCanvas(Math.cos(th) * 2, Math.sin(th) * 2, W, H);
      if (i === 0) ctx.moveTo(sx, sy); else ctx.lineTo(sx, sy);
    }
    ctx.stroke(); ctx.setLineDash([]); ctx.globalAlpha = 1;

    // transformed circle (filled)
    ctx.beginPath();
    for (let i = 0; i <= 72; i++) {
      const th = (i / 72) * 2 * Math.PI;
      const [px, py] = apply(Math.cos(th) * 2, Math.sin(th) * 2);
      const [sx, sy] = toCanvas(px, py, W, H);
      if (i === 0) ctx.moveTo(sx, sy); else ctx.lineTo(sx, sy);
    }
    ctx.closePath();
    ctx.fillStyle = 'rgba(16,185,129,0.12)'; ctx.fill();
    ctx.strokeStyle = '#10b981'; ctx.lineWidth = 2.2; ctx.stroke();

    // sample vectors fan
    ctx.strokeStyle = '#10b981'; ctx.globalAlpha = 0.5;
    for (let deg = 0; deg < 360; deg += 30) {
      const th = (deg * Math.PI) / 180;
      const [px, py] = apply(Math.cos(th) * 1.7, Math.sin(th) * 1.7);
      const [sx1, sy1] = toCanvas(0, 0, W, H);
      const [sx2, sy2] = toCanvas(px, py, W, H);
      ctx.beginPath(); ctx.moveTo(sx1, sy1); ctx.lineTo(sx2, sy2); ctx.stroke();
    }
    ctx.globalAlpha = 1;

    // eigenvectors (computed from the ORIGINAL matrix, fixed reference lines)
    const eig = eigen(matrix);
    if (!eig.complex && eig.v1 && eig.v2) {
      [[eig.v1, '#d97706'], [eig.v2, '#7c3aed']].forEach(([v, col]) => {
        const vec = v as [number, number];
        const [x1, y1] = toCanvas(-vec[0] * 4, -vec[1] * 4, W, H);
        const [x2, y2] = toCanvas(vec[0] * 4, vec[1] * 4, W, H);
        ctx.strokeStyle = col as string; ctx.lineWidth = 2.6; ctx.globalAlpha = 0.85;
        ctx.beginPath(); ctx.moveTo(x1, y1); ctx.lineTo(x2, y2); ctx.stroke();
        ctx.globalAlpha = 1;
      });
    }
  }, [matrix, t, toCanvas]);

  useEffect(() => { draw(); }, [draw]);

  return <canvas ref={canvasRef} width={width} height={height} className="rounded-xl" />;
}
