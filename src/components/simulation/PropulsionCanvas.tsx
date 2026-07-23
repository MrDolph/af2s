'use client';
import { useRef, useEffect, useCallback } from 'react';
import { rocketStateAt, rocketBurnTime } from '@/lib/physics/consequences';

interface Props {
  rocketMass: number; fuelFraction: number; exhaustSpeed: number; massFlowRate: number;
  isRunning: boolean; isPaused: boolean;
  onTick?: (simTime: number, v: number, burnedOut: boolean) => void;
  width?: number; height?: number;
}

const TARGET_REAL_SECONDS = 18; // any slider combination plays out in about this long

interface Star { x: number; y: number; speed: number; }

export function PropulsionCanvas({
  rocketMass, fuelFraction, exhaustSpeed, massFlowRate, isRunning, isPaused, onTick,
  width = 660, height = 260,
}: Props) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const rafRef = useRef<number>(0);
  const lastFrameRef = useRef<number | null>(null);
  const simTime = useRef(0);       // compressed "mission" time fed into the physics
  const starsRef = useRef<Star[]>([]);
  const simRef = useRef({ rocketMass, fuelFraction, exhaustSpeed, massFlowRate, isRunning, isPaused, onTick });
  simRef.current = { rocketMass, fuelFraction, exhaustSpeed, massFlowRate, isRunning, isPaused, onTick };

  useEffect(() => {
    simTime.current = 0;
    lastFrameRef.current = null;
    starsRef.current = Array.from({ length: 40 }, () => ({
      x: Math.random(), y: Math.random(), speed: 0.4 + Math.random() * 0.8,
    }));
  }, [rocketMass, fuelFraction, exhaustSpeed, massFlowRate]);

  const draw = useCallback((timestamp?: number) => {
    const canvas = canvasRef.current; if (!canvas) return;
    const ctx = canvas.getContext('2d'); if (!ctx) return;
    const { rocketMass: m, fuelFraction: ff, exhaustSpeed: ve, massFlowRate: mdot, isRunning: r, isPaused: pa, onTick: ot } = simRef.current;
    const W = canvas.width, H = canvas.height;

    const dryMass = m * (1 - ff);
    const fuelMass = m * ff;
    const burnTime = rocketBurnTime(fuelMass, mdot);
    const compression = Math.max(1, burnTime / TARGET_REAL_SECONDS);

    if (r && !pa && timestamp !== undefined) {
      if (lastFrameRef.current !== null) {
        const realDt = Math.min((timestamp - lastFrameRef.current) / 1000, 0.1);
        simTime.current += realDt * compression;
      }
      lastFrameRef.current = timestamp;
    } else {
      lastFrameRef.current = timestamp ?? null;
    }

    const state = rocketStateAt(simTime.current, dryMass, fuelMass, ve, mdot);
    ot?.(state.t, state.v, state.burnedOut);

    // ── Scene ──────────────────────────────────────────────────────────────
    ctx.clearRect(0, 0, W, H);
    const sky = ctx.createLinearGradient(0, 0, 0, H);
    sky.addColorStop(0, '#0f172a'); sky.addColorStop(1, '#1e293b');
    ctx.fillStyle = sky; ctx.fillRect(0, 0, W, H);

    // Starfield streams past faster as speed increases — a visual proxy for
    // "the rocket is now moving faster" without needing it to fly off-screen
    // at velocities that can reach thousands of m/s.
    const streamSpeed = 0.002 + Math.min(state.v / 3000, 1) * 0.03;
    ctx.fillStyle = 'white';
    starsRef.current.forEach(s => {
      if (r && !pa) {
        s.x -= streamSpeed * s.speed;
        if (s.x < 0) { s.x = 1; s.y = Math.random(); }
      }
      const size = 0.8 + s.speed;
      ctx.globalAlpha = 0.5 + s.speed * 0.4;
      ctx.fillRect(s.x * W, s.y * H, size, size);
    });
    ctx.globalAlpha = 1;

    // Rocket, centred, nose pointing right
    const cx = W * 0.42, cy = H / 2;
    const bodyW = 70, bodyH = 34;

    // Exhaust flame — length/intensity track current thrust, vanishes at burnout
    if (!state.burnedOut && r) {
      const flameLen = 20 + (state.thrust / (ve * mdot || 1)) * 55;
      const flicker = Math.sin(simTime.current * 24) * 4;
      const grad = ctx.createLinearGradient(cx - bodyW / 2, cy, cx - bodyW / 2 - flameLen, cy);
      grad.addColorStop(0, 'rgba(253,224,71,0.95)');
      grad.addColorStop(0.5, 'rgba(251,146,60,0.85)');
      grad.addColorStop(1, 'rgba(239,68,68,0)');
      ctx.fillStyle = grad;
      ctx.beginPath();
      ctx.moveTo(cx - bodyW / 2, cy - 10);
      ctx.lineTo(cx - bodyW / 2 - flameLen - flicker, cy);
      ctx.lineTo(cx - bodyW / 2, cy + 10);
      ctx.closePath(); ctx.fill();
    }

    // Body
    const bodyGrad = ctx.createLinearGradient(cx, cy - bodyH / 2, cx, cy + bodyH / 2);
    bodyGrad.addColorStop(0, '#e0e7ff'); bodyGrad.addColorStop(1, '#a5b4fc');
    ctx.fillStyle = bodyGrad;
    ctx.beginPath();
    ctx.roundRect(cx - bodyW / 2, cy - bodyH / 2, bodyW, bodyH, 6);
    ctx.fill();
    ctx.strokeStyle = '#4338ca'; ctx.lineWidth = 1.5; ctx.stroke();
    // Nose cone
    ctx.fillStyle = '#818cf8';
    ctx.beginPath();
    ctx.moveTo(cx + bodyW / 2, cy - bodyH / 2);
    ctx.lineTo(cx + bodyW / 2 + 22, cy);
    ctx.lineTo(cx + bodyW / 2, cy + bodyH / 2);
    ctx.closePath(); ctx.fill();
    ctx.fillStyle = '#312e81'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
    ctx.fillText(`${state.mass.toFixed(0)}kg`, cx, cy + 4);

    // Fuel gauge
    const gx = 16, gy = H - 26, gw = 90, gh = 8;
    ctx.fillStyle = 'rgba(255,255,255,0.15)';
    ctx.beginPath(); ctx.roundRect(gx, gy, gw, gh, 4); ctx.fill();
    ctx.fillStyle = state.fuelFraction > 0.2 ? '#34d399' : '#f87171';
    ctx.beginPath(); ctx.roundRect(gx, gy, gw * Math.max(0, state.fuelFraction), gh, 4); ctx.fill();
    ctx.fillStyle = '#cbd5e1'; ctx.font = '9px system-ui'; ctx.textAlign = 'left';
    ctx.fillText(`Fuel ${(state.fuelFraction * 100).toFixed(0)}%`, gx, gy - 4);

    // HUD
    ctx.textAlign = 'right';
    const hud = [
      `T+${state.t.toFixed(1)}s`,
      `v = ${state.v.toFixed(1)} m/s`,
      `a = ${state.acceleration.toFixed(2)} m/s²`,
      `Thrust = ${state.thrust.toFixed(0)} N`,
    ];
    ctx.font = 'bold 10px monospace'; ctx.fillStyle = '#e0e7ff';
    hud.forEach((line, i) => ctx.fillText(line, W - 12, 18 + i * 15));

    if (state.burnedOut) {
      ctx.textAlign = 'center'; ctx.font = 'bold 11px system-ui'; ctx.fillStyle = '#fbbf24';
      ctx.fillText('🔥 Engine cutoff — coasting at constant velocity (Newton\u2019s 1st Law)', W / 2, H - 10);
    }

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
