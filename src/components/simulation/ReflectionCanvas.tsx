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
