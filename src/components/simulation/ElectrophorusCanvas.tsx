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
