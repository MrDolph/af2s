#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
# A-Factor STEM Studio — patch v32: fix Pause not freezing the animation in
# Shadows (and Reflection's rotating mirror, which had the identical bug)
#
#   Same root cause as the eclipse pause bug fixed in the previous patch.
#   Both canvases computed their animated value as
#   `animate ? liveValue : sliderValue`, where `animate` means "running
#   AND not paused". The instant Pause was pressed, that flipped to
#   false, so the view snapped straight back to whatever the slider's
#   current value was, instead of freezing at the live sweep position —
#   exactly the "pause isn't pausing, it's not letting me inspect the
#   view" symptom reported.
#
#   Having just fixed this exact pattern in the eclipse simulation,
#   searched the rest of the animated canvases for the same bug rather
#   than waiting for it to be reported topic by topic. Found it in
#   exactly two places: ShadowsCanvas (reported) and the rotating-mirror
#   mode of ReflectionCanvas (not yet reported, but the identical bug).
#   Checked every other animated canvas in the app (Capacitor,
#   Polarization) and confirmed they already use the correct pattern —
#   keyed on `isRunning` alone, which is what lets the animation freeze
#   in place on pause instead of resetting.
#
#   Fixed both by switching the condition from `animate` to `isRunning`:
#   while running (paused or not), the view always reflects the live
#   position, which simply stops advancing while paused rather than
#   falling back to the slider's default. The slider-controlled static
#   preview now only applies before Run is first pressed, or after an
#   actual Reset (which was already working correctly — it fully
#   remounts the canvas via a key change, which is the appropriate way
#   to return to the default and was not affected by this bug).
#
# Run from the af2s project root (Git Bash):   bash patches/patch-v32-shadows-pause-fix.sh
# ══════════════════════════════════════════════════════════════════════════════
set -euo pipefail

if [ ! -f "package.json" ]; then
  echo "Run this from the af2s project root (package.json not found)." >&2
  exit 1
fi

echo "-- A-Factor patch v32: fix Pause in Shadows + rotating mirror --"
mkdir -p "src/components/simulation"

echo "  -> src/components/simulation/ShadowsCanvas.tsx"
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
    // moves — bounded to stay clear of both endpoints. Freezes at the
    // current position while paused (keyed on isRunning alone) rather than
    // snapping back to the slider's default value, which is what
    // `animate` (isRunning && !isPaused) would do here — the same pause
    // bug found and fixed in the eclipse simulation.
    const minDist = 55, maxDist = s.screenDistPx - 45;
    const sweepMid = (minDist + maxDist) / 2, sweepAmp = (maxDist - minDist) / 2;
    const objectDistPx = s.isRunning
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

    // Four boundary rays, extended out to the screen's x. Verified by
    // brute-force sampling many source points (not just these four extreme
    // rays) which region each screen point actually falls in: the UMBRA
    // (fully dark) boundary is the SAME-SIDE pairing (top-to-top,
    // bottom-to-bottom), and the PENUMBRA's outer edge (where any light at
    // all first appears) is the OPPOSITE-SIDE pairing (top-to-bottom,
    // bottom-to-top) — this holds universally, whichever of the source or
    // the object is larger. The reverse assignment looks plausible from
    // the ray diagram alone but is provably wrong: sampled classification
    // showed the "opposite-side" region was >90% lit at its edges, not
    // fully dark.
    const umbraTopY = lineAtX(srcTop, objTop, scrX);   // same-side: true umbra, upper edge
    const umbraBotY = lineAtX(srcBot, objBot, scrX);   // same-side: true umbra, lower edge
    const penTopY = lineAtX(srcBot, objTop, scrX);     // opposite-side: true penumbra outer edge
    const penBotY = lineAtX(srcTop, objBot, scrX);     // opposite-side: true penumbra outer edge

    // Screen, painted in bands: lit (white) / penumbra (grayscale gradient
    // — dimmer, not a different hue) / umbra (near-black). Using a tinted
    // colour like yellow for "lit" or for the penumbra gradient invites
    // reading it as a difference in colour rather than in brightness — a
    // real penumbra is simply dimmer white light, so this stays grayscale
    // throughout.
    const screenTop = 20, screenBottom = H - 20;
    ctx.fillStyle = '#ffffff'; ctx.fillRect(scrX - 6, screenTop, 6, screenBottom - screenTop);
    const bandFill = (y0: number, y1: number, fill: string | CanvasGradient) => {
      const a = Math.max(screenTop, Math.min(y0, y1));
      const b = Math.min(screenBottom, Math.max(y0, y1));
      if (b <= a) return;
      ctx.fillStyle = fill;
      ctx.fillRect(scrX - 6, a, 6, b - a);
    };
    bandFill(screenTop, penTopY, '#ffffff');
    const gradTop = ctx.createLinearGradient(0, penTopY, 0, umbraTopY);
    gradTop.addColorStop(0, '#ffffff'); gradTop.addColorStop(1, '#0f172a');
    bandFill(penTopY, umbraTopY, gradTop);
    bandFill(umbraTopY, umbraBotY, '#0f172a');
    const gradBot = ctx.createLinearGradient(0, umbraBotY, 0, penBotY);
    gradBot.addColorStop(0, '#0f172a'); gradBot.addColorStop(1, '#ffffff');
    bandFill(umbraBotY, penBotY, gradBot);
    bandFill(penBotY, screenBottom, '#ffffff');

    // Rays
    const drawRay = (a: Vec, b: Vec, color: string, dashed = false) => {
      const endY = lineAtX(a, b, scrX);
      ctx.save(); if (dashed) ctx.setLineDash([4, 3]);
      ctx.strokeStyle = color; ctx.lineWidth = 1.3;
      ctx.beginPath(); ctx.moveTo(a.x, a.y); ctx.lineTo(scrX, endY); ctx.stroke();
      ctx.restore();
    };
    drawRay(srcTop, objTop, 'rgba(96,165,250,0.7)');
    drawRay(srcBot, objBot, 'rgba(96,165,250,0.7)');
    if (s.sourceType === 'extended') {
      drawRay(srcBot, objTop, 'rgba(100,116,139,0.55)');
      drawRay(srcTop, objBot, 'rgba(100,116,139,0.55)');
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
      ctx.fillStyle = '#64748b';
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

echo "  -> src/components/simulation/ReflectionCanvas.tsx"
cat > "src/components/simulation/ReflectionCanvas.tsx" << 'AFEOF'
'use client';
import { useRef, useEffect, useCallback } from 'react';
import { thinLensImage } from '@/lib/physics/optics';

export type ReflectionMode = 'plane' | 'curved' | 'rotation';

interface Props {
  mode: ReflectionMode;
  // plane
  incidenceAngle: number; // degrees from the normal
  // curved (cm as display units)
  focal: number;          // |f| in cm
  objectDist: number;     // u in cm
  converging: boolean;    // true = concave (converging), false = convex (diverging)
  // rotation — mirror angle used whenever the animation isn't actively
  // sweeping (i.e. before Run, or after Pause/Reset)
  rotationAngle: number;  // degrees, mirror tilt from its 0° reference position
  isRunning: boolean; isPaused: boolean;
  onTick?: (mirrorDeg: number, reflectedDeg: number) => void;
  width?: number; height?: number;
}

function arrow(ctx: CanvasRenderingContext2D, x1: number, y1: number, x2: number, y2: number, color: string, lw = 2, headAt = 0.55) {
  ctx.save();
  ctx.strokeStyle = color; ctx.lineWidth = lw;
  ctx.beginPath(); ctx.moveTo(x1, y1); ctx.lineTo(x2, y2); ctx.stroke();
  const hx = x1 + (x2 - x1) * headAt, hy = y1 + (y2 - y1) * headAt;
  const ang = Math.atan2(y2 - y1, x2 - x1);
  ctx.fillStyle = color;
  ctx.beginPath(); ctx.moveTo(hx, hy);
  ctx.lineTo(hx - 9 * Math.cos(ang - 0.4), hy - 9 * Math.sin(ang - 0.4));
  ctx.lineTo(hx - 9 * Math.cos(ang + 0.4), hy - 9 * Math.sin(ang + 0.4));
  ctx.closePath(); ctx.fill();
  ctx.restore();
}

function objectArrow(ctx: CanvasRenderingContext2D, x: number, yBase: number, yTip: number, color: string, label: string) {
  ctx.save();
  ctx.strokeStyle = color; ctx.lineWidth = 3; ctx.lineCap = 'round';
  ctx.beginPath(); ctx.moveTo(x, yBase); ctx.lineTo(x, yTip); ctx.stroke();
  const dir = Math.sign(yTip - yBase) || -1;
  ctx.fillStyle = color;
  ctx.beginPath(); ctx.moveTo(x, yTip);
  ctx.lineTo(x - 6, yTip - dir * 10); ctx.lineTo(x + 6, yTip - dir * 10);
  ctx.closePath(); ctx.fill();
  ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
  ctx.fillText(label, x, yTip - dir * 16);
  ctx.restore();
}

// A small asymmetric "flag" marker on an object/image arrow, so lateral
// inversion (mirror image flips left-right, unlike a rotation) is visibly
// obvious rather than just asserted in text.
function flag(ctx: CanvasRenderingContext2D, x: number, y: number, dir: 1 | -1, color: string) {
  ctx.save();
  ctx.fillStyle = color;
  ctx.beginPath();
  ctx.moveTo(x, y);
  ctx.lineTo(x + dir * 14, y - 5);
  ctx.lineTo(x + dir * 14, y + 5);
  ctx.closePath(); ctx.fill();
  ctx.restore();
}

interface Vec { x: number; y: number; }
function reflect(d: Vec, n: Vec): Vec {
  const dot = d.x * n.x + d.y * n.y;
  return { x: d.x - 2 * dot * n.x, y: d.y - 2 * dot * n.y };
}
function normalize(v: Vec): Vec {
  const len = Math.hypot(v.x, v.y) || 1;
  return { x: v.x / len, y: v.y / len };
}

const SWEEP_MAX_DEG = 35;
const SWEEP_PERIOD = 4.5; // s — one full back-and-forth cycle

export function ReflectionCanvas({
  mode, incidenceAngle, focal, objectDist, converging, rotationAngle,
  isRunning, isPaused, onTick, width = 660, height = 320,
}: Props) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const rafRef = useRef<number>(0);
  const lastFrameRef = useRef<number | null>(null);
  const t = useRef(0);
  const sim = useRef({ mode, incidenceAngle, focal, objectDist, converging, rotationAngle, isRunning, isPaused, onTick });
  sim.current = { mode, incidenceAngle, focal, objectDist, converging, rotationAngle, isRunning, isPaused, onTick };

  useEffect(() => { t.current = 0; lastFrameRef.current = null; }, [mode, incidenceAngle, focal, objectDist, converging, rotationAngle]);

  const draw = useCallback((timestamp?: number) => {
    const canvas = canvasRef.current; if (!canvas) return;
    const ctx = canvas.getContext('2d'); if (!ctx) return;
    const s = sim.current;
    const W = canvas.width, H = canvas.height;

    const animate = s.mode === 'rotation' && s.isRunning && !s.isPaused;
    if (animate && timestamp !== undefined) {
      if (lastFrameRef.current !== null) {
        t.current += Math.min((timestamp - lastFrameRef.current) / 1000, 0.1);
      }
      lastFrameRef.current = timestamp;
    } else {
      lastFrameRef.current = timestamp ?? null;
    }

    ctx.clearRect(0, 0, W, H);

    if (s.mode === 'plane') {
      const cx = W * 0.52, midY = H / 2;
      const mirrorTop = 20, mirrorBottom = H - 20;

      ctx.strokeStyle = '#334155'; ctx.lineWidth = 3;
      ctx.beginPath(); ctx.moveTo(cx, mirrorTop); ctx.lineTo(cx, mirrorBottom); ctx.stroke();
      ctx.strokeStyle = '#cbd5e1'; ctx.lineWidth = 1;
      for (let y = mirrorTop; y <= mirrorBottom; y += 12) {
        ctx.beginPath(); ctx.moveTo(cx + 2, y); ctx.lineTo(cx + 10, y - 7); ctx.stroke();
      }

      // Reflection point for the labelled i=r ray sits at a fixed height;
      // the OBJECT's position is derived from the incidence-angle slider
      // (not the other way round) so the ray genuinely starts at the
      // object instead of two disconnected diagrams sharing a canvas.
      const P0: Vec = { x: cx, y: midY * 1.05 };
      const eye: Vec = { x: cx - 200, y: H * 0.2 }; // same side as the object — you can't see a reflection from behind the mirror
      const th = (s.incidenceAngle * Math.PI) / 180;
      const rayLen = 130;
      const objTip: Vec = { x: P0.x - Math.cos(th) * rayLen, y: P0.y - Math.sin(th) * rayLen };
      const objHeight = 75;
      const objBase: Vec = { x: objTip.x, y: objTip.y + objHeight };

      // Reflection points for the two "what the eye actually sees" rays,
      // found via the mirror-image method: reflect the object point across
      // the mirror, draw a straight line to the eye, and where that line
      // crosses the mirror IS the true reflection point — this guarantees
      // the law of reflection holds and that the backward extension lands
      // exactly on the image, by construction rather than by coincidence.
      const findReflectionPoint = (obj: Vec): Vec => {
        const imgOfObj: Vec = { x: 2 * cx - obj.x, y: obj.y };
        const tt = (cx - imgOfObj.x) / (eye.x - imgOfObj.x);
        return { x: cx, y: imgOfObj.y + tt * (eye.y - imgOfObj.y) };
      };
      const P1 = findReflectionPoint(objTip);
      const P2 = findReflectionPoint(objBase);
      const imgTip: Vec = { x: 2 * cx - objTip.x, y: objTip.y };
      const imgBase: Vec = { x: 2 * cx - objBase.x, y: objBase.y };

      // Normal at P0, for the labelled i=r construction
      ctx.setLineDash([5, 5]); ctx.strokeStyle = '#94a3b8'; ctx.lineWidth = 1;
      ctx.beginPath(); ctx.moveTo(P0.x - 60, P0.y); ctx.lineTo(P0.x + 60, P0.y); ctx.stroke();
      ctx.setLineDash([]);
      ctx.fillStyle = '#94a3b8'; ctx.font = '9px system-ui'; ctx.textAlign = 'left';
      ctx.fillText('normal', P0.x + 62, P0.y + 3);

      // Ray A: object tip -> P0 -> reflects at an equal angle (labelled i, r)
      arrow(ctx, objTip.x, objTip.y, P0.x, P0.y, '#6366f1', 2.2);
      const rA = { x: P0.x - Math.cos(th) * 70, y: P0.y + Math.sin(th) * 70 };
      arrow(ctx, P0.x, P0.y, rA.x, rA.y, '#a5b4fc', 2.2);
      ctx.fillStyle = '#4338ca'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
      ctx.fillText(`i=${s.incidenceAngle}°`, P0.x - 30, P0.y - 10);
      ctx.fillStyle = '#818cf8';
      ctx.fillText(`r=${s.incidenceAngle}°`, P0.x - 30, P0.y + 20);

      // Ray B and C: the actual rays the eye receives, from the top and
      // bottom of the object — solid to the mirror and on to the eye, then
      // a dashed backward extension from the reflection point through the
      // eye's direction, landing exactly on the image (top/bottom).
      [
        { obj: objTip, P: P1 },
        { obj: objBase, P: P2 },
      ].forEach(({ obj, P }) => {
        arrow(ctx, obj.x, obj.y, P.x, P.y, '#10b981', 1.8);
        arrow(ctx, P.x, P.y, eye.x, eye.y, '#10b981', 1.8, 0.85);
        ctx.save(); ctx.setLineDash([5, 4]); ctx.strokeStyle = 'rgba(16,185,129,0.55)'; ctx.lineWidth = 1.4;
        const ang = Math.atan2(eye.y - P.y, eye.x - P.x);
        const backX = P.x - Math.cos(ang) * 260, backY = P.y - Math.sin(ang) * 260;
        ctx.beginPath(); ctx.moveTo(P.x, P.y); ctx.lineTo(backX, backY); ctx.stroke();
        ctx.restore();
      });

      // Object and image arrows — drawn last so they sit cleanly on top of
      // the rays that terminate exactly at their tip/base.
      objectArrow(ctx, objTip.x, objBase.y, objTip.y, '#0f172a', 'O');
      flag(ctx, objTip.x, objTip.y + 8, 1, '#0f172a');
      ctx.save(); ctx.globalAlpha = 0.85;
      objectArrow(ctx, imgTip.x, imgBase.y, imgTip.y, '#8b5cf6', 'I (virtual)');
      ctx.restore();
      flag(ctx, imgTip.x, imgTip.y + 8, -1, '#8b5cf6');

      ctx.fillStyle = '#a78bfa'; ctx.font = '16px system-ui'; ctx.textAlign = 'center';
      ctx.fillText('👁', eye.x, eye.y + 5);

      ctx.fillStyle = '#64748b'; ctx.font = '10px system-ui'; ctx.textAlign = 'left';
      ctx.fillText('Solid: real light rays reaching the eye. Dashed: traced backward — they meet exactly at the image, laterally inverted.', 8, H - 10);
    } else if (s.mode === 'curved') {
      const axisY = H / 2, cx = W / 2;
      const f = s.converging ? s.focal : -s.focal;
      const u = s.objectDist;
      const img = thinLensImage(u, f);
      const scale = Math.min(3.2, (W / 2 - 30) / Math.max(u, Math.abs(img.atInfinity ? u : img.v), 2 * s.focal));
      const hObj = 44;

      ctx.strokeStyle = '#94a3b8'; ctx.lineWidth = 1;
      ctx.beginPath(); ctx.moveTo(0, axisY); ctx.lineTo(W, axisY); ctx.stroke();

      const bow = s.converging ? -26 : 26;
      ctx.save();
      ctx.strokeStyle = '#6366f1'; ctx.lineWidth = 4;
      ctx.beginPath();
      ctx.moveTo(cx + bow, axisY - 80);
      ctx.quadraticCurveTo(cx - bow, axisY, cx + bow, axisY + 80);
      ctx.stroke();
      ctx.lineWidth = 1; ctx.strokeStyle = '#c7d2fe';
      for (let yOff = -70; yOff <= 70; yOff += 14) {
        const tParam = (yOff + 80) / 160;
        const curveX = cx + bow * Math.pow(1 - 2 * tParam, 2);
        ctx.beginPath();
        ctx.moveTo(curveX + 3, axisY + yOff);
        ctx.lineTo(curveX + 12, axisY + yOff - 8);
        ctx.stroke();
      }
      ctx.restore();

      const fPx = s.focal * scale;
      ctx.fillStyle = '#f59e0b'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
      ([[-fPx, 'F'], [-2 * fPx, '2F']] as [number, string][]).forEach(([dx, lab]) => {
        const x = cx + dx;
        if (x < 10 || x > W - 10) return;
        ctx.beginPath(); ctx.arc(x, axisY, 3, 0, Math.PI * 2); ctx.fill();
        ctx.fillText(lab, x, axisY + 16);
      });

      const objX = cx - u * scale;
      objectArrow(ctx, objX, axisY, axisY - hObj, '#0f172a', 'O');

      if (!img.atInfinity) {
        const ix = img.real ? cx - img.v * scale : cx + Math.abs(img.v) * scale;
        const tipY = img.inverted ? axisY + hObj * img.m : axisY - hObj * img.m;
        if (ix > -40 && ix < W + 40) {
          objectArrow(ctx, ix, axisY, tipY, img.real ? '#10b981' : '#8b5cf6', img.real ? 'I (real)' : 'I (virtual)');
        }
        const tip: [number, number] = [objX, axisY - hObj];
        const drawTo = (fromX: number, fromY: number, toX: number, toY: number, color: string, dashed = false) => {
          ctx.save(); if (dashed) ctx.setLineDash([5, 4]);
          ctx.strokeStyle = color; ctx.lineWidth = 1.6;
          const ang = Math.atan2(toY - fromY, toX - fromX);
          const ext = 60;
          ctx.beginPath(); ctx.moveTo(fromX, fromY);
          ctx.lineTo(toX + Math.cos(ang) * ext, toY + Math.sin(ang) * ext);
          ctx.stroke(); ctx.restore();
        };
        arrow(ctx, tip[0], tip[1], cx, tip[1], '#ef4444', 1.6, 0.5);
        drawTo(cx, tip[1], ix, tipY, '#ef4444', !img.real);
        arrow(ctx, tip[0], tip[1], cx, axisY, '#3b82f6', 1.6, 0.5);
        drawTo(cx, axisY, ix, tipY, '#3b82f6', !img.real);
      } else {
        ctx.fillStyle = '#64748b'; ctx.font = 'bold 11px system-ui'; ctx.textAlign = 'center';
        ctx.fillText('Object at F — rays emerge parallel, image at infinity', cx, 26);
      }

      ctx.fillStyle = '#64748b'; ctx.font = '10px system-ui'; ctx.textAlign = 'left';
      const nature = img.atInfinity ? 'at infinity'
        : `${img.real ? 'real' : 'virtual'}, ${img.inverted ? 'inverted' : 'upright'}, ${img.m > 1 ? 'magnified' : img.m < 1 ? 'diminished' : 'same size'}`;
      ctx.fillText(`u=${u}cm  f=${f}cm  →  v=${img.atInfinity ? '∞' : Math.abs(img.v).toFixed(1) + 'cm'}  m=${img.atInfinity ? '∞' : img.m.toFixed(2)}  (${nature})`, 8, H - 8);
    } else {
      // ── Rotation of a mirror: incident ray fixed, mirror rotates ──────────
      // Classic result: rotate the mirror by θ, the reflected ray rotates by
      // 2θ. Uses genuine vector reflection (not an assumed formula) and then
      // MEASURES the angle between the current and reference reflected rays,
      // so the 2θ relationship is demonstrated, not just asserted.
      const P: Vec = { x: W * 0.6, y: H * 0.58 };     // fixed point of incidence
      const S: Vec = { x: P.x - 230, y: P.y - 150 };  // fixed light source

      const d = normalize({ x: P.x - S.x, y: P.y - S.y }); // fixed incident direction

      // Freezes at the current sweep angle while paused (keyed on
      // isRunning alone) rather than snapping back to the slider's
      // default value — the same pause bug found and fixed in the
      // shadows and eclipse simulations.
      const angleDeg = s.isRunning
        ? SWEEP_MAX_DEG * Math.sin((2 * Math.PI / SWEEP_PERIOD) * t.current)
        : s.rotationAngle;
      const angleRad = (angleDeg * Math.PI) / 180;

      const mirrorDir: Vec = { x: Math.cos(angleRad), y: Math.sin(angleRad) };
      const normal: Vec = { x: Math.sin(angleRad), y: -Math.cos(angleRad) }; // points "up" at 0°
      const normal0: Vec = { x: 0, y: -1 };

      const r = reflect(d, normal);
      const r0 = reflect(d, normal0);
      const reflectedDeg = ((Math.atan2(r.y, r.x) - Math.atan2(r0.y, r0.x)) * 180) / Math.PI;
      s.onTick?.(angleDeg, reflectedDeg);

      ctx.fillStyle = '#f8fafc'; ctx.fillRect(0, 0, W, H);

      // Faint reference (0°) mirror position and reflected ray
      const refLen = 100;
      ctx.save(); ctx.setLineDash([4, 4]); ctx.strokeStyle = '#e2e8f0'; ctx.lineWidth = 1.5;
      ctx.beginPath(); ctx.moveTo(P.x - refLen, P.y); ctx.lineTo(P.x + refLen, P.y); ctx.stroke();
      ctx.strokeStyle = '#fde68a';
      ctx.beginPath(); ctx.moveTo(P.x, P.y); ctx.lineTo(P.x + r0.x * 190, P.y + r0.y * 190); ctx.stroke();
      ctx.restore();

      // Current mirror (solid) with silvered-back hatching
      const mLen = 100;
      ctx.strokeStyle = '#334155'; ctx.lineWidth = 4;
      ctx.beginPath();
      ctx.moveTo(P.x - mirrorDir.x * mLen, P.y - mirrorDir.y * mLen);
      ctx.lineTo(P.x + mirrorDir.x * mLen, P.y + mirrorDir.y * mLen);
      ctx.stroke();
      ctx.strokeStyle = '#cbd5e1'; ctx.lineWidth = 1;
      for (let k = -mLen + 8; k <= mLen - 8; k += 12) {
        const bx = P.x + mirrorDir.x * k, by = P.y + mirrorDir.y * k;
        ctx.beginPath();
        ctx.moveTo(bx + normal.x * -2, by + normal.y * -2);
        ctx.lineTo(bx + normal.x * -10 + mirrorDir.x * 6, by + normal.y * -10 + mirrorDir.y * 6);
        ctx.stroke();
      }

      // Normal (dashed)
      ctx.save(); ctx.setLineDash([4, 4]); ctx.strokeStyle = '#94a3b8'; ctx.lineWidth = 1;
      ctx.beginPath(); ctx.moveTo(P.x - normal.x * 60, P.y - normal.y * 60); ctx.lineTo(P.x + normal.x * 60, P.y + normal.y * 60); ctx.stroke();
      ctx.restore();

      // Incident ray (fixed) and current reflected ray
      arrow(ctx, S.x, S.y, P.x, P.y, '#6366f1', 2.5);
      arrow(ctx, P.x, P.y, P.x + r.x * 190, P.y + r.y * 190, '#10b981', 2.5);

      // Angle arcs: mirror rotation (small, at the mirror) vs reflected-ray
      // rotation (bigger, at the reflected ray) — drawn so the "twice as
      // wide" relationship is visible at a glance, not just in the numbers.
      const arcR1 = 34;
      ctx.strokeStyle = '#f59e0b'; ctx.lineWidth = 2;
      ctx.beginPath(); ctx.arc(P.x, P.y, arcR1, -Math.PI / 2, -Math.PI / 2 + angleRad, angleRad < 0); ctx.stroke();
      const arcR2 = 60;
      const a0 = Math.atan2(r0.y, r0.x), a1 = Math.atan2(r.y, r.x);
      ctx.strokeStyle = '#ef4444'; ctx.lineWidth = 2;
      ctx.beginPath(); ctx.arc(P.x, P.y, arcR2, a0, a1, a1 < a0); ctx.stroke();

      ctx.fillStyle = '#334155'; ctx.font = 'bold 11px system-ui'; ctx.textAlign = 'center';
      ctx.fillText(`Mirror rotated ${angleDeg.toFixed(1)}°  →  reflected ray rotated ${reflectedDeg.toFixed(1)}°  (≈ 2× the mirror's rotation)`, W / 2, 22);
      ctx.fillStyle = '#64748b'; ctx.font = '10px system-ui'; ctx.textAlign = 'left';
      ctx.fillText('Light source position is fixed — only the mirror turns', 8, H - 10);
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
AFEOF

echo ""
echo "Patch v32 applied -- 2 files written."
echo ""
echo "Next steps:"
echo "  rm -rf .next"
echo "  npm run dev"
echo ""
echo "Check: /simulations/rectilinear-propagation -> Shadows tab. Press Run,"
echo "then Pause partway through -- the object should freeze in place for"
echo "inspection, not jump back to the slider's default. Reset should still"
echo "return everything to default as expected. Same check applies to"
echo "/simulations/reflection -> Rotating mirror tab."
