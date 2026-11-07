import Link from 'next/link';
import { AppHeader } from '@/components/layout/AppHeader';
import { topics } from '@/lib/explorer/catalog';
import { SUBJECTS } from '@/lib/subjects';

export const metadata = { title: 'Explore STEM simulations | A-Factor STEM Studio' };

const groups = [
  ...SUBJECTS.filter(subject => subject.status === 'live'),
  { slug: 'geophysics', label: 'Geophysics', href: '/geophysics', icon: '🌍', description: 'Earth, space and field methods' },
].map(subject => ({
  ...subject,
  simulations: topics.filter(topic => !topic.protected && topic.subject === subject.label),
})).filter(group => group.simulations.length > 0);

export default function StemCatalog() {
  return (
    <>
      <AppHeader />
      <main className="mx-auto max-w-7xl px-4 py-5 text-gray-900 sm:px-6 sm:py-8">
        <h1 className="text-2xl font-bold tracking-tight sm:text-4xl">Explore STEM simulations</h1>
        <p className="mt-2 max-w-2xl text-sm leading-relaxed text-gray-600">
          Choose a subject, then open a simulation to test an idea, change a variable or work through a classroom activity.
        </p>
        <nav aria-label="Jump to a subject" className="mt-4 flex flex-wrap gap-2">
          {groups.map(group => (
            <a key={group.slug} href={`#${group.slug}`}
              className="inline-flex min-h-10 items-center rounded-lg border border-indigo-100 bg-indigo-50 px-3 text-sm font-medium text-indigo-800">
              <span aria-hidden="true" className="mr-2">{group.icon}</span>{group.label}
            </a>
          ))}
        </nav>

        <div className="mt-5 space-y-5">
          {groups.map(group => (
            <section key={group.slug} id={group.slug} className="scroll-mt-20 rounded-xl border border-gray-200 bg-white p-3 sm:p-4">
              <div className="flex flex-wrap items-center justify-between gap-2">
                <h2 className="text-lg font-semibold">{group.label}</h2>
                <Link href={group.href} className="text-sm font-medium text-indigo-700 hover:underline">
                  {group.label} hub →
                </Link>
              </div>
              <p className="mt-1 text-sm text-gray-600">{group.description}</p>
              <ul className="mt-3 grid gap-2 sm:grid-cols-2 lg:grid-cols-3">
                {group.simulations.map(simulation => (
                  <li key={simulation.id}>
                    <Link href={simulation.route} className="flex min-h-11 items-center rounded-lg bg-gray-50 px-3 py-2 text-sm font-medium text-gray-800 hover:bg-indigo-50 hover:text-indigo-800">
                      {simulation.title}
                    </Link>
                  </li>
                ))}
              </ul>
            </section>
          ))}
        </div>
        <p className="mt-5 text-sm text-gray-600">
          Open the <Link href="/minitab" className="font-semibold text-indigo-700 hover:underline">student classroom</Link> for simulations that require sign-in.
        </p>
      </main>
    </>
  );
}
