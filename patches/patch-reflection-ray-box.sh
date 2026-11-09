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
@@ -5,7 +5,7 @@
 
 import { Suspense, useState, useCallback, useEffect, useRef } from 'react';
 import { useSearchParams } from 'next/navigation';
-import { ReflectionCanvas, ReflectionMode } from '@/components/simulation/ReflectionCanvas';
+import { ReflectionCanvas, ReflectionMode, type ReflectionSource } from '@/components/simulation/ReflectionCanvas';
 import { SimulationControls } from '@/components/simulation/SimulationControls';
 
 function num(sp: URLSearchParams, key: string, fallback: number, min: number, max: number) {
@@ -56,7 +56,7 @@
   const [objectDist, setObjectDist] = useState(() => num(sp, 'u', 40, 5, 90));
   const [converging, setConverging] = useState(() => sp.get('conv') !== '0');
   const [parabolic, setParabolic] = useState(() => sp.get('shape') === 'parabolic');
-  const [showSource, setShowSource] = useState(() => sp.get('source') !== '0');
+  const [source, setSource] = useState<ReflectionSource>(() => sp.get('source') === '0' ? 'hidden' : sp.get('source') === 'ray-box' ? 'ray-box' : 'point');
   const [rotationDone, setRotationDone] = useState(false);
   const [rotationAngle, setRotationAngle] = useState(() => num(sp, 'angle', 15, -35, 35));
 
@@ -74,7 +74,7 @@
     <SimulationStage containerRef={embedBoxRef} className="af-embed-stage mx-auto max-w-4xl space-y-3 p-3 sm:p-4">
       <div data-stage-role="canvas"><ReflectionCanvas key={resetKey} mode={mode} incidenceAngle={incidenceAngle}
         focal={focal} objectDist={objectDist} converging={converging}
-        parabolic={parabolic} showSource={showSource}
+        parabolic={parabolic} source={source}
                   onRotationComplete={() => { setRotationDone(true); setIsRunning(false); }}
                   rotationAngle={rotationAngle} isRunning={isRunning} isPaused={isPaused}
         width={Math.max(160, embedSize.width - 24)} height={Math.round((Math.max(160, embedSize.width - 24)) / (embedSize.width < 600 ? Math.min(2.0625, 1.6) : 2.0625))} /></div>
@@ -88,8 +88,13 @@
           <p className="mb-3 text-xs font-medium uppercase tracking-wide text-gray-400">Parameters</p>
           <div className="grid grid-cols-1 gap-x-6 gap-y-3 sm:grid-cols-2">
             <label className="flex items-center gap-2 text-sm text-slate-700">
-                  <input type="checkbox" checked={showSource} onChange={event => setShowSource(event.target.checked)} />
-                  Show light source
+                  Light source
+                  <select value={source} onChange={event => setSource(event.target.value as ReflectionSource)}
+                    className="rounded-md border border-slate-300 bg-white px-2 py-1">
+                    <option value="point">Point source</option>
+                    <option value="ray-box">Ray box</option>
+                    <option value="hidden">Hidden</option>
+                  </select>
                 </label>
                 {mode === 'plane' && (
               <Slider label="Angle of incidence" unit="°" value={incidenceAngle} min={0} max={90} step={1} set={setIncidenceAngle} color="#6366f1" />
--- a/src/app/simulations/reflection/page.tsx
+++ b/src/app/simulations/reflection/page.tsx
@@ -6,7 +6,7 @@
 import { useState, useCallback, useEffect, useRef } from 'react';
 import { AppHeader } from '@/components/layout/AppHeader';
 import { SimulationControls } from '@/components/simulation/SimulationControls';
-import { ReflectionCanvas, ReflectionMode } from '@/components/simulation/ReflectionCanvas';
+import { ReflectionCanvas, ReflectionMode, type ReflectionSource } from '@/components/simulation/ReflectionCanvas';
 import { EmbedButton } from '@/components/ui/EmbedButton';
 import { thinLensImage } from '@/lib/physics/optics';
 import { useResponsiveCanvasSize } from '@/hooks/useResponsiveCanvasSize';
@@ -104,7 +104,7 @@
   const [converging, setConverging] = useState(true);
 
   const [parabolic, setParabolic] = useState(false);
-  const [showSource, setShowSource] = useState(true);
+  const [source, setSource] = useState<ReflectionSource>('point');
   const [rotationDone, setRotationDone] = useState(false);
   const [rotationAngle, setRotationAngle] = useState(15);
   const [isRunning, setIsRunning] = useState(false);
@@ -183,7 +183,7 @@
               <div data-stage-role="canvas" ref={canvasBoxRef} className="rounded-2xl border border-gray-200 bg-white p-3 shadow-sm">
                 <ReflectionCanvas key={resetKey} mode={mode} incidenceAngle={incidenceAngle}
                   focal={focal} objectDist={objectDist} converging={converging}
-                  parabolic={parabolic} showSource={showSource}
+                  parabolic={parabolic} source={source}
                   onRotationComplete={() => { setRotationDone(true); setIsRunning(false); }}
                   rotationAngle={rotationAngle} isRunning={isRunning} isPaused={isPaused}
                   onTick={handleRotationTick}
@@ -199,9 +199,9 @@
                 <EmbedButton path="/embed/reflection"
                   title={`${MODE_META[mode].title} — A-Factor STEM Studio`}
                   params={
-                    mode === 'plane' ? { mode, angle: incidenceAngle, source: showSource ? 1 : 0 }
-                    : mode === 'rotation' ? { mode, angle: rotationAngle, source: showSource ? 1 : 0 }
-                    : { mode, focal, u: objectDist, conv: converging ? 1 : 0, shape: parabolic ? 'parabolic' : 'spherical', source: showSource ? 1 : 0 }
+                    mode === 'plane' ? { mode, angle: incidenceAngle, source: source === 'hidden' ? 0 : source === 'point' ? 1 : source }
+                    : mode === 'rotation' ? { mode, angle: rotationAngle, source: source === 'hidden' ? 0 : source === 'point' ? 1 : source }
+                    : { mode, focal, u: objectDist, conv: converging ? 1 : 0, shape: parabolic ? 'parabolic' : 'spherical', source: source === 'hidden' ? 0 : source === 'point' ? 1 : source }
                   } />
               </div>
 
@@ -209,8 +209,13 @@
                 <p className="text-xs font-medium text-gray-400 uppercase tracking-wide">Parameters</p>
 
                 <label className="flex items-center gap-2 text-sm text-slate-700">
-                  <input type="checkbox" checked={showSource} onChange={event => setShowSource(event.target.checked)} />
-                  Show light source
+                  Light source
+                  <select value={source} onChange={event => setSource(event.target.value as ReflectionSource)}
+                    className="rounded-md border border-slate-300 bg-white px-2 py-1">
+                    <option value="point">Point source</option>
+                    <option value="ray-box">Ray box</option>
+                    <option value="hidden">Hidden</option>
+                  </select>
                 </label>
                 {mode === 'plane' && (
                   <Slider label="Angle of incidence" unit="°" value={incidenceAngle} min={0} max={90} step={1} set={setIncidenceAngle} color="#6366f1"
--- a/src/components/simulation/ReflectionCanvas.tsx
+++ b/src/components/simulation/ReflectionCanvas.tsx
@@ -1,6 +1,8 @@
 'use client';
 import { useRef, useEffect, useCallback } from 'react';
 import { thinLensImage } from '@/lib/physics/optics';
+
+export type ReflectionSource = 'point' | 'ray-box' | 'hidden';
 
 export type ReflectionMode = 'plane' | 'curved' | 'rotation';
 
@@ -13,7 +15,7 @@
   objectDist: number;     // u in cm
   converging: boolean;    // true = concave (converging), false = convex (diverging)
   parabolic?: boolean;
-  showSource?: boolean;
+  source?: ReflectionSource;
   onRotationComplete?: () => void;
   rotationAngle: number;  // target tilt from the 0° reference position
   isRunning: boolean; isPaused: boolean;
@@ -64,6 +66,23 @@
 }
 
 interface Vec { x: number; y: number; }
+function drawSource(ctx: CanvasRenderingContext2D, source: ReflectionSource, x: number, y: number, angle: number, halfHeight = 8) {
+  if (source === 'hidden') return;
+  ctx.save();
+  ctx.translate(x, y);
+  ctx.rotate(angle);
+  ctx.fillStyle = '#f59e0b';
+  if (source === 'point') {
+    ctx.beginPath(); ctx.arc(0, 0, 4, 0, Math.PI * 2); ctx.fill();
+  } else {
+    ctx.fillStyle = '#1e293b';
+    ctx.beginPath(); ctx.roundRect(-22, -halfHeight, 22, halfHeight * 2, 3); ctx.fill();
+    ctx.fillStyle = '#fbbf24';
+    ctx.fillRect(-4, -halfHeight + 2, 4, halfHeight * 2 - 4);
+  }
+  ctx.restore();
+}
+
 function reflect(d: Vec, n: Vec): Vec {
   const dot = d.x * n.x + d.y * n.y;
   return { x: d.x - 2 * dot * n.x, y: d.y - 2 * dot * n.y };
@@ -77,15 +96,15 @@
 
 export function ReflectionCanvas({
   mode, incidenceAngle, focal, objectDist, converging, rotationAngle,
-  parabolic = false, showSource = true, onRotationComplete,
+  parabolic = false, source = 'point', onRotationComplete,
   isRunning, isPaused, onTick, width = 660, height = 320,
 }: Props) {
   const canvasRef = useRef<HTMLCanvasElement | null>(null);
   const rafRef = useRef<number>(0);
   const lastFrameRef = useRef<number | null>(null);
   const t = useRef(0);
-  const sim = useRef({ mode, incidenceAngle, focal, objectDist, converging, rotationAngle, isRunning, isPaused, onTick, parabolic, showSource, onRotationComplete });
-  sim.current = { mode, incidenceAngle, focal, objectDist, converging, rotationAngle, isRunning, isPaused, onTick, parabolic, showSource, onRotationComplete };
+  const sim = useRef({ mode, incidenceAngle, focal, objectDist, converging, rotationAngle, isRunning, isPaused, onTick, parabolic, source, onRotationComplete });
+  sim.current = { mode, incidenceAngle, focal, objectDist, converging, rotationAngle, isRunning, isPaused, onTick, parabolic, source, onRotationComplete };
 
   useEffect(() => { t.current = 0; lastFrameRef.current = null; }, [mode, incidenceAngle, focal, objectDist, converging, rotationAngle]);
 
@@ -167,6 +186,7 @@
       ctx.stroke();
       ctx.fillStyle = '#312e81'; ctx.font = '600 15px system-ui'; ctx.textAlign = 'center';
       ctx.fillText(incidence === 90 ? '90° · Grazing incidence' : `Incidence ${incidence}° · Reflection ${incidence}°`, W / 2, 18, W - 16);
+      drawSource(ctx, s.source, objTip.x, objTip.y, th);
       if (incidence === 90) {
         ctx.fillText('The ray runs along the mirror surface.', W / 2, H - 10, W - 16);
         rafRef.current = requestAnimationFrame(draw);
@@ -194,9 +214,6 @@
       // the rays that terminate exactly at their tip/base.
       objectArrow(ctx, objTip.x, objBase.y, objTip.y, '#0f172a', 'O');
       flag(ctx, objTip.x, objTip.y + 8, 1, '#0f172a');
-      if (s.showSource) {
-        ctx.fillStyle = '#f59e0b'; ctx.beginPath(); ctx.arc(objTip.x, objTip.y, 4, 0, Math.PI * 2); ctx.fill();
-      }
       ctx.save(); ctx.globalAlpha = 0.85;
       objectArrow(ctx, imgTip.x, imgBase.y, imgTip.y, '#8b5cf6', 'I (virtual)');
       ctx.restore();
@@ -246,15 +263,13 @@
 
       if (s.parabolic) {
         const focusX = cx - parabolaFocus;
+        if (s.source === 'ray-box') drawSource(ctx, s.source, 24, axisY, 0, mirrorHalf * 0.8 + 5);
         for (const fraction of [-0.8, -0.4, 0.4, 0.8]) {
           const dy = mirrorHalf * fraction;
           const hitX = surfaceX(dy);
           arrow(ctx, 24, axisY + dy, hitX, axisY + dy, '#4338ca');
           arrow(ctx, hitX, axisY + dy, focusX, axisY, '#047857');
-          if (s.showSource) {
-            ctx.fillStyle = '#f59e0b';
-            ctx.beginPath(); ctx.arc(24, axisY + dy, 4, 0, Math.PI * 2); ctx.fill();
-          }
+          if (s.source === 'point') drawSource(ctx, s.source, 24, axisY + dy, 0);
         }
         markFocus(focusX, 'F');
         ctx.fillStyle = '#334155'; ctx.font = '600 15px system-ui'; ctx.textAlign = 'center';
@@ -290,9 +305,7 @@
       }
 
       objectArrow(ctx, objX, axisY, objTipY, '#0f172a', 'O');
-      if (s.showSource) {
-        ctx.fillStyle = '#f59e0b'; ctx.beginPath(); ctx.arc(objX, objTipY, 4, 0, Math.PI * 2); ctx.fill();
-      }
+      drawSource(ctx, s.source, objX, objTipY, 0);
       if (img.atInfinity) {
         ctx.fillStyle = '#334155'; ctx.font = '600 15px system-ui'; ctx.textAlign = 'center';
         ctx.fillText('Object at F · Parallel reflected rays · Image at infinity', cx, 22, W - 16);
@@ -375,10 +388,11 @@
       // Incident ray (fixed) and current reflected ray
       arrow(ctx, S.x, S.y, P.x, P.y, '#6366f1', 2.5);
       arrow(ctx, P.x, P.y, P.x + r.x * rayLength, P.y + r.y * rayLength, '#10b981', 2.5);
-      if (s.showSource) {
-        ctx.fillStyle = '#b45309'; ctx.beginPath(); ctx.arc(S.x, S.y, 5, 0, Math.PI * 2); ctx.fill();
+      drawSource(ctx, s.source, S.x, S.y, Math.atan2(d.y, d.x));
+      if (s.source !== 'hidden') {
+        ctx.fillStyle = '#92400e';
         ctx.font = '600 14px system-ui'; ctx.textAlign = 'right';
-        ctx.fillText('Fixed source', S.x - 8, S.y, Math.max(1, S.x - 12));
+        ctx.fillText(s.source === 'ray-box' ? 'Fixed ray box' : 'Fixed source', S.x - 23, S.y, Math.max(1, S.x - 27));
       }
       const normalAngle = Math.atan2(normal.y, normal.x);
       const incidentAngle = Math.atan2(-d.y, -d.x);
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
echo 'Reflection ray-box option added.'
