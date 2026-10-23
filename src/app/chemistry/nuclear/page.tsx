'use client';
import { useMemo, useState } from 'react';
import Link from 'next/link';
import { AppHeader } from '@/components/layout/AppHeader';
import { EvidencePanel } from '@/components/chemistry/EvidencePanel';
import { NuclideChart } from '@/components/chemistry/NuclideChart';
import { DecayCurve } from '@/components/chemistry/DecayCurve';
import {
  AVOGADRO, MODE_LABEL, MODE_SHORT, SEC, applyDecay, balance, decayConstant, fmtNum, fmtTime, followChain, hints, label,
  lookup, nameOf, parseEquation, plainLabel, remainingFraction, sideText, symbolOf, timeToFraction,
  type Mode, type TimeUnit,
} from '@/lib/chemistry/nuclear';
import { ELEMENTS } from '@/lib/chemistry/elements';

const MODES: Mode[] = ['A', 'B-', 'B+', 'EC', 'P', 'N', 'G'];
const NUCLIDE_PRESETS: [string, number, number][] = [
  ['U-238', 92, 238], ['C-14', 6, 14], ['K-40', 19, 40], ['Co-60', 27, 60], ['F-18', 9, 18], ['Rn-222', 86, 222], ['Cs-137', 55, 137], ['H-3', 1, 3], ['n', 0, 1],
];
const EQ_EXAMPLES: [string, string][] = [
  ['U-235 fission', 'U-235 + n -> Ba-141 + Kr-92 + 3 n'],
  ['D–T fusion', 'H-2 + H-3 -> He-4 + n'],
  ['α decay', 'U-238 -> Th-234 + alpha'],
  ['β⁻ decay', 'C-14 -> N-14 + e- + anti-nu'],
  ['β⁺ decay', 'Na-22 -> Ne-22 + e+ + nu'],
  ['Electron capture', 'Be-7 + e- -> Li-7 + nu'],
  ['Missing antineutrino', 'C-14 -> N-14 + e-'],
];
const UNITS: TimeUnit[] = ['us', 'ms', 's', 'min', 'h', 'd', 'y'];
const UNIT_LABEL: Record<TimeUnit, string> = { us: 'µs', ms: 'ms', s: 's', min: 'min', h: 'h', d: 'days', y: 'years' };

function bestUnit(sec: number): { value: number; unit: TimeUnit } {
  for (const u of [...UNITS].reverse()) if (sec >= SEC[u]) return { value: Number((sec / SEC[u]).toPrecision(4)), unit: u };
  return { value: Number((sec / SEC.us).toPrecision(4)), unit: 'us' };
}

const Row = ({ k, v }: { k: string; v: React.ReactNode }) => (
  <div className="flex justify-between gap-3 border-b border-gray-100 py-1.5 text-xs last:border-0"><dt className="text-gray-500">{k}</dt><dd className="text-right font-medium text-gray-900">{v}</dd></div>
);
const Card = ({ children, title }: { children: React.ReactNode; title?: string }) => (
  <div className="rounded-2xl border border-gray-200 bg-white p-5">{title && <h2 className="mb-3 text-sm font-semibold text-gray-900">{title}</h2>}{children}</div>
);

function BalanceTable({ bal }: { bal: ReturnType<typeof balance> }) {
  const rows: [string, 'A' | 'Z' | 'L'][] = [['Nucleon number A', 'A'], ['Charge Z (in e)', 'Z'], ['Lepton number L', 'L']];
  return (
    <table className="w-full text-xs">
      <thead className="text-[10px] uppercase tracking-wide text-gray-400"><tr><th className="py-1 text-left font-medium">Conserved</th><th className="text-right font-medium">Left</th><th className="text-right font-medium">Right</th><th className="w-8" /></tr></thead>
      <tbody>
        {rows.map(([name, k]) => (
          <tr key={k} className="border-t border-gray-100">
            <td className="py-1.5 text-gray-600">{name}</td>
            <td className="text-right font-mono text-gray-900">{bal.left[k]}</td>
            <td className="text-right font-mono text-gray-900">{bal.right[k]}</td>
            <td className={`text-right font-semibold ${bal.ok[k] ? 'text-emerald-600' : 'text-red-600'}`} aria-label={bal.ok[k] ? 'conserved' : 'not conserved'}>{bal.ok[k] ? '✓' : '✗'}</td>
          </tr>
        ))}
      </tbody>
    </table>
  );
}

export default function NuclearPage() {
  const [nuc, setNuc] = useState({ z: 92, a: 238 });
  const [modeState, setModeState] = useState<{ key: string; mode: Mode } | null>(null);
  const [custom, setCustom] = useState<{ key: string; value: number; unit: TimeUnit } | null>(null);
  const [amountKind, setAmountKind] = useState<'mass' | 'atoms'>('mass');
  const [amount, setAmount] = useState(1);
  const [time, setTime] = useState(1);
  const [timeUnit, setTimeUnit] = useState<TimeUnit>('y');
  const [targetPct, setTargetPct] = useState(25);
  const [eq, setEq] = useState(EQ_EXAMPLES[0][1]);

  const { z, a } = nuc;
  const key = `${z}-${a}`;
  const ref = lookup(z, a);
  const hint = hints(z, a);
  const nameText = z === 0 ? 'Free neutron' : `${nameOf(z)}-${a}`;

  const defaultMode: Mode = ref?.modes[0]?.mode ?? (hint.delta < -0.9 ? 'B-' : hint.delta > 0.9 ? 'B+' : z >= 83 ? 'A' : 'B-');
  const mode = modeState?.key === key ? modeState.mode : defaultMode;
  const decay = applyDecay(z, a, mode);
  const chain = followChain(z, a);
  const reported = ref?.modes.find(m => m.mode === mode);
  const daughterRef = decay.daughter ? lookup(decay.daughter.z, decay.daughter.a) : undefined;

  // Half-life lab
  const refHL = ref?.t ?? null;
  const refBest = refHL ? bestUnit(refHL) : null;
  const hlValue = custom?.key === key ? custom.value : refBest?.value ?? 1;
  const hlUnit = custom?.key === key ? custom.unit : refBest?.unit ?? 'y';
  const T = custom?.key === key ? custom.value * SEC[custom.unit] : refHL;
  const tSec = time * SEC[timeUnit];
  const lab = (() => {
    if (!T || T <= 0 || !(tSec >= 0)) return null;
    const f = remainingFraction(tSec, T);
    const n0 = amountKind === 'atoms' ? amount : (amount / a) * AVOGADRO; // molar mass ≈ A g/mol
    const n = n0 * f;
    const lambda = decayConstant(T);
    const frac = Math.min(Math.max(targetPct / 100, 1e-12), 1);
    return { f, n0, n, lambda, act0: lambda * n0, act: lambda * n, massLeft: (n / AVOGADRO) * a, tTarget: timeToFraction(frac, T), tHalf: tSec / T };
  })();

  const parsed = useMemo(() => parseEquation(eq), [eq]);
  const eqBal = useMemo(() => (parsed.errors.length ? null : balance(parsed.left, parsed.right)), [parsed]);

  const choose = (zz: number, aa: number) => setNuc({ z: zz, a: Math.max(aa, zz, 1) });
  const setMode = (m: Mode) => setModeState({ key, mode: m });

  return (
    <>
      <AppHeader />
      <main className="min-h-screen bg-gray-50">
        <div className="mx-auto max-w-7xl px-4 py-6 sm:px-6">
          <Link href="/chemistry" className="text-xs text-gray-400 transition hover:text-indigo-600">← Chemistry</Link>
          <h1 className="mt-1 text-xl font-semibold text-gray-900 sm:text-2xl">Nuclear playground</h1>
          <p className="mb-5 mt-1 text-sm text-gray-500">Chemistry rearranges electrons; nuclear processes change the nucleus. Pick a nuclide, test decay modes against the conservation laws, and run the decay law. Balance tells you a process is <span className="font-medium text-gray-700">allowed by the bookkeeping</span> — not that it happens.</p>

          <div className="grid grid-cols-1 gap-5 lg:grid-cols-[minmax(0,1.2fr)_minmax(0,1fr)]">
            <div className="min-w-0 space-y-5">
              <Card>
                <NuclideChart selected={nuc} daughter={decay.daughter} onSelect={choose} />
              </Card>

              <Card title="Decay chain (bundled reference data)">
                <div className="flex flex-wrap items-center gap-1.5 text-xs">
                  {chain.steps.map((s, i) => (
                    <span key={i} className="flex items-center gap-1.5">
                      <button type="button" onClick={() => choose(s.z, s.a)} className={`rounded-md border px-2 py-1 ${s.z === z && s.a === a ? 'border-indigo-600 bg-indigo-50 text-indigo-800' : 'border-gray-200 text-gray-700 hover:border-indigo-300'}`}>
                        <span className="font-semibold">{label(s.z, s.a)}</span>
                        {s.t !== null && <span className="ml-1 text-[10px] text-gray-400">{fmtTime(s.t)}</span>}
                      </button>
                      {s.mode && <span className="text-[11px] text-gray-400">{MODE_SHORT[s.mode]} →</span>}
                    </span>
                  ))}
                </div>
                <p className="mt-2 text-[11px] text-gray-500">
                  {chain.end === 'stable' && `Ends at a stable nuclide after ${chain.steps.length - 1} step${chain.steps.length === 2 ? '' : 's'}.`}
                  {chain.end === 'unknown' && 'The chain stops where the bundled table has no entry — the nuclide may be stable or simply not listed here.'}
                  {chain.end === 'invalid' && 'The chain stops because the next daughter would not be a valid nucleus.'}
                  {chain.end === 'limit' && 'Stopped after 30 steps.'} Each step follows only the dominant reported mode; branching is ignored.
                </p>
              </Card>

              <Card title="Nuclear equation checker">
                <div className="mb-2 flex flex-wrap gap-2">
                  {EQ_EXAMPLES.map(([t, v]) => <button key={t} type="button" onClick={() => setEq(v)} className="rounded-full border border-gray-200 px-2.5 py-1 text-[11px] text-gray-700 hover:border-indigo-300 hover:text-indigo-700">{t}</button>)}
                </div>
                <label className="sr-only" htmlFor="eq">Nuclear equation</label>
                <input id="eq" value={eq} onChange={e => setEq(e.target.value)} spellCheck={false} className="h-10 w-full rounded-lg border border-gray-200 px-3 font-mono text-sm" placeholder="U-235 + n -> Ba-141 + Kr-92 + 3 n" />
                <p className="mt-1 text-[11px] text-gray-400">Write nuclides as U-235, 235U or ²³⁵U; particles as n, p, alpha, e-, e+, nu, anti-nu, gamma, d, t.</p>
                {parsed.errors.length > 0 ? (
                  <ul className="mt-3 space-y-1 rounded-lg bg-amber-50 px-3 py-2 text-xs text-amber-900">{parsed.errors.map(e => <li key={e}>{e}</li>)}</ul>
                ) : eqBal && (
                  <div className="mt-3">
                    <div className="rounded-lg bg-gray-50 px-3 py-2 text-center text-base text-gray-900">{sideText(parsed.left)} → {sideText(parsed.right)}</div>
                    <div className="mt-3"><BalanceTable bal={eqBal} /></div>
                    <p className={`mt-3 rounded-lg px-3 py-2 text-xs ${eqBal.balanced ? 'bg-emerald-50 text-emerald-900' : 'bg-red-50 text-red-800'}`}>
                      {eqBal.balanced ? 'Balanced: nucleon number, charge and lepton number are all conserved. Energy (Q-value) is not checked.' : `Not balanced: ${[!eqBal.ok.A && 'nucleon number', !eqBal.ok.Z && 'charge', !eqBal.ok.L && 'lepton number'].filter(Boolean).join(', ')} not conserved.`}
                    </p>
                  </div>
                )}
              </Card>
            </div>

            <div className="min-w-0 space-y-5">
              <Card>
                <div className="flex flex-wrap gap-2">
                  {NUCLIDE_PRESETS.map(([t, zz, aa]) => <button key={t} type="button" onClick={() => choose(zz, aa)} className={`rounded-full border px-2.5 py-1 text-[11px] ${z === zz && a === aa ? 'border-indigo-600 bg-indigo-600 text-white' : 'border-gray-200 bg-white text-gray-700 hover:border-indigo-300'}`}>{t}</button>)}
                </div>
                <div className="mt-3 flex gap-2">
                  <label className="flex-1 text-[11px] text-gray-500">Element
                    <select value={z} onChange={e => choose(Number(e.target.value), a)} className="mt-1 h-8 w-full rounded-md border border-gray-200 bg-white px-2 text-sm">
                      <option value={0}>n — Neutron</option>
                      {ELEMENTS.map(el => <option key={el.z} value={el.z}>{el.symbol} — {el.name} (Z={el.z})</option>)}
                    </select>
                  </label>
                  <label className="w-24 text-[11px] text-gray-500">Mass no. A
                    <input type="number" min={Math.max(1, z)} max={300} value={a} onChange={e => choose(z, Math.round(Number(e.target.value)) || 1)} className="mt-1 h-8 w-full rounded-md border border-gray-200 px-2 text-sm" />
                  </label>
                </div>
                <div className="mt-4 flex items-baseline gap-3">
                  <span className="text-4xl font-semibold text-gray-900">{label(z, a)}</span>
                  <span className="text-sm text-gray-500">{nameText}</span>
                </div>
                <dl className="mt-2">
                  <Row k="Protons / neutrons" v={`${z} / ${a - z}`} />
                  <Row k="N/Z" v={z ? (((a - z) / z)).toFixed(2) : '—'} />
                  {ref ? <>
                    <Row k="Half-life" v={ref.t === null ? 'Stable (observationally)' : fmtTime(ref.t)} />
                    <Row k="Reported decay" v={ref.modes.length ? ref.modes.map(m => `${MODE_SHORT[m.mode]}${m.pct ? ` ${m.pct}%` : ''}`).join(', ') : '—'} />
                  </> : <Row k="Reference data" v="None bundled" />}
                </dl>
                {ref?.note && <p className="mt-1 text-[11px] text-gray-500">{ref.note}</p>}
                {!ref && <p className="mt-2 rounded-lg bg-amber-50 px-3 py-2 text-[11px] text-amber-900">No half-life or decay mode is bundled for {plainLabel(z, a)}. Look it up in NUBASE / ENSDF (e.g. NNDC NuDat or the IAEA Live Chart of Nuclides) before relying on any value. The rule-of-thumb hint below is not data.</p>}
                <p className="mt-3 text-[11px] leading-relaxed text-gray-500"><span className="font-medium text-gray-700">Rule of thumb:</span> {hint.lines.join(' ')} <span className="text-gray-400">(stability line at Z ≈ {hint.zs.toFixed(1)} for A = {a})</span></p>
              </Card>

              <Card title="Decay explorer">
                <div className="flex flex-wrap gap-1.5">
                  {MODES.map(m => <button key={m} type="button" onClick={() => setMode(m)} className={`rounded-md border px-2.5 py-1 text-xs ${mode === m ? 'border-indigo-600 bg-indigo-600 text-white' : 'border-gray-200 text-gray-700 hover:border-indigo-300'}`} title={MODE_LABEL[m]}>{MODE_SHORT[m]}</button>)}
                </div>
                <p className="mt-1 text-[11px] text-gray-400">{MODE_LABEL[mode]}</p>
                <div className="mt-3 rounded-lg bg-gray-50 px-3 py-3 text-center text-base text-gray-900" aria-live="polite">{sideText(decay.left)} → {sideText(decay.right)}</div>
                {decay.issues.length > 0 && <ul className="mt-2 space-y-1 rounded-lg bg-red-50 px-3 py-2 text-xs text-red-800">{decay.issues.map(i => <li key={i}>{i}</li>)}</ul>}
                <div className="mt-3"><BalanceTable bal={decay.bal} /></div>
                <div className="mt-3 space-y-1.5 text-[11px] leading-relaxed">
                  <p className={`rounded-lg px-3 py-2 ${reported ? 'bg-emerald-50 text-emerald-900' : 'bg-gray-50 text-gray-700'}`}>
                    {reported ? `${MODE_SHORT[mode]} is a reported decay mode of ${plainLabel(z, a)}${reported.pct ? ` (≈ ${reported.pct}% branch)` : ''}.`
                      : ref ? (ref.t === null ? `${plainLabel(z, a)} is listed as stable, so this decay is not observed — it balances on paper only.` : `${MODE_SHORT[mode]} is not a reported mode for ${plainLabel(z, a)} in the bundled table.`)
                      : 'No reference data for this nuclide, so there is nothing to compare this mode against.'}
                  </p>
                  <p className="px-1 text-gray-500">Conservation laws are necessary, not sufficient: the decay must also release energy (Q &gt; 0), which is not computed here.</p>
                </div>
                {decay.daughter && (
                  <button type="button" onClick={() => choose(decay.daughter!.z, decay.daughter!.a)} className="mt-3 rounded-lg border border-gray-200 px-3 py-1.5 text-xs text-gray-700 hover:border-indigo-300">
                    Go to daughter {plainLabel(decay.daughter.z, decay.daughter.a)}{daughterRef ? (daughterRef.t === null ? ' (stable)' : ` (${fmtTime(daughterRef.t)})`) : ''} →
                  </button>
                )}
              </Card>

              <Card title="Half-life lab">
                <div className="grid grid-cols-2 gap-3 text-[11px] text-gray-500">
                  <div className="col-span-2">Half-life
                    <div className="mt-1 flex gap-2">
                      <input type="number" min={0} step="any" value={hlValue} onChange={e => setCustom({ key, value: Number(e.target.value), unit: hlUnit })} className="h-8 w-full rounded-md border border-gray-200 px-2 text-sm text-gray-900" aria-label="Half-life value" />
                      <select value={hlUnit} onChange={e => setCustom({ key, value: hlValue, unit: e.target.value as TimeUnit })} className="h-8 rounded-md border border-gray-200 bg-white px-2 text-sm text-gray-900" aria-label="Half-life unit">{UNITS.map(u => <option key={u} value={u}>{UNIT_LABEL[u]}</option>)}</select>
                    </div>
                    <span className="mt-1 block text-gray-400">{custom?.key === key ? 'Your value. ' : refHL ? 'From the bundled reference. ' : 'No bundled value — enter one. '}{custom?.key === key && refHL ? <button type="button" className="text-indigo-600 hover:underline" onClick={() => setCustom(null)}>Reset to reference</button> : null}</span>
                  </div>
                  <div>Initial amount
                    <div className="mt-1 flex gap-1.5">
                      <input type="number" min={0} step="any" value={amount} onChange={e => setAmount(Number(e.target.value))} className="h-8 w-full rounded-md border border-gray-200 px-2 text-sm text-gray-900" aria-label="Initial amount" />
                      <select value={amountKind} onChange={e => setAmountKind(e.target.value as 'mass' | 'atoms')} className="h-8 rounded-md border border-gray-200 bg-white px-1 text-sm text-gray-900"><option value="mass">g</option><option value="atoms">atoms</option></select>
                    </div>
                  </div>
                  <div>Elapsed time
                    <div className="mt-1 flex gap-1.5">
                      <input type="number" min={0} step="any" value={time} onChange={e => setTime(Number(e.target.value))} className="h-8 w-full rounded-md border border-gray-200 px-2 text-sm text-gray-900" aria-label="Elapsed time" />
                      <select value={timeUnit} onChange={e => setTimeUnit(e.target.value as TimeUnit)} className="h-8 rounded-md border border-gray-200 bg-white px-1 text-sm text-gray-900">{UNITS.map(u => <option key={u} value={u}>{UNIT_LABEL[u]}</option>)}</select>
                    </div>
                  </div>
                </div>

                {!lab ? (
                  <p className="mt-3 rounded-lg bg-amber-50 px-3 py-2 text-xs text-amber-900">Enter a positive half-life and a non-negative time to run the decay law.</p>
                ) : (
                  <>
                    <div className="mt-3"><DecayCurve tHalf={lab.tHalf} /></div>
                    <dl className="mt-3">
                      <Row k="Elapsed" v={`${fmtNum(lab.tHalf, 4)} half-lives`} />
                      <Row k="Fraction remaining N/N₀" v={`${fmtNum(lab.f, 4)} (${fmtNum(lab.f * 100, 4)} %)`} />
                      <Row k="Nuclei remaining" v={fmtNum(lab.n, 4)} />
                      <Row k="Mass remaining (≈ A g/mol)" v={`${fmtNum(lab.massLeft, 4)} g`} />
                      <Row k="Decay constant λ" v={`${fmtNum(lab.lambda, 4)} s⁻¹`} />
                      <Row k="Activity now / initially" v={`${fmtNum(lab.act, 4)} / ${fmtNum(lab.act0, 4)} Bq`} />
                    </dl>
                    <div className="mt-3 flex flex-wrap items-center gap-2 text-xs text-gray-600">
                      Time until
                      <input type="number" min={0.0001} max={100} step="any" value={targetPct} onChange={e => setTargetPct(Number(e.target.value))} className="h-7 w-20 rounded-md border border-gray-200 px-2 text-sm" aria-label="Percent remaining" />
                      % remains:
                      <span className="font-semibold text-gray-900">{targetPct > 0 && targetPct <= 100 ? fmtTime(lab.tTarget) : '—'}</span>
                    </div>
                    <p className="mt-2 text-[11px] text-gray-400">N = N₀·2^(−t/T½) for a single nuclide with no ingrowth from parents. Mass uses A g/mol as the molar mass.</p>
                  </>
                )}
              </Card>

              <EvidencePanel
                candidate="You chose this nuclide, decay mode or equation. Writing a balanced equation does not mean the process is observed."
                rule={{ label: `Conservation of nucleon number, charge and lepton number (${decay.bal.balanced ? 'balanced for the selected decay' : 'check the selected decay'}). Rule-of-thumb stability hints are not data.`, ok: decay.bal.balanced }}
                database={{ state: ref ? 'warn' : 'no', text: ref ? 'Half-life and decay modes come from a small hand-bundled table of ~70 well-known nuclides, rounded. Verify against NUBASE / ENSDF before quoting.' : 'No bundled data for this nuclide. Check NUBASE / ENSDF (NNDC NuDat, IAEA Live Chart).' }}
                calculated={{ state: 'no', text: 'No Q-values, binding energies or branching ratios are computed; only the decay law is evaluated.' }}
              />
              <p className="px-1 text-[10px] text-gray-400">Symbol check: {symbolOf(z)} · units of the decay lab convert with 1 y = 365.25 d.</p>
            </div>
          </div>
        </div>
      </main>
    </>
  );
}
