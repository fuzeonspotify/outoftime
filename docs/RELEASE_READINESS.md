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
  - shared panel, label, button and progress-bar styling
- `scripts/ui/main.gd`
  - public title screen, controls screen and fade transition
- `scripts/player/third_person_controller.gd`
  - objective card, chapter identity, interaction prompt, hold progress, narrative messages, crosshair feedback and pause menu
- `scripts/ui/scene_ui_polish.gd`
  - consistent styling for chapter-specific HUD labels, end screens, buttons and 3D text
- `scripts/world/road_release_polish.gd`
  - Memory Bridge copy, HUD presentation and pause menu

## Release interaction architecture

- `scripts/world/interactable.gd`
  - configurable action title and context
  - hold-to-interact timing
  - world-space diamond, ring and guide beam
  - proximity pulse and color feedback
  - one-shot and repeatable interaction handling
  - narrative response dispatch
- `scripts/world/interaction_release_polish.gd`
  - scene-wide configuration for memorials, characters, gravity anchors, power breakers, journals and exits
  - edited public-facing interaction copy
  - action-specific hold timing and marker presentation

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

Necessary behavior from generic fix scripts was preserved under scoped production names:

- `cemetery_memorial_alignment.gd`
- `nightclub_balcony_access.gd`
- `model_runtime_alignment.gd`

## Asset behavior

- Kenney asset sources and licenses are documented under `assets/models/kenney/`.
- Runtime-downloaded assets are cached under `user://`.
- Procedural geometry remains available when a model archive cannot be downloaded or imported.
- Unreleased music files remain excluded from Git.
- Missing optional music cues do not block gameplay or display developer-facing messages to players.

## Manual release test matrix

Run the full game from `scenes/main.tscn` with a clean `user://` cache and again with a populated cache.

### Title screen

- Verify mouse and keyboard focus on Begin Story, Controls, Back and Quit.
- Verify Controls closes with Back and Escape.
- Verify Begin Story fades into the cemetery once and cannot be double-triggered.
- Verify no developer, prototype or missing-audio status appears.

### Every exploration chapter

- Verify objective card text fits at 1280×720, 1920×1080 and one ultrawide resolution.
- Verify controls hint fades out without hiding the objective.
- Verify Escape opens Pause and Resume restores captured mouse input.
- Verify Restart Chapter reloads cleanly.
- Verify Return to Title stops chapter audio.
- Verify interaction prompts appear only for enabled objects.
- Verify releasing E before completion resets hold progress.
- Verify one-shot markers disappear after activation.
- Verify repeatable interactions require E to be released before triggering again.
- Verify overlapping interaction areas do not leave a stuck prompt.

### Cemetery

- Inspect the memorial and verify edited narrative copy.
- Confirm the woman and her marker appear only after the memorial interaction.
- Confirm the gate remains behind the woman.
- Confirm the woman interaction completes the prologue transition.

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
- Verify anchor hold interactions and progress text.
- Verify the portal activates only after all three anchors.
- Test once with an empty Kenney cache and once with cached files.
- Verify model-download failure leaves the procedural route playable.

### Ruined Club

- Verify all three breaker markers and hold interactions.
- Verify the balcony access ramp is clear and the upper breaker is reachable.
- Verify disabled backstage exit has no marker or prompt.
- Verify the backstage exit activates after all breakers.
- Verify stability and breaker HUD elements remain readable over lighting pulses.

### Skeleton Chamber

- Verify all three journal prompts, hold progress and narrative text.
- Verify journals cannot be counted twice.
- Verify the woman interaction remains disabled until all journals are read.
- Verify the final transition and chapter-complete objective.

## Final build gate

Before distributing the game publicly:

1. Complete the full manual matrix above in an actual Godot build.
2. Run a clean Windows export outside the editor.
3. Test with optional music files present and absent.
4. Test first-run Kenney downloads on a normal residential connection.
5. Record at least one uninterrupted full playthrough and review every UI transition at playback speed.
6. Confirm export credits and third-party asset provenance are included wherever the final distribution presents credits.
