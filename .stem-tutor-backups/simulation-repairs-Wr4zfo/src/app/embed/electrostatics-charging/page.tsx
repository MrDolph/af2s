'use client';
import { Suspense, useState, useCallback, useEffect, useRef } from 'react';
import { useSearchParams } from 'next/navigation';
import { ChargingMethodsCanvas, ChargingMethod } from '@/components/simulation/ChargingMethodsCanvas';
import { ElectroscopeCanvas, ElectroscopeMode } from '@/components/simulation/ElectroscopeCanvas';
import { ElectrophorusCanvas } from '@/components/simulation/ElectrophorusCanvas';
import { SimulationControls } from '@/components/simulation/SimulationControls';

type Topic = 'production' | 'electroscope' | 'electrophorus';

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

function ElectrostaticsChargingEmbedInner() {
  const sp = useSearchParams();
  const topic = ((): Topic => {
    const t = sp.get('topic');
    return t === 'electroscope' || t === 'electrophorus' ? t : 'production';
  })();
  const showControls = sp.get('controls') !== '0';

  const [method, setMethod] = useState<ChargingMethod>(() => {
    const m = sp.get('method');
    return m === 'conduction' || m === 'induction' ? m : 'friction';
  });
  const [electroscopeMode, setElectroscopeMode] = useState<ElectroscopeMode>(() => (sp.get('mode') === 'testing' ? 'testing' : 'charging'));
  const [rodSign, setRodSign] = useState<1 | -1>(() => (sp.get('rod') === '-1' ? -1 : 1));
  const [electroscopeSign, setElectroscopeSign] = useState<1 | -1>(() => (sp.get('es') === '1' ? 1 : -1));

  const [isRunning, setIsRunning] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const [resetKey, setResetKey] = useState(0);
  const [electrophorusCycle, setElectrophorusCycle] = useState(0);
  const reset = useCallback(() => { setIsRunning(false); setIsPaused(false); setResetKey(k => k + 1); setElectrophorusCycle(0); }, []);
  const resetTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  useEffect(() => {
    if (resetTimer.current) clearTimeout(resetTimer.current);
    resetTimer.current = setTimeout(reset, 100);
  }, [topic, method, electroscopeMode, rodSign, electroscopeSign, reset]);

  return (
    <div className="mx-auto max-w-2xl space-y-3 p-3 sm:p-4">
      {topic === 'production' && (
        <ChargingMethodsCanvas key={resetKey} method={method} rodSign={rodSign} isRunning={isRunning} isPaused={isPaused} width={640} height={300} />
      )}
      {topic === 'electroscope' && (
        <ElectroscopeCanvas key={resetKey} mode={electroscopeMode} rodSign={rodSign} electroscopeSign={electroscopeSign}
          isRunning={isRunning} isPaused={isPaused} width={640} height={300} />
      )}
      {topic === 'electrophorus' && (
        <ElectrophorusCanvas key={resetKey} isRunning={isRunning} isPaused={isPaused}
          cycleCount={electrophorusCycle} onCycleComplete={() => setElectrophorusCycle(c => c + 1)} width={640} height={300} />
      )}
      <SimulationControls isRunning={isRunning} isPaused={isPaused}
        onRun={() => { setIsRunning(true); setIsPaused(false); }}
        onPause={() => setIsPaused(p => !p)} onReset={reset} />
      {showControls && (
        <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm space-y-3">
          <p className="text-xs font-medium uppercase tracking-wide text-gray-400">Parameters</p>
          {topic === 'production' && (
            <div className="flex flex-col gap-2">
              {(['friction', 'conduction', 'induction'] as const).map(m => (
                <button key={m} onClick={() => setMethod(m)}
                  className={`rounded-lg border px-3 py-2 text-xs font-medium capitalize text-left transition ${
                    method === m ? 'border-indigo-300 bg-indigo-50 text-indigo-700' : 'border-gray-200 bg-white text-gray-500'
                  }`}>{m}</button>
              ))}
              {method !== 'friction' && (
                <div className="flex gap-2 pt-1">
                  {([1, -1] as const).map(sgn => (
                    <button key={sgn} onClick={() => setRodSign(sgn)}
                      className={`flex-1 rounded-lg border px-2 py-2 text-xs font-medium transition ${
                        rodSign === sgn ? 'border-indigo-300 bg-indigo-50 text-indigo-700' : 'border-gray-200 bg-white text-gray-500'
                      }`}>Rod: {sgn > 0 ? '+' : '−'}</button>
                  ))}
                </div>
              )}
            </div>
          )}
          {topic === 'electroscope' && <>
            <div className="flex gap-2">
              {(['charging', 'testing'] as const).map(m => (
                <button key={m} onClick={() => setElectroscopeMode(m)}
                  className={`flex-1 rounded-lg border px-2 py-2 text-xs font-medium capitalize transition ${
                    electroscopeMode === m ? 'border-indigo-300 bg-indigo-50 text-indigo-700' : 'border-gray-200 bg-white text-gray-500'
                  }`}>{m}</button>
              ))}
            </div>
            {electroscopeMode === 'testing' && (
              <div className="flex gap-2">
                {([1, -1] as const).map(sgn => (
                  <button key={sgn} onClick={() => setElectroscopeSign(sgn)}
                    className={`flex-1 rounded-lg border px-2 py-2 text-xs font-medium transition ${
                      electroscopeSign === sgn ? 'border-indigo-300 bg-indigo-50 text-indigo-700' : 'border-gray-200 bg-white text-gray-500'
                    }`}>Electroscope: {sgn > 0 ? '+' : '−'}</button>
                ))}
              </div>
            )}
            <div className="flex gap-2">
              {([1, -1] as const).map(sgn => (
                <button key={sgn} onClick={() => setRodSign(sgn)}
                  className={`flex-1 rounded-lg border px-2 py-2 text-xs font-medium transition ${
                    rodSign === sgn ? 'border-indigo-300 bg-indigo-50 text-indigo-700' : 'border-gray-200 bg-white text-gray-500'
                  }`}>Rod: {sgn > 0 ? '+' : '−'}</button>
              ))}
            </div>
          </>}
          {topic === 'electrophorus' && (
            <p className="text-xs text-gray-500">Press Run to lower the disc, earth it, and lift it away.</p>
          )}
        </div>
      )}
      <PoweredBy />
    </div>
  );
}

export default function ElectrostaticsChargingEmbedPage() {
  return (
    <Suspense fallback={<div className="p-8 text-center text-xs text-gray-400">Loading simulation…</div>}>
      <ElectrostaticsChargingEmbedInner />
    </Suspense>
  );
}
