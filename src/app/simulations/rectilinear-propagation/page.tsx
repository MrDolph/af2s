'use client';
import { useState, useRef } from 'react';
import { AppHeader } from '@/components/layout/AppHeader';
import { ShadowsCanvas } from '@/components/simulation/ShadowsCanvas';
import { EclipseCanvas, EclipseType } from '@/components/simulation/EclipseCanvas';
import { PinholeCanvas } from '@/components/simulation/PinholeCanvas';
import { EmbedButton } from '@/components/ui/EmbedButton';
import { umbraLength, pinholeImageHeight, pinholeMagnification, SUN_ANGULAR_DIAMETER_DEG, MOON_ANGULAR_DIAMETER_DEG } from '@/lib/physics/rectilinear';
import { useResponsiveCanvasSize } from '@/hooks/useResponsiveCanvasSize';

type Topic = 'shadows' | 'eclipse' | 'pinhole';

const CURRICULA = ['WAEC', 'NECO', 'IGCSE', 'SAT', 'JUPEB'];
const CC: Record<string, string> = {
  WAEC: 'bg-indigo-100 text-indigo-700', NECO: 'bg-pink-100 text-pink-700',
  IGCSE: 'bg-emerald-100 text-emerald-700', SAT: 'bg-orange-100 text-orange-700',
  JUPEB: 'bg-purple-100 text-purple-700',
};

const TOPIC_META: Record<Topic, { title: string; icon: string; sub: string; eq: string }> = {
  shadows: { title: 'Shadows',        icon: '🌑', sub: 'Umbra & penumbra',              eq: 'light travels in straight lines' },
  eclipse: { title: 'Eclipses',       icon: '🌘', sub: 'Solar & lunar',                  eq: 'a shadow, cast across space' },
  pinhole: { title: 'Pinhole camera', icon: '📷', sub: 'A laboratory consequence',       eq: 'hI/v = hO/u' },
};

const TEACHER_NOTES: Record<Topic, string[]> = {
  shadows: [
    'Sources of light are LUMINOUS (produce their own light — the Sun, a candle, a bulb) or NON-LUMINOUS (only visible because they reflect light from elsewhere — the Moon, this page, a person).',
    'A shadow forms because light travels in straight lines (rectilinear propagation) and cannot bend around an opaque object.',
    'A POINT source produces a shadow with a sharp edge — only an umbra, no penumbra — because every ray from the single point is blocked in exactly the same way.',
    'An EXTENDED source produces a shadow with two regions: the UMBRA (completely dark — no part of the source is visible from there) and the PENUMBRA (partially lit — only part of the source is visible from there, so some light still reaches it).',
    'Moving the object closer to an extended source makes the penumbra relatively LARGER compared to the umbra; moving it closer to the screen makes the shadow\u2019s edges sharper.',
  ],
  eclipse: [
    'A solar eclipse happens when the Moon passes directly between the Sun and Earth, casting its shadow onto Earth\u2019s surface — people in the umbra see a total eclipse, people in the penumbra see a partial one.',
    'A lunar eclipse happens when Earth passes directly between the Sun and the Moon, and the Moon passes through Earth\u2019s shadow.',
    'Eclipses don\u2019t happen every month because the Moon\u2019s orbit is tilted about 5° relative to Earth\u2019s orbit around the Sun — most months, the Moon\u2019s shadow (or Earth\u2019s shadow) simply misses, passing above or below the target body.',
    'A remarkable coincidence: the Sun is about 400 times wider than the Moon, but also about 400 times farther away — so they have almost the same apparent size in our sky, which is why the Moon can only just barely cover the Sun during a total solar eclipse.',
    'This whole topic is a direct, large-scale consequence of the same rectilinear-propagation geometry used for a tabletop shadow demo — only the distances and sizes change.',
  ],
  pinhole: [
    'A pinhole camera has no lens — a single small hole lets through only one straight-line ray per point on the object, which is exactly why the image forms upside down (inverted): rays from the top of the object cross the hole and land at the BOTTOM of the screen, and vice versa.',
    'The image is always REAL (it lands on an actual screen/film) — this is a direct laboratory demonstration of rectilinear propagation, needing no lens or mirror at all.',
    'Image height formula (similar triangles): hI/v = hO/u, where u = object-to-hole distance, v = hole-to-screen distance.',
    'A SMALLER hole gives a sharper image (closer to one ray per object point) but a DIMMER one (less light gets through) — a genuine trade-off, and why real pinhole cameras need long exposure times.',
    'Making the hole too large lets a whole BUNDLE of rays through each object point, and those bundles overlap on the screen — this is what blurs the image, not some separate effect, but the same straight-line geometry applied to a hole with actual size.',
  ],
};

const EXERCISES: Record<Topic, { q: string; a: string }[]> = {
  shadows: [
    { q: 'A point source of light is placed 20cm from an opaque disc of radius 5cm. Explain what kind of shadow forms and why.', a: 'A sharp shadow with only an umbra, no penumbra — every ray from a single point is blocked identically at the disc\u2019s edge, so there is no region that receives partial light.' },
    { q: 'State the two regions formed in the shadow of an extended light source, and define each.', a: 'Umbra: the region that receives no light at all from the source (completely dark). Penumbra: the region that receives light from only part of the source (partially lit).' },
    { q: 'Why can you sometimes see a fuzzy-edged shadow under a fluorescent tube light, but a sharp-edged shadow under a small torch bulb?', a: 'A fluorescent tube is an extended source, producing a penumbra (fuzzy edge) around the umbra. A small torch bulb behaves close to a point source, giving a mostly sharp-edged shadow.' },
  ],
  eclipse: [
    { q: 'Distinguish between a solar eclipse and a lunar eclipse in terms of the positions of the Sun, Earth, and Moon.', a: 'Solar eclipse: Moon is between the Sun and Earth, and the Moon\u2019s shadow falls on Earth. Lunar eclipse: Earth is between the Sun and the Moon, and the Moon passes through Earth\u2019s shadow.' },
    { q: 'Explain why we do not see a solar and a lunar eclipse every single month, even though the Moon orbits Earth roughly every month.', a: 'The Moon\u2019s orbital plane is tilted about 5° relative to Earth\u2019s orbital plane around the Sun. Most months, this tilt carries the Moon\u2019s shadow (or its path through Earth\u2019s shadow) above or below the target body, so no eclipse occurs — only when the alignment is nearly exact does the shadow actually land.' },
    { q: 'A person standing in the umbra of the Moon\u2019s shadow during a solar eclipse sees a total eclipse. What would a person standing in the penumbra see instead?', a: 'A partial eclipse — from the penumbra, only part of the Sun\u2019s disc is covered by the Moon, since part of the Sun is still visible from that position.' },
  ],
  pinhole: [
    { q: 'An object 1.6m tall stands 4m from a pinhole camera. The screen is 20cm behind the pinhole. Find the height of the image.', a: 'hI = hO×(v/u) = 1.6×(0.2/4) = 0.08m = 8cm.' },
    { q: 'Explain, using a ray diagram argument, why the image in a pinhole camera is always inverted.', a: 'A ray from the TOP of the object must travel in a straight line through the single pinhole — since the hole is below the top of the object, that ray continues downward past the hole and lands near the BOTTOM of the screen. Likewise, a ray from the bottom of the object lands near the top. Top-to-bottom and bottom-to-top swap, so the image is upside down.' },
    { q: 'A student makes the pinhole bigger to let in more light. What happens to the sharpness of the image, and why?', a: 'The image becomes blurrier. A larger hole allows a whole bundle of rays (not just one) from each point on the object to pass through, and these bundles land on overlapping regions of the screen instead of a single sharp point, smearing the image out.' },
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

export default function RectilinearPropagationPage() {
  const [topic, setTopic] = useState<Topic>('shadows');
  const [openEx, setOpenEx] = useState<number | null>(null);
  const [activeCurricula, setActiveCurricula] = useState(['WAEC', 'IGCSE', 'SAT']);

  const [sourceType, setSourceType] = useState<'point' | 'extended'>('extended');
  const [sourceRadius, setSourceRadius] = useState(35);
  const [objectRadius, setObjectRadius] = useState(24);
  const [objectDist, setObjectDist] = useState(160);
  const [screenDist, setScreenDist] = useState(420);

  const [eclipseType, setEclipseType] = useState<EclipseType>('solar');
  const [orbitalOffset, setOrbitalOffset] = useState(0);

  const [objectHeight, setObjectHeight] = useState(90);
  const [pinholeObjectDist, setPinholeObjectDist] = useState(140);
  const [pinholeScreenDist, setPinholeScreenDist] = useState(160);
  const [pinholeRadius, setPinholeRadius] = useState(1);

  const canvasBoxRef = useRef<HTMLDivElement>(null);
  const canvasSize = useResponsiveCanvasSize(canvasBoxRef, 660, 300, 980);

  const uLen = umbraLength(sourceRadius, objectRadius, objectDist);
  const imgH = pinholeImageHeight(objectHeight, pinholeObjectDist, pinholeScreenDist);
  const mag = pinholeMagnification(pinholeObjectDist, pinholeScreenDist);

  return (
    <>
      <AppHeader />
      <main className="min-h-screen bg-gray-50">
        <section className="border-b border-gray-200 bg-white">
          <div className="mx-auto max-w-[100rem] px-4 sm:px-6 py-4">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
              <div>
                <p className="text-xs text-gray-400 mb-0.5">Optics</p>
                <h1 className="text-lg font-semibold text-gray-900">Sources of Light & Rectilinear Propagation</h1>
              </div>
              <div className="flex gap-1.5 flex-wrap">
                {CURRICULA.map(c => (
                  <button key={c}
                    onClick={() => setActiveCurricula(p => p.includes(c) ? p.filter(x => x !== c) : [...p, c])}
                    className={`text-xs px-2.5 py-2 rounded-full border font-medium transition ${
                      activeCurricula.includes(c) ? CC[c] + ' border-transparent' : 'bg-white text-gray-400 border-gray-200'
                    }`}>{c}</button>
                ))}
              </div>
            </div>
          </div>
        </section>

        <div className="mx-auto max-w-[100rem] px-4 sm:px-6 py-4 space-y-4">
          <div className="flex gap-1 bg-gray-100 p-1 rounded-xl overflow-x-auto">
            {(Object.keys(TOPIC_META) as Topic[]).map(t => (
              <button key={t} onClick={() => { setTopic(t); setOpenEx(null); }}
                className={`shrink-0 flex items-center gap-1.5 px-3 py-2 rounded-lg text-xs font-medium transition ${
                  topic === t ? 'bg-white text-indigo-700 shadow-sm' : 'text-gray-500 hover:text-gray-700'
                }`}>
                <span>{TOPIC_META[t].icon}</span><span>{TOPIC_META[t].title}</span>
              </button>
            ))}
          </div>

          <div className="flex flex-wrap items-center gap-3 rounded-xl border border-gray-200 bg-white px-4 py-2.5">
            <span className="text-xs text-gray-400">{TOPIC_META[topic].sub}</span>
            <span className="text-sm font-semibold font-mono text-gray-900">{TOPIC_META[topic].eq}</span>
          </div>

          <div className="grid grid-cols-1 lg:grid-cols-[1fr_220px] xl:grid-cols-[1fr_220px_260px] gap-4">
            <div className="space-y-3 min-w-0">
              <div ref={canvasBoxRef} className="rounded-2xl border border-gray-200 bg-white p-3 shadow-sm">
                {topic === 'shadows' && (
                  <ShadowsCanvas sourceType={sourceType} sourceRadiusPx={sourceRadius} objectRadiusPx={objectRadius}
                    objectDistPx={objectDist} screenDistPx={screenDist}
                    width={canvasSize.width} height={canvasSize.height} />
                )}
                {topic === 'eclipse' && (
                  <EclipseCanvas eclipseType={eclipseType} orbitalOffset={orbitalOffset}
                    width={canvasSize.width} height={canvasSize.height} />
                )}
                {topic === 'pinhole' && (
                  <PinholeCanvas objectHeightPx={objectHeight} objectDistPx={pinholeObjectDist} screenDistPx={pinholeScreenDist}
                    pinholeRadiusPx={pinholeRadius}
                    width={canvasSize.width} height={canvasSize.height} />
                )}
              </div>

              <div className="flex flex-wrap items-center justify-end gap-2">
                <EmbedButton path="/embed/rectilinear-propagation"
                  title={`${TOPIC_META[topic].title} — A-Factor STEM Studio`}
                  params={
                    topic === 'shadows' ? { topic, src: sourceType, sr: sourceRadius, or: objectRadius, od: objectDist, sd: screenDist }
                    : topic === 'eclipse' ? { topic, type: eclipseType, offset: orbitalOffset }
                    : { topic, h: objectHeight, u: pinholeObjectDist, v: pinholeScreenDist, r: pinholeRadius }
                  } />
              </div>

              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm space-y-4">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide">Parameters</p>

                {topic === 'shadows' && <>
                  <div className="flex gap-2">
                    {(['point', 'extended'] as const).map(t => (
                      <button key={t} onClick={() => setSourceType(t)}
                        className={`flex-1 rounded-lg border px-2 py-2 text-xs font-medium capitalize transition ${
                          sourceType === t ? 'border-indigo-300 bg-indigo-50 text-indigo-700' : 'border-gray-200 bg-white text-gray-500'
                        }`}>{t} source</button>
                    ))}
                  </div>
                  {sourceType === 'extended' && (
                    <Slider label="Source size" unit="px" value={sourceRadius} min={5} max={60} step={1} set={setSourceRadius} color="#fbbf24" />
                  )}
                  <Slider label="Object size" unit="px" value={objectRadius} min={8} max={50} step={1} set={setObjectRadius} color="#64748b" />
                  <Slider label="Object distance" unit="px" value={objectDist} min={60} max={300} step={5} set={setObjectDist} color="#6366f1" />
                  <Slider label="Screen distance" unit="px" value={screenDist} min={objectDist + 40} max={560} step={5} set={setScreenDist} color="#8b5cf6" />
                </>}

                {topic === 'eclipse' && <>
                  <div className="flex gap-2">
                    {(['solar', 'lunar'] as const).map(t => (
                      <button key={t} onClick={() => setEclipseType(t)}
                        className={`flex-1 rounded-lg border px-2 py-2 text-xs font-medium capitalize transition ${
                          eclipseType === t ? 'border-indigo-300 bg-indigo-50 text-indigo-700' : 'border-gray-200 bg-white text-gray-500'
                        }`}>{t}</button>
                    ))}
                  </div>
                  <Slider label="Orbital alignment offset" unit="px" value={orbitalOffset} min={0} max={120} step={2} set={setOrbitalOffset} color="#6366f1"
                    note="0 = perfectly aligned. Increase to see why most months have no eclipse." />
                </>}

                {topic === 'pinhole' && <>
                  <Slider label="Object height" unit="px" value={objectHeight} min={30} max={130} step={5} set={setObjectHeight} color="#0f172a" />
                  <Slider label="Object distance (u)" unit="px" value={pinholeObjectDist} min={60} max={260} step={5} set={setPinholeObjectDist} color="#6366f1" />
                  <Slider label="Screen distance (v)" unit="px" value={pinholeScreenDist} min={40} max={260} step={5} set={setPinholeScreenDist} color="#8b5cf6" />
                  <Slider label="Pinhole size" unit="px" value={pinholeRadius} min={0} max={12} step={0.5} set={setPinholeRadius} color="#f59e0b"
                    note="0 = ideal sharp point. Larger → visibly blurs the image." />
                </>}
              </div>
            </div>

            <div className="space-y-3">
              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide mb-3">Calculated</p>
                <div className="space-y-2">
                  {topic === 'shadows' && <>
                    <StatRow label="Shadow type" value={sourceType === 'point' ? 'sharp (no penumbra)' : 'umbra + penumbra'} unit="" color="text-indigo-600" />
                    <StatRow label="Umbra converges at" value={uLen === null ? 'never (source ≤ object)' : uLen.toFixed(0)} unit={uLen === null ? '' : 'px beyond object'} color="text-emerald-600" />
                  </>}
                  {topic === 'eclipse' && <>
                    <StatRow label="Sun angular diameter" value={SUN_ANGULAR_DIAMETER_DEG.toFixed(3)} unit="°" color="text-amber-600" />
                    <StatRow label="Moon angular diameter" value={MOON_ANGULAR_DIAMETER_DEG.toFixed(3)} unit="°" color="text-indigo-600" />
                    <StatRow label="Ratio" value={(SUN_ANGULAR_DIAMETER_DEG / MOON_ANGULAR_DIAMETER_DEG).toFixed(3)} unit="" color="text-purple-600" />
                  </>}
                  {topic === 'pinhole' && <>
                    <StatRow label="Image height" value={imgH.toFixed(1)} unit="px" color="text-indigo-600" />
                    <StatRow label="Magnification v/u" value={mag.toFixed(3)} unit="×" color="text-emerald-600" />
                    <StatRow label="Orientation" value="inverted" unit="" color="text-rose-500" />
                    <StatRow label="Nature" value="real" unit="" color="text-purple-600" />
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
                  {TEACHER_NOTES[topic].map((n, i) => (
                    <li key={i} className="text-xs text-amber-900 leading-relaxed flex gap-2">
                      <span className="text-amber-400 shrink-0 mt-0.5">•</span>{n}
                    </li>
                  ))}
                </ul>
              </div>

              <div className="rounded-2xl border border-gray-200 bg-white p-4">
                <p className="text-xs font-medium text-gray-500 uppercase tracking-wide mb-3">✏️ Exercises</p>
                <div className="space-y-2">
                  {EXERCISES[topic].map((ex, i) => (
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
