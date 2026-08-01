# Poly Haven Environment Assets

The active environment replacement system downloads and caches the exact assets listed below from the official Poly Haven API during startup.

**Source:** https://polyhaven.com/

**API:** https://api.polyhaven.com/

**License:** CC0 / public domain. See https://polyhaven.com/license

**Powered by Poly Haven.**

## Required original replacement models

- `street_lamp_01`
- `painted_wooden_bench`
- `dead_quiver_trunk`
- `street_lamp_02`
- `concrete_road_barrier_02`
- `chandelier_01`
- `flower_empodium`
- `bar_chair_round_01`
- `industrial_coffee_table`
- `wine_barrel_01`
- `industrial_wall_sconce`
- `shelf_01`
- `gothic_coffee_table`
- `wooden_chair_01`

`marble_bust_01` was removed from the required set and is not instantiated in False Heaven.

## Required expanded models

- `planter_box_01`
- `painted_wooden_sofa`
- `ceramic_vase_01`
- `covered_car`
- `utility_box_01`
- `metal_trash_can`
- `sofa_02`
- `modern_coffee_table_01`
- `television_01` (official legacy slug `Television_01`)
- `cassette_player`
- `sofa_01` (official legacy slug `Sofa_01`)
- `classic_nightstand_01` (official legacy slug `ClassicNightstand_01`)
- `wooden_table_03` (official legacy slug `WoodenTable_03`)
- `wooden_candlestick`
- `side_table_01`
- `plastic_monobloc_chair_01`

## Required PBR materials

- `monastery_stone_floor`
- `asphalt_02`
- `marble_01`
- `scuffed_cement`
- `stone_floor`
- `rock_ground`

## Level use

- **Cemetery:** expanded arrival courtyard and side burial gardens, realistic lamps, benches, planters, vases and an abandoned chair.
- **Memory Road:** extended driving distance, utility cabinets, covered vehicles and weathered trash cans.
- **False Heaven:** expanded ceremonial arrival court, planters and vases; no sculpture-head models.
- **Ruined Nightclub:** expanded lobby and side lounges with sofas, tables, television, cassette player and industrial props.
- **Skeleton Chamber:** expanded entry crypt and reading alcoves with gothic seating, tables, candlesticks and vases.

## Runtime policy

- The loader selects the 1K glTF package first, then 2K or 4K only when necessary.
- The complete downloaded package for each individual model must be 50 MB or less.
- Model dependencies and PBR maps are cached under `user://out_of_time_polyhaven_required_v2`.
- Downloaded model bundles are accepted only after file-size and MD5 verification.
- These are required primary assets. There is no low-poly or procedural environment-model fallback.
- If a required asset cannot be downloaded or loaded, story startup remains locked and reports the exact missing asset.
