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
@@ -145,7 +145,6 @@
       // (not the other way round) so the ray genuinely starts at the
       // object instead of two disconnected diagrams sharing a canvas.
       const P0: Vec = { x: cx, y: midY * 1.05 };
-      const eye: Vec = { x: W * 0.12, y: H * 0.24 }; // same side as the object — you can't see a reflection from behind the mirror
       const incidence = Math.max(0, Math.min(90, s.incidenceAngle));
       const th = incidence * Math.PI / 180;
       const rayLen = Math.min(W * 0.34, H * 0.29);
@@ -153,19 +152,6 @@
       const objHeight = H * 0.22;
       const objBase: Vec = { x: objTip.x, y: objTip.y + objHeight };
 
-      // Reflection points for the two "what the eye actually sees" rays,
-      // found via the mirror-image method: reflect the object point across
-      // the mirror, draw a straight line to the eye, and where that line
-      // crosses the mirror IS the true reflection point — this guarantees
-      // the law of reflection holds and that the backward extension lands
-      // exactly on the image, by construction rather than by coincidence.
-      const findReflectionPoint = (obj: Vec): Vec => {
-        const imgOfObj: Vec = { x: 2 * cx - obj.x, y: obj.y };
-        const tt = (cx - imgOfObj.x) / (eye.x - imgOfObj.x);
-        return { x: cx, y: imgOfObj.y + tt * (eye.y - imgOfObj.y) };
-      };
-      const P1 = findReflectionPoint(objTip);
-      const P2 = findReflectionPoint(objBase);
       const imgTip: Vec = { x: 2 * cx - objTip.x, y: objTip.y };
       const imgBase: Vec = { x: 2 * cx - objBase.x, y: objBase.y };
 
@@ -179,7 +165,7 @@
       // Ray A: object tip -> P0 -> reflects at an equal angle (labelled i, r)
       arrow(ctx, objTip.x, objTip.y, P0.x, P0.y, '#6366f1', 2.2);
       const rA = { x: P0.x - Math.cos(th) * rayLen, y: P0.y + Math.sin(th) * rayLen };
-      arrow(ctx, P0.x, P0.y, rA.x, rA.y, '#4338ca', 2.2);
+      arrow(ctx, P0.x, P0.y, rA.x, rA.y, '#4338ca', 2.2, 0.72);
       const arcRadius = Math.min(rayLen * 0.55, 42);
       ctx.strokeStyle = '#4338ca'; ctx.lineWidth = 2;
       ctx.beginPath();
@@ -194,20 +180,20 @@
         return;
       }
 
-      // Ray B and C: the actual rays the eye receives, from the top and
-      // bottom of the object — solid to the mirror and on to the eye, then
-      // a dashed backward extension from the reflection point through the
-      // eye's direction, landing exactly on the image (top/bottom).
-      [
-        { obj: objTip, image: imgTip, P: P1 },
-        { obj: objBase, image: imgBase, P: P2 },
-      ].forEach(({ obj, image, P }) => {
-        arrow(ctx, obj.x, obj.y, P.x, P.y, '#10b981', 1.8);
-        arrow(ctx, P.x, P.y, eye.x, eye.y, '#10b981', 1.8, 0.85);
-        ctx.save(); ctx.setLineDash([5, 4]); ctx.strokeStyle = 'rgba(16,185,129,0.55)'; ctx.lineWidth = 1.4;
-        ctx.beginPath(); ctx.moveTo(P.x, P.y); ctx.lineTo(image.x, image.y); ctx.stroke();
-        ctx.restore();
-      });
+      // A second ray leaves the same object tip and hits lower on the
+      // mirror. Both backward extensions meet at that tip's virtual image.
+      const secondHit = { x: cx, y: H * 0.63 };
+      const outgoing = { x: objTip.x - cx, y: secondHit.y - objTip.y };
+      const reach = Math.min(1, (H - 36 - secondHit.y) / outgoing.y);
+      arrow(ctx, objTip.x, objTip.y, secondHit.x, secondHit.y, '#047857', 2);
+      arrow(ctx, secondHit.x, secondHit.y, secondHit.x + outgoing.x * reach,
+        secondHit.y + outgoing.y * reach, '#047857', 2);
+      ctx.save(); ctx.setLineDash([5, 4]); ctx.lineWidth = 1.7;
+      for (const [hit, color] of [[P0, '#4338ca'], [secondHit, '#047857']] as const) {
+        ctx.strokeStyle = color;
+        ctx.beginPath(); ctx.moveTo(hit.x, hit.y); ctx.lineTo(imgTip.x, imgTip.y); ctx.stroke();
+      }
+      ctx.restore();
 
       // Object and image arrows — drawn last so they sit cleanly on top of
       // the rays that terminate exactly at their tip/base.
@@ -218,11 +204,9 @@
       ctx.restore();
       flag(ctx, imgTip.x, imgTip.y + 8, -1, '#8b5cf6');
 
-      ctx.fillStyle = '#a78bfa'; ctx.font = '16px system-ui'; ctx.textAlign = 'center';
-      ctx.fillText('👁', eye.x, eye.y + 5);
-
-      ctx.fillStyle = '#334155'; ctx.font = '600 14px system-ui'; ctx.textAlign = 'left';
-      ctx.fillText('Solid: reflected rays · Dashed: virtual image rays', 8, H - 10, W - 20);
+      ctx.fillStyle = '#334155'; ctx.font = '600 14px system-ui'; ctx.textAlign = 'center';
+      ctx.fillText('Dashed extensions meet at the virtual image tip', W / 2, H - 25, W - 16);
+      ctx.fillText('Same height · Equal distances from the mirror', W / 2, H - 8, W - 16);
     } else if (s.mode === 'curved') {
       const axisY = H / 2, cx = W / 2;
       const f = s.converging ? s.focal : -s.focal;
@@ -379,13 +363,18 @@
         ctx.stroke();
       }
 
-      // Normal (dashed)
+      // Show the initial normal throughout and add the current normal once the mirror turns.
       ctx.save(); ctx.setLineDash([4, 4]); ctx.strokeStyle = '#94a3b8'; ctx.lineWidth = 1;
       const normalLength = Math.min(rayLength * 1.3, Math.max(rayLength, P.y - 49));
       const normalTip = { x: P.x + normal.x * normalLength, y: P.y + normal.y * normalLength };
       ctx.beginPath();
       ctx.moveTo(P.x - normal.x * rayLength * 0.75, P.y - normal.y * rayLength * 0.75);
       ctx.lineTo(normalTip.x, normalTip.y); ctx.stroke();
+      const turned = Math.abs(angleDeg) >= 0.05;
+      if (turned) {
+        ctx.strokeStyle = '#64748b'; ctx.setLineDash([2, 4]);
+        ctx.beginPath(); ctx.moveTo(P.x, P.y); ctx.lineTo(P.x, P.y - normalLength); ctx.stroke();
+      }
       ctx.restore();
 
       // Incident ray (fixed) and current reflected ray
@@ -428,13 +417,16 @@
       ctx.fillStyle = '#0f172a'; ctx.beginPath(); ctx.arc(P.x, P.y, 4, 0, Math.PI * 2); ctx.fill();
       const reflectedEnd = { x: P.x + r.x * rayLength, y: P.y + r.y * rayLength };
       ctx.fillStyle = '#047857'; ctx.font = '700 14px system-ui'; ctx.textAlign = r.x >= 0 ? 'left' : 'right';
-      ctx.fillText('R', reflectedEnd.x + (r.x >= 0 ? 5 : -5), reflectedEnd.y - 6,
+      if (turned) ctx.fillText('R', reflectedEnd.x + (r.x >= 0 ? 5 : -5), reflectedEnd.y - 6,
         Math.max(1, (r.x >= 0 ? W - reflectedEnd.x : reflectedEnd.x) - 10));
 
       ctx.fillStyle = '#92400e'; ctx.textAlign = 'left';
       ctx.fillText('R′', P.x + r0.x * rayLength + 5, P.y + r0.y * rayLength + 13);
       ctx.fillStyle = '#475569'; ctx.textAlign = 'center';
-      ctx.fillText('Normal', normalTip.x, Math.max(55, normalTip.y - 5), W - 16);
+      ctx.fillText('N', P.x, Math.max(55, P.y - normalLength - 5));
+      if (turned) {
+        ctx.fillText('N′', normalTip.x + Math.sign(angleDeg) * 12, Math.max(55, normalTip.y + 12));
+      }
 
       ctx.textAlign = 'center'; ctx.font = '700 16px system-ui'; ctx.fillStyle = '#0f172a';
       ctx.fillText(`Mirror θ = ${angleDeg.toFixed(1)}°   ·   Ray turn 2θ = ${reflectedDeg.toFixed(1)}°`, W / 2, 20, W - 16);
@@ -442,7 +434,7 @@
       ctx.fillText(`From the current normal: incidence i = reflection r = ${incidenceDeg.toFixed(1)}°`, W / 2, 39, W - 16);
       ctx.fillStyle = '#334155';
       ctx.fillText('R′: original reflected ray · R: new reflected ray', W / 2, H - 27, W - 16);
-      ctx.fillText('Blue: fixed incident ray · r: angle of reflection', W / 2, H - 9, W - 16);
+      ctx.fillText('N: initial normal · N′: rotated normal · r: reflection angle', W / 2, H - 9, W - 16);
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
echo 'Plane mirror rays and rotation normals updated.'
