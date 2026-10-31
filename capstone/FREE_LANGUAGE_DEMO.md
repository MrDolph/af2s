# Free local-language demo

Run `bash patch-stem-tutor-free-languages.sh` from the existing project's root, then `npm run dev` and open http://localhost:3000/tutor.

Use the language selector at the top: English, Yorùbá, Hausa or Igbo. The selected language controls all four starter lessons, examples, activities, questions, hints, feedback, practice record and demo tutor responses. Language and practice results persist in browser storage when available. Existing practice results use the same IDs and remain usable.

The demo tutor has five prepared response types: explain, worked example, activity, hint and solution. Suggestion buttons work in every language. The text box recognises a small set of words for these requests; unfamiliar requests get a clear message asking the learner to choose a supported action. It does not solve arbitrary questions or translate arbitrary new content.

No API key, credits, payment, Redis connection or model download is needed for this demo page. It makes no calls to /api/tutor. The existing live endpoint and other site features remain untouched. Your other simulations may still use their own existing APIs. The three linked activities open separately and their own interface language is unchanged. Biology remains a guided thought experiment.

For a capstone demonstration, say: “This is the local multilingual guided prototype. It demonstrates the learning flow and prepared lesson responses in four languages. Live generative AI is a separate optional extension.”

## Try this

1. Select Yorùbá, choose Physics, and click the explanation and example buttons.
2. Switch to Hausa or Igbo: lessons and prepared replies change language immediately.
3. Choose Chemistry, Biology or Mathematics; try a hint and submit a practice answer.
4. Reload and check that language and results persist.
5. Download the practice record in the selected language.

Technical terms are sometimes intentionally retained in English beside local-language explanations. Translation wording is draft content: have fluent subject teachers review it before classroom use. No claim of professional translation review or measured learning gains is made.

## Files

- src/app/tutor/page.tsx: replaces tutor UI with free multilingual mode and retains the contrast fix.
- src/lib/tutor/translation-data.json: editable labels and translated content.
- src/lib/tutor/local-demo.ts: locale selection and deterministic responses.
- capstone/FREE_LANGUAGE_DEMO.md: this guide.

Backups are created in .stem-tutor-backups before changing existing files. No package.json, environment settings, live endpoint, header or simulation files are modified.

## Checks completed

Production build and TypeScript checks passed. Automated checks covered all four languages, four subjects, five prepared response types, preservation of correct-answer indices and activity URLs, multilingual request matching and the unsupported-request fallback. Browser interaction and fluent-speaker review remain to be completed. Managed browser preview was unavailable because the preview runner supplied flags unsupported by this project's Next.js dev command.
