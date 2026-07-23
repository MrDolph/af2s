'use client';
import { useRef, useEffect, useCallback } from 'react';
import { apparentWeight, elevatorAcceleration, ElevatorState, g } from '@/lib/physics/consequences';

interface Props {
  mass: number;
  elevState: ElevatorState;
  manualAccel: number;
  isRunning: boolean;
  isPaused: boolean;
  width?: number; height?: number;
}

export function ElevatorCanvas({ mass, elevState, manualAccel, isRunning, isPaused, width = 500, height = 340 }: Props) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const rafRef = useRef<number>(0);
  const yRef = useRef(220);
  const vyRef = useRef(0);
  const timeRef = useRef(0);
  const lastFrameRef = useRef<number | null>(null);
  const simRef = useRef({ mass, elevState, manualAccel, isRunning, isPaused });
  simRef.current = { mass, elevState, manualAccel, isRunning, isPaused };

  useEffect(() => {
    yRef.current = 220; vyRef.current = 0; timeRef.current = 0; lastFrameRef.current = null;
  }, [elevState, mass, manualAccel]);

  const draw = useCallback((timestamp?: number) => {
    const canvas = canvasRef.current; if (!canvas) return;
    const ctx = canvas.getContext('2d'); if (!ctx) return;
    const { mass: m, elevState: st, manualAccel: ma, isRunning: r, isPaused: p } = simRef.current;
    const W = canvas.width, H = canvas.height;

    const accel = elevatorAcceleration(st, ma);
    const Wapp = apparentWeight(m, accel);
    const Wtrue = m * g;

    let dt = 0;
    if (r && !p && timestamp !== undefined) {
      if (lastFrameRef.current !== null) {
        dt = Math.min((timestamp - lastFrameRef.current) / 1000, 0.1);
      }
      lastFrameRef.current = timestamp;
    } else {
      lastFrameRef.current = timestamp ?? null;
    }
    if (dt > 0) {
      vyRef.current += accel * dt * 60; // px/s (60 = same visual scale as before)
      yRef.current -= vyRef.current * dt;
      // Clamp
      if (yRef.current < 60) { yRef.current = 60; vyRef.current = 0; }
      if (yRef.current > H - 80) { yRef.current = H - 80; vyRef.current = 0; }
      timeRef.current += dt;
    }

    ctx.clearRect(0, 0, W, H);

    // Building background
    ctx.fillStyle = '#f1f5f9';
    ctx.fillRect(60, 20, W - 120, H - 40);
    ctx.strokeStyle = '#cbd5e1'; ctx.lineWidth = 1;
    ctx.strokeRect(60, 20, W - 120, H - 40);

    // Floor lines
    for (let fl = 0; fl < 6; fl++) {
      const fy = 20 + fl * (H - 40) / 5;
      ctx.beginPath(); ctx.moveTo(60, fy); ctx.lineTo(W - 60, fy);
      ctx.strokeStyle = '#e2e8f0'; ctx.lineWidth = 1; ctx.stroke();
      ctx.fillStyle = '#94a3b8'; ctx.font = '9px system-ui'; ctx.textAlign = 'left';
      ctx.fillText(`${5 - fl}F`, 62, fy + 12);
    }

    // Elevator cables
    ctx.beginPath();
    ctx.moveTo(W / 2 - 20, 20); ctx.lineTo(W / 2 - 20, yRef.current);
    ctx.moveTo(W / 2 + 20, 20); ctx.lineTo(W / 2 + 20, yRef.current);
    ctx.strokeStyle = '#64748b'; ctx.lineWidth = 2; ctx.stroke();

    // Elevator box
    const EW = 120, EH = 80;
    const ex = W / 2 - EW / 2;
    const ey = yRef.current;

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
    ctx.fillStyle = '#f59e0b'; ctx.font = 'bold 9px system-ui'; ctx.textAlign = 'center';
    ctx.fillText(`${Wapp.toFixed(0)}N`, px, py + 11);

    // Velocity arrow on elevator
    if (Math.abs(vyRef.current) > 0.3) {
      const dir = vyRef.current > 0 ? -1 : 1; // canvas y inverted
      const arrowY = ey + EH / 2;
      const arrowX = ex - 20;
      ctx.save();
      ctx.beginPath(); ctx.moveTo(arrowX, arrowY); ctx.lineTo(arrowX, arrowY + dir * 30);
      ctx.strokeStyle = '#10b981'; ctx.lineWidth = 2; ctx.stroke();
      ctx.beginPath(); ctx.moveTo(arrowX, arrowY + dir * 30);
      ctx.lineTo(arrowX - 5, arrowY + dir * 20);
      ctx.lineTo(arrowX + 5, arrowY + dir * 20);
      ctx.closePath(); ctx.fillStyle = '#10b981'; ctx.fill();
      ctx.restore();
    }

    // Info panel (right)
    const ix = W - 50;
    const infos = [
      { l: 'True weight', v: `${Wtrue.toFixed(1)} N`, c: '#64748b' },
      { l: 'Apparent weight', v: `${Wapp.toFixed(1)} N`, c: Wapp > Wtrue ? '#10b981' : Wapp < Wtrue ? '#ef4444' : '#6366f1' },
      { l: 'Acceleration', v: `${accel.toFixed(2)} m/s²`, c: '#f59e0b' },
      { l: 'State', v: st.replace('-', ' '), c: '#6366f1' },
    ];
    infos.forEach((info, i) => {
      ctx.fillStyle = '#64748b'; ctx.font = '9px system-ui'; ctx.textAlign = 'right';
      ctx.fillText(info.l, ix, 40 + i * 32);
      ctx.fillStyle = info.c; ctx.font = 'bold 12px system-ui';
      ctx.fillText(info.v, ix, 54 + i * 32);
    });

    // Weightlessness indicator
    if (st === 'freefall' || Wapp < 1) {
      ctx.fillStyle = 'rgba(239,68,68,0.15)';
      ctx.fillRect(ex, ey, EW, EH);
      ctx.fillStyle = '#ef4444'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
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
