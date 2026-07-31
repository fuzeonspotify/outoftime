# Runtime Lead-Character and Vehicle Sources

These optional models are prepared during the title-screen loading phase and cached under `user://`. No character or vehicle download begins during active gameplay. Procedural scene geometry remains available only as an offline/importer fallback.

## Main player — complete rigged body

- Asset: **3D Male Base Mesh**
- Original creator: orange-juice-games
- Godot mirror/maintainer: BoQsc `Godot-3D-Male-Base-Mesh`
- License: Creative Commons CC0 1.0 Universal
- Runtime package: `male_base_mesh.zip`
- Model properties: one complete UV-unwrapped male body with a full armature
- Use in game: the full skinned model replaces the old procedural skeleton geometry and is animated through its `Skeleton3D` bones.

When the primary package cannot be loaded, the game attempts Khronos' **Rigged Figure** sample. That fallback contains skins and animations and is licensed under Creative Commons Attribution 4.0 by Cesium.

## Ghost woman — complete rigged body

- Asset: **MPFB example avatar (`mpfb.glb`)**
- Source: met4citizen `TalkingHead`
- Creation toolchain: Blender and MPFB / MakeHuman assets
- License: Creative Commons CC0 1.0 Universal
- Model properties: complete full-body avatar with a Mixamo-compatible armature
- Use in game: the complete skinned avatar replaces the old mannequin/extra-head hybrid in both the Cemetery and Chamber. Spectral treatment is applied to the model's existing full-body surfaces; no separate top, head or hair mesh is added by the game.

## Memory Road vehicle

- Asset: **Car Concept**
- Repository: KhronosGroup `glTF-Sample-Assets`
- Creator: Eric Chadwick, Darmstadt Graphics Group GmbH
- License: Creative Commons Attribution 4.0 International
- Original source: public-domain concept car by Unity Fan
- Runtime file: `Models/CarConcept/glTF-Binary/CarConcept.glb`
- Use in game: primary bridge/crash vehicle with its PBR glass, interior, wheels and body materials preserved. Showcase branding is hidden where the model exposes it through mesh or material names.

The Car Concept and Rigged Figure attribution must remain in distributed credits because those optimized assets are CC BY 4.0. The primary player and MPFB ghost-woman models are CC0, but their credits are retained here for provenance.
