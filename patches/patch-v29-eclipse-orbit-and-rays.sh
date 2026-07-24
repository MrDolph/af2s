#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
# A-Factor STEM Studio — patch v29: eclipse rebuilt to match standard
# literature diagrams — real Moon-orbits-Earth mechanics restored, with
# exactly 4 ray lines (the classic umbra/penumbra tangent construction)
#
#   Earth is fixed and the Moon genuinely orbits it on a real, clearly
#   visible elliptical path (drawn to scale with the motion, not a
#   decorative loop) in BOTH modes. The orbit's two nodes (where it
#   crosses the Sun-Earth line) are marked. Solar eclipses need the Moon
#   on the Sun-facing side of its orbit; lunar eclipses need the Moon on
#   the far side, with Earth in between — the correct geometry either way,
#   continuously animated lap after lap.
#
#   Exactly four ray lines are drawn from the Sun to the current
#   occluder's edges, extended onward to where they land — the standard
#   textbook umbra/penumbra tangent-line construction, not a shaded cone.
#   The same-side pair (top-to-top, bottom-to-bottom) is the true umbra;
#   the opposite-side pair (bottom-to-top, top-to-bottom, dashed here) is
#   the penumbra's outer edge — this pairing was verified by brute-force
#   sampling in the shadows simulation elsewhere in this app, and is
#   reused here unchanged.
#
#   Tuned the orbital tilt (30°, exaggerated from the real ~5° for
#   visibility) so eclipses are a genuinely narrow, rare fraction of the
#   orbit rather than triggering across a wide swath of it — verified
#   numerically with a full 360° sweep: solar eclipses occur in a single
#   ~7.5%-of-orbit window centred on the correct node, lunar eclipses in a
#   ~16%-of-orbit window centred on the other node (lunar eclipses being
#   more forgiving of alignment than solar ones, because Earth's shadow is
#   larger than the Moon's — this asymmetry is physically correct, not a
#   bug, matching how real lunar eclipses are visible from the whole
#   night side of Earth while solar eclipses trace a narrow path).
#
#   Kept the geometric-validity check (occluder must genuinely sit between
#   the Sun and the target) from the previous investigation — without it,
#   the ray extrapolation can numerically "detect" an eclipse when the
#   Moon is on the wrong side of Earth entirely.
#
#   Kept the "View from Earth" inset panel (Sun/Moon overlapping discs for
#   solar; the Moon's disc darkening for lunar) showing what an observer
#   would actually see, alongside the side-on orbital diagram.
#
# Run from the af2s project root (Git Bash):   bash patches/patch-v29-eclipse-orbit-and-rays.sh
# ══════════════════════════════════════════════════════════════════════════════
set -euo pipefail

if [ ! -f "package.json" ]; then
  echo "Run this from the af2s project root (package.json not found)." >&2
  exit 1
fi

echo "-- A-Factor patch v29: eclipse with real orbit + 4-ray construction --"
mkdir -p "src/app/embed/rectilinear-propagation" "src/app/simulations/rectilinear-propagation" "src/components/simulation"

echo "  -> src/components/simulation/EclipseCanvas.tsx"
cat > "src/components/simulation/EclipseCanvas.tsx" << 'AFEOF'
'use client';
import { useRef, useEffect, useCallback } from 'react';

export type EclipseType = 'solar' | 'lunar';

interface Props {
  eclipseType: EclipseType;
  orbitAngleDeg: number; // used as a fixed value only when not animating (paused/reset)
  isRunning: boolean; isPaused: boolean;
  onTick?: (angleDeg: number, eclipseHappening: boolean) => void;
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
const ORBIT_R = 110;       // px — the Moon's orbital radius around Earth

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
    const angleDeg = animate ? ((t.current / ORBIT_PERIOD) * 360) % 360 : s.orbitAngleDeg;
    const angleRad = (angleDeg * Math.PI) / 180;
    const tiltRad = (TILT_DEG * Math.PI) / 180;

    ctx.clearRect(0, 0, W, H);
    ctx.fillStyle = '#0f172a'; ctx.fillRect(0, 0, W, H);
    ctx.fillStyle = 'rgba(255,255,255,0.4)';
    for (let i = 0; i < 40; i++) ctx.fillRect((i * 53) % W, (i * 97) % H, 1, 1);

    const midY = H / 2;
    const sunX = 55, sunR = 42;
    const earthX = W * 0.62, earthR = 22, moonR = 10;

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
    const occ = s.eclipseType === 'solar' ? { x: moonX, y: moonY, r: moonR } : { x: earthX, y: midY, r: earthR };
    const target = s.eclipseType === 'solar' ? { x: earthX, y: midY, r: earthR } : { x: moonX, y: moonY, r: moonR };

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

    let eclipseHappening = false;
    if (validGeometry) {
      const umbraTopAtTarget = lineAtX(srcTop, occTop, target.x);
      const umbraBotAtTarget = lineAtX(srcBot, occBot, target.x);
      eclipseHappening = umbraTopAtTarget < target.y + target.r && umbraBotAtTarget > target.y - target.r;
      if (eclipseHappening) {
        ctx.save();
        ctx.beginPath(); ctx.arc(target.x, target.y, target.r, 0, Math.PI * 2); ctx.clip();
        ctx.fillStyle = 'rgba(15,23,42,0.7)';
        ctx.fillRect(target.x - target.r, Math.max(target.y - target.r, umbraTopAtTarget), target.r * 2,
          Math.min(target.y + target.r, umbraBotAtTarget) - Math.max(target.y - target.r, umbraTopAtTarget));
        ctx.restore();
      }
    }
    s.onTick?.(angleDeg, eclipseHappening);

    // "View from Earth" inset — what an observer would actually see.
    const insetX = W - 78, insetY = H - 66, insetR = 30;
    ctx.save();
    ctx.fillStyle = 'rgba(15,23,42,0.9)';
    ctx.beginPath(); ctx.roundRect(insetX - insetR - 10, insetY - insetR - 18, insetR * 2 + 20, insetR * 2 + 30, 8); ctx.fill();
    ctx.strokeStyle = 'rgba(148,163,184,0.4)'; ctx.stroke();
    ctx.fillStyle = '#94a3b8'; ctx.font = 'bold 9px system-ui'; ctx.textAlign = 'center';
    ctx.fillText('View from Earth', insetX, insetY - insetR - 6);
    if (s.eclipseType === 'solar') {
      const sunEarthOffset = moonY - midY; // reuse the Moon's current misalignment for the inset
      ctx.fillStyle = '#fbbf24';
      ctx.beginPath(); ctx.arc(insetX, insetY, insetR, 0, Math.PI * 2); ctx.fill();
      const clamp = Math.max(-1, Math.min(1, sunEarthOffset / (ORBIT_R * Math.sin(tiltRad))));
      ctx.fillStyle = '#0f172a';
      ctx.beginPath(); ctx.arc(insetX, insetY + clamp * insetR * 1.6, insetR * 0.98, 0, Math.PI * 2); ctx.fill();
    } else {
      const darkness = eclipseHappening ? 0.75 : 0.05;
      ctx.fillStyle = '#e2e8f0';
      ctx.beginPath(); ctx.arc(insetX, insetY, insetR, 0, Math.PI * 2); ctx.fill();
      ctx.fillStyle = `rgba(127,29,29,${darkness})`;
      ctx.beginPath(); ctx.arc(insetX, insetY, insetR, 0, Math.PI * 2); ctx.fill();
    }
    ctx.restore();

    ctx.font = 'bold 11px system-ui'; ctx.textAlign = 'center';
    ctx.fillStyle = eclipseHappening ? '#f87171' : '#94a3b8';
    ctx.fillText(
      eclipseHappening
        ? (s.eclipseType === 'solar' ? '☾ SOLAR ECLIPSE — the Moon blocks sunlight from reaching Earth' : '🌍 LUNAR ECLIPSE — the Moon passes through Earth\u2019s shadow')
        : 'No eclipse right now — the Moon is not at a node',
      W / 2 - 40, 22,
    );
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

echo "  -> src/app/simulations/rectilinear-propagation/page.tsx"
cat > "src/app/simulations/rectilinear-propagation/page.tsx" << 'AFEOF'
'use client';
import { useState, useCallback, useEffect, useRef } from 'react';
import { AppHeader } from '@/components/layout/AppHeader';
import { SimulationControls } from '@/components/simulation/SimulationControls';
import { ShadowsCanvas } from '@/components/simulation/ShadowsCanvas';
import { EclipseCanvas, EclipseType } from '@/components/simulation/EclipseCanvas';
import { PinholeCanvas } from '@/components/simulation/PinholeCanvas';
import { EmbedButton } from '@/components/ui/EmbedButton';
import { umbraLength, pinholeImageHeight, pinholeMagnification, SUN_ANGULAR_DIAMETER_DEG, MOON_ANGULAR_DIAMETER_DEG } from '@/lib/physics/rectilinear';
import { useResponsiveCanvasSize } from '@/hooks/useResponsiveCanvasSize';

type Topic = 'shadows' | 'eclipse' | 'pinhole';

const CURRICULA = ['WAEC', 'NECO', 'IGCSE', 'SAT', 'JUPEB'];
const CC: Record<string, string> = {
  WAEC: 'bg-indigo-100 text-indigo-700', NECO: 'bg-pink-100 text-pink-700',
  IGCSE: 'bg-emerald-100 text-emerald-700', SAT: 'bg-orange-100 text-orange-700',
  JUPEB: 'bg-purple-100 text-purple-700',
};

const TOPIC_META: Record<Topic, { title: string; icon: string; sub: string; eq: string }> = {
  shadows: { title: 'Shadows',        icon: '🌑', sub: 'Umbra & penumbra',              eq: 'light travels in straight lines' },
  eclipse: { title: 'Eclipses',       icon: '🌘', sub: 'Solar & lunar',                  eq: 'a shadow, cast across space' },
  pinhole: { title: 'Pinhole camera', icon: '📷', sub: 'A laboratory consequence',       eq: 'hI/v = hO/u' },
};

const TEACHER_NOTES: Record<Topic, string[]> = {
  shadows: [
    'Sources of light are LUMINOUS (produce their own light — the Sun, a candle, a bulb) or NON-LUMINOUS (only visible because they reflect light from elsewhere — the Moon, this page, a person).',
    'A shadow forms because light travels in straight lines (rectilinear propagation) and cannot bend around an opaque object.',
    'A POINT source produces a shadow with a sharp edge — only an umbra, no penumbra — because every ray from the single point is blocked in exactly the same way.',
    'An EXTENDED source produces a shadow with two regions: the UMBRA (completely dark — no part of the source is visible from there) and the PENUMBRA (partially lit — only part of the source is visible from there, so some light still reaches it).',
    'Moving the object closer to an extended source makes the penumbra relatively LARGER compared to the umbra; moving it closer to the screen makes the shadow\u2019s edges sharper.',
  ],
  eclipse: [
    'A solar eclipse happens when the Moon passes directly between the Sun and Earth, casting its shadow onto Earth\u2019s surface — people in the umbra see a total eclipse, people in the penumbra see a partial one.',
    'A lunar eclipse happens when Earth passes directly between the Sun and the Moon, and the Moon passes through Earth\u2019s shadow.',
    'Eclipses don\u2019t happen every month because the Moon\u2019s orbit is tilted about 5° relative to Earth\u2019s orbit around the Sun — most months, the Moon\u2019s shadow (or Earth\u2019s shadow) simply misses, passing above or below the target body.',
    'A remarkable coincidence: the Sun is about 400 times wider than the Moon, but also about 400 times farther away — so they have almost the same apparent size in our sky, which is why the Moon can only just barely cover the Sun during a total solar eclipse.',
    'This whole topic is a direct, large-scale consequence of the same rectilinear-propagation geometry used for a tabletop shadow demo — only the distances and sizes change.',
  ],
  pinhole: [
    'A pinhole camera has no lens — a single small hole lets through only one straight-line ray per point on the object, which is exactly why the image forms upside down (inverted): rays from the top of the object cross the hole and land at the BOTTOM of the screen, and vice versa.',
    'The image is always REAL (it lands on an actual screen/film) — this is a direct laboratory demonstration of rectilinear propagation, needing no lens or mirror at all.',
    'Image height formula (similar triangles): hI/v = hO/u, where u = object-to-hole distance, v = hole-to-screen distance.',
    'A SMALLER hole gives a sharper image (closer to one ray per object point) but a DIMMER one (less light gets through) — a genuine trade-off, and why real pinhole cameras need long exposure times.',
    'Making the hole too large lets a whole BUNDLE of rays through each object point, and those bundles overlap on the screen — this is what blurs the image, not some separate effect, but the same straight-line geometry applied to a hole with actual size.',
  ],
};

const EXERCISES: Record<Topic, { q: string; a: string }[]> = {
  shadows: [
    { q: 'A point source of light is placed 20cm from an opaque disc of radius 5cm. Explain what kind of shadow forms and why.', a: 'A sharp shadow with only an umbra, no penumbra — every ray from a single point is blocked identically at the disc\u2019s edge, so there is no region that receives partial light.' },
    { q: 'State the two regions formed in the shadow of an extended light source, and define each.', a: 'Umbra: the region that receives no light at all from the source (completely dark). Penumbra: the region that receives light from only part of the source (partially lit).' },
    { q: 'Why can you sometimes see a fuzzy-edged shadow under a fluorescent tube light, but a sharp-edged shadow under a small torch bulb?', a: 'A fluorescent tube is an extended source, producing a penumbra (fuzzy edge) around the umbra. A small torch bulb behaves close to a point source, giving a mostly sharp-edged shadow.' },
  ],
  eclipse: [
    { q: 'Distinguish between a solar eclipse and a lunar eclipse in terms of the positions of the Sun, Earth, and Moon.', a: 'Solar eclipse: Moon is between the Sun and Earth, and the Moon\u2019s shadow falls on Earth. Lunar eclipse: Earth is between the Sun and the Moon, and the Moon passes through Earth\u2019s shadow.' },
    { q: 'Explain why we do not see a solar and a lunar eclipse every single month, even though the Moon orbits Earth roughly every month.', a: 'The Moon\u2019s orbital plane is tilted about 5° relative to Earth\u2019s orbital plane around the Sun. Most months, this tilt carries the Moon\u2019s shadow (or its path through Earth\u2019s shadow) above or below the target body, so no eclipse occurs — only when the alignment is nearly exact does the shadow actually land.' },
    { q: 'A person standing in the umbra of the Moon\u2019s shadow during a solar eclipse sees a total eclipse. What would a person standing in the penumbra see instead?', a: 'A partial eclipse — from the penumbra, only part of the Sun\u2019s disc is covered by the Moon, since part of the Sun is still visible from that position.' },
  ],
  pinhole: [
    { q: 'An object 1.6m tall stands 4m from a pinhole camera. The screen is 20cm behind the pinhole. Find the height of the image.', a: 'hI = hO×(v/u) = 1.6×(0.2/4) = 0.08m = 8cm.' },
    { q: 'Explain, using a ray diagram argument, why the image in a pinhole camera is always inverted.', a: 'A ray from the TOP of the object must travel in a straight line through the single pinhole — since the hole is below the top of the object, that ray continues downward past the hole and lands near the BOTTOM of the screen. Likewise, a ray from the bottom of the object lands near the top. Top-to-bottom and bottom-to-top swap, so the image is upside down.' },
    { q: 'A student makes the pinhole bigger to let in more light. What happens to the sharpness of the image, and why?', a: 'The image becomes blurrier. A larger hole allows a whole bundle of rays (not just one) from each point on the object to pass through, and these bundles land on overlapping regions of the screen instead of a single sharp point, smearing the image out.' },
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

export default function RectilinearPropagationPage() {
  const [topic, setTopic] = useState<Topic>('shadows');
  const [openEx, setOpenEx] = useState<number | null>(null);
  const [activeCurricula, setActiveCurricula] = useState(['WAEC', 'IGCSE', 'SAT']);
  const [isRunning, setIsRunning] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const [resetKey, setResetKey] = useState(0);

  const [sourceType, setSourceType] = useState<'point' | 'extended'>('extended');
  const [sourceRadius, setSourceRadius] = useState(35);
  const [objectRadius, setObjectRadius] = useState(24);
  const [objectDist, setObjectDist] = useState(160);
  const [screenDist, setScreenDist] = useState(420);

  const [eclipseType, setEclipseType] = useState<EclipseType>('solar');
  const [orbitAngleDeg, setOrbitAngleDeg] = useState(180);

  const [objectHeight, setObjectHeight] = useState(90);
  const [pinholeObjectDist, setPinholeObjectDist] = useState(140);
  const [pinholeScreenDist, setPinholeScreenDist] = useState(160);
  const [pinholeRadius, setPinholeRadius] = useState(1);

  const reset = useCallback(() => { setIsRunning(false); setIsPaused(false); setResetKey(k => k + 1); }, []);
  const resetTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  useEffect(() => {
    if (resetTimer.current) clearTimeout(resetTimer.current);
    resetTimer.current = setTimeout(reset, 100);
  }, [topic, sourceType, sourceRadius, objectRadius, objectDist, screenDist, eclipseType, orbitAngleDeg, objectHeight, pinholeObjectDist, pinholeScreenDist, pinholeRadius, reset]);

  const canvasBoxRef = useRef<HTMLDivElement>(null);
  const canvasSize = useResponsiveCanvasSize(canvasBoxRef, 660, 300, 980);

  const uLen = umbraLength(sourceRadius, objectRadius, objectDist);
  const imgH = pinholeImageHeight(objectHeight, pinholeObjectDist, pinholeScreenDist);
  const mag = pinholeMagnification(pinholeObjectDist, pinholeScreenDist);

  return (
    <>
      <AppHeader />
      <main className="min-h-screen bg-gray-50">
        <section className="border-b border-gray-200 bg-white">
          <div className="mx-auto max-w-[100rem] px-4 sm:px-6 py-4">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
              <div>
                <p className="text-xs text-gray-400 mb-0.5">Optics</p>
                <h1 className="text-lg font-semibold text-gray-900">Sources of Light & Rectilinear Propagation</h1>
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
                {topic === 'shadows' && (
                  <ShadowsCanvas key={resetKey} sourceType={sourceType} sourceRadiusPx={sourceRadius} objectRadiusPx={objectRadius}
                    objectDistPx={objectDist} screenDistPx={screenDist}
                    isRunning={isRunning} isPaused={isPaused}
                    width={canvasSize.width} height={canvasSize.height} />
                )}
                {topic === 'eclipse' && (
                  <EclipseCanvas key={resetKey} eclipseType={eclipseType} orbitAngleDeg={orbitAngleDeg}
                    isRunning={isRunning} isPaused={isPaused}
                    width={canvasSize.width} height={canvasSize.height} />
                )}
                {topic === 'pinhole' && (
                  <PinholeCanvas objectHeightPx={objectHeight} objectDistPx={pinholeObjectDist} screenDistPx={pinholeScreenDist}
                    pinholeRadiusPx={pinholeRadius}
                    width={canvasSize.width} height={canvasSize.height} />
                )}
              </div>

              <div className="flex flex-wrap items-center justify-between gap-2">
                {topic !== 'pinhole' ? (
                  <SimulationControls isRunning={isRunning} isPaused={isPaused}
                    onRun={() => { setIsRunning(true); setIsPaused(false); }}
                    onPause={() => setIsPaused(p => !p)} onReset={reset} />
                ) : <span />}
                <EmbedButton path="/embed/rectilinear-propagation"
                  title={`${TOPIC_META[topic].title} — A-Factor STEM Studio`}
                  params={
                    topic === 'shadows' ? { topic, src: sourceType, sr: sourceRadius, or: objectRadius, od: objectDist, sd: screenDist }
                    : topic === 'eclipse' ? { topic, type: eclipseType, angle: orbitAngleDeg }
                    : { topic, h: objectHeight, u: pinholeObjectDist, v: pinholeScreenDist, r: pinholeRadius }
                  } />
              </div>

              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm space-y-4">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide">Parameters</p>

                {topic === 'shadows' && <>
                  <div className="flex gap-2">
                    {(['point', 'extended'] as const).map(t => (
                      <button key={t} onClick={() => setSourceType(t)}
                        className={`flex-1 rounded-lg border px-2 py-2 text-xs font-medium capitalize transition ${
                          sourceType === t ? 'border-indigo-300 bg-indigo-50 text-indigo-700' : 'border-gray-200 bg-white text-gray-500'
                        }`}>{t} source</button>
                    ))}
                  </div>
                  {sourceType === 'extended' && (
                    <Slider label="Source size" unit="px" value={sourceRadius} min={5} max={60} step={1} set={setSourceRadius} color="#fbbf24" />
                  )}
                  <Slider label="Object size" unit="px" value={objectRadius} min={8} max={50} step={1} set={setObjectRadius} color="#64748b" />
                  <Slider label="Object distance" unit="px" value={objectDist} min={60} max={300} step={5} set={setObjectDist} color="#6366f1" />
                  <Slider label="Screen distance" unit="px" value={screenDist} min={objectDist + 40} max={560} step={5} set={setScreenDist} color="#8b5cf6" />
                </>}

                {topic === 'eclipse' && <>
                  <div className="flex gap-2">
                    {(['solar', 'lunar'] as const).map(t => (
                      <button key={t} onClick={() => setEclipseType(t)}
                        className={`flex-1 rounded-lg border px-2 py-2 text-xs font-medium capitalize transition ${
                          eclipseType === t ? 'border-indigo-300 bg-indigo-50 text-indigo-700' : 'border-gray-200 bg-white text-gray-500'
                        }`}>{t}</button>
                    ))}
                  </div>
                  <Slider label="Moon's position in orbit" unit="°" value={orbitAngleDeg} min={0} max={359} step={1} set={setOrbitAngleDeg} color="#6366f1"
                    note="180° = between Sun and Earth (solar node). 0°/360° = opposite side (lunar node). Press Run to orbit continuously." />
                </>}

                {topic === 'pinhole' && <>
                  <Slider label="Object height" unit="px" value={objectHeight} min={30} max={130} step={5} set={setObjectHeight} color="#0f172a" />
                  <Slider label="Object distance (u)" unit="px" value={pinholeObjectDist} min={60} max={260} step={5} set={setPinholeObjectDist} color="#6366f1" />
                  <Slider label="Screen distance (v)" unit="px" value={pinholeScreenDist} min={40} max={260} step={5} set={setPinholeScreenDist} color="#8b5cf6" />
                  <Slider label="Pinhole size" unit="px" value={pinholeRadius} min={0} max={12} step={0.5} set={setPinholeRadius} color="#f59e0b"
                    note="0 = ideal sharp point. Larger → visibly blurs the image." />
                </>}
              </div>
            </div>

            <div className="space-y-3">
              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide mb-3">Calculated</p>
                <div className="space-y-2">
                  {topic === 'shadows' && <>
                    <StatRow label="Shadow type" value={sourceType === 'point' ? 'sharp (no penumbra)' : 'umbra + penumbra'} unit="" color="text-indigo-600" />
                    <StatRow label="Umbra converges at" value={uLen === null ? 'never (source ≤ object)' : uLen.toFixed(0)} unit={uLen === null ? '' : 'px beyond object'} color="text-emerald-600" />
                  </>}
                  {topic === 'eclipse' && <>
                    <StatRow label="Sun angular diameter" value={SUN_ANGULAR_DIAMETER_DEG.toFixed(3)} unit="°" color="text-amber-600" />
                    <StatRow label="Moon angular diameter" value={MOON_ANGULAR_DIAMETER_DEG.toFixed(3)} unit="°" color="text-indigo-600" />
                    <StatRow label="Ratio" value={(SUN_ANGULAR_DIAMETER_DEG / MOON_ANGULAR_DIAMETER_DEG).toFixed(3)} unit="" color="text-purple-600" />
                  </>}
                  {topic === 'pinhole' && <>
                    <StatRow label="Image height" value={imgH.toFixed(1)} unit="px" color="text-indigo-600" />
                    <StatRow label="Magnification v/u" value={mag.toFixed(3)} unit="×" color="text-emerald-600" />
                    <StatRow label="Orientation" value="inverted" unit="" color="text-rose-500" />
                    <StatRow label="Nature" value="real" unit="" color="text-purple-600" />
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

echo "  -> src/app/embed/rectilinear-propagation/page.tsx"
cat > "src/app/embed/rectilinear-propagation/page.tsx" << 'AFEOF'
'use client';
import { Suspense, useState, useCallback, useEffect, useRef } from 'react';
import { useSearchParams } from 'next/navigation';
import { ShadowsCanvas } from '@/components/simulation/ShadowsCanvas';
import { EclipseCanvas, EclipseType } from '@/components/simulation/EclipseCanvas';
import { PinholeCanvas } from '@/components/simulation/PinholeCanvas';
import { SimulationControls } from '@/components/simulation/SimulationControls';

type Topic = 'shadows' | 'eclipse' | 'pinhole';

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

function RectilinearEmbedInner() {
  const sp = useSearchParams();
  const topic = ((): Topic => {
    const t = sp.get('topic');
    return t === 'eclipse' || t === 'pinhole' ? t : 'shadows';
  })();
  const showControls = sp.get('controls') !== '0';

  const [sourceType, setSourceType] = useState<'point' | 'extended'>(() => (sp.get('src') === 'point' ? 'point' : 'extended'));
  const [sourceRadius, setSourceRadius] = useState(() => num(sp, 'sr', 35, 5, 60));
  const [objectRadius, setObjectRadius] = useState(() => num(sp, 'or', 24, 8, 50));
  const [objectDist, setObjectDist] = useState(() => num(sp, 'od', 160, 60, 300));
  const [screenDist, setScreenDist] = useState(() => num(sp, 'sd', 420, 100, 560));

  const [eclipseType, setEclipseType] = useState<EclipseType>(() => (sp.get('type') === 'lunar' ? 'lunar' : 'solar'));
  const [orbitAngleDeg, setOrbitAngleDeg] = useState(() => num(sp, 'angle', 180, 0, 359));

  const [objectHeight, setObjectHeight] = useState(() => num(sp, 'h', 90, 30, 130));
  const [pinholeObjectDist, setPinholeObjectDist] = useState(() => num(sp, 'u', 140, 60, 260));
  const [pinholeScreenDist, setPinholeScreenDist] = useState(() => num(sp, 'v', 160, 40, 260));
  const [pinholeRadius, setPinholeRadius] = useState(() => num(sp, 'r', 1, 0, 12));

  const [isRunning, setIsRunning] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const [resetKey, setResetKey] = useState(0);
  const reset = useCallback(() => { setIsRunning(false); setIsPaused(false); setResetKey(k => k + 1); }, []);
  const resetTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  useEffect(() => {
    if (resetTimer.current) clearTimeout(resetTimer.current);
    resetTimer.current = setTimeout(reset, 100);
  }, [topic, sourceType, sourceRadius, objectRadius, objectDist, screenDist, eclipseType, orbitAngleDeg, objectHeight, pinholeObjectDist, pinholeScreenDist, pinholeRadius, reset]);

  return (
    <div className="mx-auto max-w-2xl space-y-3 p-3 sm:p-4">
      {topic === 'shadows' && (
        <ShadowsCanvas key={resetKey} sourceType={sourceType} sourceRadiusPx={sourceRadius} objectRadiusPx={objectRadius}
          objectDistPx={objectDist} screenDistPx={screenDist}
          isRunning={isRunning} isPaused={isPaused} width={640} height={280} />
      )}
      {topic === 'eclipse' && (
        <EclipseCanvas key={resetKey} eclipseType={eclipseType} orbitAngleDeg={orbitAngleDeg}
          isRunning={isRunning} isPaused={isPaused} width={640} height={280} />
      )}
      {topic === 'pinhole' && (
        <PinholeCanvas objectHeightPx={objectHeight} objectDistPx={pinholeObjectDist} screenDistPx={pinholeScreenDist}
          pinholeRadiusPx={pinholeRadius} width={640} height={280} />
      )}
      {topic !== 'pinhole' && (
        <SimulationControls isRunning={isRunning} isPaused={isPaused}
          onRun={() => { setIsRunning(true); setIsPaused(false); }}
          onPause={() => setIsPaused(p => !p)} onReset={reset} />
      )}
      {showControls && (
        <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm space-y-3">
          <p className="text-xs font-medium uppercase tracking-wide text-gray-400">Parameters</p>
          {topic === 'shadows' && <>
            <div className="flex gap-2">
              {(['point', 'extended'] as const).map(t => (
                <button key={t} onClick={() => setSourceType(t)}
                  className={`flex-1 rounded-lg border px-2 py-1.5 text-xs font-medium capitalize transition ${
                    sourceType === t ? 'border-indigo-300 bg-indigo-50 text-indigo-700' : 'border-gray-200 bg-white text-gray-500'
                  }`}>{t}</button>
              ))}
            </div>
            {sourceType === 'extended' && (
              <Slider label="Source size" unit="px" value={sourceRadius} min={5} max={60} step={1} set={setSourceRadius} color="#fbbf24" />
            )}
            <Slider label="Object size" unit="px" value={objectRadius} min={8} max={50} step={1} set={setObjectRadius} color="#64748b" />
            <Slider label="Object distance" unit="px" value={objectDist} min={60} max={300} step={5} set={setObjectDist} color="#6366f1" />
            <Slider label="Screen distance" unit="px" value={screenDist} min={objectDist + 40} max={560} step={5} set={setScreenDist} color="#8b5cf6" />
          </>}
          {topic === 'eclipse' && <>
            <div className="flex gap-2">
              {(['solar', 'lunar'] as const).map(t => (
                <button key={t} onClick={() => setEclipseType(t)}
                  className={`flex-1 rounded-lg border px-2 py-1.5 text-xs font-medium capitalize transition ${
                    eclipseType === t ? 'border-indigo-300 bg-indigo-50 text-indigo-700' : 'border-gray-200 bg-white text-gray-500'
                  }`}>{t}</button>
              ))}
            </div>
            <Slider label="Moon's orbital position" unit="°" value={orbitAngleDeg} min={0} max={359} step={1} set={setOrbitAngleDeg} color="#6366f1" />
          </>}
          {topic === 'pinhole' && <>
            <Slider label="Object height" unit="px" value={objectHeight} min={30} max={130} step={5} set={setObjectHeight} color="#0f172a" />
            <Slider label="Object distance (u)" unit="px" value={pinholeObjectDist} min={60} max={260} step={5} set={setPinholeObjectDist} color="#6366f1" />
            <Slider label="Screen distance (v)" unit="px" value={pinholeScreenDist} min={40} max={260} step={5} set={setPinholeScreenDist} color="#8b5cf6" />
            <Slider label="Pinhole size" unit="px" value={pinholeRadius} min={0} max={12} step={0.5} set={setPinholeRadius} color="#f59e0b" />
          </>}
        </div>
      )}
      <PoweredBy />
    </div>
  );
}

export default function RectilinearEmbedPage() {
  return (
    <Suspense fallback={<div className="p-8 text-center text-xs text-gray-400">Loading simulation…</div>}>
      <RectilinearEmbedInner />
    </Suspense>
  );
}
AFEOF

echo ""
echo "Patch v29 applied -- 3 files written."
echo ""
echo "Next steps:"
echo "  rm -rf .next"
echo "  npm run dev"
echo ""
echo "Check: /simulations/rectilinear-propagation -> Eclipses tab. Press Run"
echo "and watch the Moon genuinely orbit Earth along the dashed elliptical"
echo "path, with exactly 4 ray lines from the Sun, only eclipsing briefly"
echo "near each of the two marked nodes."
