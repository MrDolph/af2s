'use client';
import { useRef, useEffect, useCallback } from 'react';
import { spreadFraction, gratingMaximumAngle, maxGratingOrder, maxFringeOrder } from '@/lib/physics/diffraction';

export type DiffractionMode = 'single-slit' | 'grating' | 'double-slit';

interface Props {
  mode: DiffractionMode;
  wavelengthNm: number;    // all modes — visible-light range
  slitWidthNm: number;     // single-slit mode: the gap width
  slitSpacingNm: number;   // grating mode: spacing between slits
  doubleSlitSepNm: number; // double-slit mode: separation between the two slits
  isRunning: boolean; isPaused: boolean;
  width?: number; height?: number;
}

interface Ripple { spawnT: number; sourceY: number; }
interface FringeCell { x: number; y: number; intensity: number; }

const WAVE_SPEED = 90; // px/s — purely a pacing constant, not to physical scale
const GRID_STEP = 4;   // px — coarse sampling keeps the interference-pattern precompute cheap

export function DiffractionCanvas({ mode, wavelengthNm, slitWidthNm, slitSpacingNm, doubleSlitSepNm, isRunning, isPaused, width = 660, height = 300 }: Props) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const rafRef = useRef<number>(0);
  const lastFrameRef = useRef<number | null>(null);
  const t = useRef(0);
  const ripples = useRef<Ripple[]>([]);
  const lastSpawnT = useRef(-999);
  const fringeCache = useRef<FringeCell[]>([]);
  const simRef = useRef({ mode, wavelengthNm, slitWidthNm, slitSpacingNm, doubleSlitSepNm, isRunning, isPaused });
  simRef.current = { mode, wavelengthNm, slitWidthNm, slitSpacingNm, doubleSlitSepNm, isRunning, isPaused };

  useEffect(() => {
    t.current = 0; ripples.current = []; lastSpawnT.current = -999; lastFrameRef.current = null;
    fringeCache.current = []; // force a recompute on the next draw for double-slit mode
  }, [mode, wavelengthNm, slitWidthNm, slitSpacingNm, doubleSlitSepNm]);

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
        ripples.current.push({ spawnT: t.current, sourceY: gapY });
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
    } else if (s.mode === 'grating') {
      const gratingX = W * 0.22;
      const screenX = W * 0.86;
      const midY = H / 2;
      const wavelengthPx = 8 + ((s.wavelengthNm - 400) / 300) * 10;

      // Animated incoming wavefronts, same visual language as single-slit —
      // previously this mode had Run/Pause buttons that visibly did
      // nothing at all once pressed.
      ctx.strokeStyle = 'rgba(129,140,248,0.5)'; ctx.lineWidth = 1.5;
      const phase = (t.current * WAVE_SPEED) % wavelengthPx;
      for (let x = gratingX - phase; x > 0; x -= wavelengthPx) {
        ctx.beginPath(); ctx.moveTo(x, midY - 30); ctx.lineTo(x, midY + 30); ctx.stroke();
      }

      // Grating (barrier with several fine slits)
      ctx.fillStyle = '#475569'; ctx.fillRect(gratingX - 3, 10, 6, H - 20);
      const nSlits = 7;
      const slitGapPx = 16;
      for (let i = -Math.floor(nSlits / 2); i <= Math.floor(nSlits / 2); i++) {
        ctx.clearRect(gratingX - 3, midY + i * slitGapPx - 2, 6, 4);
      }

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
    } else {
      // ── Young's double-slit interference ────────────────────────────────
      const gapX = W * 0.32;
      const screenX = W * 0.9;
      const midY = H / 2;
      const wavelengthPx = 8 + ((s.wavelengthNm - 400) / 300) * 10;
      // Cosmetic px scale, but used consistently for BOTH the interference
      // grid below and the labelled screen fringe positions, so the two
      // visualisations agree with each other rather than being drawn from
      // two different, potentially-inconsistent scales.
      const sepPx = 20 + ((s.doubleSlitSepNm - 200_000) / 800_000) * 140;
      const slit1: { x: number; y: number } = { x: gapX, y: midY - sepPx / 2 };
      const slit2: { x: number; y: number } = { x: gapX, y: midY + sepPx / 2 };

      // Precompute the steady-state interference pattern once per
      // parameter change (not every frame) — the fringe PATTERN itself is
      // time-invariant for continuous coherent sources; what's animated
      // separately below is the travelling wavefronts, not the pattern.
      if (fringeCache.current.length === 0) {
        const cells: FringeCell[] = [];
        for (let gx = gapX + 6; gx < screenX; gx += GRID_STEP) {
          for (let gy = 15; gy < H - 30; gy += GRID_STEP) {
            const d1 = Math.hypot(gx - slit1.x, gy - slit1.y);
            const d2 = Math.hypot(gx - slit2.x, gy - slit2.y);
            const pathDiff = d1 - d2;
            const intensity = Math.pow(Math.cos((Math.PI * pathDiff) / wavelengthPx), 2);
            cells.push({ x: gx, y: gy, intensity });
          }
        }
        fringeCache.current = cells;
      }
      ctx.save();
      fringeCache.current.forEach(c => {
        const v = Math.round(c.intensity * 180);
        ctx.fillStyle = `rgb(${v},${v},${Math.min(255, v + 60)})`;
        ctx.fillRect(c.x, c.y, GRID_STEP, GRID_STEP);
      });
      ctx.restore();

      // Barrier with the two slits
      ctx.fillStyle = '#1e293b';
      ctx.fillRect(gapX - 3, 10, 6, slit1.y - 10 - 3);
      ctx.fillRect(gapX - 3, slit1.y + 3, 6, slit2.y - slit1.y - 6);
      ctx.fillRect(gapX - 3, slit2.y + 3, 6, H - 20 - slit2.y - 3);

      // Animated travelling wavefronts, spawned in sync from both slits —
      // the SAME period/phase from each, since the slits are illuminated
      // coherently (the defining condition of Young's experiment).
      const period = wavelengthPx / WAVE_SPEED;
      ctx.strokeStyle = 'rgba(129,140,248,0.45)'; ctx.lineWidth = 1.2;
      const phase = (t.current * WAVE_SPEED) % wavelengthPx;
      for (let x = gapX - phase; x > 0; x -= wavelengthPx) {
        ctx.beginPath(); ctx.moveTo(x, 15); ctx.lineTo(x, H - 30); ctx.stroke();
      }
      if (s.isRunning && !s.isPaused && t.current - lastSpawnT.current >= period) {
        lastSpawnT.current = t.current;
        ripples.current.push({ spawnT: t.current, sourceY: slit1.y }, { spawnT: t.current, sourceY: slit2.y });
      }
      ripples.current = ripples.current.filter(r => (t.current - r.spawnT) * WAVE_SPEED < W);
      ctx.strokeStyle = 'rgba(255,255,255,0.55)'; ctx.lineWidth = 1;
      ripples.current.forEach(r => {
        const radius = (t.current - r.spawnT) * WAVE_SPEED;
        if (radius < 2) return;
        ctx.beginPath(); ctx.arc(gapX, r.sourceY, radius, -Math.PI / 2, Math.PI / 2);
        ctx.stroke();
      });

      // Screen with labelled fringe positions. Uses the EXACT angular
      // relation sinθ=nλ/d (same approach as grating mode) rather than the
      // small-angle approximation Δy≈λD/d — at this pixel scale λ/d isn't
      // always small, and the approximation was verified to place dots
      // dozens of pixels away from the interference grid's actual peaks.
      // The exact form always agrees with the grid, at any scale.
      ctx.strokeStyle = '#334155'; ctx.lineWidth = 3;
      ctx.beginPath(); ctx.moveTo(screenX, 15); ctx.lineTo(screenX, H - 30); ctx.stroke();
      const screenDistPx = screenX - gapX;
      const maxN = maxFringeOrder(wavelengthPx, sepPx);
      let visibleFringes = 0;
      for (let n = -maxN; n <= maxN; n++) {
        const sinTheta = (n * wavelengthPx) / sepPx;
        if (Math.abs(sinTheta) > 1) continue;
        const y = midY + screenDistPx * Math.tan(Math.asin(sinTheta));
        if (y < 15 || y > H - 30) continue;
        visibleFringes++;
        ctx.fillStyle = n === 0 ? '#ffffff' : '#93c5fd';
        ctx.beginPath(); ctx.arc(screenX, y, n === 0 ? 4 : 3, 0, Math.PI * 2); ctx.fill();
      }

      ctx.fillStyle = '#e2e8f0'; ctx.font = 'bold 11px system-ui'; ctx.textAlign = 'center';
      ctx.fillText('Bright fringes where the path difference from the two slits is a whole number of wavelengths', W / 2, 22);
      ctx.fillStyle = '#94a3b8'; ctx.font = '10px system-ui'; ctx.textAlign = 'left';
      ctx.fillText(`fringe spacing Δy = λD/d (near the centre) — ${visibleFringes} bright fringes visible on this screen`, 8, H - 10);
    }

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
