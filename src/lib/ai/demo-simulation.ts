import type { AIPromptRequest, AIPromptResponse } from '@/types/ai';
export class DemoPromptError extends Error { readonly status = 422; }
type Lang = 'en' | 'yo' | 'ha' | 'ig';
const copy = {
  en: {
    title: 'Free demo · Projectile motion',
    description: 'Projectile parameters read from supported text patterns, without an AI service.',
    note: 'Free rule-based demo, not generative AI. Ignoring air resistance, horizontal velocity is constant and gravity accelerates the projectile downward. Unspecified values use the defaults shown below. Launch and landing are at equal heights.',
    values: 'Parameters', defaults: 'Defaults used', none: 'none',
    unsupported: 'This free homepage demo supports projectile motion only. Try: "Show projectile motion at 45° and 30 m/s". Open the simulations catalogue for other topics.',
    numbers: 'Some numbers could not be interpreted, or a parameter was repeated. Use explicit units: 30 m/s, 45°, gravity 9.81 m/s², mass 1 kg.',
    range: 'Use speed 1–100 m/s, angle 1–89°, gravity 1–25 m/s² and mass 0.1–100 kg, matching the homepage controls.',
    planet: 'For another planet or the Moon, specify gravity numerically (for example: gravity 2 m/s²). The demo does not infer planetary gravity.',
  },
  yo: {
    title: 'Àpẹẹrẹ ọ̀fẹ́ · Projectile motion',
    description: 'A ka àwọn iye projectile láti inú àpẹẹrẹ ọ̀rọ̀, láìlo iṣẹ́ AI.',
    note: 'Àpẹẹrẹ tó ń lo òfin ni èyí; kì í ṣe AI tó ń dá ìdáhùn tuntun. Láìka ìdènà afẹ́fẹ́ sí, velocity petele kì í yí padà; gravity ń fa ohun náà sísàlẹ̀. Bí o kò bá sọ iye kan, a lo iye àkọ́kọ́ tó wà nísàlẹ̀. Ibi ìfilọ́lẹ̀ àti ibi ìbalẹ̀ ga bákan náà.',
    values: 'Àwọn iye', defaults: 'Iye àkọ́kọ́ tí a lò', none: 'kò sí',
    unsupported: 'Àpẹẹrẹ ọ̀fẹ́ ojú ìwé yìí ń ṣe projectile motion nìkan. Gbìyànjú: "Ṣe afihan projectile ni 45° ati 30 m/s". Ṣí àkójọ simulation fún kókó mìíràn.',
    numbers: 'A kò lè túmọ̀ díẹ̀ nínú àwọn nọ́mbà, tàbí o tún iye kan sọ. Lo unit kedere: 30 m/s, 45°, gravity 9.81 m/s², mass 1 kg.',
    range: 'Lo speed 1–100 m/s, igun 1–89°, gravity 1–25 m/s² àti mass 0.1–100 kg, gẹ́gẹ́ bí àwọn controls ojú ìwé.',
    planet: 'Fún planet mìíràn tàbí Òṣùpá, kọ iye gravity pẹ̀lú nọ́mbà. Àpẹẹrẹ yìí kò lè mọ gravity planet fúnra rẹ̀.',
  },
  ha: {
    title: 'Samfurin kyauta · Projectile motion',
    description: 'Ana karanta ma’aunin projectile daga tsarin rubutu ba tare da sabis na AI ba.',
    note: 'Wannan samfurin yana amfani da ƙa’idoji; ba AI mai samar da sabbin amsoshi ba ne. Ba tare da juriyar iska ba, gudun kwance ba ya sauyawa, gravity kuma yana hanzarta abin zuwa ƙasa. Abin da ba ka bayyana ba yana amfani da ma’aunin farko da aka nuna a ƙasa. Tsayin farawa da na sauka ɗaya ne.',
    values: 'Ma’aunai', defaults: 'Ma’aunin farko da aka yi amfani da shi', none: 'babu',
    unsupported: 'Wannan samfurin shafin farko yana goyon bayan projectile motion kawai. Gwada: "Nuna projectile a 45° da 30 m/s". Buɗe jerin simulations don sauran batutuwa.',
    numbers: 'An kasa fahimtar wasu lambobi, ko an maimaita ma’auni. Yi amfani da units: 30 m/s, 45°, gravity 9.81 m/s², mass 1 kg.',
    range: 'Yi amfani da gudu 1–100 m/s, kusurwa 1–89°, gravity 1–25 m/s² da mass 0.1–100 kg, kamar controls na shafin.',
    planet: 'Don wata duniya ko Wata, ka rubuta gravity da lamba. Wannan samfurin ba ya gano gravity na duniya da kansa.',
  },
  ig: {
    title: 'Ihe ngosi efu · Projectile motion',
    description: 'A na-agụ ụkpụrụ projectile site n’usoro ederede na-enweghị ọrụ AI.',
    note: 'Ihe ngosi a na-eji iwu edoziri; ọ bụghị AI na-emepụta azịza ọhụrụ. Mgbe mgbochi ikuku adịghị, velocity kwụ ọtọ n’ala anaghị agbanwe; gravity na-eme ka ihe ahụ gaa ala ngwa ngwa. Ihe ị na-akọwaghị na-eji ụkpụrụ mbido e depụtara n’okpuru. Ebe mbido na ebe ọdịda nọ n’otu ịdị elu.',
    values: 'Ụkpụrụ', defaults: 'Ụkpụrụ mbido e ji mee ihe', none: 'ọ dịghị',
    unsupported: 'Ihe ngosi efu na peeji a na-akwado naanị projectile motion. Gbalịa: "Gosi projectile na 45° na 30 m/s". Mepee ndepụta simulations maka ihe ndị ọzọ.',
    numbers: 'Aghọtaghị ụfọdụ ọnụọgụ, ma ọ bụ i degharịrị otu ụkpụrụ. Jiri units doro anya: 30 m/s, 45°, gravity 9.81 m/s², mass 1 kg.',
    range: 'Jiri speed 1–100 m/s, nkuku 1–89°, gravity 1–25 m/s² na mass 0.1–100 kg, dịka controls dị na peeji a.',
    planet: 'Maka planet ọzọ ma ọ bụ Ọnwa, dee gravity n’ọnụọgụ. Ihe ngosi a anaghị achọpụta gravity planet n’onwe ya.',
  },
};
export function parseDemoSimulation(request: AIPromptRequest): AIPromptResponse & { mode: 'demo' } {
  if (request.language && !['en', 'yo', 'ha', 'ig'].includes(request.language)) throw new DemoPromptError('The free demo supports English, Yoruba, Hausa and Igbo.');
  const language = (request.language || 'en') as Lang;
  const c = copy[language];
  const text = request.prompt.normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase();
  if (!/\b(projectile|projectiles)\b/.test(text) || /\b(newton|ohm|circuit|circular|pendulum|wave|friction|wind|drag|resistance)\b/.test(text)) throw new DemoPromptError(c.unsupported);
  const params = { initialVelocity: 20, angle: 45, gravity: 9.81, mass: 1 };
  type Key = keyof typeof params;
  const specified = new Set<Key>();
  let remaining = text;
  const number = '([-+]?(?:\\d+(?:\\.\\d*)?|\\.\\d+)(?:e[-+]?\\d+)?)';
  function read(key: Key, expression: string) {
    remaining = remaining.replace(new RegExp(expression, 'g'), (whole, value: string) => {
      if (specified.has(key)) throw new DemoPromptError(c.numbers);
      const n = Number(value); if (!Number.isFinite(n)) throw new DemoPromptError(c.numbers);
      params[key] = n; specified.add(key); return ' '.repeat(whole.length);
    });
  }
  // Parse acceleration before speed, so m/s² is never interpreted as velocity.
  read('gravity', `(?:gravity|gravitational acceleration|g)\\s*(?:=|:|of|ni|a|na)?\\s*${number}\\s*(?:m\\s*\\/\\s*s(?:²|\\^2|2))?`);
  read('gravity', `${number}\\s*m\\s*\\/\\s*s(?:²|\\^\\s*2|2)`);
  read('initialVelocity', `${number}\\s*(?:m\\s*\\/\\s*s|mps|met(?:er|re)s? per second)(?![a-z0-9²^])`);
  read('initialVelocity', `(?:speed|velocity|gudu)\\s*(?:=|:|of|ni|a|na)?\\s*${number}(?![\\d.])`);
  read('angle', `${number}\\s*(?:°|degrees?|deg|digiri)(?![a-z])`);
  read('angle', `(?:angle|igun|kusurwa|nkuku)\\s*(?:=|:|of|ni|a|na)?\\s*${number}(?![\\d.])`);
  read('mass', `${number}\\s*(?:kg|kilograms?)(?![a-z])`);
  read('mass', `mass\\s*(?:=|:|of|ni|a|na)?\\s*${number}(?![\\d.])`);
  if (/\d/.test(remaining)) throw new DemoPromptError(c.numbers);
  if (/\b(moon|mars|venus|jupiter|mercury|saturn|uranus|neptune)\b/.test(text) && !specified.has('gravity')) throw new DemoPromptError(c.planet);
  if (params.initialVelocity < 1 || params.initialVelocity > 100 || params.angle < 1 || params.angle > 89 || params.gravity < 1 || params.gravity > 25 || params.mass < .1 || params.mass > 100) throw new DemoPromptError(c.range);
  const defaults = (Object.keys(params) as Key[]).filter(k => !specified.has(k));
  return {
    mode: 'demo', simulationType: 'projectile_motion', title: c.title,
    description: c.description, params,
    explanation: `${c.note}\n${c.values}: u = ${params.initialVelocity} m/s; θ = ${params.angle}°; g = ${params.gravity} m/s²; m = ${params.mass} kg. ${c.defaults}: ${defaults.length ? defaults.join(', ') : c.none}.`,
    suggestedFollowUps: [],
  };
}
