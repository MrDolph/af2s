#!/usr/bin/env bash
set -euo pipefail
if [[ ! -f package.json || ! -f src/app/simulations/consequences-of-motion/page.tsx ]]; then
  echo 'Run this patch from the A-Factor project root.' >&2
  exit 1
fi
patch_file=$(mktemp)
trap 'rm -f "$patch_file"' EXIT
cat > "$patch_file" <<'AF_MECHANICS_PATCH'
--- a/src/app/simulations/diffraction/page.tsx
+++ b/src/app/simulations/diffraction/page.tsx
@@ -168,7 +168,7 @@
           </div>
 
           <div className="grid grid-cols-1 lg:grid-cols-[minmax(0,1fr)_220px] xl:grid-cols-[minmax(0,1fr)_220px_260px] gap-4">
-            <SimulationStage className="space-y-3 min-w-0">
+            <SimulationStage className="af-optics-stage space-y-3 min-w-0">
               <div data-stage-role="canvas" ref={canvasBoxRef} className="rounded-2xl border border-gray-200 bg-white p-3 shadow-sm">
                 <DiffractionCanvas key={resetKey} mode={mode} wavelengthNm={wavelengthNm} slitWidthNm={slitWidthNm} slitSpacingNm={slitSpacingNm}
                   doubleSlitSepNm={doubleSlitSepNm}
--- a/src/app/simulations/polarization/page.tsx
+++ b/src/app/simulations/polarization/page.tsx
@@ -168,7 +168,7 @@
           </div>
 
           <div className="grid grid-cols-1 lg:grid-cols-[minmax(0,1fr)_220px] xl:grid-cols-[minmax(0,1fr)_220px_260px] gap-4">
-            <SimulationStage className="space-y-3 min-w-0">
+            <SimulationStage className="af-optics-stage space-y-3 min-w-0">
               <div data-stage-role="canvas" ref={canvasBoxRef} className="rounded-2xl border border-gray-200 bg-white p-3 shadow-sm">
                 <PolarizationCanvas key={resetKey} mode={mode} polarizerAngle={polarizerAngle} analyzerAngle={analyzerAngle}
                   isRunning={isRunning} isPaused={isPaused}
--- a/src/app/simulations/rectilinear-propagation/page.tsx
+++ b/src/app/simulations/rectilinear-propagation/page.tsx
@@ -186,7 +186,7 @@
           </div>
 
           <div className="grid grid-cols-1 lg:grid-cols-[minmax(0,1fr)_220px] xl:grid-cols-[minmax(0,1fr)_220px_260px] gap-4">
-            <SimulationStage className="space-y-3 min-w-0">
+            <SimulationStage className="af-optics-stage space-y-3 min-w-0">
               <div data-stage-role="canvas" ref={canvasBoxRef} className="rounded-2xl border border-gray-200 bg-white p-3 shadow-sm">
                 {topic === 'shadows' && (
                   <ShadowsCanvas key={resetKey} sourceType={sourceType} sourceRadiusPx={sourceRadius} objectRadiusPx={objectRadius}
--- a/src/app/simulations/reflection/page.tsx
+++ b/src/app/simulations/reflection/page.tsx
@@ -176,7 +176,7 @@
           </div>
 
           <div className="grid grid-cols-1 lg:grid-cols-[minmax(0,1fr)_220px] xl:grid-cols-[minmax(0,1fr)_220px_260px] gap-4">
-            <SimulationStage className="space-y-3 min-w-0">
+            <SimulationStage className="af-optics-stage space-y-3 min-w-0">
               <div data-stage-role="canvas" ref={canvasBoxRef} className="rounded-2xl border border-gray-200 bg-white p-3 shadow-sm">
                 <ReflectionCanvas key={resetKey} mode={mode} incidenceAngle={incidenceAngle}
                   focal={focal} objectDist={objectDist} converging={converging}
--- a/src/app/simulations/refraction/page.tsx
+++ b/src/app/simulations/refraction/page.tsx
@@ -154,7 +154,7 @@
           </div>
 
           <div className="grid grid-cols-1 lg:grid-cols-[minmax(0,1fr)_220px] xl:grid-cols-[minmax(0,1fr)_220px_260px] gap-4">
-            <SimulationStage className="space-y-3 min-w-0">
+            <SimulationStage className="af-optics-stage space-y-3 min-w-0">
               <div data-stage-role="canvas" ref={canvasBoxRef} className="rounded-2xl border border-gray-200 bg-white p-3 shadow-sm">
                 <OpticsCanvas mode={mode} n1={n1} n2={n2} theta1={theta1}
                   focal={focal} objectDist={objectDist} converging={converging}
--- a/src/components/simulation/DiffractionCanvas.tsx
+++ b/src/components/simulation/DiffractionCanvas.tsx
@@ -105,13 +105,13 @@
       });
       ctx.setLineDash([]);
 
-      ctx.fillStyle = '#e2e8f0'; ctx.font = 'bold 11px system-ui'; ctx.textAlign = 'center';
+      ctx.fillStyle = '#e2e8f0'; ctx.font = '600 15px system-ui'; ctx.textAlign = 'center';
       ctx.fillText(
         spread >= 0.99 ? 'Slit narrower than the wavelength — waves spread through almost a full half-circle' : `Diffraction half-angle ≈ ${(maxSpreadAngle * 180 / Math.PI).toFixed(0)}°`,
-        W / 2, 22,
+        W / 2, 22, W - 16,
       );
-      ctx.fillStyle = '#94a3b8'; ctx.font = '10px system-ui'; ctx.textAlign = 'left';
-      ctx.fillText(`λ/a = ${(s.wavelengthNm / s.slitWidthNm).toFixed(2)} — bigger ratio (narrower slit, or longer wavelength) means more spreading`, 8, H - 10);
+      ctx.fillStyle = '#94a3b8'; ctx.font = '600 14px system-ui'; ctx.textAlign = 'left';
+      ctx.fillText(`λ/a = ${(s.wavelengthNm / s.slitWidthNm).toFixed(2)} — bigger ratio (narrower slit, or longer wavelength) means more spreading`, 8, H - 10, W - 20);
       rafRef.current = requestAnimationFrame(draw);
       return;
     } else if (s.mode === 'grating') {
@@ -163,14 +163,14 @@
         ctx.beginPath(); ctx.arc(screenX, targetY, n === 0 ? 5 : 4, 0, Math.PI * 2);
         ctx.fillStyle = n === 0 ? '#ffffff' : hue;
         ctx.fill();
-        ctx.fillStyle = '#cbd5e1'; ctx.font = '9px system-ui'; ctx.textAlign = 'left';
+        ctx.fillStyle = '#cbd5e1'; ctx.font = '600 13px system-ui'; ctx.textAlign = 'left';
         ctx.fillText(`n=${n}`, screenX + 10, targetY + 3);
       });
 
-      ctx.fillStyle = '#e2e8f0'; ctx.font = 'bold 11px system-ui'; ctx.textAlign = 'center';
-      ctx.fillText(`d sinθ = nλ — up to order n = ±${maxOrder} visible at this spacing/wavelength`, W / 2, 22);
-      ctx.fillStyle = '#94a3b8'; ctx.font = '10px system-ui'; ctx.textAlign = 'left';
-      ctx.fillText(`λ=${s.wavelengthNm}nm  d=${s.slitSpacingNm}nm`, 8, H - 10);
+      ctx.fillStyle = '#e2e8f0'; ctx.font = '600 15px system-ui'; ctx.textAlign = 'center';
+      ctx.fillText(`d sinθ = nλ — up to order n = ±${maxOrder} visible at this spacing/wavelength`, W / 2, 22, W - 16);
+      ctx.fillStyle = '#94a3b8'; ctx.font = '600 14px system-ui'; ctx.textAlign = 'left';
+      ctx.fillText(`λ=${s.wavelengthNm}nm  d=${s.slitSpacingNm}nm`, 8, H - 10, W - 20);
     } else {
       // ── Young's double-slit interference ────────────────────────────────
       const gapX = W * 0.32;
@@ -259,10 +259,10 @@
         ctx.beginPath(); ctx.arc(screenX, y, n === 0 ? 4 : 3, 0, Math.PI * 2); ctx.fill();
       }
 
-      ctx.fillStyle = '#e2e8f0'; ctx.font = 'bold 11px system-ui'; ctx.textAlign = 'center';
-      ctx.fillText('Bright fringes where the path difference from the two slits is a whole number of wavelengths', W / 2, 22);
-      ctx.fillStyle = '#94a3b8'; ctx.font = '10px system-ui'; ctx.textAlign = 'left';
-      ctx.fillText(`fringe spacing Δy = λD/d (near the centre) — ${visibleFringes} bright fringes visible on this screen`, 8, H - 10);
+      ctx.fillStyle = '#e2e8f0'; ctx.font = '600 15px system-ui'; ctx.textAlign = 'center';
+      ctx.fillText('Bright fringes: path difference = nλ', W / 2, 22, W - 16);
+      ctx.fillStyle = '#94a3b8'; ctx.font = '600 14px system-ui'; ctx.textAlign = 'left';
+      ctx.fillText(`fringe spacing Δy = λD/d (near the centre) — ${visibleFringes} bright fringes visible on this screen`, 8, H - 10, W - 20);
     }
 
     rafRef.current = requestAnimationFrame(draw);
--- a/src/components/simulation/EclipseCanvas.tsx
+++ b/src/components/simulation/EclipseCanvas.tsx
@@ -88,7 +88,7 @@
     // Sun
     ctx.fillStyle = '#fbbf24';
     ctx.beginPath(); ctx.arc(sunX, midY, sunR, 0, Math.PI * 2); ctx.fill();
-    ctx.fillStyle = '#fde68a'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
+    ctx.fillStyle = '#fde68a'; ctx.font = '600 14px system-ui'; ctx.textAlign = 'center';
     ctx.fillText('Sun', sunX, midY + sunR + 16);
 
     // The Moon's actual orbital path around Earth — a real, clearly
@@ -149,13 +149,13 @@
     // Earth
     ctx.fillStyle = '#3b82f6';
     ctx.beginPath(); ctx.arc(earthX, midY, earthR, 0, Math.PI * 2); ctx.fill();
-    ctx.fillStyle = '#bfdbfe'; ctx.font = 'bold 10px system-ui';
+    ctx.fillStyle = '#bfdbfe'; ctx.font = '600 14px system-ui';
     ctx.fillText('Earth', earthX, midY - earthR - 8);
 
     // Moon
     ctx.fillStyle = '#cbd5e1';
     ctx.beginPath(); ctx.arc(moonX, moonY, moonR, 0, Math.PI * 2); ctx.fill();
-    ctx.fillStyle = '#e2e8f0'; ctx.font = '9px system-ui';
+    ctx.fillStyle = '#e2e8f0'; ctx.font = '600 13px system-ui';
     ctx.fillText('Moon', moonX, moonY - moonR - 6);
 
     let eclipseState: 'none' | 'partial' | 'total' = 'none';
@@ -220,7 +220,7 @@
     ctx.fillStyle = 'rgba(15,23,42,0.9)';
     ctx.beginPath(); ctx.roundRect(insetX - insetR - 10, insetY - insetR - 18, insetR * 2 + 20, insetR * 2 + 30, 8); ctx.fill();
     ctx.strokeStyle = 'rgba(148,163,184,0.4)'; ctx.stroke();
-    ctx.fillStyle = '#94a3b8'; ctx.font = 'bold 9px system-ui'; ctx.textAlign = 'center';
+    ctx.fillStyle = '#94a3b8'; ctx.font = '600 13px system-ui'; ctx.textAlign = 'center';
     ctx.fillText('View from Earth', insetX, insetY - insetR - 6);
     if (isSunSide) {
       ctx.fillStyle = '#fbbf24';
@@ -251,7 +251,7 @@
     }
     ctx.restore();
 
-    ctx.font = 'bold 11px system-ui'; ctx.textAlign = 'center';
+    ctx.font = '600 15px system-ui'; ctx.textAlign = 'center';
     ctx.fillStyle = eclipseState === 'total' ? '#f87171' : eclipseState === 'partial' ? '#fbbf24' : '#94a3b8';
     const bodyLabel = isSunSide ? 'Earth' : 'the Moon';
     const eclipseLabel = eclipseState === 'total'
@@ -261,9 +261,9 @@
       : eclipseState === 'partial'
       ? `PARTIAL ECLIPSE — only part of ${bodyLabel} is in shadow`
       : 'No eclipse right now — the Moon is not at a node';
-    ctx.fillText(eclipseLabel, W / 2 - 40, 22);
-    ctx.fillStyle = '#64748b'; ctx.font = '9px system-ui'; ctx.textAlign = 'left';
-    ctx.fillText('Not to scale. Dashed ellipse = the Moon\u2019s real orbit around Earth; the dots are its two nodes.', 8, H - 8);
+    ctx.fillText(eclipseLabel, W / 2 - 40, 22, W - 20);
+    ctx.fillStyle = '#64748b'; ctx.font = '600 13px system-ui'; ctx.textAlign = 'left';
+    ctx.fillText('Not to scale · Dashed: lunar orbit · Dots: nodes', 8, H - 8, W - 20);
 
     rafRef.current = requestAnimationFrame(draw);
   }, []);
--- a/src/components/simulation/OpticsCanvas.tsx
+++ b/src/components/simulation/OpticsCanvas.tsx
@@ -39,7 +39,7 @@
   ctx.beginPath(); ctx.moveTo(x, yTip);
   ctx.lineTo(x - 6, yTip - dir * 10); ctx.lineTo(x + 6, yTip - dir * 10);
   ctx.closePath(); ctx.fill();
-  ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
+  ctx.font = '600 14px system-ui'; ctx.textAlign = 'center';
   ctx.fillText(label, x, yTip - dir * 16);
   ctx.restore();
 }
@@ -66,18 +66,18 @@
       // Normal
       ctx.setLineDash([5, 5]); ctx.strokeStyle = '#94a3b8'; ctx.lineWidth = 1;
       ctx.beginPath(); ctx.moveTo(cx, 20); ctx.lineTo(cx, H - 20); ctx.stroke(); ctx.setLineDash([]);
-      ctx.fillStyle = '#475569'; ctx.font = 'bold 11px system-ui'; ctx.textAlign = 'left';
-      ctx.fillText(`n₁ = ${s.n1}`, 12, 22);
+      ctx.fillStyle = '#475569'; ctx.font = '600 15px system-ui'; ctx.textAlign = 'left';
+      ctx.fillText(`n₁ = ${s.n1}`, 12, 22, W - 20);
       ctx.fillText(`n₂ = ${s.n2}`, 12, H - 12);
-      ctx.fillStyle = '#94a3b8'; ctx.font = '9px system-ui';
-      ctx.fillText('normal', cx + 6, 26);
+      ctx.fillStyle = '#334155'; ctx.font = '600 13px system-ui';
+      ctx.fillText('normal', cx + 6, 26, W - 20);
 
       const t1 = s.theta1 * Math.PI / 180;
       const rayLen = Math.min(cx, midY) - 30;
       // Incident ray (arrives at the boundary point)
       const ix = cx - Math.sin(t1) * rayLen, iy = midY - Math.cos(t1) * rayLen;
       arrow(ctx, ix, iy, cx, midY, '#6366f1', 2.5);
-      ctx.fillStyle = '#4338ca'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
+      ctx.fillStyle = '#4338ca'; ctx.font = '600 14px system-ui'; ctx.textAlign = 'center';
       ctx.fillText(`θ₁=${s.theta1}°`, cx - 44, midY - 22);
 
       const t2deg = snellTheta2(s.n1, s.n2, s.theta1);
@@ -85,7 +85,7 @@
         // Total internal reflection: all light reflects at θ1
         const rx = cx + Math.sin(t1) * rayLen, ry = midY - Math.cos(t1) * rayLen;
         arrow(ctx, cx, midY, rx, ry, '#ef4444', 2.5);
-        ctx.fillStyle = '#ef4444'; ctx.font = 'bold 11px system-ui'; ctx.textAlign = 'center';
+        ctx.fillStyle = '#ef4444'; ctx.font = '600 15px system-ui'; ctx.textAlign = 'center';
         const cc = criticalAngle(s.n1, s.n2);
         ctx.fillText(`TOTAL INTERNAL REFLECTION  (θ₁ > θc = ${cc?.toFixed(1)}°)`, cx, H - 30);
       } else {
@@ -93,7 +93,7 @@
         // Refracted ray
         const fx = cx + Math.sin(t2) * rayLen, fy = midY + Math.cos(t2) * rayLen;
         arrow(ctx, cx, midY, fx, fy, '#10b981', 2.5);
-        ctx.fillStyle = '#059669'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
+        ctx.fillStyle = '#059669'; ctx.font = '600 14px system-ui'; ctx.textAlign = 'center';
         ctx.fillText(`θ₂=${t2deg.toFixed(1)}°`, cx + 48, midY + 30);
         // Partial (weak) reflection
         const rx = cx + Math.sin(t1) * rayLen * 0.6, ry = midY - Math.cos(t1) * rayLen * 0.6;
@@ -135,7 +135,7 @@
     // Focal points — a lens has two physical focal points, since light can
     // enter from either side.
     const fPx = s.focal * scale;
-    ctx.fillStyle = '#f59e0b'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
+    ctx.fillStyle = '#f59e0b'; ctx.font = '600 14px system-ui'; ctx.textAlign = 'center';
     ([[-fPx, 'F'], [fPx, 'F'], [-2 * fPx, '2F'], [2 * fPx, '2F']] as [number, string][]).forEach(([dx, lab]) => {
       const x = cx + dx;
       if (x < 10 || x > W - 10) return;
@@ -177,15 +177,15 @@
       drawTo(cx, axisY, ix, tipY, '#3b82f6', !img.real);
       ctx.restore();
     } else {
-      ctx.fillStyle = '#64748b'; ctx.font = 'bold 11px system-ui'; ctx.textAlign = 'center';
-      ctx.fillText('Object at F — rays emerge parallel, image at infinity', cx, 26);
+      ctx.fillStyle = '#334155'; ctx.font = '600 15px system-ui'; ctx.textAlign = 'center';
+      ctx.fillText('Object at F — rays emerge parallel, image at infinity', cx, 26, W - 20);
     }
 
     // Caption
-    ctx.fillStyle = '#64748b'; ctx.font = '10px system-ui'; ctx.textAlign = 'left';
+    ctx.fillStyle = '#334155'; ctx.font = '600 14px system-ui'; ctx.textAlign = 'left';
     const nature = img.atInfinity ? 'at infinity'
       : `${img.real ? 'real' : 'virtual'}, ${img.inverted ? 'inverted' : 'upright'}, ${img.m > 1 ? 'magnified' : img.m < 1 ? 'diminished' : 'same size'}`;
-    ctx.fillText(`u=${u}cm  f=${f}cm  →  v=${img.atInfinity ? '∞' : Math.abs(img.v).toFixed(1) + 'cm'}  m=${img.atInfinity ? '∞' : img.m.toFixed(2)}  (${nature})`, 8, H - 8);
+    ctx.fillText(`u=${u}cm  f=${f}cm  →  v=${img.atInfinity ? '∞' : Math.abs(img.v).toFixed(1) + 'cm'}  m=${img.atInfinity ? '∞' : img.m.toFixed(2)}  (${nature})`, 8, H - 8, W - 20);
   }, []);
 
   useEffect(() => { draw(); });
--- a/src/components/simulation/PinholeCanvas.tsx
+++ b/src/components/simulation/PinholeCanvas.tsx
@@ -53,7 +53,7 @@
 
     // Object
     arrowUp(ctx, objX, objBase, objTip, '#0f172a');
-    ctx.fillStyle = '#0f172a'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
+    ctx.fillStyle = '#0f172a'; ctx.font = '600 14px system-ui'; ctx.textAlign = 'center';
     ctx.fillText('O', objX, objTip - 10);
 
     // Rays from the top and bottom of the object, through the pinhole
@@ -98,19 +98,19 @@
     }
     ctx.restore();
     arrowUp(ctx, scrX + 14, imgBaseY, imgTipY, '#7c3aed');
-    ctx.fillStyle = '#7c3aed'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
-    ctx.fillText('I (inverted, real)', scrX + 14, Math.max(imgTipY, imgBaseY) + 16);
+    ctx.fillStyle = '#7c3aed'; ctx.font = '600 14px system-ui'; ctx.textAlign = 'center';
+    ctx.fillText('I · real image', Math.min(scrX + 14, W - 54), Math.min(H - 27, Math.max(imgTipY, imgBaseY) + 18));
 
-    ctx.fillStyle = '#64748b'; ctx.font = '10px system-ui'; ctx.textAlign = 'center';
+    ctx.fillStyle = '#334155'; ctx.font = '600 14px system-ui'; ctx.textAlign = 'center';
     ctx.fillText(
       s.pinholeRadiusPx < 1.5
-        ? 'A single ray per object point crosses at the pinhole — sharp, inverted, real image'
-        : 'A larger hole lets a BUNDLE of rays through each point — overlapping projections blur the image',
-      W / 2, H - 6,
+        ? 'Small pinhole → sharp, inverted image'
+        : 'Larger pinhole → overlapping rays blur the image',
+      W / 2, H - 8, W - 16,
     );
 
-    ctx.fillStyle = '#94a3b8'; ctx.font = '9px system-ui'; ctx.textAlign = 'left';
-    ctx.fillText('pinhole', pinX - 20, 10);
+    ctx.fillStyle = '#334155'; ctx.font = '600 13px system-ui'; ctx.textAlign = 'left';
+    ctx.fillText('pinhole', pinX - 20, 16);
   }, []);
 
   useEffect(() => { draw(); });
--- a/src/components/simulation/PolarizationCanvas.tsx
+++ b/src/components/simulation/PolarizationCanvas.tsx
@@ -32,7 +32,7 @@
   for (let y = midY - halfH + 6; y <= midY + halfH - 6; y += 10) {
     ctx.beginPath(); ctx.moveTo(x - dx, y - dy); ctx.lineTo(x + dx, y + dy); ctx.stroke();
   }
-  ctx.fillStyle = '#475569'; ctx.font = 'bold 9px system-ui'; ctx.textAlign = 'center';
+  ctx.fillStyle = '#475569'; ctx.font = '600 13px system-ui'; ctx.textAlign = 'center';
   ctx.fillText(label, x, midY + halfH + 16);
   ctx.restore();
 }
@@ -91,10 +91,10 @@
         vibrationTick(ctx, x, midY, s.polarizerAngle, 16 * wobble, '#10b981');
       }
 
-      ctx.fillStyle = '#334155'; ctx.font = 'bold 11px system-ui'; ctx.textAlign = 'center';
-      ctx.fillText('Unpolarized (all directions) → plane-polarized (one direction only)', W / 2, 24);
-      ctx.fillStyle = '#64748b'; ctx.font = '10px system-ui'; ctx.textAlign = 'left';
-      ctx.fillText(`Transmission axis at ${s.polarizerAngle}° from vertical`, 8, H - 10);
+      ctx.fillStyle = '#334155'; ctx.font = '600 15px system-ui'; ctx.textAlign = 'center';
+      ctx.fillText('Unpolarized → plane-polarized', W / 2, 24, W - 16);
+      ctx.fillStyle = '#334155'; ctx.font = '600 14px system-ui'; ctx.textAlign = 'left';
+      ctx.fillText(`Transmission axis at ${s.polarizerAngle}° from vertical`, 8, H - 10, W - 20);
       rafRef.current = requestAnimationFrame(draw);
       return;
     }
@@ -121,13 +121,13 @@
       vibrationTick(ctx, x, midY, s.analyzerAngle, 15 * wobble * ampScale, `rgba(16,185,129,${0.3 + I * 0.7})`);
     }
 
-    ctx.fillStyle = '#334155'; ctx.font = 'bold 11px system-ui'; ctx.textAlign = 'center';
+    ctx.fillStyle = '#334155'; ctx.font = '600 15px system-ui'; ctx.textAlign = 'center';
     ctx.fillText(
       s.analyzerAngle > 85 && s.analyzerAngle < 95 ? 'Crossed polarizers — no light gets through' : `Malus's law: I = I₀cos²θ = ${(I * 100).toFixed(0)}% of I₀`,
-      W / 2, 24,
+      W / 2, 24, W - 16,
     );
-    ctx.fillStyle = '#64748b'; ctx.font = '10px system-ui'; ctx.textAlign = 'left';
-    ctx.fillText(`θ = ${s.analyzerAngle}° between the two transmission axes`, 8, H - 10);
+    ctx.fillStyle = '#334155'; ctx.font = '600 14px system-ui'; ctx.textAlign = 'left';
+    ctx.fillText(`θ = ${s.analyzerAngle}° between the two transmission axes`, 8, H - 10, W - 20);
 
     rafRef.current = requestAnimationFrame(draw);
   }, []);
--- a/src/components/simulation/ReflectionCanvas.tsx
+++ b/src/components/simulation/ReflectionCanvas.tsx
@@ -43,7 +43,7 @@
   ctx.beginPath(); ctx.moveTo(x, yTip);
   ctx.lineTo(x - 6, yTip - dir * 10); ctx.lineTo(x + 6, yTip - dir * 10);
   ctx.closePath(); ctx.fill();
-  ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
+  ctx.font = '600 14px system-ui'; ctx.textAlign = 'center';
   ctx.fillText(label, x, yTip - dir * 16);
   ctx.restore();
 }
@@ -149,14 +149,14 @@
       ctx.setLineDash([5, 5]); ctx.strokeStyle = '#94a3b8'; ctx.lineWidth = 1;
       ctx.beginPath(); ctx.moveTo(P0.x - 60, P0.y); ctx.lineTo(P0.x + 60, P0.y); ctx.stroke();
       ctx.setLineDash([]);
-      ctx.fillStyle = '#94a3b8'; ctx.font = '9px system-ui'; ctx.textAlign = 'left';
+      ctx.fillStyle = '#334155'; ctx.font = '600 13px system-ui'; ctx.textAlign = 'left';
       ctx.fillText('normal', P0.x + 62, P0.y + 3);
 
       // Ray A: object tip -> P0 -> reflects at an equal angle (labelled i, r)
       arrow(ctx, objTip.x, objTip.y, P0.x, P0.y, '#6366f1', 2.2);
       const rA = { x: P0.x - Math.cos(th) * 70, y: P0.y + Math.sin(th) * 70 };
       arrow(ctx, P0.x, P0.y, rA.x, rA.y, '#a5b4fc', 2.2);
-      ctx.fillStyle = '#4338ca'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
+      ctx.fillStyle = '#4338ca'; ctx.font = '600 14px system-ui'; ctx.textAlign = 'center';
       ctx.fillText(`i=${s.incidenceAngle}°`, P0.x - 30, P0.y - 10);
       ctx.fillStyle = '#818cf8';
       ctx.fillText(`r=${s.incidenceAngle}°`, P0.x - 30, P0.y + 20);
@@ -190,8 +190,8 @@
       ctx.fillStyle = '#a78bfa'; ctx.font = '16px system-ui'; ctx.textAlign = 'center';
       ctx.fillText('👁', eye.x, eye.y + 5);
 
-      ctx.fillStyle = '#64748b'; ctx.font = '10px system-ui'; ctx.textAlign = 'left';
-      ctx.fillText('Solid: real light rays reaching the eye. Dashed: traced backward — they meet exactly at the image, laterally inverted.', 8, H - 10);
+      ctx.fillStyle = '#334155'; ctx.font = '600 14px system-ui'; ctx.textAlign = 'left';
+      ctx.fillText('Solid: reflected rays · Dashed: virtual image rays', 8, H - 10, W - 20);
     } else if (s.mode === 'curved') {
       const axisY = H / 2, cx = W / 2;
       const f = s.converging ? s.focal : -s.focal;
@@ -222,7 +222,7 @@
       ctx.restore();
 
       const fPx = s.focal * scale;
-      ctx.fillStyle = '#f59e0b'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
+      ctx.fillStyle = '#f59e0b'; ctx.font = '600 14px system-ui'; ctx.textAlign = 'center';
       ([[-fPx, 'F'], [-2 * fPx, '2F']] as [number, string][]).forEach(([dx, lab]) => {
         const x = cx + dx;
         if (x < 10 || x > W - 10) return;
@@ -254,14 +254,14 @@
         arrow(ctx, tip[0], tip[1], cx, axisY, '#3b82f6', 1.6, 0.5);
         drawTo(cx, axisY, ix, tipY, '#3b82f6', !img.real);
       } else {
-        ctx.fillStyle = '#64748b'; ctx.font = 'bold 11px system-ui'; ctx.textAlign = 'center';
-        ctx.fillText('Object at F — rays emerge parallel, image at infinity', cx, 26);
-      }
-
-      ctx.fillStyle = '#64748b'; ctx.font = '10px system-ui'; ctx.textAlign = 'left';
+        ctx.fillStyle = '#334155'; ctx.font = '600 15px system-ui'; ctx.textAlign = 'center';
+        ctx.fillText('Object at F — rays emerge parallel, image at infinity', cx, 26, W - 20);
+      }
+
+      ctx.fillStyle = '#334155'; ctx.font = '600 14px system-ui'; ctx.textAlign = 'left';
       const nature = img.atInfinity ? 'at infinity'
         : `${img.real ? 'real' : 'virtual'}, ${img.inverted ? 'inverted' : 'upright'}, ${img.m > 1 ? 'magnified' : img.m < 1 ? 'diminished' : 'same size'}`;
-      ctx.fillText(`u=${u}cm  f=${f}cm  →  v=${img.atInfinity ? '∞' : Math.abs(img.v).toFixed(1) + 'cm'}  m=${img.atInfinity ? '∞' : img.m.toFixed(2)}  (${nature})`, 8, H - 8);
+      ctx.fillText(`u=${u}cm  f=${f}cm  →  v=${img.atInfinity ? '∞' : Math.abs(img.v).toFixed(1) + 'cm'}  m=${img.atInfinity ? '∞' : img.m.toFixed(2)}  (${nature})`, 8, H - 8, W - 20);
     } else {
       // ── Rotation of a mirror: incident ray fixed, mirror rotates ──────────
       // Classic result: rotate the mirror by θ, the reflected ray rotates by
@@ -337,10 +337,10 @@
       ctx.strokeStyle = '#ef4444'; ctx.lineWidth = 2;
       ctx.beginPath(); ctx.arc(P.x, P.y, arcR2, a0, a1, a1 < a0); ctx.stroke();
 
-      ctx.fillStyle = '#334155'; ctx.font = 'bold 11px system-ui'; ctx.textAlign = 'center';
-      ctx.fillText(`Mirror rotated ${angleDeg.toFixed(1)}°  →  reflected ray rotated ${reflectedDeg.toFixed(1)}°  (≈ 2× the mirror's rotation)`, W / 2, 22);
-      ctx.fillStyle = '#64748b'; ctx.font = '10px system-ui'; ctx.textAlign = 'left';
-      ctx.fillText('Light source position is fixed — only the mirror turns', 8, H - 10);
+      ctx.fillStyle = '#334155'; ctx.font = '600 15px system-ui'; ctx.textAlign = 'center';
+      ctx.fillText(`Mirror rotated ${angleDeg.toFixed(1)}°  →  reflected ray rotated ${reflectedDeg.toFixed(1)}°  (≈ 2× the mirror's rotation)`, W / 2, 22, W - 16);
+      ctx.fillStyle = '#334155'; ctx.font = '600 14px system-ui'; ctx.textAlign = 'left';
+      ctx.fillText('Light source position is fixed — only the mirror turns', 8, H - 10, W - 20);
     }
 
     rafRef.current = requestAnimationFrame(draw);
--- a/src/components/simulation/ShadowsCanvas.tsx
+++ b/src/components/simulation/ShadowsCanvas.tsx
@@ -136,36 +136,36 @@
     } else {
       ctx.beginPath(); ctx.ellipse(srcX, midY, 6, rs, 0, 0, Math.PI * 2); ctx.fill();
     }
-    ctx.fillStyle = '#fcd34d'; ctx.font = '10px system-ui'; ctx.textAlign = 'center';
+    ctx.fillStyle = '#fcd34d'; ctx.font = '600 14px system-ui'; ctx.textAlign = 'center';
     ctx.fillText(s.sourceType === 'point' ? 'point source' : 'extended source', srcX, midY - rs - 12);
 
     // Opaque object
     ctx.fillStyle = '#475569';
     ctx.beginPath(); ctx.ellipse(objX, midY, 10, ro, 0, 0, Math.PI * 2); ctx.fill();
-    ctx.fillStyle = '#94a3b8'; ctx.font = '10px system-ui';
+    ctx.fillStyle = '#94a3b8'; ctx.font = '600 14px system-ui';
     ctx.fillText('opaque object', objX, midY - ro - 10);
 
-    ctx.fillStyle = '#cbd5e1'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'left';
+    ctx.fillStyle = '#cbd5e1'; ctx.font = '600 14px system-ui'; ctx.textAlign = 'left';
     ctx.fillText('screen', scrX - 40, screenTop - 6);
 
     // Labels
-    ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'left';
+    ctx.font = '600 14px system-ui'; ctx.textAlign = 'left';
     if (Math.abs(umbraBotY - umbraTopY) > 14) {
       ctx.fillStyle = '#e2e8f0';
-      ctx.fillText('umbra', scrX + 10, (umbraTopY + umbraBotY) / 2 + 3);
+      ctx.fillText('umbra', Math.min(scrX + 10, W - 82), (umbraTopY + umbraBotY) / 2 + 3);
     }
     if (s.sourceType === 'extended' && Math.abs(penTopY - umbraTopY) > 10) {
-      ctx.fillStyle = '#64748b';
-      ctx.fillText('penumbra', scrX + 10, (penTopY + umbraTopY) / 2 + 3);
-      ctx.fillText('penumbra', scrX + 10, (penBotY + umbraBotY) / 2 + 3);
+      ctx.fillStyle = '#cbd5e1';
+      ctx.fillText('penumbra', Math.min(scrX + 10, W - 82), (penTopY + umbraTopY) / 2 + 3);
+      ctx.fillText('penumbra', Math.min(scrX + 10, W - 82), (penBotY + umbraBotY) / 2 + 3);
     }
 
-    ctx.fillStyle = '#94a3b8'; ctx.font = '10px system-ui'; ctx.textAlign = 'center';
+    ctx.fillStyle = '#94a3b8'; ctx.font = '600 14px system-ui'; ctx.textAlign = 'center';
     ctx.fillText(
       s.sourceType === 'point'
-        ? 'Point source → a single sharp-edged shadow (umbra only, no penumbra)'
-        : 'Extended source → umbra (no light at all) surrounded by penumbra (partly lit, some of the source is visible from there)',
-      W / 2, H - 6,
+        ? 'Point source → sharp umbra'
+        : 'Extended source → umbra + penumbra',
+      W / 2, H - 8, W - 16,
     );
 
     rafRef.current = requestAnimationFrame(draw);
--- a/src/components/simulation/simulation-stage.css
+++ b/src/components/simulation/simulation-stage.css
@@ -83,10 +83,10 @@
 }
 .af-simulation-stage[data-expanded="true"] .af-stage-parameters :is(.grid,.space-y-3,.space-y-4):has(input) { display: flex; flex-wrap: nowrap; align-items: flex-start; gap: .75rem; }
 
-/* Keep mechanics scenes centered and their HTML labels legible at classroom scale. */
-.af-mechanics-stage[data-expanded="true"] :is(.af-stage-toolbar, [data-stage-role="playback"], .af-stage-parameters) .text-xs { font-size: .875rem; }
-.af-mechanics-stage[data-expanded="true"] .af-stage-parameters [class*="text-[10px]"] { font-size: .8125rem; }
-.af-mechanics-stage[data-expanded="true"] [data-stage-role="canvas"]:has(> canvas:only-child) {
+/* Keep mechanics and optics scenes centered and their HTML labels legible at classroom scale. */
+:is(.af-mechanics-stage, .af-optics-stage)[data-expanded="true"] :is(.af-stage-toolbar, [data-stage-role="playback"], .af-stage-parameters) .text-xs { font-size: .875rem; }
+:is(.af-mechanics-stage, .af-optics-stage)[data-expanded="true"] .af-stage-parameters [class*="text-[10px]"] { font-size: .8125rem; }
+:is(.af-mechanics-stage, .af-optics-stage)[data-expanded="true"] [data-stage-role="canvas"]:has(> canvas:only-child) {
  display: grid;
  place-items: center;
 }
@@ -96,9 +96,9 @@
 }
 .af-mechanics-stage[data-expanded="true"] .af-collision-demo { flex: 1; }
 .af-mechanics-stage[data-expanded="true"] .af-collision-track { min-height: 64px; }
-.af-mechanics-stage[data-expanded="true"] [data-stage-role="canvas"] > canvas:only-child {
+:is(.af-mechanics-stage, .af-optics-stage)[data-expanded="true"] [data-stage-role="canvas"] > canvas:only-child {
  max-height: 100%;
 }
-.af-mechanics-stage[data-expanded="true"] [data-stage-role="canvas"]:has(> canvas:only-child) {
+:is(.af-mechanics-stage, .af-optics-stage)[data-expanded="true"] [data-stage-role="canvas"]:has(> canvas:only-child) {
  grid-template: minmax(0, 1fr) / minmax(0, 1fr);
 }
--- a/src/hooks/useResponsiveCanvasSize.ts
+++ b/src/hooks/useResponsiveCanvasSize.ts
@@ -47,9 +47,9 @@
       const style = getComputedStyle(el);
       const available = el.clientWidth - parseFloat(style.paddingLeft || '0') - parseFloat(style.paddingRight || '0');
       if (!available) return;
-      // Direct mechanics canvases redraw to fill the classroom panel.
+      // Direct mechanics and optics canvases redraw to fill the classroom panel.
       const expanded = el.closest('[data-expanded="true"]');
-      const fillsScene = expanded?.classList.contains('af-mechanics-stage')
+      const fillsScene = expanded?.matches('.af-mechanics-stage, .af-optics-stage')
         && el.matches('[data-stage-role="canvas"]:has(> canvas:only-child)');
       const w = Math.floor(fillsScene ? available : Math.min(available, expanded ? 1600 : maxWidth));
       const effectiveAspect = available < MOBILE_BREAKPOINT ? Math.min(aspect, MOBILE_MAX_ASPECT) : aspect;
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
echo 'Optics canvases and labels updated.'
