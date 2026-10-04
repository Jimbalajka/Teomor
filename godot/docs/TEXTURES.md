# Текстуры стиля (attic / alley) — v1.4 depth

## Файлы
`godot/assets/textures/style/`

На каждый материал:
- `*_512.png` — albedo **с запечённой глубиной** (AO + soft bevel из normal)
- `*_n_512.png` — normal
- `*_r_512.png` — roughness

| Стем | Зона | CC0 / рефы |
|------|------|------------|
| `tex_attic_plaster` | стены чердака | Plaster003 |
| `tex_attic_wood` | пол/балки | WoodSiding001 + WoodFloor044 |
| `tex_alley_stone` | стены переулка | PavingStones070 + Rocks022 + пурпур `Эмб1` |
| `tex_alley_floor` | пол переулка | pavement/concrete + ink |
| `tex_metal_barrel` | металл | MetalPlates006 + Rust001 |
| `tex_ink_grime` | швы | `стиль 1.1/` |
| `tex_vsegrib_*` | грибы | `Грибы/` + синтетический normal |

Сырьё: `assets/textures/_src/` (gitignore).

## Зачем так
Фидбек автора / DD: не плоский «наклеенный PNG», а глубина + единый стиль; без мозаичного тайлинга.

В Godot: normal+rough + **per-mesh UV offset/jitter** (`build_scenes.gd`).

## Пересборка
См. [`TOOLS.md`](TOOLS.md).

```bash
cd godot
python3 scripts/tools/fetch_open_materials.py
python3 scripts/bake_style_textures.py
python3 scripts/tools/check_textures.py
godot4 --path . --headless -s res://scripts/build_scenes.gd
```

Лицензии: ambientCG **CC0**; авторские рефы — собственность автора.
