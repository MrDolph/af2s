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
