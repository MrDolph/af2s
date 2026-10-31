# A-Factor STEM Tutor

**Project owner:** Fatai Olalekan Dawodu (MrDOF), A-Factor EdTech Solutions.

**Proposed title:** Development of an AI-Powered STEM Tutoring Bot Integrated with A-Factor STEM Studio.

**Audience:** Senior secondary learners in Lagos, Nigeria; initial pilot with five volunteer learners. This is a proposed audience, not an assertion that testing has occurred.

## Problem and value proposition

Learners can struggle to connect abstract STEM explanations with practical investigation and independent problem-solving. The pilot will investigate this problem with real learners rather than assume its prevalence.

We help senior secondary learners connect STEM concepts with practice by combining guided explanations, existing interactive activities, hints and immediate answer feedback in one study flow.

## Aim and objectives

Build and evaluate a small tutoring prototype covering Physics, Chemistry, Biology and Mathematics. It should allow a learner to select a subject, understand one concept, investigate an activity and answer a practice question. It should recommend only activity routes verified in the supplied source and preserve a simple practice record locally. Optional live AI answers should use server-held credentials and clearly disclose their limitations.

## Working scope

Physics: projectile motion; linked projectile simulation.
Chemistry: elements and compounds; linked compound builder.
Biology: photosynthesis; guided limiting-factor thought experiment.
Mathematics: sine and cosine; linked unit-circle explorer.

Core flow: Explain → Explore → Practise → Review. No login, payment or student database. The guided mode uses fixed content and deterministic feedback; it is not generative AI. The optional server endpoint supplies generative answers when configured. A working guided demo alone should not be presented as proof that live AI has been tested.

## Approach

Existing Next.js/React/TypeScript application, styled with its Tailwind utilities. Lesson catalogue contains educational content and verified routes. The browser saves only question attempts. A separate server endpoint validates requests, enforces shared Redis quotas and requests an Anthropic response. Model output is rendered as text, while activity links come only from the fixed catalogue.

## Evaluation

Pilot with five real target learners, using anonymous participant codes. Ask them to complete the main learning task without help. Record completion, time, errors and where they needed assistance. Review explanations with a subject teacher. A single practice question and a five-person usability pilot cannot establish mastery or causal learning gains.

Suggested success criterion to set before testing: at least 4 of 5 learners finish the selected lesson/activity/question flow without facilitator help. Record actual results, including failures. Retest confusing steps after revision.

## Deliverables and limits

Integration source, setup guide, lesson catalogue, working demonstration, anonymous test notes and a short project presentation. No testing results, screenshots, curriculum accreditation or performance gains are claimed in this brief. The app has not been deployed to the existing Vercel site as part of preparing this package.

Potential next steps: more topic coverage, a Biology simulation, teacher-reviewed question banks, direct simulation-state integration and a larger educational evaluation.
