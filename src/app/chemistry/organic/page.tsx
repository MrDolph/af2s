'use client';
import { useEffect, useState } from 'react';
import Link from 'next/link';
import { AppHeader } from '@/components/layout/AppHeader';
import { MoleculeEditor, H, type Tool } from '@/components/chemistry/MoleculeEditor';
import { EvidencePanel } from '@/components/chemistry/EvidencePanel';
import { CandidatesPanel } from '@/components/chemistry/CandidatesPanel';
import {
  ISOMER_SETS, LIBRARY, PALETTE, components, dbe, formulaText, functionalGroups, identify, loadPreset, massOf, parseSmiles,
  placeMol, toMolfile, toSmiles, valenceInfo, composition, type Mol,
} from '@/lib/chemistry/organic';
import { saveCandidate, download, type Candidate } from '@/lib/chemistry/candidates';

const TOOLS: { id: Tool; label: string; hint: string }[] = [
  { id: 'move', label: 'Move', hint: 'Drag atoms to rearrange the drawing.' },
  { id: 'atom', label: 'Add atom', hint: 'Tap empty space to place the chosen element. With “auto-bond” on, each new atom bonds to the last selected one, so you can draw chains quickly. Tap an atom with a different element chosen to change it.' },
  { id: 'bond', label: 'Bond', hint: 'Tap one atom, then another. Tap the same pair again to cycle single → double → triple → none.' },
  { id: 'erase', label: 'Erase', hint: 'Tap an atom or a bond to delete it.' },
];
const GROUPS = Array.from(new Set(LIBRARY.map(p => p.group)));

export default function OrganicPage() {
  const [width, setWidth] = useState(640);
  const [mol, setMol] = useState<Mol>(() => loadPreset('Ethanol') ?? { atoms: [], bonds: [] });
  const [undo, setUndo] = useState<Mol[]>([]);
  const [tool, setTool] = useState<Tool>('move');
  const [element, setElement] = useState('C');
  const [selected, setSelected] = useState<number | null>(null);
  const [autoBond, setAutoBond] = useState(true);
  const [skeletal, setSkeletal] = useState(false);
  const [smiles, setSmiles] = useState('');
  const [smilesError, setSmilesError] = useState<string | null>(null);
  const [saved, setSaved] = useState(false);
  const [copied, setCopied] = useState(false);

  const pickTool = (t: Tool) => { setTool(t); setSelected(null); };
  // Phones get a narrower drawing space so atoms and labels render at a readable size.
  useEffect(() => {
    const t = setTimeout(() => {
      if (window.innerWidth < 640) { setWidth(360); setMol(m => placeMol(m, 360, H)); }
    }, 0);
    return () => clearTimeout(t);
  }, []);
  const push = () => setUndo(u => [...u.slice(-29), mol]);
  const commit = (m: Mol) => { push(); setMol(m); setSaved(false); setCopied(false); };
  const doUndo = () => { setUndo(u => { if (!u.length) return u; setMol(u[u.length - 1]); setSelected(null); return u.slice(0, -1); }); setSaved(false); };
  const load = (m: Mol) => { push(); setMol(m); setSelected(null); setSmilesError(null); setSaved(false); setCopied(false); };
  const loadByName = (name: string) => { const m = loadPreset(name, width, H); if (m) load(m); };

  const n = mol.atoms.length;
  const { h, bad } = valenceInfo(mol);
  const totalH = h.reduce((s, x) => s + x, 0);
  const formula = n ? formulaText(mol) : '—';
  const mass = n ? massOf(mol) : 0;
  const unsat = n ? dbe(mol) : null;
  const groups = n ? functionalGroups(mol) : [];
  const id = identify(mol);
  const parts = components(mol);
  const smilesOut = n ? toSmiles(mol) : '';
  const valid = n > 0 && bad.length === 0 && parts === 1;

  const drawSmiles = () => {
    const r = parseSmiles(smiles);
    if (r.error || !r.mol) { setSmilesError(r.error ?? 'Could not read that SMILES.'); return; }
    load(placeMol(r.mol, width, H));
  };
  const onSave = () => {
    if (!n) return;
    saveCandidate({
      name: id.same ?? formula, kind: 'organic', formula, composition: composition(mol), molarMass: mass,
      chargeStatus: valid ? 'Valences satisfied' : 'Valence problem',
      organic: { atoms: mol.atoms, bonds: mol.bonds, smiles: smilesOut },
    });
    setSaved(true);
  };
  const onLoadCandidate = (c: Candidate) => { if (c.organic) load({ atoms: c.organic.atoms, bonds: c.organic.bonds }); };
  const tip = TOOLS.find(t => t.id === tool)!;

  return (
    <>
      <AppHeader />
      <main className="min-h-screen bg-gray-50">
        <div className="mx-auto max-w-7xl px-4 py-6 sm:px-6">
          <Link href="/chemistry" className="text-xs text-gray-400 transition hover:text-indigo-600">← Chemistry</Link>
          <h1 className="mt-1 text-xl font-semibold text-gray-900 sm:text-2xl">Organic molecules</h1>
          <p className="mb-4 mt-1 text-sm text-gray-500">Draw atoms and bonds, or load a molecule. Hydrogens fill in automatically from valence. The tool reads the structure you drew — it tells you what the <span className="font-medium text-gray-700">graph</span> contains, not whether the molecule is stable or easy to make.</p>

          <div className="grid grid-cols-1 gap-5 lg:grid-cols-[minmax(0,1.35fr)_minmax(0,1fr)]">
            <div className="min-w-0 space-y-5">
              <div className="rounded-2xl border border-gray-200 bg-white p-4">
                <div className="mb-3 flex flex-wrap items-center gap-2">
                  <div className="flex overflow-hidden rounded-lg border border-gray-200" role="group" aria-label="Drawing tool">
                    {TOOLS.map(t => <button key={t.id} type="button" aria-pressed={tool === t.id} onClick={() => pickTool(t.id)} className={`px-3 py-1.5 text-xs font-medium ${tool === t.id ? 'bg-indigo-600 text-white' : 'bg-white text-gray-600 hover:bg-gray-50'}`}>{t.label}</button>)}
                  </div>
                  <button type="button" onClick={doUndo} disabled={!undo.length} className="rounded-lg border border-gray-200 px-3 py-1.5 text-xs text-gray-600 enabled:hover:border-indigo-300 disabled:opacity-40">Undo</button>
                  <button type="button" onClick={() => { if (n) { push(); setMol({ atoms: [], bonds: [] }); setSelected(null); setSaved(false); } }} disabled={!n} className="rounded-lg border border-gray-200 px-3 py-1.5 text-xs text-gray-600 enabled:hover:border-red-300 enabled:hover:text-red-600 disabled:opacity-40">Clear</button>
                </div>
                {/* Always rendered (hidden when unused) so the canvas never jumps when the tool changes. */}
                {(
                  <div className={`mb-3 flex flex-wrap items-center gap-1.5 ${tool === 'atom' ? '' : 'invisible'}`} role="group" aria-label="Element" aria-hidden={tool !== 'atom'}>
                    {PALETTE.map(el => <button key={el} type="button" tabIndex={tool === 'atom' ? 0 : -1} aria-pressed={element === el} onClick={() => setElement(el)} className={`h-8 min-w-8 rounded-md border px-2 text-xs font-semibold ${element === el ? 'border-indigo-600 bg-indigo-600 text-white' : 'border-gray-200 text-gray-700 hover:border-indigo-300'}`}>{el}</button>)}
                    <label className="ml-2 flex items-center gap-1.5 text-xs text-gray-600"><input type="checkbox" checked={autoBond} onChange={e => setAutoBond(e.target.checked)} />Auto-bond</label>
                  </div>
                )}
                <MoleculeEditor mol={mol} tool={tool} element={element} selected={selected} autoBond={autoBond} skeletal={skeletal} width={width}
                  onLive={setMol} onCommit={commit} onSelect={setSelected} onDragStart={push} />
                <div className="mt-2 flex flex-wrap items-center gap-x-4 gap-y-1">
                  <p className="min-w-0 flex-1 text-[11px] text-gray-500">{tip.hint}</p>
                  <label className="flex items-center gap-1.5 text-xs text-gray-600"><input type="checkbox" checked={skeletal} onChange={e => setSkeletal(e.target.checked)} />Skeletal style</label>
                </div>
              </div>

              <div className="rounded-2xl border border-gray-200 bg-white p-4">
                <h2 className="mb-2 text-sm font-semibold text-gray-900">Load a molecule</h2>
                <label className="sr-only" htmlFor="lib">Molecule library</label>
                <select id="lib" value="" onChange={e => e.target.value && loadByName(e.target.value)} className="h-9 w-full rounded-md border border-gray-200 bg-white px-2 text-sm">
                  <option value="">Choose from the library ({LIBRARY.length} molecules)…</option>
                  {GROUPS.map(g => <optgroup key={g} label={g}>{LIBRARY.filter(p => p.group === g).map(p => <option key={p.name} value={p.name}>{p.name}</option>)}</optgroup>)}
                </select>
                <div className="mt-3 text-[11px] font-medium uppercase tracking-wide text-gray-400">Isomer sets — same formula, different structure</div>
                <div className="mt-1.5 space-y-1.5">
                  {ISOMER_SETS.map(s => (
                    <div key={s.formula} className="flex flex-wrap items-center gap-1.5">
                      <span className="w-14 text-xs font-medium text-gray-500">{s.formula}</span>
                      {s.names.map(nm => <button key={nm} type="button" onClick={() => loadByName(nm)} className="rounded-full border border-gray-200 px-2.5 py-1 text-[11px] text-gray-700 hover:border-indigo-300 hover:text-indigo-700">{nm.replace(/ \(.*\)/, '')}</button>)}
                    </div>
                  ))}
                </div>
                <div className="mt-4 text-[11px] font-medium uppercase tracking-wide text-gray-400">Or type a SMILES string</div>
                <div className="mt-1.5 flex gap-2">
                  <label className="sr-only" htmlFor="smiles">SMILES</label>
                  <input id="smiles" value={smiles} onChange={e => { setSmiles(e.target.value); setSmilesError(null); }} onKeyDown={e => e.key === 'Enter' && drawSmiles()} spellCheck={false} autoCapitalize="off" placeholder="e.g. CC(=O)O or c1ccccc1" className="h-9 min-w-0 flex-1 rounded-md border border-gray-200 px-3 font-mono text-sm" />
                  <button type="button" onClick={drawSmiles} className="h-9 rounded-md bg-indigo-600 px-3 text-xs font-medium text-white hover:bg-indigo-700">Draw</button>
                </div>
                {smilesError && <p className="mt-1.5 rounded-lg bg-amber-50 px-3 py-2 text-xs text-amber-900">{smilesError}</p>}
                <p className="mt-1.5 text-[11px] text-gray-400">Supports C N O S P F Cl Br I, aromatic c n o s, branches ( ), rings, and = # bonds. Charges and stereochemistry are not modelled.</p>
              </div>
              <CandidatesPanel onLoad={onLoadCandidate} />
            </div>

            <div className="min-w-0 space-y-5">
              <div className="rounded-2xl border border-gray-200 bg-white p-5">
                <div className="text-[11px] font-medium uppercase tracking-wide text-gray-400">Molecular formula</div>
                <div className="text-3xl font-semibold text-gray-900" aria-live="polite">{formula}</div>
                {n > 0 && (
                  <div className={`mt-1 text-sm ${id.same ? 'text-emerald-700' : 'text-gray-500'}`}>
                    {id.same ? `Matches ${id.same} in the library` : valid ? 'Not in the built-in library (that does not mean it doesn’t exist)' : ''}
                  </div>
                )}

                {n > 0 && (bad.length > 0 || parts > 1) && (
                  <ul className="mt-3 space-y-1 rounded-lg bg-red-50 px-3 py-2 text-xs text-red-800">
                    {bad.length > 0 && <li>{bad.length} atom{bad.length > 1 ? 's have' : ' has'} too many bonds for its valence (shown in red).</li>}
                    {parts > 1 && <li>The drawing has {parts} separate pieces; the numbers below treat them as one species.</li>}
                  </ul>
                )}

                <dl className="mt-3 divide-y divide-gray-100 text-xs">
                  <div className="flex justify-between py-1.5"><dt className="text-gray-500">Molar mass</dt><dd className="font-medium text-gray-900">{n ? `${mass.toFixed(3)} g/mol` : '—'}</dd></div>
                  <div className="flex justify-between py-1.5"><dt className="text-gray-500">Heavy atoms / bonds / H</dt><dd className="font-medium text-gray-900">{n} / {mol.bonds.length} / {totalH}</dd></div>
                  <div className="flex justify-between py-1.5"><dt className="text-gray-500">Degrees of unsaturation</dt><dd className="font-medium text-gray-900">{n ? (unsat ?? '—') : '—'}</dd></div>
                  <div className="flex justify-between gap-3 py-1.5"><dt className="text-gray-500">SMILES</dt><dd className="min-w-0 break-all text-right font-mono font-medium text-gray-900">{smilesOut || '—'}</dd></div>
                </dl>

                <div className="mt-3">
                  <div className="text-[11px] font-medium uppercase tracking-wide text-gray-400">Functional groups found</div>
                  {groups.length ? (
                    <div className="mt-1.5 flex flex-wrap gap-1.5">{groups.map(g => <span key={g.label} className="rounded-full bg-indigo-50 px-2.5 py-1 text-[11px] font-medium text-indigo-800">{g.label}{g.count > 1 ? ` ×${g.count}` : ''}</span>)}</div>
                  ) : <p className="mt-1 text-xs text-gray-500">{n ? 'None of the recognised groups (an alkane-type framework, or an unusual arrangement).' : 'Draw or load a molecule.'}</p>}
                </div>

                {id.isomers.length > 0 && (
                  <div className="mt-4">
                    <div className="text-[11px] font-medium uppercase tracking-wide text-gray-400">Library isomers of {formula}</div>
                    <div className="mt-1.5 flex flex-wrap gap-1.5">{id.isomers.map(nm => <button key={nm} type="button" onClick={() => loadByName(nm)} className="rounded-full border border-gray-200 px-2.5 py-1 text-[11px] text-gray-700 hover:border-indigo-300 hover:text-indigo-700">{nm}</button>)}</div>
                    <p className="mt-1.5 text-[11px] text-gray-400">Constitutional isomers: same atoms, connected differently. Their properties can differ a lot. Stereoisomers (cis/trans, mirror images) are not distinguished here.</p>
                  </div>
                )}

                <div className="mt-4 flex flex-wrap gap-2">
                  <button type="button" onClick={onSave} disabled={!n} className="rounded-lg bg-indigo-600 px-3 py-1.5 text-xs font-medium text-white enabled:hover:bg-indigo-700 disabled:opacity-40">{saved ? 'Saved ✓' : 'Save candidate'}</button>
                  <button type="button" disabled={!n} onClick={async () => { try { await navigator.clipboard.writeText(smilesOut); setCopied(true); } catch { /* clipboard blocked */ } }} className="rounded-lg border border-gray-200 px-3 py-1.5 text-xs text-gray-700 enabled:hover:border-indigo-300 disabled:opacity-40">{copied ? 'Copied ✓' : 'Copy SMILES'}</button>
                  <button type="button" disabled={!n} onClick={() => download(`${(id.same ?? formula).replace(/[^A-Za-z0-9]+/g, '_')}.mol`, toMolfile(mol, id.same ?? formula), 'chemical/x-mdl-molfile')} className="rounded-lg border border-gray-200 px-3 py-1.5 text-xs text-gray-700 enabled:hover:border-indigo-300 disabled:opacity-40">Download .mol</button>
                  {n > 0 && <Link href={`/chemistry/compound-builder?c=${Object.entries(composition(mol)).map(([s, c]) => `${s}:${c}`).join(',')}`} className="rounded-lg border border-gray-200 px-3 py-1.5 text-xs text-gray-700 hover:border-indigo-300">Open in builder →</Link>}
                </div>
              </div>

              <EvidencePanel
                candidate="You drew or loaded this structure. A valid-looking drawing does not mean the molecule is stable, isolable or easy to make."
                rule={{ label: n ? `${bad.length ? 'Valence rules violated. ' : 'Valences satisfied. '}Groups come from fixed pattern rules on the bond graph.` : 'Draw or load a molecule to run the checks.', ok: n ? valid : null }}
                database={{ state: id.same ? 'warn' : 'no', text: id.same ? `Matched to “${id.same}” in a small built-in library of ${LIBRARY.length} molecules — not a chemical database. Confirm identity in PubChem or similar.` : `Compared only against the built-in library of ${LIBRARY.length} molecules. Use PubChem, ChEBI or a similar database to look a structure up.` }}
                calculated={{ state: 'no', text: 'None. The 2D layout is only a drawing: no 3D geometry, energies, charges, pKa or spectra are calculated.' }}
              />
            </div>
          </div>
        </div>
      </main>
    </>
  );
}
