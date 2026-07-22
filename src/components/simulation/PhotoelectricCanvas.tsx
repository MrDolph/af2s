'use client';
import { useRef, useEffect, useCallback } from 'react';
import { keMaxEV, thresholdF14, lightColor, wavelengthNm } from '@/lib/physics/photoelectric';

interface Props {
  f14: number;         // frequency in 10¹⁴ Hz
  intensity: number;   // 1–10 (relative)
  phiEV: number;       // work function
  metalName: string;
  isRunning: boolean; isPaused: boolean;
  width?: number; height?: number;
}

interface Electron { x: number; y: number; vx: number; }
interface Photon { x: number; y: number; }

export function PhotoelectricCanvas({ f14, intensity, phiEV, metalName, isRunning, isPaused, width = 640, height = 300 }: Props) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const rafRef = useRef<number>(0);
  const tRef = useRef(0);
  const lastFrameRef = useRef<number | null>(null);
  const electronsRef = useRef<Electron[]>([]);
  const photonsRef = useRef<Photon[]>([]);
  const emitAccRef = useRef(0);
  const collectedRef = useRef(0);
  const sim = useRef({ f14, intensity, phiEV, metalName, isRunning, isPaused });
  sim.current = { f14, intensity, phiEV, metalName, isRunning, isPaused };

  useEffect(() => {
    tRef.current = 0; lastFrameRef.current = null;
    electronsRef.current = []; photonsRef.current = [];
    emitAccRef.current = 0; collectedRef.current = 0;
  }, [f14, intensity, phiEV]);

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

    const ke = keMaxEV(s.f14, s.phiEV);
    const emits = ke > 0;
    const plateX = 90, collX = W - 70;
    const beamColor = lightColor(s.f14);

    // Spawn photons streaming towards the plate; rate ∝ intensity.
    if (dt > 0) {
      emitAccRef.current += dt * s.intensity * 4;
      while (emitAccRef.current >= 1) {
        emitAccRef.current -= 1;
        photonsRef.current.push({ x: 0, y: 0 }); // param along beam 0→1
        // Each absorbed photon MAY free one electron (if above threshold).
        if (emits) {
          // Speed on screen ∝ √KE — doubling KE does not double speed.
          const px = plateX + 6;
          const py = 60 + Math.random() * (H - 140);
          electronsRef.current.push({ x: px, y: py, vx: 40 + Math.sqrt(ke) * 90 });
        }
      }
      photonsRef.current.forEach(p => { p.x += dt * 1.6; });
      photonsRef.current = photonsRef.current.filter(p => p.x < 1);
      electronsRef.current.forEach(e => { e.x += e.vx * dt; });
      const before = electronsRef.current.length;
      electronsRef.current = electronsRef.current.filter(e => e.x < collX);
      collectedRef.current += before - electronsRef.current.length;
    }

    ctx.clearRect(0, 0, W, H);
    ctx.fillStyle = '#f8fafc'; ctx.fillRect(0, 0, W, H);

    // Light source (top-left) + beam onto the plate
    const srcX = 20, srcY = 26;
    ctx.save();
    ctx.fillStyle = beamColor;
    ctx.beginPath(); ctx.arc(srcX, srcY, 10, 0, Math.PI * 2); ctx.fill();
    ctx.globalAlpha = 0.14 + s.intensity * 0.02;
    ctx.beginPath();
    ctx.moveTo(srcX, srcY);
    ctx.lineTo(plateX, 50); ctx.lineTo(plateX, H - 70); ctx.closePath();
    ctx.fillStyle = beamColor; ctx.fill();
    ctx.restore();
    // Photons as short dashes travelling down the beam
    ctx.save();
    ctx.strokeStyle = beamColor; ctx.lineWidth = 2;
    photonsRef.current.forEach(p => {
      const bx = srcX + (plateX - srcX) * p.x;
      const by = srcY + ((H / 2 - 10) - srcY) * p.x + Math.sin(p.x * 40) * 6;
      ctx.beginPath(); ctx.moveTo(bx - 5, by); ctx.lineTo(bx + 5, by); ctx.stroke();
    });
    ctx.restore();

    // Metal plate (emitter)
    ctx.fillStyle = '#64748b';
    ctx.fillRect(plateX - 10, 50, 10, H - 120);
    ctx.fillStyle = '#334155'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
    ctx.fillText(s.metalName, plateX - 5, H - 56);
    ctx.font = '9px system-ui'; ctx.fillStyle = '#64748b';
    ctx.fillText(`φ = ${s.phiEV} eV`, plateX - 5, H - 44);

    // Collector
    ctx.fillStyle = '#94a3b8';
    ctx.fillRect(collX, 50, 8, H - 120);
    ctx.fillStyle = '#64748b'; ctx.font = '9px system-ui';
    ctx.fillText('collector', collX + 4, H - 56);

    // Photoelectrons
    ctx.save();
    electronsRef.current.forEach(e => {
      ctx.beginPath(); ctx.arc(e.x, e.y, 3.5, 0, Math.PI * 2);
      ctx.fillStyle = '#0ea5e9'; ctx.fill();
      ctx.fillStyle = '#0369a1'; ctx.font = '8px system-ui'; ctx.textAlign = 'center';
      ctx.fillText('e⁻', e.x, e.y - 6);
    });
    ctx.restore();

    // Status banner
    ctx.textAlign = 'center'; ctx.font = 'bold 11px system-ui';
    if (!emits) {
      ctx.fillStyle = '#ef4444';
      ctx.fillText(`NO EMISSION — f below threshold f₀ = ${thresholdF14(s.phiEV).toFixed(2)}×10¹⁴ Hz (however bright the light!)`, W / 2, 24);
    } else {
      ctx.fillStyle = '#059669';
      ctx.fillText(`Emitting: KEmax = ${ke.toFixed(2)} eV per electron — intensity changes HOW MANY, not how fast`, W / 2, 24);
    }

    // HUD
    ctx.fillStyle = '#64748b'; ctx.font = '10px system-ui'; ctx.textAlign = 'left';
    ctx.fillText(`f = ${s.f14.toFixed(2)}×10¹⁴ Hz (λ ≈ ${wavelengthNm(s.f14).toFixed(0)} nm)   intensity = ${s.intensity}   collected: ${collectedRef.current} e⁻   t = ${tRef.current.toFixed(1)}s`, 8, H - 10);

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
