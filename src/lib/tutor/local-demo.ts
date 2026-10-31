import data from './translation-data.json';
import { lessons, type Lesson } from './lessons';
export const languages = ['en', 'yo', 'ha', 'ig'] as const;
export type Language = typeof languages[number];
export type DemoIntent = 'explain' | 'example' | 'activity' | 'hint' | 'solution';
export function isLanguage(value: unknown): value is Language { return languages.some(l => l === value); }
export function strings(language: Language) { return data[language].ui; }
export function languageName(language: Language) { return data[language].name; }
export function localizedLesson(id: string, language: Language): Lesson {
  const base = lessons.find(l => l.id === id) || lessons[0];
  if (language === 'en') return base;
  const translations = data[language].lessons;
  const copy = translations[base.id as keyof typeof translations];
  return { ...base, ...copy };
}
export function normalize(text: string) {
  return text.normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase().replace(/[^a-z0-9\s]/g, ' ').replace(/\s+/g, ' ').trim();
}
const patterns: [DemoIntent, string[]][] = [
  ['hint', ['hint', 'clue', 'iṭoniṣona', 'itọnisọna', 'alamar taimako', 'ntuziaka']],
  ['example', ['example', 'apẹẹrẹ', 'apere', 'misali', 'ihe atụ', 'ihe atu']],
  ['activity', ['activity', 'simulation', 'investigation', 'experiment', 'ise', 'aiki', 'nnwale', 'oru']],
  ['solution', ['solution', 'answer', 'idahun', 'ojutu', 'amsa', 'mafita', 'aziza', 'ngwota']],
  ['explain', ['explain', 'explanation', 'salaye', 'alaye', 'bayyana', 'bayani', 'kowaa', 'nkọwa', 'nkowa']],
];
// Whole phrases only: the demo does not pretend to solve unfamiliar questions.
export function detectIntent(question: string): DemoIntent | null {
  const text = ' ' + normalize(question) + ' ';
  for (const [intent, phrases] of patterns) if (phrases.some(p => text.includes(' ' + normalize(p) + ' '))) return intent;
  return null;
}
export function demoAnswer(id: string, language: Language, intent: DemoIntent | null): string {
  const lesson = localizedLesson(id, language);
  if (intent === 'explain') return lesson.explanation;
  if (intent === 'example') return lesson.example;
  if (intent === 'activity') return lesson.investigation;
  if (intent === 'hint') return lesson.hint;
  if (intent === 'solution') return lesson.solution;
  return strings(language).fallback;
}
