import Link from 'next/link';
import { AppHeader } from '@/components/layout/AppHeader';
import { lessons } from '@/lib/biology/lessons';

export const metadata = { title: 'Biology simulations | A-Factor STEM Studio' };

const TOPIC_STYLE: Record<string, { icon: string; category: string }> = {
  'skeletal-system': { icon: '🦴', category: 'Human biology' },
  cells: { icon: '🔬', category: 'Cell biology' },
  mitosis: { icon: '🧬', category: 'Cell division' },
  meiosis: { icon: '🧬', category: 'Cell division' },
  transpiration: { icon: '🌿', category: 'Plant biology' },
  classification: { icon: '🗂️', category: 'Classification' },
  'life-processes': { icon: '🌱', category: 'Foundations' },
};

export default function BiologyHub() {
  const cards = [
    { slug: 'skeletal-system', title: 'Human skeletal system', intro: 'Explore major bones, axial and appendicular divisions, and identification challenges.' },
    ...Object.entries(lessons).map(([slug, lesson]) => ({ slug, title: lesson.title, intro: lesson.intro })),
  ];

  return (
    <div className="min-h-screen bg-gray-50 text-gray-900">
      <AppHeader />
      <main className="mx-auto max-w-7xl px-4 py-8 sm:px-6">
        <p className="text-sm font-semibold text-teal-700">A-Factor STEM Studio · Biology</p>
        <h1 className="mt-2 text-3xl font-semibold">Explore living systems</h1>
        <p className="my-4 max-w-2xl text-sm leading-7 text-gray-600">
          Interactive models, classroom challenges, teacher guidance and student practice. Expand any activity for a classroom demonstration.
        </p>
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4">
          {cards.map(card => {
            const style = TOPIC_STYLE[card.slug] ?? { icon: '🔬', category: 'Biology' };
            return (
              <div key={card.slug} className="group relative overflow-hidden rounded-2xl border border-gray-200 bg-white transition hover:border-indigo-300 hover:shadow-md focus-within:border-indigo-300 focus-within:shadow-md">
                <div className="pointer-events-none absolute right-3 top-3 flex items-center gap-1">
                  <span aria-hidden="true" className="h-1.5 w-1.5 rounded-full bg-emerald-500" />
                  <span className="text-[10px] font-medium text-emerald-600">Live</span>
                </div>
                <Link href={'/biology/' + card.slug} className="block h-full rounded-2xl focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600">
                  <div className="p-5">
                    <div className="mb-3 flex items-center gap-2 pr-12">
                      <span aria-hidden="true" className="text-2xl">{style.icon}</span>
                      <span className="text-[10px] font-medium uppercase tracking-wide text-gray-400">{style.category}</span>
                    </div>
                    <h2 className="mb-1.5 text-sm font-semibold text-gray-900 transition group-hover:text-indigo-700">{card.title}</h2>
                    <p className="mb-3 text-xs leading-relaxed text-gray-500">{card.intro}</p>
                    <div className="flex flex-wrap gap-1.5">
                      <span className="rounded-full bg-indigo-100 px-2 py-0.5 text-[10px] font-medium text-indigo-700">Interactive</span>
                      <span className="rounded-full bg-emerald-100 px-2 py-0.5 text-[10px] font-medium text-emerald-700">Teacher &amp; student</span>
                    </div>
                  </div>
                </Link>
              </div>
            );
          })}
        </div>
      </main>
    </div>
  );
}
