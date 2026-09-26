'use client';
import { useState, useCallback, useRef, useMemo } from 'react';
import { AppHeader } from '@/components/layout/AppHeader';
import { SimulationControls } from '@/components/simulation/SimulationControls';
import { BandTheoryCanvas } from '@/components/simulation/BandTheoryCanvas';
import { EmbedButton } from '@/components/ui/EmbedButton';
import { useResponsiveCanvasSize } from '@/hooks/useResponsiveCanvasSize';
import {
  BAND_PRESETS, BandTheoryParams, MaterialType, DopingType,
  MATERIALS, kT_eV, intrinsicConcentration, dopedFermiLevel,
  materialTypeLabel, getConductivityDescription,
  type BandTheoryStats,
} from '@/lib/physics/bandTheory';

const CURRICULA = ['WAEC', 'NECO', 'IGCSE', 'SAT', 'JUPEB', 'A-Level', 'Undergrad'];
const CC: Record<string, string> = {
  WAEC: 'bg-indigo-100 text-indigo-700',
  NECO: 'bg-pink-100 text-pink-700',
  IGCSE: 'bg-emerald-100 text-emerald-700',
  SAT: 'bg-orange-100 text-orange-700',
  JUPEB: 'bg-purple-100 text-purple-700',
  'A-Level': 'bg-cyan-100 text-cyan-700',
  Undergrad: 'bg-rose-100 text-rose-700',
};

const SCENARIO_NOTES: Record<MaterialType, { title: string; bullets: string[] }> = {
  insulator: {
    title: 'Insulators — Forbidden Gap Blocks All Conduction',
    bullets: [
      'The band gap Eg > 3 eV is so large that thermal energy at room temperature (kT ≈ 0.025 eV) cannot excite electrons from the valence band to the conduction band.',
      'At T = 0 K, the valence band is completely full and the conduction band completely empty. The Fermi level sits near the middle of the gap.',
      'Even at 1000 K, kT ≈ 0.086 eV is still far smaller than Eg for diamond (5.5 eV). Insulators remain non-conductive across all practical temperatures.',
      'The filled valence band cannot carry current because for every electron moving right, another moves left — net current is zero. No empty states exist for acceleration.',
      'Applications: electrical isolation, substrate materials, optical windows (transparent because photons with E < Eg cannot be absorbed).',
    ],
  },
  semiconductor: {
    title: 'Semiconductors — The Tunable Middle Ground',
    bullets: [
      'The band gap Eg ≈ 0.5–2 eV is small enough that thermal excitation creates a measurable number of electron-hole pairs at room temperature, but large enough that conductivity is controllable.',
      'Intrinsic semiconductors: ni = √(NcNv) exp(−Eg/2kT). For Si at 300 K, ni ≈ 1.5×10¹⁰ cm⁻³ — tiny compared to metals (~10²² cm⁻³), but enough for electronics.',
      'Doping introduces donor (n-type) or acceptor (p-type) impurities at ~10¹⁵–10¹⁹ cm⁻³, overwhelming intrinsic carriers and shifting the Fermi level toward Ec or Ev.',
      'The Fermi level is the energy at which the probability of occupation is 50%. In n-type material it rises toward Ec; in p-type it falls toward Ev.',
      'Temperature dependence: at low T, carriers freeze out onto dopants. At moderate T, extrinsic conduction dominates. At high T, intrinsic carriers dominate again — this limits device operating temperatures.',
    ],
  },
  conductor: {
    title: 'Conductors — Overlapping Bands Create Free Electrons',
    bullets: [
      'In metals, the valence and conduction bands overlap (Eg = 0). There is no forbidden gap — electrons are always free to move and accelerate under an electric field.',
      'The Fermi level lies inside the conduction band. Even at absolute zero, states above Ef are available for conduction. This is why metals conduct at all temperatures.',
      'Electron concentration is enormous: ~10²² cm⁻³, roughly one free electron per atom. This is 10¹² times higher than intrinsic silicon.',
      'Resistance in metals arises from electron-phonon and electron-impurity scattering, not from a lack of carriers. As T increases, phonon scattering increases → resistance rises.',
      'The Drude model (classical) and Sommerfeld model (quantum) both explain metallic conduction, but only the quantum model correctly predicts specific heat and the Wiedemann-Franz law.',
    ],
  },
};

const GENERAL_NOTES = [
  'Energy bands arise from the periodic potential of the crystal lattice. The Schrödinger equation in a periodic potential (Kronig-Penney model) produces allowed energy bands separated by forbidden gaps.',
  'The Pauli exclusion principle prevents electrons from occupying the same quantum state. A filled band cannot conduct because there are no adjacent empty states for electrons to move into.',
  'The Fermi-Dirac distribution f(E) = 1/(exp((E−Ef)/kT) + 1) gives the probability that a state at energy E is occupied. At T = 0, it is a step function; at T > 0, the step smooths over ~kT.',
  'Direct bandgap (GaAs): the conduction band minimum and valence band maximum occur at the same k-point. An electron can drop directly, emitting a photon — ideal for LEDs and lasers.',
  'Indirect bandgap (Si, Ge): the band edges occur at different k-points. Recombination requires a phonon to conserve momentum, making photon emission far less efficient.',
  'The density of states g(E) ∝ √(E−Ec) in the conduction band and ∝ √(Ev−E) in the valence band. This parabolic shape arises from the free-electron-like dispersion near band edges.',
];

const EXERCISES = [
  {
    q: 'Set material to Diamond (insulator) at 300 K. How many electrons do you see in the conduction band? Why? Calculate the approximate number per cm³.',
    a: 'Virtually zero electrons in the conduction band. For Eg = 5.5 eV and kT = 0.025 eV, ni ≈ √(NcNv) exp(−5.5/0.05) ≈ 10¹⁹ × exp(−110) ≈ 10⁻²⁹ cm⁻³. Essentially none. The probability of thermal excitation across the gap is astronomically small.',
  },
  {
    q: 'Switch to Silicon (semiconductor). Increase temperature from 300 K to 600 K. What happens to the number of conduction electrons? By what factor does ni increase?',
    a: 'ni doubles roughly every 10 K for Si near room temperature, but the exact factor from 300→600 K is ~10⁶ (from ~10¹⁰ to ~10¹⁶ cm⁻³). The exponential term exp(−Eg/2kT) dominates. At 600 K, silicon becomes significantly conductive — this is why high-temperature electronics use wide-bandgap materials like SiC.',
  },
  {
    q: 'Set Silicon to n-type with doping 10¹⁶ cm⁻³. Where does the Fermi level move? What happens to electron and hole concentrations?',
    a: 'The Fermi level shifts up toward the conduction band: Ef ≈ Ec − kT ln(Nc/Nd) ≈ 1.12 − 0.025 ln(2.8×10¹⁹/10¹⁶) ≈ 1.12 − 0.21 ≈ 0.91 eV above the valence band. Electron concentration ≈ Nd = 10¹⁶ cm⁻³. Hole concentration drops to p ≈ ni²/Nd ≈ (1.5×10¹⁰)²/10¹⁶ ≈ 2.25×10⁴ cm⁻³ — minority carriers are suppressed.',
  },
  {
    q: 'Compare Silicon and Germanium at the same temperature (300 K). Which has more intrinsic carriers? Why does this make Ge less suitable for high-temperature devices?',
    a: 'Ge has Eg = 0.67 eV vs Si 1.12 eV. The exponential gives ni(Ge) ≈ ni(Si) × exp((1.12−0.67)/(2×0.025)) ≈ 2×10¹³ cm⁻³, about 1000× higher. At elevated temperatures, Ge becomes too conductive intrinsically, making it hard to control with doping. Si remains extrinsic up to ~150°C.',
  },
  {
    q: 'Select Copper (conductor). Why are there electrons in the "conduction band" even at 0 K? What would happen to resistance as temperature increases?',
    a: 'Copper has overlapping valence and conduction bands — no gap exists. The Fermi level sits inside the conduction band, so states are always available. At 0 K, electrons fill up to Ef but states above remain empty. As T increases, phonon scattering increases, so resistance rises (unlike semiconductors, where resistance falls because more carriers are generated).',
  },
  {
    q: 'Graduate: Explain why the Fermi level in an intrinsic semiconductor sits very close to the middle of the band gap, but not exactly at the midpoint.',
    a: 'Charge neutrality requires n = p. Using n = Nc exp(−(Ec−Ef)/kT) and p = Nv exp(−(Ef−Ev)/kT), setting n = p gives Ef = (Ec+Ev)/2 + (3kT/4) ln(mh*/me*). The second term shifts Ef slightly because the effective densities of states Nc and Nv depend on the effective masses of electrons and holes. For Si, mh* > me*, so Ef is slightly above midgap.',
  },
];

function Slider({ label, unit, value, min, max, step, set, color, note }: {
  label: string; unit: string; value: number; min: number; max: number;
  step: number; set: (v: number) => void; color: string; note?: string;
}) {
  return (
    <div className="space-y-1.5">
      <div className="flex justify-between text-xs">
        <span className="text-gray-500">{label}</span>
        <span className="font-medium tabular-nums text-gray-800">
          {value} <span className="text-gray-400 font-normal">{unit}</span>
        </span>
      </div>
      <input type="range" min={min} max={max} step={step} value={value} onChange={(e) => set(Number(e.target.value))} className="w-full" style={{ accentColor: color }} />
      {note && <p className="text-[10px] text-gray-400">{note}</p>}
    </div>
  );
}

function StatRow({ label, value, unit, color }: { label: string; value: string; unit: string; color: string; }) {
  return (
    <div className="flex justify-between items-center rounded-lg bg-gray-50 px-3 py-2">
      <span className="text-xs text-gray-500">{label}</span>
      <span className={`text-xs font-semibold tabular-nums ${color}`}>{value} <span className="text-gray-400 font-normal">{unit}</span></span>
    </div>
  );
}

function CollapsiblePanel({
  title, children, defaultOpen = true, badge,
}: {
  title: string; children: React.ReactNode; defaultOpen?: boolean; badge?: string;
}) {
  const [open, setOpen] = useState(defaultOpen);
  return (
    <div className="rounded-2xl border border-gray-200 bg-white shadow-sm overflow-hidden">
      <button onClick={() => setOpen((o) => !o)} className="w-full flex items-center justify-between px-4 py-3 hover:bg-gray-50 transition">
        <div className="flex items-center gap-2">
          <span className="text-xs font-medium text-gray-400 uppercase tracking-wide">{title}</span>
          {badge && <span className="text-[10px] px-1.5 py-0.5 rounded-full bg-indigo-50 text-indigo-600 font-medium">{badge}</span>}
        </div>
        <span className="text-gray-400 text-xs">{open ? '▲ Hide' : '▼ Show'}</span>
      </button>
      {open && <div className="px-4 pb-4">{children}</div>}
    </div>
  );
}

export default function BandTheoryPage() {
  const [isRunning, setIsRunning] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const [resetKey, setResetKey] = useState(0);
  const [openEx, setOpenEx] = useState<number | null>(null);
  const [activeCurricula, setActiveCurricula] = useState(['IGCSE', 'SAT', 'JUPEB', 'A-Level', 'Undergrad']);

  const [material, setMaterial] = useState('silicon');
  const [temperature, setTemperature] = useState(300);
  const [dopingType, setDopingType] = useState<DopingType>('intrinsic');
  const [dopingConcentration, setDopingConcentration] = useState(10);
  const [speed, setSpeed] = useState(1);
  const [zoom, setZoom] = useState(1);
  const [showElectrons, setShowElectrons] = useState(true);
  const [showHoles, setShowHoles] = useState(true);
  const [showFermiLevel, setShowFermiLevel] = useState(true);
  const [showBandGap, setShowBandGap] = useState(true);
  const [showThermalEnergy, setShowThermalEnergy] = useState(false);
  const [showDOS, setShowDOS] = useState(false);
  const [animateCarriers, setAnimateCarriers] = useState(true);

  const params: BandTheoryParams = {
    material, temperature, dopingType, dopingConcentration,
    speed, zoom, showElectrons, showHoles, showFermiLevel,
    showBandGap, showThermalEnergy, showDOS, animateCarriers,
  };

  const [liveStats, setLiveStats] = useState<BandTheoryStats>({
    bandGap: 1.12, temperature: 300, kT: 0.0259, fermiLevel: 0.56,
    intrinsicConc: 1.5e10, electronConc: 1.5e10, holeConc: 1.5e10, conductivity: 'Moderate',
  });

  const mat = MATERIALS[material];
  const matType = mat?.type || 'semiconductor';

  const applyPreset = useCallback((presetIdx: number) => {
    const preset = BAND_PRESETS[presetIdx];
    if (!preset) return;
    const pp = preset.params;
    if (pp.material) setMaterial(pp.material);
    if (pp.temperature !== undefined) setTemperature(pp.temperature);
    if (pp.dopingType) setDopingType(pp.dopingType);
    if (pp.dopingConcentration !== undefined) setDopingConcentration(pp.dopingConcentration);
    if (pp.showElectrons !== undefined) setShowElectrons(pp.showElectrons);
    if (pp.showHoles !== undefined) setShowHoles(pp.showHoles);
    if (pp.showFermiLevel !== undefined) setShowFermiLevel(pp.showFermiLevel);
    if (pp.showBandGap !== undefined) setShowBandGap(pp.showBandGap);
    if (pp.showThermalEnergy !== undefined) setShowThermalEnergy(pp.showThermalEnergy);
    setIsRunning(false); setIsPaused(false);
    setResetKey((k) => k + 1);
  }, []);

  const reset = useCallback(() => {
    setIsRunning(false); setIsPaused(false);
    setResetKey((k) => k + 1);
  }, []);

  const canvasBoxRef = useRef<HTMLDivElement>(null);
  const canvasSize = useResponsiveCanvasSize(canvasBoxRef, 720, 500, 900);

  const lastTickRef = useRef(0);
  const handleTick = useCallback((stats: BandTheoryStats) => {
    const now = performance.now();
    if (now - lastTickRef.current < 80) return;
    lastTickRef.current = now;
    setLiveStats(stats);
  }, []);

  const scenarioNote = SCENARIO_NOTES[matType];
  const dopingLabel = dopingType === 'intrinsic' ? 'Intrinsic' : dopingType === 'n-type' ? 'n-type' : 'p-type';

  return (
    <>
      <AppHeader />
      <main className="min-h-screen bg-gray-50">
        <section className="border-b border-gray-200 bg-white">
          <div className="mx-auto max-w-[100rem] px-4 sm:px-6 py-4">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
              <div>
                <p className="text-xs text-gray-400 mb-0.5">Solid State Physics — Electronic Properties of Materials</p>
                <h1 className="text-lg font-semibold text-gray-900">Energy Band Theory</h1>
              </div>
              <div className="flex gap-1.5 flex-wrap">
                {CURRICULA.map((c) => (
                  <button key={c} onClick={() => setActiveCurricula((p) => p.includes(c) ? p.filter((x) => x !== c) : [...p, c])}
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
            <span className="text-xs text-gray-400">Atomic Orbitals → Crystal Bands → Gap → Doping → Devices</span>
            <span className="text-sm font-semibold font-mono text-gray-900">ni = √(NcNv) e^(−Eg/2kT)</span>
          </div>

          {/* Material type cards */}
          <div className="grid grid-cols-3 lg:grid-cols-6 gap-1.5 sm:gap-2">
            {Object.entries(MATERIALS).map(([key, m]) => {
              const active = material === key;
              return (
                <button key={key} onClick={() => { setMaterial(key); setIsRunning(false); setResetKey((k) => k + 1); }}
                  className={`relative rounded-xl border px-2 py-2 sm:px-3 sm:py-3 text-left hover:shadow-md transition min-w-0
                    ${active ? 'border-indigo-400 bg-indigo-50 text-indigo-800 ring-1 ring-indigo-200' : 'border-gray-200 bg-white text-gray-600 hover:border-indigo-200'}`}>
                  <div className="flex items-center justify-between mb-0.5 sm:mb-1">
                    <p className={`text-[10px] sm:text-xs font-semibold ${active ? 'text-indigo-700' : 'text-gray-700'}`}>{m.symbol}</p>
                    {active && <span className="w-1.5 h-1.5 sm:w-2 sm:h-2 rounded-full bg-indigo-500 animate-pulse" />}
                  </div>
                  <p className="text-[9px] sm:text-[10px] text-gray-400 leading-relaxed">{m.name}</p>
                  <p className="text-[9px] text-gray-400 mt-0.5">{m.bandGap > 0 ? `Eg=${m.bandGap}eV` : 'No gap'}</p>
                  {active && <div className="absolute bottom-0 left-0 right-0 h-0.5 bg-indigo-400 rounded-b-xl" />}
                </button>
              );
            })}
          </div>

          {/* Presets */}
          <div className="flex gap-2 overflow-x-auto pb-1">
            {BAND_PRESETS.map((preset, i) => (
              <button key={i} onClick={() => applyPreset(i)}
                className="shrink-0 rounded-xl border border-gray-200 bg-white px-3 py-2 text-left hover:border-indigo-300 hover:shadow-sm transition min-w-[200px]">
                <p className="text-xs font-medium text-indigo-700">{preset.name}</p>
                <p className="text-[10px] text-gray-400 mt-0.5 leading-relaxed">{preset.description}</p>
              </button>
            ))}
          </div>

          <div className="grid grid-cols-1 lg:grid-cols-[1fr_280px] xl:grid-cols-[1fr_280px_300px] gap-4 items-start">
            <div className="space-y-3 min-w-0">
              <div ref={canvasBoxRef} className="rounded-2xl border border-gray-200 bg-white p-3 shadow-sm">
                <BandTheoryCanvas key={resetKey} params={params} isRunning={isRunning} isPaused={isPaused} onTick={handleTick} width={canvasSize.width} height={canvasSize.height} />
              </div>

              <div className="flex flex-wrap items-center justify-between gap-2">
                <SimulationControls isRunning={isRunning} isPaused={isPaused}
                  onRun={() => { setIsRunning(true); setIsPaused(false); }}
                  onPause={() => setIsPaused((p) => !p)} onReset={reset} />
                <EmbedButton path="/embed/band-theory" title="Energy Band Theory — A-Factor STEM Studio"
                  params={{ mat: material, T: temperature, dopant: dopingType, conc: dopingConcentration, speed, zoom, e: showElectrons ? 1 : 0, h: showHoles ? 1 : 0, ef: showFermiLevel ? 1 : 0, eg: showBandGap ? 1 : 0, kt: showThermalEnergy ? 1 : 0, dos: showDOS ? 1 : 0, anim: animateCarriers ? 1 : 0 }} />
              </div>

              {/* Parameters — sticky bottom on desktop, right after controls on mobile */}
              <div className="lg:sticky lg:bottom-4 z-30">
                <CollapsiblePanel title="Parameters" badge="Interactive" defaultOpen={true}>
                  <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-x-6 gap-y-4">
                    <div className="space-y-3">
                      <p className="text-[10px] font-medium text-indigo-600 uppercase tracking-wide">Material</p>
                      <Slider label="Temperature" unit="K" value={temperature} min={0} max={1000} step={10} set={setTemperature} color="#f43f5e" note="Thermal energy kT = {kT_eV(temperature).toFixed(3)} eV" />
                      <Slider label="Doping conc." unit="log₁₀(cm⁻³)" value={dopingConcentration} min={10} max={20} step={0.5} set={setDopingConcentration} color="#8b5cf6" note={`Actual: ${Math.pow(10, dopingConcentration).toExponential(0)} cm⁻³`} />
                    </div>
                    <div className="space-y-3">
                      <p className="text-[10px] font-medium text-amber-600 uppercase tracking-wide">Doping</p>
                      <div className="flex gap-2">
                        {(['intrinsic', 'n-type', 'p-type'] as DopingType[]).map((d) => (
                          <button key={d} onClick={() => setDopingType(d)}
                            className={`text-xs px-3 py-1.5 rounded-lg border transition ${dopingType === d ? 'border-indigo-400 bg-indigo-50 text-indigo-700 font-medium' : 'border-gray-200 text-gray-500 hover:border-indigo-200'}`}>
                            {d}
                          </button>
                        ))}
                      </div>
                      <Slider label="Animation speed" unit="×" value={speed} min={0} max={3} step={0.1} set={setSpeed} color="#3b82f6" />
                      <Slider label="Zoom" unit="×" value={zoom} min={0.5} max={2} step={0.1} set={setZoom} color="#10b981" />
                    </div>
                    <div className="space-y-3">
                      <p className="text-[10px] font-medium text-emerald-600 uppercase tracking-wide">Display</p>
                      <div className="flex flex-wrap gap-2">
                        {[
                          { label: 'Electrons', checked: showElectrons, set: setShowElectrons },
                          { label: 'Holes', checked: showHoles, set: setShowHoles },
                          { label: 'Fermi level', checked: showFermiLevel, set: setShowFermiLevel },
                          { label: 'Band gap', checked: showBandGap, set: setShowBandGap },
                          { label: 'kT indicator', checked: showThermalEnergy, set: setShowThermalEnergy },
                          { label: 'Animate', checked: animateCarriers, set: setAnimateCarriers },
                        ].map((item) => (
                          <label key={item.label} className="flex items-center gap-1.5 text-[11px] text-gray-600 cursor-pointer bg-gray-50 px-2 py-1 rounded-md border border-gray-100 hover:border-indigo-200 transition">
                            <input type="checkbox" checked={item.checked} onChange={(e) => item.set(e.target.checked)} className="rounded" />
                            {item.label}
                          </label>
                        ))}
                      </div>
                    </div>
                  </div>
                </CollapsiblePanel>
              </div>
            </div>

            {/* Stats sidebar */}
            <div className="space-y-3">
              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide mb-3">Calculated</p>
                <div className="space-y-2">
                  <StatRow label="Material" value={mat?.symbol || 'Si'} unit="" color="text-indigo-600" />
                  <StatRow label="Band gap Eg" value={liveStats.bandGap.toFixed(2)} unit="eV" color="text-amber-600" />
                  <StatRow label="Temperature" value={liveStats.temperature.toString()} unit="K" color="text-rose-500" />
                  <StatRow label="Thermal kT" value={liveStats.kT.toFixed(4)} unit="eV" color="text-pink-500" />
                  <StatRow label="Fermi level" value={liveStats.fermiLevel.toFixed(2)} unit="eV" color="text-white" />
                  <div className="border-t border-gray-100 my-1" />
                  <StatRow label="ni (intrinsic)" value={liveStats.intrinsicConc.toExponential(1)} unit="cm⁻³" color="text-emerald-600" />
                  <StatRow label="Electrons n" value={liveStats.electronConc.toExponential(1)} unit="cm⁻³" color="text-blue-500" />
                  <StatRow label="Holes p" value={liveStats.holeConc.toExponential(1)} unit="cm⁻³" color="text-purple-600" />
                  <StatRow label="Conductivity" value={liveStats.conductivity} unit="" color="text-cyan-600" />
                </div>
              </div>

              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide mb-2">Key Formula</p>
                <div className="space-y-2 text-[10px] text-gray-600 font-mono leading-relaxed">
                  <p>ni = √(NcNv) · exp(−Eg/2kT)</p>
                  <p>ni ≈ {liveStats.intrinsicConc.toExponential(1)} cm⁻³</p>
                  <p className="text-gray-400">———————</p>
                  <p>n · p = ni²</p>
                  <p>n = {liveStats.electronConc.toExponential(1)}</p>
                  <p>p = {liveStats.holeConc.toExponential(1)}</p>
                </div>
              </div>

              <div className="rounded-2xl border border-gray-100 bg-white p-4">
                <p className="text-xs text-gray-400 mb-2">Curriculum</p>
                <div className="flex flex-wrap gap-1.5">
                  {CURRICULA.map((c) => (
                    <span key={c} className={`text-xs font-medium px-2 py-0.5 rounded-full ${activeCurricula.includes(c) ? CC[c] : 'bg-gray-100 text-gray-400'}`}>{c}</span>
                  ))}
                </div>
              </div>
            </div>

            {/* Teacher Notes + Exercises */}
            <div className="space-y-3 lg:col-span-2 xl:col-span-1">
              <CollapsiblePanel title="Teacher Notes" badge={materialTypeLabel(matType)} defaultOpen={true}>
                <div className="space-y-3">
                  <div className="rounded-lg bg-amber-50 border border-amber-100 p-3">
                    <p className="text-xs font-semibold text-amber-800 mb-1.5">{scenarioNote.title}</p>
                    <ul className="space-y-1.5">
                      {scenarioNote.bullets.map((b, i) => (
                        <li key={i} className="text-[11px] text-amber-900 leading-relaxed flex gap-2">
                          <span className="text-amber-400 shrink-0 mt-0.5">•</span>{b}
                        </li>
                      ))}
                    </ul>
                  </div>
                  <div>
                    <p className="text-[10px] font-medium text-gray-400 uppercase tracking-wide mb-2">General Principles</p>
                    <ul className="space-y-2">
                      {GENERAL_NOTES.map((n, i) => (
                        <li key={i} className="text-xs text-gray-600 leading-relaxed flex gap-2">
                          <span className="text-gray-300 shrink-0 mt-0.5">•</span>{n}
                        </li>
                      ))}
                    </ul>
                  </div>
                </div>
              </CollapsiblePanel>

              <CollapsiblePanel title="Exercises" defaultOpen={false}>
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
              </CollapsiblePanel>
            </div>
          </div>
        </div>
      </main>
    </>
  );
}