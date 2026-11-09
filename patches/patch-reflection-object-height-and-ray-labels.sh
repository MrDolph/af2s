#!/usr/bin/env bash
set -euo pipefail
if [[ ! -f package.json || ! -f src/app/simulations/reflection/page.tsx ]]; then
  echo 'Run this patch from the A-Factor project root.' >&2
  exit 1
fi
patch_file=$(mktemp)
trap 'rm -f "$patch_file"' EXIT
cat > "$patch_file" <<'AF_MECHANICS_PATCH'
--- a/src/app/embed/reflection/page.tsx
+++ b/src/app/embed/reflection/page.tsx
@@ -53,6 +53,7 @@
 
   const [incidenceAngle, setIncidenceAngle] = useState(() => num(sp, 'angle', 35, 0, 90));
   const [focal, setFocal] = useState(() => num(sp, 'focal', 15, 5, 40));
+  const [objectHeight, setObjectHeight] = useState(() => num(sp, 'h', 12, 2, 30));
   const [objectDist, setObjectDist] = useState(() => num(sp, 'u', 40, 5, 90));
   const [converging, setConverging] = useState(() => sp.get('conv') !== '0');
   const [parabolic, setParabolic] = useState(() => sp.get('shape') === 'parabolic');
@@ -73,7 +74,7 @@
   return (
     <SimulationStage containerRef={embedBoxRef} className="af-embed-stage mx-auto max-w-4xl space-y-3 p-3 sm:p-4">
       <div data-stage-role="canvas"><ReflectionCanvas key={resetKey} mode={mode} incidenceAngle={incidenceAngle}
-        focal={focal} objectDist={objectDist} converging={converging}
+        focal={focal} objectDist={objectDist} objectHeight={objectHeight} converging={converging}
         parabolic={parabolic} source={source}
                   onRotationComplete={() => { setRotationDone(true); setIsRunning(false); }}
                   rotationAngle={rotationAngle} isRunning={isRunning} isPaused={isPaused}
@@ -101,7 +102,8 @@
             )}
             {mode === 'curved' && <>
               <Slider label="Focal length |f|" unit="cm" value={focal} min={5} max={40} step={1} set={setFocal} color="#f59e0b" />
-              {!parabolic && <Slider label="Object distance u" unit="cm" value={objectDist} min={5} max={90} step={1} set={setObjectDist} color="#6366f1" />}
+              {!parabolic && <Slider label="Object height" unit="cm" value={objectHeight} min={2} max={30} step={1} set={setObjectHeight} color="#6366f1" />}
+                  {!parabolic && <Slider label="Object distance u" unit="cm" value={objectDist} min={5} max={90} step={1} set={setObjectDist} color="#6366f1" />}
               <div className="space-y-1">
                 <span className="text-xs text-gray-500">Type</span>
                 <div className="flex gap-2">
--- a/src/app/simulations/reflection/page.tsx
+++ b/src/app/simulations/reflection/page.tsx
@@ -100,6 +100,7 @@
 
   const [incidenceAngle, setIncidenceAngle] = useState(35);
   const [focal, setFocal] = useState(15);
+  const [objectHeight, setObjectHeight] = useState(12);
   const [objectDist, setObjectDist] = useState(40);
   const [converging, setConverging] = useState(true);
 
@@ -136,6 +137,7 @@
   useTopicPreset("simulations-reflection", { "incidenceAngle": setIncidenceAngle,
     "focal": setFocal,
     "objectDist": setObjectDist,
+    "objectHeight": setObjectHeight,
     "rotationAngle": setRotationAngle }, { "mode": (value: string) => setMode(value as typeof mode) });
   return (
     <>
@@ -182,7 +184,7 @@
             <SimulationStage className="af-optics-stage space-y-3 min-w-0">
               <div data-stage-role="canvas" ref={canvasBoxRef} className="rounded-2xl border border-gray-200 bg-white p-3 shadow-sm">
                 <ReflectionCanvas key={resetKey} mode={mode} incidenceAngle={incidenceAngle}
-                  focal={focal} objectDist={objectDist} converging={converging}
+                  focal={focal} objectDist={objectDist} objectHeight={objectHeight} converging={converging}
                   parabolic={parabolic} source={source}
                   onRotationComplete={() => { setRotationDone(true); setIsRunning(false); }}
                   rotationAngle={rotationAngle} isRunning={isRunning} isPaused={isPaused}
@@ -201,7 +203,7 @@
                   params={
                     mode === 'plane' ? { mode, angle: incidenceAngle, source: source === 'hidden' ? 0 : source === 'point' ? 1 : source }
                     : mode === 'rotation' ? { mode, angle: rotationAngle, source: source === 'hidden' ? 0 : source === 'point' ? 1 : source }
-                    : { mode, focal, u: objectDist, conv: converging ? 1 : 0, shape: parabolic ? 'parabolic' : 'spherical', source: source === 'hidden' ? 0 : source === 'point' ? 1 : source }
+                    : { mode, focal, u: objectDist, h: objectHeight, conv: converging ? 1 : 0, shape: parabolic ? 'parabolic' : 'spherical', source: source === 'hidden' ? 0 : source === 'point' ? 1 : source }
                   } />
               </div>
 
@@ -241,6 +243,7 @@
                     </div>
                   </div>
                   <Slider label="Focal length |f|" unit="cm" value={focal} min={5} max={40} step={1} set={setFocal} color="#f59e0b" />
+                  {!parabolic && <Slider label="Object height" unit="cm" value={objectHeight} min={2} max={30} step={1} set={setObjectHeight} color="#6366f1" />}
                   {!parabolic && <Slider label="Object distance u" unit="cm" value={objectDist} min={5} max={90} step={1} set={setObjectDist} color="#6366f1"
                     note="Slide the object through 2F, F and inside F — watch the image flip" />}
                 </>}
@@ -264,6 +267,7 @@
                   </>}
                   {mode === 'curved' && !parabolic && <>
                     <StatRow label="Image distance v" value={img.atInfinity ? '∞' : Math.abs(img.v).toFixed(1)} unit={img.atInfinity ? '' : 'cm'} color="text-indigo-600" />
+                    <StatRow label="Image height" value={img.atInfinity ? '—' : (objectHeight * img.m).toFixed(1)} unit={img.atInfinity ? '' : 'cm'} color="text-emerald-600" />
                     <StatRow label="Magnification m" value={img.atInfinity ? '∞' : img.m.toFixed(2)} unit="×" color="text-emerald-600" />
                     <StatRow label="Nature" value={img.atInfinity ? 'at infinity' : img.real ? 'real' : 'virtual'} unit="" color="text-amber-600" />
                     <StatRow label="Orientation" value={img.atInfinity ? '—' : img.inverted ? 'inverted' : 'upright'} unit="" color="text-rose-500" />
--- a/src/components/simulation/ReflectionCanvas.tsx
+++ b/src/components/simulation/ReflectionCanvas.tsx
@@ -12,6 +12,7 @@
   incidenceAngle: number; // degrees from the normal
   // curved (cm as display units)
   focal: number;          // |f| in cm
+  objectHeight?: number;  // cm
   objectDist: number;     // u in cm
   converging: boolean;    // true = concave (converging), false = convex (diverging)
   parabolic?: boolean;
@@ -96,15 +97,15 @@
 
 export function ReflectionCanvas({
   mode, incidenceAngle, focal, objectDist, converging, rotationAngle,
-  parabolic = false, source = 'point', onRotationComplete,
+  objectHeight = 12, parabolic = false, source = 'point', onRotationComplete,
   isRunning, isPaused, onTick, width = 660, height = 320,
 }: Props) {
   const canvasRef = useRef<HTMLCanvasElement | null>(null);
   const rafRef = useRef<number>(0);
   const lastFrameRef = useRef<number | null>(null);
   const t = useRef(0);
-  const sim = useRef({ mode, incidenceAngle, focal, objectDist, converging, rotationAngle, isRunning, isPaused, onTick, parabolic, source, onRotationComplete });
-  sim.current = { mode, incidenceAngle, focal, objectDist, converging, rotationAngle, isRunning, isPaused, onTick, parabolic, source, onRotationComplete };
+  const sim = useRef({ mode, incidenceAngle, focal, objectDist, converging, rotationAngle, isRunning, isPaused, onTick, objectHeight, parabolic, source, onRotationComplete });
+  sim.current = { mode, incidenceAngle, focal, objectDist, converging, rotationAngle, isRunning, isPaused, onTick, objectHeight, parabolic, source, onRotationComplete };
 
   useEffect(() => { t.current = 0; lastFrameRef.current = null; }, [mode, incidenceAngle, focal, objectDist, converging, rotationAngle]);
 
@@ -198,15 +199,13 @@
       // a dashed backward extension from the reflection point through the
       // eye's direction, landing exactly on the image (top/bottom).
       [
-        { obj: objTip, P: P1 },
-        { obj: objBase, P: P2 },
-      ].forEach(({ obj, P }) => {
+        { obj: objTip, image: imgTip, P: P1 },
+        { obj: objBase, image: imgBase, P: P2 },
+      ].forEach(({ obj, image, P }) => {
         arrow(ctx, obj.x, obj.y, P.x, P.y, '#10b981', 1.8);
         arrow(ctx, P.x, P.y, eye.x, eye.y, '#10b981', 1.8, 0.85);
         ctx.save(); ctx.setLineDash([5, 4]); ctx.strokeStyle = 'rgba(16,185,129,0.55)'; ctx.lineWidth = 1.4;
-        const ang = Math.atan2(eye.y - P.y, eye.x - P.x);
-        const backX = P.x - Math.cos(ang) * 260, backY = P.y - Math.sin(ang) * 260;
-        ctx.beginPath(); ctx.moveTo(P.x, P.y); ctx.lineTo(backX, backY); ctx.stroke();
+        ctx.beginPath(); ctx.moveTo(P.x, P.y); ctx.lineTo(image.x, image.y); ctx.stroke();
         ctx.restore();
       });
 
@@ -230,7 +229,7 @@
       const u = s.objectDist;
       const img = thinLensImage(u, f);
       const maxDistance = Math.max(u, 2 * s.focal, img.atInfinity ? 0 : Math.abs(img.v));
-      const objectHeight = 12;
+      const objectHeight = Math.max(2, Math.min(30, s.objectHeight));
       const maxHeight = objectHeight * Math.max(1, img.atInfinity ? 1 : img.m);
       const mirrorHalf = Math.min(H * 0.33, W * 0.26);
       const scale = Math.min((W / 2 - 32) / maxDistance, (H / 2 - 28) / maxHeight, mirrorHalf * 0.82 / objectHeight);
@@ -327,7 +326,7 @@
       ctx.fillStyle = '#334155'; ctx.font = '600 14px system-ui'; ctx.textAlign = 'left';
       const nature = img.atInfinity ? 'at infinity'
         : `${img.real ? 'real' : 'virtual'}, ${img.inverted ? 'inverted' : 'upright'}, ${img.m > 1 ? 'magnified' : img.m < 1 ? 'diminished' : 'same size'}`;
-      ctx.fillText(`u=${u}cm  f=${f}cm  →  v=${img.atInfinity ? '∞' : Math.abs(img.v).toFixed(1) + 'cm'}  m=${img.atInfinity ? '∞' : img.m.toFixed(2)}  (${nature})`, 8, H - 8, W - 20);
+      ctx.fillText(`u=${u}cm  f=${f}cm  →  v=${img.atInfinity ? '∞' : Math.abs(img.v).toFixed(1) + 'cm'}  hₒ=${objectHeight}cm  m=${img.atInfinity ? '∞' : img.m.toFixed(2)}  (${nature})`, 8, H - 8, W - 20);
     } else {
       // ── Rotation of a mirror: incident ray fixed, mirror rotates ──────────
       // Classic result: rotate the mirror by θ, the reflected ray rotates by
@@ -382,7 +381,11 @@
 
       // Normal (dashed)
       ctx.save(); ctx.setLineDash([4, 4]); ctx.strokeStyle = '#94a3b8'; ctx.lineWidth = 1;
-      ctx.beginPath(); ctx.moveTo(P.x - normal.x * (rayLength * 0.65), P.y - normal.y * (rayLength * 0.65)); ctx.lineTo(P.x + normal.x * (rayLength * 0.65), P.y + normal.y * (rayLength * 0.65)); ctx.stroke();
+      const normalLength = Math.min(rayLength * 1.3, Math.max(rayLength, P.y - 49));
+      const normalTip = { x: P.x + normal.x * normalLength, y: P.y + normal.y * normalLength };
+      ctx.beginPath();
+      ctx.moveTo(P.x - normal.x * rayLength * 0.75, P.y - normal.y * rayLength * 0.75);
+      ctx.lineTo(normalTip.x, normalTip.y); ctx.stroke();
       ctx.restore();
 
       // Incident ray (fixed) and current reflected ray
@@ -425,16 +428,21 @@
       ctx.fillStyle = '#0f172a'; ctx.beginPath(); ctx.arc(P.x, P.y, 4, 0, Math.PI * 2); ctx.fill();
       const reflectedEnd = { x: P.x + r.x * rayLength, y: P.y + r.y * rayLength };
       ctx.fillStyle = '#047857'; ctx.font = '700 14px system-ui'; ctx.textAlign = r.x >= 0 ? 'left' : 'right';
-      ctx.fillText('Reflected', reflectedEnd.x + (r.x >= 0 ? 5 : -5), reflectedEnd.y - 6,
+      ctx.fillText('R', reflectedEnd.x + (r.x >= 0 ? 5 : -5), reflectedEnd.y - 6,
         Math.max(1, (r.x >= 0 ? W - reflectedEnd.x : reflectedEnd.x) - 10));
+
+      ctx.fillStyle = '#92400e'; ctx.textAlign = 'left';
+      ctx.fillText('R′', P.x + r0.x * rayLength + 5, P.y + r0.y * rayLength + 13);
+      ctx.fillStyle = '#475569'; ctx.textAlign = 'center';
+      ctx.fillText('Normal', normalTip.x, Math.max(55, normalTip.y - 5), W - 16);
 
       ctx.textAlign = 'center'; ctx.font = '700 16px system-ui'; ctx.fillStyle = '#0f172a';
       ctx.fillText(`Mirror θ = ${angleDeg.toFixed(1)}°   ·   Ray turn 2θ = ${reflectedDeg.toFixed(1)}°`, W / 2, 20, W - 16);
       ctx.font = '600 14px system-ui';
       ctx.fillText(`From the current normal: incidence i = reflection r = ${incidenceDeg.toFixed(1)}°`, W / 2, 39, W - 16);
       ctx.fillStyle = '#334155';
-      ctx.fillText('Blue: fixed incident ray · Green: current reflected ray', W / 2, H - 27, W - 16);
-      ctx.fillText('Dark solid: current mirror · Dashed: initial mirror, initial ray, current normal', W / 2, H - 9, W - 16);
+      ctx.fillText('R′: original reflected ray · R: new reflected ray', W / 2, H - 27, W - 16);
+      ctx.fillText('Blue: fixed incident ray · r: angle of reflection', W / 2, H - 9, W - 16);
     }
 
     rafRef.current = requestAnimationFrame(draw);
AF_MECHANICS_PATCH
if git apply --reverse --check "$patch_file" 2>/dev/null; then
  echo 'Mechanics update is already installed.'
  exit 0
fi
if ! git apply --check "$patch_file"; then
  echo 'The patch conflicts with your current source. No source files changed.' >&2
  exit 1
fi
git apply "$patch_file"
echo 'Reflection height and ray labels updated.'
