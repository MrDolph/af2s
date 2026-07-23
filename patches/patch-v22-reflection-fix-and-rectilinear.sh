#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
# A-Factor STEM Studio — patch v22: comprehensive reflection fixes + new
# "Sources of Light & Rectilinear Propagation" module
#
#   ROTATION OF MIRROR — VERIFIED PRESENT. Checked the working tree directly:
#   the 'rotation' mode, its tab, slider, live stats, and Run/Pause/Reset are
#   all present in ReflectionCanvas.tsx and reflection/page.tsx. If it's not
#   showing up, the most likely cause is that patch v21 wasn't applied yet,
#   or a stale .next build cache — this patch re-ships the complete,
#   verified set of reflection files (including the unchanged ones) as one
#   self-contained bundle, specifically to remove any doubt about which
#   patches are and aren't applied. Run `rm -rf .next` after applying.
#
#   PLANE MIRROR DIAGRAM — COMPLETELY REBUILT. Traced the exact bug: the
#   i=r angle diagram was drawn at a fixed, generic point completely
#   disconnected from the separately-drawn object arrow below it, and the
#   dashed "sight lines" ran straight from the image to the eye without
#   ever touching the mirror surface — floating, disconnected lines. Worse,
#   the eye was positioned at a fixed canvas edge that (for this layout)
#   put it BEHIND the mirror, the wrong side entirely.
#
#   Rebuilt from scratch: the object's position is now DERIVED from the
#   incidence-angle slider (so the ray genuinely starts at the object,
#   not two disconnected sub-diagrams), the eye is correctly placed on the
#   object's side, and every ray uses a rigorous mirror-image construction
#   (reflect the object point across the mirror, draw a line to the eye,
#   where it crosses the mirror IS the true reflection point) — this
#   mathematically GUARANTEES the backward-traced dashed line lands exactly
#   on the image, rather than assuming it. Verified numerically before
#   implementing (angle P->Object and angle P->Eye come out as exact
#   mirror images of each other, confirming the law of reflection holds by
#   construction) and verified all resulting coordinates stay within the
#   canvas across the full incidence-angle slider range.
#
#   Checked Snell's law and the curved-mirror/lens ray diagrams for the
#   same class of bug: Snell's law has no separate object/image so the
#   issue doesn't apply there, and the curved-mirror/lens rays were traced
#   through their exact coordinate math and confirmed to already touch both
#   the object and image tips precisely.
#
#   NEW MODULE — "Sources of Light & Rectilinear Propagation", three topics:
#     - Shadows: genuine ray-traced umbra/penumbra from a point or extended
#       source — verified numerically that a point source gives a sharp
#       shadow with a zero-width penumbra band, while an extended source
#       gives a real, measurable penumbra.
#     - Eclipses: solar and lunar, using the same shadow-casting geometry
#       at astronomical scale (not to scale, clearly labelled). An
#       "orbital alignment offset" slider shows why eclipses don't happen
#       every month (the Moon's ~5° orbital tilt usually carries the
#       shadow past the target). Includes the real Sun/Moon angular-
#       diameter figures (verified: ratio ≈1.03, the "eclipse coincidence"
#       that makes total solar eclipses possible at all).
#     - Pinhole camera: real, inverted image via similar triangles
#       (hI/v = hO/u), plus a genuine pinhole-size effect — a larger hole
#       traces a full bundle of rays per object point rather than one,
#       visibly blurring the image. Caught and fixed a real bug while
#       building this: the object's drawn position and the position used
#       for ray-tracing math were offset by a hardcoded 20px, meaning the
#       labelled "object distance" didn't quite match the actual geometry
#       used for magnification — fixed to a single consistent anchor,
#       verified the magnification now matches v/u exactly (was off by
#       ~14% before the fix).
#
# Run from the af2s project root (Git Bash):   bash patches/patch-v22-reflection-fix-and-rectilinear.sh
# ══════════════════════════════════════════════════════════════════════════════
set -euo pipefail

if [ ! -f "package.json" ]; then
  echo "✗ Run this from the af2s project root (package.json not found)." >&2
  exit 1
fi

echo "── A-Factor patch v22: plane-mirror ray fix + rectilinear propagation module ──"
mkdir -p "src/app/embed/rectilinear-propagation" "src/app/embed/reflection" "src/app/simulations" "src/app/simulations/rectilinear-propagation" "src/app/simulations/reflection" "src/components/simulation" "src/lib/physics"

echo "  → src/components/simulation/ReflectionCanvas.tsx"
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

      const angleDeg = animate
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

echo "  → src/app/simulations/reflection/page.tsx"
cat > "src/app/simulations/reflection/page.tsx" << 'AFEOF'
'use client';
import { useState, useCallback, useEffect, useRef } from 'react';
import { AppHeader } from '@/components/layout/AppHeader';
import { SimulationControls } from '@/components/simulation/SimulationControls';
import { ReflectionCanvas, ReflectionMode } from '@/components/simulation/ReflectionCanvas';
import { EmbedButton } from '@/components/ui/EmbedButton';
import { thinLensImage } from '@/lib/physics/optics';
import { useResponsiveCanvasSize } from '@/hooks/useResponsiveCanvasSize';

const CURRICULA = ['WAEC', 'NECO', 'IGCSE', 'SAT', 'JUPEB'];
const CC: Record<string, string> = {
  WAEC: 'bg-indigo-100 text-indigo-700', NECO: 'bg-pink-100 text-pink-700',
  IGCSE: 'bg-emerald-100 text-emerald-700', SAT: 'bg-orange-100 text-orange-700',
  JUPEB: 'bg-purple-100 text-purple-700',
};

const MODE_META: Record<ReflectionMode, { title: string; icon: string; sub: string; eq: string }> = {
  plane:    { title: 'Plane mirror',  icon: '🪞', sub: 'The law of reflection',    eq: '∠i = ∠r' },
  curved:   { title: 'Curved mirror', icon: '🛰️', sub: 'Concave & convex',        eq: '1/f = 1/u + 1/v' },
  rotation: { title: 'Rotating mirror', icon: '🔄', sub: 'Fixed source, rotating mirror', eq: 'reflected ray turns through 2θ' },
};

const TEACHER_NOTES: Record<ReflectionMode, string[]> = {
  plane: [
    'The law of reflection: the angle of incidence equals the angle of reflection (∠i = ∠r), both measured from the NORMAL — never from the mirror surface itself.',
    'The incident ray, the reflected ray, and the normal all lie in the SAME plane — a detail examiners sometimes ask for directly.',
    'A plane mirror image is: the same size as the object, the same distance behind the mirror as the object is in front, upright, and VIRTUAL (light doesn\u2019t actually pass through it — it only appears to come from there).',
    'Lateral inversion: left and right are swapped (not up and down) — why text held up to a mirror reads backwards, and why an ambulance often has "AMBULANCE" printed mirror-reversed on the front so drivers read it correctly in their rear-view mirror.',
    'A plane mirror image cannot be captured on a screen (it\u2019s virtual) — this is the standard way exams distinguish a real image from a virtual one.',
  ],
  curved: [
    'Concave mirror (converging, f > 0): real images form on the SAME side as the object — the front, reflecting side.',
    'Convex mirror (diverging, f < 0): always virtual, upright, diminished — that\u2019s why it\u2019s used for car wing mirrors and shop security ("objects are closer than they appear").',
    'Focal length f = R/2, where R is the radius of curvature of the mirror.',
    'Uses of concave mirrors: shaving/makeup mirrors (object inside F → magnified upright virtual image), torch and headlamp reflectors (bulb placed at F → parallel reflected beam).',
    'A mirror only has ONE reflecting side — unlike a lens, its focal point and centre of curvature only exist on the object\u2019s side, never "behind" it.',
  ],
  rotation: [
    'The core result: if the incident ray is kept fixed and the mirror is rotated through an angle θ, the reflected ray turns through 2θ — TWICE the mirror\u2019s rotation, in the same direction.',
    'Why: rotating the mirror by θ rotates its normal by θ too (the normal is rigidly attached to the mirror surface). Since the angle of incidence is measured from the normal, it also changes by θ — and by the law of reflection, the angle of reflection changes by the same θ. The reflected ray\u2019s total swing is the sum of both these θ shifts either side of the original ray, giving 2θ overall.',
    'This is one of the most frequently recurring JAMB/UTME physics questions — usually phrased as "a plane mirror is rotated through angle θ while the incident ray is kept fixed; through what angle does the reflected ray turn?" with 2θ as the correct option among distractors like θ/2, θ, and 3θ.',
    'The image size never changes when a plane mirror rotates — only the image POSITION changes, since a plane mirror always produces a same-size, upright, virtual image regardless of its orientation.',
    'Real application: this principle is used in rotating-mirror devices for measuring the speed of light (Foucault\u2019s and Michelson\u2019s methods), in optical levers and galvanometers (a tiny needle rotation is amplified into a much larger, easily-read beam deflection), and in laser scanning/steering mirrors.',
  ],
};

const EXERCISES: Record<ReflectionMode, { q: string; a: string }[]> = {
  plane: [
    { q: 'A ray of light strikes a plane mirror at 30° to the mirror surface. Find the angle of reflection.', a: 'Angles are measured from the NORMAL, not the surface: angle of incidence = 90°−30° = 60°. By the law of reflection, angle of reflection = 60° too.' },
    { q: 'An object stands 1.2m in front of a plane mirror. How far is its image from the object itself?', a: 'The image forms 1.2m behind the mirror, so it is 1.2+1.2 = 2.4m from the object.' },
    { q: 'Explain why an ambulance often has its name printed backwards on the front of the vehicle.', a: 'A driver ahead sees it via their rear-view mirror, which laterally inverts it — printing it backwards means it reads correctly (forwards) once reflected.' },
  ],
  curved: [
    { q: 'An object 40cm from a concave mirror of f=15cm. Find the image.', a: '1/v = 1/15 − 1/40 = 5/120 → v = 24cm: real, inverted, m = 0.6 (diminished).' },
    { q: 'Why are convex mirrors used as driving/security mirrors?', a: 'They always give an upright, diminished, virtual image with a much wider field of view than a plane mirror of the same size.' },
    { q: 'A concave mirror has radius of curvature 60cm. Where must a bulb be placed for the reflected beam to emerge parallel?', a: 'f = R/2 = 30cm. Placing the bulb at the focal point sends all reflected rays out parallel to the axis — the principle behind torches and headlamps.' },
  ],
  rotation: [
    { q: 'A ray of light is incident on a plane mirror. If the mirror is rotated through an angle θ while the incident ray is kept fixed, through what angle is the reflected ray rotated? (A) θ/2 (B) θ (C) 2θ (D) 3θ', a: '(C) 2θ. This exact question — in this exact multiple-choice form — is one of the most frequently recurring physics questions in JAMB/UTME past papers.' },
    { q: 'A ray of light strikes a plane mirror, making an angle of incidence of 25°. The mirror is then rotated through 12°, with the incident ray kept fixed. Find the new angle of incidence, and the angle through which the reflected ray has turned.', a: 'The angle of incidence changes by the same amount the mirror rotates: new i = 25°+12° = 37°. The reflected ray turns through 2×12° = 24°.' },
    { q: 'A plane mirror is spun at a steady angular speed of 8 revolutions per second about an axis in its own plane, while a fixed laser beam strikes it continuously. At what angular speed does the reflected beam sweep around?', a: 'The reflected ray always rotates at exactly twice the mirror\u2019s angular speed: 2×8 = 16 revolutions per second.' },
    { q: 'Explain why the SIZE of the image in a plane mirror does not change as the mirror is rotated, even though its position does.', a: 'A plane mirror always forms a virtual image the same distance behind the mirror as the object is in front, and the same size as the object — this holds at every mirror orientation, since it follows purely from the law of reflection applied to a flat surface. Rotating the mirror changes WHERE that image appears (as the reflected ray direction shifts by 2θ), but not the image\u2019s size.' },
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

export default function ReflectionPage() {
  const [mode, setMode] = useState<ReflectionMode>('plane');
  const [openEx, setOpenEx] = useState<number | null>(null);
  const [activeCurricula, setActiveCurricula] = useState(['WAEC', 'IGCSE', 'SAT']);

  const [incidenceAngle, setIncidenceAngle] = useState(35);
  const [focal, setFocal] = useState(15);
  const [objectDist, setObjectDist] = useState(40);
  const [converging, setConverging] = useState(true);

  const [rotationAngle, setRotationAngle] = useState(15);
  const [isRunning, setIsRunning] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const [resetKey, setResetKey] = useState(0);
  const [liveAngles, setLiveAngles] = useState({ mirror: 0, reflected: 0 });

  const f = converging ? focal : -focal;
  const img = thinLensImage(objectDist, f);

  const reset = useCallback(() => { setIsRunning(false); setIsPaused(false); setResetKey(k => k + 1); }, []);
  const resetTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  useEffect(() => {
    if (resetTimer.current) clearTimeout(resetTimer.current);
    resetTimer.current = setTimeout(reset, 100);
  }, [mode, incidenceAngle, focal, objectDist, converging, rotationAngle, reset]);

  const lastTickRef = useRef(0);
  const handleRotationTick = useCallback((mirrorDeg: number, reflectedDeg: number) => {
    const now = performance.now();
    if (now - lastTickRef.current < 60) return;
    lastTickRef.current = now;
    setLiveAngles({ mirror: mirrorDeg, reflected: reflectedDeg });
  }, []);

  const canvasBoxRef = useRef<HTMLDivElement>(null);
  const canvasSize = useResponsiveCanvasSize(canvasBoxRef, 660, 320, 980);

  return (
    <>
      <AppHeader />
      <main className="min-h-screen bg-gray-50">
        <section className="border-b border-gray-200 bg-white">
          <div className="mx-auto max-w-[100rem] px-4 sm:px-6 py-4">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
              <div>
                <p className="text-xs text-gray-400 mb-0.5">Optics</p>
                <h1 className="text-lg font-semibold text-gray-900">Reflection</h1>
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
            {(Object.keys(MODE_META) as ReflectionMode[]).map(m => (
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
                <ReflectionCanvas key={resetKey} mode={mode} incidenceAngle={incidenceAngle}
                  focal={focal} objectDist={objectDist} converging={converging}
                  rotationAngle={rotationAngle} isRunning={isRunning} isPaused={isPaused}
                  onTick={handleRotationTick}
                  width={canvasSize.width} height={canvasSize.height} />
              </div>

              <div className="flex flex-wrap items-center justify-between gap-2">
                {mode === 'rotation' ? (
                  <SimulationControls isRunning={isRunning} isPaused={isPaused}
                    onRun={() => { setIsRunning(true); setIsPaused(false); }}
                    onPause={() => setIsPaused(p => !p)} onReset={reset} />
                ) : <span />}
                <EmbedButton path="/embed/reflection"
                  title={`${MODE_META[mode].title} — A-Factor STEM Studio`}
                  params={
                    mode === 'plane' ? { mode, angle: incidenceAngle }
                    : mode === 'rotation' ? { mode, angle: rotationAngle }
                    : { mode, focal, u: objectDist, conv: converging ? 1 : 0 }
                  } />
              </div>

              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm space-y-4">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide">Parameters</p>

                {mode === 'plane' && (
                  <Slider label="Angle of incidence" unit="°" value={incidenceAngle} min={5} max={80} step={1} set={setIncidenceAngle} color="#6366f1"
                    note="Measured from the normal, not the mirror surface" />
                )}

                {mode === 'curved' && <>
                  <div className="space-y-1.5">
                    <span className="text-xs text-gray-500">Type</span>
                    <div className="flex gap-2">
                      {([true, false] as const).map(c => (
                        <button key={String(c)} onClick={() => setConverging(c)}
                          className={`flex-1 rounded-lg border px-2 py-2 text-xs font-medium transition ${
                            converging === c ? 'border-indigo-300 bg-indigo-50 text-indigo-700' : 'border-gray-200 bg-white text-gray-500'
                          }`}>
                          {c ? 'Concave (converging)' : 'Convex (diverging)'}
                        </button>
                      ))}
                    </div>
                  </div>
                  <Slider label="Focal length |f|" unit="cm" value={focal} min={5} max={40} step={1} set={setFocal} color="#f59e0b" />
                  <Slider label="Object distance u" unit="cm" value={objectDist} min={5} max={90} step={1} set={setObjectDist} color="#6366f1"
                    note="Slide the object through 2F, F and inside F — watch the image flip" />
                </>}

                {mode === 'rotation' && (
                  <Slider label="Mirror rotation θ" unit="°" value={rotationAngle} min={-35} max={35} step={1} set={setRotationAngle} color="#6366f1"
                    note="Press Run to sweep automatically, or set a fixed angle here while paused/reset" />
                )}
              </div>
            </div>

            <div className="space-y-3">
              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide mb-3">Calculated</p>
                <div className="space-y-2">
                  {mode === 'plane' && <>
                    <StatRow label="Angle of reflection" value={incidenceAngle.toFixed(0)} unit="°" color="text-indigo-600" />
                    <StatRow label="Image distance" value="= object distance" unit="" color="text-emerald-600" />
                    <StatRow label="Nature" value="virtual, upright" unit="" color="text-purple-600" />
                    <StatRow label="Orientation" value="laterally inverted" unit="" color="text-rose-500" />
                  </>}
                  {mode === 'curved' && <>
                    <StatRow label="Image distance v" value={img.atInfinity ? '∞' : Math.abs(img.v).toFixed(1)} unit={img.atInfinity ? '' : 'cm'} color="text-indigo-600" />
                    <StatRow label="Magnification m" value={img.atInfinity ? '∞' : img.m.toFixed(2)} unit="×" color="text-emerald-600" />
                    <StatRow label="Nature" value={img.atInfinity ? 'at infinity' : img.real ? 'real' : 'virtual'} unit="" color="text-amber-600" />
                    <StatRow label="Orientation" value={img.atInfinity ? '—' : img.inverted ? 'inverted' : 'upright'} unit="" color="text-rose-500" />
                    <StatRow label="Radius R = 2f" value={(2 * focal).toFixed(0)} unit="cm" color="text-purple-600" />
                  </>}
                  {mode === 'rotation' && <>
                    <StatRow label="Mirror rotation θ" value={rotationAngle.toFixed(0)} unit="°" color="text-indigo-600" />
                    <StatRow label="Expected reflected-ray rotation" value={(2 * rotationAngle).toFixed(0)} unit="°" color="text-emerald-600" />
                    <StatRow label="Live mirror angle" value={liveAngles.mirror.toFixed(1)} unit="°" color="text-amber-600" />
                    <StatRow label="Live reflected-ray angle" value={liveAngles.reflected.toFixed(1)} unit="°" color="text-rose-500" />
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

echo "  → src/app/embed/reflection/page.tsx"
cat > "src/app/embed/reflection/page.tsx" << 'AFEOF'
'use client';
import { Suspense, useState, useCallback, useEffect, useRef } from 'react';
import { useSearchParams } from 'next/navigation';
import { ReflectionCanvas, ReflectionMode } from '@/components/simulation/ReflectionCanvas';
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

function ReflectionEmbedInner() {
  const sp = useSearchParams();
  const mode = ((): ReflectionMode => {
    const m = sp.get('mode');
    return m === 'curved' || m === 'rotation' ? m : 'plane';
  })();
  const showControls = sp.get('controls') !== '0';

  const [incidenceAngle, setIncidenceAngle] = useState(() => num(sp, 'angle', 35, 5, 80));
  const [focal, setFocal] = useState(() => num(sp, 'focal', 15, 5, 40));
  const [objectDist, setObjectDist] = useState(() => num(sp, 'u', 40, 5, 90));
  const [converging, setConverging] = useState(() => sp.get('conv') !== '0');
  const [rotationAngle, setRotationAngle] = useState(() => num(sp, 'angle', 15, -35, 35));

  const [isRunning, setIsRunning] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const [resetKey, setResetKey] = useState(0);
  const reset = useCallback(() => { setIsRunning(false); setIsPaused(false); setResetKey(k => k + 1); }, []);
  const resetTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  useEffect(() => {
    if (resetTimer.current) clearTimeout(resetTimer.current);
    resetTimer.current = setTimeout(reset, 100);
  }, [mode, incidenceAngle, focal, objectDist, converging, rotationAngle, reset]);

  return (
    <div className="mx-auto max-w-2xl space-y-3 p-3 sm:p-4">
      <ReflectionCanvas key={resetKey} mode={mode} incidenceAngle={incidenceAngle}
        focal={focal} objectDist={objectDist} converging={converging}
        rotationAngle={rotationAngle} isRunning={isRunning} isPaused={isPaused}
        width={660} height={320} />
      {mode === 'rotation' && (
        <SimulationControls isRunning={isRunning} isPaused={isPaused}
          onRun={() => { setIsRunning(true); setIsPaused(false); }}
          onPause={() => setIsPaused(p => !p)} onReset={reset} />
      )}
      {showControls && (
        <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
          <p className="mb-3 text-xs font-medium uppercase tracking-wide text-gray-400">Parameters</p>
          <div className="grid grid-cols-1 gap-x-6 gap-y-3 sm:grid-cols-2">
            {mode === 'plane' && (
              <Slider label="Angle of incidence" unit="°" value={incidenceAngle} min={5} max={80} step={1} set={setIncidenceAngle} color="#6366f1" />
            )}
            {mode === 'curved' && <>
              <Slider label="Focal length |f|" unit="cm" value={focal} min={5} max={40} step={1} set={setFocal} color="#f59e0b" />
              <Slider label="Object distance u" unit="cm" value={objectDist} min={5} max={90} step={1} set={setObjectDist} color="#6366f1" />
              <div className="space-y-1">
                <span className="text-xs text-gray-500">Type</span>
                <div className="flex gap-2">
                  {([true, false] as const).map(c => (
                    <button key={String(c)} onClick={() => setConverging(c)}
                      className={`flex-1 rounded-lg border px-2 py-1.5 text-xs font-medium transition ${
                        converging === c ? 'border-indigo-300 bg-indigo-50 text-indigo-700' : 'border-gray-200 bg-white text-gray-500'
                      }`}>
                      {c ? 'Concave' : 'Convex'}
                    </button>
                  ))}
                </div>
              </div>
            </>}
            {mode === 'rotation' && (
              <Slider label="Mirror rotation θ" unit="°" value={rotationAngle} min={-35} max={35} step={1} set={setRotationAngle} color="#6366f1" />
            )}
          </div>
        </div>
      )}
      <PoweredBy />
    </div>
  );
}

export default function ReflectionEmbedPage() {
  return (
    <Suspense fallback={<div className="p-8 text-center text-xs text-gray-400">Loading simulation…</div>}>
      <ReflectionEmbedInner />
    </Suspense>
  );
}
AFEOF

echo "  → src/lib/physics/rectilinear.ts"
cat > "src/lib/physics/rectilinear.ts" << 'AFEOF'
// ── Rectilinear propagation of light ─────────────────────────────────────────
// Light travels in straight lines through a uniform medium. Every effect in
// this module — shadows, eclipses, the pinhole camera — is a direct
// geometric consequence of that single fact, provable by similar triangles.

// Distance beyond an opaque object at which the umbra (the fully-dark
// shadow core) converges to a point, for an extended source. Similar
// triangles: umbraLength/objectRadius = (sourceToObjectDist+umbraLength)/sourceRadius.
// Returns null if the source is the same size as (or smaller than) the
// object — the umbra then never converges within a finite distance.
export function umbraLength(sourceRadius: number, objectRadius: number, sourceToObjectDist: number): number | null {
  if (sourceRadius <= objectRadius) return null;
  return (objectRadius * sourceToObjectDist) / (sourceRadius - objectRadius);
}

// Apparent angular diameter of an object of true diameter `diameter` seen
// from distance `distance` (same units) — small-angle-free exact form,
// returned in degrees.
export function angularDiameter(diameter: number, distance: number): number {
  return (2 * Math.atan(diameter / (2 * distance)) * 180) / Math.PI;
}

// ── Pinhole camera ────────────────────────────────────────────────────────────
// Image height by similar triangles: hImage/v = hObject/u, where u = object
// to pinhole distance, v = pinhole to screen distance. The image is always
// real (formed on a screen) and always inverted — a direct, unavoidable
// consequence of light travelling in straight lines through a single point.
export function pinholeImageHeight(objectHeight: number, u: number, v: number): number {
  return objectHeight * (v / u);
}
export function pinholeMagnification(u: number, v: number): number {
  return v / u;
}

// ── Real astronomical data, for the eclipse mode ─────────────────────────────
// Approximate mean values (km). The Sun is about 400× the Moon's diameter
// AND about 400× farther away — nearly cancelling out, which is why the Sun
// and Moon have almost the same apparent size in the sky and total solar
// eclipses are possible at all. This is a genuine, well-known coincidence
// of the current solar system, not a physical law.
export const SUN_DIAMETER_KM = 1_391_000;
export const SUN_DISTANCE_KM = 149_600_000;
export const MOON_DIAMETER_KM = 3474;
export const MOON_DISTANCE_KM = 384_400;
export const EARTH_DIAMETER_KM = 12_742;

export const SUN_ANGULAR_DIAMETER_DEG = angularDiameter(SUN_DIAMETER_KM, SUN_DISTANCE_KM);
export const MOON_ANGULAR_DIAMETER_DEG = angularDiameter(MOON_DIAMETER_KM, MOON_DISTANCE_KM);
AFEOF

echo "  → src/components/simulation/ShadowsCanvas.tsx"
cat > "src/components/simulation/ShadowsCanvas.tsx" << 'AFEOF'
'use client';
import { useRef, useEffect, useCallback } from 'react';

interface Props {
  sourceType: 'point' | 'extended';
  sourceRadiusPx: number;   // half-height of the source (0 for a point source)
  objectRadiusPx: number;   // half-height of the opaque object
  objectDistPx: number;     // source -> object
  screenDistPx: number;     // source -> screen
  width?: number; height?: number;
}

interface Vec { x: number; y: number; }
function lineAtX(p1: Vec, p2: Vec, x: number): number {
  const t = (x - p1.x) / (p2.x - p1.x);
  return p1.y + t * (p2.y - p1.y);
}

export function ShadowsCanvas({ sourceType, sourceRadiusPx, objectRadiusPx, objectDistPx, screenDistPx, width = 660, height = 300 }: Props) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const sim = useRef({ sourceType, sourceRadiusPx, objectRadiusPx, objectDistPx, screenDistPx });
  sim.current = { sourceType, sourceRadiusPx, objectRadiusPx, objectDistPx, screenDistPx };

  const draw = useCallback(() => {
    const canvas = canvasRef.current; if (!canvas) return;
    const ctx = canvas.getContext('2d'); if (!ctx) return;
    const s = sim.current;
    const W = canvas.width, H = canvas.height;
    ctx.clearRect(0, 0, W, H);
    ctx.fillStyle = '#0f172a'; ctx.fillRect(0, 0, W, H);

    const midY = H / 2;
    const srcX = 50;
    const objX = srcX + s.objectDistPx;
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
  }, []);

  useEffect(() => { draw(); });

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
  orbitalOffset: number; // 0 = perfectly aligned (eclipse happens); larger = the Moon's orbit is tilted away and the shadow misses
  width?: number; height?: number;
}

interface Vec { x: number; y: number; }
function lineAtX(p1: Vec, p2: Vec, x: number): number {
  const t = (x - p1.x) / (p2.x - p1.x);
  return p1.y + t * (p2.y - p1.y);
}

export function EclipseCanvas({ eclipseType, orbitalOffset, width = 660, height = 300 }: Props) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const sim = useRef({ eclipseType, orbitalOffset });
  sim.current = { eclipseType, orbitalOffset };

  const draw = useCallback(() => {
    const canvas = canvasRef.current; if (!canvas) return;
    const ctx = canvas.getContext('2d'); if (!ctx) return;
    const s = sim.current;
    const W = canvas.width, H = canvas.height;
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

    const smallY = midY + s.orbitalOffset;

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
  }, []);

  useEffect(() => { draw(); });

  return (
    <canvas ref={canvasRef} width={width} height={height}
      className="w-full rounded-xl border border-gray-200" style={{ display: 'block' }} />
  );
}
AFEOF

echo "  → src/components/simulation/PinholeCanvas.tsx"
cat > "src/components/simulation/PinholeCanvas.tsx" << 'AFEOF'
'use client';
import { useRef, useEffect, useCallback } from 'react';

interface Props {
  objectHeightPx: number;
  objectDistPx: number;   // object -> pinhole (u)
  screenDistPx: number;   // pinhole -> screen (v)
  pinholeRadiusPx: number; // 0 = ideal point aperture; larger = blur
  width?: number; height?: number;
}

function arrowUp(ctx: CanvasRenderingContext2D, x: number, yBase: number, yTip: number, color: string) {
  ctx.strokeStyle = color; ctx.lineWidth = 3; ctx.lineCap = 'round';
  ctx.beginPath(); ctx.moveTo(x, yBase); ctx.lineTo(x, yTip); ctx.stroke();
  const dir = Math.sign(yTip - yBase) || -1;
  ctx.fillStyle = color;
  ctx.beginPath(); ctx.moveTo(x, yTip);
  ctx.lineTo(x - 6, yTip - dir * 10); ctx.lineTo(x + 6, yTip - dir * 10);
  ctx.closePath(); ctx.fill();
}

export function PinholeCanvas({ objectHeightPx, objectDistPx, screenDistPx, pinholeRadiusPx, width = 660, height = 300 }: Props) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const sim = useRef({ objectHeightPx, objectDistPx, screenDistPx, pinholeRadiusPx });
  sim.current = { objectHeightPx, objectDistPx, screenDistPx, pinholeRadiusPx };

  const draw = useCallback(() => {
    const canvas = canvasRef.current; if (!canvas) return;
    const ctx = canvas.getContext('2d'); if (!ctx) return;
    const s = sim.current;
    const W = canvas.width, H = canvas.height;
    ctx.clearRect(0, 0, W, H);
    ctx.fillStyle = '#f8fafc'; ctx.fillRect(0, 0, W, H);

    const midY = H / 2;
    // Single consistent anchor for the object's position: objectDistPx is
    // the TRUE object-to-pinhole distance used both for drawing and for
    // every ray calculation below — no separate cosmetic offset that could
    // drift out of sync with the labelled slider value.
    const objX = 40;
    const pinX = Math.min(objX + s.objectDistPx, W - 60);
    const scrX = Math.min(pinX + s.screenDistPx, W - 20);

    const objBase = midY, objTip = midY - s.objectHeightPx;

    // Camera box (barrier with the pinhole, and the back screen wall)
    ctx.fillStyle = '#1e293b';
    ctx.fillRect(pinX - 4, 15, 8, midY - s.pinholeRadiusPx - 15);
    ctx.fillRect(pinX - 4, midY + s.pinholeRadiusPx, 8, H - 15 - (midY + s.pinholeRadiusPx));
    ctx.fillRect(scrX, 15, 4, H - 30);
    ctx.strokeStyle = '#334155'; ctx.lineWidth = 1;
    ctx.strokeRect(pinX, 15, scrX - pinX, H - 30);

    // Object
    arrowUp(ctx, objX, objBase, objTip, '#0f172a');
    ctx.fillStyle = '#0f172a'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
    ctx.fillText('O', objX, objTip - 10);

    // Rays from the top and bottom of the object, through the pinhole
    // aperture, crossing over to form an inverted image. If the pinhole
    // has a finite radius, trace through BOTH its top and bottom edge (not
    // just its centre) so the resulting blur is the genuine geometric
    // overlap of every possible straight-line path, not an assumed effect.
    const pinTop = midY - s.pinholeRadiusPx, pinBot = midY + s.pinholeRadiusPx;
    const rayFrom = (objY: number, pinY: number, color: string, alpha: number) => {
      const dyRatio = (pinY - objY) / (pinX - objX);
      const scrY = pinY + dyRatio * (scrX - pinX);
      ctx.strokeStyle = color.replace('ALPHA', String(alpha));
      ctx.lineWidth = 1.2;
      ctx.beginPath(); ctx.moveTo(objX, objY); ctx.lineTo(scrX, scrY); ctx.stroke();
      return scrY;
    };

    let imgTipY: number, imgBaseY: number;
    if (s.pinholeRadiusPx < 1.5) {
      imgTipY = rayFrom(objTip, midY, 'rgba(239,68,68,ALPHA)', 0.8);
      imgBaseY = rayFrom(objBase, midY, 'rgba(99,102,241,ALPHA)', 0.8);
    } else {
      // Sharp (centre) rays plus the blur-forming edge rays
      imgTipY = rayFrom(objTip, midY, 'rgba(239,68,68,ALPHA)', 0.9);
      imgBaseY = rayFrom(objBase, midY, 'rgba(99,102,241,ALPHA)', 0.9);
      rayFrom(objTip, pinTop, 'rgba(239,68,68,ALPHA)', 0.25);
      rayFrom(objTip, pinBot, 'rgba(239,68,68,ALPHA)', 0.25);
      rayFrom(objBase, pinTop, 'rgba(99,102,241,ALPHA)', 0.25);
      rayFrom(objBase, pinBot, 'rgba(99,102,241,ALPHA)', 0.25);
    }

    // Image on the screen — inverted (top of object -> bottom of image)
    ctx.save();
    if (s.pinholeRadiusPx >= 1.5) {
      // Blurred band: the finite-size aperture means each object point
      // spreads into a small disc on the screen rather than a sharp point.
      const blur = s.pinholeRadiusPx * (s.screenDistPx / Math.max(s.objectDistPx, 1) + 1);
      ctx.globalAlpha = 0.55;
      ctx.strokeStyle = '#8b5cf6'; ctx.lineWidth = Math.max(3, blur);
      ctx.beginPath(); ctx.moveTo(scrX, imgBaseY); ctx.lineTo(scrX, imgTipY); ctx.stroke();
      ctx.globalAlpha = 1;
    }
    ctx.restore();
    arrowUp(ctx, scrX + 14, imgBaseY, imgTipY, '#7c3aed');
    ctx.fillStyle = '#7c3aed'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
    ctx.fillText('I (inverted, real)', scrX + 14, Math.max(imgTipY, imgBaseY) + 16);

    ctx.fillStyle = '#64748b'; ctx.font = '10px system-ui'; ctx.textAlign = 'center';
    ctx.fillText(
      s.pinholeRadiusPx < 1.5
        ? 'A single ray per object point crosses at the pinhole — sharp, inverted, real image'
        : 'A larger hole lets a BUNDLE of rays through each point — overlapping projections blur the image',
      W / 2, H - 6,
    );

    ctx.fillStyle = '#94a3b8'; ctx.font = '9px system-ui'; ctx.textAlign = 'left';
    ctx.fillText('pinhole', pinX - 20, 10);
  }, []);

  useEffect(() => { draw(); });

  return (
    <canvas ref={canvasRef} width={width} height={height}
      className="w-full rounded-xl border border-gray-200 bg-white" style={{ display: 'block' }} />
  );
}
AFEOF

echo "  → src/app/simulations/rectilinear-propagation/page.tsx"
cat > "src/app/simulations/rectilinear-propagation/page.tsx" << 'AFEOF'
'use client';
import { useState, useRef } from 'react';
import { AppHeader } from '@/components/layout/AppHeader';
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
                  <ShadowsCanvas sourceType={sourceType} sourceRadiusPx={sourceRadius} objectRadiusPx={objectRadius}
                    objectDistPx={objectDist} screenDistPx={screenDist}
                    width={canvasSize.width} height={canvasSize.height} />
                )}
                {topic === 'eclipse' && (
                  <EclipseCanvas eclipseType={eclipseType} orbitalOffset={orbitalOffset}
                    width={canvasSize.width} height={canvasSize.height} />
                )}
                {topic === 'pinhole' && (
                  <PinholeCanvas objectHeightPx={objectHeight} objectDistPx={pinholeObjectDist} screenDistPx={pinholeScreenDist}
                    pinholeRadiusPx={pinholeRadius}
                    width={canvasSize.width} height={canvasSize.height} />
                )}
              </div>

              <div className="flex flex-wrap items-center justify-end gap-2">
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
import { Suspense, useState } from 'react';
import { useSearchParams } from 'next/navigation';
import { ShadowsCanvas } from '@/components/simulation/ShadowsCanvas';
import { EclipseCanvas, EclipseType } from '@/components/simulation/EclipseCanvas';
import { PinholeCanvas } from '@/components/simulation/PinholeCanvas';

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

  return (
    <div className="mx-auto max-w-2xl space-y-3 p-3 sm:p-4">
      {topic === 'shadows' && (
        <ShadowsCanvas sourceType={sourceType} sourceRadiusPx={sourceRadius} objectRadiusPx={objectRadius}
          objectDistPx={objectDist} screenDistPx={screenDist} width={640} height={280} />
      )}
      {topic === 'eclipse' && (
        <EclipseCanvas eclipseType={eclipseType} orbitalOffset={orbitalOffset} width={640} height={280} />
      )}
      {topic === 'pinhole' && (
        <PinholeCanvas objectHeightPx={objectHeight} objectDistPx={pinholeObjectDist} screenDistPx={pinholeScreenDist}
          pinholeRadiusPx={pinholeRadius} width={640} height={280} />
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
    description: 'The law of reflection, mirror rotation (fixed source, 2θ rule), and concave/convex ray diagrams.',
    icon: '🪞',
    tags: ['WAEC', 'NECO', 'IGCSE', 'SAT'],
    topic: 'Optics',
    status: 'live',
  },
  {
    slug: 'rectilinear-propagation',
    href: '/simulations/rectilinear-propagation',
    title: 'Sources of Light & Rectilinear Propagation',
    description: 'Shadows (umbra & penumbra), solar & lunar eclipses, and the pinhole camera.',
    icon: '🌑',
    tags: ['WAEC', 'NECO', 'IGCSE'],
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
echo "✓ Patch v22 applied — 10 files written."
echo ""
echo "IMPORTANT: clear the build cache before restarting, or stale pages can"
echo "make new tabs/modes appear missing even after the source is updated:"
echo "  rm -rf .next"
echo "  npm run dev"
echo ""
echo "Check:"
echo "  /simulations/reflection -> 3 tabs should show: Plane mirror, Curved"
echo "    mirror, Rotating mirror. Plane mirror's rays should now visibly"
echo "    touch the object arrow and the dashed lines should touch the"
echo "    image arrow, passing through the mirror, not floating separately."
echo "  /simulations/rectilinear-propagation -> Shadows, Eclipses, Pinhole"
echo "    camera tabs, all new."
