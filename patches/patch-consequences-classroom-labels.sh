#!/usr/bin/env bash
set -euo pipefail
if [[ ! -f package.json || ! -f src/app/simulations/consequences-of-motion/page.tsx ]]; then
  echo 'Run this patch from the A-Factor project root.' >&2
  exit 1
fi
patch_file=$(mktemp)
trap 'rm -f "$patch_file"' EXIT
cat > "$patch_file" <<'AF_MECHANICS_PATCH'
--- a/src/components/simulation/ElevatorCanvas.tsx
+++ b/src/components/simulation/ElevatorCanvas.tsx
@@ -34,7 +34,7 @@
     const Wapp = apparentWeight(m, accel);
     const Wtrue = m * g;
 
-    const top = 40;
+    const top = 52;
     const bottom = Math.max(top + 24, H - 108);
     const travel = bottom - top;
     const direction = st.endsWith('down') || st === 'freefall' ? -1 : 1;
@@ -66,23 +66,23 @@
 
     // Building background
     ctx.fillStyle = '#f1f5f9';
-    ctx.fillRect(24, 32, W - 48, H - 48);
+    ctx.fillRect(24, 44, W - 48, H - 60);
     ctx.strokeStyle = '#cbd5e1'; ctx.lineWidth = 1;
-    ctx.strokeRect(24, 32, W - 48, H - 48);
+    ctx.strokeRect(24, 44, W - 48, H - 60);
 
     // Floor lines
     for (let fl = 0; fl < 6; fl++) {
-      const fy = 32 + fl * (H - 48) / 5;
+      const fy = 44 + fl * (H - 60) / 5;
       ctx.beginPath(); ctx.moveTo(24, fy); ctx.lineTo(W - 24, fy);
       ctx.strokeStyle = '#e2e8f0'; ctx.lineWidth = 1; ctx.stroke();
-      ctx.fillStyle = '#94a3b8'; ctx.font = '9px system-ui'; ctx.textAlign = 'left';
+      ctx.fillStyle = '#475569'; ctx.font = '600 14px system-ui'; ctx.textAlign = 'left';
       ctx.fillText(`${5 - fl}F`, 28, fy + 12);
     }
 
     // Elevator cables
     ctx.beginPath();
-    ctx.moveTo(W / 2 - 20, 32); ctx.lineTo(W / 2 - 20, ey);
-    ctx.moveTo(W / 2 + 20, 32); ctx.lineTo(W / 2 + 20, ey);
+    ctx.moveTo(W / 2 - 20, 44); ctx.lineTo(W / 2 - 20, ey);
+    ctx.moveTo(W / 2 + 20, 44); ctx.lineTo(W / 2 + 20, ey);
     ctx.strokeStyle = '#64748b'; ctx.lineWidth = 2; ctx.stroke();
 
     // Elevator box
@@ -112,7 +112,7 @@
     // Scale under feet
     ctx.fillStyle = '#1e293b';
     ctx.beginPath(); ctx.roundRect(px - 16, py + 4, 32, 8, 3); ctx.fill();
-    ctx.fillStyle = '#f59e0b'; ctx.font = 'bold 9px system-ui'; ctx.textAlign = 'center';
+    ctx.fillStyle = '#f59e0b'; ctx.font = 'bold 12px system-ui'; ctx.textAlign = 'center';
     ctx.fillText(`${Wapp.toFixed(0)}N`, px, py + 11);
 
     // Positive physical components point upward on the canvas.
@@ -121,7 +121,7 @@
       const sign = Math.sign(value);
       const tip = start - sign * Math.min(35, 18 + Math.abs(value) * 2);
       ctx.strokeStyle = color; ctx.fillStyle = color; ctx.lineWidth = 3;
-      ctx.font = 'bold 13px system-ui'; ctx.textAlign = 'center';
+      ctx.font = 'bold 18px system-ui'; ctx.textAlign = 'center';
       if (Math.abs(value) < 0.01) {
         ctx.fillText(`${label} = 0`, x, start + 4);
         return;
@@ -143,17 +143,17 @@
       { l: 'Velocity', v: `${(direction * speed).toFixed(2)} m/s`, c: '#047857' },
     ];
     infos.forEach((info, i) => {
-      ctx.fillStyle = '#64748b'; ctx.font = '9px system-ui'; ctx.textAlign = 'center';
-      ctx.fillText(info.l, W * (i + 0.5) / infos.length, 11);
-      ctx.fillStyle = info.c; ctx.font = 'bold 12px system-ui';
-      ctx.fillText(info.v, W * (i + 0.5) / infos.length, 25);
+      ctx.fillStyle = '#64748b'; ctx.font = '600 14px system-ui'; ctx.textAlign = 'center';
+      ctx.fillText(info.l, W * (i + 0.5) / infos.length, 15, W / 4 - 8);
+      ctx.fillStyle = info.c; ctx.font = 'bold 18px system-ui';
+      ctx.fillText(info.v, W * (i + 0.5) / infos.length, 36, W / 4 - 8);
     });
 
     // Weightlessness indicator
     if (st === 'freefall' || Wapp < 1) {
       ctx.fillStyle = 'rgba(239,68,68,0.15)';
       ctx.fillRect(ex, ey, EW, EH);
-      ctx.fillStyle = '#ef4444'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
+      ctx.fillStyle = '#ef4444'; ctx.font = 'bold 15px system-ui'; ctx.textAlign = 'center';
       ctx.fillText('WEIGHTLESS', W / 2, ey - 8);
     }
 
--- a/src/components/simulation/PropulsionCanvas.tsx
+++ b/src/components/simulation/PropulsionCanvas.tsx
@@ -114,7 +114,7 @@
     ctx.lineTo(cx + bodyW / 2 + 22, cy);
     ctx.lineTo(cx + bodyW / 2, cy + bodyH / 2);
     ctx.closePath(); ctx.fill();
-    ctx.fillStyle = '#312e81'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
+    ctx.fillStyle = '#312e81'; ctx.font = 'bold 13px system-ui'; ctx.textAlign = 'center';
     ctx.fillText(`${state.mass.toFixed(0)}kg`, cx, cy + 4);
 
     // Fuel gauge
@@ -123,25 +123,24 @@
     ctx.beginPath(); ctx.roundRect(gx, gy, gw, gh, 4); ctx.fill();
     ctx.fillStyle = state.fuelFraction > 0.2 ? '#34d399' : '#f87171';
     ctx.beginPath(); ctx.roundRect(gx, gy, gw * Math.max(0, state.fuelFraction), gh, 4); ctx.fill();
-    ctx.fillStyle = '#cbd5e1'; ctx.font = '9px system-ui'; ctx.textAlign = 'left';
+    ctx.fillStyle = '#cbd5e1'; ctx.font = '600 15px system-ui'; ctx.textAlign = 'left';
     ctx.fillText(`Fuel ${(state.fuelFraction * 100).toFixed(0)}%`, gx, gy - 4);
 
     // HUD
     ctx.textAlign = 'right';
-    const uiScale = Math.max(0.75, Math.min(1, W / 660));
     const hud = [
       `T+${state.t.toFixed(1)}s`,
       `v = ${state.v.toFixed(1)} m/s`,
       `a = ${state.acceleration.toFixed(2)} m/s²`,
       `Thrust = ${state.thrust.toFixed(0)} N`,
     ];
-    const hudFont = Math.max(8, Math.round(10 * uiScale)), hudLineH = Math.max(12, Math.round(15 * uiScale));
+    const hudFont = Math.max(14, Math.min(20, Math.round(W / 45))), hudLineH = hudFont + 5;
     ctx.font = `bold ${hudFont}px monospace`; ctx.fillStyle = '#e0e7ff';
-    hud.forEach((line, i) => ctx.fillText(line, W - 12, 18 + i * hudLineH));
+    hud.forEach((line, i) => ctx.fillText(line, W - 12, hudFont + 5 + i * hudLineH));
 
     if (state.burnedOut) {
-      ctx.textAlign = 'center'; ctx.font = 'bold 11px system-ui'; ctx.fillStyle = '#fbbf24';
-      ctx.fillText('🔥 Engine cutoff — coasting at constant velocity (Newton\u2019s 1st Law)', W / 2, H - 10);
+      ctx.textAlign = 'center'; ctx.font = 'bold 16px system-ui'; ctx.fillStyle = '#fbbf24';
+      ctx.fillText('Engine cutoff · coasting at constant velocity', W / 2, H - 5, W - 16);
     }
 
     rafRef.current = requestAnimationFrame(draw);
--- a/src/components/simulation/WalkingCanvas.tsx
+++ b/src/components/simulation/WalkingCanvas.tsx
@@ -55,16 +55,16 @@
     ctx.strokeStyle = '#94a3b8'; ctx.lineWidth = 2; ctx.stroke();
 
     // Surface label
-    ctx.fillStyle = '#94a3b8'; ctx.font = '10px system-ui'; ctx.textAlign = 'center';
+    ctx.fillStyle = '#334155'; ctx.font = '600 16px system-ui'; ctx.textAlign = 'center';
     if (!fr) {
-      ctx.fillText('ICE — frictionless (no grip, no walking)', W / 2, H - 10);
+      ctx.fillText('ICE — frictionless (no grip, no walking)', W / 2, H - 10, W - 16);
       // Ice texture
       for (let ix = 0; ix < W; ix += 30) {
         ctx.strokeStyle = 'rgba(147,197,253,0.5)'; ctx.lineWidth = 1;
         ctx.beginPath(); ctx.moveTo(ix, groundY); ctx.lineTo(ix + 15, groundY + 8); ctx.stroke();
       }
     } else {
-      ctx.fillText('Normal ground — friction provides forward push', W / 2, H - 10);
+      ctx.fillText('Normal ground — friction provides forward push', W / 2, H - 10, W - 16);
     }
 
     // Walking person (stick figure with leg animation)
@@ -107,9 +107,9 @@
       ctx.beginPath(); ctx.moveTo(footX - 55, pushY);
       ctx.lineTo(footX - 45, pushY - 5); ctx.lineTo(footX - 45, pushY + 5);
       ctx.closePath(); ctx.fill();
-      ctx.font = '9px system-ui'; ctx.textAlign = 'center';
-      ctx.fillText('Foot on ground', footX - 28, pushY - 8);
-      ctx.fillText('(action ←)', footX - 28, pushY + 14);
+      ctx.font = '600 14px system-ui'; ctx.textAlign = 'center';
+      ctx.fillStyle = '#991b1b';
+      ctx.fillText('Foot pushes ground ←', W / 2, H - 31, W - 16);
 
       // Ground pushes person forward (reaction) — green arrow rightward on person
       ctx.strokeStyle = '#10b981'; ctx.lineWidth = 2;
@@ -118,15 +118,15 @@
       ctx.beginPath(); ctx.moveTo(x + 35, py - 45);
       ctx.lineTo(x + 25, py - 50); ctx.lineTo(x + 25, py - 40);
       ctx.closePath(); ctx.fill();
-      ctx.fillText('Ground on person', x + 5, py - 52);
-      ctx.fillText('(reaction →)', x + 5, py - 35);
+      ctx.fillStyle = '#065f46';
+      ctx.fillText('Ground pushes person →', W / 2, 22, W - 16);
       ctx.restore();
     }
 
     if (!fr && r) {
       // Feet slipping
-      ctx.fillStyle = '#ef4444'; ctx.font = '11px system-ui'; ctx.textAlign = 'center';
-      ctx.fillText('No friction → no reaction force → cannot walk!', x, py - 110);
+      ctx.fillStyle = '#ef4444'; ctx.font = '600 15px system-ui'; ctx.textAlign = 'center';
+      ctx.fillText('No friction → no forward push', W / 2, 22, W - 16);
     }
 
     rafRef.current = requestAnimationFrame(draw);
--- a/src/components/simulation/WeightlessnessCanvas.tsx
+++ b/src/components/simulation/WeightlessnessCanvas.tsx
@@ -53,14 +53,14 @@
   ctx.fillStyle = '#1e293b';
   ctx.beginPath(); ctx.roundRect(bx + boxW / 2 - 16, sy, 32, 8, 3); ctx.fill();
   ctx.fillStyle = weightless ? '#ef4444' : '#059669';
-  ctx.font = 'bold 9px system-ui'; ctx.textAlign = 'center';
+  ctx.font = 'bold 14px system-ui'; ctx.textAlign = 'center';
   ctx.fillText(`${scaleReading.toFixed(0)}N`, bx + boxW / 2, sy + 20);
 
-  ctx.fillStyle = '#64748b'; ctx.font = 'bold 10px system-ui';
-  ctx.fillText(label, x + w / 2, y - 6);
+  ctx.fillStyle = '#64748b'; ctx.font = 'bold 16px system-ui';
+  ctx.fillText(label, x + w / 2, y - 6, w - 8);
   if (weightless && fallOffset > 2) {
-    ctx.fillStyle = '#ef4444'; ctx.font = 'bold 9px system-ui';
-    ctx.fillText('WEIGHTLESS', x + w / 2, by - 4);
+    ctx.fillStyle = '#ef4444'; ctx.font = 'bold 14px system-ui';
+    ctx.fillText('WEIGHTLESS', x + w / 2, by - 4, w - 8);
   }
 }
 
@@ -90,7 +90,7 @@
       lastFrameRef.current = timestamp ?? null;
     }
 
-    const chamberH = H - 30;
+    const chamberH = H - 65;
     const maxDropPx = chamberH - 80;
     const dropDistanceM = freeFallDistance(t.current, gv);
     // Visual pixel scale chosen so a representative drop (Earth g, ~2s) just
@@ -118,10 +118,10 @@
       landed.current ? 'Landed' : 'Free falling', falling && !landed.current);
 
     // Context readout
-    ctx.fillStyle = '#475569'; ctx.font = '10px system-ui'; ctx.textAlign = 'left';
-    ctx.fillText(`g at this altitude = ${gv.toFixed(2)} m/s²  (${(gv / 9.81 * 100).toFixed(0)}% of Earth surface)`, 10, H - 6);
-    ctx.textAlign = 'right';
-    ctx.fillText(`fallen ${dropDistanceM.toFixed(1)} m in ${t.current.toFixed(1)}s`, W - 10, H - 6);
+    ctx.fillStyle = '#475569'; ctx.font = '600 15px system-ui'; ctx.textAlign = 'left';
+    ctx.fillText(`g at this altitude = ${gv.toFixed(2)} m/s²  (${(gv / 9.81 * 100).toFixed(0)}% of Earth surface)`, 10, H - 23, W - 20);
+    ctx.textAlign = 'left';
+    ctx.fillText(`fallen ${dropDistanceM.toFixed(1)} m in ${t.current.toFixed(1)}s`, 10, H - 5, W - 20);
 
     rafRef.current = requestAnimationFrame(draw);
   }, []);
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
echo 'Consequences of Motion canvas labels updated.'
