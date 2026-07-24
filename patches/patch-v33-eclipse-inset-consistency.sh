#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
# A-Factor STEM Studio — patch v33: fix "View from Earth" inset not
# corresponding to the actual eclipse state for solar/annular
#
#   DIAGNOSIS. The inset used a completely separate, uncoordinated
#   calculation from the main diagram's none/partial/total classification
#   — raw Moon vertical offset, normalised against the orbit's maximum
#   possible offset, with NO check against validGeometry at all. Verified
#   numerically that this was actively wrong: at the Moon's far-side node
#   (irrelevant for solar/annular — no eclipse is geometrically possible
#   there), its raw vertical offset is ALSO near zero, just as it is at
#   the correct near-side node — so the inset showed a near-total-eclipse
#   picture even when the main diagram correctly showed no eclipse at all
#   and no shadow cone was even being drawn.
#
#   FIX. The inset's Sun/Moon overlap is now derived directly from the
#   SAME umbra/penumbra values used to classify none/partial/total for
#   the main diagram (lifted to a shared scope, not recomputed
#   separately), and the overlap decision is keyed directly off
#   eclipseState rather than a separately-clamped continuous value that
#   could disagree with it near the edges. Verified numerically across
#   the full 360° orbit, for both solar and annular Moon sizes, that the
#   inset's overlap now agrees with eclipseState at every single degree —
#   overlap exactly when state is partial or total, clear separation
#   exactly when state is none, with a smooth, meaningful gradient (more
#   overlap deeper into a total eclipse, less near the edges) rather than
#   an abrupt binary jump.
#
# Run from the af2s project root (Git Bash):   bash patches/patch-v33-eclipse-inset-consistency.sh
# ══════════════════════════════════════════════════════════════════════════════
set -euo pipefail

if [ ! -f "package.json" ]; then
  echo "Run this from the af2s project root (package.json not found)." >&2
  exit 1
fi

echo "-- A-Factor patch v33: fix View from Earth inset consistency --"
mkdir -p "src/components/simulation"

echo "  -> src/components/simulation/EclipseCanvas.tsx"
cat > "src/components/simulation/EclipseCanvas.tsx" << 'AFEOF'
'use client';
import { useRef, useEffect, useCallback } from 'react';

export type EclipseType = 'solar' | 'annular' | 'lunar';

interface Props {
  eclipseType: EclipseType;
  orbitAngleDeg: number; // used as a fixed value only when not animating (paused/reset)
  isRunning: boolean; isPaused: boolean;
  onTick?: (angleDeg: number, eclipseState: 'none' | 'partial' | 'total') => void;
  width?: number; height?: number;
}

interface Vec { x: number; y: number; }
function lineAtX(p1: Vec, p2: Vec, x: number): number {
  const t = (x - p1.x) / (p2.x - p1.x);
  return p1.y + t * (p2.y - p1.y);
}

const ORBIT_PERIOD = 9;   // s — one full simulated lunar orbit, repeating continuously
const TILT_DEG = 30;      // exaggerated for visibility (real inclination ~5°) — chosen so the
                           // eclipse window is a genuinely narrow, "rare" fraction of the orbit

export function EclipseCanvas({ eclipseType, orbitAngleDeg, isRunning, isPaused, onTick, width = 660, height = 320 }: Props) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const rafRef = useRef<number>(0);
  const lastFrameRef = useRef<number | null>(null);
  const t = useRef(0);
  const sim = useRef({ eclipseType, orbitAngleDeg, isRunning, isPaused, onTick });
  sim.current = { eclipseType, orbitAngleDeg, isRunning, isPaused, onTick };

  useEffect(() => { t.current = 0; lastFrameRef.current = null; }, [eclipseType, orbitAngleDeg]);

  const draw = useCallback((timestamp?: number) => {
    const canvas = canvasRef.current; if (!canvas) return;
    const ctx = canvas.getContext('2d'); if (!ctx) return;
    const s = sim.current;
    const W = canvas.width, H = canvas.height;

    const animate = s.isRunning && !s.isPaused;
    if (animate && timestamp !== undefined) {
      if (lastFrameRef.current !== null) {
        t.current += Math.min((timestamp - lastFrameRef.current) / 1000, 0.1);
      }
      lastFrameRef.current = timestamp;
    } else {
      lastFrameRef.current = timestamp ?? null;
    }
    // The Moon genuinely orbits Earth, continuously, lap after lap — it
    // passes near alignment twice per orbit (the two nodes) and is
    // clearly off-axis the rest of the time, exactly like a real orbit.
    // Freeze at the CURRENT animated position while paused, so pausing
    // lets you inspect the view in place — only fall back to the slider's
    // static preview value when playback hasn't started at all. The
    // previous version used `animate` here (running && !paused), which
    // meant pausing snapped straight back to the slider's default value
    // instead of freezing where the orbit actually was.
    const angleDeg = s.isRunning ? ((t.current / ORBIT_PERIOD) * 360) % 360 : s.orbitAngleDeg;
    const angleRad = (angleDeg * Math.PI) / 180;
    const tiltRad = (TILT_DEG * Math.PI) / 180;

    ctx.clearRect(0, 0, W, H);
    ctx.fillStyle = '#0f172a'; ctx.fillRect(0, 0, W, H);
    ctx.fillStyle = 'rgba(255,255,255,0.4)';
    for (let i = 0; i < 40; i++) ctx.fillRect((i * 53) % W, (i * 97) % H, 1, 1);

    const midY = H / 2;
    // Every size scales with the actual canvas dimensions (bigger on a
    // wide desktop canvas, still comfortable on a narrow mobile one)
    // rather than fixed pixel constants — verified numerically to stay
    // within bounds from a small ~340x200 mobile canvas up to a wide
    // ~980x340 desktop one.
    const scale = Math.min(W / 660, H / 320);
    const sunR = 42 * scale;
    const sunX = Math.max(sunR + 15, 55 * scale);
    const earthX = W * 0.66;
    const earthR = 22 * scale;
    // The Moon appears smaller here for an annular eclipse — it really is
    // farther from Earth at these points in its slightly elliptical
    // orbit, so even perfectly aligned it can't fully cover the Sun.
    const moonR = (s.eclipseType === 'annular' ? 7 : 10) * scale;
    const maxOrbitRHorizontal = Math.min(earthX - sunX - sunR - 25, W - earthX - 25);
    const ORBIT_R = Math.max(60 * scale, Math.min(maxOrbitRHorizontal, H * 0.46));

    const moonX = earthX + ORBIT_R * Math.cos(angleRad);
    const moonY = midY + ORBIT_R * Math.sin(angleRad) * Math.sin(tiltRad);

    // Sun
    ctx.fillStyle = '#fbbf24';
    ctx.beginPath(); ctx.arc(sunX, midY, sunR, 0, Math.PI * 2); ctx.fill();
    ctx.fillStyle = '#fde68a'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
    ctx.fillText('Sun', sunX, midY + sunR + 16);

    // The Moon's actual orbital path around Earth — a real, clearly
    // visible ellipse (the projection of its tilted circular orbit), not
    // a decorative loop. This IS the orbit, drawn to scale with the
    // motion below, in both modes.
    ctx.save();
    ctx.strokeStyle = 'rgba(148,163,184,0.55)'; ctx.setLineDash([5, 4]); ctx.lineWidth = 1.3;
    ctx.beginPath();
    ctx.ellipse(earthX, midY, ORBIT_R, ORBIT_R * Math.sin(tiltRad), 0, 0, Math.PI * 2);
    ctx.stroke();
    ctx.restore();
    // The two nodes — where the tilted orbit crosses the Sun-Earth line,
    // the only points where an eclipse can happen.
    ctx.fillStyle = 'rgba(148,163,184,0.8)';
    [earthX - ORBIT_R, earthX + ORBIT_R].forEach(nx => {
      ctx.beginPath(); ctx.arc(nx, midY, 2.5, 0, Math.PI * 2); ctx.fill();
    });

    // Earth is always the target/occluder's fixed reference; the Moon is
    // always the body actually moving. Which one blocks light from the
    // other depends on which side of the orbit the Moon is currently on:
    // solar eclipse needs the Moon between the Sun and Earth; lunar
    // eclipse needs Earth between the Sun and the Moon.
    const isSunSide = s.eclipseType === 'solar' || s.eclipseType === 'annular';
    const occ = isSunSide ? { x: moonX, y: moonY, r: moonR } : { x: earthX, y: midY, r: earthR };
    const target = isSunSide ? { x: earthX, y: midY, r: earthR } : { x: moonX, y: moonY, r: moonR };

    // A ray extrapolated to the target's x is only physically meaningful
    // if the occluder genuinely sits between the Sun and the target —
    // otherwise it's just a line extrapolated the wrong way. This is what
    // correctly restricts eclipses to the Moon's near side (solar) or far
    // side (lunar) of its orbit, not both.
    const validGeometry = occ.x > sunX && target.x > occ.x;

    const srcTop: Vec = { x: sunX, y: midY - sunR }, srcBot: Vec = { x: sunX, y: midY + sunR };
    const occTop: Vec = { x: occ.x, y: occ.y - occ.r }, occBot: Vec = { x: occ.x, y: occ.y + occ.r };
    // Exactly four rays, the classic umbra/penumbra construction: the
    // same-side pair (top-to-top, bottom-to-bottom) marks the true umbra;
    // the opposite-side pair (bottom-to-top, top-to-bottom) marks the
    // penumbra's outer edge — verified by brute-force sampling in the
    // shadows simulation elsewhere in this app. Each ray is drawn all the
    // way from the Sun's edge, touching the occluder's edge, and onward
    // to where it actually lands.
    const drawRay = (from: Vec, throughPoint: Vec, color: string, dashed = false) => {
      const endY = lineAtX(from, throughPoint, target.x);
      ctx.save(); if (dashed) ctx.setLineDash([4, 3]);
      ctx.strokeStyle = color; ctx.lineWidth = 1.4;
      ctx.beginPath(); ctx.moveTo(from.x, from.y); ctx.lineTo(throughPoint.x, throughPoint.y);
      if (validGeometry) ctx.lineTo(target.x, endY);
      ctx.stroke(); ctx.restore();
    };
    drawRay(srcTop, occTop, 'rgba(96,165,250,0.75)');
    drawRay(srcBot, occBot, 'rgba(96,165,250,0.75)');
    drawRay(srcBot, occTop, 'rgba(148,163,184,0.6)', true);
    drawRay(srcTop, occBot, 'rgba(148,163,184,0.6)', true);

    // Earth
    ctx.fillStyle = '#3b82f6';
    ctx.beginPath(); ctx.arc(earthX, midY, earthR, 0, Math.PI * 2); ctx.fill();
    ctx.fillStyle = '#bfdbfe'; ctx.font = 'bold 10px system-ui';
    ctx.fillText('Earth', earthX, midY - earthR - 8);

    // Moon
    ctx.fillStyle = '#cbd5e1';
    ctx.beginPath(); ctx.arc(moonX, moonY, moonR, 0, Math.PI * 2); ctx.fill();
    ctx.fillStyle = '#e2e8f0'; ctx.font = '9px system-ui';
    ctx.fillText('Moon', moonX, moonY - moonR - 6);

    let eclipseState: 'none' | 'partial' | 'total' = 'none';
    // Lifted out of the validGeometry block so the "View from Earth" inset
    // below can reuse the EXACT same umbra/penumbra values the main
    // diagram uses to classify none/partial/total — previously the inset
    // used a completely separate calculation (raw Moon offset, no
    // validGeometry check at all), which could show a near-total-eclipse
    // picture even when the Moon was on the wrong side of its orbit
    // entirely and no eclipse was geometrically possible. Verified this
    // numerically: at the Moon's far-side node, its raw vertical offset is
    // ALSO near zero, so the old inset showed "near alignment" there too.
    let penCenterY = target.y, penRadius = 0, umbCenterY = target.y, umbRadius = 0;
    if (validGeometry) {
      const umbraTopAtTarget = lineAtX(srcTop, occTop, target.x);
      const umbraBotAtTarget = lineAtX(srcBot, occBot, target.x);
      const penTopAtTarget = lineAtX(srcBot, occTop, target.x);
      const penBotAtTarget = lineAtX(srcTop, occBot, target.x);
      // Explicit min/max rather than assuming top<bot — the boundary rays
      // can cross (converge and invert order) well before reaching the
      // target, especially for the smaller annular-eclipse Moon, and the
      // check needs to stay correct either way rather than relying on a
      // specific ray order that only coincidentally holds in some cases.
      const uLo = Math.min(umbraTopAtTarget, umbraBotAtTarget), uHi = Math.max(umbraTopAtTarget, umbraBotAtTarget);
      const pLo = Math.min(penTopAtTarget, penBotAtTarget), pHi = Math.max(penTopAtTarget, penBotAtTarget);
      penCenterY = (pLo + pHi) / 2; penRadius = (pHi - pLo) / 2;
      umbCenterY = (uLo + uHi) / 2; umbRadius = (uHi - uLo) / 2;
      const totalOverlap = uLo < target.y + target.r && uHi > target.y - target.r;
      const partialOverlap = pLo < target.y + target.r && pHi > target.y - target.r;
      eclipseState = totalOverlap ? 'total' : partialOverlap ? 'partial' : 'none';

      // Umbra and penumbra are always concentric (same centre — verified
      // numerically) so they're drawn as concentric circles clipped to
      // Earth's own disc: a genuinely small dark spot (only that part of
      // Earth sees totality) inside a larger, lighter region (partial
      // visibility), with the REST of Earth left its normal colour. A
      // full-width band — the earlier approach — made even a modest
      // vertical overlap look like most of the planet had gone dark,
      // since it stretched edge-to-edge regardless of how narrow the
      // actual umbra was.
      if (eclipseState !== 'none') {
        ctx.save();
        ctx.beginPath(); ctx.arc(target.x, target.y, target.r, 0, Math.PI * 2); ctx.clip();
        ctx.fillStyle = 'rgba(100,116,139,0.55)';
        ctx.beginPath(); ctx.arc(target.x, penCenterY, penRadius, 0, Math.PI * 2); ctx.fill();
        if (eclipseState === 'total') {
          ctx.fillStyle = 'rgba(15,23,42,0.85)';
          ctx.beginPath(); ctx.arc(target.x, umbCenterY, umbRadius, 0, Math.PI * 2); ctx.fill();
        }
        ctx.restore();
      }
    }
    s.onTick?.(angleDeg, eclipseState);

    // "View from Earth" inset — what an observer at Earth's centre would
    // actually see. Derived directly from the SAME penumbra/umbra values
    // just used above (not a separate calculation), so it can never show
    // a state that contradicts the main diagram or the classification.
    const insetX = W - 78, insetY = H - 66, insetR = 30;
    ctx.save();
    ctx.fillStyle = 'rgba(15,23,42,0.9)';
    ctx.beginPath(); ctx.roundRect(insetX - insetR - 10, insetY - insetR - 18, insetR * 2 + 20, insetR * 2 + 30, 8); ctx.fill();
    ctx.strokeStyle = 'rgba(148,163,184,0.4)'; ctx.stroke();
    ctx.fillStyle = '#94a3b8'; ctx.font = 'bold 9px system-ui'; ctx.textAlign = 'center';
    ctx.fillText('View from Earth', insetX, insetY - insetR - 6);
    if (isSunSide) {
      ctx.fillStyle = '#fbbf24';
      ctx.beginPath(); ctx.arc(insetX, insetY, insetR, 0, Math.PI * 2); ctx.fill();
      // Position is only meaningful once we know the classification —
      // deriving it straight from eclipseState (already correctly
      // computed above, including the validGeometry gate) rather than a
      // separately-clamped continuous formula guarantees the inset can
      // never show overlap for a "none" state or separation for a
      // "partial"/"total" one.
      const direction = target.y >= penCenterY ? 1 : -1;
      const normalizedOffset = penRadius > 0.001 ? Math.abs(target.y - penCenterY) / penRadius : 999;
      const offsetFactor = eclipseState === 'none' ? 2.4 : Math.min(1.3, normalizedOffset);
      // A total eclipse's Moon disc is almost exactly the Sun's apparent
      // size (the real "eclipse coincidence"); an annular eclipse's Moon
      // is visibly smaller, so even at perfect alignment a bright ring of
      // the Sun remains round its edge — that ring IS the whole visual
      // definition of an annular eclipse, so it has to actually show here.
      const moonInsetR = s.eclipseType === 'annular' ? insetR * 0.72 : insetR * 0.98;
      ctx.fillStyle = '#0f172a';
      ctx.beginPath(); ctx.arc(insetX, insetY + direction * offsetFactor * insetR, moonInsetR, 0, Math.PI * 2); ctx.fill();
    } else {
      const darkness = eclipseState === 'total' ? 0.75 : eclipseState === 'partial' ? 0.35 : 0.05;
      ctx.fillStyle = '#e2e8f0';
      ctx.beginPath(); ctx.arc(insetX, insetY, insetR, 0, Math.PI * 2); ctx.fill();
      ctx.fillStyle = `rgba(127,29,29,${darkness})`;
      ctx.beginPath(); ctx.arc(insetX, insetY, insetR, 0, Math.PI * 2); ctx.fill();
    }
    ctx.restore();

    ctx.font = 'bold 11px system-ui'; ctx.textAlign = 'center';
    ctx.fillStyle = eclipseState === 'total' ? '#f87171' : eclipseState === 'partial' ? '#fbbf24' : '#94a3b8';
    const bodyLabel = isSunSide ? 'Earth' : 'the Moon';
    const eclipseLabel = eclipseState === 'total'
      ? (s.eclipseType === 'solar' ? '☾ TOTAL SOLAR ECLIPSE — full Sun blocked in a small region of Earth'
        : s.eclipseType === 'annular' ? '☾ ANNULAR ECLIPSE — the Moon is too far away to fully cover the Sun, leaving a ring'
        : `🌍 TOTAL LUNAR ECLIPSE — ${bodyLabel} is fully inside Earth\u2019s umbra`)
      : eclipseState === 'partial'
      ? `PARTIAL ECLIPSE — only part of ${bodyLabel} is in shadow`
      : 'No eclipse right now — the Moon is not at a node';
    ctx.fillText(eclipseLabel, W / 2 - 40, 22);
    ctx.fillStyle = '#64748b'; ctx.font = '9px system-ui'; ctx.textAlign = 'left';
    ctx.fillText('Not to scale. Dashed ellipse = the Moon\u2019s real orbit around Earth; the dots are its two nodes.', 8, H - 8);

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
AFEOF

echo ""
echo "Patch v33 applied -- 1 files written."
echo ""
echo "Next steps:"
echo "  rm -rf .next"
echo "  npm run dev"
echo ""
echo "Check: /simulations/rectilinear-propagation -> Eclipses tab, Solar and"
echo "Annular modes. Press Run and watch the View from Earth inset -- it"
echo "should now show the Sun/Moon discs separated whenever the main label"
echo "says 'No eclipse', and overlapping whenever it says Partial or Total,"
echo "at every point in the orbit, including the far side where the old"
echo "version incorrectly showed near-alignment."
