#!/usr/bin/env python3
"""Fetch open CC0 material albedos into assets/textures/_src/.

Sources: ambientCG (CC0). No account.

Usage:
  python3 scripts/tools/fetch_open_materials.py
"""
from __future__ import annotations

import io
import urllib.request
import zipfile
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "assets" / "textures" / "_src"

# Prefer materials with readable mid-frequency structure (boards / stone / plaster).
PACKS = {
    # wood boards / planks (ambientCG CC0)
    "wood_planks": "https://ambientcg.com/get?file=WoodFloor044_1K-JPG.zip",
    "wood_boards": "https://ambientcg.com/get?file=WoodSiding001_1K-JPG.zip",
    "wood": "https://ambientcg.com/get?file=WoodFloor051_1K-JPG.zip",
    # stone / pavement with cracks
    "stone_pavement": "https://ambientcg.com/get?file=PavingStones070_1K-JPG.zip",
    "stone_rocks": "https://ambientcg.com/get?file=Rocks022_1K-JPG.zip",
    # wall plaster / concrete variation
    "plaster": "https://ambientcg.com/get?file=Plaster003_1K-JPG.zip",
    "concrete": "https://ambientcg.com/get?file=Concrete034_1K-JPG.zip",
    # metal / rust (readable plates, not flat brushed)
    "metal": "https://ambientcg.com/get?file=MetalPlates006_1K-JPG.zip",
    "metal_rust": "https://ambientcg.com/get?file=Rust001_1K-JPG.zip",
    "metal_smooth": "https://ambientcg.com/get?file=Metal032_1K-JPG.zip",
}


def fetch(key: str, url: str) -> Path | None:
    SRC.mkdir(parents=True, exist_ok=True)
    color_path = SRC / f"{key}_color.jpg"
    if color_path.exists() and color_path.stat().st_size > 10_000:
        print("HAVE", color_path)
        return color_path
    print("GET", url)
    req = urllib.request.Request(url, headers={"User-Agent": "TeomorOpenMaterials/1.1"})
    try:
        with urllib.request.urlopen(req, timeout=180) as resp:
            data = resp.read()
    except Exception as e:
        print("FAIL", key, e)
        return None
    (SRC / f"{key}.zip").write_bytes(data)
    with zipfile.ZipFile(io.BytesIO(data)) as zf:
        names = [n for n in zf.namelist() if n.lower().endswith((".jpg", ".jpeg", ".png"))]
        pick = None
        for n in names:
            ln = n.lower()
            if "color" in ln or "diff" in ln or "albedo" in ln:
                pick = n
                break
        if pick is None and names:
            pick = names[0]
        if pick is None:
            return None
        im = Image.open(io.BytesIO(zf.read(pick))).convert("RGB")
        im.save(color_path, quality=93)
        print("WROTE", color_path, im.size)
        return color_path


def main() -> int:
    ok = 0
    for key, url in PACKS.items():
        if fetch(key, url) is not None:
            ok += 1
    print(f"DONE fetched_or_cached={ok}/{len(PACKS)} dir={SRC}")
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
