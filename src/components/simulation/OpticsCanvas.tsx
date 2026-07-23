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
