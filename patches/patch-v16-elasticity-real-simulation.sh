#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
# A-Factor STEM Studio — patch v16: elasticity is now an actual animated
# simulation, not a static parameterised diagram
#
#   Confirmed: ElasticityCanvas redrew with `useEffect(() => { draw(); })` —
#   no requestAnimationFrame loop, no isRunning/isPaused, and the page had
#   no SimulationControls at all. Moving a slider redrew the picture
#   instantly; there was no actual stretching motion to watch, ever.
#
#   Rewrote it as a real phase-based simulation for both modes:
#
#   HOOKE'S LAW SPRING
#     - Press Run: the load is suddenly applied and the spring genuinely
#       overshoots past its eventual equilibrium extension before settling
#       with decaying oscillation — physically accurate damped step
#       response, not a stylised animation. The implied mass (F = mg) sets
#       a real oscillation frequency, so it's not an arbitrary timing —
#       verified numerically (overshoots to ~140% of equilibrium, settles
#       to 100% by ~1.2s for representative slider values).
#     - Once settled, a new "Remove load" action appears. Within the
#       elastic limit, the spring fully recovers to its natural length.
#       Beyond it, it recovers only the elastic portion and keeps a visible
#       PERMANENT SET — the teacher notes already taught this concept, but
#       nothing ever showed it happening. Verified end-to-end for both
#       outcomes before shipping.
#     - Added plasticExtension/permanentSet/springStepResponse to the
#       physics lib; forceExtensionCurve now reuses plasticExtension
#       instead of duplicating the same formula.
#
#   YOUNG'S MODULUS WIRE
#     - Press Run: the wire eases out to its calculated extension (real
#       wire deformation happens too fast/stiff to show meaningful
#       oscillation, so this is a clean settle rather than a bounce).
#     - Added real breaking-stress data per material (Steel 400MPa, Copper
#       220MPa, Brass 350MPa, Aluminium 150MPa, Glass 50MPa, Rubber 20MPa).
#       If the computed stress exceeds the selected material's breaking
#       stress, the wire visibly SNAPS mid-stretch instead of completing
#       the extension — verified that at the default sliders, some
#       materials survive and others don't, giving a genuine
#       compare-the-materials demo rather than everything behaving
#       identically.
#
#   Both modes are now wired into Run/Pause/Reset like every other
#   simulation in the app; the embed route was updated to match.
#
# Run from the af2s project root (Git Bash):   bash patches/patch-v16-elasticity-real-simulation.sh
# ══════════════════════════════════════════════════════════════════════════════
set -euo pipefail

if [ ! -f "package.json" ]; then
  echo "✗ Run this from the af2s project root (package.json not found)." >&2
  exit 1
fi

echo "── A-Factor patch v16: elasticity becomes a real animated simulation ──"
mkdir -p "src/app/embed/elasticity" "src/app/simulations/elasticity" "src/components/simulation" "src/lib/physics"

echo "  → src/lib/physics/elasticity.ts"
cat > "src/lib/physics/elasticity.ts" << 'AFEOF'
// ── Elasticity ────────────────────────────────────────────────────────────────
// Hooke's law:  F = ke   (up to the elastic limit / limit of proportionality)
// Energy stored (elastic PE): E = ½Fe = ½ke²
// For a wire:
//   stress σ = F/A,  strain ε = e/L,  Young's modulus E = σ/ε = FL/(Ae)

export const G = 9.81;

export function extension(F: number, k: number) {
  return k > 0 ? F / k : 0;
}
export function springEnergy(k: number, e: number) {
  return 0.5 * k * e * e;
}
export function stress(F: number, A: number) {
  return A > 0 ? F / A : 0;
}
export function strain(e: number, L: number) {
  return L > 0 ? e / L : 0;
}
export function youngModulus(F: number, A: number, e: number, L: number) {
  const s = strain(e, L);
  return s > 0 ? stress(F, A) / s : 0;
}
// Wire extension from Young's modulus: e = FL/(AE)
export function wireExtension(F: number, L: number, A: number, E: number) {
  return A > 0 && E > 0 ? (F * L) / (A * E) : 0;
}

// Extension including the plastic region beyond the elastic limit — same
// shape used by forceExtensionCurve, exposed directly as a function of F so
// canvases can evaluate a single target extension without sampling a curve.
export function plasticExtension(F: number, k: number, elasticLimitF: number): number {
  const eLimit = elasticLimitF / k;
  if (F <= elasticLimitF) return F / k;
  const dF = F - elasticLimitF;
  return eLimit + (dF / k) * (1 + 3 * (dF / elasticLimitF));
}

// The permanent "set" left behind after a plastically-deformed spring is
// unloaded. Unloading follows a path parallel to the original elastic
// slope (the standard simplified model for this level) — elastic recovery
// removes exactly the elastic limit's worth of extension, leaving the rest
// as permanent deformation.
export function permanentSet(F: number, k: number, elasticLimitF: number): number {
  if (F <= elasticLimitF) return 0;
  return plasticExtension(F, k, elasticLimitF) - elasticLimitF / k;
}

// Damped step response of a spring suddenly loaded with mass m = F/g: this
// is what you actually see if you hang a weight on a spring and let go —
// it overshoots past the eventual equilibrium and settles with decaying
// oscillation, not a smooth glide straight to eEq. ω is derived from the
// real implied mass, so the oscillation frequency is physically genuine,
// not just a stylised animation.
export function springStepResponse(t: number, eEq: number, k: number, mass: number, zeta = 0.28): number {
  if (mass <= 0 || k <= 0 || t <= 0) return 0;
  const omega = Math.sqrt(k / mass);
  if (zeta >= 1) return eEq * (1 - Math.exp(-omega * t)); // overdamped fallback
  const omegaD = omega * Math.sqrt(1 - zeta * zeta);
  return eEq * (1 - Math.exp(-zeta * omega * t) * (Math.cos(omegaD * t) + (zeta * omega / omegaD) * Math.sin(omegaD * t)));
}

export const WIRE_MATERIALS = [
  { name: 'Steel',     E: 200e9,  breakingStressMPa: 400 },
  { name: 'Copper',    E: 117e9,  breakingStressMPa: 220 },
  { name: 'Brass',     E: 100e9,  breakingStressMPa: 350 },
  { name: 'Aluminium', E: 69e9,   breakingStressMPa: 150 },
  { name: 'Glass',     E: 70e9,   breakingStressMPa: 50 },
  { name: 'Rubber',    E: 0.05e9, breakingStressMPa: 20 },
] as const;

// Force–extension curve: linear (Hooke) up to the elastic limit, then a
// flattening plastic region — the classic exam graph.
export function forceExtensionCurve(k: number, elasticLimitF: number, fMax: number, points = 100) {
  return Array.from({ length: points + 1 }, (_, i) => {
    const F = (i / points) * fMax;
    return { e: +(plasticExtension(F, k, elasticLimitF) * 100).toFixed(3), F: +F.toFixed(2) }; // e in cm for the graph
  });
}
AFEOF

echo "  → src/components/simulation/ElasticityCanvas.tsx"
cat > "src/components/simulation/ElasticityCanvas.tsx" << 'AFEOF'
'use client';
import { useRef, useEffect, useCallback } from 'react';
import { plasticExtension, permanentSet, springStepResponse, springEnergy, wireExtension, stress, strain, G } from '@/lib/physics/elasticity';

export type ElasticityMode = 'hooke' | 'wire';

interface Props {
  mode: ElasticityMode;
  load: number;          // N
  k: number;              // N/m (hooke mode)
  elasticLimitF: number;
  // wire mode:
  wireLength: number;     // m
  wireDiamMm: number;     // mm
  youngE: number;         // Pa
  materialName: string;
  breakingStressMPa: number;
  isRunning: boolean; isPaused: boolean;
  unloadKey: number;      // increments to trigger "remove load" (hooke, once settled)
  onSettled?: () => void;
  onBroken?: () => void;
  width?: number; height?: number;
}

type HookePhase = 'unloaded' | 'settling' | 'settled' | 'unloading' | 'recovered' | 'permanent';
type WirePhase = 'unloaded' | 'stretching' | 'stretched' | 'breaking' | 'broken';

function drawCoil(ctx: CanvasRenderingContext2D, x: number, yTop: number, len: number, coils = 10, r = 16) {
  ctx.save();
  ctx.strokeStyle = '#64748b'; ctx.lineWidth = 2.5; ctx.lineJoin = 'round';
  ctx.beginPath();
  ctx.moveTo(x, yTop);
  const seg = len / (coils + 1);
  ctx.lineTo(x, yTop + seg / 2);
  for (let i = 0; i < coils; i++) {
    ctx.lineTo(x + (i % 2 === 0 ? r : -r), yTop + seg / 2 + seg * i + seg / 2);
  }
  ctx.lineTo(x, yTop + len - seg / 2);
  ctx.lineTo(x, yTop + len);
  ctx.stroke();
  ctx.restore();
}

function easeOutCubic(x: number) { return 1 - Math.pow(1 - Math.min(Math.max(x, 0), 1), 3); }

export function ElasticityCanvas({
  mode, load, k, elasticLimitF, wireLength, wireDiamMm, youngE, materialName, breakingStressMPa,
  isRunning, isPaused, unloadKey, onSettled, onBroken, width = 640, height = 320,
}: Props) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const rafRef = useRef<number>(0);
  const lastFrameRef = useRef<number | null>(null);
  const t = useRef(0);            // time since the current phase began
  const hookePhase = useRef<HookePhase>('unloaded');
  const wirePhase = useRef<WirePhase>('unloaded');
  const eAtPhaseStart = useRef(0); // extension when the current phase began (for the unloading leg)
  const lastUnloadKey = useRef(unloadKey);
  const settledFired = useRef(false);
  const brokenFired = useRef(false);
  const sim = useRef({
    mode, load, k, elasticLimitF, wireLength, wireDiamMm, youngE, materialName, breakingStressMPa,
    isRunning, isPaused, onSettled, onBroken,
  });
  sim.current = {
    mode, load, k, elasticLimitF, wireLength, wireDiamMm, youngE, materialName, breakingStressMPa,
    isRunning, isPaused, onSettled, onBroken,
  };

  // Physics parameters change -> start over from unloaded.
  useEffect(() => {
    t.current = 0;
    hookePhase.current = 'unloaded';
    wirePhase.current = 'unloaded';
    eAtPhaseStart.current = 0;
    lastFrameRef.current = null;
    settledFired.current = false;
    brokenFired.current = false;
  }, [mode, load, k, elasticLimitF, wireLength, wireDiamMm, youngE, breakingStressMPa]);

  // "Remove load" trigger for the hooke mode, once settled.
  useEffect(() => {
    if (unloadKey !== lastUnloadKey.current) {
      lastUnloadKey.current = unloadKey;
      if (hookePhase.current === 'settled') {
        hookePhase.current = 'unloading';
        t.current = 0;
      }
    }
  }, [unloadKey]);

  const draw = useCallback((timestamp?: number) => {
    const canvas = canvasRef.current; if (!canvas) return;
    const ctx = canvas.getContext('2d'); if (!ctx) return;
    const s = sim.current;
    const W = canvas.width, H = canvas.height;

    let dt = 0;
    if (s.isRunning && !s.isPaused && timestamp !== undefined) {
      if (lastFrameRef.current !== null) {
        dt = Math.min((timestamp - lastFrameRef.current) / 1000, 0.1);
      }
      lastFrameRef.current = timestamp;
    } else {
      lastFrameRef.current = timestamp ?? null;
    }

    ctx.clearRect(0, 0, W, H);
    ctx.fillStyle = '#f8fafc'; ctx.fillRect(0, 0, W, H);

    // Ceiling
    ctx.fillStyle = '#cbd5e1'; ctx.fillRect(0, 20, W, 10);
    ctx.strokeStyle = '#94a3b8';
    for (let x = 6; x < W; x += 14) {
      ctx.beginPath(); ctx.moveTo(x, 20); ctx.lineTo(x - 6, 12); ctx.stroke();
    }

    if (s.mode === 'hooke') {
      const eEq = plasticExtension(s.load, s.k, s.elasticLimitF);
      const eLimit = s.elasticLimitF / s.k;
      const beyondLimit = s.load > s.elasticLimitF;
      const ePermanent = permanentSet(s.load, s.k, s.elasticLimitF);
      const mass = s.load / G;
      const zeta = 0.28;
      const omega = Math.sqrt(s.k / Math.max(mass, 0.01));
      const settleTime = 3.91 / (zeta * omega); // time for the 2% decay envelope

      // Advance the phase's local clock, and step transitions.
      if (dt > 0) {
        if (hookePhase.current === 'unloaded' && s.isRunning) {
          hookePhase.current = 'settling'; t.current = 0;
        } else {
          t.current += dt;
        }
        if (hookePhase.current === 'settling' && t.current >= settleTime) {
          hookePhase.current = 'settled';
          if (!settledFired.current) { settledFired.current = true; s.onSettled?.(); }
        }
        if (hookePhase.current === 'unloading') {
          const dropSettle = 3.91 / (zeta * omega); // same envelope shape for the release leg
          if (t.current >= dropSettle) {
            hookePhase.current = ePermanent > 0.0005 ? 'permanent' : 'recovered';
          }
        }
      }

      // Current extension as a pure function of phase + local time.
      let e: number;
      if (hookePhase.current === 'unloaded') e = 0;
      else if (hookePhase.current === 'settling') e = springStepResponse(t.current, eEq, s.k, mass, zeta);
      else if (hookePhase.current === 'settled') e = eEq;
      else if (hookePhase.current === 'unloading') {
        const drop = eEq - ePermanent;
        e = eEq - springStepResponse(t.current, drop, s.k, mass, zeta);
      } else e = ePermanent; // 'recovered' (0) or 'permanent'

      const eScale = 900; // px per metre
      const natural = 90;
      const xUnloaded = W / 2 - 130, xLoaded = W / 2 + 90;

      // Reference (unloaded) spring
      drawCoil(ctx, xUnloaded, 30, natural);
      ctx.strokeStyle = '#cbd5e1'; ctx.setLineDash([4, 4]);
      ctx.beginPath(); ctx.moveTo(xUnloaded - 60, 30 + natural); ctx.lineTo(xLoaded + 80, 30 + natural); ctx.stroke();
      ctx.setLineDash([]);
      ctx.fillStyle = '#94a3b8'; ctx.font = '10px system-ui'; ctx.textAlign = 'center';
      ctx.fillText('natural length', xUnloaded, 30 + natural + 18);

      // Loaded spring
      const stretch = Math.min(Math.max(e, 0) * eScale, H - 200);
      drawCoil(ctx, xLoaded, 30, natural + stretch);
      const showMass = hookePhase.current !== 'unloaded';
      if (showMass) {
        const mw = 56, mh = 40;
        const beyondNow = e * s.k > s.elasticLimitF + 0.01;
        ctx.fillStyle = beyondNow ? '#ef4444' : '#6366f1';
        ctx.fillRect(xLoaded - mw / 2, 30 + natural + stretch, mw, mh);
        ctx.fillStyle = 'white'; ctx.font = 'bold 11px system-ui'; ctx.textAlign = 'center';
        const shownLoad = hookePhase.current === 'unloading' || hookePhase.current === 'recovered' || hookePhase.current === 'permanent' ? 0 : s.load;
        ctx.fillText(`${shownLoad.toFixed(0)}N`, xLoaded, 30 + natural + stretch + mh / 2 + 4);
      }

      // Extension bracket
      if (stretch > 6) {
        const bx = xLoaded + 60;
        ctx.strokeStyle = '#10b981'; ctx.lineWidth = 1.5;
        ctx.beginPath(); ctx.moveTo(bx, 30 + natural); ctx.lineTo(bx, 30 + natural + stretch); ctx.stroke();
        [30 + natural, 30 + natural + stretch].forEach(y => {
          ctx.beginPath(); ctx.moveTo(bx - 4, y); ctx.lineTo(bx + 4, y); ctx.stroke();
        });
        ctx.fillStyle = '#059669'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'left';
        ctx.fillText(`e = ${(Math.max(e, 0) * 100).toFixed(1)} cm`, bx + 8, 30 + natural + stretch / 2 + 3);
      }
      // Elastic-limit marker, so the overshoot past it is visible during settling
      const limitStretch = eLimit * eScale;
      if (limitStretch > 4 && limitStretch < H - 200) {
        ctx.strokeStyle = '#f59e0b'; ctx.setLineDash([3, 3]); ctx.lineWidth = 1;
        ctx.beginPath(); ctx.moveTo(xLoaded - 40, 30 + natural + limitStretch); ctx.lineTo(xLoaded + 40, 30 + natural + limitStretch); ctx.stroke();
        ctx.setLineDash([]);
      }

      ctx.font = 'bold 11px system-ui'; ctx.textAlign = 'center';
      if (hookePhase.current === 'unloaded') {
        ctx.fillStyle = '#6366f1';
        ctx.fillText('Press Run to hang the load and watch it settle', W / 2, H - 30);
      } else if (hookePhase.current === 'settling') {
        ctx.fillStyle = '#6366f1';
        ctx.fillText('Settling — a suddenly-applied load overshoots before it damps out', W / 2, H - 30);
      } else if (hookePhase.current === 'settled' && beyondLimit) {
        ctx.fillStyle = '#ef4444';
        ctx.fillText(`BEYOND THE ELASTIC LIMIT (${s.elasticLimitF}N) — permanent deformation once unloaded`, W / 2, H - 30);
      } else if (hookePhase.current === 'settled') {
        ctx.fillStyle = '#059669';
        ctx.fillText(`Settled — energy stored = ½Fe = ${springEnergy(s.k, eEq).toFixed(2)} J`, W / 2, H - 30);
      } else if (hookePhase.current === 'unloading') {
        ctx.fillStyle = '#f59e0b';
        ctx.fillText('Load removed — recovering…', W / 2, H - 30);
      } else if (hookePhase.current === 'recovered') {
        ctx.fillStyle = '#059669';
        ctx.fillText('Fully recovered to natural length — within the elastic limit', W / 2, H - 30);
      } else {
        ctx.fillStyle = '#ef4444';
        ctx.fillText(`PERMANENT SET = ${(ePermanent * 100).toFixed(1)} cm — it never returns to natural length`, W / 2, H - 30);
      }
      ctx.fillStyle = '#64748b'; ctx.font = '10px system-ui'; ctx.textAlign = 'left';
      ctx.fillText(`k = ${s.k} N/m   equilibrium: F = ke → e = ${(eEq * 100).toFixed(1)} cm`, 8, H - 10);
    }

    if (s.mode === 'wire') {
      const A = Math.PI * Math.pow((s.wireDiamMm / 1000) / 2, 2);
      const eTarget = wireExtension(s.load, s.wireLength, A, s.youngE);
      const sg = stress(s.load, A);
      const sn = strain(eTarget, s.wireLength);
      const willBreak = sg / 1e6 > s.breakingStressMPa;
      const STRETCH_DURATION = 0.8;

      if (dt > 0) {
        if (wirePhase.current === 'unloaded' && s.isRunning) {
          wirePhase.current = willBreak ? 'breaking' : 'stretching'; t.current = 0;
        } else {
          t.current += dt;
        }
        if (wirePhase.current === 'stretching' && t.current >= STRETCH_DURATION) wirePhase.current = 'stretched';
        if (wirePhase.current === 'breaking' && t.current >= STRETCH_DURATION * 0.65) {
          wirePhase.current = 'broken';
          if (!brokenFired.current) { brokenFired.current = true; s.onBroken?.(); }
        }
      }

      const progress = wirePhase.current === 'breaking'
        ? easeOutCubic(t.current / (STRETCH_DURATION * 0.65))
        : easeOutCubic(t.current / STRETCH_DURATION);
      const e = wirePhase.current === 'unloaded' ? 0
        : wirePhase.current === 'broken' ? eTarget * 0.65
        : eTarget * Math.min(progress, 1);

      const x = W / 2 - 60;
      const naturalPx = H - 150;
      // Real extensions are fractions of a millimetre — magnified ×2000 on
      // screen so students can SEE it; true values printed below.
      const MAG = 2000;
      const stretchPx = Math.min(e * MAG, 90);

      // Reference end marker
      ctx.strokeStyle = '#cbd5e1'; ctx.setLineDash([4, 4]); ctx.lineWidth = 1;
      ctx.beginPath(); ctx.moveTo(x - 70, 30 + naturalPx); ctx.lineTo(x + 150, 30 + naturalPx); ctx.stroke();
      ctx.setLineDash([]);

      if (wirePhase.current === 'broken') {
        // Snapped: two loose ends, load fallen away.
        const breakY = 30 + naturalPx * 0.55;
        const fall = Math.min((t.current - STRETCH_DURATION * 0.65) * 260, H);
        ctx.strokeStyle = '#64748b'; ctx.lineWidth = Math.max(1.5, s.wireDiamMm * 3);
        ctx.beginPath(); ctx.moveTo(x, 30); ctx.lineTo(x - 3, breakY - 6); ctx.stroke();
        ctx.beginPath(); ctx.moveTo(x + 4, breakY + 10 + fall); ctx.lineTo(x, 30 + naturalPx + stretchPx + fall); ctx.stroke();
        const mw = 60, mh = 40;
        ctx.fillStyle = '#ef4444';
        ctx.fillRect(x - mw / 2, 30 + naturalPx + stretchPx + fall, mw, mh);
        ctx.fillStyle = 'white'; ctx.font = 'bold 11px system-ui'; ctx.textAlign = 'center';
        ctx.fillText(`${s.load.toFixed(0)}N`, x, 30 + naturalPx + stretchPx + fall + mh / 2 + 4);
        ctx.fillStyle = '#ef4444'; ctx.font = 'bold 12px system-ui';
        ctx.fillText('💥 SNAPPED', x, breakY - 16);
      } else {
        ctx.strokeStyle = '#64748b'; ctx.lineWidth = Math.max(1.5, s.wireDiamMm * 3);
        ctx.beginPath(); ctx.moveTo(x, 30); ctx.lineTo(x, 30 + naturalPx + stretchPx); ctx.stroke();
        if (wirePhase.current !== 'unloaded') {
          const mw = 60, mh = 40;
          ctx.fillStyle = '#6366f1';
          ctx.fillRect(x - mw / 2, 30 + naturalPx + stretchPx, mw, mh);
          ctx.fillStyle = 'white'; ctx.font = 'bold 11px system-ui'; ctx.textAlign = 'center';
          ctx.fillText(`${s.load.toFixed(0)}N`, x, 30 + naturalPx + stretchPx + mh / 2 + 4);
        }
        if (stretchPx > 3) {
          const bx = x + 70;
          ctx.strokeStyle = '#10b981'; ctx.lineWidth = 1.5;
          ctx.beginPath(); ctx.moveTo(bx, 30 + naturalPx); ctx.lineTo(bx, 30 + naturalPx + stretchPx); ctx.stroke();
          ctx.fillStyle = '#059669'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'left';
          ctx.fillText(`e = ${(e * 1000).toFixed(3)} mm (shown ×${MAG})`, bx + 8, 30 + naturalPx + stretchPx / 2 + 3);
        }
      }

      // Info card
      ctx.save();
      const cx0 = W - 250, cy0 = 46;
      ctx.fillStyle = 'rgba(255,255,255,0.9)';
      ctx.beginPath(); ctx.roundRect(cx0, cy0, 236, 134, 10); ctx.fill();
      ctx.strokeStyle = '#e2e8f0'; ctx.stroke();
      ctx.fillStyle = '#334155'; ctx.font = 'bold 11px system-ui'; ctx.textAlign = 'left';
      ctx.fillText(`${s.materialName} wire`, cx0 + 12, cy0 + 20);
      ctx.font = '10px monospace'; ctx.fillStyle = '#475569';
      const lines = [
        `L = ${s.wireLength} m,  d = ${s.wireDiamMm} mm`,
        `A = πd²/4 = ${(A * 1e6).toFixed(4)} mm²`,
        `stress σ = F/A = ${(sg / 1e6).toFixed(1)} MPa`,
        `strain ε = e/L = ${sn.toExponential(2)}`,
        `E = σ/ε = ${(s.youngE / 1e9).toFixed(0)} GPa`,
        `breaks at ${s.breakingStressMPa} MPa`,
      ];
      lines.forEach((l, i) => ctx.fillText(l, cx0 + 12, cy0 + 40 + i * 16));
      ctx.restore();

      ctx.font = 'bold 11px system-ui'; ctx.textAlign = 'center';
      if (wirePhase.current === 'unloaded') {
        ctx.fillStyle = '#6366f1';
        ctx.fillText('Press Run to hang the load', W / 2 - 60, H - 30);
      } else if (willBreak) {
        ctx.fillStyle = '#ef4444';
        ctx.fillText(`σ = ${(sg / 1e6).toFixed(0)} MPa exceeds ${s.materialName}'s breaking stress`, W / 2 - 60, H - 30);
      }
      ctx.fillStyle = '#64748b'; ctx.font = '10px system-ui'; ctx.textAlign = 'left';
      ctx.fillText(`Young's modulus is a MATERIAL property — same E whatever the wire's size. e = FL/(AE)`, 8, H - 10);
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
AFEOF

echo "  → src/app/simulations/elasticity/page.tsx"
cat > "src/app/simulations/elasticity/page.tsx" << 'AFEOF'
'use client';
import { useState, useMemo, useRef, useCallback, useEffect } from 'react';
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, Label, ReferenceDot, ReferenceLine } from 'recharts';
import { AppHeader } from '@/components/layout/AppHeader';
import { SimulationControls } from '@/components/simulation/SimulationControls';
import { ElasticityCanvas, ElasticityMode } from '@/components/simulation/ElasticityCanvas';
import { EmbedButton } from '@/components/ui/EmbedButton';
import { extension, springEnergy, forceExtensionCurve, wireExtension, stress, strain, youngModulus, WIRE_MATERIALS } from '@/lib/physics/elasticity';
import { useResponsiveCanvasSize } from '@/hooks/useResponsiveCanvasSize';

const CURRICULA = ['WAEC', 'NECO', 'IGCSE', 'SAT', 'JUPEB'];
const CC: Record<string, string> = {
  WAEC: 'bg-indigo-100 text-indigo-700', NECO: 'bg-pink-100 text-pink-700',
  IGCSE: 'bg-emerald-100 text-emerald-700', SAT: 'bg-orange-100 text-orange-700',
  JUPEB: 'bg-purple-100 text-purple-700',
};

const MODE_META: Record<ElasticityMode, { title: string; icon: string; sub: string; eq: string }> = {
  hooke: { title: "Hooke's law", icon: '🌀', sub: 'A loaded spring',       eq: 'F = ke' },
  wire:  { title: 'Young modulus', icon: '🧵', sub: 'Stretching a wire', eq: 'E = σ/ε = FL/(Ae)' },
};

const TEACHER_NOTES: Record<ElasticityMode, string[]> = {
  hooke: [
    "Hooke's law: extension is directly proportional to the applied force, e ∝ F, i.e. F = ke — but only up to the ELASTIC LIMIT.",
    'Beyond the elastic limit the spring deforms PERMANENTLY: it will not return to its natural length when the load is removed, and F = ke no longer applies.',
    'The spring constant k (N/m) measures stiffness: a bigger k means a stiffer spring that stretches less for the same force.',
    'Energy stored in a stretched (or compressed) spring: E = ½Fe = ½ke² — the area under a force–extension graph, used in catapults, archery bows, and pogo sticks.',
    'Springs in series share the load but each stretches independently (softer overall); springs in parallel share the extension (stiffer overall) — a nice follow-up demonstration.',
  ],
  wire: [
    'Stress σ = F/A (force per unit cross-sectional area) and strain ε = e/L (extension per unit original length) — both are needed because a thick wire stretches less than a thin one under the same force.',
    "Young's modulus E = σ/ε is a property of the MATERIAL only — steel always has the same E, whatever the wire's length or thickness.",
    'Real wire extensions under normal loads are tiny (often fractions of a millimetre) — this simulation magnifies the extension so you can see it; the true value is always shown in the info card.',
    'A stress–strain graph for a ductile material (like copper) shows a straight (Hookean) region, then plastic deformation, then a breaking point — steel and glass behave very differently here.',
    'Practical use: engineers select materials by their E value — steel cables for bridges need high E (stiff, minimal sag) while rubber seals need low E (flexible).',
  ],
};

const EXERCISES: Record<ElasticityMode, { q: string; a: string }[]> = {
  hooke: [
    { q: 'A spring stretches 4cm under a 20N load. Find its spring constant k.', a: 'k = F/e = 20/0.04 = 500 N/m.' },
    { q: 'A spring of k=250 N/m is stretched by 6cm. Find the elastic energy stored.', a: 'E = ½ke² = ½×250×0.06² = 0.45 J.' },
    { q: 'A spring obeys Hooke\'s law up to 30N, extending 10cm at that load. What extension would 45N (beyond the limit) roughly NOT follow, and why?', a: 'It would NOT simply extend to 15cm proportionally — beyond the elastic limit the material deforms plastically and extension grows faster than F for a given increase in load, and the deformation becomes permanent.' },
  ],
  wire: [
    { q: 'A steel wire (E=200 GPa) of length 2m and cross-sectional area 1×10⁻⁶ m² carries a 100N load. Find its extension.', a: 'e = FL/(AE) = (100×2)/(1e-6×200e9) = 200/200000 = 1×10⁻³ m = 1mm.' },
    { q: 'A wire of diameter 0.5mm stretches 0.8mm under a 50N load over 1.5m. Find the stress and strain.', a: 'A=π(0.00025)²≈1.96×10⁻⁷m². σ=F/A=50/1.96e-7≈2.55×10⁸ Pa. ε=e/L=0.0008/1.5≈5.33×10⁻⁴.' },
    { q: 'Using the previous answer, find the Young\'s modulus.', a: 'E=σ/ε=2.55×10⁸/5.33×10⁻⁴≈4.78×10¹¹ Pa ≈ 478 GPa.' },
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

function ForceExtensionGraph({ k, elasticLimitF, load }: { k: number; elasticLimitF: number; load: number }) {
  const fMax = elasticLimitF * 2.2;
  const data = useMemo(() => forceExtensionCurve(k, elasticLimitF, fMax), [k, elasticLimitF, fMax]);
  const e = extension(Math.min(load, elasticLimitF), k) * 100;
  const eLimitCm = (elasticLimitF / k) * 100;
  return (
    <ResponsiveContainer width="100%" height={190}>
      <LineChart data={data} margin={{ top: 8, right: 16, left: 10, bottom: 28 }}>
        <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
        <XAxis dataKey="e" type="number" tick={{ fontSize: 10 }}>
          <Label value="Extension e (cm)" position="insideBottom" offset={-16} style={{ fontSize: 10, fill: '#94a3b8' }} />
        </XAxis>
        <YAxis dataKey="F" tick={{ fontSize: 10 }}>
          <Label value="Force F (N)" angle={-90} position="insideLeft" offset={12} style={{ fontSize: 10, fill: '#94a3b8' }} />
        </YAxis>
        <Tooltip formatter={(v: unknown) => [Number(v).toFixed(2) + ' N', 'F']} labelFormatter={e => `e=${Number(e).toFixed(2)}cm`} />
        <Line type="linear" dataKey="F" stroke="#6366f1" strokeWidth={2} dot={false} isAnimationActive={false} />
        <ReferenceLine x={eLimitCm} stroke="#f59e0b" strokeDasharray="4 4"
          label={{ value: 'elastic limit', position: 'top', fontSize: 9, fill: '#d97706' }} />
        <ReferenceDot x={e} y={Math.min(load, elasticLimitF)} r={6} fill="#ef4444" stroke="#fff" strokeWidth={2} />
      </LineChart>
    </ResponsiveContainer>
  );
}

export default function ElasticityPage() {
  const [mode, setMode] = useState<ElasticityMode>('hooke');
  const [openEx, setOpenEx] = useState<number | null>(null);
  const [activeCurricula, setActiveCurricula] = useState(['WAEC', 'IGCSE', 'SAT']);

  const [load, setLoad] = useState(8);
  const [k, setK] = useState(200);
  const [elasticLimitF, setElasticLimitF] = useState(15);

  const [wireLength, setWireLength] = useState(2);
  const [wireDiamMm, setWireDiamMm] = useState(0.5);
  const [matIdx, setMatIdx] = useState(0);
  const [wireLoad, setWireLoad] = useState(60);
  const material = WIRE_MATERIALS[matIdx];

  const [isRunning, setIsRunning] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const [resetKey, setResetKey] = useState(0);
  const [unloadKey, setUnloadKey] = useState(0);
  const [settled, setSettled] = useState(false);
  const [broken, setBroken] = useState(false);

  const A = Math.PI * Math.pow((wireDiamMm / 1000) / 2, 2);
  const e = wireExtension(wireLoad, wireLength, A, material.E);

  const reset = useCallback(() => {
    setIsRunning(false); setIsPaused(false);
    setResetKey(k => k + 1);
    setSettled(false); setBroken(false);
  }, []);

  const resetTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  useEffect(() => {
    if (resetTimer.current) clearTimeout(resetTimer.current);
    resetTimer.current = setTimeout(reset, 100);
  }, [mode, load, k, elasticLimitF, wireLength, wireDiamMm, matIdx, wireLoad, reset]);

  const canvasBoxRef = useRef<HTMLDivElement>(null);
  const canvasSize = useResponsiveCanvasSize(canvasBoxRef, 640, 320, 980);

  return (
    <>
      <AppHeader />
      <main className="min-h-screen bg-gray-50">
        <section className="border-b border-gray-200 bg-white">
          <div className="mx-auto max-w-[100rem] px-4 sm:px-6 py-4">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
              <div>
                <p className="text-xs text-gray-400 mb-0.5">Mechanics</p>
                <h1 className="text-lg font-semibold text-gray-900">Elasticity</h1>
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
            {(Object.keys(MODE_META) as ElasticityMode[]).map(m => (
              <button key={m} onClick={() => { setMode(m); setOpenEx(null); }}
                className={`shrink-0 flex items-center gap-1.5 px-3 py-2 rounded-lg text-xs font-medium transition ${
                  mode === m ? 'bg-white text-indigo-700 shadow-sm' : 'text-gray-500 hover:text-gray-700'
                }`}>
                <span>{MODE_META[m].icon}</span><span>{MODE_META[m].title}</span>
              </button>
            ))}
          </div>

          <div className="flex flex-wrap items-center gap-3 rounded-xl border border-gray-200 bg-white px-4 py-2.5">
            <span className="text-xs text-gray-400">{MODE_META[mode].sub}</span>
            <span className="text-sm font-semibold font-mono text-gray-900">{MODE_META[mode].eq}</span>
          </div>

          <div className="grid grid-cols-1 lg:grid-cols-[1fr_220px] xl:grid-cols-[1fr_220px_260px] gap-4">
            <div className="space-y-3 min-w-0">
              <div ref={canvasBoxRef} className="rounded-2xl border border-gray-200 bg-white p-3 shadow-sm">
                <ElasticityCanvas key={resetKey} mode={mode}
                  load={mode === 'hooke' ? load : wireLoad} k={k} elasticLimitF={elasticLimitF}
                  wireLength={wireLength} wireDiamMm={wireDiamMm} youngE={material.E} materialName={material.name}
                  breakingStressMPa={material.breakingStressMPa}
                  isRunning={isRunning} isPaused={isPaused} unloadKey={unloadKey}
                  onSettled={() => setSettled(true)} onBroken={() => setBroken(true)}
                  width={canvasSize.width} height={canvasSize.height} />
              </div>

              <div className="flex flex-wrap items-center justify-between gap-2">
                <SimulationControls isRunning={isRunning} isPaused={isPaused}
                  onRun={() => { setIsRunning(true); setIsPaused(false); }}
                  onPause={() => setIsPaused(p => !p)} onReset={reset} />
                {mode === 'hooke' && settled && (
                  <button onClick={() => { setUnloadKey(k => k + 1); setSettled(false); }}
                    className="rounded-lg border border-gray-200 bg-white px-4 py-2 text-sm font-medium text-gray-600 transition hover:bg-gray-50">
                    Remove load
                  </button>
                )}
                {mode === 'wire' && broken && (
                  <span className="text-xs font-medium text-red-600">💥 Snapped — Reset to try again</span>
                )}
              </div>

              <div className="flex justify-end">
                <EmbedButton path="/embed/elasticity"
                  title={`${MODE_META[mode].title} — A-Factor STEM Studio`}
                  params={mode === 'hooke' ? { mode, load, k, limit: elasticLimitF } : { mode, mat: matIdx, L: wireLength, d: wireDiamMm, F: wireLoad }} />
              </div>

              {mode === 'hooke' && (
                <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                  <p className="text-xs font-medium text-gray-400 uppercase tracking-wide mb-2">Force–extension graph</p>
                  <ForceExtensionGraph k={k} elasticLimitF={elasticLimitF} load={load} />
                  <p className="text-[10px] text-gray-400 mt-2 text-center">
                    Linear (Hooke) region, then plastic deformation beyond the elastic limit
                  </p>
                </div>
              )}

              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm space-y-4">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide">Parameters</p>
                {mode === 'hooke' && <>
                  <Slider label="Load F" unit="N" value={load} min={0} max={30} step={0.5} set={setLoad} color="#6366f1" />
                  <Slider label="Spring constant k" unit="N/m" value={k} min={50} max={500} step={10} set={setK} color="#f59e0b" />
                  <Slider label="Elastic limit" unit="N" value={elasticLimitF} min={5} max={25} step={1} set={setElasticLimitF} color="#ef4444" />
                </>}
                {mode === 'wire' && <>
                  <div className="flex flex-wrap gap-1.5">
                    {WIRE_MATERIALS.map((m, i) => (
                      <button key={m.name} onClick={() => setMatIdx(i)}
                        className={`rounded-full border px-2.5 py-2 text-[11px] font-medium transition ${
                          matIdx === i ? 'border-indigo-300 bg-indigo-50 text-indigo-700' : 'border-gray-200 bg-white text-gray-500 hover:border-indigo-200'
                        }`}>{m.name}</button>
                    ))}
                  </div>
                  <Slider label="Load F" unit="N" value={wireLoad} min={5} max={200} step={5} set={setWireLoad} color="#6366f1" />
                  <Slider label="Wire length L" unit="m" value={wireLength} min={0.5} max={5} step={0.1} set={setWireLength} color="#10b981" />
                  <Slider label="Wire diameter" unit="mm" value={wireDiamMm} min={0.1} max={2} step={0.05} set={setWireDiamMm} color="#8b5cf6" />
                </>}
              </div>
            </div>

            <div className="space-y-3">
              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide mb-3">Calculated</p>
                <div className="space-y-2">
                  {mode === 'hooke' && <>
                    <StatRow label="Extension e" value={(extension(Math.min(load, elasticLimitF), k) * 100).toFixed(2)} unit="cm" color="text-indigo-600" />
                    <StatRow label="Energy stored" value={springEnergy(k, extension(Math.min(load, elasticLimitF), k)).toFixed(3)} unit="J" color="text-emerald-600" />
                    <StatRow label="Within limit?" value={load <= elasticLimitF ? 'yes' : 'NO — plastic'} unit="" color="text-amber-600" />
                  </>}
                  {mode === 'wire' && <>
                    <StatRow label="Cross-section A" value={(A * 1e6).toFixed(4)} unit="mm²" color="text-indigo-600" />
                    <StatRow label="Stress σ" value={(stress(wireLoad, A) / 1e6).toFixed(1)} unit="MPa" color="text-emerald-600" />
                    <StatRow label="Strain ε" value={strain(e, wireLength).toExponential(2)} unit="" color="text-amber-600" />
                    <StatRow label="Extension e" value={(e * 1000).toFixed(3)} unit="mm" color="text-rose-500" />
                    <StatRow label="Young modulus" value={(youngModulus(wireLoad, A, e, wireLength) / 1e9).toFixed(0)} unit="GPa" color="text-purple-600" />
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
                  {TEACHER_NOTES[mode].map((n, i) => (
                    <li key={i} className="text-xs text-amber-900 leading-relaxed flex gap-2">
                      <span className="text-amber-400 shrink-0 mt-0.5">•</span>{n}
                    </li>
                  ))}
                </ul>
              </div>

              <div className="rounded-2xl border border-gray-200 bg-white p-4">
                <p className="text-xs font-medium text-gray-500 uppercase tracking-wide mb-3">✏️ Exercises</p>
                <div className="space-y-2">
                  {EXERCISES[mode].map((ex, i) => (
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

echo "  → src/app/embed/elasticity/page.tsx"
cat > "src/app/embed/elasticity/page.tsx" << 'AFEOF'
'use client';
import { Suspense, useState, useCallback, useEffect, useRef } from 'react';
import { useSearchParams } from 'next/navigation';
import { ElasticityCanvas, ElasticityMode } from '@/components/simulation/ElasticityCanvas';
import { SimulationControls } from '@/components/simulation/SimulationControls';
import { WIRE_MATERIALS } from '@/lib/physics/elasticity';

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

function ElasticityEmbedInner() {
  const sp = useSearchParams();
  const mode = ((): ElasticityMode => (sp.get('mode') === 'wire' ? 'wire' : 'hooke'))();
  const showControls = sp.get('controls') !== '0';

  const [load, setLoad] = useState(() => num(sp, 'load', 8, 0, 30));
  const [k, setK] = useState(() => num(sp, 'k', 200, 50, 500));
  const [elasticLimitF, setElasticLimitF] = useState(() => num(sp, 'limit', 15, 5, 25));

  const [matIdx, setMatIdx] = useState(() => Math.round(num(sp, 'mat', 0, 0, WIRE_MATERIALS.length - 1)));
  const [wireLength, setWireLength] = useState(() => num(sp, 'L', 2, 0.5, 5));
  const [wireDiamMm, setWireDiamMm] = useState(() => num(sp, 'd', 0.5, 0.1, 2));
  const [wireLoad, setWireLoad] = useState(() => num(sp, 'F', 60, 5, 200));
  const material = WIRE_MATERIALS[matIdx];

  const [isRunning, setIsRunning] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const [resetKey, setResetKey] = useState(0);
  const [unloadKey, setUnloadKey] = useState(0);
  const [settled, setSettled] = useState(false);

  const reset = useCallback(() => {
    setIsRunning(false); setIsPaused(false); setResetKey(k => k + 1); setSettled(false);
  }, []);
  const resetTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  useEffect(() => {
    if (resetTimer.current) clearTimeout(resetTimer.current);
    resetTimer.current = setTimeout(reset, 100);
  }, [mode, load, k, elasticLimitF, matIdx, wireLength, wireDiamMm, wireLoad, reset]);

  return (
    <div className="mx-auto max-w-2xl space-y-3 p-3 sm:p-4">
      <ElasticityCanvas key={resetKey} mode={mode}
        load={mode === 'hooke' ? load : wireLoad} k={k} elasticLimitF={elasticLimitF}
        wireLength={wireLength} wireDiamMm={wireDiamMm} youngE={material.E} materialName={material.name}
        breakingStressMPa={material.breakingStressMPa}
        isRunning={isRunning} isPaused={isPaused} unloadKey={unloadKey}
        onSettled={() => setSettled(true)}
        width={640} height={320} />
      <div className="flex flex-wrap items-center justify-between gap-2">
        <SimulationControls isRunning={isRunning} isPaused={isPaused}
          onRun={() => { setIsRunning(true); setIsPaused(false); }}
          onPause={() => setIsPaused(p => !p)} onReset={reset} />
        {mode === 'hooke' && settled && (
          <button onClick={() => { setUnloadKey(k => k + 1); setSettled(false); }}
            className="rounded-lg border border-gray-200 bg-white px-4 py-2 text-sm font-medium text-gray-600 transition hover:bg-gray-50">
            Remove load
          </button>
        )}
      </div>
      {showControls && (
        <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm space-y-3">
          <p className="text-xs font-medium uppercase tracking-wide text-gray-400">Parameters</p>
          {mode === 'hooke' ? <>
            <Slider label="Load" unit="N" value={load} min={0} max={30} step={0.5} set={setLoad} color="#6366f1" />
            <Slider label="Spring constant" unit="N/m" value={k} min={50} max={500} step={10} set={setK} color="#f59e0b" />
            <Slider label="Elastic limit" unit="N" value={elasticLimitF} min={5} max={25} step={1} set={setElasticLimitF} color="#ef4444" />
          </> : <>
            <div className="flex flex-wrap gap-1.5">
              {WIRE_MATERIALS.map((m, i) => (
                <button key={m.name} onClick={() => setMatIdx(i)}
                  className={`rounded-full border px-2.5 py-2 text-[11px] font-medium transition ${
                    matIdx === i ? 'border-indigo-300 bg-indigo-50 text-indigo-700' : 'border-gray-200 bg-white text-gray-500'
                  }`}>{m.name}</button>
              ))}
            </div>
            <Slider label="Load" unit="N" value={wireLoad} min={5} max={200} step={5} set={setWireLoad} color="#6366f1" />
            <Slider label="Length" unit="m" value={wireLength} min={0.5} max={5} step={0.1} set={setWireLength} color="#10b981" />
            <Slider label="Diameter" unit="mm" value={wireDiamMm} min={0.1} max={2} step={0.05} set={setWireDiamMm} color="#8b5cf6" />
          </>}
        </div>
      )}
      <PoweredBy />
    </div>
  );
}

export default function ElasticityEmbedPage() {
  return (
    <Suspense fallback={<div className="p-8 text-center text-xs text-gray-400">Loading simulation…</div>}>
      <ElasticityEmbedInner />
    </Suspense>
  );
}
AFEOF

echo ""
echo "✓ Patch v16 applied — 4 files written."
echo ""
echo "Next steps:"
echo "  rm -rf .next"
echo "  npm run dev"
echo ""
echo "Check: /simulations/elasticity"
echo "  - Hooke's law: press Run, watch the spring overshoot and settle."
echo "    Set the load above the elastic limit, let it settle, then click"
echo "    "Remove load" -- it should recover partway and leave a visible"
echo "    permanent set instead of returning to natural length."
echo "  - Wire: try different materials at the same load/diameter -- some"
echo "    should survive, others should visibly snap."
