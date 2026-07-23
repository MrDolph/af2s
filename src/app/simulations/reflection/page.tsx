'use client';
import { useState, useCallback, useEffect, useRef } from 'react';
import { AppHeader } from '@/components/layout/AppHeader';
import { SimulationControls } from '@/components/simulation/SimulationControls';
import { ReflectionCanvas, ReflectionMode } from '@/components/simulation/ReflectionCanvas';
import { EmbedButton } from '@/components/ui/EmbedButton';
import { thinLensImage } from '@/lib/physics/optics';
import { useResponsiveCanvasSize } from '@/hooks/useResponsiveCanvasSize';

const CURRICULA = ['WAEC', 'NECO', 'IGCSE', 'SAT', 'JUPEB'];
const CC: Record<string, string> = {
  WAEC: 'bg-indigo-100 text-indigo-700', NECO: 'bg-pink-100 text-pink-700',
  IGCSE: 'bg-emerald-100 text-emerald-700', SAT: 'bg-orange-100 text-orange-700',
  JUPEB: 'bg-purple-100 text-purple-700',
};

const MODE_META: Record<ReflectionMode, { title: string; icon: string; sub: string; eq: string }> = {
  plane:    { title: 'Plane mirror',  icon: '🪞', sub: 'The law of reflection',    eq: '∠i = ∠r' },
  curved:   { title: 'Curved mirror', icon: '🛰️', sub: 'Concave & convex',        eq: '1/f = 1/u + 1/v' },
  rotation: { title: 'Rotating mirror', icon: '🔄', sub: 'Fixed source, rotating mirror', eq: 'reflected ray turns through 2θ' },
};

const TEACHER_NOTES: Record<ReflectionMode, string[]> = {
  plane: [
    'The law of reflection: the angle of incidence equals the angle of reflection (∠i = ∠r), both measured from the NORMAL — never from the mirror surface itself.',
    'The incident ray, the reflected ray, and the normal all lie in the SAME plane — a detail examiners sometimes ask for directly.',
    'A plane mirror image is: the same size as the object, the same distance behind the mirror as the object is in front, upright, and VIRTUAL (light doesn\u2019t actually pass through it — it only appears to come from there).',
    'Lateral inversion: left and right are swapped (not up and down) — why text held up to a mirror reads backwards, and why an ambulance often has "AMBULANCE" printed mirror-reversed on the front so drivers read it correctly in their rear-view mirror.',
    'A plane mirror image cannot be captured on a screen (it\u2019s virtual) — this is the standard way exams distinguish a real image from a virtual one.',
  ],
  curved: [
    'Concave mirror (converging, f > 0): real images form on the SAME side as the object — the front, reflecting side.',
    'Convex mirror (diverging, f < 0): always virtual, upright, diminished — that\u2019s why it\u2019s used for car wing mirrors and shop security ("objects are closer than they appear").',
    'Focal length f = R/2, where R is the radius of curvature of the mirror.',
    'Uses of concave mirrors: shaving/makeup mirrors (object inside F → magnified upright virtual image), torch and headlamp reflectors (bulb placed at F → parallel reflected beam).',
    'A mirror only has ONE reflecting side — unlike a lens, its focal point and centre of curvature only exist on the object\u2019s side, never "behind" it.',
  ],
  rotation: [
    'The core result: if the incident ray is kept fixed and the mirror is rotated through an angle θ, the reflected ray turns through 2θ — TWICE the mirror\u2019s rotation, in the same direction.',
    'Why: rotating the mirror by θ rotates its normal by θ too (the normal is rigidly attached to the mirror surface). Since the angle of incidence is measured from the normal, it also changes by θ — and by the law of reflection, the angle of reflection changes by the same θ. The reflected ray\u2019s total swing is the sum of both these θ shifts either side of the original ray, giving 2θ overall.',
    'This is one of the most frequently recurring JAMB/UTME physics questions — usually phrased as "a plane mirror is rotated through angle θ while the incident ray is kept fixed; through what angle does the reflected ray turn?" with 2θ as the correct option among distractors like θ/2, θ, and 3θ.',
    'The image size never changes when a plane mirror rotates — only the image POSITION changes, since a plane mirror always produces a same-size, upright, virtual image regardless of its orientation.',
    'Real application: this principle is used in rotating-mirror devices for measuring the speed of light (Foucault\u2019s and Michelson\u2019s methods), in optical levers and galvanometers (a tiny needle rotation is amplified into a much larger, easily-read beam deflection), and in laser scanning/steering mirrors.',
  ],
};

const EXERCISES: Record<ReflectionMode, { q: string; a: string }[]> = {
  plane: [
    { q: 'A ray of light strikes a plane mirror at 30° to the mirror surface. Find the angle of reflection.', a: 'Angles are measured from the NORMAL, not the surface: angle of incidence = 90°−30° = 60°. By the law of reflection, angle of reflection = 60° too.' },
    { q: 'An object stands 1.2m in front of a plane mirror. How far is its image from the object itself?', a: 'The image forms 1.2m behind the mirror, so it is 1.2+1.2 = 2.4m from the object.' },
    { q: 'Explain why an ambulance often has its name printed backwards on the front of the vehicle.', a: 'A driver ahead sees it via their rear-view mirror, which laterally inverts it — printing it backwards means it reads correctly (forwards) once reflected.' },
  ],
  curved: [
    { q: 'An object 40cm from a concave mirror of f=15cm. Find the image.', a: '1/v = 1/15 − 1/40 = 5/120 → v = 24cm: real, inverted, m = 0.6 (diminished).' },
    { q: 'Why are convex mirrors used as driving/security mirrors?', a: 'They always give an upright, diminished, virtual image with a much wider field of view than a plane mirror of the same size.' },
    { q: 'A concave mirror has radius of curvature 60cm. Where must a bulb be placed for the reflected beam to emerge parallel?', a: 'f = R/2 = 30cm. Placing the bulb at the focal point sends all reflected rays out parallel to the axis — the principle behind torches and headlamps.' },
  ],
  rotation: [
    { q: 'A ray of light is incident on a plane mirror. If the mirror is rotated through an angle θ while the incident ray is kept fixed, through what angle is the reflected ray rotated? (A) θ/2 (B) θ (C) 2θ (D) 3θ', a: '(C) 2θ. This exact question — in this exact multiple-choice form — is one of the most frequently recurring physics questions in JAMB/UTME past papers.' },
    { q: 'A ray of light strikes a plane mirror, making an angle of incidence of 25°. The mirror is then rotated through 12°, with the incident ray kept fixed. Find the new angle of incidence, and the angle through which the reflected ray has turned.', a: 'The angle of incidence changes by the same amount the mirror rotates: new i = 25°+12° = 37°. The reflected ray turns through 2×12° = 24°.' },
    { q: 'A plane mirror is spun at a steady angular speed of 8 revolutions per second about an axis in its own plane, while a fixed laser beam strikes it continuously. At what angular speed does the reflected beam sweep around?', a: 'The reflected ray always rotates at exactly twice the mirror\u2019s angular speed: 2×8 = 16 revolutions per second.' },
    { q: 'Explain why the SIZE of the image in a plane mirror does not change as the mirror is rotated, even though its position does.', a: 'A plane mirror always forms a virtual image the same distance behind the mirror as the object is in front, and the same size as the object — this holds at every mirror orientation, since it follows purely from the law of reflection applied to a flat surface. Rotating the mirror changes WHERE that image appears (as the reflected ray direction shifts by 2θ), but not the image\u2019s size.' },
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

export default function ReflectionPage() {
  const [mode, setMode] = useState<ReflectionMode>('plane');
  const [openEx, setOpenEx] = useState<number | null>(null);
  const [activeCurricula, setActiveCurricula] = useState(['WAEC', 'IGCSE', 'SAT']);

  const [incidenceAngle, setIncidenceAngle] = useState(35);
  const [focal, setFocal] = useState(15);
  const [objectDist, setObjectDist] = useState(40);
  const [converging, setConverging] = useState(true);

  const [rotationAngle, setRotationAngle] = useState(15);
  const [isRunning, setIsRunning] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const [resetKey, setResetKey] = useState(0);
  const [liveAngles, setLiveAngles] = useState({ mirror: 0, reflected: 0 });

  const f = converging ? focal : -focal;
  const img = thinLensImage(objectDist, f);

  const reset = useCallback(() => { setIsRunning(false); setIsPaused(false); setResetKey(k => k + 1); }, []);
  const resetTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  useEffect(() => {
    if (resetTimer.current) clearTimeout(resetTimer.current);
    resetTimer.current = setTimeout(reset, 100);
  }, [mode, incidenceAngle, focal, objectDist, converging, rotationAngle, reset]);

  const lastTickRef = useRef(0);
  const handleRotationTick = useCallback((mirrorDeg: number, reflectedDeg: number) => {
    const now = performance.now();
    if (now - lastTickRef.current < 60) return;
    lastTickRef.current = now;
    setLiveAngles({ mirror: mirrorDeg, reflected: reflectedDeg });
  }, []);

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
                <h1 className="text-lg font-semibold text-gray-900">Reflection</h1>
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
            {(Object.keys(MODE_META) as ReflectionMode[]).map(m => (
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
          </div>

          <div className="grid grid-cols-1 lg:grid-cols-[1fr_220px] xl:grid-cols-[1fr_220px_260px] gap-4">
            <div className="space-y-3 min-w-0">
              <div ref={canvasBoxRef} className="rounded-2xl border border-gray-200 bg-white p-3 shadow-sm">
                <ReflectionCanvas key={resetKey} mode={mode} incidenceAngle={incidenceAngle}
                  focal={focal} objectDist={objectDist} converging={converging}
                  rotationAngle={rotationAngle} isRunning={isRunning} isPaused={isPaused}
                  onTick={handleRotationTick}
                  width={canvasSize.width} height={canvasSize.height} />
              </div>

              <div className="flex flex-wrap items-center justify-between gap-2">
                {mode === 'rotation' ? (
                  <SimulationControls isRunning={isRunning} isPaused={isPaused}
                    onRun={() => { setIsRunning(true); setIsPaused(false); }}
                    onPause={() => setIsPaused(p => !p)} onReset={reset} />
                ) : <span />}
                <EmbedButton path="/embed/reflection"
                  title={`${MODE_META[mode].title} — A-Factor STEM Studio`}
                  params={
                    mode === 'plane' ? { mode, angle: incidenceAngle }
                    : mode === 'rotation' ? { mode, angle: rotationAngle }
                    : { mode, focal, u: objectDist, conv: converging ? 1 : 0 }
                  } />
              </div>

              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm space-y-4">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide">Parameters</p>

                {mode === 'plane' && (
                  <Slider label="Angle of incidence" unit="°" value={incidenceAngle} min={5} max={80} step={1} set={setIncidenceAngle} color="#6366f1"
                    note="Measured from the normal, not the mirror surface" />
                )}

                {mode === 'curved' && <>
                  <div className="space-y-1.5">
                    <span className="text-xs text-gray-500">Type</span>
                    <div className="flex gap-2">
                      {([true, false] as const).map(c => (
                        <button key={String(c)} onClick={() => setConverging(c)}
                          className={`flex-1 rounded-lg border px-2 py-2 text-xs font-medium transition ${
                            converging === c ? 'border-indigo-300 bg-indigo-50 text-indigo-700' : 'border-gray-200 bg-white text-gray-500'
                          }`}>
                          {c ? 'Concave (converging)' : 'Convex (diverging)'}
                        </button>
                      ))}
                    </div>
                  </div>
                  <Slider label="Focal length |f|" unit="cm" value={focal} min={5} max={40} step={1} set={setFocal} color="#f59e0b" />
                  <Slider label="Object distance u" unit="cm" value={objectDist} min={5} max={90} step={1} set={setObjectDist} color="#6366f1"
                    note="Slide the object through 2F, F and inside F — watch the image flip" />
                </>}

                {mode === 'rotation' && (
                  <Slider label="Mirror rotation θ" unit="°" value={rotationAngle} min={-35} max={35} step={1} set={setRotationAngle} color="#6366f1"
                    note="Press Run to sweep automatically, or set a fixed angle here while paused/reset" />
                )}
              </div>
            </div>

            <div className="space-y-3">
              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide mb-3">Calculated</p>
                <div className="space-y-2">
                  {mode === 'plane' && <>
                    <StatRow label="Angle of reflection" value={incidenceAngle.toFixed(0)} unit="°" color="text-indigo-600" />
                    <StatRow label="Image distance" value="= object distance" unit="" color="text-emerald-600" />
                    <StatRow label="Nature" value="virtual, upright" unit="" color="text-purple-600" />
                    <StatRow label="Orientation" value="laterally inverted" unit="" color="text-rose-500" />
                  </>}
                  {mode === 'curved' && <>
                    <StatRow label="Image distance v" value={img.atInfinity ? '∞' : Math.abs(img.v).toFixed(1)} unit={img.atInfinity ? '' : 'cm'} color="text-indigo-600" />
                    <StatRow label="Magnification m" value={img.atInfinity ? '∞' : img.m.toFixed(2)} unit="×" color="text-emerald-600" />
                    <StatRow label="Nature" value={img.atInfinity ? 'at infinity' : img.real ? 'real' : 'virtual'} unit="" color="text-amber-600" />
                    <StatRow label="Orientation" value={img.atInfinity ? '—' : img.inverted ? 'inverted' : 'upright'} unit="" color="text-rose-500" />
                    <StatRow label="Radius R = 2f" value={(2 * focal).toFixed(0)} unit="cm" color="text-purple-600" />
                  </>}
                  {mode === 'rotation' && <>
                    <StatRow label="Mirror rotation θ" value={rotationAngle.toFixed(0)} unit="°" color="text-indigo-600" />
                    <StatRow label="Expected reflected-ray rotation" value={(2 * rotationAngle).toFixed(0)} unit="°" color="text-emerald-600" />
                    <StatRow label="Live mirror angle" value={liveAngles.mirror.toFixed(1)} unit="°" color="text-amber-600" />
                    <StatRow label="Live reflected-ray angle" value={liveAngles.reflected.toFixed(1)} unit="°" color="text-rose-500" />
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
