'use client';
import { useState, useRef } from 'react';
import { AppHeader } from '@/components/layout/AppHeader';
import { BoylesCanvas } from '@/components/simulation/BoylesCanvas';
import { CharlesCanvas } from '@/components/simulation/CharlesCanvas';
import { PressureLawCanvas } from '@/components/simulation/PressureLawCanvas';
import { IdealGasCanvas } from '@/components/simulation/IdealGasCanvas';
import { useResponsiveCanvasSize } from '@/hooks/useResponsiveCanvasSize';
import { GasLawGraph } from '@/components/simulation/GasLawGraph';
import {
  idealGasPressure, idealGasVolume, idealGasMoles, idealGasTemperature,
  charlesNewVolume, pressureLawNewPressure, VAN_DER_WAALS,
} from '@/lib/physics/gas-laws';

type Law = 'boyle' | 'charles' | 'pressure' | 'ideal' | 'real';

const CURRICULA = ['WAEC', 'NECO', 'IGCSE', 'SAT', 'JUPEB'];
const CURRICULUM_COLORS: Record<string, string> = {
  WAEC: 'bg-indigo-100 text-indigo-700', NECO: 'bg-pink-100 text-pink-700',
  IGCSE: 'bg-emerald-100 text-emerald-700', SAT: 'bg-orange-100 text-orange-700',
  JUPEB: 'bg-purple-100 text-purple-700',
};

const LAW_META: Record<Law, { title: string; equation: string; condition: string; graphLabel: string; graphDesc: string }> = {
  boyle:    { title: "Boyle's Law",    equation: 'P₁V₁ = P₂V₂',   condition: 'constant T, n',            graphLabel: 'P–V graph',           graphDesc: 'Hyperbolic isotherm. Yellow dot = current state.' },
  charles:  { title: "Charles' Law",   equation: 'V₁/T₁ = V₂/T₂', condition: 'constant P, n — T in K',  graphLabel: 'V–T graph',           graphDesc: 'Straight line → 0 K. Yellow dot = current state.' },
  pressure: { title: 'Pressure Law',   equation: 'P₁/T₁ = P₂/T₂', condition: 'constant V, n — T in K',  graphLabel: 'P–T graph',           graphDesc: 'Straight line → 0 K. Pressure rises with temperature.' },
  ideal:    { title: 'Ideal Gas Law',  equation: 'PV = nRT',        condition: 'R = 8.314 J mol⁻¹ K⁻¹', graphLabel: 'P–V isotherms',       graphDesc: 'Three isotherms at different mole counts. All obey PV = nRT.' },
  real:     { title: 'Real Gases',     equation: '(P + an²/V²)(V − nb) = nRT', condition: 'Van der Waals equation', graphLabel: 'Compressibility (Z vs P)', graphDesc: 'Z = PV/nRT. Ideal gas Z = 1 always. Real gases deviate at high pressure.' },
};

const TEACHER_NOTES: Record<Law, string[]> = {
  boyle: [
    "Boyle's Law: at constant T, pressure and volume are inversely proportional — P₁V₁ = P₂V₂.",
    "The P–V graph is a hyperbola. Each curve (isotherm) represents a different temperature.",
    "Higher temperature isotherms sit above lower ones — more energy means higher pressure at same volume.",
    "Real gases deviate from this at very high pressures or near condensation.",
    "Ask: what happens to particles when volume decreases? Why does pressure increase?",
  ],
  charles: [
    "Charles' Law: at constant P, volume is proportional to absolute temperature — V₁/T₁ = V₂/T₂.",
    "Temperature MUST be in Kelvin. 0°C is not zero molecular motion — 0 K is.",
    "Extended to 0 K, the V–T graph passes through the origin — this is how absolute zero was estimated.",
    "A gas at 0 K would have zero volume — impossible for real gases (they liquefy first).",
    "Ask: why do hot air balloons rise? Why do car tyres stiffen in cold weather?",
  ],
  pressure: [
    "Pressure Law (Gay-Lussac): at constant V, pressure is proportional to T — P₁/T₁ = P₂/T₂.",
    "This is what happens in rigid sealed containers like pressure cookers and aerosol cans.",
    "NEVER heat a sealed rigid container — pressure rises until it ruptures.",
    "The P–T graph is a straight line through 0 K, just like Charles' Law.",
    "Combined with Boyle's and Charles' Law, this gives the ideal gas law: PV = nRT.",
  ],
  ideal: [
    "The ideal gas law PV = nRT unifies Boyle's, Charles', and the Pressure Law into one equation.",
    "R = 8.314 J mol⁻¹ K⁻¹ is the universal gas constant — the same for every gas.",
    "An ideal gas has no intermolecular forces and particles occupy zero volume.",
    "Use the calculator: input any 3 of P, V, n, T and solve for the 4th.",
    "At standard conditions (STP: 0°C, 100 kPa), 1 mol of ideal gas occupies 22.4 L.",
  ],
  real: [
    "Real gases deviate from ideal behaviour due to: (1) intermolecular attractions and (2) finite particle volume.",
    "The Van der Waals equation corrects for both: (P + an²/V²)(V − nb) = nRT. 'a' corrects for attractions; 'b' for particle volume.",
    "Z = PV/nRT is the compressibility factor. For ideal gas Z = 1. Real gases: Z < 1 at moderate P (attractions dominate), Z > 1 at high P (volume dominates).",
    "CO₂ and NH₃ show strong deviation (large 'a') — they have strong intermolecular forces.",
    "Helium and H₂ are nearly ideal — small, non-polar molecules with weak forces.",
  ],
};

const EXERCISES: Record<Law, { q: string; a: string }[]> = {
  boyle: [
    { q: "A gas at 200 kPa occupies 4 L. Find the volume at 400 kPa (constant T).", a: "V₂ = P₁V₁/P₂ = (200×4)/400 = 2 L" },
    { q: "A gas at 100 kPa occupies 8 L. Find the pressure at 2 L.", a: "P₂ = P₁V₁/V₂ = (100×8)/2 = 400 kPa" },
    { q: "Why is the P–V graph a hyperbola and not a straight line?", a: "P and V are inversely proportional (PV = constant), so plotting one against the other gives a rectangular hyperbola." },
  ],
  charles: [
    { q: "A gas occupies 3 L at 300 K. Find its volume at 600 K (constant P).", a: "V₂ = V₁T₂/T₁ = (3×600)/300 = 6 L" },
    { q: "A balloon is 2 L at 27°C. Find volume at 127°C.", a: "T₁=300K, T₂=400K → V₂ = (2×400)/300 = 2.67 L" },
    { q: "Why must temperature be in Kelvin for gas law calculations?", a: "Kelvin measures absolute thermal energy starting from 0 K (zero molecular motion). Celsius 0 is arbitrary — ratios in Celsius give wrong answers." },
  ],
  pressure: [
    { q: "Gas in a rigid container: 150 kPa at 300 K. Find pressure at 600 K.", a: "P₂ = P₁T₂/T₁ = (150×600)/300 = 300 kPa" },
    { q: "An aerosol can: 250 kPa at 20°C. Find pressure at 60°C.", a: "T₁=293K, T₂=333K → P₂ = (250×333)/293 ≈ 284 kPa" },
    { q: "Why is it dangerous to throw an aerosol can into a fire?", a: "Fixed volume means rising temperature causes pressure to rise proportionally — eventually exceeding the can's rated limit, causing explosion." },
  ],
  ideal: [
    { q: "Calculate the volume of 2 mol of ideal gas at 300 K and 100 kPa.", a: "V = nRT/P = (2 × 8.314 × 300) / (100×1000) = 0.0499 m³ = 49.9 L" },
    { q: "What pressure does 0.5 mol of gas exert in a 10 L container at 27°C?", a: "T=300K, V=0.01m³ → P = nRT/V = (0.5×8.314×300)/0.01 = 124,710 Pa ≈ 125 kPa" },
    { q: "At STP (0°C, 100 kPa), what volume does 1 mol of ideal gas occupy?", a: "V = nRT/P = (1×8.314×273)/(100,000) = 0.0227 m³ = 22.7 L (≈ 22.4 L)" },
  ],
  real: [
    { q: "Why does CO₂ deviate more from ideal behaviour than helium?", a: "CO₂ has stronger intermolecular attractions (large 'a' = 3.64) and larger molecular volume (larger 'b'). Helium has a = 0.034 — nearly ideal." },
    { q: "At what conditions do real gases behave most like ideal gases?", a: "High temperature and low pressure — high T means thermal energy dominates over attractions; low P means molecules are far apart and volume is negligible." },
    { q: "What does Z < 1 tell us about a real gas?", a: "Intermolecular attractions are dominant — the gas is more compressed than an ideal gas at the same conditions. Common at moderate pressures." },
  ],
};

const REAL_WORLD: Record<Law, { icon: string; text: string }[]> = {
  boyle:    [{ icon: '🤿', text: 'Scuba — gas in lungs expands as diver ascends.' }, { icon: '🩺', text: 'Breathing — diaphragm lowers volume to draw air in.' }, { icon: '💉', text: 'Syringes — reduced pressure draws in fluid.' }],
  charles:  [{ icon: '🎈', text: 'Hot air balloons — heat expands gas, reducing density.' }, { icon: '🚗', text: 'Car tyres stiffen in cold — volume decreases.' }, { icon: '🍞', text: 'Bread rising — CO₂ expands in oven heat.' }],
  pressure: [{ icon: '🥘', text: 'Pressure cooker — sealed volume means pressure rises with T.' }, { icon: '💣', text: 'Aerosol cans — never incinerate, pressure rises rapidly.' }, { icon: '🌡️', text: 'Gas thermometers measure T by pressure change at fixed V.' }],
  ideal:    [{ icon: '🏭', text: 'Industrial gas storage — engineers use PV = nRT to size tanks.' }, { icon: '🚀', text: 'Rocket propellant — gas behaviour at extreme T and P.' }, { icon: '⚗️', text: 'Lab calculations — molar volume, stoichiometry of gases.' }],
  real:     [{ icon: '❄️', text: 'Refrigerants — real gas properties essential for cooling cycles.' }, { icon: '🏗️', text: 'High-pressure pipelines — Van der Waals correction at 200+ atm.' }, { icon: '🌊', text: 'Deep-sea gas pockets — extreme P makes gas behaviour non-ideal.' }],
};

type SolveFor = 'P' | 'V' | 'n' | 'T';

export default function GasLawsPage() {
  const [law, setLaw] = useState<Law>('boyle');
  const [volume, setVolume] = useState(4);
  const [temperature, setTemperature] = useState(300);
  const [pressure, setPressure] = useState(200);
  const [moles, setMoles] = useState(0.1);
  const [openEx, setOpenEx] = useState<number | null>(null);
  const [activeCurricula, setActiveCurricula] = useState(['WAEC', 'IGCSE']);
  const [selectedGas, setSelectedGas] = useState('CO2');
  const [solveFor, setSolveFor] = useState<SolveFor>('P');

  // Derived values
  const derivedP_boyle  = idealGasPressure(moles, temperature, volume) / 1000;
  const derivedV_charles = charlesNewVolume(3, 300, temperature);
  const derivedP_pressure = pressureLawNewPressure(200, 300, temperature);

  // Ideal gas solver
  const solvedValue = (() => {
    if (solveFor === 'P') return { label: 'P', value: (idealGasPressure(moles, temperature, volume) / 1000).toFixed(2), unit: 'kPa' };
    if (solveFor === 'V') return { label: 'V', value: idealGasVolume(moles, temperature, pressure).toFixed(3), unit: 'L' };
    if (solveFor === 'n') return { label: 'n', value: idealGasMoles(pressure, volume, temperature).toFixed(4), unit: 'mol' };
    return { label: 'T', value: idealGasTemperature(pressure, volume, moles).toFixed(1), unit: 'K' };
  })();

  const toggleC = (c: string) =>
    setActiveCurricula(p => p.includes(c) ? p.filter(x => x !== c) : [...p, c]);

  const meta = LAW_META[law];

  // This card sits in a narrower grid column (alongside a graph/stats
  // column), so it gets a smaller cap than the full-width single-canvas
  // sims elsewhere in the app.
  const canvasBoxRef = useRef<HTMLDivElement>(null);
  const canvasSize = useResponsiveCanvasSize(canvasBoxRef, 280, 240, 460);

  return (
    <>
      <AppHeader />
      <main className="min-h-screen bg-gray-50">
        <section className="border-b border-gray-200 bg-white">
          <div className="mx-auto max-w-[100rem] px-4 sm:px-6 py-5">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
              <div>
                <p className="text-xs text-gray-400 mb-1">Thermal physics</p>
                <h1 className="text-lg sm:text-xl font-semibold text-gray-900">Gas laws</h1>
              </div>
              <div className="flex gap-1.5 flex-wrap">
                {CURRICULA.map(c => (
                  <button key={c} onClick={() => toggleC(c)}
                    className={`text-xs px-2.5 py-1 rounded-full border font-medium transition ${
                      activeCurricula.includes(c) ? CURRICULUM_COLORS[c] + ' border-transparent' : 'bg-white text-gray-400 border-gray-200'
                    }`}>{c}</button>
                ))}
              </div>
            </div>
          </div>
        </section>

        <div className="mx-auto max-w-[100rem] px-4 sm:px-6 py-5 space-y-4">

          {/* Tabs */}
          <div className="flex gap-1 bg-gray-100 p-1 rounded-xl overflow-x-auto">
            {(Object.keys(LAW_META) as Law[]).map(l => (
              <button key={l} onClick={() => { setLaw(l); setOpenEx(null); }}
                className={`shrink-0 px-3 sm:px-4 py-2 rounded-lg text-xs font-medium transition ${
                  law === l ? 'bg-white text-indigo-700 shadow-sm' : 'text-gray-500 hover:text-gray-700'
                }`}>{LAW_META[l].title}</button>
            ))}
          </div>

          {/* Equation banner */}
          <div className="flex flex-wrap items-center gap-3 rounded-xl border border-gray-200 bg-white px-4 py-2.5">
            <span className="text-xs text-gray-400">Equation</span>
            <span className="text-sm font-semibold text-gray-900 font-mono">{meta.equation}</span>
            <span className="text-xs text-gray-400">{meta.condition}</span>
          </div>

          {/* Main grid */}
          <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-4">

            {/* Left: canvas / calculator */}
            <div className="space-y-3">
              <div ref={canvasBoxRef} className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide mb-3">
                  {law === 'boyle' ? 'Compression (constant T)' :
                   law === 'charles' ? 'Expansion (constant P)' :
                   law === 'pressure' ? 'Rigid container (constant V)' :
                   law === 'ideal' ? 'Ideal gas container' :
                   'Real vs ideal gas'}
                </p>

                {law === 'boyle'    && <BoylesCanvas volume={volume} temperature={temperature} moles={moles} width={canvasSize.width} height={canvasSize.height} />}
                {law === 'charles'  && <CharlesCanvas temperature={temperature} pressure={pressure} moles={moles} width={canvasSize.width} height={canvasSize.height} />}
                {law === 'pressure' && <PressureLawCanvas temperature={temperature} volume={volume} moles={moles} width={canvasSize.width} height={canvasSize.height} />}
                {law === 'ideal'    && <IdealGasCanvas pressure={pressure} volume={volume} temperature={temperature} moles={moles} solveFor={solveFor} width={canvasSize.width} height={canvasSize.height} />}
                {law === 'real'     && (
                  <div className="space-y-3">
                    <div className="rounded-xl border border-gray-100 bg-gray-50 p-3">
                      <p className="text-xs text-gray-400 mb-2">Select gas</p>
                      <div className="grid grid-cols-2 gap-1.5">
                        {Object.entries(VAN_DER_WAALS).filter(([k]) => k !== 'ideal').map(([key, g]) => (
                          <button key={key} onClick={() => setSelectedGas(key)}
                            className={`text-xs px-2 py-1.5 rounded-lg border font-medium transition text-left ${
                              selectedGas === key ? 'bg-indigo-600 text-white border-indigo-600' : 'bg-white text-gray-600 border-gray-200 hover:border-gray-300'
                            }`}>
                            <span className="font-mono">{g.formula}</span>
                            <span className="text-[10px] block opacity-70">{g.name}</span>
                          </button>
                        ))}
                      </div>
                    </div>
                    <div className="rounded-xl border border-gray-100 bg-gray-50 p-3 text-xs space-y-1.5">
                      <p className="font-medium text-gray-600">Van der Waals constants</p>
                      <div className="flex gap-4">
                        <span className="text-gray-500">a = <span className="font-mono font-medium text-gray-800">{VAN_DER_WAALS[selectedGas].a}</span> Pa·m⁶/mol²</span>
                        <span className="text-gray-500">b = <span className="font-mono font-medium text-gray-800">{VAN_DER_WAALS[selectedGas].b}</span> m³/mol</span>
                      </div>
                      <p className="text-gray-400 text-[10px]">a = intermolecular attractions · b = particle volume</p>
                    </div>
                  </div>
                )}
              </div>

              {/* Sliders / calculator */}
              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm space-y-4">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide">
                  {law === 'ideal' ? 'PV = nRT calculator' : 'Adjust parameters'}
                </p>

                {law === 'ideal' && (
                  <>
                    <div className="grid grid-cols-4 gap-1 bg-gray-100 p-1 rounded-xl">
                      {(['P', 'V', 'n', 'T'] as SolveFor[]).map(s => (
                        <button key={s} onClick={() => setSolveFor(s)}
                          className={`py-1.5 rounded-lg text-xs font-medium transition ${
                            solveFor === s ? 'bg-white text-indigo-700 shadow-sm' : 'text-gray-500'
                          }`}>Solve {s}</button>
                      ))}
                    </div>
                    {solveFor !== 'P' && (
                      <div className="space-y-1.5">
                        <div className="flex justify-between text-xs"><span className="text-gray-500">Pressure</span><span className="font-medium tabular-nums">{pressure} kPa</span></div>
                        <input type="range" min="10" max="1000" step="10" value={pressure} onChange={e => setPressure(Number(e.target.value))} className="w-full" style={{ accentColor: '#6366f1' }} />
                      </div>
                    )}
                    {solveFor !== 'V' && (
                      <div className="space-y-1.5">
                        <div className="flex justify-between text-xs"><span className="text-gray-500">Volume</span><span className="font-medium tabular-nums">{volume.toFixed(1)} L</span></div>
                        <input type="range" min="0.5" max="20" step="0.1" value={volume} onChange={e => setVolume(Number(e.target.value))} className="w-full" style={{ accentColor: '#10b981' }} />
                      </div>
                    )}
                    {solveFor !== 'n' && (
                      <div className="space-y-1.5">
                        <div className="flex justify-between text-xs"><span className="text-gray-500">Moles</span><span className="font-medium tabular-nums">{moles.toFixed(2)} mol</span></div>
                        <input type="range" min="0.01" max="1" step="0.01" value={moles} onChange={e => setMoles(Number(e.target.value))} className="w-full" style={{ accentColor: '#f59e0b' }} />
                      </div>
                    )}
                    {solveFor !== 'T' && (
                      <div className="space-y-1.5">
                        <div className="flex justify-between text-xs"><span className="text-gray-500">Temperature</span><span className="font-medium tabular-nums">{temperature} K</span></div>
                        <input type="range" min="100" max="1000" step="10" value={temperature} onChange={e => setTemperature(Number(e.target.value))} className="w-full" style={{ accentColor: '#ef4444' }} />
                      </div>
                    )}
                    <div className="rounded-xl bg-indigo-50 px-4 py-3 text-center">
                      <p className="text-xs text-indigo-400 mb-1">Solving for {solveFor}</p>
                      <p className="text-xl font-bold text-indigo-700 font-mono">{solvedValue.value} <span className="text-sm font-normal">{solvedValue.unit}</span></p>
                    </div>
                  </>
                )}

                {law === 'boyle' && (
                  <>
                    <div className="space-y-1.5">
                      <div className="flex justify-between text-xs"><span className="text-gray-500">Volume</span><span className="font-medium tabular-nums">{volume.toFixed(1)} L</span></div>
                      <input type="range" min="0.5" max="10" step="0.1" value={volume} onChange={e => setVolume(Number(e.target.value))} className="w-full" style={{ accentColor: '#6366f1' }} />
                    </div>
                    <div className="space-y-1.5">
                      <div className="flex justify-between text-xs"><span className="text-gray-500">Temperature (constant)</span><span className="font-medium tabular-nums">{temperature} K</span></div>
                      <input type="range" min="200" max="600" step="10" value={temperature} onChange={e => setTemperature(Number(e.target.value))} className="w-full" style={{ accentColor: '#f59e0b' }} />
                    </div>
                    <div className="rounded-xl bg-indigo-50 px-3 py-2.5">
                      <span className="text-sm font-medium text-indigo-700">P = {derivedP_boyle.toFixed(1)} kPa</span>
                    </div>
                  </>
                )}

                {law === 'charles' && (
                  <>
                    <div className="space-y-1.5">
                      <div className="flex justify-between text-xs"><span className="text-gray-500">Temperature</span><span className="font-medium tabular-nums">{temperature} K ({temperature - 273}°C)</span></div>
                      <input type="range" min="100" max="600" step="10" value={temperature} onChange={e => setTemperature(Number(e.target.value))} className="w-full" style={{ accentColor: '#f59e0b' }} />
                    </div>
                    <div className="space-y-1.5">
                      <div className="flex justify-between text-xs"><span className="text-gray-500">Pressure (constant)</span><span className="font-medium tabular-nums">{pressure} kPa</span></div>
                      <input type="range" min="50" max="500" step="10" value={pressure} onChange={e => setPressure(Number(e.target.value))} className="w-full" style={{ accentColor: '#10b981' }} />
                    </div>
                    <div className="rounded-xl bg-emerald-50 px-3 py-2.5">
                      <span className="text-sm font-medium text-emerald-700">V = {derivedV_charles.toFixed(2)} L</span>
                    </div>
                  </>
                )}

                {law === 'pressure' && (
                  <>
                    <div className="space-y-1.5">
                      <div className="flex justify-between text-xs"><span className="text-gray-500">Temperature</span><span className="font-medium tabular-nums">{temperature} K ({temperature - 273}°C)</span></div>
                      <input type="range" min="100" max="600" step="10" value={temperature} onChange={e => setTemperature(Number(e.target.value))} className="w-full" style={{ accentColor: '#f59e0b' }} />
                    </div>
                    <div className="space-y-1.5">
                      <div className="flex justify-between text-xs"><span className="text-gray-500">Volume (constant)</span><span className="font-medium tabular-nums">{volume.toFixed(1)} L</span></div>
                      <input type="range" min="0.5" max="10" step="0.1" value={volume} onChange={e => setVolume(Number(e.target.value))} className="w-full" style={{ accentColor: '#6366f1' }} />
                    </div>
                    <div className="rounded-xl bg-red-50 px-3 py-2.5">
                      <span className="text-sm font-medium text-red-700">P = {derivedP_pressure.toFixed(1)} kPa</span>
                    </div>
                  </>
                )}

                {law === 'real' && (
                  <>
                    <div className="space-y-1.5">
                      <div className="flex justify-between text-xs"><span className="text-gray-500">Temperature</span><span className="font-medium tabular-nums">{temperature} K</span></div>
                      <input type="range" min="200" max="800" step="10" value={temperature} onChange={e => setTemperature(Number(e.target.value))} className="w-full" style={{ accentColor: '#f59e0b' }} />
                    </div>
                    <div className="space-y-1.5">
                      <div className="flex justify-between text-xs"><span className="text-gray-500">Moles</span><span className="font-medium tabular-nums">{moles.toFixed(2)} mol</span></div>
                      <input type="range" min="0.01" max="1" step="0.01" value={moles} onChange={e => setMoles(Number(e.target.value))} className="w-full" style={{ accentColor: '#6366f1' }} />
                    </div>
                    <p className="text-xs text-gray-400">Lower T and higher P = more deviation from ideal. Try CO₂ vs He.</p>
                  </>
                )}
              </div>
            </div>

            {/* Graph */}
            <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
              <p className="text-xs font-medium text-gray-400 uppercase tracking-wide mb-1">{meta.graphLabel}</p>
              <p className="text-xs text-gray-400 mb-4">{meta.graphDesc}</p>
              <GasLawGraph
                law={law}
                currentV={volume}
                currentP={law === 'boyle' ? derivedP_boyle : law === 'pressure' ? derivedP_pressure : pressure}
                currentT={temperature}
                moles={moles}
                selectedGas={selectedGas}
              />
              <div className="mt-4 rounded-xl border border-indigo-100 bg-indigo-50 p-3">
                <p className="text-xs font-medium text-indigo-600 mb-2">Real world</p>
                <ul className="space-y-1.5">
                  {REAL_WORLD[law].map((r, i) => (
                    <li key={i} className="text-xs text-indigo-800 flex gap-2 leading-relaxed">
                      <span className="shrink-0">{r.icon}</span>{r.text}
                    </li>
                  ))}
                </ul>
              </div>
              <div className="mt-3">
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
            <div className="space-y-3 md:col-span-2 xl:col-span-1">
              <div className="rounded-2xl border border-amber-100 bg-amber-50 p-4">
                <p className="text-xs font-medium text-amber-700 uppercase tracking-wide mb-3">📋 Teacher notes</p>
                <ul className="space-y-2">
                  {TEACHER_NOTES[law].map((note, i) => (
                    <li key={i} className="text-xs text-amber-900 leading-relaxed flex gap-2">
                      <span className="text-amber-400 shrink-0 mt-0.5">•</span>{note}
                    </li>
                  ))}
                </ul>
              </div>
              <div className="rounded-2xl border border-gray-200 bg-white p-4">
                <p className="text-xs font-medium text-gray-500 uppercase tracking-wide mb-3">✏️ Exercises</p>
                <div className="space-y-2">
                  {EXERCISES[law].map((ex, i) => (
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
