'use client';
import { useRef, useEffect, useCallback } from 'react';
import { flatFriction, inclineFriction } from '@/lib/physics/friction';

export type FrictionMode = 'flat' | 'incline';

interface Props {
  mode: FrictionMode;
  mass: number;
  applied: number;      // N (flat mode)
  angle: number;        // degrees (incline mode)
  muS: number; muK: number;
  isRunning: boolean; isPaused: boolean;
  resetKey: number;
  width?: number; height?: number;
}

function forceArrow(ctx: CanvasRenderingContext2D, x: number, y: number, dx: number, dy: number, color: string, label: string, labelDy = -8) {
  const len = Math.hypot(dx, dy);
  if (len < 1) return;
  const ang = Math.atan2(dy, dx);
  ctx.save();
  ctx.strokeStyle = color; ctx.lineWidth = 2.5; ctx.lineCap = 'round';
  ctx.beginPath(); ctx.moveTo(x, y); ctx.lineTo(x + dx, y + dy); ctx.stroke();
  ctx.fillStyle = color;
  ctx.beginPath(); ctx.moveTo(x + dx, y + dy);
  ctx.lineTo(x + dx - 9 * Math.cos(ang - 0.4), y + dy - 9 * Math.sin(ang - 0.4));
  ctx.lineTo(x + dx - 9 * Math.cos(ang + 0.4), y + dy - 9 * Math.sin(ang + 0.4));
  ctx.closePath(); ctx.fill();
  ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
  ctx.fillText(label, x + dx, y + dy + labelDy);
  ctx.restore();
}

export function FrictionCanvas({ mode, mass, applied, angle, muS, muK, isRunning, isPaused, resetKey, width = 640, height = 300 }: Props) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const rafRef = useRef<number>(0);
  const lastFrameRef = useRef<number | null>(null);
  const posRef = useRef(0);   // metres travelled
  const velRef = useRef(0);   // m/s
  const tRef = useRef(0);
  const sim = useRef({ mode, mass, applied, angle, muS, muK, isRunning, isPaused });
  sim.current = { mode, mass, applied, angle, muS, muK, isRunning, isPaused };

  useEffect(() => {
    posRef.current = 0; velRef.current = 0; tRef.current = 0;
    lastFrameRef.current = null;
  }, [mode, mass, applied, angle, muS, muK, resetKey]);

  const draw = useCallback((timestamp?: number) => {
    const canvas = canvasRef.current; if (!canvas) return;
    const ctx = canvas.getContext('2d'); if (!ctx) return;
    const s = sim.current;
    const W = canvas.width, H = canvas.height;

    let dt = 0;
    if (s.isRunning && !s.isPaused && timestamp !== undefined) {
      if (lastFrameRef.current !== null) {
        dt = Math.min((timestamp - lastFrameRef.current) / 1000, 0.1);
        tRef.current += dt;
      }
      lastFrameRef.current = timestamp;
    } else {
      lastFrameRef.current = timestamp ?? null;
    }

    ctx.clearRect(0, 0, W, H);
    ctx.fillStyle = '#f8fafc'; ctx.fillRect(0, 0, W, H);

    const SCALE = 1.4; // px per N for arrows

    if (s.mode === 'flat') {
      const r = flatFriction(s.mass, s.applied, s.muS, s.muK);
      // Wall-clock physics integration once sliding
      if (dt > 0 && r.moving) {
        velRef.current += r.acceleration * dt;
        posRef.current += velRef.current * dt;
      }
      const groundY = H - 70;
      const bw = 70, bh = 48;
      const px = 60 + ((posRef.current * 40) % (W - 180)); // wraps to stay on screen
      // Ground with texture ∝ μ
      ctx.fillStyle = '#e2e8f0'; ctx.fillRect(0, groundY, W, 70);
      ctx.strokeStyle = '#94a3b8'; ctx.lineWidth = 2;
      ctx.beginPath(); ctx.moveTo(0, groundY); ctx.lineTo(W, groundY); ctx.stroke();
      ctx.strokeStyle = '#cbd5e1'; ctx.lineWidth = 1;
      const rough = 6 + s.muS * 20;
      for (let x = 4; x < W; x += rough) {
        ctx.beginPath(); ctx.moveTo(x, groundY); ctx.lineTo(x + 4, groundY + 5); ctx.stroke();
      }
      // Block
      ctx.fillStyle = r.moving ? '#f59e0b' : '#6366f1';
      ctx.fillRect(px, groundY - bh, bw, bh);
      ctx.fillStyle = 'white'; ctx.font = 'bold 11px system-ui'; ctx.textAlign = 'center';
      ctx.fillText(`${s.mass} kg`, px + bw / 2, groundY - bh / 2 + 4);
      const cx = px + bw / 2, cy = groundY - bh / 2;
      // Forces
      forceArrow(ctx, px + bw, cy, Math.min(s.applied * SCALE, 150), 0, '#059669', `F = ${s.applied.toFixed(0)}N`, -10);
      forceArrow(ctx, px, cy, -Math.min(r.friction * SCALE, 150), 0, '#ef4444', `f = ${r.friction.toFixed(1)}N`, -10);
      forceArrow(ctx, cx, groundY - bh, 0, -Math.min(r.N * SCALE * 0.5, 70), '#3b82f6', `N`, -6);
      forceArrow(ctx, cx, groundY, 0, Math.min(r.N * SCALE * 0.5, 60), '#8b5cf6', `mg`, 14);
      // Status
      ctx.font = 'bold 11px system-ui'; ctx.textAlign = 'center';
      if (!r.moving) {
        ctx.fillStyle = '#4338ca';
        ctx.fillText(`STATIC — friction matches F exactly (limit: μsN = ${r.staticMax.toFixed(1)}N)`, W / 2, 28);
      } else {
        ctx.fillStyle = '#b45309';
        ctx.fillText(`SLIDING — kinetic friction μkN = ${r.friction.toFixed(1)}N,  a = ${r.acceleration.toFixed(2)} m/s²`, W / 2, 28);
      }
      ctx.fillStyle = '#64748b'; ctx.font = '10px system-ui'; ctx.textAlign = 'left';
      ctx.fillText(`v = ${velRef.current.toFixed(2)} m/s   distance = ${posRef.current.toFixed(1)} m   t = ${tRef.current.toFixed(1)}s`, 8, H - 10);
    }

    if (s.mode === 'incline') {
      const r = inclineFriction(s.mass, s.angle, s.muS, s.muK);
      if (dt > 0 && r.sliding) {
        velRef.current += r.acceleration * dt;
        posRef.current += velRef.current * dt;
      }
      const th = (s.angle * Math.PI) / 180;
      const baseX = 60, baseY = H - 50;
      const slopeLen = Math.min((W - 140) / Math.cos(th), (H - 110) / Math.max(Math.sin(th), 0.05));
      const topX = baseX + slopeLen * Math.cos(th);
      const topY = baseY - slopeLen * Math.sin(th);
      // Hill
      ctx.fillStyle = '#e2e8f0';
      ctx.beginPath(); ctx.moveTo(baseX, baseY); ctx.lineTo(topX, topY); ctx.lineTo(topX, baseY); ctx.closePath(); ctx.fill();
      ctx.strokeStyle = '#94a3b8'; ctx.lineWidth = 2;
      ctx.beginPath(); ctx.moveTo(baseX, baseY); ctx.lineTo(topX, topY); ctx.stroke();
      ctx.beginPath(); ctx.moveTo(baseX - 40, baseY); ctx.lineTo(W, baseY); ctx.stroke();
      // Angle arc
      ctx.strokeStyle = '#6366f1'; ctx.lineWidth = 1.5;
      ctx.beginPath(); ctx.arc(baseX, baseY, 34, -th, 0); ctx.stroke();
      ctx.fillStyle = '#4338ca'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'left';
      ctx.fillText(`θ = ${s.angle}°`, baseX + 40, baseY - 8);
      // Block on the slope (slides down from 75% up)
      const sMax = slopeLen * 0.7;
      const sPos = Math.min(posRef.current * 30, sMax * 0.95);
      const along = slopeLen * 0.75 - sPos;
      const bx = baseX + along * Math.cos(th);
      const by = baseY - along * Math.sin(th);
      const bw = 54, bh = 36;
      ctx.save();
      ctx.translate(bx, by); ctx.rotate(-th);
      ctx.fillStyle = r.sliding ? '#f59e0b' : '#6366f1';
      ctx.fillRect(-bw / 2, -bh, bw, bh);
      ctx.fillStyle = 'white'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
      ctx.fillText(`${s.mass}kg`, 0, -bh / 2 + 3);
      ctx.restore();
      // Forces (in slope frame, drawn in world coordinates)
      const c0x = bx, c0y = by - bh / 2;
      const dirDown: [number, number] = [-Math.cos(th), Math.sin(th)];
      const dirN: [number, number] = [-Math.sin(th), -Math.cos(th)];
      forceArrow(ctx, c0x, c0y, dirDown[0] * Math.min(r.gravityAlong * SCALE, 110), dirDown[1] * Math.min(r.gravityAlong * SCALE, 110), '#8b5cf6', `mg sinθ = ${r.gravityAlong.toFixed(1)}N`, -8);
      forceArrow(ctx, c0x, c0y, -dirDown[0] * Math.min(r.friction * SCALE, 110), -dirDown[1] * Math.min(r.friction * SCALE, 110), '#ef4444', `f = ${r.friction.toFixed(1)}N`, 14);
      forceArrow(ctx, c0x, c0y, dirN[0] * Math.min(r.N * SCALE * 0.5, 70), dirN[1] * Math.min(r.N * SCALE * 0.5, 70), '#3b82f6', 'N', -6);
      // Status
      ctx.font = 'bold 11px system-ui'; ctx.textAlign = 'center';
      if (!r.sliding) {
        ctx.fillStyle = '#4338ca';
        ctx.fillText(`STATIC — tilts to ${r.reposeAngle.toFixed(1)}° (angle of repose, tanθr = μs) before slipping`, W / 2, 28);
      } else {
        ctx.fillStyle = '#b45309';
        ctx.fillText(`SLIDING — a = g(sinθ − μk cosθ) = ${r.acceleration.toFixed(2)} m/s²`, W / 2, 28);
      }
      ctx.fillStyle = '#64748b'; ctx.font = '10px system-ui'; ctx.textAlign = 'left';
      ctx.fillText(`v = ${velRef.current.toFixed(2)} m/s   t = ${tRef.current.toFixed(1)}s`, 8, H - 10);
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
