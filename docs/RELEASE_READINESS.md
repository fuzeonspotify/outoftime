# Out of Time — Release Readiness Audit

This document records the active five-chapter build, runtime systems and required manual test matrix.

## Active scene flow

1. `scenes/main.tscn`
2. `scenes/cemetery.tscn`
3. `scenes/road_memory.tscn`
4. `scenes/afterlife_city.tscn` — compatibility path retained; active content is False Heaven
5. `scenes/ruined_nightclub.tscn`
6. `scenes/skeleton_chamber.tscn`

The `afterlife_city.tscn` path remains stable so existing handoffs and cached references do not break. The former gravity void and Memory Train are not attached to any active scene.

## Bridge vehicle and crash architecture

- `scripts/assets/kenney_car_library.gd`
  - downloads Kenney's CC0 Car Kit during title-screen preparation
  - uses the official archive first and the OpenGameArt mirror as a fallback
  - extracts GLB files in frame-sized batches
  - selects a sedan/sports-style vehicle automatically
  - imports the chosen model through `GLTFDocument`
  - exposes a memory-cached prototype to the road chapter
- `scripts/world/road_memory_runtime.gd`
  - replaces the procedural car with the cached model when available
  - normalizes scale and ground placement from the model AABB
  - preserves the procedural car as an offline fallback
  - transitions automatically from gameplay into the bridge crash
  - directs side, impact, fall and whiteout camera shots
  - changes directly to the preloaded Heaven scene
- `scripts/audio/bridge_crash_audio.gd`
  - tire screech, guardrail strain, major impact, glass burst, heartbeat and tinnitus
  - positional left/right crash details for headphones

The bridge must never download, extract or import the vehicle during gameplay. All optional model work belongs to startup preparation.

## False Heaven architecture

- `scripts/world/heaven_descent.gd`
  - builds the procession, arches, gardens, water channels, clouds and final gate
  - computes corruption continuously from the player's position along the negative-Z route
  - reverses every state when the player walks back toward the crash site
  - changes lighting, fog, saturation, architecture, flora, particles, UI and audio
  - enables the exit only when the illusion is almost fully exposed
- `scripts/world/heaven_angel.gd`
  - procedural angel NPC with robe, wings, halo, eyes and horns
  - continuously morphs color, posture, attention, wing pose, halo placement and horn scale
  - turns toward the player as corruption increases
- `scripts/audio/heaven_descent_audio.gd`
  - choir and breeze layers for the light state
  - corruption drone and heartbeat layers for the dark state
  - threshold bells, gate reveal and positional angel whispers

False Heaven is position-driven rather than a one-way timeline. Standing at the same location must always resolve to the same target corruption state, regardless of the route used to reach it.

## Shared systems

- `scripts/ui/ui_style.gd`: shared angular UI styling and feedback
- `scripts/ui/main_startup.gd`: startup preparation gate and current story copy
- `scripts/player/third_person_controller.gd`: movement, objectives, interaction HUD and pause menu
- `scripts/dialogue/dialogue_director.gd`: branching dialogue and cinematic cameras
- `scripts/world/interactable.gd`: hold-to-interact prompts and world markers
- `scripts/audio/sfx_director.gd`: shared Music, Ambience, SFX, Dialogue and UI buses
- `scripts/audio/music_director.gd`: soundtrack caching, long crossfades and dialogue ducking

## Startup preparation

`scripts/bootstrap/startup_preloader.gd` warms:

- all active chapter scenes
- optional online audio
- the CC0 bridge vehicle
- cemetery and nightclub environment models

The Begin Story button remains locked until startup preparation completes or a procedural fallback is selected.

## Asset provenance

- Kenney Car Kit provenance: `assets/models/kenney/CAR_KIT.md`
- Kenney environment model provenance: `assets/models/kenney/`
- Sound provenance and cache behavior: `assets/audio/CC0_AUDIO_LIBRARY.md`
- Runtime-downloaded assets are cached under `user://`
- Unreleased songs remain excluded from Git

## Manual release test matrix

Run from `scenes/main.tscn` with both an empty and populated `user://` cache.

### Title screen and startup

- Verify startup reaches 100% and unlocks Begin Story.
- Verify the chapter list says False Heaven and contains no Void or Memory Train wording.
- Verify the car archive status completes without freezing the UI.
- Verify failure of both car archive URLs activates the procedural vehicle fallback.
- Verify later launches reuse the cache without another archive download.
- Verify Begin Story cannot be double-triggered.

### Cemetery and dialogue

- Verify memorial progression and woman reveal.
- Complete trust, doubt and defiance routes.
- Verify dialogue locks movement, restores the camera and ducks audio correctly.
- Verify Pontiac begins after the conversation.

### Memory Road — vehicle

- Verify the selected Kenney car is visible, grounded and facing the driving direction.
- Verify its scale fits the road and obstacle collision distances.
- Verify headlights and taillights align acceptably with the selected model.
- Verify the procedural fallback car remains usable offline.
- Verify A/D steering and mouse-wheel camera distance.
- Verify road recycling, obstacle collisions and memory integrity.

### Memory Road — crash

- Verify reaching the distance target starts the crash automatically with no results screen.
- Verify losing all memory integrity reaches the same crash without a soft lock.
- Verify steering stops when the cinematic begins.
- Verify the crash camera becomes current and the gameplay camera does not fight it.
- Verify tire screech, right-side guardrail hit, glass, impact, heartbeat and tinnitus sequencing.
- Verify screen shake decays rather than accumulating permanently.
- Verify guardrail destruction and car fall remain visible at 1280×720 and ultrawide.
- Verify the whiteout changes to the preloaded Heaven scene once.
- Verify Pontiac and road ambience use long fades during the crash.

### False Heaven — initial state

- Verify the white crash transition fades into the wake-up sequence.
- Verify the player begins at the bright end of the procession.
- Verify angel halos, white wings, warm lighting, choir and gardens are visible.
- Verify the objective explains that direction controls the environment.
- Verify Escape pause, restart and return-to-title work through the player controller.

### False Heaven — directional corruption

- Walk toward negative Z and verify corruption rises smoothly rather than stepping abruptly.
- Stop at several positions and verify the state remains stable without continuing to darken.
- Walk back toward positive Z and verify all systems restore smoothly.
- Repeat forward/backward movement quickly and verify no state becomes stuck.
- Verify fog, ambient light, sun color, fill light, saturation and contrast all reverse.
- Verify marble, gold, path, water, clouds, flowers and motes all reverse.
- Verify sanctity percentage follows position and remains between 0% and 100%.
- Verify threshold messages do not spam while standing still.

### False Heaven — angels

- Verify all 26 NPCs spawn without overlapping the central path.
- Verify angels become demonic gradually rather than switching models.
- Verify halos lower and tilt, wings fold, horns grow, eyes turn red and robes darken.
- Verify corrupted angels turn toward the player and move closer to the path.
- Walk backward and verify every NPC returns to the original angel state.
- Verify directional whispers originate from different left/right NPC positions under headphones.

### False Heaven — exit

- Verify the gate marker remains disabled before roughly 92% corruption.
- Verify reaching the fully corrupted end enables the hold interaction.
- Walk backward after enabling it and verify the marker and prompt disable again.
- Re-approach and verify it enables again.
- Verify activating the gate locks movement, plays the reveal and fades into the ruined club once.

### Ruined Club and Chamber

- Verify all three nightclub breakers and the backstage exit.
- Verify distant club impacts remain positional.
- Verify all three chamber journals.
- Complete truth, defiance and mercy confrontation routes.

### Offline and fallback pass

- Disconnect the network and clear optional caches.
- Verify startup reaches a playable fallback state.
- Verify the procedural road car replaces the unavailable Kenney model.
- Verify crash and Heaven procedural audio remain available.
- Verify the complete story reaches the chamber without a remote asset.

## Final build gate

1. Complete this matrix in the editor.
2. Run a clean Windows export outside the editor.
3. Test optional music present and absent.
4. Test first-run startup online and offline.
5. Record one uninterrupted full playthrough.
6. Review crash and Heaven once on headphones and once on laptop speakers.
7. Confirm export credits and third-party provenance are included.
