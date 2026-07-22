'use client';
import { useRef, useEffect, useCallback } from 'react';
import { lambdaMinNm, electronSpeedFraction, MO_EXCITATION_KV } from '@/lib/physics/xrays';

interface Props {
  kV: number;          // tube voltage in kilovolts
  current: number;     // filament current 1–10 (relative)
  isRunning: boolean; isPaused: boolean;
  width?: number; height?: number;
}

interface Beam { x: number; y: number; }
interface Ray { p: number; ang: number; }

export function XrayCanvas({ kV, current, isRunning, isPaused, width = 640, height = 300 }: Props) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const rafRef = useRef<number>(0);
  const tRef = useRef(0);
  const lastFrameRef = useRef<number | null>(null);
  const electronsRef = useRef<Beam[]>([]);
  const raysRef = useRef<Ray[]>([]);
  const accRef = useRef(0);
  const sim = useRef({ kV, current, isRunning, isPaused });
  sim.current = { kV, current, isRunning, isPaused };

  useEffect(() => {
    tRef.current = 0; lastFrameRef.current = null;
    electronsRef.current = []; raysRef.current = []; accRef.current = 0;
  }, [kV, current]);

  const draw = useCallback((timestamp?: number) => {
    const canvas = canvasRef.current; if (!canvas) return;
    const ctx = canvas.getContext('2d'); if (!ctx) return;
    const s = sim.current;
    const W = canvas.width, H = canvas.height;

    let dt = 0;
    if (s.isRunning && !s.isPaused && timestamp !== undefined) {
      if (lastFrameRef.current !== null) {
        dt = Math.min((timestamp - lastFrameRef.current) / 1000, 0.1);
        tRef.current += dt;
      }
      lastFrameRef.current = timestamp;
    } else {
      lastFrameRef.current = timestamp ?? null;
    }

    const cathX = 110, anodeX = W - 170, beamY = 120;
    const eSpeed = 120 + s.kV * 3; // px/s ∝ ish √V feel, readable

    if (dt > 0) {
      accRef.current += dt * s.current * 3;
      while (accRef.current >= 1) {
        accRef.current -= 1;
        electronsRef.current.push({ x: cathX + 8, y: beamY + (Math.random() - 0.5) * 14 });
      }
      electronsRef.current.forEach(e => { e.x += eSpeed * dt; });
      const arrived = electronsRef.current.filter(e => e.x >= anodeX).length;
      electronsRef.current = electronsRef.current.filter(e => e.x < anodeX);
      for (let i = 0; i < arrived; i++) {
        // ~1% of electron energy becomes X-rays (rest is heat) — but we draw
        // a ray per impact so the physics is visible.
        raysRef.current.push({ p: 0, ang: Math.PI / 2 + (Math.random() - 0.5) * 0.9 });
      }
      raysRef.current.forEach(r => { r.p += dt * 220; });
      raysRef.current = raysRef.current.filter(r => r.p < 180);
    }

    ctx.clearRect(0, 0, W, H);
    ctx.fillStyle = '#f8fafc'; ctx.fillRect(0, 0, W, H);

    // Evacuated glass tube
    ctx.save();
    ctx.strokeStyle = '#cbd5e1'; ctx.lineWidth = 3;
    ctx.beginPath();
    ctx.roundRect(70, 60, W - 200, 120, 40);
    ctx.stroke();
    ctx.fillStyle = 'rgba(226,232,240,0.25)'; ctx.fill();
    ctx.fillStyle = '#94a3b8'; ctx.font = '9px system-ui'; ctx.textAlign = 'left';
    ctx.fillText('evacuated tube', 82, 76);
    ctx.restore();

    // Cathode (heated filament)
    ctx.save();
    ctx.strokeStyle = '#f59e0b'; ctx.lineWidth = 3;
    ctx.beginPath();
    for (let i = 0; i < 4; i++) {
      ctx.arc(cathX, beamY - 12 + i * 8, 4, Math.PI * 0.5, Math.PI * 1.5, i % 2 === 0);
    }
    ctx.stroke();
    const glow = ctx.createRadialGradient(cathX, beamY, 2, cathX, beamY, 26);
    glow.addColorStop(0, 'rgba(251,191,36,0.5)'); glow.addColorStop(1, 'transparent');
    ctx.fillStyle = glow;
    ctx.beginPath(); ctx.arc(cathX, beamY, 26, 0, Math.PI * 2); ctx.fill();
    ctx.fillStyle = '#92400e'; ctx.font = 'bold 9px system-ui'; ctx.textAlign = 'center';
    ctx.fillText('cathode (−)', cathX, beamY + 44);
    ctx.fillText('hot filament', cathX, beamY + 55);
    ctx.restore();

    // Anode: angled tungsten/molybdenum target block
    ctx.save();
    ctx.fillStyle = '#64748b';
    ctx.beginPath();
    ctx.moveTo(anodeX, beamY - 34);
    ctx.lineTo(anodeX + 46, beamY - 34);
    ctx.lineTo(anodeX + 46, beamY + 34);
    ctx.lineTo(anodeX, beamY + 34);
    ctx.closePath(); ctx.fill();
    // Angled face
    ctx.fillStyle = '#475569';
    ctx.beginPath();
    ctx.moveTo(anodeX, beamY - 34);
    ctx.lineTo(anodeX + 18, beamY + 34);
    ctx.lineTo(anodeX, beamY + 34);
    ctx.closePath(); ctx.fill();
    ctx.fillStyle = '#334155'; ctx.font = 'bold 9px system-ui'; ctx.textAlign = 'center';
    ctx.fillText('anode (+)', anodeX + 24, beamY - 42);
    ctx.fillText('Mo target', anodeX + 24, beamY + 48);
    ctx.restore();

    // Electron beam
    ctx.save();
    electronsRef.current.forEach(e => {
      ctx.beginPath(); ctx.arc(e.x, e.y, 3, 0, Math.PI * 2);
      ctx.fillStyle = '#0ea5e9'; ctx.fill();
    });
    ctx.restore();

    // X-rays: wavy rays leaving the target downward through a window
    ctx.save();
    ctx.strokeStyle = '#8b5cf6'; ctx.lineWidth = 1.6;
    raysRef.current.forEach(r => {
      const ox = anodeX + 8, oy = beamY + 10;
      ctx.beginPath();
      for (let d = Math.max(0, r.p - 34); d <= r.p; d += 3) {
        const wob = Math.sin(d * 0.55) * 3;
        const x = ox + Math.cos(r.ang) * d - Math.sin(r.ang) * wob;
        const y = oy + Math.sin(r.ang) * d + Math.cos(r.ang) * wob;
        if (d === Math.max(0, r.p - 34)) ctx.moveTo(x, y); else ctx.lineTo(x, y);
      }
      ctx.stroke();
    });
    ctx.fillStyle = '#7c3aed'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
    ctx.fillText('X-rays', anodeX + 8, H - 40);
    ctx.restore();

    // HV supply annotation
    ctx.save();
    ctx.strokeStyle = '#94a3b8'; ctx.lineWidth = 1.5; ctx.setLineDash([5, 4]);
    ctx.beginPath(); ctx.moveTo(cathX, 60); ctx.lineTo(cathX, 34); ctx.lineTo(anodeX + 24, 34); ctx.lineTo(anodeX + 24, 60); ctx.stroke();
    ctx.setLineDash([]);
    ctx.fillStyle = '#475569'; ctx.font = 'bold 11px system-ui'; ctx.textAlign = 'center';
    ctx.fillText(`${s.kV} kV`, (cathX + anodeX) / 2, 28);
    ctx.restore();

    // Status
    ctx.fillStyle = s.kV >= MO_EXCITATION_KV ? '#059669' : '#64748b';
    ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
    ctx.fillText(
      s.kV >= MO_EXCITATION_KV
        ? 'V above 20 kV — characteristic Kα/Kβ lines appear in the spectrum'
        : 'Continuous (bremsstrahlung) spectrum only — raise V past 20 kV for the K lines',
      W / 2, H - 24,
    );

    ctx.fillStyle = '#64748b'; ctx.font = '10px system-ui'; ctx.textAlign = 'left';
    ctx.fillText(`λmin = hc/eV = ${lambdaMinNm(s.kV).toFixed(4)} nm   e⁻ speed ≈ ${(electronSpeedFraction(s.kV) * 100).toFixed(0)}% of c   ~99% of the energy becomes HEAT in the anode`, 8, H - 8);

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
