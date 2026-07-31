# Kenney Level Expansion Assets

The cemetery, Pontiac bridge, ruined nightclub and skeleton chamber use additional official Kenney GLB models loaded by:

`scripts/world/kenney_level_expansion.gd`

The void uses separate space-focused Kenney packs documented in `KENNEY_VOID_PACKS.md`.

## Sources

### Kenney Starter Kit 3D Platformer

- Repository: `KenneyNL/Starter-Kit-3D-Platformer`
- Pinned commit: `3fa8a04b1c01ab23db43123d4ce814a34c3fc7f0`
- License for included 3D assets: CC0 1.0
- Models used:
  - `brick.glb`
  - `cloud.glb`
  - `flag.glb`
  - `grass-small.glb`
  - `grass.glb`
  - `platform-grass-large-round.glb`
  - `platform-large.glb`
  - `platform-medium.glb`
  - `platform.glb`
  - `Textures/colormap.png`

### Kenney Starter Kit FPS

- Repository: `KenneyNL/Starter-Kit-FPS`
- Pinned commit: `185fd2326d74a5cf858cffc616f87cf9696f9cc0`
- License for included 3D assets: CC0 1.0
- Models used:
  - `wall-high.glb`
  - `wall-low.glb`
  - `platform-large-grass.glb`
  - `Textures/colormap.png`

## Runtime cache

The files are downloaded from the pinned official GitHub revisions on first use and cached under:

`user://kenney_level_expansion`

Later scene loads reuse the cached files. If a download is unavailable, existing procedural art remains active so progression is not blocked.

Attribution is not required for CC0 assets, but source information is retained for provenance and appreciation.
