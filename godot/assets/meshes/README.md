# Meshes — Teomor

- `_src/` — сырые zip с Drive/itch (**gitignore**, не пушить). Сейчас: `model.zip` / распаковка.
- `props/` — отобранное для сцен (Kenney GLB, PropsLite, Dungeon Items, Dummy)
- `modular/` — двери/забор proto (CC0)
- `env/` — HDRI (Daysky)

В сценах: `build_scenes.gd` → `_add_mesh_prop`.
Приоритет п.2: Kenney barrels/crates/overhang + dungeon gates + proto doors.

Не в git (только _src): Medieval Village ~161MB, soiTavern ~322MB, PSX Modular Medieval.
