'use client';
import { useRef, useEffect, useCallback } from 'react';
import { apparentWeight, elevatorAcceleration, ElevatorState, g } from '@/lib/physics/consequences';

interface Props {
  mass: number;
  elevState: ElevatorState;
  manualAccel: number;
  isRunning: boolean;
  isPaused: boolean;
  onComplete?: () => void;
  width?: number; height?: number;
}

export function ElevatorCanvas({ mass, elevState, manualAccel, isRunning, isPaused, onComplete, width = 500, height = 340 }: Props) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const rafRef = useRef<number>(0);
  const timeRef = useRef(0);
  const lastFrameRef = useRef<number | null>(null);
  const simRef = useRef({ mass, elevState, manualAccel, isRunning, isPaused, onComplete });
  simRef.current = { mass, elevState, manualAccel, isRunning, isPaused, onComplete };

  useEffect(() => {
    timeRef.current = 0; lastFrameRef.current = null;
  }, [elevState, mass, manualAccel]);

  const draw = useCallback((timestamp?: number) => {
    const canvas = canvasRef.current; if (!canvas) return;
    const ctx = canvas.getContext('2d'); if (!ctx) return;
    const { mass: m, elevState: st, manualAccel: ma, isRunning: r, isPaused: p, onComplete: complete } = simRef.current;
    const W = canvas.width, H = canvas.height;

    const accel = elevatorAcceleration(st, ma);
    const Wapp = apparentWeight(m, accel);
    const Wtrue = m * g;

    const top = 52;
    const bottom = Math.max(top + 24, H - 108);
    const travel = bottom - top;
    const direction = st.endsWith('down') || st === 'freefall' ? -1 : 1;
    const braking = st.startsWith('decel');
    const cruising = st.startsWith('constant');
    const magnitude = Math.abs(accel);
    // Map the complete motion to the visible shaft. Keep the same mapping
    // when resizing so the elapsed time and physical velocity stay intact.
    const distance = 6;
    const initialSpeed = braking ? Math.sqrt(2 * magnitude * distance) : cruising ? 2 : 0;
    const duration = cruising ? distance / initialSpeed : magnitude > 0 ? Math.sqrt(2 * distance / magnitude) : 0;
    if (r && !p && timestamp !== undefined && timeRef.current < duration) {
      const dt = lastFrameRef.current === null ? 0 : Math.min((timestamp - lastFrameRef.current) / 1000, 0.1);
      timeRef.current = Math.min(duration, timeRef.current + dt);
      lastFrameRef.current = timestamp;
      if (timeRef.current === duration) complete?.();
    } else {
      lastFrameRef.current = null;
    }

    const t = timeRef.current;
    const speed = Math.max(0, initialSpeed + direction * accel * t);
    const displacement = Math.min(distance, initialSpeed * t + 0.5 * direction * accel * t * t);
    const ey = st === 'rest' ? (top + bottom) / 2 : direction > 0
      ? bottom - displacement / distance * travel
      : top + displacement / distance * travel;

    ctx.clearRect(0, 0, W, H);

    // Building background
    ctx.fillStyle = '#f1f5f9';
    ctx.fillRect(24, 44, W - 48, H - 60);
    ctx.strokeStyle = '#cbd5e1'; ctx.lineWidth = 1;
    ctx.strokeRect(24, 44, W - 48, H - 60);

    // Floor lines
    for (let fl = 0; fl < 6; fl++) {
      const fy = 44 + fl * (H - 60) / 5;
      ctx.beginPath(); ctx.moveTo(24, fy); ctx.lineTo(W - 24, fy);
      ctx.strokeStyle = '#e2e8f0'; ctx.lineWidth = 1; ctx.stroke();
      ctx.fillStyle = '#475569'; ctx.font = '600 14px system-ui'; ctx.textAlign = 'left';
      ctx.fillText(`${5 - fl}F`, 28, fy + 12);
    }

    // Elevator cables
    ctx.beginPath();
    ctx.moveTo(W / 2 - 20, 44); ctx.lineTo(W / 2 - 20, ey);
    ctx.moveTo(W / 2 + 20, 44); ctx.lineTo(W / 2 + 20, ey);
    ctx.strokeStyle = '#64748b'; ctx.lineWidth = 2; ctx.stroke();

    // Elevator box
    const EW = 120, EH = 80;
    const ex = W / 2 - EW / 2;

    // Elevator body
    ctx.fillStyle = '#e0e7ff';
    ctx.strokeStyle = '#6366f1'; ctx.lineWidth = 2;
    ctx.beginPath(); ctx.roundRect(ex, ey, EW, EH, 6);
    ctx.fill(); ctx.stroke();

    // Door lines
    ctx.strokeStyle = '#818cf8'; ctx.lineWidth = 1;
    ctx.beginPath(); ctx.moveTo(W / 2, ey + 10); ctx.lineTo(W / 2, ey + EH - 10);
    ctx.stroke();

    // Person inside
    const px = W / 2, py = ey + EH - 30;
    // Body
    ctx.fillStyle = '#4f46e5';
    ctx.beginPath(); ctx.ellipse(px, py - 10, 8, 14, 0, 0, Math.PI * 2); ctx.fill();
    // Head
    ctx.fillStyle = '#f9a8d4';
    ctx.beginPath(); ctx.arc(px, py - 28, 9, 0, Math.PI * 2); ctx.fill();

    // Scale under feet
    ctx.fillStyle = '#1e293b';
    ctx.beginPath(); ctx.roundRect(px - 16, py + 4, 32, 8, 3); ctx.fill();
    ctx.fillStyle = '#f59e0b'; ctx.font = 'bold 12px system-ui'; ctx.textAlign = 'center';
    ctx.fillText(`${Wapp.toFixed(0)}N`, px, py + 11);

    // Positive physical components point upward on the canvas.
    const drawVector = (x: number, value: number, label: string, color: string) => {
      const start = ey + EH / 2;
      const sign = Math.sign(value);
      const tip = start - sign * Math.min(35, 18 + Math.abs(value) * 2);
      ctx.strokeStyle = color; ctx.fillStyle = color; ctx.lineWidth = 3;
      ctx.font = 'bold 18px system-ui'; ctx.textAlign = 'center';
      if (Math.abs(value) < 0.01) {
        ctx.fillText(`${label} = 0`, x, start + 4);
        return;
      }
      ctx.beginPath(); ctx.moveTo(x, start); ctx.lineTo(x, tip); ctx.stroke();
      ctx.beginPath(); ctx.moveTo(x, tip);
      ctx.lineTo(x - 5, tip + sign * 8); ctx.lineTo(x + 5, tip + sign * 8);
      ctx.closePath(); ctx.fill();
      ctx.fillText(label, x, sign > 0 ? start + 15 : start - 7);
    };
    drawVector(ex - 22, direction * speed, 'v', '#047857');
    drawVector(ex + EW + 22, accel, 'a', '#92400e');

    // Info panel (right)
    const infos = [
      { l: 'True weight', v: `${Wtrue.toFixed(1)} N`, c: '#64748b' },
      { l: 'Apparent weight', v: `${Wapp.toFixed(1)} N`, c: Wapp > Wtrue ? '#10b981' : Wapp < Wtrue ? '#ef4444' : '#6366f1' },
      { l: 'Acceleration', v: `${accel.toFixed(2)} m/s²`, c: '#f59e0b' },
      { l: 'Velocity', v: `${(direction * speed).toFixed(2)} m/s`, c: '#047857' },
    ];
    infos.forEach((info, i) => {
      ctx.fillStyle = '#64748b'; ctx.font = '600 14px system-ui'; ctx.textAlign = 'center';
      ctx.fillText(info.l, W * (i + 0.5) / infos.length, 15, W / 4 - 8);
      ctx.fillStyle = info.c; ctx.font = 'bold 18px system-ui';
      ctx.fillText(info.v, W * (i + 0.5) / infos.length, 36, W / 4 - 8);
    });

    // Weightlessness indicator
    if (st === 'freefall' || Wapp < 1) {
      ctx.fillStyle = 'rgba(239,68,68,0.15)';
      ctx.fillRect(ex, ey, EW, EH);
      ctx.fillStyle = '#ef4444'; ctx.font = 'bold 15px system-ui'; ctx.textAlign = 'center';
      ctx.fillText('WEIGHTLESS', W / 2, ey - 8);
    }

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
