'use client';
import { useRef, useEffect, useCallback } from 'react';
import { idealGasPressure } from '@/lib/physics/gas-laws';

interface IdealGasCanvasProps {
  pressure: number;    // kPa
  volume: number;      // L
  temperature: number; // K
  moles: number;
  solveFor: 'P' | 'V' | 'T' | 'n';
  width?: number;
  height?: number;
}

interface Particle { x: number; y: number; vx: number; vy: number; }

const CLEFT = 60, CTOP = 30, CWIDTH = 160, CHEIGHT = 200;
const CRIGHT = CLEFT + CWIDTH;
const CBOTTOM = CTOP + CHEIGHT;

export function IdealGasCanvas({ pressure, volume, temperature, moles, width = 320, height = 300 }: IdealGasCanvasProps) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const rafRef = useRef<number>(0);
  const particles = useRef<Particle[]>([]);
  const sim = useRef({ pressure, volume, temperature, moles, width, height });
  sim.current = { pressure, volume, temperature, moles, width, height };

  useEffect(() => {
    const count = Math.max(8, Math.min(Math.round(moles * 60), 60));
    particles.current = Array.from({ length: count }, () => ({
      x: CLEFT + 8 + Math.random() * (CWIDTH - 16),
      y: CTOP + 8 + Math.random() * (CHEIGHT - 16),
      vx: (Math.random() - 0.5) * 2,
      vy: (Math.random() - 0.5) * 2,
    }));
  }, [moles]);

  const draw = useCallback(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;
    const { temperature: T, moles: n, volume: V } = sim.current;

    const pKpa = idealGasPressure(n, T, V) / 1000;
    const heat = Math.min((T - 100) / 500, 1);
    const speedFactor = Math.sqrt(T / 300);
    const count = Math.max(8, Math.min(Math.round(n * 60), 60));

    // Adjust particle count smoothly
    while (particles.current.length < count) {
      particles.current.push({
        x: CLEFT + 8 + Math.random() * (CWIDTH - 16),
        y: CTOP + 8 + Math.random() * (CHEIGHT - 16),
        vx: (Math.random() - 0.5) * 2,
        vy: (Math.random() - 0.5) * 2,
      });
    }
    if (particles.current.length > count) particles.current.length = count;

    ctx.clearRect(0, 0, canvas.width, canvas.height);

    // Container
    const fillR = Math.round(219 + heat * 36);
    const fillG = Math.round(234 - heat * 114);
    const fillB = Math.round(254 - heat * 154);
    ctx.fillStyle = `rgba(${fillR},${fillG},${fillB},0.25)`;
    ctx.fillRect(CLEFT, CTOP, CWIDTH, CHEIGHT);
    ctx.strokeStyle = '#64748b'; ctx.lineWidth = 2;
    ctx.strokeRect(CLEFT, CTOP, CWIDTH, CHEIGHT);

    // Volume label
    ctx.fillStyle = '#94a3b8'; ctx.font = '10px system-ui'; ctx.textAlign = 'center';
    ctx.fillText(`V = ${V.toFixed(1)} L`, CLEFT + CWIDTH / 2, CTOP - 8);

    // Particles
    for (const p of particles.current) {
      p.x += p.vx * speedFactor;
      p.y += p.vy * speedFactor;
      if (p.x < CLEFT + 5)    { p.x = CLEFT + 5;    p.vx = Math.abs(p.vx); }
      if (p.x > CRIGHT - 5)   { p.x = CRIGHT - 5;   p.vx = -Math.abs(p.vx); }
      if (p.y < CTOP + 5)     { p.y = CTOP + 5;     p.vy = Math.abs(p.vy); }
      if (p.y > CBOTTOM - 5)  { p.y = CBOTTOM - 5;  p.vy = -Math.abs(p.vy); }
      ctx.beginPath();
      ctx.arc(p.x, p.y, 4, 0, Math.PI * 2);
      ctx.fillStyle = `rgba(${Math.round(99 + heat * 120)},102,${Math.round(241 - heat * 141)},0.85)`;
      ctx.fill();
    }

    // PV = nRT readout
    const labels = [
      { label: 'P', value: `${pKpa.toFixed(1)} kPa`, color: '#6366f1' },
      { label: 'V', value: `${V.toFixed(1)} L`,       color: '#10b981' },
      { label: 'n', value: `${n.toFixed(2)} mol`,     color: '#f59e0b' },
      { label: 'T', value: `${T} K`,                  color: '#ef4444' },
    ];
    labels.forEach((l, i) => {
      const lx = CRIGHT + 20;
      const ly = CTOP + 30 + i * 42;
      ctx.fillStyle = l.color; ctx.font = 'bold 11px system-ui'; ctx.textAlign = 'left';
      ctx.fillText(l.label, lx, ly);
      ctx.fillStyle = '#1e293b'; ctx.font = '11px system-ui';
      ctx.fillText(l.value, lx + 14, ly);
    });

    // PV = nRT verification
    const pv = pKpa * 1000 * V * 0.001;
    const nrt = n * 8.314 * T;
    ctx.fillStyle = '#94a3b8'; ctx.font = '10px monospace'; ctx.textAlign = 'center';
    ctx.fillText('PV = nRT', CLEFT + CWIDTH / 2, CBOTTOM + 20);
    ctx.fillStyle = '#6366f1'; ctx.font = 'bold 10px monospace';
    ctx.fillText(`${pv.toFixed(1)} ≈ ${nrt.toFixed(1)} J`, CLEFT + CWIDTH / 2, CBOTTOM + 34);

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
