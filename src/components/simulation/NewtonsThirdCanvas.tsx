'use client';
import { useRef, useEffect, useCallback, useState } from 'react';

interface Props {
  mass1: number; mass2: number; force: number;
  scenario: 'push' | 'rocket' | 'collision';
  isRunning: boolean; isPaused: boolean;
  width?: number; height?: number;
}

export function NewtonsThirdCanvas({ mass1, mass2, force, scenario, isRunning, isPaused, width = 680, height = 240 }: Props) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const rafRef = useRef<number>(0);
  const t = useRef(0);
  const simRef = useRef({ mass1, mass2, force, scenario, isRunning, isPaused, width, height });
  simRef.current = { mass1, mass2, force, scenario, isRunning, isPaused, width, height };

  useEffect(() => { t.current = 0; }, [mass1, mass2, force, scenario]);

  const draw = useCallback(() => {
    const canvas = canvasRef.current; if (!canvas) return;
    const ctx = canvas.getContext('2d'); if (!ctx) return;
    const { mass1: m1, mass2: m2, force: F, scenario: sc, isRunning: r, isPaused: p } = simRef.current;
    const W = canvas.width, H = canvas.height;

    if (r && !p) t.current += 0.016;

    const a1 = F / m1; // acceleration of object 1 (reaction)
    const a2 = F / m2; // acceleration of object 2 (action)

    ctx.clearRect(0, 0, W, H);

    const groundY = H - 50;
    ctx.fillStyle = '#f8fafc'; ctx.fillRect(0, 0, W, groundY);
    ctx.fillStyle = '#e2e8f0'; ctx.fillRect(0, groundY, W, H - groundY);
    ctx.beginPath(); ctx.moveTo(0, groundY); ctx.lineTo(W, groundY);
    ctx.strokeStyle = '#94a3b8'; ctx.lineWidth = 2; ctx.stroke();

    const cx = W / 2;
    const dt = t.current;
    const BLOCK_H = 48;

    if (sc === 'push') {
      // Two people/objects pushing off each other from the centre
      const x1 = cx - 40 - 0.5 * a1 * dt * dt * 30;  // moves left
      const x2 = cx + 40 + 0.5 * a2 * dt * dt * 30;   // moves right
      const by = groundY - BLOCK_H;

      // Object 1 (left)
      ctx.fillStyle = '#6366f1'; ctx.beginPath();
      ctx.roundRect(x1 - 52, by, 52, BLOCK_H, 6); ctx.fill();
      ctx.fillStyle = 'white'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
      ctx.fillText(`${m1}kg`, x1 - 26, by + BLOCK_H / 2 + 4);

      // Object 2 (right)
      ctx.fillStyle = '#10b981'; ctx.beginPath();
      ctx.roundRect(x2, by, 52, BLOCK_H, 6); ctx.fill();
      ctx.fillStyle = 'white'; ctx.textAlign = 'center';
      ctx.fillText(`${m2}kg`, x2 + 26, by + BLOCK_H / 2 + 4);

      // Force arrows
      const midY = by + BLOCK_H / 2;
      const fLen = Math.min(F * 1.5, 70);
      // Reaction on obj1 (leftward)
      ctx.strokeStyle = '#ef4444'; ctx.lineWidth = 2.5;
      ctx.beginPath(); ctx.moveTo(x1 - 52, midY); ctx.lineTo(x1 - 52 - fLen, midY); ctx.stroke();
      ctx.fillStyle = '#ef4444';
      ctx.beginPath(); ctx.moveTo(x1 - 52 - fLen, midY);
      ctx.lineTo(x1 - 52 - fLen + 9, midY - 5); ctx.lineTo(x1 - 52 - fLen + 9, midY + 5);
      ctx.closePath(); ctx.fill();
      ctx.font = '10px system-ui'; ctx.textAlign = 'center';
      ctx.fillText(`−F=${F}N`, x1 - 52 - fLen / 2, midY - 10);

      // Action on obj2 (rightward)
      ctx.strokeStyle = '#10b981'; ctx.lineWidth = 2.5;
      ctx.beginPath(); ctx.moveTo(x2 + 52, midY); ctx.lineTo(x2 + 52 + fLen, midY); ctx.stroke();
      ctx.fillStyle = '#10b981';
      ctx.beginPath(); ctx.moveTo(x2 + 52 + fLen, midY);
      ctx.lineTo(x2 + 52 + fLen - 9, midY - 5); ctx.lineTo(x2 + 52 + fLen - 9, midY + 5);
      ctx.closePath(); ctx.fill();
      ctx.fillText(`+F=${F}N`, x2 + 52 + fLen / 2, midY - 10);

      ctx.fillStyle = '#6366f1'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
      ctx.fillText(`a₁=${a1.toFixed(2)} m/s² ←`, x1 - 26, by - 8);
      ctx.fillStyle = '#10b981';
      ctx.fillText(`a₂=${a2.toFixed(2)} m/s² →`, x2 + 26, by - 8);
    }

    if (sc === 'rocket') {
      const rocketX = 80 + 0.5 * a2 * dt * dt * 40;
      const by = groundY - 60;
      // Rocket body
      ctx.fillStyle = '#6366f1';
      ctx.beginPath(); ctx.roundRect(rocketX, by, 70, 50, 8); ctx.fill();
      ctx.fillStyle = '#f59e0b';
      ctx.beginPath(); ctx.moveTo(rocketX + 70, by + 25);
      ctx.lineTo(rocketX + 90, by + 10); ctx.lineTo(rocketX + 90, by + 40); ctx.closePath(); ctx.fill();
      ctx.fillStyle = 'white'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
      ctx.fillText(`${m1}kg`, rocketX + 35, by + 28);

      // Exhaust
      const exhaustLen = Math.min(F * 2, 100);
      const ey = by + 25;
      for (let i = 0; i < 5; i++) {
        const jitter = (Math.sin(t.current * 20 + i) * 6);
        ctx.fillStyle = `rgba(${200 + i * 10},${100 - i * 15},30,${0.8 - i * 0.12})`;
        ctx.beginPath();
        ctx.ellipse(rocketX - 10 - i * exhaustLen / 5, ey + jitter, exhaustLen / 5 * (1 - i * 0.15), 8 - i, 0, 0, Math.PI * 2);
        ctx.fill();
      }
      // Thrust force arrow
      ctx.strokeStyle = '#ef4444'; ctx.lineWidth = 2;
      ctx.beginPath(); ctx.moveTo(rocketX, ey); ctx.lineTo(rocketX - 50, ey); ctx.stroke();
      ctx.fillStyle = '#ef4444'; ctx.font = '10px system-ui'; ctx.textAlign = 'center';
      ctx.fillText(`Thrust (reaction)`, rocketX - 25, ey - 10);
      // Rocket motion arrow
      ctx.strokeStyle = '#10b981'; ctx.lineWidth = 2;
      ctx.beginPath(); ctx.moveTo(rocketX + 90, ey); ctx.lineTo(rocketX + 130, ey); ctx.stroke();
      ctx.fillStyle = '#10b981';
      ctx.beginPath(); ctx.moveTo(rocketX + 130, ey);
      ctx.lineTo(rocketX + 120, ey - 5); ctx.lineTo(rocketX + 120, ey + 5);
      ctx.closePath(); ctx.fill();
      ctx.fillText(`Motion (action)`, rocketX + 110, ey - 12);
      ctx.fillStyle = '#475569'; ctx.font = 'bold 10px monospace'; ctx.textAlign = 'left';
      ctx.fillText(`a=${a2.toFixed(2)} m/s²`, 10, 20);
    }

    if (sc === 'collision') {
      const B1W = 56, B2W = 56;
      const startGap = 240;
      const x1 = cx - startGap / 2 - B1W + Math.min(0.5 * a1 * dt * dt * 60, startGap / 2 - 4);
      const x2 = cx + startGap / 2 - Math.min(0.5 * a2 * dt * dt * 60, startGap / 2 - 4);
      const by = groundY - BLOCK_H;
      const midY = by + BLOCK_H / 2;

      ctx.fillStyle = '#6366f1'; ctx.beginPath(); ctx.roundRect(x1, by, B1W, BLOCK_H, 6); ctx.fill();
      ctx.fillStyle = 'white'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
      ctx.fillText(`${m1}kg`, x1 + B1W / 2, by + BLOCK_H / 2 + 4);
      ctx.fillStyle = '#10b981'; ctx.beginPath(); ctx.roundRect(x2, by, B2W, BLOCK_H, 6); ctx.fill();
      ctx.fillStyle = 'white'; ctx.fillText(`${m2}kg`, x2 + B2W / 2, by + BLOCK_H / 2 + 4);

      // Force arrows
      const fLen = Math.min(F * 1.2, 60);
      ctx.strokeStyle = '#ef4444'; ctx.lineWidth = 2.5;
      ctx.beginPath(); ctx.moveTo(x1, midY); ctx.lineTo(x1 - fLen, midY); ctx.stroke();
      ctx.fillStyle = '#ef4444';
      ctx.beginPath(); ctx.moveTo(x1 - fLen, midY);
      ctx.lineTo(x1 - fLen + 9, midY - 5); ctx.lineTo(x1 - fLen + 9, midY + 5);
      ctx.closePath(); ctx.fill();
      ctx.font = '10px system-ui'; ctx.textAlign = 'center';
      ctx.fillText(`−F`, x1 - fLen / 2, midY - 10);

      ctx.strokeStyle = '#10b981'; ctx.lineWidth = 2.5;
      ctx.beginPath(); ctx.moveTo(x2 + B2W, midY); ctx.lineTo(x2 + B2W + fLen, midY); ctx.stroke();
      ctx.fillStyle = '#10b981';
      ctx.beginPath(); ctx.moveTo(x2 + B2W + fLen, midY);
      ctx.lineTo(x2 + B2W + fLen - 9, midY - 5); ctx.lineTo(x2 + B2W + fLen - 9, midY + 5);
      ctx.closePath(); ctx.fill();
      ctx.fillText(`+F`, x2 + B2W + fLen / 2, midY - 10);

      ctx.fillStyle = '#475569'; ctx.font = '10px monospace'; ctx.textAlign = 'center';
      ctx.fillText(`Equal and opposite forces — F₁₂ = −F₂₁ = ${F}N`, W / 2, groundY + 20);
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
