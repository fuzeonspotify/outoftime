# Heaven Gate Finale — Manual Test Matrix

Run these checks in an actual Godot 4.7 build after clearing the Output panel.

## Gate interruption

- Reach at least 92% Heaven corruption and verify the false gate becomes interactable.
- Hold E once and confirm the portal begins opening before the attack interrupts it.
- Confirm the nearest final-row dark angel leaves formation and crosses the aisle smoothly.
- Confirm the active camera matches the third-person view before moving to player eye height.
- Confirm the player model and HUD disappear only after the first-person camera takes control.
- Confirm the camera ends close to the angel face without clipping behind it.
- Confirm movement, mouse look, jumping, pausing and gate interaction are locked during the attack.

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

## Runtime model checks

- On a clean cache, confirm startup displays character and realistic vehicle preparation states.
- Confirm the player uses the scanned skull while the body still animates during movement.
- Confirm the ghost woman uses the spectral detailed body in both Cemetery and Chamber.
- Confirm the Car Concept loads on the Memory Road and remains visible through the crash.
- Confirm sample logos are hidden where node or material naming exposes them.
- Disconnect the network, clear optional caches and confirm all procedural fallbacks remain playable.
