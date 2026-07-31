# Realistic Runtime Model Sources

The following optional models are downloaded during the title-screen preparation phase and cached under `user://`. They are never downloaded during active gameplay. Existing procedural models remain as offline or importer fallbacks.

## Main character skull

- Asset: **Skull / ScatteringSkull**
- Repository: KhronosGroup `glTF-Sample-Assets`
- Creator: Vladimir Petkovic
- License: Creative Commons CC0 1.0 Universal
- Runtime file: `Models/ScatteringSkull/glTF-Binary/ScatteringSkull.glb`
- Use in game: normalized to the animated procedural skeleton body and given subtle violet eye lights.

## Ghost woman body and clothing

- Asset: **Corset**
- Repository: KhronosGroup `glTF-Sample-Assets`
- Creator credit: Microsoft; asset record © 2017 UX3D
- License: Creative Commons CC0 1.0 Universal
- Runtime file: `Models/Corset/glTF-Binary/Corset.glb`
- Use in game: spectral female mannequin/corset base with transparent PBR materials, a ghost face, hair silhouette and emissive eyes.

## Memory Road vehicle

- Asset: **Car Concept**
- Repository: KhronosGroup `glTF-Sample-Assets`
- Creator: Eric Chadwick, Darmstadt Graphics Group GmbH
- License: Creative Commons Attribution 4.0 International
- Original source: public-domain concept car by Unity Fan
- Runtime file: `Models/CarConcept/glTF-Binary/CarConcept.glb`
- Use in game: primary bridge and crash vehicle, automatically normalized and tinted for the memory-road palette.

The Car Concept attribution must remain in distributed credits because its optimized model and textures are CC BY 4.0. The Skull and Corset assets are CC0, but their credits are retained here as good provenance practice.
