'use client';
import { useState, useRef, useCallback, useEffect } from 'react';
import { AppHeader } from '@/components/layout/AppHeader';
import { SimulationControls } from '@/components/simulation/SimulationControls';
import { EmbedButton } from '@/components/ui/EmbedButton';
import { UnitCircleCanvas } from '@/components/simulation/UnitCircleCanvas';
import { UnitCircleGraph } from '@/components/simulation/UnitCircleGraph';
import { useResponsiveCanvasSize } from '@/hooks/useResponsiveCanvasSize';
import { deg2rad, rad2deg, quadrantOf, QUADRANT_SIGNS } from '@/lib/physics/unitCircle';

const TEACHER_NOTES = [
  "Every point on the unit circle is (cos θ, sin θ) — that's not a coincidence to memorise, it's the actual definition. Drag the point and watch both coordinates update together.",
  "The yellow line is always the point's x-coordinate (cos θ); the red line is always its y-coordinate (sin θ) — the 'projection' picture is the fastest way to see why sin and cos are just shifted copies of each other (90° out of phase).",
  "The sign of sin θ and cos θ in each quadrant follows directly from which coordinates are positive/negative there — no need to memorise 'CAST' or similar mnemonics if students can see why it's true here.",
  "Degrees and radians are just two different rulers measuring the same rotation — 360° and 2π radians are the same full turn. The toggle lets students build intuition for both before an exam forces a quick conversion.",
  "The two graphs below are literally 'unroll the circle onto a line' — dragging the point around the circle traces out exactly the sine and cosine curves, in real time.",
];

const EXERCISES: { q: string; a: string }[] = [
  { q: 'Convert 150° to radians, giving your answer as a fraction of π.', a: '150° = 150×(π/180) = 5π/6.' },
  { q: 'Convert 7π/4 radians to degrees.', a: '7π/4 × (180/π) = 315°.' },
  { q: 'Which quadrant is 210° in, and what are the signs of sin and cos there?', a: 'Quadrant III (180°–270°): both sin and cos are negative.' },
  { q: 'Using the unit circle, state sin(60°) and cos(60°) exactly (as surds/fractions, not decimals).', a: 'sin(60°) = √3/2, cos(60°) = 1/2.' },
  { q: 'Explain why sin(150°) = sin(30°), using the unit circle picture.', a: '150° and 30° are reflections of each other across the vertical axis — same height (y-coordinate), so the same sine value. Their cosines are opposite in sign instead.' },
  { q: 'A point on the unit circle has cos θ = −0.5 and sin θ is positive. Which quadrant is θ in, and what is θ in degrees?', a: 'Quadrant II (cos negative, sin positive) — θ = 120°.' },
];

export default function UnitCirclePage() {
  const [angleDeg, setAngleDeg] = useState(105.86);
  const [unit, setUnit] = useState<'deg' | 'rad'>('deg');
  const [animating, setAnimating] = useState(false);
  const [openEx, setOpenEx] = useState<number | null>(null);
  const animRef = useRef<number>(0);
  const lastTsRef = useRef<number | null>(null);

  const canvasBoxRef = useRef<HTMLDivElement>(null);
  const canvasSize = useResponsiveCanvasSize(canvasBoxRef, 440, 440, 480);

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
        setAngleDeg(prev => (prev + dt * 60) % 360); // 60°/s — one full turn every 6s
      }
      lastTsRef.current = ts;
      animRef.current = requestAnimationFrame(step);
    };
    animRef.current = requestAnimationFrame(step);
  }, [animating]);

  useEffect(() => () => cancelAnimationFrame(animRef.current), []);

  const rad = deg2rad(angleDeg);
  const sinVal = Math.sin(rad), cosVal = Math.cos(rad);
  const quadrant = quadrantOf(angleDeg);
  const signs = QUADRANT_SIGNS[quadrant];

  const displayValue = unit === 'deg' ? angleDeg.toFixed(2) : rad2deg(angleDeg) === 0 ? '0' : (rad).toFixed(3);
  const sliderMax = unit === 'deg' ? 360 : Math.PI * 2;
  const sliderValue = unit === 'deg' ? angleDeg : rad;
  const handleSliderChange = (v: number) => {
    setAngleDeg(unit === 'deg' ? v : rad2deg(v));
  };

  return (
    <>
      <AppHeader />
      <main className="min-h-screen bg-gray-50">
        <section className="border-b border-gray-200 bg-white">
          <div className="mx-auto max-w-[100rem] px-4 sm:px-6 py-4">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
              <div>
                <p className="text-xs text-gray-400 mb-0.5">Mathematics — Trigonometry</p>
                <h1 className="text-lg font-semibold text-gray-900">Unit Circle Explorer</h1>
              </div>
              <div className="flex gap-2">
                <span className="text-xs px-3 py-1.5 rounded-full font-medium bg-indigo-100 text-indigo-700">
                  θ = {angleDeg.toFixed(2)}°
                </span>
                <span className="text-xs px-3 py-1.5 rounded-full font-medium bg-purple-100 text-purple-700">
                  {rad.toFixed(3)} rad
                </span>
              </div>
            </div>
          </div>
        </section>

        <div className="mx-auto max-w-[100rem] px-4 sm:px-6 py-4 space-y-4">
          <div className="grid grid-cols-1 lg:grid-cols-[1fr_260px] xl:grid-cols-[1fr_260px_300px] gap-4">

            <div className="space-y-3 min-w-0">
              <div ref={canvasBoxRef} className="rounded-2xl border border-gray-200 bg-white p-3 shadow-sm flex justify-center">
                <UnitCircleCanvas angleDeg={angleDeg} onAngleChange={setAngleDeg} width={canvasSize.width} height={canvasSize.height} />
              </div>

              <div className="flex flex-wrap items-center gap-3 rounded-2xl border border-gray-200 bg-white p-3 shadow-sm">
                <SimulationControls
                  isRunning={animating} isPaused={false}
                  onRun={toggleAnimate}
                  onPause={toggleAnimate}
                  onReset={() => { cancelAnimationFrame(animRef.current); setAnimating(false); lastTsRef.current = null; setAngleDeg(0); }}
                />
                <div className="flex rounded-lg border border-gray-200 overflow-hidden text-xs">
                  <button onClick={() => setUnit('deg')}
                    className={`px-3 py-1.5 font-medium transition ${unit === 'deg' ? 'bg-indigo-600 text-white' : 'bg-white text-gray-500'}`}>
                    Degrees
                  </button>
                  <button onClick={() => setUnit('rad')}
                    className={`px-3 py-1.5 font-medium transition ${unit === 'rad' ? 'bg-indigo-600 text-white' : 'bg-white text-gray-500'}`}>
                    Radians
                  </button>
                </div>
                <EmbedButton path="/embed/unit-circle" params={{ angleDeg }} title="Unit Circle Explorer" />
              </div>

              <div className="rounded-2xl border border-gray-200 bg-white p-3 shadow-sm">
                <div className="flex items-center gap-3">
                  <span className="text-xs text-gray-500 shrink-0 w-14">θ ({unit === 'deg' ? '°' : 'rad'})</span>
                  <input type="range" min={0} max={sliderMax} step={sliderMax / 720} value={sliderValue}
                    onChange={e => handleSliderChange(Number(e.target.value))}
                    className="flex-1" style={{ accentColor: '#6366f1' }} />
                  <span className="text-xs font-mono text-gray-500 w-16 text-right">{displayValue}{unit === 'deg' ? '°' : ''}</span>
                </div>
              </div>

              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                <p className="text-xs font-medium text-gray-500 uppercase tracking-wide mb-2">sin θ and cos θ vs angle</p>
                <UnitCircleGraph angleDeg={angleDeg} />
              </div>
            </div>

            <div className="space-y-3">
              <div className="rounded-2xl border border-gray-100 bg-white p-4 space-y-2">
                <p className="text-xs font-medium uppercase tracking-wide text-gray-400 mb-2">Live readout</p>
                {[
                  { l: 'θ (degrees)', v: `${angleDeg.toFixed(2)}°`, c: 'text-indigo-600' },
                  { l: 'θ (radians)', v: `${rad.toFixed(3)} rad`, c: 'text-purple-600' },
                  { l: 'sin θ', v: sinVal.toFixed(3), c: 'text-rose-600' },
                  { l: 'cos θ', v: cosVal.toFixed(3), c: 'text-amber-600' },
                  { l: 'Quadrant', v: `${['', 'I', 'II', 'III', 'IV'][quadrant]}`, c: 'text-gray-700' },
                  { l: 'Signs (sin, cos)', v: `(${signs.sin}, ${signs.cos})`, c: 'text-gray-700' },
                ].map(r => (
                  <div key={r.l} className="flex justify-between items-center rounded-lg bg-gray-50 px-3 py-2">
                    <span className="text-xs text-gray-500">{r.l}</span>
                    <span className={`text-xs font-semibold tabular-nums ${r.c}`}>{r.v}</span>
                  </div>
                ))}
              </div>
              <p className="text-[11px] text-gray-400 px-1">Drag the point around the circle, or use the slider — try Animate for a continuous sweep.</p>
            </div>

            <div className="space-y-3 lg:col-span-2 xl:col-span-1">
              <div className="rounded-2xl border border-amber-100 bg-amber-50 p-4">
                <p className="text-xs font-medium text-amber-700 uppercase tracking-wide mb-3">📋 Teacher notes</p>
                <ul className="space-y-2">
                  {TEACHER_NOTES.map((n, i) => (
                    <li key={i} className="text-xs text-amber-900 leading-relaxed flex gap-2">
                      <span className="text-amber-400 shrink-0 mt-0.5">•</span>{n}
                    </li>
                  ))}
                </ul>
              </div>

              <div className="rounded-2xl border border-gray-200 bg-white p-4">
                <p className="text-xs font-medium text-gray-500 uppercase tracking-wide mb-3">✏️ Exercises</p>
                <div className="space-y-2">
                  {EXERCISES.map((ex, i) => (
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
