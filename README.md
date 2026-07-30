# Out of Time

**A short cinematic game and interactive music experience by FuzeXO.**

> You were never the first.

You play as a skeleton who wakes in a surreal afterlife, falls in love with a mysterious woman, and follows her across a dying world. He believes he is saving her. Near the end, he discovers a chamber filled with skeletons just like him—each carrying the same flower, weapon, journal and promise. She has repeated the journey many times. His attempt ends with her betrayal and his death.

## Current playable build

The first 3D scene is now playable:

- Third-person skeleton controller and cinematic spring-arm camera
- Walking, sprinting and jumping
- Mouse camera controls and collision
- Foggy moonlit cemetery greybox
- Graves, trees, lanterns, gate and memorial
- Reusable `[E]` interaction system
- Memorial story beat and mysterious-woman reveal
- Dynamic `Okay` and `Pontiac` music cues when local audio is available

### Controls

| Input | Action |
| --- | --- |
| `WASD` | Move |
| Mouse | Rotate camera |
| `Shift` | Sprint |
| `Space` | Jump |
| `E` | Interact |
| `Esc` | Release or recapture mouse |

## One-week target

A polished 15–25 minute 3D vertical slice:

1. Cemetery awakening
2. Meeting the woman
3. Spectral Pontiac road sequence
4. High-intensity ruined-club escape
5. Chamber of previous skeletons
6. Betrayal and death
7. Full `Out of Time` ending and credits

## Soundtrack structure

| Act | Song | Narrative purpose |
| --- | --- | --- |
| The Mask | Okay | The skeleton acts fine despite waking broken and confused |
| The False Love | Pontiac | Romantic cinematic drive; the happiest and most trusting moment |
| The Rush | Rockstar | A loud chase/escape where he feels powerful and alive |
| The Reveal | Circles | Repeated journals expose cheating, lies and manipulation as a cycle |
| The Death | Out of Time | Betrayal, collapse and full ending credits |

Most songs will use short edits, instrumentals or stems during gameplay. `Out of Time` is reserved for the complete final emotional payoff.

## Open the project

1. Clone or pull this repository.
2. Open Godot 4.
3. Import `project.godot` when opening it for the first time.
4. Press **F5**.
5. Select **BEGIN** from the title screen.

## Add local music

Put game-ready OGG files in `assets/audio/local/` using these filenames:

- `okay.ogg`
- `pontiac.ogg`
- `rockstar.ogg`
- `circles.ogg`
- `out_of_time.ogg`

Music files are intentionally ignored by Git so unreleased master recordings are not published in this public repository.

## Next development order

- Replace the generated skeleton with a rigged animated character
- Expand the woman encounter into dialogue and companion behavior
- Add the forest/ruined-city transition
- Build the Pontiac on-rails driving sequence
- Add the chamber reveal and ending cutscene
- Complete lighting, audio, export and release polish

## Technical direction

- Engine: Godot 4
- Visual style: stylized low-poly, neon afterlife, heavy fog and cinematic lighting
- Platform target: Windows first, then web if performance allows
- Scope rule: one unforgettable short experience instead of a large unfinished game
