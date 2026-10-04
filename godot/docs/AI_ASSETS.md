# AI-ассеты — Теомор (чердак + Грибной)

**Зачем:** якорь стиля принят условно (`STYLE_ANCHOR.md`). Без грязных текстур судить рано.  
**Кто что делает:** ты — реф/ОК «похоже»; нейронка — сырьё; я — сажаю в Godot, ломаю под якорь (Nearest, desat, ink).

Я сам меши/текстуры «как в Бличе» не рисую. Ниже — готовые промпты и порядок генерации.

---

## Что генерить первым (чеклист)

Только **5–8 тайловых albedo** на slice. Без моделей, без PBR-пачек, без склада/библиотеки.

| # | Файл (цель) | Зона | Доминанта | Рефы img2img |
|---|-------------|------|-----------|--------------|
| 1 | `tex_attic_plaster_alb.png` | чердак — стены | пергамент | `стиль 1.1/`, `Стиль ост/` |
| 2 | `tex_attic_floorboards_alb.png` | чердак — пол | пергамент/дерево | `стиль 1.1/`, `Стиль мои рисунки/` |
| 3 | `tex_attic_beam_alb.png` | чердак — балки | тёмное дерево + ink | `стиль 1.1/` |
| 4 | `tex_alley_stone_alb.png` | переулок — стены/земля | пурпур-грязь | `цвет/Эмб1.jpg`, `стиль 1.1/` |
| 5 | `tex_mushroom_cap_alb.png` | всегриб — шляпка | пурпур | `Грибы/`, `цвет/` |
| 6 | `tex_mushroom_flesh_alb.png` | стебель/наросты | пурпур приглуш. | `Грибы/` |
| 7 | `tex_ink_grime_overlay.png` | общий оверлей пятен | чернила | `стиль 1.1/`, `Стиль ост/` |
| 8 | *(опц.)* `tex_barrel_metal_alb.png` | бочки/железо | ink + ржавч. пергамент | `Стиль ост/` |

**Размер:** 512×512 или 1024×1024, **tileable / seamless**.  
**Формат:** PNG, без альфы (кроме #7 — можно с альфой).  
**Куда класть:** `godot/assets/textures/style_v1/`.

После ОКки — напиши «готово» / кинь файлы → я подключу в `build_scenes.gd` вместо procedural noise.

---

## Colab с нуля
Пошагово открыть/GPU/готовый ноутбук: [`COLAB_START.md`](COLAB_START.md) → `colab/teomor_seamless.ipynb`.

## Инструмент

| Задача | Лучший выбор |
|--------|----------------|
| Тайлы стен/пола | **Flux / SDXL + ComfyUI**, img2img по рефам |
| Быстро «на глаз» | Leonardo / Scenario (потом всё равно давим в Godot) |
| Midjourney | только mood, **не** для тайлов |
| 3D позже | Meshy / Tripo / Rodin → glTF; low-poly + перекраска |

**Godot import (обязательно):** Filter = **Nearest**, Repeat = Enabled, без mipmaps-blur если возможно.

---

## Общий якорь (вшивать в каждый промпт)

```
Teomor style anchor: dirty parchment yellow, diseased purple, black ink strokes.
One dominant color only. PS2 Silent Hill + Dread Delusion + White Knuckle grit,
pixelated film grain, halftone, cross-hatching, desaturated, never clean PBR,
never neon, never glossy, never pure white. Seamless tileable texture, top-down
flat albedo, no perspective, no characters, no UI, no watermark.
```

### Negative (общий)

```
clean PBR, photoreal, sharp 8k, vibrant rainbow, neon glow, anime cel, plastic,
glossy, chrome, bloom, depth of field, 3d render showcase, text, logo, border,
frame, character, face, hands, perspective room, furniture showcase
```

### Палитра из кода (ориентир)

- parchment `rgb(158,128,71)` / dark `rgb(92,71,41)`
- purple `rgb(107,41,97)` / glow `rgb(140,46,122)`
- ink `rgb(13,10,13)`
- wood `rgb(102,71,41)`

---

## Промпты по слотам

Копируй **якорь + слот**. Strength img2img: **0.35–0.55** (выше — уезжает от рефа).

### 1. Чердак — штукатурка / стены

```
seamless tileable dirty attic plaster wall albedo, stained parchment yellow
dominant, dust, water marks, black ink speckles and pen-stroke cracks,
halftone grain, worn medieval hovel, flat lighting, desaturated ochre
```

Реф: `стиль 1.1/*` (зерно) + лёгкий цвет с пергамента.

### 2. Чердак — половицы

```
seamless tileable worn wooden floorboards albedo, dirty parchment brown-yellow,
scratches, ink-dark gaps between planks, PS2 texture grit, no shine, flat ortho
```

### 3. Чердак — балка

```
seamless tileable dark timber beam wood grain albedo, almost black-brown ink,
rough hewn, fungus speckles faint purple dust in pores, desaturated, flat
```

### 4. Грибной переулок — камень/земля

```
seamless tileable damp ghetto alley ground and wall mix albedo, diseased muddy
purple dominant, wet dirt, mushroom spore stains, black ink puddles, sickly
paper fill in cracks, Silent Hill fog grit, never clean cobblestone photo
```

Реф: `цвет/Эмб1.jpg` (пурпур формы) + `стиль 1.1/` (грязь).

### 5. Шляпка всегриба

```
seamless tileable organic mushroom cap skin albedo, bruised purple dominant,
small spores and warty growths, soft subsurface look but dirty not cute,
ink pores, desaturated magenta-violet, flat, no cute toadstool white spots
```

Реф: `Грибы/Screenshot_*.png`, `цвет/`.

### 6. Плоть / стебель / нарост

```
seamless tileable spongy fungal flesh albedo, muted purple-brown, fibrous,
rot patches, black ink veins, diseased growth, horror indie PS2, flat tile
```

### 7. Оверлей чернильной грязи (с альфой)

```
seamless transparent grunge overlay, black ink splatters, pen strokes,
cross-hatching, film dust, screentone dots, sparse on transparent background,
no color, high contrast, tileable
```

### 8. (опц.) Бочка / железо

```
seamless tileable rusted barrel metal albedo, dark ink iron, parchment rust
stains, dents, never chrome, flat industrial grit like Blame ink wash
```

---

## Правило кадра (после вставки)

Как в `STYLE_ANCHOR.md` / Блич TYBW:

- **Чердак** — доминирует пергамент; пурпур только пятнами/углом.
- **Грибной** — доминирует пурпур; пергамент только в fill/пыли.
- Не смешивать три базы поровну в одном кадре.

---

## 3D — не сейчас

Когда текстуры встанут и якорь «принят» окончательно:

1. low-poly crate / barrel / mushroom cluster (Meshy/Tripo)
2. перекраска материалами из `assets/textures/style_v1/`
3. ломать форму blob-наростками (как `_growth_blob` в `build_scenes.gd`)

Промпт-заготовка меша:

```
low poly game asset, PS2 era, ~500-1500 tris, diseased purple mushroom cluster
with spore warts, no PBR showcase, dull, single mesh, glTF friendly
```

---

## Приёмка (твой ОК)

Текстура ок, если:

1. один цвет доминирует;
2. выглядит грязно / «кино-чб + пятно», не магазинный PBR;
3. тайлится без шва при Nearest;
4. на чердаке не орёт пурпуром; в переулке не орёт чистым жёлтым.

Кидай файлы или пиши «готово N» по номерам из чеклиста.
