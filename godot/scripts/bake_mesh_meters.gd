extends SceneTree

## Bake awkward FBX packs into meter-correct GLB + commit-friendly .import sidecars.
## godot4 --path . --headless -s res://scripts/bake_mesh_meters.gd

const PROTO := "res://assets/meshes/modular/proto/"
const CHAR := "res://assets/meshes/props/character/"
const HUM := "res://assets/meshes/props/humanoid/"

# Proto greybox is authored as ~2 m modules. Bake ×0.5 → 1 m grid next to player.
const PROTO_SCALE := 0.5
# Character_Character raw height ~2.4 m on long axis after orient; fit ~1.85.
const PROTO_CHAR_SCALE := 0.85


func _init() -> void:
	_bake_dir_fbx(PROTO, PROTO_SCALE, {
		"Character_Character.fbx": PROTO_CHAR_SCALE,
	})
	_bake_one(CHAR + "Dummy.fbx", CHAR + "Dummy.glb", 1.0)
	_write_import(CHAR + "Dummy.fbx", 1.0, "uid://teomor_dummy_fbx")
	_bake_one(HUM + "Humanoid.fbx", HUM + "Humanoid.glb", 1.0)
	_write_import(HUM + "Humanoid.fbx", 1.0, "uid://teomor_humanoid_fbx")
	print("BAKE_MESH_METERS_OK")
	quit()


func _bake_dir_fbx(dir_res: String, default_scale: float, overrides: Dictionary) -> void:
	var d := DirAccess.open(dir_res)
	if d == null:
		push_error("missing %s" % dir_res)
		return
	d.list_dir_begin()
	var fn := d.get_next()
	while fn != "":
		if fn.ends_with(".fbx") and not fn.begins_with("Sample"):
			var scale: float = float(overrides.get(fn, default_scale))
			var src := dir_res + fn
			var dst := dir_res + fn.get_basename() + ".glb"
			_bake_one(src, dst, scale)
			_write_import(src, scale, "")
		fn = d.get_next()


func _bake_one(src_res: String, dst_res: String, bake_scale: float) -> void:
	var src := ProjectSettings.globalize_path(src_res)
	var dst := ProjectSettings.globalize_path(dst_res)
	if not FileAccess.file_exists(src):
		push_warning("SKIP missing %s" % src_res)
		return
	var fdoc := FBXDocument.new()
	var fstate := FBXState.new()
	var aerr := fdoc.append_from_file(src, fstate)
	if aerr != OK:
		push_warning("FBX_FAIL %s err=%s" % [src_res, aerr])
		return
	# Round-trip to GLB first so ImporterMesh → ArrayMesh.
	var tmp := dst + ".tmp.glb"
	var w1 := GLTFDocument.new().write_to_filesystem(fstate, tmp)
	if w1 != OK:
		push_warning("WRITE_TMP_FAIL %s err=%s" % [src_res, w1])
		return
	var gdoc := GLTFDocument.new()
	var gst := GLTFState.new()
	if gdoc.append_from_file(tmp, gst) != OK:
		push_warning("RELOAD_TMP_FAIL %s" % src_res)
		return
	var scn := gdoc.generate_scene(gst)
	if scn == null:
		push_warning("SCENE_FAIL %s" % src_res)
		return
	# Bake scale into every Node3D local scale so GLTF export keeps meters.
	_multiply_node_scales(scn, bake_scale)
	var out_doc := GLTFDocument.new()
	var out_state := GLTFState.new()
	var cerr := out_doc.append_from_scene(scn, out_state)
	if cerr != OK:
		DirAccess.copy_absolute(tmp, dst)
		print("BAKE_COPY_ONLY %s scale_hint=%s (append_from_scene=%s)" % [dst_res, bake_scale, cerr])
	else:
		var w2 := out_doc.write_to_filesystem(out_state, dst)
		print("BAKE %s scale=%s write=%s" % [dst_res, bake_scale, w2])
	DirAccess.remove_absolute(tmp)
	var a := _aabb(scn)
	print("  aabb_size", a.size, " hY", snappedf(a.size.y, 0.001))


func _multiply_node_scales(node: Node, factor: float) -> void:
	var target := _find_primary_scale_node(node)
	if target != null:
		target.scale = target.scale * factor


func _find_primary_scale_node(node: Node) -> Node3D:
	# First Node3D with non-1 scale (Armature/×100 hubs); else scene root.
	var q: Array = [node]
	var root3: Node3D = null
	while not q.is_empty():
		var n: Node = q.pop_front()
		if n is Node3D:
			var n3 := n as Node3D
			if root3 == null:
				root3 = n3
			if (n3.scale - Vector3.ONE).length() > 0.001:
				return n3
		for c in n.get_children():
			q.append(c)
	return root3


func _write_import(fbx_res: String, root_scale: float, uid: String) -> void:
	var abs_fbx := ProjectSettings.globalize_path(fbx_res)
	if not FileAccess.file_exists(abs_fbx):
		return
	var import_path := abs_fbx + ".import"
	var uid_line := uid if uid != "" else "uid://%s" % fbx_res.get_file().replace(".", "_").replace(" ", "_").to_lower()
	var dest := "res://.godot/imported/%s-%s.scn" % [fbx_res.get_file(), uid_line.replace("uid://", "")]
	var text := """[remap]

importer="scene"
importer_version=1
type="PackedScene"
uid="%s"
path="%s"

[deps]

source_file="%s"
dest_files=PackedStringArray("%s")

[params]

nodes/root_type=""
nodes/root_name=""
nodes/root_scale=%s
nodes/apply_root_scale=true
meshes/ensure_tangents=true
meshes/generate_lods=true
meshes/create_shadow_meshes=true
meshes/light_baking=1
meshes/lightmap_texel_size=0.2
skins/use_named_skins=true
animation/import=true
animation/fps=30
import_script/path=""
_subresources={}
fbx/importer=0
fbx/allow_geometry_helper_nodes=false
fbx/embedded_image_handling=1
""" % [uid_line, dest, fbx_res, dest, str(root_scale)]
	var f := FileAccess.open(import_path, FileAccess.WRITE)
	if f == null:
		push_warning("IMPORT_WRITE_FAIL %s" % import_path)
		return
	f.store_string(text)
	f.close()
	print("IMPORT %s root_scale=%s" % [fbx_res, root_scale])


func _aabb(n: Node) -> AABB:
	var boxes: Array = []
	_collect(n, Transform3D.IDENTITY, boxes)
	if boxes.is_empty():
		return AABB()
	var a: AABB = boxes[0]
	for i in range(1, boxes.size()):
		a = a.merge(boxes[i])
	return a


func _collect(n: Node, xf: Transform3D, boxes: Array) -> void:
	var local := xf
	if n is Node3D:
		local = xf * (n as Node3D).transform
	if n is MeshInstance3D and (n as MeshInstance3D).mesh:
		var a := (n as MeshInstance3D).mesh.get_aabb()
		var merged := AABB()
		var first := true
		for dx in [0.0, 1.0]:
			for dy in [0.0, 1.0]:
				for dz in [0.0, 1.0]:
					var p := local * (a.position + Vector3(a.size.x * dx, a.size.y * dy, a.size.z * dz))
					if first:
						merged = AABB(p, Vector3.ZERO)
						first = false
					else:
						merged = merged.expand(p)
		boxes.append(merged)
	for c in n.get_children():
		_collect(c, local if n is Node3D else xf, boxes)
