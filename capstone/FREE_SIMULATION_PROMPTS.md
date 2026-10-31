# Free /api/ai simulation demo

Install from the project root with `bash patch-ai-free-demo.sh`, then stop the dev server (Ctrl+C) and restart with `npm run dev`. Open the homepage at http://localhost:3000.

The default is now the free rule-based parser, independent of whether ANTHROPIC_API_KEY is missing or invalid. No Anthropic request is made in demo mode. It reads numeric settings; it is not a generative model. It requires a running Next.js server, but no paid API for these prompts.

Choose English, Yoruba, Hausa or Igbo in the prompt bar. Click a sample or enter a projectile prompt with clear units. The explanation uses the selected response language. The rest of the simulation interface is unchanged. Language wording is draft content for fluent-teacher review.

Supported examples:

- Show projectile motion at 45° and 30 m/s
- Ṣe afihan projectile ni 45° ati 30 m/s
- Nuna projectile a 45° da 30 m/s
- Gosi projectile na 45° na 30 m/s
- Projectile at 30 m/s, 30°, gravity 2 m/s², mass 2 kg

The word `projectile` is a supported keyword in all four languages. English parameter names and SI symbols are retained. The parser does not understand arbitrary language or word-based numbers. Select the response language explicitly; it does not infer language from your question.

Defaults for omitted settings: speed 20 m/s; angle 45°; gravity 9.81 m/s²; mass 1 kg. The response lists defaults used. Limits match homepage controls: speed 1–100 m/s, angle 1–89°, gravity 1–25 m/s², mass 0.1–100 kg. Unsupported numeric values and repeated settings return a clear error without changing the current simulation.

Scope: homepage projectile motion only, with no air resistance and equal launch/landing heights. Other simulations remain in the simulations catalogue. The old Newton-law example was removed because this homepage does not display that scene. The patch does not generate new simulations or answer general STEM questions. Use the separate /tutor guided demo for prepared lesson responses.

## Environment

No environment change is normally needed. To explicitly select free mode in `.env.local`:

```
SIMULATION_AI_MODE=demo
```

Only `SIMULATION_AI_MODE=live` enables the existing paid Anthropic integration. Do not set that for this free demo. If using a deployed site, apply the code changes and redeploy; set the same mode there if previously overridden. This patch does not repair or validate the old API key. Demo mode bypasses it. It does not change the separate /api/tutor endpoint.

## Validation

TypeScript and production build checks passed. Automated parser checks covered English, Yoruba, Hausa and Igbo examples; degree and acceleration formats; defaults; invalid bounds; unknown numerical input; duplicate settings; unsupported topics; and the default path with a deliberately invalid key and blocked external fetch. Browser interaction testing remains unverified.
