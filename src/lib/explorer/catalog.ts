import data from './topics-data.json';
export type Language = 'en' | 'yo' | 'ha' | 'ig';
export type Parameter = { key: string; label: string; unit: string; min: number; max: number; default: number; integer?:boolean };
export type Topic = { id: string; route: string; subject: string; title: string; description: string; principle: string; concept: string; aliases: string[]; parameters: Parameter[]; modes: { key: string; default: string; options: string[] }[]; protected: boolean };
export const topics: Topic[] = data;
export function getTopic(id: string) { return topics.find(t => t.id === id); }
export function isLanguage(value: unknown): value is Language { return ['en','yo','ha','ig'].includes(value as string); }
export function normalize(text: string) { return text.normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase().replace(/[^a-z0-9]+/g, ' ').trim(); }
