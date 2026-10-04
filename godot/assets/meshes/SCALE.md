# Масштаб мешей — без ручного Root Scale

Godot: **1 unit = 1 метр**. Сырые FBX у паков разные; чтобы не крутить Import руками:

1. **Канон в сценах — `.glb`**, уже в метрах (`scripts/bake_mesh_meters.gd`).
2. **`.import` для FBX закоммичены** с нужным `nodes/root_scale` — drag-and-drop FBX тоже ок после pull.

| Ассет | Было неудобно | Сейчас |
|-------|----------------|--------|
| `props/character/Dummy` | казался ~180 м | **GLB ~1.84 м**, FBX import scale **1.0** |
| `props/humanoid/Humanoid` | — | **GLB ~1.80 м**, FBX import **1.0** |
| `modular/proto/Pieces_*` | куб 2 м / стены 4 м | bake **×0.5** → сетка **1 м**; FBX import **0.5** |
| `modular/proto/Character_Character` | ~2.4 м, кривой up-axis | bake **×0.85**; в сцене крутить **X = -90°** (или брать Dummy/Humanoid) |
| `props/mushrooms/*` | — | GLB метры, Y-up |
| Kenney `.glb` | ок | 1.0 |

## Перепечь после новых FBX
```bash
godot4 --path godot --headless -s res://scripts/bake_mesh_meters.gd
```
Коммить и `.glb`, и соседние `.import`.

## Канон роста Теомора
- Игрок: **~1.85 м**
- Dummy / Humanoid: **~1.8 м**
- Стоячие НПС в билде = Humanoid.glb
