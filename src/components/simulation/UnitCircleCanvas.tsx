'use client';
import { useRef, useEffect, useCallback } from 'react';
import { deg2rad, COMMON_ANGLES } from '@/lib/physics/unitCircle';

interface Props {
  angleDeg: number;
  onAngleChange: (deg: number) => void;
  width?: number;
  height?: number;
}

export function UnitCircleCanvas({ angleDeg, onAngleChange, width = 440, height = 440 }: Props) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const draggingRef = useRef(false);
  const sim = useRef({ angleDeg });
  sim.current = { angleDeg };

  const draw = useCallback(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;
    const W = canvas.width, H = canvas.height;
    const cx = W / 2, cy = H / 2;
    const R = Math.min(W, H) * 0.32;

    ctx.clearRect(0, 0, W, H);
    ctx.fillStyle = '#f8fafc';
    ctx.fillRect(0, 0, W, H);

    // axes
    ctx.strokeStyle = '#94a3b8';
    ctx.lineWidth = 1.3;
    ctx.beginPath();
    ctx.moveTo(cx - R - 40, cy); ctx.lineTo(cx + R + 40, cy);
    ctx.moveTo(cx, cy - R - 40); ctx.lineTo(cx, cy + R + 40);
    ctx.stroke();

    // quadrant labels
    ctx.fillStyle = '#cbd5e1';
    ctx.font = '600 13px sans-serif';
    ctx.textAlign = 'center';
    ctx.fillText('I', cx + R * 0.42, cy - R * 0.36);
    ctx.fillText('II', cx - R * 0.42, cy - R * 0.36);
    ctx.fillText('III', cx - R * 0.42, cy + R * 0.48);
    ctx.fillText('IV', cx + R * 0.42, cy + R * 0.48);

    // main circle
    ctx.strokeStyle = '#94a3b8';
    ctx.lineWidth = 1.6;
    ctx.beginPath();
    ctx.arc(cx, cy, R, 0, 2 * Math.PI);
    ctx.stroke();

    // common-angle ticks + labels
    ctx.font = '10px sans-serif';
    COMMON_ANGLES.forEach(({ deg, radLabel }) => {
      const rad = deg2rad(deg);
      const px = cx + R * Math.cos(rad), py = cy - R * Math.sin(rad);
      ctx.fillStyle = '#f59e0b';
      ctx.beginPath();
      ctx.arc(px, py, 2.5, 0, 2 * Math.PI);
      ctx.fill();

      const lx = cx + (R + 22) * Math.cos(rad), ly = cy - (R + 22) * Math.sin(rad);
      ctx.fillStyle = '#b45309';
      ctx.textAlign = 'center';
      ctx.fillText(`${deg}°`, lx, ly - 4);
      ctx.fillStyle = '#92400e';
      ctx.fillText(radLabel, lx, ly + 8);
    });

    // current angle
    const rad = deg2rad(angleDeg);
    const px = cx + R * Math.cos(rad), py = cy - R * Math.sin(rad);

    // angle arc from positive x-axis
    ctx.strokeStyle = '#6366f1';
    ctx.lineWidth = 1.3;
    ctx.beginPath();
    ctx.arc(cx, cy, 26, -rad, 0, false);
    ctx.stroke();
    if (angleDeg > 12) {
      ctx.fillStyle = '#4f46e5';
      ctx.font = 'italic 12px serif';
      ctx.textAlign = 'center';
      ctx.fillText('\u03b8', cx + 42 * Math.cos(rad / 2), cy - 42 * Math.sin(rad / 2) + 4);
    }

    // radius line
    ctx.strokeStyle = '#475569';
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.moveTo(cx, cy); ctx.lineTo(px, py);
    ctx.stroke();

    // cos projection (yellow, horizontal, along x-axis to px)
    ctx.strokeStyle = '#eab308';
    ctx.lineWidth = 2.4;
    ctx.beginPath();
    ctx.moveTo(cx, cy); ctx.lineTo(px, cy);
    ctx.stroke();

    // sin projection (red, vertical, from x-axis up/down to point)
    ctx.strokeStyle = '#ef4444';
    ctx.lineWidth = 2.4;
    ctx.beginPath();
    ctx.moveTo(px, cy); ctx.lineTo(px, py);
    ctx.stroke();

    // point on circle
    ctx.fillStyle = '#4f46e5';
    ctx.beginPath();
    ctx.arc(px, py, 7, 0, 2 * Math.PI);
    ctx.fill();
    ctx.strokeStyle = 'white';
    ctx.lineWidth = 2;
    ctx.stroke();

    // axis endpoint labels — placed just inside the circle so they never collide
    // with the outside degree/radian labels at 90 and 270 degrees
    ctx.fillStyle = '#64748b';
    ctx.font = '11px sans-serif';
    ctx.textAlign = 'right';
    ctx.fillText('(1, 0)', cx + R - 6, cy - 6);
    ctx.textAlign = 'left';
    ctx.fillText('(\u22121, 0)', cx - R + 6, cy - 6);
    ctx.fillText('(0, 1)', cx + 8, cy - R + 16);
    ctx.fillText('(0, \u22121)', cx + 8, cy + R - 8);
  }, [angleDeg]);

  useEffect(() => { draw(); }, [draw]);

  const setFromPointer = useCallback((clientX: number, clientY: number) => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const rect = canvas.getBoundingClientRect();
    const scaleX = canvas.width / rect.width, scaleY = canvas.height / rect.height;
    const px = (clientX - rect.left) * scaleX, py = (clientY - rect.top) * scaleY;
    const cx = canvas.width / 2, cy = canvas.height / 2;
    const dx = px - cx, dy = cy - py; // flip y so up is positive
    let deg = (Math.atan2(dy, dx) * 180) / Math.PI;
    if (deg < 0) deg += 360;
    onAngleChange(deg);
  }, [onAngleChange]);

  return (
    <canvas
      ref={canvasRef}
      width={width}
      height={height}
      className="rounded-xl cursor-grab active:cursor-grabbing touch-none max-w-full"
      onPointerDown={e => { (e.target as HTMLCanvasElement).setPointerCapture(e.pointerId); draggingRef.current = true; setFromPointer(e.clientX, e.clientY); }}
      onPointerMove={e => { if (draggingRef.current) setFromPointer(e.clientX, e.clientY); }}
      onPointerUp={() => { draggingRef.current = false; }}
    />
  );
}
