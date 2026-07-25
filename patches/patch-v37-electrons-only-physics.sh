#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
# A-Factor STEM Studio — patch v37: rigorous "only electrons move" physics
# across charging by conduction, induction, the electroscope, and the
# electrophorus, plus a much closer (but still non-contact) induction gap
#
#   CONDUCTION — now correctly sign-aware. Added a rodSign prop; static
#   charge indicators (which never move) match the rod's actual sign, but
#   the TRANSFER animation is always electrons, with direction correctly
#   reversed for a positive rod: negative rod -> electrons flow rod-to-
#   body (body ends up negative, same as rod); positive rod -> electrons
#   flow body-to-rod (body ends up positive, same as rod, because it LOST
#   electrons, not because positive charge arrived). Matches the exact
#   mechanism described: opposite charges in the body are drawn to the
#   rod and neutralised there, leaving the body with the rod's sign.
#
#   INDUCTION — completely rebuilt on two points:
#     1. Gap tightened to a verified 12px ("very close but not touching"),
#        down from the previous 36px, while still remaining clearly
#        distinct from the zero-gap contact used in conduction/friction.
#     2. Charge visualisation replaced with genuine electron-only
#        redistribution: a fixed set of 6 electron markers animates its
#        OWN position (repelled to the far side for a negative rod,
#        attracted to the near side for a positive rod) rather than new
#        "+" objects appearing to represent the depleted region — that
#        region now only ever gets a text label, since no positive charge
#        actually moved there. Verified numerically across all 5 phases
#        for both rod signs: negative rod ends with 4 electrons (2 short
#        of the neutral 6 -> net positive, opposite the rod); positive
#        rod ends with 8 (2 more than neutral -> net negative, opposite
#        the rod).
#
#   ELECTROSCOPE — fixed a real bug in the flow animation: it was using
#   the rod's sign directly, which would have shown "+" symbols moving
#   into the electroscope for a positive rod (positive charge does not
#   travel). Now always draws electrons, with direction reversed for a
#   positive rod (electrons flow OUT — leaves -> cap -> rod — since
#   positive charging works by the electroscope losing electrons).
#   Verified the exact path numerically for both signs.
#
#   ELECTROPHORUS — applied the same rigor: replaced the static "+" dot
#   objects representing the disc's electron-depleted underside with a
#   text label, and made the "-" (electron) markers genuinely redistribute
#   position (evenly spread -> clustered at the top during induction,
#   losing some via the ground point during earthing, then spreading back
#   out evenly once lifted clear of the slab's influence) rather than
#   simply fading in/out at fixed positions. Verified numerically: 7
#   electrons evenly spread -> still 7 but clustered during induction (no
#   charge lost yet, matching real physics) -> 4 remaining after earthing
#   -> redistributes evenly across the isolated disc once lifted.
#
#   Updated all four topics' teacher notes to explicitly state the "only
#   electrons move, protons never move" principle and correctly describe
#   the mechanism for both rod signs.
#
# Run from the af2s project root (Git Bash):   bash patches/patch-v37-electrons-only-physics.sh
# ══════════════════════════════════════════════════════════════════════════════
set -euo pipefail

if [ ! -f "package.json" ]; then
  echo "Run this from the af2s project root (package.json not found)." >&2
  exit 1
fi

echo "-- A-Factor patch v37: rigorous electron-only physics across electrostatics-charging --"
mkdir -p "src/app/embed/electrostatics-charging" "src/app/simulations/electrostatics-charging" "src/components/simulation"

echo "  -> src/components/simulation/ChargingMethodsCanvas.tsx"
cat > "src/components/simulation/ChargingMethodsCanvas.tsx" << 'AFEOF'
'use client';
import { useRef, useEffect, useCallback } from 'react';

export type ChargingMethod = 'friction' | 'conduction' | 'induction';

interface Props {
  method: ChargingMethod;
  rodSign: 1 | -1; // conduction/induction only — friction's outcome is fixed by material choice
  isRunning: boolean; isPaused: boolean;
  onPhaseChange?: (phase: string) => void;
  width?: number; height?: number;
}

function drawCharge(ctx: CanvasRenderingContext2D, x: number, y: number, sign: 1 | -1, r = 7) {
  ctx.save();
  ctx.fillStyle = sign > 0 ? '#ef4444' : '#3b82f6';
  ctx.beginPath(); ctx.arc(x, y, r, 0, Math.PI * 2); ctx.fill();
  ctx.strokeStyle = 'white'; ctx.lineWidth = 1.5;
  ctx.beginPath(); ctx.moveTo(x - r * 0.5, y); ctx.lineTo(x + r * 0.5, y); ctx.stroke();
  if (sign > 0) { ctx.beginPath(); ctx.moveTo(x, y - r * 0.5); ctx.lineTo(x, y + r * 0.5); ctx.stroke(); }
  ctx.restore();
}

// Phase durations (s) for each method's animated sequence
const DURATIONS: Record<ChargingMethod, number[]> = {
  friction: [1.2, 1.8, 1.2],                 // approach, rub, separate
  conduction: [1.2, 1.4, 1.2],               // approach, touch/transfer, separate
  induction: [1.0, 1.4, 1.2, 0.8, 1.2],      // approach, polarize, ground, disconnect, remove
};
const FRICTION_LABELS = ['Rod and cloth, both neutral', 'Rubbing transfers electrons rod → cloth', 'Rod is left positive, cloth negative'];

function getPhaseLabels(method: ChargingMethod, rodSign: 1 | -1): string[] {
  if (method === 'friction') return FRICTION_LABELS;
  if (method === 'conduction') {
    return rodSign < 0
      ? ['Negatively charged rod approaches a neutral sphere', 'Contact — electrons flow from the rod onto the sphere', 'Sphere keeps the SAME sign as the rod (−), rod\u2019s charge is reduced']
      : ['Positively charged rod approaches a neutral sphere', 'Contact — electrons flow from the sphere onto the rod', 'Sphere keeps the SAME sign as the rod (+), rod\u2019s charge is reduced'];
  }
  // induction
  return rodSign < 0
    ? [
        'Negatively charged rod approaches — sphere still neutral overall',
        'Electrons are repelled to the far side — only electrons move, the total charge is still zero',
        'Earthing: the repelled electrons escape to ground',
        'Ground wire disconnected — sphere now has a net charge',
        'Rod removed — sphere is left short of electrons: net POSITIVE, opposite the rod',
      ]
    : [
        'Positively charged rod approaches — sphere still neutral overall',
        'Electrons are attracted to the near side — only electrons move, the total charge is still zero',
        'Earthing: more electrons are drawn in from the ground',
        'Ground wire disconnected — sphere now has a net charge',
        'Rod removed — sphere is left with extra electrons: net NEGATIVE, opposite the rod',
      ];
}

export function ChargingMethodsCanvas({ method, rodSign, isRunning, isPaused, onPhaseChange, width = 660, height = 300 }: Props) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const rafRef = useRef<number>(0);
  const lastFrameRef = useRef<number | null>(null);
  const t = useRef(0);
  const lastPhaseIdx = useRef(-1);
  const sim = useRef({ method, rodSign, isRunning, isPaused, onPhaseChange });
  sim.current = { method, rodSign, isRunning, isPaused, onPhaseChange };

  useEffect(() => { t.current = 0; lastFrameRef.current = null; lastPhaseIdx.current = -1; }, [method, rodSign]);

  const draw = useCallback((timestamp?: number) => {
    const canvas = canvasRef.current; if (!canvas) return;
    const ctx = canvas.getContext('2d'); if (!ctx) return;
    const s = sim.current;
    const W = canvas.width, H = canvas.height;
    const durations = DURATIONS[s.method];
    const totalDuration = durations.reduce((a, b) => a + b, 0);

    if (s.isRunning && !s.isPaused && timestamp !== undefined) {
      if (lastFrameRef.current !== null) {
        t.current = Math.min(t.current + (timestamp - lastFrameRef.current) / 1000, totalDuration);
      }
      lastFrameRef.current = timestamp;
    } else {
      lastFrameRef.current = timestamp ?? null;
    }

    // Which phase are we in, and how far through it (0..1)?
    let acc = 0, phaseIdx = 0, phaseT = 0;
    for (let i = 0; i < durations.length; i++) {
      if (t.current < acc + durations[i] || i === durations.length - 1) {
        phaseIdx = i; phaseT = Math.min(1, (t.current - acc) / durations[i]); break;
      }
      acc += durations[i];
    }
    if (!s.isRunning) { phaseIdx = 0; phaseT = 0; }
    if (phaseIdx !== lastPhaseIdx.current) { lastPhaseIdx.current = phaseIdx; s.onPhaseChange?.(getPhaseLabels(s.method, s.rodSign)[phaseIdx]); }

    ctx.clearRect(0, 0, W, H);
    ctx.fillStyle = '#f8fafc'; ctx.fillRect(0, 0, W, H);

    const midY = H / 2;

    if (s.method === 'friction') {
      // approach(0) -> rub(1) -> separate(2). The rod stays fixed; the
      // cloth approaches until it is in EXACT physical contact (zero gap
      // between the rod's right edge and the cloth's left edge) before
      // any rubbing or charge transfer happens — rubbing requires
      // contact, so the cloth reaches contact at the end of the approach
      // phase and stays there, sliding vertically along the seam, rather
      // than hovering apart from the rod the whole time.
      const rodHalfW = 8, clothHalfW = 26;
      const rodX = W / 2 - 70;
      const clothTouchX = rodX + rodHalfW + clothHalfW; // exact contact position, gap = 0

      const approach = phaseIdx === 0 ? phaseT : 1;
      const separate = phaseIdx === 2 ? phaseT : 0;
      // Before contact, cloth approaches from further right. Once
      // approach completes, clothX snaps exactly onto the touching
      // position and stays there through the whole rub phase.
      const clothX = approach < 1
        ? clothTouchX + 130 * (1 - approach)
        : clothTouchX + separate * 100;

      // Rubbing = sliding along the seam while still touching, not
      // wobbling apart from each other. Clamped so the cloth's stroke
      // never carries it past the rod's own top/bottom edge.
      const rubReach = 34;
      const rubY = phaseIdx === 1 ? Math.sin(t.current * 7) * rubReach : 0;

      // Rod (glass) — fixed
      ctx.fillStyle = '#c7d2fe'; ctx.fillRect(rodX - rodHalfW, midY - 60, rodHalfW * 2, 120);
      ctx.strokeStyle = '#6366f1'; ctx.strokeRect(rodX - rodHalfW, midY - 60, rodHalfW * 2, 120);
      ctx.fillStyle = '#334155'; ctx.font = '10px system-ui'; ctx.textAlign = 'center';
      ctx.fillText('glass rod', rodX, midY - 70);

      // Cloth (silk) — approaches, then slides vertically while touching
      const clothY = midY + rubY;
      ctx.fillStyle = '#fecaca'; ctx.fillRect(clothX - clothHalfW, clothY - 50, clothHalfW * 2, 100);
      ctx.strokeStyle = '#ef4444'; ctx.strokeRect(clothX - clothHalfW, clothY - 50, clothHalfW * 2, 100);
      ctx.fillText('silk cloth', clothX, clothY - 60);

      // A short motion streak at the contact seam while actively rubbing,
      // so the sliding-while-touching motion reads clearly rather than
      // looking like the cloth is merely twitching in place.
      if (phaseIdx === 1) {
        ctx.save();
        ctx.strokeStyle = 'rgba(239,68,68,0.35)'; ctx.lineWidth = 3; ctx.lineCap = 'round';
        ctx.beginPath();
        ctx.moveTo(rodX + rodHalfW, midY - Math.sign(Math.cos(t.current * 7)) * rubReach * 0.6);
        ctx.lineTo(rodX + rodHalfW, clothY);
        ctx.stroke();
        ctx.restore();
      }

      // Electrons transfer directly across the contact seam (a few
      // pixels, not across an open gap) — spawning near the rod's
      // surface and settling just inside the cloth's surface, at the
      // CURRENT rubbing height so the transfer visibly tracks the
      // sliding contact point.
      const rubProgress = phaseIdx === 1 ? phaseT : phaseIdx > 1 ? 1 : 0;
      if (phaseIdx === 1) {
        for (let i = 0; i < 4; i++) {
          const localPhase = (rubProgress * 3 + i * 0.6) % 1;
          const ex = (rodX + rodHalfW) + (clothX - clothHalfW - (rodX + rodHalfW)) * localPhase;
          const ey = clothY - 25 + i * 17;
          drawCharge(ctx, ex, ey, -1, 4.5);
        }
      }
      const netCharge = phaseIdx >= 1 ? Math.min(1, rubProgress) : 0;
      if (netCharge > 0.05 || phaseIdx === 2) {
        drawCharge(ctx, rodX, midY + 45, 1, 6);
        drawCharge(ctx, clothX, clothY + 45, -1, 6);
      }
    } else if (s.method === 'conduction') {
      const sphereR = 34;
      const sphereX = W / 2 + 90;
      const negative = s.rodSign < 0;
      // Rod tip approaches until it is in EXACT physical contact with the
      // sphere's surface (zero gap) — conduction requires actual contact,
      // so the rod reaches the sphere's surface exactly at the end of the
      // approach phase rather than stopping visibly short of it.
      const touchX = sphereX - sphereR;
      const approach = phaseIdx === 0 ? phaseT : 1;
      const separate = phaseIdx === 2 ? phaseT : 0;
      const rodTipX = approach < 1 ? touchX - 100 * (1 - approach) : touchX + separate * 90;

      // The rod's OWN static charge markers represent its net charge and
      // never move — only the transfer animation below (always electrons)
      // does. A negative rod shows its excess electrons directly; a
      // positive rod is missing electrons, so a "+" label represents that
      // deficiency rather than drawing fictitious moving positive charges.
      const rodTransferred = phaseIdx >= 1 ? Math.min(1, phaseIdx === 1 ? phaseT : 1) : 0;
      ctx.fillStyle = '#93c5fd'; ctx.fillRect(rodTipX - 90, midY - 8, 90, 16);
      ctx.strokeStyle = '#2563eb'; ctx.strokeRect(rodTipX - 90, midY - 8, 90, 16);
      ctx.fillStyle = '#334155'; ctx.font = '10px system-ui'; ctx.textAlign = 'center';
      ctx.fillText(negative ? 'negatively charged rod' : 'positively charged rod', rodTipX - 45, midY - 20);
      if (negative) {
        const nRodElectrons = Math.round(5 - rodTransferred * 2); // loses some of its excess electrons
        for (let i = 0; i < nRodElectrons; i++) drawCharge(ctx, rodTipX - 12 - i * 16, midY, -1, 5);
      } else {
        ctx.fillStyle = '#dc2626'; ctx.font = 'bold 12px system-ui';
        ctx.fillText('+'.repeat(Math.max(1, 3 - Math.round(rodTransferred * 2))), rodTipX - 45, midY + 4);
      }

      ctx.fillStyle = '#e2e8f0';
      ctx.beginPath(); ctx.arc(sphereX, midY, sphereR, 0, Math.PI * 2); ctx.fill();
      ctx.strokeStyle = '#94a3b8'; ctx.stroke();
      ctx.fillText('neutral sphere', sphereX, midY - 46);

      // Electrons visibly cross the contact point during the touch phase
      // — ALWAYS electrons, with the direction set by which object is
      // attracting them: onto the sphere from a negative rod (repelled by
      // the rod's excess electrons), or off the sphere onto a positive
      // rod (drawn toward the rod's deficiency). Protons never move.
      if (phaseIdx === 1) {
        for (let i = 0; i < 4; i++) {
          const localPhase = (phaseT * 3 + i * 0.5) % 1;
          const travel = Math.min(1, localPhase * 1.6);
          const f = negative ? travel : 1 - travel; // reversed direction for a positive rod
          const ex = rodTipX + (sphereX - sphereR - rodTipX) * f;
          drawCharge(ctx, ex, midY - 10 + i * 6, -1, 4.5);
        }
      }
      if (phaseIdx >= 1) {
        const n = Math.round((phaseIdx === 1 ? phaseT : 1) * 4);
        for (let i = 0; i < n; i++) {
          const a = (i / 4) * Math.PI * 2;
          drawCharge(ctx, sphereX + Math.cos(a) * 20, midY + Math.sin(a) * 20, s.rodSign, 5);
        }
      }
      if (phaseIdx === 2) {
        ctx.fillStyle = '#1e293b'; ctx.font = 'bold 10px system-ui';
        ctx.fillText(
          negative ? 'rod: reduced (–)   sphere: (–), same sign as rod' : 'rod: reduced (+)   sphere: (+), same sign as rod',
          W / 2, H - 16,
        );
      }
    } else {
      // induction: approach(0) polarise(1) ground(2) disconnect(3) remove(4)
      // The rod stops VERY close to the sphere but never touches it —
      // induction relies on the field reaching across a small gap, unlike
      // friction/conduction which need actual contact.
      const negative = s.rodSign < 0;
      const sphereR = 34;
      const minGap = 12;
      const approach = phaseIdx === 0 ? phaseT : 1;
      const remove = phaseIdx === 4 ? phaseT : 0;
      const gap = minGap + 150 * (1 - approach) + remove * 170;
      const sphereX = W / 2 + 60;
      const rodTipX = sphereX - sphereR - gap;

      ctx.fillStyle = '#93c5fd'; ctx.fillRect(rodTipX - 90, midY - 100, 16, 100);
      ctx.strokeStyle = '#2563eb'; ctx.strokeRect(rodTipX - 90, midY - 100, 16, 100);
      ctx.fillStyle = '#334155'; ctx.font = '10px system-ui'; ctx.textAlign = 'center';
      ctx.fillText(negative ? 'negative rod' : 'positive rod', rodTipX - 82, midY - 110);
      if (negative) {
        for (let i = 0; i < 4; i++) drawCharge(ctx, rodTipX - 82, midY - 90 + i * 25, -1, 5);
      } else {
        ctx.fillStyle = '#dc2626'; ctx.font = 'bold 14px system-ui';
        ctx.fillText('+ + +', rodTipX - 82, midY - 40);
      }

      ctx.fillStyle = '#e2e8f0';
      ctx.beginPath(); ctx.arc(sphereX, midY, sphereR, 0, Math.PI * 2); ctx.fill();
      ctx.strokeStyle = '#94a3b8'; ctx.stroke();

      const polarised = phaseIdx >= 1;
      const grounded = phaseIdx === 2 || phaseIdx === 3;
      const finalCharge = phaseIdx === 4;

      if (grounded) {
        ctx.strokeStyle = '#64748b'; ctx.lineWidth = 2;
        ctx.beginPath(); ctx.moveTo(sphereX + 34, midY); ctx.lineTo(sphereX + 80, midY); ctx.lineTo(sphereX + 80, midY + 60); ctx.stroke();
        for (let i = -1; i <= 1; i++) { ctx.beginPath(); ctx.moveTo(sphereX + 72 + i * 6, midY + 60); ctx.lineTo(sphereX + 66 + i * 6, midY + 70); ctx.stroke(); }
        ctx.fillStyle = '#64748b'; ctx.font = '9px system-ui'; ctx.fillText('ground', sphereX + 80, midY + 84);
      }

      // ONLY electrons move — this is drawn as a fixed set of electron
      // markers that REDISTRIBUTE by animating their position (never
      // appearing as new "positive charge" objects). The near side
      // (toward the rod) simply ends up with fewer of them or more,
      // depending on whether they're attracted or repelled; the resulting
      // net-positive region is shown as a text label, not a moving
      // particle, since no positive charge actually travelled there.
      const baseCount = 6;
      const nearAngle = Math.PI;   // toward the rod (left)
      const farAngle = 0;          // away from the rod (right)
      const clusterAngle = negative ? farAngle : nearAngle; // repelled away / attracted toward
      const depletedSideLabel = negative ? { x: sphereX - 16, y: midY } : { x: sphereX + 16, y: midY };

      // How many electrons have left (negative-rod case) or arrived
      // (positive-rod case) via the ground wire so far.
      const grndCount = grounded || finalCharge ? Math.round(2 * (phaseIdx === 2 ? phaseT : 1)) : 0;
      const visibleCount = negative ? baseCount - grndCount : baseCount + grndCount;

      if (polarised) {
        for (let i = 0; i < visibleCount; i++) {
          const baseA = (i / baseCount) * Math.PI * 2;
          // Ease from the evenly-spread neutral angle toward a tight
          // cluster around clusterAngle as polarisation/settling proceeds.
          const clusterA = clusterAngle + ((i - (baseCount - 1) / 2) / baseCount) * (Math.PI * 0.6);
          const settle = finalCharge ? 1 - remove : 1; // spread back out evenly once the rod is removed
          const a = baseA + (clusterA - baseA) * settle;
          const ex = sphereX + Math.cos(a) * 20, ey = midY + Math.sin(a) * 20;
          drawCharge(ctx, ex, ey, -1, 5);
        }
        if (!finalCharge) {
          ctx.fillStyle = '#dc2626'; ctx.font = 'bold 11px system-ui'; ctx.textAlign = 'center';
          ctx.fillText('+', depletedSideLabel.x, depletedSideLabel.y - 4);
        }
      }
      if (finalCharge) {
        ctx.fillStyle = negative ? '#dc2626' : '#2563eb'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
        ctx.fillText(negative ? 'net +' : 'net −', sphereX, midY - sphereR - 10);
        ctx.fillStyle = '#1e293b'; ctx.font = 'bold 10px system-ui';
        ctx.fillText(
          negative ? 'Sphere is short 2 electrons: net POSITIVE, opposite the rod' : 'Sphere has 2 extra electrons: net NEGATIVE, opposite the rod',
          W / 2, H - 16,
        );
      }
    }

    ctx.fillStyle = '#334155'; ctx.font = 'bold 11px system-ui'; ctx.textAlign = 'center';
    ctx.fillText(getPhaseLabels(s.method, s.rodSign)[phaseIdx] ?? '', W / 2, 24);

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

echo "  -> src/components/simulation/ElectroscopeCanvas.tsx"
cat > "src/components/simulation/ElectroscopeCanvas.tsx" << 'AFEOF'
'use client';
import { useRef, useEffect, useCallback } from 'react';
import { electroscopeDivergenceAngle } from '@/lib/physics/electrostatics';

export type ElectroscopeMode = 'charging' | 'testing';

interface Props {
  mode: ElectroscopeMode;
  rodSign: 1 | -1;               // sign of the charging rod (charging mode) or the test rod (testing mode)
  electroscopeSign: 1 | -1;      // testing mode only: the electroscope's pre-existing charge sign
  isRunning: boolean; isPaused: boolean;
  onTick?: (divergenceDeg: number) => void;
  width?: number; height?: number;
}

const MAX_ANGLE = 40;

function drawCharge(ctx: CanvasRenderingContext2D, x: number, y: number, sign: 1 | -1, r = 6) {
  ctx.save();
  ctx.fillStyle = sign > 0 ? '#ef4444' : '#3b82f6';
  ctx.beginPath(); ctx.arc(x, y, r, 0, Math.PI * 2); ctx.fill();
  ctx.strokeStyle = 'white'; ctx.lineWidth = 1.3;
  ctx.beginPath(); ctx.moveTo(x - r * 0.5, y); ctx.lineTo(x + r * 0.5, y); ctx.stroke();
  if (sign > 0) { ctx.beginPath(); ctx.moveTo(x, y - r * 0.5); ctx.lineTo(x, y + r * 0.5); ctx.stroke(); }
  ctx.restore();
}

export function ElectroscopeCanvas({ mode, rodSign, electroscopeSign, isRunning, isPaused, onTick, width = 660, height = 320 }: Props) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const rafRef = useRef<number>(0);
  const lastFrameRef = useRef<number | null>(null);
  const t = useRef(0);
  const sim = useRef({ mode, rodSign, electroscopeSign, isRunning, isPaused, onTick });
  sim.current = { mode, rodSign, electroscopeSign, isRunning, isPaused, onTick };

  useEffect(() => { t.current = 0; lastFrameRef.current = null; }, [mode, rodSign, electroscopeSign]);

  const draw = useCallback((timestamp?: number) => {
    const canvas = canvasRef.current; if (!canvas) return;
    const ctx = canvas.getContext('2d'); if (!ctx) return;
    const s = sim.current;
    const W = canvas.width, H = canvas.height;

    const DURATION = s.mode === 'charging' ? 3.2 : 3.6;
    if (s.isRunning && !s.isPaused && timestamp !== undefined) {
      if (lastFrameRef.current !== null) {
        t.current = Math.min(t.current + (timestamp - lastFrameRef.current) / 1000, DURATION);
      }
      lastFrameRef.current = timestamp;
    } else {
      lastFrameRef.current = timestamp ?? null;
    }
    const running = s.isRunning;

    ctx.clearRect(0, 0, W, H);
    ctx.fillStyle = '#f8fafc'; ctx.fillRect(0, 0, W, H);

    const capX = W / 2, capY = 60;
    const jarTop = 90, jarBottom = H - 30, jarHalfW = 70;
    const leafTopY = jarTop + 20, leafLen = 90;

    let divergenceDeg: number, rodApproach: number, sign: 1 | -1, chargeVisible = 0;

    if (s.mode === 'charging') {
      // approach (0-0.9) -> touch/transfer (0.9-2.4) -> withdraw (2.4-3.2)
      const p1 = 0.9, p2 = 2.4;
      if (!running) { rodApproach = 0; chargeVisible = 0; }
      else if (t.current < p1) { rodApproach = t.current / p1; chargeVisible = 0; }
      else if (t.current < p2) { rodApproach = 1; chargeVisible = (t.current - p1) / (p2 - p1); }
      else { rodApproach = 1 - (t.current - p2) / (DURATION - p2); chargeVisible = 1; }
      sign = s.rodSign;
      divergenceDeg = electroscopeDivergenceAngle(chargeVisible, 1, MAX_ANGLE);
    } else {
      // baseline charge already present; test rod approaches (0-1.2), holds (1.2-2.4), retreats (2.4-3.6)
      const baseline = 0.6; // baseline divergence fraction before the test rod arrives
      const p1 = 1.2, p2 = 2.4;
      if (!running) { rodApproach = 0; }
      else if (t.current < p1) { rodApproach = t.current / p1; }
      else if (t.current < p2) { rodApproach = 1; }
      else { rodApproach = 1 - (t.current - p2) / (DURATION - p2); }
      sign = s.rodSign;
      const sameSign = s.rodSign === s.electroscopeSign;
      // Same sign approaching -> pushes more charge onto the leaves (more divergence).
      // Opposite sign approaching -> draws charge back up to the cap (less divergence).
      const influence = (sameSign ? 1 : -1) * rodApproach * 0.7;
      const frac = Math.max(0.05, Math.min(1, baseline + influence));
      divergenceDeg = electroscopeDivergenceAngle(frac, 1, MAX_ANGLE);
      chargeVisible = baseline; // the electroscope's own charge is always present in this mode
    }
    s.onTick?.(divergenceDeg);

    // Charging/test rod — reaches EXACT contact with the cap's surface
    // (the cap is drawn as an ellipse of x-radius 18, so contact is at
    // capX-18) rather than stopping visibly short of it.
    const capRadius = 18;
    const rodTipX = capX - capRadius - (1 - rodApproach) * 160;
    if (rodApproach > 0.01) {
      ctx.fillStyle = '#93c5fd'; ctx.fillRect(rodTipX - 90, capY - 8, 90, 16);
      ctx.strokeStyle = '#2563eb'; ctx.strokeRect(rodTipX - 90, capY - 8, 90, 16);
      for (let i = 0; i < 4; i++) drawCharge(ctx, rodTipX - 14 - i * 20, capY, sign, 5);
      ctx.fillStyle = '#334155'; ctx.font = '10px system-ui'; ctx.textAlign = 'center';
      ctx.fillText(`${sign > 0 ? '+' : '−'} rod`, rodTipX - 45, capY - 18);
    }

    // Jar / case
    ctx.strokeStyle = '#cbd5e1'; ctx.lineWidth = 2;
    ctx.strokeRect(capX - jarHalfW, jarTop, jarHalfW * 2, jarBottom - jarTop);

    // Cap and rod down to the leaves
    ctx.fillStyle = '#94a3b8';
    ctx.beginPath(); ctx.ellipse(capX, capY, capRadius, 8, 0, 0, Math.PI * 2); ctx.fill();
    ctx.fillRect(capX - 3, capY, 6, leafTopY - capY);

    // Leaves — hinge at the bottom of the rod, swinging apart by divergenceDeg
    const hingeY = leafTopY;
    const rad = (divergenceDeg * Math.PI) / 180;
    ctx.strokeStyle = '#eab308'; ctx.lineWidth = 3; ctx.lineCap = 'round';
    [-1, 1].forEach(side => {
      const dx = Math.sin(rad) * side, dy = Math.cos(rad);
      ctx.beginPath(); ctx.moveTo(capX, hingeY); ctx.lineTo(capX + dx * leafLen, hingeY + dy * leafLen); ctx.stroke();
    });

    // Electron flow — while charge is actively transferring by contact,
    // particles travel visibly along the cap-rod-leaf path, instead of
    // charge simply appearing simultaneously at the cap AND the leaves
    // with no transit shown. This is ALWAYS electrons (never drawn as a
    // "+" particle) — a negative rod pushes electrons IN (cap -> leaves);
    // a positive rod pulls the electroscope's own electrons OUT (leaves
    // -> cap, up toward the rod), since positive charging works by the
    // electroscope losing electrons, not by positive charge arriving.
    if (s.mode === 'charging' && running && t.current >= 0.9 && t.current < 2.4) {
      const negative = s.rodSign < 0;
      const flowT = t.current - 0.9;
      const segALen = hingeY - capY;
      const nParticles = 6;
      for (let i = 0; i < nParticles; i++) {
        const side = i % 2 === 0 ? -1 : 1;
        const dx = Math.sin(rad) * side, dy = Math.cos(rad);
        const segBLen = leafLen;
        const totalLen = segALen + segBLen;
        const speed = 130; // px/s along the path
        const rawPhase = (((flowT * speed) + i * (totalLen / nParticles)) % totalLen) / totalLen;
        const phase = negative ? rawPhase : 1 - rawPhase; // reversed direction for a positive rod
        let px: number, py: number;
        if (phase * totalLen < segALen) {
          const f = (phase * totalLen) / segALen;
          px = capX; py = capY + f * segALen;
        } else {
          const f = (phase * totalLen - segALen) / segBLen;
          px = capX + dx * leafLen * f; py = hingeY + dy * leafLen * f;
        }
        drawCharge(ctx, px, py, -1, 4);
      }
    }

    // Charge distributed over the cap/rod/leaves once present
    if (chargeVisible > 0.05) {
      const n = Math.round(chargeVisible * 3) + 1;
      for (let i = 0; i < n; i++) drawCharge(ctx, capX + (i - (n - 1) / 2) * 14, capY - 16, sign, 4.5);
      [-1, 1].forEach(side => {
        const dx = Math.sin(rad) * side, dy = Math.cos(rad);
        drawCharge(ctx, capX + dx * leafLen * 0.6, hingeY + dy * leafLen * 0.6, sign, 4.5);
      });
    }

    ctx.fillStyle = '#334155'; ctx.font = 'bold 11px system-ui'; ctx.textAlign = 'center';
    if (s.mode === 'charging') {
      ctx.fillText(
        !running ? 'Press Run: charging by contact' :
        t.current < 0.9 ? 'Rod approaches the cap' :
        t.current < 2.4 ? 'Touching — charge spreads onto the cap, rod and leaves' :
        'Rod withdrawn — leaves stay diverged (electroscope is now charged)',
        W / 2, 20,
      );
    } else {
      const sameSign = s.rodSign === s.electroscopeSign;
      ctx.fillText(
        !running ? `Electroscope pre-charged (${s.electroscopeSign > 0 ? '+' : '−'}). Press Run to test with a ${s.rodSign > 0 ? '+' : '−'} rod` :
        t.current < 2.4 ? (sameSign ? 'Same sign approaching — leaves diverge FURTHER' : 'Opposite sign approaching — leaves diverge LESS') :
        'Rod withdrawn — leaves return to the original divergence',
        W / 2, 20,
      );
    }
    ctx.fillStyle = '#64748b'; ctx.font = '10px system-ui'; ctx.textAlign = 'left';
    ctx.fillText(`Leaf divergence ≈ ${divergenceDeg.toFixed(0)}°`, 8, H - 10);

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

echo "  -> src/components/simulation/ElectrophorusCanvas.tsx"
cat > "src/components/simulation/ElectrophorusCanvas.tsx" << 'AFEOF'
'use client';
import { useRef, useEffect, useCallback } from 'react';

interface Props {
  isRunning: boolean; isPaused: boolean;
  cycleCount: number; // how many times the disc has been lifted+used this run (for the "repeatable" teaching point)
  onCycleComplete?: () => void;
  width?: number; height?: number;
}

function drawCharge(ctx: CanvasRenderingContext2D, x: number, y: number, sign: 1 | -1, r = 6) {
  ctx.save();
  ctx.fillStyle = sign > 0 ? '#ef4444' : '#3b82f6';
  ctx.beginPath(); ctx.arc(x, y, r, 0, Math.PI * 2); ctx.fill();
  ctx.strokeStyle = 'white'; ctx.lineWidth = 1.3;
  ctx.beginPath(); ctx.moveTo(x - r * 0.5, y); ctx.lineTo(x + r * 0.5, y); ctx.stroke();
  if (sign > 0) { ctx.beginPath(); ctx.moveTo(x, y - r * 0.5); ctx.lineTo(x, y + r * 0.5); ctx.stroke(); }
  ctx.restore();
}

// before(0) -> lower disc onto slab(1) -> induction settles(2) -> finger grounds it(3) -> lift disc(4)
const DURATIONS = [0.6, 1.0, 0.8, 1.0, 1.2];
const TOTAL = DURATIONS.reduce((a, b) => a + b, 0);
const PHASE_LABELS = [
  'Insulating slab, charged negative by rubbing earlier — the disc is not yet placed',
  'Metal disc lowered onto the charged slab (insulating handle keeps your hand safe)',
  'Induction: only the disc\u2019s free electrons move — repelled to the top, leaving the underside short of electrons (net positive there)',
  'Touch the disc with a finger — the repelled electrons escape to earth through you',
  'Lift the disc by its insulating handle — short of electrons overall, it carries away a net POSITIVE charge',
];

export function ElectrophorusCanvas({ isRunning, isPaused, cycleCount, onCycleComplete, width = 660, height = 320 }: Props) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const rafRef = useRef<number>(0);
  const lastFrameRef = useRef<number | null>(null);
  const t = useRef(0);
  const firedComplete = useRef(false);
  const sim = useRef({ isRunning, isPaused, onCycleComplete });
  sim.current = { isRunning, isPaused, onCycleComplete };

  useEffect(() => { t.current = 0; lastFrameRef.current = null; firedComplete.current = false; }, [cycleCount]);

  const draw = useCallback((timestamp?: number) => {
    const canvas = canvasRef.current; if (!canvas) return;
    const ctx = canvas.getContext('2d'); if (!ctx) return;
    const s = sim.current;
    const W = canvas.width, H = canvas.height;

    if (s.isRunning && !s.isPaused && timestamp !== undefined) {
      if (lastFrameRef.current !== null) {
        t.current = Math.min(t.current + (timestamp - lastFrameRef.current) / 1000, TOTAL);
      }
      lastFrameRef.current = timestamp;
    } else {
      lastFrameRef.current = timestamp ?? null;
    }

    let acc = 0, phaseIdx = 0, phaseT = 0;
    for (let i = 0; i < DURATIONS.length; i++) {
      if (t.current < acc + DURATIONS[i] || i === DURATIONS.length - 1) {
        phaseIdx = i; phaseT = DURATIONS[i] > 0 ? Math.min(1, (t.current - acc) / DURATIONS[i]) : 1; break;
      }
      acc += DURATIONS[i];
    }
    if (!s.isRunning) { phaseIdx = 0; phaseT = 0; }
    if (s.isRunning && t.current >= TOTAL && !firedComplete.current) { firedComplete.current = true; s.onCycleComplete?.(); }

    ctx.clearRect(0, 0, W, H);
    ctx.fillStyle = '#f8fafc'; ctx.fillRect(0, 0, W, H);

    const midY = H * 0.62, slabX = W / 2, slabW = 220, slabH = 22;
    const slabTop = midY - slabH / 2;

    // Insulating slab (charged negative, fixed for the whole demo)
    ctx.fillStyle = '#c4b5fd'; ctx.fillRect(slabX - slabW / 2, slabTop, slabW, slabH);
    ctx.strokeStyle = '#7c3aed'; ctx.strokeRect(slabX - slabW / 2, slabTop, slabW, slabH);
    ctx.fillStyle = '#334155'; ctx.font = '10px system-ui'; ctx.textAlign = 'center';
    ctx.fillText('insulating slab (charged −)', slabX, slabTop + slabH + 16);
    for (let i = -3; i <= 3; i++) drawCharge(ctx, slabX + i * 28, slabTop + slabH / 2, -1, 5);

    // Disc height: starts high, lowers onto the slab in phase 1, stays down
    // through phases 2-3, lifts away in phase 4.
    const restY = slabTop - 14;
    const highY = slabTop - 130;
    let discY: number;
    if (phaseIdx === 0) discY = highY;
    else if (phaseIdx === 1) discY = highY + (restY - highY) * phaseT;
    else if (phaseIdx < 4) discY = restY;
    else discY = restY + (highY - restY) * phaseT;

    // Handle (insulating)
    ctx.strokeStyle = '#78350f'; ctx.lineWidth = 6; ctx.lineCap = 'round';
    ctx.beginPath(); ctx.moveTo(slabX, discY); ctx.lineTo(slabX, discY - 70); ctx.stroke();

    // Metal disc
    ctx.fillStyle = '#e2e8f0';
    ctx.beginPath(); ctx.ellipse(slabX, discY, 90, 12, 0, 0, Math.PI * 2); ctx.fill();
    ctx.strokeStyle = '#94a3b8'; ctx.stroke();
    ctx.fillStyle = '#334155'; ctx.font = '10px system-ui';
    ctx.fillText('metal disc', slabX, discY - 90);

    const touching = phaseIdx >= 1;
    const induced = phaseIdx >= 2;
    const grounded = phaseIdx === 3;
    const groundProgress = phaseIdx === 3 ? phaseT : phaseIdx > 3 ? 1 : 0;
    const lifted = phaseIdx === 4;
    const settling = phaseIdx === 2 ? phaseT : phaseIdx === 3 ? 1 : phaseIdx === 4 ? 1 - phaseT : 0;

    // ONLY electrons move here — this is a fixed set of electron markers
    // that redistributes by animating position (never appearing as a
    // separate "+" object). Before induction they sit evenly spread
    // across the disc; as induction proceeds they visibly migrate to the
    // top surface (repelled by the slab's negative charge underneath),
    // leaving the underside electron-short — shown only as a text label,
    // since no positive charge actually arrived there. Once lifted clear
    // of the slab's influence, the remaining electrons spread back out
    // evenly over the now-isolated disc.
    if (touching) {
      const baseCount = 7;
      const leftCount = grounded || lifted ? Math.max(0, baseCount - Math.round(3 * (grounded ? groundProgress : 1))) : baseCount;
      for (let i = 0; i < leftCount; i++) {
        const ix = i - (baseCount - 1) / 2;
        const evenY = discY; // neutral / isolated: spread across the disc's middle
        const clusteredY = discY - 8; // induced: clustered at the top surface
        const y = evenY + (clusteredY - evenY) * settling;
        drawCharge(ctx, slabX + ix * 24, y, -1, 5);
      }
      if (induced && !lifted) {
        ctx.fillStyle = '#dc2626'; ctx.font = 'bold 11px system-ui'; ctx.textAlign = 'center';
        ctx.fillText('+', slabX, discY + 20);
      }
    }

    if (grounded) {
      // finger/ground symbol touching the top of the disc
      ctx.fillStyle = '#fbbf24';
      ctx.beginPath(); ctx.ellipse(slabX + 70, discY - 30, 8, 20, 0.3, 0, Math.PI * 2); ctx.fill();
      ctx.fillStyle = '#78350f'; ctx.font = '9px system-ui'; ctx.fillText('finger (to earth)', slabX + 70, discY - 56);
    }

    if (lifted && phaseT > 0.3) {
      ctx.save(); ctx.globalAlpha = Math.min(1, (phaseT - 0.3) / 0.3);
      ctx.fillStyle = '#dc2626'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
      ctx.fillText('disc now carries a net POSITIVE charge (short of electrons)', slabX, discY + 34);
      ctx.restore();
    }

    ctx.fillStyle = '#334155'; ctx.font = 'bold 11px system-ui'; ctx.textAlign = 'center';
    ctx.fillText(PHASE_LABELS[phaseIdx], W / 2, 20);
    ctx.fillStyle = '#64748b'; ctx.font = '10px system-ui'; ctx.textAlign = 'left';
    ctx.fillText(`Cycle ${cycleCount + 1} — the slab itself is never touched, so this can repeat indefinitely`, 8, H - 10);

    rafRef.current = requestAnimationFrame(draw);
  }, [cycleCount]);

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

echo "  -> src/app/simulations/electrostatics-charging/page.tsx"
cat > "src/app/simulations/electrostatics-charging/page.tsx" << 'AFEOF'
'use client';
import { useState, useCallback, useEffect, useRef } from 'react';
import { AppHeader } from '@/components/layout/AppHeader';
import { SimulationControls } from '@/components/simulation/SimulationControls';
import { ChargingMethodsCanvas, ChargingMethod } from '@/components/simulation/ChargingMethodsCanvas';
import { ElectroscopeCanvas, ElectroscopeMode } from '@/components/simulation/ElectroscopeCanvas';
import { ElectrophorusCanvas } from '@/components/simulation/ElectrophorusCanvas';
import { EmbedButton } from '@/components/ui/EmbedButton';
import { useResponsiveCanvasSize } from '@/hooks/useResponsiveCanvasSize';

type Topic = 'production' | 'electroscope' | 'electrophorus';

const CURRICULA = ['WAEC', 'NECO', 'IGCSE', 'SAT', 'JUPEB'];
const CC: Record<string, string> = {
  WAEC: 'bg-indigo-100 text-indigo-700', NECO: 'bg-pink-100 text-pink-700',
  IGCSE: 'bg-emerald-100 text-emerald-700', SAT: 'bg-orange-100 text-orange-700',
  JUPEB: 'bg-purple-100 text-purple-700',
};

const TOPIC_META: Record<Topic, { title: string; icon: string; sub: string; eq: string }> = {
  production:    { title: 'Production of charges', icon: '⚡', sub: 'Friction, conduction, induction', eq: 'like charges repel, unlike attract' },
  electroscope:  { title: 'Gold-leaf electroscope', icon: '🍂', sub: 'Detecting & testing charge',      eq: 'divergence ∝ charge' },
  electrophorus: { title: 'Electrophorus',          icon: '🔌', sub: 'Repeatable charging by induction', eq: 'induced charge is opposite the slab' },
};

const TEACHER_NOTES: Record<Topic, string[]> = {
  production: [
    'In ALL of these methods, only ELECTRONS ever move. Protons are locked inside the nucleus and never transfer between objects — every "positive charge" you see is really a region that has LOST electrons, not one that gained protons.',
    'Charging by FRICTION: rubbing two different insulators transfers electrons from one to the other. Whichever material holds electrons less strongly ends up positive (lost electrons); the other ends up negative (gained electrons) — equal and opposite charges.',
    'Charging by CONDUCTION (contact): the rod and the body must actually TOUCH — this is real physical contact, not just closeness. A negative rod has excess electrons that spread onto the neutral body it touches. A positive rod is short of electrons, so it instead pulls electrons OFF the body it touches. Either way, the body ends up the SAME sign as the rod, and the rod\u2019s own charge is reduced.',
    'Charging by INDUCTION: the rod comes very close to the conductor — close enough for its field to act — but must NOT touch it, unlike friction and conduction. A negative rod repels the conductor\u2019s free electrons to the far side; a positive rod attracts them to the near side. Earthing while the rod is still present lets electrons escape (negative rod) or draws extra electrons in (positive rod). Once the earth connection and then the rod are removed (in that order), the conductor is left with a net charge OPPOSITE the inducing rod.',
    'A key exam distinction: conduction leaves the object with the SAME sign of charge as the charging body; induction leaves it with the OPPOSITE sign — and induction never involves contact at all.',
    'The order of steps matters for induction: the earth connection must be broken BEFORE the charged rod is taken away — if the rod is removed first, the separated charges simply recombine and no net charge is left behind.',
  ],
  electroscope: [
    'A gold-leaf electroscope detects and estimates charge: charge spreads down the cap, rod, and onto the two thin leaves, which — carrying the same sign — repel each other and diverge.',
    'As always, only ELECTRONS move here — never protons. Charging the electroscope with a negative rod pushes electrons IN (rod → cap → leaves). Charging it with a positive rod pulls the electroscope\u2019s own electrons OUT (leaves → cap → rod), leaving it short of electrons and therefore positive — the rod never "gives" it positive charge directly.',
    'Charging BY CONTACT: touch a charged rod to the cap; electrons transfer, spread through the instrument, and the leaves diverge and STAY diverged once the rod is removed.',
    'TESTING the sign of an unknown charge: bring it near the cap of an already-charged electroscope (no contact). If the leaves diverge FURTHER, the unknown charge has the SAME sign as the electroscope. If the leaves diverge LESS, it has the OPPOSITE sign.',
    'This works by induction at the cap: a like charge repels the electroscope\u2019s own charge further down toward the leaves (more divergence); an unlike charge attracts it back up toward the cap (less divergence).',
    'An electroscope can also be charged BY INDUCTION (earthing the case while a charged rod is held near the cap, then removing the earth before the rod) — giving it a charge opposite to the rod, the same principle as the electrophorus.',
  ],
  electrophorus: [
    'An electrophorus is a device for producing charge repeatedly from a SINGLE charging of an insulating slab — the slab itself is charged once (by friction) and never touched again.',
    'As with all induction, only ELECTRONS move here. The slab\u2019s negative charge repels the disc\u2019s free electrons to its top surface — the underside is simply short of electrons, not visited by positive charge.',
    'Sequence: place the metal disc on the charged slab (induction separates its charges) → touch the disc briefly to earth it (the repelled electrons escape) → lift the disc by its INSULATING handle.',
    'The disc lifts away carrying a net charge OPPOSITE to the slab\u2019s charge — if the slab is negative, the disc becomes positive (short of electrons).',
    'Because the slab\u2019s own charge is never used up (only induction happens, no charge transfers to or from the slab), this process can be repeated many times from a single rubbing of the slab.',
    'The insulating handle is essential — touching the metal disc directly (instead of through the handle) would earth it through your hand at the wrong moment and prevent it from carrying charge away.',
  ],
};

const EXERCISES: Record<Topic, { q: string; a: string }[]> = {
  production: [
    { q: 'An ebonite rod is rubbed with fur and becomes negatively charged. What happens to the fur, and why?', a: 'The fur becomes positively charged. Rubbing transfers electrons from the fur to the rod (since the rod holds electrons more strongly here), leaving the fur short of electrons — positively charged — while the rod gains the electrons and becomes negative.' },
    { q: 'A positively charged rod touches a neutral metal sphere on an insulating stand. State the sign of charge left on the sphere.', a: 'Positive — the same sign as the charging rod, since conduction transfers charge of the same sign onto the object touched.' },
    { q: 'Describe how to charge a metal sphere negatively using a POSITIVELY charged rod, without ever touching the rod to the sphere.', a: 'Bring the positive rod close to the sphere (inducing separation of charge — the near side becomes negative, the far side positive). Earth the sphere while the rod is still near, letting the repelled positive charge flow to earth. Disconnect the earth first, THEN remove the rod. The sphere is left with a net negative charge — opposite to the rod.' },
  ],
  electroscope: [
    { q: 'A charged electroscope has its leaves diverged. An unknown charged rod is brought near the cap and the leaves diverge further. What can you conclude about the rod\u2019s charge?', a: 'The rod carries the SAME sign of charge as the electroscope — a like charge repels the electroscope\u2019s charge further down onto the leaves, increasing the divergence.' },
    { q: 'Explain why the leaves of an electroscope diverge when it is charged.', a: 'Charge spreads through the cap, rod, and onto both leaves. Since both leaves carry the same sign, they repel each other and swing apart.' },
    { q: 'A student touches a charged rod to the cap of a neutral electroscope, then removes the rod. Describe and explain what is observed.', a: 'The leaves diverge as the rod touches (charge spreading onto them) and REMAIN diverged after the rod is removed, since the electroscope has now genuinely been charged by contact and retains that charge.' },
  ],
  electrophorus: [
    { q: 'Explain why the metal disc of an electrophorus becomes charged even though it never touches the (already charged) slab with a bare conducting path carrying charge from the slab.', a: 'The disc becomes charged by INDUCTION, not by charge transfer from the slab. The slab\u2019s fixed charge polarises the disc (separates its own charges); earthing the disc lets the repelled charge escape, leaving the disc with an induced charge of its own once the earth and then the slab contact are removed.' },
    { q: 'Why can an electrophorus be used repeatedly without re-charging the insulating slab?', a: 'The slab\u2019s charge is never transferred away — it only induces a redistribution of charge on the disc each time. Since the slab\u2019s own charge is untouched, the same slab can induce a fresh charge on the disc again and again.' },
    { q: 'State the correct order of steps for using an electrophorus, and explain why the order matters.', a: 'Lower the disc onto the slab → earth the disc (e.g., touch it) → remove the earth connection → THEN lift the disc away. If the disc were lifted before removing the earth connection, charge would simply flow back from earth as it left, and the disc would end up uncharged.' },
  ],
};

function StatRow({ label, value, unit, color }: { label: string; value: string; unit: string; color: string }) {
  return (
    <div className="flex justify-between items-center rounded-lg bg-gray-50 px-3 py-2">
      <span className="text-xs text-gray-500">{label}</span>
      <span className={`text-xs font-semibold tabular-nums ${color}`}>{value} <span className="text-gray-400 font-normal">{unit}</span></span>
    </div>
  );
}

export default function ElectrostaticsChargingPage() {
  const [topic, setTopic] = useState<Topic>('production');
  const [isRunning, setIsRunning] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const [resetKey, setResetKey] = useState(0);
  const [openEx, setOpenEx] = useState<number | null>(null);
  const [activeCurricula, setActiveCurricula] = useState(['WAEC', 'IGCSE', 'SAT']);

  const [method, setMethod] = useState<ChargingMethod>('friction');
  const [chargingPhaseLabel, setChargingPhaseLabel] = useState('');

  const [electroscopeMode, setElectroscopeMode] = useState<ElectroscopeMode>('charging');
  const [rodSign, setRodSign] = useState<1 | -1>(-1);
  const [electroscopeSign, setElectroscopeSign] = useState<1 | -1>(-1);
  const [liveDivergence, setLiveDivergence] = useState(0);

  const [electrophorusCycle, setElectrophorusCycle] = useState(0);

  const reset = useCallback(() => {
    setIsRunning(false); setIsPaused(false); setResetKey(k => k + 1);
    setElectrophorusCycle(0);
  }, []);
  const resetTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  useEffect(() => {
    if (resetTimer.current) clearTimeout(resetTimer.current);
    resetTimer.current = setTimeout(reset, 100);
  }, [topic, method, electroscopeMode, rodSign, electroscopeSign, reset]);

  const canvasBoxRef = useRef<HTMLDivElement>(null);
  const canvasSize = useResponsiveCanvasSize(canvasBoxRef, 660, 320, 980);

  return (
    <>
      <AppHeader />
      <main className="min-h-screen bg-gray-50">
        <section className="border-b border-gray-200 bg-white">
          <div className="mx-auto max-w-[100rem] px-4 sm:px-6 py-4">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
              <div>
                <p className="text-xs text-gray-400 mb-0.5">Electricity · Electrostatics</p>
                <h1 className="text-lg font-semibold text-gray-900">Charging Objects</h1>
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
                {topic === 'production' && (
                  <ChargingMethodsCanvas key={resetKey} method={method} rodSign={rodSign}
                    isRunning={isRunning} isPaused={isPaused} onPhaseChange={setChargingPhaseLabel}
                    width={canvasSize.width} height={canvasSize.height} />
                )}
                {topic === 'electroscope' && (
                  <ElectroscopeCanvas key={resetKey} mode={electroscopeMode} rodSign={rodSign} electroscopeSign={electroscopeSign}
                    isRunning={isRunning} isPaused={isPaused} onTick={setLiveDivergence}
                    width={canvasSize.width} height={canvasSize.height} />
                )}
                {topic === 'electrophorus' && (
                  <ElectrophorusCanvas key={resetKey} isRunning={isRunning} isPaused={isPaused}
                    cycleCount={electrophorusCycle} onCycleComplete={() => setElectrophorusCycle(c => c + 1)}
                    width={canvasSize.width} height={canvasSize.height} />
                )}
              </div>

              <div className="flex flex-wrap items-center justify-between gap-2">
                <SimulationControls isRunning={isRunning} isPaused={isPaused}
                  onRun={() => { setIsRunning(true); setIsPaused(false); }}
                  onPause={() => setIsPaused(p => !p)} onReset={reset} />
                <EmbedButton path="/embed/electrostatics-charging"
                  title={`${TOPIC_META[topic].title} — A-Factor STEM Studio`}
                  params={
                    topic === 'production' ? { topic, method }
                    : topic === 'electroscope' ? { topic, mode: electroscopeMode, rod: rodSign, es: electroscopeSign }
                    : { topic }
                  } />
              </div>

              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm space-y-4">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide">Parameters</p>

                {topic === 'production' && (
                  <div className="flex flex-col gap-2">
                    {(['friction', 'conduction', 'induction'] as const).map(m => (
                      <button key={m} onClick={() => setMethod(m)}
                        className={`rounded-lg border px-3 py-2 text-xs font-medium capitalize text-left transition ${
                          method === m ? 'border-indigo-300 bg-indigo-50 text-indigo-700' : 'border-gray-200 bg-white text-gray-500'
                        }`}>{m}</button>
                    ))}
                    {method !== 'friction' && (
                      <div className="pt-2 border-t border-gray-100 space-y-1.5">
                        <span className="text-xs text-gray-500">Rod&apos;s charge</span>
                        <div className="flex gap-2">
                          {([1, -1] as const).map(sgn => (
                            <button key={sgn} onClick={() => setRodSign(sgn)}
                              className={`flex-1 rounded-lg border px-2 py-2 text-xs font-medium transition ${
                                rodSign === sgn ? 'border-indigo-300 bg-indigo-50 text-indigo-700' : 'border-gray-200 bg-white text-gray-500'
                              }`}>{sgn > 0 ? 'Positive (+)' : 'Negative (−)'}</button>
                          ))}
                        </div>
                      </div>
                    )}
                  </div>
                )}

                {topic === 'electroscope' && <>
                  <div className="flex gap-2">
                    {(['charging', 'testing'] as const).map(m => (
                      <button key={m} onClick={() => setElectroscopeMode(m)}
                        className={`flex-1 rounded-lg border px-2 py-2 text-xs font-medium capitalize transition ${
                          electroscopeMode === m ? 'border-indigo-300 bg-indigo-50 text-indigo-700' : 'border-gray-200 bg-white text-gray-500'
                        }`}>{m}</button>
                    ))}
                  </div>
                  {electroscopeMode === 'testing' && (
                    <div className="space-y-1.5">
                      <span className="text-xs text-gray-500">Electroscope&apos;s existing charge</span>
                      <div className="flex gap-2">
                        {([1, -1] as const).map(sgn => (
                          <button key={sgn} onClick={() => setElectroscopeSign(sgn)}
                            className={`flex-1 rounded-lg border px-2 py-2 text-xs font-medium transition ${
                              electroscopeSign === sgn ? 'border-indigo-300 bg-indigo-50 text-indigo-700' : 'border-gray-200 bg-white text-gray-500'
                            }`}>{sgn > 0 ? 'Positive (+)' : 'Negative (−)'}</button>
                        ))}
                      </div>
                    </div>
                  )}
                  <div className="space-y-1.5">
                    <span className="text-xs text-gray-500">{electroscopeMode === 'charging' ? 'Charging rod' : 'Test rod'}</span>
                    <div className="flex gap-2">
                      {([1, -1] as const).map(sgn => (
                        <button key={sgn} onClick={() => setRodSign(sgn)}
                          className={`flex-1 rounded-lg border px-2 py-2 text-xs font-medium transition ${
                            rodSign === sgn ? 'border-indigo-300 bg-indigo-50 text-indigo-700' : 'border-gray-200 bg-white text-gray-500'
                          }`}>{sgn > 0 ? 'Positive (+)' : 'Negative (−)'}</button>
                      ))}
                    </div>
                  </div>
                </>}

                {topic === 'electrophorus' && (
                  <p className="text-xs text-gray-500 leading-relaxed">Press Run to lower the disc, earth it, and lift it away. Press Run again afterwards to repeat the cycle from the same charged slab.</p>
                )}
              </div>
            </div>

            <div className="space-y-3">
              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide mb-3">Calculated</p>
                <div className="space-y-2">
                  {topic === 'production' && <>
                    <StatRow label="Method" value={method} unit="" color="text-indigo-600" />
                    <StatRow label="Current phase" value={chargingPhaseLabel || '—'} unit="" color="text-emerald-600" />
                  </>}
                  {topic === 'electroscope' && <>
                    <StatRow label="Mode" value={electroscopeMode} unit="" color="text-indigo-600" />
                    <StatRow label="Live divergence" value={liveDivergence.toFixed(0)} unit="°" color="text-emerald-600" />
                    {electroscopeMode === 'testing' && (
                      <StatRow label="Relationship" value={rodSign === electroscopeSign ? 'same sign → more' : 'opposite sign → less'} unit="" color="text-amber-600" />
                    )}
                  </>}
                  {topic === 'electrophorus' && <>
                    <StatRow label="Cycles completed" value={electrophorusCycle.toString()} unit="" color="text-indigo-600" />
                    <StatRow label="Slab charge used" value="none — reusable" unit="" color="text-emerald-600" />
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

echo "  -> src/app/embed/electrostatics-charging/page.tsx"
cat > "src/app/embed/electrostatics-charging/page.tsx" << 'AFEOF'
'use client';
import { Suspense, useState, useCallback, useEffect, useRef } from 'react';
import { useSearchParams } from 'next/navigation';
import { ChargingMethodsCanvas, ChargingMethod } from '@/components/simulation/ChargingMethodsCanvas';
import { ElectroscopeCanvas, ElectroscopeMode } from '@/components/simulation/ElectroscopeCanvas';
import { ElectrophorusCanvas } from '@/components/simulation/ElectrophorusCanvas';
import { SimulationControls } from '@/components/simulation/SimulationControls';

type Topic = 'production' | 'electroscope' | 'electrophorus';

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

function ElectrostaticsChargingEmbedInner() {
  const sp = useSearchParams();
  const topic = ((): Topic => {
    const t = sp.get('topic');
    return t === 'electroscope' || t === 'electrophorus' ? t : 'production';
  })();
  const showControls = sp.get('controls') !== '0';

  const [method, setMethod] = useState<ChargingMethod>(() => {
    const m = sp.get('method');
    return m === 'conduction' || m === 'induction' ? m : 'friction';
  });
  const [electroscopeMode, setElectroscopeMode] = useState<ElectroscopeMode>(() => (sp.get('mode') === 'testing' ? 'testing' : 'charging'));
  const [rodSign, setRodSign] = useState<1 | -1>(() => (sp.get('rod') === '-1' ? -1 : 1));
  const [electroscopeSign, setElectroscopeSign] = useState<1 | -1>(() => (sp.get('es') === '1' ? 1 : -1));

  const [isRunning, setIsRunning] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const [resetKey, setResetKey] = useState(0);
  const [electrophorusCycle, setElectrophorusCycle] = useState(0);
  const reset = useCallback(() => { setIsRunning(false); setIsPaused(false); setResetKey(k => k + 1); setElectrophorusCycle(0); }, []);
  const resetTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  useEffect(() => {
    if (resetTimer.current) clearTimeout(resetTimer.current);
    resetTimer.current = setTimeout(reset, 100);
  }, [topic, method, electroscopeMode, rodSign, electroscopeSign, reset]);

  return (
    <div className="mx-auto max-w-2xl space-y-3 p-3 sm:p-4">
      {topic === 'production' && (
        <ChargingMethodsCanvas key={resetKey} method={method} rodSign={rodSign} isRunning={isRunning} isPaused={isPaused} width={640} height={300} />
      )}
      {topic === 'electroscope' && (
        <ElectroscopeCanvas key={resetKey} mode={electroscopeMode} rodSign={rodSign} electroscopeSign={electroscopeSign}
          isRunning={isRunning} isPaused={isPaused} width={640} height={300} />
      )}
      {topic === 'electrophorus' && (
        <ElectrophorusCanvas key={resetKey} isRunning={isRunning} isPaused={isPaused}
          cycleCount={electrophorusCycle} onCycleComplete={() => setElectrophorusCycle(c => c + 1)} width={640} height={300} />
      )}
      <SimulationControls isRunning={isRunning} isPaused={isPaused}
        onRun={() => { setIsRunning(true); setIsPaused(false); }}
        onPause={() => setIsPaused(p => !p)} onReset={reset} />
      {showControls && (
        <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm space-y-3">
          <p className="text-xs font-medium uppercase tracking-wide text-gray-400">Parameters</p>
          {topic === 'production' && (
            <div className="flex flex-col gap-2">
              {(['friction', 'conduction', 'induction'] as const).map(m => (
                <button key={m} onClick={() => setMethod(m)}
                  className={`rounded-lg border px-3 py-2 text-xs font-medium capitalize text-left transition ${
                    method === m ? 'border-indigo-300 bg-indigo-50 text-indigo-700' : 'border-gray-200 bg-white text-gray-500'
                  }`}>{m}</button>
              ))}
              {method !== 'friction' && (
                <div className="flex gap-2 pt-1">
                  {([1, -1] as const).map(sgn => (
                    <button key={sgn} onClick={() => setRodSign(sgn)}
                      className={`flex-1 rounded-lg border px-2 py-2 text-xs font-medium transition ${
                        rodSign === sgn ? 'border-indigo-300 bg-indigo-50 text-indigo-700' : 'border-gray-200 bg-white text-gray-500'
                      }`}>Rod: {sgn > 0 ? '+' : '−'}</button>
                  ))}
                </div>
              )}
            </div>
          )}
          {topic === 'electroscope' && <>
            <div className="flex gap-2">
              {(['charging', 'testing'] as const).map(m => (
                <button key={m} onClick={() => setElectroscopeMode(m)}
                  className={`flex-1 rounded-lg border px-2 py-2 text-xs font-medium capitalize transition ${
                    electroscopeMode === m ? 'border-indigo-300 bg-indigo-50 text-indigo-700' : 'border-gray-200 bg-white text-gray-500'
                  }`}>{m}</button>
              ))}
            </div>
            {electroscopeMode === 'testing' && (
              <div className="flex gap-2">
                {([1, -1] as const).map(sgn => (
                  <button key={sgn} onClick={() => setElectroscopeSign(sgn)}
                    className={`flex-1 rounded-lg border px-2 py-2 text-xs font-medium transition ${
                      electroscopeSign === sgn ? 'border-indigo-300 bg-indigo-50 text-indigo-700' : 'border-gray-200 bg-white text-gray-500'
                    }`}>Electroscope: {sgn > 0 ? '+' : '−'}</button>
                ))}
              </div>
            )}
            <div className="flex gap-2">
              {([1, -1] as const).map(sgn => (
                <button key={sgn} onClick={() => setRodSign(sgn)}
                  className={`flex-1 rounded-lg border px-2 py-2 text-xs font-medium transition ${
                    rodSign === sgn ? 'border-indigo-300 bg-indigo-50 text-indigo-700' : 'border-gray-200 bg-white text-gray-500'
                  }`}>Rod: {sgn > 0 ? '+' : '−'}</button>
              ))}
            </div>
          </>}
          {topic === 'electrophorus' && (
            <p className="text-xs text-gray-500">Press Run to lower the disc, earth it, and lift it away.</p>
          )}
        </div>
      )}
      <PoweredBy />
    </div>
  );
}

export default function ElectrostaticsChargingEmbedPage() {
  return (
    <Suspense fallback={<div className="p-8 text-center text-xs text-gray-400">Loading simulation…</div>}>
      <ElectrostaticsChargingEmbedInner />
    </Suspense>
  );
}
AFEOF

echo ""
echo "Patch v37 applied -- 5 files written."
echo ""
echo "Next steps:"
echo "  rm -rf .next"
echo "  npm run dev"
echo ""
echo "Check: /simulations/electrostatics-charging"
echo "  Production of charges -> Conduction: try both rod signs -- watch the"
echo "    electron dots reverse direction for a positive vs negative rod."
echo "  Production of charges -> Induction: the rod should stop much closer"
echo "    to the sphere now (but still not touching), and the electron dots"
echo "    should visibly migrate position rather than a + symbol appearing."
echo "  Gold-leaf electroscope -> Charging: try a positive rod -- electrons"
echo "    should flow UP and OUT of the electroscope, not down into it."
echo "  Electrophorus: the induced-side + should now be a label, and the"
echo "    electron dots should visibly cluster then redistribute."
