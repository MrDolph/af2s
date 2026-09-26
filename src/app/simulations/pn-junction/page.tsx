// src/app/simulations/pn-junction/page.tsx
'use client';

import React, { useState, useCallback } from 'react';
import Link from 'next/link';
import PnJunctionCanvas from '@/components/simulation/PnJunctionCanvas';
import { MaterialParams, getPreset, PRESET_NAMES, PRESET_LABELS } from '@/lib/physics/pnJunction';

export default function PnJunctionPage() {
  const [params, setParams] = useState<MaterialParams>(getPreset('equilibrium'));
  const [activePreset, setActivePreset] = useState('equilibrium');

  const applyPreset = useCallback((name: string) => {
    setParams(getPreset(name));
    setActivePreset(name);
  }, []);

  const updateParam = useCallback(<K extends keyof MaterialParams>(key: K, value: MaterialParams[K]) => {
    setParams(prev => ({ ...prev, [key]: value }));
    setActivePreset('custom');
  }, []);

  const isRectifier = params.circuitMode !== 'diode';

  return (
    <div className="min-h-screen bg-slate-950 text-slate-100 flex flex-col">
      <header className="border-b border-slate-800 bg-slate-950/80 backdrop-blur-md sticky top-0 z-50">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 h-16 flex items-center justify-between">
          <div className="flex items-center gap-4">
            <Link href="/simulations" className="text-slate-400 hover:text-slate-200 transition-colors text-sm font-medium">
              ← Simulations
            </Link>
            <span className="text-slate-600">|</span>
            <h1 className="text-lg font-semibold text-slate-100">PN Junction & Rectification</h1>
          </div>
          <div className="flex items-center gap-3">
            <span className="text-xs px-2 py-1 rounded-full bg-blue-500/10 text-blue-400 border border-blue-500/20">Semiconductor Devices</span>
            <span className="text-xs px-2 py-1 rounded-full bg-emerald-500/10 text-emerald-400 border border-emerald-500/20">Live</span>
          </div>
        </div>
      </header>

      <main className="flex-1 p-6">
        <div className="max-w-6xl mx-auto">
          <p className="text-slate-400 mb-6">
            Explore depletion regions, built-in potential, and rectification. Switch between diode analysis 
            and real rectifier circuits with animated AC/DC conversion, current flow, and power calculations.
          </p>

          <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
            <div className="lg:col-span-2">
              <PnJunctionCanvas params={params} width={900} height={600} />
            </div>

            <div className="space-y-4">
              <div className="bg-slate-900 rounded-lg p-4 border border-slate-700">
                <h3 className="font-semibold mb-3 text-sm uppercase tracking-wide text-slate-400">Circuit Mode</h3>
                <div className="grid grid-cols-3 gap-2">
                  {(['diode', 'half-wave', 'full-wave'] as const).map(mode => (
                    <button
                      key={mode}
                      onClick={() => updateParam('circuitMode', mode)}
                      className={`px-2 py-2 rounded text-xs font-medium transition-colors ${
                        params.circuitMode === mode
                          ? 'bg-blue-600 text-white'
                          : 'bg-slate-800 text-slate-300 hover:bg-slate-700'
                      }`}
                    >
                      {mode === 'diode' ? 'Diode' : mode === 'half-wave' ? 'Half-Wave' : 'Full-Wave'}
                    </button>
                  ))}
                </div>
              </div>

              <div className="bg-slate-900 rounded-lg p-4 border border-slate-700">
                <h3 className="font-semibold mb-3 text-sm uppercase tracking-wide text-slate-400">Presets</h3>
                <div className="grid grid-cols-2 gap-2">
                  {PRESET_NAMES.map(name => (
                    <button
                      key={name}
                      onClick={() => applyPreset(name)}
                      className={`px-3 py-2 rounded text-sm font-medium transition-colors ${
                        activePreset === name ? 'bg-blue-600 text-white' : 'bg-slate-800 text-slate-300 hover:bg-slate-700'
                      }`}
                    >
                      {PRESET_LABELS[name]}
                    </button>
                  ))}
                </div>
              </div>

              <div className="bg-slate-900 rounded-lg p-4 border border-slate-700 space-y-4">
                <h3 className="font-semibold text-sm uppercase tracking-wide text-slate-400">Parameters</h3>

                <div>
                  <label className="block text-sm text-slate-400 mb-1">Material</label>
                  <select
                    value={params.material}
                    onChange={e => updateParam('material', e.target.value as MaterialParams['material'])}
                    className="w-full bg-slate-800 border border-slate-600 rounded px-3 py-2 text-sm"
                  >
                    <option value="Si">Silicon (Si) — Vf ≈ 0.7V</option>
                    <option value="Ge">Germanium (Ge) — Vf ≈ 0.3V</option>
                    <option value="GaAs">GaAs — Vf ≈ 1.2V</option>
                  </select>
                </div>

                {!isRectifier && (
                  <>
                    <div>
                      <label className="block text-sm text-slate-400 mb-1">
                        P-side Doping (Na): {params.Na.toExponential(1)} cm⁻³
                      </label>
                      <input type="range" min="14" max="19" step="0.5"
                        value={Math.log10(params.Na)}
                        onChange={e => updateParam('Na', Math.pow(10, parseFloat(e.target.value)))}
                        className="w-full accent-blue-500" />
                    </div>
                    <div>
                      <label className="block text-sm text-slate-400 mb-1">
                        N-side Doping (Nd): {params.Nd.toExponential(1)} cm⁻³
                      </label>
                      <input type="range" min="14" max="19" step="0.5"
                        value={Math.log10(params.Nd)}
                        onChange={e => updateParam('Nd', Math.pow(10, parseFloat(e.target.value)))}
                        className="w-full accent-blue-500" />
                    </div>
                    <div>
                      <label className="block text-sm text-slate-400 mb-1">
                        Applied Bias: {params.appliedBias >= 0 ? '+' : ''}{params.appliedBias.toFixed(2)} V
                      </label>
                      <input type="range" min="-10" max="1" step="0.05"
                        value={params.appliedBias}
                        onChange={e => updateParam('appliedBias', parseFloat(e.target.value))}
                        className="w-full accent-blue-500" />
                    </div>
                  </>
                )}

                {isRectifier && (
                  <>
                    <div>
                      <label className="block text-sm text-slate-400 mb-1">
                        AC Input (Vpeak): {params.Vin} V
                      </label>
                      <input type="range" min="2" max="20" step="0.5"
                        value={params.Vin}
                        onChange={e => updateParam('Vin', parseFloat(e.target.value))}
                        className="w-full accent-blue-500" />
                    </div>
                    <div>
                      <label className="block text-sm text-slate-400 mb-1">
                        Load Resistance: {params.Rload} Ω
                      </label>
                      <input type="range" min="100" max="10000" step="100"
                        value={params.Rload}
                        onChange={e => updateParam('Rload', parseInt(e.target.value))}
                        className="w-full accent-blue-500" />
                    </div>
                    <div>
                      <label className="block text-sm text-slate-400 mb-1">
                        Frequency: {params.freq} Hz
                      </label>
                      <input type="range" min="10" max="100" step="5"
                        value={params.freq}
                        onChange={e => updateParam('freq', parseInt(e.target.value))}
                        className="w-full accent-blue-500" />
                    </div>
                  </>
                )}

                <div>
                  <label className="block text-sm text-slate-400 mb-1">
                    Temperature: {params.temperature} K
                  </label>
                  <input type="range" min="100" max="600" step="10"
                    value={params.temperature}
                    onChange={e => updateParam('temperature', parseInt(e.target.value))}
                    className="w-full accent-blue-500" />
                </div>
              </div>

              <div className="bg-slate-900 rounded-lg p-4 border border-slate-700">
                <h3 className="font-semibold text-sm uppercase tracking-wide text-slate-400 mb-2">Teacher Notes</h3>
                <div className="text-sm text-slate-300 space-y-2">
                  {!isRectifier && params.appliedBias === 0 && (
                    <p><strong>Equilibrium:</strong> At zero bias, diffusion and drift currents balance. The depletion region forms as ionized donors/acceptors create a space charge. Built-in potential Vbi = (kT/q) ln(Na·Nd/ni²).</p>
                  )}
                  {!isRectifier && params.appliedBias > 0 && (
                    <p><strong>Forward Bias:</strong> Reducing the barrier allows majority carriers to diffuse. Current follows Shockley: I = Is(e^(V/nVT) - 1). For Si, significant current flows above ~0.7V.</p>
                  )}
                  {!isRectifier && params.appliedBias < 0 && (
                    <p><strong>Reverse Bias:</strong> Barrier increases, depletion widens. Only minority carriers contribute — tiny saturation current until avalanche breakdown at high reverse voltage.</p>
                  )}
                  {params.circuitMode === 'half-wave' && (
                    <>
                      <p><strong>Half-Wave Rectifier:</strong> Only positive half-cycles pass. One diode + load resistor. Vdc = (Vpeak - Vf)/π. Efficiency ≈ 40.6%. High ripple (121%).</p>
                      <div className="mt-2 p-2 bg-slate-800 rounded border border-slate-700">
                        <p className="text-yellow-400 font-medium text-xs uppercase mb-1">Practice Problem</p>
                        <p className="text-xs">A half-wave rectifier has Vpeak = 10V, Rload = 1kΩ, Si diode. Calculate: (a) DC output voltage, (b) DC load current, (c) PIV rating needed.</p>
                        <p className="text-xs text-slate-500 mt-1">Answers: (a) 2.96V, (b) 2.96mA, (c) 10V</p>
                      </div>
                    </>
                  )}
                  {params.circuitMode === 'full-wave' && (
                    <>
                      <p><strong>Full-Wave Bridge:</strong> 4 diodes conduct both half-cycles. Vdc = 2(Vpeak - Vf)/π. Efficiency ≈ 81.2%. Lower ripple (48%). No center-tapped transformer needed.</p>
                      <div className="mt-2 p-2 bg-slate-800 rounded border border-slate-700">
                        <p className="text-yellow-400 font-medium text-xs uppercase mb-1">Practice Problem</p>
                        <p className="text-xs">A bridge rectifier has Vpeak = 10V, Rload = 1kΩ, Si diodes. Calculate: (a) DC output voltage, (b) Total diode power loss, (c) Efficiency.</p>
                        <p className="text-xs text-slate-500 mt-1">Answers: (a) 5.91V, (b) 16.6mW, (c) ~81%</p>
                      </div>
                    </>
                  )}
                  {params.material !== 'Si' && (
                    <p><strong>Material Effect:</strong> {params.material} has Vf ≈ {params.material === 'Ge' ? '0.3V' : '1.2V'}, affecting rectifier efficiency and output voltage.</p>
                  )}
                </div>
              </div>
            </div>
          </div>
        </div>
      </main>

      <footer className="border-t border-slate-800 bg-slate-950 py-6">
        <div className="max-w-6xl mx-auto px-6 flex flex-col sm:flex-row items-center justify-between gap-4">
          <p className="text-sm text-slate-500">PN Junction Simulation — Semiconductor Physics Engine</p>
          <div className="flex items-center gap-4 text-sm text-slate-500">
            <Link href="/simulations" className="hover:text-slate-300 transition-colors">All Simulations</Link>
            <Link href="/simulations/band-theory" className="hover:text-slate-300 transition-colors">← Band Theory</Link>
            <Link href="/simulations/bjt-transistor" className="hover:text-slate-300 transition-colors">BJT →</Link>
          </div>
        </div>
      </footer>
    </div>
  );
}