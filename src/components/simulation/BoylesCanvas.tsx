'use client';
import { useRef, useEffect, useCallback, useState } from 'react';
import { boyleCurve, idealGasPressure } from '@/lib/physics/gas-laws';

interface BoylesCanvasProps {
  volume: number;       // L (0.5 – 10)
  temperature: number;  // K
  moles: number;
  width?: number;
  height?: number;
}

const N = 40; // number of particles

interface Particle { x: number; y: number; vx: number; vy: number; r: number; }

function randomParticles(count: number, cx: number, cy: number, pistonY: number, bottom: number): Particle[] {
  return Array.from({ length: count }, () => ({
    x: cx - 50 + Math.random() * 100,
    y: pistonY + 8 + Math.random() * (bottom - pistonY - 16),
    vx: (Math.random() - 0.5) * 3,
    vy: (Math.random() - 0.5) * 3,
    r: 4,
  }));
}

export function BoylesCanvas({ volume, temperature, moles, width = 340, height = 320 }: BoylesCanvasProps) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const rafRef = useRef<number>(0);
  const particles = useRef<Particle[]>([]);
  const simRef = useRef({ volume, temperature, moles, width, height });
  simRef.current = { volume, temperature, moles, width, height };

  const CX = width / 2;
  const CYLINDER_W = 120;
  const CYLINDER_LEFT = CX - CYLINDER_W / 2;
  const CYLINDER_RIGHT = CX + CYLINDER_W / 2;
  const CYLINDER_TOP = 20;
  const CYLINDER_BOTTOM = height - 40;
  const CYLINDER_H = CYLINDER_BOTTOM - CYLINDER_TOP;

  const getPistonY = useCallback((vol: number) => {
    const fillFraction = Math.min(vol / 10, 1);
    return CYLINDER_BOTTOM - fillFraction * CYLINDER_H;
  }, [CYLINDER_BOTTOM, CYLINDER_H]);

  // Init particles
  useEffect(() => {
    const pistonY = getPistonY(volume);
    particles.current = randomParticles(N, CX, (pistonY + CYLINDER_BOTTOM) / 2, pistonY, CYLINDER_BOTTOM);
  }, []);  // eslint-disable-line

  const draw = useCallback(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;
    const { volume: vol, temperature: temp, moles: n, width: w, height: h } = simRef.current;

    const pistonY = getPistonY(vol);
    const pressure = idealGasPressure(n, temp, vol) / 1000;
    const speedFactor = Math.sqrt(temp / 300);

    ctx.clearRect(0, 0, w, h);

    // Cylinder walls
    ctx.fillStyle = '#f8fafc';
    ctx.fillRect(CYLINDER_LEFT, pistonY, CYLINDER_W, CYLINDER_BOTTOM - pistonY);
    ctx.strokeStyle = '#94a3b8';
    ctx.lineWidth = 2;
    ctx.strokeRect(CYLINDER_LEFT, pistonY, CYLINDER_W, CYLINDER_BOTTOM - pistonY);

    // Piston
    const grad = ctx.createLinearGradient(CYLINDER_LEFT, 0, CYLINDER_RIGHT, 0);
    grad.addColorStop(0, '#6366f1');
    grad.addColorStop(1, '#818cf8');
    ctx.fillStyle = grad;
    ctx.fillRect(CYLINDER_LEFT, pistonY - 12, CYLINDER_W, 14);
    ctx.strokeStyle = '#4338ca';
    ctx.lineWidth = 1.5;
    ctx.strokeRect(CYLINDER_LEFT, pistonY - 12, CYLINDER_W, 14);

    // Piston handle
    ctx.fillStyle = '#4338ca';
    ctx.fillRect(CX - 6, CYLINDER_TOP, 12, pistonY - 12 - CYLINDER_TOP);

    // Pressure label
    ctx.fillStyle = '#4338ca';
    ctx.font = 'bold 11px system-ui';
    ctx.textAlign = 'center';
    ctx.fillText(`${pressure.toFixed(1)} kPa`, CX, pistonY - 18);

    // Update + draw particles
    const ps = particles.current;
    for (const p of ps) {
      p.x += p.vx * speedFactor;
      p.y += p.vy * speedFactor;
      if (p.x - p.r < CYLINDER_LEFT)  { p.x = CYLINDER_LEFT + p.r;  p.vx = Math.abs(p.vx); }
      if (p.x + p.r > CYLINDER_RIGHT) { p.x = CYLINDER_RIGHT - p.r; p.vx = -Math.abs(p.vx); }
      if (p.y - p.r < pistonY)        { p.y = pistonY + p.r;        p.vy = Math.abs(p.vy); }
      if (p.y + p.r > CYLINDER_BOTTOM){ p.y = CYLINDER_BOTTOM - p.r; p.vy = -Math.abs(p.vy); }

      const heat = Math.min(((temp - 100) / 500), 1);
      const r = Math.round(99 + heat * 120);
      const b = Math.round(180 - heat * 120);
      ctx.beginPath();
      ctx.arc(p.x, p.y, p.r, 0, Math.PI * 2);
      ctx.fillStyle = `rgba(${r},120,${b},0.8)`;
      ctx.fill();
    }

    // Volume label
    ctx.fillStyle = '#64748b';
    ctx.font = '11px system-ui';
    ctx.textAlign = 'left';
    ctx.fillText(`V = ${vol.toFixed(1)} L`, CYLINDER_RIGHT + 8, (pistonY + CYLINDER_BOTTOM) / 2);
    ctx.fillText(`T = ${temp} K`, CYLINDER_RIGHT + 8, (pistonY + CYLINDER_BOTTOM) / 2 + 16);

    rafRef.current = requestAnimationFrame(draw);
  }, [CX, CYLINDER_BOTTOM, CYLINDER_LEFT, CYLINDER_RIGHT, CYLINDER_TOP, getPistonY]);

  useEffect(() => {
    rafRef.current = requestAnimationFrame(draw);
    return () => cancelAnimationFrame(rafRef.current);
  }, [draw]);

  return (
    <canvas ref={canvasRef} width={width} height={height}
      className="w-full rounded-xl border border-gray-200 bg-white" style={{ display: 'block' }} />
  );
}
