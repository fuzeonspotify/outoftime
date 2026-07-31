# Out of Time — Runtime CC0 Audio Library

The game uses selected sound effects from official Kenney audio packs. Kenney releases the assets on these pages under Creative Commons CC0 1.0.

## Source packs

### Interface Sounds

- Official page: `https://kenney.nl/assets/interface-sounds`
- OpenGameArt mirror archive: `https://opengameart.org/sites/default/files/kenney_interfaceSounds.zip`
- Used for:
  - menu hover and confirmation feedback
  - dialogue typewriter ticks
  - dialogue response selection
  - cancel and back feedback

### Sci-Fi Sounds

- Official page: `https://kenney.nl/assets/sci-fi-sounds`
- OpenGameArt mirror archive: `https://opengameart.org/sites/default/files/sci-fi_sounds.zip`
- Used for:
  - gravity anchors and force fields
  - void pulses
  - portal and chapter transitions
  - low-frequency reveals
  - machinery and power restoration

### Impact Sounds

- Official page: `https://kenney.nl/assets/impact-sounds`
- Used for:
  - grass and concrete footsteps
  - landing reinforcement
  - ruined-club metal impacts

The current loader resolves the official Kenney archive URL from the asset page. The procedural footstep and landing sounds remain available when the archive cannot be resolved.

### RPG Audio

- Official page: `https://kenney.nl/assets/rpg-audio`
- OpenGameArt mirror archive: `https://opengameart.org/sites/default/files/RPGsounds_Kenney.zip`
- Used for:
  - journal and page interactions
  - book handling
  - distant creaks and environmental details

## Runtime behavior

`scripts/audio/online_audio_library.gd` downloads the packs asynchronously and extracts only `.ogg` and `.wav` files. The cache is stored outside the project under:

`user://out_of_time_audio_v1`

The repository does not redistribute the downloaded archives or extracted files. Every cue has a generated procedural fallback, so menus, interactions and progression continue to work when the player is offline or a remote source is unavailable.

## Headphone mix

The runtime audio system separates:

- Music
- Ambience
- World SFX
- Dialogue
- UI

Ambience and dialogue use independent room treatment. Environmental details are positioned around the listener with `AudioStreamPlayer3D`, while dialogue temporarily ducks the music and environmental beds.

Attribution is not required by CC0, but source information is retained for provenance and appreciation.
