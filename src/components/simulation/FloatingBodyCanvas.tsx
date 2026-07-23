'use client';
import { useRef, useEffect, useCallback } from 'react';
import { submergedFraction, sinkingAcceleration, upthrust, willFloat, dampedStepResponse, G } from '@/lib/physics/equilibrium';

interface Props {
  objDensity: number;   // kg/m³
  liquidDensity: number;
  liquidName: string;
  blockHeight: number;  // m (visual/physics height of the block)
  isRunning: boolean; isPaused: boolean;
  onTick?: (submergedFrac: number, settled: boolean) => void;
  width?: number; height?: number;
}

export const BLOCK_WIDTH_M = 0.3;
const PX_PER_M = 260;

export function FloatingBodyCanvas({
  objDensity, liquidDensity, liquidName, blockHeight, isRunning, isPaused, onTick,
  width = 640, height = 300,
}: Props) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const rafRef = useRef<number>(0);
  const lastFrameRef = useRef<number | null>(null);
  const t = useRef(0);
  const sunkDepth = useRef(0); // for the sinking case: distance fallen below the surface
  const settled = useRef(false);
  const simRef = useRef({ objDensity, liquidDensity, liquidName, blockHeight, isRunning, isPaused, onTick });
  simRef.current = { objDensity, liquidDensity, liquidName, blockHeight, isRunning, isPaused, onTick };

  useEffect(() => {
    t.current = 0; sunkDepth.current = 0; settled.current = false; lastFrameRef.current = null;
  }, [objDensity, liquidDensity, blockHeight]);

  const draw = useCallback((timestamp?: number) => {
    const canvas = canvasRef.current; if (!canvas) return;
    const ctx = canvas.getContext('2d'); if (!ctx) return;
    const s = simRef.current;
    const W = canvas.width, H = canvas.height;

    let dt = 0;
    if (s.isRunning && !s.isPaused && timestamp !== undefined) {
      if (lastFrameRef.current !== null) dt = Math.min((timestamp - lastFrameRef.current) / 1000, 0.1);
      lastFrameRef.current = timestamp;
    } else {
      lastFrameRef.current = timestamp ?? null;
    }

    const floats = willFloat(s.objDensity, s.liquidDensity);
    const surfaceY = H * 0.4;
    const containerBottom = H - 20;
    const maxSinkPx = containerBottom - surfaceY - 20;

    let submergedPx: number; // how much of the block is below the surface line, in px
    if (floats) {
      const eqSubmergedM = s.blockHeight * submergedFraction(s.objDensity, s.liquidDensity);
      const eqSubmergedPx = eqSubmergedM * PX_PER_M;
      const mass = s.objDensity * BLOCK_WIDTH_M * s.blockHeight;
      const kEff = s.liquidDensity * G * BLOCK_WIDTH_M;
      submergedPx = s.isRunning ? dampedStepResponse(t.current, eqSubmergedPx, kEff, mass) : 0;
      if (dt > 0) t.current += dt;
      if (!settled.current && Math.abs(submergedPx - eqSubmergedPx) < eqSubmergedPx * 0.02) settled.current = true;
    } else {
      // A literal SI-accurate fall would either finish in a blink (dense
      // objects) or take unrealistically long (barely-denser ones) inside
      // a small stylised container. Instead, approach the container floor
      // exponentially, with a rate tied to the real sinking acceleration —
      // so denser objects still visibly sink faster than barely-denser
      // ones, bounded to a watchable ~1-3s range regardless of slider values.
      const rate = 0.5 + (Math.abs(sinkingAcceleration(s.objDensity, s.liquidDensity)) / G) * 2;
      if (dt > 0 && !settled.current) {
        t.current += dt;
        sunkDepth.current = maxSinkPx * (1 - Math.exp(-t.current * rate));
        if (sunkDepth.current >= maxSinkPx * 0.98) { sunkDepth.current = maxSinkPx; settled.current = true; }
      }
      submergedPx = Math.min(s.blockHeight * PX_PER_M, sunkDepth.current + s.blockHeight * PX_PER_M);
    }
    s.onTick?.(floats ? Math.min(submergedPx / (s.blockHeight * PX_PER_M), 1) : 1, settled.current);

    ctx.clearRect(0, 0, W, H);
    ctx.fillStyle = '#f8fafc'; ctx.fillRect(0, 0, W, H);

    // Container
    const contL = W * 0.18, contR = W * 0.82;
    ctx.strokeStyle = '#94a3b8'; ctx.lineWidth = 2;
    ctx.beginPath(); ctx.moveTo(contL, 20); ctx.lineTo(contL, containerBottom); ctx.lineTo(contR, containerBottom); ctx.lineTo(contR, 20); ctx.stroke();

    // Liquid
    ctx.fillStyle = 'rgba(96,165,250,0.35)';
    ctx.fillRect(contL, surfaceY, contR - contL, containerBottom - surfaceY);
    ctx.strokeStyle = 'rgba(59,130,246,0.6)'; ctx.lineWidth = 1.5;
    ctx.beginPath(); ctx.moveTo(contL, surfaceY); ctx.lineTo(contR, surfaceY); ctx.stroke();
    ctx.fillStyle = '#2563eb'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'left';
    ctx.fillText(`${s.liquidName} (ρ=${s.liquidDensity} kg/m³)`, contL + 8, surfaceY - 8);

    // Block
    const blockWpx = BLOCK_WIDTH_M * PX_PER_M;
    const blockHpx = s.blockHeight * PX_PER_M;
    const bx = (contL + contR) / 2 - blockWpx / 2;
    const by = surfaceY + submergedPx - blockHpx;
    ctx.fillStyle = floats ? '#a78bfa' : '#94a3b8';
    ctx.fillRect(bx, by, blockWpx, blockHpx);
    ctx.strokeStyle = floats ? '#7c3aed' : '#475569'; ctx.lineWidth = 2;
    ctx.strokeRect(bx, by, blockWpx, blockHpx);
    ctx.fillStyle = 'white'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
    ctx.fillText(`ρ=${s.objDensity}`, bx + blockWpx / 2, by + blockHpx / 2 + 4);

    // Upthrust / weight arrows once the run has started
    if (s.isRunning) {
      const V = BLOCK_WIDTH_M * s.blockHeight;
      const Vsub = BLOCK_WIDTH_M * (submergedPx / PX_PER_M);
      const U = upthrust(s.liquidDensity, Vsub);
      const Wt = s.objDensity * G * V;
      const cx0 = bx + blockWpx / 2;
      const scaleN = 30 / Math.max(Wt, U, 1);
      // Weight (down, red)
      ctx.strokeStyle = '#ef4444'; ctx.lineWidth = 2;
      ctx.beginPath(); ctx.moveTo(cx0 - 14, by + blockHpx); ctx.lineTo(cx0 - 14, by + blockHpx + Wt * scaleN); ctx.stroke();
      ctx.fillStyle = '#ef4444'; ctx.font = 'bold 9px system-ui'; ctx.textAlign = 'center';
      ctx.fillText(`W=${Wt.toFixed(0)}N`, cx0 - 14, by + blockHpx + Wt * scaleN + 12);
      // Upthrust (up, blue)
      ctx.strokeStyle = '#2563eb'; ctx.lineWidth = 2;
      ctx.beginPath(); ctx.moveTo(cx0 + 14, by + blockHpx); ctx.lineTo(cx0 + 14, by + blockHpx - U * scaleN); ctx.stroke();
      ctx.fillStyle = '#2563eb';
      ctx.fillText(`U=${U.toFixed(0)}N`, cx0 + 14, by + blockHpx - U * scaleN - 6);
    }

    // Status
    ctx.font = 'bold 11px system-ui'; ctx.textAlign = 'center';
    if (floats) {
      ctx.fillStyle = '#059669';
      ctx.fillText(`FLOATS — ${(submergedFraction(s.objDensity, s.liquidDensity) * 100).toFixed(0)}% submerged at equilibrium (Archimedes: weight = upthrust)`, W / 2, 20);
    } else {
      ctx.fillStyle = '#dc2626';
      ctx.fillText(`SINKS — object denser than the liquid, upthrust can never equal its weight`, W / 2, 20);
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
