'use client';
import { useRef, useEffect, useCallback } from 'react';

interface PressureLawCanvasProps {
  temperature: number; // K
  volume: number;      // L (fixed)
  moles: number;
  refTemp?: number;
  refPressure?: number;
  width?: number;
  height?: number;
}

const N = 40;
interface Particle { x: number; y: number; vx: number; vy: number; }

export function PressureLawCanvas({
  temperature, volume, moles,
  refTemp = 300, refPressure = 200,
  width = 340, height = 320,
}: PressureLawCanvasProps) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const rafRef = useRef<number>(0);
  const particles = useRef<Particle[]>([]);

  const sim = useRef({ temperature, volume, moles, refTemp, refPressure, width, height });
  sim.current = { temperature, volume, moles, refTemp, refPressure, width, height };

  const CX = width / 2;
  const CWIDTH = 110;
  const CLEFT = CX - CWIDTH / 2;
  const CRIGHT = CX + CWIDTH / 2;
  const CTOP = 40;
  const CBOTTOM = height - 50;
  const CHEIGHT = CBOTTOM - CTOP;

  useEffect(() => {
    particles.current = Array.from({ length: N }, () => ({
      x: CLEFT + 8 + Math.random() * (CWIDTH - 16),
      y: CTOP + 8 + Math.random() * (CHEIGHT - 16),
      vx: (Math.random() - 0.5) * 2,
      vy: (Math.random() - 0.5) * 2,
    }));
  }, []); // eslint-disable-line

  const draw = useCallback(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;
    const { temperature: temp, refTemp: rT, refPressure: rP, width: w, height: h } = sim.current;

    const currentPressure = (rP * temp) / rT;
    const heat = Math.min((temp - 100) / 500, 1);
    const speedFactor = Math.sqrt(temp / 300);

    ctx.clearRect(0, 0, w, h);

    // Container — rigid walls (fixed volume)
    const fillR = Math.round(219 + heat * 36);
    const fillG = Math.round(234 - heat * 114);
    const fillB = Math.round(254 - heat * 154);
    ctx.fillStyle = `rgba(${fillR},${fillG},${fillB},0.3)`;
    ctx.fillRect(CLEFT, CTOP, CWIDTH, CHEIGHT);

    // Thick rigid walls to show volume is fixed
    ctx.strokeStyle = '#475569';
    ctx.lineWidth = 4;
    ctx.strokeRect(CLEFT, CTOP, CWIDTH, CHEIGHT);

    // "Fixed" label on walls
    ctx.fillStyle = '#94a3b8';
    ctx.font = '9px system-ui';
    ctx.textAlign = 'center';
    ctx.fillText('fixed walls', CX, CTOP - 8);

    // Pressure gauge on right wall
    const gaugeH = CHEIGHT - 20;
    const gaugeFill = Math.min((currentPressure / (rP * 3)) * gaugeH, gaugeH);
    const gaugeX = CRIGHT + 16;
    ctx.fillStyle = '#f1f5f9';
    ctx.fillRect(gaugeX, CTOP + 10, 12, gaugeH);
    ctx.strokeStyle = '#cbd5e1'; ctx.lineWidth = 1;
    ctx.strokeRect(gaugeX, CTOP + 10, 12, gaugeH);

    const gaugeGrad = ctx.createLinearGradient(0, CTOP + 10 + gaugeH, 0, CTOP + 10);
    gaugeGrad.addColorStop(0, '#10b981');
    gaugeGrad.addColorStop(0.5, '#f59e0b');
    gaugeGrad.addColorStop(1, '#ef4444');
    ctx.fillStyle = gaugeGrad;
    ctx.fillRect(gaugeX, CTOP + 10 + gaugeH - gaugeFill, 12, gaugeFill);

    ctx.fillStyle = '#475569'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'left';
    ctx.fillText('P', gaugeX + 2, CTOP - 2);
    ctx.fillStyle = '#6366f1'; ctx.font = 'bold 11px system-ui';
    ctx.fillText(`${currentPressure.toFixed(0)} kPa`, gaugeX - 2, CBOTTOM + 20);

    // Particles
    for (const p of particles.current) {
      p.x += p.vx * speedFactor;
      p.y += p.vy * speedFactor;
      if (p.x < CLEFT + 5)   { p.x = CLEFT + 5;   p.vx = Math.abs(p.vx); }
      if (p.x > CRIGHT - 5)  { p.x = CRIGHT - 5;  p.vx = -Math.abs(p.vx); }
      if (p.y < CTOP + 5)    { p.y = CTOP + 5;    p.vy = Math.abs(p.vy); }
      if (p.y > CBOTTOM - 5) { p.y = CBOTTOM - 5; p.vy = -Math.abs(p.vy); }

      ctx.beginPath();
      ctx.arc(p.x, p.y, 4, 0, Math.PI * 2);
      ctx.fillStyle = `rgba(${Math.round(99 + heat * 120)},102,${Math.round(241 - heat * 141)},0.85)`;
      ctx.fill();
    }

    // Temperature label
    ctx.fillStyle = '#64748b'; ctx.font = '11px system-ui'; ctx.textAlign = 'left';
    ctx.fillText(`T = ${temp} K`, CLEFT, h - 8);
    ctx.fillText(`V = fixed`, CLEFT, h + 8);

    rafRef.current = requestAnimationFrame(draw);
  }, [CX, CBOTTOM, CHEIGHT, CLEFT, CRIGHT, CWIDTH, CTOP]);

  useEffect(() => {
    rafRef.current = requestAnimationFrame(draw);
    return () => cancelAnimationFrame(rafRef.current);
  }, [draw]);

  return (
    <canvas ref={canvasRef} width={width} height={height}
      className="w-full rounded-xl border border-gray-200 bg-white" style={{ display: 'block' }} />
  );
}
