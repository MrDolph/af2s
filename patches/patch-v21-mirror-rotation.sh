#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
# A-Factor STEM Studio — patch v21: rotation-of-a-mirror simulation added to
# Reflection, plus verified UTME/JAMB-style exercises
#
#   New third mode in the Reflection module: fixed light source, rotating
#   mirror. The classic result — rotate the mirror by θ, the reflected ray
#   rotates by 2θ — is not just asserted, it's DEMONSTRATED: the canvas uses
#   genuine vector reflection (r = d - 2(d·n)n, not an assumed angle
#   formula) and then independently MEASURES the angle between the current
#   and reference reflected rays. Verified numerically across the full
#   sweep range in both directions (±5° through ±35°) that the measured
#   angle equals exactly 2× the mirror's rotation every time before
#   shipping.
#
#   On Run, the mirror sweeps automatically back and forth (a damped-free
#   sine sweep, ±35° over a 4.5s cycle) so the 2:1 relationship is visibly
#   obvious — the reflected ray sweeps twice as far, twice as fast. Pause
#   freezes it mid-sweep; the angle can also be set manually via a slider
#   while stopped. Two angle-measure arcs are drawn directly on the canvas
#   (amber for the mirror's rotation, red for the reflected ray's) so the
#   "twice as wide" relationship is visible at a glance, not just in the
#   numbers.
#
#   Verified via web search that this is a genuine, frequently recurring
#   JAMB/UTME physics question (confirmed against a real 2024 JAMB past-
#   questions compilation) before writing exercises — wrote original
#   questions in the same style and numeric pattern rather than reproducing
#   any single source's exact wording, including the standard MCQ form,
#   a numeric worked example, an angular-velocity variant, and a
#   conceptual "why doesn't image size change" question.
#
# Run from the af2s project root (Git Bash):   bash patches/patch-v21-mirror-rotation.sh
# ══════════════════════════════════════════════════════════════════════════════
set -euo pipefail

if [ ! -f "package.json" ]; then
  echo "✗ Run this from the af2s project root (package.json not found)." >&2
  exit 1
fi

echo "── A-Factor patch v21: rotation-of-a-mirror simulation ──"
mkdir -p "src/app/embed/reflection" "src/app/simulations" "src/app/simulations/reflection" "src/components/simulation"

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
      const cx = W * 0.58, midY = H / 2;
      const mirrorTop = 30, mirrorBottom = H - 90;

      ctx.strokeStyle = '#334155'; ctx.lineWidth = 3;
      ctx.beginPath(); ctx.moveTo(cx, mirrorTop); ctx.lineTo(cx, mirrorBottom); ctx.stroke();
      ctx.strokeStyle = '#cbd5e1'; ctx.lineWidth = 1;
      for (let y = mirrorTop; y <= mirrorBottom; y += 12) {
        ctx.beginPath(); ctx.moveTo(cx + 2, y); ctx.lineTo(cx + 10, y - 7); ctx.stroke();
      }

      const poi = { x: cx, y: midY };
      ctx.setLineDash([5, 5]); ctx.strokeStyle = '#94a3b8'; ctx.lineWidth = 1;
      ctx.beginPath(); ctx.moveTo(poi.x - 90, poi.y); ctx.lineTo(poi.x + 90, poi.y); ctx.stroke();
      ctx.setLineDash([]);
      ctx.fillStyle = '#94a3b8'; ctx.font = '9px system-ui'; ctx.textAlign = 'left';
      ctx.fillText('normal', poi.x + 92, poi.y + 3);

      const th = (s.incidenceAngle * Math.PI) / 180;
      const rayLen = 90;
      const ix = poi.x - Math.cos(th) * rayLen, iy = poi.y - Math.sin(th) * rayLen;
      arrow(ctx, ix, iy, poi.x, poi.y, '#6366f1', 2.5);
      const rx = poi.x - Math.cos(th) * rayLen, ry = poi.y + Math.sin(th) * rayLen;
      arrow(ctx, poi.x, poi.y, rx, ry, '#10b981', 2.5);
      ctx.fillStyle = '#4338ca'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
      ctx.fillText(`i=${s.incidenceAngle}°`, poi.x - 34, poi.y - 14);
      ctx.fillStyle = '#059669';
      ctx.fillText(`r=${s.incidenceAngle}°`, poi.x - 34, poi.y + 22);

      const objDistPx = 130;
      const objX = cx - objDistPx, imgX = cx + objDistPx;
      const oy1 = H - 60, oy2 = H - 110;
      objectArrow(ctx, objX, oy1, oy2, '#0f172a', 'O');
      flag(ctx, objX, oy2 + 8, 1, '#0f172a');

      ctx.save(); ctx.setLineDash([5, 4]); ctx.globalAlpha = 0.75;
      objectArrow(ctx, imgX, oy1, oy2, '#8b5cf6', 'I (virtual)');
      ctx.restore();
      flag(ctx, imgX, oy2 + 8, -1, '#8b5cf6');

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
echo "✓ Patch v21 applied — 4 files written."
echo ""
echo "Next steps:"
echo "  rm -rf .next"
echo "  npm run dev"
echo ""
echo "Check: /simulations/reflection -> Rotating mirror tab. Press Run and"
echo "watch the reflected ray sweep at twice the mirror's rate; try the"
echo "manual angle slider while paused/reset too."
