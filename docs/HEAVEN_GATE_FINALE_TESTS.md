# Crash, Heaven Gate, and Lead Models — Manual Test Matrix

Run these checks in an actual Godot 4.7 build after clearing the Output panel.

## Centered final-cut bridge crash

- Complete or fail the Memory Road and confirm there is about a 2.2-second premonition pause before the crash movement begins.
- Confirm a seven-piece blockade spans the road with its center piece exactly on the road centerline.
- Confirm the painted centerline leads directly to the blockade rather than an object beside the road.
- Confirm the car remains centered while approaching and does not teleport sideways.
- Confirm the long approach lasts about 5.8 seconds and clearly reveals the roadblock.
- Confirm the separate braking shot lasts about 2.2 seconds before the final impact.
- Confirm the first collision destroys only the centered blockade pieces.
- Confirm the impact is held long enough to read before the car is thrown toward the right rail.
- Confirm the rightward rail slide lasts about 3.6 seconds.
- Confirm the right guardrail breaks late in the rail slide rather than during the center collision.
- Confirm the fall remains visible for about 5.4 seconds before the whiteout begins.
- Confirm the Car Concept keeps distinct paint, glass, interior and wheel materials through the crash.

## Gate midpoint interruption

- Reach at least 92% Heaven corruption and verify the false gate becomes interactable.
- Confirm the first hold duration is about 5 seconds.
- Start holding E and watch the progress bar.
- Confirm the portal and progress bar stop at exactly 50%, before E is released and before normal gate activation completes.
- Confirm releasing E after the interruption cannot activate the gate a second time.
- Confirm the portal remains visually half-open throughout the beginning of the attack.
- Confirm the final-row right angel crosses the procession over about 5.4 seconds instead of teleporting.
- Confirm the camera moves from third person to eye height over about 1.8 seconds.
- Confirm the player model and HUD disappear only after the first-person camera reaches eye height.
- Confirm the angel pauses close to the player before grabbing them.
- Confirm the separate pull into the angel's face takes about 2.6 seconds.
- Confirm the camera holds close to the face for about one second before the QTE appears.
- Confirm movement, mouse look, jumping, pausing and additional gate interaction are locked during the attack.

## W/A/S/D survival sequence

- Confirm seven key prompts are visible and the active key is clearly highlighted.
- Confirm only physical W, A, S and D input advances or fails the sequence.
- Confirm a correct key advances one position and resets the step timer.
- Confirm an incorrect key consumes one chance and generates a new complete sequence.
- Confirm a timeout consumes one chance and generates a new complete sequence.
- Confirm the display begins at three chances and death occurs after the third failed attempt.
- Confirm correct, incorrect, timeout and death sounds are distinct on headphones.

## Failure outcome

- Lose all three attempts.
- Confirm the angel lunges closer, the camera FOV expands, the red impact appears and the screen fades to black.
- Confirm the current Heaven chapter reloads once.
- Confirm no jumpscare audio or cinematic camera survives the reload.

## Success and purification

- Complete all seven inputs in one attempt.
- Confirm the angel releases the player and returns toward formation.
- Confirm every angel loses its horns, regains open golden wings and receives a bright halo and eyes.
- Confirm the sky, sunlight, fog, architecture and particles transition to a stable bright-gold state.
- Confirm the dark drone and pressure audio stop and the release chord plays.
- Confirm the normal third-person camera, player model, HUD and mouse capture restore.
- Confirm position no longer makes Heaven dark again after purification.
- Confirm the gate is re-armed with the prompt `Open the golden portal`.
- Hold E a second time and confirm the original fade to the Ruined Club occurs once.

## Complete rigged lead models

- On a clean v3 character cache, confirm startup displays the character-model preparation state.
- Confirm the main character is the complete KayKit skinned skeleton named `RiggedMainSkeleton`.
- Confirm the old procedural skeleton meshes are entirely hidden when the complete rig loads.
- Confirm embedded idle, walk, run and airborne animations switch with player movement.
- Confirm the player is not the old skeleton with a replacement head.
- Confirm the ghost woman is one complete skinned body named `RiggedGhostWomanFullBody` in both Cemetery and Chamber.
- Confirm her original opaque body and clothing textures remain coherent from every camera angle.
- Confirm no separate corset, replacement head, synthetic hair cap or transparent top is added.
- Confirm her full armature idles through its embedded animation or the manual full-rig fallback.
- Disconnect the network and clear the v3 optional cache; confirm complete rigged fallbacks or the original procedural story placeholders remain playable without partial hybrid models.
