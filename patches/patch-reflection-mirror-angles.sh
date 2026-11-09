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
@@ -51,7 +51,7 @@
   })();
   const showControls = sp.get('controls') !== '0';
 
-  const [incidenceAngle, setIncidenceAngle] = useState(() => num(sp, 'angle', 35, 5, 80));
+  const [incidenceAngle, setIncidenceAngle] = useState(() => num(sp, 'angle', 35, 0, 90));
   const [focal, setFocal] = useState(() => num(sp, 'focal', 15, 5, 40));
   const [objectDist, setObjectDist] = useState(() => num(sp, 'u', 40, 5, 90));
   const [converging, setConverging] = useState(() => sp.get('conv') !== '0');
@@ -83,7 +83,7 @@
           <p className="mb-3 text-xs font-medium uppercase tracking-wide text-gray-400">Parameters</p>
           <div className="grid grid-cols-1 gap-x-6 gap-y-3 sm:grid-cols-2">
             {mode === 'plane' && (
-              <Slider label="Angle of incidence" unit="°" value={incidenceAngle} min={5} max={80} step={1} set={setIncidenceAngle} color="#6366f1" />
+              <Slider label="Angle of incidence" unit="°" value={incidenceAngle} min={0} max={90} step={1} set={setIncidenceAngle} color="#6366f1" />
             )}
             {mode === 'curved' && <>
               <Slider label="Focal length |f|" unit="cm" value={focal} min={5} max={40} step={1} set={setFocal} color="#f59e0b" />
--- a/src/app/simulations/reflection/page.tsx
+++ b/src/app/simulations/reflection/page.tsx
@@ -204,7 +204,7 @@
                 <p className="text-xs font-medium text-gray-400 uppercase tracking-wide">Parameters</p>
 
                 {mode === 'plane' && (
-                  <Slider label="Angle of incidence" unit="°" value={incidenceAngle} min={5} max={80} step={1} set={setIncidenceAngle} color="#6366f1"
+                  <Slider label="Angle of incidence" unit="°" value={incidenceAngle} min={0} max={90} step={1} set={setIncidenceAngle} color="#6366f1"
                     note="Measured from the normal, not the mirror surface" />
                 )}
 
--- a/src/components/simulation/ReflectionCanvas.tsx
+++ b/src/components/simulation/ReflectionCanvas.tsx
@@ -108,7 +108,7 @@
 
     if (s.mode === 'plane') {
       const cx = W * 0.52, midY = H / 2;
-      const mirrorTop = 20, mirrorBottom = H - 20;
+      const mirrorTop = H * 0.12, mirrorBottom = H * 0.88;
 
       ctx.strokeStyle = '#334155'; ctx.lineWidth = 3;
       ctx.beginPath(); ctx.moveTo(cx, mirrorTop); ctx.lineTo(cx, mirrorBottom); ctx.stroke();
@@ -122,11 +122,12 @@
       // (not the other way round) so the ray genuinely starts at the
       // object instead of two disconnected diagrams sharing a canvas.
       const P0: Vec = { x: cx, y: midY * 1.05 };
-      const eye: Vec = { x: cx - 200, y: H * 0.2 }; // same side as the object — you can't see a reflection from behind the mirror
-      const th = (s.incidenceAngle * Math.PI) / 180;
-      const rayLen = 130;
+      const eye: Vec = { x: W * 0.12, y: H * 0.24 }; // same side as the object — you can't see a reflection from behind the mirror
+      const incidence = Math.max(0, Math.min(90, s.incidenceAngle));
+      const th = incidence * Math.PI / 180;
+      const rayLen = Math.min(W * 0.34, H * 0.29);
       const objTip: Vec = { x: P0.x - Math.cos(th) * rayLen, y: P0.y - Math.sin(th) * rayLen };
-      const objHeight = 75;
+      const objHeight = H * 0.22;
       const objBase: Vec = { x: objTip.x, y: objTip.y + objHeight };
 
       // Reflection points for the two "what the eye actually sees" rays,
@@ -154,12 +155,20 @@
 
       // Ray A: object tip -> P0 -> reflects at an equal angle (labelled i, r)
       arrow(ctx, objTip.x, objTip.y, P0.x, P0.y, '#6366f1', 2.2);
-      const rA = { x: P0.x - Math.cos(th) * 70, y: P0.y + Math.sin(th) * 70 };
-      arrow(ctx, P0.x, P0.y, rA.x, rA.y, '#a5b4fc', 2.2);
-      ctx.fillStyle = '#4338ca'; ctx.font = '600 14px system-ui'; ctx.textAlign = 'center';
-      ctx.fillText(`i=${s.incidenceAngle}°`, P0.x - 30, P0.y - 10);
-      ctx.fillStyle = '#818cf8';
-      ctx.fillText(`r=${s.incidenceAngle}°`, P0.x - 30, P0.y + 20);
+      const rA = { x: P0.x - Math.cos(th) * rayLen, y: P0.y + Math.sin(th) * rayLen };
+      arrow(ctx, P0.x, P0.y, rA.x, rA.y, '#4338ca', 2.2);
+      const arcRadius = Math.min(rayLen * 0.55, 42);
+      ctx.strokeStyle = '#4338ca'; ctx.lineWidth = 2;
+      ctx.beginPath();
+      ctx.arc(P0.x, P0.y, arcRadius, Math.PI - th, Math.PI + th);
+      ctx.stroke();
+      ctx.fillStyle = '#312e81'; ctx.font = '600 15px system-ui'; ctx.textAlign = 'center';
+      ctx.fillText(incidence === 90 ? '90° · Grazing incidence' : `Incidence ${incidence}° · Reflection ${incidence}°`, W / 2, 18, W - 16);
+      if (incidence === 90) {
+        ctx.fillText('The ray runs along the mirror surface.', W / 2, H - 10, W - 16);
+        rafRef.current = requestAnimationFrame(draw);
+        return;
+      }
 
       // Ray B and C: the actual rays the eye receives, from the top and
       // bottom of the object — solid to the mirror and on to the eye, then
@@ -203,16 +212,17 @@
       ctx.strokeStyle = '#94a3b8'; ctx.lineWidth = 1;
       ctx.beginPath(); ctx.moveTo(0, axisY); ctx.lineTo(W, axisY); ctx.stroke();
 
-      const bow = s.converging ? -26 : 26;
+      const mirrorHalf = Math.min(H * 0.34, W * 0.28);
+      const bow = mirrorHalf * (s.converging ? -0.325 : 0.325);
       ctx.save();
       ctx.strokeStyle = '#6366f1'; ctx.lineWidth = 4;
       ctx.beginPath();
-      ctx.moveTo(cx + bow, axisY - 80);
-      ctx.quadraticCurveTo(cx - bow, axisY, cx + bow, axisY + 80);
+      ctx.moveTo(cx + bow, axisY - mirrorHalf);
+      ctx.quadraticCurveTo(cx - bow, axisY, cx + bow, axisY + mirrorHalf);
       ctx.stroke();
       ctx.lineWidth = 1; ctx.strokeStyle = '#c7d2fe';
-      for (let yOff = -70; yOff <= 70; yOff += 14) {
-        const tParam = (yOff + 80) / 160;
+      for (let yOff = -mirrorHalf + 10; yOff <= mirrorHalf - 10; yOff += 14) {
+        const tParam = (yOff + mirrorHalf) / (2 * mirrorHalf);
         const curveX = cx + bow * Math.pow(1 - 2 * tParam, 2);
         ctx.beginPath();
         ctx.moveTo(curveX + 3, axisY + yOff);
@@ -268,8 +278,10 @@
       // 2θ. Uses genuine vector reflection (not an assumed formula) and then
       // MEASURES the angle between the current and reference reflected rays,
       // so the 2θ relationship is demonstrated, not just asserted.
-      const P: Vec = { x: W * 0.6, y: H * 0.58 };     // fixed point of incidence
-      const S: Vec = { x: P.x - 230, y: P.y - 150 };  // fixed light source
+      const P: Vec = { x: W * 0.5, y: H * 0.55 };     // fixed point of incidence
+      const rayLength = Math.min(W * 0.43, H * 0.36);
+      const sourceOffset = rayLength / Math.SQRT2;
+      const S: Vec = { x: P.x - sourceOffset, y: P.y - sourceOffset };  // fixed light source
 
       const d = normalize({ x: P.x - S.x, y: P.y - S.y }); // fixed incident direction
 
@@ -288,21 +300,22 @@
 
       const r = reflect(d, normal);
       const r0 = reflect(d, normal0);
-      const reflectedDeg = ((Math.atan2(r.y, r.x) - Math.atan2(r0.y, r0.x)) * 180) / Math.PI;
+      const reflectedTurn = Math.atan2(r0.x * r.y - r0.y * r.x, r0.x * r.x + r0.y * r.y);
+      const reflectedDeg = reflectedTurn * 180 / Math.PI;
       s.onTick?.(angleDeg, reflectedDeg);
 
       ctx.fillStyle = '#f8fafc'; ctx.fillRect(0, 0, W, H);
 
       // Faint reference (0°) mirror position and reflected ray
-      const refLen = 100;
+      const mirrorHalf = Math.min(W * 0.38, H * 0.48);
       ctx.save(); ctx.setLineDash([4, 4]); ctx.strokeStyle = '#e2e8f0'; ctx.lineWidth = 1.5;
-      ctx.beginPath(); ctx.moveTo(P.x - refLen, P.y); ctx.lineTo(P.x + refLen, P.y); ctx.stroke();
+      ctx.beginPath(); ctx.moveTo(P.x - mirrorHalf, P.y); ctx.lineTo(P.x + mirrorHalf, P.y); ctx.stroke();
       ctx.strokeStyle = '#fde68a';
-      ctx.beginPath(); ctx.moveTo(P.x, P.y); ctx.lineTo(P.x + r0.x * 190, P.y + r0.y * 190); ctx.stroke();
+      ctx.beginPath(); ctx.moveTo(P.x, P.y); ctx.lineTo(P.x + r0.x * rayLength, P.y + r0.y * rayLength); ctx.stroke();
       ctx.restore();
 
       // Current mirror (solid) with silvered-back hatching
-      const mLen = 100;
+      const mLen = mirrorHalf;
       ctx.strokeStyle = '#334155'; ctx.lineWidth = 4;
       ctx.beginPath();
       ctx.moveTo(P.x - mirrorDir.x * mLen, P.y - mirrorDir.y * mLen);
@@ -319,26 +332,26 @@
 
       // Normal (dashed)
       ctx.save(); ctx.setLineDash([4, 4]); ctx.strokeStyle = '#94a3b8'; ctx.lineWidth = 1;
-      ctx.beginPath(); ctx.moveTo(P.x - normal.x * 60, P.y - normal.y * 60); ctx.lineTo(P.x + normal.x * 60, P.y + normal.y * 60); ctx.stroke();
+      ctx.beginPath(); ctx.moveTo(P.x - normal.x * (rayLength * 0.65), P.y - normal.y * (rayLength * 0.65)); ctx.lineTo(P.x + normal.x * (rayLength * 0.65), P.y + normal.y * (rayLength * 0.65)); ctx.stroke();
       ctx.restore();
 
       // Incident ray (fixed) and current reflected ray
       arrow(ctx, S.x, S.y, P.x, P.y, '#6366f1', 2.5);
-      arrow(ctx, P.x, P.y, P.x + r.x * 190, P.y + r.y * 190, '#10b981', 2.5);
+      arrow(ctx, P.x, P.y, P.x + r.x * rayLength, P.y + r.y * rayLength, '#10b981', 2.5);
 
       // Angle arcs: mirror rotation (small, at the mirror) vs reflected-ray
       // rotation (bigger, at the reflected ray) — drawn so the "twice as
       // wide" relationship is visible at a glance, not just in the numbers.
-      const arcR1 = 34;
+      const arcR1 = rayLength * 0.28;
       ctx.strokeStyle = '#f59e0b'; ctx.lineWidth = 2;
-      ctx.beginPath(); ctx.arc(P.x, P.y, arcR1, -Math.PI / 2, -Math.PI / 2 + angleRad, angleRad < 0); ctx.stroke();
-      const arcR2 = 60;
-      const a0 = Math.atan2(r0.y, r0.x), a1 = Math.atan2(r.y, r.x);
+      ctx.beginPath(); ctx.arc(P.x, P.y, arcR1, 0, angleRad, angleRad < 0); ctx.stroke();
+      const arcR2 = rayLength * 0.5;
+      const a0 = Math.atan2(r0.y, r0.x);
       ctx.strokeStyle = '#ef4444'; ctx.lineWidth = 2;
-      ctx.beginPath(); ctx.arc(P.x, P.y, arcR2, a0, a1, a1 < a0); ctx.stroke();
+      ctx.beginPath(); ctx.arc(P.x, P.y, arcR2, a0, a0 + reflectedTurn, reflectedTurn < 0); ctx.stroke();
 
       ctx.fillStyle = '#334155'; ctx.font = '600 15px system-ui'; ctx.textAlign = 'center';
-      ctx.fillText(`Mirror rotated ${angleDeg.toFixed(1)}°  →  reflected ray rotated ${reflectedDeg.toFixed(1)}°  (≈ 2× the mirror's rotation)`, W / 2, 22, W - 16);
+      ctx.fillText(`Mirror θ: ${angleDeg.toFixed(1)}° · Reflected ray 2θ: ${reflectedDeg.toFixed(1)}°`, W / 2, 22, W - 16);
       ctx.fillStyle = '#334155'; ctx.font = '600 14px system-ui'; ctx.textAlign = 'left';
       ctx.fillText('Light source position is fixed — only the mirror turns', 8, H - 10, W - 20);
     }
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
echo 'Reflection mirror geometry and angles updated.'
