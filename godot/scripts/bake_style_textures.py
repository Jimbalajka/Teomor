#!/usr/bin/env python3
"""Bake Teomor style albedo tiles from author refs + open CC0 sources.

Goal: materials must READ (boards, stone, plaster) — not flat two-color blobs.
Palette grade is a wash over structure, not a replace.

Outputs 512 PNG into assets/textures/style/.
"""
from __future__ import annotations

import math
import subprocess
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

GODOT = Path(__file__).resolve().parents[1]  # godot/
ROOT = GODOT.parent  # Teomor/
if not (GODOT / "project.godot").exists():
    ROOT = Path("/home/ec2-user/Teomor")
    GODOT = ROOT / "godot"
OUT = GODOT / "assets" / "textures" / "style"
SRC = GODOT / "assets" / "textures" / "_src"
SIZE = 512

PARCHMENT = np.array([0.62, 0.50, 0.28], dtype=np.float32)
PARCHMENT_DARK = np.array([0.36, 0.28, 0.16], dtype=np.float32)
PURPLE = np.array([0.42, 0.16, 0.38], dtype=np.float32)
PURPLE_GLOW = np.array([0.55, 0.18, 0.48], dtype=np.float32)
INK = np.array([0.05, 0.04, 0.05], dtype=np.float32)
WOOD = np.array([0.40, 0.28, 0.16], dtype=np.float32)
STONE = np.array([0.28, 0.24, 0.22], dtype=np.float32)


def ensure_dirs() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    SRC.mkdir(parents=True, exist_ok=True)


def load_rgb(path: Path) -> Image.Image:
    return Image.open(path).convert("RGB")


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


def make_seamless(arr: np.ndarray, blend: int = 40) -> np.ndarray:
    a = arr.copy()
    h, w, _ = a.shape
    b = min(blend, h // 4, w // 4)
    if b <= 1:
        return a
    for i in range(b):
        t = i / (b - 1)
        wgt = 0.5 - 0.5 * math.cos(math.pi * t)
        left = a[:, i].copy()
        right = a[:, w - 1 - i].copy()
        a[:, i] = left * (1 - wgt) + right * wgt
        a[:, w - 1 - i] = right * (1 - wgt) + left * wgt
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


def local_contrast(arr: np.ndarray, radius: int = 2, amount: float = 0.55) -> np.ndarray:
    """Boost mid-frequency detail so boards/cracks survive palette wash."""
    im = to_img(arr)
    blur = im.filter(ImageFilter.GaussianBlur(radius=radius))
    detail = arr - to_arr(blur)
    return np.clip(arr + detail * amount, 0.0, 1.0)


def grade_keep_structure(
    arr: np.ndarray,
    c_lo: np.ndarray,
    c_hi: np.ndarray,
    mix: float = 0.55,
    contrast: float = 1.2,
) -> np.ndarray:
    """Colorize toward palette but keep source structure/chroma dirt.

    mix: 0 = keep source, 1 = full palette remap.
    """
    arr = local_contrast(arr, 2, 0.65)
    lum = luminance(arr)
    # normalize softly — keep relative board/stone contrast
    p1, p99 = np.percentile(lum, 1), np.percentile(lum, 99)
    lum_n = np.clip((lum - p1) / max(1e-5, (p99 - p1)), 0.0, 1.0)
    lum_n = np.clip((lum_n - 0.5) * contrast + 0.5, 0.0, 1.0)
    pal = c_lo[None, None, :] * (1.0 - lum_n[..., None]) + c_hi[None, None, :] * lum_n[..., None]
    # Preserve high-frequency identity from source
    src_gain = (lum[..., None] + 0.08) / (np.mean(lum) + 0.08)
    structured = np.clip(pal * (0.72 + 0.45 * src_gain) * (0.85 + 0.3 * (arr / (lum[..., None] + 1e-4))), 0, 1)
    out = arr * (1.0 - mix) + structured * mix
    return np.clip(out, 0.0, 1.0)


def overlay_ink(base: np.ndarray, ink_src: np.ndarray, amount: float = 0.28) -> np.ndarray:
    ink_l = 1.0 - luminance(ink_src)
    lo, hi = np.percentile(ink_l, 45), np.percentile(ink_l, 98)
    ink_l = np.clip((ink_l - lo) / max(1e-5, (hi - lo)), 0.0, 1.0) ** 1.15
    out = base * (1.0 - amount * ink_l[..., None]) + INK[None, None, :] * (amount * ink_l[..., None])
    return np.clip(out, 0.0, 1.0)


def add_grain(arr: np.ndarray, strength: float = 0.03, seed: int = 1) -> np.ndarray:
    rng = np.random.default_rng(seed)
    noise = rng.normal(0.0, strength, size=arr.shape).astype(np.float32)
    return np.clip(arr + noise, 0.0, 1.0)


def desaturate(arr: np.ndarray, sat: float = 0.72) -> np.ndarray:
    lum = luminance(arr)[..., None]
    return np.clip(lum * (1.0 - sat) + arr * sat, 0.0, 1.0)


def save(name: str, arr: np.ndarray) -> Path:
    path = OUT / name
    to_img(arr).save(path, "PNG", optimize=True)
    print("WROTE", path, arr.shape)
    return path


def first_existing(names: list[str]) -> Path | None:
    for n in names:
        p = SRC / n
        if p.exists() and p.stat().st_size > 10_000:
            return p
    return None


def crop_interest(path: Path, box_frac: tuple[float, float, float, float]) -> Image.Image:
    im = load_rgb(path)
    w, h = im.size
    x0, y0, x1, y1 = box_frac
    return im.crop((int(w * x0), int(h * y0), int(w * x1), int(h * y1)))


def ensure_open_materials() -> None:
    fetch = GODOT / "scripts" / "tools" / "fetch_open_materials.py"
    if fetch.exists():
        print("RUN", fetch)
        subprocess.run([sys.executable, str(fetch)], check=False)


def main() -> None:
    ensure_dirs()
    ensure_open_materials()

    emb1 = ROOT / "цвет" / "Эмб1.jpg"
    color_shot = ROOT / "цвет" / "Screenshot_93.png"
    ink_a = ROOT / "стиль 1.1" / "8b9855d02f57dffda3ed516de3117faf.jpg"
    ink_b = ROOT / "стиль 1.1" / "8fcbfa5f0348988157f46adf60f6f62e.jpg"
    mush = ROOT / "Грибы" / "Screenshot_94.png"
    mush2 = ROOT / "Грибы" / "Screenshot_93.png"
    style_ost = ROOT / "Стиль ост" / "Screenshot_97.png"

    wood_p = first_existing(["wood_boards_color.jpg", "wood_planks_color.jpg", "wood_color.jpg"])
    stone_p = first_existing(["stone_pavement_color.jpg", "stone_rocks_color.jpg", "stone_color.jpg"])
    plaster_p = first_existing(["plaster_color.jpg", "concrete_color.jpg"])
    metal_p = first_existing(["metal_color.jpg", "metal_rust_color.jpg", "metal_smooth_color.jpg"])
    rust_p = first_existing(["metal_rust_color.jpg"])
    concrete_p = first_existing(["concrete_color.jpg"])

    # Ink / grime
    ink_im = resize_cover(load_rgb(ink_a if ink_a.exists() else style_ost))
    if ink_b.exists():
        ink2 = resize_cover(load_rgb(ink_b))
        ink_arr = make_seamless(desaturate(0.55 * to_arr(ink_im) + 0.45 * to_arr(ink2), 0.2))
    else:
        ink_arr = make_seamless(desaturate(to_arr(ink_im), 0.15))
    ink_arr = grade_keep_structure(ink_arr, INK, PARCHMENT_DARK, mix=0.7, contrast=1.35)
    ink_arr = add_grain(ink_arr, 0.025, 11)
    save("tex_ink_grime_512.png", ink_arr)

    # Attic plaster — keep plaster pores
    if plaster_p:
        base = to_arr(resize_cover(load_rgb(plaster_p)))
    else:
        base = np.full((SIZE, SIZE, 3), PARCHMENT, dtype=np.float32)
    if emb1.exists():
        wash = to_arr(to_img(to_arr(resize_cover(crop_interest(emb1, (0.05, 0.05, 0.95, 0.35))))).filter(ImageFilter.GaussianBlur(20)))
        base = base * 0.9 + wash * 0.1
    plaster = grade_keep_structure(base, PARCHMENT_DARK, PARCHMENT, mix=0.5, contrast=1.12)
    plaster = overlay_ink(plaster, ink_arr, 0.22)
    plaster = desaturate(add_grain(make_seamless(plaster), 0.02, 2), 0.7)
    save("tex_attic_plaster_512.png", plaster)

    # Wood boards — preserve plank lines
    if wood_p:
        warr = to_arr(resize_cover(load_rgb(wood_p)))
    else:
        warr = plaster
    planks = first_existing(["wood_planks_color.jpg", "wood_color.jpg"])
    if planks:
        w2 = to_arr(resize_cover(load_rgb(planks)))
        warr = np.clip(warr * 0.7 + w2 * 0.3, 0.0, 1.0)
    warr = local_contrast(warr, 1, 1.25)
    warr = local_contrast(warr, 3, 0.55)
    wood = grade_keep_structure(warr, PARCHMENT_DARK * 0.9, WOOD * 1.05, mix=0.36, contrast=1.35)
    wood = overlay_ink(wood, ink_arr, 0.1)
    wood = desaturate(add_grain(make_seamless(wood), 0.016, 3), 0.82)
    save("tex_attic_wood_512.png", wood)

    # Alley stone / pavement
    if stone_p:
        sbase = to_arr(resize_cover(load_rgb(stone_p)))
    elif concrete_p:
        sbase = to_arr(resize_cover(load_rgb(concrete_p)))
    else:
        sbase = plaster
    sbase = local_contrast(sbase, 2, 0.75)
    purple_ref = emb1 if emb1.exists() else color_shot
    if purple_ref and purple_ref.exists():
        pref = to_arr(resize_cover(crop_interest(purple_ref, (0.25, 0.35, 0.75, 0.95))))
    else:
        pref = np.full_like(sbase, PURPLE)
    stone = grade_keep_structure(sbase, STONE * 0.65, STONE * 1.1 + PARCHMENT * 0.12, mix=0.5, contrast=1.18)
    dark = 1.0 - luminance(stone)
    dark = np.clip((dark - 0.4) / 0.45, 0.0, 1.0)[..., None]
    stone = stone * (1.0 - 0.4 * dark) + (pref * 0.5 + PURPLE * 0.5) * (0.4 * dark)
    stone = overlay_ink(stone, ink_arr, 0.22)
    stone = desaturate(add_grain(make_seamless(stone), 0.022, 4), 0.75)
    save("tex_alley_stone_512.png", stone)

    # Vsegrib
    if mush.exists():
        m1 = to_arr(resize_cover(load_rgb(mush)))
    else:
        m1 = pref
    if mush2.exists():
        m = 0.55 * m1 + 0.45 * to_arr(resize_cover(load_rgb(mush2)))
    else:
        m = m1
    m = local_contrast(m, 2, 0.5)
    flesh = grade_keep_structure(m, PURPLE * 0.45, PURPLE_GLOW, mix=0.6, contrast=1.1)
    flesh = flesh * 0.8 + pref * 0.2
    flesh = overlay_ink(flesh, ink_arr, 0.15)
    flesh = desaturate(add_grain(make_seamless(flesh), 0.03, 5), 0.82)
    save("tex_vsegrib_flesh_512.png", flesh)

    cap = grade_keep_structure(m, PURPLE, PURPLE_GLOW * 1.05, mix=0.62, contrast=1.2)
    cap = overlay_ink(cap, ink_arr, 0.1)
    cap = desaturate(add_grain(make_seamless(cap), 0.025, 6), 0.86)
    save("tex_vsegrib_cap_512.png", cap)
    emit = np.clip((luminance(cap) - 0.45) * 2.2, 0.0, 1.0)
    save("tex_vsegrib_cap_emit_512.png", PURPLE_GLOW[None, None, :] * emit[..., None])

    # Metal plates + rust structure
    if metal_p:
        met = local_contrast(to_arr(resize_cover(load_rgb(metal_p))), 1, 1.0)
    else:
        met = stone
    if rust_p:
        rust = local_contrast(to_arr(resize_cover(load_rgb(rust_p))), 2, 0.8)
        met = np.clip(met * 0.62 + rust * 0.38, 0.0, 1.0)
    metal = grade_keep_structure(met, INK * 0.25 + STONE * 0.35, STONE * 0.75 + PARCHMENT_DARK * 0.25, mix=0.42, contrast=1.35)
    rng = np.random.default_rng(7)
    blot = rng.random((SIZE, SIZE)).astype(np.float32)
    blot = np.asarray(Image.fromarray((blot * 255).astype(np.uint8), "L").filter(ImageFilter.GaussianBlur(6)), dtype=np.float32) / 255.0
    blot = np.clip((blot - 0.62) * 3.0, 0.0, 1.0)[..., None]
    metal = metal * (1.0 - 0.3 * blot) + PURPLE[None, None, :] * (0.3 * blot)
    metal = overlay_ink(metal, ink_arr, 0.14)
    metal = desaturate(add_grain(make_seamless(metal), 0.02, 8), 0.62)
    save("tex_metal_barrel_512.png", metal)

    # Floor
    floor = grade_keep_structure(stone, INK, STONE, mix=0.55, contrast=1.3)
    floor = overlay_ink(floor, ink_arr, 0.3)
    floor = desaturate(add_grain(make_seamless(floor * 0.9 + flesh * 0.1), 0.025, 9), 0.65)
    save("tex_alley_floor_512.png", floor)

    print("DONE", OUT)


if __name__ == "__main__":
    main()
