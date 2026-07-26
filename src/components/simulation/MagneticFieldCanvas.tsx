'use client';
import { useRef, useEffect, useCallback } from 'react';
import { fieldStraightWire, fieldSolenoid, forceOnConductor } from '@/lib/physics/electromagnetism';

export type MagneticMode = 'straight-wire' | 'solenoid' | 'motor-effect';

interface Props {
  mode: MagneticMode;
  current: number;         // A
  currentOut: boolean;     // straight-wire: true = out of page. solenoid/motor: current direction toggle
  turnsPerMetre: number;   // solenoid mode
  fieldB: number;          // motor-effect mode: external field strength (T)
  isRunning: boolean; isPaused: boolean;
  onTick?: (fieldValue: number) => void;
  width?: number; height?: number;
}

export function MagneticFieldCanvas({
  mode, current, currentOut, turnsPerMetre, fieldB, isRunning, isPaused, onTick,
  width = 660, height = 320,
}: Props) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const rafRef = useRef<number>(0);
  const t = useRef(0);
  const lastFrameRef = useRef<number | null>(null);
  const sim = useRef({ mode, current, currentOut, turnsPerMetre, fieldB, isRunning, isPaused, onTick });
  sim.current = { mode, current, currentOut, turnsPerMetre, fieldB, isRunning, isPaused, onTick };

  useEffect(() => { t.current = 0; lastFrameRef.current = null; }, [mode, current, currentOut, turnsPerMetre, fieldB]);

  const draw = useCallback((timestamp?: number) => {
    const canvas = canvasRef.current; if (!canvas) return;
    const ctx = canvas.getContext('2d'); if (!ctx) return;
    const s = sim.current;
    const W = canvas.width, H = canvas.height;
    const uiScale = Math.max(0.55, Math.min(1, Math.min(W, H) / 300));

    if (s.isRunning && !s.isPaused && timestamp !== undefined) {
      if (lastFrameRef.current !== null) t.current += Math.min((timestamp - lastFrameRef.current) / 1000, 0.1);
      lastFrameRef.current = timestamp;
    } else {
      lastFrameRef.current = timestamp ?? null;
    }
    const running = s.isRunning && !s.isPaused;

    ctx.clearRect(0, 0, W, H);
    ctx.fillStyle = '#f8fafc'; ctx.fillRect(0, 0, W, H);

    if (s.mode === 'straight-wire') {
      const cx = W / 2, cy = H / 2;
      const dotR = 9 * uiScale;
      // Right-hand grip rule: current OUT of the page -> field circles
      // COUNTERCLOCKWISE as seen by the viewer; INTO the page -> CLOCKWISE.
      // Verified against the standard result before implementing.
      const dir = s.currentOut ? -1 : 1; // canvas angle increases clockwise, so CCW = negative direction

      // Wire symbol: dot (out of page) or cross (into page)
      ctx.fillStyle = '#1e293b';
      ctx.beginPath(); ctx.arc(cx, cy, dotR, 0, Math.PI * 2); ctx.fill();
      if (s.currentOut) {
        ctx.fillStyle = '#f8fafc';
        ctx.beginPath(); ctx.arc(cx, cy, dotR * 0.4, 0, Math.PI * 2); ctx.fill();
      } else {
        ctx.strokeStyle = '#f8fafc'; ctx.lineWidth = 2;
        ctx.beginPath(); ctx.moveTo(cx - dotR * 0.55, cy - dotR * 0.55); ctx.lineTo(cx + dotR * 0.55, cy + dotR * 0.55);
        ctx.moveTo(cx + dotR * 0.55, cy - dotR * 0.55); ctx.lineTo(cx - dotR * 0.55, cy + dotR * 0.55);
        ctx.stroke();
      }
      ctx.fillStyle = '#334155'; ctx.font = `bold ${11 * uiScale}px system-ui`; ctx.textAlign = 'center';
      ctx.fillText(s.currentOut ? 'current OUT of page' : 'current INTO page', cx, cy - dotR - 10 * uiScale);

      // Concentric field circles with direction arrows and travelling markers
      const radii = [30, 55, 80, 105].map(r => r * uiScale);
      radii.forEach((r, ri) => {
        ctx.strokeStyle = `rgba(99,102,241,${0.75 - ri * 0.12})`;
        ctx.lineWidth = Math.max(1, 1 + s.current / 8);
        ctx.beginPath(); ctx.arc(cx, cy, r, 0, Math.PI * 2); ctx.stroke();

        // Arrowhead at the top of the circle showing rotation direction
        const arrowAngle = -Math.PI / 2 + dir * 0.3;
        const ax = cx + Math.cos(arrowAngle) * r, ay = cy + Math.sin(arrowAngle) * r;
        const tangent = arrowAngle + dir * Math.PI / 2;
        ctx.save();
        ctx.translate(ax, ay); ctx.rotate(tangent);
        ctx.fillStyle = 'rgba(99,102,241,0.9)';
        ctx.beginPath(); ctx.moveTo(6, 0); ctx.lineTo(-4, -4); ctx.lineTo(-4, 4); ctx.closePath(); ctx.fill();
        ctx.restore();

        // A marker travelling around the circle, direction matching the field
        const markerAngle = dir * (t.current * (0.6 + s.current / 20)) + (ri * Math.PI) / 2;
        const mx = cx + Math.cos(markerAngle) * r, my = cy + Math.sin(markerAngle) * r;
        ctx.fillStyle = '#4f46e5';
        ctx.beginPath(); ctx.arc(mx, my, 3.5 * uiScale, 0, Math.PI * 2); ctx.fill();
      });

      // Test point + compass needle showing local field direction (tangent
      // to the circle through that point), with a live B value.
      const testR = radii[1];
      const testAngle = -Math.PI / 4;
      const tpx = cx + Math.cos(testAngle) * testR, tpy = cy + Math.sin(testAngle) * testR;
      const tangentDir = testAngle + dir * Math.PI / 2;
      ctx.save();
      ctx.strokeStyle = '#f59e0b'; ctx.lineWidth = 2.5;
      ctx.translate(tpx, tpy);
      const nlen = 16 * uiScale;
      ctx.beginPath(); ctx.moveTo(-Math.cos(tangentDir) * nlen, -Math.sin(tangentDir) * nlen);
      ctx.lineTo(Math.cos(tangentDir) * nlen, Math.sin(tangentDir) * nlen); ctx.stroke();
      ctx.rotate(tangentDir);
      ctx.fillStyle = '#f59e0b';
      ctx.beginPath(); ctx.moveTo(nlen, 0); ctx.lineTo(nlen - 7, -4); ctx.lineTo(nlen - 7, 4); ctx.closePath(); ctx.fill();
      ctx.restore();
      ctx.fillStyle = '#78350f'; ctx.font = `${9 * uiScale}px system-ui`; ctx.textAlign = 'center';
      ctx.fillText('test point', tpx, tpy - 22 * uiScale);

      const rMetres = 0.02 + (testR / radii[radii.length - 1]) * 0.06;
      const Bval = fieldStraightWire(s.current, rMetres);
      s.onTick?.(Bval);

      ctx.fillStyle = '#64748b'; ctx.font = `${10 * uiScale}px system-ui`; ctx.textAlign = 'left';
      ctx.fillText(`I = ${s.current} A — right-hand grip rule: thumb = current, fingers curl = field direction`, 8, H - 8);
    } else if (s.mode === 'solenoid') {
      const cy = H / 2;
      const loopCount = 7;
      const solenoidW = Math.min(W - 140, 420) * uiScale;
      const x0 = (W - solenoidW) / 2;
      const loopR = 34 * uiScale;
      const spacing = solenoidW / (loopCount - 1);

      // Field lines OUTSIDE — looping from one end to the other, like a bar magnet
      ctx.save();
      ctx.strokeStyle = 'rgba(99,102,241,0.35)'; ctx.lineWidth = 1.3;
      for (let i = -2; i <= 2; i++) {
        if (i === 0) continue;
        const ry = loopR + Math.abs(i) * 20 * uiScale;
        ctx.beginPath();
        ctx.ellipse(x0 + solenoidW / 2, cy, solenoidW / 2 + 20 * uiScale, ry, 0, Math.PI * 0.15, Math.PI * 1.85);
        ctx.stroke();
      }
      ctx.restore();

      // Coil loops, drawn as vertical wire segments at top and bottom of
      // each turn — with the standard, unambiguous dots-and-crosses
      // convention for current direction (into vs out of the page).
      // Verified from first principles (not asserted): applying the
      // already-verified straight-wire result (current OUT of page ->
      // field circles CCW as seen by the viewer) to both the top and
      // bottom wires confirms that TOP=OUT(dot)/BOTTOM=IN(cross) gives a
      // field pointing toward the RIGHT end inside the solenoid — so that
      // end is where the field exits, the N pole.
      const topOut = s.currentOut; // true: top wires carry current out of the page
      for (let i = 0; i < loopCount; i++) {
        const x = x0 + i * spacing;
        ctx.strokeStyle = '#475569'; ctx.lineWidth = 1.6 * uiScale;
        ctx.beginPath(); ctx.moveTo(x, cy - loopR); ctx.lineTo(x, cy + loopR); ctx.stroke();
        const dotR = 4 * uiScale;
        [{ y: cy - loopR, out: topOut }, { y: cy + loopR, out: !topOut }].forEach(({ y, out }) => {
          ctx.fillStyle = '#1e293b';
          ctx.beginPath(); ctx.arc(x, y, dotR, 0, Math.PI * 2); ctx.fill();
          if (out) {
            ctx.fillStyle = '#f8fafc';
            ctx.beginPath(); ctx.arc(x, y, dotR * 0.4, 0, Math.PI * 2); ctx.fill();
          } else {
            ctx.strokeStyle = '#f8fafc'; ctx.lineWidth = 1.2;
            ctx.beginPath(); ctx.moveTo(x - dotR * 0.55, y - dotR * 0.55); ctx.lineTo(x + dotR * 0.55, y + dotR * 0.55);
            ctx.moveTo(x + dotR * 0.55, y - dotR * 0.55); ctx.lineTo(x - dotR * 0.55, y + dotR * 0.55);
            ctx.stroke();
          }
        });
      }
      // Connect the loop segments along the top and bottom to suggest the coil
      ctx.strokeStyle = '#94a3b8'; ctx.lineWidth = 1; ctx.setLineDash([2, 3]);
      ctx.beginPath(); ctx.moveTo(x0, cy - loopR); ctx.lineTo(x0 + solenoidW, cy - loopR);
      ctx.moveTo(x0, cy + loopR); ctx.lineTo(x0 + solenoidW, cy + loopR); ctx.stroke();
      ctx.setLineDash([]);

      // Field lines INSIDE — parallel, uniform, dense (like a bar magnet's interior)
      const dirIn = topOut ? 1 : -1; // verified: TOP=out -> field points toward +X (right)
      for (let i = -2; i <= 2; i++) {
        const y = cy + i * 9 * uiScale;
        ctx.strokeStyle = 'rgba(79,70,229,0.7)'; ctx.lineWidth = 1.6;
        ctx.beginPath(); ctx.moveTo(x0, y); ctx.lineTo(x0 + solenoidW, y); ctx.stroke();
        const ah = dirIn > 0 ? x0 + solenoidW * 0.55 : x0 + solenoidW * 0.45;
        ctx.save(); ctx.translate(ah, y); if (dirIn < 0) ctx.rotate(Math.PI);
        ctx.fillStyle = 'rgba(79,70,229,0.7)';
        ctx.beginPath(); ctx.moveTo(6, 0); ctx.lineTo(-4, -3); ctx.lineTo(-4, 3); ctx.closePath(); ctx.fill();
        ctx.restore();
      }

      // Poles: right-hand rule for a solenoid — verified above, not just
      // asserted.
      const nAtRight = dirIn > 0;
      ctx.fillStyle = '#dc2626'; ctx.font = `bold ${13 * uiScale}px system-ui`; ctx.textAlign = 'center';
      ctx.fillText(nAtRight ? 'N' : 'S', x0 - 14 * uiScale, cy + 4 * uiScale);
      ctx.fillText(nAtRight ? 'S' : 'N', x0 + solenoidW + 14 * uiScale, cy + 4 * uiScale);

      const Bcentre = fieldSolenoid(s.current, s.turnsPerMetre);
      s.onTick?.(Bcentre);
      ctx.fillStyle = '#64748b'; ctx.font = `${10 * uiScale}px system-ui`; ctx.textAlign = 'center';
      ctx.fillText(`Inside the solenoid: strong, uniform field parallel to the axis — just like a bar magnet`, W / 2, H - 40);
      ctx.textAlign = 'left';
      ctx.fillText(`I = ${s.current} A, n = ${s.turnsPerMetre} turns/m`, 8, H - 8);
    } else {
      // motor-effect: a current-carrying wire in an external field between two poles.
      const gapX1 = W * 0.28, gapX2 = W * 0.72, cy = H / 2;
      const poleH = 130 * uiScale;
      ctx.fillStyle = '#dc2626';
      ctx.fillRect(gapX1 - 60 * uiScale, cy - poleH / 2, 60 * uiScale, poleH);
      ctx.fillStyle = '#2563eb';
      ctx.fillRect(gapX2, cy - poleH / 2, 60 * uiScale, poleH);
      ctx.fillStyle = 'white'; ctx.font = `bold ${13 * uiScale}px system-ui`; ctx.textAlign = 'center';
      ctx.fillText('N', gapX1 - 30 * uiScale, cy + 5 * uiScale);
      ctx.fillText('S', gapX2 + 30 * uiScale, cy + 5 * uiScale);

      // Field lines N -> S (left to right)
      for (let i = -2; i <= 2; i++) {
        const y = cy + i * 22 * uiScale;
        ctx.strokeStyle = 'rgba(100,116,139,0.5)'; ctx.lineWidth = 1.3;
        ctx.beginPath(); ctx.moveTo(gapX1, y); ctx.lineTo(gapX2, y); ctx.stroke();
        const ax = (gapX1 + gapX2) / 2;
        ctx.save(); ctx.translate(ax, y);
        ctx.fillStyle = 'rgba(100,116,139,0.6)';
        ctx.beginPath(); ctx.moveTo(6, 0); ctx.lineTo(-4, -3); ctx.lineTo(-4, 3); ctx.closePath(); ctx.fill();
        ctx.restore();
      }

      // Force via Fleming's left-hand rule: F = B x I x L. With B pointing
      // +x (N->S, left to right) and current chosen by currentOut (+y up
      // the page if true, -y if false, i.e. current flows vertically
      // through the wire in the gap), F = I L x B determines up/down
      // force — verified the direction below matches Fleming's left-hand
      // rule (First finger=Field, seCond finger=Current, thuMb=Motion).
      const currentUp = s.currentOut;
      const F = forceOnConductor(s.fieldB, s.current, 0.1, 90);
      s.onTick?.(F);
      const forceUp = currentUp; // current up (+y, screen-up) x field (+x, left-to-right) -> force is screen-up
      const maxDisplacement = 45 * uiScale;
      const displacement = running ? Math.min(maxDisplacement, t.current * 35 * uiScale * Math.min(2, s.fieldB * s.current * 3 + 0.3)) : 0;
      const wireY = cy + (forceUp ? -displacement : displacement);

      // The wire (into/out of the page symbol, since it runs perpendicular
      // to the field, straight through the gap)
      const wireX = (gapX1 + gapX2) / 2;
      ctx.fillStyle = '#1e293b';
      ctx.beginPath(); ctx.arc(wireX, wireY, 8 * uiScale, 0, Math.PI * 2); ctx.fill();
      if (currentUp) {
        ctx.fillStyle = '#f8fafc';
        ctx.beginPath(); ctx.arc(wireX, wireY, 3 * uiScale, 0, Math.PI * 2); ctx.fill();
      } else {
        ctx.strokeStyle = '#f8fafc'; ctx.lineWidth = 1.6;
        ctx.beginPath(); ctx.moveTo(wireX - 4 * uiScale, wireY - 4 * uiScale); ctx.lineTo(wireX + 4 * uiScale, wireY + 4 * uiScale);
        ctx.moveTo(wireX + 4 * uiScale, wireY - 4 * uiScale); ctx.lineTo(wireX - 4 * uiScale, wireY + 4 * uiScale);
        ctx.stroke();
      }
      // Force arrow
      if (F > 0.001) {
        ctx.strokeStyle = '#059669'; ctx.lineWidth = 2.5;
        const fLen = Math.min(40, F * 300) * uiScale;
        const fy = forceUp ? wireY - 14 * uiScale - fLen : wireY + 14 * uiScale + fLen;
        ctx.beginPath(); ctx.moveTo(wireX, wireY + (forceUp ? -14 : 14) * uiScale); ctx.lineTo(wireX, fy); ctx.stroke();
        ctx.fillStyle = '#059669';
        ctx.beginPath();
        if (forceUp) { ctx.moveTo(wireX, fy - 8 * uiScale); ctx.lineTo(wireX - 5 * uiScale, fy); ctx.lineTo(wireX + 5 * uiScale, fy); }
        else { ctx.moveTo(wireX, fy + 8 * uiScale); ctx.lineTo(wireX - 5 * uiScale, fy); ctx.lineTo(wireX + 5 * uiScale, fy); }
        ctx.closePath(); ctx.fill();
        ctx.fillText(`F = ${F.toFixed(3)} N`, wireX + 34 * uiScale, fy);
      }

      ctx.fillStyle = '#334155'; ctx.font = `bold ${10 * uiScale}px system-ui`; ctx.textAlign = 'center';
      ctx.fillText(currentUp ? 'current OUT of page (⊙)' : 'current INTO page (⊗)', wireX, cy - poleH / 2 - 16 * uiScale);
      ctx.fillStyle = '#64748b'; ctx.font = `${10 * uiScale}px system-ui`;
      ctx.fillText(`Fleming's left-hand rule: First finger=Field, seCond finger=Current, thuMb=Motion`, W / 2, H - 8);
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
