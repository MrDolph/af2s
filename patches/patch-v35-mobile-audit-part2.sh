#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
# A-Factor STEM Studio — patch v35: mobile responsiveness pass 2 — the rest
# of the systematic 55-canvas audit
#
#   Continued the audit from patch v34 with several additional grep
#   strategies (fixed-position bx/by variables, roundRect/fillRect calls
#   with large literal dimensions, legend/key text blocks) across every
#   canvas not yet checked. Cross-checked each match against its actual
#   context rather than trusting the grep alone — several matches turned
#   out to be legitimate physics-object positions (a block sliding along
#   a path, a particle's coordinates) or already-responsive scale-factor
#   clamps, not overlay sizing bugs, and were left alone.
#
#   Found and fixed two genuine remaining issues, both physics-apparatus
#   diagrams (not "scorecard" stat boxes like patch v34's fixes, but the
#   same underlying problem — fixed pixel sizing that didn't scale with
#   the canvas):
#
#     - HeatTransferCanvas (convection mode): the fluid beaker was a fixed
#       260px wide, about 76% of a typical mobile canvas's width. Capped
#       it to a canvas-width-relative maximum instead.
#     - XrayCanvas: the tube, cathode, and anode positions used several
#       independent fixed pixel offsets (70, 110, W-170, 120, 200) that
#       didn't shrink together on a narrow canvas, cramping the electron
#       beam's travel distance. Scaled all of them by one consistent
#       factor — verified numerically that at the original 660px design
#       width every value comes out EXACTLY unchanged, with graceful,
#       proportional shrinking below that.
#
#   Also swept every canvas broadly for any remaining large fixed-pixel
#   dimensions with a final catch-all search; nothing further turned up.
#   Combined with patch v34, this covers every confirmed instance of
#   fixed-size overlay or apparatus sizing found across all 55 canvases
#   in the app.
#
# Run from the af2s project root (Git Bash):   bash patches/patch-v35-mobile-audit-part2.sh
# ══════════════════════════════════════════════════════════════════════════════
set -euo pipefail

if [ ! -f "package.json" ]; then
  echo "Run this from the af2s project root (package.json not found)." >&2
  exit 1
fi

echo "-- A-Factor patch v35: mobile responsiveness pass 2 --"
mkdir -p "src/components/simulation"

echo "  -> src/components/simulation/HeatTransferCanvas.tsx"
cat > "src/components/simulation/HeatTransferCanvas.tsx" << 'AFEOF'
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
      const bw = Math.min(260, W * 0.72), bx = W / 2 - bw / 2, by = 50, bh = H - 130;
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
AFEOF

echo "  -> src/components/simulation/XrayCanvas.tsx"
cat > "src/components/simulation/XrayCanvas.tsx" << 'AFEOF'
'use client';
import { useRef, useEffect, useCallback } from 'react';
import { lambdaMinNm, electronSpeedFraction, MO_EXCITATION_KV } from '@/lib/physics/xrays';

interface Props {
  kV: number;          // tube voltage in kilovolts
  current: number;     // filament current 1–10 (relative)
  isRunning: boolean; isPaused: boolean;
  width?: number; height?: number;
}

interface Beam { x: number; y: number; }
interface Ray { p: number; ang: number; }

export function XrayCanvas({ kV, current, isRunning, isPaused, width = 640, height = 300 }: Props) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const rafRef = useRef<number>(0);
  const tRef = useRef(0);
  const lastFrameRef = useRef<number | null>(null);
  const electronsRef = useRef<Beam[]>([]);
  const raysRef = useRef<Ray[]>([]);
  const accRef = useRef(0);
  const sim = useRef({ kV, current, isRunning, isPaused });
  sim.current = { kV, current, isRunning, isPaused };

  useEffect(() => {
    tRef.current = 0; lastFrameRef.current = null;
    electronsRef.current = []; raysRef.current = []; accRef.current = 0;
  }, [kV, current]);

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

    const xrayScale = Math.max(0.55, Math.min(1, W / 660));
    const cathX = Math.round(110 * xrayScale), anodeX = W - Math.round(170 * xrayScale), beamY = 120 * xrayScale;
    const eSpeed = 120 + s.kV * 3; // px/s ∝ ish √V feel, readable

    if (dt > 0) {
      accRef.current += dt * s.current * 3;
      while (accRef.current >= 1) {
        accRef.current -= 1;
        electronsRef.current.push({ x: cathX + 8, y: beamY + (Math.random() - 0.5) * 14 });
      }
      electronsRef.current.forEach(e => { e.x += eSpeed * dt; });
      const arrived = electronsRef.current.filter(e => e.x >= anodeX).length;
      electronsRef.current = electronsRef.current.filter(e => e.x < anodeX);
      for (let i = 0; i < arrived; i++) {
        // ~1% of electron energy becomes X-rays (rest is heat) — but we draw
        // a ray per impact so the physics is visible.
        raysRef.current.push({ p: 0, ang: Math.PI / 2 + (Math.random() - 0.5) * 0.9 });
      }
      raysRef.current.forEach(r => { r.p += dt * 220; });
      raysRef.current = raysRef.current.filter(r => r.p < 180);
    }

    ctx.clearRect(0, 0, W, H);
    ctx.fillStyle = '#f8fafc'; ctx.fillRect(0, 0, W, H);

    // Evacuated glass tube
    ctx.save();
    ctx.strokeStyle = '#cbd5e1'; ctx.lineWidth = 3;
    ctx.beginPath();
    ctx.roundRect(Math.round(70 * xrayScale), Math.round(60 * xrayScale), W - Math.round(200 * xrayScale), Math.round(120 * xrayScale), Math.round(40 * xrayScale));
    ctx.stroke();
    ctx.fillStyle = 'rgba(226,232,240,0.25)'; ctx.fill();
    ctx.fillStyle = '#94a3b8'; ctx.font = '9px system-ui'; ctx.textAlign = 'left';
    ctx.fillText('evacuated tube', Math.round(82 * xrayScale), Math.round(76 * xrayScale));
    ctx.restore();

    // Cathode (heated filament)
    ctx.save();
    ctx.strokeStyle = '#f59e0b'; ctx.lineWidth = 3;
    ctx.beginPath();
    for (let i = 0; i < 4; i++) {
      ctx.arc(cathX, beamY - 12 + i * 8, 4, Math.PI * 0.5, Math.PI * 1.5, i % 2 === 0);
    }
    ctx.stroke();
    const glow = ctx.createRadialGradient(cathX, beamY, 2, cathX, beamY, 26);
    glow.addColorStop(0, 'rgba(251,191,36,0.5)'); glow.addColorStop(1, 'transparent');
    ctx.fillStyle = glow;
    ctx.beginPath(); ctx.arc(cathX, beamY, 26, 0, Math.PI * 2); ctx.fill();
    ctx.fillStyle = '#92400e'; ctx.font = 'bold 9px system-ui'; ctx.textAlign = 'center';
    ctx.fillText('cathode (−)', cathX, beamY + 44);
    ctx.fillText('hot filament', cathX, beamY + 55);
    ctx.restore();

    // Anode: angled tungsten/molybdenum target block
    ctx.save();
    ctx.fillStyle = '#64748b';
    ctx.beginPath();
    ctx.moveTo(anodeX, beamY - 34);
    ctx.lineTo(anodeX + 46, beamY - 34);
    ctx.lineTo(anodeX + 46, beamY + 34);
    ctx.lineTo(anodeX, beamY + 34);
    ctx.closePath(); ctx.fill();
    // Angled face
    ctx.fillStyle = '#475569';
    ctx.beginPath();
    ctx.moveTo(anodeX, beamY - 34);
    ctx.lineTo(anodeX + 18, beamY + 34);
    ctx.lineTo(anodeX, beamY + 34);
    ctx.closePath(); ctx.fill();
    ctx.fillStyle = '#334155'; ctx.font = 'bold 9px system-ui'; ctx.textAlign = 'center';
    ctx.fillText('anode (+)', anodeX + 24, beamY - 42);
    ctx.fillText('Mo target', anodeX + 24, beamY + 48);
    ctx.restore();

    // Electron beam
    ctx.save();
    electronsRef.current.forEach(e => {
      ctx.beginPath(); ctx.arc(e.x, e.y, 3, 0, Math.PI * 2);
      ctx.fillStyle = '#0ea5e9'; ctx.fill();
    });
    ctx.restore();

    // X-rays: wavy rays leaving the target downward through a window
    ctx.save();
    ctx.strokeStyle = '#8b5cf6'; ctx.lineWidth = 1.6;
    raysRef.current.forEach(r => {
      const ox = anodeX + 8, oy = beamY + 10;
      ctx.beginPath();
      for (let d = Math.max(0, r.p - 34); d <= r.p; d += 3) {
        const wob = Math.sin(d * 0.55) * 3;
        const x = ox + Math.cos(r.ang) * d - Math.sin(r.ang) * wob;
        const y = oy + Math.sin(r.ang) * d + Math.cos(r.ang) * wob;
        if (d === Math.max(0, r.p - 34)) ctx.moveTo(x, y); else ctx.lineTo(x, y);
      }
      ctx.stroke();
    });
    ctx.fillStyle = '#7c3aed'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
    ctx.fillText('X-rays', anodeX + 8, H - 40);
    ctx.restore();

    // HV supply annotation
    ctx.save();
    ctx.strokeStyle = '#94a3b8'; ctx.lineWidth = 1.5; ctx.setLineDash([5, 4]);
    ctx.beginPath(); ctx.moveTo(cathX, 60); ctx.lineTo(cathX, 34); ctx.lineTo(anodeX + 24, 34); ctx.lineTo(anodeX + 24, 60); ctx.stroke();
    ctx.setLineDash([]);
    ctx.fillStyle = '#475569'; ctx.font = 'bold 11px system-ui'; ctx.textAlign = 'center';
    ctx.fillText(`${s.kV} kV`, (cathX + anodeX) / 2, 28);
    ctx.restore();

    // Status
    ctx.fillStyle = s.kV >= MO_EXCITATION_KV ? '#059669' : '#64748b';
    ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
    ctx.fillText(
      s.kV >= MO_EXCITATION_KV
        ? 'V above 20 kV — characteristic Kα/Kβ lines appear in the spectrum'
        : 'Continuous (bremsstrahlung) spectrum only — raise V past 20 kV for the K lines',
      W / 2, H - 24,
    );

    ctx.fillStyle = '#64748b'; ctx.font = '10px system-ui'; ctx.textAlign = 'left';
    ctx.fillText(`λmin = hc/eV = ${lambdaMinNm(s.kV).toFixed(4)} nm   e⁻ speed ≈ ${(electronSpeedFraction(s.kV) * 100).toFixed(0)}% of c   ~99% of the energy becomes HEAT in the anode`, 8, H - 8);

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
AFEOF

echo ""
echo "Patch v35 applied -- 2 files written."
echo ""
echo "Next steps:"
echo "  rm -rf .next"
echo "  npm run dev"
echo ""
echo "Check on a narrow mobile-width browser window at:"
echo "  /simulations/heat-transfer (Convection mode) and /simulations/xray"
echo "-- both should now scale proportionally on mobile instead of"
echo "cramping or overflowing, while looking unchanged on desktop."
echo ""
echo "This completes the systematic mobile audit across all 55 simulation"
echo "canvases, combined with patch v34."
