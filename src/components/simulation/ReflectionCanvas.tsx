'use client';
import { useRef, useEffect, useCallback } from 'react';
import { thinLensImage } from '@/lib/physics/optics';

export type ReflectionSource = 'point' | 'ray-box' | 'hidden';

export type ReflectionMode = 'plane' | 'curved' | 'rotation';

interface Props {
  mode: ReflectionMode;
  // plane
  incidenceAngle: number; // degrees from the normal
  // curved (cm as display units)
  focal: number;          // |f| in cm
  objectHeight?: number;  // cm
  objectDist: number;     // u in cm
  converging: boolean;    // true = concave (converging), false = convex (diverging)
  parabolic?: boolean;
  source?: ReflectionSource;
  onRotationComplete?: () => void;
  rotationAngle: number;  // target tilt from the 0° reference position
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
  ctx.font = '600 14px system-ui'; ctx.textAlign = 'center';
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
function drawSource(ctx: CanvasRenderingContext2D, source: ReflectionSource, x: number, y: number, angle: number, halfHeight = 8) {
  if (source === 'hidden') return;
  ctx.save();
  ctx.translate(x, y);
  ctx.rotate(angle);
  ctx.fillStyle = '#f59e0b';
  if (source === 'point') {
    ctx.beginPath(); ctx.arc(0, 0, 4, 0, Math.PI * 2); ctx.fill();
  } else {
    ctx.fillStyle = '#1e293b';
    ctx.beginPath(); ctx.roundRect(-22, -halfHeight, 22, halfHeight * 2, 3); ctx.fill();
    ctx.fillStyle = '#fbbf24';
    ctx.fillRect(-4, -halfHeight + 2, 4, halfHeight * 2 - 4);
  }
  ctx.restore();
}

function reflect(d: Vec, n: Vec): Vec {
  const dot = d.x * n.x + d.y * n.y;
  return { x: d.x - 2 * dot * n.x, y: d.y - 2 * dot * n.y };
}
function normalize(v: Vec): Vec {
  const len = Math.hypot(v.x, v.y) || 1;
  return { x: v.x / len, y: v.y / len };
}

const ROTATION_SECONDS = 3;

export function ReflectionCanvas({
  mode, incidenceAngle, focal, objectDist, converging, rotationAngle,
  objectHeight = 12, parabolic = false, source = 'point', onRotationComplete,
  isRunning, isPaused, onTick, width = 660, height = 320,
}: Props) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const rafRef = useRef<number>(0);
  const lastFrameRef = useRef<number | null>(null);
  const t = useRef(0);
  const sim = useRef({ mode, incidenceAngle, focal, objectDist, converging, rotationAngle, isRunning, isPaused, onTick, objectHeight, parabolic, source, onRotationComplete });
  sim.current = { mode, incidenceAngle, focal, objectDist, converging, rotationAngle, isRunning, isPaused, onTick, objectHeight, parabolic, source, onRotationComplete };

  useEffect(() => { t.current = 0; lastFrameRef.current = null; }, [mode, incidenceAngle, focal, objectDist, converging, rotationAngle]);

  const draw = useCallback((timestamp?: number) => {
    const canvas = canvasRef.current; if (!canvas) return;
    const ctx = canvas.getContext('2d'); if (!ctx) return;
    const s = sim.current;
    const W = canvas.width, H = canvas.height;

    const animate = s.mode === 'rotation' && s.isRunning && !s.isPaused;
    if (animate && timestamp !== undefined) {
      if (lastFrameRef.current !== null) {
        const next = Math.min(ROTATION_SECONDS, t.current + Math.min((timestamp - lastFrameRef.current) / 1000, 0.1));
        if (t.current < ROTATION_SECONDS && next === ROTATION_SECONDS) s.onRotationComplete?.();
        t.current = next;
      }
      lastFrameRef.current = timestamp;
    } else {
      lastFrameRef.current = null;
    }

    ctx.clearRect(0, 0, W, H);

    if (s.mode === 'plane') {
      const cx = W * 0.52, midY = H / 2;
      const mirrorTop = H * 0.12, mirrorBottom = H * 0.88;

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
      const incidence = Math.max(0, Math.min(90, s.incidenceAngle));
      const th = incidence * Math.PI / 180;
      const rayLen = Math.min(W * 0.34, H * 0.29);
      const objTip: Vec = { x: P0.x - Math.cos(th) * rayLen, y: P0.y - Math.sin(th) * rayLen };
      const objHeight = H * 0.22;
      const objBase: Vec = { x: objTip.x, y: objTip.y + objHeight };

      const imgTip: Vec = { x: 2 * cx - objTip.x, y: objTip.y };
      const imgBase: Vec = { x: 2 * cx - objBase.x, y: objBase.y };

      // Normal at P0, for the labelled i=r construction
      ctx.setLineDash([5, 5]); ctx.strokeStyle = '#94a3b8'; ctx.lineWidth = 1;
      ctx.beginPath(); ctx.moveTo(P0.x - 60, P0.y); ctx.lineTo(P0.x + 60, P0.y); ctx.stroke();
      ctx.setLineDash([]);
      ctx.fillStyle = '#334155'; ctx.font = '600 13px system-ui'; ctx.textAlign = 'left';
      ctx.fillText('normal', P0.x + 62, P0.y + 3);

      // Ray A: object tip -> P0 -> reflects at an equal angle (labelled i, r)
      arrow(ctx, objTip.x, objTip.y, P0.x, P0.y, '#6366f1', 2.2);
      const rA = { x: P0.x - Math.cos(th) * rayLen, y: P0.y + Math.sin(th) * rayLen };
      arrow(ctx, P0.x, P0.y, rA.x, rA.y, '#4338ca', 2.2, 0.72);
      const arcRadius = Math.min(rayLen * 0.55, 42);
      ctx.strokeStyle = '#4338ca'; ctx.lineWidth = 2;
      ctx.beginPath();
      ctx.arc(P0.x, P0.y, arcRadius, Math.PI - th, Math.PI + th);
      ctx.stroke();
      ctx.fillStyle = '#312e81'; ctx.font = '600 15px system-ui'; ctx.textAlign = 'center';
      ctx.fillText(incidence === 90 ? '90° · Grazing incidence' : `Incidence ${incidence}° · Reflection ${incidence}°`, W / 2, 18, W - 16);
      drawSource(ctx, s.source, objTip.x, objTip.y, th);
      if (incidence === 90) {
        ctx.fillText('The ray runs along the mirror surface.', W / 2, H - 10, W - 16);
        rafRef.current = requestAnimationFrame(draw);
        return;
      }

      // A second ray leaves the same object tip and hits lower on the
      // mirror. Both backward extensions meet at that tip's virtual image.
      const secondHit = { x: cx, y: H * 0.63 };
      const outgoing = { x: objTip.x - cx, y: secondHit.y - objTip.y };
      const reach = Math.min(1, (H - 36 - secondHit.y) / outgoing.y);
      arrow(ctx, objTip.x, objTip.y, secondHit.x, secondHit.y, '#047857', 2);
      arrow(ctx, secondHit.x, secondHit.y, secondHit.x + outgoing.x * reach,
        secondHit.y + outgoing.y * reach, '#047857', 2);
      ctx.save(); ctx.setLineDash([5, 4]); ctx.lineWidth = 1.7;
      for (const [hit, color] of [[P0, '#4338ca'], [secondHit, '#047857']] as const) {
        ctx.strokeStyle = color;
        ctx.beginPath(); ctx.moveTo(hit.x, hit.y); ctx.lineTo(imgTip.x, imgTip.y); ctx.stroke();
      }
      ctx.restore();

      // Object and image arrows — drawn last so they sit cleanly on top of
      // the rays that terminate exactly at their tip/base.
      objectArrow(ctx, objTip.x, objBase.y, objTip.y, '#0f172a', 'O');
      flag(ctx, objTip.x, objTip.y + 8, 1, '#0f172a');
      ctx.save(); ctx.globalAlpha = 0.85;
      objectArrow(ctx, imgTip.x, imgBase.y, imgTip.y, '#8b5cf6', 'I (virtual)');
      ctx.restore();
      flag(ctx, imgTip.x, imgTip.y + 8, -1, '#8b5cf6');

      ctx.fillStyle = '#334155'; ctx.font = '600 14px system-ui'; ctx.textAlign = 'center';
      ctx.fillText('Dashed extensions meet at the virtual image tip', W / 2, H - 25, W - 16);
      ctx.fillText('Same height · Equal distances from the mirror', W / 2, H - 8, W - 16);
    } else if (s.mode === 'curved') {
      const axisY = H / 2, cx = W / 2;
      const f = s.converging ? s.focal : -s.focal;
      const u = s.objectDist;
      const img = thinLensImage(u, f);
      const maxDistance = Math.max(u, 2 * s.focal, img.atInfinity ? 0 : Math.abs(img.v));
      const objectHeight = Math.max(2, Math.min(30, s.objectHeight));
      const maxHeight = objectHeight * Math.max(1, img.atInfinity ? 1 : img.m);
      const mirrorHalf = Math.min(H * 0.33, W * 0.26);
      const scale = Math.min((W / 2 - 32) / maxDistance, (H / 2 - 28) / maxHeight, mirrorHalf * 0.82 / objectHeight);
      const hObj = objectHeight * scale;
      const parabolaFocus = Math.min(W * 0.26, Math.max(mirrorHalf, s.focal * W / 150));
      const bow = s.parabolic ? -(mirrorHalf ** 2) / (4 * parabolaFocus) : mirrorHalf * (s.converging ? -0.32 : 0.32);
      const surfaceX = (dy: number) => cx + bow * (dy / mirrorHalf) ** 2;
      const curve = (offset: number, color: string, width: number) => {
        ctx.strokeStyle = color; ctx.lineWidth = width;
        ctx.beginPath(); ctx.moveTo(cx + bow + offset, axisY - mirrorHalf);
        ctx.quadraticCurveTo(cx - bow + offset, axisY, cx + bow + offset, axisY + mirrorHalf);
        ctx.stroke();
      };

      ctx.strokeStyle = '#94a3b8'; ctx.lineWidth = 1;
      ctx.beginPath(); ctx.moveTo(0, axisY); ctx.lineTo(W, axisY); ctx.stroke();
      curve(5, '#475569', 7);
      ctx.strokeStyle = '#334155'; ctx.lineWidth = 2;
      for (let dy = -mirrorHalf + 9; dy < mirrorHalf - 8; dy += 12) {
        const x = surfaceX(dy);
        ctx.beginPath(); ctx.moveTo(x + 5, axisY + dy); ctx.lineTo(x + 15, axisY + dy - 6); ctx.stroke();
      }
      curve(0, '#818cf8', 3);

      const markFocus = (x: number, label: string) => {
        ctx.fillStyle = '#92400e'; ctx.font = '600 14px system-ui'; ctx.textAlign = 'center';
        ctx.beginPath(); ctx.arc(x, axisY, 3, 0, Math.PI * 2); ctx.fill();
        ctx.fillText(label, x, axisY + 19);
      };

      if (s.parabolic) {
        const focusX = cx - parabolaFocus;
        if (s.source === 'ray-box') drawSource(ctx, s.source, 24, axisY, 0, mirrorHalf * 0.8 + 5);
        for (const fraction of [-0.8, -0.4, 0.4, 0.8]) {
          const dy = mirrorHalf * fraction;
          const hitX = surfaceX(dy);
          arrow(ctx, 24, axisY + dy, hitX, axisY + dy, '#4338ca');
          arrow(ctx, hitX, axisY + dy, focusX, axisY, '#047857');
          if (s.source === 'point') drawSource(ctx, s.source, 24, axisY + dy, 0);
        }
        markFocus(focusX, 'F');
        ctx.fillStyle = '#334155'; ctx.font = '600 15px system-ui'; ctx.textAlign = 'center';
        ctx.fillText(`Parabolic mirror · Parallel rays meet at F (${s.focal} cm)`, cx, 22, W - 16);
        rafRef.current = requestAnimationFrame(draw);
        return;
      }

      const focusX = cx - f * scale;
      markFocus(focusX, 'F');
      if (Math.abs(f * scale) >= 28) markFocus(cx - 2 * f * scale, 'C');
      const objX = cx - u * scale;
      const objTipY = axisY - hObj;
      const ix = img.atInfinity ? 0 : cx - img.v * scale;
      const tipY = axisY + (img.inverted ? 1 : -1) * hObj * img.m;

      // Use the paraxial image solution, with ray joins on the reflecting face.

      for (const [hitY, color] of [[objTipY, '#b91c1c'], [axisY, '#1d4ed8']] as const) {
        const hitX = surfaceX(hitY - axisY);
        arrow(ctx, objX, objTipY, hitX, hitY, color, 1.6);
        if (img.real && !img.atInfinity) {
          arrow(ctx, hitX, hitY, ix, tipY, color, 1.6);
        } else {
          const slope = img.atInfinity ? -hObj / (u * scale) : (tipY - hitY) / (ix - hitX);
          const reach = Math.min(hitX - 8, (slope < 0 ? H - 24 - hitY : hitY - 24) / Math.max(Math.abs(slope), 0.01));
          arrow(ctx, hitX, hitY, hitX - reach, hitY - slope * reach, color, 1.6);
          if (!img.atInfinity) {
            ctx.save(); ctx.setLineDash([5, 4]); ctx.strokeStyle = color;
            ctx.beginPath(); ctx.moveTo(hitX, hitY); ctx.lineTo(ix, tipY); ctx.stroke(); ctx.restore();
          }
        }
      }

      objectArrow(ctx, objX, axisY, objTipY, '#0f172a', 'O');
      drawSource(ctx, s.source, objX, objTipY, 0);
      if (img.atInfinity) {
        ctx.fillStyle = '#334155'; ctx.font = '600 15px system-ui'; ctx.textAlign = 'center';
        ctx.fillText('Object at F · Parallel reflected rays · Image at infinity', cx, 22, W - 16);
      } else {
        const color = img.real ? '#047857' : '#7c3aed';
        objectArrow(ctx, ix, axisY, tipY, color, 'I');
        if (Math.abs(tipY - axisY) < 12) {
          const insetX = W - 30, insetY = 55;
          objectArrow(ctx, insetX, insetY, insetY + (img.inverted ? 19 : -19), color, 'I');
          ctx.fillStyle = color; ctx.textAlign = 'right'; ctx.font = '600 12px system-ui';
          ctx.fillText('Image detail (enlarged)', insetX - 12, insetY, W / 2 - 48);
        }
        if (Math.abs(tipY - axisY) < 12 || hObj < 12) {
          ctx.fillStyle = '#334155'; ctx.font = '600 14px system-ui'; ctx.textAlign = 'center';
          ctx.fillText('Diagram zoomed out to fit the object and image', cx, 22, W - 16);
        }
      }

      ctx.fillStyle = '#334155'; ctx.font = '600 14px system-ui'; ctx.textAlign = 'left';
      const nature = img.atInfinity ? 'at infinity'
        : `${img.real ? 'real' : 'virtual'}, ${img.inverted ? 'inverted' : 'upright'}, ${img.m > 1 ? 'magnified' : img.m < 1 ? 'diminished' : 'same size'}`;
      ctx.fillText(`u=${u}cm  f=${f}cm  →  v=${img.atInfinity ? '∞' : Math.abs(img.v).toFixed(1) + 'cm'}  hₒ=${objectHeight}cm  m=${img.atInfinity ? '∞' : img.m.toFixed(2)}  (${nature})`, 8, H - 8, W - 20);
    } else {
      // ── Rotation of a mirror: incident ray fixed, mirror rotates ──────────
      // Classic result: rotate the mirror by θ, the reflected ray rotates by
      // 2θ. Uses genuine vector reflection (not an assumed formula) and then
      // MEASURES the angle between the current and reference reflected rays,
      // so the 2θ relationship is demonstrated, not just asserted.
      const P: Vec = { x: W * 0.5, y: H * 0.52 };     // fixed point of incidence
      const rayLength = Math.min(W * 0.39, H * 0.31);
      const sourceOffset = rayLength / Math.SQRT2;
      const S: Vec = { x: P.x - sourceOffset, y: P.y - sourceOffset };  // fixed light source

      const d = normalize({ x: P.x - S.x, y: P.y - S.y }); // fixed incident direction

      const angleDeg = s.rotationAngle * (t.current / ROTATION_SECONDS);
      const angleRad = (angleDeg * Math.PI) / 180;

      const mirrorDir: Vec = { x: Math.cos(angleRad), y: Math.sin(angleRad) };
      const normal: Vec = { x: Math.sin(angleRad), y: -Math.cos(angleRad) }; // points "up" at 0°
      const normal0: Vec = { x: 0, y: -1 };

      const r = reflect(d, normal);
      const r0 = reflect(d, normal0);
      const reflectedTurn = Math.atan2(r0.x * r.y - r0.y * r.x, r0.x * r.x + r0.y * r.y);
      const reflectedDeg = reflectedTurn * 180 / Math.PI;
      s.onTick?.(angleDeg, reflectedDeg);

      ctx.fillStyle = '#f8fafc'; ctx.fillRect(0, 0, W, H);

      // Faint reference (0°) mirror position and reflected ray
      const mirrorHalf = Math.min(W * 0.38, H * 0.48);
      ctx.save(); ctx.setLineDash([4, 4]); ctx.strokeStyle = '#64748b'; ctx.lineWidth = 1.5;
      ctx.beginPath(); ctx.moveTo(P.x - mirrorHalf, P.y); ctx.lineTo(P.x + mirrorHalf, P.y); ctx.stroke();
      ctx.strokeStyle = '#a16207';
      ctx.beginPath(); ctx.moveTo(P.x, P.y); ctx.lineTo(P.x + r0.x * rayLength, P.y + r0.y * rayLength); ctx.stroke();
      ctx.restore();

      // Current mirror (solid) with silvered-back hatching
      const mLen = mirrorHalf;
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

      // Show the initial normal throughout and add the current normal once the mirror turns.
      ctx.save(); ctx.setLineDash([4, 4]); ctx.strokeStyle = '#94a3b8'; ctx.lineWidth = 1;
      const normalLength = Math.min(rayLength * 1.3, Math.max(rayLength, P.y - 49));
      const normalTip = { x: P.x + normal.x * normalLength, y: P.y + normal.y * normalLength };
      ctx.beginPath();
      ctx.moveTo(P.x - normal.x * rayLength * 0.75, P.y - normal.y * rayLength * 0.75);
      ctx.lineTo(normalTip.x, normalTip.y); ctx.stroke();
      const turned = Math.abs(angleDeg) >= 0.05;
      if (turned) {
        ctx.strokeStyle = '#64748b'; ctx.setLineDash([2, 4]);
        ctx.beginPath(); ctx.moveTo(P.x, P.y); ctx.lineTo(P.x, P.y - normalLength); ctx.stroke();
      }
      ctx.restore();

      // Incident ray (fixed) and current reflected ray
      arrow(ctx, S.x, S.y, P.x, P.y, '#6366f1', 2.5);
      arrow(ctx, P.x, P.y, P.x + r.x * rayLength, P.y + r.y * rayLength, '#10b981', 2.5);
      drawSource(ctx, s.source, S.x, S.y, Math.atan2(d.y, d.x));
      if (s.source !== 'hidden') {
        ctx.fillStyle = '#92400e';
        ctx.font = '600 14px system-ui'; ctx.textAlign = 'right';
        ctx.fillText(s.source === 'ray-box' ? 'Fixed ray box' : 'Fixed source', S.x - 23, S.y, Math.max(1, S.x - 27));
      }
      const normalAngle = Math.atan2(normal.y, normal.x);
      const incidentAngle = Math.atan2(-d.y, -d.x);
      const reflectionAngle = Math.atan2(r.y, r.x);
      const incidenceDeg = Math.acos(Math.max(-1, Math.min(1, -d.x * normal.x - d.y * normal.y))) * 180 / Math.PI;
      const drawRayAngle = (end: number, color: string, label: string) => {
        const turn = Math.atan2(Math.sin(end - normalAngle), Math.cos(end - normalAngle));
        const radius = rayLength * 0.7;
        ctx.strokeStyle = color; ctx.lineWidth = 2;
        ctx.beginPath(); ctx.arc(P.x, P.y, radius, normalAngle, normalAngle + turn, turn < 0); ctx.stroke();
        const middle = normalAngle + turn / 2;
        ctx.fillStyle = color; ctx.font = '600 13px system-ui'; ctx.textAlign = 'center';
        ctx.fillText(label, P.x + Math.cos(middle) * (radius + 12), P.y + Math.sin(middle) * (radius + 12));
      };
      drawRayAngle(incidentAngle, '#4338ca', 'i');
      drawRayAngle(reflectionAngle, '#047857', 'r');


      // Angle arcs: mirror rotation (small, at the mirror) vs reflected-ray
      // rotation (bigger, at the reflected ray) — drawn so the "twice as
      // wide" relationship is visible at a glance, not just in the numbers.
      const arcR1 = rayLength * 0.28;
      ctx.strokeStyle = '#f59e0b'; ctx.lineWidth = 2;
      ctx.beginPath(); ctx.arc(P.x, P.y, arcR1, 0, angleRad, angleRad < 0); ctx.stroke();
      const arcR2 = rayLength * 0.5;
      const a0 = Math.atan2(r0.y, r0.x);
      ctx.strokeStyle = '#ef4444'; ctx.lineWidth = 2;
      ctx.beginPath(); ctx.arc(P.x, P.y, arcR2, a0, a0 + reflectedTurn, reflectedTurn < 0); ctx.stroke();

      ctx.fillStyle = '#0f172a'; ctx.beginPath(); ctx.arc(P.x, P.y, 4, 0, Math.PI * 2); ctx.fill();
      const reflectedEnd = { x: P.x + r.x * rayLength, y: P.y + r.y * rayLength };
      ctx.fillStyle = '#047857'; ctx.font = '700 14px system-ui'; ctx.textAlign = r.x >= 0 ? 'left' : 'right';
      if (turned) ctx.fillText('R', reflectedEnd.x + (r.x >= 0 ? 5 : -5), reflectedEnd.y - 6,
        Math.max(1, (r.x >= 0 ? W - reflectedEnd.x : reflectedEnd.x) - 10));

      ctx.fillStyle = '#92400e'; ctx.textAlign = 'left';
      ctx.fillText('R′', P.x + r0.x * rayLength + 5, P.y + r0.y * rayLength + 13);
      ctx.fillStyle = '#475569'; ctx.textAlign = 'center';
      ctx.fillText('N', P.x, Math.max(55, P.y - normalLength - 5));
      if (turned) {
        ctx.fillText('N′', normalTip.x + Math.sign(angleDeg) * 12, Math.max(55, normalTip.y + 12));
      }

      ctx.textAlign = 'center'; ctx.font = '700 16px system-ui'; ctx.fillStyle = '#0f172a';
      ctx.fillText(`Mirror θ = ${angleDeg.toFixed(1)}°   ·   Ray turn 2θ = ${reflectedDeg.toFixed(1)}°`, W / 2, 20, W - 16);
      ctx.font = '600 14px system-ui';
      ctx.fillText(`From the current normal: incidence i = reflection r = ${incidenceDeg.toFixed(1)}°`, W / 2, 39, W - 16);
      ctx.fillStyle = '#334155';
      ctx.fillText('R′: original reflected ray · R: new reflected ray', W / 2, H - 27, W - 16);
      ctx.fillText('N: initial normal · N′: rotated normal · r: reflection angle', W / 2, H - 9, W - 16);
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
