# Accessibility and voice support

Run `bash patch-accessibility-voice.sh` from the project root, then restart `npm run dev` and refresh. The Accessibility button is the round person icon at the bottom left. Your subject dropdown, Try now button and AI explainer remain as configured.

## Adjustable and resettable controls

- Text size: 100–150%, with a one-click text reset. Browser zoom still works independently.
- More paragraph line and letter spacing.
- Stronger keyboard focus indicators.
- Underlined links.
- Reduced CSS/interface motion. Simulation animations keep their own Run/Pause controls.
- Read-aloud voice, rate, pitch and on-device-voice preference.
- Voice input, disabled by default until enabled in settings.
- Reset all accessibility settings: restores defaults, stops speech/microphone activity and removes the saved accessibility preference. It keeps quiz results, application language choices and other application data.

Settings are saved only in this browser under afactor-accessibility-v1. No student profile or disability information is collected. If storage is unavailable, settings still work for the current session. Different devices and browsers have separate preferences.

## Read aloud

Read aloud buttons appear in the topic explainer, tutor lessons and prepared tutor replies. Pause, Resume and Stop are available while reading. Nothing reads automatically. A basic English spoken form is provided for a few common formulae and symbols; this is not a general mathematical screen reader.

The accessibility panel can also read up to the first 12,000 characters of the current page's main text. It does not automatically describe canvases, charts or iframe contents. Visible written text remains available for learners who do not use audio.

By default only browser voices marked as on-device are eligible. Automatic voice selection matches the text's language. English, Yoruba, Hausa and Igbo text can only be spoken when the device exposes a matching voice; the patch does not install or manufacture voices. If a matching voice is unavailable, the app shows a clear message. It does not silently read Yoruba with an English voice. Turning off on-device-only mode may allow provider-backed voices that send text to that provider.

Voice availability and installation are controlled by the operating system/browser. Reference: https://developer.mozilla.org/en-US/docs/Web/API/SpeechSynthesis/getVoices

## Speak a question

Enable voice input in Accessibility settings, return to the tutor or simulation prompt box, and press Speak a question. The browser may request microphone permission. Press Stop microphone to finish, review/edit the transcription and then submit using the normal button. It never submits automatically. Speech input appends to the current field, respecting the existing length limit. Common English spoken units and “equals” are normalised for the existing parser.

Your browser's recognition service may process audio online. Support varies by browser and language; typing remains available when recognition is absent or permission is denied. The app does not save microphone recordings. Recognition stops on route/language changes, disabling voice input, opening settings or resetting accessibility settings.

Reference: https://developer.mozilla.org/en-US/docs/Web/API/SpeechRecognition

These features require no new paid AI API. They do not change the free demo's prepared-response and supported-topic limits.

## Scope and verification

This is an accessibility improvement, not a claim of full WCAG conformance or suitability for every learner. Standard screen readers, keyboard access and browser zoom remain important. Embedded tools and simulation-specific graphics may need their own adaptations. Reduced interface motion does not stop scientific animations implemented in JavaScript.

TypeScript and production build checks were completed. Settings sanitisation/defaults, speech-text helpers and installer behaviour were checked. Actual audio playback, microphone permission flows, keyboard interaction and physical-device visual testing require testing in the target browser; these were not verified through the unavailable managed browser preview.

Suggested checks:

1. Adjust each setting and reload; check that it is retained.
2. Reset all settings; check normal appearance, no active speech, voice input off, and quiz results unchanged.
3. Try Read aloud, Pause, Resume and Stop with an installed English voice.
4. Try a local-language lesson with and without a matching installed voice.
5. Enable dictation, deny permission once, then allow it and verify editable text.
6. Navigate with Tab and use Skip to main content, Escape and modal close buttons.
7. Test enlarged text on a phone and verify that the two floating helpers do not overlap.
