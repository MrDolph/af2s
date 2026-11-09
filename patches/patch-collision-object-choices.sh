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
@@ -10,7 +10,7 @@
 import { WeightlessnessCanvas } from '@/components/simulation/WeightlessnessCanvas';
 import { WalkingCanvas } from '@/components/simulation/WalkingCanvas';
 import { PropulsionCanvas } from '@/components/simulation/PropulsionCanvas';
-import { CollisionCanvas } from '@/components/simulation/CollisionCanvas';
+import { COLLISION_OBJECTS, CollisionCanvas, type CollisionObject } from '@/components/simulation/CollisionCanvas';
 import { useResponsiveCanvasSize } from '@/hooks/useResponsiveCanvasSize';
 import {
   apparentWeight, solveCollision, rocketAnalytics, rocketStateAt,
@@ -149,6 +149,8 @@
   const [liveFall, setLiveFall] = useState({ t: 0, distance: 0 });
 
   // Collision
+  const [objectA, setObjectA] = useState<CollisionObject>('block');
+  const [objectB, setObjectB] = useState<CollisionObject>('block');
   const [collM1, setCollM1] = useState(3);
   const [collM2, setCollM2] = useState(2);
   const [collU1, setCollU1] = useState(6);
@@ -291,7 +293,7 @@
                 )}
 
                 {topic === 'collision' && (
-                  <CollisionCanvas key={JSON.stringify([resetKey, collParams])} params={collParams}
+                  <CollisionCanvas key={JSON.stringify([resetKey, collParams])} params={collParams} objectA={objectA} objectB={objectB}
                     isRunning={isRunning} isPaused={isPaused}
                     onComplete={() => { setIsComplete(true); setIsRunning(false); }} />
                 )}
@@ -430,10 +432,19 @@
                           }`}>{t === 'elastic' ? 'Elastic' : 'Inelastic (sticks)'}</button>
                       ))}
                     </div>
-                    <Slider label="Mass 1 (blue)" unit="kg" value={collM1} min={0.5} max={10} step={0.5} set={setCollM1} color="#6366f1" />
-                    <Slider label="Velocity 1" unit="m/s" value={collU1} min={-10} max={20} step={0.5} set={setCollU1} color="#6366f1" />
-                    <Slider label="Mass 2 (green)" unit="kg" value={collM2} min={0.5} max={10} step={0.5} set={setCollM2} color="#10b981" />
-                    <Slider label="Velocity 2" unit="m/s" value={collU2} min={-10} max={10} step={0.5} set={setCollU2} color="#10b981" note="Negative = moving left" />
+                    {([{ label: 'Object A', value: objectA, set: setObjectA }, { label: 'Object B', value: objectB, set: setObjectB }]).map(({ label, value, set }) => (
+                      <label key={label} className="grid gap-1 text-sm font-medium text-slate-700">
+                        {label}
+                        <select value={value} onChange={event => set(event.target.value as CollisionObject)}
+                          className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-slate-900">
+                          {Object.entries(COLLISION_OBJECTS).map(([id, name]) => <option key={id} value={id}>{name}</option>)}
+                        </select>
+                      </label>
+                    ))}
+                    <Slider label="Mass A (blue)" unit="kg" value={collM1} min={0.5} max={10} step={0.5} set={setCollM1} color="#6366f1" />
+                    <Slider label="Velocity A" unit="m/s" value={collU1} min={-10} max={20} step={0.5} set={setCollU1} color="#6366f1" />
+                    <Slider label="Mass B (green)" unit="kg" value={collM2} min={0.5} max={10} step={0.5} set={setCollM2} color="#10b981" />
+                    <Slider label="Velocity B" unit="m/s" value={collU2} min={-10} max={10} step={0.5} set={setCollU2} color="#10b981" note="Negative = moving left" />
                   </>
                 )}
               </div>
--- a/src/components/simulation/CollisionCanvas.tsx
+++ b/src/components/simulation/CollisionCanvas.tsx
@@ -14,8 +14,28 @@
   return `${value > 0 ? '+' : ''}${Number(value.toFixed(2))}`;
 }
 
-export function CollisionCanvas({ params, isRunning, isPaused, onComplete }: {
+export const COLLISION_OBJECTS = {
+  block: 'Block',
+  trolley: 'Trolley',
+  car: 'Toy car',
+  truck: 'Toy pickup truck',
+  lorry: 'Toy lorry',
+} as const;
+
+export type CollisionObject = keyof typeof COLLISION_OBJECTS;
+
+// Each silhouette spans the same contact width as the original block.
+const VEHICLE_BODIES = {
+  trolley: 'M0 76H72V99H0Z M0 76V63H5V76Z',
+  car: 'M0 81H9L21 66H47L60 81H72V99H0Z',
+  truck: 'M0 79H32V65H53L64 78H72V99H0Z',
+  lorry: 'M0 60H43V83H47V68H61L72 81V99H0Z',
+};
+
+export function CollisionCanvas({ params, isRunning, isPaused, onComplete, objectA = 'block', objectB = 'block' }: {
   params: CollisionParams;
+  objectA?: CollisionObject;
+  objectB?: CollisionObject;
   isRunning: boolean;
   isPaused: boolean;
   onComplete: () => void;
@@ -85,13 +105,20 @@
           <path d="M0 112H480" stroke="#64748b" strokeWidth="2" />
           {phase === 1 && <path d={`M${x2} 38v77`} stroke="#d97706" strokeWidth="10" />}
           {[x1, x2].map((x, i) => {
+            const object = i === 0 ? objectA : objectB;
             const color = i === 0 ? '#4338ca' : '#047857';
             const center = x + BLOCK / 2;
             const direction = Math.sign(arrows[i]);
             const tip = center + direction * 26;
             return <g key={i}>
-              <rect x={x} y="55" width={BLOCK} height="56" rx={phase === 1 || (phase === 2 && sticks) ? 0 : 7} fill={color} />
-              <text x={center} y="92" fill="white" fontSize="25" fontWeight="700" textAnchor="middle">{i === 0 ? 'A' : 'B'}</text>
+              {object === 'block' ? <rect x={x} y="55" width={BLOCK} height="56" rx={phase === 1 || (phase === 2 && sticks) ? 0 : 7} fill={color} /> : (
+                <g transform={`translate(${x} 0)${(i === 0 ? u1 : u2) < 0 ? ` translate(${BLOCK} 0) scale(-1 1)` : ''}`}>
+                  <path d={VEHICLE_BODIES[object]} fill={color} />
+                  <circle cx="15" cy="103" r="8" fill="#1e293b" />
+                  <circle cx="57" cy="103" r="8" fill="#1e293b" />
+                </g>
+              )}
+              <text x={center} y="92" fill="white" fontSize={object === 'block' ? 25 : 15} fontWeight="700" textAnchor="middle">{i === 0 ? 'A' : 'B'}</text>
               {direction !== 0 && <path d={`M${center - direction * 20} 31H${tip}m${-direction * 9} -7 ${direction * 9} 7 ${-direction * 9} 7`} fill="none" stroke={phase === 1 ? '#b45309' : color} strokeWidth="4" strokeLinejoin="round" />}
               {direction === 0 && <circle cx={center} cy="31" r="4" fill={color} />}
             </g>;
@@ -99,8 +126,8 @@
         </svg>
       </div>
       <div className="grid grid-cols-2 gap-1 text-sm font-semibold tabular-nums">
-        <div className="rounded-md bg-indigo-50 px-2 py-1 text-indigo-900">A · {params.m1} kg<br />{phase === 1 ? `J: ${signed(result.impulse)} N·s` : `${signed(arrows[0])} m/s`}</div>
-        <div className="rounded-md bg-emerald-50 px-2 py-1 text-emerald-900">B · {params.m2} kg<br />{phase === 1 ? `J: ${signed(-result.impulse)} N·s` : `${signed(arrows[1])} m/s`}</div>
+        <div className="rounded-md bg-indigo-50 px-2 py-1 text-indigo-900">A · {COLLISION_OBJECTS[objectA]} · {params.m1} kg<br />{phase === 1 ? `J: ${signed(result.impulse)} N·s` : `${signed(arrows[0])} m/s`}</div>
+        <div className="rounded-md bg-emerald-50 px-2 py-1 text-emerald-900">B · {COLLISION_OBJECTS[objectB]} · {params.m2} kg<br />{phase === 1 ? `J: ${signed(-result.impulse)} N·s` : `${signed(arrows[1])} m/s`}</div>
       </div>
       <p className="text-xs leading-snug text-slate-700 sm:text-sm" aria-live="polite">{messages[phase]} {phase === 2 && `Total momentum: ${result.momentumBefore} → ${result.momentumAfter} kg·m/s. Kinetic energy: ${result.keBefore} → ${result.keAfter} J.`}</p>
     </section>
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
echo 'Collision object choices added.'
