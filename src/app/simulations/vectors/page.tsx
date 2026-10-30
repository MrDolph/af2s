'use client';
import { useRef, useState } from 'react';
import { AppHeader } from '@/components/layout/AppHeader';
import { EmbedButton } from '@/components/ui/EmbedButton';
import { VectorCanvas } from '@/components/simulation/VectorCanvas';
import { useResponsiveCanvasSize } from '@/hooks/useResponsiveCanvasSize';
import { type P3, type View, DEFAULT_VIEW, P, clampTo, describeDirection, fmt } from '@/lib/physics/space';
import {
  type Context, type Method, type Op, type PracticeKind, type Problem, type Scene, type VMode, type VState, CONTEXTS, COL, PRACTICE_KINDS,
  add, angleBetween, checkProblem, compText, cross, dot, fromPolar, ijk, isZero, mag, minus, neg, projScalar, projVector, scale, sceneFor, sum, toPolar,
  randomProblem, unit, withUnit, workAdd, workComponentsFromPolar, workCross, workDirection, workDot, workMagnitude, workScalar,
} from '@/lib/physics/vectors';

type D = '2d' | '3d';
const CURRICULA = ['WAEC', 'NECO', 'IGCSE', 'SAT', 'JUPEB'];
const CC: Record<string, string> = { WAEC: 'bg-indigo-100 text-indigo-700', NECO: 'bg-pink-100 text-pink-700', IGCSE: 'bg-emerald-100 text-emerald-700', SAT: 'bg-orange-100 text-orange-700', JUPEB: 'bg-purple-100 text-purple-700' };
const MODES: { id: VMode; title: string }[] = [
  { id: 'components', title: 'Components' }, { id: 'add', title: 'Add & subtract' }, { id: 'scalar', title: 'Scalar multiple' },
  { id: 'dot', title: 'Dot product' }, { id: 'cross', title: 'Cross product' }, { id: 'practice', title: '🎯 Practice' },
];
const KIND_LABEL: Record<PracticeKind, string> = { resultant: 'A + B', difference: 'A − B', magnitude: 'Magnitude', direction: 'Direction', scalar: 'Scalar multiple', dot: 'Dot product', angle: 'Angle between', cross: 'Cross product', projection: 'Projection' };

const NOTES: Record<VMode, string[]> = {
  components: [
    'A vector has a magnitude (size) and a direction. Its components are its shadows on the axes: Ax = |A| cos θ and Ay = |A| sin θ.',
    'From components back to the vector: |A| = √(Ax² + Ay² [+ Az²]). The direction is θ = tan⁻¹(Ay/Ax), but always check the quadrant from the signs of Ax and Ay.',
    'The unit vector Â = A/|A| has magnitude 1 and carries only the direction, so A = |A| Â. The unit vectors along the axes are i, j and k.',
    'A free vector is defined by magnitude and direction only: it is the same vector wherever you draw it.',
  ],
  add: [
    'Triangle (tip-to-tail): draw B starting at the tip of A. The resultant goes from the tail of A to the tip of B. Parallelogram: draw both from the same point; the resultant is the diagonal from that point.',
    'In components: R = (Ax + Bx, Ay + By). Subtraction is addition of the reverse: A − B = A + (−B), and A − B is the vector from the tip of B to the tip of A.',
    'Order does not matter (A + B = B + A) and neither does grouping. If vectors drawn tip-to-tail close into a polygon, the resultant is zero: for forces, that means equilibrium.',
    '|A + B| is never more than |A| + |B|; they are equal only when A and B point the same way.',
  ],
  scalar: [
    'Multiplying by a scalar k multiplies every component: kA = (kAx, kAy). The magnitude becomes |k||A|.',
    'If k > 0 the direction is unchanged; if k < 0 the vector reverses; if k = 0 you get the zero vector.',
    'Two vectors are parallel exactly when one is a scalar multiple of the other. The unit vector is (1/|A|)A.',
    'Distributive laws: k(A + B) = kA + kB and (k + m)A = kA + mA.',
  ],
  dot: [
    'The dot (scalar) product A·B = AxBx + AyBy [+ AzBz] = |A||B| cos θ is a number, not a vector.',
    'Its sign tells you about the angle: positive means acute, zero means perpendicular, negative means obtuse. A·B = 0 is the test for perpendicular vectors.',
    'The component of A along B is A·B/|B| (the scalar projection). Physics uses: work W = F·d and power P = F·v.',
    'A·B = B·A, and A·A = |A|².',
  ],
  cross: [
    'The cross (vector) product A × B is a vector perpendicular to both A and B. Its magnitude |A||B| sin θ equals the area of the parallelogram they span.',
    'Direction: right-hand rule. Point your fingers along A, curl them towards B, and your thumb gives A × B.',
    'It is not commutative: B × A = −(A × B). Parallel vectors have a zero cross product.',
    'Used for torque τ = r × F, the magnetic force F = q v × B and angular momentum L = r × p.',
  ],
  practice: [
    'Work out the answer on paper first, then type it in. Use the "working" shown after Reveal to find where a step went wrong.',
    'Check signs: most mistakes in vector problems are sign errors in negative components.',
    'Magnitudes and angles are marked correct within a small rounding tolerance (0.01 for lengths, 0.15° for angles).',
  ],
};
const EXERCISES: Record<VMode, { q: string; a: string }[]> = {
  components: [
    { q: 'A force of 50 N acts at 36.9° above the +x axis. Find its components.', a: 'Fx = 50 cos 36.9° ≈ 40 N and Fy = 50 sin 36.9° ≈ 30 N.' },
    { q: 'A = (−6, 8). Find |A| and its direction measured from +x.', a: '|A| = √(36 + 64) = 10. The reference angle is tan⁻¹(8/6) = 53.1°, and A is in quadrant II, so θ = 180° − 53.1° = 126.9°.' },
    { q: 'A vector has |A| = 13 and Ax = 5, pointing upwards (Ay > 0). Find Ay and the unit vector Â.', a: 'Ay = √(13² − 5²) = 12. Â = (5/13, 12/13) = (0.385, 0.923).' },
  ],
  add: [
    { q: 'A = (3, 4) and B = (−1, 2). Find A + B, its magnitude and direction, and A − B.', a: 'A + B = (2, 6), |A + B| = √40 ≈ 6.32, θ = tan⁻¹(6/2) = 71.6°. A − B = (4, 2).' },
    { q: 'A student walks 5 m east then 12 m north. Find the distance walked and the displacement.', a: 'Distance = 17 m. Displacement = (5, 12): magnitude 13 m at tan⁻¹(12/5) = 67.4° north of east.' },
    { q: 'Forces F₁ = (3, 4) N and F₂ = (−5, 1) N act on a body in equilibrium together with F₃. Find F₃.', a: 'F₁ + F₂ + F₃ = 0, so F₃ = −(F₁ + F₂) = −(−2, 5) = (2, −5) N.' },
  ],
  scalar: [
    { q: 'A = (2, −3). Find 3A, −A and 0.5A.', a: '3A = (6, −9); −A = (−2, 3); 0.5A = (1, −1.5).' },
    { q: 'Is (6, −9) parallel to (2, −3)?', a: 'Yes: (6, −9) = 3 × (2, −3), so they are parallel and point the same way.' },
    { q: 'Find the unit vector in the direction of (3, 4), and a vector of magnitude 10 in that direction.', a: 'Unit vector = (3/5, 4/5) = (0.6, 0.8). A vector of magnitude 10 is 10 × (0.6, 0.8) = (6, 8).' },
  ],
  dot: [
    { q: 'A = (2, 3) and B = (4, −1). Find A·B and the angle between them.', a: 'A·B = 8 − 3 = 5. |A| = √13, |B| = √17, so cos θ = 5/√221 = 0.336 and θ = 70.3°.' },
    { q: 'A force F = (10, 0) N moves a body through d = (3, 4) m. Find the work done.', a: 'W = F·d = (10)(3) + (0)(4) = 30 J.' },
    { q: 'For which value of k are (3, 4) and (k, 6) perpendicular?', a: 'Perpendicular means the dot product is 0: 3k + 24 = 0, so k = −8.' },
  ],
  cross: [
    { q: 'A = (1, 2, 3) and B = (4, 5, 6). Find A × B and its magnitude.', a: 'A × B = (2·6 − 3·5, 3·4 − 1·6, 1·5 − 2·4) = (−3, 6, −3). Magnitude = √(9 + 36 + 9) = √54 ≈ 7.35.' },
    { q: 'A wrench arm r = (2, 0, 0) m has a force F = (0, 3, 0) N applied. Find the torque r × F.', a: 'τ = (0·0 − 0·3, 0·0 − 2·0, 2·3 − 0·0) = (0, 0, 6) N·m: magnitude 6 N·m, along +z.' },
    { q: 'Find the area of the parallelogram with sides (3, 0) and (1, 2).', a: 'Area = |Ax By − Ay Bx| = |3·2 − 0·1| = 6.' },
  ],
  practice: [
    { q: 'Tip: unsure how to start? Return to the mode for that operation, set the same vectors, and compare your working with the steps shown.', a: 'Each mode shows the working for exactly the numbers on screen.' },
  ],
};

const DEFAULTS: Record<D, { A: P3; B: P3; C: P3 }> = {
  '2d': { A: P(3, 4), B: P(-1, 2), C: P(-2, -5) },
  '3d': { A: P(3, 2, 1), B: P(1, 3, 2), C: P(-2, 1, -1) },
};

function NumField({ label, value, onCommit, min, max, color, step }: { label: string; value: number; onCommit: (v: number) => void; min: number; max: number; color?: string; step?: string }) {
  const [text, setText] = useState<string | null>(null);
  return (
    <label className="flex min-w-0 flex-1 items-center gap-1.5 text-xs">
      <span className="font-semibold" style={{ color }}>{label}</span>
      <input type="number" inputMode="decimal" step={step ?? 'any'} min={min} max={max} aria-label={label} value={text ?? String(Number(value.toFixed(2)))}
        onChange={e => { setText(e.target.value); const v = Number(e.target.value); if (e.target.value !== '' && e.target.value !== '-' && Number.isFinite(v)) onCommit(clampTo(v, max)); }}
        onBlur={() => setText(null)} className="h-8 w-full min-w-0 rounded-md border border-gray-200 bg-white px-2 text-sm tabular-nums" />
    </label>
  );
}
const Stat = ({ k, v, c = 'text-gray-900' }: { k: string; v: React.ReactNode; c?: string }) => (
  <div className="flex items-center justify-between gap-3 rounded-lg bg-gray-50 px-3 py-2"><span className="text-xs text-gray-500">{k}</span><span className={`text-right text-sm font-semibold tabular-nums ${c}`}>{v}</span></div>
);
const Toggle = ({ label, on, set }: { label: string; on: boolean; set: (v: boolean) => void }) => (
  <label className="flex items-center gap-1.5 text-xs text-gray-600"><input type="checkbox" checked={on} onChange={e => set(e.target.checked)} />{label}</label>
);
const Seg = <T extends string>({ value, options, set, label }: { value: T; options: { id: T; label: string }[]; set: (v: T) => void; label: string }) => (
  <div className="flex overflow-hidden rounded-md border border-gray-200" role="group" aria-label={label}>
    {options.map(o => <button key={o.id} type="button" aria-pressed={value === o.id} onClick={() => set(o.id)} className={`px-2.5 py-1.5 text-xs ${value === o.id ? 'bg-indigo-600 text-white' : 'bg-white text-gray-600 hover:bg-gray-50'}`}>{o.label}</button>)}
  </div>
);

export default function VectorsPage() {
  const [dim, setDim] = useState<D>('2d');
  const [mode, setMode] = useState<VMode>('components');
  const [ctx, setCtx] = useState<Context>('generic');
  const [vecs, setVecs] = useState(DEFAULTS);
  const [k, setK] = useState(2);
  const [op, setOp] = useState<Op>('A+B');
  const [method, setMethod] = useState<Method>('triangle');
  const [useC, setUseC] = useState(false);
  const [showComponents, setShowComponents] = useState(true);
  const [showUnit, setShowUnit] = useState(false);
  const [showAngle, setShowAngle] = useState(true);
  const [snap, setSnap] = useState(1);
  const [view, setView] = useState<View>(DEFAULT_VIEW);
  const [dragAxis, setDragAxis] = useState<'floor' | 'height'>('floor');
  const [planes, setPlanes] = useState(true); const [grid, setGrid] = useState(true);
  const [openEx, setOpenEx] = useState<number | null>(null);
  const [curr, setCurr] = useState(['WAEC', 'IGCSE', 'SAT']);
  // practice
  const [kind, setKind] = useState<PracticeKind | 'mixed'>('mixed');
  const [problem, setProblem] = useState<Problem | null>(null);
  const [typed, setTyped] = useState<string[]>(['', '', '']);
  const [result, setResult] = useState<{ correct: boolean; wrong: number[]; revealed?: boolean } | null>(null);
  const [score, setScore] = useState({ right: 0, tries: 0 });

  const boxRef = useRef<HTMLDivElement>(null);
  const size = useResponsiveCanvasSize(boxRef, 660, dim === '3d' ? 500 : 520, 900);
  const compact = size.width < 560;
  const canvasH = compact ? Math.round(size.width * 1.0) : size.height;

  const { A, B, C } = vecs[dim];
  const state: VState = { A, B, C, k, op, method, useC, showComponents, showUnit, showAngle };
  const practicing = mode === 'practice';

  const newProblem = (kk: PracticeKind | 'mixed' = kind, d: D = dim) => { setProblem(randomProblem(kk, d)); setTyped(['', '', '']); setResult(null); };
  const changeMode = (m: VMode) => { setMode(m); setResult(null); if (m === 'practice' && !problem) newProblem(kind, dim); };
  const changeDim = (d: D) => { setDim(d); setResult(null); if (practicing) newProblem(kind, d); };

  const practiceScene = (p: Problem): Scene => {
    const sc: Scene = { arrows: [{ from: P(), to: p.A, color: COL.A, width: 3.2, label: 'A', labelAt: 0.55 }], polys: [], arcs: [], handles: [], marks: [] };
    if (!['magnitude', 'direction', 'scalar'].includes(p.kind)) sc.arrows.push({ from: P(), to: p.B, color: COL.B, width: 3.2, label: 'B', labelAt: 0.55 });
    return sc;
  };
  const scene: Scene = practicing ? (problem ? practiceScene(problem) : { arrows: [], polys: [], arcs: [], handles: [], marks: [] }) : sceneFor(mode, dim, state, ctx);

  const setVec = (id: 'A' | 'B' | 'C', v: P3) => setVecs(s => ({ ...s, [dim]: { ...s[dim], [id]: dim === '2d' ? P(v.x, v.y, 0) : v } }));
  const onHandle = (id: 'A' | 'B' | 'C', at: P3) => {
    const h = scene.handles.find(x => x.id === id); if (!h) return;
    setVec(id, scale(minus(at, h.base), h.mul ?? 1));
  };

  // derived values
  const R = op === 'B−A' ? minus(B, A) : op === 'A−B' ? minus(A, B) : add(A, B);
  const Rtot = useC ? add(R, C) : R;
  const kA = scale(A, k);
  const ang = angleBetween(A, B);
  const X = cross(A, B);
  const dirText = (v: P3) => describeDirection(v, dim);
  const active: ('A' | 'B' | 'C')[] = mode === 'components' || mode === 'scalar' ? ['A'] : mode === 'add' ? (useC ? ['A', 'B', 'C'] : ['A', 'B']) : mode === 'dot' || mode === 'cross' ? ['A', 'B'] : [];
  const col = { A: COL.A, B: COL.B, C: COL.C };
  const comp: ('x' | 'y' | 'z')[] = dim === '2d' ? ['x', 'y'] : ['x', 'y', 'z'];
  const rg = 12;

  const check = () => {
    if (!problem) return;
    const given = problem.answer.map((_, i) => (typed[i].trim() === '' ? NaN : Number(typed[i])));
    if (given.some(g => !Number.isFinite(g))) { setResult({ correct: false, wrong: [], revealed: false }); return; }
    const r = checkProblem(problem, given); setResult(r); setScore(s => ({ right: s.right + (r.correct ? 1 : 0), tries: s.tries + 1 }));
  };

  const working: string[] = [];
  if (!practicing) {
    if (mode === 'components') {
      working.push(workMagnitude(A, dim));
      if (dim === '2d') working.push(workDirection(A)); else { const dd = dirText(A); working.push(`Direction: ${dd.text}`); }
      if (dim === '2d' && !isZero(A)) { const p = toPolar(A); workComponentsFromPolar(p.r, p.theta).forEach(l => working.push(l)); }
    }
    if (mode === 'add') {
      const first = op === 'B−A' ? B : A, second = op === 'B−A' ? A : B, n1 = op === 'B−A' ? 'B' : 'A', n2 = op === 'B−A' ? 'A' : 'B';
      workAdd(first, second, dim, op === 'A+B' ? '+' : '−', n1, n2, 'R').forEach(l => working.push(l));
      working.push(workMagnitude(R, dim, 'R'));
      if (dim === '2d') working.push(workDirection(R));
      if (useC) { workAdd(R, C, dim, '+', 'R', 'C', 'R′').forEach(l => working.push(l)); }
    }
    if (mode === 'scalar') { workScalar(A, k, dim).forEach(l => working.push(l)); working.push(`|kA| = |k||A| = ${fmt(Math.abs(k))} × ${fmt(mag(A))} = ${fmt(mag(kA))}`); }
    if (mode === 'dot') workDot(A, B, dim).forEach(l => working.push(l));
    if (mode === 'cross') { if (dim === '3d') workCross(A, B).forEach(l => working.push(l)); else working.push(`(A×B)z = AxBy − AyBx = (${fmt(A.x)})(${fmt(B.y)}) − (${fmt(A.y)})(${fmt(B.x)}) = ${fmt(X.z)}`); working.push(`|A×B| = ${fmt(mag(X))}`); }
  }

  const unitA = unit(A);

  return (
    <>
      <AppHeader />
      <main className="min-h-screen bg-gray-50">
        <section className="border-b border-gray-200 bg-white">
          <div className="mx-auto max-w-[100rem] px-4 py-4 sm:px-6">
            <div className="flex flex-col justify-between gap-3 sm:flex-row sm:items-center">
              <div><p className="mb-0.5 text-xs text-gray-400">Space and time</p><h1 className="text-lg font-semibold text-gray-900">Vectors: components, addition &amp; products</h1></div>
              <div className="flex flex-wrap gap-1.5">{CURRICULA.map(c => <button key={c} onClick={() => setCurr(s => (s.includes(c) ? s.filter(x => x !== c) : [...s, c]))} className={`rounded-full border px-2.5 py-2 text-xs font-medium transition ${curr.includes(c) ? CC[c] + ' border-transparent' : 'border-gray-200 bg-white text-gray-400'}`}>{c}</button>)}</div>
            </div>
          </div>
        </section>

        <div className="mx-auto max-w-[100rem] space-y-4 px-4 py-4 sm:px-6">
          <div className="flex flex-wrap items-center gap-3">
            <div className="flex gap-1 rounded-xl bg-gray-100 p-1" role="tablist" aria-label="Dimensions">
              {(['2d', '3d'] as D[]).map(d => <button key={d} role="tab" aria-selected={dim === d} onClick={() => changeDim(d)} className={`rounded-lg px-4 py-2 text-xs font-medium transition ${dim === d ? 'bg-white text-indigo-700 shadow-sm' : 'text-gray-500 hover:text-gray-700'}`}>{d === '2d' ? '2D · Plane' : '3D · Space'}</button>)}
            </div>
            <label className="flex items-center gap-1.5 text-xs text-gray-600">Think of the vectors as
              <select value={ctx} onChange={e => setCtx(e.target.value as Context)} className="h-8 rounded-md border border-gray-200 bg-white px-2 text-xs">{(Object.keys(CONTEXTS) as Context[]).map(c => <option key={c} value={c}>{CONTEXTS[c].label}{CONTEXTS[c].unit ? ` (${CONTEXTS[c].unit})` : ''}</option>)}</select>
            </label>
          </div>
          <div className="flex gap-1 overflow-x-auto" role="tablist" aria-label="Topic">
            {MODES.map(m => <button key={m.id} role="tab" aria-selected={mode === m.id} onClick={() => changeMode(m.id)} className={`shrink-0 rounded-full border px-3.5 py-1.5 text-xs font-medium transition ${mode === m.id ? 'border-indigo-600 bg-indigo-600 text-white' : 'border-gray-200 bg-white text-gray-600 hover:border-indigo-300'}`}>{m.title}</button>)}
          </div>

          <div className="grid grid-cols-1 gap-4 lg:grid-cols-[1fr_320px] xl:grid-cols-[1fr_320px_280px]">
            <div className="min-w-0 space-y-3">
              <div ref={boxRef} className="overflow-hidden rounded-2xl border border-gray-200 bg-white p-2 shadow-sm">
                <VectorCanvas dim={dim} width={size.width} height={canvasH} scene={scene} snap={snap} view={view} onView={setView} dragAxis={dragAxis} showPlanes={planes} showGrid={grid}
                  readOnly={practicing} onHandle={onHandle}
                  ariaLabel={`${dim === '2d' ? '2D' : '3D'} vector diagram. ${practicing ? 'The vectors for the current problem are drawn from the origin.' : 'Drag the coloured handles at the tips of the vectors, or focus the diagram and use the arrow keys.'}`} />
              </div>
              <div className="flex flex-wrap items-center gap-x-4 gap-y-2 rounded-xl border border-gray-200 bg-white px-3 py-2.5">
                <label className="flex items-center gap-1.5 text-xs text-gray-600">Snap
                  <select value={snap} onChange={e => setSnap(Number(e.target.value))} className="h-7 rounded-md border border-gray-200 bg-white px-1.5 text-xs"><option value={1}>whole numbers</option><option value={0.5}>0.5</option><option value={0}>0.1 (free)</option></select>
                </label>
                {!practicing && (mode === 'components' || mode === 'scalar') && <Toggle label="Unit vector Â" on={showUnit} set={setShowUnit} />}
                {!practicing && mode === 'components' && <Toggle label="Components" on={showComponents} set={setShowComponents} />}
                {!practicing && mode !== 'scalar' && (dim === '2d' || mode !== 'components') && <Toggle label="Angle" on={showAngle} set={setShowAngle} />}
                {dim === '3d' && <>
                  <div className="flex items-center gap-1.5 text-xs text-gray-600">Drag tip <Seg value={dragAxis} set={setDragAxis} label="Drag direction" options={[{ id: 'floor', label: 'across floor' }, { id: 'height', label: 'up / down' }]} /></div>
                  <Toggle label="Planes" on={planes} set={setPlanes} />
                </>}
                <Toggle label="Grid" on={grid} set={setGrid} />
                <div className="ml-auto"><EmbedButton path="/embed/vectors" title="Vectors — A-Factor STEM Studio" params={{ dim, mode: practicing ? 'add' : mode, A: `${A.x},${A.y},${A.z}`, B: `${B.x},${B.y},${B.z}`, k: String(k) }} /></div>
              </div>
              <p className="text-[11px] text-gray-400">{practicing ? 'Practice: the problem’s vectors are drawn from the origin on the grid.' : `Drag the coloured dots at the vector tips${dim === '3d' ? ', drag empty space to rotate' : ''}; or click the diagram and use the arrow keys${dim === '3d' ? ' (Page Up/Down for z)' : ''}.`}</p>
            </div>

            <div className="min-w-0 space-y-3">
              {!practicing && (
                <div className="space-y-3 rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                  <p className="text-xs font-medium uppercase tracking-wide text-gray-400">{active.length > 1 ? 'Vectors' : 'Vector A'}</p>
                  {active.map(id => {
                    const v = vecs[dim][id], p = toPolar(v);
                    return (
                      <div key={id} className="space-y-1.5 rounded-xl border border-gray-100 p-2">
                        <div className="text-xs font-semibold" style={{ color: col[id] }}>{id} = {compText(v, dim, 2)} = {ijk(v, dim)}</div>
                        <div className="flex gap-1.5">{comp.map(c => <NumField key={c} label={`${id}${c}`} value={v[c]} min={-rg * 4} max={rg * 4} color={col[id]} onCommit={n => setVec(id, { ...v, [c]: n })} />)}</div>
                        {dim === '2d' && <div className="flex gap-1.5"><NumField label={`|${id}|`} value={p.r} min={0} max={rg * 6} color={col[id]} onCommit={n => setVec(id, fromPolar(n, p.theta))} /><NumField label="θ°" value={p.theta} min={0} max={360} color={col[id]} onCommit={n => setVec(id, fromPolar(p.r, n))} /></div>}
                      </div>
                    );
                  })}
                  {mode === 'scalar' && (
                    <div className="space-y-1.5"><div className="flex items-center gap-2"><NumField label="k" value={k} min={-10} max={10} color={COL.R} onCommit={setK} /></div><input type="range" min={-3} max={3} step={0.5} value={Math.max(-3, Math.min(3, k))} onChange={e => setK(Number(e.target.value))} aria-label="k slider" className="w-full" style={{ accentColor: COL.R }} /></div>
                  )}
                  {mode === 'add' && (
                    <div className="space-y-2">
                      <div className="flex flex-wrap items-center gap-2"><span className="text-xs text-gray-500">Operation</span><Seg value={op} set={setOp} label="Operation" options={[{ id: 'A+B', label: 'A + B' }, { id: 'A−B', label: 'A − B' }, { id: 'B−A', label: 'B − A' }]} /></div>
                      <div className="flex flex-wrap items-center gap-2"><span className="text-xs text-gray-500">Method</span><Seg value={method} set={setMethod} label="Method" options={[{ id: 'triangle', label: 'Tip-to-tail' }, { id: 'parallelogram', label: 'Parallelogram' }, { id: 'both', label: 'Both' }]} /></div>
                      {op === 'A+B' && <Toggle label="Add a third vector C (polygon rule)" on={useC} set={setUseC} />}
                    </div>
                  )}
                  <div className="flex flex-wrap gap-1.5">
                    <button onClick={() => setVecs(s => ({ ...s, [dim]: DEFAULTS[dim] }))} className="rounded-md border border-gray-200 px-2.5 py-1 text-[11px] text-gray-600 hover:border-indigo-300">Reset</button>
                    {mode === 'dot' && dim === '2d' && <button onClick={() => setVecs(s => ({ ...s, '2d': { ...s['2d'], B: P(-s['2d'].A.y, s['2d'].A.x) } }))} className="rounded-md border border-gray-200 px-2.5 py-1 text-[11px] text-gray-600 hover:border-indigo-300">Make B ⟂ A</button>}
                    {mode === 'add' && <button onClick={() => { if (!useC) setUseC(true); setVec('C', neg(add(A, B))); }} className="rounded-md border border-gray-200 px-2.5 py-1 text-[11px] text-gray-600 hover:border-indigo-300">Balance with C</button>}
                  </div>
                </div>
              )}

              {!practicing && (
                <div className="space-y-2 rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                  <p className="text-xs font-medium uppercase tracking-wide text-gray-400">Results</p>
                  {mode === 'components' && (<>
                    <Stat k="Magnitude |A|" v={withUnit(fmt(mag(A)), ctx)} c="text-indigo-600" />
                    <Stat k="Components" v={compText(A, dim)} />
                    {unitA && <Stat k="Unit vector Â" v={compText(unitA, dim, 3)} />}
                    <div className="rounded-lg bg-gray-50 px-3 py-2 text-xs leading-relaxed text-gray-700"><span className="font-medium">Direction: </span>{isZero(A) ? 'The zero vector has no direction.' : dirText(A).text}{dim === '2d' && !isZero(A) && dirText(A).bearing !== undefined ? ` · bearing ${fmt(dirText(A).bearing!, 1)}°` : ''}</div>
                    {dim === '3d' && !isZero(A) && <div className="rounded-lg bg-gray-50 px-3 py-2 text-xs leading-relaxed text-gray-700">Angles with the axes: x {fmt(dirText(A).axisAngles!.x, 1)}°, y {fmt(dirText(A).axisAngles!.y, 1)}°, z {fmt(dirText(A).axisAngles!.z, 1)}°</div>}
                  </>)}
                  {mode === 'add' && (<>
                    <Stat k={`${op === 'A+B' ? (useC ? 'A + B + C' : 'A + B') : op === 'A−B' ? 'A − B' : 'B − A'} (${CONTEXTS[ctx].resultant.toLowerCase()})`} v={compText(Rtot, dim)} c="text-rose-600" />
                    <Stat k="Magnitude" v={withUnit(fmt(mag(Rtot)), ctx)} c="text-rose-600" />
                    <div className="rounded-lg bg-rose-50 px-3 py-2 text-xs leading-relaxed text-rose-900"><span className="font-medium">Direction: </span>{isZero(Rtot) ? 'Zero vector.' : dirText(Rtot).text}</div>
                    {ang !== null && <Stat k="Angle between A and B" v={`${fmt(ang, 1)}°`} />}
                    <div className="rounded-lg bg-gray-50 px-3 py-2 text-xs leading-relaxed text-gray-700">
                      {isZero(Rtot) ? <span className="font-medium text-emerald-700">The resultant is zero: the vectors close into a polygon. For forces this means the body is in equilibrium.</span>
                        : op === 'A+B' && !useC ? <>Order does not matter: B + A = {compText(add(B, A), dim)} = A + B. Also |A + B| = {fmt(mag(R))} ≤ |A| + |B| = {fmt(mag(A) + mag(B))}.</>
                        : <>Check: {op === 'A−B' ? 'A − B is the vector from the tip of B to the tip of A.' : op === 'B−A' ? 'B − A is the vector from the tip of A to the tip of B, the opposite of A − B.' : `A + B + C = ${compText(sum([A, B, C]), dim)}.`}</>}
                    </div>
                  </>)}
                  {mode === 'scalar' && (<>
                    <Stat k={`kA with k = ${fmt(k)}`} v={compText(kA, dim)} c="text-rose-600" />
                    <Stat k="Magnitude |kA|" v={withUnit(fmt(mag(kA)), ctx)} c="text-rose-600" />
                    <div className="rounded-lg bg-gray-50 px-3 py-2 text-xs leading-relaxed text-gray-700">{k === 0 ? 'k = 0 gives the zero vector.' : k > 0 ? `k > 0: same direction as A, ${k > 1 ? 'stretched' : k < 1 ? 'shrunk' : 'unchanged'}.` : `k < 0: opposite direction to A, ${Math.abs(k) > 1 ? 'stretched' : Math.abs(k) < 1 ? 'shrunk' : 'same length'}.`}</div>
                    {unitA && <Stat k="Unit vector Â" v={compText(unitA, dim, 3)} />}
                  </>)}
                  {mode === 'dot' && (<>
                    <Stat k="A·B" v={fmt(dot(A, B))} c="text-indigo-600" />
                    <Stat k="Angle θ" v={ang === null ? 'undefined' : `${fmt(ang, 1)}°`} />
                    <Stat k="Scalar projection of A on B" v={projScalar(A, B) === null ? '—' : fmt(projScalar(A, B)!)} c="text-cyan-700" />
                    <Stat k="Vector projection" v={projVector(A, B) ? compText(projVector(A, B)!, dim) : '—'} />
                    <div className={`rounded-lg px-3 py-2 text-xs leading-relaxed ${Math.abs(dot(A, B)) < 1e-9 ? 'bg-emerald-50 text-emerald-900' : 'bg-gray-50 text-gray-700'}`}>{Math.abs(dot(A, B)) < 1e-9 ? 'A·B = 0: the vectors are perpendicular (or one is zero).' : dot(A, B) > 0 ? 'A·B > 0: the angle is acute (less than 90°).' : 'A·B < 0: the angle is obtuse (more than 90°).'} Example: a force A (N) moving a body through B (m) does work W = A·B joules.</div>
                  </>)}
                  {mode === 'cross' && (<>
                    {dim === '3d' ? <Stat k="A × B (drawn shortened if long)" v={compText(X, dim)} c="text-violet-700" /> : <Stat k="A × B (along z)" v={`(0, 0, ${fmt(X.z)})`} c="text-violet-700" />}
                    <Stat k="|A × B| = parallelogram area" v={fmt(mag(X))} c="text-violet-700" />
                    <Stat k="Check |A||B| sin θ" v={ang === null ? '—' : fmt(mag(A) * mag(B) * Math.sin((ang * Math.PI) / 180))} />
                    <div className="rounded-lg bg-gray-50 px-3 py-2 text-xs leading-relaxed text-gray-700">
                      {isZero(X) ? 'A × B = 0: the vectors are parallel (or one is zero), so the parallelogram has no area.' : dim === '3d' ? <>Right-hand rule: fingers along A, curl towards B, thumb along A × B. Check: (A×B)·A = {fmt(dot(X, A))} and (A×B)·B = {fmt(dot(X, B))}, both zero because A × B is perpendicular to each. B × A = {compText(neg(X), dim)}.</> : <>In 2D the cross product points along the z-axis, {X.z > 0 ? 'out of the page (B is counter-clockwise from A)' : 'into the page (B is clockwise from A)'}. <button className="font-medium text-indigo-600 hover:underline" onClick={() => changeDim('3d')}>Switch to 3D to see it.</button></>}
                    </div>
                  </>)}
                </div>
              )}

              {!practicing && working.length > 0 && (
                <details open className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                  <summary className="cursor-pointer text-xs font-medium uppercase tracking-wide text-gray-400">Working</summary>
                  <div className="mt-2 space-y-1.5">{working.map((l, i) => <p key={i} className="font-mono text-[11px] leading-relaxed text-gray-700">{l}</p>)}</div>
                </details>
              )}

              {practicing && (
                <div className="space-y-3 rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                  <div className="flex items-center justify-between"><p className="text-xs font-medium uppercase tracking-wide text-gray-400">Practice</p><span className="rounded-full bg-gray-100 px-2.5 py-1 text-[11px] font-medium text-gray-600">Score {score.right} / {score.tries}</span></div>
                  <label className="flex items-center gap-2 text-xs text-gray-600">Topic
                    <select value={kind} onChange={e => { const v = e.target.value as PracticeKind | 'mixed'; setKind(v); newProblem(v); }} className="h-8 flex-1 rounded-md border border-gray-200 bg-white px-2 text-xs">
                      <option value="mixed">Mixed</option>{PRACTICE_KINDS[dim].map(kk => <option key={kk} value={kk}>{KIND_LABEL[kk]}</option>)}
                    </select>
                  </label>
                  {problem && (<>
                    <p className="rounded-lg bg-indigo-50 px-3 py-2 text-sm leading-relaxed text-indigo-900">{problem.prompt}</p>
                    <div className="flex gap-2">{problem.inputs.map((lab, i) => (
                      <label key={i} className="flex min-w-0 flex-1 flex-col gap-1 text-[11px] text-gray-500">{lab}
                        <input type="number" inputMode="decimal" step="any" value={typed[i]} aria-label={lab} onChange={e => { setTyped(t => t.map((x, j) => (j === i ? e.target.value : x))); setResult(null); }} className={`h-8 w-full min-w-0 rounded-md border px-2 text-sm ${result && result.wrong.includes(i) ? 'border-red-300 bg-red-50' : 'border-gray-200'}`} />
                      </label>))}</div>
                    <div className="flex flex-wrap gap-2">
                      <button onClick={check} className="rounded-lg bg-indigo-600 px-4 py-2 text-xs font-medium text-white hover:bg-indigo-700">Check</button>
                      <button onClick={() => newProblem()} className="rounded-lg border border-gray-200 bg-white px-4 py-2 text-xs text-gray-700 hover:border-indigo-300">New problem</button>
                      <button onClick={() => setResult({ correct: false, wrong: [], revealed: true })} className="rounded-lg border border-gray-200 bg-white px-3 py-2 text-xs text-gray-500">Reveal</button>
                    </div>
                    {result && (
                      <div aria-live="polite" className={`rounded-lg px-3 py-2 text-xs leading-relaxed ${result.correct ? 'bg-emerald-50 text-emerald-900' : 'bg-amber-50 text-amber-900'}`}>
                        {result.correct ? '✓ Correct!' : result.revealed ? <>Answer: <span className="font-semibold">{problem.answer.map(a => fmt(a, 2)).join(', ')}</span>{problem.unit ? ` ${problem.unit}` : ''}. <span className="font-mono">{problem.explain}</span></> : result.wrong.length ? `Not quite: check ${result.wrong.map(i => problem.inputs[i]).join(' and ')}.` : 'Fill in every box first.'}
                      </div>
                    )}
                  </>)}
                </div>
              )}
            </div>

            <div className="space-y-3 lg:col-span-2 xl:col-span-1">
              <div className="rounded-2xl border border-amber-100 bg-amber-50 p-4">
                <p className="mb-3 text-xs font-medium uppercase tracking-wide text-amber-700">📋 Teacher notes</p>
                <ul className="space-y-2">{NOTES[mode].map((n, i) => <li key={i} className="flex gap-2 text-xs leading-relaxed text-amber-900"><span className="mt-0.5 shrink-0 text-amber-400">•</span>{n}</li>)}</ul>
              </div>
              <div className="rounded-2xl border border-gray-200 bg-white p-4">
                <p className="mb-3 text-xs font-medium uppercase tracking-wide text-gray-500">✏️ Exercises</p>
                <div className="space-y-2">{EXERCISES[mode].map((ex, i) => (
                  <div key={`${mode}-${i}`} className="overflow-hidden rounded-xl border border-gray-100">
                    <button onClick={() => setOpenEx(openEx === i ? null : i)} aria-expanded={openEx === i} className="flex w-full justify-between gap-2 px-3 py-2.5 text-left text-xs leading-relaxed text-gray-700 transition hover:bg-gray-50"><span><span className="font-medium text-indigo-600">Q{i + 1}.</span> {ex.q}</span><span className="shrink-0 text-sm text-gray-300">{openEx === i ? '▲' : '▼'}</span></button>
                    {openEx === i && <div className="border-t border-gray-100 bg-emerald-50 px-3 py-2.5 text-xs leading-relaxed text-emerald-800"><span className="font-medium">Answer: </span>{ex.a}</div>}
                  </div>))}</div>
              </div>
              <div className="rounded-2xl border border-gray-100 bg-white p-4"><p className="mb-2 text-xs text-gray-400">Curriculum</p><div className="flex flex-wrap gap-1.5">{CURRICULA.map(c => <span key={c} className={`rounded-full px-2 py-0.5 text-xs font-medium ${curr.includes(c) ? CC[c] : 'bg-gray-100 text-gray-400'}`}>{c}</span>)}</div></div>
            </div>
          </div>
        </div>
      </main>
    </>
  );
}
