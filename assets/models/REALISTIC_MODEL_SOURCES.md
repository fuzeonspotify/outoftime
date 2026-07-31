# Runtime Lead-Character and Vehicle Sources

These optional models are prepared during the title-screen loading phase and cached under `user://`. No character or vehicle download begins during active gameplay. Procedural scene geometry remains available only as an offline/importer fallback.

## Main player — complete rigged skeleton

- Asset: **KayKit Skeleton Minion** (`Skeleton_Minion.glb`)
- Source: KayKit Character Pack — Skeletons
- License: Creative Commons CC0 1.0 Universal
- Runtime cache: `user://out_of_time_rigged_characters_v3/`
- Model properties: one complete skinned skeleton character with a `Skeleton3D` armature and embedded animation library
- Use in game: the complete body replaces every visible procedural player mesh. The runtime controller selects embedded idle, walk, run and airborne animations according to player movement.

When the KayKit skeleton cannot be downloaded or imported, the game attempts Khronos' **Rigged Figure** sample. That fallback contains a complete skin and animation data and is licensed under Creative Commons Attribution 4.0 by Cesium.

## Ghost woman — complete rigged body

- Asset: **MPFB example avatar** (`mpfb.glb`)
- Source: met4citizen `TalkingHead`
- Creation toolchain: Blender and MPFB / MakeHuman assets
- License: Creative Commons CC0 1.0 Universal
- Runtime cache: `user://out_of_time_rigged_characters_v3/`
- Model properties: complete full-body avatar with a Mixamo-compatible armature
- Use in game: the complete skinned avatar replaces all placeholder woman meshes in both the Cemetery and Chamber. Its original opaque PBR surfaces and textures remain intact; ghostliness comes from restrained grading, emission and scene lighting rather than transparent replacement clothing.

When the MPFB avatar is unavailable, the game attempts the complete rigged **KayKit Mage** character under CC0. No head-only, corset-only or synthetic clothing layer is installed by the active character system.

## Memory Road vehicle

- Asset: **Car Concept**
- Repository: KhronosGroup `glTF-Sample-Assets`
- Creator: Eric Chadwick, Darmstadt Graphics Group GmbH
- License: Creative Commons Attribution 4.0 International
- Original source: public-domain concept car by Unity Fan
- Runtime file: `Models/CarConcept/glTF-Binary/CarConcept.glb`
- Use in game: primary bridge/crash vehicle with its PBR glass, interior, wheels and body materials preserved. Showcase branding is hidden where the model exposes it through mesh or material names.

The Car Concept and Rigged Figure attribution must remain in distributed credits because those optimized assets are CC BY 4.0. The KayKit and MPFB primary character models are CC0, but their credits are retained here for provenance.
