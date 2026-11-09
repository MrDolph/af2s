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
@@ -65,7 +65,7 @@
   ],
   collision: [
     "Momentum is always conserved in collisions (no external forces). Kinetic energy may or may not be conserved.",
-    "Elastic collision: KE conserved (e=1). Inelastic: KE lost (e<1). Perfectly inelastic: objects stick together (e=0).",
+    "Elastic collisions conserve kinetic energy. Inelastic collisions lose kinetic energy. Sticking is the perfectly inelastic case (e=0), which this demo uses.",
     "Impulse = change in momentum = FΔt. Increasing contact time (crumple zones, airbags) reduces peak force.",
     "The impulse-momentum theorem is why cars have airbags — same Δp, longer Δt, smaller F on passenger.",
     "WAEC exam: most collision questions just apply p_before = p_after. Check if KE is asked separately.",
@@ -154,10 +154,9 @@
   const [collU1, setCollU1] = useState(6);
   const [collU2, setCollU2] = useState(0);
   const [collType, setCollType] = useState<CollisionParams['type']>('elastic');
-  const [collE, setCollE] = useState(0.6);
   const collParams: CollisionParams = useMemo(
-    () => ({ m1: collM1, m2: collM2, u1: collU1, u2: collU2, type: collType, e: collE }),
-    [collM1, collM2, collU1, collU2, collType, collE]
+    () => ({ m1: collM1, m2: collM2, u1: collU1, u2: collU2, type: collType }),
+    [collM1, collM2, collU1, collU2, collType]
   );
   const rocketA = rocketAnalytics(rocketMass, exhaustSpeed, massFlowRate);
   const rocketDryMass = rocketMass * (1 - fuelFraction);
@@ -180,7 +179,7 @@
   useEffect(() => {
     if (resetTimer.current) clearTimeout(resetTimer.current);
     resetTimer.current = setTimeout(reset, 100);
-  }, [topic, elevMass, elevState, elevAccel, frictionEnabled, rocketMass, exhaustSpeed, massFlowRate, fuelFraction, wlHeight, collM1, collM2, collU1, collU2, collType, collE, reset]);
+  }, [topic, elevMass, elevState, elevAccel, frictionEnabled, rocketMass, exhaustSpeed, massFlowRate, fuelFraction, wlHeight, collM1, collM2, collU1, collU2, collType, reset]);
 
   // Elevator is a tall, portrait-ish shaft; walking/collision are wide
   // and short — pick the matching base aspect before scaling up.
@@ -212,8 +211,7 @@
     "collM1": setCollM1,
     "collU1": setCollU1,
     "collM2": setCollM2,
-    "collU2": setCollU2,
-    "collE": setCollE }, {  });
+    "collU2": setCollU2 }, {  });
   return (
     <>
       <AppHeader />
@@ -423,21 +421,18 @@
 
                 {topic === 'collision' && (
                   <>
-                    <div className="grid grid-cols-3 gap-1 bg-gray-100 p-1 rounded-xl">
-                      {(['elastic', 'inelastic', 'perfectly-inelastic'] as CollisionParams['type'][]).map(t => (
-                        <button key={t} onClick={() => setCollType(t)}
+                    <div className="grid grid-cols-2 gap-1 bg-gray-100 p-1 rounded-xl">
+                      {(['elastic', 'perfectly-inelastic'] as const).map(t => (
+                        <button key={t} onClick={() => setCollType(t)} aria-pressed={collType === t}
                           className={`py-2 rounded-lg text-[10px] font-medium transition ${
                             collType === t ? 'bg-white text-indigo-700 shadow-sm' : 'text-gray-500'
-                          }`}>{t === 'perfectly-inelastic' ? 'Stick together' : t.charAt(0).toUpperCase() + t.slice(1)}</button>
+                          }`}>{t === 'elastic' ? 'Elastic' : 'Inelastic (sticks)'}</button>
                       ))}
                     </div>
                     <Slider label="Mass 1 (blue)" unit="kg" value={collM1} min={0.5} max={10} step={0.5} set={setCollM1} color="#6366f1" />
                     <Slider label="Velocity 1" unit="m/s" value={collU1} min={-10} max={20} step={0.5} set={setCollU1} color="#6366f1" />
                     <Slider label="Mass 2 (green)" unit="kg" value={collM2} min={0.5} max={10} step={0.5} set={setCollM2} color="#10b981" />
                     <Slider label="Velocity 2" unit="m/s" value={collU2} min={-10} max={10} step={0.5} set={setCollU2} color="#10b981" note="Negative = moving left" />
-                    {collType === 'inelastic' && (
-                      <Slider label="Coefficient of restitution (e)" unit="" value={collE} min={0.01} max={0.99} step={0.01} set={setCollE} color="#f59e0b" note="0 = stick together, 1 = elastic" />
-                    )}
                   </>
                 )}
               </div>
--- a/src/components/simulation/StaticDynamicCanvas.tsx
+++ b/src/components/simulation/StaticDynamicCanvas.tsx
@@ -10,6 +10,8 @@
   onTick?: (v: number, x: number) => void;
   width?: number; height?: number;
 }
+
+const PIXELS_PER_METRE = 44;
 
 function forceArrow(ctx: CanvasRenderingContext2D, x: number, y: number, len: number, dir: 1 | -1, color: string, label: string) {
   if (len < 2) return;
@@ -63,15 +65,10 @@
       lastFrameRef.current = timestamp ?? null;
     }
     if (dt > 0) {
+      x.current += v.current * dt + 0.5 * a * dt * dt;
       v.current += a * dt;
-      x.current += v.current * dt;
-      // Wrap so a genuinely unbalanced / constant-velocity block never
-      // just runs off-screen forever.
-      const wrapRange = 140;
-      if (x.current > wrapRange) x.current = -wrapRange;
-      if (x.current < -wrapRange) x.current = wrapRange;
+      s.onTick?.(v.current, x.current);
     }
-    s.onTick?.(v.current, x.current);
 
     ctx.clearRect(0, 0, W, H);
     ctx.fillStyle = '#f8fafc'; ctx.fillRect(0, 0, W, groundY);
@@ -79,7 +76,17 @@
     ctx.strokeStyle = '#94a3b8'; ctx.lineWidth = 2;
     ctx.beginPath(); ctx.moveTo(0, groundY); ctx.lineTo(W, groundY); ctx.stroke();
 
-    const cx = W / 2 + x.current;
+    // The track marks stay fixed while the block crosses them.
+    ctx.strokeStyle = '#64748b'; ctx.lineWidth = 1;
+    for (let mark = W / 2 % PIXELS_PER_METRE; mark < W; mark += PIXELS_PER_METRE) {
+      ctx.beginPath(); ctx.moveTo(mark, groundY); ctx.lineTo(mark, groundY + 9); ctx.stroke();
+    }
+
+    // Wrap the drawing only. The displacement readout stays continuous.
+    const margin = Math.min(130, W / 4);
+    const span = Math.max(1, W - 2 * margin);
+    const offset = x.current * PIXELS_PER_METRE + span / 2;
+    const cx = margin + ((offset % span + span) % span);
     const bw = 64, bh = 48;
     const by = groundY - bh;
     const midY = by + bh / 2;
@@ -90,24 +97,28 @@
     ctx.fillText(`${s.mass}kg`, cx, midY + 4);
 
     // Force arrows — right-pulling f1 (green), left-pulling f2 (red)
-    forceArrow(ctx, cx + bw / 2, midY, Math.min(s.f1 * 3, 130), 1, '#10b981', `F₁=${s.f1}N`);
-    forceArrow(ctx, cx - bw / 2, midY, Math.min(s.f2 * 3, 130), -1, '#ef4444', `F₂=${s.f2}N`);
+    forceArrow(ctx, cx + bw / 2, midY, Math.min(s.f1 * 3, margin - 36), 1, '#10b981', `F₁=${s.f1}N`);
+    forceArrow(ctx, cx - bw / 2, midY, Math.min(s.f2 * 3, margin - 36), -1, '#ef4444', `F₂=${s.f2}N`);
 
-    ctx.font = 'bold 11px system-ui'; ctx.textAlign = 'center';
+    if (Math.abs(v.current) > 0.01) {
+      forceArrow(ctx, cx, by - 22, Math.min(54, 24 + Math.abs(v.current) * 8), v.current > 0 ? 1 : -1, '#4338ca', 'Velocity');
+    }
+
+    ctx.font = 'bold 14px system-ui'; ctx.textAlign = 'center';
     if (bal.equilibrium) {
       ctx.fillStyle = '#059669';
       ctx.fillText(
         s.scenario === 'static'
-          ? 'ΣF = 0 — STATIC EQUILIBRIUM: at rest, and stays at rest'
-          : `ΣF = 0 — DYNAMIC EQUILIBRIUM: moving at a constant ${INITIAL_V.toFixed(1)} m/s`,
+          ? 'Static equilibrium · at rest'
+          : 'Dynamic equilibrium · constant velocity',
         W / 2, 24,
       );
     } else {
       ctx.fillStyle = '#f59e0b';
       ctx.fillText(`NOT in equilibrium — ΣF = ${bal.netForce.toFixed(1)}N, a = ${a.toFixed(2)} m/s²`, W / 2, 24);
     }
-    ctx.fillStyle = '#64748b'; ctx.font = '10px system-ui'; ctx.textAlign = 'left';
-    ctx.fillText(`v = ${v.current.toFixed(2)} m/s`, 8, H - 10);
+    ctx.fillStyle = '#334155'; ctx.font = '600 12px system-ui'; ctx.textAlign = 'left';
+    ctx.fillText(`v = ${v.current.toFixed(2)} m/s   ·   Δx = ${x.current.toFixed(2)} m`, 8, H - 10);
 
     rafRef.current = requestAnimationFrame(draw);
   }, []);
--- a/src/components/simulation/simulation-stage.css
+++ b/src/components/simulation/simulation-stage.css
@@ -96,3 +96,9 @@
 }
 .af-mechanics-stage[data-expanded="true"] .af-collision-demo { flex: 1; }
 .af-mechanics-stage[data-expanded="true"] .af-collision-track { min-height: 64px; }
+.af-mechanics-stage[data-expanded="true"] [data-stage-role="canvas"] > canvas:only-child {
+ max-height: 100%;
+}
+.af-mechanics-stage[data-expanded="true"] [data-stage-role="canvas"]:has(> canvas:only-child) {
+ grid-template: minmax(0, 1fr) / minmax(0, 1fr);
+}
--- a/src/hooks/useResponsiveCanvasSize.ts
+++ b/src/hooks/useResponsiveCanvasSize.ts
@@ -47,9 +47,15 @@
       const style = getComputedStyle(el);
       const available = el.clientWidth - parseFloat(style.paddingLeft || '0') - parseFloat(style.paddingRight || '0');
       if (!available) return;
-      const w = Math.round(Math.min(available, el.closest('[data-expanded="true"]') ? 1600 : maxWidth));
+      // Direct mechanics canvases redraw to fill the classroom panel.
+      const expanded = el.closest('[data-expanded="true"]');
+      const fillsScene = expanded?.classList.contains('af-mechanics-stage')
+        && el.matches('[data-stage-role="canvas"]:has(> canvas:only-child)');
+      const w = Math.floor(fillsScene ? available : Math.min(available, expanded ? 1600 : maxWidth));
       const effectiveAspect = available < MOBILE_BREAKPOINT ? Math.min(aspect, MOBILE_MAX_ASPECT) : aspect;
-      const h = Math.max(minHeight, Math.round(w / effectiveAspect));
+      const nominalHeight = Math.max(minHeight, Math.round(w / effectiveAspect));
+      const availableHeight = Math.floor(el.clientHeight - parseFloat(style.paddingTop || '0') - parseFloat(style.paddingBottom || '0'));
+      const h = fillsScene && availableHeight >= 120 ? availableHeight : nominalHeight;
       setSize(prev => (prev.width === w && prev.height === h ? prev : { width: w, height: h }));
     };
 
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
echo 'Constant velocity, classroom sizing and collision choices updated.'
