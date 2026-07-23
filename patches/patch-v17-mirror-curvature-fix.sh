#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
# A-Factor STEM Studio — patch v17: fix inverted mirror curvature + wrong-side
# focal markers in the refraction/optics module
#
#   MIRROR CURVATURE WAS BACKWARDS. Traced the quadratic bezier the mirror
#   arc is drawn with to its closed form (x(t) = cx + bow·(1-2t)²) and
#   proved numerically: for "concave" (converging=true), the code set
#   bow=+26, which put the mirror's pole CLOSER to the object than its
#   edges — a shape that bulges toward the viewer, i.e. actually CONVEX.
#   The convex case was exactly as backwards the other way. Concave and
#   convex mirrors were drawn as each other, which is why "it doesn't make
#   sense at all" — the reflecting surface's coating side, the direction
#   it opens, none of it matched the labels. Fixed by flipping the sign
#   (bow = converging ? -26 : 26) and verified numerically at seven sample
#   heights that both shapes now open the correct direction relative to
#   the object.
#
#   Also fixed the silvered-coating hatching, which was drawn as a straight
#   line offset from a single fixed x (the endpoint's x only) rather than
#   following the curve — it now traces the same closed-form curve at each
#   sampled height, consistently offset to the side away from the object.
#
#   F/2F FOCAL MARKERS WERE DRAWN ON BOTH SIDES FOR MIRRORS. That's correct
#   for lenses (light passes through, so there's a real focal point on each
#   side) but wrong for a mirror — nothing physically exists "behind" a
#   mirror. Mirrors now only show F/2F on the object's side.
#
# Run from the af2s project root (Git Bash):   bash patches/patch-v17-mirror-curvature-fix.sh
# ══════════════════════════════════════════════════════════════════════════════
set -euo pipefail

if [ ! -f "package.json" ]; then
  echo "✗ Run this from the af2s project root (package.json not found)." >&2
  exit 1
fi

mkdir -p "src/components/simulation"

echo "  → src/components/simulation/OpticsCanvas.tsx"
cat > "src/components/simulation/OpticsCanvas.tsx" << 'AFEOF'
'use client';
import { useRef, useEffect, useCallback } from 'react';
import { snellTheta2, criticalAngle, thinLensImage } from '@/lib/physics/optics';

export type OpticsMode = 'snell' | 'lens' | 'mirror';

interface Props {
  mode: OpticsMode;
  // snell
  n1: number; n2: number; theta1: number;
  // lens / mirror (cm as display units)
  focal: number;          // |f| in cm
  objectDist: number;     // u in cm
  converging: boolean;    // true: convex lens / concave mirror
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
    if (s.mode === 'lens') {
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
    } else {
      // Mirror arc. The pole (on-axis point, used for all u/v/f distances)
      // sits at a FIXED x = cx regardless of curvature — only the top/bottom
      // edges bow toward or away from the object, exactly like a real
      // spherical mirror surface.
      //   Concave (converging): the reflecting surface curves AWAY from the
      //     object at the pole — edges reach OUT toward the object, like a
      //     satellite dish or the inside of a bowl facing the object.
      //   Convex (diverging): the surface bulges TOWARD the object at the
      //     pole, edges recede away — like the back of a spoon.
      const bow = s.converging ? -26 : 26; // edge offset from the pole (edges at cx+bow)
      ctx.strokeStyle = '#6366f1'; ctx.lineWidth = 4;
      ctx.beginPath();
      ctx.moveTo(cx + bow, axisY - 80);
      ctx.quadraticCurveTo(cx - bow, axisY, cx + bow, axisY + 80);
      ctx.stroke();
      // Silvered coating on the BACK of the glass — traces the same curve
      // (x(t) = cx + bow·(1−2t)², the closed form of the quadratic bezier
      // above) offset slightly further from the object, rather than a
      // straight line at a single fixed x.
      ctx.lineWidth = 1; ctx.strokeStyle = '#c7d2fe';
      for (let yOff = -70; yOff <= 70; yOff += 14) {
        const tParam = (yOff + 80) / 160;
        const curveX = cx + bow * Math.pow(1 - 2 * tParam, 2);
        ctx.beginPath();
        ctx.moveTo(curveX + 3, axisY + yOff);
        ctx.lineTo(curveX + 12, axisY + yOff - 8);
        ctx.stroke();
      }
    }
    ctx.restore();

    // Focal points. A lens has two physical focal points (light can enter
    // from either side); a mirror has only ONE — nothing physically exists
    // "behind" a mirror, so F/2F only make sense on the object's side.
    const fPx = s.focal * scale;
    ctx.fillStyle = '#f59e0b'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
    const focalMarks: [number, string][] = s.mode === 'mirror'
      ? [[-fPx, 'F'], [-2 * fPx, '2F']]
      : [[-fPx, 'F'], [fPx, 'F'], [-2 * fPx, '2F'], [2 * fPx, '2F']];
    focalMarks.forEach(([dx, lab]) => {
      const x = cx + dx;
      if (x < 10 || x > W - 10) return;
      ctx.beginPath(); ctx.arc(x, axisY, 3, 0, Math.PI * 2); ctx.fill();
      ctx.fillText(lab, x, axisY + 16);
    });

    // Object
    const objX = cx - u * scale;
    objectArrow(ctx, objX, axisY, axisY - hObj, '#0f172a', 'O');

    // Image
    const sideSign = s.mode === 'mirror' ? -1 : 1; // real image forms LEFT of a mirror
    if (!img.atInfinity) {
      const imgX = img.real ? cx + sideSign * img.v * scale : cx - Math.abs(img.v) * scale * (s.mode === 'mirror' ? -1 : 1);
      // Simpler + convention-correct: real → opposite side (lens) / same side (mirror);
      // virtual → same side as object (lens) / behind mirror.
      const ix = s.mode === 'lens'
        ? (img.real ? cx + img.v * scale : cx - Math.abs(img.v) * scale)
        : (img.real ? cx - img.v * scale : cx + Math.abs(img.v) * scale);
      void imgX;
      const hImg = hObj * img.m * (img.inverted ? 1 : -1); // inverted draws below? tip direction:
      const tipY = img.inverted ? axisY + hObj * img.m : axisY - hObj * img.m;
      if (ix > -40 && ix < W + 40) {
        objectArrow(ctx, ix, axisY, tipY, img.real ? '#10b981' : '#8b5cf6', img.real ? 'I (real)' : 'I (virtual)');
      }
      void hImg;

      // Principal rays from object tip
      const tip: [number, number] = [objX, axisY - hObj];
      const dev = cx;
      ctx.save();
      // Ray 1: parallel to axis → through/away-from F after device
      arrow(ctx, tip[0], tip[1], dev, tip[1], '#ef4444', 1.6, 0.5);
      // after device it must pass through the image tip
      const drawTo = (fromX: number, fromY: number, toX: number, toY: number, color: string, dashed = false) => {
        ctx.save(); if (dashed) ctx.setLineDash([5, 4]);
        ctx.strokeStyle = color; ctx.lineWidth = 1.6;
        // extend beyond the target
        const ang = Math.atan2(toY - fromY, toX - fromX);
        const ext = 60;
        ctx.beginPath(); ctx.moveTo(fromX, fromY);
        ctx.lineTo(toX + Math.cos(ang) * ext, toY + Math.sin(ang) * ext);
        ctx.stroke(); ctx.restore();
      };
      drawTo(dev, tip[1], ix, tipY, '#ef4444', !img.real);
      // Ray 2: through the centre (lens) — undeviated; mirror: to pole, reflects symmetric
      if (s.mode === 'lens') {
        drawTo(tip[0], tip[1], cx, axisY, '#3b82f6');
        drawTo(cx, axisY, ix, tipY, '#3b82f6', !img.real);
      } else {
        arrow(ctx, tip[0], tip[1], cx, axisY, '#3b82f6', 1.6, 0.5);
        drawTo(cx, axisY, ix, tipY, '#3b82f6', !img.real);
      }
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

echo ""
echo "✓ Patch v17 applied."
echo ""
echo "Next steps:"
echo "  rm -rf .next"
echo "  npm run dev"
echo ""
echo "Check: /simulations/refraction -> Mirrors tab. Toggle Concave/Convex —"
echo "the reflecting surface should now open toward the object for concave"
echo "(like a satellite dish) and bulge toward the object for convex (like"
echo "the back of a spoon), with F/2F markers only on the object's side."
