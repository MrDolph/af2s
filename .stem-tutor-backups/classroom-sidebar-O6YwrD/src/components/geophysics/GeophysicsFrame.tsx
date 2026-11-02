import Link from 'next/link';
import { AppHeader } from '@/components/layout/AppHeader';

type ModuleName = 'lab' | 'earth' | 'solar' | 'tectonics';

const MODULES: { id: ModuleName; label: string; href: string }[] = [
  { id: 'lab', label: 'Geophysics lab', href: '/geophysics/lab' },
  { id: 'earth', label: 'Earth Explorer', href: '/geophysics/earth' },
  { id: 'solar', label: 'Solar System', href: '/geophysics/solar' },
  { id: 'tectonics', label: 'Tectonics & Earth’s shape', href: '/geophysics/tectonics' },
];

export function GeophysicsFrame({ active, src, title }: {
  active: ModuleName;
  src: string;
  title: string;
}) {
  return (
    <div style={{ height: '100dvh', minHeight: '28rem', display: 'flex', flexDirection: 'column', backgroundColor: '#f4f5f0', colorScheme: 'light', }}>
      <div className="shrink-0"><AppHeader /></div>
      <nav aria-label="Geophysics modules" className="shrink-0 border-b border-gray-200 bg-white">
        <div className="mx-auto flex max-w-7xl items-center gap-1 overflow-x-auto px-4 py-2 sm:px-6">
          {MODULES.map(module => (
            <Link key={module.id} href={module.href}
              aria-current={active === module.id ? 'page' : undefined}
              className={`whitespace-nowrap rounded-lg px-3 py-2 text-xs font-medium transition focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600 ${active === module.id
                  ? 'bg-indigo-50 text-indigo-700'
                  : 'text-gray-600 hover:bg-gray-50 hover:text-gray-900'
                }`}>
              {module.label}
            </Link>
          ))}
        </div>
      </nav>
      <main aria-label={title} style={{ flex: '1 1 0%', minHeight: 0 }}>
        <iframe key={src} src={src} title={title}
          style={{
            display: 'block', width: '100%', height: '100%', border: 0, backgroundColor: '#f4f5f0',
            colorScheme: 'light',
          }} />
      </main>
    </div>
  );
}
