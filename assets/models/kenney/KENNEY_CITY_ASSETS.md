# Kenney City Models

The afterlife city uses a curated subset of official Kenney GLB assets from:

- Repository: `KenneyNL/Starter-Kit-City-Builder`
- Pinned source commit: `4535092b740b378b700efd9df9e27a631815b84a`
- Original creator: Kenney
- Asset license: Creative Commons Zero 1.0 Universal (CC0)
- Project page: `https://github.com/KenneyNL/Starter-Kit-City-Builder`
- Kenney asset library: `https://kenney.nl/assets`

Kenney states that the 3D assets included in the starter kit are CC0 licensed. Attribution is not required, but it is included here as appreciation and to preserve provenance.

## Runtime asset cache

To avoid adding a large collection of binary models to the Git repository, `scripts/world/kenney_city_loader.gd` downloads the pinned official GLB files and shared color-map texture on the first city load. Files are cached under:

`user://kenney_city`

Later city loads use the local cache and do not download the models again. If the download is unavailable, the original procedural city remains active so gameplay is never blocked.

## Curated models

- `road-straight.glb`
- `road-intersection.glb`
- `road-corner.glb`
- `road-split.glb`
- `road-straight-lightposts.glb`
- `pavement.glb`
- `pavement-fountain.glb`
- `building-small-a.glb`
- `building-small-b.glb`
- `building-small-c.glb`
- `building-small-d.glb`
- `building-garage.glb`
- `grass-trees.glb`
- `grass-trees-tall.glb`
- `Textures/colormap.png`
