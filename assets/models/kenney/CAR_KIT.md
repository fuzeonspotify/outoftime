# Kenney Car Kit — Bridge Vehicle Source

The Memory Road vehicle is selected at startup from Kenney's **Car Kit**.

- Creator: Kenney
- Official source page: `https://www.kenney.nl/assets/car-kit`
- OpenGameArt mirror: `https://opengameart.org/content/car-kit`
- License: Creative Commons CC0 1.0 Universal
- Formats supplied by the source pack: glTF/GLB, FBX and OBJ
- Runtime cache: `user://kenney_car_kit_v1`

The game downloads the archive during the title-screen preparation phase, extracts GLB or glTF model data and required textures in frame-sized batches, ranks sedan/sports-style candidates, imports the first valid model through Godot's `GLTFDocument`, and keeps the generated prototype in memory for the bridge chapter.

When the archive is unavailable or no candidate imports successfully, the existing procedural vehicle is used so the game remains fully playable offline. Attribution is not required by CC0, but this record is retained for provenance and creator credit.
