'use client';

import { useEffect, useEffectEvent, useRef, useState } from 'react';
import { type CollisionParams, solveCollision } from '@/lib/physics/consequences';

const APPROACH = 1.6;
const CONTACT = 1;
const DEPARTURE = 1.5;
const RELEASE = APPROACH + CONTACT;
const END = RELEASE + DEPARTURE;
const BLOCK = 72;

function signed(value: number) {
  return `${value > 0 ? '+' : ''}${Number(value.toFixed(2))}`;
}

export const COLLISION_OBJECTS = {
  block: 'Block',
  trolley: 'Trolley',
  car: 'Toy car',
  truck: 'Toy pickup truck',
  lorry: 'Toy lorry',
} as const;

export type CollisionObject = keyof typeof COLLISION_OBJECTS;

// Each silhouette spans the same contact width as the original block.
const VEHICLE_BODIES = {
  trolley: 'M0 76H72V99H0Z M0 76V63H5V76Z',
  car: 'M0 81H9L21 66H47L60 81H72V99H0Z',
  truck: 'M0 79H32V65H53L64 78H72V99H0Z',
  lorry: 'M0 60H43V83H47V68H61L72 81V99H0Z',
};

export function CollisionCanvas({ params, isRunning, isPaused, onComplete, objectA = 'block', objectB = 'block' }: {
  params: CollisionParams;
  objectA?: CollisionObject;
  objectB?: CollisionObject;
  isRunning: boolean;
  isPaused: boolean;
  onComplete: () => void;
}) {
  const [time, setTime] = useState(0);
  const elapsed = useRef(0);
  const complete = useEffectEvent(onComplete);
  const closing = params.u1 > params.u2;
  const sticks = params.type === 'perfectly-inelastic';
  const result = solveCollision(params);
  const end = closing ? END : APPROACH;

  useEffect(() => {
    if (!isRunning || isPaused) return;
    let frame: number;
    let previous: number | undefined;
    function advance(now: number) {
      if (previous !== undefined) elapsed.current = Math.min(end, elapsed.current + Math.min(0.05, (now - previous) / 1000));
      previous = now;
      setTime(elapsed.current);
      if (elapsed.current < end) frame = requestAnimationFrame(advance);
      else complete();
    }
    frame = requestAnimationFrame(advance);
    return () => cancelAnimationFrame(frame);
  }, [end, isRunning, isPaused]);

  const phase = !closing || time < APPROACH ? 0 : time < RELEASE ? 1 : 2;
  const [u1, u2] = [params.u1, params.u2];
  // Derive exact velocities for positioning so even a small rebound separates.
  const e = sticks ? 0 : params.type === 'elastic' ? 1 : params.e ?? 0.5;
  const centerVelocity = (params.m1 * u1 + params.m2 * u2) / (params.m1 + params.m2);
  const separation = e * (u1 - u2);
  const v1 = centerVelocity - separation * params.m2 / (params.m1 + params.m2);
  const v2 = centerVelocity + separation * params.m1 / (params.m1 + params.m2);
  const gap = closing ? (u1 - u2) * APPROACH : Math.max(4, Math.abs(u1 - u2));
  const contact = u1 * APPROACH;
  const final = closing ? [contact + v1 * DEPARTURE, contact + v2 * DEPARTURE] : [u1 * APPROACH, gap + u2 * APPROACH];
  const left = Math.min(0, gap, contact, ...final);
  const right = Math.max(0, gap, contact, ...final);
  // Fit the entire demonstration once. The track and bodies never zoom during playback.
  const scale = 310 / Math.max(1, right - left);
  const offset = (480 - BLOCK * 2 - (right - left) * scale) / 2;
  const approach = Math.min(time, APPROACH);
  const depart = Math.max(0, time - RELEASE);
  const x1 = offset + ((phase === 2 ? contact + v1 * depart : u1 * approach) - left) * scale;
  const x2 = offset + BLOCK + ((phase === 2 ? contact + v2 * depart : gap + u2 * approach) - left) * scale;
  const messages = [
    closing ? 'The gap closes because A’s signed velocity is greater than B’s.' : 'The gap cannot close. Set A’s velocity greater than B’s to see an impact.',
    'Contact is slowed for illustration. The arrows show the equal and opposite impulses that change the bodies’ momenta.',
    sticks ? 'The bodies remain joined and move with a common velocity.' : 'The bodies separate. The arrows show their final directions of motion.',
  ];
  const arrows = phase === 1 ? [result.impulse, -result.impulse] : phase === 2 ? [v1, v2] : [u1, u2];

  return (
    <section className="af-collision-demo flex min-w-0 flex-col gap-2 rounded-xl border border-slate-300 bg-white p-2 sm:p-3" aria-label="Collision demonstration">
      <ol className="grid grid-cols-3 gap-1 text-center text-xs font-semibold sm:text-sm" aria-label="Collision stages">
        {['Before impact', 'During impact', 'After impact'].map((label, index) => (
          <li key={label} aria-current={index === phase ? 'step' : undefined}
            className={`rounded-md border px-1 py-1 ${index === phase ? 'border-indigo-700 bg-indigo-700 text-white' : 'border-slate-200 bg-slate-50 text-slate-700'}`}>
            {index + 1}. {label}
          </li>
        ))}
      </ol>
      <div className="af-collision-track flex min-h-0 flex-1 items-center justify-center rounded-lg bg-slate-50">
        <svg viewBox="0 0 480 128" className="block max-h-full w-full" role="img" aria-label="Body A starts left of body B. Arrows indicate direction.">
          <path d="M0 112H480" stroke="#64748b" strokeWidth="2" />
          {phase === 1 && <path d={`M${x2} 38v77`} stroke="#d97706" strokeWidth="10" />}
          {[x1, x2].map((x, i) => {
            const object = i === 0 ? objectA : objectB;
            const color = i === 0 ? '#4338ca' : '#047857';
            const center = x + BLOCK / 2;
            const direction = Math.sign(arrows[i]);
            const tip = center + direction * 26;
            return <g key={i}>
              {object === 'block' ? <rect x={x} y="55" width={BLOCK} height="56" rx={phase === 1 || (phase === 2 && sticks) ? 0 : 7} fill={color} /> : (
                <g transform={`translate(${x} 0)${(i === 0 ? u1 : u2) < 0 ? ` translate(${BLOCK} 0) scale(-1 1)` : ''}`}>
                  <path d={VEHICLE_BODIES[object]} fill={color} />
                  <circle cx="15" cy="103" r="8" fill="#1e293b" />
                  <circle cx="57" cy="103" r="8" fill="#1e293b" />
                </g>
              )}
              <text x={center} y="92" fill="white" fontSize={object === 'block' ? 25 : 15} fontWeight="700" textAnchor="middle">{i === 0 ? 'A' : 'B'}</text>
              {direction !== 0 && <path d={`M${center - direction * 20} 31H${tip}m${-direction * 9} -7 ${direction * 9} 7 ${-direction * 9} 7`} fill="none" stroke={phase === 1 ? '#b45309' : color} strokeWidth="4" strokeLinejoin="round" />}
              {direction === 0 && <circle cx={center} cy="31" r="4" fill={color} />}
            </g>;
          })}
        </svg>
      </div>
      <div className="grid grid-cols-2 gap-1 text-sm font-semibold tabular-nums">
        <div className="rounded-md bg-indigo-50 px-2 py-1 text-indigo-900">A · {COLLISION_OBJECTS[objectA]} · {params.m1} kg<br />{phase === 1 ? `J: ${signed(result.impulse)} N·s` : `${signed(arrows[0])} m/s`}</div>
        <div className="rounded-md bg-emerald-50 px-2 py-1 text-emerald-900">B · {COLLISION_OBJECTS[objectB]} · {params.m2} kg<br />{phase === 1 ? `J: ${signed(-result.impulse)} N·s` : `${signed(arrows[1])} m/s`}</div>
      </div>
      <p className="text-xs leading-snug text-slate-700 sm:text-sm" aria-live="polite">{messages[phase]} {phase === 2 && `Total momentum: ${result.momentumBefore} → ${result.momentumAfter} kg·m/s. Kinetic energy: ${result.keBefore} → ${result.keAfter} J.`}</p>
    </section>
  );
}
