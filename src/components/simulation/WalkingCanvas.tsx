'use client';
import { useRef, useEffect, useCallback } from 'react';

interface Props {
  isRunning: boolean; isPaused: boolean;
  frictionEnabled: boolean; surfaceMass: number;
  width?: number; height?: number;
}

export function WalkingCanvas({ isRunning, isPaused, frictionEnabled, width = 680, height = 220 }: Props) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const rafRef = useRef<number>(0);
  const tRef = useRef(0);
  const xRef = useRef(100);
  const lastFrameRef = useRef<number | null>(null);
  const simRef = useRef({ isRunning, isPaused, frictionEnabled });
  simRef.current = { isRunning, isPaused, frictionEnabled };

  useEffect(() => { tRef.current = 0; xRef.current = 100; lastFrameRef.current = null; }, [frictionEnabled]);

  const draw = useCallback((timestamp?: number) => {
    const canvas = canvasRef.current; if (!canvas) return;
    const ctx = canvas.getContext('2d'); if (!ctx) return;
    const { isRunning: r, isPaused: p, frictionEnabled: fr } = simRef.current;
    const W = canvas.width, H = canvas.height;

    let dt = 0;
    if (r && !p && timestamp !== undefined) {
      if (lastFrameRef.current !== null) {
        dt = Math.min((timestamp - lastFrameRef.current) / 1000, 0.1);
      }
      lastFrameRef.current = timestamp;
    } else {
      lastFrameRef.current = timestamp ?? null;
    }
    if (dt > 0) {
      tRef.current += dt * 1.5; // matches the original leg-swing pacing
      if (fr) {
        xRef.current += dt * 108; // ~1.8px/frame at 60fps, now real-time
        if (xRef.current > W - 100) xRef.current = 100; // loop back for a continuous demo
      }
    }

    const t = tRef.current;
    const x = xRef.current;
    const groundY = H - 50;

    ctx.clearRect(0, 0, W, H);

    // Sky
    ctx.fillStyle = '#f0f6ff'; ctx.fillRect(0, 0, W, groundY);
    // Ground
    ctx.fillStyle = '#e2e8f0'; ctx.fillRect(0, groundY, W, H - groundY);
    ctx.beginPath(); ctx.moveTo(0, groundY); ctx.lineTo(W, groundY);
    ctx.strokeStyle = '#94a3b8'; ctx.lineWidth = 2; ctx.stroke();

    // Surface label
    ctx.fillStyle = '#94a3b8'; ctx.font = '10px system-ui'; ctx.textAlign = 'center';
    if (!fr) {
      ctx.fillText('ICE — frictionless (no grip, no walking)', W / 2, H - 10);
      // Ice texture
      for (let ix = 0; ix < W; ix += 30) {
        ctx.strokeStyle = 'rgba(147,197,253,0.5)'; ctx.lineWidth = 1;
        ctx.beginPath(); ctx.moveTo(ix, groundY); ctx.lineTo(ix + 15, groundY + 8); ctx.stroke();
      }
    } else {
      ctx.fillText('Normal ground — friction provides forward push', W / 2, H - 10);
    }

    // Walking person (stick figure with leg animation)
    const py = groundY;
    const legAngle = Math.sin(t * 4) * 0.5;

    // Body
    ctx.strokeStyle = '#4f46e5'; ctx.lineWidth = 3;
    ctx.beginPath(); ctx.moveTo(x, py - 80); ctx.lineTo(x, py - 40); ctx.stroke();
    // Head
    ctx.fillStyle = '#f9a8d4'; ctx.beginPath(); ctx.arc(x, py - 92, 12, 0, Math.PI * 2); ctx.fill();
    ctx.strokeStyle = '#ec4899'; ctx.lineWidth = 1.5; ctx.stroke();
    // Arms
    ctx.strokeStyle = '#4f46e5'; ctx.lineWidth = 2.5;
    ctx.beginPath();
    ctx.moveTo(x, py - 70); ctx.lineTo(x + Math.cos(legAngle + 1) * 25, py - 50);
    ctx.moveTo(x, py - 70); ctx.lineTo(x - Math.cos(legAngle + 1) * 25, py - 50);
    ctx.stroke();
    // Legs
    const legLen = 35;
    const footAngle = legAngle * 0.8;
    ctx.beginPath();
    ctx.moveTo(x, py - 40);
    ctx.lineTo(x + Math.sin(footAngle) * legLen, py - 10);
    ctx.lineTo(x + Math.sin(footAngle) * legLen + 10, py);
    ctx.moveTo(x, py - 40);
    ctx.lineTo(x - Math.sin(footAngle) * legLen, py - 10);
    ctx.lineTo(x - Math.sin(footAngle) * legLen + 10, py);
    ctx.strokeStyle = '#4f46e5'; ctx.lineWidth = 2.5; ctx.stroke();

    // Force arrows
    if (fr && r) {
      const pushY = py - 10;
      // Foot pushes ground backward (action) — red arrow leftward from foot
      const footX = x + Math.sin(footAngle) * legLen + 10;
      ctx.save();
      ctx.strokeStyle = '#ef4444'; ctx.lineWidth = 2;
      ctx.beginPath(); ctx.moveTo(footX, pushY); ctx.lineTo(footX - 55, pushY); ctx.stroke();
      ctx.fillStyle = '#ef4444';
      ctx.beginPath(); ctx.moveTo(footX - 55, pushY);
      ctx.lineTo(footX - 45, pushY - 5); ctx.lineTo(footX - 45, pushY + 5);
      ctx.closePath(); ctx.fill();
      ctx.font = '9px system-ui'; ctx.textAlign = 'center';
      ctx.fillText('Foot on ground', footX - 28, pushY - 8);
      ctx.fillText('(action ←)', footX - 28, pushY + 14);

      // Ground pushes person forward (reaction) — green arrow rightward on person
      ctx.strokeStyle = '#10b981'; ctx.lineWidth = 2;
      ctx.beginPath(); ctx.moveTo(x - 30, py - 45); ctx.lineTo(x + 35, py - 45); ctx.stroke();
      ctx.fillStyle = '#10b981';
      ctx.beginPath(); ctx.moveTo(x + 35, py - 45);
      ctx.lineTo(x + 25, py - 50); ctx.lineTo(x + 25, py - 40);
      ctx.closePath(); ctx.fill();
      ctx.fillText('Ground on person', x + 5, py - 52);
      ctx.fillText('(reaction →)', x + 5, py - 35);
      ctx.restore();
    }

    if (!fr && r) {
      // Feet slipping
      ctx.fillStyle = '#ef4444'; ctx.font = '11px system-ui'; ctx.textAlign = 'center';
      ctx.fillText('No friction → no reaction force → cannot walk!', x, py - 110);
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
