#!/usr/bin/env python3
"""Bake Teomor style maps: albedo (with baked depth) + normal + rough.

Goal (author / DD ref):
- surfaces feel deep, not flat pasted noise
- materials read (boards / stone / plaster)
- less obvious mosaic tiling

Open sources: ambientCG CC0 via scripts/tools/fetch_open_materials.py
"""
from __future__ import annotations

import math
import subprocess
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

GODOT = Path(__file__).resolve().parents[1]
ROOT = GODOT.parent
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
    if a.ndim == 2:
        return Image.fromarray((a * 255.0 + 0.5).astype(np.uint8), "L")
    if a.shape[2] == 1:
        return Image.fromarray((a[..., 0] * 255.0 + 0.5).astype(np.uint8), "L")
    return Image.fromarray((a * 255.0 + 0.5).astype(np.uint8), "RGB")


def resize_cover(im: Image.Image, size: int = SIZE) -> Image.Image:
    w, h = im.size
    scale = max(size / w, size / h)
    nw, nh = max(1, int(w * scale + 0.5)), max(1, int(h * scale + 0.5))
    im = im.resize((nw, nh), Image.Resampling.LANCZOS)
    left = (nw - size) // 2
    top = (nh - size) // 2
    return im.crop((left, top, left + size, top + size))


def luminance(arr: np.ndarray) -> np.ndarray:
    if arr.ndim == 2:
        return arr
    if arr.shape[-1] == 1:
        return arr[..., 0]
    return arr[..., 0] * 0.299 + arr[..., 1] * 0.587 + arr[..., 2] * 0.114


def local_contrast(arr: np.ndarray, radius: int = 2, amount: float = 0.55) -> np.ndarray:
    im = to_img(arr).convert("RGB")
    blur = im.filter(ImageFilter.GaussianBlur(radius=radius))
    detail = arr - to_arr(blur)
    return np.clip(arr + detail * amount, 0.0, 1.0)


def soft_seamless(arr: np.ndarray, blend: int = 24) -> np.ndarray:
    """Lighter edge blend — heavy blend was creating visible mosaic cells."""
    a = arr.copy()
    h, w = a.shape[:2]
    b = min(blend, h // 8, w // 8)
    if b <= 1:
        return a
    for i in range(b):
        t = i / max(1, b - 1)
        wgt = 0.5 - 0.5 * math.cos(math.pi * t)
        wgt *= 0.65
        if a.ndim == 3:
            left, right = a[:, i].copy(), a[:, w - 1 - i].copy()
            a[:, i] = left * (1 - wgt) + right * wgt
            a[:, w - 1 - i] = right * (1 - wgt) + left * wgt
            top, bot = a[i].copy(), a[h - 1 - i].copy()
            a[i] = top * (1 - wgt) + bot * wgt
            a[h - 1 - i] = bot * (1 - wgt) + top * wgt
        else:
            left, right = a[:, i].copy(), a[:, w - 1 - i].copy()
            a[:, i] = left * (1 - wgt) + right * wgt
            a[:, w - 1 - i] = right * (1 - wgt) + left * wgt
            top, bot = a[i].copy(), a[h - 1 - i].copy()
            a[i] = top * (1 - wgt) + bot * wgt
            a[h - 1 - i] = bot * (1 - wgt) + top * wgt
    return a


def macro_breakup(arr: np.ndarray, seed: int, strength: float = 0.12) -> np.ndarray:
    """Low-frequency unique blotches to kill mosaic repetition."""
    rng = np.random.default_rng(seed)
    small = rng.random((16, 16)).astype(np.float32)
    im = Image.fromarray((small * 255).astype(np.uint8), "L").resize((SIZE, SIZE), Image.Resampling.BICUBIC)
    m = np.asarray(im, dtype=np.float32) / 255.0
    m = (m - 0.5) * 2.0 * strength
    if arr.ndim == 3:
        return np.clip(arr + m[..., None], 0.0, 1.0)
    return np.clip(arr + m, 0.0, 1.0)


def grade_keep_structure(
    arr: np.ndarray,
    c_lo: np.ndarray,
    c_hi: np.ndarray,
    mix: float = 0.45,
    contrast: float = 1.2,
) -> np.ndarray:
    arr = local_contrast(arr, 2, 0.55)
    lum = luminance(arr)
    p1, p99 = np.percentile(lum, 1), np.percentile(lum, 99)
    lum_n = np.clip((lum - p1) / max(1e-5, (p99 - p1)), 0.0, 1.0)
    lum_n = np.clip((lum_n - 0.5) * contrast + 0.5, 0.0, 1.0)
    pal = c_lo[None, None, :] * (1.0 - lum_n[..., None]) + c_hi[None, None, :] * lum_n[..., None]
    src_gain = (lum[..., None] + 0.08) / (float(np.mean(lum)) + 0.08)
    chroma = arr / (lum[..., None] + 1e-4)
    structured = np.clip(pal * (0.72 + 0.4 * src_gain) * (0.88 + 0.25 * chroma), 0, 1)
    return np.clip(arr * (1.0 - mix) + structured * mix, 0.0, 1.0)


def overlay_ink(base: np.ndarray, ink_src: np.ndarray, amount: float = 0.22) -> np.ndarray:
    ink_l = 1.0 - luminance(ink_src)
    lo, hi = np.percentile(ink_l, 50), np.percentile(ink_l, 98)
    ink_l = np.clip((ink_l - lo) / max(1e-5, (hi - lo)), 0.0, 1.0) ** 1.1
    return np.clip(base * (1.0 - amount * ink_l[..., None]) + INK * (amount * ink_l[..., None]), 0, 1)


def add_grain(arr: np.ndarray, strength: float = 0.02, seed: int = 1) -> np.ndarray:
    rng = np.random.default_rng(seed)
    noise = rng.normal(0.0, strength, size=arr.shape).astype(np.float32)
    return np.clip(arr + noise, 0.0, 1.0)


def desaturate(arr: np.ndarray, sat: float = 0.75) -> np.ndarray:
    lum = luminance(arr)[..., None]
    return np.clip(lum * (1.0 - sat) + arr * sat, 0.0, 1.0)


def load_map(key_suffixes: list[str], kind: str) -> np.ndarray | None:
    for key in key_suffixes:
        p = SRC / f"{key}_{kind}.jpg"
        if p.exists() and p.stat().st_size > 5_000:
            return to_arr(resize_cover(load_rgb(p)))
    return None


def bake_depth_into_albedo(color: np.ndarray, ao: np.ndarray | None, normal: np.ndarray | None) -> np.ndarray:
    """DD-like: paint occlusion + soft top light into albedo."""
    out = color.copy()
    if ao is not None:
        a = luminance(ao)
        a = (a - np.percentile(a, 2)) / max(1e-5, (np.percentile(a, 98) - np.percentile(a, 2)))
        a = np.clip(a, 0.0, 1.0)
        # darker cracks / contact
        out *= (0.55 + 0.45 * a)[..., None]
    if normal is not None:
        n = normal * 2.0 - 1.0
        # OpenGL normal: +Y up in tangent space; fake key light from above-left
        light = np.array([-0.35, 0.82, 0.45], dtype=np.float32)
        light /= np.linalg.norm(light)
        ndotl = np.clip(n[..., 0] * light[0] + n[..., 1] * light[1] + n[..., 2] * light[2], 0.0, 1.0)
        # cavity from facing away
        cavity = np.clip(n[..., 2] * 0.5 + 0.5, 0.0, 1.0)
        shade = 0.62 + 0.28 * ndotl + 0.10 * cavity
        out *= shade[..., None]
    return np.clip(out, 0.0, 1.0)


def stylize_normal(normal: np.ndarray | None, seed: int) -> np.ndarray:
    if normal is None:
        flat = np.zeros((SIZE, SIZE, 3), dtype=np.float32)
        flat[..., 0] = 0.5
        flat[..., 1] = 0.5
        flat[..., 2] = 1.0
        return flat
    n = normal.copy()
    # slight contrast on XY for readable relief, keep Z up
    nxy = (n[..., 0:2] - 0.5) * 1.25 + 0.5
    n[..., 0:2] = np.clip(nxy, 0.0, 1.0)
    n = soft_seamless(n, 16)
    n = macro_breakup(n, seed + 99, 0.03)
    # re-normalize-ish in encoded space
    return np.clip(n, 0.0, 1.0)


def stylize_rough(rough: np.ndarray | None, ao: np.ndarray | None, seed: int, base: float = 0.85) -> np.ndarray:
    if rough is None:
        r = np.full((SIZE, SIZE), base, dtype=np.float32)
    else:
        r = luminance(rough)
        r = (r - r.min()) / max(1e-5, (r.max() - r.min()))
        r = np.clip(0.55 + 0.4 * r, 0.35, 0.98)
    if ao is not None:
        a = luminance(ao)
        r = np.clip(r + (1.0 - a) * 0.08, 0.3, 0.99)
    r = soft_seamless(r, 16)
    r = macro_breakup(r, seed + 7, 0.04)
    return np.clip(r, 0.0, 1.0)


def save_rgb(name: str, arr: np.ndarray) -> None:
    path = OUT / name
    to_img(arr).save(path, "PNG", optimize=True)
    print("WROTE", path.name, getattr(arr, "shape", None))


def save_gray_as_rgb(name: str, arr: np.ndarray) -> None:
    if arr.ndim == 2:
        rgb = np.repeat(arr[..., None], 3, axis=2)
    else:
        rgb = arr
    save_rgb(name, rgb)


def crop_interest(path: Path, box_frac: tuple[float, float, float, float]) -> Image.Image:
    im = load_rgb(path)
    w, h = im.size
    x0, y0, x1, y1 = box_frac
    return im.crop((int(w * x0), int(h * y0), int(w * x1), int(h * y1)))


def ensure_open_materials() -> None:
    fetch = GODOT / "scripts" / "tools" / "fetch_open_materials.py"
    print("RUN", fetch)
    subprocess.run([sys.executable, str(fetch)], check=False)


def build_material(
    keys: list[str],
    c_lo: np.ndarray,
    c_hi: np.ndarray,
    ink: np.ndarray,
    seed: int,
    mix: float,
    ink_amt: float,
    sat: float,
    out_stem: str,
    purple_bleed: np.ndarray | None = None,
    purple_amt: float = 0.0,
) -> None:
    color = load_map(keys, "color")
    if color is None:
        color = np.full((SIZE, SIZE, 3), c_hi, dtype=np.float32)
    ao = load_map(keys, "ao")
    normal = load_map(keys, "normal")
    rough = load_map(keys, "rough")

    color = local_contrast(color, 1, 0.7)
    color = grade_keep_structure(color, c_lo, c_hi, mix=mix, contrast=1.2)
    color = bake_depth_into_albedo(color, ao, normal)
    if purple_bleed is not None and purple_amt > 0:
        dark = 1.0 - luminance(color)
        dark = np.clip((dark - 0.35) / 0.5, 0.0, 1.0)[..., None]
        color = color * (1.0 - purple_amt * dark) + purple_bleed * (purple_amt * dark)
    color = overlay_ink(color, ink, ink_amt)
    color = desaturate(color, sat)
    color = macro_breakup(color, seed, 0.10)
    color = add_grain(soft_seamless(color, 20), 0.016, seed)
    save_rgb(f"{out_stem}_512.png", color)

    n_out = stylize_normal(normal, seed)
    save_rgb(f"{out_stem}_n_512.png", n_out)
    r_out = stylize_rough(rough, ao, seed)
    save_gray_as_rgb(f"{out_stem}_r_512.png", r_out)


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

    ink_im = resize_cover(load_rgb(ink_a if ink_a.exists() else style_ost))
    if ink_b.exists():
        ink = 0.55 * to_arr(ink_im) + 0.45 * to_arr(resize_cover(load_rgb(ink_b)))
    else:
        ink = to_arr(ink_im)
    ink = desaturate(ink, 0.2)
    ink = grade_keep_structure(ink, INK, PARCHMENT_DARK, mix=0.65, contrast=1.3)
    ink = bake_depth_into_albedo(ink, None, None)
    ink = macro_breakup(add_grain(soft_seamless(ink, 18), 0.02, 11), 11, 0.08)
    save_rgb("tex_ink_grime_512.png", ink)
    # flat helper maps for ink
    save_rgb("tex_ink_grime_n_512.png", stylize_normal(None, 11))
    save_gray_as_rgb("tex_ink_grime_r_512.png", stylize_rough(None, None, 11, 0.92))

    build_material(
        ["plaster", "concrete"],
        PARCHMENT_DARK,
        PARCHMENT,
        ink,
        seed=2,
        mix=0.42,
        ink_amt=0.18,
        sat=0.72,
        out_stem="tex_attic_plaster",
    )
    build_material(
        ["wood_boards", "wood_planks", "wood"],
        PARCHMENT_DARK,
        np.clip(WOOD * 1.25 + PARCHMENT * 0.15, 0, 1),
        ink,
        seed=3,
        mix=0.34,
        ink_amt=0.08,
        sat=0.84,
        out_stem="tex_attic_wood",
    )
    # Lift wood midtones — DD boards read as material, not near-black
    wood_p = OUT / "tex_attic_wood_512.png"
    if wood_p.exists():
        w = to_arr(load_rgb(wood_p))
        w = np.clip(w * 1.22 + 0.04, 0.0, 1.0)
        save_rgb("tex_attic_wood_512.png", w)

    pref = None
    purple_ref = emb1 if emb1.exists() else color_shot
    if purple_ref and purple_ref.exists():
        pref = to_arr(resize_cover(crop_interest(purple_ref, (0.25, 0.35, 0.75, 0.95))))
    else:
        pref = np.full((SIZE, SIZE, 3), PURPLE, dtype=np.float32)

    build_material(
        ["stone_pavement", "stone_rocks", "concrete"],
        STONE * 0.65,
        STONE * 1.1 + PARCHMENT * 0.12,
        ink,
        seed=4,
        mix=0.4,
        ink_amt=0.16,
        sat=0.76,
        out_stem="tex_alley_stone",
        purple_bleed=pref * 0.5 + PURPLE * 0.5,
        purple_amt=0.35,
    )
    build_material(
        ["stone_pavement", "concrete", "stone_rocks"],
        INK,
        STONE,
        ink,
        seed=9,
        mix=0.45,
        ink_amt=0.24,
        sat=0.68,
        out_stem="tex_alley_floor",
        purple_bleed=pref * 0.35 + PURPLE * 0.65,
        purple_amt=0.18,
    )
    build_material(
        ["metal", "metal_rust", "metal_smooth"],
        INK * 0.25 + STONE * 0.35,
        STONE * 0.75 + PARCHMENT_DARK * 0.25,
        ink,
        seed=8,
        mix=0.38,
        ink_amt=0.12,
        sat=0.62,
        out_stem="tex_metal_barrel",
        purple_bleed=PURPLE[None, None, :] * np.ones((SIZE, SIZE, 1), dtype=np.float32),
        purple_amt=0.22,
    )

    # Vsegrib — author refs; synthesize normal from luminance for depth
    if mush.exists():
        m1 = to_arr(resize_cover(load_rgb(mush)))
    else:
        m1 = pref
    if mush2.exists():
        m = 0.55 * m1 + 0.45 * to_arr(resize_cover(load_rgb(mush2)))
    else:
        m = m1
    m = local_contrast(m, 2, 0.55)
    flesh = grade_keep_structure(m, PURPLE * 0.45, PURPLE_GLOW, mix=0.55, contrast=1.1)
    flesh = flesh * 0.8 + pref * 0.2
    # fake AO from luminance
    fake_ao = luminance(flesh)
    fake_ao = (fake_ao - fake_ao.min()) / max(1e-5, fake_ao.max() - fake_ao.min())
    flesh = bake_depth_into_albedo(flesh, fake_ao[..., None] * np.ones(3), None)
    flesh = overlay_ink(flesh, ink, 0.12)
    flesh = desaturate(macro_breakup(add_grain(soft_seamless(flesh, 18), 0.025, 5), 5, 0.08), 0.84)
    save_rgb("tex_vsegrib_flesh_512.png", flesh)
    # normal from height
    h = luminance(flesh)
    gy, gx = np.gradient(h)
    n = np.stack([-gx * 4.0, -gy * 4.0, np.ones_like(h)], axis=-1)
    nn = np.linalg.norm(n, axis=-1, keepdims=True) + 1e-6
    n = n / nn
    n_enc = n * 0.5 + 0.5
    save_rgb("tex_vsegrib_flesh_n_512.png", stylize_normal(n_enc, 5))
    save_gray_as_rgb("tex_vsegrib_flesh_r_512.png", stylize_rough(None, fake_ao[..., None], 5, 0.8))

    cap = grade_keep_structure(m, PURPLE, PURPLE_GLOW * 1.05, mix=0.58, contrast=1.2)
    cap = bake_depth_into_albedo(cap, fake_ao[..., None] * np.ones(3), None)
    cap = overlay_ink(cap, ink, 0.08)
    cap = desaturate(macro_breakup(add_grain(soft_seamless(cap, 18), 0.02, 6), 6, 0.07), 0.88)
    save_rgb("tex_vsegrib_cap_512.png", cap)
    save_rgb("tex_vsegrib_cap_n_512.png", stylize_normal(n_enc, 6))
    save_gray_as_rgb("tex_vsegrib_cap_r_512.png", stylize_rough(None, fake_ao[..., None], 6, 0.7))
    emit = np.clip((luminance(cap) - 0.45) * 2.2, 0.0, 1.0)
    save_rgb("tex_vsegrib_cap_emit_512.png", PURPLE_GLOW[None, None, :] * emit[..., None])

    print("DONE", OUT)


if __name__ == "__main__":
    main()
