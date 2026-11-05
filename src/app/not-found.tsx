import Link from 'next/link';
import { AppHeader } from '@/components/layout/AppHeader';

export default function NotFound() {
  return (
    <div className="min-h-screen bg-gray-50 text-gray-900">
      <AppHeader />

      <main className="mx-auto flex max-w-3xl flex-col items-center px-4 py-20 text-center sm:py-28">
        <p className="text-sm font-semibold uppercase tracking-widest text-indigo-600">
          A-Factor STEM Studio
        </p>

        <p
          aria-hidden="true"
          className="mt-6 text-8xl font-extrabold tracking-tight text-indigo-600 sm:text-9xl"
        >
          404
        </p>

        <h1 className="mt-6 text-3xl font-bold sm:text-4xl">
          Page not found
        </h1>

        <p className="mt-4 max-w-md text-base leading-7 text-gray-600">
          This page may have moved, or the link may be incorrect.
          Let’s get you back to exploring.
        </p>

        <nav
          aria-label="Page recovery"
          className="mt-8 flex w-full flex-col justify-center gap-3 sm:w-auto sm:flex-row"
        >
          <Link
            href="/"
            className="rounded-xl bg-indigo-600 px-6 py-3 font-medium text-white hover:bg-indigo-700 focus-visible:outline-2 focus-visible:outline-offset-4 focus-visible:outline-indigo-600"
          >
            Back to Home
          </Link>

          <Link
            href="/explore"
            className="rounded-xl border border-gray-300 bg-white px-6 py-3 font-medium text-gray-900 hover:bg-gray-100 focus-visible:outline-2 focus-visible:outline-offset-4 focus-visible:outline-indigo-600"
          >
            Explore Topics
          </Link>

          <Link
            href="/simulations"
            className="rounded-xl border border-gray-300 bg-white px-6 py-3 font-medium text-gray-900 hover:bg-gray-100 focus-visible:outline-2 focus-visible:outline-offset-4 focus-visible:outline-indigo-600"
          >
            Simulations
          </Link>
        </nav>
      </main>
    </div>
  );
}