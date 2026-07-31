# Kenney Void GLB Packs

The expanded void chapter loads selected GLB models from two official Kenney asset packs.

## Space Station Kit

- Official page: `https://kenney.nl/assets/space-station-kit`
- Runtime archive: `https://kenney.nl/media/pages/assets/space-station-kit/6475288f2e-1712749919/kenney_space-station-kit.zip`
- License: Creative Commons CC0 1.0
- Intended uses in the void chapter:
  - broken station structures
  - wall and window fragments
  - pillars and door frames
  - stairs, display props and rock clusters

## Space Kit

- Official page: `https://www.kenney.nl/assets/space-kit`
- Runtime archive: `https://www.kenney.nl/media/pages/assets/space-kit/20874c75ac-1677698978/kenney_space-kit.zip`
- License: Creative Commons CC0 1.0
- Intended uses in the void chapter:
  - asteroids
  - satellites
  - spacecraft
  - planets
  - distant station silhouettes

## Runtime behavior

`scripts/world/void_glb_loader.gd` downloads each official ZIP once, preserves the archive folder structure, and extracts GLB files together with their referenced textures.

The texture-aware cache is stored under:

`user://kenney_void_assets_v2`

Downloaded ZIP archives are kept under:

`user://kenney_void_assets`

The loader searches extracted model names by descriptive keywords, so minor archive folder-layout differences do not break the chapter. Procedural void geometry remains in place as a fallback if a download or model import fails.

Attribution is not required for CC0 assets, but these sources are retained for provenance and appreciation.
