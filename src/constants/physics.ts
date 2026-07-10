export const PHYSICS_CONSTANTS = {
  GRAVITY: 9.81,
  AIR_DENSITY: 1.225,
  CANVAS_SCALE: 50,
} as const;

export const SIMULATION_TOPICS = {
  projectile_motion: {
    label: 'Projectile motion',
    defaultParams: { initialVelocity: 20, angle: 45, gravity: 9.81, mass: 1 },
    paramLabels: {
      initialVelocity: { label: 'Initial velocity', unit: 'm/s', min: 1, max: 100 },
      angle: { label: 'Launch angle', unit: '°', min: 1, max: 89 },
      gravity: { label: 'Gravity', unit: 'm/s²', min: 1, max: 25 },
      mass: { label: 'Mass', unit: 'kg', min: 0.1, max: 100 },
    },
  },
  newtons_second_law: {
    label: "Newton's second law",
    defaultParams: { mass: 5, force: 20, friction: 0.1 },
    paramLabels: {
      mass: { label: 'Mass', unit: 'kg', min: 0.5, max: 50 },
      force: { label: 'Applied force', unit: 'N', min: 1, max: 200 },
      friction: { label: 'Friction coefficient', unit: '', min: 0, max: 1 },
    },
  },
} as const;

export const WAEC_TOPICS = [
  'Projectile motion',
  "Newton's laws of motion",
  'Simple harmonic motion',
  "Ohm's law and circuits",
  'Refraction and lenses',
  'Wave interference',
] as const;
