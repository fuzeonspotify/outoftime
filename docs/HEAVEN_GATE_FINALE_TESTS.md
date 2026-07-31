# Crash, Heaven Gate, and Lead Models — Manual Test Matrix

Run these checks in an actual Godot 4.7 build after clearing the Output panel.

## Centered bridge crash

- Complete or fail the Memory Road and confirm there is a readable pause before the crash begins.
- Confirm the blockade is built directly across the center of the road rather than beside it.
- Confirm the car approaches the centered blockade without an unexplained sideways teleport.
- Confirm the approach lasts about 3.5 seconds and gives the player time to see the obstacle.
- Confirm the first collision destroys the centered barrier pieces.
- Confirm the car then slides toward the right rail for about 2.3 seconds.
- Confirm the right guardrail breaks near the rail impact rather than during the first collision.
- Confirm the fall remains visible for about 4.1 seconds before the whiteout begins.
- Confirm the Car Concept keeps distinct paint, glass, interior and wheel materials through the crash.

## Gate midpoint interruption

- Reach at least 92% Heaven corruption and verify the false gate becomes interactable.
- Confirm the first hold duration is about 2.8 seconds.
- Start holding E and watch the progress bar.
- Confirm the angel attack begins when the first bar reaches 50%, before E is released and before normal gate activation completes.
- Confirm releasing E after the interruption cannot activate the gate a second time.
- Confirm the portal remains visually half-open as the attack starts.
- Confirm the selected dark angel takes about 3.1 seconds to cross the aisle instead of teleporting to the player.
- Confirm the camera moves from third person to eye height over about 1.25 seconds.
- Confirm the player model and HUD disappear only after the first-person camera reaches eye height.
- Confirm the separate pull into the angel's face takes about 1.45 seconds.
- Confirm the QTE waits through a brief close-face hold before appearing.
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

- On a clean v2 character cache, confirm startup displays the character-model preparation state.
- Confirm the main character is one complete skinned body named `RiggedMainCharacter`.
- Confirm the old procedural skeleton meshes are hidden only when that complete rig loads successfully.
- Confirm the player armature moves its arms, forearms, thighs, shins, spine, head and hips during walking, sprinting and jumping.
- Confirm the player does not appear as the old skeleton with a replacement head.
- Confirm the ghost woman is one complete skinned body named `RiggedGhostWoman` in both Cemetery and Chamber.
- Confirm no separate corset top, synthetic head or hair cap is added over the ghost model.
- Confirm her spine, head and arms move subtly during idle presentation.
- Disconnect the network and clear the v2 optional cache; confirm the procedural story fallbacks remain playable without partial hybrid models.
