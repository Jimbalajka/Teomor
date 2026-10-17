"""Export oddity_shop_bw.blend -> GLB for Godot (no anim bake)."""
from __future__ import annotations

import os
import sys

import bpy
from mathutils import Vector

SRC = "/home/ec2-user/Teomor/oddity_shop_bw.blend"
OUT = "/home/ec2-user/Teomor/godot/assets/meshes/locations/oddity_shop.glb"
SKIP_NAMES = {"Plane"}  # huge backdrop, not gameplay geo


def _convert_emission_to_principled() -> None:
    for mat in bpy.data.materials:
        nt = mat.node_tree
        if nt is None:
            continue
        nodes = nt.nodes
        links = nt.links
        out = None
        em = None
        for n in nodes:
            if n.type == "OUTPUT_MATERIAL":
                out = n
            elif n.type == "EMISSION":
                em = n
        if out is None or em is None:
            continue
        if not em.outputs["Emission"].is_linked:
            continue
        col_from = None
        for link in list(links):
            if link.to_node == em and link.to_socket.name == "Color":
                col_from = link.from_socket
        bsdf = nodes.new("ShaderNodeBsdfPrincipled")
        bsdf.location = (em.location.x + 40.0, em.location.y)
        if col_from is not None:
            links.new(col_from, bsdf.inputs["Base Color"])
            links.new(col_from, bsdf.inputs["Emission Color"])
            bsdf.inputs["Emission Strength"].default_value = 0.25
        for link in list(links):
            if link.to_node == out and link.to_socket.name == "Surface":
                links.remove(link)
        links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
        print("converted", mat.name)


def _bounds(objs: list[bpy.types.Object]) -> tuple[Vector, Vector]:
    minv = Vector((1e9, 1e9, 1e9))
    maxv = Vector((-1e9, -1e9, -1e9))
    for o in objs:
        for corner in o.bound_box:
            w = o.matrix_world @ Vector(corner)
            minv = Vector((min(minv.x, w.x), min(minv.y, w.y), min(minv.z, w.z)))
            maxv = Vector((max(maxv.x, w.x), max(maxv.y, w.y), max(maxv.z, w.z)))
    return minv, maxv


def main() -> int:
    bpy.ops.wm.open_mainfile(filepath=SRC)

    export_meshes: list[bpy.types.Object] = []
    for o in bpy.data.objects:
        if o.type != "MESH":
            continue
        if o.name.startswith("WGT-") or o.name in SKIP_NAMES:
            o.hide_render = True
            o.hide_viewport = True
            continue
        o.hide_render = False
        o.hide_viewport = False
        export_meshes.append(o)

    _convert_emission_to_principled()
    minv, maxv = _bounds(export_meshes)
    print("meshes", len(export_meshes))
    print("bounds", tuple(round(v, 3) for v in minv), "->", tuple(round(v, 3) for v in maxv))
    print("size", tuple(round(maxv[i] - minv[i], 3) for i in range(3)))

    bpy.ops.object.select_all(action="DESELECT")
    for o in bpy.data.objects:
        o.select_set(False)
    selected = 0
    for o in export_meshes:
        o.select_set(True)
        selected += 1
    for o in bpy.data.objects:
        if o.type == "ARMATURE":
            o.select_set(True)
            selected += 1
    print("selected", selected)

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=OUT,
        use_selection=True,
        export_format="GLB",
        export_texcoords=True,
        export_normals=True,
        export_materials="EXPORT",
        export_image_format="AUTO",
        export_apply=False,
        export_yup=True,
        export_animations=False,
        export_skins=True,
        export_morph=False,
    )
    print("exported", OUT, "bytes", os.path.getsize(OUT))
    return 0


if __name__ == "__main__":
    sys.exit(main())
