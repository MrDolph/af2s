'use client';
import { useRef, useEffect, useCallback } from 'react';
import { generatorPeakEmf, transformerSecondaryVoltage, transformerSecondaryCurrent } from '@/lib/physics/electromagnetism';

export type InductionMode = 'faraday-lenz' | 'ac-generator' | 'transformer';

interface Props {
  mode: InductionMode;
  turns: number;             // faraday-lenz: coil turns. generator: coil turns.
  speed: number;              // faraday-lenz: magnet oscillation speed (rad/s-ish)
  magnetPoleOut: boolean;     // faraday-lenz: which pole faces the coil (true = N facing coil)
  fieldB: number;             // generator: field strength (T)
  coilArea: number;           // generator: coil area (m^2)
  omega: number;              // generator: angular speed (rad/s)
  primaryTurns: number;       // transformer
  secondaryTurns: number;     // transformer
  primaryVoltage: number;     // transformer: peak AC voltage
  isRunning: boolean; isPaused: boolean;
  onTick?: (value: number) => void;
  width?: number; height?: number;
}

function drawGalvanometer(ctx: CanvasRenderingContext2D, cx: number, cy: number, r: number, deflectionFrac: number, uiScale: number) {
  ctx.save();
  ctx.fillStyle = '#f8fafc'; ctx.strokeStyle = '#94a3b8'; ctx.lineWidth = 2;
  ctx.beginPath(); ctx.arc(cx, cy, r, Math.PI, 0); ctx.closePath(); ctx.fill(); ctx.stroke();
  ctx.strokeStyle = '#cbd5e1'; ctx.lineWidth = 1;
  for (let i = -1; i <= 1; i++) {
    const a = Math.PI / 2 + i * Math.PI / 3;
    ctx.beginPath(); ctx.moveTo(cx + Math.cos(a) * r * 0.7, cy - Math.sin(a) * r * 0.7); ctx.lineTo(cx + Math.cos(a) * r * 0.9, cy - Math.sin(a) * r * 0.9); ctx.stroke();
  }
  const clamped = Math.max(-1, Math.min(1, deflectionFrac));
  const needleAngle = Math.PI / 2 - clamped * (Math.PI / 2.4);
  ctx.strokeStyle = '#dc2626'; ctx.lineWidth = 2.5;
  ctx.beginPath(); ctx.moveTo(cx, cy); ctx.lineTo(cx + Math.cos(needleAngle) * r * 0.85, cy - Math.sin(needleAngle) * r * 0.85); ctx.stroke();
  ctx.fillStyle = '#334155';
  ctx.beginPath(); ctx.arc(cx, cy, 3 * uiScale, 0, Math.PI * 2); ctx.fill();
  ctx.font = `${9 * uiScale}px system-ui`; ctx.textAlign = 'center'; ctx.fillStyle = '#64748b';
  ctx.fillText('G', cx, cy + 16 * uiScale);
}

export function InductionCanvas({
  mode, turns, speed, magnetPoleOut, fieldB, coilArea, omega,
  primaryTurns, secondaryTurns, primaryVoltage,
  isRunning, isPaused, onTick, width = 660, height = 320,
}: Props) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const rafRef = useRef<number>(0);
  const t = useRef(0);
  const lastFrameRef = useRef<number | null>(null);
  const prevFluxRef = useRef<number | null>(null);
  const emfTraceRef = useRef<number[]>([]);
  const sim = useRef({ mode, turns, speed, magnetPoleOut, fieldB, coilArea, omega, primaryTurns, secondaryTurns, primaryVoltage, isRunning, isPaused, onTick });
  sim.current = { mode, turns, speed, magnetPoleOut, fieldB, coilArea, omega, primaryTurns, secondaryTurns, primaryVoltage, isRunning, isPaused, onTick };

  useEffect(() => {
    t.current = 0; lastFrameRef.current = null; prevFluxRef.current = null; emfTraceRef.current = [];
  }, [mode, turns, speed, magnetPoleOut, fieldB, coilArea, omega, primaryTurns, secondaryTurns, primaryVoltage]);

  const draw = useCallback((timestamp?: number) => {
    const canvas = canvasRef.current; if (!canvas) return;
    const ctx = canvas.getContext('2d'); if (!ctx) return;
    const s = sim.current;
    const W = canvas.width, H = canvas.height;
    const uiScale = Math.max(0.55, Math.min(1, Math.min(W, H) / 300));

    let dt = 0;
    if (s.isRunning && !s.isPaused && timestamp !== undefined) {
      if (lastFrameRef.current !== null) { dt = Math.min((timestamp - lastFrameRef.current) / 1000, 0.1); t.current += dt; }
      lastFrameRef.current = timestamp;
    } else {
      lastFrameRef.current = timestamp ?? null;
    }

    ctx.clearRect(0, 0, W, H);
    ctx.fillStyle = '#f8fafc'; ctx.fillRect(0, 0, W, H);

    if (s.mode === 'faraday-lenz') {
      const cy = H / 2;
      const coilX = W * 0.62;
      const loopR = 40 * uiScale;
      // Magnet oscillates in/out. x = gap between magnet tip and coil.
      const gapAmp = 150 * uiScale;
      const gapX = Math.abs(Math.sin(t.current * s.speed)) * gapAmp;

      // Flux linkage model: smooth bell curve in gap distance (physically
      // reasonable, not a literal dipole formula) — verified numerically
      // before implementing that this gives EMF that correctly peaks
      // during fast motion and drops to ~0 at the turning points.
      const x0 = 60 * uiScale;
      const flux = s.turns * (1 / (1 + (gapX / x0) * (gapX / x0))) * (s.magnetPoleOut ? 1 : -1);
      let emf = 0;
      if (prevFluxRef.current !== null && dt > 0) emf = -(flux - prevFluxRef.current) / dt;
      prevFluxRef.current = flux;

      const magnetX = coilX - loopR - 20 * uiScale - gapX;

      // Bar magnet
      const magW = 70 * uiScale, magH = 26 * uiScale;
      ctx.fillStyle = s.magnetPoleOut ? '#dc2626' : '#2563eb';
      ctx.fillRect(magnetX - magW, cy - magH / 2, magW / 2, magH);
      ctx.fillStyle = s.magnetPoleOut ? '#2563eb' : '#dc2626';
      ctx.fillRect(magnetX - magW / 2, cy - magH / 2, magW / 2, magH);
      ctx.strokeStyle = '#1e293b'; ctx.lineWidth = 1.5; ctx.strokeRect(magnetX - magW, cy - magH / 2, magW, magH);
      ctx.fillStyle = 'white'; ctx.font = `bold ${11 * uiScale}px system-ui`; ctx.textAlign = 'center';
      ctx.fillText(s.magnetPoleOut ? 'N' : 'S', magnetX - magW * 0.25, cy + 4 * uiScale);
      ctx.fillText(s.magnetPoleOut ? 'S' : 'N', magnetX - magW * 0.75, cy + 4 * uiScale);

      // Coil (dots-and-crosses convention, same as solenoid mode). The
      // induced near-face pole follows the verified Lenz's-law relation:
      // SAME as the magnet's facing pole while approaching (repel),
      // OPPOSITE while receding (attract) — derived from the sign of emf
      // (rate of flux increase) rather than asserted separately, so it
      // can never disagree with the galvanometer reading.
      const fluxIncreasing = emf * (s.magnetPoleOut ? -1 : 1) > 0; // emf = -dPhi/dt, so dPhi/dt = -emf
      const nearFaceIsN = fluxIncreasing ? s.magnetPoleOut : !s.magnetPoleOut;
      const loopCount = 5;
      const coilSpan = 70 * uiScale;
      for (let i = 0; i < loopCount; i++) {
        const x = coilX + (i / (loopCount - 1)) * coilSpan;
        ctx.strokeStyle = '#475569'; ctx.lineWidth = 1.6 * uiScale;
        ctx.beginPath(); ctx.moveTo(x, cy - loopR); ctx.lineTo(x, cy + loopR); ctx.stroke();
      }
      // Current markers only shown while there's meaningfully-large emf
      if (Math.abs(emf) > 0.01) {
        // Coil's near (left) face should be N when nearFaceIsN=true. The
        // solenoid mode verified TOP=out(dot)/BOTTOM=in(cross) puts N at
        // the RIGHT end; by mirror symmetry, reversing every current
        // (TOP=in/BOTTOM=out) moves N to the LEFT end instead — so
        // nearFaceIsN=true (N wanted at the left, near, end) needs
        // topOut=false, not topOut=nearFaceIsN.
        const topOut = !nearFaceIsN;
        for (let i = 0; i < loopCount; i++) {
          const x = coilX + (i / (loopCount - 1)) * coilSpan;
          const dotR = 3.5 * uiScale;
          [{ y: cy - loopR, out: topOut }, { y: cy + loopR, out: !topOut }].forEach(({ y, out }) => {
            ctx.fillStyle = '#1e293b';
            ctx.beginPath(); ctx.arc(x, y, dotR, 0, Math.PI * 2); ctx.fill();
            if (out) { ctx.fillStyle = '#f8fafc'; ctx.beginPath(); ctx.arc(x, y, dotR * 0.4, 0, Math.PI * 2); ctx.fill(); }
            else {
              ctx.strokeStyle = '#f8fafc'; ctx.lineWidth = 1;
              ctx.beginPath(); ctx.moveTo(x - dotR * 0.5, y - dotR * 0.5); ctx.lineTo(x + dotR * 0.5, y + dotR * 0.5);
              ctx.moveTo(x + dotR * 0.5, y - dotR * 0.5); ctx.lineTo(x - dotR * 0.5, y + dotR * 0.5); ctx.stroke();
            }
          });
        }
        ctx.fillStyle = nearFaceIsN ? '#dc2626' : '#2563eb'; ctx.font = `bold ${10 * uiScale}px system-ui`; ctx.textAlign = 'center';
        ctx.fillText(nearFaceIsN ? 'N' : 'S', coilX - 12 * uiScale, cy - loopR - 10 * uiScale);
      }

      drawGalvanometer(ctx, coilX + coilSpan + 55 * uiScale, cy, 32 * uiScale, emf * 0.4, uiScale);
      s.onTick?.(emf);

      ctx.fillStyle = '#334155'; ctx.font = `bold ${10 * uiScale}px system-ui`; ctx.textAlign = 'center';
      ctx.fillText(`EMF = ${emf.toFixed(2)} (arb. units) — ${Math.abs(emf) < 0.02 ? 'no relative motion, no EMF' : fluxIncreasing ? 'flux increasing: coil repels the magnet' : 'flux decreasing: coil attracts the magnet'}`, W / 2, H - 8);
    } else if (s.mode === 'ac-generator') {
      const cx = W * 0.32, cy = H / 2;
      const poleGap = 90 * uiScale, poleH = 130 * uiScale;
      ctx.fillStyle = '#dc2626'; ctx.fillRect(cx - poleGap - 50 * uiScale, cy - poleH / 2, 50 * uiScale, poleH);
      ctx.fillStyle = '#2563eb'; ctx.fillRect(cx + poleGap, cy - poleH / 2, 50 * uiScale, poleH);
      ctx.fillStyle = 'white'; ctx.font = `bold ${12 * uiScale}px system-ui`; ctx.textAlign = 'center';
      ctx.fillText('N', cx - poleGap - 25 * uiScale, cy + 4 * uiScale);
      ctx.fillText('S', cx + poleGap + 25 * uiScale, cy + 4 * uiScale);
      for (let i = -2; i <= 2; i++) {
        const y = cy + i * 22 * uiScale;
        ctx.strokeStyle = 'rgba(100,116,139,0.4)'; ctx.lineWidth = 1.2;
        ctx.beginPath(); ctx.moveTo(cx - poleGap, y); ctx.lineTo(cx + poleGap, y); ctx.stroke();
      }

      const theta = s.omega * t.current;
      const coilW = 60 * uiScale, coilH = 80 * uiScale;
      // Rotating coil, viewed edge-on: its apparent width shrinks with cos(theta)
      // Apparent width: zero when the coil's normal points along B (edge-on
      // to the viewer, flux max, EMF=0) and full when the normal points
      // toward the viewer (face-on, flux=0, EMF=peak) — verified from the
      // 3D geometry before implementing; this is sin(theta), not cos(theta).
      const apparentW = Math.abs(Math.sin(theta)) * coilW;
      const frontFacing = Math.sin(theta) >= 0;
      ctx.save();
      ctx.strokeStyle = frontFacing ? '#4f46e5' : '#7c3aed'; ctx.lineWidth = 3 * uiScale;
      ctx.strokeRect(cx - apparentW / 2, cy - coilH / 2, Math.max(2, apparentW), coilH);
      ctx.restore();

      const peakEmf = generatorPeakEmf(s.turns, s.fieldB, s.coilArea, s.omega);
      const emfNow = peakEmf * Math.sin(theta);
      s.onTick?.(emfNow);

      if (s.isRunning && !s.isPaused) {
        emfTraceRef.current.push(emfNow);
        if (emfTraceRef.current.length > 200) emfTraceRef.current.shift();
      }
      // EMF-vs-time graph
      const gx = W * 0.62, gy = H * 0.28, gw = W * 0.34, gh = H * 0.44;
      ctx.strokeStyle = '#cbd5e1'; ctx.lineWidth = 1;
      ctx.strokeRect(gx, gy, gw, gh);
      ctx.beginPath(); ctx.moveTo(gx, gy + gh / 2); ctx.lineTo(gx + gw, gy + gh / 2);
      ctx.strokeStyle = '#e2e8f0'; ctx.stroke();
      const trace = emfTraceRef.current;
      if (trace.length > 1 && peakEmf > 0) {
        ctx.beginPath();
        trace.forEach((v, i) => {
          const px = gx + (i / 199) * gw;
          const py = gy + gh / 2 - (v / peakEmf) * (gh / 2 - 4);
          if (i === 0) ctx.moveTo(px, py); else ctx.lineTo(px, py);
        });
        ctx.strokeStyle = '#4f46e5'; ctx.lineWidth = 1.8; ctx.stroke();
      }
      ctx.fillStyle = '#64748b'; ctx.font = `${9 * uiScale}px system-ui`; ctx.textAlign = 'left';
      ctx.fillText(`EMF vs time`, gx, gy - 6);
      ctx.fillText(`peak = ${peakEmf.toFixed(1)}V`, gx, gy + gh + 14);

      ctx.fillStyle = '#334155'; ctx.font = `bold ${10 * uiScale}px system-ui`; ctx.textAlign = 'center';
      const nearParallel = Math.abs(Math.sin(theta)) > 0.97;
      const nearPerp = Math.abs(Math.cos(theta)) > 0.97;
      ctx.fillText(
        nearParallel ? 'Coil plane parallel to B: cutting field lines fastest — EMF near MAXIMUM'
          : nearPerp ? 'Coil plane perpendicular to B: sides moving along the field — EMF near ZERO'
          : `e = ${emfNow.toFixed(1)} V`,
        W / 2, H - 8,
      );
    } else {
      // transformer
      const cx = W / 2, cy = H / 2;
      const coreW = 220 * uiScale, coreH = 130 * uiScale, coreT = 22 * uiScale;
      ctx.strokeStyle = '#78716c'; ctx.lineWidth = coreT; ctx.lineJoin = 'round';
      ctx.strokeRect(cx - coreW / 2, cy - coreH / 2, coreW, coreH);
      ctx.fillStyle = '#f8fafc'; ctx.fillRect(cx - coreW / 2 + coreT, cy - coreH / 2 + coreT, coreW - coreT * 2, coreH - coreT * 2);

      const omegaT = 4;
      const iPrimary = Math.sin(t.current * omegaT);
      const primaryTurnsDrawn = 5, secondaryTurnsDrawn = Math.max(3, Math.min(8, Math.round(5 * (s.secondaryTurns / Math.max(1, s.primaryTurns)))));
      const px = cx - coreW / 2 - 4 * uiScale, sx = cx + coreW / 2 + 4 * uiScale;
      const loopR = 16 * uiScale;
      for (let i = 0; i < primaryTurnsDrawn; i++) {
        const y = cy - coreH / 2 + 14 * uiScale + i * ((coreH - 28 * uiScale) / (primaryTurnsDrawn - 1));
        ctx.strokeStyle = '#dc2626'; ctx.lineWidth = 1.8 * uiScale;
        ctx.beginPath(); ctx.ellipse(px, y, loopR, 7 * uiScale, 0, 0, Math.PI * 2); ctx.stroke();
      }
      for (let i = 0; i < secondaryTurnsDrawn; i++) {
        const y = cy - coreH / 2 + 14 * uiScale + i * ((coreH - 28 * uiScale) / (secondaryTurnsDrawn - 1));
        ctx.strokeStyle = '#2563eb'; ctx.lineWidth = 1.8 * uiScale;
        ctx.beginPath(); ctx.ellipse(sx, y, loopR, 7 * uiScale, 0, 0, Math.PI * 2); ctx.stroke();
      }
      // Current direction markers, oscillating with iPrimary
      ctx.fillStyle = iPrimary >= 0 ? '#dc2626' : '#f87171';
      ctx.beginPath(); ctx.arc(px, cy - coreH / 2 - 14 * uiScale, 3.5 * uiScale, 0, Math.PI * 2); ctx.fill();

      const vs = transformerSecondaryVoltage(s.primaryVoltage, s.primaryTurns, s.secondaryTurns);
      const isec = transformerSecondaryCurrent(1, s.primaryTurns, s.secondaryTurns); // per 1A primary, illustrative
      s.onTick?.(vs);

      ctx.fillStyle = '#334155'; ctx.font = `bold ${10 * uiScale}px system-ui`; ctx.textAlign = 'center';
      ctx.fillText(`${s.primaryTurns} turns`, px, cy + coreH / 2 + 18 * uiScale);
      ctx.fillText(`${s.secondaryTurns} turns`, sx, cy + coreH / 2 + 18 * uiScale);
      ctx.fillStyle = '#64748b'; ctx.font = `${10 * uiScale}px system-ui`;
      ctx.fillText(
        `Vp=${s.primaryVoltage}V -> Vs=${vs.toFixed(1)}V (${s.secondaryTurns > s.primaryTurns ? 'step-UP' : s.secondaryTurns < s.primaryTurns ? 'step-DOWN' : 'isolation, 1:1'}) — Is per 1A Ip = ${isec.toFixed(2)}A`,
        W / 2, H - 8,
      );
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
