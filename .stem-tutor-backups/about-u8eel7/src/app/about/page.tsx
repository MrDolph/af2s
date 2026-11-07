import Image from 'next/image';
import Link from 'next/link';
import { AppHeader } from '@/components/layout/AppHeader';

export const metadata = { title: 'About | A-Factor STEM Studio' };

const portfolio = 'https://mrdof-portfolio.vercel.app/';

export default function AboutPage() {
  return (
    <>
      <AppHeader />
      <main className="mx-auto max-w-4xl space-y-5 px-4 py-5 text-gray-900 sm:px-6 sm:py-8">
        <section className="rounded-2xl border border-indigo-100 bg-indigo-50 p-4 sm:p-6">
          <p className="text-xs font-semibold uppercase tracking-wide text-indigo-700">A-Factor STEM Studio</p>
          <h1 className="mt-1 text-2xl font-bold tracking-tight sm:text-4xl">Learn STEM by doing</h1>
          <p className="mt-2 max-w-2xl text-sm leading-relaxed text-gray-700 sm:text-base">
            A-Factor brings interactive STEM learning to students and teachers, with African classrooms in mind.
            Change a variable, observe what happens and connect the result to the science or mathematics behind it.
          </p>
          <div className="mt-4 flex flex-wrap gap-2">
            <Link href="/stem" className="inline-flex min-h-11 items-center rounded-lg bg-indigo-700 px-4 text-sm font-semibold text-white hover:bg-indigo-800">
              Explore all simulations
            </Link>
            <Link href="/tutor" className="inline-flex min-h-11 items-center rounded-lg border border-indigo-200 bg-white px-4 text-sm font-semibold text-indigo-800">
              Open STEM Tutor
            </Link>
          </div>
        </section>

        <section aria-labelledby="learning-at-afactor">
          <h2 id="learning-at-afactor" className="text-lg font-semibold">What you can do</h2>
          <ul className="mt-2 grid gap-2 sm:grid-cols-2">
            <li className="rounded-xl border border-gray-200 bg-white p-3 text-sm leading-relaxed text-gray-700">
              <strong className="block text-gray-900">Explore across subjects</strong>
              Investigate atoms, cells, materials, Earth systems and mathematical relationships.
              Use circuit and materials simulations to connect scientific ideas to technology and engineering.
            </li>
            <li className="rounded-xl border border-gray-200 bg-white p-3 text-sm leading-relaxed text-gray-700">
              <strong className="block text-gray-900">Teach and practise</strong>
              Run classroom demonstrations, compare predictions with results and use worked examples and exercises where available.
            </li>
          </ul>
        </section>

        <details className="rounded-xl border border-gray-200 bg-white p-3">
          <summary className="cursor-pointer text-sm font-semibold">Curriculum and language support</summary>
          <p className="mt-2 text-sm leading-relaxed text-gray-600">
            Explore activities tagged for WAEC, NECO, IGCSE, JUPEB and SAT on the subject pages.
            The topic explorer offers English, Yorùbá, Hausa and Igbo options.
          </p>
        </details>

        <section aria-labelledby="founder-heading" className="flex items-start gap-3 rounded-xl border border-gray-200 bg-white p-3 sm:gap-4 sm:p-4">
          <Image src="/iamdof-avatar.jpg" alt="Fatai Olalekan Dawodu" width={64} height={64}
            className="h-14 w-14 shrink-0 rounded-full object-cover sm:h-16 sm:w-16" />
          <div className="min-w-0">
            <h2 id="founder-heading" className="text-base font-semibold">IamDOF 🕶</h2>
            <p className="text-sm text-gray-700">Fatai Olalekan Dawodu · Founder and educator</p>
            <p className="mt-1 text-sm leading-relaxed text-gray-600">
              I build A-Factor to make STEM easier to teach, explore and practise.
            </p>
            <a href={portfolio} className="mt-1 inline-flex min-h-10 items-center text-sm font-semibold text-indigo-700 hover:underline">
              View my portfolio →
            </a>
          </div>
        </section>
      </main>
    </>
  );
}
