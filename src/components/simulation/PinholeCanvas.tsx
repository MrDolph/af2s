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
