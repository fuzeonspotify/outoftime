# Out of Time — Release Readiness Audit

This document records the active five-chapter build, its runtime systems and the manual test matrix required before distribution.

## Active scene flow

1. `scenes/main.tscn`
2. `scenes/cemetery.tscn`
3. `scenes/road_memory.tscn`
4. `scenes/afterlife_city.tscn` — compatibility path retained; active content is the Memory Train
5. `scenes/ruined_nightclub.tscn`
6. `scenes/skeleton_chamber.tscn`

The `afterlife_city.tscn` path remains stable so the Pontiac handoff and any saved references do not break. The former gravity void is no longer attached to the active scene.

## Release UI architecture

- `scripts/ui/ui_style.gd`
  - shared angular signal-panel, label, button and progress styling
  - consistent hover, focus and confirmation audio
- `scripts/ui/main.gd`
  - title screen, controls screen and fade transition
- `scripts/ui/main_startup.gd`
  - startup preparation overlay
  - Memory Train story copy and chapter listing
- `scripts/player/third_person_controller.gd`
  - objective card, interaction prompt, narrative messages and pause menu
- `scripts/ui/memory_hud_effects.gd`
  - vignette, scanlines, corner framing and chapter telemetry
- `scripts/world/road_release_polish.gd`
  - Pontiac memory HUD and pause presentation
- `scripts/world/memory_train.gd`
  - dedicated action HUD, track choice, cinematic bars, damage flash and screen shake

## Cinematic dialogue architecture

- `data/dialogues.json`
  - branching cemetery and chamber conversations
  - response tone, outcomes and camera-shot instructions
- `scripts/dialogue/dialogue_director.gd`
  - typewriter dialogue and numbered responses
  - speaker close-ups, player close-ups, two-shots and wide shots
  - dialogue audio feedback and music ducking
- `scripts/dialogue/cinematic_player_lock.gd`
  - freezes exploration movement during conversations
  - safely hides and restores the HUD and mouse mode
- `scripts/dialogue/cemetery_dialogue_integration.gd`
  - trust, doubt and defiance outcomes
- `scripts/dialogue/chamber_dialogue_integration.gd`
  - truth, defiance and mercy outcomes

## Memory Train architecture

- `scripts/world/memory_train.gd`
  - automatic forward action with three-lane movement
  - jumping, obstacle avoidance, integrity and checkpoint rewind
  - passenger car, track split, roof run and engine overdrive stages
  - live route selection: follow her or follow yourself
  - mid-game side-impact, passing-train and roof-transition camera sequences
  - bridge-collapse jump event
  - engine control-bank alignment challenges
  - cinematic nightclub crash transition
- `scripts/audio/memory_train_audio.gd`
  - generated sub-rumble, wheel rhythm, wind and metal strain loops
  - horns, brakes, track switches, electrical sparks and impacts
  - positional left/right train events for headphones
  - intensity scaling through the chapter
- `scripts/world/road_memory_runtime.gd`
  - rewrites the Pontiac completion screen as an impossible railroad crossing
  - boards the cached Memory Train scene

The Memory Train cutscenes intentionally leave gameplay processing active. Camera direction changes, shake and set pieces must never block lane or jump input.

## Interaction architecture

- `scripts/world/interactable.gd`
  - configurable action title and context
  - hold-to-interact timing
  - world-space marker and proximity feedback
  - one-shot and repeatable interaction behavior
  - narrative response or cinematic-dialogue handoff
- `scripts/world/interaction_release_polish.gd`
  - scene-wide configuration for memorials, characters, breakers, journals and exits

## Headphone audio architecture

- `scripts/audio/online_audio_library.gd`
  - asynchronous optional CC0 pack preparation
  - runtime OGG and WAV loading
  - procedural fallback compatibility
- `scripts/audio/sfx_director.gd`
  - Music, Ambience, SFX, Dialogue and UI buses
  - footsteps, jumps, landings, interactions and transition effects
  - positional environmental details
- `scripts/audio/memory_train_audio.gd`
  - train-specific layered and positional audio
- `scripts/audio/nightclub_spatial_audio.gd`
  - positional metal failures throughout the ruined club
- `scripts/audio/music_director.gd`
  - soundtrack caching, long crossfades and dialogue ducking

CC0 sources and cache behavior are documented in `assets/audio/CC0_AUDIO_LIBRARY.md`.

## Startup preparation

`scripts/bootstrap/startup_preloader.gd` now warms:

- all five chapter scenes
- optional online audio
- cemetery, road, nightclub and chamber environment models

The former void ZIP download, extraction and GLB warmup have been removed from the active startup path. The Memory Train uses procedural geometry and audio, so it does not need a remote model archive.

## Archived implementation layers

The former void scripts remain in the repository as inactive implementation history:

- `scripts/world/afterlife_void.gd`
- `scripts/world/afterlife_void_release.gd`
- `scripts/world/void_glb_expansion.gd`
- `scripts/world/void_glb_loader.gd`

They are not referenced by `scenes/afterlife_city.tscn` or the active startup preloader. They should not initialize during a normal playthrough.

## Asset behavior

- Kenney model and sound provenance is documented under `assets/`.
- Runtime-downloaded optional assets are cached under `user://`.
- Procedural geometry and generated audio remain available offline.
- Unreleased music files remain excluded from Git.
- Missing optional music does not block gameplay.

## Manual release test matrix

Run the full game from `scenes/main.tscn` once with a clean `user://` cache and once with populated caches.

### Title screen and startup

- Verify startup reaches 100% and unlocks Begin Story.
- Verify the chapter list says Memory Train rather than Void.
- Verify mouse and keyboard focus on Begin Story, Controls, Back and Quit.
- Verify Controls closes with Back and Escape.
- Verify Begin Story cannot be double-triggered.
- Verify no developer-facing download or missing-audio errors appear.

### Every exploration chapter

- Verify objective cards fit at 1280×720, 1920×1080 and ultrawide.
- Verify Escape opens Pause and Resume restores mouse capture.
- Verify Restart Chapter and Return to Title stop chapter audio.
- Verify interaction prompts, hold progress and one-shot markers.
- Verify walking, sprinting, jumping and landing audio pacing.

### Cinematic dialogue

- Verify dialogue freezes exploration movement and hides the HUD.
- Verify gameplay camera, mouse mode and audio levels restore afterward.
- Verify Enter/E reveal and response keys 1–4.
- Verify each response produces one choice sound.
- Verify every camera angle avoids clipping.
- Complete every cemetery and chamber outcome.

### Cemetery

- Inspect the memorial and edited narrative copy.
- Confirm the woman appears only after the memorial.
- Complete trust, doubt and defiance routes.
- Verify the Pontiac cue begins after the conversation.

### Pontiac memory

- Verify A/D steering and mouse-wheel camera control.
- Verify integrity and distance remain readable.
- Verify failure and completion screens use polished buttons.
- Verify the completion screen describes the railroad crossing.
- Verify the button says Board the Memory Train.
- Verify boarding fades and changes scene once.

### Memory Train — general

- Verify the old void does not appear or begin downloading assets.
- Verify Rockstar starts with a long fade while train layers begin immediately.
- Verify A/D changes lanes and Space jumps throughout gameplay camera cuts.
- Verify damage produces screen shake, impact audio and a visible integrity loss.
- Verify three losses rewind the current train section without restarting the chapter.
- Verify headphones clearly place impacts, sparks and metal strain left or right.
- Verify all UI text remains readable during shake and flashes.

### Memory Train — passenger car

- Verify luggage requires a jump and shadow passengers require lane movement.
- Verify the side-collision cutscene does not disable controls.
- Verify the phantom train passes in the correct direction.
- Verify camera returns to the normal chase position.

### Memory Train — track split

- Verify A selects Follow Her and D selects Follow Yourself.
- Verify E confirms the highlighted route.
- Verify the timer safely selects the current route when it reaches zero.
- Verify route confirmation tilts the train, plays the switch and changes story text.
- Complete the level once on each route.

### Memory Train — roof

- Verify the roof-transition camera returns control cleanly.
- Verify signal frames, live cables and roof gaps are avoidable.
- Verify the passing-train sequence keeps jump and lane input active.
- Verify the bridge-collapse warning gives enough time to jump.
- Verify repeated gaps cannot spawn an impossible pattern.

### Memory Train — engine

- Verify all three control-bank prompts appear in order.
- Verify left, center and right alignment checks use the correct lane.
- Verify correct alignment plays a stable confirmation.
- Verify incorrect alignment damages but does not soft-lock the stage.
- Verify the engine reaches the finale after the third control bank.

### Memory Train — finale

- Verify the nightclub gate approaches during the action camera push.
- Verify layered horn, sparks, impacts, shake and FOV ramp remain performant.
- Verify the final flash changes to the preloaded ruined nightclub scene once.
- Verify Memory Train ambience and Rockstar fade out during the transition.

### Ruined Club

- Verify all three breakers and hold interactions.
- Verify distant metal failures appear at different headphone positions.
- Verify balcony access and the upper breaker remain reachable.
- Verify the backstage exit activates only after all breakers.

### Skeleton Chamber

- Verify all three journal interactions and page audio.
- Verify journals cannot be counted twice.
- Verify the woman remains disabled until all journals are read.
- Complete truth, defiance and mercy routes.

### First-run and offline audio

- Delete `user://out_of_time_audio_v1` and launch from the title screen.
- Verify the startup UI remains responsive during optional audio preparation.
- Relaunch and confirm caches prevent repeated archive work.
- Disconnect the network, clear the cache and verify the complete story remains playable.
- Verify Memory Train procedural audio is always available offline.

## Final build gate

1. Complete the full matrix in an actual Godot build.
2. Run a clean Windows export outside the editor.
3. Test with optional music present and absent.
4. Test first-run preparation online and offline.
5. Record one uninterrupted full playthrough.
6. Review the train once on headphones and once on laptop speakers.
7. Confirm export credits and third-party asset provenance are present.
