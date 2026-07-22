'use client';
import { useRef, useEffect, useCallback } from 'react';

export type HeatMode = 'conduction' | 'convection' | 'radiation';

interface Props {
  mode: HeatMode;
  hotTemp: number;    // °C
  coldTemp: number;   // °C
  isRunning: boolean; isPaused: boolean;
  width?: number; height?: number;
}

// Temperature → colour (blue 0° → red 100°+)
function tempColor(tc: number, alpha = 1): string {
  const t = Math.min(1, Math.max(0, tc / 120));
  const r = Math.round(59 + t * (239 - 59));
  const g = Math.round(130 - t * (130 - 68));
  const b = Math.round(246 - t * (246 - 68));
  return `rgba(${r},${g},${b},${alpha})`;
}

function flame(ctx: CanvasRenderingContext2D, x: number, y: number, t: number) {
  ctx.save();
  for (let i = 0; i < 3; i++) {
    const wob = Math.sin(t * 7 + i * 2) * 3;
    const h = 20 + i * -5 + Math.sin(t * 9 + i) * 3;
    ctx.beginPath();
    ctx.moveTo(x - 8 + i * 8 + wob, y);
    ctx.quadraticCurveTo(x - 8 + i * 8 + wob - 5, y - h / 2, x - 8 + i * 8 + wob, y - h);
    ctx.quadraticCurveTo(x - 8 + i * 8 + wob + 5, y - h / 2, x - 8 + i * 8 + wob, y);
    ctx.fillStyle = i === 1 ? '#f59e0b' : '#ef4444';
    ctx.globalAlpha = 0.85;
    ctx.fill();
  }
  ctx.restore();
}

export function HeatTransferCanvas({ mode, hotTemp, coldTemp, isRunning, isPaused, width = 640, height = 300 }: Props) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const rafRef = useRef<number>(0);
  const tRef = useRef(0);
  const lastFrameRef = useRef<number | null>(null);
  const warmthRef = useRef(0); // radiation target warming 0→1
  const sim = useRef({ mode, hotTemp, coldTemp, isRunning, isPaused });
  sim.current = { mode, hotTemp, coldTemp, isRunning, isPaused };

  useEffect(() => {
    tRef.current = 0; lastFrameRef.current = null; warmthRef.current = 0;
  }, [mode, hotTemp, coldTemp]);

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
    const t = tRef.current;

    ctx.clearRect(0, 0, W, H);
    ctx.fillStyle = '#f8fafc'; ctx.fillRect(0, 0, W, H);

    if (s.mode === 'conduction') {
      // Metal rod, hot left → cold right; particles vibrate harder where hotter.
      const rodY = H / 2 - 20, rodH = 56, rodX = 80, rodW = W - 160;
      const grad = ctx.createLinearGradient(rodX, 0, rodX + rodW, 0);
      grad.addColorStop(0, tempColor(s.hotTemp, 0.35));
      grad.addColorStop(1, tempColor(s.coldTemp, 0.35));
      ctx.fillStyle = grad;
      ctx.fillRect(rodX, rodY, rodW, rodH);
      ctx.strokeStyle = '#94a3b8'; ctx.lineWidth = 2;
      ctx.strokeRect(rodX, rodY, rodW, rodH);
      // Particles: fixed lattice positions, vibration amplitude ∝ local T.
      // Energy passes along WITHOUT the particles migrating — that is conduction.
      const cols = 22, rows = 3;
      for (let c = 0; c < cols; c++) {
        const frac = c / (cols - 1);
        const localT = s.hotTemp + (s.coldTemp - s.hotTemp) * frac;
        // The "wave" of vibration spreads left→right over time
        const reached = t * 4 > frac * 10;
        const amp = reached ? 1.5 + (localT / 120) * 5 : 1;
        for (let r = 0; r < rows; r++) {
          const x0 = rodX + 16 + c * ((rodW - 32) / (cols - 1));
          const y0 = rodY + 14 + r * ((rodH - 28) / (rows - 1));
          const jx = Math.sin(t * (9 + c) + r * 2) * amp;
          const jy = Math.cos(t * (11 + c * 0.7) + r) * amp;
          ctx.beginPath(); ctx.arc(x0 + jx, y0 + jy, 3.4, 0, Math.PI * 2);
          ctx.fillStyle = tempColor(localT); ctx.fill();
        }
      }
      flame(ctx, rodX + 8, rodY + rodH + 44, t);
      ctx.fillStyle = '#475569'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
      ctx.fillText(`HOT ${s.hotTemp}°C`, rodX + 20, rodY - 10);
      ctx.fillText(`COLD ${s.coldTemp}°C`, rodX + rodW - 24, rodY - 10);
      ctx.fillStyle = '#64748b'; ctx.font = '10px system-ui';
      ctx.fillText('Particles vibrate harder and pass energy along — they do NOT move down the rod', W / 2, H - 26);
    }

    if (s.mode === 'convection') {
      // Beaker of fluid with a circulation loop; heated at bottom-left.
      const bx = W / 2 - 130, by = 50, bw = 260, bh = H - 130;
      ctx.fillStyle = 'rgba(186,230,253,0.4)';
      ctx.fillRect(bx, by, bw, bh);
      ctx.strokeStyle = '#94a3b8'; ctx.lineWidth = 2;
      ctx.beginPath();
      ctx.moveTo(bx, by); ctx.lineTo(bx, by + bh); ctx.lineTo(bx + bw, by + bh); ctx.lineTo(bx + bw, by);
      ctx.stroke();
      // Particles circulate on an ellipse: rise on the heated left, sink right.
      const cxm = bx + bw / 2, cym = by + bh / 2;
      const rx = bw / 2 - 30, ry = bh / 2 - 24;
      const N = 26;
      for (let i = 0; i < N; i++) {
        const phase = (i / N) * Math.PI * 2 + t * 0.8;
        // parametric loop: angle 0 = bottom-left rising
        const px = cxm - Math.cos(phase) * rx;
        const py = cym + Math.sin(phase) * ry * (Math.cos(phase) > 0 ? 1 : 1);
        const yFrac = (py - by) / bh;            // 0 top … 1 bottom
        const rising = Math.sin(phase) < 0 ? false : true;
        void rising;
        const localT = s.hotTemp * (1 - yFrac) * 0.4 + (yFrac > 0.7 && px < cxm ? s.hotTemp : s.coldTemp + (s.hotTemp - s.coldTemp) * (1 - yFrac) * 0.6);
        ctx.beginPath(); ctx.arc(px, py, 4.5, 0, Math.PI * 2);
        ctx.fillStyle = tempColor(Math.min(localT, 110)); ctx.fill();
      }
      // Loop arrows
      ctx.save();
      ctx.strokeStyle = 'rgba(100,116,139,0.5)'; ctx.lineWidth = 1.5; ctx.setLineDash([5, 4]);
      ctx.beginPath(); ctx.ellipse(cxm, cym, rx, ry, 0, 0, Math.PI * 2); ctx.stroke();
      ctx.restore();
      ctx.fillStyle = '#ef4444'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
      ctx.fillText('warm, less dense → RISES', bx - 4, cym - 8);
      ctx.fillStyle = '#3b82f6';
      ctx.fillText('cool, denser → SINKS', bx + bw + 6, cym - 8);
      flame(ctx, bx + 50, by + bh + 44, t);
      ctx.fillStyle = '#64748b'; ctx.font = '10px system-ui';
      ctx.fillText('A convection current: the FLUID ITSELF moves, carrying the energy', W / 2, H - 26);
    }

    if (s.mode === 'radiation') {
      // Heater/Sun on the left radiating across a vacuum to an object.
      const sx = 90, sy = H / 2 - 12;
      warmthRef.current = Math.min(1, warmthRef.current + dt * 0.12 * (s.hotTemp / 100));
      // Sun
      const sun = ctx.createRadialGradient(sx, sy, 4, sx, sy, 34);
      sun.addColorStop(0, '#fde047'); sun.addColorStop(1, '#f59e0b');
      ctx.beginPath(); ctx.arc(sx, sy, 30, 0, Math.PI * 2);
      ctx.fillStyle = sun; ctx.fill();
      // Rays: wavy IR arrows travelling right
      ctx.save();
      ctx.strokeStyle = '#f97316'; ctx.lineWidth = 1.6;
      for (let r = -2; r <= 2; r++) {
        const y0 = sy + r * 26;
        const speed = 130;
        const head = (t * speed) % (W - 220);
        ctx.beginPath();
        for (let d = 0; d <= head; d += 4) {
          const x = sx + 40 + d;
          const y = y0 + Math.sin(d * 0.25 - t * 6) * 5;
          if (d === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
        }
        ctx.stroke();
      }
      ctx.restore();
      // Vacuum label
      ctx.fillStyle = '#94a3b8'; ctx.font = 'italic 10px system-ui'; ctx.textAlign = 'center';
      ctx.fillText('VACUUM — no particles needed', W / 2, 40);
      // Object warming up
      const ox = W - 130, oy = H / 2 - 40, ow = 60, oh = 80;
      const objT = s.coldTemp + (s.hotTemp - s.coldTemp) * warmthRef.current * 0.7;
      ctx.fillStyle = tempColor(objT, 0.8);
      ctx.fillRect(ox, oy, ow, oh);
      ctx.strokeStyle = '#64748b'; ctx.lineWidth = 2; ctx.strokeRect(ox, oy, ow, oh);
      ctx.fillStyle = '#334155'; ctx.font = 'bold 10px system-ui';
      ctx.fillText(`${objT.toFixed(0)}°C`, ox + ow / 2, oy + oh / 2 + 4);
      ctx.fillText('absorber', ox + ow / 2, oy + oh + 16);
      ctx.fillStyle = '#64748b'; ctx.font = '10px system-ui';
      ctx.fillText('Infrared electromagnetic waves — the ONLY mode that crosses empty space (Sun → Earth)', W / 2, H - 26);
    }

    ctx.fillStyle = '#64748b'; ctx.font = '10px system-ui'; ctx.textAlign = 'left';
    ctx.fillText(`t = ${t.toFixed(1)}s`, 8, H - 8);

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
