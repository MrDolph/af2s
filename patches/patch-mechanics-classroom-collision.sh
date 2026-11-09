#!/usr/bin/env bash
set -euo pipefail
if [[ ! -f package.json || ! -f src/app/simulations/consequences-of-motion/page.tsx ]]; then
  echo 'Run this patch from the A-Factor project root.' >&2
  exit 1
fi
patch_file=$(mktemp)
trap 'rm -f "$patch_file"' EXIT
cat > "$patch_file" <<'AF_MECHANICS_PATCH'
--- a/src/app/simulations/consequences-of-motion/page.tsx
+++ b/src/app/simulations/consequences-of-motion/page.tsx
@@ -153,18 +153,8 @@
   const [collM2, setCollM2] = useState(2);
   const [collU1, setCollU1] = useState(6);
   const [collU2, setCollU2] = useState(0);
-  const [collType, setCollType] = useState<CollisionParams['type']>('perfectly-inelastic');
+  const [collType, setCollType] = useState<CollisionParams['type']>('elastic');
   const [collE, setCollE] = useState(0.6);
-  const [collResult, setCollResult] = useState<ReturnType<typeof solveCollision> | null>(null);
-
-  // Stable object identity: without this, the instant the collision finishes
-  // (onComplete calling setCollResult/setIsComplete/setIsRunning) the page
-  // re-renders and recreates this object with a new reference. Since
-  // CollisionCanvas's phase-reset effect depends on [params], that new
-  // reference retriggers it at the exact moment impact transitions to
-  // "after" — resetting the whole sequence right when it should be showing
-  // the post-collision result. Same root cause as the earlier Newton's 2nd
-  // law "vibrating block" bug.
   const collParams: CollisionParams = useMemo(
     () => ({ m1: collM1, m2: collM2, u1: collU1, u2: collU2, type: collType, e: collE }),
     [collM1, collM2, collU1, collU2, collType, collE]
@@ -183,7 +173,6 @@
   const reset = useCallback(() => {
     setIsRunning(false); setIsPaused(false);
     setIsComplete(false); setResetKey(k => k + 1);
-    setCollResult(null);
     setLiveRocket({ t: 0, v: 0, burnedOut: false });
     setLiveFall({ t: 0, distance: 0 });
   }, []);
@@ -254,13 +243,12 @@
           {/* Topic tabs — scrollable on mobile */}
           <div className="flex gap-1 bg-gray-100 p-1 rounded-xl overflow-x-auto">
             {(Object.keys(TOPIC_META) as Topic[]).map(t => (
-              <button key={t} onClick={() => { setTopic(t); setOpenEx(null); }}
+              <button key={t} onClick={() => { setTopic(t); setOpenEx(null); }} aria-pressed={topic === t}
                 className={`shrink-0 flex items-center gap-1.5 px-3 py-2 rounded-lg text-xs font-medium transition ${
                   topic === t ? 'bg-white text-indigo-700 shadow-sm' : 'text-gray-500 hover:text-gray-700'
                 }`}>
-                <span>{TOPIC_META[t].icon}</span>
-                <span className="hidden sm:inline">{TOPIC_META[t].title}</span>
-                <span className="sm:hidden">{TOPIC_META[t].icon}</span>
+                <span aria-hidden="true">{TOPIC_META[t].icon}</span>
+                <span>{TOPIC_META[t].title}</span>
               </button>
             ))}
           </div>
@@ -275,7 +263,7 @@
           <div className="grid grid-cols-1 lg:grid-cols-[minmax(0,1fr)_220px] xl:grid-cols-[minmax(0,1fr)_220px_260px] gap-4">
 
             {/* Canvas + controls + params */}
-            <SimulationStage className="space-y-3 min-w-0">
+            <SimulationStage className="af-mechanics-stage space-y-3 min-w-0">
               <div data-stage-role="canvas" ref={canvasBoxRef} className="rounded-2xl border border-gray-200 bg-white p-3 shadow-sm">
 
                 {topic === 'elevator' && (
@@ -304,10 +292,9 @@
                 )}
 
                 {topic === 'collision' && (
-                  <CollisionCanvas key={resetKey} params={collParams}
+                  <CollisionCanvas key={JSON.stringify([resetKey, collParams])} params={collParams}
                     isRunning={isRunning} isPaused={isPaused}
-                    onComplete={r => { setCollResult(r); setIsComplete(true); setIsRunning(false); }}
-                    width={canvasSize.width} height={canvasSize.height} />
+                    onComplete={() => { setIsComplete(true); setIsRunning(false); }} />
                 )}
               </div>
 
@@ -365,11 +352,11 @@
               <div data-stage-role="playback" className="flex flex-wrap items-center justify-between gap-2">
                 <SimulationControls
                   isRunning={isRunning && !isComplete} isPaused={isPaused}
-                  onRun={() => { setIsRunning(true); setIsPaused(false); setIsComplete(false); }}
+                  onRun={() => { if (topic === 'collision' && isComplete) setResetKey(k => k + 1); setIsRunning(true); setIsPaused(false); setIsComplete(false); }}
                   onPause={() => setIsPaused(p => !p)}
                   onReset={reset}
                 />
-                {isComplete && <span className="text-xs font-medium text-emerald-600">✓ Complete — Reset to go again</span>}
+                {isComplete && <span className="text-xs font-medium text-emerald-600">{topic === 'collision' ? '✓ Complete · Run to replay' : '✓ Complete — Reset to go again'}</span>}
                 {topic === 'propulsion' && liveRocket.burnedOut && (
                   <span className="text-xs font-medium text-amber-600">🔥 Engine cutoff — coasting</span>
                 )}
@@ -513,7 +500,8 @@
                     </div>
                   ))}
 
-                  {topic === 'collision' && [
+                  {topic === 'collision' && collU1 <= collU2 && <p className="text-sm text-slate-700">No impact occurs at these velocities.</p>}
+                  {topic === 'collision' && collU1 > collU2 && [
                     { l: 'v₁ after', v: `${collRes.v1.toFixed(2)} m/s`, c: 'text-indigo-600' },
                     { l: 'v₂ after', v: `${collRes.v2.toFixed(2)} m/s`, c: 'text-emerald-600' },
                     { l: 'p before', v: `${collRes.momentumBefore.toFixed(2)} kg·m/s`, c: 'text-gray-600' },
--- a/src/app/simulations/coupled-oscillators/page.tsx
+++ b/src/app/simulations/coupled-oscillators/page.tsx
@@ -273,7 +273,7 @@
           </div>
 
           <div className="grid grid-cols-1 lg:grid-cols-[minmax(0,1fr)_220px] xl:grid-cols-[minmax(0,1fr)_220px_260px] gap-4">
-            <SimulationStage className="space-y-3 min-w-0">
+            <SimulationStage className="af-mechanics-stage space-y-3 min-w-0">
               <div data-stage-role="canvas" ref={canvasBoxRef} className="rounded-2xl border border-gray-200 bg-white p-3 shadow-sm">
                 <CoupledOscillatorsCanvas
                   key={resetKey}
--- a/src/app/simulations/double-pendulum/page.tsx
+++ b/src/app/simulations/double-pendulum/page.tsx
@@ -286,7 +286,7 @@
           </div>
 
           <div className="grid grid-cols-1 lg:grid-cols-[minmax(0,1fr)_220px] xl:grid-cols-[minmax(0,1fr)_220px_260px] gap-4">
-            <SimulationStage className="space-y-3 min-w-0">
+            <SimulationStage className="af-mechanics-stage space-y-3 min-w-0">
               <div data-stage-role="canvas" ref={canvasBoxRef} className="rounded-2xl border border-gray-200 bg-white p-3 shadow-sm">
                 <DoublePendulumCanvas
                   key={resetKey}
--- a/src/app/simulations/elasticity/page.tsx
+++ b/src/app/simulations/elasticity/page.tsx
@@ -193,7 +193,7 @@
           </div>
 
           <div className="grid grid-cols-1 lg:grid-cols-[minmax(0,1fr)_220px] xl:grid-cols-[minmax(0,1fr)_220px_260px] gap-4">
-            <SimulationStage className="space-y-3 min-w-0">
+            <SimulationStage className="af-mechanics-stage space-y-3 min-w-0">
               <div data-stage-role="canvas" ref={canvasBoxRef} className="rounded-2xl border border-gray-200 bg-white p-3 shadow-sm">
                 <ElasticityCanvas key={resetKey} mode={mode}
                   load={mode === 'hooke' ? load : wireLoad} k={k} elasticLimitF={elasticLimitF}
--- a/src/app/simulations/equilibrium-of-forces/page.tsx
+++ b/src/app/simulations/equilibrium-of-forces/page.tsx
@@ -248,7 +248,7 @@
           </div>
 
           <div className="grid grid-cols-1 lg:grid-cols-[minmax(0,1fr)_220px] xl:grid-cols-[minmax(0,1fr)_220px_260px] gap-4">
-            <SimulationStage className="space-y-3 min-w-0">
+            <SimulationStage className="af-mechanics-stage space-y-3 min-w-0">
               <div data-stage-role="canvas" ref={canvasBoxRef} className="rounded-2xl border border-gray-200 bg-white p-3 shadow-sm">
                 {topic === 'static-dynamic' && (
                   <StaticDynamicCanvas key={resetKey} scenario={scenario} f1={sdF1} f2={sdF2} mass={sdMass}
--- a/src/app/simulations/friction/page.tsx
+++ b/src/app/simulations/friction/page.tsx
@@ -204,7 +204,7 @@
           </div>
 
           <div className="grid grid-cols-1 lg:grid-cols-[minmax(0,1fr)_220px] xl:grid-cols-[minmax(0,1fr)_220px_260px] gap-4">
-            <SimulationStage className="space-y-3 min-w-0">
+            <SimulationStage className="af-mechanics-stage space-y-3 min-w-0">
               <div data-stage-role="canvas" ref={canvasBoxRef} className="rounded-2xl border border-gray-200 bg-white p-3 shadow-sm">
                 <FrictionCanvas key={resetKey} mode={mode} mass={mass} applied={applied} angle={angle}
                   appliedIncline={appliedIncline} muS={muS} muK={muK} isRunning={isRunning} isPaused={isPaused} resetKey={resetKey}
--- a/src/app/simulations/newtons-laws/page.tsx
+++ b/src/app/simulations/newtons-laws/page.tsx
@@ -251,7 +251,7 @@
           <div className="grid grid-cols-1 lg:grid-cols-[minmax(0,1fr)_220px] xl:grid-cols-[minmax(0,1fr)_220px_260px] gap-4">
 
             {/* Col 1: Canvas + controls + sliders */}
-            <SimulationStage className="space-y-3 min-w-0">
+            <SimulationStage className="af-mechanics-stage space-y-3 min-w-0">
               <div data-stage-role="canvas" ref={canvasBoxRef} className="rounded-2xl border border-gray-200 bg-white p-3 shadow-sm">
                 {law === '1st' && (
                   <NewtonsFirstCanvas
--- a/src/app/simulations/oscillations/page.tsx
+++ b/src/app/simulations/oscillations/page.tsx
@@ -311,7 +311,7 @@
           <div className="grid grid-cols-1 lg:grid-cols-[minmax(0,1fr)_220px] xl:grid-cols-[minmax(0,1fr)_220px_260px] gap-4">
 
             {/* Canvas + graph + controls + sliders */}
-            <SimulationStage className="space-y-3 min-w-0">
+            <SimulationStage className="af-mechanics-stage space-y-3 min-w-0">
 
               {/* Canvas */}
               <div data-stage-role="canvas" ref={canvasBoxRef} className="rounded-2xl border border-gray-200 bg-white p-3 shadow-sm">
--- a/src/app/simulations/projectile-motion/page.tsx
+++ b/src/app/simulations/projectile-motion/page.tsx
@@ -247,7 +247,7 @@
           </div>
 
           {/* ── MOBILE: stack everything; DESKTOP: 3-col ── */}
-          <SimulationStage className="grid grid-cols-1 lg:grid-cols-[minmax(0,1fr)_220px] xl:grid-cols-[minmax(0,1fr)_220px_260px] gap-4">
+          <SimulationStage className="af-mechanics-stage grid grid-cols-1 lg:grid-cols-[minmax(0,1fr)_220px] xl:grid-cols-[minmax(0,1fr)_220px_260px] gap-4">
 
             {/* Col 1: canvas + controls */}
             <div data-stage-role="canvas" className="space-y-3 min-w-0">
--- a/src/app/simulations/space/page.tsx
+++ b/src/app/simulations/space/page.tsx
@@ -192,7 +192,7 @@
 
           <div className="grid grid-cols-1 gap-4 lg:grid-cols-[minmax(0,1fr)_300px] xl:grid-cols-[minmax(0,1fr)_300px_280px]">
             {/* Canvas + controls */}
-            <SimulationStage className="min-w-0 space-y-3">
+            <SimulationStage className="af-mechanics-stage min-w-0 space-y-3">
               <div data-stage-role="canvas" ref={boxRef} className="overflow-hidden rounded-2xl border border-gray-200 bg-white p-2 shadow-sm">
                 <SpaceCanvas
                   dim={dim} activity={act} width={size.width} height={canvasH}
--- a/src/app/simulations/vectors/page.tsx
+++ b/src/app/simulations/vectors/page.tsx
@@ -239,7 +239,7 @@
           </div>
 
           <div className="grid grid-cols-1 gap-4 lg:grid-cols-[minmax(0,1fr)_320px] xl:grid-cols-[minmax(0,1fr)_320px_280px]">
-            <SimulationStage className="min-w-0 space-y-3">
+            <SimulationStage className="af-mechanics-stage min-w-0 space-y-3">
               <div data-stage-role="canvas" ref={boxRef} className="overflow-hidden rounded-2xl border border-gray-200 bg-white p-2 shadow-sm">
                 <VectorCanvas dim={dim} width={size.width} height={canvasH} scene={scene} snap={snap} view={view} onView={setView} dragAxis={dragAxis} showPlanes={planes} showGrid={grid}
                   readOnly={practicing} onHandle={onHandle}
--- a/src/components/simulation/CollisionCanvas.tsx
+++ b/src/components/simulation/CollisionCanvas.tsx
@@ -1,190 +1,108 @@
 'use client';
-import { useRef, useEffect, useCallback } from 'react';
-import { CollisionParams, solveCollision } from '@/lib/physics/consequences';
 
-interface Props {
-  params: CollisionParams;
-  isRunning: boolean; isPaused: boolean;
-  onComplete?: (result: ReturnType<typeof solveCollision>) => void;
-  width?: number; height?: number;
+import { useEffect, useEffectEvent, useRef, useState } from 'react';
+import { type CollisionParams, solveCollision } from '@/lib/physics/consequences';
+
+const APPROACH = 1.6;
+const CONTACT = 1;
+const DEPARTURE = 1.5;
+const RELEASE = APPROACH + CONTACT;
+const END = RELEASE + DEPARTURE;
+const BLOCK = 72;
+
+function signed(value: number) {
+  return `${value > 0 ? '+' : ''}${Number(value.toFixed(2))}`;
 }
 
-const BW = 64;
-const X1_START = 80;
-const X2_START = 500;
-const IMPACT_FLASH_DURATION = 0.3; // s — bodies stay visually in contact for this long
-// px per (m/s) per second of wall-clock time — tuned to match the pacing of
-// the original frame-based animation (which moved u*0.8px every frame,
-// ~48px/s at 60fps) now that motion is driven by real elapsed time instead.
-const PX_PER_MPS = 48;
-
-type Phase = 'before' | 'impact' | 'after';
-
-export function CollisionCanvas({ params, isRunning, isPaused, onComplete, width = 680, height = 220 }: Props) {
-  const canvasRef = useRef<HTMLCanvasElement | null>(null);
-  const rafRef = useRef<number>(0);
-  const lastFrameRef = useRef<number | null>(null);
-  const t = useRef(0);           // wall-clock time since this run started/reset
-  const tImpact = useRef(0);     // the value of t at the moment of impact
-  const phase = useRef<Phase>('before');
-  const completedRef = useRef(false);
-  const result = useRef(solveCollision(params));
-  const simRef = useRef({ params, isRunning, isPaused, onComplete });
-  simRef.current = { params, isRunning, isPaused, onComplete };
+export function CollisionCanvas({ params, isRunning, isPaused, onComplete }: {
+  params: CollisionParams;
+  isRunning: boolean;
+  isPaused: boolean;
+  onComplete: () => void;
+}) {
+  const [time, setTime] = useState(0);
+  const elapsed = useRef(0);
+  const complete = useEffectEvent(onComplete);
+  const closing = params.u1 > params.u2;
+  const sticks = params.type === 'perfectly-inelastic';
+  const result = solveCollision(params);
+  const end = closing ? END : APPROACH;
 
   useEffect(() => {
-    phase.current = 'before';
-    t.current = 0;
-    tImpact.current = 0;
-    completedRef.current = false;
-    lastFrameRef.current = null;
-    result.current = solveCollision(params);
-  }, [params]);
+    if (!isRunning || isPaused) return;
+    let frame: number;
+    let previous: number | undefined;
+    function advance(now: number) {
+      if (previous !== undefined) elapsed.current = Math.min(end, elapsed.current + Math.min(0.05, (now - previous) / 1000));
+      previous = now;
+      setTime(elapsed.current);
+      if (elapsed.current < end) frame = requestAnimationFrame(advance);
+      else complete();
+    }
+    frame = requestAnimationFrame(advance);
+    return () => cancelAnimationFrame(frame);
+  }, [end, isRunning, isPaused]);
 
-  const draw = useCallback((timestamp?: number) => {
-    const canvas = canvasRef.current; if (!canvas) return;
-    const ctx = canvas.getContext('2d'); if (!ctx) return;
-    const { params: p, isRunning: r, isPaused: pa, onComplete: oc } = simRef.current;
-    const W = 680, H = Math.max(260, canvas.height);
-    const groundY = H - 50;
-
-    // Real wall-clock dt, gated on running/paused exactly like every other
-    // canvas in the app — this also means the impact flash duration and the
-    // moment onComplete fires both correctly freeze while paused, instead of
-    // the old setTimeout (which kept counting down regardless of pause and
-    // was the root of the sequence "skipping ahead" unpredictably).
-    let dt = 0;
-    if (r && !pa && timestamp !== undefined) {
-      if (lastFrameRef.current !== null) {
-        dt = Math.min((timestamp - lastFrameRef.current) / 1000, 0.1);
-        t.current += dt;
-      }
-      lastFrameRef.current = timestamp;
-    } else {
-      lastFrameRef.current = timestamp ?? null;
-    }
-
-    // Position is always a pure function of elapsed time (not an
-    // accumulator), so there's no drift and pausing/resuming is exact.
-    let x1: number, x2: number;
-    if (phase.current === 'before') {
-      x1 = X1_START + p.u1 * PX_PER_MPS * t.current;
-      x2 = X2_START + p.u2 * PX_PER_MPS * t.current;
-      if (dt > 0 && x1 + BW >= x2) {
-        phase.current = 'impact';
-        tImpact.current = t.current;
-        result.current = solveCollision(p);
-        // Clamp to the exact contact point so the flash starts flush against
-        // both bodies rather than with a visible last-frame overlap.
-        x2 = x1 + BW;
-      }
-    } else if (phase.current === 'impact') {
-      x1 = X1_START + p.u1 * PX_PER_MPS * tImpact.current;
-      x2 = x1 + BW; // frozen in contact during the flash
-      if (t.current - tImpact.current >= IMPACT_FLASH_DURATION) {
-        phase.current = 'after';
-        if (!completedRef.current) { completedRef.current = true; oc?.(result.current); }
-      }
-    } else {
-      const tAfter = t.current - tImpact.current - IMPACT_FLASH_DURATION;
-      const xImpact = X1_START + p.u1 * PX_PER_MPS * tImpact.current + BW; // shared contact point
-      x1 = xImpact - BW + result.current.v1 * PX_PER_MPS * tAfter;
-      x2 = xImpact + result.current.v2 * PX_PER_MPS * tAfter;
-    }
-
-    ctx.setTransform(canvas.width / W, 0, 0, canvas.height / H, 0, 0);
-    ctx.clearRect(0, 0, W, H);
-    ctx.fillStyle = '#f8fafc'; ctx.fillRect(0, 0, W, groundY);
-    ctx.fillStyle = '#e2e8f0'; ctx.fillRect(0, groundY, W, H - groundY);
-    ctx.beginPath(); ctx.moveTo(0, groundY); ctx.lineTo(W, groundY);
-    ctx.strokeStyle = '#94a3b8'; ctx.lineWidth = 2; ctx.stroke();
-
-    const by = groundY - 56;
-    const midY = by + 28;
-
-    const worldLeft = Math.min(0, x1 - 80, x2 - 80);
-    const worldRight = Math.max(W, x1 + BW + 80, x2 + BW + 80);
-    const cameraScale = W / (worldRight - worldLeft);
-    x1 = (x1 - worldLeft) * cameraScale;
-    x2 = (x2 - worldLeft) * cameraScale;
-    const blockWidth = BW * cameraScale;
-
-    // Impact flash
-    if (phase.current === 'impact') {
-      ctx.fillStyle = 'rgba(251,191,36,0.35)';
-      ctx.beginPath(); ctx.arc(x1 + blockWidth / 2, midY, 50, 0, Math.PI * 2); ctx.fill();
-      ctx.fillStyle = '#f59e0b'; ctx.font = 'bold 14px system-ui'; ctx.textAlign = 'center';
-      ctx.fillText('IMPACT!', x1 + blockWidth / 2, midY - 55);
-    }
-
-    // Block 1
-    const bg1 = ctx.createLinearGradient(x1, by, x1, by + 56);
-    bg1.addColorStop(0, '#818cf8'); bg1.addColorStop(1, '#4f46e5');
-    ctx.fillStyle = bg1;
-    ctx.beginPath(); ctx.roundRect(x1, by, blockWidth, 56, 6); ctx.fill();
-    ctx.strokeStyle = '#3730a3'; ctx.lineWidth = 1.5;
-    ctx.beginPath(); ctx.roundRect(x1, by, blockWidth, 56, 6); ctx.stroke();
-    ctx.fillStyle = 'white'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
-    ctx.fillText(`${p.m1}kg`, x1 + blockWidth / 2, midY - 6);
-    ctx.font = '9px system-ui';
-    ctx.fillText(phase.current === 'before' ? `u=${p.u1} m/s` : `v=${result.current.v1.toFixed(1)} m/s`, x1 + blockWidth / 2, midY + 10);
-
-    // Block 2
-    const bg2 = ctx.createLinearGradient(x2, by, x2, by + 56);
-    bg2.addColorStop(0, '#34d399'); bg2.addColorStop(1, '#059669');
-    ctx.fillStyle = bg2;
-    ctx.beginPath(); ctx.roundRect(x2, by, blockWidth, 56, 6); ctx.fill();
-    ctx.strokeStyle = '#047857'; ctx.lineWidth = 1.5;
-    ctx.beginPath(); ctx.roundRect(x2, by, blockWidth, 56, 6); ctx.stroke();
-    ctx.fillStyle = 'white'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
-    ctx.fillText(`${p.m2}kg`, x2 + blockWidth / 2, midY - 6);
-    ctx.font = '9px system-ui';
-    ctx.fillText(phase.current === 'before' ? `u=${p.u2} m/s` : `v=${result.current.v2.toFixed(1)} m/s`, x2 + blockWidth / 2, midY + 10);
-
-    // Velocity arrows before impact
-    if (phase.current === 'before') {
-      [{ x: x1, v: p.u1, w: blockWidth }, { x: x2, v: p.u2, w: blockWidth }].forEach(b => {
-        if (Math.abs(b.v) < 0.01) return;
-        const dir = Math.sign(b.v);
-        const ax = dir > 0 ? b.x + b.w : b.x;
-        const arrowLen = Math.min(Math.abs(b.v) * 10, 60);
-        ctx.save();
-        ctx.strokeStyle = '#f59e0b'; ctx.lineWidth = 2;
-        ctx.beginPath(); ctx.moveTo(ax, midY - 30); ctx.lineTo(ax + dir * arrowLen, midY - 30); ctx.stroke();
-        ctx.fillStyle = '#f59e0b';
-        ctx.beginPath(); ctx.moveTo(ax + dir * arrowLen, midY - 30);
-        ctx.lineTo(ax + dir * arrowLen - dir * 8, midY - 35);
-        ctx.lineTo(ax + dir * arrowLen - dir * 8, midY - 25);
-        ctx.closePath(); ctx.fill();
-        ctx.restore();
-      });
-
-      // Warn if the bodies are not actually on a collision course, so the
-      // "before" phase doesn't just run forever with no explanation.
-      if (p.u1 - p.u2 <= 0) {
-        ctx.fillStyle = '#dc2626'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
-        ctx.fillText('Not closing — body 1 is not catching up to body 2 (raise u₁ or lower u₂)', W / 2, 20);
-      }
-    }
-
-    // Type label
-    ctx.fillStyle = '#6366f1'; ctx.font = '10px system-ui'; ctx.textAlign = 'left';
-    ctx.fillText(`${p.type} collision`, 10, 18);
-    if (phase.current === 'after') {
-      ctx.fillStyle = '#10b981';
-      ctx.fillText(`p: ${result.current.momentumBefore.toFixed(1)} → ${result.current.momentumAfter.toFixed(1)} kg·m/s  |  KE lost: ${result.current.keLost.toFixed(1)} J`, 10, H - 12);
-    }
-
-    rafRef.current = requestAnimationFrame(draw);
-  }, []);
-
-  useEffect(() => {
-    rafRef.current = requestAnimationFrame(draw);
-    return () => cancelAnimationFrame(rafRef.current);
-  }, [draw]);
+  const phase = !closing || time < APPROACH ? 0 : time < RELEASE ? 1 : 2;
+  const [u1, u2] = [params.u1, params.u2];
+  // Derive exact velocities for positioning so even a small rebound separates.
+  const e = sticks ? 0 : params.type === 'elastic' ? 1 : params.e ?? 0.5;
+  const centerVelocity = (params.m1 * u1 + params.m2 * u2) / (params.m1 + params.m2);
+  const separation = e * (u1 - u2);
+  const v1 = centerVelocity - separation * params.m2 / (params.m1 + params.m2);
+  const v2 = centerVelocity + separation * params.m1 / (params.m1 + params.m2);
+  const gap = closing ? (u1 - u2) * APPROACH : Math.max(4, Math.abs(u1 - u2));
+  const contact = u1 * APPROACH;
+  const final = closing ? [contact + v1 * DEPARTURE, contact + v2 * DEPARTURE] : [u1 * APPROACH, gap + u2 * APPROACH];
+  const left = Math.min(0, gap, contact, ...final);
+  const right = Math.max(0, gap, contact, ...final);
+  // Fit the entire demonstration once. The track and bodies never zoom during playback.
+  const scale = 310 / Math.max(1, right - left);
+  const offset = (480 - BLOCK * 2 - (right - left) * scale) / 2;
+  const approach = Math.min(time, APPROACH);
+  const depart = Math.max(0, time - RELEASE);
+  const x1 = offset + ((phase === 2 ? contact + v1 * depart : u1 * approach) - left) * scale;
+  const x2 = offset + BLOCK + ((phase === 2 ? contact + v2 * depart : gap + u2 * approach) - left) * scale;
+  const messages = [
+    closing ? 'The gap closes because A’s signed velocity is greater than B’s.' : 'The gap cannot close. Set A’s velocity greater than B’s to see an impact.',
+    'Contact is slowed for illustration. The arrows show the equal and opposite impulses that change the bodies’ momenta.',
+    sticks ? 'The bodies remain joined and move with a common velocity.' : 'The bodies separate. The arrows show their final directions of motion.',
+  ];
+  const arrows = phase === 1 ? [result.impulse, -result.impulse] : phase === 2 ? [v1, v2] : [u1, u2];
 
   return (
-    <canvas ref={canvasRef} width={width} height={height}
-      className="w-full rounded-xl border border-gray-200 bg-white" style={{ display: 'block' }} />
+    <section className="af-collision-demo flex min-w-0 flex-col gap-2 rounded-xl border border-slate-300 bg-white p-2 sm:p-3" aria-label="Collision demonstration">
+      <ol className="grid grid-cols-3 gap-1 text-center text-xs font-semibold sm:text-sm" aria-label="Collision stages">
+        {['Before impact', 'During impact', 'After impact'].map((label, index) => (
+          <li key={label} aria-current={index === phase ? 'step' : undefined}
+            className={`rounded-md border px-1 py-1 ${index === phase ? 'border-indigo-700 bg-indigo-700 text-white' : 'border-slate-200 bg-slate-50 text-slate-700'}`}>
+            {index + 1}. {label}
+          </li>
+        ))}
+      </ol>
+      <div className="af-collision-track flex min-h-0 flex-1 items-center justify-center rounded-lg bg-slate-50">
+        <svg viewBox="0 0 480 128" className="block max-h-full w-full" role="img" aria-label="Body A starts left of body B. Arrows indicate direction.">
+          <path d="M0 112H480" stroke="#64748b" strokeWidth="2" />
+          {phase === 1 && <path d={`M${x2} 38v77`} stroke="#d97706" strokeWidth="10" />}
+          {[x1, x2].map((x, i) => {
+            const color = i === 0 ? '#4338ca' : '#047857';
+            const center = x + BLOCK / 2;
+            const direction = Math.sign(arrows[i]);
+            const tip = center + direction * 26;
+            return <g key={i}>
+              <rect x={x} y="55" width={BLOCK} height="56" rx={phase === 1 || (phase === 2 && sticks) ? 0 : 7} fill={color} />
+              <text x={center} y="92" fill="white" fontSize="25" fontWeight="700" textAnchor="middle">{i === 0 ? 'A' : 'B'}</text>
+              {direction !== 0 && <path d={`M${center - direction * 20} 31H${tip}m${-direction * 9} -7 ${direction * 9} 7 ${-direction * 9} 7`} fill="none" stroke={phase === 1 ? '#b45309' : color} strokeWidth="4" strokeLinejoin="round" />}
+              {direction === 0 && <circle cx={center} cy="31" r="4" fill={color} />}
+            </g>;
+          })}
+        </svg>
+      </div>
+      <div className="grid grid-cols-2 gap-1 text-sm font-semibold tabular-nums">
+        <div className="rounded-md bg-indigo-50 px-2 py-1 text-indigo-900">A · {params.m1} kg<br />{phase === 1 ? `J: ${signed(result.impulse)} N·s` : `${signed(arrows[0])} m/s`}</div>
+        <div className="rounded-md bg-emerald-50 px-2 py-1 text-emerald-900">B · {params.m2} kg<br />{phase === 1 ? `J: ${signed(-result.impulse)} N·s` : `${signed(arrows[1])} m/s`}</div>
+      </div>
+      <p className="text-xs leading-snug text-slate-700 sm:text-sm" aria-live="polite">{messages[phase]} {phase === 2 && `Total momentum: ${result.momentumBefore} → ${result.momentumAfter} kg·m/s. Kinetic energy: ${result.keBefore} → ${result.keAfter} J.`}</p>
+    </section>
   );
 }
--- a/src/components/simulation/ConicalPendulumCanvas.tsx
+++ b/src/components/simulation/ConicalPendulumCanvas.tsx
@@ -73,7 +73,7 @@
     const projectedAngle = Math.atan2(bobY - pivotY, bobX - cx);
     ctx.arc(cx, pivotY, 28, Math.min(Math.PI / 2, projectedAngle), Math.max(Math.PI / 2, projectedAngle));
     ctx.strokeStyle = '#f59e0b'; ctx.lineWidth = 1.5; ctx.stroke();
-    ctx.fillStyle = '#f59e0b'; ctx.font = '10px system-ui'; ctx.textAlign = 'left';
+    ctx.fillStyle = '#92400e'; ctx.font = '600 12px system-ui'; ctx.textAlign = 'left';
     ctx.fillText(`θ=${th}° (true angle)`, cx + 6, pivotY + 38);
 
     // Bob
@@ -92,7 +92,7 @@
     ctx.strokeStyle = '#10b981'; ctx.lineWidth = 2;
     ctx.beginPath(); ctx.moveTo(bobX, bobY);
     ctx.lineTo(bobX + Tx / Tmag * Tscale, bobY + Ty / Tmag * Tscale); ctx.stroke();
-    ctx.fillStyle = '#10b981'; ctx.font = '9px system-ui'; ctx.textAlign = 'center';
+    ctx.fillStyle = '#047857'; ctx.font = '600 12px system-ui'; ctx.textAlign = 'center';
     ctx.fillText(`T=${T.toFixed(1)}N`, bobX + Tx / Tmag * Tscale * 0.6, bobY + Ty / Tmag * Tscale * 0.6 - 6);
     ctx.restore();
 
@@ -106,12 +106,12 @@
     ctx.beginPath(); ctx.moveTo(bobX, bobY + Wscale);
     ctx.lineTo(bobX - 4, bobY + Wscale - 7); ctx.lineTo(bobX + 4, bobY + Wscale - 7);
     ctx.closePath(); ctx.fill();
-    ctx.font = '9px system-ui'; ctx.textAlign = 'left';
+    ctx.fillStyle = '#b91c1c'; ctx.font = '600 12px system-ui'; ctx.textAlign = 'left';
     ctx.fillText(`mg=${W_n.toFixed(1)}N`, bobX + 6, bobY + Wscale / 2);
     ctx.restore();
 
     // Info
-    ctx.fillStyle = '#64748b'; ctx.font = '10px system-ui'; ctx.textAlign = 'center';
+    ctx.fillStyle = '#334155'; ctx.font = '600 12px system-ui'; ctx.textAlign = 'center';
     ctx.fillText(`r=${r_circ.toFixed(2)}m  T_period=${(2*Math.PI/omega).toFixed(2)}s`, cx, H - 8);
 
     rafRef.current = requestAnimationFrame(draw);
--- a/src/components/simulation/NewtonsSecondCanvas.tsx
+++ b/src/components/simulation/NewtonsSecondCanvas.tsx
@@ -106,7 +106,7 @@
       ctx.beginPath(); ctx.moveTo(ax + fLen, midY);
       ctx.lineTo(ax + fLen - 10, midY - 6); ctx.lineTo(ax + fLen - 10, midY + 6);
       ctx.closePath(); ctx.fillStyle = '#10b981'; ctx.fill();
-      ctx.fillStyle = '#10b981'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
+      ctx.fillStyle = '#047857'; ctx.font = 'bold 12px system-ui'; ctx.textAlign = 'center';
       ctx.fillText(`F=${pm.appliedForce}N`, ax + fLen / 2, midY - 10);
       ctx.restore();
     }
@@ -121,14 +121,14 @@
       ctx.beginPath(); ctx.moveTo(ax - fLen, midY + 14);
       ctx.lineTo(ax - fLen + 9, midY + 8); ctx.lineTo(ax - fLen + 9, midY + 20);
       ctx.closePath(); ctx.fillStyle = '#ef4444'; ctx.fill();
-      ctx.fillStyle = '#ef4444'; ctx.font = '10px system-ui'; ctx.textAlign = 'center';
+      ctx.fillStyle = '#b91c1c'; ctx.font = 'bold 12px system-ui'; ctx.textAlign = 'center';
       ctx.fillText(`f=${(pm.friction * pm.mass * 9.81).toFixed(1)}N`, ax - fLen / 2, midY + 30);
       ctx.restore();
     }
 
     // Net force label
     const netF = state.netForce;
-    ctx.fillStyle = '#6366f1'; ctx.font = 'bold 11px monospace'; ctx.textAlign = 'left';
+    ctx.fillStyle = '#3730a3'; ctx.font = 'bold 13px monospace'; ctx.textAlign = 'left';
     ctx.fillText(`F_net=${netF.toFixed(1)}N  a=${state.a.toFixed(2)}m/s²  v=${state.v.toFixed(2)}m/s`, 10, 22);
 
     rafRef.current = requestAnimationFrame(draw);
--- a/src/components/simulation/ProjectileCanvas.tsx
+++ b/src/components/simulation/ProjectileCanvas.tsx
@@ -162,8 +162,8 @@
     ctx.save();
     ctx.strokeStyle = '#e2e8f0';
     ctx.lineWidth = 1;
-    ctx.fillStyle = '#94a3b8';
-    ctx.font = '11px system-ui, sans-serif';
+    ctx.fillStyle = '#475569';
+    ctx.font = '12px system-ui, sans-serif';
     const xStep = Math.ceil(analytics.maxRange / 6 / 5) * 5 || 1;
     ctx.textAlign = 'center';
     for (let x = 0; x <= analytics.maxRange * 1.1; x += xStep) {
@@ -212,7 +212,7 @@
     ctx.moveTo(pCx, pCy); ctx.lineTo(pCx, h - GROUND_HEIGHT);
     ctx.strokeStyle = 'rgba(99,102,241,0.4)'; ctx.lineWidth = 1.5; ctx.stroke();
     ctx.setLineDash([]);
-    ctx.fillStyle = '#6366f1'; ctx.font = 'bold 11px system-ui';
+    ctx.fillStyle = '#4338ca'; ctx.font = 'bold 13px system-ui';
     ctx.textAlign = 'center';
     ctx.fillText(`${analytics.maxHeight.toFixed(1)}m`, pCx, pCy - 10);
     ctx.restore();
@@ -224,7 +224,7 @@
     ctx.save();
     ctx.beginPath(); ctx.arc(lCx, h - GROUND_HEIGHT, 5, 0, Math.PI * 2);
     ctx.fillStyle = '#10b981'; ctx.fill();
-    ctx.fillStyle = '#10b981'; ctx.font = 'bold 11px system-ui';
+    ctx.fillStyle = '#047857'; ctx.font = 'bold 13px system-ui';
     ctx.textAlign = 'center';
     ctx.fillText(`${analytics.maxRange.toFixed(1)}m`, lCx, h - GROUND_HEIGHT + 32);
     ctx.restore();
--- a/src/components/simulation/simulation-stage.css
+++ b/src/components/simulation/simulation-stage.css
@@ -82,3 +82,17 @@
  .af-simulation-stage[data-expanded="true"] .af-stage-parameters > [data-stage-role="parameters"] { padding: .2rem; }
 }
 .af-simulation-stage[data-expanded="true"] .af-stage-parameters :is(.grid,.space-y-3,.space-y-4):has(input) { display: flex; flex-wrap: nowrap; align-items: flex-start; gap: .75rem; }
+
+/* Keep mechanics scenes centered and their HTML labels legible at classroom scale. */
+.af-mechanics-stage[data-expanded="true"] :is(.af-stage-toolbar, [data-stage-role="playback"], .af-stage-parameters) .text-xs { font-size: .875rem; }
+.af-mechanics-stage[data-expanded="true"] .af-stage-parameters [class*="text-[10px]"] { font-size: .8125rem; }
+.af-mechanics-stage[data-expanded="true"] [data-stage-role="canvas"]:has(> canvas:only-child) {
+ display: grid;
+ place-items: center;
+}
+.af-mechanics-stage[data-expanded="true"] [data-stage-role="canvas"]:has(.af-collision-demo) {
+ display: flex;
+ flex-direction: column;
+}
+.af-mechanics-stage[data-expanded="true"] .af-collision-demo { flex: 1; }
+.af-mechanics-stage[data-expanded="true"] .af-collision-track { min-height: 64px; }
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
echo 'Mechanics classroom and Collision & Impact updates installed.'
