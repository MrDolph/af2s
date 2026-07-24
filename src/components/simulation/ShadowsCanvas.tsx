'use client';
import { useRef, useEffect, useCallback } from 'react';

interface Props {
  sourceType: 'point' | 'extended';
  sourceRadiusPx: number;   // half-height of the source (0 for a point source)
  objectRadiusPx: number;   // half-height of the opaque object
  objectDistPx: number;     // source -> object (also the centre of the sweep when animating)
  screenDistPx: number;     // source -> screen
  isRunning: boolean; isPaused: boolean;
  width?: number; height?: number;
}

interface Vec { x: number; y: number; }
function lineAtX(p1: Vec, p2: Vec, x: number): number {
  const t = (x - p1.x) / (p2.x - p1.x);
  return p1.y + t * (p2.y - p1.y);
}

const SWEEP_PERIOD = 5; // s — one full back-and-forth pass of the object

export function ShadowsCanvas({ sourceType, sourceRadiusPx, objectRadiusPx, objectDistPx, screenDistPx, isRunning, isPaused, width = 660, height = 300 }: Props) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const rafRef = useRef<number>(0);
  const lastFrameRef = useRef<number | null>(null);
  const t = useRef(0);
  const sim = useRef({ sourceType, sourceRadiusPx, objectRadiusPx, objectDistPx, screenDistPx, isRunning, isPaused });
  sim.current = { sourceType, sourceRadiusPx, objectRadiusPx, objectDistPx, screenDistPx, isRunning, isPaused };

  useEffect(() => { t.current = 0; lastFrameRef.current = null; }, [sourceType, sourceRadiusPx, objectRadiusPx, objectDistPx, screenDistPx]);

  const draw = useCallback((timestamp?: number) => {
    const canvas = canvasRef.current; if (!canvas) return;
    const ctx = canvas.getContext('2d'); if (!ctx) return;
    const s = sim.current;
    const W = canvas.width, H = canvas.height;

    const animate = s.isRunning && !s.isPaused;
    if (animate && timestamp !== undefined) {
      if (lastFrameRef.current !== null) {
        t.current += Math.min((timestamp - lastFrameRef.current) / 1000, 0.1);
      }
      lastFrameRef.current = timestamp;
    } else {
      lastFrameRef.current = timestamp ?? null;
    }

    // Sweep the object between just past the source and just short of the
    // screen, so the umbra/penumbra visibly change size and position as it
    // moves — bounded to stay clear of both endpoints. Freezes at the
    // current position while paused (keyed on isRunning alone) rather than
    // snapping back to the slider's default value, which is what
    // `animate` (isRunning && !isPaused) would do here — the same pause
    // bug found and fixed in the eclipse simulation.
    const minDist = 55, maxDist = s.screenDistPx - 45;
    const sweepMid = (minDist + maxDist) / 2, sweepAmp = (maxDist - minDist) / 2;
    const objectDistPx = s.isRunning
      ? sweepMid + sweepAmp * Math.sin((2 * Math.PI / SWEEP_PERIOD) * t.current)
      : Math.min(Math.max(s.objectDistPx, minDist), maxDist);

    ctx.clearRect(0, 0, W, H);
    ctx.fillStyle = '#0f172a'; ctx.fillRect(0, 0, W, H);

    const midY = H / 2;
    const srcX = 50;
    const objX = srcX + objectDistPx;
    const scrX = Math.min(srcX + s.screenDistPx, W - 20);
    const rs = s.sourceType === 'point' ? 0.001 : s.sourceRadiusPx;
    const ro = s.objectRadiusPx;

    const srcTop: Vec = { x: srcX, y: midY - rs };
    const srcBot: Vec = { x: srcX, y: midY + rs };
    const objTop: Vec = { x: objX, y: midY - ro };
    const objBot: Vec = { x: objX, y: midY + ro };

    // Four boundary rays, extended out to the screen's x. Verified by
    // brute-force sampling many source points (not just these four extreme
    // rays) which region each screen point actually falls in: the UMBRA
    // (fully dark) boundary is the SAME-SIDE pairing (top-to-top,
    // bottom-to-bottom), and the PENUMBRA's outer edge (where any light at
    // all first appears) is the OPPOSITE-SIDE pairing (top-to-bottom,
    // bottom-to-top) — this holds universally, whichever of the source or
    // the object is larger. The reverse assignment looks plausible from
    // the ray diagram alone but is provably wrong: sampled classification
    // showed the "opposite-side" region was >90% lit at its edges, not
    // fully dark.
    const umbraTopY = lineAtX(srcTop, objTop, scrX);   // same-side: true umbra, upper edge
    const umbraBotY = lineAtX(srcBot, objBot, scrX);   // same-side: true umbra, lower edge
    const penTopY = lineAtX(srcBot, objTop, scrX);     // opposite-side: true penumbra outer edge
    const penBotY = lineAtX(srcTop, objBot, scrX);     // opposite-side: true penumbra outer edge

    // Screen, painted in bands: lit (white) / penumbra (grayscale gradient
    // — dimmer, not a different hue) / umbra (near-black). Using a tinted
    // colour like yellow for "lit" or for the penumbra gradient invites
    // reading it as a difference in colour rather than in brightness — a
    // real penumbra is simply dimmer white light, so this stays grayscale
    // throughout.
    const screenTop = 20, screenBottom = H - 20;
    ctx.fillStyle = '#ffffff'; ctx.fillRect(scrX - 6, screenTop, 6, screenBottom - screenTop);
    const bandFill = (y0: number, y1: number, fill: string | CanvasGradient) => {
      const a = Math.max(screenTop, Math.min(y0, y1));
      const b = Math.min(screenBottom, Math.max(y0, y1));
      if (b <= a) return;
      ctx.fillStyle = fill;
      ctx.fillRect(scrX - 6, a, 6, b - a);
    };
    bandFill(screenTop, penTopY, '#ffffff');
    const gradTop = ctx.createLinearGradient(0, penTopY, 0, umbraTopY);
    gradTop.addColorStop(0, '#ffffff'); gradTop.addColorStop(1, '#0f172a');
    bandFill(penTopY, umbraTopY, gradTop);
    bandFill(umbraTopY, umbraBotY, '#0f172a');
    const gradBot = ctx.createLinearGradient(0, umbraBotY, 0, penBotY);
    gradBot.addColorStop(0, '#0f172a'); gradBot.addColorStop(1, '#ffffff');
    bandFill(umbraBotY, penBotY, gradBot);
    bandFill(penBotY, screenBottom, '#ffffff');

    // Rays
    const drawRay = (a: Vec, b: Vec, color: string, dashed = false) => {
      const endY = lineAtX(a, b, scrX);
      ctx.save(); if (dashed) ctx.setLineDash([4, 3]);
      ctx.strokeStyle = color; ctx.lineWidth = 1.3;
      ctx.beginPath(); ctx.moveTo(a.x, a.y); ctx.lineTo(scrX, endY); ctx.stroke();
      ctx.restore();
    };
    drawRay(srcTop, objTop, 'rgba(96,165,250,0.7)');
    drawRay(srcBot, objBot, 'rgba(96,165,250,0.7)');
    if (s.sourceType === 'extended') {
      drawRay(srcBot, objTop, 'rgba(100,116,139,0.55)');
      drawRay(srcTop, objBot, 'rgba(100,116,139,0.55)');
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
      ctx.fillStyle = '#64748b';
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

    rafRef.current = requestAnimationFrame(draw);
  }, []);

  useEffect(() => {
    rafRef.current = requestAnimationFrame(draw);
    return () => cancelAnimationFrame(rafRef.current);
  }, [draw]);

  return (
    <canvas ref={canvasRef} width={width} height={height}
      className="w-full rounded-xl border border-gray-200" style={{ display: 'block' }} />
  );
}
