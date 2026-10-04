# Текстуры стиля — author packs v1.5

## Файлы
godot/assets/textures/author/ — рабочие 512 (albedo / normal / rough)

| Стем | Зона | Источник (авторская папка Текстурки) |
|------|------|----------------------------------------|
| wood_weathered | пол / балки / доски | wood_peeling_paint_weathered_1k |
| concrete | внутренние стены, надстройки | cracked_concrete_1k |
| brick_broken | основной массив зданий | broken_brick_wall_1k |
| brick_mossy | запас / сырые пятна | mossy_brick_1k |
| tile_worn | низ зданий (цоколь) | worn_tile_floor_1k |
| floor_mix | пол переулка | бетон + керамика |
| metal_rusty | бочки / карнизы / металл | rusty_metal_02_1k |

Грибы / ink-grime пока в assets/textures/style/ (tex_vsegrib_*, tex_ink_grime).

Сырьё zip: assets/textures/_src/author/ (gitignore). Указатель: Текстурки/README.md.

## Зачем так
Авторские бесшовные карты уже под цветокор; отказ от плоских наклеенных bake-only PNG.
Раскладка от автора: дерево=пол, бетон=внутр. стены, кирпич=массив, керамика=низ, металл=детали, пол=бетон+керамика.

В Godot: normal+rough + per-mesh UV jitter (build_scenes.gd).

## Пересборка
См. TOOLS.md.

```bash
cd godot
godot4 --path . --headless -s res://scripts/build_scenes.gd
```

Лицензии: паки из Текстурки — от автора (Poly Haven–подобные 1k); старые ambientCG CC0 в style/ как запас.

## Hand-paint
Бесшовка в Krita: [`KRITA_SEAMLESS.md`](KRITA_SEAMLESS.md).
