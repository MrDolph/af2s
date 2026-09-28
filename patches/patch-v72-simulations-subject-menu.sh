#!/bin/bash
# A-Factor STEM Studio — "Simulations" multi-level menu (subjects)
# Run inside af2s/ (the project ROOT, not inside patches/), AFTER v71:
#     bash patches/patch-v72-simulations-subject-menu.sh
#
# WHAT IT DOES
#   Replaces the flat "Simulations" and "Mathematics" nav items with a single
#   "Simulations ▾" menu that lists subjects beneath it:
#
#       Simulations ▾
#         ⚛️ Physics       -> /simulations
#         📐 Mathematics   -> /mathematics
#
#   - Desktop: click "Simulations" to open; click outside or press Escape to close.
#   - Mobile:  "Simulations" expands in place, with the subjects indented beneath it.
#   - The trigger highlights whenever you're anywhere inside a subject, and the
#     subject you're in is highlighted in the list.
#
# TO ADD A SUBJECT LATER (Biology, Chemistry, IT, ...):
#   Edit ONE file, src/lib/subjects.ts — there are commented-out examples in it.
#   Use status: 'soon' to show a subject greyed out with a "Coming soon" tag
#   before its hub page exists, then flip it to 'live' once it does.
#
# WHAT IT CHANGES
#   New:   src/lib/subjects.ts, src/components/layout/SimulationsMenu.tsx
#          (only written if they don't exist, so YOUR later edits to the subject
#           list are never overwritten if you re-run this patch)
#   Edited (targeted, idempotent, CRLF/LF-aware — never a full overwrite):
#          src/components/layout/AppHeader.tsx
#            - removes the flat 'Simulations' / 'Mathematics' NAV entries
#            - adds one import and puts the menu where 'Simulations' used to sit
#
# The Physics hub, the Mathematics hub, the home-page link and the two-way pills
# from v71 are left as they are. (Those pills only make sense for two subjects;
# once you add a third, ask for them to be swapped for a generic "other subjects"
# row driven by this same list.)

set -e

# ── Guards ─────────────────────────────────────────────────────────────────────
if [ ! -f package.json ] || [ ! -d src ]; then
  echo "ERROR: run this from your project root (the folder containing package.json and src/),"
  echo "       e.g.   cd af2s   then   bash patches/patch-v72-simulations-subject-menu.sh"
  exit 1
fi
if ! command -v node >/dev/null 2>&1; then
  echo "ERROR: 'node' was not found on your PATH. It is needed for this patch's edits."
  exit 1
fi
if [ ! -f src/app/mathematics/page.tsx ]; then
  echo "ERROR: src/app/mathematics/page.tsx was not found."
  echo "       This patch builds on v71 (the Mathematics pages) - run"
  echo "       patches/patch-v71-mathematics-visible-and-email.sh first, otherwise the"
  echo "       new menu would link to a page that doesn't exist yet."
  exit 1
fi
if [ ! -f src/components/layout/AppHeader.tsx ]; then
  echo "ERROR: src/components/layout/AppHeader.tsx was not found."
  exit 1
fi

echo "Applying Simulations subject menu (v72)..."

# Writes stdin to the given path ONLY if that file doesn't exist yet.
write_if_missing() {
  if [ -f "$1" ]; then
    cat > /dev/null
    echo "  keeping your existing $1"
  else
    mkdir -p "$(dirname "$1")"
    cat > "$1"
    echo "  wrote $1"
  fi
}

write_if_missing src/lib/subjects.ts << 'FILEEOF'
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
FILEEOF

write_if_missing src/components/layout/SimulationsMenu.tsx << 'FILEEOF'
'use client';
import { useState, useRef, useEffect, useId } from 'react';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { SUBJECTS, isSubjectPath, type Subject } from '@/lib/subjects';

function Chevron({ open }: { open: boolean }) {
  return (
    <svg
      width="10" height="10" viewBox="0 0 10 10" fill="none" stroke="currentColor"
      strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true"
      className={`transition-transform ${open ? 'rotate-180' : ''}`}
    >
      <path d="M2 3.5l3 3 3-3" />
    </svg>
  );
}

function SoonTag() {
  return (
    <span className="rounded-full bg-gray-100 px-1.5 py-0.5 text-[10px] font-medium text-gray-400">
      Coming soon
    </span>
  );
}

// One row in the dropdown. 'soon' subjects are greyed out and not clickable.
function SubjectRow({ subject, current, onNavigate }: { subject: Subject; current: boolean; onNavigate: () => void }) {
  const body = (
    <>
      <span className="mt-0.5 text-lg leading-none" aria-hidden="true">{subject.icon}</span>
      <span className="min-w-0">
        <span className={`flex items-center gap-2 text-sm font-medium ${current ? 'text-indigo-700' : 'text-gray-800'}`}>
          {subject.label}
          {subject.status === 'soon' && <SoonTag />}
        </span>
        <span className="block text-xs leading-snug text-gray-500">{subject.description}</span>
      </span>
    </>
  );

  if (subject.status !== 'live') {
    return <div className="flex cursor-not-allowed items-start gap-3 rounded-lg px-3 py-2 opacity-60">{body}</div>;
  }
  return (
    <Link
      href={subject.href}
      onClick={onNavigate}
      aria-current={current ? 'page' : undefined}
      className={`flex items-start gap-3 rounded-lg px-3 py-2 transition ${current ? 'bg-indigo-50' : 'hover:bg-gray-50'}`}
    >
      {body}
    </Link>
  );
}

/** Desktop: a "Simulations ▾" button that reveals the subject list. */
export function SimulationsMenu() {
  const pathname = usePathname();
  const [open, setOpen] = useState(false);
  const wrapRef = useRef<HTMLDivElement>(null);
  const panelId = useId();
  const active = SUBJECTS.some(s => s.status === 'live' && isSubjectPath(pathname, s));

  // Close on outside click or Escape while open.
  useEffect(() => {
    if (!open) return;
    const onDown = (e: MouseEvent) => {
      if (wrapRef.current && !wrapRef.current.contains(e.target as Node)) setOpen(false);
    };
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') setOpen(false);
    };
    document.addEventListener('mousedown', onDown);
    document.addEventListener('keydown', onKey);
    return () => {
      document.removeEventListener('mousedown', onDown);
      document.removeEventListener('keydown', onKey);
    };
  }, [open]);

  return (
    <div ref={wrapRef} className="relative">
      <button
        type="button"
        onClick={() => setOpen(v => !v)}
        aria-expanded={open}
        aria-controls={panelId}
        className={`flex items-center gap-1.5 rounded-lg px-3 py-1.5 text-sm transition ${
          active || open
            ? 'bg-indigo-50 text-indigo-700 font-medium'
            : 'text-gray-500 hover:text-gray-900 hover:bg-gray-50'
        }`}
      >
        Simulations
        <Chevron open={open} />
      </button>

      {/* Always rendered (just hidden when closed) so the links exist in the page HTML. */}
      <div
        id={panelId}
        className={`${open ? 'block' : 'hidden'} absolute left-0 top-full z-50 mt-2 w-72 rounded-xl border border-gray-200 bg-white p-1.5 shadow-lg`}
      >
        <p className="px-3 pb-1 pt-1.5 text-[10px] font-medium uppercase tracking-wide text-gray-400">
          Choose a subject
        </p>
        {SUBJECTS.map(s => (
          <SubjectRow
            key={s.slug}
            subject={s}
            current={s.status === 'live' && isSubjectPath(pathname, s)}
            onNavigate={() => setOpen(false)}
          />
        ))}
      </div>
    </div>
  );
}

/** Mobile: an expandable "Simulations" section with the subjects indented beneath it. */
export function SimulationsMobileMenu({ onNavigate }: { onNavigate?: () => void }) {
  const pathname = usePathname();
  const [open, setOpen] = useState(true); // the mobile menu is already opened on purpose, so show the subjects
  const panelId = useId();
  const active = SUBJECTS.some(s => s.status === 'live' && isSubjectPath(pathname, s));

  return (
    <div>
      <button
        type="button"
        onClick={() => setOpen(v => !v)}
        aria-expanded={open}
        aria-controls={panelId}
        className={`flex w-full items-center justify-between rounded-lg px-3 py-2 text-sm transition ${
          active ? 'bg-indigo-50 text-indigo-700 font-medium' : 'text-gray-600 hover:bg-gray-50'
        }`}
      >
        Simulations
        <Chevron open={open} />
      </button>
      {open && (
        <div id={panelId} className="ml-3 mt-1 space-y-0.5 border-l border-gray-100 pl-2">
          {SUBJECTS.map(s => (
            <SubjectRow
              key={s.slug}
              subject={s}
              current={s.status === 'live' && isSubjectPath(pathname, s)}
              onNavigate={() => onNavigate?.()}
            />
          ))}
        </div>
      )}
    </div>
  );
}
FILEEOF

node - << 'NODEEOF'
const fs = require('fs');

const read = p => fs.readFileSync(p, 'utf8');
const write = (p, s) => fs.writeFileSync(p, s, 'utf8');
const nlOf = s => (s.includes('\r\n') ? '\r\n' : '\n');
const problems = [];

const HEADER = 'src/components/layout/AppHeader.tsx';

(function editHeader() {
  let s = read(HEADER);
  const nl = nlOf(s);

  if (s.includes('SimulationsMenu')) {
    console.log('  header already uses the Simulations menu - skipping');
    return;
  }

  // 1. Add the import after the last single-line import.
  const importRe = /^import\s.+\sfrom\s+['"][^'"]+['"];?[ \t]*\r?\n/gm;
  let last = null, m;
  while ((m = importRe.exec(s)) !== null) last = m;
  if (!last) {
    problems.push("AppHeader.tsx: couldn't find its import lines. Add this near the top by hand:  import { SimulationsMenu, SimulationsMobileMenu } from '@/components/layout/SimulationsMenu';");
    return;
  }
  const at = last.index + last[0].length;
  s = s.slice(0, at) + "import { SimulationsMenu, SimulationsMobileMenu } from '@/components/layout/SimulationsMenu';" + nl + s.slice(at);

  // 2. Remove the flat 'Simulations' and 'Mathematics' entries from NAV
  //    (the menu replaces both; 'About' stays).
  let removed = 0;
  for (const label of ['Simulations', 'Mathematics']) {
    const re = new RegExp("^[ \\t]*\\{\\s*label:\\s*['\"]" + label + "['\"][^}]*\\}\\s*,?[ \\t]*\\r?\\n", 'm');
    if (re.test(s)) { s = s.replace(re, ''); removed++; }
  }

  // 3. Slot the menu in where 'Simulations' used to be: just before the
  //    desktop NAV.map (first) and the mobile NAV.map (second).
  const mapRe = /^([ \t]*)\{NAV\.map\(/gm;
  const hits = [];
  let h;
  while ((h = mapRe.exec(s)) !== null) hits.push({ index: h.index, indent: h[1] });
  if (hits.length !== 2) {
    problems.push("AppHeader.tsx: expected exactly two '{NAV.map(' blocks (desktop, then mobile) but found " + hits.length + ". Nothing was changed. Add <SimulationsMenu /> to the desktop nav and <SimulationsMobileMenu /> to the mobile nav by hand.");
    return;
  }
  const before = i => s.slice(Math.max(0, i - 300), i);
  if (!/sm:flex/.test(before(hits[0].index)) || !/sm:hidden/.test(before(hits[1].index))) {
    problems.push("AppHeader.tsx: the two NAV.map blocks aren't where this patch expects (desktop 'sm:flex' nav, then mobile 'sm:hidden' menu). Nothing was changed. Add <SimulationsMenu /> to the desktop nav and <SimulationsMobileMenu /> to the mobile nav by hand.");
    return;
  }

  const hasSetOpen = /\bsetOpen\b/.test(s);
  const mobileTag = hasSetOpen ? '<SimulationsMobileMenu onNavigate={() => setOpen(false)} />' : '<SimulationsMobileMenu />';
  // insert the later one first so the earlier index stays valid
  s = s.slice(0, hits[1].index) + hits[1].indent + mobileTag + nl + s.slice(hits[1].index);
  s = s.slice(0, hits[0].index) + hits[0].indent + '<SimulationsMenu />' + nl + s.slice(hits[0].index);

  write(HEADER, s);
  console.log('  header: added the Simulations menu (desktop + mobile), removed ' + removed + ' flat nav entr' + (removed === 1 ? 'y' : 'ies'));
})();

// ── Checklist ───────────────────────────────────────────────────────────
console.log('');
console.log('Checking the result:');
let failed = false;
function check(label, ok) {
  console.log((ok ? '  [OK]   ' : '  [FAIL] ') + label);
  if (!ok) failed = true;
}
const exists = p => fs.existsSync(p);
const header = exists(HEADER) ? read(HEADER) : '';
const subjects = exists('src/lib/subjects.ts') ? read('src/lib/subjects.ts') : '';

check('Subjects list              src/lib/subjects.ts (Physics + Mathematics)',
  /slug:\s*'physics'/.test(subjects) && /slug:\s*'mathematics'/.test(subjects));
check('Menu component             src/components/layout/SimulationsMenu.tsx', exists('src/components/layout/SimulationsMenu.tsx'));
check('Header imports the menu    AppHeader.tsx', /from\s+['"]@\/components\/layout\/SimulationsMenu['"]/.test(header));
check('Desktop menu in place      <SimulationsMenu />', /<SimulationsMenu\s*\/>/.test(header));
check('Mobile menu in place       <SimulationsMobileMenu />', /<SimulationsMobileMenu/.test(header));
check("No flat 'Simulations' item left in NAV", !/label:\s*['"]Simulations['"]/.test(header));
check("No flat 'Mathematics' item left in NAV", !/label:\s*['"]Mathematics['"]/.test(header));
check('Mathematics hub still exists   src/app/mathematics/page.tsx', exists('src/app/mathematics/page.tsx'));

for (const pr of problems) console.log('  ERROR: ' + pr);
if (failed || problems.length) {
  console.log('');
  console.log('Some steps did not complete - see the [FAIL] / ERROR lines above.');
  process.exit(1);
}
console.log('');
console.log('All checks passed.');
NODEEOF

echo ""
echo "Next steps:"
echo "  1. bash -c \"rm -rf .next\""
echo "  2. Restart the dev server:   npm run dev --webpack      (or: npm run build)"
echo "  3. Hard-refresh (Ctrl+Shift+R). The top bar should now show 'Simulations ▾' -"
echo "     click it to see Physics and Mathematics."
echo "  To add Biology/Chemistry/IT later, edit src/lib/subjects.ts (examples are in the file)."
