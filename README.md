# Out of Time

**A cinematic psychological afterlife game and interactive music experience by FuzeXO.**

> You were never the first.

You play as a skeleton who wakes in a surreal afterlife and follows a mysterious woman through memories that feel increasingly rehearsed. What begins as a rescue becomes a cycle: a cemetery, a spectral Pontiac ride, a gravity-fractured void, a ruined nightclub and a chamber filled with the people who followed her before.

## Playable experience

The current Godot 4 project contains a connected five-chapter vertical slice:

1. **The Cemetery** — awaken, examine the memorial and question the woman at the gate.
2. **The Memory Bridge** — steer the spectral Pontiac through failed memories.
3. **The Void** — cross floating ruins while gravity shifts, reverses and nearly disappears.
4. **The Ruined Club** — restore three breakers while the spectral crowd closes in.
5. **The Chamber** — recover the journals and confront the truth behind the cycle.

The build includes:

- Third-person movement, sprinting, jumping and spring-arm camera collision
- Contextual hold-to-interact prompts with world markers and progress feedback
- Branching conversations with multiple responses and outcome-specific objectives
- Cinematic dialogue cameras, close-ups, two-shots, wide shots and letterbox presentation
- Typewriter dialogue pacing, numbered response shortcuts and dedicated choice feedback
- Chapter objectives, narrative message cards and memory-signal HUD effects
- Pause, restart chapter, return-to-title and quit controls in every chapter
- Headphone-focused Music, Ambience, SFX, Dialogue and UI buses
- Positional environmental details, dialogue ducking and independent room treatment
- Runtime-loaded CC0 Kenney sound and GLB packs with procedural fallbacks
- Responsive 16:9-first UI that expands safely to wider and taller windows

## Controls

| Input | Action |
| --- | --- |
| `WASD` | Move or steer |
| Mouse | Rotate camera |
| Mouse wheel | Adjust the Pontiac camera |
| `Shift` | Sprint |
| `Space` | Jump |
| Hold `E` | Interact |
| `Enter` or `E` | Reveal dialogue text / continue |
| `1`–`4` | Select dialogue response |
| `Esc` | Pause |

## Open the project

1. Clone or pull this repository.
2. Open Godot 4.7.
3. Import `project.godot` when opening the project for the first time.
4. Press **F5**.
5. Select **BEGIN STORY**.

The first launch can take longer while official CC0 model and sound packs are cached asynchronously. Later sessions use the local caches. Procedural geometry and generated sound effects remain available if an asset download fails or the player is offline.

## Optional local music

Place game-ready OGG files in `assets/audio/local/` using these filenames:

- `okay.ogg`
- `pontiac.ogg`
- `rockstar.ogg`
- `circles.ogg`
- `out_of_time.ogg`

The audio files are ignored by Git so unreleased master recordings are not published in this repository. The game remains playable when a cue is missing.

## Soundtrack structure

| Act | Song | Narrative purpose |
| --- | --- | --- |
| The Mask | Okay | The skeleton acts fine despite waking broken and confused |
| The False Love | Pontiac | The happiest and most trusting memory |
| The Rush | Rockstar | Power, speed and denial inside the ruined club |
| The Reveal | Circles | Recovered journals expose the repeated manipulation |
| The Death | Out of Time | Betrayal, collapse and the final emotional payoff |

## Technical direction

- Engine: Godot 4.7
- Visual style: stylized low-poly neon afterlife with fog, memory-signal UI and cinematic lighting
- Primary target: Windows desktop
- Rendering: GL Compatibility
- Scope: one focused short experience rather than a large unfinished game

## Asset provenance

Kenney model sources are documented under `assets/models/kenney/`. Runtime sound sources, licenses and cache behavior are documented in `assets/audio/CC0_AUDIO_LIBRARY.md`. The referenced packs are CC0; source records are retained for provenance even where attribution is not required.
