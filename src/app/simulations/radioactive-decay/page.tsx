'use client';
import { useState, useCallback, useEffect, useRef } from 'react';
import { AppHeader } from '@/components/layout/AppHeader';
import { SimulationControls } from '@/components/simulation/SimulationControls';
import { DecayCanvas, DecayGraph } from '@/components/simulation/DecayCanvas';
import { EmbedButton } from '@/components/ui/EmbedButton';
import { decayConstant, activity, remaining } from '@/lib/physics/decay';

const CURRICULA = ['WAEC', 'NECO', 'IGCSE', 'SAT', 'JUPEB'];
const CC: Record<string, string> = {
  WAEC: 'bg-indigo-100 text-indigo-700', NECO: 'bg-pink-100 text-pink-700',
  IGCSE: 'bg-emerald-100 text-emerald-700', SAT: 'bg-orange-100 text-orange-700',
  JUPEB: 'bg-purple-100 text-purple-700',
};

const TEACHER_NOTES = [
  'Decay is RANDOM for one nucleus but statistically predictable for many — the red measured dot scatters around the smooth blue theory curve, and the scatter shrinks as N₀ grows.',
  'After each half-life exactly half of what remains decays: N₀ → N₀/2 → N₀/4 → N₀/8 … the dashed gridlines mark 1T½, 2T½, 3T½.',
  'The decay constant λ = ln2/T½ is the probability per second that any one nucleus decays. Activity A = λN falls with the same half-life as N.',
  'Nothing changes the half-life — not temperature, pressure, or chemistry. It is a nuclear property.',
  'Carbon-14 dating: living things maintain constant C-14; after death it halves every 5730 years. Measuring the remaining fraction gives the age.',
];

const EXERCISES = [
  { q: 'A sample has half-life 8s and starts with 640 nuclei. How many remain after 24s?', a: '24s = 3 half-lives. 640 → 320 → 160 → 80 nuclei.' },
  { q: 'The activity of a source falls from 1200Bq to 150Bq in 36 minutes. Find the half-life.', a: '1200→600→300→150 is 3 halvings, so T½ = 36/3 = 12 minutes.' },
  { q: 'A sample of half-life 5730 years retains 25% of its C-14. How old is it?', a: '25% = (1/2)² → 2 half-lives → 2 × 5730 = 11460 years.' },
  { q: 'Find the decay constant of a nuclide with T½ = 10s, and the activity of 400 nuclei.', a: 'λ = ln2/10 = 0.0693 s⁻¹. A = λN = 0.0693 × 400 ≈ 27.7 decays/s.' },
];

function Slider({ label, unit, value, min, max, step, set, color, note }: {
  label: string; unit: string; value: number; min: number; max: number;
  step: number; set: (v: number) => void; color: string; note?: string;
}) {
  return (
    <div className="space-y-1.5">
      <div className="flex justify-between text-xs">
        <span className="text-gray-500">{label}</span>
        <span className="font-medium tabular-nums text-gray-800">{value} <span className="text-gray-400 font-normal">{unit}</span></span>
      </div>
      <input type="range" min={min} max={max} step={step} value={value}
        onChange={e => set(Number(e.target.value))} className="w-full" style={{ accentColor: color }} />
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

export default function RadioactiveDecayPage() {
  const [isRunning, setIsRunning] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const [resetKey, setResetKey] = useState(0);
  const [openEx, setOpenEx] = useState<number | null>(null);
  const [activeCurricula, setActiveCurricula] = useState(['WAEC', 'IGCSE', 'JUPEB']);

  const [n0, setN0] = useState(400);
  const [halfLife, setHalfLife] = useState(5);
  const [live, setLive] = useState({ t: 0, n: 400 });

  const resetTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const reset = useCallback(() => {
    setIsRunning(false); setIsPaused(false);
    setResetKey(k => k + 1); setLive({ t: 0, n: n0 });
  }, [n0]);
  useEffect(() => {
    if (resetTimer.current) clearTimeout(resetTimer.current);
    resetTimer.current = setTimeout(reset, 80);
  }, [n0, halfLife, reset]);

  // Throttle graph updates (same pattern as SHM) — canvas has its own rAF loop.
  const lastTickRef = useRef(0);
  const handleTick = useCallback((t: number, n: number) => {
    const now = performance.now();
    if (now - lastTickRef.current > 40) {
      lastTickRef.current = now;
      setLive({ t, n });
    }
  }, []);

  const lam = decayConstant(halfLife);

  return (
    <>
      <AppHeader />
      <main className="min-h-screen bg-gray-50">
        <section className="border-b border-gray-200 bg-white">
          <div className="mx-auto max-w-7xl px-4 sm:px-6 py-4">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
              <div>
                <p className="text-xs text-gray-400 mb-0.5">Modern physics</p>
                <h1 className="text-lg font-semibold text-gray-900">Radioactive decay</h1>
              </div>
              <div className="flex gap-1.5 flex-wrap">
                {CURRICULA.map(c => (
                  <button key={c}
                    onClick={() => setActiveCurricula(p => p.includes(c) ? p.filter(x => x !== c) : [...p, c])}
                    className={`text-xs px-2.5 py-1 rounded-full border font-medium transition ${
                      activeCurricula.includes(c) ? CC[c] + ' border-transparent' : 'bg-white text-gray-400 border-gray-200'
                    }`}>{c}</button>
                ))}
              </div>
            </div>
          </div>
        </section>

        <div className="mx-auto max-w-7xl px-4 sm:px-6 py-4 space-y-4">
          <div className="flex flex-wrap items-center gap-3 rounded-xl border border-gray-200 bg-white px-4 py-2.5">
            <span className="text-xs text-gray-400">Random decay, predictable statistics</span>
            <span className="text-sm font-semibold font-mono text-gray-900">N = N₀ · 2^(−t/T½)</span>
            <span className="text-xs text-gray-400 ml-2">λ = ln2/T½ &nbsp;|&nbsp; A = λN</span>
          </div>

          <div className="grid grid-cols-1 lg:grid-cols-[1fr_220px] xl:grid-cols-[1fr_220px_260px] gap-4">
            <div className="space-y-3 min-w-0">
              <div className="rounded-2xl border border-gray-200 bg-white p-3 shadow-sm">
                <DecayCanvas n0={n0} halfLife={halfLife} resetKey={resetKey}
                  isRunning={isRunning} isPaused={isPaused}
                  onTick={handleTick} width={640} height={300} />
              </div>

              <div className="flex flex-wrap items-center justify-between gap-2">
                <SimulationControls isRunning={isRunning} isPaused={isPaused}
                  onRun={() => { setIsRunning(true); setIsPaused(false); }}
                  onPause={() => setIsPaused(p => !p)} onReset={reset} />
                <EmbedButton path="/embed/decay"
                  title="Radioactive decay — A-Factor STEM Studio"
                  params={{ n0, hl: halfLife }} />
              </div>

              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide mb-2">Decay curve N–t</p>
                <DecayGraph n0={n0} halfLife={halfLife} currentT={live.t} currentN={live.n} />
                <p className="text-[10px] text-gray-400 mt-2 text-center">
                  Blue dot: theory N₀·2^(−t/T½) — Red dot: your random sample. They agree better with larger N₀.
                </p>
              </div>

              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm space-y-4">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide">Parameters</p>
                <Slider label="Initial nuclei N₀" unit="" value={n0} min={50} max={900} step={50} set={setN0} color="#6366f1"
                  note="Larger samples follow the theory curve more closely" />
                <Slider label="Half-life T½" unit="s" value={halfLife} min={1} max={20} step={0.5} set={setHalfLife} color="#f59e0b" />
              </div>
            </div>

            <div className="space-y-3">
              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide mb-3">Calculated</p>
                <div className="space-y-2">
                  <StatRow label="Decay constant λ" value={lam.toFixed(4)} unit="s⁻¹" color="text-indigo-600" />
                  <StatRow label="Initial activity" value={activity(n0, halfLife).toFixed(1)} unit="Bq" color="text-emerald-600" />
                  <StatRow label="N after 1 T½" value={(n0 / 2).toFixed(0)} unit="" color="text-amber-600" />
                  <StatRow label="N after 2 T½" value={(n0 / 4).toFixed(0)} unit="" color="text-rose-500" />
                  <StatRow label="N after 3 T½" value={(n0 / 8).toFixed(0)} unit="" color="text-purple-600" />
                  {live.t > 0 && (
                    <StatRow label={`Theory at t=${live.t.toFixed(1)}s`} value={remaining(n0, halfLife, live.t).toFixed(0)} unit="" color="text-gray-600" />
                  )}
                </div>
              </div>

              <div className="rounded-2xl border border-gray-100 bg-white p-4">
                <p className="text-xs text-gray-400 mb-2">Curriculum</p>
                <div className="flex flex-wrap gap-1.5">
                  {CURRICULA.map(c => (
                    <span key={c} className={`text-xs font-medium px-2 py-0.5 rounded-full ${
                      activeCurricula.includes(c) ? CC[c] : 'bg-gray-100 text-gray-400'
                    }`}>{c}</span>
                  ))}
                </div>
              </div>
            </div>

            <div className="space-y-3 lg:col-span-2 xl:col-span-1">
              <div className="rounded-2xl border border-amber-100 bg-amber-50 p-4">
                <p className="text-xs font-medium text-amber-700 uppercase tracking-wide mb-3">📋 Teacher notes</p>
                <ul className="space-y-2">
                  {TEACHER_NOTES.map((n, i) => (
                    <li key={i} className="text-xs text-amber-900 leading-relaxed flex gap-2">
                      <span className="text-amber-400 shrink-0 mt-0.5">•</span>{n}
                    </li>
                  ))}
                </ul>
              </div>

              <div className="rounded-2xl border border-gray-200 bg-white p-4">
                <p className="text-xs font-medium text-gray-500 uppercase tracking-wide mb-3">✏️ Exercises</p>
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
              </div>
            </div>
          </div>
        </div>
      </main>
    </>
  );
}
