'use client';
interface SimulationControlsProps { isRunning: boolean; isPaused: boolean; onRun: () => void; onPause: () => void; onReset: () => void; }
export function SimulationControls({ isRunning, isPaused, onRun, onPause, onReset }: SimulationControlsProps) {
  return (
    <div className="flex items-center gap-2">
      {!isRunning ? (
        <button onClick={onRun} className="flex items-center gap-2 rounded-lg bg-indigo-600 px-5 py-2.5 text-sm font-medium text-white transition hover:bg-indigo-700">
          <svg width="14" height="14" viewBox="0 0 14 14" fill="currentColor"><path d="M3 2.5l8 4.5-8 4.5V2.5z" /></svg>
          Run
        </button>
      ) : (
        <button onClick={onPause} className="flex items-center gap-2 rounded-lg bg-amber-500 px-5 py-2.5 text-sm font-medium text-white transition hover:bg-amber-600">
          <svg width="14" height="14" viewBox="0 0 14 14" fill="currentColor"><rect x="2" y="2" width="4" height="10" rx="1" /><rect x="8" y="2" width="4" height="10" rx="1" /></svg>
          {isPaused ? 'Resume' : 'Pause'}
        </button>
      )}
      <button onClick={onReset} className="flex items-center gap-2 rounded-lg border border-gray-200 bg-white px-5 py-2.5 text-sm font-medium text-gray-600 transition hover:bg-gray-50">
        <svg width="14" height="14" viewBox="0 0 14 14" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round"><path d="M2 7a5 5 0 1 0 1-3H2V2" /></svg>
        Reset
      </button>
    </div>
  );
}
