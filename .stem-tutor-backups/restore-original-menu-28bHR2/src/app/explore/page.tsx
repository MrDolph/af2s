import { AppHeader } from '@/components/layout/AppHeader';
import { PromptBar } from '@/components/ai/PromptBar';
import { topics } from '@/lib/explorer/catalog';
export const metadata={title:'Try AI | A-Factor STEM Studio'};
export default function ExplorePage(){return <div style={{background:'#f1f5f9',minHeight:'100vh',color:'#111827',colorScheme:'light'}}><AppHeader/><main className="af-explorer mx-auto min-w-0 max-w-6xl px-3 py-6 sm:px-6 sm:py-10"><p className="text-xs font-semibold uppercase tracking-widest text-indigo-700">A-Factor STEM Studio</p><h1 className="mt-2 text-3xl font-semibold">Understand a STEM concept</h1><p className="mb-7 mt-3 max-w-2xl text-sm leading-7 text-gray-700">Choose from {topics.length} existing topics to get a guided explanation, inspect a supported calculation and prepare a related simulation. This free demo uses rules and prepared content without a paid AI API.</p><PromptBar/></main></div>;}
