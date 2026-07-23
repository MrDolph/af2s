'use client';
import { useRef, useEffect, useCallback } from 'react';
import { spreadFraction, gratingMaximumAngle, maxGratingOrder } from '@/lib/physics/diffraction';

export type DiffractionMode = 'single-slit' | 'grating';

interface Props {
  mode: DiffractionMode;
  wavelengthNm: number;   // both modes — visible-light range
  slitWidthNm: number;    // single-slit mode: the gap width
  slitSpacingNm: number;  // grating mode: spacing between slits
  isRunning: boolean; isPaused: boolean;
  width?: number; height?: number;
}

interface Ripple { spawnT: number; }

const WAVE_SPEED = 90; // px/s — purely a pacing constant, not to physical scale

export function DiffractionCanvas({ mode, wavelengthNm, slitWidthNm, slitSpacingNm, isRunning, isPaused, width = 660, height = 300 }: Props) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const rafRef = useRef<number>(0);
  const lastFrameRef = useRef<number | null>(null);
  const t = useRef(0);
  const ripples = useRef<Ripple[]>([]);
  const lastSpawnT = useRef(-999);
  const simRef = useRef({ mode, wavelengthNm, slitWidthNm, slitSpacingNm, isRunning, isPaused });
  simRef.current = { mode, wavelengthNm, slitWidthNm, slitSpacingNm, isRunning, isPaused };

  useEffect(() => {
    t.current = 0; ripples.current = []; lastSpawnT.current = -999; lastFrameRef.current = null;
  }, [mode, wavelengthNm, slitWidthNm, slitSpacingNm]);

  const draw = useCallback((timestamp?: number) => {
    const canvas = canvasRef.current; if (!canvas) return;
    const ctx = canvas.getContext('2d'); if (!ctx) return;
    const s = simRef.current;
    const W = canvas.width, H = canvas.height;

    if (s.isRunning && !s.isPaused && timestamp !== undefined) {
      if (lastFrameRef.current !== null) {
        t.current += Math.min((timestamp - lastFrameRef.current) / 1000, 0.1);
      }
      lastFrameRef.current = timestamp;
    } else {
      lastFrameRef.current = timestamp ?? null;
    }

    ctx.clearRect(0, 0, W, H);
    ctx.fillStyle = '#0f172a'; ctx.fillRect(0, 0, W, H);

    if (s.mode === 'single-slit') {
      const gapX = W * 0.4;
      const gapY = H / 2;
      // Visual wavelength spacing (px) — purely cosmetic, mapped from the
      // 400-700nm slider range to a readable on-screen spacing. Physics
      // (the spread angle) uses the REAL λ/a ratio, not this pixel value.
      const wavelengthPx = 8 + ((s.wavelengthNm - 400) / 300) * 10;
      const period = wavelengthPx / WAVE_SPEED;
      const spread = spreadFraction(s.wavelengthNm, s.slitWidthNm); // 0..1
      const maxSpreadAngle = (Math.PI / 2) * spread; // radians, half-angle either side

      // Incoming plane wavefronts (left of the barrier)
      ctx.strokeStyle = 'rgba(129,140,248,0.5)'; ctx.lineWidth = 1.5;
      const phase = (t.current * WAVE_SPEED) % wavelengthPx;
      for (let x = gapX - phase; x > 0; x -= wavelengthPx) {
        ctx.beginPath(); ctx.moveTo(x, 10); ctx.lineTo(x, H - 40); ctx.stroke();
      }

      // Barrier with a gap, gap width shown proportionally (cosmetic scale)
      const gapHalfPx = Math.max(4, Math.min(70, (s.slitWidthNm / 3000) * 140));
      ctx.fillStyle = '#475569';
      ctx.fillRect(gapX - 3, 10, 6, gapY - gapHalfPx - 10);
      ctx.fillRect(gapX - 3, gapY + gapHalfPx, 6, H - 40 - (gapY + gapHalfPx));

      // Spawn a new outgoing ripple every period, from the moment a
      // wavefront reaches the gap
      if (s.isRunning && !s.isPaused && t.current - lastSpawnT.current >= period) {
        lastSpawnT.current = t.current;
        ripples.current.push({ spawnT: t.current });
      }
      ripples.current = ripples.current.filter(r => (t.current - r.spawnT) * WAVE_SPEED < W);

      // Outgoing wavefronts: arcs limited to ±maxSpreadAngle either side of
      // straight-ahead — narrow gap (large λ/a) draws a wide fan; wide gap
      // (small λ/a) stays close to a forward beam.
      ctx.strokeStyle = 'rgba(52,211,153,0.7)'; ctx.lineWidth = 1.5;
      ripples.current.forEach(r => {
        const radius = (t.current - r.spawnT) * WAVE_SPEED;
        if (radius < 2) return;
        ctx.beginPath();
        ctx.arc(gapX, gapY, radius, -maxSpreadAngle, maxSpreadAngle);
        ctx.stroke();
      });

      // Spread-angle guide lines
      ctx.strokeStyle = 'rgba(251,191,36,0.4)'; ctx.setLineDash([4, 4]); ctx.lineWidth = 1;
      [-maxSpreadAngle, maxSpreadAngle].forEach(a => {
        ctx.beginPath(); ctx.moveTo(gapX, gapY); ctx.lineTo(gapX + Math.cos(a) * (W - gapX), gapY + Math.sin(a) * (W - gapX)); ctx.stroke();
      });
      ctx.setLineDash([]);

      ctx.fillStyle = '#e2e8f0'; ctx.font = 'bold 11px system-ui'; ctx.textAlign = 'center';
      ctx.fillText(
        spread >= 0.99 ? 'Slit narrower than the wavelength — waves spread through almost a full half-circle' : `Diffraction half-angle ≈ ${(maxSpreadAngle * 180 / Math.PI).toFixed(0)}°`,
        W / 2, 22,
      );
      ctx.fillStyle = '#94a3b8'; ctx.font = '10px system-ui'; ctx.textAlign = 'left';
      ctx.fillText(`λ/a = ${(s.wavelengthNm / s.slitWidthNm).toFixed(2)} — bigger ratio (narrower slit, or longer wavelength) means more spreading`, 8, H - 10);
      rafRef.current = requestAnimationFrame(draw);
      return;
    }

    // ── Diffraction grating ──────────────────────────────────────────────────
    const gratingX = W * 0.22;
    const screenX = W * 0.86;
    const midY = H / 2;

    // Incident monochromatic beam
    ctx.strokeStyle = 'rgba(129,140,248,0.6)'; ctx.lineWidth = 2;
    ctx.beginPath(); ctx.moveTo(10, midY); ctx.lineTo(gratingX, midY); ctx.stroke();

    // Grating (barrier with several fine slits)
    ctx.fillStyle = '#475569'; ctx.fillRect(gratingX - 3, 10, 6, H - 20);
    const nSlits = 7;
    const slitGapPx = 16;
    for (let i = -Math.floor(nSlits / 2); i <= Math.floor(nSlits / 2); i++) {
      ctx.clearRect(gratingX - 3, midY + i * slitGapPx - 2, 6, 4);
    }
    ctx.strokeStyle = '#94a3b8'; ctx.font = '9px system-ui';

    // Screen
    ctx.strokeStyle = '#334155'; ctx.lineWidth = 3;
    ctx.beginPath(); ctx.moveTo(screenX, 10); ctx.lineTo(screenX, H - 20); ctx.stroke();

    const maxOrder = maxGratingOrder(s.wavelengthNm, s.slitSpacingNm);
    const orders = Array.from({ length: 2 * maxOrder + 1 }, (_, i) => i - maxOrder);
    const hue = wavelengthToColor(s.wavelengthNm);

    orders.forEach(n => {
      const angleDeg = gratingMaximumAngle(s.wavelengthNm, s.slitSpacingNm, n);
      if (angleDeg === null) return;
      const angleRad = (angleDeg * Math.PI) / 180;
      const dx = screenX - gratingX;
      const dy = Math.tan(angleRad) * dx;
      const targetY = midY + dy;
      if (targetY < 10 || targetY > H - 20) return;

      ctx.save();
      ctx.strokeStyle = n === 0 ? 'rgba(255,255,255,0.5)' : `${hue}55`;
      ctx.lineWidth = n === 0 ? 1.5 : 1;
      ctx.beginPath(); ctx.moveTo(gratingX, midY); ctx.lineTo(screenX, targetY); ctx.stroke();
      ctx.restore();

      ctx.beginPath(); ctx.arc(screenX, targetY, n === 0 ? 5 : 4, 0, Math.PI * 2);
      ctx.fillStyle = n === 0 ? '#ffffff' : hue;
      ctx.fill();
      ctx.fillStyle = '#cbd5e1'; ctx.font = '9px system-ui'; ctx.textAlign = 'left';
      ctx.fillText(`n=${n}`, screenX + 10, targetY + 3);
    });

    ctx.fillStyle = '#e2e8f0'; ctx.font = 'bold 11px system-ui'; ctx.textAlign = 'center';
    ctx.fillText(`d sinθ = nλ — up to order n = ±${maxOrder} visible at this spacing/wavelength`, W / 2, 22);
    ctx.fillStyle = '#94a3b8'; ctx.font = '10px system-ui'; ctx.textAlign = 'left';
    ctx.fillText(`λ=${s.wavelengthNm}nm  d=${s.slitSpacingNm}nm`, 8, H - 10);

    rafRef.current = requestAnimationFrame(draw);
  }, []);

  useEffect(() => {
    rafRef.current = requestAnimationFrame(draw);
    return () => cancelAnimationFrame(rafRef.current);
  }, [draw]);

  return (
    <canvas ref={canvasRef} width={width} height={height}
      className="w-full rounded-xl border border-gray-200" style={{ display: 'block' }} />
  );
}

function wavelengthToColor(nm: number): string {
  if (nm < 450) return '#8b5cf6';
  if (nm < 495) return '#3b82f6';
  if (nm < 570) return '#22c55e';
  if (nm < 590) return '#eab308';
  if (nm < 620) return '#f97316';
  return '#ef4444';
}
