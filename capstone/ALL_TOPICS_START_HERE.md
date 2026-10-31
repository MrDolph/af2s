# All-topic explorer and free explainer

## Install

Place `patch-all-topics-explorer.sh` beside package.json in your existing project. From that folder run:

```bash
bash patch-all-topics-explorer.sh
npm run dev
```

Restart an already running development server before testing. Open http://localhost:3000/explore or choose **Explore topics** from the header. Deploy the source changes normally to add the explorer to your Vercel site.

The patch needs the existing project dependencies, including TypeScript, installed in node_modules. It does not install packages, change credentials or deploy anything. It prepares all source changes before writing them, backs up changed files, and retains unrelated edits in simulation pages by inserting only a preset hook and import. If it cannot locate an expected component, it stops before applying the patch. Do not rerun older projectile-only AI patches afterwards; they would replace the new prompt bar and endpoint.

## What is covered

58 distinct activity routes: Physics simulations, Chemistry playgrounds, Mathematics explorers and Geophysics. The legacy Physics unit-circle URL redirects to Mathematics and is not counted twice. Existing Minitab student-login restrictions remain in force. No new Biology simulation is claimed; the /tutor Biology lesson remains separate.

Every registered activity has a matching overview, key relation/principle, a free local-language concept explanation and an activity link. The original full activity text and technical topic names remain in English. English, Yoruba, Hausa and Igbo are available for the explainer. Formulae, assumptions accompanying computed examples and technical parameter labels remain in English/SI notation. Translations are drafts for fluent subject-teacher review.

47 activities have numeric preset adapters covering 256 source-verified controls. Their available simulation modes are included where a verified mode catalogue exists. Controls without an adapter remain manual inside the original activity. Some activities mix several modes: a field for an inactive mode will not affect the current display. Select the appropriate mode and change its controls. The explorer lists all registered numeric fields; it does not claim every interactive setting is automated.

The remaining 11 activities open with their original controls and a topic explainer: electrostatic charging, space, compound builder, organic molecules, periodic table, the four Geophysics tools, gamma function and gradient explorer. Composition, atom selection, molecular drawing and iframe-based tools keep their existing interfaces; numerical input is not guessed for these activities.

## Main workflow

1. Select the topic and response language.
2. Expand **Settings to apply** to inspect the actual field keys, defaults and allowed ranges.
3. Enter optional values in those fields, or write a supported prompt.
4. Click **Explain and prepare**. Review the explanation and prepared settings.
5. Click **Open simulation**. This uses a full page load so the initial settings reach the existing React state reliably.
6. Use the simulation's normal Run and Reset controls. The explainer does not start or observe the animation.

The homepage retains its existing projectile quick preview. Non-projectile requests prepare a link to their own page; they do not replace the homepage canvas. Use /explore for a dedicated topic-neutral experience. The explanation panel appears on registered pages, with prepared settings expanded when supplied. If sliders are changed afterwards, the panel remains an explanation of the prepared settings, not a live measurement of the current simulation.

## Example prompts

```
Ohm 12 V 6 ohm
Newton second law 10 kg 50 N friction2=0
Waves f=1 lambda=2
Projectile 30 m/s 45°
Unit circle 30 degrees
Gas laws law=ideal temperature=300 moles=0.1 volume=4
Radioactive decay halfLife=5 n0=400
Quantum tunneling particleEnergy=1 barrierHeight=2 barrierWidth=2
```

Exact `key=value` syntax works for each numeric field listed under the chosen topic. Short natural-language/units forms are available for selected common cases; the parser is not a language model. It does not solve arbitrary questions or generate new simulations. Unrecognised numerical values, invalid ranges and duplicate fields are rejected. Omitted values use the displayed defaults. Supplying a field both in the settings form and the prompt is considered a duplicate.

For non-standard projectile modes use the exact keys for that mode, such as `mode=horizontal hV0=20 hH=30`, rather than a generic speed shortcut. Parameters for other modes keep their source defaults.

## Calculations

Computed examples are provided for Ohm's law/series/parallel ohmic circuits, Newton's second-law horizontal block model, standard projectile motion, simple travelling-wave speed/period and the unit circle. Other topics show their own principle and existing activity instead of fabricating a numerical answer. Non-ohmic, complex or unsupported submodes do not receive a misleading generic calculation.

For `Ohm 12 V 6 ohm`, I = 2 A and P = 24 W. For `Newton second law 10 kg 50 N friction2=0`, a = 5 m/s². Without the friction setting, the existing simulation's coefficient 0.2 is used and the explanation includes that friction model.

## File map

- src/lib/explorer/topics-data.json — shared topic catalogue, controls, limits, modes and routes.
- src/lib/explorer/catalog.ts — catalogue types and lookup.
- src/lib/explorer/prepare.ts — topic detection, validated settings, preset URLs and selected calculations.
- src/lib/explorer/locales.ts — language labels and concept explanations.
- src/lib/explorer/use-topic-preset.ts — initial URL-to-state bridge.
- src/components/ai/PromptBar.tsx — topic/language selection and prompt input.
- src/components/explorer/ResultCard.tsx — explanation and prepared settings.
- src/components/explorer/TopicContext.tsx — activity-page explanation panel.
- src/app/explore/page.tsx — topic-neutral explorer.
- src/app/api/ai/route.ts — free all-topic endpoint, with no model-provider calls.

Adding a future activity requires a catalogue entry and, if numeric handoff is wanted, a verified state adapter. New catalogue entries are not created automatically. This patch uses the uploaded source as its inventory.

## Important implementation limits

The free /api/ai response now uses a topic-aware contract (`topicId`, `params`, `modes`, `url`, `explanation`); the patched prompt bar understands it. Any separately written client that relied on the old six-value `simulationType` response would need updating. The supplied source had only the patched PromptBar as its caller.

The separate /tutor guided demo and /api/tutor endpoint are unchanged. The former Anthropic simulation parser remains on disk but is not called by the new /api/ai endpoint. SIMULATION_AI_MODE does not enable paid requests through this new free endpoint. All-topic live generative AI would require a separate, deliberate integration later.

## Checks completed and remaining

Production build and TypeScript checks passed in the supplied project. Automated checks covered all 58 route files, all 232 topic/language combinations, bounds, mode values, URL round trips, topic-name recognition and representative calculations. Endpoint checks used an invalid provider key with external fetch blocked. Preset-hook checks covered all 47 numeric activities and 256 field names. The installer was checked for application, repeat runs and preservation of unrelated source edits.

Browser visual/interaction QA and fluent-speaker review remain outstanding. The managed preview runner could not launch this Next.js project because it supplied incompatible dev-command flags; no browser-tested claim is made. After installation, try the examples above on your own browser and verify their settings against the activity controls before presenting.
