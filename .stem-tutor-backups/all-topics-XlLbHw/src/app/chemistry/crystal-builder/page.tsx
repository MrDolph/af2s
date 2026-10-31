'use client';
import { useMemo, useState } from 'react';
import Link from 'next/link';
import { AppHeader } from '@/components/layout/AppHeader';
import { CrystalViewer, type SiteStyle } from '@/components/chemistry/CrystalViewer';
import { EvidencePanel } from '@/components/chemistry/EvidencePanel';
import { CandidatesPanel } from '@/components/chemistry/CandidatesPanel';
import { ELEMENTS, BY_SYMBOL } from '@/lib/chemistry/elements';
import { molarMass, reduce } from '@/lib/chemistry/compound';
import { withBoundaryImages, fmtCharge, type Site } from '@/lib/chemistry/perovskite';
import {
  PROTOTYPES, PROTO_ORDER, analyseCrystal, cellAtoms, crystalCif, geometry, type ProtoId, type Role,
} from '@/lib/chemistry/crystal';
import { saveCandidate, download, type Candidate } from '@/lib/chemistry/candidates';

const ROLE_COLOR: Record<Role, string> = { A: '#f59e0b', X: '#818cf8' };
type Els = Record<Role, string>;

interface Preset { label: string; proto: ProtoId; el: Els; a: number; note: string }
const PRESETS: Preset[] = [
  { label: 'NaCl', proto: 'rocksalt', el: { A: 'Na', X: 'Cl' }, a: 5.64, note: 'The textbook rocksalt structure; note the computed density against the ≈ 2.16 g/cm³ usually quoted.' },
  { label: 'MgO', proto: 'rocksalt', el: { A: 'Mg', X: 'O' }, a: 4.21, note: 'Rocksalt oxide.' },
  { label: 'CsCl', proto: 'cscl', el: { A: 'Cs', X: 'Cl' }, a: 4.12, note: 'Eight-fold coordination: the large Cs⁺ ion gives a radius ratio near 0.92.' },
  { label: 'ZnS', proto: 'zincblende', el: { A: 'Zn', X: 'S' }, a: 5.41, note: 'Zincblende (sphalerite) form of ZnS; ZnS also exists as hexagonal wurtzite, which this builder does not draw.' },
  { label: 'GaAs', proto: 'zincblende', el: { A: 'Ga', X: 'As' }, a: 5.65, note: 'A covalent III–V semiconductor in the zincblende structure — the radius-ratio rule is for ionic solids, so ignore it here.' },
  { label: 'CaF₂', proto: 'fluorite', el: { A: 'Ca', X: 'F' }, a: 5.46, note: 'Fluorite: Ca²⁺ is 8-coordinate, F⁻ 4-coordinate.' },
  { label: 'Li₂O', proto: 'fluorite', el: { A: 'O', X: 'Li' }, a: 4.62, note: 'Antifluorite (roles swapped). A good example where the radius-ratio rule predicts octahedral Li⁺ but the real structure is tetrahedral.' },
  { label: 'Cu', proto: 'fcc', el: { A: 'Cu', X: 'Cu' }, a: 3.61, note: 'Close-packed fcc metal.' },
  { label: 'Fe (bcc)', proto: 'bcc', el: { A: 'Fe', X: 'Fe' }, a: 2.87, note: 'Room-temperature α-iron is bcc.' },
  { label: 'Si', proto: 'diamond', el: { A: 'Si', X: 'Si' }, a: 5.43, note: 'Diamond cubic silicon.' },
  { label: 'Po (sc)', proto: 'sc', el: { A: 'Po', X: 'Po' }, a: 3.35, note: 'α-polonium is the rare example of a simple cubic element.' },
  { label: 'Cu₃Au', proto: 'cu3au', el: { A: 'Au', X: 'Cu' }, a: 3.75, note: 'An ordered fcc alloy at low temperature; it disorders on heating.' },
];

function ElementSelect({ label, color, value, onChange }: { label: string; color: string; value: string; onChange: (s: string) => void }) {
  return (
    <div className="min-w-0 rounded-xl border border-gray-200 p-3">
      <div className="flex items-center gap-1.5 text-[11px] font-medium text-gray-500"><span className="inline-block h-2.5 w-2.5 rounded-full" style={{ background: color }} />{label}</div>
      <select value={value} onChange={e => onChange(e.target.value)} className="mt-2 h-9 w-full rounded-md border border-gray-200 bg-white px-2 text-sm" aria-label={label}>
        {ELEMENTS.filter(x => x.z <= 103).map(x => <option key={x.symbol} value={x.symbol}>{x.symbol} — {x.name}</option>)}
      </select>
    </div>
  );
}

export default function CrystalBuilderPage() {
  const [pid, setPid] = useState<ProtoId>(PRESETS[0].proto);
  const [el, setEl] = useState<Els>(PRESETS[0].el);
  const [a, setA] = useState(PRESETS[0].a);
  const [note, setNote] = useState<string | null>(PRESETS[0].note);
  const [n, setN] = useState(1);
  const [bonds, setBonds] = useState(true);
  const [cell, setCell] = useState(true);
  const [saved, setSaved] = useState(false);

  const proto = PROTOTYPES[pid];
  const binary = proto.roles.length === 2;
  const effEl: Els = binary ? el : { A: el.A, X: el.A };
  const geo = geometry(proto);
  const rep = analyseCrystal(proto, effEl, a);

  const atoms = useMemo(() => withBoundaryImages(cellAtoms(proto).map(x => ({ site: x.site, frac: x.frac })), n), [proto, n]);
  const styles = (() => {
    const out: Partial<Record<Site, SiteStyle>> = {};
    proto.sublattices.forEach(s => {
      const sym = effEl[s.role];
      out[s.site] = { label: sym, color: ROLE_COLOR[s.role], radius: 0.075 + 0.012 * BY_SYMBOL[sym].period };
    });
    return out;
  })();
  const siteNames = Object.fromEntries(proto.sublattices.map(s => [s.site, s.name])) as Partial<Record<Site, string>>;

  const loadPreset = (p: Preset) => { setPid(p.proto); setEl(p.el); setA(p.a); setNote(p.note); setSaved(false); };
  const setRole = (r: Role, s: string) => { setEl(e => ({ ...e, [r]: s })); setNote(null); setSaved(false); };
  const changeProto = (id: ProtoId) => { setPid(id); setNote(null); setSaved(false); };

  const onSave = () => {
    saveCandidate({
      name: `${rep.formula} (${proto.label.split(' (')[0]})`, kind: 'crystal', formula: rep.formula, composition: reduce(rep.composition),
      molarMass: molarMass(reduce(rep.composition)), chargeStatus: rep.charge?.status ?? 'single element',
      crystal: { prototype: pid, elements: effEl, a, density: rep.density }, note: note ?? undefined,
    });
    setSaved(true);
  };
  const onLoad = (c: Candidate) => {
    if (c.crystal) { setPid(c.crystal.prototype as ProtoId); setEl(c.crystal.elements as Els); setA(c.crystal.a); setNote(c.note ?? null); }
  };

  const groups = ['Elements', 'AX compounds', 'AX₂ compounds', 'Ordered alloys'] as const;
  const rr = rep.radius;

  return (
    <>
      <AppHeader />
      <main className="min-h-screen bg-gray-50">
        <div className="mx-auto max-w-7xl px-4 py-6 sm:px-6">
          <Link href="/chemistry" className="text-xs text-gray-400 transition hover:text-indigo-600">← Chemistry</Link>
          <h1 className="mt-1 text-xl font-semibold text-gray-900 sm:text-2xl">Crystal builder</h1>
          <p className="mb-4 mt-1 text-sm text-gray-500">Choose a cubic prototype, assign elements and a lattice parameter, and read off coordination, density and packing. These are <span className="font-medium text-gray-700">computed from the geometry</span>; they don’t show that a material adopts that structure.</p>

          <div className="mb-4 flex flex-wrap gap-2">
            {PRESETS.map(p => <button key={p.label} type="button" onClick={() => loadPreset(p)} className="rounded-full border border-gray-200 bg-white px-3 py-1 text-xs text-gray-700 transition hover:border-indigo-300 hover:text-indigo-700">{p.label}</button>)}
          </div>
          {note && <p className="mb-5 rounded-xl border border-indigo-100 bg-indigo-50 px-3 py-2 text-xs text-indigo-900">{note} <span className="opacity-70">Lattice parameters are approximate literature values — check the primary source before citing.</span></p>}

          <div className="grid grid-cols-1 gap-5 lg:grid-cols-[minmax(0,1.3fr)_minmax(0,1fr)]">
            <div className="min-w-0 space-y-5">
              <div className="rounded-2xl border border-gray-200 bg-white p-4">
                <CrystalViewer atoms={atoms} extent={n} styles={styles} siteNames={siteNames} bondDist={geo.nn} bondMode="nn" sizeScale={0.85} sizeNote="atom size shows period only" showBonds={bonds} showCell={cell} showA />
                <div className="mt-3 flex flex-wrap items-center gap-x-4 gap-y-2 border-t border-gray-100 pt-3 text-xs text-gray-600">
                  <label className="flex items-center gap-1.5"><input type="checkbox" checked={bonds} onChange={e => setBonds(e.target.checked)} />Nearest-neighbour bonds</label>
                  <label className="flex items-center gap-1.5"><input type="checkbox" checked={cell} onChange={e => setCell(e.target.checked)} />Cell edges</label>
                  <span className="ml-auto flex items-center gap-1.5">Cells
                    {[1, 2].map(v => <button key={v} type="button" onClick={() => setN(v)} className={`rounded-md border px-2 py-0.5 ${n === v ? 'border-indigo-600 bg-indigo-600 text-white' : 'border-gray-200 hover:border-indigo-300'}`}>{v}×{v}×{v}</button>)}
                  </span>
                </div>
                <p className="mt-2 text-[11px] text-gray-400">{proto.label} · {proto.spaceGroup}. {proto.note}</p>
              </div>

              <div className="rounded-2xl border border-gray-200 bg-white p-5">
                <h2 className="mb-3 text-sm font-semibold text-gray-900">Compare the prototypes <span className="font-normal text-gray-400">(computed from each geometry)</span></h2>
                <div className="overflow-x-auto">
                  <table className="w-full min-w-[460px] text-left text-xs">
                    <thead className="text-[10px] uppercase tracking-wide text-gray-400"><tr><th className="py-1 pr-2 font-medium">Prototype</th><th className="pr-2 font-medium">Atoms / cell</th><th className="pr-2 font-medium">Type</th><th className="pr-2 font-medium">Coordination</th><th className="font-medium">NN dist.</th></tr></thead>
                    <tbody>
                      {PROTO_ORDER.map(id => {
                        const g = geometry(PROTOTYPES[id]);
                        return (
                          <tr key={id} className={`border-t border-gray-100 ${id === pid ? 'bg-indigo-50/60' : ''}`}>
                            <td className="py-1.5 pr-2"><button type="button" onClick={() => changeProto(id)} className="text-left font-medium text-gray-900 hover:text-indigo-700">{PROTOTYPES[id].label}</button></td>
                            <td className="pr-2 text-gray-700">{g.atomsPerCell}</td>
                            <td className="pr-2 text-gray-700">{g.stoich}</td>
                            <td className="pr-2 text-gray-700">{g.coordination.map(c => `${c.role} ${c.total}`).join(' · ')}</td>
                            <td className="text-gray-700">{g.nn.toFixed(3)} a</td>
                          </tr>
                        );
                      })}
                    </tbody>
                  </table>
                </div>
              </div>
              <CandidatesPanel onLoad={onLoad} />
            </div>

            <div className="min-w-0 space-y-5">
              <div className="rounded-2xl border border-gray-200 bg-white p-5">
                <label className="text-[11px] font-medium uppercase tracking-wide text-gray-400" htmlFor="proto">Prototype</label>
                <select id="proto" value={pid} onChange={e => changeProto(e.target.value as ProtoId)} className="mt-1 h-9 w-full rounded-md border border-gray-200 bg-white px-2 text-sm">
                  {groups.map(g => <optgroup key={g} label={g}>{PROTO_ORDER.filter(id => PROTOTYPES[id].group === g).map(id => <option key={id} value={id}>{PROTOTYPES[id].label}</option>)}</optgroup>)}
                </select>

                <div className="mt-3 grid gap-3 sm:grid-cols-2">
                  <ElementSelect label={binary ? 'A element' : 'Element'} color={ROLE_COLOR.A} value={el.A} onChange={s => setRole('A', s)} />
                  {binary && <ElementSelect label="X element" color={ROLE_COLOR.X} value={el.X} onChange={s => setRole('X', s)} />}
                </div>

                <div className="mt-4 text-[11px] font-medium uppercase tracking-wide text-gray-400">Candidate</div>
                <div className="text-3xl font-semibold text-gray-900" aria-live="polite">{rep.formula}</div>
                <div className="text-xs text-gray-500">{geo.atomsPerCell} atoms per cubic cell · {geo.stoich === 'A' ? 'one element' : `AX type ${geo.stoich}`}</div>

                <div className="mt-3 flex items-center gap-2 text-xs">
                  <label htmlFor="a" className="font-medium text-gray-500">Lattice parameter a (Å)</label>
                  <input id="a" type="number" step={0.01} min={1.5} max={12} value={a} onChange={e => { setA(Number(e.target.value) || 5); setSaved(false); }} className="h-8 w-24 rounded-md border border-gray-200 px-2 text-sm" />
                </div>
                <p className="mt-1 text-[11px] text-gray-400">Preset values are approximate literature numbers. For a new combination this is a placeholder you set — not a prediction.</p>

                <dl className="mt-3 divide-y divide-gray-100 text-xs">
                  {geo.coordination.filter(c => binary || c.role === 'A').map(c => (
                    <div key={c.role} className="flex justify-between py-1.5"><dt className="text-gray-500">Coordination of {binary ? `${effEl[c.role]} (${c.role})` : effEl.A}</dt><dd className="font-medium text-gray-900">{c.total}{c.like > 0 && c.unlike > 0 ? ` (${c.unlike} unlike + ${c.like} like)` : ''}</dd></div>
                  ))}
                  <div className="flex justify-between py-1.5"><dt className="text-gray-500">Nearest-neighbour distance</dt><dd className="font-medium text-gray-900">{rep.nnAngstrom.toFixed(3)} Å</dd></div>
                  <div className="flex justify-between py-1.5"><dt className="text-gray-500">Density</dt><dd className="font-medium text-gray-900">{rep.density.toFixed(3)} g/cm³</dd></div>
                  {rep.packing != null && <div className="flex justify-between py-1.5"><dt className="text-gray-500">Packing fraction (ideal hard spheres)</dt><dd className="font-medium text-gray-900">{rep.packing.toFixed(4)}</dd></div>}
                </dl>

                {rep.charge && (
                  <div className={`mt-3 rounded-lg px-3 py-2 text-[11px] leading-relaxed ${rep.charge.status === 'balanced' ? 'bg-emerald-50 text-emerald-900' : 'bg-amber-50 text-amber-900'}`}>
                    <span className="font-medium">Charge balance.</span> {rep.charge.message}
                    {rep.charge.solutions[0] && <span className="mt-0.5 block font-mono">{Object.entries(rep.charge.solutions[0].states).map(([s, q]) => `${s}${fmtCharge(q)}`).join('  ')}</span>}
                  </div>
                )}
                {rr && (
                  <div className={`mt-2 rounded-lg px-3 py-2 text-[11px] leading-relaxed ${rr.consistent ? 'bg-emerald-50 text-emerald-900' : 'bg-amber-50 text-amber-900'}`}>
                    <span className="font-medium">Radius-ratio rule.</span> r(cation)/r(anion) = {rr.cationRadius.toFixed(2)}/{rr.anionRadius.toFixed(2)} = {rr.ratio.toFixed(3)}, which suggests {rr.expectedCN}-fold coordination ({rr.expectedText}); this prototype has {rr.actualCN}. {rr.consistent ? 'Consistent.' : 'Not consistent — the rule has many exceptions (covalent character, polarisation), so this does not rule the structure out.'}
                  </div>
                )}

                <div className="mt-4 flex flex-wrap gap-2">
                  <button type="button" onClick={onSave} className="rounded-lg bg-indigo-600 px-3 py-1.5 text-xs font-medium text-white hover:bg-indigo-700">{saved ? 'Saved ✓' : 'Save candidate'}</button>
                  <button type="button" onClick={() => download(`${rep.formula}-${pid}-proposed.cif`, crystalCif(proto, effEl, a, rep.formula), 'chemical/x-cif')} className="rounded-lg border border-gray-200 px-3 py-1.5 text-xs text-gray-700 hover:border-indigo-300">Download CIF (proposed)</button>
                  <Link href={`/chemistry/compound-builder?c=${Object.entries(rep.composition).map(([s, c]) => `${s}:${c}`).join(',')}`} className="rounded-lg border border-gray-200 px-3 py-1.5 text-xs text-gray-700 hover:border-indigo-300">Open in builder →</Link>
                </div>
              </div>
              <EvidencePanel
                rule={{ label: rep.charge ? (rep.charge.status === 'balanced' ? 'Charges can balance' : rep.charge.message) + (rr ? `; radius ratio ${rr.ratio.toFixed(2)} ${rr.consistent ? 'matches' : 'does not match'} this prototype.` : '.') : 'Single element — no charge check; geometry only.', ok: rep.charge ? (rep.charge.status === 'balanced' && (rr ? rr.consistent : true)) : null }}
                extra={proto.label}
                calculated={{ state: 'warn', text: 'Only simple geometric quantities (coordination, density, packing) from the prototype and your lattice parameter. No energies or relaxation.' }}
                database={{ state: 'no', text: 'Not checked. Compare with a structure database (e.g. ICSD, Crystallography Open Database, Materials Project) before saying a compound adopts this structure.' }}
              />
            </div>
          </div>
        </div>
      </main>
    </>
  );
}
