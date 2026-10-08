#!/usr/bin/env python3
"""Remap free PSX/retro packs into Teomor parchment / purple / ink palette.

Keeps source structure (luminance + local contrast), replaces hue toward style anchor.
Writes 512 albedo (+ simple n/r) into assets/textures/author/.
"""
from __future__ import annotations

import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

GODOT = Path(__file__).resolve().parents[2]
SRC = GODOT / "assets" / "textures" / "_src" / "author"
OUT = GODOT / "assets" / "textures" / "author"
SIZE = 512

# Style anchor bases (linear-ish 0..1)
PARCHMENT = np.array([0.62, 0.50, 0.28], dtype=np.float32)
PARCHMENT_DARK = np.array([0.36, 0.28, 0.16], dtype=np.float32)
PURPLE = np.array([0.42, 0.16, 0.38], dtype=np.float32)
PURPLE_GLOW = np.array([0.55, 0.18, 0.48], dtype=np.float32)
INK = np.array([0.05, 0.04, 0.05], dtype=np.float32)
WOOD = np.array([0.40, 0.28, 0.16], dtype=np.float32)
STONE = np.array([0.28, 0.24, 0.22], dtype=np.float32)
METAL = np.array([0.22, 0.20, 0.19], dtype=np.float32)


def to_arr(im: Image.Image) -> np.ndarray:
    return np.asarray(im.convert("RGB"), dtype=np.float32) / 255.0


def to_img(arr: np.ndarray) -> Image.Image:
    a = np.clip(arr, 0.0, 1.0)
    return Image.fromarray((a * 255.0 + 0.5).astype(np.uint8), "RGB")


def luminance(arr: np.ndarray) -> np.ndarray:
    return arr[..., 0] * 0.299 + arr[..., 1] * 0.587 + arr[..., 2] * 0.114


def resize_nearest_cover(im: Image.Image, size: int = SIZE) -> Image.Image:
    # Keep PSX crunch: nearest upscale after small lanczos to square
    im = im.convert("RGB")
    w, h = im.size
    side = max(w, h)
    canvas = Image.new("RGB", (side, side), (0, 0, 0))
    canvas.paste(im, ((side - w) // 2, (side - h) // 2))
    return canvas.resize((size, size), Image.Resampling.NEAREST)


def soft_seamless(arr: np.ndarray, blend: int = 20) -> np.ndarray:
    a = arr.copy()
    h, w = a.shape[:2]
    b = min(blend, h // 8, w // 8)
    if b <= 1:
        return a
    for i in range(b):
        t = i / max(1, b - 1)
        wgt = (0.5 - 0.5 * math.cos(math.pi * t)) * 0.7
        left, right = a[:, i].copy(), a[:, w - 1 - i].copy()
        a[:, i] = left * (1 - wgt) + right * wgt
        a[:, w - 1 - i] = right * (1 - wgt) + left * wgt
        top, bot = a[i].copy(), a[h - 1 - i].copy()
        a[i] = top * (1 - wgt) + bot * wgt
        a[h - 1 - i] = bot * (1 - wgt) + top * wgt
    return a


def remap_dual(arr: np.ndarray, low: np.ndarray, high: np.ndarray, ink_amt: float = 0.18, purple_amt: float = 0.0) -> np.ndarray:
    """Map luminance to low..high, push darks to ink, optional purple in midtones."""
    lum = luminance(arr)
    # stretch contrast a bit so structure survives recolor
    lo, hi = np.percentile(lum, 5), np.percentile(lum, 95)
    if hi - lo < 1e-4:
        n = lum
    else:
        n = np.clip((lum - lo) / (hi - lo), 0.0, 1.0)
    n = np.power(n, 0.92)
    base = low[None, None, :] * (1.0 - n[..., None]) + high[None, None, :] * n[..., None]
    # keep a whisper of original chroma so materials don't become plastic flat
    orig = arr * 0.12 + base * 0.88
    # ink in cracks
    ink_w = np.clip(1.0 - n, 0.0, 1.0) ** 1.6 * ink_amt
    out = orig * (1.0 - ink_w[..., None]) + INK[None, None, :] * ink_w[..., None]
    if purple_amt > 0.0:
        # sick purple in mid-dark voids
        mid = np.exp(-((n - 0.35) ** 2) / 0.04)
        pw = mid * purple_amt
        out = out * (1.0 - pw[..., None]) + PURPLE[None, None, :] * pw[..., None]
    return np.clip(out, 0.0, 1.0)


def make_normal_rough(albedo: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    lum = luminance(albedo)
    im = Image.fromarray((lum * 255).astype(np.uint8), "L")
    # fake height from luminance
    blur = im.filter(ImageFilter.GaussianBlur(radius=1.2))
    h = np.asarray(blur, dtype=np.float32) / 255.0
    # sobel-ish
    dx = np.zeros_like(h)
    dy = np.zeros_like(h)
    dx[:, 1:-1] = h[:, 2:] - h[:, :-2]
    dy[1:-1, :] = h[2:, :] - h[:-2, :]
    strength = 2.8
    nx = -dx * strength
    ny = -dy * strength
    nz = np.ones_like(h)
    inv = 1.0 / np.sqrt(nx * nx + ny * ny + nz * nz + 1e-8)
    nrm = np.stack([(nx * inv) * 0.5 + 0.5, (ny * inv) * 0.5 + 0.5, (nz * inv) * 0.5 + 0.5], axis=-1)
    # rough: brighter cracks a bit glossier? keep matte overall
    rough = np.clip(0.78 + (1.0 - lum) * 0.18, 0.55, 0.98)
    rough_rgb = np.stack([rough, rough, rough], axis=-1)
    return nrm, rough_rgb


def save_maps(stem: str, albedo: np.ndarray) -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    alb = soft_seamless(albedo)
    nrm, rough = make_normal_rough(alb)
    to_img(alb).save(OUT / f"{stem}_512.png")
    to_img(nrm).save(OUT / f"{stem}_n_512.png")
    to_img(rough).save(OUT / f"{stem}_r_512.png")
    print("wrote", stem)


def load_first(paths: list[Path]) -> Image.Image:
    for p in paths:
        if p.exists():
            return Image.open(p)
    raise FileNotFoundError(" missing any of: " + ", ".join(str(p) for p in paths))


def main() -> None:
    horror = SRC / "psx_horror_sample" / "128px"
    free128 = SRC / "psx_textures_free" / "128"
    retro64 = SRC / "retro64_textures_free" / "64"

    jobs = [
        (
            "wood_hand",
            [
                horror / "planks_dark_old.png",
                free128 / "wood" / "wood_floor.png",
            ],
            WOOD,
            PARCHMENT_DARK,
            0.22,
            0.04,
        ),
        (
            "wood_weathered",
            [
                free128 / "wood" / "wood_floor.png",
                horror / "door_wood_old.png",
            ],
            PARCHMENT_DARK,
            PARCHMENT,
            0.18,
            0.03,
        ),
        (
            "concrete",
            [
                free128 / "plaster_paper" / "plaster_cracked.png",
                horror / "concrete_cracked.png",
            ],
            PARCHMENT_DARK,
            PARCHMENT,
            0.16,
            0.05,
        ),
        (
            "brick_broken",
            [
                horror / "brick_red.png",
                free128 / "brick" / "brick_red.png",
            ],
            STONE,
            PURPLE,
            0.2,
            0.22,
        ),
        (
            "brick_mossy",
            [
                free128 / "brick" / "brick_red.png",
                horror / "brick_red.png",
            ],
            STONE * 0.85,
            PURPLE * 0.75 + PARCHMENT_DARK * 0.25,
            0.22,
            0.28,
        ),
        (
            "stone_broken",
            [
                horror / "stone_blocks_dungeon.png",
                free128 / "concrete_stone" / "concrete.png",
            ],
            STONE,
            PURPLE * 0.55 + STONE * 0.45,
            0.2,
            0.18,
        ),
        (
            "stone_broken2",
            [
                free128 / "concrete_stone" / "concrete.png",
                horror / "stone_blocks_dungeon.png",
            ],
            STONE * 0.9,
            PURPLE * 0.4 + PARCHMENT_DARK * 0.2 + STONE * 0.4,
            0.18,
            0.2,
        ),
        (
            "floor_mix",
            [
                horror / "dirt.png",
                free128 / "ground" / "ground_dirt.png" if (free128 / "ground" / "ground_dirt.png").exists() else horror / "dirt.png",
            ],
            STONE * 0.7 + INK * 0.3,
            PURPLE * 0.35 + PARCHMENT_DARK * 0.35 + STONE * 0.3,
            0.24,
            0.16,
        ),
        (
            "tile_worn",
            [
                horror / "tiles_bathroom_dirty.png",
                free128 / "tiles" / "tiles_white_dirty.png",
            ],
            STONE,
            PARCHMENT_DARK,
            0.2,
            0.08,
        ),
        (
            "metal_rusty",
            [
                horror / "metal_rusty_sheet.png",
                free128 / "metal" / "metal_Rusty.png" if False else horror / "metal_rusty_sheet.png",
            ],
            METAL,
            PURPLE * 0.25 + METAL * 0.75,
            0.28,
            0.1,
        ),
    ]

    # resolve optional ground path better
    ground_candidates = list((free128 / "ground").glob("*.png")) if (free128 / "ground").exists() else []
    for stem, paths, low, high, ink_amt, purple_amt in jobs:
        if stem == "floor_mix" and ground_candidates:
            paths = [ground_candidates[0], horror / "dirt.png"]
        # metal free pack search
        if stem == "metal_rusty":
            metal_hits = list((free128 / "metal").glob("*.png")) if (free128 / "metal").exists() else []
            if metal_hits:
                paths = [horror / "metal_rusty_sheet.png", metal_hits[0]]
        im = load_first(paths)
        arr = to_arr(resize_nearest_cover(im))
        remapped = remap_dual(arr, low, high, ink_amt=ink_amt, purple_amt=purple_amt)
        save_maps(stem, remapped)

    # attic-oriented aliases into style/ as well for build_scenes tex_attic_*
    style = GODOT / "assets" / "textures" / "style"
    style.mkdir(parents=True, exist_ok=True)
    mapping = {
        "tex_attic_wood_512.png": "wood_hand_512.png",
        "tex_attic_plaster_512.png": "concrete_512.png",
        "tex_alley_stone_512.png": "stone_broken_512.png",
        "tex_alley_floor_512.png": "floor_mix_512.png",
    }
    for dst_name, src_name in mapping.items():
        src = OUT / src_name
        if not src.exists():
            continue
        Image.open(src).save(style / dst_name)
        stem = src_name.replace("_512.png", "")
        for suf, out_suf in (("_n_512.png", dst_name.replace("_512.png", "_n_512.png")), ("_r_512.png", dst_name.replace("_512.png", "_r_512.png"))):
            s2 = OUT / f"{stem}{suf}"
            if s2.exists():
                Image.open(s2).save(style / out_suf)
        print("mirrored", dst_name)


if __name__ == "__main__":
    main()
