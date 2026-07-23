#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
# A-Factor STEM Studio — patch v19: split Reflection out of the Refraction
# module — mirrors reflect, they don't refract
#
#   The "Refraction & lenses" page had a "Mirrors" tab bundled in alongside
#   Snell's law and lenses. That's a real category error: refraction is
#   light bending as it crosses a boundary between media; a mirror doesn't
#   refract anything, it reflects. Teaching "mirror" as a sub-topic of
#   "refraction" mislabels the underlying physics for students.
#
#   Split cleanly into two separate modules:
#
#   REFRACTION (trimmed) — now only Snell's law + lenses, both genuinely
#   refraction phenomena. OpticsCanvas's OpticsMode is now 'snell' | 'lens'
#   only; all mirror-drawing logic, teacher notes, and exercises about
#   mirrors were removed from this page.
#
#   REFLECTION (new) — two modes:
#     - Plane mirror: the actual law of reflection (∠i = ∠r, both measured
#       from the normal) with an animated incident/reflected ray pair, PLUS
#       image formation (virtual, upright, same size, same distance, and
#       LATERALLY INVERTED — shown with a small flag marker that visibly
#       flips sides, not just asserted in text). This didn't exist
#       anywhere in the app before — the old module went straight to
#       curved mirrors without ever covering the fundamental law.
#     - Curved mirror: the concave/convex ray-diagram logic, moved over
#       from OpticsCanvas essentially unchanged (already fixed for the
#       curvature-direction bug in the previous patch).
#   Existing mirror teacher notes and exercises were moved here rather than
#   deleted, since they're legitimately about reflection.
#
#   Added a new embed route (/embed/reflection) and a hub card. The
#   simulations hub now correctly lists "Refraction & lenses" and
#   "Reflection" as two separate Optics entries.
#
# Run from the af2s project root (Git Bash):   bash patches/patch-v19-split-reflection-module.sh
# ══════════════════════════════════════════════════════════════════════════════
set -euo pipefail

if [ ! -f "package.json" ]; then
  echo "✗ Run this from the af2s project root (package.json not found)." >&2
  exit 1
fi

echo "── A-Factor patch v19: split Reflection out of Refraction ──"
mkdir -p "src/app/embed/optics" "src/app/embed/reflection" "src/app/simulations" "src/app/simulations/reflection" "src/app/simulations/refraction" "src/components/simulation"

echo "  → src/components/simulation/OpticsCanvas.tsx"
cat > "src/components/simulation/OpticsCanvas.tsx" << 'AFEOF'
'use client';
import { useRef, useEffect, useCallback } from 'react';
import { snellTheta2, criticalAngle, thinLensImage } from '@/lib/physics/optics';

export type OpticsMode = 'snell' | 'lens';

interface Props {
  mode: OpticsMode;
  // snell
  n1: number; n2: number; theta1: number;
  // lens (cm as display units)
  focal: number;          // |f| in cm
  objectDist: number;     // u in cm
  converging: boolean;    // true = convex (converging), false = concave (diverging)
  width?: number; height?: number;
}

function arrow(ctx: CanvasRenderingContext2D, x1: number, y1: number, x2: number, y2: number, color: string, lw = 2, headAt = 0.55) {
  ctx.save();
  ctx.strokeStyle = color; ctx.lineWidth = lw;
  ctx.beginPath(); ctx.moveTo(x1, y1); ctx.lineTo(x2, y2); ctx.stroke();
  // Direction arrowhead mid-ray
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

export function OpticsCanvas({ mode, n1, n2, theta1, focal, objectDist, converging, width = 660, height = 320 }: Props) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const sim = useRef({ mode, n1, n2, theta1, focal, objectDist, converging });
  sim.current = { mode, n1, n2, theta1, focal, objectDist, converging };

  const draw = useCallback(() => {
    const canvas = canvasRef.current; if (!canvas) return;
    const ctx = canvas.getContext('2d'); if (!ctx) return;
    const s = sim.current;
    const W = canvas.width, H = canvas.height;
    ctx.clearRect(0, 0, W, H);

    if (s.mode === 'snell') {
      const midY = H / 2, cx = W / 2;
      // Media
      ctx.fillStyle = 'rgba(219,234,254,0.6)'; ctx.fillRect(0, 0, W, midY);
      ctx.fillStyle = 'rgba(165,180,252,0.35)'; ctx.fillRect(0, midY, W, H - midY);
      ctx.strokeStyle = '#64748b'; ctx.lineWidth = 2;
      ctx.beginPath(); ctx.moveTo(0, midY); ctx.lineTo(W, midY); ctx.stroke();
      // Normal
      ctx.setLineDash([5, 5]); ctx.strokeStyle = '#94a3b8'; ctx.lineWidth = 1;
      ctx.beginPath(); ctx.moveTo(cx, 20); ctx.lineTo(cx, H - 20); ctx.stroke(); ctx.setLineDash([]);
      ctx.fillStyle = '#475569'; ctx.font = 'bold 11px system-ui'; ctx.textAlign = 'left';
      ctx.fillText(`n₁ = ${s.n1}`, 12, 22);
      ctx.fillText(`n₂ = ${s.n2}`, 12, H - 12);
      ctx.fillStyle = '#94a3b8'; ctx.font = '9px system-ui';
      ctx.fillText('normal', cx + 6, 26);

      const t1 = s.theta1 * Math.PI / 180;
      const rayLen = Math.min(cx, midY) - 30;
      // Incident ray (arrives at the boundary point)
      const ix = cx - Math.sin(t1) * rayLen, iy = midY - Math.cos(t1) * rayLen;
      arrow(ctx, ix, iy, cx, midY, '#6366f1', 2.5);
      ctx.fillStyle = '#4338ca'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
      ctx.fillText(`θ₁=${s.theta1}°`, cx - 44, midY - 22);

      const t2deg = snellTheta2(s.n1, s.n2, s.theta1);
      if (t2deg === null) {
        // Total internal reflection: all light reflects at θ1
        const rx = cx + Math.sin(t1) * rayLen, ry = midY - Math.cos(t1) * rayLen;
        arrow(ctx, cx, midY, rx, ry, '#ef4444', 2.5);
        ctx.fillStyle = '#ef4444'; ctx.font = 'bold 11px system-ui'; ctx.textAlign = 'center';
        const cc = criticalAngle(s.n1, s.n2);
        ctx.fillText(`TOTAL INTERNAL REFLECTION  (θ₁ > θc = ${cc?.toFixed(1)}°)`, cx, H - 30);
      } else {
        const t2 = t2deg * Math.PI / 180;
        // Refracted ray
        const fx = cx + Math.sin(t2) * rayLen, fy = midY + Math.cos(t2) * rayLen;
        arrow(ctx, cx, midY, fx, fy, '#10b981', 2.5);
        ctx.fillStyle = '#059669'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
        ctx.fillText(`θ₂=${t2deg.toFixed(1)}°`, cx + 48, midY + 30);
        // Partial (weak) reflection
        const rx = cx + Math.sin(t1) * rayLen * 0.6, ry = midY - Math.cos(t1) * rayLen * 0.6;
        ctx.save(); ctx.globalAlpha = 0.35;
        arrow(ctx, cx, midY, rx, ry, '#ef4444', 1.5);
        ctx.restore();
      }
      return;
    }

    // ── Lens / Mirror ray diagram ─────────────────────────────────────────────
    const axisY = H / 2, cx = W / 2;
    const f = s.converging ? s.focal : -s.focal;   // real-is-positive
    const u = s.objectDist;
    const img = thinLensImage(u, f);
    const scale = Math.min(3.2, (W / 2 - 30) / Math.max(u, Math.abs(img.atInfinity ? u : img.v), 2 * s.focal));
    const hObj = 44; // object height px

    // Principal axis
    ctx.strokeStyle = '#94a3b8'; ctx.lineWidth = 1;
    ctx.beginPath(); ctx.moveTo(0, axisY); ctx.lineTo(W, axisY); ctx.stroke();

    // Device
    ctx.save();
    ctx.strokeStyle = '#6366f1'; ctx.lineWidth = 3; ctx.lineCap = 'round';
    ctx.beginPath(); ctx.moveTo(cx, axisY - 78); ctx.lineTo(cx, axisY + 78); ctx.stroke();
    // Arrowheads: outward = converging (convex), inward = diverging (concave)
    const d = s.converging ? 1 : -1;
    [[-78, -1], [78, 1]].forEach(([yo, sgn]) => {
      ctx.fillStyle = '#6366f1';
      ctx.beginPath();
      ctx.moveTo(cx, axisY + yo);
      ctx.lineTo(cx - 8, axisY + yo - sgn * d * 10);
      ctx.lineTo(cx + 8, axisY + yo - sgn * d * 10);
      ctx.closePath(); ctx.fill();
    });
    ctx.restore();

    // Focal points — a lens has two physical focal points, since light can
    // enter from either side.
    const fPx = s.focal * scale;
    ctx.fillStyle = '#f59e0b'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
    ([[-fPx, 'F'], [fPx, 'F'], [-2 * fPx, '2F'], [2 * fPx, '2F']] as [number, string][]).forEach(([dx, lab]) => {
      const x = cx + dx;
      if (x < 10 || x > W - 10) return;
      ctx.beginPath(); ctx.arc(x, axisY, 3, 0, Math.PI * 2); ctx.fill();
      ctx.fillText(lab, x, axisY + 16);
    });

    // Object
    const objX = cx - u * scale;
    objectArrow(ctx, objX, axisY, axisY - hObj, '#0f172a', 'O');

    // Image — real forms on the opposite side (light passes through);
    // virtual forms on the same side as the object.
    if (!img.atInfinity) {
      const ix = img.real ? cx + img.v * scale : cx - Math.abs(img.v) * scale;
      const tipY = img.inverted ? axisY + hObj * img.m : axisY - hObj * img.m;
      if (ix > -40 && ix < W + 40) {
        objectArrow(ctx, ix, axisY, tipY, img.real ? '#10b981' : '#8b5cf6', img.real ? 'I (real)' : 'I (virtual)');
      }

      // Principal rays from object tip
      const tip: [number, number] = [objX, axisY - hObj];
      const dev = cx;
      ctx.save();
      // Ray 1: parallel to axis → through/away-from F after the lens
      arrow(ctx, tip[0], tip[1], dev, tip[1], '#ef4444', 1.6, 0.5);
      const drawTo = (fromX: number, fromY: number, toX: number, toY: number, color: string, dashed = false) => {
        ctx.save(); if (dashed) ctx.setLineDash([5, 4]);
        ctx.strokeStyle = color; ctx.lineWidth = 1.6;
        const ang = Math.atan2(toY - fromY, toX - fromX);
        const ext = 60;
        ctx.beginPath(); ctx.moveTo(fromX, fromY);
        ctx.lineTo(toX + Math.cos(ang) * ext, toY + Math.sin(ang) * ext);
        ctx.stroke(); ctx.restore();
      };
      drawTo(dev, tip[1], ix, tipY, '#ef4444', !img.real);
      // Ray 2: through the optical centre — undeviated
      drawTo(tip[0], tip[1], cx, axisY, '#3b82f6');
      drawTo(cx, axisY, ix, tipY, '#3b82f6', !img.real);
      ctx.restore();
    } else {
      ctx.fillStyle = '#64748b'; ctx.font = 'bold 11px system-ui'; ctx.textAlign = 'center';
      ctx.fillText('Object at F — rays emerge parallel, image at infinity', cx, 26);
    }

    // Caption
    ctx.fillStyle = '#64748b'; ctx.font = '10px system-ui'; ctx.textAlign = 'left';
    const nature = img.atInfinity ? 'at infinity'
      : `${img.real ? 'real' : 'virtual'}, ${img.inverted ? 'inverted' : 'upright'}, ${img.m > 1 ? 'magnified' : img.m < 1 ? 'diminished' : 'same size'}`;
    ctx.fillText(`u=${u}cm  f=${f}cm  →  v=${img.atInfinity ? '∞' : Math.abs(img.v).toFixed(1) + 'cm'}  m=${img.atInfinity ? '∞' : img.m.toFixed(2)}  (${nature})`, 8, H - 8);
  }, []);

  useEffect(() => { draw(); });

  return (
    <canvas ref={canvasRef} width={width} height={height}
      className="w-full rounded-xl border border-gray-200 bg-white" style={{ display: 'block' }} />
  );
}
AFEOF

echo "  → src/components/simulation/ReflectionCanvas.tsx"
cat > "src/components/simulation/ReflectionCanvas.tsx" << 'AFEOF'
'use client';
import { useRef, useEffect, useCallback } from 'react';
import { thinLensImage } from '@/lib/physics/optics';

export type ReflectionMode = 'plane' | 'curved';

interface Props {
  mode: ReflectionMode;
  // plane
  incidenceAngle: number; // degrees from the normal
  // curved (cm as display units)
  focal: number;          // |f| in cm
  objectDist: number;     // u in cm
  converging: boolean;    // true = concave (converging), false = convex (diverging)
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

export function ReflectionCanvas({ mode, incidenceAngle, focal, objectDist, converging, width = 660, height = 320 }: Props) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const sim = useRef({ mode, incidenceAngle, focal, objectDist, converging });
  sim.current = { mode, incidenceAngle, focal, objectDist, converging };

  const draw = useCallback(() => {
    const canvas = canvasRef.current; if (!canvas) return;
    const ctx = canvas.getContext('2d'); if (!ctx) return;
    const s = sim.current;
    const W = canvas.width, H = canvas.height;
    ctx.clearRect(0, 0, W, H);

    if (s.mode === 'plane') {
      const cx = W * 0.58, midY = H / 2;
      const mirrorTop = 30, mirrorBottom = H - 90;

      // Mirror (vertical line, silvered back hatched to the right)
      ctx.strokeStyle = '#334155'; ctx.lineWidth = 3;
      ctx.beginPath(); ctx.moveTo(cx, mirrorTop); ctx.lineTo(cx, mirrorBottom); ctx.stroke();
      ctx.strokeStyle = '#cbd5e1'; ctx.lineWidth = 1;
      for (let y = mirrorTop; y <= mirrorBottom; y += 12) {
        ctx.beginPath(); ctx.moveTo(cx + 2, y); ctx.lineTo(cx + 10, y - 7); ctx.stroke();
      }

      // Normal (dashed, perpendicular to mirror at the point of incidence)
      const poi = { x: cx, y: midY };
      ctx.setLineDash([5, 5]); ctx.strokeStyle = '#94a3b8'; ctx.lineWidth = 1;
      ctx.beginPath(); ctx.moveTo(poi.x - 90, poi.y); ctx.lineTo(poi.x + 90, poi.y); ctx.stroke();
      ctx.setLineDash([]);
      ctx.fillStyle = '#94a3b8'; ctx.font = '9px system-ui'; ctx.textAlign = 'left';
      ctx.fillText('normal', poi.x + 92, poi.y + 3);

      // Incident and reflected rays — same angle from the normal, either
      // side, which IS the law of reflection made visible.
      const t = (s.incidenceAngle * Math.PI) / 180;
      const rayLen = 90;
      const ix = poi.x - Math.cos(t) * rayLen, iy = poi.y - Math.sin(t) * rayLen;
      arrow(ctx, ix, iy, poi.x, poi.y, '#6366f1', 2.5);
      const rx = poi.x - Math.cos(t) * rayLen, ry = poi.y + Math.sin(t) * rayLen;
      arrow(ctx, poi.x, poi.y, rx, ry, '#10b981', 2.5);
      ctx.fillStyle = '#4338ca'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
      ctx.fillText(`i=${s.incidenceAngle}°`, poi.x - 34, poi.y - 14);
      ctx.fillStyle = '#059669';
      ctx.fillText(`r=${s.incidenceAngle}°`, poi.x - 34, poi.y + 22);

      // Object in front of the mirror, and its virtual image the SAME
      // distance behind it — same size, upright, but laterally inverted
      // (the flag flips from right-pointing to left-pointing).
      const objDistPx = 130;
      const objX = cx - objDistPx, imgX = cx + objDistPx;
      const oy1 = H - 60, oy2 = H - 110;
      objectArrow(ctx, objX, oy1, oy2, '#0f172a', 'O');
      flag(ctx, objX, oy2 + 8, 1, '#0f172a');

      ctx.save(); ctx.setLineDash([5, 4]); ctx.globalAlpha = 0.75;
      objectArrow(ctx, imgX, oy1, oy2, '#8b5cf6', 'I (virtual)');
      ctx.restore();
      flag(ctx, imgX, oy2 + 8, -1, '#8b5cf6');

      // Sight lines showing how the eye "sees" the image behind the mirror
      const eyeX = W - 30, eyeY = H * 0.3;
      ctx.save(); ctx.setLineDash([3, 3]); ctx.strokeStyle = 'rgba(139,92,246,0.5)'; ctx.lineWidth = 1;
      [oy1, oy2].forEach(oy => {
        ctx.beginPath(); ctx.moveTo(imgX, oy); ctx.lineTo(eyeX, eyeY); ctx.stroke();
      });
      ctx.restore();
      ctx.fillStyle = '#a78bfa'; ctx.font = '14px system-ui'; ctx.textAlign = 'center';
      ctx.fillText('👁', eyeX, eyeY + 5);

      ctx.fillStyle = '#64748b'; ctx.font = '10px system-ui'; ctx.textAlign = 'left';
      ctx.fillText('Image: same size, same distance behind, upright, but LATERALLY INVERTED (the flag flips sides)', 8, H - 10);
      return;
    }

    // ── Curved mirror ray diagram ───────────────────────────────────────────
    const axisY = H / 2, cx = W / 2;
    const f = s.converging ? s.focal : -s.focal; // real-is-positive
    const u = s.objectDist;
    const img = thinLensImage(u, f);
    const scale = Math.min(3.2, (W / 2 - 30) / Math.max(u, Math.abs(img.atInfinity ? u : img.v), 2 * s.focal));
    const hObj = 44;

    ctx.strokeStyle = '#94a3b8'; ctx.lineWidth = 1;
    ctx.beginPath(); ctx.moveTo(0, axisY); ctx.lineTo(W, axisY); ctx.stroke();

    // Mirror arc. Pole (used for all u/v/f distances) sits at a fixed
    // x = cx; only the top/bottom edges bow toward or away from the object.
    //   Concave: reflecting surface curves AWAY from the object at the pole
    //     — edges reach out toward the object, like a satellite dish.
    //   Convex: surface bulges TOWARD the object at the pole, edges recede
    //     — like the back of a spoon.
    const bow = s.converging ? -26 : 26;
    ctx.save();
    ctx.strokeStyle = '#6366f1'; ctx.lineWidth = 4;
    ctx.beginPath();
    ctx.moveTo(cx + bow, axisY - 80);
    ctx.quadraticCurveTo(cx - bow, axisY, cx + bow, axisY + 80);
    ctx.stroke();
    // Silvered back — traces the curve's closed form x(t)=cx+bow(1-2t)^2.
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

    // Focal marker — a mirror only has ONE physical side.
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
      // Real image forms on the SAME side as the object (in front of the
      // mirror); virtual forms behind it.
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
  }, []);

  useEffect(() => { draw(); });

  return (
    <canvas ref={canvasRef} width={width} height={height}
      className="w-full rounded-xl border border-gray-200 bg-white" style={{ display: 'block' }} />
  );
}
AFEOF

echo "  → src/app/simulations/refraction/page.tsx"
cat > "src/app/simulations/refraction/page.tsx" << 'AFEOF'
'use client';
import { useState, useRef } from 'react';
import { AppHeader } from '@/components/layout/AppHeader';
import { OpticsCanvas, OpticsMode } from '@/components/simulation/OpticsCanvas';
import { EmbedButton } from '@/components/ui/EmbedButton';
import { snellTheta2, criticalAngle, thinLensImage, lensPower } from '@/lib/physics/optics';
import { useResponsiveCanvasSize } from '@/hooks/useResponsiveCanvasSize';

const CURRICULA = ['WAEC', 'NECO', 'IGCSE', 'SAT', 'JUPEB'];
const CC: Record<string, string> = {
  WAEC: 'bg-indigo-100 text-indigo-700', NECO: 'bg-pink-100 text-pink-700',
  IGCSE: 'bg-emerald-100 text-emerald-700', SAT: 'bg-orange-100 text-orange-700',
  JUPEB: 'bg-purple-100 text-purple-700',
};

const MODE_META: Record<OpticsMode, { title: string; icon: string; sub: string; eq: string }> = {
  snell:  { title: 'Refraction', icon: '💠', sub: 'Light crossing a boundary', eq: 'n₁ sinθ₁ = n₂ sinθ₂' },
  lens:   { title: 'Lenses',     icon: '🔍', sub: 'Convex & concave',          eq: '1/f = 1/u + 1/v' },
};

const PRESETS = [
  { label: 'Air → Glass', n1: 1.0, n2: 1.5 },
  { label: 'Air → Water', n1: 1.0, n2: 1.33 },
  { label: 'Glass → Air', n1: 1.5, n2: 1.0 },
  { label: 'Water → Air', n1: 1.33, n2: 1.0 },
  { label: 'Diamond → Air', n1: 2.42, n2: 1.0 },
];

const TEACHER_NOTES: Record<OpticsMode, string[]> = {
  snell: [
    'Into a DENSER medium (n₂ > n₁): light bends TOWARDS the normal. Into a less dense medium: away from it.',
    'The critical angle only exists going dense → less dense; sinθc = n₂/n₁.',
    'Beyond θc, ALL light reflects: total internal reflection — the basis of optical fibres and diamond sparkle.',
    'Refractive index n = c/v = sinθ₁/sinθ₂ = real depth / apparent depth (three exam definitions of the same thing).',
    'Diamond → air: θc ≈ 24.4° — tiny, which is why diamonds trap and bounce light so much.',
  ],
  lens: [
    'Real-is-positive convention: f > 0 for converging (convex), f < 0 for diverging (concave). WAEC/IGCSE mark schemes use this.',
    'Convex lens: object beyond 2F → diminished real image; between F and 2F → magnified real image; inside F → magnified virtual (magnifying glass).',
    'A concave lens ALWAYS gives a virtual, upright, diminished image regardless of object position.',
    'Two principal rays fix the image: parallel-to-axis (bends through F) and through the optical centre (undeviated).',
    'Lens power P = 1/f (f in metres), unit dioptre — opticians add powers of lenses in contact.',
  ],
};

const EXERCISES: Record<OpticsMode, { q: string; a: string }[]> = {
  snell: [
    { q: 'Light passes from air into glass (n=1.5) at 45°. Find the angle of refraction.', a: 'sinθ₂ = sin45°/1.5 = 0.707/1.5 = 0.471 → θ₂ = 28.1°.' },
    { q: 'Find the critical angle for water (n=1.33) to air.', a: 'sinθc = 1/1.33 = 0.752 → θc = 48.8°.' },
    { q: 'Light travels at 3×10⁸ m/s in air. Find its speed in glass of n=1.5.', a: 'v = c/n = 3×10⁸/1.5 = 2×10⁸ m/s.' },
  ],
  lens: [
    { q: 'An object 30cm from a convex lens of f=20cm. Find the image position and magnification.', a: '1/v = 1/20 − 1/30 = 1/60 → v = 60cm (real). m = v/u = 2 (magnified, inverted).' },
    { q: 'An object 10cm from a convex lens of f=15cm. Describe the image.', a: '1/v = 1/15 − 1/10 = −1/30 → v = −30cm: virtual, upright, m=3 — a magnifying glass.' },
    { q: 'Find the power of a converging lens with f = 25cm.', a: 'P = 1/f = 1/0.25 = +4 dioptres.' },
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

export default function RefractionPage() {
  const [mode, setMode] = useState<OpticsMode>('snell');
  const [openEx, setOpenEx] = useState<number | null>(null);
  const [activeCurricula, setActiveCurricula] = useState(['WAEC', 'IGCSE', 'SAT']);

  const [n1, setN1] = useState(1.0);
  const [n2, setN2] = useState(1.5);
  const [theta1, setTheta1] = useState(35);
  const [focal, setFocal] = useState(15);
  const [objectDist, setObjectDist] = useState(40);
  const [converging, setConverging] = useState(true);

  const t2 = snellTheta2(n1, n2, theta1);
  const critAng = criticalAngle(n1, n2);
  const f = converging ? focal : -focal;
  const img = thinLensImage(objectDist, f);

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
                <h1 className="text-lg font-semibold text-gray-900">Refraction &amp; lenses</h1>
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
            {(Object.keys(MODE_META) as OpticsMode[]).map(m => (
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
            {mode !== 'snell' && <span className="text-xs text-gray-400 ml-2">m = v/u · real is positive</span>}
          </div>

          <div className="grid grid-cols-1 lg:grid-cols-[1fr_220px] xl:grid-cols-[1fr_220px_260px] gap-4">
            <div className="space-y-3 min-w-0">
              <div ref={canvasBoxRef} className="rounded-2xl border border-gray-200 bg-white p-3 shadow-sm">
                <OpticsCanvas mode={mode} n1={n1} n2={n2} theta1={theta1}
                  focal={focal} objectDist={objectDist} converging={converging}
                  width={canvasSize.width} height={canvasSize.height} />
              </div>

              <div className="flex flex-wrap items-center justify-end gap-2">
                <EmbedButton path="/embed/optics"
                  title={`${MODE_META[mode].title} — A-Factor STEM Studio`}
                  params={{ mode, n1, n2, theta1, focal, u: objectDist, conv: converging ? 1 : 0 }} />
              </div>

              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm space-y-4">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide">Parameters</p>

                {mode === 'snell' && <>
                  <div className="flex flex-wrap gap-1.5">
                    {PRESETS.map(p => (
                      <button key={p.label} onClick={() => { setN1(p.n1); setN2(p.n2); }}
                        className={`rounded-full border px-2.5 py-2 text-[11px] font-medium transition ${
                          n1 === p.n1 && n2 === p.n2
                            ? 'border-indigo-300 bg-indigo-50 text-indigo-700'
                            : 'border-gray-200 bg-white text-gray-500 hover:border-indigo-200'
                        }`}>{p.label}</button>
                    ))}
                  </div>
                  <Slider label="Angle of incidence θ₁" unit="°" value={theta1} min={0} max={89} step={1} set={setTheta1} color="#6366f1"
                    note={critAng !== null ? `Critical angle θc = ${critAng.toFixed(1)}° — push θ₁ past it for TIR` : undefined} />
                  <Slider label="n₁ (top medium)" unit="" value={n1} min={1} max={2.5} step={0.01} set={setN1} color="#f59e0b" />
                  <Slider label="n₂ (bottom medium)" unit="" value={n2} min={1} max={2.5} step={0.01} set={setN2} color="#10b981" />
                </>}

                {mode !== 'snell' && <>
                  <div className="space-y-1.5">
                    <span className="text-xs text-gray-500">Type</span>
                    <div className="flex gap-2">
                      {([true, false] as const).map(c => (
                        <button key={String(c)} onClick={() => setConverging(c)}
                          className={`flex-1 rounded-lg border px-2 py-2 text-xs font-medium transition ${
                            converging === c ? 'border-indigo-300 bg-indigo-50 text-indigo-700' : 'border-gray-200 bg-white text-gray-500'
                          }`}>
                          {c ? 'Convex (converging)' : 'Concave (diverging)'}
                        </button>
                      ))}
                    </div>
                  </div>
                  <Slider label="Focal length |f|" unit="cm" value={focal} min={5} max={40} step={1} set={setFocal} color="#f59e0b" />
                  <Slider label="Object distance u" unit="cm" value={objectDist} min={5} max={90} step={1} set={setObjectDist} color="#6366f1"
                    note="Slide the object through 2F, F and inside F — watch the image flip" />
                </>}
              </div>
            </div>

            <div className="space-y-3">
              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide mb-3">Calculated</p>
                <div className="space-y-2">
                  {mode === 'snell' && <>
                    <StatRow label="Angle of refraction θ₂" value={t2 === null ? 'TIR' : t2.toFixed(1)} unit={t2 === null ? '' : '°'} color="text-indigo-600" />
                    <StatRow label="Critical angle θc" value={critAng === null ? '—' : critAng.toFixed(1)} unit={critAng === null ? '' : '°'} color="text-emerald-600" />
                    <StatRow label="n₂/n₁ ratio" value={(n2 / n1).toFixed(3)} unit="" color="text-amber-600" />
                    <StatRow label="Bends" value={t2 === null ? 'reflects fully' : n2 > n1 ? 'towards normal' : 'away from normal'} unit="" color="text-rose-500" />
                  </>}
                  {mode !== 'snell' && <>
                    <StatRow label="Image distance v" value={img.atInfinity ? '∞' : Math.abs(img.v).toFixed(1)} unit={img.atInfinity ? '' : 'cm'} color="text-indigo-600" />
                    <StatRow label="Magnification m" value={img.atInfinity ? '∞' : img.m.toFixed(2)} unit="×" color="text-emerald-600" />
                    <StatRow label="Nature" value={img.atInfinity ? 'at infinity' : img.real ? 'real' : 'virtual'} unit="" color="text-amber-600" />
                    <StatRow label="Orientation" value={img.atInfinity ? '—' : img.inverted ? 'inverted' : 'upright'} unit="" color="text-rose-500" />
                    {mode === 'lens' && (
                      <StatRow label="Power" value={lensPower(f / 100).toFixed(2)} unit="D" color="text-purple-600" />
                    )}
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

echo "  → src/app/simulations/reflection/page.tsx"
cat > "src/app/simulations/reflection/page.tsx" << 'AFEOF'
'use client';
import { useState, useRef } from 'react';
import { AppHeader } from '@/components/layout/AppHeader';
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
  plane:  { title: 'Plane mirror',  icon: '🪞', sub: 'The law of reflection',    eq: '∠i = ∠r' },
  curved: { title: 'Curved mirror', icon: '🛰️', sub: 'Concave & convex',        eq: '1/f = 1/u + 1/v' },
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

  const f = converging ? focal : -focal;
  const img = thinLensImage(objectDist, f);

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
                <ReflectionCanvas mode={mode} incidenceAngle={incidenceAngle}
                  focal={focal} objectDist={objectDist} converging={converging}
                  width={canvasSize.width} height={canvasSize.height} />
              </div>

              <div className="flex flex-wrap items-center justify-end gap-2">
                <EmbedButton path="/embed/reflection"
                  title={`${MODE_META[mode].title} — A-Factor STEM Studio`}
                  params={mode === 'plane' ? { mode, angle: incidenceAngle } : { mode, focal, u: objectDist, conv: converging ? 1 : 0 }} />
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

echo "  → src/app/embed/optics/page.tsx"
cat > "src/app/embed/optics/page.tsx" << 'AFEOF'
'use client';
import { Suspense, useState } from 'react';
import { useSearchParams } from 'next/navigation';
import { OpticsCanvas, OpticsMode } from '@/components/simulation/OpticsCanvas';

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

function OpticsEmbedInner() {
  const sp = useSearchParams();
  const mode = ((): OpticsMode => (sp.get('mode') === 'lens' ? 'lens' : 'snell'))();
  const showControls = sp.get('controls') !== '0';

  const [n1, setN1] = useState(() => num(sp, 'n1', 1.0, 1, 2.5));
  const [n2, setN2] = useState(() => num(sp, 'n2', 1.5, 1, 2.5));
  const [theta1, setTheta1] = useState(() => num(sp, 'theta1', 35, 0, 89));
  const [focal, setFocal] = useState(() => num(sp, 'focal', 15, 5, 40));
  const [objectDist, setObjectDist] = useState(() => num(sp, 'u', 40, 5, 90));
  const [converging, setConverging] = useState(() => sp.get('conv') !== '0');

  return (
    <div className="mx-auto max-w-2xl space-y-3 p-3 sm:p-4">
      <OpticsCanvas mode={mode} n1={n1} n2={n2} theta1={theta1}
        focal={focal} objectDist={objectDist} converging={converging}
        width={660} height={320} />
      {showControls && (
        <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
          <p className="mb-3 text-xs font-medium uppercase tracking-wide text-gray-400">Parameters</p>
          <div className="grid grid-cols-1 gap-x-6 gap-y-3 sm:grid-cols-2">
            {mode === 'snell' && <>
              <Slider label="Angle of incidence θ₁" unit="°" value={theta1} min={0} max={89} step={1} set={setTheta1} color="#6366f1" />
              <Slider label="n₁ (top)" unit="" value={n1} min={1} max={2.5} step={0.01} set={setN1} color="#f59e0b" />
              <Slider label="n₂ (bottom)" unit="" value={n2} min={1} max={2.5} step={0.01} set={setN2} color="#10b981" />
            </>}
            {mode !== 'snell' && <>
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
                      {c ? 'Converging' : 'Diverging'}
                    </button>
                  ))}
                </div>
              </div>
            </>}
          </div>
        </div>
      )}
      <PoweredBy />
    </div>
  );
}

export default function OpticsEmbedPage() {
  return (
    <Suspense fallback={<div className="p-8 text-center text-xs text-gray-400">Loading simulation…</div>}>
      <OpticsEmbedInner />
    </Suspense>
  );
}
AFEOF

echo "  → src/app/embed/reflection/page.tsx"
cat > "src/app/embed/reflection/page.tsx" << 'AFEOF'
'use client';
import { Suspense, useState } from 'react';
import { useSearchParams } from 'next/navigation';
import { ReflectionCanvas, ReflectionMode } from '@/components/simulation/ReflectionCanvas';

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
  const mode = ((): ReflectionMode => (sp.get('mode') === 'curved' ? 'curved' : 'plane'))();
  const showControls = sp.get('controls') !== '0';

  const [incidenceAngle, setIncidenceAngle] = useState(() => num(sp, 'angle', 35, 5, 80));
  const [focal, setFocal] = useState(() => num(sp, 'focal', 15, 5, 40));
  const [objectDist, setObjectDist] = useState(() => num(sp, 'u', 40, 5, 90));
  const [converging, setConverging] = useState(() => sp.get('conv') !== '0');

  return (
    <div className="mx-auto max-w-2xl space-y-3 p-3 sm:p-4">
      <ReflectionCanvas mode={mode} incidenceAngle={incidenceAngle}
        focal={focal} objectDist={objectDist} converging={converging}
        width={660} height={320} />
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
echo "✓ Patch v19 applied — 7 files written."
echo ""
echo "Next steps:"
echo "  rm -rf .next"
echo "  npm run dev"
echo ""
echo "Check:"
echo "  /simulations/refraction -- only Snell's law and Lenses tabs remain"
echo "  /simulations/reflection -- new page, Plane mirror + Curved mirror tabs"
echo "  /simulations -- hub shows both as separate Optics cards"
