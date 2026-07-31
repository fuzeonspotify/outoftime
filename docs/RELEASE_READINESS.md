# Out of Time — Release Readiness Audit

This document records the repository cleanup, player-facing polish systems and final manual test matrix for the current five-chapter build.

## Active scene flow

1. `scenes/main.tscn`
2. `scenes/cemetery.tscn`
3. `scenes/road_memory.tscn`
4. `scenes/afterlife_city.tscn` — retained as a compatibility path; the scene root and content are the Afterlife Void
5. `scenes/ruined_nightclub.tscn`
6. `scenes/skeleton_chamber.tscn`

Keeping the existing `afterlife_city.tscn` path avoids breaking saved scene references and the Pontiac handoff. No city buildings or city-only loaders remain attached to it.

## Release UI architecture

- `scripts/ui/ui_style.gd`
  - shared angular signal-panel, label, button and progress-bar styling
  - consistent hover, focus and confirmation audio
- `scripts/ui/main.gd`
  - public title screen, controls screen and fade transition
- `scripts/player/third_person_controller.gd`
  - objective card, chapter identity, interaction prompt, hold progress, narrative messages, crosshair feedback and pause menu
- `scripts/ui/memory_hud_effects.gd`
  - vignette, drifting scanlines, corner framing and chapter signal telemetry
- `scripts/ui/scene_ui_polish.gd`
  - consistent styling for chapter-specific HUD labels, end screens, buttons and 3D text
- `scripts/world/road_release_polish.gd`
  - Memory Bridge copy, HUD presentation and pause menu

## Cinematic dialogue architecture

- `data/dialogues.json`
  - branching cemetery and chamber conversations
  - response tone and outcome data
  - camera-shot instructions
- `scripts/dialogue/dialogue_director.gd`
  - typewriter dialogue and numbered response choices
  - speaker close-ups, player close-ups, two-shots and wide shots
  - letterbox, scanlines and memory-link presentation
  - dialogue-specific sound feedback and music ducking
- `scripts/dialogue/cinematic_player_lock.gd`
  - freezes movement and exploration input during conversations
  - hides and restores the exploration HUD safely
- `scripts/dialogue/cemetery_dialogue_integration.gd`
  - replaces the cemetery's former single-line woman interaction
  - applies trust, doubt or defiance outcomes
- `scripts/dialogue/chamber_dialogue_integration.gd`
  - replaces the final single-line confrontation
  - applies truth, defiance or mercy outcomes

## Release interaction architecture

- `scripts/world/interactable.gd`
  - configurable action title and context
  - hold-to-interact timing
  - world-space diamond, ring and guide beam
  - proximity pulse and color feedback
  - one-shot and repeatable interaction handling
  - narrative response or cinematic-dialogue handoff
- `scripts/world/interaction_release_polish.gd`
  - scene-wide configuration for memorials, characters, gravity anchors, power breakers, journals and exits
  - edited public-facing interaction copy
  - action-specific hold timing and marker presentation

## Headphone audio architecture

- `scripts/audio/online_audio_library.gd`
  - asynchronous CC0 pack download and extraction
  - runtime OGG and WAV loading
  - keyword-based cue selection
- `scripts/audio/sfx_director.gd`
  - separate Music, Ambience, SFX, Dialogue and UI buses
  - independent ambience and dialogue reverb
  - footsteps, jumps, landings, interactions and transition effects
  - positional environmental detail using `AudioStreamPlayer3D`
  - procedural fallback sounds when downloaded audio is unavailable
- `scripts/audio/nightclub_spatial_audio.gd`
  - distant positional metal failures throughout the ruined club
- `scripts/audio/music_director.gd`
  - Music bus routing and dialogue ducking

CC0 sound sources and cache behavior are documented in `assets/audio/CC0_AUDIO_LIBRARY.md`.

## Intentionally retained implementation layers

The following pairs use inheritance intentionally and are not abandoned duplicates:

- `scripts/world/afterlife_void.gd`
  - complete large-scale void implementation
- `scripts/world/afterlife_void_release.gd`
  - release checkpoint and gravity-anchor overrides
- `scripts/world/void_glb_expansion.gd`
  - complete Kenney archive download, import and placement implementation
- `scripts/world/void_glb_loader.gd`
  - texture-aware recursive extraction and production cache behavior

`scripts/models/octahedron_mesh.gd` remains because the complete base void implementation references its registered mesh class while loading.

## Removed legacy and temporary files

The release pass removed or replaced:

- the procedural city loader and city cleanup scripts
- the unused city audio wrapper
- the old city asset document
- the bridge copy-repair script
- temporary `_v2` void filenames
- generic `runtime_fixes`, `nightclub_layout_fix` and `model_alignment_fixes` filenames
- prototype title-screen status and soundtrack-planning UI
- single-line character conversations in the cemetery and chamber

Necessary behavior from generic fix scripts was preserved under scoped production names:

- `cemetery_memorial_alignment.gd`
- `nightclub_balcony_access.gd`
- `model_runtime_alignment.gd`

## Asset behavior

- Kenney model sources and licenses are documented under `assets/models/kenney/`.
- Kenney sound sources and licenses are documented under `assets/audio/`.
- Runtime-downloaded assets are cached under `user://`.
- Procedural geometry and generated audio remain available when a remote archive cannot be downloaded or imported.
- Unreleased music files remain excluded from Git.
- Missing optional music cues do not block gameplay or display developer-facing messages to players.

## Manual release test matrix

Run the full game from `scenes/main.tscn` with a clean `user://` cache and again with a populated cache.

### Title screen

- Verify mouse and keyboard focus on Begin Story, Controls, Back and Quit.
- Verify every hover/focus produces one restrained UI sound.
- Verify every press produces one confirmation sound.
- Verify Controls closes with Back and Escape.
- Verify Begin Story fades into the cemetery once and cannot be double-triggered.
- Verify no developer, prototype or missing-audio status appears.

### Every exploration chapter

- Verify objective card text fits at 1280×720, 1920×1080 and one ultrawide resolution.
- Verify the memory vignette, scanlines, corner frame and chapter code remain subtle.
- Verify controls hint fades out without hiding the objective.
- Verify Escape opens Pause and Resume restores captured mouse input.
- Verify Restart Chapter reloads cleanly.
- Verify Return to Title stops chapter audio.
- Verify interaction prompts appear only for enabled objects.
- Verify releasing E before completion resets hold progress.
- Verify one-shot markers disappear after activation.
- Verify repeatable interactions require E to be released before triggering again.
- Verify overlapping interaction areas do not leave a stuck prompt.
- Verify walking, sprinting, jumping and landing produce correctly paced effects.

### Cinematic dialogue

- Verify entering dialogue freezes player movement and hides both exploration HUD layers.
- Verify the active gameplay camera is restored after every outcome.
- Verify mouse focus, keyboard focus, Enter/E reveal and response keys 1–4.
- Verify a response produces one dialogue-choice sound rather than stacked clicks.
- Verify typewriter ticks remain quiet enough under headphones.
- Verify music and ambience duck smoothly at dialogue start and restore afterward.
- Verify every speaker, player, two-shot and wide camera position avoids clipping geometry.
- Verify text wraps at 1280×720 and ultrawide resolutions.
- Verify rapidly pressing Enter cannot skip two nodes at once.

### Cemetery

- Inspect the memorial and verify edited narrative copy.
- Confirm the woman and her marker appear only after the memorial interaction.
- Confirm the gate remains behind the woman.
- Complete trust, doubt and defiance conversation routes.
- Verify each route produces the intended objective after the cinematic ends.
- Verify the Pontiac cue begins only after the conversation completes.

### Memory Bridge

- Verify A/D steering and mouse-wheel camera control.
- Verify title and instructions use release copy.
- Verify memory integrity and distance remain readable during motion.
- Verify failure and completion screens use polished buttons.
- Verify the completion button says Enter the Void.
- Verify Pause, Restart, Return to Title and Quit work while driving.

### Void

- Verify all three anchor markers are initially visible and the portal marker is hidden.
- Verify low, inverted, near-zero and restored gravity boundaries.
- Verify every recovery checkpoint returns the player to reachable geometry.
- Verify anchor hold interactions and force-field feedback.
- Verify positional void pulses move around the listener rather than playing only in the center.
- Verify the portal activates only after all three anchors.
- Test once with an empty Kenney cache and once with cached files.
- Verify model and sound download failure leaves the procedural route playable.

### Ruined Club

- Verify all three breaker markers and hold interactions.
- Verify each breaker uses machinery/power-restoration feedback.
- Verify distant metal failures appear at different positions under headphones.
- Verify the balcony access ramp is clear and the upper breaker is reachable.
- Verify disabled backstage exit has no marker or prompt.
- Verify the backstage exit activates after all breakers.
- Verify stability and breaker HUD elements remain readable over lighting pulses.

### Skeleton Chamber

- Verify all three journal prompts, hold progress, page audio and narrative text.
- Verify journals cannot be counted twice.
- Verify the woman interaction remains disabled until all journals are read.
- Complete truth, defiance and mercy confrontation routes.
- Verify each route restores the camera and reaches the chapter-end presentation once.

### First-run and offline audio

- Delete `user://out_of_time_audio_v1` and launch from the title screen.
- Verify the UI remains responsive while packs download asynchronously.
- Verify procedural fallback sounds play before downloads complete.
- Verify downloaded sounds begin appearing without restarting when packs become ready.
- Relaunch and confirm cached audio requires no repeated archive download.
- Disconnect the network, clear the cache and verify the complete game remains playable.
- Check that no remote failure message appears in player-facing UI.

## Final build gate

Before distributing the game publicly:

1. Complete the full manual matrix above in an actual Godot build.
2. Run a clean Windows export outside the editor.
3. Test with optional music files present and absent.
4. Test first-run Kenney model and sound downloads on a normal residential connection.
5. Test the same build offline with empty caches.
6. Record at least one uninterrupted full playthrough and review every UI, dialogue and camera transition at playback speed.
7. Review the complete game once on headphones and once on laptop speakers.
8. Confirm export credits and third-party asset provenance are included wherever the final distribution presents credits.
