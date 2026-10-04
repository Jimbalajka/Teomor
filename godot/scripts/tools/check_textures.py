#!/usr/bin/env python3
"""Check style albedo readability (structure / flatness).

Usage:
  python3 scripts/tools/check_textures.py
"""
from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
STYLE = ROOT / "assets" / "textures" / "style"

# Heuristic gates for "material reads" (not photo-real).
MIN_BLOCK = {
    "tex_attic_wood_512.png": 0.075,
    "tex_alley_stone_512.png": 0.08,
    "tex_attic_plaster_512.png": 0.06,
    "tex_alley_floor_512.png": 0.06,
    "tex_metal_barrel_512.png": 0.05,
    "tex_ink_grime_512.png": 0.06,
    "tex_vsegrib_flesh_512.png": 0.07,
    "tex_vsegrib_cap_512.png": 0.07,
}


def stats(path: Path, block: int = 32) -> dict:
    arr = np.asarray(Image.open(path).convert("RGB"), dtype=np.float32) / 255.0
    h, w, _ = arr.shape
    blocks = [
        arr[y : y + block, x : x + block].std()
        for y in range(0, h - block, block)
        for x in range(0, w - block, block)
    ]
    return {
        "mean": arr.mean(axis=(0, 1)),
        "gstd": float(arr.std()),
        "block": float(np.median(blocks) if blocks else 0.0),
    }


def main() -> int:
    if not STYLE.exists():
        print("MISSING", STYLE)
        return 1
    bad = 0
    print(f"DIR {STYLE}")
    for path in sorted(STYLE.glob("*.png")):
        if path.name.endswith("_emit_512.png"):
            continue
        s = stats(path)
        need = MIN_BLOCK.get(path.name)
        flag = ""
        if need is not None and s["block"] < need:
            flag = f"  LOW_DETAIL need>={need:.2f}"
            bad += 1
        m = s["mean"]
        print(
            f"{path.name:32s} mean=[{m[0]:.3f} {m[1]:.3f} {m[2]:.3f}] "
            f"gstd={s['gstd']:.3f} block={s['block']:.3f}{flag}"
        )
    if bad:
        print(f"FAIL detail_checks={bad}")
        return 2
    print("OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
