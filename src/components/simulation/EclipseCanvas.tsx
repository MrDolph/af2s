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
