'use client';
import { useMemo, useState } from 'react';
import Link from 'next/link';
import { AppHeader } from '@/components/layout/AppHeader';
import { CrystalViewer, type SiteStyle } from '@/components/chemistry/CrystalViewer';
import { EvidencePanel } from '@/components/chemistry/EvidencePanel';
import { CandidatesPanel } from '@/components/chemistry/CandidatesPanel';
import { ELEMENTS, BY_SYMBOL } from '@/lib/chemistry/elements';
import { molarMass } from '@/lib/chemistry/compound';
import { withBoundaryImages, type Site } from '@/lib/chemistry/perovskite';
import {
  TEMPLATES, SUB_SITE, SUB_NAME, NN_DIST, analyseHeusler, heuslerAtoms, heuslerCif, heuslerDensity, roleCount,
  type Role, type Sub, type TemplateId,
} from '@/lib/chemistry/heusler';
import { saveCandidate, download, type Candidate } from '@/lib/chemistry/candidates';

const ROLE_COLOR: Record<Role, string> = { X: '#f59e0b', Y: '#818cf8', Z: '#2dd4bf' };
type Els = Record<Role, string>;

interface Preset { label: string; template: TemplateId; el: Els; a: number; note: string }
const PRESETS: Preset[] = [
  { label: 'TiNiSn', template: 'half-Y4c', el: { X: 'Ti', Y: 'Ni', Z: 'Sn' }, a: 5.94,
    note: 'Half-Heusler with 18 valence electrons — the standard example of a closed-shell, semiconducting count (thermoelectric studies).' },
  { label: 'NiMnSb', template: 'half-X4c', el: { X: 'Ni', Y: 'Mn', Z: 'Sb' }, a: 5.92,
    note: 'The classic half-metallic half-Heusler. N_v = 22 gives the Slater–Pauling moment of 4 μB, which matches what is reported.' },
  { label: 'Co₂MnSi', template: 'full-L21', el: { X: 'Co', Y: 'Mn', Z: 'Si' }, a: 5.65,
    note: 'Regular L2₁ full-Heusler studied for half-metallicity; N_v = 29 gives the reported 5 μB.' },
  { label: 'Co₂FeSi', template: 'full-L21', el: { X: 'Co', Y: 'Fe', Z: 'Si' }, a: 5.64,
    note: 'Regular L2₁ full-Heusler with N_v = 30, i.e. a Slater–Pauling moment of 6 μB.' },
  { label: 'Fe₂VAl', template: 'full-L21', el: { X: 'Fe', Y: 'V', Z: 'Al' }, a: 5.76,
    note: 'N_v = 24: the closed-shell count of a non-magnetic full-Heusler (semimetal/narrow-gap candidate).' },
  { label: 'Ni₂MnGa', template: 'full-L21', el: { X: 'Ni', Y: 'Mn', Z: 'Ga' }, a: 5.83,
    note: 'Magnetic shape-memory alloy; the cubic L2₁ phase here is the high-temperature austenite, and the real material transforms martensitically.' },
  { label: 'Mn₂CoAl', template: 'full-inverse', el: { X: 'Mn', Y: 'Co', Z: 'Al' }, a: 5.80,
    note: 'Inverse (XA) full-Heusler discussed as a spin-gapless / ferrimagnetic candidate; N_v = 26 gives 2 μB.' },
];

function ElementSelect({ role, value, onChange }: { role: Role; value: string; onChange: (s: string) => void }) {
  const e = BY_SYMBOL[value];
  return (
    <div className="rounded-xl border border-gray-200 p-3">
      <div className="flex items-center gap-1.5 text-[11px] font-medium text-gray-500">
        <span className="inline-block h-2.5 w-2.5 rounded-full" style={{ background: ROLE_COLOR[role] }} />{role} element
      </div>
      <select value={value} onChange={ev => onChange(ev.target.value)} className="mt-2 h-8 w-full rounded-md border border-gray-200 bg-white px-2 text-sm" aria-label={`${role} element`}>
        {ELEMENTS.filter(x => x.z <= 103).map(x => <option key={x.symbol} value={x.symbol}>{x.symbol} — {x.name}</option>)}
      </select>
      <div className="mt-1.5 text-[11px] text-gray-400">Valence electrons counted: {e.group == null ? '3 (f-block, approx.)' : e.group <= 12 ? e.group : e.group - 10}</div>
    </div>
  );
}

export default function HeuslerPage() {
  const [tid, setTid] = useState<TemplateId>(PRESETS[0].template);
  const [el, setEl] = useState<Els>(PRESETS[0].el);
  const [a, setA] = useState(PRESETS[0].a);
  const [note, setNote] = useState<string | null>(PRESETS[0].note);
  const [n, setN] = useState(1);
  const [bonds, setBonds] = useState(true);
  const [cell, setCell] = useState(true);
  const [saved, setSaved] = useState(false);

  const t = TEMPLATES[tid];
  const report = useMemo(() => analyseHeusler(t, el), [t, el]);
  const atoms = useMemo(() => withBoundaryImages(heuslerAtoms(t), n), [t, n]);
  const mass = molarMass(report.composition);
  const dens = heuslerDensity(t, a, el);

  const styles = useMemo(() => {
    const out: Partial<Record<Site, SiteStyle>> = {};
    (Object.keys(t.layout) as Sub[]).forEach(sub => {
      const role = t.layout[sub];
      if (!role) return;
      out[SUB_SITE[sub]] = { label: el[role], color: ROLE_COLOR[role], radius: 0.075 + 0.012 * BY_SYMBOL[el[role]].period };
    });
    return out;
  }, [t, el]);
  const siteNames = useMemo(() => Object.fromEntries((Object.keys(SUB_NAME) as Sub[]).map(s => [SUB_SITE[s], SUB_NAME[s]])) as Partial<Record<Site, string>>, []);

  const roles: Role[] = ['X', 'Y', 'Z'];
  const loadPreset = (p: Preset) => { setTid(p.template); setEl(p.el); setA(p.a); setNote(p.note); setSaved(false); };
  const setRole = (r: Role, s: string) => { setEl(e => ({ ...e, [r]: s })); setNote(null); setSaved(false); };

  const onSave = () => {
    saveCandidate({
      name: `${report.formula} (${t.family === 'half' ? 'half' : 'full'}, ${t.id.split('-')[1]})`,
      kind: 'heusler', formula: report.formula, composition: report.composition, molarMass: mass,
      chargeStatus: `N_v = ${report.nv}`,
      heusler: { template: t.id, elements: el, a, valenceElectrons: report.nv, slaterPauling: report.moment },
      note: note ?? undefined,
    });
    setSaved(true);
  };
  const onLoad = (c: Candidate) => {
    if (c.heusler) {
      setTid(c.heusler.template as TemplateId);
      setEl(c.heusler.elements as Els);
      setA(c.heusler.a);
      setNote(c.note ?? null);
    }
  };

  const tone = { good: 'bg-emerald-50 text-emerald-900', info: 'bg-gray-50 text-gray-700', warn: 'bg-amber-50 text-amber-900' } as const;

  return (
    <>
      <AppHeader />
      <main className="min-h-screen bg-gray-50">
        <div className="mx-auto max-w-7xl px-4 py-6 sm:px-6">
          <Link href="/chemistry" className="text-xs text-gray-400 transition hover:text-indigo-600">← Chemistry</Link>
          <h1 className="mt-1 text-xl font-semibold text-gray-900 sm:text-2xl">Heusler alloys</h1>
          <p className="mb-4 mt-1 text-sm text-gray-500">Place X, Y and Z on the four fcc sublattices, compare site arrangements, and check valence-electron rules. The model is a <span className="font-medium text-gray-700">proposed ordering</span>, not a relaxed or confirmed structure.</p>

          <div className="mb-4 flex flex-wrap gap-2">
            {PRESETS.map(p => (
              <button key={p.label} type="button" onClick={() => loadPreset(p)} className="rounded-full border border-gray-200 bg-white px-3 py-1 text-xs text-gray-700 transition hover:border-indigo-300 hover:text-indigo-700">{p.label}</button>
            ))}
          </div>
          {note && <p className="mb-5 rounded-xl border border-indigo-100 bg-indigo-50 px-3 py-2 text-xs text-indigo-900">{note} <span className="opacity-70">Reference notes and lattice parameters are approximate summaries — check the primary literature before citing.</span></p>}

          <div className="grid grid-cols-1 gap-5 lg:grid-cols-[minmax(0,1.3fr)_minmax(0,1fr)]">
            <div className="min-w-0 space-y-5">
              <div className="rounded-2xl border border-gray-200 bg-white p-4">
                <CrystalViewer atoms={atoms} extent={n} styles={styles} siteNames={siteNames} bondDist={NN_DIST} bondMode="nn" sizeScale={0.62} sizeNote="atom size shows period only" showBonds={bonds} showCell={cell} showA />
                <div className="mt-3 flex flex-wrap items-center gap-x-4 gap-y-2 border-t border-gray-100 pt-3 text-xs text-gray-600">
                  <label className="flex items-center gap-1.5"><input type="checkbox" checked={bonds} onChange={e => setBonds(e.target.checked)} />Nearest-neighbour bonds</label>
                  <label className="flex items-center gap-1.5"><input type="checkbox" checked={cell} onChange={e => setCell(e.target.checked)} />Cell edges</label>
                  <span className="ml-auto flex items-center gap-1.5">Cells
                    {[1, 2].map(v => <button key={v} type="button" onClick={() => setN(v)} className={`rounded-md border px-2 py-0.5 ${n === v ? 'border-indigo-600 bg-indigo-600 text-white' : 'border-gray-200 hover:border-indigo-300'}`}>{v}×{v}×{v}</button>)}
                  </span>
                </div>
                <p className="mt-2 text-[11px] text-gray-400">{t.label} · {t.spaceGroup}. {t.note} Atom sizes show period only, not ionic or atomic radii.{t.family === 'half' && ' The 4d site is vacant.'}</p>
              </div>
              <CandidatesPanel onLoad={onLoad} />
            </div>

            <div className="min-w-0 space-y-5">
              <div className="rounded-2xl border border-gray-200 bg-white p-5">
                <label className="text-[11px] font-medium uppercase tracking-wide text-gray-400" htmlFor="template">Template / arrangement</label>
                <select id="template" value={tid} onChange={e => { setTid(e.target.value as TemplateId); setSaved(false); }} className="mt-1 h-9 w-full rounded-md border border-gray-200 bg-white px-2 text-sm">
                  <optgroup label="Half-Heusler XYZ (three arrangements)">
                    {(['half-X4c', 'half-Y4c', 'half-Z4c'] as TemplateId[]).map(id => <option key={id} value={id}>{TEMPLATES[id].label}</option>)}
                  </optgroup>
                  <optgroup label="Full-Heusler X₂YZ">
                    {(['full-L21', 'full-inverse'] as TemplateId[]).map(id => <option key={id} value={id}>{TEMPLATES[id].label}</option>)}
                  </optgroup>
                </select>
                <p className="mt-1 text-[11px] text-gray-400">Labels (e.g. “Type I/II/III”) vary between papers, so arrangements are named here by site.</p>

                <div className="mt-3 grid gap-3 sm:grid-cols-3">
                  {roles.filter(r => roleCount(t, r) > 0).map(r => <ElementSelect key={r} role={r} value={el[r]} onChange={s => setRole(r, s)} />)}
                </div>

                <div className="mt-4 text-[11px] font-medium uppercase tracking-wide text-gray-400">Candidate</div>
                <div className="text-3xl font-semibold text-gray-900" aria-live="polite">{report.display}</div>
                <div className="text-xs text-gray-500">{mass.toFixed(2)} g/mol per formula unit</div>

                <dl className="mt-3 divide-y divide-gray-100 text-xs">
                  <div className="flex justify-between py-1.5"><dt className="text-gray-500">Valence electrons N_v</dt><dd className="font-medium text-gray-900">{report.nv}{report.approx && ' (approx.)'}</dd></div>
                  <div className="flex justify-between py-1.5"><dt className="text-gray-500">Slater–Pauling M = N_v − {t.family === 'half' ? 18 : 24}</dt><dd className="font-medium text-gray-900">{report.moment == null ? '0 (closed shell)' : `${report.moment > 0 ? '+' : ''}${report.moment} μB / f.u.`}</dd></div>
                  <div className="flex justify-between py-1.5"><dt className="text-gray-500">Nearest-neighbour distance</dt><dd className="font-medium text-gray-900">{(a * NN_DIST).toFixed(3)} Å</dd></div>
                  <div className="flex justify-between py-1.5"><dt className="text-gray-500">Density at this a</dt><dd className="font-medium text-gray-900">{dens.toFixed(2)} g/cm³</dd></div>
                </dl>

                <div className="mt-3 space-y-1.5">
                  {report.checks.map(c => (
                    <div key={c.label} className={`rounded-lg px-3 py-2 text-[11px] leading-relaxed ${tone[c.tone]}`}><span className="font-medium">{c.label}.</span> {c.text}</div>
                  ))}
                </div>

                <div className="mt-4 border-t border-gray-100 pt-3">
                  <label className="text-[11px] font-medium text-gray-500" htmlFor="a">Lattice parameter a (Å)</label>
                  <div className="mt-1 flex items-center gap-2">
                    <input id="a" type="number" step={0.01} min={3} max={9} value={a} onChange={e => { setA(Number(e.target.value) || 5.8); setSaved(false); }} className="h-8 w-24 rounded-md border border-gray-200 px-2 text-sm" />
                    <span className="text-[11px] text-gray-400">Preset values are approximate literature numbers; for new compositions this is a placeholder you should replace, not a prediction.</span>
                  </div>
                </div>

                <div className="mt-4 flex flex-wrap gap-2">
                  <button type="button" onClick={onSave} className="rounded-lg bg-indigo-600 px-3 py-1.5 text-xs font-medium text-white hover:bg-indigo-700">{saved ? 'Saved ✓' : 'Save candidate'}</button>
                  <button type="button" onClick={() => download(`${report.formula}-${t.id}-proposed.cif`, heuslerCif({ title: report.formula, a, t, el }), 'chemical/x-cif')} className="rounded-lg border border-gray-200 px-3 py-1.5 text-xs text-gray-700 hover:border-indigo-300">Download CIF (proposed)</button>
                  <Link href={`/chemistry/compound-builder?c=${Object.entries(report.composition).map(([s, c]) => `${s}:${c}`).join(',')}`} className="rounded-lg border border-gray-200 px-3 py-1.5 text-xs text-gray-700 hover:border-indigo-300">Open in builder →</Link>
                </div>
              </div>
              <EvidencePanel
                rule={{ label: `N_v = ${report.nv} against the ${t.family === 'half' ? '8/18' : '24'}-electron closed-shell counts, plus a Slater–Pauling estimate. Counting rules only.`, ok: report.nv === (t.family === 'half' ? 18 : 24) || (t.family === 'half' && report.nv === 8) ? true : null }}
                extra={`${t.label}`}
              />
            </div>
          </div>
        </div>
      </main>
    </>
  );
}
