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
@@ -55,12 +55,15 @@
   const [focal, setFocal] = useState(() => num(sp, 'focal', 15, 5, 40));
   const [objectDist, setObjectDist] = useState(() => num(sp, 'u', 40, 5, 90));
   const [converging, setConverging] = useState(() => sp.get('conv') !== '0');
+  const [parabolic, setParabolic] = useState(() => sp.get('shape') === 'parabolic');
+  const [showSource, setShowSource] = useState(() => sp.get('source') !== '0');
+  const [rotationDone, setRotationDone] = useState(false);
   const [rotationAngle, setRotationAngle] = useState(() => num(sp, 'angle', 15, -35, 35));
 
   const [isRunning, setIsRunning] = useState(false);
   const [isPaused, setIsPaused] = useState(false);
   const [resetKey, setResetKey] = useState(0);
-  const reset = useCallback(() => { setIsRunning(false); setIsPaused(false); setResetKey(k => k + 1); }, []);
+  const reset = useCallback(() => { setIsRunning(false); setIsPaused(false); setRotationDone(false); setResetKey(k => k + 1); }, []);
   const resetTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
   useEffect(() => {
     if (resetTimer.current) clearTimeout(resetTimer.current);
@@ -71,34 +74,44 @@
     <SimulationStage containerRef={embedBoxRef} className="af-embed-stage mx-auto max-w-4xl space-y-3 p-3 sm:p-4">
       <div data-stage-role="canvas"><ReflectionCanvas key={resetKey} mode={mode} incidenceAngle={incidenceAngle}
         focal={focal} objectDist={objectDist} converging={converging}
-        rotationAngle={rotationAngle} isRunning={isRunning} isPaused={isPaused}
+        parabolic={parabolic} showSource={showSource}
+                  onRotationComplete={() => { setRotationDone(true); setIsRunning(false); }}
+                  rotationAngle={rotationAngle} isRunning={isRunning} isPaused={isPaused}
         width={Math.max(160, embedSize.width - 24)} height={Math.round((Math.max(160, embedSize.width - 24)) / (embedSize.width < 600 ? Math.min(2.0625, 1.6) : 2.0625))} /></div>
       <div data-stage-role="playback">{mode === 'rotation' && (
         <SimulationControls isRunning={isRunning} isPaused={isPaused}
-          onRun={() => { setIsRunning(true); setIsPaused(false); }}
+          onRun={() => { if (rotationDone) setResetKey(k => k + 1); setRotationDone(false); setIsRunning(true); setIsPaused(false); }}
           onPause={() => setIsPaused(p => !p)} onReset={reset} />
       )}</div>
       <div data-stage-role="parameters">{showControls && (
         <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
           <p className="mb-3 text-xs font-medium uppercase tracking-wide text-gray-400">Parameters</p>
           <div className="grid grid-cols-1 gap-x-6 gap-y-3 sm:grid-cols-2">
-            {mode === 'plane' && (
+            <label className="flex items-center gap-2 text-sm text-slate-700">
+                  <input type="checkbox" checked={showSource} onChange={event => setShowSource(event.target.checked)} />
+                  Show light source
+                </label>
+                {mode === 'plane' && (
               <Slider label="Angle of incidence" unit="°" value={incidenceAngle} min={0} max={90} step={1} set={setIncidenceAngle} color="#6366f1" />
             )}
             {mode === 'curved' && <>
               <Slider label="Focal length |f|" unit="cm" value={focal} min={5} max={40} step={1} set={setFocal} color="#f59e0b" />
-              <Slider label="Object distance u" unit="cm" value={objectDist} min={5} max={90} step={1} set={setObjectDist} color="#6366f1" />
+              {!parabolic && <Slider label="Object distance u" unit="cm" value={objectDist} min={5} max={90} step={1} set={setObjectDist} color="#6366f1" />}
               <div className="space-y-1">
                 <span className="text-xs text-gray-500">Type</span>
                 <div className="flex gap-2">
                   {([true, false] as const).map(c => (
-                    <button key={String(c)} onClick={() => setConverging(c)}
+                    <button key={String(c)} onClick={() => { setParabolic(false); setConverging(c); }}
                       className={`flex-1 rounded-lg border px-2 py-1.5 text-xs font-medium transition ${
-                        converging === c ? 'border-indigo-300 bg-indigo-50 text-indigo-700' : 'border-gray-200 bg-white text-gray-500'
+                        !parabolic && converging === c ? 'border-indigo-300 bg-indigo-50 text-indigo-700' : 'border-gray-200 bg-white text-gray-500'
                       }`}>
                       {c ? 'Concave' : 'Convex'}
                     </button>
                   ))}
+                  <button type="button" aria-pressed={parabolic} onClick={() => setParabolic(true)}
+                    className={`rounded-lg border px-2 py-2 text-xs font-medium ${parabolic ? 'border-indigo-300 bg-indigo-50 text-indigo-700' : 'border-gray-200 bg-white text-gray-600'}`}>
+                    Parabolic
+                  </button>
                 </div>
               </div>
             </>}
--- a/src/app/simulations/reflection/page.tsx
+++ b/src/app/simulations/reflection/page.tsx
@@ -103,6 +103,9 @@
   const [objectDist, setObjectDist] = useState(40);
   const [converging, setConverging] = useState(true);
 
+  const [parabolic, setParabolic] = useState(false);
+  const [showSource, setShowSource] = useState(true);
+  const [rotationDone, setRotationDone] = useState(false);
   const [rotationAngle, setRotationAngle] = useState(15);
   const [isRunning, setIsRunning] = useState(false);
   const [isPaused, setIsPaused] = useState(false);
@@ -112,7 +115,7 @@
   const f = converging ? focal : -focal;
   const img = thinLensImage(objectDist, f);
 
-  const reset = useCallback(() => { setIsRunning(false); setIsPaused(false); setResetKey(k => k + 1); }, []);
+  const reset = useCallback(() => { setIsRunning(false); setIsPaused(false); setRotationDone(false); setResetKey(k => k + 1); }, []);
   const resetTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
   useEffect(() => {
     if (resetTimer.current) clearTimeout(resetTimer.current);
@@ -180,6 +183,8 @@
               <div data-stage-role="canvas" ref={canvasBoxRef} className="rounded-2xl border border-gray-200 bg-white p-3 shadow-sm">
                 <ReflectionCanvas key={resetKey} mode={mode} incidenceAngle={incidenceAngle}
                   focal={focal} objectDist={objectDist} converging={converging}
+                  parabolic={parabolic} showSource={showSource}
+                  onRotationComplete={() => { setRotationDone(true); setIsRunning(false); }}
                   rotationAngle={rotationAngle} isRunning={isRunning} isPaused={isPaused}
                   onTick={handleRotationTick}
                   width={canvasSize.width} height={canvasSize.height} />
@@ -188,21 +193,25 @@
               <div data-stage-role="playback" className="flex flex-wrap items-center justify-between gap-2">
                 {mode === 'rotation' ? (
                   <SimulationControls isRunning={isRunning} isPaused={isPaused}
-                    onRun={() => { setIsRunning(true); setIsPaused(false); }}
+                    onRun={() => { if (rotationDone) setResetKey(k => k + 1); setRotationDone(false); setIsRunning(true); setIsPaused(false); }}
                     onPause={() => setIsPaused(p => !p)} onReset={reset} />
                 ) : <span />}
                 <EmbedButton path="/embed/reflection"
                   title={`${MODE_META[mode].title} — A-Factor STEM Studio`}
                   params={
-                    mode === 'plane' ? { mode, angle: incidenceAngle }
-                    : mode === 'rotation' ? { mode, angle: rotationAngle }
-                    : { mode, focal, u: objectDist, conv: converging ? 1 : 0 }
+                    mode === 'plane' ? { mode, angle: incidenceAngle, source: showSource ? 1 : 0 }
+                    : mode === 'rotation' ? { mode, angle: rotationAngle, source: showSource ? 1 : 0 }
+                    : { mode, focal, u: objectDist, conv: converging ? 1 : 0, shape: parabolic ? 'parabolic' : 'spherical', source: showSource ? 1 : 0 }
                   } />
               </div>
 
               <div data-stage-role="parameters" className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm space-y-4">
                 <p className="text-xs font-medium text-gray-400 uppercase tracking-wide">Parameters</p>
 
+                <label className="flex items-center gap-2 text-sm text-slate-700">
+                  <input type="checkbox" checked={showSource} onChange={event => setShowSource(event.target.checked)} />
+                  Show light source
+                </label>
                 {mode === 'plane' && (
                   <Slider label="Angle of incidence" unit="°" value={incidenceAngle} min={0} max={90} step={1} set={setIncidenceAngle} color="#6366f1"
                     note="Measured from the normal, not the mirror surface" />
@@ -213,23 +222,27 @@
                     <span className="text-xs text-gray-500">Type</span>
                     <div className="flex gap-2">
                       {([true, false] as const).map(c => (
-                        <button key={String(c)} onClick={() => setConverging(c)}
+                        <button key={String(c)} onClick={() => { setParabolic(false); setConverging(c); }}
                           className={`flex-1 rounded-lg border px-2 py-2 text-xs font-medium transition ${
-                            converging === c ? 'border-indigo-300 bg-indigo-50 text-indigo-700' : 'border-gray-200 bg-white text-gray-500'
+                            !parabolic && converging === c ? 'border-indigo-300 bg-indigo-50 text-indigo-700' : 'border-gray-200 bg-white text-gray-500'
                           }`}>
                           {c ? 'Concave (converging)' : 'Convex (diverging)'}
                         </button>
                       ))}
+                  <button type="button" aria-pressed={parabolic} onClick={() => setParabolic(true)}
+                    className={`rounded-lg border px-2 py-2 text-xs font-medium ${parabolic ? 'border-indigo-300 bg-indigo-50 text-indigo-700' : 'border-gray-200 bg-white text-gray-600'}`}>
+                    Parabolic
+                  </button>
                     </div>
                   </div>
                   <Slider label="Focal length |f|" unit="cm" value={focal} min={5} max={40} step={1} set={setFocal} color="#f59e0b" />
-                  <Slider label="Object distance u" unit="cm" value={objectDist} min={5} max={90} step={1} set={setObjectDist} color="#6366f1"
-                    note="Slide the object through 2F, F and inside F — watch the image flip" />
+                  {!parabolic && <Slider label="Object distance u" unit="cm" value={objectDist} min={5} max={90} step={1} set={setObjectDist} color="#6366f1"
+                    note="Slide the object through 2F, F and inside F — watch the image flip" />}
                 </>}
 
                 {mode === 'rotation' && (
                   <Slider label="Mirror rotation θ" unit="°" value={rotationAngle} min={-35} max={35} step={1} set={setRotationAngle} color="#6366f1"
-                    note="Press Run to sweep automatically, or set a fixed angle here while paused/reset" />
+                    note="Set the target angle, then press Run for one turn from 0°." />
                 )}
               </div>
             </SimulationStage>
@@ -244,13 +257,14 @@
                     <StatRow label="Nature" value="virtual, upright" unit="" color="text-purple-600" />
                     <StatRow label="Orientation" value="laterally inverted" unit="" color="text-rose-500" />
                   </>}
-                  {mode === 'curved' && <>
+                  {mode === 'curved' && !parabolic && <>
                     <StatRow label="Image distance v" value={img.atInfinity ? '∞' : Math.abs(img.v).toFixed(1)} unit={img.atInfinity ? '' : 'cm'} color="text-indigo-600" />
                     <StatRow label="Magnification m" value={img.atInfinity ? '∞' : img.m.toFixed(2)} unit="×" color="text-emerald-600" />
                     <StatRow label="Nature" value={img.atInfinity ? 'at infinity' : img.real ? 'real' : 'virtual'} unit="" color="text-amber-600" />
                     <StatRow label="Orientation" value={img.atInfinity ? '—' : img.inverted ? 'inverted' : 'upright'} unit="" color="text-rose-500" />
                     <StatRow label="Radius R = 2f" value={(2 * focal).toFixed(0)} unit="cm" color="text-purple-600" />
                   </>}
+                  {mode === 'curved' && parabolic && <StatRow label="Parallel rays focus at" value={focal.toFixed(0)} unit="cm" color="text-indigo-600" />}
                   {mode === 'rotation' && <>
                     <StatRow label="Mirror rotation θ" value={rotationAngle.toFixed(0)} unit="°" color="text-indigo-600" />
                     <StatRow label="Expected reflected-ray rotation" value={(2 * rotationAngle).toFixed(0)} unit="°" color="text-emerald-600" />
--- a/src/components/simulation/ReflectionCanvas.tsx
+++ b/src/components/simulation/ReflectionCanvas.tsx
@@ -12,9 +12,10 @@
   focal: number;          // |f| in cm
   objectDist: number;     // u in cm
   converging: boolean;    // true = concave (converging), false = convex (diverging)
-  // rotation — mirror angle used whenever the animation isn't actively
-  // sweeping (i.e. before Run, or after Pause/Reset)
-  rotationAngle: number;  // degrees, mirror tilt from its 0° reference position
+  parabolic?: boolean;
+  showSource?: boolean;
+  onRotationComplete?: () => void;
+  rotationAngle: number;  // target tilt from the 0° reference position
   isRunning: boolean; isPaused: boolean;
   onTick?: (mirrorDeg: number, reflectedDeg: number) => void;
   width?: number; height?: number;
@@ -72,19 +73,19 @@
   return { x: v.x / len, y: v.y / len };
 }
 
-const SWEEP_MAX_DEG = 35;
-const SWEEP_PERIOD = 4.5; // s — one full back-and-forth cycle
+const ROTATION_SECONDS = 3;
 
 export function ReflectionCanvas({
   mode, incidenceAngle, focal, objectDist, converging, rotationAngle,
+  parabolic = false, showSource = true, onRotationComplete,
   isRunning, isPaused, onTick, width = 660, height = 320,
 }: Props) {
   const canvasRef = useRef<HTMLCanvasElement | null>(null);
   const rafRef = useRef<number>(0);
   const lastFrameRef = useRef<number | null>(null);
   const t = useRef(0);
-  const sim = useRef({ mode, incidenceAngle, focal, objectDist, converging, rotationAngle, isRunning, isPaused, onTick });
-  sim.current = { mode, incidenceAngle, focal, objectDist, converging, rotationAngle, isRunning, isPaused, onTick };
+  const sim = useRef({ mode, incidenceAngle, focal, objectDist, converging, rotationAngle, isRunning, isPaused, onTick, parabolic, showSource, onRotationComplete });
+  sim.current = { mode, incidenceAngle, focal, objectDist, converging, rotationAngle, isRunning, isPaused, onTick, parabolic, showSource, onRotationComplete };
 
   useEffect(() => { t.current = 0; lastFrameRef.current = null; }, [mode, incidenceAngle, focal, objectDist, converging, rotationAngle]);
 
@@ -97,11 +98,13 @@
     const animate = s.mode === 'rotation' && s.isRunning && !s.isPaused;
     if (animate && timestamp !== undefined) {
       if (lastFrameRef.current !== null) {
-        t.current += Math.min((timestamp - lastFrameRef.current) / 1000, 0.1);
+        const next = Math.min(ROTATION_SECONDS, t.current + Math.min((timestamp - lastFrameRef.current) / 1000, 0.1));
+        if (t.current < ROTATION_SECONDS && next === ROTATION_SECONDS) s.onRotationComplete?.();
+        t.current = next;
       }
       lastFrameRef.current = timestamp;
     } else {
-      lastFrameRef.current = timestamp ?? null;
+      lastFrameRef.current = null;
     }
 
     ctx.clearRect(0, 0, W, H);
@@ -191,6 +194,9 @@
       // the rays that terminate exactly at their tip/base.
       objectArrow(ctx, objTip.x, objBase.y, objTip.y, '#0f172a', 'O');
       flag(ctx, objTip.x, objTip.y + 8, 1, '#0f172a');
+      if (s.showSource) {
+        ctx.fillStyle = '#f59e0b'; ctx.beginPath(); ctx.arc(objTip.x, objTip.y, 4, 0, Math.PI * 2); ctx.fill();
+      }
       ctx.save(); ctx.globalAlpha = 0.85;
       objectArrow(ctx, imgTip.x, imgBase.y, imgTip.y, '#8b5cf6', 'I (virtual)');
       ctx.restore();
@@ -206,66 +212,102 @@
       const f = s.converging ? s.focal : -s.focal;
       const u = s.objectDist;
       const img = thinLensImage(u, f);
-      const scale = Math.min(3.2, (W / 2 - 30) / Math.max(u, Math.abs(img.atInfinity ? u : img.v), 2 * s.focal));
-      const hObj = 44;
+      const maxDistance = Math.max(u, 2 * s.focal, img.atInfinity ? 0 : Math.abs(img.v));
+      const objectHeight = 12;
+      const maxHeight = objectHeight * Math.max(1, img.atInfinity ? 1 : img.m);
+      const mirrorHalf = Math.min(H * 0.33, W * 0.26);
+      const scale = Math.min((W / 2 - 32) / maxDistance, (H / 2 - 28) / maxHeight, mirrorHalf * 0.82 / objectHeight);
+      const hObj = objectHeight * scale;
+      const parabolaFocus = Math.min(W * 0.26, Math.max(mirrorHalf, s.focal * W / 150));
+      const bow = s.parabolic ? -(mirrorHalf ** 2) / (4 * parabolaFocus) : mirrorHalf * (s.converging ? -0.32 : 0.32);
+      const surfaceX = (dy: number) => cx + bow * (dy / mirrorHalf) ** 2;
+      const curve = (offset: number, color: string, width: number) => {
+        ctx.strokeStyle = color; ctx.lineWidth = width;
+        ctx.beginPath(); ctx.moveTo(cx + bow + offset, axisY - mirrorHalf);
+        ctx.quadraticCurveTo(cx - bow + offset, axisY, cx + bow + offset, axisY + mirrorHalf);
+        ctx.stroke();
+      };
 
       ctx.strokeStyle = '#94a3b8'; ctx.lineWidth = 1;
       ctx.beginPath(); ctx.moveTo(0, axisY); ctx.lineTo(W, axisY); ctx.stroke();
-
-      const mirrorHalf = Math.min(H * 0.34, W * 0.28);
-      const bow = mirrorHalf * (s.converging ? -0.325 : 0.325);
-      ctx.save();
-      ctx.strokeStyle = '#6366f1'; ctx.lineWidth = 4;
-      ctx.beginPath();
-      ctx.moveTo(cx + bow, axisY - mirrorHalf);
-      ctx.quadraticCurveTo(cx - bow, axisY, cx + bow, axisY + mirrorHalf);
-      ctx.stroke();
-      ctx.lineWidth = 1; ctx.strokeStyle = '#c7d2fe';
-      for (let yOff = -mirrorHalf + 10; yOff <= mirrorHalf - 10; yOff += 14) {
-        const tParam = (yOff + mirrorHalf) / (2 * mirrorHalf);
-        const curveX = cx + bow * Math.pow(1 - 2 * tParam, 2);
-        ctx.beginPath();
-        ctx.moveTo(curveX + 3, axisY + yOff);
-        ctx.lineTo(curveX + 12, axisY + yOff - 8);
-        ctx.stroke();
-      }
-      ctx.restore();
-
-      const fPx = s.focal * scale;
-      ctx.fillStyle = '#f59e0b'; ctx.font = '600 14px system-ui'; ctx.textAlign = 'center';
-      ([[-fPx, 'F'], [-2 * fPx, '2F']] as [number, string][]).forEach(([dx, lab]) => {
-        const x = cx + dx;
-        if (x < 10 || x > W - 10) return;
+      curve(5, '#475569', 7);
+      ctx.strokeStyle = '#334155'; ctx.lineWidth = 2;
+      for (let dy = -mirrorHalf + 9; dy < mirrorHalf - 8; dy += 12) {
+        const x = surfaceX(dy);
+        ctx.beginPath(); ctx.moveTo(x + 5, axisY + dy); ctx.lineTo(x + 15, axisY + dy - 6); ctx.stroke();
+      }
+      curve(0, '#818cf8', 3);
+
+      const markFocus = (x: number, label: string) => {
+        ctx.fillStyle = '#92400e'; ctx.font = '600 14px system-ui'; ctx.textAlign = 'center';
         ctx.beginPath(); ctx.arc(x, axisY, 3, 0, Math.PI * 2); ctx.fill();
-        ctx.fillText(lab, x, axisY + 16);
-      });
-
+        ctx.fillText(label, x, axisY + 19);
+      };
+
+      if (s.parabolic) {
+        const focusX = cx - parabolaFocus;
+        for (const fraction of [-0.8, -0.4, 0.4, 0.8]) {
+          const dy = mirrorHalf * fraction;
+          const hitX = surfaceX(dy);
+          arrow(ctx, 24, axisY + dy, hitX, axisY + dy, '#4338ca');
+          arrow(ctx, hitX, axisY + dy, focusX, axisY, '#047857');
+          if (s.showSource) {
+            ctx.fillStyle = '#f59e0b';
+            ctx.beginPath(); ctx.arc(24, axisY + dy, 4, 0, Math.PI * 2); ctx.fill();
+          }
+        }
+        markFocus(focusX, 'F');
+        ctx.fillStyle = '#334155'; ctx.font = '600 15px system-ui'; ctx.textAlign = 'center';
+        ctx.fillText(`Parabolic mirror · Parallel rays meet at F (${s.focal} cm)`, cx, 22, W - 16);
+        rafRef.current = requestAnimationFrame(draw);
+        return;
+      }
+
+      const focusX = cx - f * scale;
+      markFocus(focusX, 'F');
+      if (Math.abs(f * scale) >= 28) markFocus(cx - 2 * f * scale, 'C');
       const objX = cx - u * scale;
-      objectArrow(ctx, objX, axisY, axisY - hObj, '#0f172a', 'O');
-
-      if (!img.atInfinity) {
-        const ix = img.real ? cx - img.v * scale : cx + Math.abs(img.v) * scale;
-        const tipY = img.inverted ? axisY + hObj * img.m : axisY - hObj * img.m;
-        if (ix > -40 && ix < W + 40) {
-          objectArrow(ctx, ix, axisY, tipY, img.real ? '#10b981' : '#8b5cf6', img.real ? 'I (real)' : 'I (virtual)');
+      const objTipY = axisY - hObj;
+      const ix = img.atInfinity ? 0 : cx - img.v * scale;
+      const tipY = axisY + (img.inverted ? 1 : -1) * hObj * img.m;
+
+      // The spherical-mirror construction uses paraxial rays at the vertex plane.
+
+      for (const [hitY, color] of [[objTipY, '#b91c1c'], [axisY, '#1d4ed8']] as const) {
+        arrow(ctx, objX, objTipY, cx, hitY, color, 1.6);
+        if (img.real && !img.atInfinity) {
+          arrow(ctx, cx, hitY, ix, tipY, color, 1.6);
+        } else {
+          const slope = img.atInfinity ? -hObj / (u * scale) : (tipY - hitY) / (ix - cx);
+          const reach = Math.min(cx - 8, (H / 2 - 26) / Math.max(Math.abs(slope), 0.01));
+          arrow(ctx, cx, hitY, cx - reach, hitY - slope * reach, color, 1.6);
+          if (!img.atInfinity) {
+            ctx.save(); ctx.setLineDash([5, 4]); ctx.strokeStyle = color;
+            ctx.beginPath(); ctx.moveTo(cx, hitY); ctx.lineTo(ix, tipY); ctx.stroke(); ctx.restore();
+          }
         }
-        const tip: [number, number] = [objX, axisY - hObj];
-        const drawTo = (fromX: number, fromY: number, toX: number, toY: number, color: string, dashed = false) => {
-          ctx.save(); if (dashed) ctx.setLineDash([5, 4]);
-          ctx.strokeStyle = color; ctx.lineWidth = 1.6;
-          const ang = Math.atan2(toY - fromY, toX - fromX);
-          const ext = 60;
-          ctx.beginPath(); ctx.moveTo(fromX, fromY);
-          ctx.lineTo(toX + Math.cos(ang) * ext, toY + Math.sin(ang) * ext);
-          ctx.stroke(); ctx.restore();
-        };
-        arrow(ctx, tip[0], tip[1], cx, tip[1], '#ef4444', 1.6, 0.5);
-        drawTo(cx, tip[1], ix, tipY, '#ef4444', !img.real);
-        arrow(ctx, tip[0], tip[1], cx, axisY, '#3b82f6', 1.6, 0.5);
-        drawTo(cx, axisY, ix, tipY, '#3b82f6', !img.real);
+      }
+
+      objectArrow(ctx, objX, axisY, objTipY, '#0f172a', 'O');
+      if (s.showSource) {
+        ctx.fillStyle = '#f59e0b'; ctx.beginPath(); ctx.arc(objX, objTipY, 4, 0, Math.PI * 2); ctx.fill();
+      }
+      if (img.atInfinity) {
+        ctx.fillStyle = '#334155'; ctx.font = '600 15px system-ui'; ctx.textAlign = 'center';
+        ctx.fillText('Object at F · Parallel reflected rays · Image at infinity', cx, 22, W - 16);
       } else {
-        ctx.fillStyle = '#334155'; ctx.font = '600 15px system-ui'; ctx.textAlign = 'center';
-        ctx.fillText('Object at F — rays emerge parallel, image at infinity', cx, 26, W - 20);
+        const color = img.real ? '#047857' : '#7c3aed';
+        objectArrow(ctx, ix, axisY, tipY, color, 'I');
+        if (Math.abs(tipY - axisY) < 12) {
+          const insetX = W - 30, insetY = 55;
+          objectArrow(ctx, insetX, insetY, insetY + (img.inverted ? 19 : -19), color, 'I');
+          ctx.fillStyle = color; ctx.textAlign = 'right'; ctx.font = '600 12px system-ui';
+          ctx.fillText('Image detail (enlarged)', insetX - 12, insetY, W / 2 - 48);
+        }
+        if (Math.abs(tipY - axisY) < 12 || hObj < 12) {
+          ctx.fillStyle = '#334155'; ctx.font = '600 14px system-ui'; ctx.textAlign = 'center';
+          ctx.fillText('Diagram zoomed out to fit the object and image', cx, 22, W - 16);
+        }
       }
 
       ctx.fillStyle = '#334155'; ctx.font = '600 14px system-ui'; ctx.textAlign = 'left';
@@ -285,13 +327,7 @@
 
       const d = normalize({ x: P.x - S.x, y: P.y - S.y }); // fixed incident direction
 
-      // Freezes at the current sweep angle while paused (keyed on
-      // isRunning alone) rather than snapping back to the slider's
-      // default value — the same pause bug found and fixed in the
-      // shadows and eclipse simulations.
-      const angleDeg = s.isRunning
-        ? SWEEP_MAX_DEG * Math.sin((2 * Math.PI / SWEEP_PERIOD) * t.current)
-        : s.rotationAngle;
+      const angleDeg = s.rotationAngle * (t.current / ROTATION_SECONDS);
       const angleRad = (angleDeg * Math.PI) / 180;
 
       const mirrorDir: Vec = { x: Math.cos(angleRad), y: Math.sin(angleRad) };
@@ -308,9 +344,9 @@
 
       // Faint reference (0°) mirror position and reflected ray
       const mirrorHalf = Math.min(W * 0.38, H * 0.48);
-      ctx.save(); ctx.setLineDash([4, 4]); ctx.strokeStyle = '#e2e8f0'; ctx.lineWidth = 1.5;
+      ctx.save(); ctx.setLineDash([4, 4]); ctx.strokeStyle = '#64748b'; ctx.lineWidth = 1.5;
       ctx.beginPath(); ctx.moveTo(P.x - mirrorHalf, P.y); ctx.lineTo(P.x + mirrorHalf, P.y); ctx.stroke();
-      ctx.strokeStyle = '#fde68a';
+      ctx.strokeStyle = '#a16207';
       ctx.beginPath(); ctx.moveTo(P.x, P.y); ctx.lineTo(P.x + r0.x * rayLength, P.y + r0.y * rayLength); ctx.stroke();
       ctx.restore();
 
@@ -338,6 +374,27 @@
       // Incident ray (fixed) and current reflected ray
       arrow(ctx, S.x, S.y, P.x, P.y, '#6366f1', 2.5);
       arrow(ctx, P.x, P.y, P.x + r.x * rayLength, P.y + r.y * rayLength, '#10b981', 2.5);
+      if (s.showSource) {
+        ctx.fillStyle = '#b45309'; ctx.beginPath(); ctx.arc(S.x, S.y, 5, 0, Math.PI * 2); ctx.fill();
+        ctx.font = '600 14px system-ui'; ctx.textAlign = 'right';
+        ctx.fillText('Fixed source', S.x - 8, S.y, Math.max(1, S.x - 12));
+      }
+      const normalAngle = Math.atan2(normal.y, normal.x);
+      const incidentAngle = Math.atan2(-d.y, -d.x);
+      const reflectionAngle = Math.atan2(r.y, r.x);
+      const incidenceDeg = Math.acos(Math.max(-1, Math.min(1, -d.x * normal.x - d.y * normal.y))) * 180 / Math.PI;
+      const drawRayAngle = (end: number, color: string, label: string) => {
+        const turn = Math.atan2(Math.sin(end - normalAngle), Math.cos(end - normalAngle));
+        const radius = rayLength * 0.7;
+        ctx.strokeStyle = color; ctx.lineWidth = 2;
+        ctx.beginPath(); ctx.arc(P.x, P.y, radius, normalAngle, normalAngle + turn, turn < 0); ctx.stroke();
+        const middle = normalAngle + turn / 2;
+        ctx.fillStyle = color; ctx.font = '600 13px system-ui'; ctx.textAlign = 'center';
+        ctx.fillText(label, P.x + Math.cos(middle) * (radius + 12), P.y + Math.sin(middle) * (radius + 12));
+      };
+      drawRayAngle(incidentAngle, '#4338ca', 'i');
+      drawRayAngle(reflectionAngle, '#047857', 'r');
+
 
       // Angle arcs: mirror rotation (small, at the mirror) vs reflected-ray
       // rotation (bigger, at the reflected ray) — drawn so the "twice as
@@ -353,7 +410,7 @@
       ctx.fillStyle = '#334155'; ctx.font = '600 15px system-ui'; ctx.textAlign = 'center';
       ctx.fillText(`Mirror θ: ${angleDeg.toFixed(1)}° · Reflected ray 2θ: ${reflectedDeg.toFixed(1)}°`, W / 2, 22, W - 16);
       ctx.fillStyle = '#334155'; ctx.font = '600 14px system-ui'; ctx.textAlign = 'left';
-      ctx.fillText('Light source position is fixed — only the mirror turns', 8, H - 10, W - 20);
+      ctx.fillText(`Fixed incident ray · i = r = ${incidenceDeg.toFixed(1)}° · Dashed: 0° reference and normal`, 8, H - 10, W - 20);
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
echo 'Curved mirrors and single-turn rotation updated.'
