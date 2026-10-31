// src/app/simulations/bjt-transistor/page.tsx
'use client';

import React, { useState, useCallback } from 'react';
import Link from 'next/link';
import BjtCanvas from '@/components/simulation/BjtCanvas';
import { BjtParams, getPreset, PRESET_NAMES, PRESET_LABELS, REGION_DESCRIPTIONS, TOPOLOGY_DESCRIPTIONS } from '@/lib/physics/bjtTransistor';

export default function BjtTransistorPage() {
  const [params, setParams] = useState<BjtParams>(getPreset('ce-active'));
  const [activePreset, setActivePreset] = useState('ce-active');

  const applyPreset = useCallback((name: string) => {
    setParams(getPreset(name));
    setActivePreset(name);
  }, []);

  const updateParam = useCallback(<K extends keyof BjtParams>(key: K, value: BjtParams[K]) => {
    setParams(prev => ({ ...prev, [key]: value }));
    setActivePreset('custom');
  }, []);

  const region = params.Vbe < (params.material === 'Si' ? 0.5 : 0.2) ? 'cutoff' : params.Vbe - params.Vce < 0.3 ? 'active' : 'saturation';

  return (
    <div className="min-h-screen bg-slate-950 text-slate-100 flex flex-col">
      <header className="border-b border-slate-800 bg-slate-950/80 backdrop-blur-md sticky top-0 z-50">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 h-16 flex items-center justify-between">
          <div className="flex items-center gap-4">
            <Link href="/simulations" className="text-slate-400 hover:text-slate-200 transition-colors text-sm font-medium">← Simulations</Link>
            <span className="text-slate-600">|</span>
            <h1 className="text-lg font-semibold text-slate-100">BJT Transistor — Circuit Analysis</h1>
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
            Explore BJT operating regions with real circuit topologies. Analyze Common-Emitter, Common-Collector, 
            and Common-Base amplifiers with load lines, gain calculations, and animated current flow.
          </p>

          <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
            <div className="lg:col-span-2">
              <BjtCanvas params={params} width={900} height={640} />
            </div>

            <div className="space-y-4">
              <div className="bg-slate-900 rounded-lg p-4 border border-slate-700">
                <h3 className="font-semibold mb-3 text-sm uppercase tracking-wide text-slate-400">Circuit Topology</h3>
                <div className="grid grid-cols-3 gap-2">
                  {(['common-emitter', 'common-collector', 'common-base'] as const).map(top => (
                    <button
                      key={top}
                      onClick={() => updateParam('topology', top)}
                      className={`px-2 py-2 rounded text-xs font-medium transition-colors ${
                        params.topology === top ? 'bg-blue-600 text-white' : 'bg-slate-800 text-slate-300 hover:bg-slate-700'
                      }`}
                    >
                      {top === 'common-emitter' ? 'CE' : top === 'common-collector' ? 'CC' : 'CB'}
                    </button>
                  ))}
                </div>
                <p className="text-xs text-slate-500 mt-2">{TOPOLOGY_DESCRIPTIONS[params.topology]}</p>
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
                  <select value={params.material} onChange={e => updateParam('material', e.target.value as BjtParams['material'])}
                    className="w-full bg-slate-800 border border-slate-600 rounded px-3 py-2 text-sm">
                    <option value="Si">Silicon (Vbe ≈ 0.7V)</option>
                    <option value="Ge">Germanium (Vbe ≈ 0.3V)</option>
                  </select>
                </div>

                <div>
                  <label className="block text-sm text-slate-400 mb-1">Supply Voltage (Vcc): {params.Vcc} V</label>
                  <input type="range" min="3" max="20" step="0.5" value={params.Vcc}
                    onChange={e => updateParam('Vcc', parseFloat(e.target.value))}
                    className="w-full accent-blue-500" />
                </div>

                <div>
                  <label className="block text-sm text-slate-400 mb-1">Base-Emitter Voltage (Vbe): {params.Vbe.toFixed(2)} V</label>
                  <input type="range" min="0" max="1.0" step="0.01" value={params.Vbe}
                    onChange={e => updateParam('Vbe', parseFloat(e.target.value))}
                    className="w-full accent-blue-500" />
                </div>

                <div>
                  <label className="block text-sm text-slate-400 mb-1">Collector-Emitter Voltage (Vce): {params.Vce.toFixed(1)} V</label>
                  <input type="range" min="0" max="15" step="0.1" value={params.Vce}
                    onChange={e => updateParam('Vce', parseFloat(e.target.value))}
                    className="w-full accent-blue-500" />
                </div>

                <div>
                  <label className="block text-sm text-slate-400 mb-1">Base Resistor (Rb): {params.Rb} kΩ</label>
                  <input type="range" min="10" max="500" step="10" value={params.Rb}
                    onChange={e => updateParam('Rb', parseInt(e.target.value))}
                    className="w-full accent-blue-500" />
                </div>

                <div>
                  <label className="block text-sm text-slate-400 mb-1">Collector Resistor (Rc): {params.Rc} kΩ</label>
                  <input type="range" min="0.1" max="10" step="0.1" value={params.Rc}
                    onChange={e => updateParam('Rc', parseFloat(e.target.value))}
                    className="w-full accent-blue-500" />
                </div>

                <div>
                  <label className="block text-sm text-slate-400 mb-1">Emitter Resistor (Re): {params.Re} kΩ</label>
                  <input type="range" min="0" max="5" step="0.1" value={params.Re}
                    onChange={e => updateParam('Re', parseFloat(e.target.value))}
                    className="w-full accent-blue-500" />
                </div>

                <div>
                  <label className="block text-sm text-slate-400 mb-1">Load Resistor (Rload): {params.Rload} kΩ</label>
                  <input type="range" min="1" max="50" step="1" value={params.Rload}
                    onChange={e => updateParam('Rload', parseInt(e.target.value))}
                    className="w-full accent-blue-500" />
                </div>

                <div>
                  <label className="block text-sm text-slate-400 mb-1">Current Gain (β): {params.beta}</label>
                  <input type="range" min="20" max="500" step="10" value={params.beta}
                    onChange={e => updateParam('beta', parseInt(e.target.value))}
                    className="w-full accent-blue-500" />
                </div>

                <div>
                  <label className="block text-sm text-slate-400 mb-1">Temperature: {params.temperature} K</label>
                  <input type="range" min="200" max="500" step="10" value={params.temperature}
                    onChange={e => updateParam('temperature', parseInt(e.target.value))}
                    className="w-full accent-blue-500" />
                </div>
              </div>

              <div className="bg-slate-900 rounded-lg p-4 border border-slate-700">
                <h3 className="font-semibold text-sm uppercase tracking-wide text-slate-400 mb-2">Teacher Notes</h3>
                <div className="text-sm text-slate-300 space-y-2">
                  <p className="text-green-400 font-medium">Region: {region.toUpperCase()}</p>
                  <p>{REGION_DESCRIPTIONS[region]}</p>
                  <p className="text-blue-400 font-medium text-xs uppercase mt-2">{params.topology.replace(/-/g, ' ').toUpperCase()} Topology</p>
                  <p className="text-xs">{TOPOLOGY_DESCRIPTIONS[params.topology]}</p>
                  
                  <div className="mt-3 p-2 bg-slate-800 rounded border border-slate-700">
                    <p className="text-yellow-400 font-medium text-xs uppercase mb-1">Practice Problem</p>
                    {params.topology === 'common-emitter' && (
                      <>
                        <p className="text-xs">A CE amplifier has Vcc = 12V, Rc = 2kΩ, Re = 0.5kΩ, β = 100, Vbe = 0.7V. The Q-point is set at Vce = 6V.</p>
                        <p className="text-xs text-slate-500 mt-1">Find: (a) Ib, (b) Ic, (c) Rb needed, (d) Voltage gain with Rload = 10kΩ</p>
                        <p className="text-xs text-slate-400 mt-1">Answers: (a) 28.6μA, (b) 2.86mA, (c) 395kΩ, (d) Av ≈ -238</p>
                      </>
                    )}
                    {params.topology === 'common-collector' && (
                      <>
                        <p className="text-xs">An emitter follower has Vcc = 10V, Re = 2kΩ, β = 100, Vbe = 0.7V. Calculate the output voltage when Vin = 5V.</p>
                        <p className="text-xs text-slate-500 mt-1">Find: (a) Ve, (b) Ie, (c) Voltage gain, (d) Why is this called a "buffer"?</p>
                        <p className="text-xs text-slate-400 mt-1">Answers: (a) 4.3V, (b) 2.15mA, (c) Av ≈ 0.99, (d) High Zin, low Zout — isolates stages</p>
                      </>
                    )}
                    {params.topology === 'common-base' && (
                      <>
                        <p className="text-xs">A CB amplifier has Ie = 2mA, Rc = 3kΩ, α = 0.99. The input resistance is 12.5Ω.</p>
                        <p className="text-xs text-slate-500 mt-1">Find: (a) Ic, (b) Voltage gain, (c) Current gain, (d) Why is input Z so low?</p>
                        <p className="text-xs text-slate-400 mt-1">Answers: (a) 1.98mA, (b) Av ≈ 297, (c) Ai ≈ 0.99, (d) Input at emitter: re = VT/Ie ≈ 12.5Ω</p>
                      </>
                    )}
                  </div>
                  
                  {params.beta > 200 && (
                    <p className="text-xs">High β means small base current controls large collector current — excellent for amplification but watch for thermal runaway.</p>
                  )}
                  {params.material === 'Ge' && (
                    <p className="text-xs">Germanium has lower Vbe (~0.3V) but higher leakage current (Ico doubles every 10°C vs every 6°C for Si).</p>
                  )}
                </div>
              </div>
            </div>
          </div>
        </div>
      </main>

      <footer className="border-t border-slate-800 bg-slate-950 py-6">
        <div className="max-w-6xl mx-auto px-6 flex flex-col sm:flex-row items-center justify-between gap-4">
          <p className="text-sm text-slate-500">BJT Transistor Simulation — Circuit Analysis Engine</p>
          <div className="flex items-center gap-4 text-sm text-slate-500">
            <Link href="/simulations" className="hover:text-slate-300 transition-colors">All Simulations</Link>
            <Link href="/simulations/pn-junction" className="hover:text-slate-300 transition-colors">← PN Junction</Link>
            <Link href="/simulations/mosfet" className="hover:text-slate-300 transition-colors">MOSFET →</Link>
          </div>
        </div>
      </footer>
    </div>
  );
}