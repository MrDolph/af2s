'use client';
import { useState, useCallback } from 'react';
import { PromptBar } from '@/components/ai/PromptBar';
import { ProjectileCanvas } from '@/components/simulation/ProjectileCanvas';
import { SimulationStats } from '@/components/simulation/SimulationStats';
import { SimulationControls } from '@/components/simulation/SimulationControls';
import { ParamControls } from '@/components/simulation/ParamControls';
import type { AIPromptResponse } from '@/types/ai';
import type { ProjectileParams, ProjectileState } from '@/lib/physics/projectile';
import type { GraphDataPoint } from '@/types/simulation';

const DEFAULT_PARAMS: ProjectileParams = {
  initialVelocity: 20,
  angle: 45,
  gravity: 9.81,
  mass: 1,
};

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
    setIsRunning(false);
    setIsPaused(false);
    setLiveState(null);
    setIsComplete(false);
    setResetKey(k => k + 1);
  }, []);

  const handleRun = () => {
    setIsRunning(true);
    setIsPaused(false);
    setIsComplete(false);
  };

  const handlePause = () => setIsPaused(p => !p);

  // Reset: stop + increment resetKey so canvas knows this is an explicit reset
  const handleReset = () => {
    setIsRunning(false);
    setIsPaused(false);
    setLiveState(null);
    setIsComplete(false);
    setResetKey(k => k + 1);
  };

  const handleParamChange = (next: ProjectileParams) => {
    setParams(next);
    setIsRunning(false);
    setIsPaused(false);
    setLiveState(null);
    setIsComplete(false);
    setResetKey(k => k + 1);
  };

  const handleTick = useCallback((s: ProjectileState) => setLiveState(s), []);

  // Simulation complete — ball STAYS at landing position, no reset
  const handleComplete = useCallback((_: GraphDataPoint[]) => {
    setIsComplete(true);
    // deliberately NOT setting isRunning false here
    // ball stays where it landed until Reset is pressed
  }, []);

  const currentSpeed = liveState
    ? Math.sqrt(liveState.vx ** 2 + liveState.vy ** 2)
    : undefined;

  return (
    <main className="min-h-screen bg-gray-50">
      {/* Header */}
      <header className="border-b border-gray-200 bg-white px-6 py-4">
        <div className="mx-auto flex max-w-6xl items-center justify-between">
          <div>
            <h1 className="text-xl font-semibold text-gray-900">A-Factor</h1>
            <p className="text-xs text-gray-400">STEM Simulation Studio</p>
          </div>
          <span className="rounded-full bg-indigo-50 px-3 py-1 text-xs font-medium text-indigo-600">
            Phase 1 · Projectile motion
          </span>
        </div>
      </header>

      <div className="mx-auto max-w-6xl px-6 py-8 space-y-6">

        {/* AI Prompt bar */}
        <div className="rounded-2xl border border-gray-200 bg-white p-6 shadow-sm">
          <h2 className="mb-1 text-sm font-medium text-gray-900">Describe your simulation</h2>
          <p className="mb-4 text-xs text-gray-400">
            Type in English, Yoruba, Hausa, or Igbo — AI generates simulation parameters instantly.
          </p>
          <PromptBar onResult={handleAIResult} />
        </div>

        {/* AI explanation card */}
        {lastResponse && (
          <div className="rounded-2xl border border-indigo-100 bg-indigo-50 px-6 py-4">
            <p className="text-xs font-medium text-indigo-400 mb-1 uppercase tracking-wide">
              {lastResponse.title}
            </p>
            <p className="text-sm text-indigo-800 leading-relaxed">{lastResponse.explanation}</p>
            {lastResponse.suggestedFollowUps?.length > 0 && (
              <div className="mt-3 flex flex-wrap gap-2">
                {lastResponse.suggestedFollowUps.map(q => (
                  <span key={q} className="rounded-full border border-indigo-200 bg-white px-3 py-1 text-xs text-indigo-600">
                    {q}
                  </span>
                ))}
              </div>
            )}
          </div>
        )}

        {/* Main simulation area */}
        <div className="grid grid-cols-1 gap-6 lg:grid-cols-[1fr_280px]">

          {/* Left: canvas + controls + stats */}
          <div className="space-y-4">
            <ProjectileCanvas
              key={resetKey}
              params={params}
              isRunning={isRunning}
              isPaused={isPaused}
              onTick={handleTick}
              onComplete={handleComplete}
              width={720}
              height={380}
            />

            <div className="flex items-center justify-between">
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

          {/* Right: parameter sliders */}
          <div>
            <ParamControls
              params={params}
              onChange={handleParamChange}
              disabled={isRunning && !isComplete}
            />
          </div>
        </div>
      </div>
    </main>
  );
}