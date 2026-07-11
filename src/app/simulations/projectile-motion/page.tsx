'use client';
import { useState, useCallback } from 'react';
import Link from 'next/link';
import { AppHeader } from '@/components/layout/AppHeader';
import { PromptBar } from '@/components/ai/PromptBar';
import { ProjectileCanvas } from '@/components/simulation/ProjectileCanvas';
import { ProjectileGraph } from '@/components/simulation/ProjectileGraph';
import { SimulationStats } from '@/components/simulation/SimulationStats';
import { SimulationControls } from '@/components/simulation/SimulationControls';
import { ParamControls } from '@/components/simulation/ParamControls';
import type { AIPromptResponse } from '@/types/ai';
import type { ProjectileParams, ProjectileState } from '@/lib/physics/projectile';
import type { GraphDataPoint } from '@/types/simulation';

type GraphType = 'trajectory' | 'height-time' | 'velocity-time';

const CURRICULA = ['WAEC', 'NECO', 'IGCSE', 'SAT', 'JUPEB'];
const CURRICULUM_COLORS: Record<string, string> = {
  WAEC: 'bg-indigo-100 text-indigo-700', NECO: 'bg-pink-100 text-pink-700',
  IGCSE: 'bg-emerald-100 text-emerald-700', SAT: 'bg-orange-100 text-orange-700',
  JUPEB: 'bg-purple-100 text-purple-700',
};

const TEACHER_NOTES = [
  "Projectile motion combines constant horizontal velocity (no air resistance) with vertical free-fall under gravity. These are independent — they don't affect each other.",
  "Maximum range occurs at 45° for a given initial speed. Ask students to verify this by testing 30° vs 45° vs 60° with the same velocity.",
  "Complementary angles (e.g. 30° and 60°) give the same range but different heights and times of flight — great for exam questions.",
  "On the Moon (g ≈ 1.6 m/s²), the same launch gives 6× the range. Use the gravity slider to explore other planets.",
  "The velocity vector decomposes into vx (constant) and vy (decreasing to zero at peak, then increasing downward). Toggle the vector components on the canvas.",
];

const EXERCISES = [
  {
    q: "A ball is launched at 20 m/s at 45°. Calculate its maximum height. (g = 10 m/s²)",
    a: "Max height = v²sin²θ / 2g = (20² × sin²45°) / (2×10) = (400 × 0.5) / 20 = 10 m",
  },
  {
    q: "A projectile has a time of flight of 4 s and is launched at 30°. Find the initial velocity. (g = 10 m/s²)",
    a: "t = 2v sinθ / g → v = gt / 2sinθ = (10×4) / (2×sin30°) = 40 / 1 = 40 m/s",
  },
  {
    q: "At what two angles can a projectile be launched at 30 m/s to hit a target 45 m away? (g = 10 m/s²)",
    a: "R = v²sin2θ / g → sin2θ = Rg/v² = (45×10)/900 = 0.5 → 2θ = 30° or 150° → θ = 15° or 75°",
  },
  {
    q: "Why does horizontal velocity remain constant throughout the flight (ignoring air resistance)?",
    a: "No horizontal force acts on the projectile — Newton's 1st law. Only gravity acts, and it acts vertically.",
  },
  {
    q: "A ball is thrown horizontally at 15 m/s from a cliff 80 m high. How far from the base does it land? (g = 10 m/s²)",
    a: "Time to fall: h = ½gt² → t = √(2h/g) = √16 = 4 s. Range = vx × t = 15 × 4 = 60 m",
  },
];

const REAL_WORLD = [
  { icon: '⚽', text: 'Footballs, basketballs, and cricket balls follow parabolic paths — players intuitively solve projectile equations.' },
  { icon: '🚀', text: 'Rocket artillery and ballistic missiles are calculated using projectile equations adjusted for Earth\'s curvature.' },
  { icon: '🏹', text: 'Archery and javelin athletes choose optimal launch angles — 45° maximises range on flat ground.' },
  { icon: '💧', text: 'Water fountain jets are designed using projectile physics to create specific arc shapes.' },
];

const DEFAULT_PARAMS: ProjectileParams = { initialVelocity: 20, angle: 45, gravity: 9.81, mass: 1 };

export default function ProjectileMotionPage() {
  const [params, setParams] = useState<ProjectileParams>(DEFAULT_PARAMS);
  const [isRunning, setIsRunning] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const [liveState, setLiveState] = useState<ProjectileState | null>(null);
  const [isComplete, setIsComplete] = useState(false);
  const [lastResponse, setLastResponse] = useState<AIPromptResponse | null>(null);
  const [resetKey, setResetKey] = useState(0);
  const [graphType, setGraphType] = useState<GraphType>('trajectory');
  const [openEx, setOpenEx] = useState<number | null>(null);
  const [activeCurricula, setActiveCurricula] = useState(['WAEC', 'IGCSE', 'SAT']);

  const handleAIResult = useCallback((response: AIPromptResponse) => {
    setLastResponse(response);
    if (response.simulationType === 'projectile_motion') {
      const p = response.params as ProjectileParams;
      setParams({
        initialVelocity: Number(p.initialVelocity) || 20,
        angle: Number(p.angle) || 45,
        gravity: Number(p.gravity) || 9.81,
        mass: Number(p.mass) || 1,
      });
    }
    setIsRunning(false); setIsPaused(false);
    setLiveState(null); setIsComplete(false);
    setResetKey(k => k + 1);
  }, []);

  const handleRun = () => { setIsRunning(true); setIsPaused(false); setIsComplete(false); };
  const handlePause = () => setIsPaused(p => !p);
  const handleReset = () => {
    setIsRunning(false); setIsPaused(false);
    setLiveState(null); setIsComplete(false);
    setResetKey(k => k + 1);
  };
  const handleParamChange = (next: ProjectileParams) => {
    setParams(next); setIsRunning(false); setIsPaused(false);
    setLiveState(null); setIsComplete(false);
    setResetKey(k => k + 1);
  };
  const handleTick = useCallback((s: ProjectileState) => setLiveState(s), []);
  const handleComplete = useCallback((_: GraphDataPoint[]) => setIsComplete(true), []);

  const currentSpeed = liveState ? Math.sqrt(liveState.vx ** 2 + liveState.vy ** 2) : 0;
  const toggleC = (c: string) =>
    setActiveCurricula(p => p.includes(c) ? p.filter(x => x !== c) : [...p, c]);

  return (
    <>
      <AppHeader />
      <main className="min-h-screen bg-gray-50">

        {/* Header */}
        <section className="border-b border-gray-200 bg-white">
          <div className="mx-auto max-w-7xl px-4 sm:px-6 py-5">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
              <div>
                <p className="text-xs text-gray-400 mb-1">Mechanics</p>
                <h1 className="text-lg sm:text-xl font-semibold text-gray-900">Projectile motion</h1>
              </div>
              <div className="flex gap-1.5 flex-wrap">
                {CURRICULA.map(c => (
                  <button key={c} onClick={() => toggleC(c)}
                    className={`text-xs px-2.5 py-1 rounded-full border font-medium transition ${
                      activeCurricula.includes(c)
                        ? CURRICULUM_COLORS[c] + ' border-transparent'
                        : 'bg-white text-gray-400 border-gray-200 hover:border-gray-300'
                    }`}>{c}</button>
                ))}
              </div>
            </div>
          </div>
        </section>

        <div className="mx-auto max-w-7xl px-4 sm:px-6 py-5 space-y-4">

          {/* AI prompt */}
          <div className="rounded-2xl border border-gray-200 bg-white p-4 sm:p-5">
            <p className="text-xs font-medium text-gray-400 uppercase tracking-wide mb-3">AI prompt</p>
            <PromptBar onResult={handleAIResult} />
            {lastResponse && (
              <div className="mt-3 rounded-xl bg-indigo-50 px-4 py-3">
                <p className="text-xs font-medium text-indigo-400 mb-0.5">{lastResponse.title}</p>
                <p className="text-xs text-indigo-800 leading-relaxed">{lastResponse.explanation}</p>
              </div>
            )}
          </div>

          {/* Key equation */}
          <div className="flex flex-wrap gap-3">
            {[
              { label: 'Range', eq: 'R = v²sin2θ / g' },
              { label: 'Max height', eq: 'H = v²sin²θ / 2g' },
              { label: 'Time of flight', eq: 'T = 2v sinθ / g' },
            ].map(e => (
              <div key={e.label} className="rounded-xl border border-gray-200 bg-white px-4 py-2.5 flex items-center gap-3">
                <span className="text-xs text-gray-400">{e.label}</span>
                <span className="text-sm font-semibold text-gray-900 font-mono">{e.eq}</span>
              </div>
            ))}
          </div>

          {/* Main layout */}
          <div className="grid grid-cols-1 xl:grid-cols-[1fr_1fr_280px] gap-4">

            {/* Canvas + controls + params */}
            <div className="space-y-3">
              <div className="rounded-2xl border border-gray-200 bg-white p-3 shadow-sm">
                <ProjectileCanvas
                  key={resetKey}
                  params={params}
                  isRunning={isRunning}
                  isPaused={isPaused}
                  onTick={handleTick}
                  onComplete={handleComplete}
                  width={680}
                  height={300}
                />
              </div>
              <div className="flex flex-wrap items-center gap-3 justify-between">
                <SimulationControls
                  isRunning={isRunning && !isComplete}
                  isPaused={isPaused}
                  onRun={handleRun}
                  onPause={handlePause}
                  onReset={handleReset}
                />
                {isComplete && (
                  <span className="text-xs font-medium text-emerald-600">✓ Complete — Reset to go again</span>
                )}
              </div>
              <SimulationStats
                params={params}
                elapsedTime={liveState?.time}
                currentHeight={liveState ? Math.max(0, liveState.y) : undefined}
                currentSpeed={currentSpeed}
              />
              <ParamControls params={params} onChange={handleParamChange} disabled={isRunning && !isComplete} />
            </div>

            {/* Graph panel */}
            <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm space-y-3">
              {/* Graph type tabs */}
              <div className="flex gap-1 bg-gray-100 p-1 rounded-xl">
                {([
                  { key: 'trajectory', label: 'x–y path' },
                  { key: 'height-time', label: 'h–t' },
                  { key: 'velocity-time', label: 'v–t' },
                ] as { key: GraphType; label: string }[]).map(g => (
                  <button key={g.key} onClick={() => setGraphType(g.key)}
                    className={`flex-1 py-1.5 rounded-lg text-xs font-medium transition ${
                      graphType === g.key ? 'bg-white text-indigo-700 shadow-sm' : 'text-gray-500 hover:text-gray-700'
                    }`}>
                    {g.label}
                  </button>
                ))}
              </div>

              <p className="text-xs text-gray-400">
                {graphType === 'trajectory' && 'Parabolic path — horizontal vs vertical displacement. Yellow dot tracks current position.'}
                {graphType === 'height-time' && 'Height over time — rises then falls symmetrically under gravity.'}
                {graphType === 'velocity-time' && '|v| total speed (indigo), vx constant (green), vy decreasing then rising (red).'}
              </p>

              <ProjectileGraph
                params={params}
                graphType={graphType}
                elapsedTime={liveState?.time}
                currentHeight={liveState ? Math.max(0, liveState.y) : 0}
                currentSpeed={currentSpeed}
                currentVx={liveState?.vx ?? 0}
                currentVy={liveState?.vy ?? 0}
              />

              {/* Real world */}
              <div className="rounded-xl border border-indigo-100 bg-indigo-50 p-3 mt-2">
                <p className="text-xs font-medium text-indigo-600 mb-2">Real world</p>
                <ul className="space-y-1.5">
                  {REAL_WORLD.map((r, i) => (
                    <li key={i} className="text-xs text-indigo-800 flex gap-2 leading-relaxed">
                      <span className="shrink-0">{r.icon}</span>{r.text}
                    </li>
                  ))}
                </ul>
              </div>

              {/* Curriculum */}
              <div>
                <p className="text-xs text-gray-400 mb-1.5">Curriculum</p>
                <div className="flex flex-wrap gap-1.5">
                  {CURRICULA.map(c => (
                    <span key={c} className={`text-xs font-medium px-2 py-0.5 rounded-full ${
                      activeCurricula.includes(c) ? CURRICULUM_COLORS[c] : 'bg-gray-100 text-gray-400'
                    }`}>{c}</span>
                  ))}
                </div>
              </div>
            </div>

            {/* Teacher notes + exercises */}
            <div className="space-y-3">
              <div className="rounded-2xl border border-amber-100 bg-amber-50 p-4">
                <p className="text-xs font-medium text-amber-700 uppercase tracking-wide mb-3">📋 Teacher notes</p>
                <ul className="space-y-2.5">
                  {TEACHER_NOTES.map((note, i) => (
                    <li key={i} className="text-xs text-amber-900 leading-relaxed flex gap-2">
                      <span className="text-amber-400 shrink-0 mt-0.5">•</span>{note}
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
                        <span className="text-gray-300 shrink-0 text-base leading-none">{openEx === i ? '▲' : '▼'}</span>
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
