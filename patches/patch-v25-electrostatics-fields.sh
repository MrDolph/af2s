#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
# A-Factor STEM Studio — patch v25: Electrostatics part 2 of 3 — Coulomb's
# Law & Electric Fields
#
#   COULOMB'S LAW — two charges shown at a slider-set separation with a live
#   force readout, PLUS pressing Run releases them to actually move under
#   their own mutual force — real 1D two-body integration using the real
#   Coulomb force (F=kQ1Q2/r2, converted to acceleration via F=ma with a
#   realistic 1g pith-ball mass), not just a static vector diagram. Verified
#   pacing numerically across the full slider range before shipping — like
#   charges separate smoothly (5nC weak case barely moves in 3s; 50nC
#   strong case separates to the viewing limit), unlike charges attract and
#   visibly meet within about a second in the strong case.
#
#   Caught and fixed a real bug while building this: two spots in the draw
#   loop referenced the q1nC/q2nC PROPS directly instead of through the
#   ref-mirrored `sim.current` (the pattern used everywhere else in the
#   app for canvases with a stable useCallback), which would have made the
#   charge labels/colours silently go stale if the parent re-rendered
#   without those specific props changing identity. ESLint's exhaustive-
#   deps warning caught it; fixed by routing through the ref like every
#   other value in the function.
#
#   ELECTRIC FIELD — a genuine field-line TRACER (not a schematic): each
#   line is stepped along the local net field direction in small
#   increments from many starting points, for single positive, single
#   negative, dipole, and like-charges configurations. Verified
#   numerically before shipping that the null point between two equal like
#   charges is exactly zero (not just visually close), and that the same
#   point in a dipole configuration has a genuine nonzero field pointing
#   toward the negative charge — both match the physics exactly. A
#   draggable test point shows local field strength and direction live.
#
#   All underlying formulas (Coulomb's law, field strength, potential,
#   capacitance) were already verified against textbook values in part 1;
#   this patch adds the interactive Coulomb's-law and field-line canvases
#   on top of that same physics module.
#
# Run from the af2s project root (Git Bash):   bash patches/patch-v25-electrostatics-fields.sh
# ══════════════════════════════════════════════════════════════════════════════
set -euo pipefail

if [ ! -f "package.json" ]; then
  echo "✗ Run this from the af2s project root (package.json not found)." >&2
  exit 1
fi

echo "── A-Factor patch v25: Electrostatics part 2 — Coulomb's Law & Fields ──"
mkdir -p "src/app/embed/electrostatics-fields" "src/app/simulations" "src/app/simulations/electrostatics-fields" "src/components/simulation"

echo "  → src/components/simulation/CoulombsLawCanvas.tsx"
cat > "src/components/simulation/CoulombsLawCanvas.tsx" << 'AFEOF'
'use client';
import { useRef, useEffect, useCallback } from 'react';
import { coulombForceSigned } from '@/lib/physics/electrostatics';

interface Props {
  q1nC: number; q2nC: number;  // signed charge, nanocoulombs
  initialSeparationCm: number;
  isRunning: boolean; isPaused: boolean;
  onTick?: (separationCm: number, forceN: number) => void;
  width?: number; height?: number;
}

const MASS_KG = 0.001;       // 1g — a light charged pith ball, for a watchable release animation
const PX_PER_M = 600;
const MIN_SEP_M = 0.01;      // 1cm — treat as "contact" below this

function drawCharge(ctx: CanvasRenderingContext2D, x: number, y: number, sign: 1 | -1, magnitude: number) {
  const r = 14 + Math.min(10, Math.abs(magnitude) * 0.3);
  const grad = ctx.createRadialGradient(x - 3, y - 3, 1, x, y, r);
  if (sign > 0) { grad.addColorStop(0, '#fca5a5'); grad.addColorStop(1, '#dc2626'); }
  else { grad.addColorStop(0, '#93c5fd'); grad.addColorStop(1, '#2563eb'); }
  ctx.fillStyle = grad;
  ctx.beginPath(); ctx.arc(x, y, r, 0, Math.PI * 2); ctx.fill();
  ctx.strokeStyle = 'white'; ctx.lineWidth = 2;
  ctx.beginPath(); ctx.moveTo(x - r * 0.5, y); ctx.lineTo(x + r * 0.5, y); ctx.stroke();
  if (sign > 0) { ctx.beginPath(); ctx.moveTo(x, y - r * 0.5); ctx.lineTo(x, y + r * 0.5); ctx.stroke(); }
}

function arrow(ctx: CanvasRenderingContext2D, x1: number, y1: number, x2: number, y2: number, color: string) {
  if (Math.hypot(x2 - x1, y2 - y1) < 2) return;
  ctx.save();
  ctx.strokeStyle = color; ctx.lineWidth = 3;
  ctx.beginPath(); ctx.moveTo(x1, y1); ctx.lineTo(x2, y2); ctx.stroke();
  const ang = Math.atan2(y2 - y1, x2 - x1);
  ctx.fillStyle = color;
  ctx.beginPath(); ctx.moveTo(x2, y2);
  ctx.lineTo(x2 - 10 * Math.cos(ang - 0.4), y2 - 10 * Math.sin(ang - 0.4));
  ctx.lineTo(x2 - 10 * Math.cos(ang + 0.4), y2 - 10 * Math.sin(ang + 0.4));
  ctx.closePath(); ctx.fill();
  ctx.restore();
}

export function CoulombsLawCanvas({ q1nC, q2nC, initialSeparationCm, isRunning, isPaused, onTick, width = 660, height = 260 }: Props) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const rafRef = useRef<number>(0);
  const lastFrameRef = useRef<number | null>(null);
  const sepM = useRef(0);
  const velM = useRef(0);
  const contactMade = useRef(false);
  const sim = useRef({ q1nC, q2nC, initialSeparationCm, isRunning, isPaused, onTick });
  sim.current = { q1nC, q2nC, initialSeparationCm, isRunning, isPaused, onTick };

  useEffect(() => {
    sepM.current = initialSeparationCm / 100;
    velM.current = 0;
    contactMade.current = false;
    lastFrameRef.current = null;
  }, [q1nC, q2nC, initialSeparationCm]);

  const draw = useCallback((timestamp?: number) => {
    const canvas = canvasRef.current; if (!canvas) return;
    const ctx = canvas.getContext('2d'); if (!ctx) return;
    const s = sim.current;
    const W = canvas.width, H = canvas.height;
    const midY = H / 2;

    const q1 = s.q1nC * 1e-9, q2 = s.q2nC * 1e-9;
    const running = s.isRunning && !s.isPaused;
    if (running && timestamp !== undefined && !contactMade.current) {
      if (lastFrameRef.current !== null) {
        const dt = Math.min((timestamp - lastFrameRef.current) / 1000, 0.02);
        // Sub-step for stability, since force changes quickly at close range
        const steps = 4;
        for (let i = 0; i < steps; i++) {
          const F = coulombForceSigned(q1, q2, Math.max(sepM.current, MIN_SEP_M / 2)); // + repel, - attract
          const a = F / MASS_KG;
          velM.current += a * (dt / steps);
          sepM.current += velM.current * (dt / steps);
          if (sepM.current <= MIN_SEP_M) { sepM.current = MIN_SEP_M; velM.current = 0; contactMade.current = true; break; }
          if (sepM.current > 1.2) { sepM.current = 1.2; velM.current = 0; break; } // off comfortable viewing range
        }
      }
      lastFrameRef.current = timestamp;
    } else {
      lastFrameRef.current = timestamp ?? null;
    }
    if (!s.isRunning) { sepM.current = s.initialSeparationCm / 100; contactMade.current = false; }

    const forceN = coulombForceSigned(q1, q2, sepM.current);
    s.onTick?.(sepM.current * 100, forceN);

    ctx.clearRect(0, 0, W, H);
    ctx.fillStyle = '#f8fafc'; ctx.fillRect(0, 0, W, H);

    const sepPx = Math.min(sepM.current * PX_PER_M, W - 80);
    const x1 = W / 2 - sepPx / 2, x2 = W / 2 + sepPx / 2;

    // Force vectors (drawn first so charges sit on top)
    const repulsive = forceN > 0;
    const arrowLen = Math.min(70, Math.abs(forceN) * 4e5 + 12);
    if (Math.abs(forceN) > 1e-9) {
      if (repulsive) {
        arrow(ctx, x1, midY - 40, x1 - arrowLen, midY - 40, '#f59e0b');
        arrow(ctx, x2, midY - 40, x2 + arrowLen, midY - 40, '#f59e0b');
      } else {
        arrow(ctx, x1 - arrowLen - 20, midY - 40, x1 - 20, midY - 40, '#10b981');
        arrow(ctx, x2 + arrowLen + 20, midY - 40, x2 + 20, midY - 40, '#10b981');
      }
    }

    drawCharge(ctx, x1, midY, s.q1nC >= 0 ? 1 : -1, s.q1nC);
    drawCharge(ctx, x2, midY, s.q2nC >= 0 ? 1 : -1, s.q2nC);
    ctx.fillStyle = '#334155'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
    ctx.fillText(`${s.q1nC >= 0 ? '+' : ''}${s.q1nC}nC`, x1, midY + 34);
    ctx.fillText(`${s.q2nC >= 0 ? '+' : ''}${s.q2nC}nC`, x2, midY + 34);

    ctx.font = 'bold 11px system-ui'; ctx.textAlign = 'center';
    ctx.fillStyle = contactMade.current ? '#dc2626' : repulsive ? '#f59e0b' : '#10b981';
    ctx.fillText(
      contactMade.current ? 'Charges have come into contact — the point-charge model breaks down here'
        : `${repulsive ? 'REPULSIVE' : 'ATTRACTIVE'} — F = ${Math.abs(forceN) < 1e-3 ? (Math.abs(forceN) * 1e6).toFixed(1) + ' µN' : (Math.abs(forceN) * 1e3).toFixed(2) + ' mN'}`,
      W / 2, 24,
    );
    ctx.fillStyle = '#64748b'; ctx.font = '10px system-ui'; ctx.textAlign = 'left';
    ctx.fillText(`separation r = ${(sepM.current * 100).toFixed(1)} cm`, 8, H - 10);

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

echo "  → src/components/simulation/ElectricFieldCanvas.tsx"
cat > "src/components/simulation/ElectricFieldCanvas.tsx" << 'AFEOF'
'use client';
import { useRef, useEffect, useCallback } from 'react';

export type FieldConfiguration = 'single-positive' | 'single-negative' | 'dipole' | 'like-charges';

interface Props {
  configuration: FieldConfiguration;
  testX: number; testY: number; // 0..1 fractional canvas position of the movable test point
  isRunning: boolean; isPaused: boolean;
  onTick?: (fieldStrengthRelative: number) => void;
  width?: number; height?: number;
}

interface Vec { x: number; y: number; }
interface Charge extends Vec { q: number; } // q sign only matters; magnitude is normalised for the line-tracer

function fieldAt(p: Vec, charges: Charge[]): Vec {
  let ex = 0, ey = 0;
  for (const c of charges) {
    const dx = p.x - c.x, dy = p.y - c.y;
    const r2 = dx * dx + dy * dy;
    if (r2 < 4) continue;
    const r = Math.sqrt(r2);
    const mag = c.q / r2;
    ex += mag * (dx / r);
    ey += mag * (dy / r);
  }
  return { x: ex, y: ey };
}

function traceFieldLine(start: Vec, charges: Charge[], W: number, H: number): Vec[] {
  const points: Vec[] = [start];
  let p = { ...start };
  const stepSize = 5;
  for (let i = 0; i < 400; i++) {
    const e = fieldAt(p, charges);
    const emag = Math.hypot(e.x, e.y);
    if (emag < 1e-9) break;
    p = { x: p.x + (e.x / emag) * stepSize, y: p.y + (e.y / emag) * stepSize };
    points.push(p);
    if (p.x < -20 || p.x > W + 20 || p.y < -20 || p.y > H + 20) break;
    // Terminate once close to any charge (its own start charge, or a
    // nearby opposite one the line has flowed into).
    if (charges.some(c => Math.hypot(p.x - c.x, p.y - c.y) < 16)) break;
  }
  return points;
}

function getCharges(config: FieldConfiguration, W: number, H: number): Charge[] {
  const midY = H / 2;
  switch (config) {
    case 'single-positive': return [{ x: W / 2, y: midY, q: 1 }];
    case 'single-negative': return [{ x: W / 2, y: midY, q: -1 }];
    case 'dipole': return [{ x: W / 2 - 80, y: midY, q: 1 }, { x: W / 2 + 80, y: midY, q: -1 }];
    case 'like-charges': return [{ x: W / 2 - 80, y: midY, q: 1 }, { x: W / 2 + 80, y: midY, q: 1 }];
  }
}

function drawCharge(ctx: CanvasRenderingContext2D, c: Charge) {
  const r = 16;
  ctx.fillStyle = c.q > 0 ? '#dc2626' : '#2563eb';
  ctx.beginPath(); ctx.arc(c.x, c.y, r, 0, Math.PI * 2); ctx.fill();
  ctx.strokeStyle = 'white'; ctx.lineWidth = 2;
  ctx.beginPath(); ctx.moveTo(c.x - r * 0.5, c.y); ctx.lineTo(c.x + r * 0.5, c.y); ctx.stroke();
  if (c.q > 0) { ctx.beginPath(); ctx.moveTo(c.x, c.y - r * 0.5); ctx.lineTo(c.x, c.y + r * 0.5); ctx.stroke(); }
}

export function ElectricFieldCanvas({ configuration, testX, testY, isRunning, isPaused, onTick, width = 660, height = 320 }: Props) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const rafRef = useRef<number>(0);
  const lastFrameRef = useRef<number | null>(null);
  const t = useRef(0);
  const sim = useRef({ configuration, testX, testY, isRunning, isPaused, onTick });
  sim.current = { configuration, testX, testY, isRunning, isPaused, onTick };

  useEffect(() => { t.current = 0; lastFrameRef.current = null; }, [configuration]);

  const draw = useCallback((timestamp?: number) => {
    const canvas = canvasRef.current; if (!canvas) return;
    const ctx = canvas.getContext('2d'); if (!ctx) return;
    const s = sim.current;
    const W = canvas.width, H = canvas.height;

    if (s.isRunning && !s.isPaused && timestamp !== undefined) {
      if (lastFrameRef.current !== null) t.current += (timestamp - lastFrameRef.current) / 1000;
      lastFrameRef.current = timestamp;
    } else {
      lastFrameRef.current = timestamp ?? null;
    }

    ctx.clearRect(0, 0, W, H);
    ctx.fillStyle = '#f8fafc'; ctx.fillRect(0, 0, W, H);

    const charges = getCharges(s.configuration, W, H);
    const hasPositive = charges.some(c => c.q > 0);
    const startPoints: Vec[] = [];
    const N = 12;
    if (hasPositive) {
      charges.filter(c => c.q > 0).forEach(c => {
        for (let i = 0; i < N; i++) {
          const a = (i / N) * Math.PI * 2;
          startPoints.push({ x: c.x + Math.cos(a) * 18, y: c.y + Math.sin(a) * 18 });
        }
      });
    } else {
      // Only a negative charge on the canvas: start lines on a large ring
      // so they flow inward, converging on it.
      const c = charges[0];
      const R = Math.min(W, H) * 0.42;
      for (let i = 0; i < N; i++) {
        const a = (i / N) * Math.PI * 2;
        startPoints.push({ x: c.x + Math.cos(a) * R, y: c.y + Math.sin(a) * R });
      }
    }

    ctx.strokeStyle = 'rgba(99,102,241,0.55)'; ctx.lineWidth = 1.4;
    startPoints.forEach(sp => {
      const line = traceFieldLine(sp, charges, W, H);
      if (line.length < 2) return;
      ctx.beginPath(); ctx.moveTo(line[0].x, line[0].y);
      for (let i = 1; i < line.length; i++) ctx.lineTo(line[i].x, line[i].y);
      ctx.stroke();
      // Arrowhead partway along, showing direction of travel
      const mid = line[Math.floor(line.length * 0.55)];
      const next = line[Math.min(line.length - 1, Math.floor(line.length * 0.55) + 2)];
      if (mid && next) {
        const ang = Math.atan2(next.y - mid.y, next.x - mid.x);
        ctx.save();
        ctx.fillStyle = 'rgba(99,102,241,0.8)';
        ctx.beginPath(); ctx.moveTo(mid.x, mid.y);
        ctx.lineTo(mid.x - 7 * Math.cos(ang - 0.4), mid.y - 7 * Math.sin(ang - 0.4));
        ctx.lineTo(mid.x - 7 * Math.cos(ang + 0.4), mid.y - 7 * Math.sin(ang + 0.4));
        ctx.closePath(); ctx.fill();
        ctx.restore();
      }
    });

    charges.forEach(c => drawCharge(ctx, c));

    // Movable test point, showing local field strength (relative units)
    const tx = s.testX * W, ty = s.testY * H;
    const e = fieldAt({ x: tx, y: ty }, charges);
    const emag = Math.hypot(e.x, e.y);
    s.onTick?.(emag);
    if (emag > 1e-9) {
      const dirx = e.x / emag, diry = e.y / emag;
      const arrowLen = Math.min(60, emag * 300 + 10);
      ctx.strokeStyle = '#f59e0b'; ctx.lineWidth = 3;
      ctx.beginPath(); ctx.moveTo(tx, ty); ctx.lineTo(tx + dirx * arrowLen, ty + diry * arrowLen); ctx.stroke();
      const ang = Math.atan2(diry, dirx);
      ctx.fillStyle = '#f59e0b';
      const ex2 = tx + dirx * arrowLen, ey2 = ty + diry * arrowLen;
      ctx.beginPath(); ctx.moveTo(ex2, ey2);
      ctx.lineTo(ex2 - 9 * Math.cos(ang - 0.4), ey2 - 9 * Math.sin(ang - 0.4));
      ctx.lineTo(ex2 - 9 * Math.cos(ang + 0.4), ey2 - 9 * Math.sin(ang + 0.4));
      ctx.closePath(); ctx.fill();
    }
    ctx.fillStyle = '#78350f';
    ctx.beginPath(); ctx.arc(tx, ty, 5, 0, Math.PI * 2); ctx.fill();
    ctx.fillStyle = '#334155'; ctx.font = 'bold 9px system-ui'; ctx.textAlign = 'center';
    ctx.fillText('test point', tx, ty - 12);

    const labels: Record<FieldConfiguration, string> = {
      'single-positive': 'Field lines point OUTWARD from a positive charge',
      'single-negative': 'Field lines point INWARD toward a negative charge',
      dipole: 'Field lines curve from the positive charge to the negative one',
      'like-charges': 'Field lines repel each other — a null point sits exactly between two equal like charges',
    };
    ctx.fillStyle = '#334155'; ctx.font = 'bold 11px system-ui'; ctx.textAlign = 'center';
    ctx.fillText(labels[s.configuration], W / 2, 20);

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

echo "  → src/app/simulations/electrostatics-fields/page.tsx"
cat > "src/app/simulations/electrostatics-fields/page.tsx" << 'AFEOF'
'use client';
import { useState, useCallback, useEffect, useRef } from 'react';
import { AppHeader } from '@/components/layout/AppHeader';
import { SimulationControls } from '@/components/simulation/SimulationControls';
import { CoulombsLawCanvas } from '@/components/simulation/CoulombsLawCanvas';
import { ElectricFieldCanvas, FieldConfiguration } from '@/components/simulation/ElectricFieldCanvas';
import { EmbedButton } from '@/components/ui/EmbedButton';
import { coulombForceSigned } from '@/lib/physics/electrostatics';
import { useResponsiveCanvasSize } from '@/hooks/useResponsiveCanvasSize';

type Topic = 'coulomb' | 'field';

const CURRICULA = ['WAEC', 'NECO', 'IGCSE', 'SAT', 'JUPEB'];
const CC: Record<string, string> = {
  WAEC: 'bg-indigo-100 text-indigo-700', NECO: 'bg-pink-100 text-pink-700',
  IGCSE: 'bg-emerald-100 text-emerald-700', SAT: 'bg-orange-100 text-orange-700',
  JUPEB: 'bg-purple-100 text-purple-700',
};

const TOPIC_META: Record<Topic, { title: string; icon: string; sub: string; eq: string }> = {
  coulomb: { title: "Coulomb's law", icon: '🧲', sub: 'Force between two point charges', eq: 'F = kQ₁Q₂/r²' },
  field:   { title: 'Electric field', icon: '🌐', sub: 'Field lines & field strength',     eq: 'E = kQ/r² = F/q' },
};

const TEACHER_NOTES: Record<Topic, string[]> = {
  coulomb: [
    "Coulomb's law: F = kQ₁Q₂/r², where k ≈ 8.99×10⁹ N·m²/C² (often written 1/4πε₀).",
    'Like charges REPEL (positive force by the sign convention here), unlike charges ATTRACT — the direction follows automatically from the signs of Q₁ and Q₂ in the formula.',
    'The force obeys an INVERSE-SQUARE law: doubling the separation cuts the force to a quarter, not a half — a very commonly tested numeric trap.',
    "Coulomb's law has the same mathematical FORM as Newton's law of gravitation (F=Gm₁m₂/r²) — both are inverse-square laws — but electric forces can be attractive OR repulsive, while gravity is always attractive.",
    'The released charges shown here accelerate because force causes acceleration (F=ma) — as they separate, the force (and so the acceleration) drops rapidly, which is why the motion visibly slows down even though the charges keep moving apart.',
  ],
  field: [
    'Electric field strength E at a point is the force per unit positive charge placed there: E = F/q. It is a vector — it has both magnitude and direction.',
    'For a point charge, E = kQ/r² — the same inverse-square dependence as Coulomb\u2019s law, since E is just the force ONE unit of charge would feel.',
    'Field line rules: they point in the direction a small POSITIVE test charge would move; they start on positive charges (or infinity) and end on negative charges (or infinity); they never cross; closer lines mean a stronger field.',
    'Around a single charge, field lines are straight and radial — outward from a positive charge, inward toward a negative one.',
    'Between two EQUAL like charges, there is a NULL POINT exactly at the midpoint where the two fields cancel exactly to zero — a test charge placed there feels no net force at all.',
  ],
};

const EXERCISES: Record<Topic, { q: string; a: string }[]> = {
  coulomb: [
    { q: 'Two point charges of +3μC and +5μC are 0.2m apart. Find the force between them.', a: 'F = kQ₁Q₂/r² = (8.99×10⁹ × 3×10⁻⁶ × 5×10⁻⁶) / (0.2)² = 134.9/0.04 = 3.37N (repulsive, since both charges are positive).' },
    { q: 'The distance between two charges is tripled. By what factor does the force between them change?', a: 'F ∝ 1/r², so tripling r reduces F by a factor of 1/3² = 1/9 — the new force is one-ninth of the original.' },
    { q: 'A +2μC charge and a −4μC charge are 0.1m apart. Find the magnitude and nature of the force between them.', a: 'F = kQ₁Q₂/r² = (8.99×10⁹ × 2×10⁻⁶ × 4×10⁻⁶) / (0.1)² = 71.9/0.01 = 7.19N. Since the charges have opposite signs, the force is attractive.' },
  ],
  field: [
    { q: 'Find the electric field strength at a point 0.3m from a +6μC charge.', a: 'E = kQ/r² = (8.99×10⁹ × 6×10⁻⁶) / (0.3)² = 53940/0.09 = 599,333 N/C (directed away from the charge, since it is positive).' },
    { q: 'A charge of +2μC placed at a point experiences a force of 0.5N. Find the electric field strength at that point.', a: 'E = F/q = 0.5 / (2×10⁻⁶) = 250,000 N/C.' },
    { q: 'Explain why field lines can never cross one another.', a: 'The field at any point has one definite direction. If two field lines crossed, the field at that crossing point would have two different directions at once, which is impossible — so field lines never cross.' },
    { q: 'Two equal positive point charges sit 10cm apart. Describe the field at the point exactly midway between them.', a: 'The field is zero at that midpoint — a null point. Each charge pushes a test charge there with equal magnitude but exactly opposite direction (both charges repel a positive test charge away from themselves, i.e. toward the other charge and away from itself simultaneously), so the two contributions cancel exactly.' },
  ],
};

function Slider({ label, unit, value, min, max, step, set, color, note }: {
  label: string; unit: string; value: number; min: number; max: number;
  step: number; set: (v: number) => void; color: string; note?: string;
}) {
  return (
    <div className="space-y-1.5">
      <div className="flex justify-between text-xs">
        <span className="text-gray-500">{label}</span>
        <span className="font-medium tabular-nums text-gray-800">{value} <span className="text-gray-400 font-normal">{unit}</span></span>
      </div>
      <input type="range" min={min} max={max} step={step} value={value}
        onChange={e => set(Number(e.target.value))} className="w-full" style={{ accentColor: color }} />
      {note && <p className="text-[10px] text-gray-400">{note}</p>}
    </div>
  );
}

function StatRow({ label, value, unit, color }: { label: string; value: string; unit: string; color: string }) {
  return (
    <div className="flex justify-between items-center rounded-lg bg-gray-50 px-3 py-2">
      <span className="text-xs text-gray-500">{label}</span>
      <span className={`text-xs font-semibold tabular-nums ${color}`}>{value} <span className="text-gray-400 font-normal">{unit}</span></span>
    </div>
  );
}

export default function ElectrostaticsFieldsPage() {
  const [topic, setTopic] = useState<Topic>('coulomb');
  const [isRunning, setIsRunning] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const [resetKey, setResetKey] = useState(0);
  const [openEx, setOpenEx] = useState<number | null>(null);
  const [activeCurricula, setActiveCurricula] = useState(['WAEC', 'IGCSE', 'SAT']);

  const [q1nC, setQ1nC] = useState(20);
  const [q2nC, setQ2nC] = useState(20);
  const [separationCm, setSeparationCm] = useState(10);
  const [liveCoulomb, setLiveCoulomb] = useState({ sep: 10, force: 0 });

  const [fieldConfig, setFieldConfig] = useState<FieldConfiguration>('single-positive');
  const [testX, setTestX] = useState(0.75);
  const [testY, setTestY] = useState(0.3);
  const [liveField, setLiveField] = useState(0);

  const reset = useCallback(() => { setIsRunning(false); setIsPaused(false); setResetKey(k => k + 1); }, []);
  const resetTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  useEffect(() => {
    if (resetTimer.current) clearTimeout(resetTimer.current);
    resetTimer.current = setTimeout(reset, 100);
  }, [topic, q1nC, q2nC, separationCm, fieldConfig, reset]);

  const canvasBoxRef = useRef<HTMLDivElement>(null);
  const canvasSize = useResponsiveCanvasSize(canvasBoxRef, 660, 300, 980);

  const staticForceN = coulombForceSigned(q1nC * 1e-9, q2nC * 1e-9, separationCm / 100);

  return (
    <>
      <AppHeader />
      <main className="min-h-screen bg-gray-50">
        <section className="border-b border-gray-200 bg-white">
          <div className="mx-auto max-w-[100rem] px-4 sm:px-6 py-4">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
              <div>
                <p className="text-xs text-gray-400 mb-0.5">Electricity · Electrostatics</p>
                <h1 className="text-lg font-semibold text-gray-900">Coulomb&apos;s Law &amp; Electric Fields</h1>
              </div>
              <div className="flex gap-1.5 flex-wrap">
                {CURRICULA.map(c => (
                  <button key={c}
                    onClick={() => setActiveCurricula(p => p.includes(c) ? p.filter(x => x !== c) : [...p, c])}
                    className={`text-xs px-2.5 py-2 rounded-full border font-medium transition ${
                      activeCurricula.includes(c) ? CC[c] + ' border-transparent' : 'bg-white text-gray-400 border-gray-200'
                    }`}>{c}</button>
                ))}
              </div>
            </div>
          </div>
        </section>

        <div className="mx-auto max-w-[100rem] px-4 sm:px-6 py-4 space-y-4">
          <div className="flex gap-1 bg-gray-100 p-1 rounded-xl overflow-x-auto">
            {(Object.keys(TOPIC_META) as Topic[]).map(t => (
              <button key={t} onClick={() => { setTopic(t); setOpenEx(null); }}
                className={`shrink-0 flex items-center gap-1.5 px-3 py-2 rounded-lg text-xs font-medium transition ${
                  topic === t ? 'bg-white text-indigo-700 shadow-sm' : 'text-gray-500 hover:text-gray-700'
                }`}>
                <span>{TOPIC_META[t].icon}</span><span>{TOPIC_META[t].title}</span>
              </button>
            ))}
          </div>

          <div className="flex flex-wrap items-center gap-3 rounded-xl border border-gray-200 bg-white px-4 py-2.5">
            <span className="text-xs text-gray-400">{TOPIC_META[topic].sub}</span>
            <span className="text-sm font-semibold font-mono text-gray-900">{TOPIC_META[topic].eq}</span>
          </div>

          <div className="grid grid-cols-1 lg:grid-cols-[1fr_220px] xl:grid-cols-[1fr_220px_260px] gap-4">
            <div className="space-y-3 min-w-0">
              <div ref={canvasBoxRef} className="rounded-2xl border border-gray-200 bg-white p-3 shadow-sm">
                {topic === 'coulomb' && (
                  <CoulombsLawCanvas key={resetKey} q1nC={q1nC} q2nC={q2nC} initialSeparationCm={separationCm}
                    isRunning={isRunning} isPaused={isPaused} onTick={(sep, force) => setLiveCoulomb({ sep, force })}
                    width={canvasSize.width} height={canvasSize.height} />
                )}
                {topic === 'field' && (
                  <ElectricFieldCanvas key={resetKey} configuration={fieldConfig} testX={testX} testY={testY}
                    isRunning={isRunning} isPaused={isPaused} onTick={setLiveField}
                    width={canvasSize.width} height={canvasSize.height} />
                )}
              </div>

              <div className="flex flex-wrap items-center justify-between gap-2">
                <SimulationControls isRunning={isRunning} isPaused={isPaused}
                  onRun={() => { setIsRunning(true); setIsPaused(false); }}
                  onPause={() => setIsPaused(p => !p)} onReset={reset} />
                <EmbedButton path="/embed/electrostatics-fields"
                  title={`${TOPIC_META[topic].title} — A-Factor STEM Studio`}
                  params={
                    topic === 'coulomb' ? { topic, q1: q1nC, q2: q2nC, sep: separationCm }
                    : { topic, config: fieldConfig }
                  } />
              </div>

              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm space-y-4">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide">Parameters</p>

                {topic === 'coulomb' && <>
                  <Slider label="Charge Q₁" unit="nC" value={q1nC} min={-50} max={50} step={5} set={setQ1nC} color="#dc2626" note="Negative = negative charge" />
                  <Slider label="Charge Q₂" unit="nC" value={q2nC} min={-50} max={50} step={5} set={setQ2nC} color="#2563eb" />
                  <Slider label="Initial separation" unit="cm" value={separationCm} min={5} max={30} step={1} set={setSeparationCm} color="#6366f1"
                    note="Press Run to release the charges and watch them respond to the force" />
                </>}

                {topic === 'field' && <>
                  <div className="grid grid-cols-2 gap-2">
                    {([
                      ['single-positive', 'Single +'], ['single-negative', 'Single −'],
                      ['dipole', 'Dipole (+/−)'], ['like-charges', 'Like charges (+/+)'],
                    ] as [FieldConfiguration, string][]).map(([cfg, label]) => (
                      <button key={cfg} onClick={() => setFieldConfig(cfg)}
                        className={`rounded-lg border px-2 py-2 text-xs font-medium transition ${
                          fieldConfig === cfg ? 'border-indigo-300 bg-indigo-50 text-indigo-700' : 'border-gray-200 bg-white text-gray-500'
                        }`}>{label}</button>
                    ))}
                  </div>
                  <Slider label="Test point — horizontal" unit="" value={testX} min={0.05} max={0.95} step={0.01} set={setTestX} color="#f59e0b" />
                  <Slider label="Test point — vertical" unit="" value={testY} min={0.1} max={0.9} step={0.01} set={setTestY} color="#f59e0b"
                    note="Drag to explore the field strength and direction at different points" />
                </>}
              </div>
            </div>

            <div className="space-y-3">
              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide mb-3">Calculated</p>
                <div className="space-y-2">
                  {topic === 'coulomb' && <>
                    <StatRow label="Force (at slider r)" value={Math.abs(staticForceN) < 1e-3 ? (Math.abs(staticForceN) * 1e6).toFixed(2) : (Math.abs(staticForceN) * 1e3).toFixed(3)} unit={Math.abs(staticForceN) < 1e-3 ? 'µN' : 'mN'} color="text-indigo-600" />
                    <StatRow label="Nature" value={staticForceN > 0 ? 'repulsive' : staticForceN < 0 ? 'attractive' : 'none'} unit="" color={staticForceN > 0 ? 'text-amber-600' : 'text-emerald-600'} />
                    <StatRow label="Live separation" value={liveCoulomb.sep.toFixed(1)} unit="cm" color="text-purple-600" />
                    <StatRow label="Live force" value={Math.abs(liveCoulomb.force) < 1e-3 ? (Math.abs(liveCoulomb.force) * 1e6).toFixed(2) : (Math.abs(liveCoulomb.force) * 1e3).toFixed(3)} unit={Math.abs(liveCoulomb.force) < 1e-3 ? 'µN' : 'mN'} color="text-rose-500" />
                  </>}
                  {topic === 'field' && <>
                    <StatRow label="Configuration" value={fieldConfig.replace('-', ' ')} unit="" color="text-indigo-600" />
                    <StatRow label="Relative field at test point" value={liveField.toFixed(4)} unit="" color="text-amber-600" />
                    <StatRow label="Field direction" value="shown by the amber arrow" unit="" color="text-emerald-600" />
                  </>}
                </div>
              </div>

              <div className="rounded-2xl border border-gray-100 bg-white p-4">
                <p className="text-xs text-gray-400 mb-2">Curriculum</p>
                <div className="flex flex-wrap gap-1.5">
                  {CURRICULA.map(c => (
                    <span key={c} className={`text-xs font-medium px-2 py-0.5 rounded-full ${
                      activeCurricula.includes(c) ? CC[c] : 'bg-gray-100 text-gray-400'
                    }`}>{c}</span>
                  ))}
                </div>
              </div>
            </div>

            <div className="space-y-3 lg:col-span-2 xl:col-span-1">
              <div className="rounded-2xl border border-amber-100 bg-amber-50 p-4">
                <p className="text-xs font-medium text-amber-700 uppercase tracking-wide mb-3">📋 Teacher notes</p>
                <ul className="space-y-2">
                  {TEACHER_NOTES[topic].map((n, i) => (
                    <li key={i} className="text-xs text-amber-900 leading-relaxed flex gap-2">
                      <span className="text-amber-400 shrink-0 mt-0.5">•</span>{n}
                    </li>
                  ))}
                </ul>
              </div>

              <div className="rounded-2xl border border-gray-200 bg-white p-4">
                <p className="text-xs font-medium text-gray-500 uppercase tracking-wide mb-3">✏️ Exercises</p>
                <div className="space-y-2">
                  {EXERCISES[topic].map((ex, i) => (
                    <div key={i} className="rounded-xl border border-gray-100 overflow-hidden">
                      <button onClick={() => setOpenEx(openEx === i ? null : i)}
                        className="w-full text-left px-3 py-2.5 text-xs text-gray-700 leading-relaxed hover:bg-gray-50 transition flex justify-between gap-2">
                        <span><span className="font-medium text-indigo-600">Q{i + 1}.</span> {ex.q}</span>
                        <span className="text-gray-300 shrink-0 text-sm">{openEx === i ? '▲' : '▼'}</span>
                      </button>
                      {openEx === i && (
                        <div className="px-3 py-2.5 bg-emerald-50 border-t border-gray-100 text-xs text-emerald-800 leading-relaxed">
                          <span className="font-medium">Answer: </span>{ex.a}
                        </div>
                      )}
                    </div>
                  ))}
                </div>
              </div>
            </div>
          </div>
        </div>
      </main>
    </>
  );
}
AFEOF

echo "  → src/app/embed/electrostatics-fields/page.tsx"
cat > "src/app/embed/electrostatics-fields/page.tsx" << 'AFEOF'
'use client';
import { Suspense, useState, useCallback, useEffect, useRef } from 'react';
import { useSearchParams } from 'next/navigation';
import { CoulombsLawCanvas } from '@/components/simulation/CoulombsLawCanvas';
import { ElectricFieldCanvas, FieldConfiguration } from '@/components/simulation/ElectricFieldCanvas';
import { SimulationControls } from '@/components/simulation/SimulationControls';

type Topic = 'coulomb' | 'field';

function num(sp: URLSearchParams, key: string, fallback: number, min: number, max: number) {
  const v = Number(sp.get(key));
  return Number.isFinite(v) && sp.get(key) !== null ? Math.min(max, Math.max(min, v)) : fallback;
}

function Slider({ label, unit, value, min, max, step, set, color }: {
  label: string; unit: string; value: number; min: number; max: number;
  step: number; set: (v: number) => void; color: string;
}) {
  return (
    <div className="space-y-1">
      <div className="flex justify-between text-xs">
        <span className="text-gray-500">{label}</span>
        <span className="font-medium tabular-nums text-gray-800">{value} <span className="font-normal text-gray-400">{unit}</span></span>
      </div>
      <input type="range" min={min} max={max} step={step} value={value}
        onChange={e => set(Number(e.target.value))} className="w-full" style={{ accentColor: color }} />
    </div>
  );
}

function PoweredBy() {
  return (
    <p className="text-center text-[10px] text-gray-400">
      Powered by{' '}
      <a href="/" target="_blank" rel="noopener noreferrer" className="font-medium text-indigo-500 hover:text-indigo-600">
        A-Factor STEM Studio
      </a>
    </p>
  );
}

function ElectrostaticsFieldsEmbedInner() {
  const sp = useSearchParams();
  const topic = ((): Topic => (sp.get('topic') === 'field' ? 'field' : 'coulomb'))();
  const showControls = sp.get('controls') !== '0';

  const [q1nC, setQ1nC] = useState(() => num(sp, 'q1', 20, -50, 50));
  const [q2nC, setQ2nC] = useState(() => num(sp, 'q2', 20, -50, 50));
  const [separationCm, setSeparationCm] = useState(() => num(sp, 'sep', 10, 5, 30));

  const [fieldConfig, setFieldConfig] = useState<FieldConfiguration>(() => {
    const c = sp.get('config');
    return c === 'single-negative' || c === 'dipole' || c === 'like-charges' ? c : 'single-positive';
  });
  const [testX] = useState(0.75);
  const [testY] = useState(0.3);

  const [isRunning, setIsRunning] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const [resetKey, setResetKey] = useState(0);
  const reset = useCallback(() => { setIsRunning(false); setIsPaused(false); setResetKey(k => k + 1); }, []);
  const resetTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  useEffect(() => {
    if (resetTimer.current) clearTimeout(resetTimer.current);
    resetTimer.current = setTimeout(reset, 100);
  }, [topic, q1nC, q2nC, separationCm, fieldConfig, reset]);

  return (
    <div className="mx-auto max-w-2xl space-y-3 p-3 sm:p-4">
      {topic === 'coulomb' && (
        <CoulombsLawCanvas key={resetKey} q1nC={q1nC} q2nC={q2nC} initialSeparationCm={separationCm}
          isRunning={isRunning} isPaused={isPaused} width={640} height={260} />
      )}
      {topic === 'field' && (
        <ElectricFieldCanvas key={resetKey} configuration={fieldConfig} testX={testX} testY={testY}
          isRunning={isRunning} isPaused={isPaused} width={640} height={300} />
      )}
      <SimulationControls isRunning={isRunning} isPaused={isPaused}
        onRun={() => { setIsRunning(true); setIsPaused(false); }}
        onPause={() => setIsPaused(p => !p)} onReset={reset} />
      {showControls && (
        <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm space-y-3">
          <p className="text-xs font-medium uppercase tracking-wide text-gray-400">Parameters</p>
          {topic === 'coulomb' && <>
            <Slider label="Charge Q1" unit="nC" value={q1nC} min={-50} max={50} step={5} set={setQ1nC} color="#dc2626" />
            <Slider label="Charge Q2" unit="nC" value={q2nC} min={-50} max={50} step={5} set={setQ2nC} color="#2563eb" />
            <Slider label="Initial separation" unit="cm" value={separationCm} min={5} max={30} step={1} set={setSeparationCm} color="#6366f1" />
          </>}
          {topic === 'field' && (
            <div className="grid grid-cols-2 gap-2">
              {([
                ['single-positive', 'Single +'], ['single-negative', 'Single −'],
                ['dipole', 'Dipole (+/−)'], ['like-charges', 'Like charges'],
              ] as [FieldConfiguration, string][]).map(([cfg, label]) => (
                <button key={cfg} onClick={() => setFieldConfig(cfg)}
                  className={`rounded-lg border px-2 py-2 text-xs font-medium transition ${
                    fieldConfig === cfg ? 'border-indigo-300 bg-indigo-50 text-indigo-700' : 'border-gray-200 bg-white text-gray-500'
                  }`}>{label}</button>
              ))}
            </div>
          )}
        </div>
      )}
      <PoweredBy />
    </div>
  );
}

export default function ElectrostaticsFieldsEmbedPage() {
  return (
    <Suspense fallback={<div className="p-8 text-center text-xs text-gray-400">Loading simulation…</div>}>
      <ElectrostaticsFieldsEmbedInner />
    </Suspense>
  );
}
AFEOF

echo "  → src/app/simulations/page.tsx"
cat > "src/app/simulations/page.tsx" << 'AFEOF'
'use client';
import { useState } from 'react';
import Link from 'next/link';
import { AppHeader } from '@/components/layout/AppHeader';

const CURRICULA = ['WAEC', 'NECO', 'IGCSE', 'SAT', 'JUPEB'] as const;

const SIMULATIONS = [
  {
    slug: 'projectile-motion',
    href: '/simulations/projectile-motion',
    title: 'Projectile motion',
    description: 'Launch a projectile and explore range, height, and trajectory in real time.',
    icon: '🎯',
    tags: ['WAEC', 'NECO', 'IGCSE', 'SAT', 'JUPEB'],
    topic: 'Mechanics',
    status: 'live',
  },
  {
    slug: 'gas-laws',
    href: '/simulations/gas-laws',
    title: "Gas laws (Boyle & Charles)",
    description: 'Compress gas to see pressure rise. Heat it to watch volume expand.',
    icon: '🧪',
    tags: ['WAEC', 'NECO', 'IGCSE', 'SAT'],
    topic: 'Thermal physics',
    status: 'live',
  },
  {
    slug: 'newtons-second-law',
    href: '/simulations/newtons-laws',
    title: "Newton's 2nd law",
    description: 'Apply forces to a block and observe acceleration in real time.',
    icon: '⚡',
    tags: ['WAEC', 'NECO', 'IGCSE', 'SAT', 'JUPEB'],
    topic: 'Mechanics',
    status: 'live',
  },
  {
    slug: 'consequences-of-newtons-motion-laws',
    href: '/simulations/consequences-of-motion',
    title: "Consequences of Newton's motion laws",
    description: 'Explore inertia, momentum and action-reaction with interactive experiments.',
    icon: '🚈',
    tags: ['WAEC', 'NECO', 'IGCSE', 'SAT', 'JUPEB'],
    topic: 'Mechanics',
    status: 'live',
  },
  {
    slug: 'simple-harmonic-motion',
    href: '/simulations/oscillations',
    title: 'Simple harmonic motion',
    description: 'Oscillating mass-spring system with displacement, velocity and energy graphs.',
    icon: '〰️',
    tags: ['WAEC', 'NECO', 'IGCSE', 'JUPEB'],
    topic: 'Mechanics',
    status: 'live',
  },
  {
    slug: 'ohms-law',
    href: '/simulations/ohms-law',
    title: "Ohm's law & circuits",
    description: 'Adjust voltage and resistance, measure current. Build series and parallel circuits.',
    icon: '⚡',
    tags: ['WAEC', 'NECO', 'IGCSE', 'SAT', 'JUPEB'],
    topic: 'Electricity',
    status: 'live',
  },
  {
    slug: 'electrostatics-charging',
    href: '/simulations/electrostatics-charging',
    title: 'Electrostatics: Charging Objects',
    description: 'Friction, conduction & induction, the gold-leaf electroscope, and the electrophorus.',
    icon: '🍂',
    tags: ['WAEC', 'NECO', 'IGCSE', 'JUPEB'],
    topic: 'Electricity',
    status: 'live',
  },
  {
    slug: 'electrostatics-fields',
    href: '/simulations/electrostatics-fields',
    title: "Electrostatics: Coulomb's Law & Fields",
    description: 'Force between point charges, with a real release animation, plus electric field lines.',
    icon: '🧲',
    tags: ['WAEC', 'NECO', 'IGCSE', 'SAT', 'JUPEB'],
    topic: 'Electricity',
    status: 'live',
  },
  {
    slug: 'waves',
    href: '/simulations/waves',
    title: 'Wave motion',
    description: 'Visualise transverse and longitudinal waves. Explore frequency and amplitude.',
    icon: '🌊',
    tags: ['WAEC', 'NECO', 'IGCSE', 'SAT'],
    topic: 'Waves',
    status: 'live',
  },
  {
    slug: 'diffraction',
    href: '/simulations/diffraction',
    title: 'Diffraction',
    description: 'Waves spreading through a single slit, and diffraction-grating spectral orders.',
    icon: '🌈',
    tags: ['WAEC', 'NECO', 'IGCSE', 'JUPEB'],
    topic: 'Waves',
    status: 'live',
  },
  {
    slug: 'polarization',
    href: '/simulations/polarization',
    title: 'Polarization',
    description: 'Unpolarized light through a single filter, and Malus\u2019s law with two polarizers.',
    icon: '🕶️',
    tags: ['IGCSE', 'SAT', 'JUPEB'],
    topic: 'Waves',
    status: 'live',
  },
  {
    slug: 'refraction',
    href: '/simulations/refraction',
    title: 'Refraction & lenses',
    description: 'Trace light rays through convex and concave lenses. Find focal length.',
    icon: '🔭',
    tags: ['WAEC', 'NECO', 'IGCSE', 'SAT'],
    topic: 'Optics',
    status: 'live',
  },
  {
    slug: 'reflection',
    href: '/simulations/reflection',
    title: 'Reflection',
    description: 'The law of reflection, mirror rotation (fixed source, 2θ rule), and concave/convex ray diagrams.',
    icon: '🪞',
    tags: ['WAEC', 'NECO', 'IGCSE', 'SAT'],
    topic: 'Optics',
    status: 'live',
  },
  {
    slug: 'rectilinear-propagation',
    href: '/simulations/rectilinear-propagation',
    title: 'Sources of Light & Rectilinear Propagation',
    description: 'Shadows (umbra & penumbra), solar & lunar eclipses, and the pinhole camera.',
    icon: '🌑',
    tags: ['WAEC', 'NECO', 'IGCSE'],
    topic: 'Optics',
    status: 'live',
  },
  {
    slug: 'radioactive-decay',
    href: '/simulations/radioactive-decay',
    title: 'Radioactive decay',
    description: 'Watch nuclei decay over time. Explore half-life with live decay curves.',
    icon: '☢️',
    tags: ['WAEC', 'NECO', 'IGCSE', 'JUPEB'],
    topic: 'Modern physics',
    status: 'live',
  },
  {
    slug: 'photoelectric-effect',
    href: '/simulations/photoelectric-effect',
    title: 'Photoelectric effect',
    description: "Fire light at a metal plate and test Einstein's equation hf = φ + KEmax.",
    icon: '💡',
    tags: ['WAEC', 'IGCSE', 'JUPEB'],
    topic: 'Modern physics',
    status: 'live',
  },
  {
    slug: 'de-broglie',
    href: '/simulations/de-broglie',
    title: 'De Broglie hypothesis',
    description: 'See matter waves in action: λ = h/mv for particles from electrons to cricket balls.',
    icon: '〰️',
    tags: ['IGCSE', 'JUPEB', 'SAT'],
    topic: 'Modern physics',
    status: 'live',
  },
  {
    slug: 'x-rays',
    href: '/simulations/x-rays',
    title: 'X-rays',
    description: 'Explore X-ray tube production, the continuous spectrum, and the Duane–Hunt limit.',
    icon: '🩻',
    tags: ['WAEC', 'IGCSE', 'JUPEB'],
    topic: 'Modern physics',
    status: 'live',
  },
  {
    slug: 'friction',
    href: '/simulations/friction',
    title: 'Friction',
    description: 'Static vs kinetic friction on flat and inclined surfaces, with the angle of repose.',
    icon: '🧱',
    tags: ['WAEC', 'NECO', 'IGCSE', 'SAT'],
    topic: 'Mechanics',
    status: 'live',
  },
  {
    slug: 'heat-transfer',
    href: '/simulations/heat-transfer',
    title: 'Modes of heat transfer',
    description: 'Conduction, convection, and radiation compared side by side with live particle animation.',
    icon: '🔥',
    tags: ['WAEC', 'NECO', 'IGCSE', 'SAT'],
    topic: 'Thermal physics',
    status: 'live',
  },
  {
    slug: 'elasticity',
    href: '/simulations/elasticity',
    title: 'Elasticity',
    description: "Hooke's law with a loaded spring, and Young's modulus for a stretched wire.",
    icon: '🪢',
    tags: ['WAEC', 'NECO', 'IGCSE', 'SAT'],
    topic: 'Mechanics',
    status: 'live',
  },
  {
    slug: 'equilibrium-of-forces',
    href: '/simulations/equilibrium-of-forces',
    title: 'Equilibrium of forces',
    description: 'Static & dynamic equilibrium, coplanar forces, moments, and floating bodies.',
    icon: '⚖️',
    tags: ['WAEC', 'NECO', 'IGCSE', 'JUPEB'],
    topic: 'Mechanics',
    status: 'live',
  },
];

const TOPICS = ['All', 'Mechanics', 'Electricity', 'Waves', 'Optics', 'Thermal physics', 'Modern physics'];

const CURRICULUM_COLORS: Record<string, string> = {
  WAEC:  'bg-indigo-100 text-indigo-700',
  NECO:  'bg-pink-100 text-pink-700',
  IGCSE: 'bg-emerald-100 text-emerald-700',
  SAT:   'bg-orange-100 text-orange-700',
  JUPEB: 'bg-purple-100 text-purple-700',
};

export default function SimulationsPage() {
  const [selectedTopic, setSelectedTopic] = useState<string>('All');
  const visibleSims = selectedTopic === 'All'
    ? SIMULATIONS
    : SIMULATIONS.filter(sim => sim.topic === selectedTopic);

  return (
    <>
      <AppHeader />
      <main className="min-h-screen bg-gray-50">

        {/* Hero */}
        <section className="border-b border-gray-200 bg-white">
          <div className="mx-auto max-w-7xl px-4 sm:px-6 py-10 sm:py-14">
            <div className="max-w-2xl">
              <div className="mb-3 flex flex-wrap gap-2">
                {CURRICULA.map(c => (
                  <span key={c} className={`text-xs font-medium px-2.5 py-0.5 rounded-full ${CURRICULUM_COLORS[c]}`}>{c}</span>
                ))}
              </div>
              <h1 className="text-2xl sm:text-3xl font-semibold text-gray-900 leading-tight mb-3">
                Physics simulations for every curriculum
              </h1>
              <p className="text-sm sm:text-base text-gray-500 leading-relaxed">
                Interactive, AI-powered simulations built for WAEC, NECO, IGCSE, SAT and JUPEB students.
                Type a prompt or pick a topic below.
              </p>
            </div>
          </div>
        </section>

        {/* Simulations grid */}
        <section className="mx-auto max-w-7xl px-4 sm:px-6 py-8">

          {/* Topic filter — scroll on mobile */}
          <div className="flex gap-2 overflow-x-auto pb-2 mb-6 scrollbar-hide">
            {TOPICS.map(t => {
              const count = t === 'All' ? SIMULATIONS.length : SIMULATIONS.filter(sim => sim.topic === t).length;
              const active = selectedTopic === t;
              return (
                <button key={t} onClick={() => setSelectedTopic(t)}
                  className={`shrink-0 flex items-center gap-1.5 rounded-full border px-4 py-1.5 text-xs font-medium transition whitespace-nowrap ${
                    active
                      ? 'border-indigo-600 bg-indigo-600 text-white'
                      : 'border-gray-200 bg-white text-gray-600 hover:border-indigo-300 hover:text-indigo-700'
                  }`}>
                  {t}
                  <span className={`rounded-full px-1.5 text-[10px] ${active ? 'bg-white/20' : 'bg-gray-100 text-gray-400'}`}>
                    {count}
                  </span>
                </button>
              );
            })}
          </div>

          {/* Cards grid */}
          {visibleSims.length === 0 ? (
            <div className="rounded-2xl border border-dashed border-gray-200 py-16 text-center">
              <p className="text-sm text-gray-400">No simulations in {selectedTopic} yet.</p>
            </div>
          ) : (
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
            {visibleSims.map(sim => (
              <div key={sim.slug} className={`group relative rounded-2xl border bg-white overflow-hidden transition ${
                sim.status === 'live'
                  ? 'border-gray-200 hover:border-indigo-300 hover:shadow-md cursor-pointer'
                  : 'border-gray-100 opacity-70'
              }`}>
                {sim.status === 'coming' && (
                  <div className="absolute top-3 right-3 rounded-full bg-gray-100 px-2 py-0.5 text-[10px] font-medium text-gray-400">
                    Coming soon
                  </div>
                )}
                {sim.status === 'live' && (
                  <div className="absolute top-3 right-3 flex items-center gap-1">
                    <span className="h-1.5 w-1.5 rounded-full bg-emerald-500 animate-pulse"/>
                    <span className="text-[10px] font-medium text-emerald-600">Live</span>
                  </div>
                )}

                <Link href={sim.status === 'live' ? sim.href : '#'}
                  className={sim.status !== 'live' ? 'pointer-events-none' : ''}>
                  <div className="p-5">
                    {/* Icon + topic */}
                    <div className="flex items-center justify-between mb-3">
                      <span className="text-2xl">{sim.icon}</span>
                      <span className="text-[10px] font-medium text-gray-400 uppercase tracking-wide">{sim.topic}</span>
                    </div>

                    <h3 className="text-sm font-semibold text-gray-900 mb-1.5 group-hover:text-indigo-700 transition">
                      {sim.title}
                    </h3>
                    <p className="text-xs text-gray-500 leading-relaxed mb-4">{sim.description}</p>

                    {/* Curriculum tags */}
                    <div className="flex flex-wrap gap-1">
                      {sim.tags.map(tag => (
                        <span key={tag} className={`text-[10px] font-medium px-2 py-0.5 rounded-full ${CURRICULUM_COLORS[tag]}`}>
                          {tag}
                        </span>
                      ))}
                    </div>
                  </div>

                  {sim.status === 'live' && (
                    <div className="border-t border-gray-100 px-5 py-3 flex items-center justify-between">
                      <span className="text-xs font-medium text-indigo-600">Open simulation</span>
                      <svg width="14" height="14" viewBox="0 0 14 14" fill="none" stroke="#6366f1" strokeWidth="1.5" strokeLinecap="round">
                        <path d="M2 7h10M8 3l4 4-4 4"/>
                      </svg>
                    </div>
                  )}
                </Link>
              </div>
            ))}
          </div>
          )}

          {/* Coming soon note */}
          <p className="text-center text-xs text-gray-400 mt-8">
            More simulations being added weekly. Suggest a topic at{' '}
            <a href="mailto:hello@afactor.app" className="text-indigo-500 hover:underline">hello@afactor.app</a>
          </p>
        </section>
      </main>
    </>
  );
}
AFEOF

echo ""
echo "✓ Patch v25 applied — 5 files written."
echo ""
echo "Next steps:"
echo "  rm -rf .next"
echo "  npm run dev"
echo ""
echo "Check: /simulations/electrostatics-fields -- both tabs:"
echo "  Coulomb's law: press Run, watch charges attract/repel and move."
echo "  Electric field: switch configurations, drag the test point around."
echo ""
echo "Part 3 (Electric Potential, Potential Energy, Equipotential Surfaces,"
echo "and Capacitors) is next."
