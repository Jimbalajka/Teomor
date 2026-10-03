extends SceneTree

# One-shot:
# godot4 --path . --headless -s res://scripts/build_scenes.gd


func _init() -> void:
	DirAccess.make_dir_recursive_absolute("res://scenes")
	var e1 := _save_attic()
	var e2 := _save_alley()
	var e3 := _save_warehouse()
	var e4 := _save_library_street()
	var e5 := _save_library()
	if e1 != OK or e2 != OK or e3 != OK or e4 != OK or e5 != OK:
		push_error("BUILD_FAIL attic=%s alley=%s warehouse=%s libstreet=%s library=%s" % [e1, e2, e3, e4, e5])
		quit(1)
		return
	if FileAccess.file_exists("res://scenes/outside_stub.tscn"):
		DirAccess.remove_absolute("res://scenes/outside_stub.tscn")
	print("BUILD_OK")
	quit()


func _box_mesh(size: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = "Mesh"
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mi.material_override = mat
	return mi


func _static_box(name: String, size: Vector3, pos: Vector3, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = name
	body.position = pos
	body.add_child(_box_mesh(size, color))
	var col := CollisionShape3D.new()
	col.name = "Collision"
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	return body


func _mushroom(name: String, pos: Vector3, scale: float = 1.0) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = name
	body.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.35, 0.4)
	var stem := MeshInstance3D.new()
	stem.name = "Stem"
	var stem_mesh := CylinderMesh.new()
	stem_mesh.top_radius = 0.05 * scale
	stem_mesh.bottom_radius = 0.07 * scale
	stem_mesh.height = 0.25 * scale
	stem.mesh = stem_mesh
	stem.position = Vector3(0, 0.12 * scale, 0)
	stem.material_override = mat
	body.add_child(stem)
	var cap := MeshInstance3D.new()
	cap.name = "Cap"
	var cap_mesh := SphereMesh.new()
	cap_mesh.radius = 0.14 * scale
	cap_mesh.height = 0.16 * scale
	cap.mesh = cap_mesh
	cap.position = Vector3(0, 0.28 * scale, 0)
	var cap_mat := StandardMaterial3D.new()
	cap_mat.albedo_color = Color(0.7, 0.45, 0.5)
	cap.material_override = cap_mat
	body.add_child(cap)
	var col := CollisionShape3D.new()
	col.name = "Collision"
	var shape := SphereShape3D.new()
	shape.radius = 0.16 * scale
	col.shape = shape
	col.position = Vector3(0, 0.22 * scale, 0)
	body.add_child(col)
	return body


func _mark_owners(node: Node, owner: Node) -> void:
	for child in node.get_children():
		child.owner = owner
		_mark_owners(child, owner)


func _make_interactable(name: String, pos: Vector3, prompt: String, lines: PackedStringArray, scene_path: String = "") -> StaticBody3D:
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
	player.position = pos
	player.set_script(load("res://scripts/player_fps.gd"))

	var pcol := CollisionShape3D.new()
	pcol.name = "Collision"
	var pshape := CapsuleShape3D.new()
	pshape.radius = 0.28
	pshape.height = 1.6
	pcol.shape = pshape
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
	root.add_child(player)


func _underground_env(bg: Color, ambient: Color) -> WorldEnvironment:
	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = bg
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = ambient
	env.ambient_light_energy = 0.7
	env.fog_enabled = true
	env.fog_light_color = Color(0.25, 0.28, 0.26)
	env.fog_density = 0.02
	world_env.environment = env
	return world_env


func _save_attic() -> Error:
	var root := Node3D.new()
	root.name = "Attic"

	root.add_child(_underground_env(Color(0.07, 0.07, 0.08), Color(0.3, 0.28, 0.26)))

	var lamp := OmniLight3D.new()
	lamp.name = "AtticLamp"
	lamp.position = Vector3(0, 2.2, 0)
	lamp.light_color = Color(1.0, 0.88, 0.7)
	lamp.light_energy = 1.0
	lamp.omni_range = 7.0
	root.add_child(lamp)

	var wood := Color(0.42, 0.32, 0.22)
	var plaster := Color(0.48, 0.46, 0.42)
	var dark := Color(0.22, 0.2, 0.18)
	var damp := Color(0.35, 0.38, 0.34)

	# Small cramped attic ~6x2.6x5
	root.add_child(_static_box("Floor", Vector3(6, 0.2, 5), Vector3(0, -0.1, 0), wood))
	root.add_child(_static_box("Ceiling", Vector3(6, 0.2, 5), Vector3(0, 2.6, 0), dark))
	root.add_child(_static_box("WallBack", Vector3(6, 2.6, 0.2), Vector3(0, 1.3, -2.5), plaster))
	root.add_child(_static_box("WallFront", Vector3(6, 2.6, 0.2), Vector3(0, 1.3, 2.5), plaster))
	root.add_child(_static_box("WallLeft", Vector3(0.2, 2.6, 5), Vector3(-3.0, 1.3, 0), damp))
	root.add_child(_static_box("WallRight", Vector3(0.2, 2.6, 5), Vector3(3.0, 1.3, 0), plaster))

	# Bed stub
	root.add_child(_static_box("Bed", Vector3(2.0, 0.35, 1.0), Vector3(-1.6, 0.2, -1.6), Color(0.35, 0.3, 0.28)))
	root.add_child(_static_box("BedPillow", Vector3(0.5, 0.15, 0.4), Vector3(-2.2, 0.45, -1.6), Color(0.45, 0.42, 0.4)))

	# Mirror stub (no character select)
	var mirror := _make_interactable(
		"Mirror",
		Vector3(2.2, 0.0, -1.8),
		"[E] Посмотреть в зеркало",
		PackedStringArray([
			"В зеркале — ты. Каждый вздох выпускает пар и замыливает отражение.",
			"Приходится протирать стекло рукавом.",
			"(Выбор внешности позже — пока только взгляд.)"
		])
	)
	var mirror_mesh := _box_mesh(Vector3(0.08, 1.2, 0.7), Color(0.55, 0.6, 0.65))
	mirror_mesh.position = Vector3(0, 1.1, 0)
	mirror.add_child(mirror_mesh)
	var mirror_frame := _box_mesh(Vector3(0.12, 1.35, 0.85), Color(0.25, 0.2, 0.15))
	mirror_frame.position = Vector3(-0.02, 1.1, 0)
	mirror.add_child(mirror_frame)
	var mcol := CollisionShape3D.new()
	mcol.name = "Collision"
	var mshape := BoxShape3D.new()
	mshape.size = Vector3(0.35, 1.4, 0.9)
	mcol.shape = mshape
	mcol.position = Vector3(0, 1.1, 0)
	mirror.add_child(mcol)
	root.add_child(mirror)

	# Ceiling hatch + vertical ladder visual (activate only, no climb)
	root.add_child(_static_box("HatchFrame", Vector3(1.0, 0.08, 1.0), Vector3(2.0, 2.5, 1.2), Color(0.2, 0.18, 0.15)))
	var ladder := _make_interactable(
		"RoofLadder",
		Vector3(2.0, 0.0, 1.2),
		"[E] Спуститься по лестнице",
		PackedStringArray([
			"Ты вылезаешь через занавешенную дыру на крышу дома.",
			"Лестница ведёт вниз вдоль трёхэтажного здания.",
			"Одним движением ты оказываешься внизу — в узком переулке."
		]),
		"res://scenes/alley.tscn"
	)
	# ladder rails as stacked boxes (visual only)
	for i in range(5):
		var step := _box_mesh(Vector3(0.5, 0.06, 0.12), Color(0.32, 0.24, 0.16))
		step.name = "Step_%d" % i
		step.position = Vector3(0, 0.35 + i * 0.4, 0)
		ladder.add_child(step)
	var rail_l := _box_mesh(Vector3(0.06, 2.2, 0.06), Color(0.28, 0.2, 0.14))
	rail_l.name = "RailL"
	rail_l.position = Vector3(-0.22, 1.2, 0)
	ladder.add_child(rail_l)
	var rail_r := _box_mesh(Vector3(0.06, 2.2, 0.06), Color(0.28, 0.2, 0.14))
	rail_r.name = "RailR"
	rail_r.position = Vector3(0.22, 1.2, 0)
	ladder.add_child(rail_r)
	var lcol := CollisionShape3D.new()
	lcol.name = "Collision"
	var lshape := BoxShape3D.new()
	lshape.size = Vector3(0.8, 2.4, 0.6)
	lcol.shape = lshape
	lcol.position = Vector3(0, 1.2, 0)
	ladder.add_child(lcol)
	root.add_child(ladder)

	# damp props
	root.add_child(_static_box("Crate", Vector3(0.7, 0.5, 0.7), Vector3(-2.2, 0.25, 1.4), Color(0.38, 0.28, 0.18)))
	root.add_child(_mushroom("Mushroom_Attic1", Vector3(-2.7, 0.9, -0.4), 0.9))
	root.add_child(_mushroom("Mushroom_Attic2", Vector3(2.7, 1.4, 0.3), 1.1))

	_add_player(root, Vector3(0, 0.9, 0.3))

	_mark_owners(root, root)
	var packed := PackedScene.new()
	var pack_err := packed.pack(root)
	if pack_err != OK:
		return pack_err
	return ResourceSaver.save(packed, "res://scenes/attic.tscn")


func _slab(root: Node, name: String, size: Vector3, pos: Vector3, color: Color) -> void:
	root.add_child(_static_box(name, size, pos, color))


func _npc_stub(name: String, pos: Vector3, sitting: bool, prompt: String, lines: PackedStringArray) -> StaticBody3D:
	var body := _make_interactable(name, pos, prompt, lines)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.42, 0.4)
	var torso := MeshInstance3D.new()
	torso.name = "Torso"
	var torso_mesh := CylinderMesh.new()
	if sitting:
		torso_mesh.height = 0.7
		torso.position = Vector3(0, 0.45, 0)
	else:
		torso_mesh.height = 1.1
		torso.position = Vector3(0, 0.9, 0)
	torso_mesh.top_radius = 0.2
	torso_mesh.bottom_radius = 0.22
	torso.mesh = torso_mesh
	torso.material_override = mat
	body.add_child(torso)
	var head := MeshInstance3D.new()
	head.name = "Head"
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.16
	head_mesh.height = 0.32
	head.mesh = head_mesh
	head.position = Vector3(0, 1.05 if sitting else 1.6, 0)
	head.material_override = mat
	body.add_child(head)
	var col := CollisionShape3D.new()
	col.name = "Collision"
	var shape := CapsuleShape3D.new()
	shape.radius = 0.28
	shape.height = 1.2 if sitting else 1.7
	col.shape = shape
	col.position = Vector3(0, 0.6 if sitting else 0.95, 0)
	body.add_child(col)
	return body


func _corpse_stub(name: String, pos: Vector3, prompt: String, lines: PackedStringArray) -> StaticBody3D:
	var body := _make_interactable(name, pos, prompt, lines)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.35, 0.32, 0.28)
	var torso := MeshInstance3D.new()
	torso.name = "Body"
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.22
	mesh.height = 1.5
	torso.mesh = mesh
	torso.rotation_degrees = Vector3(0, 0, 90)
	torso.position = Vector3(0, 0.22, 0)
	torso.material_override = mat
	body.add_child(torso)
	var col := CollisionShape3D.new()
	col.name = "Collision"
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.6, 0.4, 0.5)
	col.shape = shape
	col.position = Vector3(0, 0.2, 0)
	body.add_child(col)
	return body


func _save_alley() -> Error:
	var root := Node3D.new()
	root.name = "Alley"

	root.add_child(_underground_env(Color(0.06, 0.07, 0.07), Color(0.28, 0.32, 0.3)))

	var fill := OmniLight3D.new()
	fill.name = "Fill"
	fill.position = Vector3(0, 2.8, 0)
	fill.light_color = Color(0.75, 0.85, 0.8)
	fill.light_energy = 1.0
	fill.omni_range = 18.0
	root.add_child(fill)
	var fill2 := OmniLight3D.new()
	fill2.name = "FillWide"
	fill2.position = Vector3(4, 2.5, 0)
	fill2.light_color = Color(0.7, 0.8, 0.75)
	fill2.light_energy = 0.8
	fill2.omni_range = 14.0
	root.add_child(fill2)

	var stone := Color(0.32, 0.34, 0.33)
	var stone2 := Color(0.3, 0.33, 0.32)
	var floor_c := Color(0.22, 0.22, 0.2)
	var ceil_c := Color(0.16, 0.17, 0.16)
	var height := 4.5

	# Wide street along X (perpendicular). Width in Z ≈ 2.6; length ≈ 16.
	var wide_z0 := -1.3
	var wide_z1 := 1.3
	var wide_x0 := -8.0
	var wide_x1 := 8.0
	_slab(root, "WideFloor", Vector3(wide_x1 - wide_x0, 0.2, wide_z1 - wide_z0), Vector3(0, -0.1, 0), floor_c)
	_slab(root, "WideCeil", Vector3(wide_x1 - wide_x0, 0.2, wide_z1 - wide_z0), Vector3(0, height, 0), ceil_c)
	_slab(root, "WideWallSouth", Vector3(wide_x1 - wide_x0, height, 0.2), Vector3(0, height * 0.5, wide_z0), stone2)
	# north wall with gap for narrow alley mouth
	_slab(root, "WideWallNorthL", Vector3(7.35, height, 0.2), Vector3(-4.325, height * 0.5, wide_z1), stone2)
	_slab(root, "WideWallNorthR", Vector3(7.35, height, 0.2), Vector3(4.325, height * 0.5, wide_z1), stone2)
	_slab(root, "WideWallWest", Vector3(0.2, height, wide_z1 - wide_z0), Vector3(wide_x0, height * 0.5, 0), stone)

	# Narrow dead-end alley along +Z, ~2x longer
	var nar_x0 := -0.65
	var nar_x1 := 0.65
	var nar_z0 := wide_z1
	var nar_z1 := 13.5
	_slab(root, "NarFloor", Vector3(nar_x1 - nar_x0, 0.2, nar_z1 - nar_z0), Vector3(0, -0.1, (nar_z0 + nar_z1) * 0.5), floor_c)
	_slab(root, "NarCeil", Vector3(nar_x1 - nar_x0, 0.2, nar_z1 - nar_z0), Vector3(0, height, (nar_z0 + nar_z1) * 0.5), ceil_c)
	_slab(root, "NarWallL", Vector3(0.2, height, nar_z1 - nar_z0), Vector3(nar_x0, height * 0.5, (nar_z0 + nar_z1) * 0.5), stone)
	_slab(root, "NarWallR", Vector3(0.2, height, nar_z1 - nar_z0), Vector3(nar_x1, height * 0.5, (nar_z0 + nar_z1) * 0.5), stone)
	_slab(root, "NarDeadEnd", Vector3(1.5, height, 0.2), Vector3(0, height * 0.5, nar_z1), stone)

	root.add_child(_static_box("Barrel1", Vector3(0.45, 0.7, 0.45), Vector3(-0.15, 0.35, nar_z1 - 0.9), Color(0.4, 0.28, 0.18)))
	root.add_child(_static_box("Barrel2", Vector3(0.4, 0.6, 0.4), Vector3(0.2, 0.3, nar_z1 - 1.5), Color(0.38, 0.26, 0.16)))
	root.add_child(_static_box("Barrel3", Vector3(0.35, 0.55, 0.35), Vector3(-0.2, 0.28, nar_z1 - 2.0), Color(0.36, 0.25, 0.15)))

	root.add_child(_mushroom("Mush1", Vector3(nar_x0 + 0.12, 1.2, 4.0), 1.0))
	root.add_child(_mushroom("Mush2", Vector3(nar_x1 - 0.12, 1.8, 8.0), 1.2))
	root.add_child(_mushroom("Mush3", Vector3(nar_x0 + 0.12, 1.5, 11.0), 1.1))
	root.add_child(_mushroom("Mush4", Vector3(-3.0, 1.6, wide_z1 - 0.15), 1.3))
	root.add_child(_mushroom("Mush5", Vector3(3.5, 2.0, wide_z0 + 0.15), 1.4))

	# Ladder flush to LEFT wall — center free
	var up := _make_interactable(
		"LadderUp",
		Vector3(nar_x0 + 0.18, 0.0, 2.2),
		"[E] Подняться на чердак",
		PackedStringArray([
			"Ты снова хватаешься за холодные перекладины.",
			"Три этажа вверх — и снова сырой чердак."
		]),
		"res://scenes/attic.tscn"
	)
	var up_mesh := _box_mesh(Vector3(0.12, 2.5, 0.55), Color(0.3, 0.22, 0.15))
	up_mesh.position = Vector3(0, 1.25, 0)
	up.add_child(up_mesh)
	var ucol := CollisionShape3D.new()
	ucol.name = "Collision"
	var ushape := BoxShape3D.new()
	ushape.size = Vector3(0.25, 2.5, 0.7)
	ucol.shape = ushape
	ucol.position = Vector3(0, 1.25, 0)
	up.add_child(ucol)
	root.add_child(up)

	var npc_sit := _npc_stub(
		"NpcSitting",
		Vector3(-3.2, 0.0, -0.7),
		true,
		"[E] Посмотреть на деса",
		PackedStringArray([
			"Дес тяжело сидит на сырой земле. Тело уже заросло грибами.",
			"Он почти не двигается — медленно умирает."
		])
	)
	npc_sit.add_child(_mushroom("MushOnNpc", Vector3(0.15, 0.7, 0.1), 0.7))
	root.add_child(npc_sit)

	var npc_walk := _npc_stub(
		"NpcWalking",
		Vector3(2.4, 0.0, 0.5),
		false,
		"[E] Посмотреть на прохожего",
		PackedStringArray([
			"Ещё один дес — вяло и слабо идёт по своим делам.",
			"Взгляд пустой, шаг тяжёлый."
		])
	)
	root.add_child(npc_walk)

	var corpse := _corpse_stub(
		"CorpseFungal",
		Vector3(-5.5, 0.0, 0.6),
		"[E] Осмотреть труп",
		PackedStringArray([
			"Труп. Грибная проказа доела своё.",
			"От тела тянет сыростью и сладковатой гнилью.",
			"В Грибном районе к такому привыкают быстро."
		])
	)
	corpse.add_child(_mushroom("MushCorpse1", Vector3(0.3, 0.25, 0.0), 0.8))
	corpse.add_child(_mushroom("MushCorpse2", Vector3(-0.2, 0.2, 0.15), 0.6))
	root.add_child(corpse)

	# Work choice: warehouse OR library
	var to_wh := _make_interactable(
		"GoWarehouse",
		Vector3(7.3, 0.0, -0.7),
		"[E] На склад / верфи",
		PackedStringArray([
			"Ты бредешь к верфям за стенами города — путь на двадцать-тридцать минут.",
			"Впереди порт, пирсы и ор Тон Тона."
		]),
		"res://scenes/warehouse.tscn"
	)
	var wh_gate := _box_mesh(Vector3(0.25, 2.4, 1.1), Color(0.25, 0.28, 0.26))
	wh_gate.position = Vector3(0, 1.2, 0)
	to_wh.add_child(wh_gate)
	var whcol := CollisionShape3D.new()
	whcol.name = "Collision"
	var whshape := BoxShape3D.new()
	whshape.size = Vector3(0.5, 2.4, 1.3)
	whcol.shape = whshape
	whcol.position = Vector3(0, 1.2, 0)
	to_wh.add_child(whcol)
	root.add_child(to_wh)

	var to_lib := _make_interactable(
		"GoLibrary",
		Vector3(7.3, 0.0, 0.7),
		"[E] В Конгрегационную библиотеку",
		PackedStringArray([
			"Из закоулков ты сразу заходишь в Конгрегационную библиотеку.",
			"Платят лучше. Минус один: безумный Раф Лат Телий."
		]),
		"res://scenes/library.tscn"
	)
	var lib_gate := _box_mesh(Vector3(0.25, 2.4, 1.1), Color(0.28, 0.26, 0.32))
	lib_gate.position = Vector3(0, 1.2, 0)
	to_lib.add_child(lib_gate)
	var lcol := CollisionShape3D.new()
	lcol.name = "Collision"
	var lshape := BoxShape3D.new()
	lshape.size = Vector3(0.5, 2.4, 1.3)
	lcol.shape = lshape
	lcol.position = Vector3(0, 1.2, 0)
	to_lib.add_child(lcol)
	root.add_child(to_lib)

	_add_player(root, Vector3(0.15, 0.9, 2.8))

	_mark_owners(root, root)
	var packed := PackedScene.new()
	var pack_err := packed.pack(root)
	if pack_err != OK:
		return pack_err
	return ResourceSaver.save(packed, "res://scenes/alley.tscn")



func _barrier(root: Node, name: String, size: Vector3, pos: Vector3) -> void:
	# soft player-block: crates/junk wall
	var body := _static_box(name, size, pos, Color(0.38, 0.28, 0.18))
	root.add_child(body)


func _cargo_ship(root: Node, name: String, pos: Vector3, yaw_deg: float = 0.0) -> void:
	var ship := Node3D.new()
	ship.name = name
	ship.position = pos
	ship.rotation_degrees = Vector3(0, yaw_deg, 0)
	var hull := _box_mesh(Vector3(10, 2.2, 3.2), Color(0.25, 0.28, 0.3))
	hull.position = Vector3(0, 1.0, 0)
	ship.add_child(hull)
	var bridge := _box_mesh(Vector3(2.5, 1.6, 2.4), Color(0.3, 0.32, 0.35))
	bridge.position = Vector3(-2.5, 2.6, 0)
	ship.add_child(bridge)
	var stack := _box_mesh(Vector3(1.2, 2.0, 1.2), Color(0.2, 0.2, 0.22))
	stack.position = Vector3(1.5, 2.8, 0)
	ship.add_child(stack)
	root.add_child(ship)


func _add_vastersa_silhouette(root: Node, pos: Vector3, scale: float = 1.0) -> void:
	# Megastructure: hundreds of floors feel via enormous massing.
	var stone := Color(0.32, 0.35, 0.4)
	var dark := Color(0.18, 0.2, 0.24)
	var water_blue := Color(0.18, 0.32, 0.48)
	var lake := MeshInstance3D.new()
	lake.name = "Lake"
	var lake_mesh := CylinderMesh.new()
	lake_mesh.top_radius = 220.0 * scale
	lake_mesh.bottom_radius = 220.0 * scale
	lake_mesh.height = 1.0
	lake.mesh = lake_mesh
	var lake_mat := StandardMaterial3D.new()
	lake_mat.albedo_color = water_blue
	lake.material_override = lake_mat
	lake.position = pos + Vector3(0, -0.4, 0)
	root.add_child(lake)
	# base cylinder ~25%
	root.add_child(_static_box("CityBase", Vector3(140 * scale, 70 * scale, 140 * scale), pos + Vector3(0, 35 * scale, 0), stone))
	# waist narrow
	root.add_child(_static_box("CityWaist", Vector3(55 * scale, 50 * scale, 55 * scale), pos + Vector3(0, 95 * scale, 0), dark))
	# upper flare
	root.add_child(_static_box("CityUpper", Vector3(110 * scale, 120 * scale, 110 * scale), pos + Vector3(0, 180 * scale, 0), stone))
	# shaft + dome + diamond
	root.add_child(_static_box("CitySpire", Vector3(45 * scale, 100 * scale, 45 * scale), pos + Vector3(0, 290 * scale, 0), dark))
	var dome := MeshInstance3D.new()
	dome.name = "CityDome"
	var dome_mesh := SphereMesh.new()
	dome_mesh.radius = 28.0 * scale
	dome_mesh.height = 36.0 * scale
	dome.mesh = dome_mesh
	var dome_mat := StandardMaterial3D.new()
	dome_mat.albedo_color = Color(0.4, 0.45, 0.52)
	dome.material_override = dome_mat
	dome.position = pos + Vector3(0, 360 * scale, 0)
	root.add_child(dome)
	var diamond := MeshInstance3D.new()
	diamond.name = "CityDiamond"
	var dmesh := BoxMesh.new()
	dmesh.size = Vector3(16 * scale, 16 * scale, 2 * scale)
	diamond.mesh = dmesh
	var dmat := StandardMaterial3D.new()
	dmat.albedo_color = Color(0.8, 0.6, 0.25)
	diamond.material_override = dmat
	diamond.rotation_degrees = Vector3(0, 0, 45)
	diamond.position = pos + Vector3(0, 385 * scale, 0)
	root.add_child(diamond)
	# two-lane canal-bridges (in/out) with cargo ships
	root.add_child(_static_box("CanalDeckA", Vector3(320 * scale, 3 * scale, 28 * scale), pos + Vector3(180 * scale, 38 * scale, 0), Color(0.28, 0.3, 0.34)))
	root.add_child(_static_box("CanalDividerA", Vector3(300 * scale, 1.2 * scale, 2 * scale), pos + Vector3(180 * scale, 40 * scale, 0), Color(0.2, 0.22, 0.25)))
	root.add_child(_static_box("CanalDeckB", Vector3(28 * scale, 3 * scale, 320 * scale), pos + Vector3(0, 38 * scale, 180 * scale), Color(0.28, 0.3, 0.34)))
	root.add_child(_static_box("CanalDividerB", Vector3(2 * scale, 1.2 * scale, 300 * scale), pos + Vector3(0, 40 * scale, 180 * scale), Color(0.2, 0.22, 0.25)))
	_cargo_ship(root, "ShipInA", pos + Vector3(120 * scale, 41 * scale, -8 * scale), 0)
	_cargo_ship(root, "ShipOutA", pos + Vector3(200 * scale, 41 * scale, 8 * scale), 180)
	_cargo_ship(root, "ShipInB", pos + Vector3(-8 * scale, 41 * scale, 140 * scale), 90)
	_cargo_ship(root, "ShipOutB", pos + Vector3(8 * scale, 41 * scale, 210 * scale), -90)
	# distant fog towers along bridge direction
	root.add_child(_static_box("FogTower1", Vector3(20 * scale, 80 * scale, 20 * scale), pos + Vector3(300 * scale, 50 * scale, 0), Color(0.25, 0.28, 0.32)))
	root.add_child(_static_box("FogTower2", Vector3(16 * scale, 60 * scale, 16 * scale), pos + Vector3(340 * scale, 40 * scale, 30 * scale), Color(0.22, 0.25, 0.3)))



func _save_warehouse() -> Error:
	var root := Node3D.new()
	root.name = "Warehouse"

	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.42, 0.5, 0.58)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.68, 0.72)
	env.ambient_light_energy = 0.95
	env.fog_enabled = true
	env.fog_light_color = Color(0.6, 0.68, 0.74)
	env.fog_density = 0.01
	world_env.environment = env
	root.add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-28, 150, 0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	root.add_child(sun)

	var wood := Color(0.4, 0.3, 0.2)
	var metal := Color(0.3, 0.33, 0.36)
	var plank := Color(0.35, 0.32, 0.28)
	var stone := Color(0.38, 0.4, 0.42)

	# Mainland plateau; canal closer to view, warehouse set BACK for beauty shot
	root.add_child(_static_box("Yard", Vector3(90, 0.25, 70), Vector3(10, -0.1, 10), Color(0.27, 0.27, 0.25)))
	var water := MeshInstance3D.new()
	water.name = "HarborWater"
	var wmesh := BoxMesh.new()
	wmesh.size = Vector3(200, 0.2, 140)
	water.mesh = wmesh
	var wmat := StandardMaterial3D.new()
	wmat.albedo_color = Color(0.14, 0.3, 0.46)
	water.material_override = wmat
	water.position = Vector3(0, -0.25, -70)
	root.add_child(water)

	# Canal deck in front of view (ships clearly visible)
	root.add_child(_static_box("CanalDeck", Vector3(120, 2.5, 22), Vector3(0, 6, -35), Color(0.3, 0.33, 0.36)))
	root.add_child(_static_box("CanalDivider", Vector3(110, 1.0, 1.5), Vector3(0, 7.6, -35), Color(0.2, 0.22, 0.25)))
	_cargo_ship(root, "CanalShipIn", Vector3(-25, 8.2, -39), 0)
	_cargo_ship(root, "CanalShipOut", Vector3(30, 8.2, -31), 180)
	_cargo_ship(root, "CanalShipMid", Vector3(5, 8.2, -35), 0)

	# Megacity + distant central gates
	_add_vastersa_silhouette(root, Vector3(0, 0, -260), 1.35)
	root.add_child(_static_box("CentralGates", Vector3(40, 28, 8), Vector3(0, 20, -175), Color(0.25, 0.28, 0.32)))
	root.add_child(_static_box("GateArch", Vector3(18, 22, 6), Vector3(0, 18, -172), Color(0.2, 0.22, 0.26)))

	# Nearby district tower (as on ref near warehouse)
	root.add_child(_static_box("NearTower", Vector3(10, 55, 10), Vector3(-28, 27.5, 8), stone))
	root.add_child(_static_box("NearTowerTop", Vector3(6, 12, 6), Vector3(-28, 60, 8), Color(0.3, 0.32, 0.36)))

	# Piers closer to canal
	root.add_child(_static_box("Pier1", Vector3(7, 0.4, 22), Vector3(-16, 0.1, -12), plank))
	root.add_child(_static_box("Pier2", Vector3(7, 0.4, 22), Vector3(-6, 0.1, -12), plank))
	_cargo_ship(root, "DockShip1", Vector3(-16, 0.2, -20), 90)

	# Warehouse FURTHER from canal (beauty: canal+ships in frame)
	var wh := Vector3(28, 0, 22)
	root.add_child(_static_box("WH_Floor", Vector3(22, 0.2, 18), wh + Vector3(0, 0, 0), plank))
	root.add_child(_static_box("WH_WallBack", Vector3(22, 10, 0.3), wh + Vector3(0, 5, 9), metal))
	root.add_child(_static_box("WH_WallL", Vector3(0.3, 10, 18), wh + Vector3(-11, 5, 0), metal))
	root.add_child(_static_box("WH_WallR", Vector3(0.3, 10, 18), wh + Vector3(11, 5, 0), metal))
	root.add_child(_static_box("WH_FrontL", Vector3(8, 10, 0.3), wh + Vector3(-7, 5, -9), metal))
	root.add_child(_static_box("WH_FrontR", Vector3(8, 10, 0.3), wh + Vector3(7, 5, -9), metal))
	root.add_child(_static_box("WH_FrontTop", Vector3(6, 4, 0.3), wh + Vector3(0, 8, -9), metal))
	root.add_child(_static_box("WH_Roof", Vector3(22.5, 0.3, 18.5), wh + Vector3(0, 10.1, 0), Color(0.25, 0.27, 0.3)))
	root.add_child(_static_box("WH_Mezz", Vector3(20, 0.25, 8), wh + Vector3(0, 4.5, 3.5), wood))
	root.add_child(_static_box("WH_Rail", Vector3(20, 0.7, 0.15), wh + Vector3(0, 5.0, -0.4), Color(0.45, 0.35, 0.25)))
	for i in range(11):
		root.add_child(_static_box("Stair_%d" % i, Vector3(2.4, 0.2, 0.55), wh + Vector3(-8.0, 0.2 + i * 0.4, -6.0 + i * 0.45), wood))
	for x in [-6.0, 0.0, 6.0]:
		root.add_child(_static_box("Pillar_%s" % str(x), Vector3(0.5, 4.5, 0.5), wh + Vector3(x, 2.25, 3.5), wood))
	root.add_child(_static_box("CrateA", Vector3(1.2, 1.0, 1.2), wh + Vector3(-3, 0.5, -2), wood))
	root.add_child(_static_box("CrateStack", Vector3(1.3, 2.4, 1.3), wh + Vector3(6, 1.2, 4), wood))

	# port clutter near canal for silhouette
	for i in range(10):
		root.add_child(_static_box("PortCrate_%d" % i, Vector3(1.1, 0.9 + (i % 3) * 0.35, 1.1), Vector3(-22 + i * 2.0, 0.55, 0 + (i % 2)), wood))
	root.add_child(_static_box("CraneBase", Vector3(2.2, 10, 2.2), Vector3(-22, 5, -8), metal))
	root.add_child(_static_box("CraneArm", Vector3(16, 1.1, 1.3), Vector3(-14, 10, -8), metal))

	# Soft barriers
	_barrier(root, "BlockNorth", Vector3(100, 4, 2), Vector3(10, 2, 42))
	_barrier(root, "BlockEast", Vector3(2, 4, 80), Vector3(52, 2, 5))
	_barrier(root, "BlockWest", Vector3(2, 4, 80), Vector3(-40, 2, 5))
	_barrier(root, "CrateGateL", Vector3(10, 3.2, 3), Vector3(-8, 1.6, 30))
	_barrier(root, "CrateGateR", Vector3(10, 3.2, 3), Vector3(28, 1.6, 30))

	var haul := _make_interactable(
		"HaulCrate",
		wh + Vector3(-1.0, 0.0, -4.0),
		"[E] Таскать ящики",
		PackedStringArray([
			"Ты хватаешь ящик. Спина уже ноет — день только начался.",
			"(Полной механики переноски пока нет — заглушка работы.)"
		])
	)
	var haul_mesh := _box_mesh(Vector3(1.1, 0.9, 1.1), Color(0.42, 0.3, 0.18))
	haul_mesh.position = Vector3(0, 0.45, 0)
	haul.add_child(haul_mesh)
	var hcol := CollisionShape3D.new()
	hcol.name = "Collision"
	var hshape := BoxShape3D.new()
	hshape.size = Vector3(1.2, 1.0, 1.2)
	hcol.shape = hshape
	hcol.position = Vector3(0, 0.5, 0)
	haul.add_child(hcol)
	root.add_child(haul)

	var ton := _npc_stub(
		"TonTon",
		wh + Vector3(2.5, 0.0, -7.0),
		false,
		"[E] Рубин Тон Тон",
		PackedStringArray([
			"Не успев переступить порог, вопящий голос прораба кувалдой выбивает мысли.",
			"«Ты опять опоздал, грибная крыса! Ящики — живо!»",
			"Лавина матов и обвинений. Остаётся только бежать таскать груз."
		])
	)
	root.add_child(ton)

	var vista := _make_interactable(
		"LookAtCanal",
		Vector3(0.0, 0.0, -8.0),
		"[E] Смотреть на канал и город",
		PackedStringArray([
			"Склад стоит чуть в стороне — канал и грузовые видны целиком.",
			"Две полосы: корабли в город и из города. Вдали — ворота и мегаструктура Вастерсы.",
			"Рядом торчит районная башня. Мостки уходят в туман."
		])
	)
	var post := _box_mesh(Vector3(0.3, 1.7, 0.3), Color(0.35, 0.3, 0.25))
	post.position = Vector3(0, 0.85, 0)
	vista.add_child(post)
	var vcol := CollisionShape3D.new()
	vcol.name = "Collision"
	var vshape := BoxShape3D.new()
	vshape.size = Vector3(0.7, 1.8, 0.7)
	vcol.shape = vshape
	vcol.position = Vector3(0, 0.9, 0)
	vista.add_child(vcol)
	root.add_child(vista)

	var back := _make_interactable(
		"BackToAlley",
		Vector3(10.0, 0.0, 32.0),
		"[E] Вернуться в Грибной район",
		PackedStringArray(["Узкий проход между штабелями ящиков — единственная дорога назад."]),
		"res://scenes/alley.tscn"
	)
	var bmesh := _box_mesh(Vector3(2.4, 2.2, 0.4), Color(0.3, 0.28, 0.25))
	bmesh.position = Vector3(0, 1.1, 0)
	back.add_child(bmesh)
	var bcol := CollisionShape3D.new()
	bcol.name = "Collision"
	var bshape := BoxShape3D.new()
	bshape.size = Vector3(2.6, 2.2, 0.6)
	bcol.shape = bshape
	bcol.position = Vector3(0, 1.1, 0)
	back.add_child(bcol)
	root.add_child(back)

	# spawn between canal view and warehouse approach
	_add_player(root, Vector3(8, 0.9, 6))

	_mark_owners(root, root)
	var packed := PackedScene.new()
	var pack_err := packed.pack(root)
	if pack_err != OK:
		return pack_err
	return ResourceSaver.save(packed, "res://scenes/warehouse.tscn")


func _save_library() -> Error:
	var root := Node3D.new()
	root.name = "Library"

	var world_env := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.14, 0.13, 0.12)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.4, 0.36, 0.32)
	env.ambient_light_energy = 0.75
	world_env.environment = env
	root.add_child(world_env)
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0, 5.5, 0)
	lamp.light_color = Color(1.0, 0.85, 0.6)
	lamp.light_energy = 1.2
	lamp.omni_range = 22
	root.add_child(lamp)

	var wood := Color(0.36, 0.26, 0.16)
	var plaster := Color(0.48, 0.45, 0.4)
	# spacious hall inside cylinder district
	root.add_child(_static_box("Floor", Vector3(28, 0.2, 32), Vector3(0, -0.1, 0), Color(0.3, 0.26, 0.22)))
	root.add_child(_static_box("Ceil", Vector3(28, 0.25, 32), Vector3(0, 9.0, 0), Color(0.22, 0.2, 0.18)))
	root.add_child(_static_box("WallB", Vector3(28, 9, 0.35), Vector3(0, 4.5, -16), plaster))
	root.add_child(_static_box("WallF", Vector3(28, 9, 0.35), Vector3(0, 4.5, 16), plaster))
	root.add_child(_static_box("WallL", Vector3(0.35, 9, 32), Vector3(-14, 4.5, 0), plaster))
	root.add_child(_static_box("WallR", Vector3(0.35, 9, 32), Vector3(14, 4.5, 0), plaster))
	# canals overhead inside/through volume
	root.add_child(_static_box("CanalOver1", Vector3(30, 1.5, 5), Vector3(0, 7.2, -4), Color(0.28, 0.32, 0.36)))
	root.add_child(_static_box("CanalOver2", Vector3(30, 1.5, 5), Vector3(0, 7.2, 6), Color(0.28, 0.32, 0.36)))
	for z in [-8.0, -2.0, 4.0, 10.0]:
		root.add_child(_static_box("ShelfL_%s" % str(z), Vector3(4, 4.0, 0.7), Vector3(-9, 2.0, z), wood))
		root.add_child(_static_box("ShelfR_%s" % str(z), Vector3(4, 4.0, 0.7), Vector3(9, 2.0, z), wood))

	var dep := _make_interactable(
		"Dept5",
		Vector3(0, 0, 10),
		"[E] 5 отдел",
		PackedStringArray([
			"Самый большой отдел — налоговые отчёты и бюрократия.",
			"Сухие бумаги. Хорошее место… для искры."
		])
	)
	var dep_m := _box_mesh(Vector3(5, 3.0, 1.4), wood)
	dep_m.position = Vector3(0, 1.5, 0)
	dep.add_child(dep_m)
	var dep_c := CollisionShape3D.new()
	dep_c.name = "Collision"
	var dep_s := BoxShape3D.new()
	dep_s.size = Vector3(5.2, 3.1, 1.6)
	dep_c.shape = dep_s
	dep_c.position = Vector3(0, 1.55, 0)
	dep.add_child(dep_c)
	root.add_child(dep)

	var raf := _npc_stub(
		"Raf",
		Vector3(-3.0, 0, -10),
		true,
		"[E] Раф Лат Телий",
		PackedStringArray([
			"Запах протухшего мяса. Безумный Раф завтракает среди книг.",
			"«Лафей, это ты? Иди сюда!»",
			"Костлявыми пальцами он ест бобы и ими же листает страницы."
		])
	)
	root.add_child(raf)

	# Fire beat → run outside to crowded street
	var fire := _make_interactable(
		"FireEscape",
		Vector3(0, 0, 12.5),
		"[E] Пожар — бежать на улицу",
		PackedStringArray([
			"Дым заполняет 5 отдел. Пора уходить.",
			"Ты выбегаешь наружу — на просторную улицу цилиндра."
		]),
		"res://scenes/library_street.tscn"
	)
	var fm := _box_mesh(Vector3(2.0, 2.4, 0.4), Color(0.5, 0.2, 0.12))
	fm.position = Vector3(0, 1.2, 0)
	fire.add_child(fm)
	var fc := CollisionShape3D.new()
	fc.name = "Collision"
	var fs := BoxShape3D.new()
	fs.size = Vector3(2.2, 2.4, 0.6)
	fc.shape = fs
	fc.position = Vector3(0, 1.2, 0)
	fire.add_child(fc)
	root.add_child(fire)

	_barrier(root, "LibBlock1", Vector3(2.5, 3.5, 5), Vector3(-13, 1.75, 0))
	_barrier(root, "LibBlock2", Vector3(2.5, 3.5, 5), Vector3(13, 1.75, 0))

	_add_player(root, Vector3(0, 0.9, -12))
	_mark_owners(root, root)
	var packed := PackedScene.new()
	var err := packed.pack(root)
	if err != OK:
		return err
	return ResourceSaver.save(packed, "res://scenes/library.tscn")


func _save_library_street() -> Error:
	# Post-fire street: spacious fantasy avenue under canals, crowd blocks road
	var root := Node3D.new()
	root.name = "LibraryStreet"

	var world_env := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.28, 0.3, 0.34)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.52, 0.55)
	env.ambient_light_energy = 0.9
	env.fog_enabled = true
	env.fog_light_color = Color(0.55, 0.5, 0.45)
	env.fog_density = 0.012
	world_env.environment = env
	root.add_child(world_env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 30, 0)
	sun.light_energy = 0.9
	root.add_child(sun)
	var fire_light := OmniLight3D.new()
	fire_light.position = Vector3(0, 3, -14)
	fire_light.light_color = Color(1.0, 0.45, 0.15)
	fire_light.light_energy = 2.0
	fire_light.omni_range = 18
	root.add_child(fire_light)

	var stone := Color(0.42, 0.44, 0.46)
	var wood := Color(0.4, 0.3, 0.2)
	# wide street
	root.add_child(_static_box("Avenue", Vector3(18, 0.2, 48), Vector3(0, -0.1, 0), Color(0.34, 0.34, 0.36)))
	# building facades / shops / taverns
	for z in [-16.0, -6.0, 4.0, 14.0]:
		root.add_child(_static_box("ShopL_%s" % str(z), Vector3(6, 7, 8), Vector3(-12, 3.5, z), stone))
		root.add_child(_static_box("ShopR_%s" % str(z), Vector3(6, 7, 8), Vector3(12, 3.5, z), stone))
		root.add_child(_static_box("SignL_%s" % str(z), Vector3(2.5, 0.4, 0.2), Vector3(-8.7, 4.2, z), wood))
		root.add_child(_static_box("SignR_%s" % str(z), Vector3(2.5, 0.4, 0.2), Vector3(8.7, 4.2, z), wood))
	# tavern emphasis
	root.add_child(_static_box("Tavern", Vector3(7, 8, 10), Vector3(-12.5, 4, 0), Color(0.36, 0.28, 0.22)))
	var tavern_sign := _make_interactable(
		"TavernSign",
		Vector3(-8.5, 0, 0),
		"[E] Таверна",
		PackedStringArray(["Вывеска таверны. Сейчас всем не до выпивки — смотрят на пожар."])
	)
	var ts := _box_mesh(Vector3(0.3, 2.2, 1.2), wood)
	ts.position = Vector3(0, 1.1, 0)
	tavern_sign.add_child(ts)
	var tc := CollisionShape3D.new()
	tc.name = "Collision"
	var tshape := BoxShape3D.new()
	tshape.size = Vector3(0.5, 2.2, 1.4)
	tc.shape = tshape
	tc.position = Vector3(0, 1.1, 0)
	tavern_sign.add_child(tc)
	root.add_child(tavern_sign)

	# canals overhead
	root.add_child(_static_box("SkyCanal1", Vector3(40, 2, 6), Vector3(0, 10, -8), Color(0.3, 0.34, 0.38)))
	root.add_child(_static_box("SkyCanal2", Vector3(40, 2, 6), Vector3(0, 11, 10), Color(0.3, 0.34, 0.38)))

	# library facade behind (on fire)
	root.add_child(_static_box("LibFacade", Vector3(14, 10, 3), Vector3(0, 5, -22), Color(0.35, 0.3, 0.28)))
	var smoke := _make_interactable(
		"WatchFire",
		Vector3(0, 0, -18),
		"[E] Смотреть на пожар",
		PackedStringArray([
			"Из окон библиотеки валит дым.",
			"Толпа заполнила улицу и не пускает дальше — все смотрят на огонь."
		])
	)
	var sm := _box_mesh(Vector3(1, 2, 1), Color(0.2, 0.2, 0.2))
	sm.position = Vector3(0, 1, 0)
	smoke.add_child(sm)
	var sc := CollisionShape3D.new()
	sc.name = "Collision"
	var ss := BoxShape3D.new()
	ss.size = Vector3(1.2, 2, 1.2)
	sc.shape = ss
	sc.position = Vector3(0, 1, 0)
	smoke.add_child(sc)
	root.add_child(smoke)

	# crowd wall blocking street
	for i in range(9):
		var crowd := _npc_stub(
			"Crowd_%d" % i,
			Vector3(-6 + i * 1.5, 0, -12),
			false if i % 2 == 0 else true,
			"[E] Толпа",
			PackedStringArray(["Люди запрудили улицу. Все смотрят на пожар. Прохода нет."])
		)
		root.add_child(crowd)
	_barrier(root, "CrowdBlock", Vector3(16, 2.5, 2.5), Vector3(0, 1.25, -11))
	_barrier(root, "SideBlockL", Vector3(3, 3, 20), Vector3(-16, 1.5, 0))
	_barrier(root, "SideBlockR", Vector3(3, 3, 20), Vector3(16, 1.5, 0))
	_barrier(root, "FarBlock", Vector3(18, 3, 2), Vector3(0, 1.5, 22))

	var back := _make_interactable(
		"BackToAlleyFromFire",
		Vector3(0, 0, 18),
		"[E] Уйти в переулки",
		PackedStringArray(["Пока конгрегаты тушат огонь, ты можешь исчезнуть в знакомых щелях."]),
		"res://scenes/alley.tscn"
	)
	var bm := _box_mesh(Vector3(2.2, 2.2, 0.4), Color(0.3, 0.28, 0.25))
	bm.position = Vector3(0, 1.1, 0)
	back.add_child(bm)
	var bc := CollisionShape3D.new()
	bc.name = "Collision"
	var bs := BoxShape3D.new()
	bs.size = Vector3(2.4, 2.2, 0.6)
	bc.shape = bs
	bc.position = Vector3(0, 1.1, 0)
	back.add_child(bc)
	root.add_child(back)

	_add_player(root, Vector3(0, 0.9, -8))
	_mark_owners(root, root)
	var packed := PackedScene.new()
	var err := packed.pack(root)
	if err != OK:
		return err
	return ResourceSaver.save(packed, "res://scenes/library_street.tscn")
