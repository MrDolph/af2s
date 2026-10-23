'use client';
import { useEffect, useMemo, useState } from 'react';
import Link from 'next/link';
import { AppHeader } from '@/components/layout/AppHeader';
import { PeriodicTable } from '@/components/chemistry/PeriodicTable';
import { EvidencePanel } from '@/components/chemistry/EvidencePanel';
import { CandidatesPanel } from '@/components/chemistry/CandidatesPanel';
import { BY_SYMBOL, type Element } from '@/lib/chemistry/elements';
import {
  chargeBalance, cleanComposition, formulaOf, formulaPlain, massFractions, molarMass, orderedSymbols, reduce, type Composition,
} from '@/lib/chemistry/compound';
import { fmtCharge } from '@/lib/chemistry/perovskite';
import { saveCandidate, type Candidate } from '@/lib/chemistry/candidates';

const PRESETS: { label: string; c: Composition }[] = [
  { label: 'NaMgBr₃', c: { Na: 1, Mg: 1, Br: 3 } },
  { label: 'NaCl', c: { Na: 1, Cl: 1 } },
  { label: 'H₂O', c: { H: 2, O: 1 } },
  { label: 'Fe₂O₃', c: { Fe: 2, O: 3 } },
  { label: 'CsPbBr₃', c: { Cs: 1, Pb: 1, Br: 3 } },
  { label: 'C₆H₁₂O₆', c: { C: 6, H: 12, O: 6 } },
];

function parseComp(s: string): Composition {
  const out: Composition = {};
  for (const part of s.split(',')) {
    const [sym, n] = part.split(':');
    if (BY_SYMBOL[sym]) out[sym] = Math.max(1, Math.min(999, parseInt(n ?? '1', 10) || 1));
  }
  return out;
}

export default function CompoundBuilderPage() {
  const [comp, setComp] = useState<Composition>({});
  const [last, setLast] = useState<Element | null>(null);
  const [saved, setSaved] = useState(false);
  const [copied, setCopied] = useState(false);

  // Accept ?add=Na (from the periodic table) or ?c=Na:1,Mg:1,Br:3.
  useEffect(() => {
    // Deferred one tick: the URL is an external system read after hydration.
    const t = setTimeout(() => {
      const q = new URLSearchParams(window.location.search);
      const c = q.get('c'), add = q.get('add');
      if (c) setComp(parseComp(c));
      else if (add && BY_SYMBOL[add]) setComp({ [add]: 1 });
    }, 0);
    return () => clearTimeout(t);
  }, []);

  const clean = useMemo(() => cleanComposition(comp), [comp]);
  const syms = orderedSymbols(clean);
  const mass = molarMass(clean);
  const reduced = reduce(clean);
  const balance = useMemo(() => chargeBalance(clean), [clean]);
  const fractions = massFractions(clean);
  const empirical = formulaOf(reduced);
  const touch = () => { setSaved(false); setCopied(false); };

  const add = (el: Element) => { setLast(el); touch(); setComp(c => ({ ...c, [el.symbol]: Math.min(999, (c[el.symbol] ?? 0) + 1) })); };
  const setCount = (s: string, n: number) => { touch(); setComp(c => { const next = { ...c }; if (n <= 0 || !Number.isFinite(n)) delete next[s]; else next[s] = Math.min(999, Math.round(n)); return next; }); };

  const perovskiteLink = useMemo(() => {
    if (syms.length !== 3) return null;
    const byEn = [...syms].sort((a, b) => (BY_SYMBOL[a].en ?? 9) - (BY_SYMBOL[b].en ?? 9));
    return `/chemistry/perovskite-lab?A=${byEn[0]}&B=${byEn[1]}&X=${byEn[2]}`;
  }, [syms]);

  const chargeLabel = balance.status === 'balanced' ? 'Balanced (rule of thumb)' : balance.status === 'unbalanced' ? 'No balance found' : balance.message;

  const onSave = () => {
    if (!syms.length) return;
    saveCandidate({ name: formulaPlain(clean), kind: 'composition', formula: formulaPlain(clean), composition: clean, molarMass: mass, chargeStatus: chargeLabel });
    setSaved(true);
  };
  const onLoad = (c: Candidate) => { setComp(c.composition); touch(); };

  return (
    <>
      <AppHeader />
      <main className="min-h-screen bg-gray-50">
        <div className="mx-auto max-w-7xl px-4 py-6 sm:px-6">
          <Link href="/chemistry" className="text-xs text-gray-400 transition hover:text-indigo-600">← Chemistry</Link>
          <h1 className="mt-1 text-xl font-semibold text-gray-900 sm:text-2xl">Compound builder</h1>
          <p className="mb-5 mt-1 text-sm text-gray-500">Click elements to add atoms. The result is a <span className="font-medium text-gray-700">candidate composition</span>, not a claim that it exists.</p>

          <div className="grid gap-5 lg:grid-cols-[minmax(0,1.5fr)_minmax(0,1fr)]">
            <div className="space-y-5">
              <div className="rounded-2xl border border-gray-200 bg-white p-4">
                <PeriodicTable onPick={add} counts={clean} compact showLegend={false} />
                {last && <p className="mt-2 text-[11px] text-gray-400">Added {last.name} ({last.symbol}).</p>}
              </div>
              <div className="rounded-2xl border border-gray-200 bg-white p-4">
                <div className="text-[11px] font-medium uppercase tracking-wide text-gray-400">Presets</div>
                <div className="mt-2 flex flex-wrap gap-2">
                  {PRESETS.map(p => (
                    <button key={p.label} type="button" onClick={() => { touch(); setComp(p.c); }} className="rounded-full border border-gray-200 bg-white px-3 py-1 text-xs text-gray-700 transition hover:border-indigo-300 hover:text-indigo-700">{p.label}</button>
                  ))}
                </div>
              </div>
              <CandidatesPanel onLoad={onLoad} />
            </div>

            <div className="space-y-5">
              <div className="rounded-2xl border border-gray-200 bg-white p-5">
                <div className="flex items-start justify-between gap-3">
                  <div>
                    <div className="text-[11px] font-medium uppercase tracking-wide text-gray-400">Formula</div>
                    <div className="mt-0.5 min-h-[2.5rem] text-3xl font-semibold text-gray-900" aria-live="polite">{syms.length ? formulaOf(clean) : '—'}</div>
                  </div>
                  {syms.length > 0 && <button type="button" onClick={() => { touch(); setComp({}); }} className="text-xs text-gray-400 hover:text-red-600">Clear</button>}
                </div>

                {syms.length === 0 ? (
                  <p className="mt-3 text-xs text-gray-500">Pick an element from the table to begin.</p>
                ) : (
                  <>
                    <ul className="mt-3 divide-y divide-gray-100">
                      {syms.map(s => (
                        <li key={s} className="flex items-center gap-2 py-2">
                          <span className="w-8 text-sm font-semibold text-gray-900">{s}</span>
                          <span className="flex-1 truncate text-xs text-gray-500">{BY_SYMBOL[s].name}</span>
                          <button type="button" onClick={() => setCount(s, clean[s] - 1)} className="h-7 w-7 rounded-md border border-gray-200 text-gray-600 hover:border-indigo-300" aria-label={`Remove one ${s}`}>−</button>
                          <input type="number" min={0} max={999} value={clean[s]} onChange={e => setCount(s, Number(e.target.value))} className="h-7 w-14 rounded-md border border-gray-200 text-center text-sm" aria-label={`${s} atom count`} />
                          <button type="button" onClick={() => setCount(s, clean[s] + 1)} className="h-7 w-7 rounded-md border border-gray-200 text-gray-600 hover:border-indigo-300" aria-label={`Add one ${s}`}>+</button>
                        </li>
                      ))}
                    </ul>

                    <dl className="mt-3 grid grid-cols-2 gap-3 text-xs">
                      <div><dt className="text-gray-400">Molar mass</dt><dd className="text-base font-semibold text-gray-900">{mass.toFixed(3)} g/mol</dd></div>
                      <div><dt className="text-gray-400">Empirical formula</dt><dd className="text-base font-semibold text-gray-900">{empirical}</dd></div>
                    </dl>

                    <div className="mt-3">
                      <div className="mb-1 text-[11px] text-gray-400">Mass percentage</div>
                      <div className="flex h-2 overflow-hidden rounded-full bg-gray-100">
                        {fractions.map((f, i) => <div key={f.symbol} style={{ width: `${f.fraction * 100}%` }} className={['bg-indigo-500', 'bg-emerald-500', 'bg-amber-500', 'bg-rose-500', 'bg-sky-500', 'bg-violet-500'][i % 6]} title={`${f.symbol} ${(f.fraction * 100).toFixed(1)}%`} />)}
                      </div>
                      <div className="mt-1 flex flex-wrap gap-x-3 text-[11px] text-gray-600">
                        {fractions.map(f => <span key={f.symbol}>{f.symbol} {(f.fraction * 100).toFixed(2)}%</span>)}
                      </div>
                    </div>

                    <div className={`mt-4 rounded-xl px-3 py-2.5 text-xs ${balance.status === 'balanced' ? 'bg-emerald-50 text-emerald-900' : 'bg-amber-50 text-amber-900'}`}>
                      <div className="font-medium">Charge balance: {chargeLabel}</div>
                      <p className="mt-0.5 opacity-90">{balance.message}</p>
                      {balance.solutions.length > 0 && (
                        <ul className="mt-1.5 space-y-0.5">
                          {balance.solutions.slice(0, 3).map((s, i) => (
                            <li key={i} className="font-mono text-[11px]">
                              {Object.entries(s.states).map(([el, q]) => `${el}${fmtCharge(q)}`).join('  ')}
                              {s.unusual > 0 && <span className="ml-2 font-sans text-amber-700">(less-common state)</span>}
                            </li>
                          ))}
                        </ul>
                      )}
                    </div>

                    <div className="mt-4 flex flex-wrap gap-2">
                      <button type="button" onClick={onSave} className="rounded-lg bg-indigo-600 px-3 py-1.5 text-xs font-medium text-white hover:bg-indigo-700">{saved ? 'Saved ✓' : 'Save candidate'}</button>
                      <button type="button" onClick={async () => { try { await navigator.clipboard.writeText(formulaPlain(clean)); setCopied(true); } catch { /* clipboard blocked */ } }} className="rounded-lg border border-gray-200 px-3 py-1.5 text-xs text-gray-700 hover:border-indigo-300">{copied ? 'Copied ✓' : 'Copy formula'}</button>
                      {perovskiteLink && <Link href={perovskiteLink} className="rounded-lg border border-gray-200 px-3 py-1.5 text-xs text-gray-700 hover:border-indigo-300">Open in perovskite lab →</Link>}
                    </div>
                  </>
                )}
              </div>
              {syms.length > 0 && <EvidencePanel rule={{ label: balance.status === 'balanced' ? 'Charge can balance with tabulated oxidation states.' : balance.message, ok: balance.status === 'balanced' ? true : balance.status === 'unbalanced' ? false : null }} />}
            </div>
          </div>
        </div>
      </main>
    </>
  );
}
