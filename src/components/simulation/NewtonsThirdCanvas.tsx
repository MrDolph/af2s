'use client';
import { useRef, useEffect, useCallback } from 'react';
import { pushMotion, collisionMotion, THIRD_LAW_TIMING, ThirdLawPhase } from '@/lib/physics/newtons-laws';

interface Props {
  mass1: number; mass2: number; force: number;
  scenario: 'push' | 'rocket' | 'collision';
  isRunning: boolean; isPaused: boolean;
  onTick?: (t: number, v1: number, v2: number) => void;
  width?: number; height?: number;
}

const PX_PER_M = 26; // pixels per metre for push/collision scenes

function forceArrow(
  ctx: CanvasRenderingContext2D, x: number, y: number, len: number, dir: 1 | -1,
  color: string, label: string,
) {
  const ex = x + dir * len;
  ctx.save();
  ctx.strokeStyle = color; ctx.lineWidth = 2.5;
  ctx.beginPath(); ctx.moveTo(x, y); ctx.lineTo(ex, y); ctx.stroke();
  ctx.fillStyle = color;
  ctx.beginPath(); ctx.moveTo(ex, y);
  ctx.lineTo(ex - dir * 9, y - 5); ctx.lineTo(ex - dir * 9, y + 5);
  ctx.closePath(); ctx.fill();
  ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
  ctx.fillText(label, x + dir * len / 2, y - 10);
  ctx.restore();
}

function phaseLabel(phase: ThirdLawPhase, contactWord = 'CONTACT'): { text: string; color: string } {
  if (phase === 'approach') return { text: 'Approaching…', color: '#64748b' };
  if (phase === 'contact') return { text: `${contactWord} — equal & opposite forces act!`, color: '#dc2626' };
  return { text: 'Separated — no more contact force, coasting at constant velocity', color: '#059669' };
}

export function NewtonsThirdCanvas({ mass1, mass2, force, scenario, isRunning, isPaused, onTick, width = 680, height = 240 }: Props) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const rafRef = useRef<number>(0);
  const t = useRef(0);
  const lastFrameRef = useRef<number | null>(null);
  const simRef = useRef({ mass1, mass2, force, scenario, isRunning, isPaused, onTick, width, height });
  simRef.current = { mass1, mass2, force, scenario, isRunning, isPaused, onTick, width, height };

  useEffect(() => { t.current = 0; lastFrameRef.current = null; }, [mass1, mass2, force, scenario]);

  const draw = useCallback((timestamp?: number) => {
    const canvas = canvasRef.current; if (!canvas) return;
    const ctx = canvas.getContext('2d'); if (!ctx) return;
    const { mass1: m1, mass2: m2, force: F, scenario: sc, isRunning: r, isPaused: p, onTick: ot } = simRef.current;
    const W = canvas.width, H = canvas.height;

    // Real wall-clock dt — the animation always plays at true speed.
    if (r && !p && timestamp !== undefined) {
      if (lastFrameRef.current !== null) {
        t.current += Math.min((timestamp - lastFrameRef.current) / 1000, 0.1);
      }
      lastFrameRef.current = timestamp;
    } else {
      lastFrameRef.current = timestamp ?? null;
    }

    ctx.clearRect(0, 0, W, H);

    const groundY = H - 50;
    ctx.fillStyle = '#f8fafc'; ctx.fillRect(0, 0, W, groundY);
    ctx.fillStyle = '#e2e8f0'; ctx.fillRect(0, groundY, W, H - groundY);
    ctx.beginPath(); ctx.moveTo(0, groundY); ctx.lineTo(W, groundY);
    ctx.strokeStyle = '#94a3b8'; ctx.lineWidth = 2; ctx.stroke();

    const cx = W / 2;
    const BLOCK_H = 48;

    if (sc === 'push' || sc === 'collision') {
      const motion = sc === 'push' ? pushMotion(t.current, m1, m2, F) : collisionMotion(t.current, m1, m2, F);
      const { obj1, obj2, phase } = motion;
      ot?.(t.current, obj1.v, obj2.v);
      const B1W = 56, B2W = 56;
      const by = groundY - BLOCK_H;
      const midY = by + BLOCK_H / 2;

      // Facing-edge convention: obj1.x is object 1's RIGHT (facing) edge,
      // obj2.x is object 2's LEFT (facing) edge. They coincide (both 0)
      // exactly at the moment of contact — never drawn apart while a
      // contact force is shown, and never overlapping once separated.
      const edge1X = cx + obj1.x * PX_PER_M;
      const edge2X = cx + obj2.x * PX_PER_M;

      // Loop the demo once both bodies have clearly left the frame.
      const margin = 140;
      if (phase === 'separated' && (edge1X < -margin || edge2X > W + margin)) {
        t.current = 0;
      }

      ctx.fillStyle = '#6366f1'; ctx.beginPath();
      ctx.roundRect(edge1X - B1W, by, B1W, BLOCK_H, 6); ctx.fill();
      ctx.fillStyle = 'white'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
      ctx.fillText(`${m1}kg`, edge1X - B1W / 2, midY + 4);

      ctx.fillStyle = '#10b981'; ctx.beginPath();
      ctx.roundRect(edge2X, by, B2W, BLOCK_H, 6); ctx.fill();
      ctx.fillStyle = 'white'; ctx.fillText(`${m2}kg`, edge2X + B2W / 2, midY + 4);

      // Force arrows ONLY while genuinely in contact — this is the fix for
      // forces being drawn between two bodies that aren't touching.
      if (phase === 'contact') {
        const fLen = Math.min(F * 1.3, 70);
        forceArrow(ctx, edge1X - B1W, midY, fLen, -1, '#ef4444', `−F=${F}N`);
        forceArrow(ctx, edge2X + B2W, midY, fLen, 1, '#10b981', `+F=${F}N`);
        // Flash the contact point
        ctx.save();
        ctx.fillStyle = 'rgba(239,68,68,0.25)';
        ctx.beginPath(); ctx.arc((edge1X + edge2X) / 2, midY, 10, 0, Math.PI * 2); ctx.fill();
        ctx.restore();
      }

      // Acceleration / velocity readout
      ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
      ctx.fillStyle = '#6366f1';
      ctx.fillText(`v₁=${obj1.v.toFixed(2)} m/s`, edge1X - B1W / 2, by - 8);
      ctx.fillStyle = '#10b981';
      ctx.fillText(`v₂=${obj2.v.toFixed(2)} m/s`, edge2X + B2W / 2, by - 8);

      const lbl = phaseLabel(phase, sc === 'push' ? 'PUSHING OFF' : 'CONTACT');
      ctx.fillStyle = lbl.color; ctx.font = 'bold 11px system-ui'; ctx.textAlign = 'center';
      ctx.fillText(lbl.text, cx, 22);

      if (sc === 'collision') {
        ctx.fillStyle = '#94a3b8'; ctx.font = '10px system-ui';
        ctx.fillText(`gap closes at ${THIRD_LAW_TIMING.approachSpeed} m/s, then reaction forces take over on contact`, cx, H - 8);
      } else {
        ctx.fillStyle = '#94a3b8'; ctx.font = '10px system-ui';
        ctx.fillText(`contact lasts ${THIRD_LAW_TIMING.pushDuration}s while hands are still in contact`, cx, H - 8);
      }
    }

    if (sc === 'rocket') {
      const a2 = F / m1;
      ot?.(t.current, a2 * t.current, 0);
      // Wrap the rocket around the canvas so it never just vanishes off-screen.
      const travel = 0.5 * a2 * t.current * t.current * 40;
      const rocketX = ((80 + travel) % (W + 90)) - 90;
      const by = groundY - 60;
      ctx.fillStyle = '#6366f1';
      ctx.beginPath(); ctx.roundRect(rocketX, by, 70, 50, 8); ctx.fill();
      ctx.fillStyle = '#f59e0b';
      ctx.beginPath(); ctx.moveTo(rocketX + 70, by + 25);
      ctx.lineTo(rocketX + 90, by + 10); ctx.lineTo(rocketX + 90, by + 40); ctx.closePath(); ctx.fill();
      ctx.fillStyle = 'white'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
      ctx.fillText(`${m1}kg`, rocketX + 35, by + 28);

      const exhaustLen = Math.min(F * 2, 100);
      const ey = by + 25;
      for (let i = 0; i < 5; i++) {
        const jitter = (Math.sin(t.current * 20 + i) * 6);
        ctx.fillStyle = `rgba(${200 + i * 10},${100 - i * 15},30,${0.8 - i * 0.12})`;
        ctx.beginPath();
        ctx.ellipse(rocketX - 10 - i * exhaustLen / 5, ey + jitter, exhaustLen / 5 * (1 - i * 0.15), 8 - i, 0, 0, Math.PI * 2);
        ctx.fill();
      }
      ctx.strokeStyle = '#ef4444'; ctx.lineWidth = 2;
      ctx.beginPath(); ctx.moveTo(rocketX, ey); ctx.lineTo(rocketX - 50, ey); ctx.stroke();
      ctx.fillStyle = '#ef4444'; ctx.font = '10px system-ui'; ctx.textAlign = 'center';
      ctx.fillText(`Thrust (reaction)`, rocketX - 25, ey - 10);
      ctx.strokeStyle = '#10b981'; ctx.lineWidth = 2;
      ctx.beginPath(); ctx.moveTo(rocketX + 90, ey); ctx.lineTo(rocketX + 130, ey); ctx.stroke();
      ctx.fillStyle = '#10b981';
      ctx.beginPath(); ctx.moveTo(rocketX + 130, ey);
      ctx.lineTo(rocketX + 120, ey - 5); ctx.lineTo(rocketX + 120, ey + 5);
      ctx.closePath(); ctx.fill();
      ctx.fillText(`Motion (action)`, rocketX + 110, ey - 12);
      ctx.fillStyle = '#475569'; ctx.font = 'bold 10px monospace'; ctx.textAlign = 'left';
      ctx.fillText(`a=${a2.toFixed(2)} m/s²  (gas ejected backward, rocket pushed forward)`, 10, 20);
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
