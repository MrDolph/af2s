import type { Metadata } from 'next';
import { AppHeader } from '@/components/layout/AppHeader';

export const metadata: Metadata = {
  title: 'Geophysics & Earth Science | A-Factor STEM Studio',
  description: 'Interactive geophysics experiments, Earth, Solar System and plate tectonics for AUI-PHY 407.',
};
const modules = [
  { title: 'Geophysics field lab', href: '/geophysics/index.html', icon: '📈', description: 'Gravity contours, resistivity, seismic arrivals, electromagnetic attenuation and well logging.' },
  { title: 'Earth Explorer', href: '/geophysics/earth.html', icon: '🌍', description: 'Rotate, open and peel the Earth. Explore its interior and atmosphere from the inner core to the exosphere.' },
  { title: 'Solar System Explorer', href: '/geophysics/solar.html', icon: '☀️', description: 'Compare inner and outer planets, follow nebular formation and investigate Kepler’s laws.' },
  { title: 'Tectonics & Earth’s shape', href: '/geophysics/tectonics.html', icon: '🧩', description: 'World plates, continental drift, plate margins, VMM stripes, triple junctions and hydrostatic flattening.' },
];
export default function GeophysicsPage() {
  return <><AppHeader /><main className="min-h-screen bg-gray-50">
    <section className="border-b border-gray-200 bg-white"><div className="mx-auto max-w-6xl px-4 py-12 sm:px-6">
      <p className="text-xs font-semibold uppercase tracking-widest text-emerald-700">AUI-PHY 407 · Undergraduate</p>
      <h1 className="mt-3 text-3xl font-semibold tracking-tight text-gray-900">Geophysics & Earth Science</h1>
      <p className="mt-4 max-w-3xl text-base leading-7 text-gray-600">See the model, predict the response, take measurements and explain what you observe. Explore the Earth and its planetary context through guided experiments and independent practice.</p>
    </div></section>
    <section className="mx-auto grid max-w-6xl gap-6 px-4 py-10 sm:grid-cols-2 sm:px-6" aria-label="Geophysics learning modules">
      {modules.map(module => <a key={module.href} href={module.href} className="rounded-2xl border border-gray-200 bg-white p-7 transition hover:border-emerald-400 hover:shadow-md focus-visible:outline-2 focus-visible:outline-offset-4 focus-visible:outline-emerald-700">
        <span aria-hidden="true" className="text-3xl">{module.icon}</span><h2 className="mt-4 text-xl font-semibold text-gray-900">{module.title}</h2>
        <p className="mt-3 text-sm leading-6 text-gray-600">{module.description}</p><span className="mt-6 inline-block text-sm font-semibold text-emerald-700">Open explorer →</span>
      </a>)}
    </section>
    <p className="mx-auto max-w-6xl px-4 pb-10 text-xs leading-6 text-gray-500 sm:px-6">Prepared for Mr Dawodu O.F.’s geophysics lectures. Model assumptions and references are included in each explorer. Practice progress is stored on the current browser.</p>
  </main></>;
}
