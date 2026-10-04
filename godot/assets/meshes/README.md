# Meshes — Teomor

- `_src/` — сырые zip с Drive/itch (**gitignore**, не пушить).
- `props/` — отобранное для сцен:
  - `kenney/` GLB
  - `propslite/`, `dungeon_items/`
  - `mushrooms/` — **PS1 Mushroom Asset Pack** (FBX→GLB + PNG)
  - `character/Dummy.*`, `humanoid/Humanoid.*` — референс роста ~1.8 м
- `modular/` — двери/забор proto (CC0)
- `env/` — HDRI

В сценах: `build_scenes.gd` → `_add_mesh_prop` / `_mushroom` / `_mushroom_cluster`.

Шейдер из SourceCode.zip: `assets/shaders/stylized_toon.gdshader` (toon; пока не навешан на всю сцену).

Масштаб / огромный AABB: [`SCALE.md`](SCALE.md).
