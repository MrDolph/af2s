# Simplified header navigation

Run `bash patch-simplify-header-menus.sh` from your project root, then restart `npm run dev`.

- Simulations links directly to /simulations/all: the catalogue of all 58 registered activities, with subject filters and search.
- Try AI links to /explore: the same guided explainer and supported-calculation workflow previously named Explore topics.
- The separate Explore topics navigation entry is removed on desktop and mobile.
- STEM Tutor, About and Student Login remain in the header.
- The explainer stays below the header and existing mobile navigation behaviour is retained.

The original /simulations Physics directory is retained, so existing links continue to work. Chemistry, Mathematics and Geophysics remain discoverable through the all-activity catalogue. Existing student-login restrictions still apply to protected activities.

Try AI is a navigation label, not a change of engine: the free demo continues to use rules, prepared explanations and selected calculations. General conversational problem solving would require a separate model integration. This patch does not enable paid API requests.

Changed files are backed up before installation. The installer updates the header's relevant navigation entries while preserving other header customisations. TypeScript and production build checks were run; live browser visual testing remains unverified.
