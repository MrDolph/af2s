'use client';
import { useState, useCallback, useRef, useMemo, useEffect } from 'react';
import { AppHeader } from '@/components/layout/AppHeader';
import { SimulationControls } from '@/components/simulation/SimulationControls';
import { AtomicModelsCanvas } from '@/components/simulation/AtomicModelsCanvas';
import { EmbedButton } from '@/components/ui/EmbedButton';
import {
  ATOMIC_PRESETS, AtomicParams, AtomicModel,
  generateHydrogenSpectrum,
  bohrEnergy, bohrRadius, bohrVelocity,
  validQuantumNumbers, possibleLValues, possibleMValues,
  getShellCapacity,
} from '@/lib/physics/atomicModels';

const CC: Record<string, string> = {
  WAEC: 'bg-indigo-100 text-indigo-700',
  NECO: 'bg-pink-100 text-pink-700',
  IGCSE: 'bg-emerald-100 text-emerald-700',
  SAT: 'bg-orange-100 text-orange-700',
  JUPEB: 'bg-purple-100 text-purple-700',
  'A-Level': 'bg-cyan-100 text-cyan-700',
};

const TEACHER_NOTES = [
  'The atomic model evolved over 120 years. Each model corrected fatal flaws in the previous.',
  'Thomson (1897): Discovered the electron. Proposed the "plum pudding" model.',
  'Rutherford (1911): Gold foil experiment proved atom is mostly empty space with a tiny nucleus.',
  'Bohr (1913): Stationary states, quantized angular momentum L = nℏ, photon emission ΔE = hν.',
  'Schrödinger (1926): Wavefunction Ψ gives probability amplitudes. |Ψ|² is probability density.',
];

function Slider({ label, unit, value, min, max, step, set, color, note }: {
  label: string; unit: string; value: number; min: number; max: number; step: number; set: (v: number) => void; color: string; note?: string;
}) {
  return (
    <div className="space-y-1.5">
      <div className="flex justify-between text-xs">
        <span className="text-gray-500">{label}</span>
        <span className="font-medium tabular-nums text-gray-800">{value} <span className="text-gray-400 font-normal">{unit}</span></span>
      </div>
      <input type="range" min={min} max={max} step={step} value={value} onChange={(e) => set(Number(e.target.value))} className="w-full" style={{ accentColor: color }} />
      {note && <p className="text-[10px] text-gray-400">{note}</p>}
    </div>
  );
}

function StatRow({ label, value, unit, color }: { label: string; value: string; unit: string; color: string }) {
  return (
    <div className="flex justify-between items-center rounded-lg bg-gray-50 px-3 py-2">
      <span className="text-xs text-gray-500">{label}</span>
      <span className={`text-xs font-semibold tabular-nums ${color}`}>{value} <span className="text-gray-400 font-normal">{unit}</span></span>
    </div>
  );
}

export default function AtomicModelsPage() {
  const [isRunning, setIsRunning] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const [resetKey, setResetKey] = useState(0);
  const [activeCurricula, setActiveCurricula] = useState(['IGCSE', 'SAT', 'JUPEB', 'A-Level']);
  const [mobileControlsOpen, setMobileControlsOpen] = useState(false);

  const [model, setModel] = useState<AtomicModel>('thomson');
  const [speed, setSpeed] = useState(1);
  const [zoom, setZoom] = useState(1);
  const [showOrbits, setShowOrbits] = useState(true);
  const [showNucleus, setShowNucleus] = useState(true);
  const [showElectrons, setShowElectrons] = useState(true);
  const [showProbability, setShowProbability] = useState(true);
  const [showEnergyLevels, setShowEnergyLevels] = useState(true);
  const [showSpectrum, setShowSpectrum] = useState(true);
  const [showLabels, setShowLabels] = useState(true);
  const [showSpin, setShowSpin] = useState(false);
  const [showFineStructure, setShowFineStructure] = useState(false);
  const [showZeeman, setShowZeeman] = useState(false);
  const [magneticField, setMagneticField] = useState(0);
  const [nQuantum, setNQuantum] = useState(1);
  const [lQuantum, setLQuantum] = useState(0);
  const [mQuantum, setMQuantum] = useState(0);
  const [protonCount, setProtonCount] = useState(1);
  const [neutronCount, setNeutronCount] = useState(0);
  const [electronCount, setElectronCount] = useState(1);
  const [alphaEnergy, setAlphaEnergy] = useState(5);

  const params: AtomicParams = {
    model, speed, zoom, showOrbits, showNucleus, showElectrons, showProbability,
    showEnergyLevels, showSpectrum, showLabels, showSpin, showFineStructure,
    showZeeman, magneticField, nQuantum, lQuantum, mQuantum,
    protonCount, neutronCount, electronCount, alphaEnergy,
  };

  const [liveStats, setLiveStats] = useState({ energy: 0, radius: 0, velocity: 0, n: 1, wavelength: 0, shellConfig: '' });
  const lastTickRef = useRef(0);
  const handleTick = useCallback((stats: typeof liveStats) => {
    const now = performance.now();
    if (now - lastTickRef.current < 80) return;
    lastTickRef.current = now;
    setLiveStats(stats);
  }, []);

  const applyPreset = useCallback((presetIdx: number) => {
    const preset = ATOMIC_PRESETS[presetIdx];
    if (!preset) return;
    setModel(preset.model);
    const pp = preset.params;
    if (pp.speed !== undefined) setSpeed(pp.speed);
    if (pp.zoom !== undefined) setZoom(pp.zoom);
    if (pp.showOrbits !== undefined) setShowOrbits(pp.showOrbits);
    if (pp.showNucleus !== undefined) setShowNucleus(pp.showNucleus);
    if (pp.showElectrons !== undefined) setShowElectrons(pp.showElectrons);
    if (pp.showProbability !== undefined) setShowProbability(pp.showProbability);
    if (pp.showEnergyLevels !== undefined) setShowEnergyLevels(pp.showEnergyLevels);
    if (pp.showSpectrum !== undefined) setShowSpectrum(pp.showSpectrum);
    if (pp.showLabels !== undefined) setShowLabels(pp.showLabels);
    if (pp.showSpin !== undefined) setShowSpin(pp.showSpin);
    if (pp.showFineStructure !== undefined) setShowFineStructure(pp.showFineStructure);
    if (pp.showZeeman !== undefined) setShowZeeman(pp.showZeeman);
    if (pp.magneticField !== undefined) setMagneticField(pp.magneticField);
    if (pp.nQuantum !== undefined) setNQuantum(pp.nQuantum);
    if (pp.lQuantum !== undefined) setLQuantum(pp.lQuantum);
    if (pp.mQuantum !== undefined) setMQuantum(pp.mQuantum);
    if (pp.protonCount !== undefined) setProtonCount(pp.protonCount);
    if (pp.neutronCount !== undefined) setNeutronCount(pp.neutronCount);
    if (pp.electronCount !== undefined) setElectronCount(pp.electronCount);
    if (pp.alphaEnergy !== undefined) setAlphaEnergy(pp.alphaEnergy);
    setIsRunning(false); setIsPaused(false);
    setResetKey(k => k + 1);
    setLiveStats({ energy: 0, radius: 0, velocity: 0, n: 1, wavelength: 0, shellConfig: '' });
  }, []);

  const reset = useCallback(() => {
    setIsRunning(false); setIsPaused(false);
    setResetKey(k => k + 1);
    setLiveStats({ energy: 0, radius: 0, velocity: 0, n: 1, wavelength: 0, shellConfig: '' });
  }, []);

  useEffect(() => {
    if (!validQuantumNumbers(nQuantum, lQuantum, mQuantum)) {
      const validL = possibleLValues(nQuantum);
      if (!validL.includes(lQuantum)) { setLQuantum(validL[0]); setMQuantum(0); }
    }
  }, [nQuantum]);

  useEffect(() => {
    const validM = possibleMValues(lQuantum);
    if (!validM.includes(mQuantum)) setMQuantum(validM[0]);
  }, [lQuantum]);

  const spectrum = useMemo(() => generateHydrogenSpectrum(7), []);
  const modelLabels: Record<AtomicModel, string> = { thomson: 'Thomson (1897)', rutherford: 'Rutherford (1911)', bohr: 'Bohr (1913)', quantum: 'Quantum (1926)' };

  return (
    <>
      <AppHeader />
      <main className="min-h-screen bg-gray-50">
        <section className="border-b border-gray-200 bg-white">
          <div className="mx-auto max-w-[100rem] px-4 sm:px-6 py-4">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
              <div>
                <p className="text-xs text-gray-400 mb-0.5">Atomic Physics — From Plum Pudding to Quantum Field Theory</p>
                <h1 className="text-lg font-semibold text-gray-900">Atomic Models</h1>
              </div>
              <div className="flex gap-1.5 flex-wrap">
                {Object.keys(CC).map(c => (
                  <button key={c} onClick={() => setActiveCurricula(p => p.includes(c) ? p.filter(x => x !== c) : [...p, c])}
                    className={`text-xs px-2.5 py-2 rounded-full border font-medium transition ${activeCurricula.includes(c) ? CC[c] + ' border-transparent' : 'bg-white text-gray-400 border-gray-200'}`}>
                    {c}
                  </button>
                ))}
              </div>
            </div>
          </div>
        </section>

        <div className="mx-auto max-w-[100rem] px-4 sm:px-6 py-4 space-y-4">
          <div className="flex flex-wrap items-center gap-3 rounded-xl border border-gray-200 bg-white px-4 py-2.5">
            <span className="text-xs text-gray-400">Thomson → Rutherford → Bohr → Schrödinger</span>
            <span className="text-sm font-semibold font-mono text-gray-900">Eₙ = -13.6 Z²/n² eV</span>
          </div>

          <div className="flex gap-2 overflow-x-auto pb-1">
            {(['thomson', 'rutherford', 'bohr', 'quantum'] as AtomicModel[]).map(m => (
              <button key={m} onClick={() => { setModel(m); setIsRunning(false); setResetKey(k => k + 1); }}
                className={`shrink-0 rounded-xl border px-4 py-2 text-left hover:shadow-sm transition min-w-[140px] ${model === m ? 'border-indigo-400 bg-indigo-50 text-indigo-700' : 'border-gray-200 bg-white text-gray-600 hover:border-indigo-200'}`}>
                <p className="text-xs font-medium">{modelLabels[m]}</p>
              </button>
            ))}
          </div>

          <div className="flex gap-2 overflow-x-auto pb-1">
            {ATOMIC_PRESETS.map((preset, i) => (
              <button key={i} onClick={() => applyPreset(i)}
                className="shrink-0 rounded-xl border border-gray-200 bg-white px-3 py-2 text-left hover:border-indigo-300 hover:shadow-sm transition min-w-[200px]">
                <p className="text-xs font-medium text-indigo-700">{preset.name}</p>
                <p className="text-[10px] text-gray-400 mt-0.5 leading-relaxed">{preset.description}</p>
              </button>
            ))}
          </div>

          <div className="grid grid-cols-1 lg:grid-cols-[1fr_240px] xl:grid-cols-[1fr_240px_280px] gap-4">
            <div className="space-y-3 min-w-0">
              <div className="rounded-2xl border border-gray-200 bg-white p-3 shadow-sm">
                <AtomicModelsCanvas key={resetKey} params={params} isRunning={isRunning} isPaused={isPaused} onTick={handleTick} />
              </div>

              <div className="flex flex-wrap items-center justify-between gap-2">
                <SimulationControls isRunning={isRunning} isPaused={isPaused}
                  onRun={() => { setIsRunning(true); setIsPaused(false); }}
                  onPause={() => setIsPaused(p => !p)} onReset={reset} />
                <EmbedButton path="/embed/atomic-models" title="Atomic Models"
                  params={{ model, speed, zoom, orbits: showOrbits ? 1 : 0, nucleus: showNucleus ? 1 : 0, electrons: showElectrons ? 1 : 0, prob: showProbability ? 1 : 0, levels: showEnergyLevels ? 1 : 0, spectrum: showSpectrum ? 1 : 0, labels: showLabels ? 1 : 0, spin: showSpin ? 1 : 0, fs: showFineStructure ? 1 : 0, zeeman: showZeeman ? 1 : 0, B: magneticField, n: nQuantum, l: lQuantum, m: mQuantum, Z: protonCount, N: neutronCount, e: electronCount, alphaE: alphaEnergy }} />
              </div>

              {/* Mobile controls toggle */}
              <button onClick={() => setMobileControlsOpen(o => !o)} className="lg:hidden w-full py-2.5 text-sm font-medium rounded-xl border border-gray-200 bg-white text-gray-700 hover:bg-gray-50 transition">
                {mobileControlsOpen ? 'Hide controls ▲' : 'Show controls ▼'}
              </button>

              <div className={`rounded-2xl border border-gray-200 bg-white p-4 shadow-sm space-y-4 ${mobileControlsOpen ? '' : 'hidden lg:block'}`}>
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide">Parameters</p>
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                  <div className="space-y-3">
                    <p className="text-[10px] font-medium text-indigo-600 uppercase tracking-wide">Display</p>
                    <Slider label="Animation speed" unit="×" value={speed} min={0} max={3} step={0.1} set={setSpeed} color="#3b82f6" note="Time evolution speed" />
                    <Slider label="Zoom" unit="×" value={zoom} min={0.3} max={3} step={0.1} set={setZoom} color="#10b981" note="Canvas zoom level" />
                  </div>
                  <div className="space-y-3">
                    <p className="text-[10px] font-medium text-amber-600 uppercase tracking-wide">Nucleus</p>
                    <Slider label="Protons Z" unit="" value={protonCount} min={1} max={92} step={1} set={setProtonCount} color="#fbbf24" note="Atomic number" />
                    <Slider label="Neutrons N" unit="" value={neutronCount} min={0} max={150} step={1} set={setNeutronCount} color="#a78bfa" note="Neutron number" />
                  </div>
                </div>

                {model === 'rutherford' && (
                  <div className="border-t border-gray-100 pt-3">
                    <Slider label="α-particle energy" unit="MeV" value={alphaEnergy} min={1} max={10} step={0.5} set={setAlphaEnergy} color="#f43f5e" note="Kinetic energy of incoming α particles" />
                  </div>
                )}

                {model === 'bohr' && (
                  <div className="border-t border-gray-100 pt-3 space-y-3">
                    <p className="text-[10px] font-medium text-emerald-600 uppercase tracking-wide">Bohr Model Options</p>
                    <div className="flex flex-wrap gap-3">
                      <label className="flex items-center gap-2 text-xs text-gray-600 cursor-pointer"><input type="checkbox" checked={showOrbits} onChange={e => setShowOrbits(e.target.checked)} className="rounded" /> Show orbits</label>
                      <label className="flex items-center gap-2 text-xs text-gray-600 cursor-pointer"><input type="checkbox" checked={showEnergyLevels} onChange={e => setShowEnergyLevels(e.target.checked)} className="rounded" /> Energy levels</label>
                      <label className="flex items-center gap-2 text-xs text-gray-600 cursor-pointer"><input type="checkbox" checked={showSpectrum} onChange={e => setShowSpectrum(e.target.checked)} className="rounded" /> Spectrum bar</label>
                      <label className="flex items-center gap-2 text-xs text-gray-600 cursor-pointer"><input type="checkbox" checked={showSpin} onChange={e => setShowSpin(e.target.checked)} className="rounded" /> Show spin (↑)</label>
                    </div>
                    <div className="flex flex-wrap gap-3">
                      <label className="flex items-center gap-2 text-xs text-gray-600 cursor-pointer"><input type="checkbox" checked={showFineStructure} onChange={e => setShowFineStructure(e.target.checked)} className="rounded" /> Fine structure (j = l ± ½)</label>
                      <label className="flex items-center gap-2 text-xs text-gray-600 cursor-pointer"><input type="checkbox" checked={showZeeman} onChange={e => setShowZeeman(e.target.checked)} className="rounded" /> Zeeman effect</label>
                    </div>
                    {showZeeman && <Slider label="Magnetic field B" unit="T" value={magneticField} min={0} max={5} step={0.1} set={setMagneticField} color="#8b5cf6" note="Tesla — splits degenerate levels" />}
                  </div>
                )}

                {model === 'quantum' && (
                  <div className="border-t border-gray-100 pt-3 space-y-3">
                    <p className="text-[10px] font-medium text-purple-600 uppercase tracking-wide">Quantum Numbers</p>
                    <div className="grid grid-cols-3 gap-3">
                      <Slider label="n" unit="" value={nQuantum} min={1} max={4} step={1} set={setNQuantum} color="#6366f1" note="Principal quantum number" />
                      <Slider label="l" unit="" value={lQuantum} min={0} max={nQuantum - 1} step={1} set={setLQuantum} color="#ec4899" note="Angular momentum (0=s,1=p,2=d,3=f)" />
                      <Slider label="m" unit="" value={mQuantum} min={-lQuantum} max={lQuantum} step={1} set={setMQuantum} color="#10b981" note="Magnetic quantum number" />
                    </div>
                    <p className="text-[10px] text-gray-400">Orbital: <span className="font-medium text-indigo-600">{nQuantum}{['s','p','d','f'][lQuantum] || '?'}</span> — <span className="text-gray-500">{lQuantum === 0 ? 'spherical, no angular nodes' : lQuantum === 1 ? 'dumbbell, 1 angular node' : lQuantum === 2 ? 'cloverleaf, 2 angular nodes' : lQuantum === 3 ? 'complex 8-lobed, 3 angular nodes' : 'higher orbital'}</span></p>
                  </div>
                )}

                <div className="border-t border-gray-100 pt-3">
                  <p className="text-[10px] font-medium text-gray-500 uppercase tracking-wide mb-2">Visibility</p>
                  <div className="flex flex-wrap gap-3">
                    <label className="flex items-center gap-2 text-xs text-gray-600 cursor-pointer"><input type="checkbox" checked={showNucleus} onChange={e => setShowNucleus(e.target.checked)} className="rounded" /> Nucleus</label>
                    <label className="flex items-center gap-2 text-xs text-gray-600 cursor-pointer"><input type="checkbox" checked={showElectrons} onChange={e => setShowElectrons(e.target.checked)} className="rounded" /> Electrons</label>
                    <label className="flex items-center gap-2 text-xs text-gray-600 cursor-pointer"><input type="checkbox" checked={showProbability} onChange={e => setShowProbability(e.target.checked)} className="rounded" /> Probability cloud</label>
                    <label className="flex items-center gap-2 text-xs text-gray-600 cursor-pointer"><input type="checkbox" checked={showLabels} onChange={e => setShowLabels(e.target.checked)} className="rounded" /> Info labels</label>
                  </div>
                </div>
              </div>
            </div>

            <div className="space-y-3">
              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide mb-3">Calculated</p>
                <div className="space-y-2">
                  {model === 'bohr' && (
                    <>
                      <StatRow label="Energy Eₙ" value={liveStats.energy.toFixed(2)} unit="eV" color="text-indigo-600" />
                      <StatRow label="Radius rₙ" value={liveStats.radius.toFixed(2)} unit="a₀" color="text-rose-500" />
                      <StatRow label="Velocity vₙ" value={liveStats.velocity.toFixed(4)} unit="c·α" color="text-emerald-600" />
                      <StatRow label="Quantum n" value={liveStats.n.toString()} unit="" color="text-blue-500" />
                      {liveStats.wavelength > 0 && <StatRow label="λ (transition)" value={liveStats.wavelength.toFixed(1)} unit="nm" color="text-amber-600" />}
                      {showFineStructure && <StatRow label="Fine split" value="~10⁻⁴" unit="eV" color="text-purple-600" />}
                      {showZeeman && magneticField > 0 && <StatRow label="Zeeman ΔE" value={(magneticField * 5.788e-5 * 1e6).toFixed(2)} unit="μeV" color="text-pink-500" />}
                    </>
                  )}
                  {model === 'quantum' && (
                    <>
                      <StatRow label="Energy Eₙ" value={bohrEnergy(nQuantum, protonCount).toFixed(2)} unit="eV" color="text-indigo-600" />
                      <StatRow label="Bohr radius" value={bohrRadius(nQuantum, protonCount).toFixed(2)} unit="a₀" color="text-rose-500" />
                      <StatRow label="Degeneracy" value={(nQuantum * nQuantum).toString()} unit="states" color="text-purple-600" />
                      <StatRow label="Orbital" value={`${nQuantum}${['s','p','d','f'][lQuantum] || '?'}`} unit="" color="text-emerald-600" />
                      <StatRow label="Angular nodes" value={lQuantum.toString()} unit="" color="text-amber-600" />
                      <StatRow label="Radial nodes" value={(nQuantum - lQuantum - 1).toString()} unit="" color="text-blue-500" />
                    </>
                  )}
                  {model === 'thomson' && (
                    <>
                      <StatRow label="Electrons" value={electronCount.toString()} unit="" color="text-blue-500" />
                      <StatRow label="Protons" value={protonCount.toString()} unit="" color="text-amber-600" />
                      <StatRow label="Net charge" value="0" unit="e" color="text-emerald-600" />
                    </>
                  )}
                  {model === 'rutherford' && (
                    <>
                      <StatRow label="Nucleus Z" value={protonCount.toString()} unit="" color="text-amber-600" />
                      <StatRow label="Mass number A" value={(protonCount + neutronCount).toString()} unit="" color="text-rose-500" />
                      <StatRow label="α energy" value={alphaEnergy.toFixed(1)} unit="MeV" color="text-rose-500" />
                      <StatRow label="Nuclear radius" value={(1.2 * Math.pow(protonCount + neutronCount, 1/3)).toFixed(2)} unit="fm" color="text-purple-600" />
                    </>
                  )}
                </div>
              </div>

              {model === 'bohr' && (
                <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                  <p className="text-xs font-medium text-gray-400 uppercase tracking-wide mb-2">Hydrogen Spectrum</p>
                  <div className="space-y-1">
                    {spectrum.slice(0, 10).map((line, i) => (
                      <div key={i} className="flex items-center gap-2 text-[10px]">
                        <div className="w-3 h-3 rounded-full shrink-0" style={{ backgroundColor: line.color }} />
                        <span className="text-gray-500 w-16">{line.series}</span>
                        <span className="font-mono text-gray-700">{line.wavelength.toFixed(0)} nm</span>
                        <span className="text-gray-400">({line.fromN}→{line.toN})</span>
                      </div>
                    ))}
                  </div>
                </div>
              )}

              <div className="rounded-2xl border border-gray-100 bg-white p-4">
                <p className="text-xs text-gray-400 mb-2">Curriculum</p>
                <div className="flex flex-wrap gap-1.5">
                  {Object.keys(CC).map(c => <span key={c} className={`text-xs font-medium px-2 py-0.5 rounded-full ${activeCurricula.includes(c) ? CC[c] : 'bg-gray-100 text-gray-400'}`}>{c}</span>)}
                </div>
              </div>
            </div>

            <div className="space-y-3 lg:col-span-2 xl:col-span-1">
              <div className="rounded-2xl border border-amber-100 bg-amber-50 p-4">
                <p className="text-xs font-medium text-amber-700 uppercase tracking-wide mb-3">Teacher notes</p>
                <ul className="space-y-2">
                  {TEACHER_NOTES.map((n, i) => (
                    <li key={i} className="text-xs text-amber-900 leading-relaxed flex gap-2"><span className="text-amber-400 shrink-0 mt-0.5">•</span>{n}</li>
                  ))}
                </ul>
              </div>
            </div>
          </div>
        </div>
      </main>
    </>
  );
}
