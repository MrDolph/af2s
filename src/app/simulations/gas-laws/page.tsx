'use client';
import { useState } from 'react';
import { AppHeader } from '@/components/layout/AppHeader';
import { BoylesCanvas } from '@/components/simulation/BoylesCanvas';
import { CharlesCanvas } from '@/components/simulation/CharlesCanvas';
import { GasLawGraph } from '@/components/simulation/GasLawGraph';
import { idealGasPressure, charlesNewVolume } from '@/lib/physics/gas-laws';

type Law = 'boyle' | 'charles';

const CURRICULA = ['WAEC', 'NECO', 'IGCSE', 'SAT', 'JUPEB'];
const CURRICULUM_COLORS: Record<string, string> = {
  WAEC: 'bg-indigo-100 text-indigo-700', NECO: 'bg-pink-100 text-pink-700',
  IGCSE: 'bg-emerald-100 text-emerald-700', SAT: 'bg-orange-100 text-orange-700',
  JUPEB: 'bg-purple-100 text-purple-700',
};

const TEACHER_NOTES = {
  boyle: [
    "Boyle's Law: at constant temperature, P₁V₁ = P₂V₂. Pressure and volume are inversely proportional.",
    "The P-V graph is a hyperbola — halving the volume doubles the pressure.",
    "Real gases deviate at very high pressures or low temperatures.",
    "Ask students: what happens to particles when volume decreases? Why does pressure increase?",
  ],
  charles: [
    "Charles' Law: at constant pressure, V₁/T₁ = V₂/T₂. Volume is proportional to absolute temperature.",
    "Temperature MUST be in Kelvin — the law breaks down with Celsius.",
    "The V-T graph is a straight line. Extended to 0 K it passes through absolute zero.",
    "Ask students: why do hot air balloons rise? Why do car tyres overinflate in summer?",
  ],
};

const EXERCISES = {
  boyle: [
    { q: "A gas occupies 4 L at 200 kPa. What is its volume at 400 kPa? (constant T)", a: "2 L — P₁V₁ = P₂V₂ → (200×4)/400 = 2 L" },
    { q: "A gas at 100 kPa has volume 8 L. Find the pressure when V = 2 L.", a: "400 kPa — (100×8)/2 = 400 kPa" },
    { q: "Why does a sealed syringe become harder to push as you compress the gas?", a: "Reducing volume increases pressure — more particle collisions per unit area." },
  ],
  charles: [
    { q: "A gas occupies 3 L at 300 K. What volume at 600 K? (constant P)", a: "6 L — V₁/T₁ = V₂/T₂ → (3×600)/300 = 6 L" },
    { q: "A balloon has volume 2 L at 27°C. Find its volume at 127°C.", a: "T₁=300K, T₂=400K → V₂ = (2×400)/300 = 2.67 L" },
    { q: "Why must temperature be in Kelvin when using Charles' Law?", a: "Kelvin starts at absolute zero — the true zero of molecular motion. Celsius gives wrong ratios." },
  ],
};

export default function GasLawsPage() {
  const [law, setLaw] = useState<Law>('boyle');
  const [volume, setVolume] = useState(4);
  const [temperature, setTemperature] = useState(300);
  const [pressure, setPressure] = useState(200);
  const moles = 0.1;
  const [openEx, setOpenEx] = useState<number | null>(null);
  const [activeCurricula, setActiveCurricula] = useState(['WAEC', 'IGCSE']);

  const derivedPressure = idealGasPressure(moles, temperature, volume) / 1000;
  const derivedVolume = charlesNewVolume(3, 300, temperature);

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
                <p className="text-xs text-gray-400 mb-1">Thermal physics</p>
                <h1 className="text-lg sm:text-xl font-semibold text-gray-900">Gas laws</h1>
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

          {/* Law tabs */}
          <div className="flex gap-1 bg-gray-100 p-1 rounded-xl w-full sm:w-fit">
            {(['boyle', 'charles'] as Law[]).map(l => (
              <button key={l} onClick={() => setLaw(l)}
                className={`flex-1 sm:flex-none px-4 sm:px-5 py-2 rounded-lg text-xs sm:text-sm font-medium transition ${
                  law === l ? 'bg-white text-indigo-700 shadow-sm' : 'text-gray-500 hover:text-gray-700'
                }`}>
                {l === 'boyle' ? "Boyle's Law" : "Charles' Law"}
              </button>
            ))}
          </div>

          {/* Key equation pill */}
          <div className="inline-flex items-center gap-3 rounded-xl border border-gray-200 bg-white px-4 py-2.5">
            <span className="text-xs text-gray-400">Key equation</span>
            <span className="text-sm font-semibold text-gray-900">
              {law === 'boyle' ? 'P₁V₁ = P₂V₂' : 'V₁/T₁ = V₂/T₂'}
            </span>
            <span className="text-xs text-gray-400">
              {law === 'boyle' ? 'constant T' : 'constant P, T in Kelvin'}
            </span>
          </div>

          {/* Main 3-col layout — stacks on mobile */}
          <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-4">

            {/* Canvas + sliders */}
            <div className="space-y-3">
              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide mb-3">
                  {law === 'boyle' ? 'Compression (constant T)' : 'Expansion (constant P)'}
                </p>
                {law === 'boyle'
                  ? <BoylesCanvas volume={volume} temperature={temperature} moles={moles} width={280} height={260} />
                  : <CharlesCanvas temperature={temperature} pressure={pressure} moles={moles} width={280} height={260} />
                }
              </div>

              {/* Sliders */}
              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm space-y-4">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide">Adjust</p>

                {law === 'boyle' ? (
                  <>
                    <div className="space-y-1.5">
                      <div className="flex justify-between text-xs">
                        <span className="text-gray-500">Volume</span>
                        <span className="font-medium tabular-nums">{volume.toFixed(1)} L</span>
                      </div>
                      <input type="range" min="0.5" max="10" step="0.1" value={volume}
                        onChange={e => setVolume(Number(e.target.value))}
                        className="w-full" style={{ accentColor: '#6366f1' }} />
                    </div>
                    <div className="space-y-1.5">
                      <div className="flex justify-between text-xs">
                        <span className="text-gray-500">Temperature (constant)</span>
                        <span className="font-medium tabular-nums">{temperature} K</span>
                      </div>
                      <input type="range" min="200" max="600" step="10" value={temperature}
                        onChange={e => setTemperature(Number(e.target.value))}
                        className="w-full" style={{ accentColor: '#f59e0b' }} />
                    </div>
                    <div className="rounded-xl bg-indigo-50 px-3 py-2.5 text-sm">
                      <span className="font-medium text-indigo-700">P = {derivedPressure.toFixed(1)} kPa</span>
                      <span className="text-indigo-400 text-xs ml-2">↑ as V decreases</span>
                    </div>
                  </>
                ) : (
                  <>
                    <div className="space-y-1.5">
                      <div className="flex justify-between text-xs">
                        <span className="text-gray-500">Temperature</span>
                        <span className="font-medium tabular-nums">{temperature} K ({temperature - 273}°C)</span>
                      </div>
                      <input type="range" min="100" max="600" step="10" value={temperature}
                        onChange={e => setTemperature(Number(e.target.value))}
                        className="w-full" style={{ accentColor: '#f59e0b' }} />
                    </div>
                    <div className="space-y-1.5">
                      <div className="flex justify-between text-xs">
                        <span className="text-gray-500">Pressure (constant)</span>
                        <span className="font-medium tabular-nums">{pressure} kPa</span>
                      </div>
                      <input type="range" min="50" max="500" step="10" value={pressure}
                        onChange={e => setPressure(Number(e.target.value))}
                        className="w-full" style={{ accentColor: '#10b981' }} />
                    </div>
                    <div className="rounded-xl bg-emerald-50 px-3 py-2.5 text-sm">
                      <span className="font-medium text-emerald-700">V = {derivedVolume.toFixed(2)} L</span>
                      <span className="text-emerald-400 text-xs ml-2">↑ as T increases</span>
                    </div>
                  </>
                )}
              </div>
            </div>

            {/* Graph */}
            <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
              <p className="text-xs font-medium text-gray-400 uppercase tracking-wide mb-1">
                {law === 'boyle' ? 'P–V graph' : 'V–T graph'}
              </p>
              <p className="text-xs text-gray-400 mb-4">
                {law === 'boyle'
                  ? 'Hyperbolic curve at constant T. Yellow dot = current state.'
                  : 'Straight line through 0 K. Yellow dot = current state.'}
              </p>
              <GasLawGraph law={law} currentV={volume} currentP={derivedPressure} currentT={temperature} moles={moles} />

              {/* Real world */}
              <div className="mt-4 rounded-xl border border-indigo-100 bg-indigo-50 p-3">
                <p className="text-xs font-medium text-indigo-600 mb-2">Real world</p>
                {law === 'boyle' ? (
                  <ul className="space-y-1 text-xs text-indigo-800">
                    <li>🤿 Scuba diving — gas expands as diver ascends</li>
                    <li>🩺 Breathing — lungs expand to reduce pressure</li>
                    <li>💉 Syringes — pulling back creates low pressure</li>
                  </ul>
                ) : (
                  <ul className="space-y-1 text-xs text-indigo-800">
                    <li>🎈 Hot air balloons — heat expands gas, reduces density</li>
                    <li>🚗 Car tyres — overinflate in summer heat</li>
                    <li>🍞 Bread rising — CO₂ expands in the oven</li>
                  </ul>
                )}
              </div>
            </div>

            {/* Teacher notes + exercises */}
            <div className="space-y-3 md:col-span-2 xl:col-span-1">
              <div className="rounded-2xl border border-amber-100 bg-amber-50 p-4">
                <p className="text-xs font-medium text-amber-700 uppercase tracking-wide mb-2">📋 Teacher notes</p>
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

              {/* Curriculum tags */}
              <div className="rounded-2xl border border-gray-100 bg-white p-4">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide mb-2">Curriculum</p>
                <div className="flex flex-wrap gap-1.5">
                  {CURRICULA.map(c => (
                    <span key={c} className={`text-xs font-medium px-2.5 py-0.5 rounded-full ${
                      activeCurricula.includes(c) ? CURRICULUM_COLORS[c] : 'bg-gray-100 text-gray-400'
                    }`}>{c}</span>
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
