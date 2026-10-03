extends SceneTree

# One-shot:
# godot4 --path . --headless -s res://scripts/build_scenes.gd


func _init() -> void:
	DirAccess.make_dir_recursive_absolute("res://scenes")
	var e1 := _save_attic()
	var e2 := _save_alley()
	var e3 := _save_warehouse()
	if e1 != OK or e2 != OK or e3 != OK:
		push_error("BUILD_FAIL attic=%s alley=%s warehouse=%s" % [e1, e2, e3])
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

	var work := _make_interactable(
		"ExitToWork",
		Vector3(7.3, 0.0, 0.0),
		"[E] Идти на работу",
		PackedStringArray([
			"Ты медленно волочишь ноги по прохладным переулкам Грибного района.",
			"Спустя несколько десятков минут ты доходишь до верфей за пределами города."
		]),
		"res://scenes/warehouse.tscn"
	)
	var gate := _box_mesh(Vector3(0.25, 2.4, 2.2), Color(0.25, 0.28, 0.26))
	gate.position = Vector3(0, 1.2, 0)
	work.add_child(gate)
	var gcol := CollisionShape3D.new()
	gcol.name = "Collision"
	var gshape := BoxShape3D.new()
	gshape.size = Vector3(0.5, 2.4, 2.4)
	gcol.shape = gshape
	gcol.position = Vector3(0, 1.2, 0)
	work.add_child(gcol)
	root.add_child(work)

	_add_player(root, Vector3(0.15, 0.9, 2.8))

	_mark_owners(root, root)
	var packed := PackedScene.new()
	var pack_err := packed.pack(root)
	if pack_err != OK:
		return pack_err
	return ResourceSaver.save(packed, "res://scenes/alley.tscn")


func _add_vastersa_silhouette(root: Node, pos: Vector3, scale: float = 1.0) -> void:
	var stone := Color(0.35, 0.38, 0.42)
	var dark := Color(0.22, 0.24, 0.28)
	var water_blue := Color(0.25, 0.4, 0.55)
	# lake disc
	var lake := MeshInstance3D.new()
	lake.name = "Lake"
	var lake_mesh := CylinderMesh.new()
	lake_mesh.top_radius = 55.0 * scale
	lake_mesh.bottom_radius = 55.0 * scale
	lake_mesh.height = 0.4
	lake.mesh = lake_mesh
	var lake_mat := StandardMaterial3D.new()
	lake_mat.albedo_color = water_blue
	lake.material_override = lake_mat
	lake.position = pos + Vector3(0, -0.2, 0)
	root.add_child(lake)
	# base cylinder ~25% of tower height feel
	var base := _static_box("CityBase", Vector3(28 * scale, 10 * scale, 28 * scale), pos + Vector3(0, 5 * scale, 0), stone)
	root.add_child(base)
	# narrowing mid (inverted cone approximated by stacked boxes)
	root.add_child(_static_box("CityWaist", Vector3(10 * scale, 8 * scale, 10 * scale), pos + Vector3(0, 14 * scale, 0), dark))
	# upper widening cylinder
	root.add_child(_static_box("CityUpper", Vector3(18 * scale, 16 * scale, 18 * scale), pos + Vector3(0, 26 * scale, 0), stone))
	# top tower shaft
	root.add_child(_static_box("CitySpire", Vector3(8 * scale, 14 * scale, 8 * scale), pos + Vector3(0, 41 * scale, 0), dark))
	# dome + diamond symbol
	var dome := MeshInstance3D.new()
	dome.name = "CityDome"
	var dome_mesh := SphereMesh.new()
	dome_mesh.radius = 5.0 * scale
	dome_mesh.height = 7.0 * scale
	dome.mesh = dome_mesh
	var dome_mat := StandardMaterial3D.new()
	dome_mat.albedo_color = Color(0.45, 0.48, 0.55)
	dome.material_override = dome_mat
	dome.position = pos + Vector3(0, 50 * scale, 0)
	root.add_child(dome)
	var diamond := MeshInstance3D.new()
	diamond.name = "CityDiamond"
	var dmesh := BoxMesh.new()
	dmesh.size = Vector3(3 * scale, 3 * scale, 0.4 * scale)
	diamond.mesh = dmesh
	var dmat := StandardMaterial3D.new()
	dmat.albedo_color = Color(0.75, 0.55, 0.25)
	diamond.material_override = dmat
	diamond.rotation_degrees = Vector3(0, 0, 45)
	diamond.position = pos + Vector3(0, 55 * scale, 0)
	root.add_child(diamond)
	# thin bridges outward
	root.add_child(_static_box("BridgeA", Vector3(70 * scale, 1.2 * scale, 3 * scale), pos + Vector3(40 * scale, 6 * scale, 0), Color(0.3, 0.32, 0.35)))
	root.add_child(_static_box("BridgeB", Vector3(3 * scale, 1.2 * scale, 70 * scale), pos + Vector3(0, 6 * scale, 40 * scale), Color(0.3, 0.32, 0.35)))


func _save_warehouse() -> Error:
	var root := Node3D.new()
	root.name = "Warehouse"

	# open air at docks — cooler, less foggy underground feel
	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.35, 0.42, 0.48)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.6, 0.65)
	env.ambient_light_energy = 0.85
	env.fog_enabled = true
	env.fog_light_color = Color(0.45, 0.55, 0.6)
	env.fog_density = 0.008
	world_env.environment = env
	root.add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-35, 120, 0)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	root.add_child(sun)

	var wood := Color(0.4, 0.3, 0.2)
	var plank := Color(0.35, 0.32, 0.28)
	var metal := Color(0.3, 0.33, 0.36)

	# dock yard ground
	root.add_child(_static_box("Yard", Vector3(40, 0.2, 28), Vector3(0, -0.1, 0), Color(0.28, 0.28, 0.26)))
	# water near edge
	var water := MeshInstance3D.new()
	water.name = "DockWater"
	var wmesh := BoxMesh.new()
	wmesh.size = Vector3(40, 0.15, 18)
	water.mesh = wmesh
	var wmat := StandardMaterial3D.new()
	wmat.albedo_color = Color(0.2, 0.35, 0.5)
	water.material_override = wmat
	water.position = Vector3(0, -0.05, -20)
	root.add_child(water)

	# city far across water
	_add_vastersa_silhouette(root, Vector3(0, 0, -70), 1.0)

	# two-tier warehouse building (+Z side)
	var wh_z := 8.0
	# outer shell
	root.add_child(_static_box("WH_Floor", Vector3(18, 0.2, 14), Vector3(0, -0.05, wh_z), plank))
	root.add_child(_static_box("WH_WallBack", Vector3(18, 8, 0.3), Vector3(0, 4, wh_z + 7), metal))
	root.add_child(_static_box("WH_WallL", Vector3(0.3, 8, 14), Vector3(-9, 4, wh_z), metal))
	root.add_child(_static_box("WH_WallR", Vector3(0.3, 8, 14), Vector3(9, 4, wh_z), metal))
	# front wall with door gap
	root.add_child(_static_box("WH_FrontL", Vector3(6.5, 8, 0.3), Vector3(-5.75, 4, wh_z - 7), metal))
	root.add_child(_static_box("WH_FrontR", Vector3(6.5, 8, 0.3), Vector3(5.75, 4, wh_z - 7), metal))
	root.add_child(_static_box("WH_FrontTop", Vector3(5, 3, 0.3), Vector3(0, 6.5, wh_z - 7), metal))
	root.add_child(_static_box("WH_Roof", Vector3(18.5, 0.3, 14.5), Vector3(0, 8.1, wh_z), Color(0.25, 0.27, 0.3)))

	# second tier / mezzanine
	root.add_child(_static_box("WH_Mezz", Vector3(16, 0.25, 6), Vector3(0, 4.0, wh_z + 2.5), wood))
	root.add_child(_static_box("WH_Rail", Vector3(16, 0.8, 0.15), Vector3(0, 4.6, wh_z - 0.5), Color(0.45, 0.35, 0.25)))
	# support pillars
	for x in [-6.0, 0.0, 6.0]:
		root.add_child(_static_box("Pillar_%s" % str(x), Vector3(0.4, 4, 0.4), Vector3(x, 2, wh_z + 2.5), wood))

	# crates
	root.add_child(_static_box("CrateA", Vector3(1.2, 1.0, 1.2), Vector3(-4, 0.5, wh_z - 2), wood))
	root.add_child(_static_box("CrateB", Vector3(1.0, 0.8, 1.0), Vector3(-2.5, 0.4, wh_z - 1), wood))
	root.add_child(_static_box("CrateC", Vector3(1.4, 1.2, 1.0), Vector3(3.5, 0.6, wh_z + 1), wood))
	root.add_child(_static_box("CrateStack", Vector3(1.2, 2.0, 1.2), Vector3(5, 1.0, wh_z + 3), wood))

	# work crate interactable
	var haul := _make_interactable(
		"HaulCrate",
		Vector3(-1.0, 0.0, wh_z - 3.0),
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

	# Ton Ton — yell on interact / threshold feel
	var ton := _npc_stub(
		"TonTon",
		Vector3(2.0, 0.0, wh_z - 5.5),
		false,
		"[E] Рубин Тон Тон",
		PackedStringArray([
			"Не успев переступить порог, вопящий голос прораба кувалдой выбивает мысли.",
			"«Ты опять опоздал, грибная крыса! Ящики — живо!»",
			"Лавина матов и обвинений. Остаётся только бежать таскать груз."
		])
	)
	root.add_child(ton)

	# lookout plaque toward city
	var vista := _make_interactable(
		"LookAtCity",
		Vector3(0.0, 0.0, -6.0),
		"[E] Посмотреть на Вастерсу",
		PackedStringArray([
			"За холодным сапфировым озером — многоярусный город. Кораблики кишат у его стен.",
			"Для кого-то это красота. Для тебя — клетка: судьба умереть от зарастания всегриба.",
			"Мысли обрываются — склад ждёт."
		])
	)
	var post := _box_mesh(Vector3(0.25, 1.6, 0.25), Color(0.35, 0.3, 0.25))
	post.position = Vector3(0, 0.8, 0)
	vista.add_child(post)
	var vcol := CollisionShape3D.new()
	vcol.name = "Collision"
	var vshape := BoxShape3D.new()
	vshape.size = Vector3(0.6, 1.8, 0.6)
	vcol.shape = vshape
	vcol.position = Vector3(0, 0.9, 0)
	vista.add_child(vcol)
	root.add_child(vista)

	# back to alley
	var back := _make_interactable(
		"BackToAlley",
		Vector3(-10.0, 0.0, -2.0),
		"[E] Вернуться в Грибной район",
		PackedStringArray(["Ты оставляешь верфи за спиной и снова ныряешь в сырые переулки."]),
		"res://scenes/alley.tscn"
	)
	var bmesh := _box_mesh(Vector3(0.4, 2.2, 2.0), Color(0.3, 0.28, 0.25))
	bmesh.position = Vector3(0, 1.1, 0)
	back.add_child(bmesh)
	var bcol := CollisionShape3D.new()
	bcol.name = "Collision"
	var bshape := BoxShape3D.new()
	bshape.size = Vector3(0.6, 2.2, 2.2)
	bcol.shape = bshape
	bcol.position = Vector3(0, 1.1, 0)
	back.add_child(bcol)
	root.add_child(back)

	# spawn just outside warehouse door facing in
	_add_player(root, Vector3(0, 0.9, wh_z - 9.0))

	_mark_owners(root, root)
	var packed := PackedScene.new()
	var pack_err := packed.pack(root)
	if pack_err != OK:
		return pack_err
	return ResourceSaver.save(packed, "res://scenes/warehouse.tscn")
