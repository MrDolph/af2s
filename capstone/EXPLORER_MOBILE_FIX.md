# Header placement and mobile layout fix

Run from the existing project root after the all-topic explorer patch:

```bash
bash patch-explorer-mobile-layout.sh
npm run dev
```

Refresh the page. The explainer now belongs immediately after the shared AppHeader, rather than before the page in RootLayout. BJT and PN-junction pages receive it after their own custom headers. Geophysics inherits the corrected position through its existing AppHeader. The root layout only loads scoped responsive styles. This prevents duplicate explanation panels.

Responsive adjustments cover the new explorer, topic explainer, tutor, shared navigation and the two custom device-page headers:

- Tablet navigation stays in the mobile menu until the large-screen breakpoint.
- Mobile menus scroll independently when taller than the viewport.
- Explainer controls stack on narrow screens and have 44px minimum targets.
- Expanded explanations have a bounded scrolling area, keeping the header reachable.
- Long topic names, local-language text, formulae and parameter keys wrap.
- Parameter tables scroll within their card, rather than widening the whole page.
- Mobile form controls use 16px text to avoid automatic Safari zoom.
- The shared navigation menu and explainer disclose their expanded state to assistive technology.

The script backs up changed files and preserves unrelated layout/header edits. It does not change physics models, parameters, authentication, API credentials or the catalogue. Existing simulation-specific controls and canvases keep their own responsive implementation; this patch is not a redesign of every original activity.

TypeScript and production build checks were run. Installer checks cover initial application, repeat runs and header/explainer ordering. Physical-device and interactive browser checks remain unverified because the managed preview launcher is incompatible with this project's Next.js dev flags.

After applying, check /explore and an opened simulation at phone portrait/landscape and tablet widths. The main header should precede the explanation panel, controls should fit the available width, and a long parameter table should scroll inside its card.
