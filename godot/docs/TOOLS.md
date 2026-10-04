# Tools — только для `godot/` (project-scoped)

Узкие помощники, чтобы дожимать текущий якорь стиля. Не глобальные плагины Cursor.

## Зачем
Авторский фидбек: пиксели слишком крупные/одноцветные — должны читаться **доски, камень, штукатурка**, в духе Dread Delusion / грязного инди.

## Команды

```bash
cd godot

# 1) открытые CC0 материалы (ambientCG)
python3 scripts/tools/fetch_open_materials.py

# 2) перепечь albedo под палитру Теомора (структура материала сохраняется)
python3 scripts/bake_style_textures.py

# 3) проверка «не плоский ли PNG»
python3 scripts/tools/check_textures.py

# 4) пересборка сцен
godot4 --path . --headless -s res://scripts/build_scenes.gd
```

## Файлы
| Путь | Роль |
|------|------|
| `scripts/tools/fetch_open_materials.py` | качает CC0 albedo в `_src/` |
| `scripts/bake_style_textures.py` | печёт `assets/textures/style/` |
| `scripts/tools/check_textures.py` | метрика detail/flatness |
| `scripts/build_scenes.gd` | UV tiling + материалы в `.tscn` |
| `.cursor/rules/teomor-style.mdc` | правила агента только в этом проекте |

## Источники
- [ambientCG](https://ambientcg.com/) — CC0
- Авторские рефы в корне репо: `цвет/`, `Грибы/`, `стиль 1.1/`, `Стиль ост/`

## Позже (не сейчас)
Aseprite CLI, ORM/normal bake, remote gen по `AI_ASSETS.md`.
