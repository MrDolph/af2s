import { AppHeader } from '@/components/layout/AppHeader';
import { PromptBar } from '@/components/ai/PromptBar';
import { topics } from '@/lib/explorer/catalog';
export const metadata={title:'Topic explorer | A-Factor STEM Studio'};
export default function ExplorePage(){return <div style={{background:'#f1f5f9',minHeight:'100vh',color:'#111827',colorScheme:'light'}}><AppHeader/><main className="mx-auto max-w-6xl px-4 py-10 sm:px-6"><p className="text-xs font-semibold uppercase tracking-widest text-indigo-700">A-Factor STEM Studio</p><h1 className="mt-2 text-3xl font-semibold">Explore all {topics.length} topics</h1><p className="mb-7 mt-3 max-w-2xl text-sm leading-7 text-gray-700">Physics, Chemistry, Mathematics and Geophysics. Select an existing activity, prepare supported controls, and read a topic-specific explanation without a paid AI API.</p><PromptBar/></main></div>;}
