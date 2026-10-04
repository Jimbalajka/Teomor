---
name: author-assets-intake
description: >-
  Приём папок/zip/маппинга текстур от автора Теомора. Включай сам когда
  кидают Текстурки, zip, «дерево=пол…». Куда класть, имена, вшивка — без
  своей раскладки поверх авторской.
---

# author-assets-intake

## Куда
- Сырьё zip → `godot/assets/textures/_src/author/` (gitignore)
- Рабочие 512 albedo/n/r → `godot/assets/textures/author/`
- Указатель → `Текстурки/README.md`
- Документ → `docs/TEXTURES.md`

## Раскладка (не изобретать)
Слушать автора. Текущий канон v1.5:
wood→пол/доски · concrete→внутр. стены · brick→массив · tile→цоколь ·
metal→детали · floor_mix→пол переулка · грибы остаются в `style/`

## После приёма
1. Извлечь / нормализовать 512
2. Вшить в `build_scenes.gd` (TEX_* / пути)
3. Rebuild сцен
4. Обновить TEXTURES + SESSION; пуш — по ship-for-look
