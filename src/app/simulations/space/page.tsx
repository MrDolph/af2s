'use client';
import { useEffect, useRef, useState } from 'react';
import { AppHeader } from '@/components/layout/AppHeader';
import { EmbedButton } from '@/components/ui/EmbedButton';
import { SpaceCanvas, POINT_COLORS, type Activity } from '@/components/simulation/SpaceCanvas';
import { useResponsiveCanvasSize } from '@/hooks/useResponsiveCanvasSize';
import {
  type Dim, type P3, type View, DEFAULT_VIEW, JOURNEY_PRESETS, LABELS, MAX_POINTS, P, RANGE, analyseJourney, checkAnswer, clampDim,
  clampTo, coordText, distanceWorking, fmt, len, octant, quadrant, randomTarget,
} from '@/lib/physics/space';

const CURRICULA = ['WAEC', 'NECO', 'IGCSE', 'SAT', 'JUPEB'];
const CC: Record<string, string> = { WAEC: 'bg-indigo-100 text-indigo-700', NECO: 'bg-pink-100 text-pink-700', IGCSE: 'bg-emerald-100 text-emerald-700', SAT: 'bg-orange-100 text-orange-700', JUPEB: 'bg-purple-100 text-purple-700' };
const DIMS: { id: Dim; title: string; icon: string; sub: string }[] = [
  { id: '1d', title: '1D · Line', icon: '📏', sub: 'One number locates a point: x' },
  { id: '2d', title: '2D · Plane', icon: '🗺️', sub: 'Two numbers locate a point: (x, y)' },
  { id: '3d', title: '3D · Space', icon: '🧊', sub: 'Three numbers locate a point: (x, y, z)' },
];
const ACTS: { id: Activity; title: string; icon: string }[] = [
  { id: 'locate', title: 'Locate a point', icon: '📍' }, { id: 'journey', title: 'Distance & displacement', icon: '🧭' }, { id: 'practice', title: 'Practice', icon: '🎯' },
];
const VIEWS: { label: string; v: View }[] = [
  { label: 'Default', v: DEFAULT_VIEW }, { label: 'Top (xy)', v: { yaw: 0, pitch: (85 * Math.PI) / 180 } },
  { label: 'Front (xz)', v: { yaw: -Math.PI / 2, pitch: (6 * Math.PI) / 180 } }, { label: 'Side (yz)', v: { yaw: 0, pitch: (6 * Math.PI) / 180 } },
];

const NOTES: Record<Dim, string[]> = {
  '1d': [
    'Position is a signed number: its sign tells you the side of the origin, its size tells you how far.',
    'Always say where the origin is and which way is positive before you calculate anything.',
    'Distance is a scalar (path length, never negative). Displacement is a vector: Δx = x_final − x_initial, and its sign is its direction.',
    'Reversing direction adds to the distance but subtracts from the displacement. A round trip has displacement zero.',
  ],
  '2d': [
    'An ordered pair (x, y): x is read first (horizontal), then y (vertical). (3, 4) and (4, 3) are different points.',
    'The signs of x and y give the quadrant: I (+,+), II (−,+), III (−,−), IV (+,−).',
    'The distance between two points is Pythagoras on the differences: d = √(Δx² + Δy²). Δx and Δy are the legs of a right triangle.',
    'Direction: θ is measured counter-clockwise from +x, but exams often use a bearing (clockwise from north). Bearing = 90° − θ (add 360° if negative).',
  ],
  '3d': [
    'Three numbers locate a point in space: walk x along the X axis, then y parallel to Y, then z parallel to Z. The order does not matter.',
    'The axes are right-handed: point the fingers of your right hand along +X, curl them towards +Y, and your thumb points along +Z.',
    'A point’s distance from a coordinate plane is the absolute value of the one coordinate that plane does not contain: |z| from the xy-plane, |x| from the yz-plane, |y| from the xz-plane.',
    'The distance between two points extends Pythagoras to three terms: d = √(Δx² + Δy² + Δz²). Rotate the view to see the right triangles inside the box.',
  ],
};
const EXERCISES: Record<Dim, { q: string; a: string }[]> = {
  '1d': [
    { q: 'A runner starts at x = 2 m, runs to x = 9 m, then back to x = 4 m. Find the distance and the displacement.', a: 'Distance = 7 + 5 = 12 m. Displacement = 4 − 2 = +2 m (2 m in the +x direction).' },
    { q: 'A lift starts at +15 m (5th floor) and stops at −6 m (basement), with the upward direction positive. Find the distance and displacement.', a: 'Distance = 21 m. Displacement = −6 − 15 = −21 m, i.e. 21 m downward.' },
    { q: 'Can the distance travelled ever be less than the magnitude of the displacement?', a: 'No. Distance ≥ |displacement|, with equality only for motion in a straight line without reversing.' },
  ],
  '2d': [
    { q: 'A walks from (1, 2) to (4, 6). Find the distance and the direction of the displacement.', a: 'Δ = (3, 4), so d = √(9 + 16) = 5. Direction: tan⁻¹(4/3) = 53.1° north of east (θ = 53.1°, bearing 036.9°).' },
    { q: 'A student walks 3 m east, 4 m north, then 3 m west. Find the distance and the displacement.', a: 'Distance = 3 + 4 + 3 = 10 m. Displacement = (0, 4): 4 m due north.' },
    { q: 'Point P is at (−3, −4). Which quadrant is it in, how far is it from the origin, and what is the bearing of P from the origin?', a: 'Quadrant III. Distance = √(9 + 16) = 5. θ = 233.1° from +x, so the bearing is 90° − 233.1° + 360° = 216.9° (53.1° south of west).' },
  ],
  '3d': [
    { q: 'P is at (2, 3, 6). Find its distance from the origin, and from each coordinate plane.', a: 'OP = √(4 + 9 + 36) = 7. From the xy-plane: |z| = 6. From the yz-plane: |x| = 2. From the xz-plane: |y| = 3.' },
    { q: 'A = (1, −2, 0) and B = (3, 1, 6). Find the distance AB.', a: 'Δ = (2, 3, 6), so AB = √(4 + 9 + 36) = 7.' },
    { q: 'A drone flies from the origin 2 m along x, then 3 m along y, then 6 m up z. Find the distance flown and the displacement magnitude.', a: 'Distance = 2 + 3 + 6 = 11 m. Displacement = (2, 3, 6), magnitude √49 = 7 m.' },
  ],
};

const initialLocate: Record<Dim, P3> = { '1d': P(3), '2d': P(3, 4), '3d': P(3, 2, 4) };
const initialJourney = (): Record<Dim, P3[]> => ({ '1d': JOURNEY_PRESETS['1d'][0].points, '2d': JOURNEY_PRESETS['2d'][0].points, '3d': JOURNEY_PRESETS['3d'][0].points });

function NumField({ label, value, onCommit, min, max, color }: { label: string; value: number; onCommit: (v: number) => void; min: number; max: number; color: string }) {
  const [text, setText] = useState<string | null>(null);
  return (
    <label className="flex flex-1 items-center gap-1.5 text-xs">
      <span className="font-semibold" style={{ color }}>{label}</span>
      <input type="number" inputMode="decimal" step="any" min={min} max={max} aria-label={label}
        value={text ?? String(value)}
        onChange={e => { setText(e.target.value); const v = Number(e.target.value); if (e.target.value !== '' && e.target.value !== '-' && Number.isFinite(v)) onCommit(clampTo(v, max)); }}
        onBlur={() => setText(null)}
        className="h-8 w-full min-w-0 rounded-md border border-gray-200 bg-white px-2 text-sm tabular-nums" />
    </label>
  );
}

const Stat = ({ k, v, c = 'text-gray-900' }: { k: string; v: React.ReactNode; c?: string }) => (
  <div className="flex items-center justify-between gap-3 rounded-lg bg-gray-50 px-3 py-2"><span className="text-xs text-gray-500">{k}</span><span className={`text-right text-sm font-semibold tabular-nums ${c}`}>{v}</span></div>
);
const Toggle = ({ label, on, set }: { label: string; on: boolean; set: (v: boolean) => void }) => (
  <label className="flex items-center gap-1.5 text-xs text-gray-600"><input type="checkbox" checked={on} onChange={e => set(e.target.checked)} />{label}</label>
);

function walkText(step: number, p: P3, dim: Dim): string {
  const dir = (v: number, axis: string) => `${fmt(Math.abs(v))} unit${Math.abs(v) === 1 ? '' : 's'} ${v >= 0 ? 'along +' : 'along −'}${axis}`;
  if (step === 0) return 'Start at the origin O, where every coordinate is 0. Press Step to walk to the point.';
  if (step === 1) return `Step 1 — move ${dir(p.x, 'X')} (x = ${fmt(p.x)}). You are now at (${fmt(p.x)}, 0${dim === '3d' ? ', 0' : ''}).`;
  if (step === 2) return dim === '2d' ? `Step 2 — from there move ${dir(p.y, 'Y')} (y = ${fmt(p.y)}), parallel to the y-axis. You have arrived at ${coordText(p, dim)}.` : `Step 2 — now move ${dir(p.y, 'Y')} (y = ${fmt(p.y)}), parallel to the Y axis. You are at (${fmt(p.x)}, ${fmt(p.y)}, 0), directly ${p.z >= 0 ? 'below' : 'above'} the point.`;
  return `Step 3 — finally move ${dir(p.z, 'Z')} (z = ${fmt(p.z)}), parallel to the Z axis. You have arrived at ${coordText(p, dim)}.`;
}

export default function SpacePage() {
  const [dim, setDim] = useState<Dim>('3d');
  const [act, setAct] = useState<Activity>('locate');
  const [locate, setLocate] = useState<Record<Dim, P3>>(initialLocate);
  const [journey, setJourney] = useState<Record<Dim, P3[]>>(initialJourney);
  const [sel, setSel] = useState(0);
  const [snap, setSnap] = useState(1);
  const [view, setView] = useState<View>(DEFAULT_VIEW);
  const [dragAxis, setDragAxis] = useState<'floor' | 'height'>('floor');
  const [planes, setPlanes] = useState(true); const [grid, setGrid] = useState(true); const [guides, setGuides] = useState(true); const [comps, setComps] = useState(true);
  const [walk, setWalk] = useState<number | undefined>(undefined);
  const [playing, setPlaying] = useState(false);
  const [openEx, setOpenEx] = useState<number | null>(null);
  const [curr, setCurr] = useState(['WAEC', 'IGCSE', 'SAT']);
  // practice
  const [pKind, setPKind] = useState<'place' | 'read'>('place');
  const [target, setTarget] = useState<P3 | null>(null);
  const [place, setPlace] = useState<Record<Dim, P3>>({ '1d': P(0), '2d': P(0, 0), '3d': P(0, 0, 0) });
  const [typed, setTyped] = useState({ x: '', y: '', z: '' });
  const [result, setResult] = useState<{ correct: boolean; hints: string[] } | null>(null);
  const [score, setScore] = useState({ right: 0, tries: 0 });

  const boxRef = useRef<HTMLDivElement>(null);
  const size = useResponsiveCanvasSize(boxRef, 660, dim === '3d' ? 440 : 400, 900);
  // Narrow screens: a wide, short canvas would shrink the 2D/3D figures and clip the planes, so make them near-square.
  const compact = size.width < 560;
  const canvasH = compact ? Math.round(size.width * (dim === '1d' ? 0.62 : 1.0)) : size.height;
  const R = RANGE[dim];
  const readMode = act === 'practice' && pKind === 'read';

  // Auto-play for the guided walk: each tick is a timeout scheduled from the current step.
  useEffect(() => {
    if (!playing) return;
    const max = dim === '3d' ? 3 : 2, w = walk ?? 0;
    const id = setTimeout(() => { if (w >= max) setPlaying(false); else setWalk(w + 1); }, w >= max ? 0 : 1100);
    return () => clearTimeout(id);
  }, [playing, walk, dim]);

  const newChallenge = (kind = pKind, d = dim) => { setTarget(randomTarget(d)); setTyped({ x: '', y: '', z: '' }); setResult(null); setPlace(p => ({ ...p, [d]: P(0, 0, 0) })); setPKind(kind); };
  const changeDim = (d: Dim) => { setDim(d); setSel(0); setWalk(undefined); setPlaying(false); setResult(null); if (act === 'practice') newChallenge(pKind, d); };
  const changeAct = (a: Activity) => { setAct(a); setSel(0); setWalk(undefined); setPlaying(false); setResult(null); if (a === 'practice' && !target) newChallenge(pKind, dim); };

  const shown: P3[] = act === 'locate' ? [locate[dim]] : act === 'journey' ? journey[dim] : readMode ? [target ?? P()] : [place[dim]];
  const moveShown = (i: number, p: P3) => {
    if (act === 'locate') setLocate(s => ({ ...s, [dim]: p }));
    else if (act === 'journey') setJourney(s => ({ ...s, [dim]: s[dim].map((q, k) => (k === i ? p : q)) }));
    else if (!readMode) setPlace(s => ({ ...s, [dim]: p }));
    setWalk(undefined); setResult(null);
  };
  const J = analyseJourney(journey[dim], dim);
  const p = locate[dim];
  const first = journey[dim][0], last = journey[dim][journey[dim].length - 1];

  const check = () => {
    if (!target) return;
    const ans = pKind === 'place' ? clampDim(place[dim], dim) : clampDim(P(Number(typed.x), Number(typed.y || 0), Number(typed.z || 0)), dim);
    const bad = pKind === 'read' && [typed.x, dim !== '1d' ? typed.y : '0', dim === '3d' ? typed.z : '0'].some(v => v === '' || !Number.isFinite(Number(v)));
    if (bad) { setResult({ correct: false, hints: ['Fill in every coordinate first.'] }); return; }
    const r = checkAnswer(target, ans, dim, 0.01);
    setResult(r); setScore(s => ({ right: s.right + (r.correct ? 1 : 0), tries: s.tries + 1 }));
  };

  const dimMeta = DIMS.find(d => d.id === dim)!;
  const fields: ('x' | 'y' | 'z')[] = dim === '1d' ? ['x'] : dim === '2d' ? ['x', 'y'] : ['x', 'y', 'z'];
  const axisColor = { x: '#dc2626', y: '#16a34a', z: '#2563eb' };
  const walkMax = dim === '3d' ? 3 : 2;

  return (
    <>
      <AppHeader />
      <main className="min-h-screen bg-gray-50">
        <section className="border-b border-gray-200 bg-white">
          <div className="mx-auto max-w-[100rem] px-4 py-4 sm:px-6">
            <div className="flex flex-col justify-between gap-3 sm:flex-row sm:items-center">
              <div><p className="mb-0.5 text-xs text-gray-400">Space and time</p><h1 className="text-lg font-semibold text-gray-900">Space: position, distance &amp; displacement</h1></div>
              <div className="flex flex-wrap gap-1.5">
                {CURRICULA.map(c => <button key={c} onClick={() => setCurr(s => (s.includes(c) ? s.filter(x => x !== c) : [...s, c]))} className={`rounded-full border px-2.5 py-2 text-xs font-medium transition ${curr.includes(c) ? CC[c] + ' border-transparent' : 'border-gray-200 bg-white text-gray-400'}`}>{c}</button>)}
              </div>
            </div>
          </div>
        </section>

        <div className="mx-auto max-w-[100rem] space-y-4 px-4 py-4 sm:px-6">
          <div className="flex gap-1 overflow-x-auto rounded-xl bg-gray-100 p-1" role="tablist" aria-label="Number of dimensions">
            {DIMS.map(d => <button key={d.id} role="tab" aria-selected={dim === d.id} onClick={() => changeDim(d.id)} className={`flex shrink-0 items-center gap-1.5 rounded-lg px-3 py-2 text-xs font-medium transition ${dim === d.id ? 'bg-white text-indigo-700 shadow-sm' : 'text-gray-500 hover:text-gray-700'}`}><span>{d.icon}</span>{d.title}</button>)}
          </div>
          <div className="flex flex-wrap items-center gap-2">
            <div className="flex gap-1 overflow-x-auto" role="tablist" aria-label="Activity">
              {ACTS.map(a => <button key={a.id} role="tab" aria-selected={act === a.id} onClick={() => changeAct(a.id)} className={`shrink-0 rounded-full border px-3 py-1.5 text-xs font-medium transition ${act === a.id ? 'border-indigo-600 bg-indigo-600 text-white' : 'border-gray-200 bg-white text-gray-600 hover:border-indigo-300'}`}>{a.icon} {a.title}</button>)}
            </div>
            <span className="text-xs text-gray-500">{dimMeta.sub}</span>
            {act === 'journey' && <span className="rounded-lg border border-gray-200 bg-white px-2.5 py-2 font-mono text-xs text-gray-700">{dim === '1d' ? 'Δx = x₂ − x₁' : dim === '2d' ? 'd = √(Δx² + Δy²)' : 'd = √(Δx² + Δy² + Δz²)'}</span>}
          </div>

          <div className="grid grid-cols-1 gap-4 lg:grid-cols-[1fr_300px] xl:grid-cols-[1fr_300px_280px]">
            {/* Canvas + controls */}
            <div className="min-w-0 space-y-3">
              <div ref={boxRef} className="overflow-hidden rounded-2xl border border-gray-200 bg-white p-2 shadow-sm">
                <SpaceCanvas
                  dim={dim} activity={act} width={size.width} height={canvasH}
                  points={shown} labels={readMode ? ['P'] : act === 'practice' ? ['P'] : act === 'locate' ? ['P'] : LABELS}
                  selected={Math.min(sel, shown.length - 1)} onMove={moveShown} onSelect={setSel} snap={snap} view={view} onView={setView} dragAxis={dragAxis}
                  showPlanes={planes} showGrid={grid} showGuides={guides} showComponents={comps}
                  readOnly={readMode} hideCoords={readMode} walk={act === 'locate' && dim !== '1d' ? walk : undefined}
                />
              </div>

              <div className="flex flex-wrap items-center gap-x-4 gap-y-2 rounded-xl border border-gray-200 bg-white px-3 py-2.5">
                <label className="flex items-center gap-1.5 text-xs text-gray-600">Snap
                  <select value={snap} onChange={e => setSnap(Number(e.target.value))} className="h-7 rounded-md border border-gray-200 bg-white px-1.5 text-xs">
                    <option value={1}>whole numbers</option><option value={0.5}>0.5</option><option value={0}>0.1 (free)</option>
                  </select>
                </label>
                {dim === '3d' && <>
                  <div className="flex items-center gap-1.5 text-xs text-gray-600">Drag point
                    <div className="flex overflow-hidden rounded-md border border-gray-200">
                      {(['floor', 'height'] as const).map(m => <button key={m} onClick={() => setDragAxis(m)} aria-pressed={dragAxis === m} className={`px-2 py-1 text-xs ${dragAxis === m ? 'bg-indigo-600 text-white' : 'bg-white text-gray-600'}`}>{m === 'floor' ? 'across floor (x, y)' : 'up / down (z)'}</button>)}
                    </div>
                  </div>
                  <Toggle label="Planes" on={planes} set={setPlanes} />
                  <Toggle label="Floor grid" on={grid} set={setGrid} />
                </>}
                {dim === '2d' && <Toggle label="Grid" on={grid} set={setGrid} />}
                {act === 'locate' && <Toggle label={dim === '3d' ? 'Box & projection lines' : 'Guide lines'} on={guides} set={setGuides} />}
                {act === 'journey' && <><Toggle label="Components" on={comps} set={setComps} />{dim === '3d' && <Toggle label="Drop lines" on={guides} set={setGuides} />}</>}
                <div className="ml-auto"><EmbedButton path="/embed/space" title="Space — A-Factor STEM Studio" params={{ dim, act: act === 'journey' ? 'journey' : 'locate', pts: (act === 'journey' ? journey[dim] : [locate[dim]]).map(q => `${q.x},${q.y},${q.z}`).join(';') }} /></div>
              </div>
              {dim === '3d' && (
                <div className="flex flex-wrap items-center gap-1.5">
                  <span className="text-xs text-gray-500">View</span>
                  {VIEWS.map(v => <button key={v.label} onClick={() => setView(v.v)} className="rounded-md border border-gray-200 bg-white px-2.5 py-1 text-xs text-gray-600 hover:border-indigo-300 hover:text-indigo-700">{v.label}</button>)}
                  <span className="text-[11px] text-gray-400">Drag empty space to rotate · drag a point to move it · arrow keys and Page Up/Down also work</span>
                </div>
              )}
              {dim !== '3d' && <p className="text-[11px] text-gray-400">Drag a point to move it, or select it and use the arrow keys. Axes run from −{R} to +{R}.</p>}
            </div>

            {/* Parameters + readouts */}
            <div className="space-y-3">
              {act === 'locate' && (
                <>
                  <div className="space-y-3 rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                    <p className="text-xs font-medium uppercase tracking-wide text-gray-400">Point P</p>
                    <div className="flex gap-2">{fields.map(k => <NumField key={k} label={k} value={p[k]} min={-R} max={R} color={axisColor[k]} onCommit={v => { setLocate(s => ({ ...s, [dim]: { ...s[dim], [k]: v } })); setWalk(undefined); }} />)}</div>
                    {fields.map(k => (
                      <input key={k} type="range" min={-R} max={R} step={snap || 0.1} value={p[k]} aria-label={`${k} slider`} onChange={e => { setLocate(s => ({ ...s, [dim]: { ...s[dim], [k]: Number(e.target.value) } })); setWalk(undefined); }} className="w-full" style={{ accentColor: axisColor[k] }} />
                    ))}
                  </div>
                  <div className="space-y-2 rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                    <p className="text-xs font-medium uppercase tracking-wide text-gray-400">Where is it?</p>
                    <Stat k="Position" v={coordText(p, dim)} c="text-red-600" />
                    {dim === '1d' && <Stat k="Side of origin" v={p.x === 0 ? 'at O' : p.x > 0 ? 'right (+x)' : 'left (−x)'} />}
                    {dim === '1d' && <Stat k="Distance from O" v={`${fmt(Math.abs(p.x))}`} c="text-indigo-600" />}
                    {dim === '2d' && <><Stat k="Quadrant" v={quadrant(p)} /><Stat k="Distance from O" v={fmt(len(p))} c="text-indigo-600" /><Stat k="Foot on x-axis" v={`(${fmt(p.x)}, 0)`} /><Stat k="Foot on y-axis" v={`(0, ${fmt(p.y)})`} /></>}
                    {dim === '3d' && <><Stat k="Signs" v={octant(p).replace('signs (x, y, z) = ', '')} /><Stat k="Distance from O" v={fmt(len(p))} c="text-indigo-600" /><Stat k="From xy-plane (|z|)" v={fmt(Math.abs(p.z))} /><Stat k="From yz-plane (|x|)" v={fmt(Math.abs(p.x))} /><Stat k="From xz-plane (|y|)" v={fmt(Math.abs(p.y))} /><Stat k="Foot on xy-plane" v={`(${fmt(p.x)}, ${fmt(p.y)}, 0)`} /></>}
                  </div>
                  {dim !== '1d' && (
                    <div className="rounded-2xl border border-indigo-100 bg-indigo-50 p-4">
                      <p className="mb-2 text-xs font-medium uppercase tracking-wide text-indigo-400">Walk to the point</p>
                      <p className="mb-3 min-h-[3.5rem] text-xs leading-relaxed text-indigo-900" aria-live="polite">{walk === undefined ? 'Press Step to follow the route from the origin, one axis at a time.' : walkText(walk, p, dim)}</p>
                      <div className="flex flex-wrap gap-2">
                        <button onClick={() => { setPlaying(false); setWalk(w => (w === undefined ? 1 : w >= walkMax ? 0 : w + 1)); }} className="rounded-lg bg-indigo-600 px-3 py-1.5 text-xs font-medium text-white hover:bg-indigo-700">{walk !== undefined && walk >= walkMax ? 'Restart' : 'Step ▸'}</button>
                        <button onClick={() => { setWalk(0); setPlaying(true); }} className="rounded-lg border border-indigo-200 bg-white px-3 py-1.5 text-xs font-medium text-indigo-700">Play</button>
                        <button onClick={() => { setPlaying(false); setWalk(undefined); }} className="rounded-lg border border-gray-200 bg-white px-3 py-1.5 text-xs text-gray-600">Show all</button>
                      </div>
                    </div>
                  )}
                </>
              )}

              {act === 'journey' && (
                <>
                  <div className="space-y-3 rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                    <div className="flex items-center justify-between"><p className="text-xs font-medium uppercase tracking-wide text-gray-400">Journey points</p><span className="text-[11px] text-gray-400">A → … → {LABELS[journey[dim].length - 1]}</span></div>
                    {journey[dim].map((q, i) => (
                      <div key={i} onClick={() => setSel(i)} className={`rounded-xl border p-2 ${sel === i ? 'border-indigo-300 bg-indigo-50/40' : 'border-gray-100'}`}>
                        <div className="mb-1.5 flex items-center justify-between"><span className="text-xs font-semibold" style={{ color: POINT_COLORS[i % 5] }}>{LABELS[i]}{i === 0 ? ' (start)' : i === journey[dim].length - 1 ? ' (end)' : ''}</span>
                          {journey[dim].length > 2 && <button onClick={e => { e.stopPropagation(); setJourney(s => ({ ...s, [dim]: s[dim].filter((_, k) => k !== i) })); setSel(0); }} className="text-[11px] text-gray-400 hover:text-red-600" aria-label={`Remove point ${LABELS[i]}`}>Remove</button>}</div>
                        <div className="flex gap-1.5">{fields.map(k => <NumField key={k} label={k} value={q[k]} min={-R} max={R} color={axisColor[k]} onCommit={v => setJourney(s => ({ ...s, [dim]: s[dim].map((pp, kk) => (kk === i ? { ...pp, [k]: v } : pp)) }))} />)}</div>
                      </div>
                    ))}
                    <div className="flex flex-wrap gap-2">
                      <button disabled={journey[dim].length >= MAX_POINTS} onClick={() => setJourney(s => { const l = s[dim][s[dim].length - 1]; return { ...s, [dim]: [...s[dim], clampDim(P(clampTo(l.x + 2, R), clampTo(l.y + 1, R), clampTo(l.z + 1, R)), dim)] }; })} className="rounded-lg border border-gray-200 bg-white px-3 py-1.5 text-xs text-gray-700 enabled:hover:border-indigo-300 disabled:opacity-40">+ Add point</button>
                    </div>
                    <div className="flex flex-wrap gap-1.5">{JOURNEY_PRESETS[dim].map(pr => <button key={pr.label} onClick={() => { setJourney(s => ({ ...s, [dim]: pr.points })); setSel(0); }} title={pr.note} className="rounded-full border border-gray-200 bg-white px-2.5 py-1 text-[11px] text-gray-700 hover:border-indigo-300 hover:text-indigo-700">{pr.label}</button>)}</div>
                  </div>

                  <div className="space-y-2 rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                    <p className="text-xs font-medium uppercase tracking-wide text-gray-400">Results</p>
                    <Stat k="Distance (path length)" v={`${fmt(J.distance)}`} c="text-indigo-600" />
                    <Stat k="Displacement" v={dim === '1d' ? `${J.displacement.x >= 0 ? '+' : '−'}${fmt(Math.abs(J.displacement.x))}` : coordText(J.displacement, dim).replace('x = ', '')} c="text-rose-600" />
                    <Stat k="|Displacement|" v={fmt(J.magnitude)} c="text-rose-600" />
                    <div className="rounded-lg bg-rose-50 px-3 py-2 text-xs leading-relaxed text-rose-900"><span className="font-medium">Direction: </span>{J.direction.text}{J.direction.bearing !== undefined && <> · bearing {fmt(J.direction.bearing, 1)}°</>}{J.direction.axisAngles && <> · angles with x, y, z axes: {fmt(J.direction.axisAngles.x, 1)}°, {fmt(J.direction.axisAngles.y, 1)}°, {fmt(J.direction.axisAngles.z, 1)}°</>}</div>
                    <div className={`rounded-lg px-3 py-2 text-xs leading-relaxed ${J.straight ? 'bg-emerald-50 text-emerald-900' : 'bg-amber-50 text-amber-900'}`}>
                      {J.straight ? 'Distance equals the magnitude of the displacement: the path is a straight line with no reversal.' : `The path is ${fmt(J.distance - J.magnitude)} longer than the straight-line displacement. Distance ≥ |displacement| always.`}
                    </div>
                  </div>

                  <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                    <p className="mb-2 text-xs font-medium uppercase tracking-wide text-gray-400">Working: {LABELS[0]} → {LABELS[journey[dim].length - 1]}</p>
                    <p className="font-mono text-[11px] leading-relaxed text-gray-700">{distanceWorking(first, last, dim)}</p>
                    <div className="mt-3 overflow-x-auto"><table className="w-full min-w-[220px] text-left text-xs">
                      <thead className="text-[10px] uppercase tracking-wide text-gray-400"><tr><th className="py-1 font-medium">Leg</th><th className="font-medium">Δ</th><th className="text-right font-medium">Length</th></tr></thead>
                      <tbody>{J.legs.map((l, i) => <tr key={i} className="border-t border-gray-100"><td className="py-1.5 font-semibold" style={{ color: POINT_COLORS[(i + 1) % 5] }}>{LABELS[i]}→{LABELS[i + 1]}</td><td className="tabular-nums text-gray-700">{dim === '1d' ? `${l.delta.x >= 0 ? '+' : '−'}${fmt(Math.abs(l.delta.x))}` : coordText(l.delta, dim)}</td><td className="text-right tabular-nums text-gray-900">{fmt(l.length)}</td></tr>)}
                        <tr className="border-t-2 border-gray-200 font-semibold"><td className="py-1.5">Total</td><td /><td className="text-right tabular-nums text-indigo-600">{fmt(J.distance)}</td></tr></tbody>
                    </table></div>
                  </div>
                </>
              )}

              {act === 'practice' && (
                <div className="space-y-3 rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                  <div className="flex items-center justify-between"><p className="text-xs font-medium uppercase tracking-wide text-gray-400">Practice</p><span className="rounded-full bg-gray-100 px-2.5 py-1 text-[11px] font-medium text-gray-600">Score {score.right} / {score.tries}</span></div>
                  <div className="flex gap-1.5">
                    {([['place', 'Place the point'], ['read', 'Read the coordinates']] as const).map(([k, l]) => <button key={k} onClick={() => newChallenge(k)} aria-pressed={pKind === k} className={`flex-1 rounded-lg border px-2 py-2 text-xs font-medium ${pKind === k ? 'border-indigo-600 bg-indigo-600 text-white' : 'border-gray-200 bg-white text-gray-600'}`}>{l}</button>)}
                  </div>
                  {target && pKind === 'place' && <p className="rounded-lg bg-indigo-50 px-3 py-2 text-sm text-indigo-900">Move point P to <span className="font-semibold">{coordText(target, dim)}</span>, then press Check.</p>}
                  {target && pKind === 'read' && (
                    <div className="space-y-2">
                      <p className="rounded-lg bg-indigo-50 px-3 py-2 text-sm text-indigo-900">Read the coordinates of the red point P from the axes, then type them in.</p>
                      <div className="flex gap-2">{fields.map(k => <label key={k} className="flex flex-1 items-center gap-1.5 text-xs"><span className="font-semibold" style={{ color: axisColor[k] }}>{k}</span><input type="number" inputMode="decimal" value={typed[k]} aria-label={`Your ${k} value`} onChange={e => { setTyped(t => ({ ...t, [k]: e.target.value })); setResult(null); }} className="h-8 w-full min-w-0 rounded-md border border-gray-200 px-2 text-sm" /></label>)}</div>
                    </div>
                  )}
                  {pKind === 'place' && <p className="text-xs text-gray-500">P is now at <span className="font-medium text-gray-800">{coordText(place[dim], dim)}</span></p>}
                  <div className="flex gap-2">
                    <button onClick={check} disabled={!target} className="rounded-lg bg-indigo-600 px-4 py-2 text-xs font-medium text-white enabled:hover:bg-indigo-700 disabled:opacity-40">Check</button>
                    <button onClick={() => newChallenge()} className="rounded-lg border border-gray-200 bg-white px-4 py-2 text-xs text-gray-700 hover:border-indigo-300">New point</button>
                    {pKind === 'read' && <button onClick={() => setResult({ correct: false, hints: [`The answer is ${target ? coordText(target, dim) : ''}.`] })} className="rounded-lg border border-gray-200 bg-white px-3 py-2 text-xs text-gray-500">Reveal</button>}
                  </div>
                  {result && <p aria-live="polite" className={`rounded-lg px-3 py-2 text-xs leading-relaxed ${result.correct ? 'bg-emerald-50 text-emerald-900' : 'bg-amber-50 text-amber-900'}`}>{result.correct ? '✓ Correct! That is exactly the point.' : result.hints.join(' · ')}</p>}
                  {pKind === 'read' && dim === '3d' && <p className="text-[11px] text-gray-400">Tip: rotate the view and switch to the Top, Front and Side views to read each coordinate against its axis.</p>}
                </div>
              )}
            </div>

            {/* Teacher notes + exercises */}
            <div className="space-y-3 lg:col-span-2 xl:col-span-1">
              <div className="rounded-2xl border border-amber-100 bg-amber-50 p-4">
                <p className="mb-3 text-xs font-medium uppercase tracking-wide text-amber-700">📋 Teacher notes</p>
                <ul className="space-y-2">{NOTES[dim].map((n, i) => <li key={i} className="flex gap-2 text-xs leading-relaxed text-amber-900"><span className="mt-0.5 shrink-0 text-amber-400">•</span>{n}</li>)}</ul>
              </div>
              <div className="rounded-2xl border border-gray-200 bg-white p-4">
                <p className="mb-3 text-xs font-medium uppercase tracking-wide text-gray-500">✏️ Exercises</p>
                <div className="space-y-2">{EXERCISES[dim].map((ex, i) => (
                  <div key={i} className="overflow-hidden rounded-xl border border-gray-100">
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
