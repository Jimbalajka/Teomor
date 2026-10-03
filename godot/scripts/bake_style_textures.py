#!/usr/bin/env python3
"""Bake Teomor style albedo tiles from author refs + CC0 sources.

Outputs 512 PNG into assets/textures/style/.
No cloud AI / no signup.
"""
from __future__ import annotations

import io
import math
import os
import struct
import urllib.request
import zipfile
from pathlib import Path

import numpy as np
from PIL import Image, ImageEnhance, ImageFilter, ImageOps

ROOT = Path("/home/ec2-user/Teomor")
GODOT = ROOT / "godot"
OUT = GODOT / "assets" / "textures" / "style"
SRC = GODOT / "assets" / "textures" / "_src"
SIZE = 512

# Approx palette anchors from build_scenes.gd
PARCHMENT = np.array([0.62, 0.50, 0.28], dtype=np.float32)
PARCHMENT_DARK = np.array([0.36, 0.28, 0.16], dtype=np.float32)
PURPLE = np.array([0.42, 0.16, 0.38], dtype=np.float32)
PURPLE_GLOW = np.array([0.55, 0.18, 0.48], dtype=np.float32)
INK = np.array([0.05, 0.04, 0.05], dtype=np.float32)
WOOD = np.array([0.40, 0.28, 0.16], dtype=np.float32)
STONE = np.array([0.28, 0.24, 0.22], dtype=np.float32)

# ambientCG CC0 (JPG 1K packs)
CC0 = {
    "plaster": "https://ambientcg.com/get?file=Plaster001_1K-JPG.zip",
    "wood": "https://ambientcg.com/get?file=WoodFloor051_1K-JPG.zip",
    "stone": "https://ambientcg.com/get?file=Rocks022_1K-JPG.zip",
    "metal": "https://ambientcg.com/get?file=Metal032_1K-JPG.zip",
    "concrete": "https://ambientcg.com/get?file=Concrete034_1K-JPG.zip",
}


def ensure_dirs() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    SRC.mkdir(parents=True, exist_ok=True)


def load_rgb(path: Path) -> Image.Image:
    im = Image.open(path).convert("RGB")
    return im


def to_arr(im: Image.Image) -> np.ndarray:
    return np.asarray(im, dtype=np.float32) / 255.0


def to_img(arr: np.ndarray) -> Image.Image:
    a = np.clip(arr, 0.0, 1.0)
    return Image.fromarray((a * 255.0 + 0.5).astype(np.uint8), "RGB")


def resize_cover(im: Image.Image, size: int = SIZE) -> Image.Image:
    w, h = im.size
    scale = max(size / w, size / h)
    nw, nh = max(1, int(w * scale + 0.5)), max(1, int(h * scale + 0.5))
    im = im.resize((nw, nh), Image.Resampling.LANCZOS)
    left = (nw - size) // 2
    top = (nh - size) // 2
    return im.crop((left, top, left + size, top + size))


def make_seamless(arr: np.ndarray, blend: int = 48) -> np.ndarray:
    """Simple opposite-edge blend for nicer tiling."""
    a = arr.copy()
    h, w, _ = a.shape
    b = min(blend, h // 4, w // 4)
    if b <= 1:
        return a
    # horizontal wrap
    for i in range(b):
        t = i / (b - 1)
        wgt = 0.5 - 0.5 * math.cos(math.pi * t)
        left = a[:, i].copy()
        right = a[:, w - 1 - i].copy()
        a[:, i] = left * (1 - wgt) + right * wgt
        a[:, w - 1 - i] = right * (1 - wgt) + left * wgt
    # vertical wrap
    for i in range(b):
        t = i / (b - 1)
        wgt = 0.5 - 0.5 * math.cos(math.pi * t)
        top = a[i].copy()
        bot = a[h - 1 - i].copy()
        a[i] = top * (1 - wgt) + bot * wgt
        a[h - 1 - i] = bot * (1 - wgt) + top * wgt
    return a


def luminance(arr: np.ndarray) -> np.ndarray:
    return arr[..., 0] * 0.299 + arr[..., 1] * 0.587 + arr[..., 2] * 0.114


def grade_to_palette(arr: np.ndarray, c_lo: np.ndarray, c_hi: np.ndarray, contrast: float = 1.25) -> np.ndarray:
    lum = luminance(arr)
    lum = (lum - lum.min()) / max(1e-5, (lum.max() - lum.min()))
    lum = np.clip((lum - 0.5) * contrast + 0.5, 0.0, 1.0)
    out = c_lo[None, None, :] * (1.0 - lum[..., None]) + c_hi[None, None, :] * lum[..., None]
    # Keep a bit of original chroma dirt
    out = out * 0.82 + arr * 0.18
    return np.clip(out, 0.0, 1.0)


def overlay_ink(base: np.ndarray, ink_src: np.ndarray, amount: float = 0.35) -> np.ndarray:
    ink_l = 1.0 - luminance(ink_src)
    ink_l = (ink_l - np.percentile(ink_l, 40)) / max(1e-5, (np.percentile(ink_l, 98) - np.percentile(ink_l, 40)))
    ink_l = np.clip(ink_l, 0.0, 1.0) ** 1.2
    out = base * (1.0 - amount * ink_l[..., None]) + INK[None, None, :] * (amount * ink_l[..., None])
    return np.clip(out, 0.0, 1.0)


def add_grain(arr: np.ndarray, strength: float = 0.04, seed: int = 1) -> np.ndarray:
    rng = np.random.default_rng(seed)
    noise = rng.normal(0.0, strength, size=arr.shape).astype(np.float32)
    return np.clip(arr + noise, 0.0, 1.0)


def desaturate(arr: np.ndarray, sat: float = 0.65) -> np.ndarray:
    lum = luminance(arr)[..., None]
    return np.clip(lum * (1.0 - sat) + arr * sat, 0.0, 1.0)


def save(name: str, arr: np.ndarray) -> Path:
    path = OUT / name
    to_img(arr).save(path, "PNG", optimize=True)
    print("WROTE", path, arr.shape)
    return path


def download_cc0(key: str, url: str) -> Path | None:
    zip_path = SRC / f"{key}.zip"
    color_path = SRC / f"{key}_color.jpg"
    if color_path.exists():
        return color_path
    try:
        print("GET", url)
        req = urllib.request.Request(url, headers={"User-Agent": "TeomorTextureBake/1.0"})
        with urllib.request.urlopen(req, timeout=120) as resp:
            data = resp.read()
        zip_path.write_bytes(data)
        with zipfile.ZipFile(io.BytesIO(data)) as zf:
            # Prefer Color/Diffuse JPG
            names = [n for n in zf.namelist() if n.lower().endswith((".jpg", ".jpeg", ".png"))]
            pick = None
            for n in names:
                ln = n.lower()
                if "color" in ln or "diffuse" in ln or "albedo" in ln:
                    pick = n
                    break
            if pick is None and names:
                pick = names[0]
            if pick is None:
                return None
            raw = zf.read(pick)
            im = Image.open(io.BytesIO(raw)).convert("RGB")
            im.save(color_path, quality=92)
            print("CC0", key, "->", color_path)
            return color_path
    except Exception as e:
        print("CC0_FAIL", key, e)
        return None


def crop_interest(path: Path, box_frac: tuple[float, float, float, float]) -> Image.Image:
    im = load_rgb(path)
    w, h = im.size
    x0, y0, x1, y1 = box_frac
    return im.crop((int(w * x0), int(h * y0), int(w * x1), int(h * y1)))


def main() -> None:
    ensure_dirs()

    # --- author refs ---
    emb1 = ROOT / "цвет" / "Эмб1.jpg"
    color_shot = ROOT / "цвет" / "Screenshot_93.png"
    ink_a = ROOT / "стиль 1.1" / "8b9855d02f57dffda3ed516de3117faf.jpg"
    ink_b = ROOT / "стиль 1.1" / "8fcbfa5f0348988157f46adf60f6f62e.jpg"
    mush = ROOT / "Грибы" / "Screenshot_94.png"
    mush2 = ROOT / "Грибы" / "Screenshot_93.png"
    style_ost = ROOT / "Стиль ост" / "Screenshot_97.png"
    author_tone = ROOT / "Стиль мои рисунки" / "CАман2.jpg"

    # --- CC0 ---
    plaster_p = download_cc0("plaster", CC0["plaster"])
    wood_p = download_cc0("wood", CC0["wood"])
    stone_p = download_cc0("stone", CC0["stone"])
    metal_p = download_cc0("metal", CC0["metal"])
    concrete_p = download_cc0("concrete", CC0["concrete"])

    # Ink / grime from author B&W industrial refs
    ink_im = resize_cover(load_rgb(ink_a if ink_a.exists() else style_ost))
    if ink_b.exists():
        ink2 = resize_cover(load_rgb(ink_b))
        ink_arr = make_seamless(desaturate(0.55 * to_arr(ink_im) + 0.45 * to_arr(ink2), 0.15))
    else:
        ink_arr = make_seamless(desaturate(to_arr(ink_im), 0.1))
    ink_arr = grade_to_palette(ink_arr, INK, PARCHMENT_DARK, contrast=1.4)
    ink_arr = add_grain(ink_arr, 0.03, 11)
    save("tex_ink_grime_512.png", ink_arr)

    # Attic plaster: CC0 plaster graded to parchment + ink (no figurative art)
    if plaster_p and plaster_p.exists():
        base = to_arr(resize_cover(load_rgb(plaster_p)))
    else:
        base = np.full((SIZE, SIZE, 3), PARCHMENT, dtype=np.float32)
    # Warm parchment wash from Emb1 background dirt only if available (heavily blurred)
    if emb1.exists():
        wash = to_arr(resize_cover(crop_interest(emb1, (0.05, 0.05, 0.95, 0.35))))
        wash_im = to_img(wash).filter(ImageFilter.GaussianBlur(18))
        wash = to_arr(wash_im)
        base = base * 0.88 + wash * 0.12
    plaster = grade_to_palette(base, PARCHMENT_DARK, PARCHMENT, contrast=1.15)
    plaster = overlay_ink(plaster, ink_arr, 0.32)
    plaster = desaturate(plaster, 0.62)
    plaster = add_grain(make_seamless(plaster), 0.025, 2)
    save("tex_attic_plaster_512.png", plaster)

    # Wood
    if wood_p and wood_p.exists():
        warr = to_arr(resize_cover(load_rgb(wood_p)))
    else:
        warr = to_arr(resize_cover(load_rgb(author_tone))) if author_tone.exists() else plaster
    wood = grade_to_palette(warr, INK * 0 + PARCHMENT_DARK * 0.85, WOOD, contrast=1.3)
    wood = overlay_ink(wood, ink_arr, 0.22)
    wood = desaturate(add_grain(make_seamless(wood), 0.02, 3), 0.68)
    save("tex_attic_wood_512.png", wood)

    # Alley stone: rocks/concrete + purple sickness from Emb1
    if stone_p and stone_p.exists():
        sbase = to_arr(resize_cover(load_rgb(stone_p)))
    elif concrete_p and concrete_p.exists():
        sbase = to_arr(resize_cover(load_rgb(concrete_p)))
    else:
        sbase = plaster
    purple_ref = emb1 if emb1.exists() else color_shot
    if purple_ref and purple_ref.exists():
        # robe region roughly lower-center on Emb1
        pref = to_arr(resize_cover(crop_interest(purple_ref, (0.25, 0.35, 0.75, 0.95))))
    else:
        pref = np.full_like(sbase, PURPLE)
    stone = grade_to_palette(sbase, STONE * 0.55, STONE * 1.15 + PARCHMENT * 0.1, contrast=1.2)
    # bleed diseased purple into cracks (dark areas)
    dark = 1.0 - luminance(stone)
    dark = np.clip((dark - 0.35) / 0.5, 0.0, 1.0)[..., None]
    stone = stone * (1.0 - 0.55 * dark) + (pref * 0.55 + PURPLE * 0.45) * (0.55 * dark)
    stone = overlay_ink(stone, ink_arr, 0.3)
    stone = desaturate(add_grain(make_seamless(stone), 0.03, 4), 0.72)
    save("tex_alley_stone_512.png", stone)

    # Vsegrib flesh
    if mush.exists():
        m1 = to_arr(resize_cover(load_rgb(mush)))
    else:
        m1 = pref
    if mush2.exists():
        m2 = to_arr(resize_cover(load_rgb(mush2)))
        m = 0.55 * m1 + 0.45 * m2
    else:
        m = m1
    flesh = grade_to_palette(m, PURPLE * 0.45, PURPLE_GLOW, contrast=1.1)
    flesh = flesh * 0.75 + pref * 0.25
    flesh = overlay_ink(flesh, ink_arr, 0.2)
    flesh = desaturate(add_grain(make_seamless(flesh), 0.035, 5), 0.8)
    save("tex_vsegrib_flesh_512.png", flesh)

    # Cap: brighter purple patches
    cap = grade_to_palette(m, PURPLE, PURPLE_GLOW * 1.05, contrast=1.25)
    cap = overlay_ink(cap, ink_arr, 0.12)
    cap = desaturate(add_grain(make_seamless(cap), 0.03, 6), 0.85)
    save("tex_vsegrib_cap_512.png", cap)
    # emission mask-ish bright spots baked lightly into albedo already; separate soft emit helper
    emit = np.clip((luminance(cap) - 0.45) * 2.2, 0.0, 1.0)
    emit_rgb = PURPLE_GLOW[None, None, :] * emit[..., None]
    save("tex_vsegrib_cap_emit_512.png", emit_rgb)

    # Metal barrels
    if metal_p and metal_p.exists():
        met = to_arr(resize_cover(load_rgb(metal_p)))
    else:
        met = stone
    metal = grade_to_palette(met, INK * 0.2 + STONE * 0.4, STONE * 0.7 + PARCHMENT_DARK * 0.3, contrast=1.35)
    # occasional purple fungal stain
    rng = np.random.default_rng(7)
    blot = rng.random((SIZE, SIZE)).astype(np.float32)
    blot = Image.fromarray((blot * 255).astype(np.uint8), "L").filter(ImageFilter.GaussianBlur(6))
    blot = np.asarray(blot, dtype=np.float32) / 255.0
    blot = np.clip((blot - 0.62) * 3.0, 0.0, 1.0)[..., None]
    metal = metal * (1.0 - 0.4 * blot) + PURPLE[None, None, :] * (0.4 * blot)
    metal = overlay_ink(metal, ink_arr, 0.25)
    metal = desaturate(add_grain(make_seamless(metal), 0.025, 8), 0.55)
    save("tex_metal_barrel_512.png", metal)

    # Floor dirt for alley (darker)
    floor = grade_to_palette(stone if stone_p else plaster, INK, STONE, contrast=1.4)
    floor = overlay_ink(floor, ink_arr, 0.4)
    floor = desaturate(add_grain(make_seamless(floor * 0.85 + flesh * 0.15), 0.03, 9), 0.6)
    save("tex_alley_floor_512.png", floor)

    print("DONE", OUT)


if __name__ == "__main__":
    main()
