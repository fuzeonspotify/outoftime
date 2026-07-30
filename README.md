# Out of Time

**A short cinematic game and interactive music experience by FuzeXO.**

> You were never the first.

You play as a skeleton who wakes in a surreal afterlife, falls in love with a mysterious woman, and follows her across a dying world. He believes he is saving her. Near the end, he discovers a chamber filled with skeletons just like him—each carrying the same flower, weapon, journal and promise. She has repeated the journey many times. His attempt ends with her betrayal and his death.

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

1. Clone or download this repository.
2. Open Godot 4.
3. Select **Import** and choose `project.godot`.
4. Press **F6/F5** to run the prototype.

The project currently includes a runnable title screen, soundtrack-plan screen, local/private audio configuration and a music director that crossfades between story cues.

## Add local music

Put game-ready OGG files in `assets/audio/local/` using the filenames documented in that folder. Music files are intentionally ignored by Git so master recordings are not published in this public repository.

## Development order

- Player controller and cinematic third-person camera
- Cemetery greybox level
- Interaction and dialogue system
- Woman companion behavior
- Pontiac on-rails driving sequence
- Story triggers and adaptive music
- Chamber reveal and ending cutscene
- Lighting, audio, export and release polish

## Technical direction

- Engine: Godot 4
- Visual style: stylized low-poly, neon afterlife, heavy fog and cinematic lighting
- Platform target: Windows first, then web if performance allows
- Scope rule: one unforgettable short experience instead of a large unfinished game
