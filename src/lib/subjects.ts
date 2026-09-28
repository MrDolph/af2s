// The subjects listed under "Simulations" in the main menu.
//
// THIS IS THE ONE FILE TO EDIT WHEN YOU ADD A SUBJECT. To add, say, Chemistry:
//   1. Create its hub page at the href below (copy src/app/mathematics/page.tsx
//      to src/app/chemistry/page.tsx and change the title and simulation list).
//   2. Add one entry to SUBJECTS below.
// The desktop dropdown and the mobile menu both update automatically.
//
// status: 'live'  -> a normal link.
//         'soon'  -> shown greyed out with a "Coming soon" tag and no link, so
//                    you can announce a subject before its hub page exists.

export type SubjectStatus = 'live' | 'soon';

export interface Subject {
  slug: string;
  label: string;
  /** The subject's hub page. Its simulations live underneath this path. */
  href: string;
  icon: string;
  description: string;
  status: SubjectStatus;
}

export const SUBJECTS: Subject[] = [
  {
    slug: 'physics',
    label: 'Physics',
    href: '/simulations',
    icon: '⚛️',
    description: 'Mechanics, electricity, waves, optics and more',
    status: 'live',
  },
  {
    slug: 'mathematics',
    label: 'Mathematics',
    href: '/mathematics',
    icon: '📐',
    description: 'Trigonometry and the maths behind physics',
    status: 'live',
  },
  // Examples — uncomment one (and create its hub page) when you're ready:
  // { slug: 'chemistry', label: 'Chemistry', href: '/chemistry', icon: '🧪', description: 'Reactions, bonding and the periodic table', status: 'soon' },
  // { slug: 'biology',   label: 'Biology',   href: '/biology',   icon: '🧬', description: 'Cells, genetics and ecosystems',            status: 'soon' },
  // { slug: 'it',        label: 'IT',        href: '/it',        icon: '💻', description: 'Computing, networks and algorithms',        status: 'soon' },
];

/** True if `pathname` is this subject's hub or any page beneath it. */
export function isSubjectPath(pathname: string, subject: Subject): boolean {
  return pathname === subject.href || pathname.startsWith(subject.href + '/');
}
