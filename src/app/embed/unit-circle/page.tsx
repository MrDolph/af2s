'use client';
import { Suspense, useState, useRef, useCallback, useEffect } from 'react';
import { useSearchParams } from 'next/navigation';
import { UnitCircleCanvas } from '@/components/simulation/UnitCircleCanvas';
import { UnitCircleGraph } from '@/components/simulation/UnitCircleGraph';
import { useResponsiveCanvasSize } from '@/hooks/useResponsiveCanvasSize';
import { deg2rad, quadrantOf } from '@/lib/physics/unitCircle';

function num(sp: URLSearchParams, key: string, fallback: number, min: number, max: number) {
  const v = Number(sp.get(key));
  return Number.isFinite(v) && sp.get(key) !== null ? Math.min(max, Math.max(min, v)) : fallback;
}

// Supported query params:
//   angleDeg=150   starting angle in degrees (0-360)
//   unit=rad       show the readout in radians instead of degrees
//   graph=0        hide the sin/cos graphs
//   controls=0     lock the embed at the given angle (no dragging, slider or animate) —
//                  handy for worksheets that need to show one specific angle
function UnitCircleEmbedInner() {
  const sp = useSearchParams();
  const showGraph = sp.get('graph') !== '0';
  const showControls = sp.get('controls') !== '0';

  const [angleDeg, setAngleDeg] = useState(() => num(sp, 'angleDeg', 45, 0, 360));
  const [unit, setUnit] = useState<'deg' | 'rad'>(sp.get('unit') === 'rad' ? 'rad' : 'deg');
  const [animating, setAnimating] = useState(false);
  const animRef = useRef<number>(0);
  const lastTsRef = useRef<number | null>(null);

  const boxRef = useRef<HTMLDivElement>(null);
  const size = useResponsiveCanvasSize(boxRef, 420, 420, 420);

  const toggleAnimate = useCallback(() => {
    if (animating) {
      cancelAnimationFrame(animRef.current);
      setAnimating(false);
      lastTsRef.current = null;
      return;
    }
    setAnimating(true);
    const step = (ts: number) => {
      if (lastTsRef.current !== null) {
        const dt = (ts - lastTsRef.current) / 1000;
        setAngleDeg(prev => (prev + dt * 60) % 360);
      }
      lastTsRef.current = ts;
      animRef.current = requestAnimationFrame(step);
    };
    animRef.current = requestAnimationFrame(step);
  }, [animating]);

  useEffect(() => () => cancelAnimationFrame(animRef.current), []);

  const rad = deg2rad(angleDeg);
  const sinVal = Math.sin(rad), cosVal = Math.cos(rad);
  const quadrant = ['', 'I', 'II', 'III', 'IV'][quadrantOf(angleDeg)];
  const thetaText = unit === 'deg' ? `${angleDeg.toFixed(1)}°` : `${rad.toFixed(3)} rad`;

  return (
    <div className="p-3 flex flex-col md:flex-row gap-3">
      <div ref={boxRef} className="md:w-[420px] md:shrink-0 flex justify-center">
        <UnitCircleCanvas
          angleDeg={angleDeg}
          onAngleChange={showControls ? setAngleDeg : () => {}}
          width={size.width}
          height={size.height}
        />
      </div>

      <div className="flex-1 min-w-0 space-y-3">
        <div className="grid grid-cols-2 gap-2 text-xs">
          {[
            { l: 'θ', v: thetaText, c: 'text-indigo-600' },
            { l: 'Quadrant', v: quadrant, c: 'text-gray-700' },
            { l: 'sin θ', v: sinVal.toFixed(3), c: 'text-rose-600' },
            { l: 'cos θ', v: cosVal.toFixed(3), c: 'text-amber-600' },
          ].map(r => (
            <div key={r.l} className="flex justify-between rounded-lg bg-gray-50 px-3 py-2">
              <span className="text-gray-500">{r.l}</span>
              <span className={`font-semibold tabular-nums ${r.c}`}>{r.v}</span>
            </div>
          ))}
        </div>

        {showControls && (
          <div className="flex flex-wrap items-center gap-2">
            <button onClick={toggleAnimate}
              className="text-xs px-3 py-1.5 rounded-lg border border-gray-200 bg-white font-medium text-gray-600 hover:border-indigo-300 transition">
              {animating ? '⏸ Stop' : '▶ Animate'}
            </button>
            <div className="flex rounded-lg border border-gray-200 overflow-hidden text-xs">
              <button onClick={() => setUnit('deg')}
                className={`px-3 py-1.5 font-medium transition ${unit === 'deg' ? 'bg-indigo-600 text-white' : 'bg-white text-gray-500'}`}>Degrees</button>
              <button onClick={() => setUnit('rad')}
                className={`px-3 py-1.5 font-medium transition ${unit === 'rad' ? 'bg-indigo-600 text-white' : 'bg-white text-gray-500'}`}>Radians</button>
            </div>
            <input type="range" min={0} max={360} step={0.5} value={angleDeg}
              onChange={e => setAngleDeg(Number(e.target.value))}
              className="flex-1 min-w-[120px]" style={{ accentColor: '#6366f1' }} aria-label="Angle" />
          </div>
        )}

        {showGraph && <UnitCircleGraph angleDeg={angleDeg} />}

        <p className="text-[10px] text-gray-400">A-Factor STEM Studio · Unit circle explorer</p>
      </div>
    </div>
  );
}

export default function UnitCircleEmbedPage() {
  // useSearchParams() needs a Suspense boundary in the App Router, or the
  // build fails during static prerendering.
  return (
    <Suspense fallback={<div className="p-6 text-sm text-gray-400">Loading…</div>}>
      <UnitCircleEmbedInner />
    </Suspense>
  );
}
