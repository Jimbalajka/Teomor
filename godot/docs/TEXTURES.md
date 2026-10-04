# Текстуры стиля (attic / alley)

## Файлы
`godot/assets/textures/style/`

| Файл | Зона | Состав |
|------|------|--------|
| `tex_attic_plaster_512.png` | чердак стены | ambientCG **Plaster003** + тёплый wash + ink |
| `tex_attic_wood_512.png` | пол/балки/мебель | **WoodSiding001** + WoodFloor044/051 → пергамент/дерево |
| `tex_ink_grime_512.png` | швы/потолки | `стиль 1.1/` (ч/б индустриал) |
| `tex_alley_stone_512.png` | стены переулка | **PavingStones070** / Rocks022 + пурпур `цвет/Эмб1` |
| `tex_alley_floor_512.png` | пол переулка | камень + ink + bleed плоти |
| `tex_vsegrib_flesh_512.png` | наросты/ножки | `Грибы/` + `Эмб1` |
| `tex_vsegrib_cap_512.png` | шляпки | `Грибы/` graded to purple glow |
| `tex_metal_barrel_512.png` | металл | **MetalPlates006** + **Rust001** + purple blot |

Сырьё CC0: `assets/textures/_src/` (gitignore, перекачивается скриптом).

## Цель читаемости
Не огромные одноцветные пиксели. Должны читаться **доски / камень / штукатурка**.  
Bake держит структуру CC0 (`grade_keep_structure` + local contrast), палитра — wash, не замена.

Проверка:
```bash
python3 scripts/tools/check_textures.py
```

## Лицензии
- **ambientCG** — [CC0](https://ambientcg.com/list?type=Material&sort=Popular)
- Авторские папки `цвет/`, `Грибы/`, `стиль 1.1/`, `Стиль ост/`, `Стиль мои рисунки*` — собственность автора Теомора

## Пересборка
См. [`TOOLS.md`](TOOLS.md).

```bash
cd godot
python3 scripts/tools/fetch_open_materials.py
python3 scripts/bake_style_textures.py
python3 scripts/tools/check_textures.py
godot4 --path . --headless -s res://scripts/build_scenes.gd
```

Промпты на случай будущей нейрогенки: [`AI_ASSETS.md`](AI_ASSETS.md).
