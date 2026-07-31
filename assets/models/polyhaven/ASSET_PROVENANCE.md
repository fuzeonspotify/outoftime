# Poly Haven Environment Assets

The active environment replacement system downloads and caches the exact assets listed below from the official Poly Haven API during startup.

**Source:** https://polyhaven.com/

**API:** https://api.polyhaven.com/

**License:** CC0 / public domain. See https://polyhaven.com/license

**Powered by Poly Haven.**

## Required models

- `street_lamp_01`
- `painted_wooden_bench`
- `dead_quiver_trunk`
- `street_lamp_02`
- `concrete_road_barrier_02`
- `marble_bust_01`
- `chandelier_01`
- `flower_empodium`
- `bar_chair_round_01`
- `industrial_coffee_table`
- `wine_barrel_01`
- `industrial_wall_sconce`
- `shelf_01`
- `gothic_coffee_table`
- `wooden_chair_01`

## Required PBR materials

- `monastery_stone_floor`
- `asphalt_02`
- `marble_01`
- `scuffed_cement`
- `stone_floor`
- `rock_ground`

## Runtime policy

- The loader selects the 1K glTF package first, then 2K or 4K only when necessary.
- The complete downloaded package for each individual model must be 50 MB or less.
- Model dependencies and PBR maps are cached under `user://out_of_time_polyhaven_required_v1`.
- These are required primary assets. There is no low-poly or procedural environment-model fallback.
- If a required asset cannot be downloaded or loaded, story startup remains locked and reports the exact missing asset.
