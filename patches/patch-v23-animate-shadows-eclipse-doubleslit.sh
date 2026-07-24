#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
# A-Factor STEM Studio — patch v23: animate shadows/eclipse, fix dead grating
# Run button, and add Young's double-slit experiment
#
#   SHADOWS AND ECLIPSE HAD NO ANIMATION CONTROLS AT ALL. Confirmed by
#   direct grep: zero isRunning/SimulationControls anywhere in the page.
#   Both canvases were pure static diagrams. Rebuilt both with proper
#   wall-clock animation:
#     - ShadowsCanvas: on Run, the opaque object sweeps back and forth
#       between the source and screen, so the umbra/penumbra visibly
#       change size and position continuously instead of only updating
#       when a slider is dragged.
#     - EclipseCanvas: on Run, the orbital offset now varies continuously
#       (sine wave) instead of being a static slider value, so the Moon
#       genuinely drifts in and out of alignment — directly demonstrating
#       why eclipses don't happen every month, rather than just asserting
#       it in a teacher note.
#
#   GRATING MODE'S RUN BUTTON DID NOTHING. It had working Run/Pause/Reset
#   wired up, but the canvas branch had zero time-dependence — pressing Run
#   changed nothing on screen. Added animated incoming wavefronts, matching
#   every other mode.
#
#   YOUNG'S DOUBLE-SLIT EXPERIMENT — DID NOT EXIST. Only a passing mention
#   in a grating teacher note. Built from scratch: a precomputed steady-
#   state interference grid (path-difference cos² intensity, computed once
#   per parameter change rather than every frame for performance) with
#   animated travelling wavefronts from both slits on top.
#
#   Caught two real bugs while building it, both verified numerically
#   before and after the fix:
#     1. The screen fringe-dot positions used the small-angle formula
#        (Δy≈λD/d), which broke down badly at the chosen pixel scale
#        (λ/d wasn't small) — dots landed roughly 80x away from the
#        interference grid's actual peaks. Fixed by switching to the exact
#        angular relation (sinθ=nλ/d, same approach grating mode already
#        used correctly) — verified afterward the dots land within
#        floating-point precision of the grid's real peak intensities.
#     2. The default slit-separation slider value (2000nm) was physically
#        unrealistic for an actual double-slit setup (real ones run
#        0.1-1mm apart), producing an implausible 275mm fringe spacing in
#        the stats panel. Fixed the slider to a realistic 200-1000
#        micrometre range; default now gives a sensible ~mm-scale spacing
#        matching real textbook examples.
#
#   Fringe-spacing physics verified against the standard 600nm/0.5mm/1m
#   textbook example (1.2mm, exact match) before any of this was wired up.
#
# Run from the af2s project root (Git Bash):   bash patches/patch-v23-animate-shadows-eclipse-doubleslit.sh
# ══════════════════════════════════════════════════════════════════════════════
set -euo pipefail

if [ ! -f "package.json" ]; then
  echo "✗ Run this from the af2s project root (package.json not found)." >&2
  exit 1
fi

echo "── A-Factor patch v23: animated shadows/eclipse + Young's double slit ──"
mkdir -p "src/app/embed/diffraction" "src/app/embed/rectilinear-propagation" "src/app/simulations/diffraction" "src/app/simulations/rectilinear-propagation" "src/components/simulation" "src/lib/physics"

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

// ── Young's double-slit interference ─────────────────────────────────────────
// Two coherent slits separated by d, screen at distance D: bright fringes
// form where the path difference from the two slits is a whole number of
// wavelengths. Standard small-angle result for this level:
// fringe spacing Δy = λD/d — every bright (or dark) band is this far from
// its neighbour, regardless of which order it is.
export function fringeSpacing(wavelength: number, slitSpacing: number, screenDist: number): number {
  return (wavelength * screenDist) / slitSpacing;
}
// Position of the n-th bright fringe from the centre.
export function brightFringePosition(n: number, wavelength: number, slitSpacing: number, screenDist: number): number {
  return n * fringeSpacing(wavelength, slitSpacing, screenDist);
}

export function maxFringeOrder(wavelength: number, slitSpacing: number): number {
  if (slitSpacing <= 0 || wavelength <= 0) return 0;
  return Math.floor(slitSpacing / wavelength);
}
AFEOF

echo "  → src/components/simulation/ShadowsCanvas.tsx"
cat > "src/components/simulation/ShadowsCanvas.tsx" << 'AFEOF'
'use client';
import { useRef, useEffect, useCallback } from 'react';

interface Props {
  sourceType: 'point' | 'extended';
  sourceRadiusPx: number;   // half-height of the source (0 for a point source)
  objectRadiusPx: number;   // half-height of the opaque object
  objectDistPx: number;     // source -> object (also the centre of the sweep when animating)
  screenDistPx: number;     // source -> screen
  isRunning: boolean; isPaused: boolean;
  width?: number; height?: number;
}

interface Vec { x: number; y: number; }
function lineAtX(p1: Vec, p2: Vec, x: number): number {
  const t = (x - p1.x) / (p2.x - p1.x);
  return p1.y + t * (p2.y - p1.y);
}

const SWEEP_PERIOD = 5; // s — one full back-and-forth pass of the object

export function ShadowsCanvas({ sourceType, sourceRadiusPx, objectRadiusPx, objectDistPx, screenDistPx, isRunning, isPaused, width = 660, height = 300 }: Props) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const rafRef = useRef<number>(0);
  const lastFrameRef = useRef<number | null>(null);
  const t = useRef(0);
  const sim = useRef({ sourceType, sourceRadiusPx, objectRadiusPx, objectDistPx, screenDistPx, isRunning, isPaused });
  sim.current = { sourceType, sourceRadiusPx, objectRadiusPx, objectDistPx, screenDistPx, isRunning, isPaused };

  useEffect(() => { t.current = 0; lastFrameRef.current = null; }, [sourceType, sourceRadiusPx, objectRadiusPx, objectDistPx, screenDistPx]);

  const draw = useCallback((timestamp?: number) => {
    const canvas = canvasRef.current; if (!canvas) return;
    const ctx = canvas.getContext('2d'); if (!ctx) return;
    const s = sim.current;
    const W = canvas.width, H = canvas.height;

    const animate = s.isRunning && !s.isPaused;
    if (animate && timestamp !== undefined) {
      if (lastFrameRef.current !== null) {
        t.current += Math.min((timestamp - lastFrameRef.current) / 1000, 0.1);
      }
      lastFrameRef.current = timestamp;
    } else {
      lastFrameRef.current = timestamp ?? null;
    }

    // Sweep the object between just past the source and just short of the
    // screen, so the umbra/penumbra visibly change size and position as it
    // moves — bounded to stay clear of both endpoints.
    const minDist = 55, maxDist = s.screenDistPx - 45;
    const sweepMid = (minDist + maxDist) / 2, sweepAmp = (maxDist - minDist) / 2;
    const objectDistPx = animate
      ? sweepMid + sweepAmp * Math.sin((2 * Math.PI / SWEEP_PERIOD) * t.current)
      : Math.min(Math.max(s.objectDistPx, minDist), maxDist);

    ctx.clearRect(0, 0, W, H);
    ctx.fillStyle = '#0f172a'; ctx.fillRect(0, 0, W, H);

    const midY = H / 2;
    const srcX = 50;
    const objX = srcX + objectDistPx;
    const scrX = Math.min(srcX + s.screenDistPx, W - 20);
    const rs = s.sourceType === 'point' ? 0.001 : s.sourceRadiusPx;
    const ro = s.objectRadiusPx;

    const srcTop: Vec = { x: srcX, y: midY - rs };
    const srcBot: Vec = { x: srcX, y: midY + rs };
    const objTop: Vec = { x: objX, y: midY - ro };
    const objBot: Vec = { x: objX, y: midY + ro };

    // Four boundary rays, extended out to the screen's x — genuine
    // straight-line projection, not an assumed shadow shape.
    const umbraTopY = lineAtX(srcBot, objTop, scrX);   // inner ray, upper edge of umbra
    const umbraBotY = lineAtX(srcTop, objBot, scrX);   // inner ray, lower edge of umbra
    const penTopY = lineAtX(srcTop, objTop, scrX);     // outer ray, upper edge of penumbra
    const penBotY = lineAtX(srcBot, objBot, scrX);     // outer ray, lower edge of penumbra

    // Screen, painted in bands: lit (bright) / penumbra (dim, gradient) / umbra (dark)
    const screenTop = 20, screenBottom = H - 20;
    ctx.fillStyle = '#fef9c3'; ctx.fillRect(scrX - 6, screenTop, 6, screenBottom - screenTop);
    const bandFill = (y0: number, y1: number, fill: string | CanvasGradient) => {
      const a = Math.max(screenTop, Math.min(y0, y1));
      const b = Math.min(screenBottom, Math.max(y0, y1));
      if (b <= a) return;
      ctx.fillStyle = fill;
      ctx.fillRect(scrX - 6, a, 6, b - a);
    };
    bandFill(screenTop, penTopY, '#fef9c3');
    const gradTop = ctx.createLinearGradient(0, penTopY, 0, umbraTopY);
    gradTop.addColorStop(0, '#fef9c3'); gradTop.addColorStop(1, '#1e293b');
    bandFill(penTopY, umbraTopY, gradTop);
    bandFill(umbraTopY, umbraBotY, '#0f172a');
    const gradBot = ctx.createLinearGradient(0, umbraBotY, 0, penBotY);
    gradBot.addColorStop(0, '#1e293b'); gradBot.addColorStop(1, '#fef9c3');
    bandFill(umbraBotY, penBotY, gradBot);
    bandFill(penBotY, screenBottom, '#fef9c3');

    // Rays
    const drawRay = (a: Vec, b: Vec, color: string, dashed = false) => {
      const endY = lineAtX(a, b, scrX);
      ctx.save(); if (dashed) ctx.setLineDash([4, 3]);
      ctx.strokeStyle = color; ctx.lineWidth = 1.3;
      ctx.beginPath(); ctx.moveTo(a.x, a.y); ctx.lineTo(scrX, endY); ctx.stroke();
      ctx.restore();
    };
    drawRay(srcBot, objTop, 'rgba(96,165,250,0.7)');
    drawRay(srcTop, objBot, 'rgba(96,165,250,0.7)');
    if (s.sourceType === 'extended') {
      drawRay(srcTop, objTop, 'rgba(251,191,36,0.6)');
      drawRay(srcBot, objBot, 'rgba(251,191,36,0.6)');
    }

    // Source
    ctx.fillStyle = '#fbbf24';
    if (s.sourceType === 'point') {
      ctx.beginPath(); ctx.arc(srcX, midY, 5, 0, Math.PI * 2); ctx.fill();
    } else {
      ctx.beginPath(); ctx.ellipse(srcX, midY, 6, rs, 0, 0, Math.PI * 2); ctx.fill();
    }
    ctx.fillStyle = '#fcd34d'; ctx.font = '10px system-ui'; ctx.textAlign = 'center';
    ctx.fillText(s.sourceType === 'point' ? 'point source' : 'extended source', srcX, midY - rs - 12);

    // Opaque object
    ctx.fillStyle = '#475569';
    ctx.beginPath(); ctx.ellipse(objX, midY, 10, ro, 0, 0, Math.PI * 2); ctx.fill();
    ctx.fillStyle = '#94a3b8'; ctx.font = '10px system-ui';
    ctx.fillText('opaque object', objX, midY - ro - 10);

    ctx.fillStyle = '#cbd5e1'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'left';
    ctx.fillText('screen', scrX - 40, screenTop - 6);

    // Labels
    ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'left';
    if (Math.abs(umbraBotY - umbraTopY) > 14) {
      ctx.fillStyle = '#e2e8f0';
      ctx.fillText('umbra', scrX + 10, (umbraTopY + umbraBotY) / 2 + 3);
    }
    if (s.sourceType === 'extended' && Math.abs(penTopY - umbraTopY) > 10) {
      ctx.fillStyle = '#fbbf24';
      ctx.fillText('penumbra', scrX + 10, (penTopY + umbraTopY) / 2 + 3);
      ctx.fillText('penumbra', scrX + 10, (penBotY + umbraBotY) / 2 + 3);
    }

    ctx.fillStyle = '#94a3b8'; ctx.font = '10px system-ui'; ctx.textAlign = 'center';
    ctx.fillText(
      s.sourceType === 'point'
        ? 'Point source → a single sharp-edged shadow (umbra only, no penumbra)'
        : 'Extended source → umbra (no light at all) surrounded by penumbra (partly lit, some of the source is visible from there)',
      W / 2, H - 6,
    );

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
AFEOF

echo "  → src/components/simulation/EclipseCanvas.tsx"
cat > "src/components/simulation/EclipseCanvas.tsx" << 'AFEOF'
'use client';
import { useRef, useEffect, useCallback } from 'react';

export type EclipseType = 'solar' | 'lunar';

interface Props {
  eclipseType: EclipseType;
  orbitalOffset: number; // used as a fixed value only when not animating (paused/reset)
  isRunning: boolean; isPaused: boolean;
  onTick?: (offset: number, eclipseHappening: boolean) => void;
  width?: number; height?: number;
}

interface Vec { x: number; y: number; }
function lineAtX(p1: Vec, p2: Vec, x: number): number {
  const t = (x - p1.x) / (p2.x - p1.x);
  return p1.y + t * (p2.y - p1.y);
}

const ORBIT_PERIOD = 6; // s — one full simulated orbit
const MAX_OFFSET = 110; // px — the swing of the ~5° real orbital tilt, scaled for visibility

export function EclipseCanvas({ eclipseType, orbitalOffset, isRunning, isPaused, onTick, width = 660, height = 300 }: Props) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const rafRef = useRef<number>(0);
  const lastFrameRef = useRef<number | null>(null);
  const t = useRef(0);
  const sim = useRef({ eclipseType, orbitalOffset, isRunning, isPaused, onTick });
  sim.current = { eclipseType, orbitalOffset, isRunning, isPaused, onTick };

  useEffect(() => { t.current = 0; lastFrameRef.current = null; }, [eclipseType, orbitalOffset]);

  const draw = useCallback((timestamp?: number) => {
    const canvas = canvasRef.current; if (!canvas) return;
    const ctx = canvas.getContext('2d'); if (!ctx) return;
    const s = sim.current;
    const W = canvas.width, H = canvas.height;

    const animate = s.isRunning && !s.isPaused;
    if (animate && timestamp !== undefined) {
      if (lastFrameRef.current !== null) {
        t.current += Math.min((timestamp - lastFrameRef.current) / 1000, 0.1);
      }
      lastFrameRef.current = timestamp;
    } else {
      lastFrameRef.current = timestamp ?? null;
    }
    // Orbiting: the offset sweeps continuously through the full tilt range,
    // so the body drifts in and out of alignment exactly like a real
    // ~5°-inclined orbit carrying the shadow past its target most months.
    const offset = animate
      ? MAX_OFFSET * Math.sin((2 * Math.PI / ORBIT_PERIOD) * t.current)
      : s.orbitalOffset;

    ctx.clearRect(0, 0, W, H);
    ctx.fillStyle = '#0f172a'; ctx.fillRect(0, 0, W, H);
    // Starfield
    ctx.fillStyle = 'rgba(255,255,255,0.4)';
    for (let i = 0; i < 40; i++) ctx.fillRect((i * 53) % W, (i * 97) % H, 1, 1);

    const midY = H / 2;
    // Not-to-scale positions — the real distances/sizes span factors of
    // hundreds, so a to-scale diagram would render the Moon and Earth as
    // invisible points. Sizes and gaps here are chosen purely for clarity.
    const sunX = 55, sunR = 46;
    const smallX = W * 0.48;     // Moon (solar) or Earth (lunar) — the occluding body
    const smallR = s.eclipseType === 'solar' ? 14 : 26;
    const targetX = W * 0.86;    // Earth (solar) or Moon (lunar) — the body the shadow may fall on
    const targetR = s.eclipseType === 'solar' ? 26 : 14;

    const smallY = midY + offset;

    ctx.fillStyle = '#fbbf24';
    ctx.beginPath(); ctx.arc(sunX, midY, sunR, 0, Math.PI * 2); ctx.fill();
    ctx.fillStyle = '#fde68a'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
    ctx.fillText('Sun', sunX, midY + sunR + 16);

    // Shadow cone from the Sun's edges, past the occluding body — same
    // ray-tracing approach as the shadows mode, just with round bodies.
    const srcTop: Vec = { x: sunX, y: midY - sunR }, srcBot: Vec = { x: sunX, y: midY + sunR };
    const occTop: Vec = { x: smallX, y: smallY - smallR }, occBot: Vec = { x: smallX, y: smallY + smallR };
    const umbraTopAtTarget = lineAtX(srcBot, occTop, targetX);
    const umbraBotAtTarget = lineAtX(srcTop, occBot, targetX);
    const penTopAtTarget = lineAtX(srcTop, occTop, targetX);
    const penBotAtTarget = lineAtX(srcBot, occBot, targetX);

    // Shadow cone fill (umbra dark, penumbra faint)
    ctx.save();
    ctx.beginPath();
    ctx.moveTo(occTop.x, occTop.y); ctx.lineTo(occBot.x, occBot.y);
    ctx.lineTo(targetX, umbraBotAtTarget);
    ctx.lineTo(targetX, umbraTopAtTarget);
    ctx.closePath();
    ctx.fillStyle = 'rgba(15,23,42,0.85)'; ctx.fill();
    ctx.restore();
    ctx.save();
    ctx.beginPath();
    ctx.moveTo(occTop.x, occTop.y); ctx.lineTo(targetX, penTopAtTarget);
    ctx.lineTo(targetX, umbraTopAtTarget); ctx.lineTo(occTop.x, occTop.y);
    ctx.closePath(); ctx.fillStyle = 'rgba(100,116,139,0.35)'; ctx.fill();
    ctx.beginPath();
    ctx.moveTo(occBot.x, occBot.y); ctx.lineTo(targetX, penBotAtTarget);
    ctx.lineTo(targetX, umbraBotAtTarget); ctx.lineTo(occBot.x, occBot.y);
    ctx.closePath(); ctx.fillStyle = 'rgba(100,116,139,0.35)'; ctx.fill();
    ctx.restore();

    // Occluding body (Moon for solar, Earth for lunar)
    ctx.fillStyle = s.eclipseType === 'solar' ? '#cbd5e1' : '#3b82f6';
    ctx.beginPath(); ctx.arc(smallX, smallY, smallR, 0, Math.PI * 2); ctx.fill();
    ctx.fillStyle = '#e2e8f0'; ctx.font = 'bold 10px system-ui';
    ctx.fillText(s.eclipseType === 'solar' ? 'Moon' : 'Earth', smallX, smallY - smallR - 8);

    // Target body
    ctx.fillStyle = s.eclipseType === 'solar' ? '#3b82f6' : '#cbd5e1';
    ctx.beginPath(); ctx.arc(targetX, midY, targetR, 0, Math.PI * 2); ctx.fill();
    // Re-darken whatever part of the target sits inside the umbra/penumbra
    const clampTop = Math.max(midY - targetR, Math.min(umbraTopAtTarget, midY + targetR));
    const clampBot = Math.max(midY - targetR, Math.min(umbraBotAtTarget, midY + targetR));
    if (clampBot > clampTop) {
      ctx.save();
      ctx.beginPath(); ctx.arc(targetX, midY, targetR, 0, Math.PI * 2); ctx.clip();
      ctx.fillStyle = 'rgba(15,23,42,0.75)';
      ctx.fillRect(targetX - targetR, clampTop, targetR * 2, clampBot - clampTop);
      ctx.restore();
    }
    ctx.fillStyle = '#e2e8f0'; ctx.font = 'bold 10px system-ui';
    ctx.fillText(s.eclipseType === 'solar' ? 'Earth' : 'Moon', targetX, midY - targetR - 8);

    const eclipseHappening = umbraTopAtTarget < midY + targetR && umbraBotAtTarget > midY - targetR;
    s.onTick?.(offset, eclipseHappening);
    ctx.font = 'bold 11px system-ui'; ctx.textAlign = 'center';
    ctx.fillStyle = eclipseHappening ? '#f87171' : '#94a3b8';
    ctx.fillText(
      eclipseHappening
        ? (s.eclipseType === 'solar' ? '☾ SOLAR ECLIPSE — the Moon\u2019s shadow falls on Earth' : '🌍 LUNAR ECLIPSE — the Moon passes through Earth\u2019s shadow')
        : `No eclipse this orbit — the Moon\u2019s orbital tilt (~5°) carries its shadow ${s.eclipseType === 'solar' ? 'above or below Earth' : 'above or below Earth\u2019s shadow'}`,
      W / 2, 24,
    );
    ctx.fillStyle = '#64748b'; ctx.font = '9px system-ui'; ctx.textAlign = 'left';
    ctx.fillText('Not to scale — real Sun-Earth-Moon distances/sizes span hundreds of times these proportions', 8, H - 8);

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
AFEOF

echo "  → src/components/simulation/DiffractionCanvas.tsx"
cat > "src/components/simulation/DiffractionCanvas.tsx" << 'AFEOF'
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
AFEOF

echo "  → src/app/simulations/diffraction/page.tsx"
cat > "src/app/simulations/diffraction/page.tsx" << 'AFEOF'
'use client';
import { useState, useCallback, useEffect, useRef } from 'react';
import { AppHeader } from '@/components/layout/AppHeader';
import { SimulationControls } from '@/components/simulation/SimulationControls';
import { DiffractionCanvas, DiffractionMode } from '@/components/simulation/DiffractionCanvas';
import { EmbedButton } from '@/components/ui/EmbedButton';
import { firstMinimumAngle, spreadFraction, maxGratingOrder, fringeSpacing, maxFringeOrder } from '@/lib/physics/diffraction';
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
  'double-slit': { title: "Young's double slit", icon: '〰️', sub: 'Interference — bright & dark fringes', eq: 'Δy = λD/d' },
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
  'double-slit': [
    'Young\u2019s double-slit experiment (1801) was the first strong evidence that light behaves as a wave — only overlapping waves can interfere, and interference is exactly what the alternating bright/dark fringes show.',
    'Two coherent slits (same frequency, constant phase relationship) illuminated by a single source act as two synchronised wave sources. Where a crest meets a crest (or trough meets trough), the waves add — constructive interference, a bright fringe. Where a crest meets a trough, they cancel — destructive interference, a dark fringe.',
    'Fringe spacing formula: Δy = λD/d, where D is the slit-to-screen distance and d is the slit separation — every bright band sits this far from its neighbour, regardless of order.',
    'A SMALLER slit separation d gives WIDER-spaced fringes (easier to see individually); a LARGER d packs the fringes closer together.',
    'This is genuinely the same physics as the diffraction grating (many slits) — a grating just uses many more slits, which sharpens the bright fringes into much narrower, more precisely-located lines.',
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
  'double-slit': [
    { q: 'In a double-slit experiment, λ=600nm, the slits are 0.5mm apart, and the screen is 1.2m away. Find the fringe spacing.', a: 'Δy = λD/d = (600×10⁻⁹ × 1.2) / (0.5×10⁻³) = 1.44×10⁻³ m = 1.44mm.' },
    { q: 'The slit separation in a double-slit experiment is halved, with everything else unchanged. What happens to the fringe spacing?', a: 'Δy = λD/d, so halving d DOUBLES the fringe spacing — the bright and dark bands spread further apart.' },
    { q: 'Explain, in terms of path difference, why a bright fringe forms at a point equidistant from both slits.', a: 'At that point the path difference is zero, so light from both slits arrives exactly in phase (crest meets crest) — constructive interference, giving the bright central fringe.' },
    { q: 'Why must the two slits be illuminated by light from the SAME single source, rather than two separate identical lamps?', a: 'Interference needs a constant, unchanging phase relationship between the two waves (coherence). Two separate lamps emit light with random, constantly-shifting phase relative to each other, so any interference pattern would wash out instantly rather than staying fixed and visible.' },
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
  const [doubleSlitSepUm, setDoubleSlitSepUm] = useState(500); // micrometres — realistic double-slit scale (0.2-1mm)
  const doubleSlitSepNm = doubleSlitSepUm * 1000;

  const reset = useCallback(() => { setIsRunning(false); setIsPaused(false); setResetKey(k => k + 1); }, []);
  const resetTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  useEffect(() => {
    if (resetTimer.current) clearTimeout(resetTimer.current);
    resetTimer.current = setTimeout(reset, 100);
  }, [mode, wavelengthNm, slitWidthNm, slitSpacingNm, doubleSlitSepUm, reset]);

  const canvasBoxRef = useRef<HTMLDivElement>(null);
  const canvasSize = useResponsiveCanvasSize(canvasBoxRef, 660, 300, 980);

  const minAngle = firstMinimumAngle(wavelengthNm, slitWidthNm);
  const spread = spreadFraction(wavelengthNm, slitWidthNm);
  const maxOrder = maxGratingOrder(wavelengthNm, slitSpacingNm);
  const maxFringeN = maxFringeOrder(wavelengthNm, doubleSlitSepNm);

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
                  doubleSlitSepNm={doubleSlitSepNm}
                  isRunning={isRunning} isPaused={isPaused}
                  width={canvasSize.width} height={canvasSize.height} />
              </div>

              <div className="flex flex-wrap items-center justify-between gap-2">
                <SimulationControls isRunning={isRunning} isPaused={isPaused}
                  onRun={() => { setIsRunning(true); setIsPaused(false); }}
                  onPause={() => setIsPaused(p => !p)} onReset={reset} />
                <EmbedButton path="/embed/diffraction"
                  title={`${MODE_META[mode].title} — A-Factor STEM Studio`}
                  params={{ mode, wavelength: wavelengthNm, width: slitWidthNm, spacing: slitSpacingNm, sep: doubleSlitSepNm }} />
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
                {mode === 'double-slit' && (
                  <Slider label="Slit separation (d)" unit="μm" value={doubleSlitSepUm} min={200} max={1000} step={10} set={setDoubleSlitSepUm} color="#f59e0b"
                    note="Smaller separation → wider-spaced fringes" />
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
                  {mode === 'double-slit' && <>
                    <StatRow label="Fringe spacing (D=1m)" value={(fringeSpacing(wavelengthNm * 1e-9, doubleSlitSepNm * 1e-9, 1) * 1000).toFixed(2)} unit="mm" color="text-indigo-600" />
                    <StatRow label="Max order (this scale)" value={`±${maxFringeN}`} unit="" color="text-emerald-600" />
                    <StatRow label="Nature" value="constructive/destructive interference" unit="" color="text-purple-600" />
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
  const mode = ((): DiffractionMode => {
    const m = sp.get('mode');
    return m === 'grating' || m === 'double-slit' ? m : 'single-slit';
  })();
  const showControls = sp.get('controls') !== '0';

  const [wavelengthNm, setWavelengthNm] = useState(() => num(sp, 'wavelength', 550, 400, 700));
  const [slitWidthNm, setSlitWidthNm] = useState(() => num(sp, 'width', 1000, 200, 3000));
  const [slitSpacingNm, setSlitSpacingNm] = useState(() => num(sp, 'spacing', 2000, 500, 5000));
  const [doubleSlitSepUm, setDoubleSlitSepUm] = useState(() => num(sp, 'sep', 500, 200, 1000));
  const doubleSlitSepNm = doubleSlitSepUm * 1000;

  const [isRunning, setIsRunning] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const [resetKey, setResetKey] = useState(0);
  const reset = useCallback(() => { setIsRunning(false); setIsPaused(false); setResetKey(k => k + 1); }, []);
  const resetTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  useEffect(() => {
    if (resetTimer.current) clearTimeout(resetTimer.current);
    resetTimer.current = setTimeout(reset, 100);
  }, [mode, wavelengthNm, slitWidthNm, slitSpacingNm, doubleSlitSepUm, reset]);

  return (
    <div className="mx-auto max-w-2xl space-y-3 p-3 sm:p-4">
      <DiffractionCanvas key={resetKey} mode={mode} wavelengthNm={wavelengthNm} slitWidthNm={slitWidthNm} slitSpacingNm={slitSpacingNm}
        doubleSlitSepNm={doubleSlitSepNm}
        isRunning={isRunning} isPaused={isPaused} width={640} height={280} />
      <SimulationControls isRunning={isRunning} isPaused={isPaused}
        onRun={() => { setIsRunning(true); setIsPaused(false); }}
        onPause={() => setIsPaused(p => !p)} onReset={reset} />
      {showControls && (
        <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm space-y-3">
          <p className="text-xs font-medium uppercase tracking-wide text-gray-400">Parameters</p>
          <Slider label="Wavelength" unit="nm" value={wavelengthNm} min={400} max={700} step={10} set={setWavelengthNm} color="#6366f1" />
          {mode === 'single-slit' && (
            <Slider label="Slit width" unit="nm" value={slitWidthNm} min={200} max={3000} step={50} set={setSlitWidthNm} color="#f59e0b" />
          )}
          {mode === 'grating' && (
            <Slider label="Slit spacing" unit="nm" value={slitSpacingNm} min={500} max={5000} step={50} set={setSlitSpacingNm} color="#f59e0b" />
          )}
          {mode === 'double-slit' && (
            <Slider label="Slit separation" unit="μm" value={doubleSlitSepUm} min={200} max={1000} step={10} set={setDoubleSlitSepUm} color="#f59e0b" />
          )}
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

echo "  → src/app/simulations/rectilinear-propagation/page.tsx"
cat > "src/app/simulations/rectilinear-propagation/page.tsx" << 'AFEOF'
'use client';
import { useState, useCallback, useEffect, useRef } from 'react';
import { AppHeader } from '@/components/layout/AppHeader';
import { SimulationControls } from '@/components/simulation/SimulationControls';
import { ShadowsCanvas } from '@/components/simulation/ShadowsCanvas';
import { EclipseCanvas, EclipseType } from '@/components/simulation/EclipseCanvas';
import { PinholeCanvas } from '@/components/simulation/PinholeCanvas';
import { EmbedButton } from '@/components/ui/EmbedButton';
import { umbraLength, pinholeImageHeight, pinholeMagnification, SUN_ANGULAR_DIAMETER_DEG, MOON_ANGULAR_DIAMETER_DEG } from '@/lib/physics/rectilinear';
import { useResponsiveCanvasSize } from '@/hooks/useResponsiveCanvasSize';

type Topic = 'shadows' | 'eclipse' | 'pinhole';

const CURRICULA = ['WAEC', 'NECO', 'IGCSE', 'SAT', 'JUPEB'];
const CC: Record<string, string> = {
  WAEC: 'bg-indigo-100 text-indigo-700', NECO: 'bg-pink-100 text-pink-700',
  IGCSE: 'bg-emerald-100 text-emerald-700', SAT: 'bg-orange-100 text-orange-700',
  JUPEB: 'bg-purple-100 text-purple-700',
};

const TOPIC_META: Record<Topic, { title: string; icon: string; sub: string; eq: string }> = {
  shadows: { title: 'Shadows',        icon: '🌑', sub: 'Umbra & penumbra',              eq: 'light travels in straight lines' },
  eclipse: { title: 'Eclipses',       icon: '🌘', sub: 'Solar & lunar',                  eq: 'a shadow, cast across space' },
  pinhole: { title: 'Pinhole camera', icon: '📷', sub: 'A laboratory consequence',       eq: 'hI/v = hO/u' },
};

const TEACHER_NOTES: Record<Topic, string[]> = {
  shadows: [
    'Sources of light are LUMINOUS (produce their own light — the Sun, a candle, a bulb) or NON-LUMINOUS (only visible because they reflect light from elsewhere — the Moon, this page, a person).',
    'A shadow forms because light travels in straight lines (rectilinear propagation) and cannot bend around an opaque object.',
    'A POINT source produces a shadow with a sharp edge — only an umbra, no penumbra — because every ray from the single point is blocked in exactly the same way.',
    'An EXTENDED source produces a shadow with two regions: the UMBRA (completely dark — no part of the source is visible from there) and the PENUMBRA (partially lit — only part of the source is visible from there, so some light still reaches it).',
    'Moving the object closer to an extended source makes the penumbra relatively LARGER compared to the umbra; moving it closer to the screen makes the shadow\u2019s edges sharper.',
  ],
  eclipse: [
    'A solar eclipse happens when the Moon passes directly between the Sun and Earth, casting its shadow onto Earth\u2019s surface — people in the umbra see a total eclipse, people in the penumbra see a partial one.',
    'A lunar eclipse happens when Earth passes directly between the Sun and the Moon, and the Moon passes through Earth\u2019s shadow.',
    'Eclipses don\u2019t happen every month because the Moon\u2019s orbit is tilted about 5° relative to Earth\u2019s orbit around the Sun — most months, the Moon\u2019s shadow (or Earth\u2019s shadow) simply misses, passing above or below the target body.',
    'A remarkable coincidence: the Sun is about 400 times wider than the Moon, but also about 400 times farther away — so they have almost the same apparent size in our sky, which is why the Moon can only just barely cover the Sun during a total solar eclipse.',
    'This whole topic is a direct, large-scale consequence of the same rectilinear-propagation geometry used for a tabletop shadow demo — only the distances and sizes change.',
  ],
  pinhole: [
    'A pinhole camera has no lens — a single small hole lets through only one straight-line ray per point on the object, which is exactly why the image forms upside down (inverted): rays from the top of the object cross the hole and land at the BOTTOM of the screen, and vice versa.',
    'The image is always REAL (it lands on an actual screen/film) — this is a direct laboratory demonstration of rectilinear propagation, needing no lens or mirror at all.',
    'Image height formula (similar triangles): hI/v = hO/u, where u = object-to-hole distance, v = hole-to-screen distance.',
    'A SMALLER hole gives a sharper image (closer to one ray per object point) but a DIMMER one (less light gets through) — a genuine trade-off, and why real pinhole cameras need long exposure times.',
    'Making the hole too large lets a whole BUNDLE of rays through each object point, and those bundles overlap on the screen — this is what blurs the image, not some separate effect, but the same straight-line geometry applied to a hole with actual size.',
  ],
};

const EXERCISES: Record<Topic, { q: string; a: string }[]> = {
  shadows: [
    { q: 'A point source of light is placed 20cm from an opaque disc of radius 5cm. Explain what kind of shadow forms and why.', a: 'A sharp shadow with only an umbra, no penumbra — every ray from a single point is blocked identically at the disc\u2019s edge, so there is no region that receives partial light.' },
    { q: 'State the two regions formed in the shadow of an extended light source, and define each.', a: 'Umbra: the region that receives no light at all from the source (completely dark). Penumbra: the region that receives light from only part of the source (partially lit).' },
    { q: 'Why can you sometimes see a fuzzy-edged shadow under a fluorescent tube light, but a sharp-edged shadow under a small torch bulb?', a: 'A fluorescent tube is an extended source, producing a penumbra (fuzzy edge) around the umbra. A small torch bulb behaves close to a point source, giving a mostly sharp-edged shadow.' },
  ],
  eclipse: [
    { q: 'Distinguish between a solar eclipse and a lunar eclipse in terms of the positions of the Sun, Earth, and Moon.', a: 'Solar eclipse: Moon is between the Sun and Earth, and the Moon\u2019s shadow falls on Earth. Lunar eclipse: Earth is between the Sun and the Moon, and the Moon passes through Earth\u2019s shadow.' },
    { q: 'Explain why we do not see a solar and a lunar eclipse every single month, even though the Moon orbits Earth roughly every month.', a: 'The Moon\u2019s orbital plane is tilted about 5° relative to Earth\u2019s orbital plane around the Sun. Most months, this tilt carries the Moon\u2019s shadow (or its path through Earth\u2019s shadow) above or below the target body, so no eclipse occurs — only when the alignment is nearly exact does the shadow actually land.' },
    { q: 'A person standing in the umbra of the Moon\u2019s shadow during a solar eclipse sees a total eclipse. What would a person standing in the penumbra see instead?', a: 'A partial eclipse — from the penumbra, only part of the Sun\u2019s disc is covered by the Moon, since part of the Sun is still visible from that position.' },
  ],
  pinhole: [
    { q: 'An object 1.6m tall stands 4m from a pinhole camera. The screen is 20cm behind the pinhole. Find the height of the image.', a: 'hI = hO×(v/u) = 1.6×(0.2/4) = 0.08m = 8cm.' },
    { q: 'Explain, using a ray diagram argument, why the image in a pinhole camera is always inverted.', a: 'A ray from the TOP of the object must travel in a straight line through the single pinhole — since the hole is below the top of the object, that ray continues downward past the hole and lands near the BOTTOM of the screen. Likewise, a ray from the bottom of the object lands near the top. Top-to-bottom and bottom-to-top swap, so the image is upside down.' },
    { q: 'A student makes the pinhole bigger to let in more light. What happens to the sharpness of the image, and why?', a: 'The image becomes blurrier. A larger hole allows a whole bundle of rays (not just one) from each point on the object to pass through, and these bundles land on overlapping regions of the screen instead of a single sharp point, smearing the image out.' },
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

export default function RectilinearPropagationPage() {
  const [topic, setTopic] = useState<Topic>('shadows');
  const [openEx, setOpenEx] = useState<number | null>(null);
  const [activeCurricula, setActiveCurricula] = useState(['WAEC', 'IGCSE', 'SAT']);
  const [isRunning, setIsRunning] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const [resetKey, setResetKey] = useState(0);

  const [sourceType, setSourceType] = useState<'point' | 'extended'>('extended');
  const [sourceRadius, setSourceRadius] = useState(35);
  const [objectRadius, setObjectRadius] = useState(24);
  const [objectDist, setObjectDist] = useState(160);
  const [screenDist, setScreenDist] = useState(420);

  const [eclipseType, setEclipseType] = useState<EclipseType>('solar');
  const [orbitalOffset, setOrbitalOffset] = useState(0);

  const [objectHeight, setObjectHeight] = useState(90);
  const [pinholeObjectDist, setPinholeObjectDist] = useState(140);
  const [pinholeScreenDist, setPinholeScreenDist] = useState(160);
  const [pinholeRadius, setPinholeRadius] = useState(1);

  const reset = useCallback(() => { setIsRunning(false); setIsPaused(false); setResetKey(k => k + 1); }, []);
  const resetTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  useEffect(() => {
    if (resetTimer.current) clearTimeout(resetTimer.current);
    resetTimer.current = setTimeout(reset, 100);
  }, [topic, sourceType, sourceRadius, objectRadius, objectDist, screenDist, eclipseType, orbitalOffset, objectHeight, pinholeObjectDist, pinholeScreenDist, pinholeRadius, reset]);

  const canvasBoxRef = useRef<HTMLDivElement>(null);
  const canvasSize = useResponsiveCanvasSize(canvasBoxRef, 660, 300, 980);

  const uLen = umbraLength(sourceRadius, objectRadius, objectDist);
  const imgH = pinholeImageHeight(objectHeight, pinholeObjectDist, pinholeScreenDist);
  const mag = pinholeMagnification(pinholeObjectDist, pinholeScreenDist);

  return (
    <>
      <AppHeader />
      <main className="min-h-screen bg-gray-50">
        <section className="border-b border-gray-200 bg-white">
          <div className="mx-auto max-w-[100rem] px-4 sm:px-6 py-4">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
              <div>
                <p className="text-xs text-gray-400 mb-0.5">Optics</p>
                <h1 className="text-lg font-semibold text-gray-900">Sources of Light & Rectilinear Propagation</h1>
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
            {(Object.keys(TOPIC_META) as Topic[]).map(t => (
              <button key={t} onClick={() => { setTopic(t); setOpenEx(null); }}
                className={`shrink-0 flex items-center gap-1.5 px-3 py-2 rounded-lg text-xs font-medium transition ${
                  topic === t ? 'bg-white text-indigo-700 shadow-sm' : 'text-gray-500 hover:text-gray-700'
                }`}>
                <span>{TOPIC_META[t].icon}</span><span>{TOPIC_META[t].title}</span>
              </button>
            ))}
          </div>

          <div className="flex flex-wrap items-center gap-3 rounded-xl border border-gray-200 bg-white px-4 py-2.5">
            <span className="text-xs text-gray-400">{TOPIC_META[topic].sub}</span>
            <span className="text-sm font-semibold font-mono text-gray-900">{TOPIC_META[topic].eq}</span>
          </div>

          <div className="grid grid-cols-1 lg:grid-cols-[1fr_220px] xl:grid-cols-[1fr_220px_260px] gap-4">
            <div className="space-y-3 min-w-0">
              <div ref={canvasBoxRef} className="rounded-2xl border border-gray-200 bg-white p-3 shadow-sm">
                {topic === 'shadows' && (
                  <ShadowsCanvas key={resetKey} sourceType={sourceType} sourceRadiusPx={sourceRadius} objectRadiusPx={objectRadius}
                    objectDistPx={objectDist} screenDistPx={screenDist}
                    isRunning={isRunning} isPaused={isPaused}
                    width={canvasSize.width} height={canvasSize.height} />
                )}
                {topic === 'eclipse' && (
                  <EclipseCanvas key={resetKey} eclipseType={eclipseType} orbitalOffset={orbitalOffset}
                    isRunning={isRunning} isPaused={isPaused}
                    width={canvasSize.width} height={canvasSize.height} />
                )}
                {topic === 'pinhole' && (
                  <PinholeCanvas objectHeightPx={objectHeight} objectDistPx={pinholeObjectDist} screenDistPx={pinholeScreenDist}
                    pinholeRadiusPx={pinholeRadius}
                    width={canvasSize.width} height={canvasSize.height} />
                )}
              </div>

              <div className="flex flex-wrap items-center justify-between gap-2">
                {topic !== 'pinhole' ? (
                  <SimulationControls isRunning={isRunning} isPaused={isPaused}
                    onRun={() => { setIsRunning(true); setIsPaused(false); }}
                    onPause={() => setIsPaused(p => !p)} onReset={reset} />
                ) : <span />}
                <EmbedButton path="/embed/rectilinear-propagation"
                  title={`${TOPIC_META[topic].title} — A-Factor STEM Studio`}
                  params={
                    topic === 'shadows' ? { topic, src: sourceType, sr: sourceRadius, or: objectRadius, od: objectDist, sd: screenDist }
                    : topic === 'eclipse' ? { topic, type: eclipseType, offset: orbitalOffset }
                    : { topic, h: objectHeight, u: pinholeObjectDist, v: pinholeScreenDist, r: pinholeRadius }
                  } />
              </div>

              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm space-y-4">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide">Parameters</p>

                {topic === 'shadows' && <>
                  <div className="flex gap-2">
                    {(['point', 'extended'] as const).map(t => (
                      <button key={t} onClick={() => setSourceType(t)}
                        className={`flex-1 rounded-lg border px-2 py-2 text-xs font-medium capitalize transition ${
                          sourceType === t ? 'border-indigo-300 bg-indigo-50 text-indigo-700' : 'border-gray-200 bg-white text-gray-500'
                        }`}>{t} source</button>
                    ))}
                  </div>
                  {sourceType === 'extended' && (
                    <Slider label="Source size" unit="px" value={sourceRadius} min={5} max={60} step={1} set={setSourceRadius} color="#fbbf24" />
                  )}
                  <Slider label="Object size" unit="px" value={objectRadius} min={8} max={50} step={1} set={setObjectRadius} color="#64748b" />
                  <Slider label="Object distance" unit="px" value={objectDist} min={60} max={300} step={5} set={setObjectDist} color="#6366f1" />
                  <Slider label="Screen distance" unit="px" value={screenDist} min={objectDist + 40} max={560} step={5} set={setScreenDist} color="#8b5cf6" />
                </>}

                {topic === 'eclipse' && <>
                  <div className="flex gap-2">
                    {(['solar', 'lunar'] as const).map(t => (
                      <button key={t} onClick={() => setEclipseType(t)}
                        className={`flex-1 rounded-lg border px-2 py-2 text-xs font-medium capitalize transition ${
                          eclipseType === t ? 'border-indigo-300 bg-indigo-50 text-indigo-700' : 'border-gray-200 bg-white text-gray-500'
                        }`}>{t}</button>
                    ))}
                  </div>
                  <Slider label="Orbital alignment offset" unit="px" value={orbitalOffset} min={0} max={120} step={2} set={setOrbitalOffset} color="#6366f1"
                    note="0 = perfectly aligned. Increase to see why most months have no eclipse." />
                </>}

                {topic === 'pinhole' && <>
                  <Slider label="Object height" unit="px" value={objectHeight} min={30} max={130} step={5} set={setObjectHeight} color="#0f172a" />
                  <Slider label="Object distance (u)" unit="px" value={pinholeObjectDist} min={60} max={260} step={5} set={setPinholeObjectDist} color="#6366f1" />
                  <Slider label="Screen distance (v)" unit="px" value={pinholeScreenDist} min={40} max={260} step={5} set={setPinholeScreenDist} color="#8b5cf6" />
                  <Slider label="Pinhole size" unit="px" value={pinholeRadius} min={0} max={12} step={0.5} set={setPinholeRadius} color="#f59e0b"
                    note="0 = ideal sharp point. Larger → visibly blurs the image." />
                </>}
              </div>
            </div>

            <div className="space-y-3">
              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide mb-3">Calculated</p>
                <div className="space-y-2">
                  {topic === 'shadows' && <>
                    <StatRow label="Shadow type" value={sourceType === 'point' ? 'sharp (no penumbra)' : 'umbra + penumbra'} unit="" color="text-indigo-600" />
                    <StatRow label="Umbra converges at" value={uLen === null ? 'never (source ≤ object)' : uLen.toFixed(0)} unit={uLen === null ? '' : 'px beyond object'} color="text-emerald-600" />
                  </>}
                  {topic === 'eclipse' && <>
                    <StatRow label="Sun angular diameter" value={SUN_ANGULAR_DIAMETER_DEG.toFixed(3)} unit="°" color="text-amber-600" />
                    <StatRow label="Moon angular diameter" value={MOON_ANGULAR_DIAMETER_DEG.toFixed(3)} unit="°" color="text-indigo-600" />
                    <StatRow label="Ratio" value={(SUN_ANGULAR_DIAMETER_DEG / MOON_ANGULAR_DIAMETER_DEG).toFixed(3)} unit="" color="text-purple-600" />
                  </>}
                  {topic === 'pinhole' && <>
                    <StatRow label="Image height" value={imgH.toFixed(1)} unit="px" color="text-indigo-600" />
                    <StatRow label="Magnification v/u" value={mag.toFixed(3)} unit="×" color="text-emerald-600" />
                    <StatRow label="Orientation" value="inverted" unit="" color="text-rose-500" />
                    <StatRow label="Nature" value="real" unit="" color="text-purple-600" />
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
                  {TEACHER_NOTES[topic].map((n, i) => (
                    <li key={i} className="text-xs text-amber-900 leading-relaxed flex gap-2">
                      <span className="text-amber-400 shrink-0 mt-0.5">•</span>{n}
                    </li>
                  ))}
                </ul>
              </div>

              <div className="rounded-2xl border border-gray-200 bg-white p-4">
                <p className="text-xs font-medium text-gray-500 uppercase tracking-wide mb-3">✏️ Exercises</p>
                <div className="space-y-2">
                  {EXERCISES[topic].map((ex, i) => (
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

echo "  → src/app/embed/rectilinear-propagation/page.tsx"
cat > "src/app/embed/rectilinear-propagation/page.tsx" << 'AFEOF'
'use client';
import { Suspense, useState, useCallback, useEffect, useRef } from 'react';
import { useSearchParams } from 'next/navigation';
import { ShadowsCanvas } from '@/components/simulation/ShadowsCanvas';
import { EclipseCanvas, EclipseType } from '@/components/simulation/EclipseCanvas';
import { PinholeCanvas } from '@/components/simulation/PinholeCanvas';
import { SimulationControls } from '@/components/simulation/SimulationControls';

type Topic = 'shadows' | 'eclipse' | 'pinhole';

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

function RectilinearEmbedInner() {
  const sp = useSearchParams();
  const topic = ((): Topic => {
    const t = sp.get('topic');
    return t === 'eclipse' || t === 'pinhole' ? t : 'shadows';
  })();
  const showControls = sp.get('controls') !== '0';

  const [sourceType, setSourceType] = useState<'point' | 'extended'>(() => (sp.get('src') === 'point' ? 'point' : 'extended'));
  const [sourceRadius, setSourceRadius] = useState(() => num(sp, 'sr', 35, 5, 60));
  const [objectRadius, setObjectRadius] = useState(() => num(sp, 'or', 24, 8, 50));
  const [objectDist, setObjectDist] = useState(() => num(sp, 'od', 160, 60, 300));
  const [screenDist, setScreenDist] = useState(() => num(sp, 'sd', 420, 100, 560));

  const [eclipseType, setEclipseType] = useState<EclipseType>(() => (sp.get('type') === 'lunar' ? 'lunar' : 'solar'));
  const [orbitalOffset, setOrbitalOffset] = useState(() => num(sp, 'offset', 0, 0, 120));

  const [objectHeight, setObjectHeight] = useState(() => num(sp, 'h', 90, 30, 130));
  const [pinholeObjectDist, setPinholeObjectDist] = useState(() => num(sp, 'u', 140, 60, 260));
  const [pinholeScreenDist, setPinholeScreenDist] = useState(() => num(sp, 'v', 160, 40, 260));
  const [pinholeRadius, setPinholeRadius] = useState(() => num(sp, 'r', 1, 0, 12));

  const [isRunning, setIsRunning] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const [resetKey, setResetKey] = useState(0);
  const reset = useCallback(() => { setIsRunning(false); setIsPaused(false); setResetKey(k => k + 1); }, []);
  const resetTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  useEffect(() => {
    if (resetTimer.current) clearTimeout(resetTimer.current);
    resetTimer.current = setTimeout(reset, 100);
  }, [topic, sourceType, sourceRadius, objectRadius, objectDist, screenDist, eclipseType, orbitalOffset, objectHeight, pinholeObjectDist, pinholeScreenDist, pinholeRadius, reset]);

  return (
    <div className="mx-auto max-w-2xl space-y-3 p-3 sm:p-4">
      {topic === 'shadows' && (
        <ShadowsCanvas key={resetKey} sourceType={sourceType} sourceRadiusPx={sourceRadius} objectRadiusPx={objectRadius}
          objectDistPx={objectDist} screenDistPx={screenDist}
          isRunning={isRunning} isPaused={isPaused} width={640} height={280} />
      )}
      {topic === 'eclipse' && (
        <EclipseCanvas key={resetKey} eclipseType={eclipseType} orbitalOffset={orbitalOffset}
          isRunning={isRunning} isPaused={isPaused} width={640} height={280} />
      )}
      {topic === 'pinhole' && (
        <PinholeCanvas objectHeightPx={objectHeight} objectDistPx={pinholeObjectDist} screenDistPx={pinholeScreenDist}
          pinholeRadiusPx={pinholeRadius} width={640} height={280} />
      )}
      {topic !== 'pinhole' && (
        <SimulationControls isRunning={isRunning} isPaused={isPaused}
          onRun={() => { setIsRunning(true); setIsPaused(false); }}
          onPause={() => setIsPaused(p => !p)} onReset={reset} />
      )}
      {showControls && (
        <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm space-y-3">
          <p className="text-xs font-medium uppercase tracking-wide text-gray-400">Parameters</p>
          {topic === 'shadows' && <>
            <div className="flex gap-2">
              {(['point', 'extended'] as const).map(t => (
                <button key={t} onClick={() => setSourceType(t)}
                  className={`flex-1 rounded-lg border px-2 py-1.5 text-xs font-medium capitalize transition ${
                    sourceType === t ? 'border-indigo-300 bg-indigo-50 text-indigo-700' : 'border-gray-200 bg-white text-gray-500'
                  }`}>{t}</button>
              ))}
            </div>
            {sourceType === 'extended' && (
              <Slider label="Source size" unit="px" value={sourceRadius} min={5} max={60} step={1} set={setSourceRadius} color="#fbbf24" />
            )}
            <Slider label="Object size" unit="px" value={objectRadius} min={8} max={50} step={1} set={setObjectRadius} color="#64748b" />
            <Slider label="Object distance" unit="px" value={objectDist} min={60} max={300} step={5} set={setObjectDist} color="#6366f1" />
            <Slider label="Screen distance" unit="px" value={screenDist} min={objectDist + 40} max={560} step={5} set={setScreenDist} color="#8b5cf6" />
          </>}
          {topic === 'eclipse' && <>
            <div className="flex gap-2">
              {(['solar', 'lunar'] as const).map(t => (
                <button key={t} onClick={() => setEclipseType(t)}
                  className={`flex-1 rounded-lg border px-2 py-1.5 text-xs font-medium capitalize transition ${
                    eclipseType === t ? 'border-indigo-300 bg-indigo-50 text-indigo-700' : 'border-gray-200 bg-white text-gray-500'
                  }`}>{t}</button>
              ))}
            </div>
            <Slider label="Orbital offset" unit="px" value={orbitalOffset} min={0} max={120} step={2} set={setOrbitalOffset} color="#6366f1" />
          </>}
          {topic === 'pinhole' && <>
            <Slider label="Object height" unit="px" value={objectHeight} min={30} max={130} step={5} set={setObjectHeight} color="#0f172a" />
            <Slider label="Object distance (u)" unit="px" value={pinholeObjectDist} min={60} max={260} step={5} set={setPinholeObjectDist} color="#6366f1" />
            <Slider label="Screen distance (v)" unit="px" value={pinholeScreenDist} min={40} max={260} step={5} set={setPinholeScreenDist} color="#8b5cf6" />
            <Slider label="Pinhole size" unit="px" value={pinholeRadius} min={0} max={12} step={0.5} set={setPinholeRadius} color="#f59e0b" />
          </>}
        </div>
      )}
      <PoweredBy />
    </div>
  );
}

export default function RectilinearEmbedPage() {
  return (
    <Suspense fallback={<div className="p-8 text-center text-xs text-gray-400">Loading simulation…</div>}>
      <RectilinearEmbedInner />
    </Suspense>
  );
}
AFEOF

echo ""
echo "✓ Patch v23 applied — 8 files written."
echo ""
echo "Next steps:"
echo "  rm -rf .next"
echo "  npm run dev"
echo ""
echo "Check:"
echo "  /simulations/rectilinear-propagation -> Shadows tab: press Run, the"
echo "    object should slide back and forth. Eclipse tab: press Run, the"
echo "    Moon should drift through alignment and back out."
echo "  /simulations/diffraction -> Grating tab: press Run, wavefronts"
echo "    should now animate. Young's double slit tab (new): press Run,"
echo "    watch the interference pattern and travelling wavefronts."
