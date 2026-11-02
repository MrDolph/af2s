'use client';
import { SimulationStage } from '@/components/simulation/SimulationStage';

import { Suspense, useState, useRef, useCallback, useEffect } from 'react';
import { useSearchParams } from 'next/navigation';
import { SimulationControls } from '@/components/simulation/SimulationControls';
import '@/components/simulation/unit-circle.css';
import { UnitCircleCanvas } from '@/components/simulation/UnitCircleCanvas';
import { UnitCircleGraph } from '@/components/simulation/UnitCircleGraph';
import { useResponsiveCanvasSize } from '@/hooks/useResponsiveCanvasSize';
import { deg2rad, rad2deg, quadrantOf } from '@/lib/physics/unitCircle';

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
  const thetaText = unit === 'deg' ? `${angleDeg.toFixed(2)}°` : `${rad.toFixed(3)} rad`;
  const sliderMax = unit === 'deg' ? 360 : 2 * Math.PI;
  const sliderValue = unit === 'deg' ? angleDeg : rad;
  const reset = () => { cancelAnimationFrame(animRef.current); setAnimating(false); lastTsRef.current = null; setAngleDeg(num(sp, 'angleDeg', 45, 0, 360)); };

  return (
    <SimulationStage className="af-unit-circle-stage mx-auto max-w-4xl space-y-3 p-3">
      <div data-stage-role="canvas" ref={boxRef} className="flex min-w-0 justify-center rounded-2xl border border-gray-200 bg-white p-3 shadow-sm">
        <UnitCircleCanvas angleDeg={angleDeg} onAngleChange={showControls ? setAngleDeg : () => {}}
          width={size.width} height={size.height} />
      </div>

      {showControls && <div data-stage-role="playback" className="flex flex-wrap items-center gap-3 rounded-2xl border border-gray-200 bg-white p-3 shadow-sm">
        <SimulationControls isRunning={animating} isPaused={false} onRun={toggleAnimate} onPause={toggleAnimate} onReset={reset} />
        <div className="flex overflow-hidden rounded-lg border border-gray-200 text-xs" role="group" aria-label="Angle unit">
          <button onClick={() => setUnit('deg')} aria-pressed={unit==='deg'} className={`px-3 py-2 font-medium ${unit === 'deg' ? 'bg-indigo-600 text-white' : 'bg-white text-gray-600'}`}>Degrees</button>
          <button onClick={() => setUnit('rad')} aria-pressed={unit==='rad'} className={`px-3 py-2 font-medium ${unit === 'rad' ? 'bg-indigo-600 text-white' : 'bg-white text-gray-600'}`}>Radians</button>
        </div>
      </div>}

      {showControls && <div data-stage-role="parameters" className="af-unit-angle rounded-2xl border border-gray-200 bg-white p-3 shadow-sm">
        <div className="flex items-center gap-3">
          <span className="w-14 shrink-0 text-xs text-gray-500">θ ({unit === 'deg' ? '°' : 'rad'})</span>
          <input type="range" min={0} max={sliderMax} step={sliderMax / 720} value={sliderValue}
            onChange={e => setAngleDeg(unit === 'deg' ? Number(e.target.value) : rad2deg(Number(e.target.value)))}
            className="min-w-0 flex-1" style={{accentColor:'#6366f1'}} aria-label={`Angle in ${unit === 'deg' ? 'degrees' : 'radians'}`} />
          <output className="af-unit-angle-output text-right font-mono text-xs text-gray-700">{thetaText}</output>
        </div>
      </div>}

      <div data-stage-role="extra" className="grid grid-cols-2 gap-2 rounded-2xl border border-gray-200 bg-white p-3 text-xs sm:grid-cols-4">
        {[
          { l: 'θ', v: thetaText, c: 'text-indigo-600' },
          { l: 'Quadrant', v: quadrant, c: 'text-gray-700' },
          { l: 'sin θ', v: sinVal.toFixed(3), c: 'text-rose-600' },
          { l: 'cos θ', v: cosVal.toFixed(3), c: 'text-amber-600' },
        ].map(r => <div key={r.l} className="flex justify-between gap-2 rounded-lg bg-gray-50 px-3 py-2"><span className="text-gray-500">{r.l}</span><span className={`font-semibold tabular-nums ${r.c}`}>{r.v}</span></div>)}
      </div>
      {showGraph && <div data-stage-role="extra" className="rounded-2xl border border-gray-200 bg-white p-3"><UnitCircleGraph angleDeg={angleDeg} /></div>}
      <p data-stage-role="extra" className="text-center text-[10px] text-gray-500">A-Factor STEM Studio · Unit circle explorer</p>
    </SimulationStage>
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
