export type Subject = 'Physics' | 'Chemistry' | 'Biology' | 'Mathematics';
export type Lesson = {
  id: string; subject: Subject; title: string; objective: string;
  explanation: string; example: string; investigation: string;
  resource?: { title: string; href: string };
  question: string; options: string[]; correct: number; hint: string; solution: string;
};
export const lessons: Lesson[] = [
  { id: 'projectiles', subject: 'Physics', title: 'Projectile motion',
    objective: 'Explain how launch angle changes the horizontal range.',
    explanation: 'A projectile has horizontal and vertical motion at the same time. Ignoring air resistance, horizontal velocity is constant and vertical acceleration is downward at g. For launch and landing at the same height, R = u² sin(2θ) / g. Under these assumptions, 45° gives the greatest range.',
    example: 'For u = 20 m/s, θ = 45° and g = 10 m/s²: R = (20² × sin 90°) / 10 = 40 m. The initial vertical speed is 20 sin 45° ≈ 14.14 m/s.',
    investigation: 'Predict whether 30° or 60° gives the greater range. Open the projectile simulation, set the same initial speed and gravity, and compare both angles. Keep launch and landing heights equal and neglect air resistance.',
    resource: { title: 'Open projectile motion', href: '/simulations/projectile-motion' },
    question: 'With equal launch and landing heights and no air resistance, which angle gives maximum range at a fixed speed?',
    options: ['30°', '45°', '60°', '90°'], correct: 1,
    hint: 'The range depends on sin(2θ). When does this sine reach 1?',
    solution: '45° is correct: sin(2 × 45°) = sin 90° = 1. This result assumes fixed speed, equal heights and no air resistance.' },
  { id: 'compounds', subject: 'Chemistry', title: 'Elements and compounds',
    objective: 'Distinguish an element from a compound and interpret a chemical formula.',
    explanation: 'An element contains atoms with the same proton number. A compound contains atoms of different elements chemically bonded in a fixed ratio. A subscript counts atoms in a formula: H₂O contains hydrogen and oxygen in a 2:1 ratio. O₂ is an elemental molecule, not a compound.',
    example: 'H₂O has two hydrogen atoms and one oxygen atom per molecule. Its approximate molar mass is 2(1.008) + 15.999 = 18.015 g/mol. NaCl is an ionic compound: its formula describes a ratio, not a discrete molecule.',
    investigation: 'Open the compound builder. Assemble H₂O and compare its formula and molar mass with CO₂. A formula assembled in a playground is a candidate composition; it does not by itself prove chemical stability or existence.',
    resource: { title: 'Open compound builder', href: '/chemistry/compound-builder' },
    question: 'Which formula represents a compound rather than an element?',
    options: ['O₂', 'Fe', 'H₂O', 'N₂'], correct: 2,
    hint: 'Look for a formula containing two different element symbols.',
    solution: 'H₂O contains hydrogen and oxygen chemically bonded. O₂ and N₂ contain only one element each; Fe is iron.' },
  { id: 'photosynthesis', subject: 'Biology', title: 'Photosynthesis',
    objective: 'Identify the inputs, products and limiting factors of photosynthesis.',
    explanation: 'Photosynthesis uses light energy to make carbohydrates from carbon dioxide and water. In plants it occurs in chloroplasts. A simplified net equation is 6CO₂ + 6H₂O → C₆H₁₂O₆ + 6O₂, using light and chlorophyll. Light intensity, carbon dioxide availability and temperature can limit the rate.',
    example: 'A plant receives enough light and a suitable temperature, but very little CO₂. Increasing light alone may have little effect because CO₂ is limiting. Increasing the limiting input can increase the rate until another factor limits it.',
    investigation: 'Thought experiment: compare identical plants with low and high CO₂ while keeping light, water and temperature constant. Predict the result and explain what should be controlled. This is a guided activity; this version has no Biology simulation.',
    question: 'Which gas supplies the carbon used to make carbohydrates during photosynthesis?',
    options: ['Oxygen', 'Nitrogen', 'Carbon dioxide', 'Hydrogen'], correct: 2,
    hint: 'Look at the carbon-containing reactant in the photosynthesis equation.',
    solution: 'Carbon dioxide supplies carbon for carbohydrate formation. Oxygen is released during photosynthesis; plants also respire.' },
  { id: 'trigonometry', subject: 'Mathematics', title: 'Sine and cosine',
    objective: 'Relate sine and cosine to coordinates on the unit circle.',
    explanation: 'The unit circle has radius 1. A point at angle θ measured anticlockwise from the positive x-axis has coordinates (cos θ, sin θ). Thus cosine gives the horizontal coordinate and sine gives the vertical coordinate. The identity sin²θ + cos²θ = 1 follows from Pythagoras.',
    example: 'At 30°, (cos 30°, sin 30°) = (√3/2, 1/2). A velocity of 20 m/s at 30° has horizontal component 20 cos 30° ≈ 17.32 m/s and vertical component 20 sin 30° = 10 m/s.',
    investigation: 'Open the unit circle explorer. Compare 30°, 90°, 150° and 270°. Record the signs of sine and cosine in each quadrant, then explain why sin 30° = sin 150°.',
    resource: { title: 'Open unit circle explorer', href: '/mathematics/unit-circle' },
    question: 'What is sin 30°?', options: ['0', '1/2', '√3/2', '1'], correct: 1,
    hint: 'Sine is the y-coordinate on the unit circle. At 30° that coordinate is half the radius.',
    solution: 'sin 30° = 1/2. cos 30° = √3/2. Be careful to use degrees for this question.' }
];
