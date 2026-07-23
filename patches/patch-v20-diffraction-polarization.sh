#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
# A-Factor STEM Studio — patch v20: new Diffraction and Polarization modules
#
#   Completes the five-wave-properties set alongside the existing Reflection,
#   Refraction, and Wave Motion (which already covers interference via its
#   superposition/standing-wave modes) modules.
#
#   DIFFRACTION — two modes:
#     - Single slit: an animated ripple-tank-style demo — plane wavefronts
#       approach a barrier with an adjustable gap, then spread out on the
#       far side as expanding arcs. The angular spread is driven by the
#       real λ/a ratio (sinθ = λ/a for the first minimum), verified
#       numerically (λ=500nm, a=1000nm gives exactly 30°, as expected).
#     - Diffraction grating: multiple slits, monochromatic light, and a
#       screen showing bright fringes at each order n where d·sinθ = nλ —
#       verified against a hand-checked 500-lines/mm case (orders 0-3 at
#       0°, 17.5°, 36.9°, 64.2°).
#     Caught and fixed a real bug before shipping: the single-slit branch
#     had an early return that skipped the animation loop's own
#     re-scheduling call, which would have frozen the whole canvas after
#     one frame.
#
#   POLARIZATION — two modes:
#     - A single polarizer: unpolarized light (shown vibrating in many
#       directions at once) becomes plane-polarized (one direction only)
#       after a filter with an adjustable transmission axis.
#     - Malus's law: two polarizers, with the second one's angle
#       adjustable — transmitted intensity follows I=I0cos²θ, shown both
#       in the animated beam (brightness/amplitude scale with intensity)
#       and a live Recharts graph of I vs θ. Verified the standard
#       0°/45°/90° values (100%/50%/0%) numerically before shipping.
#
#   Both are wired to Run/Pause/Reset, added to the simulations hub under
#   the Waves topic, and given full embed routes.
#
# Run from the af2s project root (Git Bash):   bash patches/patch-v20-diffraction-polarization.sh
# ══════════════════════════════════════════════════════════════════════════════
set -euo pipefail

if [ ! -f "package.json" ]; then
  echo "✗ Run this from the af2s project root (package.json not found)." >&2
  exit 1
fi

echo "── A-Factor patch v20: new Diffraction + Polarization modules ──"
mkdir -p "src/app/embed/diffraction" "src/app/embed/polarization" "src/app/simulations" "src/app/simulations/diffraction" "src/app/simulations/polarization" "src/components/simulation" "src/lib/physics"

echo "  → src/lib/physics/diffraction.ts"
cat > "src/lib/physics/diffraction.ts" << 'AFEOF'
// ── Diffraction ───────────────────────────────────────────────────────────────
// Diffraction is the spreading of a wave as it passes through a gap or
// around an obstacle. It becomes pronounced when the gap width is
// comparable to (or smaller than) the wavelength — this is why sound
// (wavelengths of metres) diffracts noticeably around doorways while light
// (wavelengths of hundreds of nanometres) barely seems to at everyday gaps.

// Angle to the first minimum either side of the central maximum for a
// single slit of width `a`, wavelength `lambda` (consistent units):
// sinθ = λ/a. Returns degrees; null if λ > a (no minimum exists — the
// central maximum spreads across the whole far side).
export function firstMinimumAngle(wavelength: number, slitWidth: number): number | null {
  if (slitWidth <= 0) return null;
  const s = wavelength / slitWidth;
  if (s > 1) return null;
  return (Math.asin(s) * 180) / Math.PI;
}

// A simple, honest visual proxy for "how much the wave spreads out" — not
// a literal intensity calculation, just a monotonic 0..1 measure of how
// wide the diffracted wavefront's angular spread should be drawn, based on
// the wavelength-to-slit-width ratio. Narrow slit (ratio → large) spreads
// close to a full half-plane; wide slit (ratio → 0) stays close to a
// forward beam.
export function spreadFraction(wavelength: number, slitWidth: number): number {
  if (slitWidth <= 0) return 1;
  const ratio = wavelength / slitWidth;
  return Math.min(1, ratio);
}

// ── Diffraction grating ──────────────────────────────────────────────────────
// Grating equation: d·sinθ = n·λ — bright fringes (maxima) form where light
// from every slit arrives in phase. d = slit spacing, n = order (0, ±1, ±2…).
export function gratingMaximumAngle(wavelength: number, slitSpacing: number, order: number): number | null {
  if (slitSpacing <= 0) return null;
  const s = (order * wavelength) / slitSpacing;
  if (Math.abs(s) > 1) return null; // this order does not exist at this λ, d
  return (Math.asin(s) * 180) / Math.PI;
}
// Highest order that actually appears for a given wavelength and spacing.
export function maxGratingOrder(wavelength: number, slitSpacing: number): number {
  if (slitSpacing <= 0 || wavelength <= 0) return 0;
  return Math.floor(slitSpacing / wavelength);
}
AFEOF

echo "  → src/lib/physics/polarization.ts"
cat > "src/lib/physics/polarization.ts" << 'AFEOF'
// ── Polarization ─────────────────────────────────────────────────────────────
// Light is a transverse wave; "unpolarized" light vibrates in every
// direction perpendicular to its travel. A polarizer only transmits the
// component of vibration along its transmission axis, producing light that
// vibrates in a single plane — "plane-polarized" light.

// Malus's law: once light is already plane-polarized, the intensity that
// passes through a second polarizer (the "analyser") set at angle θ to the
// first depends on cos²θ.
export function malusIntensity(I0: number, angleDeg: number): number {
  const rad = (angleDeg * Math.PI) / 180;
  return I0 * Math.pow(Math.cos(rad), 2);
}

// Fraction of unpolarized light transmitted by a single ideal polarizer —
// exactly half, regardless of the transmission axis's orientation (there is
// no "angle" for the first polarizer to be measured against yet).
export const UNPOLARIZED_TRANSMISSION_FRACTION = 0.5;

export function malusCurve(I0: number, points = 90) {
  return Array.from({ length: points + 1 }, (_, i) => {
    const angle = (i / points) * 180;
    return { angle: +angle.toFixed(1), I: +malusIntensity(I0, angle).toFixed(3) };
  });
}
AFEOF

echo "  → src/components/simulation/DiffractionCanvas.tsx"
cat > "src/components/simulation/DiffractionCanvas.tsx" << 'AFEOF'
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
AFEOF

echo "  → src/components/simulation/PolarizationCanvas.tsx"
cat > "src/components/simulation/PolarizationCanvas.tsx" << 'AFEOF'
'use client';
import { useRef, useEffect, useCallback } from 'react';
import { malusIntensity } from '@/lib/physics/polarization';

export type PolarizationMode = 'single' | 'malus';

interface Props {
  mode: PolarizationMode;
  polarizerAngle: number;  // single mode: transmission axis, degrees from vertical
  analyzerAngle: number;   // malus mode: angle of the 2nd polarizer relative to the 1st
  isRunning: boolean; isPaused: boolean;
  width?: number; height?: number;
}

// Draws a short "vibration" tick oscillating perpendicular to the beam at
// the given angle (0° = vertical), amplitude modulated over time.
function vibrationTick(ctx: CanvasRenderingContext2D, x: number, y: number, angleDeg: number, amp: number, color: string) {
  const rad = (angleDeg * Math.PI) / 180;
  const dx = Math.sin(rad) * amp, dy = -Math.cos(rad) * amp;
  ctx.strokeStyle = color; ctx.lineWidth = 1.6;
  ctx.beginPath(); ctx.moveTo(x - dx, y - dy); ctx.lineTo(x + dx, y + dy); ctx.stroke();
}

function drawPolarizer(ctx: CanvasRenderingContext2D, x: number, midY: number, halfH: number, axisAngleDeg: number, label: string) {
  ctx.save();
  ctx.strokeStyle = '#334155'; ctx.lineWidth = 2;
  ctx.beginPath(); ctx.moveTo(x, midY - halfH); ctx.lineTo(x, midY + halfH); ctx.stroke();
  // Transmission-axis hatching
  const rad = (axisAngleDeg * Math.PI) / 180;
  const dx = Math.sin(rad) * 7, dy = -Math.cos(rad) * 7;
  ctx.strokeStyle = '#6366f1'; ctx.lineWidth = 1.2;
  for (let y = midY - halfH + 6; y <= midY + halfH - 6; y += 10) {
    ctx.beginPath(); ctx.moveTo(x - dx, y - dy); ctx.lineTo(x + dx, y + dy); ctx.stroke();
  }
  ctx.fillStyle = '#475569'; ctx.font = 'bold 9px system-ui'; ctx.textAlign = 'center';
  ctx.fillText(label, x, midY + halfH + 16);
  ctx.restore();
}

export function PolarizationCanvas({ mode, polarizerAngle, analyzerAngle, isRunning, isPaused, width = 660, height = 260 }: Props) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const rafRef = useRef<number>(0);
  const lastFrameRef = useRef<number | null>(null);
  const t = useRef(0);
  const lastWobble = useRef(1);
  const simRef = useRef({ mode, polarizerAngle, analyzerAngle, isRunning, isPaused });
  simRef.current = { mode, polarizerAngle, analyzerAngle, isRunning, isPaused };

  useEffect(() => { t.current = 0; lastWobble.current = 1; lastFrameRef.current = null; }, [mode, polarizerAngle, analyzerAngle]);

  const draw = useCallback((timestamp?: number) => {
    const canvas = canvasRef.current; if (!canvas) return;
    const ctx = canvas.getContext('2d'); if (!ctx) return;
    const s = simRef.current;
    const W = canvas.width, H = canvas.height;

    const animate = s.isRunning && !s.isPaused;
    if (animate && timestamp !== undefined) {
      if (lastFrameRef.current !== null) {
        t.current += Math.min((timestamp - lastFrameRef.current) / 1000, 0.1);
      }
      lastFrameRef.current = timestamp;
      lastWobble.current = Math.sin(t.current * 6);
    } else {
      lastFrameRef.current = timestamp ?? null;
    }
    // Holds at whatever it last was while paused/stopped, rather than
    // snapping to a different fixed amplitude.
    const wobble = lastWobble.current;

    ctx.clearRect(0, 0, W, H);
    ctx.fillStyle = '#f8fafc'; ctx.fillRect(0, 0, W, H);

    const midY = H / 2;
    const UNPOLARIZED_ANGLES = [0, 22.5, 45, 67.5, 90, 112.5, 135, 157.5];

    if (s.mode === 'single') {
      const polX = W * 0.55;
      ctx.strokeStyle = '#cbd5e1'; ctx.lineWidth = 1;
      ctx.beginPath(); ctx.moveTo(20, midY); ctx.lineTo(W - 20, midY); ctx.stroke();

      // Unpolarized: many vibration directions, before the polarizer
      for (let x = 40; x < polX - 20; x += 26) {
        UNPOLARIZED_ANGLES.forEach(a => vibrationTick(ctx, x, midY, a, 16 * wobble, 'rgba(99,102,241,0.55)'));
      }

      drawPolarizer(ctx, polX, midY, 70, s.polarizerAngle, 'Polarizer');

      // After the polarizer: only the transmission-axis direction survives
      for (let x = polX + 26; x < W - 30; x += 26) {
        vibrationTick(ctx, x, midY, s.polarizerAngle, 16 * wobble, '#10b981');
      }

      ctx.fillStyle = '#334155'; ctx.font = 'bold 11px system-ui'; ctx.textAlign = 'center';
      ctx.fillText('Unpolarized (all directions) → plane-polarized (one direction only)', W / 2, 24);
      ctx.fillStyle = '#64748b'; ctx.font = '10px system-ui'; ctx.textAlign = 'left';
      ctx.fillText(`Transmission axis at ${s.polarizerAngle}° from vertical`, 8, H - 10);
      rafRef.current = requestAnimationFrame(draw);
      return;
    }

    // ── Malus's law: two polarizers ─────────────────────────────────────────
    const p1X = W * 0.34, p2X = W * 0.66;
    const I = malusIntensity(1, s.analyzerAngle);

    ctx.strokeStyle = '#cbd5e1'; ctx.lineWidth = 1;
    ctx.beginPath(); ctx.moveTo(20, midY); ctx.lineTo(W - 20, midY); ctx.stroke();

    for (let x = 30; x < p1X - 20; x += 26) {
      UNPOLARIZED_ANGLES.forEach(a => vibrationTick(ctx, x, midY, a, 15 * wobble, 'rgba(99,102,241,0.5)'));
    }
    drawPolarizer(ctx, p1X, midY, 65, 0, 'Polarizer');
    for (let x = p1X + 24; x < p2X - 20; x += 24) {
      vibrationTick(ctx, x, midY, 0, 15 * wobble, '#6366f1');
    }
    drawPolarizer(ctx, p2X, midY, 65, s.analyzerAngle, 'Analyser');
    // Transmitted amplitude scales with √I (amplitude), brightness with I —
    // both shrink to nothing as the analyser approaches 90° (crossed).
    const ampScale = Math.sqrt(Math.max(I, 0));
    for (let x = p2X + 24; x < W - 24; x += 24) {
      vibrationTick(ctx, x, midY, s.analyzerAngle, 15 * wobble * ampScale, `rgba(16,185,129,${0.3 + I * 0.7})`);
    }

    ctx.fillStyle = '#334155'; ctx.font = 'bold 11px system-ui'; ctx.textAlign = 'center';
    ctx.fillText(
      s.analyzerAngle > 85 && s.analyzerAngle < 95 ? 'Crossed polarizers — no light gets through' : `Malus's law: I = I₀cos²θ = ${(I * 100).toFixed(0)}% of I₀`,
      W / 2, 24,
    );
    ctx.fillStyle = '#64748b'; ctx.font = '10px system-ui'; ctx.textAlign = 'left';
    ctx.fillText(`θ = ${s.analyzerAngle}° between the two transmission axes`, 8, H - 10);

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
AFEOF

echo "  → src/app/simulations/diffraction/page.tsx"
cat > "src/app/simulations/diffraction/page.tsx" << 'AFEOF'
'use client';
import { useState, useCallback, useEffect, useRef } from 'react';
import { AppHeader } from '@/components/layout/AppHeader';
import { SimulationControls } from '@/components/simulation/SimulationControls';
import { DiffractionCanvas, DiffractionMode } from '@/components/simulation/DiffractionCanvas';
import { EmbedButton } from '@/components/ui/EmbedButton';
import { firstMinimumAngle, spreadFraction, maxGratingOrder } from '@/lib/physics/diffraction';
import { useResponsiveCanvasSize } from '@/hooks/useResponsiveCanvasSize';

const CURRICULA = ['WAEC', 'NECO', 'IGCSE', 'SAT', 'JUPEB'];
const CC: Record<string, string> = {
  WAEC: 'bg-indigo-100 text-indigo-700', NECO: 'bg-pink-100 text-pink-700',
  IGCSE: 'bg-emerald-100 text-emerald-700', SAT: 'bg-orange-100 text-orange-700',
  JUPEB: 'bg-purple-100 text-purple-700',
};

const MODE_META: Record<DiffractionMode, { title: string; icon: string; sub: string; eq: string }> = {
  'single-slit': { title: 'Single slit', icon: '🌊', sub: 'Spreading through a gap', eq: 'sinθ = λ/a' },
  grating:       { title: 'Diffraction grating', icon: '🎨', sub: 'Multiple slits — spectral orders', eq: 'd sinθ = nλ' },
};

const TEACHER_NOTES: Record<DiffractionMode, string[]> = {
  'single-slit': [
    'Diffraction is the spreading of a wave as it passes through a gap or around an edge — it happens to ALL waves (sound, water, light), not just light.',
    'The amount of spreading depends on the ratio λ/a (wavelength ÷ gap width). When the gap is comparable to or smaller than the wavelength, spreading is dramatic; when the gap is much bigger than the wavelength, the wave carries on mostly straight through.',
    'This is why you can hear someone through an open doorway even when you can\u2019t see them — sound wavelengths (metres) are comparable to doorway widths, so sound diffracts strongly, while light wavelengths (hundreds of nanometres) are far too small to diffract noticeably at that gap.',
    'The first minimum either side of the central bright band occurs at sinθ = λ/a — this is the standard single-slit diffraction formula at this level.',
    'Diffraction is direct evidence that light behaves as a WAVE — a stream of simple particles travelling in straight lines would never spread out behind a gap.',
  ],
  grating: [
    'A diffraction grating is many equally-spaced slits close together. Light from every slit interferes, producing sharp, bright fringes only at specific angles — far sharper than a single or double slit.',
    'Grating equation: d·sinθ = nλ, where d is the spacing between adjacent slits and n is the "order" (0, ±1, ±2, …).',
    'The n=0 order is undeviated (straight through, θ=0°) for ANY wavelength — this is why the central fringe of white light through a grating is white, not spread into a spectrum.',
    'Because sinθ depends on λ, different colours diffract to different angles for the same order — this is how gratings are used to split light into a spectrum in a spectrometer.',
    'Gratings with more lines per millimetre have a SMALLER slit spacing d, which — from the grating equation — spreads the orders out to LARGER angles.',
  ],
};

const EXERCISES: Record<DiffractionMode, { q: string; a: string }[]> = {
  'single-slit': [
    { q: 'Light of wavelength 600nm passes through a slit of width 1200nm. Find the angle to the first minimum.', a: 'sinθ = λ/a = 600/1200 = 0.5 → θ = 30°.' },
    { q: 'Explain why radio waves diffract strongly around hills but light does not.', a: 'Radio wavelengths can be metres to kilometres long — comparable to or bigger than a hill — so they diffract strongly. Light wavelengths (~500nm) are millions of times smaller than a hill, so diffraction around it is negligible.' },
    { q: 'A slit is made narrower while the wavelength stays the same. What happens to the diffraction pattern?', a: 'The λ/a ratio increases, so the central maximum and the angle to the first minimum both get WIDER — more spreading.' },
  ],
  grating: [
    { q: 'A grating has 400 lines per millimetre. Find the slit spacing d in nanometres.', a: 'd = 1mm/400 = 1/400 mm = 2500nm.' },
    { q: 'Using d=2000nm and λ=500nm, find the angle of the first-order (n=1) maximum.', a: 'sinθ = nλ/d = 500/2000 = 0.25 → θ = 14.5°.' },
    { q: 'Why does white light passed through a grating produce a spectrum at each order (except n=0)?', a: 'Each wavelength satisfies d sinθ = nλ at a different angle θ (since λ differs), so red, green, blue etc. all diffract to slightly different angles for the same order, spreading white light into its component colours — except at n=0, where sinθ=0 works for every λ, so all colours overlap and stay white.' },
  ],
};

function Slider({ label, unit, value, min, max, step, set, color, note }: {
  label: string; unit: string; value: number; min: number; max: number;
  step: number; set: (v: number) => void; color: string; note?: string;
}) {
  return (
    <div className="space-y-1.5">
      <div className="flex justify-between text-xs">
        <span className="text-gray-500">{label}</span>
        <span className="font-medium tabular-nums text-gray-800">{value} <span className="text-gray-400 font-normal">{unit}</span></span>
      </div>
      <input type="range" min={min} max={max} step={step} value={value}
        onChange={e => set(Number(e.target.value))} className="w-full" style={{ accentColor: color }} />
      {note && <p className="text-[10px] text-gray-400">{note}</p>}
    </div>
  );
}

function StatRow({ label, value, unit, color }: { label: string; value: string; unit: string; color: string }) {
  return (
    <div className="flex justify-between items-center rounded-lg bg-gray-50 px-3 py-2">
      <span className="text-xs text-gray-500">{label}</span>
      <span className={`text-xs font-semibold tabular-nums ${color}`}>{value} <span className="text-gray-400 font-normal">{unit}</span></span>
    </div>
  );
}

export default function DiffractionPage() {
  const [mode, setMode] = useState<DiffractionMode>('single-slit');
  const [isRunning, setIsRunning] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const [resetKey, setResetKey] = useState(0);
  const [openEx, setOpenEx] = useState<number | null>(null);
  const [activeCurricula, setActiveCurricula] = useState(['WAEC', 'IGCSE', 'SAT']);

  const [wavelengthNm, setWavelengthNm] = useState(550);
  const [slitWidthNm, setSlitWidthNm] = useState(1000);
  const [slitSpacingNm, setSlitSpacingNm] = useState(2000);

  const reset = useCallback(() => { setIsRunning(false); setIsPaused(false); setResetKey(k => k + 1); }, []);
  const resetTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  useEffect(() => {
    if (resetTimer.current) clearTimeout(resetTimer.current);
    resetTimer.current = setTimeout(reset, 100);
  }, [mode, wavelengthNm, slitWidthNm, slitSpacingNm, reset]);

  const canvasBoxRef = useRef<HTMLDivElement>(null);
  const canvasSize = useResponsiveCanvasSize(canvasBoxRef, 660, 300, 980);

  const minAngle = firstMinimumAngle(wavelengthNm, slitWidthNm);
  const spread = spreadFraction(wavelengthNm, slitWidthNm);
  const maxOrder = maxGratingOrder(wavelengthNm, slitSpacingNm);

  return (
    <>
      <AppHeader />
      <main className="min-h-screen bg-gray-50">
        <section className="border-b border-gray-200 bg-white">
          <div className="mx-auto max-w-[100rem] px-4 sm:px-6 py-4">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
              <div>
                <p className="text-xs text-gray-400 mb-0.5">Waves</p>
                <h1 className="text-lg font-semibold text-gray-900">Diffraction</h1>
              </div>
              <div className="flex gap-1.5 flex-wrap">
                {CURRICULA.map(c => (
                  <button key={c}
                    onClick={() => setActiveCurricula(p => p.includes(c) ? p.filter(x => x !== c) : [...p, c])}
                    className={`text-xs px-2.5 py-2 rounded-full border font-medium transition ${
                      activeCurricula.includes(c) ? CC[c] + ' border-transparent' : 'bg-white text-gray-400 border-gray-200'
                    }`}>{c}</button>
                ))}
              </div>
            </div>
          </div>
        </section>

        <div className="mx-auto max-w-[100rem] px-4 sm:px-6 py-4 space-y-4">
          <div className="flex gap-1 bg-gray-100 p-1 rounded-xl overflow-x-auto">
            {(Object.keys(MODE_META) as DiffractionMode[]).map(m => (
              <button key={m} onClick={() => { setMode(m); setOpenEx(null); }}
                className={`shrink-0 flex items-center gap-1.5 px-3 py-2 rounded-lg text-xs font-medium transition ${
                  mode === m ? 'bg-white text-indigo-700 shadow-sm' : 'text-gray-500 hover:text-gray-700'
                }`}>
                <span>{MODE_META[m].icon}</span><span>{MODE_META[m].title}</span>
              </button>
            ))}
          </div>

          <div className="flex flex-wrap items-center gap-3 rounded-xl border border-gray-200 bg-white px-4 py-2.5">
            <span className="text-xs text-gray-400">{MODE_META[mode].sub}</span>
            <span className="text-sm font-semibold font-mono text-gray-900">{MODE_META[mode].eq}</span>
          </div>

          <div className="grid grid-cols-1 lg:grid-cols-[1fr_220px] xl:grid-cols-[1fr_220px_260px] gap-4">
            <div className="space-y-3 min-w-0">
              <div ref={canvasBoxRef} className="rounded-2xl border border-gray-200 bg-white p-3 shadow-sm">
                <DiffractionCanvas key={resetKey} mode={mode} wavelengthNm={wavelengthNm} slitWidthNm={slitWidthNm} slitSpacingNm={slitSpacingNm}
                  isRunning={isRunning} isPaused={isPaused}
                  width={canvasSize.width} height={canvasSize.height} />
              </div>

              <div className="flex flex-wrap items-center justify-between gap-2">
                <SimulationControls isRunning={isRunning} isPaused={isPaused}
                  onRun={() => { setIsRunning(true); setIsPaused(false); }}
                  onPause={() => setIsPaused(p => !p)} onReset={reset} />
                <EmbedButton path="/embed/diffraction"
                  title={`${MODE_META[mode].title} — A-Factor STEM Studio`}
                  params={{ mode, wavelength: wavelengthNm, width: slitWidthNm, spacing: slitSpacingNm }} />
              </div>

              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm space-y-4">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide">Parameters</p>
                <Slider label="Wavelength" unit="nm" value={wavelengthNm} min={400} max={700} step={10} set={setWavelengthNm} color="#6366f1" note="Visible light range" />
                {mode === 'single-slit' && (
                  <Slider label="Slit width (a)" unit="nm" value={slitWidthNm} min={200} max={3000} step={50} set={setSlitWidthNm} color="#f59e0b"
                    note="Narrower slit (or longer wavelength) → more spreading" />
                )}
                {mode === 'grating' && (
                  <Slider label="Slit spacing (d)" unit="nm" value={slitSpacingNm} min={500} max={5000} step={50} set={setSlitSpacingNm} color="#f59e0b"
                    note="Smaller spacing → orders spread to wider angles" />
                )}
              </div>
            </div>

            <div className="space-y-3">
              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide mb-3">Calculated</p>
                <div className="space-y-2">
                  {mode === 'single-slit' && <>
                    <StatRow label="λ/a ratio" value={(wavelengthNm / slitWidthNm).toFixed(3)} unit="" color="text-indigo-600" />
                    <StatRow label="First minimum" value={minAngle === null ? 'none (λ>a)' : minAngle.toFixed(1)} unit={minAngle === null ? '' : '°'} color="text-emerald-600" />
                    <StatRow label="Spread fraction" value={(spread * 100).toFixed(0)} unit="%" color="text-amber-600" />
                  </>}
                  {mode === 'grating' && <>
                    <StatRow label="Max order visible" value={`±${maxOrder}`} unit="" color="text-indigo-600" />
                    <StatRow label="n=1 angle" value={maxOrder >= 1 ? (Math.asin(wavelengthNm / slitSpacingNm) * 180 / Math.PI).toFixed(1) : '—'} unit={maxOrder >= 1 ? '°' : ''} color="text-emerald-600" />
                    <StatRow label="Lines per mm" value={(1e6 / slitSpacingNm).toFixed(0)} unit="" color="text-purple-600" />
                  </>}
                </div>
              </div>

              <div className="rounded-2xl border border-gray-100 bg-white p-4">
                <p className="text-xs text-gray-400 mb-2">Curriculum</p>
                <div className="flex flex-wrap gap-1.5">
                  {CURRICULA.map(c => (
                    <span key={c} className={`text-xs font-medium px-2 py-0.5 rounded-full ${
                      activeCurricula.includes(c) ? CC[c] : 'bg-gray-100 text-gray-400'
                    }`}>{c}</span>
                  ))}
                </div>
              </div>
            </div>

            <div className="space-y-3 lg:col-span-2 xl:col-span-1">
              <div className="rounded-2xl border border-amber-100 bg-amber-50 p-4">
                <p className="text-xs font-medium text-amber-700 uppercase tracking-wide mb-3">📋 Teacher notes</p>
                <ul className="space-y-2">
                  {TEACHER_NOTES[mode].map((n, i) => (
                    <li key={i} className="text-xs text-amber-900 leading-relaxed flex gap-2">
                      <span className="text-amber-400 shrink-0 mt-0.5">•</span>{n}
                    </li>
                  ))}
                </ul>
              </div>

              <div className="rounded-2xl border border-gray-200 bg-white p-4">
                <p className="text-xs font-medium text-gray-500 uppercase tracking-wide mb-3">✏️ Exercises</p>
                <div className="space-y-2">
                  {EXERCISES[mode].map((ex, i) => (
                    <div key={i} className="rounded-xl border border-gray-100 overflow-hidden">
                      <button onClick={() => setOpenEx(openEx === i ? null : i)}
                        className="w-full text-left px-3 py-2.5 text-xs text-gray-700 leading-relaxed hover:bg-gray-50 transition flex justify-between gap-2">
                        <span><span className="font-medium text-indigo-600">Q{i + 1}.</span> {ex.q}</span>
                        <span className="text-gray-300 shrink-0 text-sm">{openEx === i ? '▲' : '▼'}</span>
                      </button>
                      {openEx === i && (
                        <div className="px-3 py-2.5 bg-emerald-50 border-t border-gray-100 text-xs text-emerald-800 leading-relaxed">
                          <span className="font-medium">Answer: </span>{ex.a}
                        </div>
                      )}
                    </div>
                  ))}
                </div>
              </div>
            </div>
          </div>
        </div>
      </main>
    </>
  );
}
AFEOF

echo "  → src/app/simulations/polarization/page.tsx"
cat > "src/app/simulations/polarization/page.tsx" << 'AFEOF'
'use client';
import { useState, useCallback, useEffect, useRef, useMemo } from 'react';
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, Label, ReferenceDot } from 'recharts';
import { AppHeader } from '@/components/layout/AppHeader';
import { SimulationControls } from '@/components/simulation/SimulationControls';
import { PolarizationCanvas, PolarizationMode } from '@/components/simulation/PolarizationCanvas';
import { EmbedButton } from '@/components/ui/EmbedButton';
import { malusIntensity, malusCurve } from '@/lib/physics/polarization';
import { useResponsiveCanvasSize } from '@/hooks/useResponsiveCanvasSize';

const CURRICULA = ['WAEC', 'NECO', 'IGCSE', 'SAT', 'JUPEB'];
const CC: Record<string, string> = {
  WAEC: 'bg-indigo-100 text-indigo-700', NECO: 'bg-pink-100 text-pink-700',
  IGCSE: 'bg-emerald-100 text-emerald-700', SAT: 'bg-orange-100 text-orange-700',
  JUPEB: 'bg-purple-100 text-purple-700',
};

const MODE_META: Record<PolarizationMode, { title: string; icon: string; sub: string; eq: string }> = {
  single: { title: 'A single polarizer', icon: '🕶️', sub: 'Unpolarized → plane-polarized', eq: 'transmits one plane of vibration' },
  malus:  { title: "Malus's law",        icon: '📐', sub: 'Two polarizers at an angle',     eq: 'I = I₀cos²θ' },
};

const TEACHER_NOTES: Record<PolarizationMode, string[]> = {
  single: [
    'Light is a TRANSVERSE wave — it vibrates perpendicular to its direction of travel. "Unpolarized" light vibrates in every possible perpendicular direction at once.',
    'A polarizer has a transmission axis — it only lets through the component of vibration ALONG that axis, blocking the rest.',
    'Only transverse waves can be polarized. Sound is a LONGITUDINAL wave (vibrates along its direction of travel) and cannot be polarized — a useful way to distinguish the two in an exam.',
    'Polarizing sunglasses reduce glare because reflected light off water or glass becomes partially polarized (mostly horizontal) — a vertically-oriented lens blocks much of that reflected glare.',
    'LCD screens work by controlling the polarization of light passing through liquid crystals sandwiched between two polarizing filters.',
  ],
  malus: [
    "Malus's law applies to ALREADY plane-polarized light passing through a second polarizer (the \"analyser\"): I = I₀cos²θ, where θ is the angle between the two transmission axes.",
    'At θ=0° (parallel axes): cos²0°=1, full transmission. At θ=90° (crossed axes): cos²90°=0, no light gets through at all.',
    'At θ=45°, exactly HALF the intensity is transmitted (cos²45°=0.5) — a commonly tested value.',
    'Two crossed polarizers block all light — but inserting a THIRD polarizer at 45° between them actually lets some light back through. This surprising result is a classic demonstration and exam favourite.',
    'Malus\u2019s law only describes the SECOND polarizer onward. The first polarizer, acting on unpolarized light, always transmits exactly half the original intensity, regardless of its axis orientation (there\u2019s no "angle" to measure against yet).',
  ],
};

const EXERCISES: Record<PolarizationMode, { q: string; a: string }[]> = {
  single: [
    { q: 'Explain why sound waves cannot be polarized but light waves can.', a: 'Polarization only applies to transverse waves, where the vibration direction can be restricted to one plane. Sound is longitudinal (vibrates along its direction of travel), so there is no perpendicular direction to restrict.' },
    { q: 'Unpolarized light of intensity 40 W/m² passes through a single ideal polarizer. Find the transmitted intensity.', a: 'A single polarizer transmits exactly half of unpolarized light: 40/2 = 20 W/m².' },
    { q: 'State one practical use of polarizing filters.', a: 'Any of: polarizing sunglasses (reduce glare from reflected light), LCD screens, photography filters (reduce reflections/enhance sky contrast), stress analysis in transparent plastics.' },
  ],
  malus: [
    { q: 'Polarized light of intensity 60 W/m² passes through an analyser at 30° to its plane of polarization. Find the transmitted intensity.', a: 'I = I₀cos²θ = 60×cos²30° = 60×0.75 = 45 W/m².' },
    { q: 'At what angle between two polarizers is the transmitted intensity exactly half the incoming polarized intensity?', a: 'cos²θ=0.5 → cosθ=1/√2 → θ=45°.' },
    { q: 'Two polarizers are crossed (90° apart) so no light passes. Explain what happens if a third polarizer is inserted between them at 45° to both.', a: 'The first polarizer transmits light polarized at 0°. The middle (45°) polarizer transmits cos²45°=50% of that, now polarized at 45°. The final (90°) polarizer then transmits cos²45°=50% of THAT (since it is 45° from the middle one\u2019s output) — so some light gets through overall, even though the outer two alone would block everything.' },
  ],
};

function Slider({ label, unit, value, min, max, step, set, color, note }: {
  label: string; unit: string; value: number; min: number; max: number;
  step: number; set: (v: number) => void; color: string; note?: string;
}) {
  return (
    <div className="space-y-1.5">
      <div className="flex justify-between text-xs">
        <span className="text-gray-500">{label}</span>
        <span className="font-medium tabular-nums text-gray-800">{value} <span className="text-gray-400 font-normal">{unit}</span></span>
      </div>
      <input type="range" min={min} max={max} step={step} value={value}
        onChange={e => set(Number(e.target.value))} className="w-full" style={{ accentColor: color }} />
      {note && <p className="text-[10px] text-gray-400">{note}</p>}
    </div>
  );
}

function StatRow({ label, value, unit, color }: { label: string; value: string; unit: string; color: string }) {
  return (
    <div className="flex justify-between items-center rounded-lg bg-gray-50 px-3 py-2">
      <span className="text-xs text-gray-500">{label}</span>
      <span className={`text-xs font-semibold tabular-nums ${color}`}>{value} <span className="text-gray-400 font-normal">{unit}</span></span>
    </div>
  );
}

function MalusGraph({ analyzerAngle }: { analyzerAngle: number }) {
  const data = useMemo(() => malusCurve(100), []);
  const I = malusIntensity(100, analyzerAngle);
  return (
    <ResponsiveContainer width="100%" height={190}>
      <LineChart data={data} margin={{ top: 8, right: 16, left: 10, bottom: 28 }}>
        <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
        <XAxis dataKey="angle" type="number" domain={[0, 180]} tick={{ fontSize: 10 }}>
          <Label value="θ between polarizers (°)" position="insideBottom" offset={-16} style={{ fontSize: 10, fill: '#94a3b8' }} />
        </XAxis>
        <YAxis tick={{ fontSize: 10 }}>
          <Label value="Transmitted I (% of I₀)" angle={-90} position="insideLeft" offset={12} style={{ fontSize: 10, fill: '#94a3b8' }} />
        </YAxis>
        <Tooltip formatter={(v: unknown) => [Number(v).toFixed(1) + '%', 'I']} labelFormatter={a => `θ=${a}°`} />
        <Line type="monotone" dataKey="I" stroke="#6366f1" strokeWidth={2} dot={false} isAnimationActive={false} />
        <ReferenceDot x={analyzerAngle} y={I} r={6} fill="#ef4444" stroke="#fff" strokeWidth={2} />
      </LineChart>
    </ResponsiveContainer>
  );
}

export default function PolarizationPage() {
  const [mode, setMode] = useState<PolarizationMode>('single');
  const [isRunning, setIsRunning] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const [resetKey, setResetKey] = useState(0);
  const [openEx, setOpenEx] = useState<number | null>(null);
  const [activeCurricula, setActiveCurricula] = useState(['WAEC', 'IGCSE', 'SAT']);

  const [polarizerAngle, setPolarizerAngle] = useState(30);
  const [analyzerAngle, setAnalyzerAngle] = useState(45);

  const reset = useCallback(() => { setIsRunning(false); setIsPaused(false); setResetKey(k => k + 1); }, []);
  const resetTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  useEffect(() => {
    if (resetTimer.current) clearTimeout(resetTimer.current);
    resetTimer.current = setTimeout(reset, 100);
  }, [mode, polarizerAngle, analyzerAngle, reset]);

  const canvasBoxRef = useRef<HTMLDivElement>(null);
  const canvasSize = useResponsiveCanvasSize(canvasBoxRef, 660, 260, 980);

  const transmitted = malusIntensity(100, analyzerAngle);

  return (
    <>
      <AppHeader />
      <main className="min-h-screen bg-gray-50">
        <section className="border-b border-gray-200 bg-white">
          <div className="mx-auto max-w-[100rem] px-4 sm:px-6 py-4">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
              <div>
                <p className="text-xs text-gray-400 mb-0.5">Waves</p>
                <h1 className="text-lg font-semibold text-gray-900">Polarization</h1>
              </div>
              <div className="flex gap-1.5 flex-wrap">
                {CURRICULA.map(c => (
                  <button key={c}
                    onClick={() => setActiveCurricula(p => p.includes(c) ? p.filter(x => x !== c) : [...p, c])}
                    className={`text-xs px-2.5 py-2 rounded-full border font-medium transition ${
                      activeCurricula.includes(c) ? CC[c] + ' border-transparent' : 'bg-white text-gray-400 border-gray-200'
                    }`}>{c}</button>
                ))}
              </div>
            </div>
          </div>
        </section>

        <div className="mx-auto max-w-[100rem] px-4 sm:px-6 py-4 space-y-4">
          <div className="flex gap-1 bg-gray-100 p-1 rounded-xl overflow-x-auto">
            {(Object.keys(MODE_META) as PolarizationMode[]).map(m => (
              <button key={m} onClick={() => { setMode(m); setOpenEx(null); }}
                className={`shrink-0 flex items-center gap-1.5 px-3 py-2 rounded-lg text-xs font-medium transition ${
                  mode === m ? 'bg-white text-indigo-700 shadow-sm' : 'text-gray-500 hover:text-gray-700'
                }`}>
                <span>{MODE_META[m].icon}</span><span>{MODE_META[m].title}</span>
              </button>
            ))}
          </div>

          <div className="flex flex-wrap items-center gap-3 rounded-xl border border-gray-200 bg-white px-4 py-2.5">
            <span className="text-xs text-gray-400">{MODE_META[mode].sub}</span>
            <span className="text-sm font-semibold font-mono text-gray-900">{MODE_META[mode].eq}</span>
          </div>

          <div className="grid grid-cols-1 lg:grid-cols-[1fr_220px] xl:grid-cols-[1fr_220px_260px] gap-4">
            <div className="space-y-3 min-w-0">
              <div ref={canvasBoxRef} className="rounded-2xl border border-gray-200 bg-white p-3 shadow-sm">
                <PolarizationCanvas key={resetKey} mode={mode} polarizerAngle={polarizerAngle} analyzerAngle={analyzerAngle}
                  isRunning={isRunning} isPaused={isPaused}
                  width={canvasSize.width} height={canvasSize.height} />
              </div>

              <div className="flex flex-wrap items-center justify-between gap-2">
                <SimulationControls isRunning={isRunning} isPaused={isPaused}
                  onRun={() => { setIsRunning(true); setIsPaused(false); }}
                  onPause={() => setIsPaused(p => !p)} onReset={reset} />
                <EmbedButton path="/embed/polarization"
                  title={`${MODE_META[mode].title} — A-Factor STEM Studio`}
                  params={mode === 'single' ? { mode, angle: polarizerAngle } : { mode, angle: analyzerAngle }} />
              </div>

              {mode === 'malus' && (
                <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                  <p className="text-xs font-medium text-gray-400 uppercase tracking-wide mb-2">Transmitted intensity vs angle</p>
                  <MalusGraph analyzerAngle={analyzerAngle} />
                  <p className="text-[10px] text-gray-400 mt-2 text-center">I = I₀cos²θ — full transmission at 0°, zero at 90° (crossed)</p>
                </div>
              )}

              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm space-y-4">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide">Parameters</p>
                {mode === 'single' && (
                  <Slider label="Transmission axis" unit="°" value={polarizerAngle} min={0} max={180} step={5} set={setPolarizerAngle} color="#6366f1" note="Measured from vertical" />
                )}
                {mode === 'malus' && (
                  <Slider label="Analyser angle θ" unit="°" value={analyzerAngle} min={0} max={180} step={1} set={setAnalyzerAngle} color="#6366f1" note="Angle between the two polarizers" />
                )}
              </div>
            </div>

            <div className="space-y-3">
              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide mb-3">Calculated</p>
                <div className="space-y-2">
                  {mode === 'single' && <>
                    <StatRow label="Transmission axis" value={polarizerAngle.toString()} unit="°" color="text-indigo-600" />
                    <StatRow label="Through 1 polarizer" value="50" unit="% of I₀" color="text-emerald-600" />
                    <StatRow label="Result" value="plane-polarized" unit="" color="text-purple-600" />
                  </>}
                  {mode === 'malus' && <>
                    <StatRow label="Angle θ" value={analyzerAngle.toString()} unit="°" color="text-indigo-600" />
                    <StatRow label="cos²θ" value={Math.pow(Math.cos(analyzerAngle * Math.PI / 180), 2).toFixed(3)} unit="" color="text-emerald-600" />
                    <StatRow label="Transmitted I" value={transmitted.toFixed(1)} unit="% of I₀" color="text-amber-600" />
                    <StatRow label="State" value={analyzerAngle < 5 ? 'aligned — max' : analyzerAngle > 85 && analyzerAngle < 95 ? 'crossed — zero' : 'partial'} unit="" color="text-rose-500" />
                  </>}
                </div>
              </div>

              <div className="rounded-2xl border border-gray-100 bg-white p-4">
                <p className="text-xs text-gray-400 mb-2">Curriculum</p>
                <div className="flex flex-wrap gap-1.5">
                  {CURRICULA.map(c => (
                    <span key={c} className={`text-xs font-medium px-2 py-0.5 rounded-full ${
                      activeCurricula.includes(c) ? CC[c] : 'bg-gray-100 text-gray-400'
                    }`}>{c}</span>
                  ))}
                </div>
              </div>
            </div>

            <div className="space-y-3 lg:col-span-2 xl:col-span-1">
              <div className="rounded-2xl border border-amber-100 bg-amber-50 p-4">
                <p className="text-xs font-medium text-amber-700 uppercase tracking-wide mb-3">📋 Teacher notes</p>
                <ul className="space-y-2">
                  {TEACHER_NOTES[mode].map((n, i) => (
                    <li key={i} className="text-xs text-amber-900 leading-relaxed flex gap-2">
                      <span className="text-amber-400 shrink-0 mt-0.5">•</span>{n}
                    </li>
                  ))}
                </ul>
              </div>

              <div className="rounded-2xl border border-gray-200 bg-white p-4">
                <p className="text-xs font-medium text-gray-500 uppercase tracking-wide mb-3">✏️ Exercises</p>
                <div className="space-y-2">
                  {EXERCISES[mode].map((ex, i) => (
                    <div key={i} className="rounded-xl border border-gray-100 overflow-hidden">
                      <button onClick={() => setOpenEx(openEx === i ? null : i)}
                        className="w-full text-left px-3 py-2.5 text-xs text-gray-700 leading-relaxed hover:bg-gray-50 transition flex justify-between gap-2">
                        <span><span className="font-medium text-indigo-600">Q{i + 1}.</span> {ex.q}</span>
                        <span className="text-gray-300 shrink-0 text-sm">{openEx === i ? '▲' : '▼'}</span>
                      </button>
                      {openEx === i && (
                        <div className="px-3 py-2.5 bg-emerald-50 border-t border-gray-100 text-xs text-emerald-800 leading-relaxed">
                          <span className="font-medium">Answer: </span>{ex.a}
                        </div>
                      )}
                    </div>
                  ))}
                </div>
              </div>
            </div>
          </div>
        </div>
      </main>
    </>
  );
}
AFEOF

echo "  → src/app/embed/diffraction/page.tsx"
cat > "src/app/embed/diffraction/page.tsx" << 'AFEOF'
'use client';
import { Suspense, useState, useCallback, useEffect, useRef } from 'react';
import { useSearchParams } from 'next/navigation';
import { DiffractionCanvas, DiffractionMode } from '@/components/simulation/DiffractionCanvas';
import { SimulationControls } from '@/components/simulation/SimulationControls';

function num(sp: URLSearchParams, key: string, fallback: number, min: number, max: number) {
  const v = Number(sp.get(key));
  return Number.isFinite(v) && sp.get(key) !== null ? Math.min(max, Math.max(min, v)) : fallback;
}

function Slider({ label, unit, value, min, max, step, set, color }: {
  label: string; unit: string; value: number; min: number; max: number;
  step: number; set: (v: number) => void; color: string;
}) {
  return (
    <div className="space-y-1">
      <div className="flex justify-between text-xs">
        <span className="text-gray-500">{label}</span>
        <span className="font-medium tabular-nums text-gray-800">{value} <span className="font-normal text-gray-400">{unit}</span></span>
      </div>
      <input type="range" min={min} max={max} step={step} value={value}
        onChange={e => set(Number(e.target.value))} className="w-full" style={{ accentColor: color }} />
    </div>
  );
}

function PoweredBy() {
  return (
    <p className="text-center text-[10px] text-gray-400">
      Powered by{' '}
      <a href="/" target="_blank" rel="noopener noreferrer" className="font-medium text-indigo-500 hover:text-indigo-600">
        A-Factor STEM Studio
      </a>
    </p>
  );
}

function DiffractionEmbedInner() {
  const sp = useSearchParams();
  const mode = ((): DiffractionMode => (sp.get('mode') === 'grating' ? 'grating' : 'single-slit'))();
  const showControls = sp.get('controls') !== '0';

  const [wavelengthNm, setWavelengthNm] = useState(() => num(sp, 'wavelength', 550, 400, 700));
  const [slitWidthNm, setSlitWidthNm] = useState(() => num(sp, 'width', 1000, 200, 3000));
  const [slitSpacingNm, setSlitSpacingNm] = useState(() => num(sp, 'spacing', 2000, 500, 5000));

  const [isRunning, setIsRunning] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const [resetKey, setResetKey] = useState(0);
  const reset = useCallback(() => { setIsRunning(false); setIsPaused(false); setResetKey(k => k + 1); }, []);
  const resetTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  useEffect(() => {
    if (resetTimer.current) clearTimeout(resetTimer.current);
    resetTimer.current = setTimeout(reset, 100);
  }, [mode, wavelengthNm, slitWidthNm, slitSpacingNm, reset]);

  return (
    <div className="mx-auto max-w-2xl space-y-3 p-3 sm:p-4">
      <DiffractionCanvas key={resetKey} mode={mode} wavelengthNm={wavelengthNm} slitWidthNm={slitWidthNm} slitSpacingNm={slitSpacingNm}
        isRunning={isRunning} isPaused={isPaused} width={640} height={280} />
      <SimulationControls isRunning={isRunning} isPaused={isPaused}
        onRun={() => { setIsRunning(true); setIsPaused(false); }}
        onPause={() => setIsPaused(p => !p)} onReset={reset} />
      {showControls && (
        <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm space-y-3">
          <p className="text-xs font-medium uppercase tracking-wide text-gray-400">Parameters</p>
          <Slider label="Wavelength" unit="nm" value={wavelengthNm} min={400} max={700} step={10} set={setWavelengthNm} color="#6366f1" />
          {mode === 'single-slit'
            ? <Slider label="Slit width" unit="nm" value={slitWidthNm} min={200} max={3000} step={50} set={setSlitWidthNm} color="#f59e0b" />
            : <Slider label="Slit spacing" unit="nm" value={slitSpacingNm} min={500} max={5000} step={50} set={setSlitSpacingNm} color="#f59e0b" />}
        </div>
      )}
      <PoweredBy />
    </div>
  );
}

export default function DiffractionEmbedPage() {
  return (
    <Suspense fallback={<div className="p-8 text-center text-xs text-gray-400">Loading simulation…</div>}>
      <DiffractionEmbedInner />
    </Suspense>
  );
}
AFEOF

echo "  → src/app/embed/polarization/page.tsx"
cat > "src/app/embed/polarization/page.tsx" << 'AFEOF'
'use client';
import { Suspense, useState, useCallback, useEffect, useRef } from 'react';
import { useSearchParams } from 'next/navigation';
import { PolarizationCanvas, PolarizationMode } from '@/components/simulation/PolarizationCanvas';
import { SimulationControls } from '@/components/simulation/SimulationControls';

function num(sp: URLSearchParams, key: string, fallback: number, min: number, max: number) {
  const v = Number(sp.get(key));
  return Number.isFinite(v) && sp.get(key) !== null ? Math.min(max, Math.max(min, v)) : fallback;
}

function Slider({ label, unit, value, min, max, step, set, color }: {
  label: string; unit: string; value: number; min: number; max: number;
  step: number; set: (v: number) => void; color: string;
}) {
  return (
    <div className="space-y-1">
      <div className="flex justify-between text-xs">
        <span className="text-gray-500">{label}</span>
        <span className="font-medium tabular-nums text-gray-800">{value} <span className="font-normal text-gray-400">{unit}</span></span>
      </div>
      <input type="range" min={min} max={max} step={step} value={value}
        onChange={e => set(Number(e.target.value))} className="w-full" style={{ accentColor: color }} />
    </div>
  );
}

function PoweredBy() {
  return (
    <p className="text-center text-[10px] text-gray-400">
      Powered by{' '}
      <a href="/" target="_blank" rel="noopener noreferrer" className="font-medium text-indigo-500 hover:text-indigo-600">
        A-Factor STEM Studio
      </a>
    </p>
  );
}

function PolarizationEmbedInner() {
  const sp = useSearchParams();
  const mode = ((): PolarizationMode => (sp.get('mode') === 'malus' ? 'malus' : 'single'))();
  const showControls = sp.get('controls') !== '0';

  const [polarizerAngle, setPolarizerAngle] = useState(() => num(sp, 'angle', 30, 0, 180));
  const [analyzerAngle, setAnalyzerAngle] = useState(() => num(sp, 'angle', 45, 0, 180));

  const [isRunning, setIsRunning] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const [resetKey, setResetKey] = useState(0);
  const reset = useCallback(() => { setIsRunning(false); setIsPaused(false); setResetKey(k => k + 1); }, []);
  const resetTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  useEffect(() => {
    if (resetTimer.current) clearTimeout(resetTimer.current);
    resetTimer.current = setTimeout(reset, 100);
  }, [mode, polarizerAngle, analyzerAngle, reset]);

  return (
    <div className="mx-auto max-w-2xl space-y-3 p-3 sm:p-4">
      <PolarizationCanvas key={resetKey} mode={mode} polarizerAngle={polarizerAngle} analyzerAngle={analyzerAngle}
        isRunning={isRunning} isPaused={isPaused} width={640} height={240} />
      <SimulationControls isRunning={isRunning} isPaused={isPaused}
        onRun={() => { setIsRunning(true); setIsPaused(false); }}
        onPause={() => setIsPaused(p => !p)} onReset={reset} />
      {showControls && (
        <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm space-y-3">
          <p className="text-xs font-medium uppercase tracking-wide text-gray-400">Parameters</p>
          {mode === 'single'
            ? <Slider label="Transmission axis" unit="°" value={polarizerAngle} min={0} max={180} step={5} set={setPolarizerAngle} color="#6366f1" />
            : <Slider label="Analyser angle" unit="°" value={analyzerAngle} min={0} max={180} step={1} set={setAnalyzerAngle} color="#6366f1" />}
        </div>
      )}
      <PoweredBy />
    </div>
  );
}

export default function PolarizationEmbedPage() {
  return (
    <Suspense fallback={<div className="p-8 text-center text-xs text-gray-400">Loading simulation…</div>}>
      <PolarizationEmbedInner />
    </Suspense>
  );
}
AFEOF

echo "  → src/app/simulations/page.tsx"
cat > "src/app/simulations/page.tsx" << 'AFEOF'
'use client';
import { useState } from 'react';
import Link from 'next/link';
import { AppHeader } from '@/components/layout/AppHeader';

const CURRICULA = ['WAEC', 'NECO', 'IGCSE', 'SAT', 'JUPEB'] as const;

const SIMULATIONS = [
  {
    slug: 'projectile-motion',
    href: '/simulations/projectile-motion',
    title: 'Projectile motion',
    description: 'Launch a projectile and explore range, height, and trajectory in real time.',
    icon: '🎯',
    tags: ['WAEC', 'NECO', 'IGCSE', 'SAT', 'JUPEB'],
    topic: 'Mechanics',
    status: 'live',
  },
  {
    slug: 'gas-laws',
    href: '/simulations/gas-laws',
    title: "Gas laws (Boyle & Charles)",
    description: 'Compress gas to see pressure rise. Heat it to watch volume expand.',
    icon: '🧪',
    tags: ['WAEC', 'NECO', 'IGCSE', 'SAT'],
    topic: 'Thermal physics',
    status: 'live',
  },
  {
    slug: 'newtons-second-law',
    href: '/simulations/newtons-laws',
    title: "Newton's 2nd law",
    description: 'Apply forces to a block and observe acceleration in real time.',
    icon: '⚡',
    tags: ['WAEC', 'NECO', 'IGCSE', 'SAT', 'JUPEB'],
    topic: 'Mechanics',
    status: 'live',
  },
  {
    slug: 'consequences-of-newtons-motion-laws',
    href: '/simulations/consequences-of-motion',
    title: "Consequences of Newton's motion laws",
    description: 'Explore inertia, momentum and action-reaction with interactive experiments.',
    icon: '🚈',
    tags: ['WAEC', 'NECO', 'IGCSE', 'SAT', 'JUPEB'],
    topic: 'Mechanics',
    status: 'live',
  },
  {
    slug: 'simple-harmonic-motion',
    href: '/simulations/oscillations',
    title: 'Simple harmonic motion',
    description: 'Oscillating mass-spring system with displacement, velocity and energy graphs.',
    icon: '〰️',
    tags: ['WAEC', 'NECO', 'IGCSE', 'JUPEB'],
    topic: 'Mechanics',
    status: 'live',
  },
  {
    slug: 'ohms-law',
    href: '/simulations/ohms-law',
    title: "Ohm's law & circuits",
    description: 'Adjust voltage and resistance, measure current. Build series and parallel circuits.',
    icon: '⚡',
    tags: ['WAEC', 'NECO', 'IGCSE', 'SAT', 'JUPEB'],
    topic: 'Electricity',
    status: 'live',
  },
  {
    slug: 'waves',
    href: '/simulations/waves',
    title: 'Wave motion',
    description: 'Visualise transverse and longitudinal waves. Explore frequency and amplitude.',
    icon: '🌊',
    tags: ['WAEC', 'NECO', 'IGCSE', 'SAT'],
    topic: 'Waves',
    status: 'live',
  },
  {
    slug: 'diffraction',
    href: '/simulations/diffraction',
    title: 'Diffraction',
    description: 'Waves spreading through a single slit, and diffraction-grating spectral orders.',
    icon: '🌈',
    tags: ['WAEC', 'NECO', 'IGCSE', 'JUPEB'],
    topic: 'Waves',
    status: 'live',
  },
  {
    slug: 'polarization',
    href: '/simulations/polarization',
    title: 'Polarization',
    description: 'Unpolarized light through a single filter, and Malus\u2019s law with two polarizers.',
    icon: '🕶️',
    tags: ['IGCSE', 'SAT', 'JUPEB'],
    topic: 'Waves',
    status: 'live',
  },
  {
    slug: 'refraction',
    href: '/simulations/refraction',
    title: 'Refraction & lenses',
    description: 'Trace light rays through convex and concave lenses. Find focal length.',
    icon: '🔭',
    tags: ['WAEC', 'NECO', 'IGCSE', 'SAT'],
    topic: 'Optics',
    status: 'live',
  },
  {
    slug: 'reflection',
    href: '/simulations/reflection',
    title: 'Reflection',
    description: 'The law of reflection at a plane mirror, plus concave and convex mirror ray diagrams.',
    icon: '🪞',
    tags: ['WAEC', 'NECO', 'IGCSE', 'SAT'],
    topic: 'Optics',
    status: 'live',
  },
  {
    slug: 'radioactive-decay',
    href: '/simulations/radioactive-decay',
    title: 'Radioactive decay',
    description: 'Watch nuclei decay over time. Explore half-life with live decay curves.',
    icon: '☢️',
    tags: ['WAEC', 'NECO', 'IGCSE', 'JUPEB'],
    topic: 'Modern physics',
    status: 'live',
  },
  {
    slug: 'photoelectric-effect',
    href: '/simulations/photoelectric-effect',
    title: 'Photoelectric effect',
    description: "Fire light at a metal plate and test Einstein's equation hf = φ + KEmax.",
    icon: '💡',
    tags: ['WAEC', 'IGCSE', 'JUPEB'],
    topic: 'Modern physics',
    status: 'live',
  },
  {
    slug: 'de-broglie',
    href: '/simulations/de-broglie',
    title: 'De Broglie hypothesis',
    description: 'See matter waves in action: λ = h/mv for particles from electrons to cricket balls.',
    icon: '〰️',
    tags: ['IGCSE', 'JUPEB', 'SAT'],
    topic: 'Modern physics',
    status: 'live',
  },
  {
    slug: 'x-rays',
    href: '/simulations/x-rays',
    title: 'X-rays',
    description: 'Explore X-ray tube production, the continuous spectrum, and the Duane–Hunt limit.',
    icon: '🩻',
    tags: ['WAEC', 'IGCSE', 'JUPEB'],
    topic: 'Modern physics',
    status: 'live',
  },
  {
    slug: 'friction',
    href: '/simulations/friction',
    title: 'Friction',
    description: 'Static vs kinetic friction on flat and inclined surfaces, with the angle of repose.',
    icon: '🧱',
    tags: ['WAEC', 'NECO', 'IGCSE', 'SAT'],
    topic: 'Mechanics',
    status: 'live',
  },
  {
    slug: 'heat-transfer',
    href: '/simulations/heat-transfer',
    title: 'Modes of heat transfer',
    description: 'Conduction, convection, and radiation compared side by side with live particle animation.',
    icon: '🔥',
    tags: ['WAEC', 'NECO', 'IGCSE', 'SAT'],
    topic: 'Thermal physics',
    status: 'live',
  },
  {
    slug: 'elasticity',
    href: '/simulations/elasticity',
    title: 'Elasticity',
    description: "Hooke's law with a loaded spring, and Young's modulus for a stretched wire.",
    icon: '🪢',
    tags: ['WAEC', 'NECO', 'IGCSE', 'SAT'],
    topic: 'Mechanics',
    status: 'live',
  },
  {
    slug: 'equilibrium-of-forces',
    href: '/simulations/equilibrium-of-forces',
    title: 'Equilibrium of forces',
    description: 'Static & dynamic equilibrium, coplanar forces, moments, and floating bodies.',
    icon: '⚖️',
    tags: ['WAEC', 'NECO', 'IGCSE', 'JUPEB'],
    topic: 'Mechanics',
    status: 'live',
  },
];

const TOPICS = ['All', 'Mechanics', 'Electricity', 'Waves', 'Optics', 'Thermal physics', 'Modern physics'];

const CURRICULUM_COLORS: Record<string, string> = {
  WAEC:  'bg-indigo-100 text-indigo-700',
  NECO:  'bg-pink-100 text-pink-700',
  IGCSE: 'bg-emerald-100 text-emerald-700',
  SAT:   'bg-orange-100 text-orange-700',
  JUPEB: 'bg-purple-100 text-purple-700',
};

export default function SimulationsPage() {
  const [selectedTopic, setSelectedTopic] = useState<string>('All');
  const visibleSims = selectedTopic === 'All'
    ? SIMULATIONS
    : SIMULATIONS.filter(sim => sim.topic === selectedTopic);

  return (
    <>
      <AppHeader />
      <main className="min-h-screen bg-gray-50">

        {/* Hero */}
        <section className="border-b border-gray-200 bg-white">
          <div className="mx-auto max-w-7xl px-4 sm:px-6 py-10 sm:py-14">
            <div className="max-w-2xl">
              <div className="mb-3 flex flex-wrap gap-2">
                {CURRICULA.map(c => (
                  <span key={c} className={`text-xs font-medium px-2.5 py-0.5 rounded-full ${CURRICULUM_COLORS[c]}`}>{c}</span>
                ))}
              </div>
              <h1 className="text-2xl sm:text-3xl font-semibold text-gray-900 leading-tight mb-3">
                Physics simulations for every curriculum
              </h1>
              <p className="text-sm sm:text-base text-gray-500 leading-relaxed">
                Interactive, AI-powered simulations built for WAEC, NECO, IGCSE, SAT and JUPEB students.
                Type a prompt or pick a topic below.
              </p>
            </div>
          </div>
        </section>

        {/* Simulations grid */}
        <section className="mx-auto max-w-7xl px-4 sm:px-6 py-8">

          {/* Topic filter — scroll on mobile */}
          <div className="flex gap-2 overflow-x-auto pb-2 mb-6 scrollbar-hide">
            {TOPICS.map(t => {
              const count = t === 'All' ? SIMULATIONS.length : SIMULATIONS.filter(sim => sim.topic === t).length;
              const active = selectedTopic === t;
              return (
                <button key={t} onClick={() => setSelectedTopic(t)}
                  className={`shrink-0 flex items-center gap-1.5 rounded-full border px-4 py-1.5 text-xs font-medium transition whitespace-nowrap ${
                    active
                      ? 'border-indigo-600 bg-indigo-600 text-white'
                      : 'border-gray-200 bg-white text-gray-600 hover:border-indigo-300 hover:text-indigo-700'
                  }`}>
                  {t}
                  <span className={`rounded-full px-1.5 text-[10px] ${active ? 'bg-white/20' : 'bg-gray-100 text-gray-400'}`}>
                    {count}
                  </span>
                </button>
              );
            })}
          </div>

          {/* Cards grid */}
          {visibleSims.length === 0 ? (
            <div className="rounded-2xl border border-dashed border-gray-200 py-16 text-center">
              <p className="text-sm text-gray-400">No simulations in {selectedTopic} yet.</p>
            </div>
          ) : (
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
            {visibleSims.map(sim => (
              <div key={sim.slug} className={`group relative rounded-2xl border bg-white overflow-hidden transition ${
                sim.status === 'live'
                  ? 'border-gray-200 hover:border-indigo-300 hover:shadow-md cursor-pointer'
                  : 'border-gray-100 opacity-70'
              }`}>
                {sim.status === 'coming' && (
                  <div className="absolute top-3 right-3 rounded-full bg-gray-100 px-2 py-0.5 text-[10px] font-medium text-gray-400">
                    Coming soon
                  </div>
                )}
                {sim.status === 'live' && (
                  <div className="absolute top-3 right-3 flex items-center gap-1">
                    <span className="h-1.5 w-1.5 rounded-full bg-emerald-500 animate-pulse"/>
                    <span className="text-[10px] font-medium text-emerald-600">Live</span>
                  </div>
                )}

                <Link href={sim.status === 'live' ? sim.href : '#'}
                  className={sim.status !== 'live' ? 'pointer-events-none' : ''}>
                  <div className="p-5">
                    {/* Icon + topic */}
                    <div className="flex items-center justify-between mb-3">
                      <span className="text-2xl">{sim.icon}</span>
                      <span className="text-[10px] font-medium text-gray-400 uppercase tracking-wide">{sim.topic}</span>
                    </div>

                    <h3 className="text-sm font-semibold text-gray-900 mb-1.5 group-hover:text-indigo-700 transition">
                      {sim.title}
                    </h3>
                    <p className="text-xs text-gray-500 leading-relaxed mb-4">{sim.description}</p>

                    {/* Curriculum tags */}
                    <div className="flex flex-wrap gap-1">
                      {sim.tags.map(tag => (
                        <span key={tag} className={`text-[10px] font-medium px-2 py-0.5 rounded-full ${CURRICULUM_COLORS[tag]}`}>
                          {tag}
                        </span>
                      ))}
                    </div>
                  </div>

                  {sim.status === 'live' && (
                    <div className="border-t border-gray-100 px-5 py-3 flex items-center justify-between">
                      <span className="text-xs font-medium text-indigo-600">Open simulation</span>
                      <svg width="14" height="14" viewBox="0 0 14 14" fill="none" stroke="#6366f1" strokeWidth="1.5" strokeLinecap="round">
                        <path d="M2 7h10M8 3l4 4-4 4"/>
                      </svg>
                    </div>
                  )}
                </Link>
              </div>
            ))}
          </div>
          )}

          {/* Coming soon note */}
          <p className="text-center text-xs text-gray-400 mt-8">
            More simulations being added weekly. Suggest a topic at{' '}
            <a href="mailto:hello@afactor.app" className="text-indigo-500 hover:underline">hello@afactor.app</a>
          </p>
        </section>
      </main>
    </>
  );
}
AFEOF

echo ""
echo "✓ Patch v20 applied — 9 files written."
echo ""
echo "Next steps:"
echo "  rm -rf .next"
echo "  npm run dev"
echo ""
echo "Check:"
echo "  /simulations/diffraction  -- single-slit spreading + grating orders"
echo "  /simulations/polarization -- single polarizer + Malus's law graph"
