# Site-wide analytics

Apply the patch from the A-Factor project root, run `npm run build`, then deploy using your normal workflow. Open `/minitab/admin/login`, sign in, and follow **Site-wide usage** to `/minitab/admin/site-analytics`.

## Environment

Use your existing `MINITAB_ADMIN_PASSCODE` and Upstash REST credentials:

- `UPSTASH_REDIS_REST_URL` and `UPSTASH_REDIS_REST_TOKEN`, or
- `KV_REST_API_URL` and `KV_REST_API_TOKEN`.

Optionally set `ANALYTICS_HASH_SECRET` to a long random secret (for example generate with `openssl rand -hex 32`). Without it, analytics uses the admin passcode. Keep all these values server-side; never prefix them NEXT_PUBLIC. Rotating the hash secret or its fallback starts new browser identities. Existing student names require a valid Minitab access cookie and `MINITAB_PASSCODE`.

Redeploy after changing environment variables. Missing storage shows a setup message; storage failures show an error rather than false zero totals. This patch does not provision storage or change your provider plan. Storage operations count toward your provider usage.

## Reports and interpretation

The new dashboard reports 7, 30 or 90 UTC days: page views, estimated distinct browsers/sessions (Redis HyperLogLog), focused visible time, popular pages/subjects, broad device type, external referrer hostname, selected simulation actions, latest activity, browser page history and page CSV export. Names are self-reported, not verified students. Browser labels cannot identify every audience member; shared devices may represent several people. These are usage indicators, not attendance or learning assessments.

Tracking starts after installation: old site-wide visits cannot be recovered. The existing Minitab dashboard and historical counters remain separate. Embedded pages count independently. Action counts cover recognised Run/Pause/Reset/classroom buttons within simulation stages. Visible time requires a focused, visible tab, is capped at 30 minutes per page view, and can be lost if the browser closes before sending. Referrer hosts describe page-view sources, not verified acquisition attribution.

Admin sessions, common bots, Do Not Track, Global Privacy Control and browser opt-outs are excluded. Blockers and cookie restrictions may reduce counts. Public telemetry is same-origin, path-allowlisted, rate-limited per signed session, and deduplicated; it is not a fraud-proof measurement system.

Reports retain 90 days; daily records expire after 95 days. Browser profiles expire after 95 days without an update. Recent events are capped at 200; the dashboard shows 100. Daily unique-count sketches expire after 95 days. No IP addresses, full query strings, typed prompts/answers, audio, fingerprints or precise location are stored by this feature. Hosting providers may keep operational logs separately.

Visitors can disable tracking at `/privacy/analytics` (linked from About). The preference clears browser analytics IDs and disables future events; it does not delete previously stored history. This preference also suppresses future legacy Minitab counters. Previously collected Minitab records retain their existing lifecycle.

Both analytics GET endpoints require an instructor cookie and use private no-store responses. No new public name-search endpoint is added.

## Verification after deployment

1. In a signed-out browser, open two topic pages and use a simulation. Keep one tab focused for over a minute.
2. In a separate instructor browser, refresh the site dashboard and check page counts, visible time and browser history.
3. In a student browser, sign into Minitab and visit a topic; check the self-reported label. A public visitor remains anonymous.
4. Confirm `/api/site-analytics` and `/api/minitab-analytics` return 401 in a signed-out browser.
5. Disable analytics on the privacy page, browse and verify no new events; re-enable to resume with a new browser ID.
6. Check desktop and mobile layouts, CSV download and 7/30/90-day filters.

Local validation does not connect to your production Redis or verify real visitor counts. New static public routes should be added to `src/lib/analytics/site-pages.json` when introduced; private routes should remain excluded.
