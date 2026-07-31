# Out of Time

**A cinematic psychological afterlife game and interactive music experience by FuzeXO.**

> You were never the first.

You play as a skeleton who wakes in a surreal afterlife and follows a mysterious woman through memories that feel increasingly rehearsed. What begins as a rescue becomes a cycle: a cemetery, a spectral Pontiac ride, a fatal bridge crash, a Heaven that reveals itself as a lie, a ruined nightclub and a chamber filled with the people who followed her before.

## Playable experience

The current Godot 4 project contains a connected five-chapter vertical slice:

1. **The Cemetery** — awaken, examine the memorial and question the woman at the gate.
2. **The Memory Road** — steer a real CC0 car model through failed memories before the bridge collapses into a cinematic crash.
3. **The Welcome** — wake in a Heaven-like procession where walking toward the distant gate darkens the atmosphere and corrupts the angels, while turning back restores them.
4. **The Ruined Club** — restore three breakers while the spectral crowd closes in.
5. **The Chamber** — recover the journals and confront the truth behind the cycle.

The build includes:

- Third-person movement, sprinting, jumping and spring-arm camera collision
- Contextual hold-to-interact prompts with world markers and progress feedback
- Branching conversations with multiple responses and outcome-specific objectives
- Cinematic dialogue cameras, close-ups, two-shots, wide shots and letterbox presentation
- A seamless bridge-to-crash-to-Heaven transition with no completion menu between chapters
- A startup-cached CC0 Kenney vehicle with a procedural offline fallback
- Crash camera cuts, guardrail destruction, screen shake, tire screech, metal impact, glass and tinnitus effects
- A fully reversible position-driven corruption system for lighting, fog, architecture, plants, particles, audio and NPC behavior
- Twenty-six angel NPCs whose halos, wings, eyes, horns, posture and attention transform continuously into demonic forms
- Directional headphone whispers and a choir/drone mix that changes with the player's location
- Typewriter dialogue pacing, numbered response shortcuts and dedicated choice feedback
- Chapter objectives, narrative message cards and memory-signal HUD effects
- Pause, restart chapter, return-to-title and quit controls throughout the game
- Headphone-focused Music, Ambience, SFX, Dialogue and UI buses
- Runtime-loaded optional CC0 Kenney assets with procedural fallbacks
- Responsive 16:9-first UI that expands safely to wider and taller windows

## Controls

| Input | Action |
| --- | --- |
| `WASD` | Move or steer |
| Mouse | Rotate camera |
| Mouse wheel | Adjust the Memory Road camera |
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

The first launch can take longer while optional sound, environment and car assets are cached. The CC0 car archive is prepared before Begin Story becomes available, so the bridge crash does not download or unpack files during gameplay. Procedural vehicle, geometry and audio fallbacks keep the complete story playable offline.

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
| The False Love | Pontiac | The happiest and most trusting memory, ending in the bridge crash |
| The Welcome | Procedural Heaven score | Choir and light dissolve into whispers, heartbeat and corruption as the illusion fails |
| The Rush | Rockstar | Power, speed and denial inside the ruined club |
| The Reveal | Circles | Recovered journals expose the repeated manipulation |
| The Death | Out of Time | Betrayal, collapse and the final emotional payoff |

## Technical direction

- Engine: Godot 4.7
- Visual style: stylized neon afterlife with fog, memory-signal UI and cinematic lighting
- Primary target: Windows desktop
- Rendering: GL Compatibility
- Scope: one focused short experience rather than a large unfinished game

## Asset provenance

Kenney model sources are documented under `assets/models/kenney/`. The bridge car comes from Kenney's **Car Kit**, released under Creative Commons CC0. Runtime sound sources, licenses and cache behavior are documented in `assets/audio/CC0_AUDIO_LIBRARY.md`. Source records are retained for provenance even where attribution is not required.
