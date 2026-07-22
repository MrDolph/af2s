'use client';
import { useState, useRef } from 'react';
import { AppHeader } from '@/components/layout/AppHeader';
import { OpticsCanvas, OpticsMode } from '@/components/simulation/OpticsCanvas';
import { EmbedButton } from '@/components/ui/EmbedButton';
import { snellTheta2, criticalAngle, thinLensImage, lensPower } from '@/lib/physics/optics';
import { useResponsiveCanvasSize } from '@/hooks/useResponsiveCanvasSize';

const CURRICULA = ['WAEC', 'NECO', 'IGCSE', 'SAT', 'JUPEB'];
const CC: Record<string, string> = {
  WAEC: 'bg-indigo-100 text-indigo-700', NECO: 'bg-pink-100 text-pink-700',
  IGCSE: 'bg-emerald-100 text-emerald-700', SAT: 'bg-orange-100 text-orange-700',
  JUPEB: 'bg-purple-100 text-purple-700',
};

const MODE_META: Record<OpticsMode, { title: string; icon: string; sub: string; eq: string }> = {
  snell:  { title: 'Refraction', icon: '💠', sub: 'Light crossing a boundary', eq: 'n₁ sinθ₁ = n₂ sinθ₂' },
  lens:   { title: 'Lenses',     icon: '🔍', sub: 'Convex & concave',          eq: '1/f = 1/u + 1/v' },
  mirror: { title: 'Mirrors',    icon: '🪞', sub: 'Concave & convex',          eq: '1/f = 1/u + 1/v' },
};

const PRESETS = [
  { label: 'Air → Glass', n1: 1.0, n2: 1.5 },
  { label: 'Air → Water', n1: 1.0, n2: 1.33 },
  { label: 'Glass → Air', n1: 1.5, n2: 1.0 },
  { label: 'Water → Air', n1: 1.33, n2: 1.0 },
  { label: 'Diamond → Air', n1: 2.42, n2: 1.0 },
];

const TEACHER_NOTES: Record<OpticsMode, string[]> = {
  snell: [
    'Into a DENSER medium (n₂ > n₁): light bends TOWARDS the normal. Into a less dense medium: away from it.',
    'The critical angle only exists going dense → less dense; sinθc = n₂/n₁.',
    'Beyond θc, ALL light reflects: total internal reflection — the basis of optical fibres and diamond sparkle.',
    'Refractive index n = c/v = sinθ₁/sinθ₂ = real depth / apparent depth (three exam definitions of the same thing).',
    'Diamond → air: θc ≈ 24.4° — tiny, which is why diamonds trap and bounce light so much.',
  ],
  lens: [
    'Real-is-positive convention: f > 0 for converging (convex), f < 0 for diverging (concave). WAEC/IGCSE mark schemes use this.',
    'Convex lens: object beyond 2F → diminished real image; between F and 2F → magnified real image; inside F → magnified virtual (magnifying glass).',
    'A concave lens ALWAYS gives a virtual, upright, diminished image regardless of object position.',
    'Two principal rays fix the image: parallel-to-axis (bends through F) and through the optical centre (undeviated).',
    'Lens power P = 1/f (f in metres), unit dioptre — opticians add powers of lenses in contact.',
  ],
  mirror: [
    'Concave mirror (converging, f > 0): same image rules as a convex lens — but real images form on the SAME side as the object.',
    'Convex mirror (diverging, f < 0): always virtual, upright, diminished — that is why it is used for car wing mirrors and shop security ("objects are closer than they appear").',
    'Focal length f = R/2 where R is the radius of curvature.',
    'Uses of concave mirrors: shaving/makeup mirrors (object inside F → magnified upright virtual image), torch and headlamp reflectors (bulb at F → parallel beam).',
    'The mirror formula is identical to the lens formula in the real-is-positive convention.',
  ],
};

const EXERCISES: Record<OpticsMode, { q: string; a: string }[]> = {
  snell: [
    { q: 'Light passes from air into glass (n=1.5) at 45°. Find the angle of refraction.', a: 'sinθ₂ = sin45°/1.5 = 0.707/1.5 = 0.471 → θ₂ = 28.1°.' },
    { q: 'Find the critical angle for water (n=1.33) to air.', a: 'sinθc = 1/1.33 = 0.752 → θc = 48.8°.' },
    { q: 'Light travels at 3×10⁸ m/s in air. Find its speed in glass of n=1.5.', a: 'v = c/n = 3×10⁸/1.5 = 2×10⁸ m/s.' },
  ],
  lens: [
    { q: 'An object 30cm from a convex lens of f=20cm. Find the image position and magnification.', a: '1/v = 1/20 − 1/30 = 1/60 → v = 60cm (real). m = v/u = 2 (magnified, inverted).' },
    { q: 'An object 10cm from a convex lens of f=15cm. Describe the image.', a: '1/v = 1/15 − 1/10 = −1/30 → v = −30cm: virtual, upright, m=3 — a magnifying glass.' },
    { q: 'Find the power of a converging lens with f = 25cm.', a: 'P = 1/f = 1/0.25 = +4 dioptres.' },
  ],
  mirror: [
    { q: 'An object 40cm from a concave mirror of f=15cm. Find the image.', a: '1/v = 1/15 − 1/40 = 5/120 → v = 24cm: real, inverted, m = 0.6 (diminished).' },
    { q: 'Why are convex mirrors used as driving mirrors?', a: 'They always give an upright, diminished, virtual image with a much wider field of view than a plane mirror.' },
    { q: 'A concave mirror has radius of curvature 60cm. Where must a bulb be placed for a parallel beam?', a: 'f = R/2 = 30cm. Place the bulb at the focal point, 30cm from the pole.' },
  ],
};

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

export default function RefractionPage() {
  const [mode, setMode] = useState<OpticsMode>('snell');
  const [openEx, setOpenEx] = useState<number | null>(null);
  const [activeCurricula, setActiveCurricula] = useState(['WAEC', 'IGCSE', 'SAT']);

  const [n1, setN1] = useState(1.0);
  const [n2, setN2] = useState(1.5);
  const [theta1, setTheta1] = useState(35);
  const [focal, setFocal] = useState(15);
  const [objectDist, setObjectDist] = useState(40);
  const [converging, setConverging] = useState(true);

  const t2 = snellTheta2(n1, n2, theta1);
  const critAng = criticalAngle(n1, n2);
  const f = converging ? focal : -focal;
  const img = thinLensImage(objectDist, f);

  const canvasBoxRef = useRef<HTMLDivElement>(null);
  const canvasSize = useResponsiveCanvasSize(canvasBoxRef, 660, 320, 980);

  return (
    <>
      <AppHeader />
      <main className="min-h-screen bg-gray-50">
        <section className="border-b border-gray-200 bg-white">
          <div className="mx-auto max-w-[100rem] px-4 sm:px-6 py-4">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
              <div>
                <p className="text-xs text-gray-400 mb-0.5">Optics</p>
                <h1 className="text-lg font-semibold text-gray-900">Refraction &amp; lenses</h1>
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

        <div className="mx-auto max-w-[100rem] px-4 sm:px-6 py-4 space-y-4">
          <div className="flex gap-1 bg-gray-100 p-1 rounded-xl overflow-x-auto">
            {(Object.keys(MODE_META) as OpticsMode[]).map(m => (
              <button key={m} onClick={() => { setMode(m); setOpenEx(null); }}
                className={`shrink-0 flex items-center gap-1.5 px-3 py-2 rounded-lg text-xs font-medium transition ${
                  mode === m ? 'bg-white text-indigo-700 shadow-sm' : 'text-gray-500 hover:text-gray-700'
                }`}>
                <span>{MODE_META[m].icon}</span><span>{MODE_META[m].title}</span>
              </button>
            ))}
          </div>

          <div className="flex flex-wrap items-center gap-3 rounded-xl border border-gray-200 bg-white px-4 py-2.5">
            <span className="text-xs text-gray-400">{MODE_META[mode].sub}</span>
            <span className="text-sm font-semibold font-mono text-gray-900">{MODE_META[mode].eq}</span>
            {mode !== 'snell' && <span className="text-xs text-gray-400 ml-2">m = v/u · real is positive</span>}
          </div>

          <div className="grid grid-cols-1 lg:grid-cols-[1fr_220px] xl:grid-cols-[1fr_220px_260px] gap-4">
            <div className="space-y-3 min-w-0">
              <div ref={canvasBoxRef} className="rounded-2xl border border-gray-200 bg-white p-3 shadow-sm">
                <OpticsCanvas mode={mode} n1={n1} n2={n2} theta1={theta1}
                  focal={focal} objectDist={objectDist} converging={converging}
                  width={canvasSize.width} height={canvasSize.height} />
              </div>

              <div className="flex flex-wrap items-center justify-end gap-2">
                <EmbedButton path="/embed/optics"
                  title={`${MODE_META[mode].title} — A-Factor STEM Studio`}
                  params={{ mode, n1, n2, theta1, focal, u: objectDist, conv: converging ? 1 : 0 }} />
              </div>

              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm space-y-4">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide">Parameters</p>

                {mode === 'snell' && <>
                  <div className="flex flex-wrap gap-1.5">
                    {PRESETS.map(p => (
                      <button key={p.label} onClick={() => { setN1(p.n1); setN2(p.n2); }}
                        className={`rounded-full border px-2.5 py-1 text-[11px] font-medium transition ${
                          n1 === p.n1 && n2 === p.n2
                            ? 'border-indigo-300 bg-indigo-50 text-indigo-700'
                            : 'border-gray-200 bg-white text-gray-500 hover:border-indigo-200'
                        }`}>{p.label}</button>
                    ))}
                  </div>
                  <Slider label="Angle of incidence θ₁" unit="°" value={theta1} min={0} max={89} step={1} set={setTheta1} color="#6366f1"
                    note={critAng !== null ? `Critical angle θc = ${critAng.toFixed(1)}° — push θ₁ past it for TIR` : undefined} />
                  <Slider label="n₁ (top medium)" unit="" value={n1} min={1} max={2.5} step={0.01} set={setN1} color="#f59e0b" />
                  <Slider label="n₂ (bottom medium)" unit="" value={n2} min={1} max={2.5} step={0.01} set={setN2} color="#10b981" />
                </>}

                {mode !== 'snell' && <>
                  <div className="space-y-1.5">
                    <span className="text-xs text-gray-500">Type</span>
                    <div className="flex gap-2">
                      {([true, false] as const).map(c => (
                        <button key={String(c)} onClick={() => setConverging(c)}
                          className={`flex-1 rounded-lg border px-2 py-1.5 text-xs font-medium transition ${
                            converging === c ? 'border-indigo-300 bg-indigo-50 text-indigo-700' : 'border-gray-200 bg-white text-gray-500'
                          }`}>
                          {mode === 'lens'
                            ? (c ? 'Convex (converging)' : 'Concave (diverging)')
                            : (c ? 'Concave (converging)' : 'Convex (diverging)')}
                        </button>
                      ))}
                    </div>
                  </div>
                  <Slider label="Focal length |f|" unit="cm" value={focal} min={5} max={40} step={1} set={setFocal} color="#f59e0b" />
                  <Slider label="Object distance u" unit="cm" value={objectDist} min={5} max={90} step={1} set={setObjectDist} color="#6366f1"
                    note="Slide the object through 2F, F and inside F — watch the image flip" />
                </>}
              </div>
            </div>

            <div className="space-y-3">
              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide mb-3">Calculated</p>
                <div className="space-y-2">
                  {mode === 'snell' && <>
                    <StatRow label="Angle of refraction θ₂" value={t2 === null ? 'TIR' : t2.toFixed(1)} unit={t2 === null ? '' : '°'} color="text-indigo-600" />
                    <StatRow label="Critical angle θc" value={critAng === null ? '—' : critAng.toFixed(1)} unit={critAng === null ? '' : '°'} color="text-emerald-600" />
                    <StatRow label="n₂/n₁ ratio" value={(n2 / n1).toFixed(3)} unit="" color="text-amber-600" />
                    <StatRow label="Bends" value={t2 === null ? 'reflects fully' : n2 > n1 ? 'towards normal' : 'away from normal'} unit="" color="text-rose-500" />
                  </>}
                  {mode !== 'snell' && <>
                    <StatRow label="Image distance v" value={img.atInfinity ? '∞' : Math.abs(img.v).toFixed(1)} unit={img.atInfinity ? '' : 'cm'} color="text-indigo-600" />
                    <StatRow label="Magnification m" value={img.atInfinity ? '∞' : img.m.toFixed(2)} unit="×" color="text-emerald-600" />
                    <StatRow label="Nature" value={img.atInfinity ? 'at infinity' : img.real ? 'real' : 'virtual'} unit="" color="text-amber-600" />
                    <StatRow label="Orientation" value={img.atInfinity ? '—' : img.inverted ? 'inverted' : 'upright'} unit="" color="text-rose-500" />
                    {mode === 'lens' && (
                      <StatRow label="Power" value={lensPower(f / 100).toFixed(2)} unit="D" color="text-purple-600" />
                    )}
                    {mode === 'mirror' && (
                      <StatRow label="Radius R = 2f" value={(2 * focal).toFixed(0)} unit="cm" color="text-purple-600" />
                    )}
                  </>}
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
                  {TEACHER_NOTES[mode].map((n, i) => (
                    <li key={i} className="text-xs text-amber-900 leading-relaxed flex gap-2">
                      <span className="text-amber-400 shrink-0 mt-0.5">•</span>{n}
                    </li>
                  ))}
                </ul>
              </div>

              <div className="rounded-2xl border border-gray-200 bg-white p-4">
                <p className="text-xs font-medium text-gray-500 uppercase tracking-wide mb-3">✏️ Exercises</p>
                <div className="space-y-2">
                  {EXERCISES[mode].map((ex, i) => (
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
