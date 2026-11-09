#!/usr/bin/env bash
set -euo pipefail
if [[ ! -f package.json || ! -f src/app/simulations/reflection/page.tsx ]]; then
  echo 'Run this patch from the A-Factor project root.' >&2
  exit 1
fi
patch_file=$(mktemp)
trap 'rm -f "$patch_file"' EXIT
cat > "$patch_file" <<'AF_MECHANICS_PATCH'
--- a/src/components/simulation/ReflectionCanvas.tsx
+++ b/src/components/simulation/ReflectionCanvas.tsx
@@ -271,19 +271,20 @@
       const ix = img.atInfinity ? 0 : cx - img.v * scale;
       const tipY = axisY + (img.inverted ? 1 : -1) * hObj * img.m;
 
-      // The spherical-mirror construction uses paraxial rays at the vertex plane.
+      // Use the paraxial image solution, with ray joins on the reflecting face.
 
       for (const [hitY, color] of [[objTipY, '#b91c1c'], [axisY, '#1d4ed8']] as const) {
-        arrow(ctx, objX, objTipY, cx, hitY, color, 1.6);
+        const hitX = surfaceX(hitY - axisY);
+        arrow(ctx, objX, objTipY, hitX, hitY, color, 1.6);
         if (img.real && !img.atInfinity) {
-          arrow(ctx, cx, hitY, ix, tipY, color, 1.6);
+          arrow(ctx, hitX, hitY, ix, tipY, color, 1.6);
         } else {
-          const slope = img.atInfinity ? -hObj / (u * scale) : (tipY - hitY) / (ix - cx);
-          const reach = Math.min(cx - 8, (H / 2 - 26) / Math.max(Math.abs(slope), 0.01));
-          arrow(ctx, cx, hitY, cx - reach, hitY - slope * reach, color, 1.6);
+          const slope = img.atInfinity ? -hObj / (u * scale) : (tipY - hitY) / (ix - hitX);
+          const reach = Math.min(hitX - 8, (slope < 0 ? H - 24 - hitY : hitY - 24) / Math.max(Math.abs(slope), 0.01));
+          arrow(ctx, hitX, hitY, hitX - reach, hitY - slope * reach, color, 1.6);
           if (!img.atInfinity) {
             ctx.save(); ctx.setLineDash([5, 4]); ctx.strokeStyle = color;
-            ctx.beginPath(); ctx.moveTo(cx, hitY); ctx.lineTo(ix, tipY); ctx.stroke(); ctx.restore();
+            ctx.beginPath(); ctx.moveTo(hitX, hitY); ctx.lineTo(ix, tipY); ctx.stroke(); ctx.restore();
           }
         }
       }
@@ -320,8 +321,8 @@
       // 2θ. Uses genuine vector reflection (not an assumed formula) and then
       // MEASURES the angle between the current and reference reflected rays,
       // so the 2θ relationship is demonstrated, not just asserted.
-      const P: Vec = { x: W * 0.5, y: H * 0.55 };     // fixed point of incidence
-      const rayLength = Math.min(W * 0.43, H * 0.36);
+      const P: Vec = { x: W * 0.5, y: H * 0.52 };     // fixed point of incidence
+      const rayLength = Math.min(W * 0.39, H * 0.31);
       const sourceOffset = rayLength / Math.SQRT2;
       const S: Vec = { x: P.x - sourceOffset, y: P.y - sourceOffset };  // fixed light source
 
@@ -407,10 +408,19 @@
       ctx.strokeStyle = '#ef4444'; ctx.lineWidth = 2;
       ctx.beginPath(); ctx.arc(P.x, P.y, arcR2, a0, a0 + reflectedTurn, reflectedTurn < 0); ctx.stroke();
 
-      ctx.fillStyle = '#334155'; ctx.font = '600 15px system-ui'; ctx.textAlign = 'center';
-      ctx.fillText(`Mirror θ: ${angleDeg.toFixed(1)}° · Reflected ray 2θ: ${reflectedDeg.toFixed(1)}°`, W / 2, 22, W - 16);
-      ctx.fillStyle = '#334155'; ctx.font = '600 14px system-ui'; ctx.textAlign = 'left';
-      ctx.fillText(`Fixed incident ray · i = r = ${incidenceDeg.toFixed(1)}° · Dashed: 0° reference and normal`, 8, H - 10, W - 20);
+      ctx.fillStyle = '#0f172a'; ctx.beginPath(); ctx.arc(P.x, P.y, 4, 0, Math.PI * 2); ctx.fill();
+      const reflectedEnd = { x: P.x + r.x * rayLength, y: P.y + r.y * rayLength };
+      ctx.fillStyle = '#047857'; ctx.font = '700 14px system-ui'; ctx.textAlign = r.x >= 0 ? 'left' : 'right';
+      ctx.fillText('Reflected', reflectedEnd.x + (r.x >= 0 ? 5 : -5), reflectedEnd.y - 6,
+        Math.max(1, (r.x >= 0 ? W - reflectedEnd.x : reflectedEnd.x) - 10));
+
+      ctx.textAlign = 'center'; ctx.font = '700 16px system-ui'; ctx.fillStyle = '#0f172a';
+      ctx.fillText(`Mirror θ = ${angleDeg.toFixed(1)}°   ·   Ray turn 2θ = ${reflectedDeg.toFixed(1)}°`, W / 2, 20, W - 16);
+      ctx.font = '600 14px system-ui';
+      ctx.fillText(`From the current normal: incidence i = reflection r = ${incidenceDeg.toFixed(1)}°`, W / 2, 39, W - 16);
+      ctx.fillStyle = '#334155';
+      ctx.fillText('Blue: fixed incident ray · Green: current reflected ray', W / 2, H - 27, W - 16);
+      ctx.fillText('Dark solid: current mirror · Dashed: initial mirror, initial ray, current normal', W / 2, H - 9, W - 16);
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
echo 'Reflection surface contacts and rotation readouts updated.'
