#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
# A-Factor STEM Studio -- patch v57: fix a genuinely backwards direction
# in the Ohm's Law & Circuits electron-flow / conventional-current toggle
#
#   ROOT CAUSE, TRACED AND VERIFIED NUMERICALLY. The battery symbol draws
#   its + terminal (the long plate) on the LEFT and its - terminal (the
#   short plate) on the RIGHT. Traced the actual wire-loop path
#   coordinates against these terminal positions: the path's own natural
#   drawing order starts near the + terminal, goes the LONG way around
#   the external circuit (through the resistor, left to right), and
#   arrives back near the - terminal. That is exactly CONVENTIONAL
#   CURRENT's direction (+ -> external circuit -> -) -- but the code had
#   this direction labelled "electron flow", and the reversed direction
#   labelled "conventional current". The two were swapped everywhere:
#   Ohm's law, Series, Parallel (every branch), and Non-ohmic modes all
#   used the same shared drawing function, so all of them had this
#   backwards in the same way.
#
#   FIXED and reverified: conventional current (dir=+1) now traces
#   + terminal -> external circuit -> - terminal, moving LEFT-TO-RIGHT
#   through the resistor -- correct. Electron flow (dir=-1) now traces
#   - terminal -> external circuit -> + terminal, moving RIGHT-TO-LEFT
#   through the resistor -- correct, and a genuine mirror image of the
#   conventional-current path, exactly matching "electrons flow opposite
#   to conventional current" without exception.
#
# Run from the af2s project root (Git Bash):   bash patches/patch-v57-circuits-flow-direction-fix.sh
# ══════════════════════════════════════════════════════════════════════════════
set -euo pipefail

if [ ! -f "package.json" ]; then
  echo "Run this from the af2s project root (package.json not found)." >&2
  exit 1
fi

echo "-- A-Factor patch v57: fix backwards electron/conventional current direction --"
mkdir -p "src/components/simulation"

echo "  -> src/components/simulation/CircuitCanvas.tsx"
cat > "src/components/simulation/CircuitCanvas.tsx" << 'AFEOF'
'use client';
import { useRef, useEffect, useCallback } from 'react';
import {
  seriesAnalysis, parallelAnalysis, ohmCurrent,
  nonOhmicCurrent, nonOhmicCalibration, NonOhmicDevice,
} from '@/lib/physics/circuits';

export type CircuitMode = 'ohm' | 'series' | 'parallel' | 'non-ohmic';
export type FlowDisplay = 'electron' | 'conventional';

interface Props {
  mode: CircuitMode;
  voltage: number;
  r1: number; r2: number; r3: number;
  nonOhmicDevice: NonOhmicDevice;
  flowDisplay: FlowDisplay;
  isRunning: boolean; isPaused: boolean;
  width?: number; height?: number;
}

// Draw a resistor zig-zag along a horizontal segment.
function drawResistor(ctx: CanvasRenderingContext2D, x: number, y: number, len: number, label: string, value: number, vertical = false) {
  const teeth = 6, amp = 7;
  ctx.save();
  ctx.translate(x, y);
  if (vertical) ctx.rotate(Math.PI / 2);
  ctx.strokeStyle = '#475569'; ctx.lineWidth = 2;
  ctx.beginPath(); ctx.moveTo(0, 0);
  const seg = len / (teeth + 1);
  ctx.lineTo(seg / 2, 0);
  for (let i = 0; i < teeth; i++) {
    ctx.lineTo(seg / 2 + seg * i + seg / 2, i % 2 === 0 ? -amp : amp);
  }
  ctx.lineTo(len - seg / 2, 0); ctx.lineTo(len, 0);
  ctx.stroke();
  ctx.restore();
  ctx.save();
  ctx.fillStyle = '#334155'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
  if (vertical) ctx.fillText(`${label}=${value}Ω`, x + 24, y + len / 2 + 3);
  else ctx.fillText(`${label}=${value}Ω`, x + len / 2, y - 14);
  ctx.restore();
}

// Filament lamp symbol: circle with a filament cross inside — the
// standard, recognisable IEC-style lamp symbol.
function drawLamp(ctx: CanvasRenderingContext2D, x: number, y: number, len: number, glow: number) {
  const cx = x + len / 2, r = 16;
  ctx.strokeStyle = '#475569'; ctx.lineWidth = 2;
  ctx.beginPath(); ctx.moveTo(x, y); ctx.lineTo(cx - r, y); ctx.stroke();
  ctx.beginPath(); ctx.moveTo(cx + r, y); ctx.lineTo(x + len, y); ctx.stroke();
  ctx.save();
  if (glow > 0.05) {
    const glowGrad = ctx.createRadialGradient(cx, y, 2, cx, y, r * 2.2);
    glowGrad.addColorStop(0, `rgba(250,204,21,${Math.min(0.6, glow * 0.6)})`);
    glowGrad.addColorStop(1, 'rgba(250,204,21,0)');
    ctx.fillStyle = glowGrad;
    ctx.beginPath(); ctx.arc(cx, y, r * 2.2, 0, Math.PI * 2); ctx.fill();
  }
  ctx.fillStyle = glow > 0.05 ? `rgba(255,251,235,1)` : '#f8fafc';
  ctx.strokeStyle = '#475569'; ctx.lineWidth = 2;
  ctx.beginPath(); ctx.arc(cx, y, r, 0, Math.PI * 2); ctx.fill(); ctx.stroke();
  ctx.strokeStyle = glow > 0.05 ? '#f59e0b' : '#94a3b8'; ctx.lineWidth = 1.5;
  ctx.beginPath(); ctx.moveTo(cx - r * 0.55, y - r * 0.55); ctx.lineTo(cx + r * 0.55, y + r * 0.55); ctx.stroke();
  ctx.beginPath(); ctx.moveTo(cx - r * 0.55, y + r * 0.55); ctx.lineTo(cx + r * 0.55, y - r * 0.55); ctx.stroke();
  ctx.restore();
  ctx.fillStyle = '#334155'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
  ctx.fillText('Filament lamp', cx, y - r - 8);
}

// Diode symbol: triangle in the direction of conventional current flow,
// with a bar at the tip (cathode).
function drawDiode(ctx: CanvasRenderingContext2D, x: number, y: number, len: number) {
  const cx = x + len / 2, half = 12;
  ctx.strokeStyle = '#475569'; ctx.lineWidth = 2;
  ctx.beginPath(); ctx.moveTo(x, y); ctx.lineTo(cx - half, y); ctx.stroke();
  ctx.beginPath(); ctx.moveTo(cx + half, y); ctx.lineTo(x + len, y); ctx.stroke();
  ctx.fillStyle = '#f8fafc'; ctx.strokeStyle = '#475569';
  ctx.beginPath();
  ctx.moveTo(cx - half, y - half); ctx.lineTo(cx - half, y + half); ctx.lineTo(cx + half, y); ctx.closePath();
  ctx.fill(); ctx.stroke();
  ctx.beginPath(); ctx.moveTo(cx + half, y - half); ctx.lineTo(cx + half, y + half); ctx.stroke();
  ctx.fillStyle = '#334155'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
  ctx.fillText('Diode', cx, y - half - 10);
}

function drawBattery(ctx: CanvasRenderingContext2D, x: number, y: number, V: number) {
  ctx.save();
  ctx.strokeStyle = '#475569'; ctx.lineWidth = 2;
  // long plate (+) and short plate (−)
  ctx.beginPath(); ctx.moveTo(x, y - 16); ctx.lineTo(x, y + 16); ctx.stroke();
  ctx.lineWidth = 4;
  ctx.beginPath(); ctx.moveTo(x + 10, y - 8); ctx.lineTo(x + 10, y + 8); ctx.stroke();
  ctx.fillStyle = '#334155'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
  ctx.fillText('+', x - 8, y - 20);
  ctx.fillText('−', x + 18, y - 20);
  ctx.fillText(`${V}V`, x + 5, y + 32);
  ctx.restore();
}

// A wire path is a list of points; charge carriers travel along it,
// distance parameterised by arc length so their SPEED on screen ∝ actual
// current.
type Path = { pts: [number, number][]; length: number; segLens: number[] };
function makePath(pts: [number, number][]): Path {
  const segLens: number[] = [];
  let length = 0;
  for (let i = 1; i < pts.length; i++) {
    const dx = pts[i][0] - pts[i - 1][0], dy = pts[i][1] - pts[i - 1][1];
    const l = Math.hypot(dx, dy);
    segLens.push(l); length += l;
  }
  return { pts, length, segLens };
}
function pointAt(path: Path, dist: number): [number, number] {
  let d = ((dist % path.length) + path.length) % path.length;
  for (let i = 0; i < path.segLens.length; i++) {
    if (d <= path.segLens[i]) {
      const f = path.segLens[i] === 0 ? 0 : d / path.segLens[i];
      const [x1, y1] = path.pts[i], [x2, y2] = path.pts[i + 1];
      return [x1 + (x2 - x1) * f, y1 + (y2 - y1) * f];
    }
    d -= path.segLens[i];
  }
  return path.pts[path.pts.length - 1];
}
function drawWire(ctx: CanvasRenderingContext2D, path: Path) {
  ctx.save();
  ctx.strokeStyle = '#94a3b8'; ctx.lineWidth = 2; ctx.lineJoin = 'round';
  ctx.beginPath();
  ctx.moveTo(path.pts[0][0], path.pts[0][1]);
  path.pts.slice(1).forEach(p => ctx.lineTo(p[0], p[1]));
  ctx.stroke();
  ctx.restore();
}
// Draws either electron flow (amber dots, physically correct drift
// direction) or conventional current (blue arrowheads, the textbook +→−
// direction — the OPPOSITE way along the same path) depending on
// flowDisplay. Dot/arrow count and speed both scale with current, so a
// bigger current reads as visibly "more" as well as "faster" — speed
// alone can be a subtle cue; density makes the difference unmistakable.
function drawCarriers(
  ctx: CanvasRenderingContext2D, path: Path, t: number, current: number, maxCurrent: number,
  flowDisplay: FlowDisplay,
) {
  if (current <= 0.0005) return;
  const frac = Math.max(0.12, Math.min(1, current / Math.max(maxCurrent, 0.0001)));
  const speed = Math.min(30 + current * 22, 170);
  const count = Math.max(3, Math.round(4 + frac * 12));
  // Verified numerically before this fix, by tracing the actual path
  // coordinates against the battery's known terminal positions (+ is the
  // long plate, drawn at the LEFT of the symbol; − is the short plate,
  // at the RIGHT): the path's own natural/defined order goes from the
  // corner nearest + terminal, the LONG way around the external circuit
  // (through the resistor/components), arriving at the corner nearest
  // − terminal. That is CONVENTIONAL CURRENT's direction (+ → external
  // circuit → −), not electron flow — electrons travel the external
  // circuit the OPPOSITE way, from − to +. The two modes had been
  // assigned backwards.
  const dir = flowDisplay === 'electron' ? -1 : 1;
  ctx.save();
  for (let i = 0; i < count; i++) {
    const d = dir * t * speed + (i / count) * path.length;
    const [x, y] = pointAt(path, d);
    if (flowDisplay === 'electron') {
      ctx.beginPath(); ctx.arc(x, y, 3, 0, Math.PI * 2);
      ctx.fillStyle = '#f59e0b'; ctx.fill();
    } else {
      // small arrowhead pointing along the conventional-current direction
      const dNext = dir * (t * speed + 0.6) + (i / count) * path.length;
      const [x2, y2] = pointAt(path, dNext);
      const ang = Math.atan2(y2 - y, x2 - x);
      ctx.save(); ctx.translate(x, y); ctx.rotate(ang);
      ctx.fillStyle = '#2563eb';
      ctx.beginPath(); ctx.moveTo(4, 0); ctx.lineTo(-3, -2.6); ctx.lineTo(-3, 2.6); ctx.closePath(); ctx.fill();
      ctx.restore();
    }
  }
  ctx.restore();
}

export function CircuitCanvas({
  mode, voltage, r1, r2, r3, nonOhmicDevice, flowDisplay,
  isRunning, isPaused, width = 640, height = 300,
}: Props) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const rafRef = useRef<number>(0);
  const tRef = useRef(0);
  const lastFrameRef = useRef<number | null>(null);
  const sim = useRef({ mode, voltage, r1, r2, r3, nonOhmicDevice, flowDisplay, isRunning, isPaused });
  sim.current = { mode, voltage, r1, r2, r3, nonOhmicDevice, flowDisplay, isRunning, isPaused };

  useEffect(() => { tRef.current = 0; lastFrameRef.current = null; }, [mode, voltage, r1, r2, r3, nonOhmicDevice, flowDisplay]);

  const draw = useCallback((timestamp?: number) => {
    const canvas = canvasRef.current; if (!canvas) return;
    const ctx = canvas.getContext('2d'); if (!ctx) return;
    const s = sim.current;
    const W = canvas.width, H = canvas.height;

    // Real wall-clock dt — carrier drift speed on screen stays proportional
    // to the actual current at any display refresh rate.
    if (s.isRunning && !s.isPaused && timestamp !== undefined) {
      if (lastFrameRef.current !== null) {
        tRef.current += Math.min((timestamp - lastFrameRef.current) / 1000, 0.1);
      }
      lastFrameRef.current = timestamp;
    } else {
      lastFrameRef.current = timestamp ?? null;
    }
    const t = tRef.current;

    ctx.clearRect(0, 0, W, H);
    ctx.fillStyle = '#f8fafc'; ctx.fillRect(0, 0, W, H);

    const L = 70, R = W - 70, T = 60, B = H - 50;

    if (s.mode === 'ohm') {
      const I = ohmCurrent(s.voltage, s.r1);
      const rLen = 130, rX = (W - rLen) / 2;
      const loop = makePath([[L, B], [L, T], [rX, T], [rX + rLen, T], [R, T], [R, B], [(R + L) / 2 + 20, B], [L, B]]);
      drawWire(ctx, loop);
      drawResistor(ctx, rX, T, rLen, 'R', s.r1);
      drawBattery(ctx, (R + L) / 2 - 5, B, s.voltage);
      drawCarriers(ctx, loop, t, I, I, s.flowDisplay);
      // Ammeter bubble
      ctx.save();
      ctx.fillStyle = 'white'; ctx.strokeStyle = '#6366f1'; ctx.lineWidth = 2;
      ctx.beginPath(); ctx.arc(L, (T + B) / 2, 18, 0, Math.PI * 2); ctx.fill(); ctx.stroke();
      ctx.fillStyle = '#4338ca'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
      ctx.fillText('A', L, (T + B) / 2 - 2);
      ctx.font = '9px system-ui';
      ctx.fillText(`${I.toFixed(2)}A`, L, (T + B) / 2 + 10);
      ctx.restore();
    }

    if (s.mode === 'non-ohmic') {
      const { cLamp, cTherm } = nonOhmicCalibration(s.r1, 12);
      const I = nonOhmicCurrent(s.nonOhmicDevice, s.voltage, cLamp, cTherm);
      const rLen = 130, rX = (W - rLen) / 2;
      const loop = makePath([[L, B], [L, T], [rX, T], [rX + rLen, T], [R, T], [R, B], [(R + L) / 2 + 20, B], [L, B]]);
      drawWire(ctx, loop);
      if (s.nonOhmicDevice === 'filament') drawLamp(ctx, rX, T, rLen, I / Math.max(0.01, ohmCurrent(24, s.r1)));
      else if (s.nonOhmicDevice === 'diode') drawDiode(ctx, rX, T, rLen);
      else drawResistor(ctx, rX, T, rLen, 'Rth', Math.round(s.voltage / Math.max(I, 0.0001)));
      drawBattery(ctx, (R + L) / 2 - 5, B, s.voltage);
      drawCarriers(ctx, loop, t, I, Math.max(I, 0.5), s.flowDisplay);
      ctx.save();
      ctx.fillStyle = 'white'; ctx.strokeStyle = '#6366f1'; ctx.lineWidth = 2;
      ctx.beginPath(); ctx.arc(L, (T + B) / 2, 18, 0, Math.PI * 2); ctx.fill(); ctx.stroke();
      ctx.fillStyle = '#4338ca'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
      ctx.fillText('A', L, (T + B) / 2 - 2);
      ctx.font = '9px system-ui';
      ctx.fillText(`${(I * 1000).toFixed(I > 0.05 ? 0 : 2)}${I > 0.05 ? 'mA' : 'A'}`, L, (T + B) / 2 + 10);
      ctx.restore();
    }

    if (s.mode === 'series') {
      const a = seriesAnalysis(s.voltage, [s.r1, s.r2, s.r3]);
      const rLen = 90, gap = (R - L - 3 * rLen) / 4;
      const xs = [L + gap, L + gap * 2 + rLen, L + gap * 3 + rLen * 2];
      const loop = makePath([[L, B], [L, T], ...xs.flatMap((x): [number, number][] => [[x, T], [x + rLen, T]]), [R, T], [R, B], [L, B]]);
      drawWire(ctx, loop);
      drawResistor(ctx, xs[0], T, rLen, 'R₁', s.r1);
      drawResistor(ctx, xs[1], T, rLen, 'R₂', s.r2);
      drawResistor(ctx, xs[2], T, rLen, 'R₃', s.r3);
      drawBattery(ctx, (R + L) / 2 - 5, B, s.voltage);
      drawCarriers(ctx, loop, t, a.I, a.I, s.flowDisplay);
      // Voltage drop labels under each resistor — the divider in action.
      ctx.save();
      ctx.fillStyle = '#059669'; ctx.font = '9px system-ui'; ctx.textAlign = 'center';
      xs.forEach((x, i) => ctx.fillText(`${a.drops[i].toFixed(2)}V`, x + rLen / 2, T + 22));
      ctx.restore();
    }

    if (s.mode === 'parallel') {
      const a = parallelAnalysis(s.voltage, [s.r1, s.r2, s.r3]);
      const maxBranch = Math.max(...a.branches, 0.0001);
      const bx1 = L + 90, bx2 = R - 90;
      const rows = [T, (T + B) / 2 - 10, B - 60];
      const rLen = bx2 - bx1 - 60;
      // Main loop through the top branch, plus each branch loop.
      const branchPaths = rows.map(y => makePath([
        [L, B], [L, y], [bx1, y], [bx1 + 30, y], [bx1 + 30 + rLen, y], [bx2, y], [R, y], [R, B], [L, B],
      ]));
      // Rails
      ctx.save(); ctx.strokeStyle = '#94a3b8'; ctx.lineWidth = 2;
      ctx.beginPath(); ctx.moveTo(L, B); ctx.lineTo(L, rows[0]); ctx.stroke();
      ctx.beginPath(); ctx.moveTo(R, B); ctx.lineTo(R, rows[0]); ctx.stroke();
      ctx.beginPath(); ctx.moveTo(L, B); ctx.lineTo(R, B); ctx.stroke();
      rows.forEach(y => { ctx.beginPath(); ctx.moveTo(L, y); ctx.lineTo(R, y); ctx.stroke(); });
      ctx.restore();
      const labels = ['R₁', 'R₂', 'R₃'], vals = [s.r1, s.r2, s.r3];
      rows.forEach((y, i) => {
        drawResistor(ctx, bx1 + 30, y, rLen, labels[i], vals[i]);
        // Carriers per branch — BOTH speed and density scale with that
        // branch's own current relative to the largest branch current,
        // so the current-divider effect (smallest R -> largest I) is
        // unmistakable, not just a subtle speed difference.
        drawCarriers(ctx, branchPaths[i], t, a.branches[i], maxBranch, s.flowDisplay);
        ctx.save();
        ctx.fillStyle = '#059669'; ctx.font = '9px system-ui'; ctx.textAlign = 'left';
        ctx.fillText(`${a.branches[i].toFixed(2)}A`, bx2 + 6, y - 6);
        ctx.restore();
      });
      drawBattery(ctx, (R + L) / 2 - 5, B, s.voltage);
    }

    ctx.fillStyle = '#64748b'; ctx.font = '10px system-ui'; ctx.textAlign = 'left';
    ctx.fillText(
      s.flowDisplay === 'electron'
        ? '● electron flow (speed & density ∝ current) — the ACTUAL direction charge carriers move'
        : '▶ conventional current (+ → −) — the direction used in circuit analysis, OPPOSITE to electron flow',
      8, H - 8,
    );

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
echo "Patch v57 applied -- 1 file written."
echo ""
echo "Next steps:"
echo "  rm -rf .next"
echo "  npm run dev"
echo ""
echo "Check: /simulations/ohms-law -- on the Ohm's law tab, switch to"
echo "'Conventional I' and confirm the arrows move from the + terminal"
echo "(left plate) around through the resistor to the - terminal (right"
echo "plate). Switch to 'Electron flow' and confirm the dots move the"
echo "exact opposite way, starting from the - terminal. Check this on"
echo "Series and Parallel too."
