'use client';
import { useRef, useEffect, useCallback } from 'react';
import { bifilarPeriodSimple, cantileverStiffness } from '@/lib/physics/shm';

type Mode = 'bifilar' | 'cantilever';

interface Props {
  mode: Mode; mass: number; rodLength: number;
  wireLength: number; separation: number;
  beamLength: number; beamWidth: number; beamHeight: number;
  youngModulus: number; load: number;
  isRunning: boolean; isPaused: boolean;
  onTick?: (t: number) => void;
  width?: number; height?: number;
}

export function BifilarCanvas({
  mode, mass, rodLength, wireLength, separation,
  beamLength, beamWidth, beamHeight, youngModulus, load,
  isRunning, isPaused, onTick, width = 380, height = 300
}: Props) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const rafRef = useRef<number>(0);
  const tRef = useRef(0);
  const lastFrameRef = useRef<number | null>(null);
  const sim = useRef({ mode, mass, rodLength, wireLength, separation, beamLength, beamWidth, beamHeight, youngModulus, load, isRunning, isPaused, onTick });
  sim.current = { mode, mass, rodLength, wireLength, separation, beamLength, beamWidth, beamHeight, youngModulus, load, isRunning, isPaused, onTick };

  useEffect(() => { tRef.current = 0; lastFrameRef.current = null; }, [mode, mass, rodLength, wireLength, separation, beamLength, beamHeight, youngModulus, load]);

  const draw = useCallback((timestamp?: number) => {
    const canvas = canvasRef.current; if (!canvas) return;
    const ctx = canvas.getContext('2d'); if (!ctx) return;
    const s = sim.current;
    const W = canvas.width, H = canvas.height;

    // Real wall-clock dt (see PendulumCanvas) — animation time == true
    // seconds at any refresh rate, so the graph marker stays in sync.
    if (s.isRunning && !s.isPaused && timestamp !== undefined) {
      if (lastFrameRef.current !== null) {
        tRef.current += Math.min((timestamp - lastFrameRef.current) / 1000, 0.1);
      }
      lastFrameRef.current = timestamp;
    } else {
      lastFrameRef.current = timestamp ?? null;
    }
    s.onTick?.(tRef.current);

    ctx.clearRect(0, 0, W, H);
    ctx.fillStyle = '#f8fafc'; ctx.fillRect(0, 0, W, H);

    if (s.mode === 'bifilar') {
      const T = bifilarPeriodSimple(s.mass, s.rodLength, s.wireLength, s.separation / 2);
      const omega = 2 * Math.PI / T;
      // cos, not sin — matches the graph's x = A·cos(ωt) convention, so the
      // rod starts at maximum twist exactly where the plotted curve starts at +A.
      const phi = 0.3 * Math.cos(omega * tRef.current); // torsion angle

      const cx = W / 2, ceilY = 20;
      const rodY = ceilY + s.wireLength * 80;
      const rodHalfL = s.rodLength * 60;

      // Ceiling
      ctx.fillStyle = '#64748b'; ctx.fillRect(cx - 60, 0, 120, 12);

      // Wires (twisted perspective)
      const w1x = cx - s.separation * 40 * Math.cos(phi);
      const w2x = cx + s.separation * 40 * Math.cos(phi);
      const rodLeft  = cx - rodHalfL * Math.cos(phi);
      const rodRight = cx + rodHalfL * Math.cos(phi);

      ctx.strokeStyle = '#94a3b8'; ctx.lineWidth = 1.5;
      ctx.beginPath(); ctx.moveTo(cx - s.separation * 40, ceilY + 12); ctx.lineTo(rodLeft, rodY); ctx.stroke();
      ctx.beginPath(); ctx.moveTo(cx + s.separation * 40, ceilY + 12); ctx.lineTo(rodRight, rodY); ctx.stroke();

      // Attachment points on ceiling
      ctx.fillStyle = '#475569';
      ctx.beginPath(); ctx.arc(cx - s.separation * 40, ceilY + 12, 4, 0, Math.PI * 2); ctx.fill();
      ctx.beginPath(); ctx.arc(cx + s.separation * 40, ceilY + 12, 4, 0, Math.PI * 2); ctx.fill();

      // Rod (rotating)
      const rodThick = 10;
      ctx.save();
      ctx.fillStyle = '#4f46e5';
      ctx.beginPath();
      ctx.moveTo(rodLeft, rodY - rodThick / 2);
      ctx.lineTo(rodRight, rodY - rodThick / 2);
      ctx.lineTo(rodRight, rodY + rodThick / 2);
      ctx.lineTo(rodLeft, rodY + rodThick / 2);
      ctx.closePath(); ctx.fill();
      ctx.strokeStyle = '#3730a3'; ctx.lineWidth = 1; ctx.stroke();
      // Mass label
      ctx.fillStyle = 'white'; ctx.font = 'bold 9px system-ui'; ctx.textAlign = 'center';
      ctx.fillText(`${s.mass}kg`, cx, rodY + 4);
      ctx.restore();

      // Angle indicator
      ctx.fillStyle = '#f59e0b'; ctx.font = '10px system-ui'; ctx.textAlign = 'center';
      ctx.fillText(`φ=${(phi * 180 / Math.PI).toFixed(1)}°`, cx, rodY + 30);
      ctx.fillStyle = '#64748b';
      ctx.fillText(`T=${T.toFixed(3)}s  I=mL²/12=${(s.mass * s.rodLength ** 2 / 12).toFixed(3)} kg·m²`, cx, H - 8);

    } else {
      // Cantilever
      const k = cantileverStiffness(s.youngModulus * 1e9, s.beamWidth / 100, s.beamHeight / 100, s.beamLength);
      const deflection = s.load / k; // metres
      const dispPx = Math.min(deflection * 2000, 80); // pixels
      const omega_c = Math.sqrt(k / s.mass);

      // Static + dynamic deflection
      const dynamicPx = s.isRunning ? dispPx + 0.3 * dispPx * Math.cos(omega_c * tRef.current) : dispPx;

      const wallX = 40, beamY = H / 2 - 10;
      const beamLenPx = W - 100;
      const beamThPx = Math.max(8, s.beamHeight * 8);

      // Wall
      ctx.fillStyle = '#94a3b8';
      ctx.fillRect(0, beamY - 40, wallX, 80);
      for (let y = beamY - 40; y < beamY + 40; y += 10) {
        ctx.strokeStyle = '#64748b'; ctx.lineWidth = 1;
        ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(wallX - 5, y + 5); ctx.stroke();
      }

      // Beam (slightly curved for deflection)
      ctx.save();
      ctx.beginPath();
      ctx.moveTo(wallX, beamY);
      const tipX = wallX + beamLenPx;
      const tipY = beamY + dynamicPx;
      // Cubic Bezier for beam deflection shape
      ctx.bezierCurveTo(
        wallX + beamLenPx * 0.6, beamY,
        wallX + beamLenPx * 0.9, beamY + dynamicPx * 0.7,
        tipX, tipY
      );
      ctx.lineTo(tipX, tipY + beamThPx);
      ctx.bezierCurveTo(
        wallX + beamLenPx * 0.9, beamY + dynamicPx * 0.7 + beamThPx,
        wallX + beamLenPx * 0.6, beamY + beamThPx,
        wallX, beamY + beamThPx
      );
      ctx.closePath();
      const beamGrad = ctx.createLinearGradient(0, beamY, 0, beamY + beamThPx);
      beamGrad.addColorStop(0, '#818cf8'); beamGrad.addColorStop(1, '#4f46e5');
      ctx.fillStyle = beamGrad; ctx.fill();
      ctx.strokeStyle = '#3730a3'; ctx.lineWidth = 1; ctx.stroke();
      ctx.restore();

      // Load (hanging weight)
      if (s.load > 0) {
        ctx.strokeStyle = '#64748b'; ctx.lineWidth = 1.5;
        ctx.beginPath(); ctx.moveTo(tipX, tipY + beamThPx); ctx.lineTo(tipX, tipY + beamThPx + 25); ctx.stroke();
        ctx.fillStyle = '#ef4444';
        ctx.beginPath(); ctx.roundRect(tipX - 20, tipY + beamThPx + 25, 40, 28, 4); ctx.fill();
        ctx.fillStyle = 'white'; ctx.font = 'bold 9px system-ui'; ctx.textAlign = 'center';
        ctx.fillText(`${s.load}N`, tipX, tipY + beamThPx + 42);
      }

      // Deflection arrow
      ctx.strokeStyle = '#f59e0b'; ctx.lineWidth = 1.5; ctx.setLineDash([3, 3]);
      ctx.beginPath(); ctx.moveTo(tipX + 18, beamY); ctx.lineTo(tipX + 18, tipY); ctx.stroke();
      ctx.setLineDash([]);
      ctx.fillStyle = '#f59e0b'; ctx.font = '9px system-ui'; ctx.textAlign = 'left';
      ctx.fillText(`δ=${deflection.toFixed(4)}m`, tipX + 22, (beamY + tipY) / 2 + 4);

      // Fixed end label
      ctx.fillStyle = '#64748b'; ctx.font = '9px system-ui'; ctx.textAlign = 'center';
      ctx.fillText('Fixed end', wallX / 2, beamY - 50);
      ctx.fillText(`k=${k.toFixed(0)} N/m  T=${(2*Math.PI/omega_c).toFixed(3)}s`, W / 2, H - 8);
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
