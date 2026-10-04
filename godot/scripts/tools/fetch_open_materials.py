#!/usr/bin/env python3
"""Fetch open CC0 material packs (albedo/normal/rough/AO) into _src/.

Source: ambientCG (CC0). No account.

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

PACKS = {
    "wood_boards": "https://ambientcg.com/get?file=WoodSiding001_1K-JPG.zip",
    "wood_planks": "https://ambientcg.com/get?file=WoodFloor044_1K-JPG.zip",
    "plaster": "https://ambientcg.com/get?file=Plaster003_1K-JPG.zip",
    "stone_pavement": "https://ambientcg.com/get?file=PavingStones070_1K-JPG.zip",
    "stone_rocks": "https://ambientcg.com/get?file=Rocks022_1K-JPG.zip",
    "metal": "https://ambientcg.com/get?file=MetalPlates006_1K-JPG.zip",
    "metal_rust": "https://ambientcg.com/get?file=Rust001_1K-JPG.zip",
    "concrete": "https://ambientcg.com/get?file=Concrete034_1K-JPG.zip",
}

MAP_KEYS = (
    ("color", ("color", "diff", "albedo")),
    ("normal", ("normalgl", "normal_gl", "normal")),
    ("rough", ("rough",)),
    ("ao", ("ambientocclusion", "ao", "occlusion")),
)


def _pick_name(names: list[str], needles: tuple[str, ...]) -> str | None:
    ranked: list[tuple[int, str]] = []
    for n in names:
        ln = n.lower().replace("\\", "/")
        base = ln.rsplit("/", 1)[-1]
        if not base.endswith((".jpg", ".jpeg", ".png")):
            continue
        for i, needle in enumerate(needles):
            if needle in base.replace("_", "").replace("-", "") or needle in base:
                # prefer NormalGL over NormalDX
                score = i
                if "normaldx" in base.replace("_", ""):
                    score += 10
                ranked.append((score, n))
                break
    if not ranked:
        return None
    ranked.sort()
    return ranked[0][1]


def fetch(key: str, url: str) -> bool:
    SRC.mkdir(parents=True, exist_ok=True)
    color_path = SRC / f"{key}_color.jpg"
    need_download = not color_path.exists() or color_path.stat().st_size < 10_000
    # also re-extract if maps missing
    for suffix, _ in MAP_KEYS:
        if not (SRC / f"{key}_{suffix}.jpg").exists():
            need_download = True
    zip_path = SRC / f"{key}.zip"
    data = None
    if need_download:
        if zip_path.exists() and zip_path.stat().st_size > 50_000:
            data = zip_path.read_bytes()
            print("USE_ZIP", zip_path)
        else:
            print("GET", url)
            req = urllib.request.Request(url, headers={"User-Agent": "TeomorOpenMaterials/2.0"})
            try:
                with urllib.request.urlopen(req, timeout=180) as resp:
                    data = resp.read()
            except Exception as e:
                print("FAIL", key, e)
                return False
            zip_path.write_bytes(data)
    else:
        print("HAVE", key)
        return True

    assert data is not None
    with zipfile.ZipFile(io.BytesIO(data)) as zf:
        names = zf.namelist()
        ok_any = False
        for suffix, needles in MAP_KEYS:
            pick = _pick_name(names, needles)
            if pick is None:
                print("MISS_MAP", key, suffix)
                continue
            im = Image.open(io.BytesIO(zf.read(pick))).convert("RGB")
            out = SRC / f"{key}_{suffix}.jpg"
            im.save(out, quality=93)
            print("WROTE", out.name, im.size)
            ok_any = True
        return ok_any


def main() -> int:
    ok = 0
    for key, url in PACKS.items():
        if fetch(key, url):
            ok += 1
    print(f"DONE packs_ok={ok}/{len(PACKS)} dir={SRC}")
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
