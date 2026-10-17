extends SceneTree

## Rebuild playable shop from authored oddity_shop.glb and set it as main scene.
## godot4 --path . --headless -s res://scripts/build_oddity_shop.gd

const GLB_PATH := "res://assets/meshes/locations/oddity_shop.glb"
const SHOP_SCENE := "res://scenes/shop.tscn"
## Cone (John) height in Blender Z ≈ 7.75 → target ~1.85 m
const MODEL_SCALE := 0.2387


func _init() -> void:
	var abs_glb := ProjectSettings.globalize_path(GLB_PATH)
	if not FileAccess.file_exists(abs_glb):
		push_error("MISSING_GLB %s" % abs_glb)
		quit(1)
		return
	var err := _save_shop()
	if err != OK:
		push_error("SHOP_BUILD_FAIL %s" % err)
		quit(1)
		return
	_set_main_scene(SHOP_SCENE)
	print("ODDITY_SHOP_OK scale=%s main=%s" % [MODEL_SCALE, SHOP_SCENE])
	quit()


func _set_main_scene(path: String) -> void:
	var cfg := ConfigFile.new()
	var load_err := cfg.load("res://project.godot")
	if load_err != OK:
		push_warning("project.godot load failed: %s" % load_err)
		return
	cfg.set_value("application", "run/main_scene", path)
	cfg.save("res://project.godot")


func _save_shop() -> Error:
	var root := Node3D.new()
	root.name = "Shop"

	root.add_child(_make_env())
	root.add_child(_make_key_light(Vector3(0.4, 3.4, 1.2), Color(0.92, 0.88, 0.95), 1.15, 14.0))
	root.add_child(_make_fill_light(Vector3(-2.2, 2.2, -1.4), Color(0.55, 0.28, 0.62), 0.55, 7.0))
	root.add_child(_make_safety_floor())

	var model := _instance_glb(GLB_PATH)
	if model == null:
		return ERR_CANT_OPEN
	model.name = "OddityShopModel"
	model.scale = Vector3.ONE * MODEL_SCALE
	# Blender Z-up → glTF Y-up already; drop so floor sits near y=0.
	model.position = Vector3.ZERO
	root.add_child(model)
	# Need inside SceneTree for MeshInstance3D.global_transform during collision bake.
	get_root().add_child(root)
	_add_trimesh_collision(root, model)

	# Keep stub choices so route still works; place near counter-ish.
	_shop_choice(
		root,
		"BuyPotion",
		Vector3(-1.1, 0.0, 0.6),
		"potion",
		"[E] Мутный эликсир",
		PackedStringArray([
			"Склянка тёплая. Жидкость медленно переливается сама.",
			"Тебе суют бумажный пропуск: «В Центральную — пока не передумали.»"
		]),
		Color(0.35, 0.55, 0.4)
	)
	_shop_choice(
		root,
		"BuyTrinket",
		Vector3(0.0, 0.0, 0.6),
		"trinket",
		"[E] Костяная безделушка",
		PackedStringArray([
			"Тяжёлая штуковина. На ощупь — как чужой сустав.",
			"Вместе с ней — пропуск в Центральную библиотеку."
		]),
		Color(0.7, 0.65, 0.5)
	)
	_shop_choice(
		root,
		"BuyFood",
		Vector3(1.1, 0.0, 0.6),
		"food",
		"[E] Сладкий свёрток",
		PackedStringArray([
			"Пахнет карамелью и плесенью одновременно.",
			"Продавец шепчет: «Это и есть плата. А вот пропуск.»"
		]),
		Color(0.55, 0.35, 0.28)
	)

	var back := _make_interactable(
		"ShopExit",
		Vector3(0.0, 0.0, 3.6),
		"[E] Выйти в переулки",
		PackedStringArray(["Колокольчик над дверью не звенит — только глухой щелчок."]),
		"res://scenes/alley.tscn"
	)
	var bm := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.4, 2.1, 0.25)
	bm.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.18, 0.18, 0.2)
	bm.material_override = mat
	bm.position = Vector3(0, 1.05, 0)
	back.add_child(bm)
	var bc := CollisionShape3D.new()
	bc.name = "Collision"
	var bs := BoxShape3D.new()
	bs.size = Vector3(1.6, 2.1, 0.45)
	bc.shape = bs
	bc.position = Vector3(0, 1.05, 0)
	back.add_child(bc)
	root.add_child(back)

	_add_player(root, Vector3(0.0, 0.9, 2.4))
	_mark_owners(root, root)
	get_root().remove_child(root)

	var packed := PackedScene.new()
	var pack_err := packed.pack(root)
	if pack_err != OK:
		return pack_err
	DirAccess.make_dir_recursive_absolute("res://scenes")
	return ResourceSaver.save(packed, SHOP_SCENE)



func _make_safety_floor() -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "SafetyFloor"
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(20, 0.2, 24)
	mesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.08, 0.08, 0.09)
	mesh.material_override = mat
	mesh.position = Vector3(0, -0.1, 0)
	body.add_child(mesh)
	var col := CollisionShape3D.new()
	col.name = "Collision"
	var shape := BoxShape3D.new()
	shape.size = Vector3(20, 0.2, 24)
	col.shape = shape
	col.position = Vector3(0, -0.1, 0)
	body.add_child(col)
	return body

func _make_env() -> WorldEnvironment:
	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.06, 0.06, 0.07)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.42, 0.4, 0.45)
	env.ambient_light_energy = 0.75
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.fog_enabled = true
	env.fog_light_color = Color(0.12, 0.1, 0.14)
	env.fog_density = 0.015
	world_env.environment = env
	return world_env


func _make_key_light(pos: Vector3, color: Color, energy: float, rng: float) -> OmniLight3D:
	var lamp := OmniLight3D.new()
	lamp.name = "KeyLight"
	lamp.position = pos
	lamp.light_color = color
	lamp.light_energy = energy
	lamp.omni_range = rng
	lamp.shadow_enabled = true
	return lamp


func _make_fill_light(pos: Vector3, color: Color, energy: float, rng: float) -> OmniLight3D:
	var lamp := OmniLight3D.new()
	lamp.name = "FillLight"
	lamp.position = pos
	lamp.light_color = color
	lamp.light_energy = energy
	lamp.omni_range = rng
	return lamp


func _instance_glb(path: String) -> Node3D:
	var abs_path := ProjectSettings.globalize_path(path) if path.begins_with("res://") else path
	if not FileAccess.file_exists(abs_path):
		push_error("load failed missing %s" % abs_path)
		return null
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_file(abs_path, state)
	if err != OK:
		push_error("GLTF_LOAD_FAIL %s err=%s" % [path, err])
		return null
	var scn := doc.generate_scene(state)
	if scn == null:
		push_error("GLTF_SCENE_NULL %s" % path)
		return null
	if scn is Node3D:
		return scn as Node3D
	var wrap := Node3D.new()
	wrap.add_child(scn)
	return wrap


func _add_trimesh_collision(root: Node, model: Node) -> void:
	var body := StaticBody3D.new()
	body.name = "OddityShopCollision"
	root.add_child(body)
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(model, meshes)
	var idx := 0
	for mi in meshes:
		if mi.mesh == null:
			continue
		var shape := mi.mesh.create_trimesh_shape()
		if shape == null:
			continue
		var col := CollisionShape3D.new()
		col.name = "Col_%s_%d" % [mi.name, idx]
		col.shape = shape
		# Local chain (works even if not inside SceneTree / under Skeleton).
		col.transform = _xform_under(mi, root)
		body.add_child(col)
		idx += 1
	print("collision_shapes=", idx)


func _xform_under(node: Node3D, ancestor: Node) -> Transform3D:
	var xforms: Array[Transform3D] = []
	var cur: Node = node
	while cur != null:
		if cur is Node3D:
			xforms.append((cur as Node3D).transform)
		if cur == ancestor:
			break
		cur = cur.get_parent()
	var out := Transform3D.IDENTITY
	for i in range(xforms.size() - 1, -1, -1):
		out *= xforms[i]
	return out


func _collect_meshes(n: Node, out: Array[MeshInstance3D]) -> void:
	if n is MeshInstance3D:
		out.append(n as MeshInstance3D)
	for c in n.get_children():
		_collect_meshes(c, out)


func _shop_choice(
	root: Node,
	name: String,
	pos: Vector3,
	choice_id: String,
	prompt: String,
	lines: PackedStringArray,
	color: Color
) -> void:
	var body := StaticBody3D.new()
	body.name = name
	body.position = pos
	body.set_script(load("res://scripts/shop_item.gd"))
	body.set("prompt_text", prompt)
	body.set("dialogue_lines", lines)
	body.set("choice_id", choice_id)
	body.set("change_scene_to", "res://scenes/central_library.tscn")
	var size := Vector3(0.7, 0.7, 0.7)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color.a = 0.35
	mesh.material_override = mat
	mesh.position = Vector3(0, size.y * 0.5, 0)
	body.add_child(mesh)
	var col := CollisionShape3D.new()
	col.name = "Collision"
	var shape := BoxShape3D.new()
	shape.size = size + Vector3(0.1, 0.1, 0.1)
	col.shape = shape
	col.position = Vector3(0, size.y * 0.5, 0)
	body.add_child(col)
	root.add_child(body)


func _make_interactable(
	name: String,
	pos: Vector3,
	prompt: String,
	lines: PackedStringArray,
	scene_path: String
) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = name
	body.position = pos
	body.set_script(load("res://scripts/interactable.gd"))
	body.set("prompt_text", prompt)
	body.set("dialogue_lines", lines)
	body.set("change_scene_to", scene_path)
	return body


func _add_player(root: Node, pos: Vector3) -> void:
	var player := CharacterBody3D.new()
	player.name = "Player"
	var feet_y := pos.y
	if feet_y > 0.45:
		feet_y = maxf(pos.y - 0.85, 0.02)
	player.position = Vector3(pos.x, feet_y, pos.z)
	player.set_script(load("res://scripts/player_fps.gd"))

	var pcol := CollisionShape3D.new()
	pcol.name = "Collision"
	var pshape := CapsuleShape3D.new()
	pshape.radius = 0.28
	pshape.height = 1.6
	pcol.shape = pshape
	pcol.position = Vector3(0, 0.8, 0)
	player.add_child(pcol)

	var cam := Camera3D.new()
	cam.name = "Camera3D"
	cam.position = Vector3(0, 0.7, 0)
	cam.current = true
	player.add_child(cam)

	var ray := RayCast3D.new()
	ray.name = "InteractRay"
	ray.target_position = Vector3(0, 0, -2.8)
	ray.enabled = true
	cam.add_child(ray)

	var prompt_layer := CanvasLayer.new()
	prompt_layer.name = "PromptLayer"
	player.add_child(prompt_layer)
	var prompt := Label.new()
	prompt.name = "Prompt"
	prompt.visible = false
	prompt.anchor_left = 0.5
	prompt.anchor_right = 0.5
	prompt.anchor_top = 0.62
	prompt.anchor_bottom = 0.62
	prompt.offset_left = -260
	prompt.offset_right = 260
	prompt.offset_top = -18
	prompt.offset_bottom = 18
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.text = "[E]"
	prompt_layer.add_child(prompt)
	var hint := Label.new()
	hint.name = "ControlsHint"
	hint.anchor_left = 0.0
	hint.anchor_right = 1.0
	hint.anchor_top = 1.0
	hint.anchor_bottom = 1.0
	hint.offset_left = 16
	hint.offset_right = -16
	hint.offset_top = -36
	hint.offset_bottom = -10
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	hint.add_theme_font_size_override("font_size", 14)
	hint.text = "WASD · Shift · Ctrl · Пробел · E · ЛКМ/F · I · K · Esc"
	prompt_layer.add_child(hint)
	root.add_child(player)


func _mark_owners(n: Node, owner: Node) -> void:
	for c in n.get_children():
		c.owner = owner
		_mark_owners(c, owner)
