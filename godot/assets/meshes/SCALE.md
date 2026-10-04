# Масштаб мешей (почему «огромный бокс»)

Godot считает **1 unit = 1 метр**. У паков единицы разные.

| Ассет | Сырой FBX | GLB после UFBX-конверта | Import / scale в сцене |
|-------|-----------|-------------------------|------------------------|
| `props/character/Dummy.fbx` | высота ~184 (см) | **~1.84 м** | GLB → scale **1.0**; raw FBX в редакторе Root Scale **0.01** |
| `props/humanoid/Humanoid.fbx` | ~1.8 | **~1.80 м** | GLB → **1.0**; прятать mesh `*Overlapping*` |
| `props/mushrooms/Mushroom*_SM` | ~0.3–0.5 | метры, Y-up | scale 1.0–1.5; albedo `Mushrooms_T.png` |
| `props/mushrooms/MushroomCluster_SM` | ~0.3 | метры | scale 1.5–2.5; albedo `MushroomCluster_T.png` |
| `modular/proto/Pieces_*.fbx` | куб 2×2×2 | — | proto-grid, не баг |
| Kenney `.glb` | ~1 м | ок | 1.0 |

## Почему бокс огромный
1. **Dummy.fbx без 0.01** в редакторе = гигант ~180 м. Для headless/билда используй **Dummy.glb** (уже в метрах).
2. **Proto pieces** сами крупные модули.
3. Выделение родителя = AABB всех детей.

## Канон роста
- Игрок: капсула **~1.85 м** (`player_fps.stand_height`).
- Референс: **Dummy.glb / Humanoid.glb ≈ 1.8 м**.
- Стоячие НПС в билде → Humanoid.glb.
