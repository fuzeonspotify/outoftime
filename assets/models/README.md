# Optional imported model overrides

The game uses improved in-engine fallback models and automatically switches to imported `.glb` models when files are placed at these paths:

- `assets/models/characters/skeleton_player.glb`
- `assets/models/characters/mysterious_woman.glb`
- `assets/models/vehicles/pontiac_coupe.glb`
- `assets/models/vehicles/abandoned_coupe.glb`
- `assets/models/environment/dead_tree.glb`
- `assets/models/props/club_speaker.glb`

Keep model origins near ground level, face them toward negative Z, and apply transforms before export. Missing files safely use the detailed procedural fallback models, so gameplay never depends on an external asset being present.
