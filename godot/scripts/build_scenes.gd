extends SceneTree

# One-shot:
# godot4 --path . --headless -s res://scripts/build_scenes.gd


func _init() -> void:
	DirAccess.make_dir_recursive_absolute("res://scenes")
	var e1 := _save_attic()
	var e2 := _save_alley()
	if e1 != OK or e2 != OK:
		push_error("BUILD_FAIL attic=%s alley=%s" % [e1, e2])
		quit(1)
		return
	# remove old stub if present
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


func _alley_walls(root: Node, x0: float, x1: float, z0: float, z1: float, height: float, color: Color) -> void:
	# floor
	var w := absf(x1 - x0)
	var d := absf(z1 - z0)
	var cx := (x0 + x1) * 0.5
	var cz := (z0 + z1) * 0.5
	root.add_child(_static_box("FloorSeg_%s" % str(cz), Vector3(w, 0.2, d), Vector3(cx, -0.1, cz), Color(0.22, 0.22, 0.2)))
	# ceiling (underground)
	root.add_child(_static_box("CeilSeg_%s" % str(cz), Vector3(w, 0.2, d), Vector3(cx, height, cz), Color(0.16, 0.17, 0.16)))
	# left/right walls
	root.add_child(_static_box("WallL_%s" % str(cz), Vector3(0.2, height, d), Vector3(x0, height * 0.5, cz), color))
	root.add_child(_static_box("WallR_%s" % str(cz), Vector3(0.2, height, d), Vector3(x1, height * 0.5, cz), color))


func _save_alley() -> Error:
	var root := Node3D.new()
	root.name = "Alley"

	root.add_child(_underground_env(Color(0.06, 0.07, 0.07), Color(0.28, 0.32, 0.3)))

	var fill := OmniLight3D.new()
	fill.name = "Fill"
	fill.position = Vector3(0, 2.5, 4)
	fill.light_color = Color(0.75, 0.85, 0.8)
	fill.light_energy = 0.9
	fill.omni_range = 12.0
	root.add_child(fill)

	var stone := Color(0.32, 0.34, 0.33)
	var height := 4.5

	# Narrow dead-end alley: width ~1.3 (x -0.65..0.65), length ~6 toward -Z end
	# Player arrives near junction (z~0), dead-end at z negative with barrels
	_alley_walls(root, -0.65, 0.65, -6.0, 1.0, height, stone)
	# back wall of dead-end
	root.add_child(_static_box("DeadEndWall", Vector3(1.5, height, 0.2), Vector3(0, height * 0.5, -6.0), stone))

	# barrels in dead end
	root.add_child(_static_box("Barrel1", Vector3(0.45, 0.7, 0.45), Vector3(-0.2, 0.35, -5.2), Color(0.4, 0.28, 0.18)))
	root.add_child(_static_box("Barrel2", Vector3(0.4, 0.6, 0.4), Vector3(0.25, 0.3, -4.7), Color(0.38, 0.26, 0.16)))
	root.add_child(_static_box("Barrel3", Vector3(0.35, 0.55, 0.35), Vector3(-0.15, 0.28, -4.4), Color(0.36, 0.25, 0.15)))

	# Wider alley ahead (+Z), about 2x width (~2.6), not very long (~10)
	_alley_walls(root, -1.3, 1.3, 1.0, 11.0, height, Color(0.3, 0.33, 0.32))
	# end wall of short wide alley
	root.add_child(_static_box("WideEndWall", Vector3(2.8, height, 0.2), Vector3(0, height * 0.5, 11.0), stone))

	# building faces / mushroom stubs
	root.add_child(_mushroom("Mush1", Vector3(-0.55, 1.2, -2.0), 1.0))
	root.add_child(_mushroom("Mush2", Vector3(0.55, 1.8, -3.5), 1.2))
	root.add_child(_mushroom("Mush3", Vector3(-1.15, 1.5, 3.0), 1.3))
	root.add_child(_mushroom("Mush4", Vector3(1.15, 2.2, 6.5), 1.5))
	root.add_child(_mushroom("Mush5", Vector3(-1.1, 0.8, 8.5), 0.9))

	# Ladder back up (Skyrim-style activate)
	var up := _make_interactable(
		"LadderUp",
		Vector3(0.0, 0.0, 0.2),
		"[E] Подняться на чердак",
		PackedStringArray([
			"Ты снова хватаешься за холодные перекладины.",
			"Три этажа вверх — и снова сырой чердак."
		]),
		"res://scenes/attic.tscn"
	)
	var up_mesh := _box_mesh(Vector3(0.5, 2.5, 0.2), Color(0.3, 0.22, 0.15))
	up_mesh.position = Vector3(0, 1.25, 0)
	up.add_child(up_mesh)
	var ucol := CollisionShape3D.new()
	ucol.name = "Collision"
	var ushape := BoxShape3D.new()
	ushape.size = Vector3(0.7, 2.5, 0.5)
	ucol.shape = ushape
	ucol.position = Vector3(0, 1.25, 0)
	up.add_child(ucol)
	root.add_child(up)

	# spawn facing toward wider alley
	_add_player(root, Vector3(0, 0.9, -1.5))

	_mark_owners(root, root)
	var packed := PackedScene.new()
	var pack_err := packed.pack(root)
	if pack_err != OK:
		return pack_err
	return ResourceSaver.save(packed, "res://scenes/alley.tscn")
