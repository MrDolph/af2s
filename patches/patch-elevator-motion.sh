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
@@ -267,6 +267,7 @@
                 {topic === 'elevator' && (
                   <ElevatorCanvas key={resetKey} mass={elevMass} elevState={elevState}
                     manualAccel={elevAccel} isRunning={isRunning} isPaused={isPaused}
+                    onComplete={() => { setIsComplete(true); setIsRunning(false); }}
                     width={canvasSize.width} height={canvasSize.height} />
                 )}
 
@@ -350,11 +351,11 @@
               <div data-stage-role="playback" className="flex flex-wrap items-center justify-between gap-2">
                 <SimulationControls
                   isRunning={isRunning && !isComplete} isPaused={isPaused}
-                  onRun={() => { if (topic === 'collision' && isComplete) setResetKey(k => k + 1); setIsRunning(true); setIsPaused(false); setIsComplete(false); }}
+                  onRun={() => { if (isComplete) setResetKey(k => k + 1); setIsRunning(true); setIsPaused(false); setIsComplete(false); }}
                   onPause={() => setIsPaused(p => !p)}
                   onReset={reset}
                 />
-                {isComplete && <span className="text-xs font-medium text-emerald-600">{topic === 'collision' ? '✓ Complete · Run to replay' : '✓ Complete — Reset to go again'}</span>}
+                {isComplete && <span className="text-xs font-medium text-emerald-600">✓ Complete · Run to replay</span>}
                 {topic === 'propulsion' && liveRocket.burnedOut && (
                   <span className="text-xs font-medium text-amber-600">🔥 Engine cutoff — coasting</span>
                 )}
--- a/src/components/simulation/ElevatorCanvas.tsx
+++ b/src/components/simulation/ElevatorCanvas.tsx
@@ -8,78 +8,86 @@
   manualAccel: number;
   isRunning: boolean;
   isPaused: boolean;
+  onComplete?: () => void;
   width?: number; height?: number;
 }
 
-export function ElevatorCanvas({ mass, elevState, manualAccel, isRunning, isPaused, width = 500, height = 340 }: Props) {
+export function ElevatorCanvas({ mass, elevState, manualAccel, isRunning, isPaused, onComplete, width = 500, height = 340 }: Props) {
   const canvasRef = useRef<HTMLCanvasElement | null>(null);
   const rafRef = useRef<number>(0);
-  const yRef = useRef(220);
-  const vyRef = useRef(0);
   const timeRef = useRef(0);
   const lastFrameRef = useRef<number | null>(null);
-  const simRef = useRef({ mass, elevState, manualAccel, isRunning, isPaused });
-  simRef.current = { mass, elevState, manualAccel, isRunning, isPaused };
+  const simRef = useRef({ mass, elevState, manualAccel, isRunning, isPaused, onComplete });
+  simRef.current = { mass, elevState, manualAccel, isRunning, isPaused, onComplete };
 
   useEffect(() => {
-    yRef.current = 220; vyRef.current = 0; timeRef.current = 0; lastFrameRef.current = null;
+    timeRef.current = 0; lastFrameRef.current = null;
   }, [elevState, mass, manualAccel]);
 
   const draw = useCallback((timestamp?: number) => {
     const canvas = canvasRef.current; if (!canvas) return;
     const ctx = canvas.getContext('2d'); if (!ctx) return;
-    const { mass: m, elevState: st, manualAccel: ma, isRunning: r, isPaused: p } = simRef.current;
+    const { mass: m, elevState: st, manualAccel: ma, isRunning: r, isPaused: p, onComplete: complete } = simRef.current;
     const W = canvas.width, H = canvas.height;
 
     const accel = elevatorAcceleration(st, ma);
     const Wapp = apparentWeight(m, accel);
     const Wtrue = m * g;
 
-    let dt = 0;
-    if (r && !p && timestamp !== undefined) {
-      if (lastFrameRef.current !== null) {
-        dt = Math.min((timestamp - lastFrameRef.current) / 1000, 0.1);
-      }
+    const top = 40;
+    const bottom = Math.max(top + 24, H - 108);
+    const travel = bottom - top;
+    const direction = st.endsWith('down') || st === 'freefall' ? -1 : 1;
+    const braking = st.startsWith('decel');
+    const cruising = st.startsWith('constant');
+    const magnitude = Math.abs(accel);
+    // Map the complete motion to the visible shaft. Keep the same mapping
+    // when resizing so the elapsed time and physical velocity stay intact.
+    const distance = 6;
+    const initialSpeed = braking ? Math.sqrt(2 * magnitude * distance) : cruising ? 2 : 0;
+    const duration = cruising ? distance / initialSpeed : magnitude > 0 ? Math.sqrt(2 * distance / magnitude) : 0;
+    if (r && !p && timestamp !== undefined && timeRef.current < duration) {
+      const dt = lastFrameRef.current === null ? 0 : Math.min((timestamp - lastFrameRef.current) / 1000, 0.1);
+      timeRef.current = Math.min(duration, timeRef.current + dt);
       lastFrameRef.current = timestamp;
+      if (timeRef.current === duration) complete?.();
     } else {
-      lastFrameRef.current = timestamp ?? null;
+      lastFrameRef.current = null;
     }
-    if (dt > 0) {
-      vyRef.current += accel * dt * 60; // px/s (60 = same visual scale as before)
-      yRef.current -= vyRef.current * dt;
-      // Clamp
-      if (yRef.current < 60) { yRef.current = 60; vyRef.current = 0; }
-      if (yRef.current > H - 80) { yRef.current = H - 80; vyRef.current = 0; }
-      timeRef.current += dt;
-    }
+
+    const t = timeRef.current;
+    const speed = Math.max(0, initialSpeed + direction * accel * t);
+    const displacement = Math.min(distance, initialSpeed * t + 0.5 * direction * accel * t * t);
+    const ey = st === 'rest' ? (top + bottom) / 2 : direction > 0
+      ? bottom - displacement / distance * travel
+      : top + displacement / distance * travel;
 
     ctx.clearRect(0, 0, W, H);
 
     // Building background
     ctx.fillStyle = '#f1f5f9';
-    ctx.fillRect(60, 20, W - 120, H - 40);
+    ctx.fillRect(24, 32, W - 48, H - 48);
     ctx.strokeStyle = '#cbd5e1'; ctx.lineWidth = 1;
-    ctx.strokeRect(60, 20, W - 120, H - 40);
+    ctx.strokeRect(24, 32, W - 48, H - 48);
 
     // Floor lines
     for (let fl = 0; fl < 6; fl++) {
-      const fy = 20 + fl * (H - 40) / 5;
-      ctx.beginPath(); ctx.moveTo(60, fy); ctx.lineTo(W - 60, fy);
+      const fy = 32 + fl * (H - 48) / 5;
+      ctx.beginPath(); ctx.moveTo(24, fy); ctx.lineTo(W - 24, fy);
       ctx.strokeStyle = '#e2e8f0'; ctx.lineWidth = 1; ctx.stroke();
       ctx.fillStyle = '#94a3b8'; ctx.font = '9px system-ui'; ctx.textAlign = 'left';
-      ctx.fillText(`${5 - fl}F`, 62, fy + 12);
+      ctx.fillText(`${5 - fl}F`, 28, fy + 12);
     }
 
     // Elevator cables
     ctx.beginPath();
-    ctx.moveTo(W / 2 - 20, 20); ctx.lineTo(W / 2 - 20, yRef.current);
-    ctx.moveTo(W / 2 + 20, 20); ctx.lineTo(W / 2 + 20, yRef.current);
+    ctx.moveTo(W / 2 - 20, 32); ctx.lineTo(W / 2 - 20, ey);
+    ctx.moveTo(W / 2 + 20, 32); ctx.lineTo(W / 2 + 20, ey);
     ctx.strokeStyle = '#64748b'; ctx.lineWidth = 2; ctx.stroke();
 
     // Elevator box
     const EW = 120, EH = 80;
     const ex = W / 2 - EW / 2;
-    const ey = yRef.current;
 
     // Elevator body
     ctx.fillStyle = '#e0e7ff';
@@ -107,34 +115,38 @@
     ctx.fillStyle = '#f59e0b'; ctx.font = 'bold 9px system-ui'; ctx.textAlign = 'center';
     ctx.fillText(`${Wapp.toFixed(0)}N`, px, py + 11);
 
-    // Velocity arrow on elevator
-    if (Math.abs(vyRef.current) > 0.3) {
-      const dir = vyRef.current > 0 ? -1 : 1; // canvas y inverted
-      const arrowY = ey + EH / 2;
-      const arrowX = ex - 20;
-      ctx.save();
-      ctx.beginPath(); ctx.moveTo(arrowX, arrowY); ctx.lineTo(arrowX, arrowY + dir * 30);
-      ctx.strokeStyle = '#10b981'; ctx.lineWidth = 2; ctx.stroke();
-      ctx.beginPath(); ctx.moveTo(arrowX, arrowY + dir * 30);
-      ctx.lineTo(arrowX - 5, arrowY + dir * 20);
-      ctx.lineTo(arrowX + 5, arrowY + dir * 20);
-      ctx.closePath(); ctx.fillStyle = '#10b981'; ctx.fill();
-      ctx.restore();
-    }
+    // Positive physical components point upward on the canvas.
+    const drawVector = (x: number, value: number, label: string, color: string) => {
+      const start = ey + EH / 2;
+      const sign = Math.sign(value);
+      const tip = start - sign * Math.min(35, 18 + Math.abs(value) * 2);
+      ctx.strokeStyle = color; ctx.fillStyle = color; ctx.lineWidth = 3;
+      ctx.font = 'bold 13px system-ui'; ctx.textAlign = 'center';
+      if (Math.abs(value) < 0.01) {
+        ctx.fillText(`${label} = 0`, x, start + 4);
+        return;
+      }
+      ctx.beginPath(); ctx.moveTo(x, start); ctx.lineTo(x, tip); ctx.stroke();
+      ctx.beginPath(); ctx.moveTo(x, tip);
+      ctx.lineTo(x - 5, tip + sign * 8); ctx.lineTo(x + 5, tip + sign * 8);
+      ctx.closePath(); ctx.fill();
+      ctx.fillText(label, x, sign > 0 ? start + 15 : start - 7);
+    };
+    drawVector(ex - 22, direction * speed, 'v', '#047857');
+    drawVector(ex + EW + 22, accel, 'a', '#92400e');
 
     // Info panel (right)
-    const ix = W - 50;
     const infos = [
       { l: 'True weight', v: `${Wtrue.toFixed(1)} N`, c: '#64748b' },
       { l: 'Apparent weight', v: `${Wapp.toFixed(1)} N`, c: Wapp > Wtrue ? '#10b981' : Wapp < Wtrue ? '#ef4444' : '#6366f1' },
       { l: 'Acceleration', v: `${accel.toFixed(2)} m/s²`, c: '#f59e0b' },
-      { l: 'State', v: st.replace('-', ' '), c: '#6366f1' },
+      { l: 'Velocity', v: `${(direction * speed).toFixed(2)} m/s`, c: '#047857' },
     ];
     infos.forEach((info, i) => {
-      ctx.fillStyle = '#64748b'; ctx.font = '9px system-ui'; ctx.textAlign = 'right';
-      ctx.fillText(info.l, ix, 40 + i * 32);
+      ctx.fillStyle = '#64748b'; ctx.font = '9px system-ui'; ctx.textAlign = 'center';
+      ctx.fillText(info.l, W * (i + 0.5) / infos.length, 11);
       ctx.fillStyle = info.c; ctx.font = 'bold 12px system-ui';
-      ctx.fillText(info.v, ix, 54 + i * 32);
+      ctx.fillText(info.v, W * (i + 0.5) / infos.length, 25);
     });
 
     // Weightlessness indicator
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
echo 'Elevator motion updated.'
