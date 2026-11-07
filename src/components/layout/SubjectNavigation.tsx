import Link from 'next/link';
import { SUBJECTS, isSubjectPath } from '@/lib/subjects';

export function SubjectNavigation({ pathname }: { pathname: string }) {
  const subjects = SUBJECTS.filter(subject => subject.status === 'live');
  const current = subjects.find(subject => isSubjectPath(pathname, subject));

  if (!current && pathname !== '/stem') return null;

  const links = [{ href: '/stem', label: 'All STEM' }, ...subjects];
  return (
    <nav aria-label="Simulation subjects" className="border-b border-gray-200 bg-white">
      <div className="mx-auto flex max-w-7xl gap-1 overflow-x-auto px-3 py-1 sm:px-6">
        {links.map(link => {
          const selected = link.href === (current?.href ?? pathname);
          return (
            <Link key={link.href} href={link.href} aria-current={selected ? 'location' : undefined}
              className={`inline-flex min-h-10 shrink-0 items-center rounded-lg px-3 text-sm font-medium ${selected ? 'bg-indigo-50 text-indigo-800' : 'text-gray-600 hover:bg-gray-100'}`}>
              {link.label}
            </Link>
          );
        })}
      </div>
    </nav>
  );
}
