# Atomic radiation lesson update

Apply `patch-atomic-radiation-lesson.sh` from the project root after the earlier atomic responsive patch. The installer checks source versions before changing anything, backs up originals and is safe to run twice. It changes only the atomic components, their hosts, lesson logic, tests and this note. No dependencies are added.

Run `node checks/atomic-models-layout.cjs` and `npm run build`. Restart development or redeploy using your usual workflow. The shared component serves `/simulations/atomic-models` and `/embed/atomic-models`.

## Teaching sequence

- **Cycle** plays arrival, absorption/excitation, a slowed excited-state hold, relaxation/emission and return to the lower state.
- **Send photon** stops at the excited state so the instructor can explain stored energy. **Relax** releases it as one outgoing photon.
- **Step** advances a whole teaching stage; **Pause/Resume** controls continuous playback. **Reset** restores the initial lower state.
- Select any pair of states from n=1 to n=7. The photon energy equals the selected gap in matching mode. Off-resonance mode chooses a photon between neighbouring transition energies, below ionisation, and demonstrates no bound-state absorption in the idealised model.
- The photon travels in real space. The vertical arrow belongs only to the energy diagram: it is not an electron trajectory or radiation beam. There is no animated radial electron path through forbidden energies.
- Excitation occurs only when the photon arrives. During emission, the atom's energy decreases when the outgoing photon is created.

This is a one-electron Bohr teaching model with schematic orbit radii, wave shape, directions and slowed timing. Actual n²/Z radii remain in the live numerical readout. Sublevel selection rules, fine structure, Zeeman splitting, cascades and realistic lifetimes are not simulated. Photon colours distinguish events; ultraviolet and infrared radiation are not visible to the eye. These are energy-level teaching examples, not an assertion that every microscopic absorption follows the same geometrical path.

Thomson is shown as a continuous positive pudding with eight embedded negative electron symbols, not a nucleus surrounded by orbiting electrons. Plus marks indicate the distributed positive medium; they are not separate protons. Small illustrative vibrations do not turn the embedded electrons into orbiting particles.

## Classroom layout

Classroom view is one viewport with compact essential controls at the top. Nuclear charge Z, model, speed, continuous zoom, Fit and the display toggles are available in the classroom header. The legacy long parameter section is hidden there; remaining specialist settings stay accessible in normal view. Desktop and landscape show the atom and energy diagram together. The atom, selected energy levels and numeric calculations stay together on portrait phones too; there are no diagram tabs to switch between. Explanatory text is shortened in compact classroom view. The normal page can scroll as usual.

## Validation

Automated checks cover photon-arrival causality, excitation hold, energy loss at emission, off-resonance rejection, hydrogen-like energy/wavelength calculations, selected-level label spacing, rendering of all four models and restarting the canvas when switching back from Bohr.

A static QA harness built from the actual React lab and SimulationStage components was checked in a browser at desktop size and at 375×667 portrait and 844×390 landscape sizes. Settled classroom content fitted within those viewports. Absorption, held excitation, relaxation and model switching were exercised. This was component browser QA, not a deployment or exhaustive test on every device.

Physics references:
- https://openstax.org/books/chemistry-2e/pages/6-2-the-bohr-model
- https://openstax.org/books/university-physics-volume-3/pages/6-4-bohrs-model-of-the-hydrogen-atom
- https://history.aip.org/exhibits/electron/jjelectr.htm

## Bohr workbench follow-up

Apply `patch-atomic-bohr-workbench.sh` after the radiation-lesson patch.

Zoom now changes the camera across the full 0.3–3× range in all four models. Magnification intentionally crops distant parts of the drawing; drag to pan, and Fit restores 1× and centres the diagram. It is not silently capped at 1×.

The atom shows multiple quantised shells, the occupied electron moving around its orbit during playback, and old-state/new-state cues during excitation and relaxation. Dashed curved arrows are explanatory jump cues, not a classical path through forbidden intermediate energies. Orbit radii are compressed for legibility; the numeric radius uses n²/Z. In a manually held excited state, Orbit motion animates the orbit without emitting a photon. Relax remains available to trigger emission. The outgoing photon has a fixed emission origin and its own propagation direction.

Live calculations show Ei, Ef, the signed atomic ΔE, supplied photon energy, frequency, wavelength, current physical radius and electron speed, plus current energy and stored energy. Large displays include numerical substitutions. Compact displays keep all numeric results visible with short labels; full expressions are available in each result's accessible label/title. Scientific notation uses ×10 superscripts. Calculations use unrounded values; displayed values are rounded. Off-resonance frequency/wavelength use the actual supplied photon energy, and a missed photon reports zero actual atomic energy transfer.

The classroom layout remains one viewport. Camera and essential calculation inputs are adjustable there, without returning to the normal page. Normal page/embed hosts share the same controls and component. Remaining advanced options outside this simplified Bohr lesson are unchanged.

Additional automated checks cover strictly changing zoom geometry at every slider step, pan/Fit framing, signed absorption/emission calculations, photon frequency/wavelength, numeric radius/speed, scientific notation and off-resonance readouts. Browser component QA exercises changing Z, stepping the on-orbit jump, 3× zoom, dragging to pan and Fit, with simultaneous calculations on desktop and phone layouts.
