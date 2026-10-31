# A-Factor STEM Tutor — installation

This is an additive integration for the supplied af2s source. It creates /tutor and /api/tutor and adds STEM Tutor to the existing header. Your existing simulation engine is retained. No new package dependencies are needed.

## Apply the integration ZIP

1. Back up your project or commit your current work.
2. Extract A-Factor_STEM_Tutor_Capstone.zip into a temporary folder.
3. Copy the contents of its `integration/src/` folder into your project's root `src/` folder, merging folders. This adds three files and replaces `src/components/layout/AppHeader.tsx` with the supplied version plus the tutor link. If you edited your header since providing the ZIP, retain your header and add `{ label: 'STEM Tutor', href: '/tutor' }` to its NAV array instead.
4. Copy the `capstone/` folder into your project root for your project documentation.
5. In the VS Code terminal at your project root, run:

```bash
npm install
npm run dev
```

6. Visit http://localhost:3000/tutor. All four guided lessons, questions, hints and local practice records work without credentials.

The ZIP is an integration package, not a standalone app. Do not replace your entire project with it. There is no shell patch to locate or execute.

## Optional live AI

The source already uses Anthropic. This integration reuses that SDK, with a server-only endpoint; it does not alter your existing /api/ai route.

Append the variables from `capstone/TUTOR_ENV.example` to `.env.local`. Supply an Anthropic API key and your Upstash Redis REST credentials (existing Vercel KV names are accepted). Set STEM_TUTOR_ENABLED=true and restart the dev server. For Vercel, configure the same variables in project settings and redeploy. Never put secrets in NEXT_PUBLIC variables.

Live questions require quota storage: 12 requests/minute and 100/day across this app, enforced atomically in Redis; the daily bucket resets at 00:00 UTC. Failed model requests also consume a slot. These limits reduce exposure but are not authentication, a billing cap, or protection against distributed misuse. Use provider spend controls before a broad public rollout. With live tutoring disabled, the endpoint returns 503 and the guided demo remains functional. No provider credentials were supplied or used during preparation.

Live answers use the selected lesson and the current question only, not conversation history. Messages are shown in the session but are not saved by the application. Questions are transmitted to the model provider. Practice results are stored in this browser, not a student database.

## Verify before demonstrating

- Open /tutor on desktop and phone; switch between all four subjects.
- Follow Learn → Explore → Practise; open each of the three activity links.
- Answer incorrectly, inspect feedback, retry, then answer correctly.
- Reload: practice results should remain. Download the record, then clear it.
- With no credentials, enable live questions and confirm the clear unavailable message.
- After configuring credentials, ask a topic question; verify the explanation and units yourself.
- Run `npx tsc --noEmit` and `npm run build` in the full project.

## Extend

Lessons and verified activity routes: `src/lib/tutor/lessons.ts`.
User interface: `src/app/tutor/page.tsx`.
Live endpoint: `src/app/api/tutor/route.ts`.

The first version intentionally has one lesson and one practice question per subject. Biology has a guided thought experiment, not an external simulation. Simulation links do not transfer settings, and the tutor cannot observe the simulation. Add curriculum mapping, more questions and research evaluation before describing this as a complete adaptive learning system.
