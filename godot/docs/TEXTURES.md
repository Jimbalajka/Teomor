# Текстуры стиля (attic / alley)

## Файлы
`godot/assets/textures/style/`

| Файл | Зона | Состав |
|------|------|--------|
| `tex_attic_plaster_512.png` | чердак стены | ambientCG Plaster001 + тон `Стиль мои рисунки` + ink overlay |
| `tex_attic_wood_512.png` | пол/мебель | ambientCG WoodFloor051 → пергамент/дерево + ink |
| `tex_ink_grime_512.png` | швы/потолки | `стиль 1.1/` (ч/б индустриал) |
| `tex_alley_stone_512.png` | стены переулка | ambientCG Rocks022 + пурпур `цвет/Эмб1` |
| `tex_alley_floor_512.png` | пол переулка | камень + ink + bleed плоти |
| `tex_vsegrib_flesh_512.png` | наросты/ножки | `Грибы/` + `Эмб1` |
| `tex_vsegrib_cap_512.png` | шляпки | `Грибы/` graded to purple glow |
| `tex_metal_barrel_512.png` | металл | ambientCG Metal032 + purple blot + ink |

Сырьё CC0 лежит в `assets/textures/_src/` (не обязательно в билде).

## Лицензии
- **ambientCG** текстуры — [CC0](https://ambientcg.com/list?type=Material&sort=Popular)
- Авторские папки `цвет/`, `Грибы/`, `стиль 1.1/`, `Стиль ост/`, `Стиль мои рисунки*` — собственность автора Теомора

## Пересборка
```bash
cd godot
python3 scripts/bake_style_textures.py
godot4 --path . --headless -s res://scripts/build_scenes.gd
```

Промпты на случай будущей нейрогенки: [`AI_ASSETS.md`](AI_ASSETS.md).
