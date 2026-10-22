'use client';
import { useEffect, useMemo, useState } from 'react';
import Link from 'next/link';
import { AppHeader } from '@/components/layout/AppHeader';
import { CrystalViewer, type SiteStyle } from '@/components/chemistry/CrystalViewer';
import { EvidencePanel } from '@/components/chemistry/EvidencePanel';
import { CandidatesPanel } from '@/components/chemistry/CandidatesPanel';
import { ELEMENTS, BY_SYMBOL } from '@/lib/chemistry/elements';
import { molarMass, formulaOf, formulaPlain } from '@/lib/chemistry/compound';
import {
  MODELS, RADII_A_XII, RADII_B_VI, RADII_X_VI, analyseModel, availableStates, density, fmtCharge, key,
  toCif, withBoundaryImages, type ModelId, type Site, type ModelSites,
} from '@/lib/chemistry/perovskite';
import { saveCandidate, download, type Candidate } from '@/lib/chemistry/candidates';

type SiteKey = 'A' | 'B' | 'B2' | 'X';
type Pick = { symbol: string; charge: number };
type Sites = Record<SiteKey, Pick>;

const TABLE: Record<SiteKey, Record<string, number>> = { A: RADII_A_XII, B: RADII_B_VI, B2: RADII_B_VI, X: RADII_X_VI };
const SITE_NAME: Record<SiteKey, string> = { A: 'A site (12-coordinate)', B: 'B site (octahedral)', B2: 'B′ site (octahedral)', X: 'X site (anion)' };
const COLORS: Record<SiteKey, string> = { A: '#f59e0b', B: '#818cf8', B2: '#2dd4bf', X: '#f87171' };

interface Preset { label: string; model: ModelId; sites: Sites; note: string }
const p = (symbol: string, charge: number): Pick => ({ symbol, charge });
const PRESETS: Preset[] = [
  { label: 'NaMgBr₃', model: 'cubic', sites: { A: p('Na', 1), B: p('Mg', 2), B2: p('Ag', 1), X: p('Br', -1) },
    note: 'Your research candidate. Assembling the formula asserts nothing about stability; the geometric factors below are only a first screen.' },
  { label: 'CsPbBr₃', model: 'cubic', sites: { A: p('Cs', 1), B: p('Pb', 2), B2: p('Ag', 1), X: p('Br', -1) },
    note: 'Well-studied halide perovskite; reported cubic only at elevated temperature, distorted (orthorhombic) at room temperature. Verify in the literature.' },
  { label: 'CsSnI₃', model: 'cubic', sites: { A: p('Cs', 1), B: p('Sn', 2), B2: p('Ag', 1), X: p('I', -1) },
    note: 'Reported perovskite with tin(II), which oxidises readily; distorted at room temperature. Verify in the literature.' },
  { label: 'SrTiO₃', model: 'cubic', sites: { A: p('Sr', 2), B: p('Ti', 4), B2: p('Ag', 1), X: p('O', -2) },
    note: 'The textbook cubic oxide perovskite at room temperature — a good sanity check for t ≈ 1.' },
  { label: 'BaTiO₃', model: 'cubic', sites: { A: p('Ba', 2), B: p('Ti', 4), B2: p('Ag', 1), X: p('O', -2) },
    note: 'Cubic only above its Curie temperature; ferroelectric and non-cubic at room temperature.' },
  { label: 'CaTiO₃', model: 'cubic', sites: { A: p('Ca', 2), B: p('Ti', 4), B2: p('Ag', 1), X: p('O', -2) },
    note: 'The mineral perovskite: a tilted orthorhombic structure, so the cubic model here is only the idealised parent.' },
  { label: 'KMgF₃', model: 'cubic', sites: { A: p('K', 1), B: p('Mg', 2), B2: p('Ag', 1), X: p('F', -1) },
    note: 'Fluoroperovskite reported with a cubic structure; a useful comparison for NaMgBr₃ (same B cation, different A and X).' },
  { label: 'NaMgF₃', model: 'cubic', sites: { A: p('Na', 1), B: p('Mg', 2), B2: p('Ag', 1), X: p('F', -1) },
    note: 'Reported as a tilted orthorhombic perovskite; compare its t with NaMgBr₃ to see the effect of swapping F for Br.' },
  { label: 'Cs₂AgBiBr₆', model: 'double', sites: { A: p('Cs', 1), B: p('Ag', 1), B2: p('Bi', 3), X: p('Br', -1) },
    note: 'Lead-free double perovskite reported in the literature, with rock-salt B/B′ ordering.' },
];

function fromQuery(): Partial<Sites> | null {
  const q = new URLSearchParams(window.location.search);
  const out: Partial<Sites> = {};
  (['A', 'B', 'X'] as const).forEach(k => {
    const sym = q.get(k);
    if (sym && BY_SYMBOL[sym]) {
      const tab = availableStates(sym, k);
      const e = BY_SYMBOL[sym];
      const fallback = k === 'X' ? e.common.find(v => v < 0) : e.common.find(v => v > 0);
      out[k] = { symbol: sym, charge: tab[0] ?? fallback ?? (k === 'X' ? -1 : 1) };
    }
  });
  return Object.keys(out).length ? out : null;
}

function SitePicker({ site, value, onChange }: { site: SiteKey; value: Pick; onChange: (v: Pick) => void }) {
  const kind: 'A' | 'B' | 'X' = site === 'B2' ? 'B' : site;
  const withData = ELEMENTS.filter(e => availableStates(e.symbol, kind).length > 0);
  const others = ELEMENTS.filter(e => availableStates(e.symbol, kind).length === 0);
  const el = BY_SYMBOL[value.symbol];
  const wantNeg = kind === 'X';
  const states = Array.from(new Set([
    ...availableStates(value.symbol, kind),
    ...[...el.common, ...el.other].filter(v => (wantNeg ? v < 0 : v > 0)),
  ])).sort((a, b) => b - a);
  const r = TABLE[site][key(value.symbol, value.charge)];
  const pickEl = (sym: string) => {
    const e = BY_SYMBOL[sym];
    const tab = availableStates(sym, kind);
    const fb = (wantNeg ? e.common.find(v => v < 0) : e.common.find(v => v > 0)) ?? (wantNeg ? -1 : 1);
    onChange({ symbol: sym, charge: tab.includes(value.charge) ? value.charge : tab[0] ?? fb });
  };
  return (
    <div className="rounded-xl border border-gray-200 p-3">
      <div className="flex items-center gap-1.5 text-[11px] font-medium text-gray-500">
        <span className="inline-block h-2.5 w-2.5 rounded-full" style={{ background: COLORS[site] }} />{SITE_NAME[site]}
      </div>
      <div className="mt-2 flex gap-2">
        <select value={value.symbol} onChange={e => pickEl(e.target.value)} className="h-8 min-w-0 flex-1 rounded-md border border-gray-200 bg-white px-2 text-sm" aria-label={`${SITE_NAME[site]} element`}>
          <optgroup label="Radius data available">
            {withData.map(e => <option key={e.symbol} value={e.symbol}>{e.symbol} — {e.name}</option>)}
          </optgroup>
          <optgroup label="No radius data (factors unavailable)">
            {others.map(e => <option key={e.symbol} value={e.symbol}>{e.symbol} — {e.name}</option>)}
          </optgroup>
        </select>
        <select value={value.charge} onChange={e => onChange({ ...value, charge: Number(e.target.value) })} className="h-8 w-20 rounded-md border border-gray-200 bg-white px-2 text-sm" aria-label={`${SITE_NAME[site]} charge`}>
          {(states.length ? states : [value.charge]).map(q => <option key={q} value={q}>{fmtCharge(q)}</option>)}
        </select>
      </div>
      <div className="mt-1.5 text-[11px] text-gray-400">{r != null ? `Shannon radius ${r.toFixed(3)} Å` : 'No tabulated radius for this ion/site'}</div>
    </div>
  );
}

export default function PerovskiteLabPage() {
  const [model, setModel] = useState<ModelId>('cubic');
  const [sites, setSites] = useState<Sites>(PRESETS[0].sites);
  const [presetNote, setPresetNote] = useState<string | null>(PRESETS[0].note);
  const [n, setN] = useState(1);
  const [aMode, setAMode] = useState<'BX' | 'AX' | 'custom'>('BX');
  const [aCustom, setACustom] = useState(5.0);
  const [bonds, setBonds] = useState(true);
  const [cell, setCell] = useState(true);
  const [showA, setShowA] = useState(true);
  const [saved, setSaved] = useState(false);

  useEffect(() => {
    const t = setTimeout(() => {
      const q = fromQuery();
      if (q) {
        setSites(s => ({ ...s, ...q }));
        setPresetNote('Pre-filled from the compound builder (A = most electropositive, X = most electronegative). Check the assignment and oxidation states.');
      }
    }, 0);
    return () => clearTimeout(t);
  }, []);

  const double = model === 'double';
  const modelDef = MODELS[model];
  const modelSites: ModelSites = { A: sites.A, B: sites.B, B2: double ? sites.B2 : undefined, X: sites.X };
  const report = useMemo(() => analyseModel(model, modelSites),
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [model, sites, double]);

  const a = aMode === 'custom' ? aCustom : aMode === 'AX' ? report.aAX ?? aCustom : report.aBX ?? aCustom;
  const elements: Record<Site, string | undefined> = { A: sites.A.symbol, B: sites.B.symbol, B2: double ? sites.B2.symbol : undefined, X: sites.X.symbol };
  const dens = density(modelDef, a, elements);
  const mass = molarMass(report.composition);
  const chargeOk = Math.abs(report.chargeSum) < 1e-9;

  const atoms = useMemo(() => withBoundaryImages(modelDef.atoms, n), [modelDef, n]);
  const styles = useMemo(() => {
    const edge = a * modelDef.cellFactor;
    const mk = (k: SiteKey): SiteStyle => {
      const r = TABLE[k][key(sites[k].symbol, sites[k].charge)] ?? 0.9;
      return { label: sites[k].symbol, color: COLORS[k], radius: r / edge };
    };
    const out: Partial<Record<Site, SiteStyle>> = { A: mk('A'), B: mk('B'), X: mk('X') };
    if (double) out.B2 = mk('B2');
    return out;
  }, [sites, a, modelDef, double]);

  const setSite = (k: SiteKey, v: Pick) => { setSites(s => ({ ...s, [k]: v })); setSaved(false); setPresetNote(null); };
  const loadPreset = (pr: Preset) => { setModel(pr.model); setSites(pr.sites); setPresetNote(pr.note); setSaved(false); };

  const onSave = () => {
    saveCandidate({
      name: formulaPlain(report.composition) + (double ? ' (double)' : ''),
      kind: 'perovskite', formula: formulaPlain(report.composition), composition: report.composition, molarMass: mass,
      chargeStatus: chargeOk ? 'Charges sum to zero' : `Charge sum ${report.chargeSum > 0 ? '+' : ''}${report.chargeSum}`,
      perovskite: { model, sites: { A: sites.A, B: sites.B, B2: double ? sites.B2 : undefined, X: sites.X }, a, tolerance: report.tolerance, octahedral: report.octahedral, density: dens },
      note: presetNote ?? undefined,
    });
    setSaved(true);
  };
  const onLoad = (c: Candidate) => {
    if (c.perovskite) {
      setModel(c.perovskite.model);
      setSites(s => ({ ...s, ...(c.perovskite!.sites as Partial<Sites>) }));
      setAMode('custom'); setACustom(c.perovskite.a); setPresetNote(c.note ?? null);
    }
  };

  const fmt = (v: number | null, d = 3) => (v == null ? '—' : v.toFixed(d));

  return (
    <>
      <AppHeader />
      <main className="min-h-screen bg-gray-50">
        <div className="mx-auto max-w-7xl px-4 py-6 sm:px-6">
          <Link href="/chemistry" className="text-xs text-gray-400 transition hover:text-indigo-600">← Chemistry</Link>
          <h1 className="mt-1 text-xl font-semibold text-gray-900 sm:text-2xl">Perovskite lab</h1>
          <p className="mb-4 mt-1 text-sm text-gray-500">Assign A, B and X sites, check the geometry, and inspect an idealised model. Idealised models are proposals — not relaxed or confirmed structures.</p>

          <div className="mb-5 flex flex-wrap gap-2">
            {PRESETS.map(pr => (
              <button key={pr.label} type="button" onClick={() => loadPreset(pr)} className="rounded-full border border-gray-200 bg-white px-3 py-1 text-xs text-gray-700 transition hover:border-indigo-300 hover:text-indigo-700">{pr.label}</button>
            ))}
          </div>
          {presetNote && <p className="mb-5 rounded-xl border border-indigo-100 bg-indigo-50 px-3 py-2 text-xs text-indigo-900">{presetNote} <span className="opacity-70">Reference notes are summaries — check the primary literature before citing.</span></p>}

          <div className="grid gap-5 lg:grid-cols-[minmax(0,1.3fr)_minmax(0,1fr)]">
            <div className="space-y-5">
              <div className="rounded-2xl border border-gray-200 bg-white p-4">
                <CrystalViewer atoms={atoms} extent={n} styles={styles} bondDist={0.5 / modelDef.cellFactor} showBonds={bonds} showCell={cell} showA={showA} />
                <div className="mt-3 flex flex-wrap items-center gap-x-4 gap-y-2 border-t border-gray-100 pt-3 text-xs text-gray-600">
                  <label className="flex items-center gap-1.5"><input type="checkbox" checked={bonds} onChange={e => setBonds(e.target.checked)} />B–X bonds</label>
                  <label className="flex items-center gap-1.5"><input type="checkbox" checked={cell} onChange={e => setCell(e.target.checked)} />Cell edges</label>
                  <label className="flex items-center gap-1.5"><input type="checkbox" checked={showA} onChange={e => setShowA(e.target.checked)} />A atoms</label>
                  <span className="ml-auto flex items-center gap-1.5">Cells
                    {[1, 2].map(v => <button key={v} type="button" onClick={() => setN(v)} className={`rounded-md border px-2 py-0.5 ${n === v ? 'border-indigo-600 bg-indigo-600 text-white' : 'border-gray-200 hover:border-indigo-300'}`}>{v}×{v}×{v}</button>)}
                  </span>
                </div>
                <p className="mt-2 text-[11px] text-gray-400">{modelDef.label} · space group {modelDef.spaceGroup}. {modelDef.note}</p>
              </div>
              <CandidatesPanel onLoad={onLoad} />
            </div>

            <div className="space-y-5">
              <div className="rounded-2xl border border-gray-200 bg-white p-5">
                <div className="flex gap-2">
                  {(Object.keys(MODELS) as ModelId[]).map(id => (
                    <button key={id} type="button" onClick={() => { setModel(id); setSaved(false); }} className={`flex-1 rounded-lg border px-2 py-1.5 text-xs font-medium ${model === id ? 'border-indigo-600 bg-indigo-600 text-white' : 'border-gray-200 text-gray-600 hover:border-indigo-300'}`}>{id === 'cubic' ? 'ABX₃' : 'A₂BB′X₆'}</button>
                  ))}
                </div>
                <div className="mt-3 grid gap-3 sm:grid-cols-2">
                  {(['A', 'B', ...(double ? ['B2'] : []), 'X'] as SiteKey[]).map(k => <SitePicker key={k} site={k} value={sites[k]} onChange={v => setSite(k, v)} />)}
                </div>

                <div className="mt-4 text-[11px] font-medium uppercase tracking-wide text-gray-400">Candidate</div>
                <div className="text-3xl font-semibold text-gray-900" aria-live="polite">{formulaOf(report.composition)}</div>
                <div className="text-xs text-gray-500">{mass.toFixed(2)} g/mol per formula unit</div>

                <dl className="mt-3 divide-y divide-gray-100 text-xs">
                  <div className="flex justify-between py-1.5"><dt className="text-gray-500">Charge sum</dt><dd className={`font-medium ${chargeOk ? 'text-emerald-700' : 'text-red-600'}`}>{chargeOk ? '0 (balanced)' : `${report.chargeSum > 0 ? '+' : ''}${report.chargeSum} — not balanced`}</dd></div>
                  <div className="flex justify-between py-1.5"><dt className="text-gray-500">Tolerance factor t</dt><dd className="font-medium text-gray-900">{fmt(report.tolerance)}</dd></div>
                  <div className="flex justify-between py-1.5"><dt className="text-gray-500">Octahedral factor μ</dt><dd className="font-medium text-gray-900">{fmt(report.octahedral)}</dd></div>
                  <div className="flex justify-between py-1.5"><dt className="text-gray-500">Estimated a (B–X contact / A–X contact)</dt><dd className="font-medium text-gray-900">{fmt(report.aBX, 2)} / {fmt(report.aAX, 2)} Å</dd></div>
                </dl>
                {report.missing.length > 0 && <p className="mt-2 rounded-lg bg-amber-50 px-3 py-2 text-[11px] text-amber-800">No tabulated radius for {report.missing.join('; ')} — factors can’t be computed.</p>}
                {report.tolerance != null && (
                  <div className="mt-3 space-y-1.5 text-[11px] leading-relaxed text-gray-600">
                    <p><span className="font-medium text-gray-900">t:</span> {report.toleranceVerdict}</p>
                    <p><span className="font-medium text-gray-900">μ:</span> {report.octahedralVerdict}</p>
                  </div>
                )}

                <div className="mt-4 border-t border-gray-100 pt-3">
                  <div className="text-[11px] font-medium text-gray-500">Lattice parameter a used for the model</div>
                  <div className="mt-1.5 flex flex-wrap items-center gap-2 text-xs">
                    {([['BX', 'B–X contact'], ['AX', 'A–X contact'], ['custom', 'Custom']] as const).map(([id, lab]) => (
                      <button key={id} type="button" onClick={() => setAMode(id)} className={`rounded-md border px-2 py-1 ${aMode === id ? 'border-indigo-600 bg-indigo-600 text-white' : 'border-gray-200 text-gray-600 hover:border-indigo-300'}`}>{lab}</button>
                    ))}
                    {aMode === 'custom' && <input type="number" step={0.01} min={2} max={12} value={aCustom} onChange={e => setACustom(Number(e.target.value) || 5)} className="h-7 w-20 rounded-md border border-gray-200 px-2" aria-label="Custom lattice parameter in angstroms" />}
                    <span className="text-gray-500">a = {a.toFixed(3)} Å{dens != null && ` · ρ ≈ ${dens.toFixed(2)} g/cm³`}</span>
                  </div>
                  <p className="mt-1 text-[11px] text-gray-400">An ionic-radius estimate, not a relaxed value. If t ≠ 1 the two contact estimates disagree — that mismatch is why real structures tilt or distort.</p>
                </div>

                <div className="mt-4 flex flex-wrap gap-2">
                  <button type="button" onClick={onSave} className="rounded-lg bg-indigo-600 px-3 py-1.5 text-xs font-medium text-white hover:bg-indigo-700">{saved ? 'Saved ✓' : 'Save candidate'}</button>
                  <button type="button" onClick={() => download(`${formulaPlain(report.composition)}-${model}-proposed.cif`, toCif({ title: formulaPlain(report.composition), a, model: modelDef, elements }), 'chemical/x-cif')} className="rounded-lg border border-gray-200 px-3 py-1.5 text-xs text-gray-700 hover:border-indigo-300">Download CIF (proposed)</button>
                  <Link href={`/chemistry/compound-builder?c=${Object.entries(report.composition).map(([s, c]) => `${s}:${c}`).join(',')}`} className="rounded-lg border border-gray-200 px-3 py-1.5 text-xs text-gray-700 hover:border-indigo-300">Open in builder →</Link>
                </div>
              </div>
              <EvidencePanel
                rule={{ label: report.tolerance == null ? 'Geometric factors unavailable (missing radii).' : `Charge ${chargeOk ? 'balances' : 'does not balance'}; t = ${report.tolerance.toFixed(3)}, μ = ${report.octahedral!.toFixed(3)}. Heuristics only.`, ok: report.tolerance == null ? null : chargeOk && report.tolerance >= 0.8 && report.tolerance <= 1.06 && report.octahedral! >= 0.414 }}
                extra={`${double ? 'double perovskite' : 'cubic'} model`}
              />
            </div>
          </div>
        </div>
      </main>
    </>
  );
}
