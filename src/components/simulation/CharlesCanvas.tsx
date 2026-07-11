'use client';
import { useRef, useEffect, useCallback } from 'react';
import { charlesNewVolume } from '@/lib/physics/gas-laws';

interface CharlesCanvasProps {
  temperature: number; // K
  pressure: number;    // kPa
  moles: number;
  refTemp?: number;    // reference temperature
  refVolume?: number;  // reference volume at refTemp
  width?: number;
  height?: number;
}

const N = 40;
interface Particle { x: number; y: number; vx: number; vy: number; }

export function CharlesCanvas({
  temperature, pressure, moles, refTemp = 300, refVolume = 3,
  width = 340, height = 320,
}: CharlesCanvasProps) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const rafRef = useRef<number>(0);
  const particles = useRef<Particle[]>([]);
  const simRef = useRef({ temperature, pressure, moles, refTemp, refVolume, width, height });
  simRef.current = { temperature, pressure, moles, refTemp, refVolume, width, height };

  const CX = width / 2;
  const CYLINDER_W = 100;
  const CYLINDER_LEFT = CX - CYLINDER_W / 2;
  const CYLINDER_RIGHT = CX + CYLINDER_W / 2;
  const CYLINDER_BOTTOM = height - 40;
  const MAX_H = CYLINDER_BOTTOM - 30;

  const getGasTop = useCallback((temp: number) => {
    const vol = charlesNewVolume(refVolume, refTemp, temp);
    const fraction = Math.min(vol / (refVolume * 2.5), 1);
    return CYLINDER_BOTTOM - fraction * MAX_H;
  }, [CYLINDER_BOTTOM, MAX_H, refTemp, refVolume]);

  useEffect(() => {
    particles.current = Array.from({ length: N }, () => ({
      x: CYLINDER_LEFT + 8 + Math.random() * (CYLINDER_W - 16),
      y: getGasTop(temperature) + 8 + Math.random() * (CYLINDER_BOTTOM - getGasTop(temperature) - 16),
      vx: (Math.random() - 0.5) * 2,
      vy: (Math.random() - 0.5) * 2,
    }));
  }, []); // eslint-disable-line

  const draw = useCallback(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;
    const { temperature: temp, width: w, height: h } = simRef.current;

    const gasTop = getGasTop(temp);
    const gasH = CYLINDER_BOTTOM - gasTop;
    const speedFactor = Math.sqrt(temp / 300);
    const heat = Math.min((temp - 100) / 600, 1);

    ctx.clearRect(0, 0, w, h);

    // Gas fill with temperature colour
    const r = Math.round(219 + heat * 36);
    const g = Math.round(234 - heat * 114);
    const b = Math.round(254 - heat * 154);
    ctx.fillStyle = `rgba(${r},${g},${b},0.35)`;
    ctx.fillRect(CYLINDER_LEFT, gasTop, CYLINDER_W, gasH);

    // Cylinder walls (open top = piston moves up)
    ctx.strokeStyle = '#94a3b8';
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.moveTo(CYLINDER_LEFT, 20);
    ctx.lineTo(CYLINDER_LEFT, CYLINDER_BOTTOM);
    ctx.lineTo(CYLINDER_RIGHT, CYLINDER_BOTTOM);
    ctx.lineTo(CYLINDER_RIGHT, 20);
    ctx.stroke();

    // Piston (floats at gas top)
    const pg = ctx.createLinearGradient(CYLINDER_LEFT, 0, CYLINDER_RIGHT, 0);
    pg.addColorStop(0, '#6366f1'); pg.addColorStop(1, '#818cf8');
    ctx.fillStyle = pg;
    ctx.fillRect(CYLINDER_LEFT, gasTop - 10, CYLINDER_W, 12);
    ctx.strokeStyle = '#4338ca'; ctx.lineWidth = 1.5;
    ctx.strokeRect(CYLINDER_LEFT, gasTop - 10, CYLINDER_W, 12);

    // Update + draw particles
    for (const p of particles.current) {
      p.x += p.vx * speedFactor;
      p.y += p.vy * speedFactor;
      if (p.x < CYLINDER_LEFT + 4)    { p.x = CYLINDER_LEFT + 4;    p.vx = Math.abs(p.vx); }
      if (p.x > CYLINDER_RIGHT - 4)   { p.x = CYLINDER_RIGHT - 4;   p.vx = -Math.abs(p.vx); }
      if (p.y < gasTop + 4)           { p.y = gasTop + 4;           p.vy = Math.abs(p.vy); }
      if (p.y > CYLINDER_BOTTOM - 4)  { p.y = CYLINDER_BOTTOM - 4;  p.vy = -Math.abs(p.vy); }

      ctx.beginPath();
      ctx.arc(p.x, p.y, 4, 0, Math.PI * 2);
      ctx.fillStyle = `rgba(${Math.round(99 + heat*120)},102,${Math.round(241 - heat*141)},0.85)`;
      ctx.fill();
    }

    // Labels
    ctx.fillStyle = '#4338ca'; ctx.font = 'bold 11px system-ui'; ctx.textAlign = 'center';
    ctx.fillText(`${(charlesNewVolume(refVolume, refTemp, temp)).toFixed(2)} L`, CX, gasTop - 16);
    ctx.fillStyle = '#64748b'; ctx.font = '11px system-ui'; ctx.textAlign = 'left';
    ctx.fillText(`T = ${temp} K`, CYLINDER_RIGHT + 8, CYLINDER_BOTTOM - 20);
    ctx.fillText(`P = const`, CYLINDER_RIGHT + 8, CYLINDER_BOTTOM - 4);

    rafRef.current = requestAnimationFrame(draw);
  }, [CX, CYLINDER_BOTTOM, CYLINDER_LEFT, CYLINDER_RIGHT, MAX_H, getGasTop]);

  useEffect(() => {
    rafRef.current = requestAnimationFrame(draw);
    return () => cancelAnimationFrame(rafRef.current);
  }, [draw]);

  return (
    <canvas ref={canvasRef} width={width} height={height}
      className="w-full rounded-xl border border-gray-200 bg-white" style={{ display: 'block' }} />
  );
}
