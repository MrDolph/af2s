'use client';
import { useState, useCallback, useRef } from 'react';
import Link from 'next/link';
import { AppHeader } from '@/components/layout/AppHeader';
import { PromptBar } from '@/components/ai/PromptBar';
import { ProjectileCanvas } from '@/components/simulation/ProjectileCanvas';
import { SimulationStats } from '@/components/simulation/SimulationStats';
import { SimulationControls } from '@/components/simulation/SimulationControls';
import { ParamControls } from '@/components/simulation/ParamControls';
import type { AIPromptResponse } from '@/types/ai';
import type { ProjectileParams, ProjectileState } from '@/lib/physics/projectile';
import type { GraphDataPoint } from '@/types/simulation';
import { useResponsiveCanvasSize } from '@/hooks/useResponsiveCanvasSize';

const DEFAULT_PARAMS: ProjectileParams = { initialVelocity: 20, angle: 45, gravity: 9.81, mass: 1 };

export default function HomePage() {
  const [params, setParams] = useState<ProjectileParams>(DEFAULT_PARAMS);
  const [isRunning, setIsRunning] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const [liveState, setLiveState] = useState<ProjectileState | null>(null);
  const [isComplete, setIsComplete] = useState(false);
  const [lastResponse, setLastResponse] = useState<AIPromptResponse | null>(null);
  const [resetKey, setResetKey] = useState(0);

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
  const handleComplete = useCallback((_: GraphDataPoint[]) => { setIsComplete(true); }, []);
  const currentSpeed = liveState ? Math.sqrt(liveState.vx ** 2 + liveState.vy ** 2) : undefined;

  const canvasBoxRef = useRef<HTMLDivElement>(null);
  const canvasSize = useResponsiveCanvasSize(canvasBoxRef, 720, 320, 900);

  return (
    <>
      <AppHeader />
      <main className="min-h-screen bg-gray-50">

        {/* Hero prompt section */}
        <section className="border-b border-gray-200 bg-white">
          <div className="mx-auto max-w-[100rem] px-4 sm:px-6 py-6 sm:py-8">
            <div className="mb-1 flex items-center gap-2">
              <span className="rounded-full bg-indigo-50 px-3 py-0.5 text-xs font-medium text-indigo-600">
                Phase 1 · Projectile motion
              </span>
              <Link href="/simulations" className="text-xs text-gray-400 hover:text-indigo-600 transition">
                All simulations →
              </Link>
            </div>
            <h2 className="text-base sm:text-lg font-semibold text-gray-900 mb-1">
              Describe your simulation
            </h2>
            <p className="text-xs text-gray-400 mb-4">
              Type in English, Yoruba, Hausa, or Igbo — AI generates parameters instantly.
            </p>
            <PromptBar onResult={handleAIResult} />
          </div>
        </section>

        <div className="mx-auto max-w-[100rem] px-4 sm:px-6 py-6 space-y-4">

          {/* AI explanation */}
          {lastResponse && (
            <div className="rounded-2xl border border-indigo-100 bg-indigo-50 px-4 sm:px-6 py-4">
              <p className="text-xs font-medium text-indigo-400 mb-1 uppercase tracking-wide">
                {lastResponse.title}
              </p>
              <p className="text-xs sm:text-sm text-indigo-800 leading-relaxed">
                {lastResponse.explanation}
              </p>
              {lastResponse.suggestedFollowUps?.length > 0 && (
                <div className="mt-3 flex flex-wrap gap-2">
                  {lastResponse.suggestedFollowUps.map(q => (
                    <span key={q} className="rounded-full border border-indigo-200 bg-white px-2.5 py-1 text-xs text-indigo-600">
                      {q}
                    </span>
                  ))}
                </div>
              )}
            </div>
          )}

          {/* Main simulation area — stack on mobile, side by side on desktop */}
          <div className="flex flex-col lg:grid lg:grid-cols-[1fr_260px] gap-4">

            {/* Canvas + controls */}
            <div className="space-y-3 min-w-0">
              <div ref={canvasBoxRef}>
                <ProjectileCanvas
                  key={resetKey}
                  params={params}
                  isRunning={isRunning}
                  isPaused={isPaused}
                  onTick={handleTick}
                  onComplete={handleComplete}
                  width={canvasSize.width}
                  height={canvasSize.height}
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
                  <span className="text-xs font-medium text-emerald-600">
                    ✓ Complete — press Reset to go again
                  </span>
                )}
              </div>
              <SimulationStats
                params={params}
                elapsedTime={liveState?.time}
                currentHeight={liveState ? Math.max(0, liveState.y) : undefined}
                currentSpeed={currentSpeed}
              />
            </div>

            {/* Param controls — below canvas on mobile */}
            <div>
              <ParamControls
                params={params}
                onChange={handleParamChange}
                disabled={isRunning && !isComplete}
              />
            </div>
          </div>

          {/* Link to all simulations */}
          <div className="rounded-2xl border border-gray-200 bg-white p-4 sm:p-5 flex flex-col sm:flex-row items-start sm:items-center justify-between gap-3">
            <div>
              <p className="text-sm font-medium text-gray-900 mb-0.5">More simulations</p>
              <p className="text-xs text-gray-400">Gas laws, Newton&apos;s laws, waves, circuits, and more.</p>
            </div>
            <Link href="/simulations"
              className="shrink-0 rounded-xl bg-indigo-600 px-5 py-2.5 text-sm font-medium text-white hover:bg-indigo-700 transition">
              Browse all →
            </Link>
          </div>
        </div>
      </main>
    </>
  );
}
