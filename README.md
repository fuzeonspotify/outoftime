# Out of Time

**A cinematic psychological afterlife game and interactive music experience by FuzeXO.**

> You were never the first.

You play as a skeleton who wakes in a surreal afterlife and follows a mysterious woman through memories that feel increasingly rehearsed. What begins as a rescue becomes a cycle: a cemetery, a spectral Pontiac ride, an impossible midnight train, a ruined nightclub and a chamber filled with the people who followed her before.

## Playable experience

The current Godot 4 project contains a connected five-chapter vertical slice:

1. **The Cemetery** — awaken, examine the memorial and question the woman at the gate.
2. **The Memory Road** — steer the spectral Pontiac through failed memories.
3. **The Memory Train** — dodge through passenger cars, choose a track, run the roof and stabilize an engine with no driver.
4. **The Ruined Club** — restore three breakers while the spectral crowd closes in.
5. **The Chamber** — recover the journals and confront the truth behind the cycle.

The build includes:

- Third-person movement, sprinting, jumping and spring-arm camera collision
- Contextual hold-to-interact prompts with world markers and progress feedback
- Branching conversations with multiple responses and outcome-specific objectives
- Cinematic dialogue cameras, close-ups, two-shots, wide shots and letterbox presentation
- A three-lane action chapter with jumping, damage, checkpoint rewind and route choice
- Mid-game train collisions, passing-train shots, roof transitions and a bridge-collapse set piece
- Camera shake, impact flashes, FOV ramps and an action finale that crashes into the nightclub
- Typewriter dialogue pacing, numbered response shortcuts and dedicated choice feedback
- Chapter objectives, narrative message cards and memory-signal HUD effects
- Pause, restart chapter, return-to-title and quit controls in every chapter
- Headphone-focused Music, Ambience, SFX, Dialogue and UI buses
- Train-specific sub-rumble, wheel rhythm, wind, horns, sparks, brakes and positional metal strain
- Runtime-loaded optional CC0 Kenney assets with procedural fallbacks
- Responsive 16:9-first UI that expands safely to wider and taller windows

## Controls

| Input | Action |
| --- | --- |
| `WASD` | Move or steer |
| `A` / `D` | Change train lane / choose track |
| Mouse | Rotate camera |
| Mouse wheel | Adjust the Pontiac camera |
| `Shift` | Sprint |
| `Space` | Jump / vault |
| Hold `E` | Interact |
| `E` | Confirm the highlighted train track |
| `Enter` or `E` | Reveal dialogue text / continue |
| `1`–`4` | Select dialogue response |
| `Esc` | Pause |

## Open the project

1. Clone or pull this repository.
2. Open Godot 4.7.
3. Import `project.godot` when opening the project for the first time.
4. Press **F5**.
5. Select **BEGIN STORY**.

The first launch can take longer while official optional model and sound packs are cached. The former void model archives are no longer part of the active startup path. The Memory Train uses procedural geometry and generated audio, so it remains fully playable offline.

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
| The Rush | Rockstar | The Memory Train accelerates through denial, danger and impossible momentum |
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
