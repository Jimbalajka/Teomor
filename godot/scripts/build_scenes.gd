extends SceneTree

# One-shot builder:
# godot4 --path . --headless -s res://scripts/build_scenes.gd


func _init() -> void:
	DirAccess.make_dir_recursive_absolute("res://scenes")
	var attic_err := _save_attic()
	var outside_err := _save_outside()
	if attic_err != OK or outside_err != OK:
		push_error("BUILD_FAIL attic=%s outside=%s" % [attic_err, outside_err])
		quit(1)
		return
	print("BUILD_OK")
	quit()


func _box_mesh(size: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
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
	var mi := _box_mesh(size, color)
	mi.name = "Mesh"
	body.add_child(mi)
	var col := CollisionShape3D.new()
	col.name = "Collision"
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
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
	pshape.radius = 0.3
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
	prompt.offset_left = -220
	prompt.offset_right = 220
	prompt.offset_top = -18
	prompt.offset_bottom = 18
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.text = "[E]"
	prompt_layer.add_child(prompt)

	root.add_child(player)


func _save_attic() -> Error:
	var root := Node3D.new()
	root.name = "Attic"

	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.08, 0.08, 0.1)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.35, 0.32, 0.28)
	env.ambient_light_energy = 0.85
	world_env.environment = env
	root.add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-35, 40, 0)
	sun.light_energy = 0.85
	sun.shadow_enabled = true
	root.add_child(sun)

	var lamp := OmniLight3D.new()
	lamp.name = "AtticLamp"
	lamp.position = Vector3(0, 2.4, 0)
	lamp.light_color = Color(1.0, 0.9, 0.7)
	lamp.light_energy = 1.15
	lamp.omni_range = 8.0
	root.add_child(lamp)

	var wood := Color(0.45, 0.34, 0.22)
	var plaster := Color(0.55, 0.52, 0.48)
	var dark := Color(0.25, 0.22, 0.18)

	root.add_child(_static_box("Floor", Vector3(8, 0.2, 6), Vector3(0, -0.1, 0), wood))
	root.add_child(_static_box("Ceiling", Vector3(8, 0.2, 6), Vector3(0, 3.0, 0), dark))
	root.add_child(_static_box("WallBack", Vector3(8, 3, 0.2), Vector3(0, 1.5, -3.0), plaster))
	root.add_child(_static_box("WallFront", Vector3(8, 3, 0.2), Vector3(0, 1.5, 3.0), plaster))
	root.add_child(_static_box("WallLeft", Vector3(0.2, 3, 6), Vector3(-4.0, 1.5, 0), plaster))
	root.add_child(_static_box("WallRight", Vector3(0.2, 3, 6), Vector3(4.0, 1.5, 0), plaster))
	root.add_child(_static_box("WindowFrame", Vector3(0.15, 1.4, 1.4), Vector3(3.9, 1.5, -0.5), Color(0.2, 0.2, 0.22)))
	root.add_child(_static_box("Prop_Crate", Vector3(0.8, 0.6, 0.8), Vector3(-2.5, 0.3, -1.8), Color(0.4, 0.28, 0.16)))
	root.add_child(_static_box("Prop_Cloth", Vector3(1.2, 0.08, 0.8), Vector3(-1.2, 0.2, 1.5), Color(0.5, 0.45, 0.4)))

	var ladder := _make_interactable(
		"WindowLadder",
		Vector3(3.4, 0.0, -0.5),
		"[E] Спуститься по лестнице",
		PackedStringArray([
			"Ты подтягиваешь лестницу к окну.",
			"Ниже двор. Пока там только заглушка."
		]),
		"res://scenes/outside_stub.tscn"
	)
	var ladder_visual := _box_mesh(Vector3(0.4, 2.2, 0.4), Color(0.35, 0.25, 0.15))
	ladder_visual.name = "Mesh"
	ladder_visual.position = Vector3(0, 1.1, 0)
	ladder.add_child(ladder_visual)
	var ladder_col := CollisionShape3D.new()
	ladder_col.name = "Collision"
	var ladder_shape := BoxShape3D.new()
	ladder_shape.size = Vector3(0.6, 2.2, 0.6)
	ladder_col.shape = ladder_shape
	ladder_col.position = Vector3(0, 1.1, 0)
	ladder.add_child(ladder_col)
	root.add_child(ladder)

	var dummy := _make_interactable(
		"Dummy",
		Vector3(-2.2, 0.0, 1.2),
		"[E] Поговорить с болванкой",
		PackedStringArray([
			"Болванка молча смотрит тряпичной головой.",
			"— ...",
			"Кажется, диалог работает."
		])
	)
	var dmat := StandardMaterial3D.new()
	dmat.albedo_color = Color(0.62, 0.55, 0.45)
	var torso := MeshInstance3D.new()
	torso.name = "Torso"
	var torso_mesh := CylinderMesh.new()
	torso_mesh.top_radius = 0.22
	torso_mesh.bottom_radius = 0.25
	torso_mesh.height = 1.1
	torso.mesh = torso_mesh
	torso.position = Vector3(0, 0.9, 0)
	torso.material_override = dmat
	dummy.add_child(torso)
	var head := MeshInstance3D.new()
	head.name = "Head"
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.18
	head_mesh.height = 0.36
	head.mesh = head_mesh
	head.position = Vector3(0, 1.65, 0)
	head.material_override = dmat
	dummy.add_child(head)
	var dcol := CollisionShape3D.new()
	dcol.name = "Collision"
	var dshape := CapsuleShape3D.new()
	dshape.radius = 0.28
	dshape.height = 1.7
	dcol.shape = dshape
	dcol.position = Vector3(0, 0.95, 0)
	dummy.add_child(dcol)
	root.add_child(dummy)

	_add_player(root, Vector3(0, 0.9, 1.5))

	_mark_owners(root, root)
	var packed := PackedScene.new()
	var pack_err := packed.pack(root)
	if pack_err != OK:
		return pack_err
	return ResourceSaver.save(packed, "res://scenes/attic.tscn")


func _save_outside() -> Error:
	var root := Node3D.new()
	root.name = "OutsideStub"

	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.45, 0.55, 0.65)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.75, 0.8)
	world_env.environment = env
	root.add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-50, 20, 0)
	root.add_child(sun)

	root.add_child(_static_box("Ground", Vector3(20, 0.2, 20), Vector3(0, -0.1, 0), Color(0.3, 0.4, 0.25)))

	var sign_body := _static_box("YardSign", Vector3(1.5, 1.2, 0.2), Vector3(0, 0.7, -3.0), Color(0.35, 0.3, 0.22))
	root.add_child(sign_body)
	var label3d := Label3D.new()
	label3d.name = "Label"
	label3d.text = "Заглушка двора"
	label3d.font_size = 48
	label3d.position = Vector3(0, 1.6, -2.8)
	root.add_child(label3d)

	var back := _make_interactable(
		"BackToAttic",
		Vector3(0, 0, 2.5),
		"[E] Вернуться на чердак",
		PackedStringArray(["Ты лезешь обратно на чердак."]),
		"res://scenes/attic.tscn"
	)
	var bmesh := _box_mesh(Vector3(1.2, 2.0, 0.35), Color(0.4, 0.3, 0.2))
	bmesh.name = "Mesh"
	bmesh.position = Vector3(0, 1.0, 0)
	back.add_child(bmesh)
	var bcol := CollisionShape3D.new()
	bcol.name = "Collision"
	var bshape := BoxShape3D.new()
	bshape.size = Vector3(1.2, 2.0, 0.35)
	bcol.shape = bshape
	bcol.position = Vector3(0, 1.0, 0)
	back.add_child(bcol)
	root.add_child(back)

	_add_player(root, Vector3(0, 0.9, 0))

	_mark_owners(root, root)
	var packed := PackedScene.new()
	var pack_err := packed.pack(root)
	if pack_err != OK:
		return pack_err
	return ResourceSaver.save(packed, "res://scenes/outside_stub.tscn")
