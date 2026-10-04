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
	var e6 := _save_shop()
	var e7 := _save_central_library()
	var e8 := _save_playtest()
	if e1 != OK or e2 != OK or e3 != OK or e4 != OK or e5 != OK or e6 != OK or e7 != OK or e8 != OK:
		push_error("BUILD_FAIL attic=%s alley=%s warehouse=%s libstreet=%s library=%s shop=%s central=%s playtest=%s" % [e1, e2, e3, e4, e5, e6, e7, e8])
		quit(1)
		return
	if FileAccess.file_exists("res://scenes/outside_stub.tscn"):
		DirAccess.remove_absolute("res://scenes/outside_stub.tscn")
	print("BUILD_OK")
	quit()


## Style anchor palette (dirty, never clean)
const C_PARCHMENT := Color(0.62, 0.5, 0.28)
const C_PARCHMENT_DARK := Color(0.36, 0.28, 0.16)
const C_INK := Color(0.05, 0.04, 0.05)
const C_PURPLE := Color(0.42, 0.16, 0.38)
const C_PURPLE_GLOW := Color(0.55, 0.18, 0.48)
const C_WOOD := Color(0.4, 0.28, 0.16)
const C_STONE := Color(0.28, 0.24, 0.22)
const C_DAMP := Color(0.3, 0.26, 0.22)

# Author Poly Haven packs (color-corrected) live in author/; mushrooms/ink remain in style/.
const TEX_DIR_AUTHOR := "res://assets/textures/author/"
const TEX_DIR_STYLE := "res://assets/textures/style/"
# Mapping from author: wood=floor/boards, concrete=inner walls, brick=building mass,
# ceramic/tile=building base, metal=props/cornices, floor=concrete+ceramic mix.
const TEX_PLASTER := "concrete_512.png"
const TEX_WOOD := "wood_hand_512.png"  # author hand-paint preview; old: wood_weathered_512.png
const TEX_STONE := "brick_broken_512.png"
# Author hand-paint for alley walls (albedo only for now)
const TEX_STONE_WIDE := "stone_broken_512.png"
const TEX_STONE_PATTERN := "stone_broken2_512.png"
const TEX_FLOOR := "floor_mix_512.png"
const TEX_BASE := "tile_worn_512.png"
const TEX_METAL := "metal_rusty_512.png"
const TEX_FLESH := "tex_vsegrib_flesh_512.png"
const TEX_CAP := "tex_vsegrib_cap_512.png"
const TEX_INK := "tex_ink_grime_512.png"


const MESH_KENNEY := "res://assets/meshes/props/kenney/"
const MESH_PROPSLITE := "res://assets/meshes/props/propslite/"
const MESH_DUNGEON := "res://assets/meshes/props/dungeon_items/"
const MESH_PROTO := "res://assets/meshes/modular/proto/"


## Instance glb prop via GLTFDocument (works headless without .import).
## FBX: open project in editor once, or prefer Kenney .glb paths.
func _add_mesh_prop(root: Node, name: String, res_path: String, pos: Vector3, rot_y_deg: float = 0.0, uniform_scale: float = 1.0, col_size: Vector3 = Vector3.ZERO) -> Node3D:
	var holder := Node3D.new()
	holder.name = name
	holder.position = pos
	holder.rotation_degrees.y = rot_y_deg
	holder.scale = Vector3.ONE * uniform_scale
	var abs_path := ProjectSettings.globalize_path(res_path) if res_path.begins_with("res://") else res_path
	var loaded := false
	if res_path.ends_with(".glb") or res_path.ends_with(".gltf"):
		if FileAccess.file_exists(abs_path):
			var doc := GLTFDocument.new()
			var state := GLTFState.new()
			var err := doc.append_from_file(abs_path, state)
			if err == OK:
				var scn := doc.generate_scene(state)
				if scn != null:
					holder.add_child(scn)
					loaded = true
			else:
				push_warning("GLTF_LOAD_FAIL %s err=%s" % [res_path, err])
	elif ResourceLoader.exists(res_path):
		var res = load(res_path)
		if res is PackedScene:
			holder.add_child((res as PackedScene).instantiate())
			loaded = true
	if not loaded:
		push_warning("MESH_MISSING %s" % res_path)
		holder.add_child(_box_mesh(Vector3(0.35, 0.35, 0.35), Color(0.45, 0.28, 0.18)))
	if col_size != Vector3.ZERO:
		var body := StaticBody3D.new()
		body.name = "ColBody"
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = col_size
		col.shape = shape
		col.position = Vector3(0, col_size.y * 0.5, 0)
		body.add_child(col)
		holder.add_child(body)
	root.add_child(holder)
	return holder



var _tex_cache: Dictionary = {}


func _hash01(x: int, y: int, salt: int = 0) -> float:
	var n := x * 374761393 + y * 668265263 + salt * 1274126177
	n = (n ^ (n >> 13)) * 1274126177
	n = n ^ (n >> 16)
	return float(n & 0xFFFF) / 65535.0


func _noise_tex(base: Color, ink_amt: float = 0.18, size: int = 48, salt: int = 1) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	for y in size:
		for x in size:
			var n := _hash01(x, y, salt)
			var n2 := _hash01(x + 17, y + 9, salt + 3)
			var c := base.lerp(C_INK, ink_amt * n)
			c = c.darkened(0.12 * n2)
			if n > 0.92:
				c = c.lerp(C_INK, 0.55)
			img.set_pixel(x, y, c)
	var tex := ImageTexture.create_from_image(img)
	return tex


func _tex_dirs_for(file_name: String) -> PackedStringArray:
	# Mushrooms / ink stay in style; architecture uses author packs.
	if file_name.begins_with("tex_vsegrib_") or file_name == TEX_INK or file_name.begins_with("tex_"):
		return PackedStringArray([TEX_DIR_STYLE, TEX_DIR_AUTHOR])
	return PackedStringArray([TEX_DIR_AUTHOR, TEX_DIR_STYLE])


func _load_style_tex(file_name: String) -> Texture2D:
	if file_name.is_empty():
		return null
	if _tex_cache.has(file_name):
		return _tex_cache[file_name]
	for tex_dir in _tex_dirs_for(file_name):
		var path := tex_dir + file_name
		# Prefer imported CompressedTexture2D so PackedScene keeps ExtResource (not megabyte embeds).
		if ResourceLoader.exists(path):
			var tex := load(path) as Texture2D
			if tex != null:
				_tex_cache[file_name] = tex
				return tex
		# Headless / pre-import fallback — still bind path to avoid embedding raw pixels in .tscn
		var img := Image.new()
		var err := img.load(ProjectSettings.globalize_path(path) if path.begins_with("res://") else path)
		if err != OK:
			err = img.load(path)
		if err != OK:
			continue
		var itex := ImageTexture.create_from_image(img)
		itex.take_over_path(path)
		_tex_cache[file_name] = itex
		return itex
	return null


func _color_dist(a: Color, b: Color) -> float:
	var dr := a.r - b.r
	var dg := a.g - b.g
	var db := a.b - b.b
	return dr * dr + dg * dg + db * db


func _pick_tex_for_color(color: Color) -> String:
	# Flesh/cap ONLY via explicit tex_name on mushroom meshes — never auto on walls.
	# Wood / warm boards
	if _color_dist(color, C_WOOD) < 0.03 or (color.r > 0.3 and color.g > 0.2 and color.b < 0.22 and color.r >= color.g):
		return TEX_WOOD
	# Parchment plaster
	if _color_dist(color, C_PARCHMENT) < 0.05 or _color_dist(color, C_PARCHMENT_DARK) < 0.04 or _color_dist(color, C_DAMP) < 0.025:
		return TEX_PLASTER
	# Stone (incl. purple-tinted walls — sick grade comes from lights/env)
	if _color_dist(color, C_STONE) < 0.05:
		return TEX_STONE
	# Near-black / floor
	if color.r + color.g + color.b < 0.35:
		return TEX_FLOOR
	# Cool grey metal-ish
	if abs(color.r - color.g) < 0.05 and abs(color.g - color.b) < 0.08 and color.r < 0.55:
		return TEX_METAL
	# Purple-ish props that aren't mushrooms → stained stone, not flesh albedo
	if color.b > color.g and color.r >= color.g:
		return TEX_STONE
	return TEX_PLASTER


func _companion_name(albedo_name: String, kind: String) -> String:
	# tex_attic_wood_512.png -> tex_attic_wood_n_512.png / _r_512.png
	if albedo_name.ends_with("_512.png"):
		return albedo_name.replace("_512.png", "_%s_512.png" % kind)
	return ""


## World-meter UV: lower = larger material features (brick not tile).
func _world_uv(tex_name: String, size: Vector3) -> float:
	var file_name := tex_name if not tex_name.is_empty() else ""
	var base := 0.45
	if file_name == TEX_STONE or file_name == TEX_STONE_WIDE or file_name == TEX_STONE_PATTERN:
		base = 0.30  # large readable masonry
	elif file_name == TEX_BASE:
		base = 0.42
	elif file_name == TEX_FLOOR:
		base = 0.4
	elif file_name == TEX_WOOD:
		base = 0.42  # readable planks
	elif file_name == TEX_PLASTER:
		base = 0.38
	elif file_name == TEX_METAL:
		base = 1.05
	elif file_name == TEX_INK:
		base = 0.5
	elif file_name == TEX_FLESH or file_name == TEX_CAP:
		base = 1.15
	else:
		# unknown / auto-pick later — mild size hint only
		base = clampf((size.x + size.y + size.z) * 0.05, 0.35, 0.7)
	return base


func _style_mat(base: Color, ink_amt: float = 0.18, rough: float = 0.92, emit: Color = Color(0, 0, 0, 1), emit_e: float = 0.0, salt: int = 1, tex_name: String = "", uv_scale: float = 1.1, uv_offset: Vector3 = Vector3.ZERO) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	var file_name := tex_name if not tex_name.is_empty() else _pick_tex_for_color(base)
	# Hard block: figurative organic maps stay off architecture
	if tex_name.is_empty() and (file_name == TEX_FLESH or file_name == TEX_CAP):
		file_name = TEX_STONE
	var tex: Texture2D = _load_style_tex(file_name)
	if tex == null:
		tex = _noise_tex(base, ink_amt, 48, salt)
		mat.albedo_color = Color(1, 1, 1)
	else:
		# Mild tint; baked AO/bevel already in albedo
		mat.albedo_color = base.lerp(Color(1, 1, 1), 0.9)
	mat.albedo_texture = tex
	var ntex: Texture2D = _load_style_tex(_companion_name(file_name, "n"))
	if ntex != null:
		mat.normal_enabled = true
		mat.normal_texture = ntex
		mat.normal_scale = 1.4
	var rtex: Texture2D = _load_style_tex(_companion_name(file_name, "r"))
	if rtex != null:
		mat.roughness_texture = rtex
		mat.roughness = 1.0
	else:
		mat.roughness = rough
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mat.uv1_triplanar = true
	# Softer blend — less "sticker on box" seams (sphere-like read)
	mat.uv1_triplanar_sharpness = 3.5
	# Mild jitter only — keep brick scale stable
	var jitter := 0.92 + 0.16 * _hash01(salt, 3, 19)
	mat.uv1_scale = Vector3(uv_scale * jitter, uv_scale * jitter, uv_scale * jitter)
	mat.uv1_offset = uv_offset
	mat.metallic = 0.0
	if emit_e > 0.0:
		mat.emission_enabled = true
		mat.emission = emit
		mat.emission_energy_multiplier = emit_e
	return mat


func _box_mesh(size: Vector3, color: Color, tex_name: String = "", salt_extra: int = 0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = "Mesh"
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	var ink := 0.2
	if color.r + color.g + color.b < 0.35:
		ink = 0.35
	# World-meter UV by material (brick large; do NOT scale up with wall length)
	var file_guess := tex_name if not tex_name.is_empty() else _pick_tex_for_color(color)
	var uv := _world_uv(file_guess, size)
	var salt := int(color.r * 97 + color.g * 53 + color.b * 31) + salt_extra + int(size.x * 13 + size.y * 29 + size.z * 47)
	var off := Vector3(_hash01(salt, 1, 5), _hash01(salt, 2, 7), _hash01(salt, 3, 11))
	mi.material_override = _style_mat(color, ink, 0.9, Color(0, 0, 0), 0.0, salt, tex_name, uv, off)
	return mi


func _static_box(name: String, size: Vector3, pos: Vector3, color: Color, tex_name: String = "") -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = name
	body.position = pos
	var salt_extra := int(abs(pos.x * 17.0) + abs(pos.y * 29.0) + abs(pos.z * 43.0) + name.length() * 13)
	body.add_child(_box_mesh(size, color, tex_name, salt_extra))
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
	var stem_mat := _style_mat(C_PURPLE.darkened(0.25), 0.25, 0.9, Color(0, 0, 0), 0.0, 11, TEX_FLESH, 1.1)
	var stem := MeshInstance3D.new()
	stem.name = "Stem"
	var stem_mesh := CylinderMesh.new()
	stem_mesh.top_radius = 0.05 * scale
	stem_mesh.bottom_radius = 0.08 * scale
	stem_mesh.height = 0.28 * scale
	stem.mesh = stem_mesh
	stem.position = Vector3(0, 0.14 * scale, 0)
	stem.material_override = stem_mat
	body.add_child(stem)
	var cap := MeshInstance3D.new()
	cap.name = "Cap"
	var cap_mesh := SphereMesh.new()
	cap_mesh.radius = 0.16 * scale
	cap_mesh.height = 0.18 * scale
	cap.mesh = cap_mesh
	cap.position = Vector3(0, 0.32 * scale, 0)
	cap.material_override = _style_mat(C_PURPLE_GLOW, 0.12, 0.85, C_PURPLE_GLOW, 0.55, 17, TEX_CAP, 1.3)
	body.add_child(cap)
	# tiny spores around base
	for i in range(3):
		var spore := MeshInstance3D.new()
		spore.name = "Spore_%d" % i
		var sm := SphereMesh.new()
		sm.radius = 0.035 * scale * (1.0 + float(i) * 0.15)
		sm.height = sm.radius * 2.0
		spore.mesh = sm
		var ang := float(i) * 2.1
		spore.position = Vector3(cos(ang) * 0.12 * scale, 0.03 * scale, sin(ang) * 0.12 * scale)
		spore.material_override = _style_mat(C_PURPLE, 0.2, 0.9, C_PURPLE_GLOW, 0.35, 20 + i, TEX_FLESH, 1.6)
		body.add_child(spore)
	var col := CollisionShape3D.new()
	col.name = "Collision"
	var shape := SphereShape3D.new()
	shape.radius = 0.18 * scale
	col.shape = shape
	col.position = Vector3(0, 0.24 * scale, 0)
	body.add_child(col)
	return body


func _growth_blob(root: Node, name: String, pos: Vector3, radius: float, glow: bool = false) -> void:
	var mi := MeshInstance3D.new()
	mi.name = name
	mi.position = pos
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 1.7
	mi.mesh = mesh
	if glow:
		mi.material_override = _style_mat(C_PURPLE_GLOW, 0.15, 0.88, C_PURPLE_GLOW, 0.45, 41, TEX_CAP, 1.2)
	else:
		mi.material_override = _style_mat(C_PURPLE.darkened(0.1), 0.28, 0.95, Color(0, 0, 0), 0.0, 43, TEX_FLESH, 1.1)
	root.add_child(mi)
	# satellite spores
	for i in range(4):
		var s := MeshInstance3D.new()
		s.name = "%s_s%d" % [name, i]
		var sm := SphereMesh.new()
		sm.radius = radius * (0.22 + 0.08 * float(i % 3))
		sm.height = sm.radius * 2.0
		s.mesh = sm
		var a := float(i) * 1.7
		s.position = pos + Vector3(cos(a) * radius * 0.9, -radius * 0.2 + float(i) * 0.03, sin(a) * radius * 0.9)
		s.material_override = _style_mat(C_PURPLE, 0.22, 0.9, C_PURPLE if glow else Color(0, 0, 0), 0.2 if glow else 0.0, 50 + i, TEX_FLESH, 1.5)
		root.add_child(s)


func _ink_streak(root: Node, name: String, pos: Vector3, size: Vector3) -> void:
	root.add_child(_static_box(name, size, pos, C_INK, TEX_INK))


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


func _poi(root: Node, name: String, pos: Vector3, size: Vector3, color: Color, prompt: String, lines: PackedStringArray, scene_path: String = "") -> StaticBody3D:
	var body := _make_interactable(name, pos, prompt, lines, scene_path)
	var mesh := _box_mesh(size, color)
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
	return body


func _shop_choice(root: Node, name: String, pos: Vector3, choice_id: String, prompt: String, lines: PackedStringArray, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = name
	body.position = pos
	body.set_script(load("res://scripts/shop_item.gd"))
	body.set("prompt_text", prompt)
	body.set("dialogue_lines", lines)
	body.set("choice_id", choice_id)
	body.set("change_scene_to", "res://scenes/central_library.tscn")
	var size := Vector3(1.2, 1.0, 1.2)
	var mesh := _box_mesh(size, color)
	mesh.position = Vector3(0, size.y * 0.5, 0)
	body.add_child(mesh)
	var col := CollisionShape3D.new()
	col.name = "Collision"
	var shape := BoxShape3D.new()
	shape.size = size + Vector3(0.15, 0.15, 0.15)
	col.shape = shape
	col.position = Vector3(0, size.y * 0.5, 0)
	body.add_child(col)
	root.add_child(body)
	return body


func _add_player(root: Node, pos: Vector3) -> void:
	var player := CharacterBody3D.new()
	player.name = "Player"
	# pos historically ~eye/center (y≈0.9); convert to feet for crouch-safe capsule.
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
	hint.text = "WASD · Shift бег · Ctrl присед · Пробел прыжок · E · Esc"
	prompt_layer.add_child(hint)
	root.add_child(player)


func _underground_env(bg: Color, ambient: Color, fog: Color = Color(0.2, 0.16, 0.14), dens: float = 0.035, amb_e: float = 0.55, exposure: float = 0.95, sick: float = 1.0) -> WorldEnvironment:
	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = bg
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = ambient
	env.ambient_light_energy = amb_e
	env.fog_enabled = true
	env.fog_light_color = fog
	env.fog_density = dens
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = exposure
	# Sick-vision filter: dirty film look, not a cover for bad geo
	env.adjustment_enabled = true
	env.adjustment_brightness = lerpf(1.0, 1.06, sick)
	env.adjustment_saturation = lerpf(0.85, 0.58, sick)
	env.adjustment_contrast = lerpf(1.05, 1.22, sick)
	env.glow_enabled = sick > 0.5
	if env.glow_enabled:
		env.glow_intensity = 0.22 * sick
		env.glow_strength = 0.8
		env.glow_bloom = 0.05
		env.glow_hdr_threshold = 0.85
	world_env.environment = env
	return world_env


func _add_rotated_box(root: Node, name: String, size: Vector3, pos: Vector3, rot_deg: Vector3, color: Color, tex_name: String = "") -> StaticBody3D:
	var body := _static_box(name, size, pos, color, tex_name)
	body.rotation_degrees = rot_deg
	return body


func _col_parchment_dirty(seed: float = 0.0) -> Color:
	# dirty yellow-white with ink bite
	var c := C_PARCHMENT.lerp(Color(0.72, 0.68, 0.55), 0.35)
	c = c.darkened(0.08 + 0.1 * seed)
	return c.lerp(C_INK, 0.12 + 0.08 * seed)


func _col_cloth(seed: float = 0.0) -> Color:
	var c := Color(0.62, 0.56, 0.42).lerp(C_PARCHMENT, 0.4)
	return c.darkened(0.05 + 0.12 * seed).lerp(C_INK, 0.1)


func _add_omni(root: Node, name: String, pos: Vector3, color: Color, energy: float, rng: float, atten: float = 1.4, shadows: bool = true) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.name = name
	l.position = pos
	l.light_color = color
	l.light_energy = energy
	l.omni_range = rng
	l.omni_attenuation = atten
	l.shadow_enabled = shadows
	if shadows:
		l.shadow_blur = 1.1
	root.add_child(l)
	return l


## Candle: warm parchment flame + purple sickness in the light
func _add_candle(root: Node, name: String, pos: Vector3, energy: float = 0.85) -> void:
	var stick := _static_box(name + "_Wax", Vector3(0.06, 0.18, 0.06), pos + Vector3(0, 0.09, 0), _col_parchment_dirty(0.2), TEX_PLASTER)
	root.add_child(stick)
	var flame := MeshInstance3D.new()
	flame.name = name + "_Flame"
	var sm := SphereMesh.new()
	sm.radius = 0.045
	sm.height = 0.09
	flame.mesh = sm
	flame.position = pos + Vector3(0, 0.22, 0)
	flame.material_override = _style_mat(C_PARCHMENT.lightened(0.2), 0.05, 0.7, C_PURPLE_GLOW, 0.85, 77, TEX_CAP, 2.0)
	root.add_child(flame)
	# purple-warm candle light
	_add_omni(root, name + "_L", pos + Vector3(0, 0.25, 0), Color(0.85, 0.45, 0.62), energy, 3.8, 1.55, true)


## Wall torch: wood haft + purple fire
func _add_torch(root: Node, name: String, pos: Vector3, yaw_deg: float = 0.0, energy: float = 1.15) -> void:
	var body := Node3D.new()
	body.name = name
	body.position = pos
	body.rotation_degrees = Vector3(0, yaw_deg, 0)
	var haft := _box_mesh(Vector3(0.07, 0.55, 0.07), C_WOOD.darkened(0.1), TEX_WOOD)
	haft.position = Vector3(0.12, 0.2, 0)
	body.add_child(haft)
	var head := MeshInstance3D.new()
	head.name = "Head"
	var cm := SphereMesh.new()
	cm.radius = 0.09
	cm.height = 0.16
	head.mesh = cm
	head.position = Vector3(0.12, 0.52, 0)
	head.material_override = _style_mat(C_PURPLE_GLOW, 0.1, 0.75, C_PURPLE_GLOW, 0.9, 88, TEX_CAP, 1.8)
	body.add_child(head)
	var br := MeshInstance3D.new()
	br.name = "Bracket"
	var bm := BoxMesh.new()
	bm.size = Vector3(0.18, 0.05, 0.05)
	br.mesh = bm
	br.position = Vector3(0.05, 0.35, 0)
	br.material_override = _style_mat(Color(0.28, 0.24, 0.2), 0.25, 0.9, Color(0,0,0), 0.0, 90, TEX_METAL, 1.2)
	body.add_child(br)
	root.add_child(body)
	var light_off := Vector3(0.18, 0.55, 0)
	if abs(yaw_deg) > 1.0:
		# approximate yaw without Basis dance
		var rad := deg_to_rad(yaw_deg)
		light_off = Vector3(cos(rad) * 0.18, 0.55, -sin(rad) * 0.18)
	_add_omni(root, name + "_L", pos + light_off, Color(0.78, 0.38, 0.7), energy, 5.5, 1.35, true)


func _add_window_frame(root: Node, name: String, pos: Vector3, size: Vector3, rot_y: float = 0.0) -> void:
	# hole (dark) + wood frame — breaks flat wall
	var hole := _static_box(name + "_Hole", size, pos, C_INK.lightened(0.04), TEX_INK)
	hole.rotation_degrees = Vector3(0, rot_y, 0)
	root.add_child(hole)
	var thick := 0.06
	var frame_col := C_WOOD.darkened(0.05)
	# simple frame strips along local axes (axis-aligned approx)
	root.add_child(_static_box(name + "_FT", Vector3(size.x + thick * 2.0, thick, size.z + 0.04), pos + Vector3(0, size.y * 0.5 + thick * 0.5, 0), frame_col, TEX_WOOD))
	root.add_child(_static_box(name + "_FB", Vector3(size.x + thick * 2.0, thick, size.z + 0.04), pos + Vector3(0, -size.y * 0.5 - thick * 0.5, 0), frame_col, TEX_WOOD))
	root.add_child(_static_box(name + "_FL", Vector3(thick, size.y, size.z + 0.04), pos + Vector3(-size.x * 0.5 - thick * 0.5, 0, 0), frame_col, TEX_WOOD))
	root.add_child(_static_box(name + "_FR", Vector3(thick, size.y, size.z + 0.04), pos + Vector3(size.x * 0.5 + thick * 0.5, 0, 0), frame_col, TEX_WOOD))


func _add_clothesline(root: Node, name: String, a: Vector3, b: Vector3, pieces: int = 4) -> void:
	var mid := (a + b) * 0.5
	var length := a.distance_to(b)
	var rope := _static_box(name + "_Rope", Vector3(length, 0.03, 0.03), mid, C_INK.lightened(0.1), TEX_INK)
	root.add_child(rope)
	for i in range(pieces):
		var t := (float(i) + 0.5) / float(pieces)
		var p := a.lerp(b, t)
		var h := 0.45 + 0.15 * float(i % 3)
		var w := 0.35 + 0.1 * float((i * 3) % 4)
		root.add_child(_static_box("%s_Cloth%d" % [name, i], Vector3(w, h, 0.04), p + Vector3(0, -h * 0.45, 0), _col_cloth(float(i) * 0.2), TEX_PLASTER))


func _save_attic() -> Error:

	var root := Node3D.new()
	root.name = "Attic"

	# Dominant: dirty parchment — key+shadow, weak fill (DD/Lunacid read)
	root.add_child(_underground_env(
		Color(0.09, 0.05, 0.06),
		Color(0.48, 0.32, 0.28),
		Color(0.34, 0.2, 0.22),
		0.028,
		0.5,
		1.02,
		0.9
	))

	# Candles only — warm parchment body, purple sickness in the light
	_add_candle(root, "CandleBed", Vector3(-1.1, 0.45, -1.35), 1.05)
	_add_candle(root, "CandleCrate", Vector3(-2.0, 0.55, 1.35), 0.9)
	_add_candle(root, "CandleMirror", Vector3(1.7, 0.9, -1.5), 0.8)
	_add_candle(root, "CandleHatch", Vector3(1.55, 0.35, 1.35), 0.75)
	# soft purple ambient spill (sick vision), not a fake sun
	_add_omni(root, "PurpleSpill", Vector3(0.0, 1.8, 0.2), Color(0.55, 0.22, 0.5), 0.45, 6.5, 1.2, false)

	var wood := C_WOOD
	var plaster := C_PARCHMENT
	var damp := C_DAMP

	# Cramped attic — break the pure box: low side walls + pitched roof slabs
	root.add_child(_static_box("Floor", Vector3(6, 0.2, 5), Vector3(0, -0.1, 0), wood, TEX_WOOD))
	root.add_child(_static_box("WallBack", Vector3(6, 2.1, 0.2), Vector3(0, 1.05, -2.5), plaster, TEX_PLASTER))
	root.add_child(_static_box("WallFront", Vector3(6, 2.1, 0.2), Vector3(0, 1.05, 2.5), plaster, TEX_PLASTER))
	root.add_child(_static_box("WallLeft", Vector3(0.2, 1.7, 5), Vector3(-3.0, 0.85, 0), damp, TEX_PLASTER))
	root.add_child(_static_box("WallRight", Vector3(0.2, 1.7, 5), Vector3(3.0, 0.85, 0), plaster, TEX_PLASTER))
	# Pitched roof (visual volume)
	_add_rotated_box(root, "RoofL", Vector3(6.2, 0.12, 3.2), Vector3(0, 2.35, -0.9), Vector3(28, 0, 0), C_WOOD.darkened(0.08), TEX_WOOD)
	_add_rotated_box(root, "RoofR", Vector3(6.2, 0.12, 3.2), Vector3(0, 2.35, 0.9), Vector3(-28, 0, 0), C_WOOD.darkened(0.1), TEX_WOOD)
	# Ridge + ceiling beams
	root.add_child(_static_box("Ridge", Vector3(6.1, 0.14, 0.22), Vector3(0, 2.95, 0), wood, TEX_WOOD))
	for i in range(4):
		var z := -1.8 + float(i) * 1.2
		root.add_child(_static_box("Beam_%d" % i, Vector3(5.6, 0.16, 0.18), Vector3(0, 2.15, z), wood, TEX_WOOD))
	# Corner posts / clutter that kill the cube read
	root.add_child(_static_box("PostL", Vector3(0.18, 2.0, 0.18), Vector3(-2.7, 1.0, -2.1), wood, TEX_WOOD))
	root.add_child(_static_box("PostR", Vector3(0.18, 2.0, 0.18), Vector3(2.7, 1.0, -2.1), wood, TEX_WOOD))
	root.add_child(_static_box("JoistBrace", Vector3(0.14, 0.9, 1.6), Vector3(-2.75, 1.7, 0.2), wood, TEX_WOOD))
	root.add_child(_static_box("Trunk", Vector3(1.1, 0.55, 0.7), Vector3(2.1, 0.28, -1.5), Color(0.34, 0.24, 0.15), TEX_WOOD))
	root.add_child(_static_box("BoardStack", Vector3(1.4, 0.25, 0.55), Vector3(-0.4, 0.15, 1.9), wood, TEX_WOOD))
	_add_clothesline(root, "AtticLine", Vector3(-1.8, 1.85, -2.2), Vector3(1.6, 1.85, -2.2), 5)
	# Window hole in side wall (wood frame)
	_add_window_frame(root, "AtticWin", Vector3(2.95, 1.15, -0.6), Vector3(0.08, 0.85, 0.7))
	# Relief: shelf niche + pipe + floor debris
	root.add_child(_static_box("ShelfNiche", Vector3(1.1, 0.08, 0.35), Vector3(-2.55, 1.35, 0.9), wood, TEX_WOOD))
	root.add_child(_static_box("ShelfNiche2", Vector3(1.1, 0.08, 0.35), Vector3(-2.55, 1.0, 0.9), wood, TEX_WOOD))
	root.add_child(_static_box("PipeRun", Vector3(0.08, 0.08, 2.4), Vector3(2.75, 1.85, 0.2), Color(0.32, 0.3, 0.28), TEX_METAL))
	root.add_child(_static_box("Debris1", Vector3(0.35, 0.12, 0.45), Vector3(0.8, 0.08, 1.6), wood, TEX_WOOD))
	root.add_child(_static_box("Debris2", Vector3(0.5, 0.1, 0.28), Vector3(-0.9, 0.06, 1.7), Color(0.3, 0.26, 0.22), TEX_PLASTER))

	# Bed stub
	root.add_child(_static_box("Bed", Vector3(2.0, 0.35, 1.0), Vector3(-1.6, 0.2, -1.6), Color(0.35, 0.3, 0.28), TEX_WOOD))
	root.add_child(_static_box("BedPillow", Vector3(0.5, 0.15, 0.4), Vector3(-2.2, 0.45, -1.6), _col_parchment_dirty(0.15), TEX_PLASTER))

	# Mirror — phase 2: name + appearance
	var mirror := StaticBody3D.new()
	mirror.name = "Mirror"
	mirror.position = Vector3(2.2, 0.0, -1.8)
	mirror.set_script(load("res://scripts/mirror_interactable.gd"))
	mirror.set("prompt_text", "[E] Посмотреть в зеркало")
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
	root.add_child(_static_box("HatchFrame", Vector3(1.0, 0.08, 1.0), Vector3(2.0, 2.7, 1.2), Color(0.2, 0.18, 0.15), TEX_WOOD))
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

	# Playtest lab (mechanics sandbox; story route still uses ladder → alley)
	var to_pt := _make_interactable(
		"GoPlaytest",
		Vector3(-2.6, 0.0, 2.05),
		"[E] В плейтест-комнату",
		PackedStringArray([
			"Занавеска в сторону — серый короб для проверки механик.",
			"Сюжетный спуск по лестнице на место."
		]),
		"res://scenes/playtest.tscn"
	)
	var pt_door := _box_mesh(Vector3(0.12, 1.9, 0.9), Color(0.22, 0.28, 0.35))
	pt_door.position = Vector3(0, 0.95, 0)
	to_pt.add_child(pt_door)
	var ptcol := CollisionShape3D.new()
	ptcol.name = "Collision"
	var ptshape := BoxShape3D.new()
	ptshape.size = Vector3(0.4, 2.0, 1.0)
	ptcol.shape = ptshape
	ptcol.position = Vector3(0, 1.0, 0)
	to_pt.add_child(ptcol)
	root.add_child(to_pt)

	# damp props
	root.add_child(_static_box("Crate", Vector3(0.7, 0.5, 0.7), Vector3(-2.2, 0.25, 1.4), Color(0.38, 0.28, 0.18), TEX_WOOD))
	# Curated itch/CC0 meshes (Kenney + PropsLite)
	_add_mesh_prop(root, "MeshCrateRopes", MESH_KENNEY + "detail-crate-ropes.glb", Vector3(-2.35, 0.0, 1.55), 20.0, 1.0, Vector3(0.7, 0.55, 0.7))
	_add_mesh_prop(root, "MeshBarrelAttic", MESH_KENNEY + "detail-barrel.glb", Vector3(1.9, 0.0, 1.7), -30.0, 1.0, Vector3(0.55, 0.7, 0.55))
	_add_mesh_prop(root, "MeshSackProxy", MESH_KENNEY + "detail-crate-small.glb", Vector3(-0.2, 0.0, 1.85), 10.0, 1.0, Vector3(0.45, 0.4, 0.45))
	_add_mesh_prop(root, "MeshShelfCrate", MESH_KENNEY + "detail-crate-small.glb", Vector3(-2.55, 1.08, 0.85), 12.0, 0.45, Vector3(0.35, 0.25, 0.3))
	_add_mesh_prop(root, "MeshPlanks", MESH_KENNEY + "fence-wood.glb", Vector3(0.6, 0.0, -2.05), 90.0, 1.0, Vector3(1.2, 0.12, 0.35))
	root.add_child(_mushroom("Mushroom_Attic1", Vector3(-2.7, 0.9, -0.4), 0.9))
	root.add_child(_mushroom("Mushroom_Attic2", Vector3(2.7, 1.4, 0.3), 1.1))

	# POI: дневник, щель с видом, мокрые тряпки
	_poi(root, "Diary", Vector3(-1.2, 0.0, -1.5), Vector3(0.35, 0.08, 0.28), Color(0.55, 0.45, 0.3),
		"[E] Листать дневник",
		PackedStringArray([
			"Потёртый блокнот. Буквы расползаются от сырости.",
			"«Ещё один день. Если не сдохну — пойду на работу.»"
		]))
	_poi(root, "WallCrack", Vector3(-2.85, 0.0, 0.8), Vector3(0.12, 1.1, 0.45), Color(0.25, 0.3, 0.28),
		"[E] Глянуть в щель",
		PackedStringArray([
			"В трещине стены — чужой двор и бледные грибы на кирпиче.",
			"Где-то внизу кашляет дес. Воздух густой, как тряпка."
		]))
	_poi(root, "WetRags", Vector3(1.4, 0.0, 1.8), Vector3(0.7, 0.2, 0.5), Color(0.3, 0.35, 0.38),
		"[E] Потрогать тряпки",
		PackedStringArray([
			"Мокрые тряпки никогда не сохнут. Чердак дышит влагой.",
			"Запах плесени уже кажется родным."
		]))

	# Form break: spore deposits / ink streaks
	_growth_blob(root, "Growth_AtticBig", Vector3(-2.6, 0.35, 1.6), 0.28, true)
	_growth_blob(root, "Growth_AtticWall", Vector3(2.85, 1.1, 0.2), 0.18, false)
	_ink_streak(root, "InkSeam1", Vector3(0.0, 1.3, -2.45), Vector3(2.2, 0.08, 0.06))
	_ink_streak(root, "InkSeam2", Vector3(-2.95, 0.8, 0.4), Vector3(0.06, 1.1, 0.08))

	_add_player(root, Vector3(0, 0.9, 0.3))

	_mark_owners(root, root)
	var packed := PackedScene.new()
	var pack_err := packed.pack(root)
	if pack_err != OK:
		return pack_err
	return ResourceSaver.save(packed, "res://scenes/attic.tscn")


func _slab(root: Node, name: String, size: Vector3, pos: Vector3, color: Color, tex_name: String = "") -> void:
	root.add_child(_static_box(name, size, pos, color, tex_name))


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

	# Dominant: dirty purple — torches carry light; glow is purple-sick
	root.add_child(_underground_env(
		Color(0.07, 0.04, 0.08),
		Color(0.36, 0.16, 0.34),
		Color(0.28, 0.12, 0.26),
		0.02,
		0.48,
		1.05,
		1.0
	))

	# Temporary spill until torches placed after layout consts
	_add_omni(root, "PurpleSpill", Vector3(0.0, 2.5, 0.0), Color(0.5, 0.2, 0.48), 0.4, 14.0, 1.15, false)

	var stone := C_STONE.lightened(0.06)
	var stone2 := C_STONE.lightened(0.1)
	var floor_c := C_STONE.darkened(0.08)
	var ceil_c := C_INK.lightened(0.1)
	var height := 4.5

	# Wide street along X (perpendicular). Width in Z ≈ 2.6; length ≈ 16.
	var wide_z0 := -1.3
	var wide_z1 := 1.3
	var wide_x0 := -8.0
	var wide_x1 := 8.0
	_slab(root, "WideFloor", Vector3(wide_x1 - wide_x0, 0.2, wide_z1 - wide_z0), Vector3(0, -0.1, 0), floor_c, TEX_FLOOR)
	_slab(root, "WideCeil", Vector3(wide_x1 - wide_x0, 0.2, wide_z1 - wide_z0), Vector3(0, height, 0), ceil_c, TEX_INK)
	_slab(root, "WideWallSouth", Vector3(wide_x1 - wide_x0, height, 0.2), Vector3(0, height * 0.5, wide_z0), stone2, TEX_STONE_WIDE)
	# north wall with gap for narrow alley mouth
	_slab(root, "WideWallNorthL", Vector3(7.35, height, 0.2), Vector3(-4.325, height * 0.5, wide_z1), stone2, TEX_STONE_PATTERN)
	_slab(root, "WideWallNorthR", Vector3(7.35, height, 0.2), Vector3(4.325, height * 0.5, wide_z1), stone2, TEX_STONE_PATTERN)
	_slab(root, "WideWallWest", Vector3(0.2, height, wide_z1 - wide_z0), Vector3(wide_x0, height * 0.5, 0), stone, TEX_STONE_WIDE)

	# Narrow dead-end alley along +Z, ~2x longer
	var nar_x0 := -0.65
	var nar_x1 := 0.65
	var nar_z0 := wide_z1
	var nar_z1 := 13.5
	_slab(root, "NarFloor", Vector3(nar_x1 - nar_x0, 0.2, nar_z1 - nar_z0), Vector3(0, -0.1, (nar_z0 + nar_z1) * 0.5), floor_c, TEX_FLOOR)
	_slab(root, "NarCeil", Vector3(nar_x1 - nar_x0, 0.2, nar_z1 - nar_z0), Vector3(0, height, (nar_z0 + nar_z1) * 0.5), ceil_c, TEX_INK)
	_slab(root, "NarWallL", Vector3(0.2, height, nar_z1 - nar_z0), Vector3(nar_x0, height * 0.5, (nar_z0 + nar_z1) * 0.5), stone, TEX_STONE_WIDE)
	_slab(root, "NarWallR", Vector3(0.2, height, nar_z1 - nar_z0), Vector3(nar_x1, height * 0.5, (nar_z0 + nar_z1) * 0.5), stone, TEX_STONE_PATTERN)
	_slab(root, "NarDeadEnd", Vector3(1.5, height, 0.2), Vector3(0, height * 0.5, nar_z1), stone, TEX_STONE_WIDE)

	root.add_child(_static_box("Barrel1", Vector3(0.45, 0.7, 0.45), Vector3(-0.15, 0.35, nar_z1 - 0.9), Color(0.35, 0.32, 0.3), TEX_METAL))
	root.add_child(_static_box("Barrel2", Vector3(0.4, 0.6, 0.4), Vector3(0.2, 0.3, nar_z1 - 1.5), Color(0.32, 0.3, 0.28), TEX_METAL))
	root.add_child(_static_box("Barrel3", Vector3(0.35, 0.55, 0.35), Vector3(-0.2, 0.28, nar_z1 - 2.0), Color(0.3, 0.28, 0.26), TEX_METAL))
	# Mesh props over primitive clutter
	_add_mesh_prop(root, "MeshBarrelNar1", MESH_KENNEY + "detail-barrel.glb", Vector3(-0.15, 0.0, nar_z1 - 0.85), 15.0, 1.05, Vector3(0.5, 0.75, 0.5))
	_add_mesh_prop(root, "MeshBarrelNar2", MESH_KENNEY + "barrels.glb", Vector3(0.25, 0.0, nar_z1 - 1.55), -25.0, 1.0, Vector3(0.45, 0.7, 0.45))
	_add_mesh_prop(root, "MeshCrateRopesA", MESH_KENNEY + "detail-crate-ropes.glb", Vector3(-5.15, 0.0, wide_z0 + 0.55), 8.0, 1.0, Vector3(0.75, 0.6, 0.65))
	_add_mesh_prop(root, "MeshCrateSmall", MESH_KENNEY + "detail-crate-small.glb", Vector3(-4.55, 0.0, wide_z0 + 0.75), -12.0, 1.0, Vector3(0.55, 0.45, 0.5))
	_add_mesh_prop(root, "MeshOverhangS", MESH_KENNEY + "overhang.glb", Vector3(-2.0, 2.35, wide_z0 + 0.05), 0.0, 1.2, Vector3.ZERO)
	_add_mesh_prop(root, "MeshOverhangS2", MESH_KENNEY + "overhang-fence.glb", Vector3(3.2, 2.35, wide_z0 + 0.05), 0.0, 1.1, Vector3.ZERO)
	_add_mesh_prop(root, "MeshDoorShop", MESH_KENNEY + "wall-door.glb", Vector3(-7.15, 0.0, 0.0), 90.0, 1.3, Vector3(0.2, 2.2, 1.1))
	_add_mesh_prop(root, "MeshGateLib", MESH_KENNEY + "wall-gate.glb", Vector3(7.15, 0.0, 0.7), -90.0, 1.0, Vector3(0.25, 2.3, 1.2))
	_add_mesh_prop(root, "MeshClothesPulley", MESH_KENNEY + "pulley.glb", Vector3(0.0, 3.15, 0.0), 0.0, 0.8, Vector3.ZERO)

	# Ceramic / tile base of building mass (author mapping)
	var plinth_h := 0.85
	_slab(root, "WideBaseSouth", Vector3(wide_x1 - wide_x0, plinth_h, 0.22), Vector3(0, plinth_h * 0.5, wide_z0 + 0.02), C_STONE.lightened(0.12), TEX_BASE)
	_slab(root, "WideBaseNorthL", Vector3(7.35, plinth_h, 0.22), Vector3(-4.325, plinth_h * 0.5, wide_z1 - 0.02), C_STONE.lightened(0.1), TEX_BASE)
	_slab(root, "WideBaseNorthR", Vector3(7.35, plinth_h, 0.22), Vector3(4.325, plinth_h * 0.5, wide_z1 - 0.02), C_STONE.lightened(0.1), TEX_BASE)
	_slab(root, "NarBaseL", Vector3(0.22, plinth_h, nar_z1 - nar_z0), Vector3(nar_x0 + 0.02, plinth_h * 0.5, (nar_z0 + nar_z1) * 0.5), C_STONE.lightened(0.08), TEX_BASE)
	_slab(root, "NarBaseR", Vector3(0.22, plinth_h, nar_z1 - nar_z0), Vector3(nar_x1 - 0.02, plinth_h * 0.5, (nar_z0 + nar_z1) * 0.5), C_STONE.lightened(0.08), TEX_BASE)

	# Cornices / ledges break flat wall slabs
	var ledge_y := 2.55
	_slab(root, "WideLedgeS", Vector3(wide_x1 - wide_x0, 0.12, 0.28), Vector3(0, ledge_y, wide_z0 + 0.12), stone2.darkened(0.05), TEX_STONE_WIDE)
	_slab(root, "WideLedgeNL", Vector3(7.35, 0.12, 0.28), Vector3(-4.325, ledge_y, wide_z1 - 0.12), stone2.darkened(0.05), TEX_STONE_PATTERN)
	_slab(root, "WideLedgeNR", Vector3(7.35, 0.12, 0.28), Vector3(4.325, ledge_y, wide_z1 - 0.12), stone2.darkened(0.05), TEX_STONE_PATTERN)
	_slab(root, "NarLedgeL", Vector3(0.22, 0.1, nar_z1 - nar_z0), Vector3(nar_x0 + 0.08, ledge_y, (nar_z0 + nar_z1) * 0.5), stone.darkened(0.04), TEX_STONE_WIDE)
	_slab(root, "NarLedgeR", Vector3(0.22, 0.1, nar_z1 - nar_z0), Vector3(nar_x1 - 0.08, ledge_y, (nar_z0 + nar_z1) * 0.5), stone.darkened(0.04), TEX_STONE_PATTERN)
	# Buttresses / pier rhythm on wide street
	for i in range(4):
		var bx := -6.0 + float(i) * 4.0
		root.add_child(_static_box("PierS_%d" % i, Vector3(0.45, height * 0.72, 0.35), Vector3(bx, height * 0.36, wide_z0 + 0.2), stone2, TEX_STONE_WIDE))
		root.add_child(_static_box("PierN_%d" % i, Vector3(0.45, height * 0.72, 0.35), Vector3(bx, height * 0.36, wide_z1 - 0.2), stone2, TEX_STONE_PATTERN))
	# Window niches (recessed dark)
	root.add_child(_static_box("NicheW1", Vector3(0.08, 1.1, 0.7), Vector3(wide_x0 + 0.12, 2.0, 0.0), C_INK.lightened(0.06), TEX_INK))
	root.add_child(_static_box("NicheS1", Vector3(0.9, 1.0, 0.08), Vector3(-2.0, 2.05, wide_z0 + 0.12), C_INK.lightened(0.05), TEX_INK))
	root.add_child(_static_box("NicheS2", Vector3(0.9, 1.0, 0.08), Vector3(3.2, 2.1, wide_z0 + 0.12), C_INK.lightened(0.05), TEX_INK))
	# Pipes + clutter silhouette
	root.add_child(_static_box("PipeNar", Vector3(0.07, 0.07, 8.5), Vector3(nar_x1 - 0.18, 3.1, 6.5), Color(0.3, 0.28, 0.26), TEX_METAL))
	root.add_child(_static_box("PipeVert", Vector3(0.09, 2.2, 0.09), Vector3(nar_x0 + 0.2, 2.0, 9.5), Color(0.28, 0.26, 0.24), TEX_METAL))
	root.add_child(_static_box("CrateA", Vector3(0.7, 0.55, 0.55), Vector3(-5.2, 0.3, wide_z0 + 0.55), Color(0.36, 0.26, 0.16), TEX_WOOD))
	root.add_child(_static_box("CrateB", Vector3(0.55, 0.45, 0.5), Vector3(-4.6, 0.25, wide_z0 + 0.7), Color(0.34, 0.24, 0.15), TEX_WOOD))
	root.add_child(_static_box("Rubble1", Vector3(0.8, 0.22, 0.5), Vector3(5.0, 0.12, wide_z1 - 0.55), stone, TEX_STONE_WIDE))
	root.add_child(_static_box("Rubble2", Vector3(0.45, 0.18, 0.6), Vector3(0.15, 0.1, 5.5), stone2, TEX_STONE_PATTERN))
	root.add_child(_static_box("BeamNar1", Vector3(1.4, 0.14, 0.14), Vector3(0, 3.6, 5.0), Color(0.3, 0.22, 0.14), TEX_WOOD))
	root.add_child(_static_box("BeamNar2", Vector3(1.4, 0.14, 0.14), Vector3(0, 3.6, 9.0), Color(0.3, 0.22, 0.14), TEX_WOOD))

	# Torches (diegetic keys) — purple fire
	_add_torch(root, "TorchS1", Vector3(-5.2, 1.55, wide_z0 + 0.22), 0.0, 1.4)
	_add_torch(root, "TorchS2", Vector3(2.8, 1.55, wide_z0 + 0.22), 0.0, 1.25)
	_add_torch(root, "TorchN1", Vector3(-3.5, 1.55, wide_z1 - 0.22), 180.0, 1.2)
	_add_torch(root, "TorchNar1", Vector3(nar_x0 + 0.22, 1.7, 5.5), 90.0, 1.15)
	_add_torch(root, "TorchNar2", Vector3(nar_x1 - 0.22, 1.7, 10.0), -90.0, 1.2)
	# Window frames / wall holes
	_add_window_frame(root, "WinS1", Vector3(-1.2, 2.35, wide_z0 + 0.1), Vector3(0.85, 1.0, 0.08))
	_add_window_frame(root, "WinS2", Vector3(4.0, 2.4, wide_z0 + 0.1), Vector3(0.7, 0.9, 0.08))
	_add_window_frame(root, "WinNar1", Vector3(nar_x1 - 0.08, 2.3, 7.2), Vector3(0.08, 0.85, 0.55))
	# Clothesline across wide street mouth
	_add_clothesline(root, "LineWide", Vector3(-2.2, 3.3, 0.15), Vector3(2.4, 3.25, -0.2), 5)
	_add_clothesline(root, "LineNar", Vector3(nar_x0 + 0.15, 3.0, 6.0), Vector3(nar_x1 - 0.15, 3.05, 6.0), 3)
	# Extra parchment-dirty props
	root.add_child(_static_box("Sack1", Vector3(0.5, 0.4, 0.4), Vector3(4.2, 0.22, wide_z0 + 0.6), _col_parchment_dirty(0.4), TEX_PLASTER))
	root.add_child(_static_box("BoardLean", Vector3(0.08, 1.4, 0.5), Vector3(-6.5, 0.7, wide_z1 - 0.45), C_WOOD.darkened(0.08), TEX_WOOD))

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

	# POI: гамак, крысы, граффити
	_poi(root, "Hammock", Vector3(-6.5, 0.0, -0.8), Vector3(1.4, 0.15, 0.6), Color(0.45, 0.35, 0.25),
		"[E] Гамак курильщика",
		PackedStringArray([
			"Чей-то гамак натянут между трубами. Пепел на земле.",
			"Хозяина нет — только сладкий дым и тихий кашель из темноты."
		]))
	_poi(root, "RatNest", Vector3(0.15, 0.0, 12.2), Vector3(0.7, 0.25, 0.7), Color(0.28, 0.24, 0.2),
		"[E] Слушать крыс",
		PackedStringArray([
			"За бочками шуршит. Много лап.",
			"Крысы Грибного района жирные и наглые — на тебя им плевать."
		]))
	_poi(root, "SporeGraffiti", Vector3(5.5, 0.0, 1.05), Vector3(0.12, 1.4, 1.6), Color(0.45, 0.55, 0.35),
		"[E] Надпись на стене",
		PackedStringArray([
			"Споровая краска: «ВАСТЕРСА ЖРЁТ СВОИХ».",
			"Рядом детский рисунок гриба с глазами."
		]))

	# Large fungal deposits + ink seams (form break)
	_growth_blob(root, "Growth_AlleyMass", Vector3(-0.1, 0.45, 12.6), 0.42, true)
	_growth_blob(root, "Growth_AlleyCorner", Vector3(-7.2, 0.5, -0.9), 0.32, true)
	_growth_blob(root, "Growth_AlleyWall", Vector3(7.0, 1.3, 0.2), 0.22, false)
	_ink_streak(root, "InkAlley1", Vector3(0.0, 2.0, 1.25), Vector3(3.5, 0.07, 0.05))
	_ink_streak(root, "InkAlley2", Vector3(-0.6, 1.5, 7.0), Vector3(0.05, 1.4, 0.08))

	# Лавка странностей — обязательная точка маршрута
	var to_shop := _make_interactable(
		"GoShop",
		Vector3(-7.3, 0.0, 0.0),
		"[E] Лавка странностей",
		PackedStringArray([
			"За вывеской без названия — узкая дверь.",
			"Пахнет маслом, пылью и чем-то сладким."
		]),
		"res://scenes/shop.tscn"
	)
	var shop_gate := _box_mesh(Vector3(0.25, 2.4, 1.3), Color(0.4, 0.28, 0.35))
	shop_gate.position = Vector3(0, 1.2, 0)
	to_shop.add_child(shop_gate)
	var shopcol := CollisionShape3D.new()
	shopcol.name = "Collision"
	var shopshape := BoxShape3D.new()
	shopshape.size = Vector3(0.5, 2.4, 1.5)
	shopcol.shape = shopshape
	shopcol.position = Vector3(0, 1.2, 0)
	to_shop.add_child(shopcol)
	root.add_child(to_shop)

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

	# POI: трюм, кран, контрабанда
	_poi(root, "ShipHold", Vector3(-16.0, 0.0, -14.0), Vector3(1.4, 1.2, 1.0), Color(0.22, 0.25, 0.28),
		"[E] Заглянуть в трюм",
		PackedStringArray([
			"Люк приоткрыт. Внизу — темнота и запах гниющей рыбы.",
			"Кто-то оставил там бочку без марки. Лучше не спрашивать."
		]))
	_poi(root, "CraneLever", Vector3(-20.5, 0.0, -8.0), Vector3(0.4, 1.6, 0.4), Color(0.5, 0.35, 0.2),
		"[E] Рычаг крана",
		PackedStringArray([
			"Старый портовый кран. Рычаг тёплый — недавно дергали.",
			"Стрела висит над водой. Сейчас тебе его не дадут."
		]))
	_poi(root, "ContrabandBarrel", Vector3(wh.x + 4.0, 0.0, wh.z - 5.0), Vector3(0.7, 1.0, 0.7), Color(0.25, 0.2, 0.18),
		"[E] Бочка без марки",
		PackedStringArray([
			"Бочка без клейма. От неё тянет сладкой гнилью и маслом.",
			"Тон Тон орёт, чтобы «не нюхать чужое». Значит, нюхать можно."
		]))

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

	# POI: полка-заглушка (без механики чтения), капель с канала, тихий угол
	_poi(root, "OddShelf", Vector3(-9.0, 0.0, -8.0), Vector3(1.2, 2.2, 0.5), Color(0.4, 0.28, 0.18),
		"[E] Понюхать полку",
		PackedStringArray([
			"Полка пахнет пылью и старым клеем.",
			"(Карточки читать позже — пока только запах и тишина.)"
		]))
	_poi(root, "CanalDrip", Vector3(0.0, 0.0, 0.0), Vector3(0.8, 0.3, 0.8), Color(0.35, 0.4, 0.45),
		"[E] Слушать капель",
		PackedStringArray([
			"Сверху, из канала, мерно капает.",
			"Каждая капля бьёт по бумагам 5 отдела, как часы."
		]))
	_poi(root, "QuietCorner", Vector3(11.0, 0.0, -12.0), Vector3(1.0, 0.9, 1.2), Color(0.32, 0.3, 0.28),
		"[E] Тихий угол",
		PackedStringArray([
			"Здесь почти не слышно Рафа. Только шорох страниц.",
			"Хорошее место залипнуть — если бы не работа."
		]))

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

	# POI + вход в лавку странностей (после пожара тоже доступна)
	_poi(root, "OddStall", Vector3(8.2, 0.0, 6.0), Vector3(1.6, 1.4, 1.0), Color(0.45, 0.3, 0.4),
		"[E] Странный лоток",
		PackedStringArray([
			"На лотке — мутные склянки и костяные безделушки.",
			"Продавец кивает в сторону двери: «Настоящая лавка — там.»"
		]))
	var to_shop_fire := _make_interactable(
		"GoShopFromStreet",
		Vector3(8.2, 0.0, 8.5),
		"[E] В лавку странностей",
		PackedStringArray([
			"Пока все смотрят на пожар, дверь лавки приоткрыта.",
			"Внутри тихо — как будто огонь их не касается."
		]),
		"res://scenes/shop.tscn"
	)
	var sg := _box_mesh(Vector3(1.6, 2.2, 0.35), Color(0.4, 0.28, 0.35))
	sg.position = Vector3(0, 1.1, 0)
	to_shop_fire.add_child(sg)
	var sgc := CollisionShape3D.new()
	sgc.name = "Collision"
	var sgs := BoxShape3D.new()
	sgs.size = Vector3(1.8, 2.2, 0.5)
	sgc.shape = sgs
	sgc.position = Vector3(0, 1.1, 0)
	to_shop_fire.add_child(sgc)
	root.add_child(to_shop_fire)

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

func _save_shop() -> Error:
	var root := Node3D.new()
	root.name = "Shop"

	# Warm-odd shop; sick filter mild — walls are plaster/wood, not flesh albedo
	root.add_child(_underground_env(
		Color(0.14, 0.1, 0.11),
		Color(0.48, 0.38, 0.34),
		Color(0.28, 0.18, 0.22),
		0.012,
		0.9,
		1.08,
		0.7
	))
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0, 3.2, 0)
	lamp.light_color = Color(1.0, 0.78, 0.55)
	lamp.light_energy = 1.45
	lamp.omni_range = 11
	lamp.shadow_enabled = true
	root.add_child(lamp)
	var lamp2 := OmniLight3D.new()
	lamp2.position = Vector3(-2.5, 2.4, -2.0)
	lamp2.light_color = Color(0.55, 0.3, 0.5)
	lamp2.light_energy = 0.45
	lamp2.omni_range = 5.0
	root.add_child(lamp2)

	var wood := Color(0.38, 0.26, 0.18)
	var plaster := C_PARCHMENT.darkened(0.08)
	root.add_child(_static_box("Floor", Vector3(10, 0.2, 8), Vector3(0, -0.1, 0), Color(0.28, 0.22, 0.18), TEX_WOOD))
	root.add_child(_static_box("Ceil", Vector3(10, 0.2, 8), Vector3(0, 3.6, 0), Color(0.22, 0.18, 0.16), TEX_PLASTER))
	root.add_child(_static_box("WallB", Vector3(10, 3.6, 0.25), Vector3(0, 1.8, -4), plaster, TEX_PLASTER))
	root.add_child(_static_box("WallF", Vector3(10, 3.6, 0.25), Vector3(0, 1.8, 4), plaster, TEX_PLASTER))
	root.add_child(_static_box("WallL", Vector3(0.25, 3.6, 8), Vector3(-5, 1.8, 0), plaster, TEX_PLASTER))
	root.add_child(_static_box("WallR", Vector3(0.25, 3.6, 8), Vector3(5, 1.8, 0), plaster, TEX_PLASTER))
	root.add_child(_static_box("Counter", Vector3(6.5, 1.0, 1.0), Vector3(0, 0.5, -1.2), wood, TEX_WOOD))
	root.add_child(_static_box("ShelfBack", Vector3(7.0, 2.2, 0.4), Vector3(0, 2.0, -3.5), wood, TEX_WOOD))
	root.add_child(_static_box("ShelfSide", Vector3(0.4, 2.0, 3.5), Vector3(-4.4, 1.9, 0.2), wood, TEX_WOOD))
	# Mushrooms as props only
	root.add_child(_mushroom("ShopMush1", Vector3(-4.3, 1.1, -2.8), 1.1))
	root.add_child(_mushroom("ShopMush2", Vector3(4.2, 0.9, -3.0), 0.9))
	_growth_blob(root, "ShopGrowth", Vector3(-4.6, 0.4, 1.5), 0.22, true)

	_poi(root, "ShopKeeperNote", Vector3(0.0, 0.0, -2.2), Vector3(0.5, 0.15, 0.4), Color(0.55, 0.45, 0.3),
		"[E] Записка на прилавке",
		PackedStringArray([
			"«Бери одно. Плата — история. Пропуск — в придачу.»",
			"Почерк дрожит. Хозяина не видно — только шорох за полкой."
		]))

	_shop_choice(root, "BuyPotion", Vector3(-2.2, 0.0, -0.2), "potion",
		"[E] Мутный эликсир",
		PackedStringArray([
			"Склянка тёплая. Жидкость медленно переливается сама.",
			"Тебе суют бумажный пропуск: «В Центральную — пока не передумали.»",
			"(3D лавки автор пришлёт позже. Сейчас — заглушка выбора.)"
		]), Color(0.35, 0.55, 0.4))
	_shop_choice(root, "BuyTrinket", Vector3(0.0, 0.0, -0.2), "trinket",
		"[E] Костяная безделушка",
		PackedStringArray([
			"Тяжёлая штуковина. На ощупь — как чужой сустав.",
			"Вместе с ней — пропуск в Центральную библиотеку.",
			"(Зарплатные исходы и торг — позже, чтобы не тормозить плейтест.)"
		]), Color(0.7, 0.65, 0.5))
	_shop_choice(root, "BuyFood", Vector3(2.2, 0.0, -0.2), "food",
		"[E] Сладкий свёрток",
		PackedStringArray([
			"Пахнет карамелью и плесенью одновременно.",
			"Продавец шепчет: «Это и есть плата. А вот пропуск.»",
			"Дорога к Центральной библиотеке открыта — на заглушку."
		]), Color(0.55, 0.35, 0.28))

	var back := _make_interactable(
		"ShopExit",
		Vector3(0.0, 0.0, 3.3),
		"[E] Выйти в переулки",
		PackedStringArray(["Колокольчик над дверью не звенит — только глухой щелчок."]),
		"res://scenes/alley.tscn"
	)
	var bm := _box_mesh(Vector3(1.6, 2.2, 0.3), Color(0.3, 0.25, 0.28))
	bm.position = Vector3(0, 1.1, 0)
	back.add_child(bm)
	var bc := CollisionShape3D.new()
	bc.name = "Collision"
	var bs := BoxShape3D.new()
	bs.size = Vector3(1.8, 2.2, 0.5)
	bc.shape = bs
	bc.position = Vector3(0, 1.1, 0)
	back.add_child(bc)
	root.add_child(back)

	_add_player(root, Vector3(0, 0.9, 2.0))
	_mark_owners(root, root)
	var packed := PackedScene.new()
	var err := packed.pack(root)
	if err != OK:
		return err
	return ResourceSaver.save(packed, "res://scenes/shop.tscn")


func _save_central_library() -> Error:
	# Заглушка: Центральная библиотека ≠ Конгрегационная (Раф)
	var root := Node3D.new()
	root.name = "CentralLibrary"

	var world_env := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.16, 0.17, 0.2)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.45, 0.48, 0.55)
	env.ambient_light_energy = 0.85
	world_env.environment = env
	root.add_child(world_env)
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0, 8, 0)
	lamp.light_color = Color(0.85, 0.9, 1.0)
	lamp.light_energy = 1.3
	lamp.omni_range = 40
	root.add_child(lamp)

	var stone := Color(0.45, 0.48, 0.52)
	var wood := Color(0.32, 0.28, 0.24)
	# гораздо больше Конгрегационной
	root.add_child(_static_box("Floor", Vector3(48, 0.2, 60), Vector3(0, -0.1, 0), Color(0.3, 0.32, 0.36)))
	root.add_child(_static_box("Ceil", Vector3(48, 0.3, 60), Vector3(0, 14, 0), Color(0.22, 0.24, 0.28)))
	root.add_child(_static_box("WallB", Vector3(48, 14, 0.4), Vector3(0, 7, -30), stone))
	root.add_child(_static_box("WallF", Vector3(48, 14, 0.4), Vector3(0, 7, 30), stone))
	root.add_child(_static_box("WallL", Vector3(0.4, 14, 60), Vector3(-24, 7, 0), stone))
	root.add_child(_static_box("WallR", Vector3(0.4, 14, 60), Vector3(24, 7, 0), stone))
	for z in range(-24, 25, 8):
		root.add_child(_static_box("AisleL_%d" % z, Vector3(6, 8, 1.2), Vector3(-14, 4, z), wood))
		root.add_child(_static_box("AisleR_%d" % z, Vector3(6, 8, 1.2), Vector3(14, 4, z), wood))
	root.add_child(_static_box("Mezz", Vector3(40, 0.3, 20), Vector3(0, 7.5, -5), Color(0.35, 0.33, 0.3)))

	_poi(root, "CentralDesk", Vector3(0.0, 0.0, -20.0), Vector3(4.0, 1.2, 1.5), Color(0.4, 0.32, 0.25),
		"[E] Стол регистратора",
		PackedStringArray([
			"Центральная библиотека. Здесь тихо иначе — холодно и огромно.",
			"Это не Конгрегационная и не Раф. Другой масштаб, другие правила.",
			"(Дальше — заглушка. Сюжетный текст автора позже.)"
		]))
	_poi(root, "PassCheck", Vector3(0.0, 0.0, -16.0), Vector3(1.0, 1.6, 0.4), Color(0.55, 0.5, 0.35),
		"[E] Показать пропуск",
		PackedStringArray([
			"Охранник кивает на бумажку из лавки.",
			"«Проходи. Только полок не трогай без запроса.»"
		]))

	var back := _make_interactable(
		"LeaveCentral",
		Vector3(0.0, 0.0, 26.0),
		"[E] Уйти в город",
		PackedStringArray(["Двери Центральной закрываются без скрипа — слишком дорогие петли."]),
		"res://scenes/alley.tscn"
	)
	var bm2 := _box_mesh(Vector3(2.4, 2.6, 0.4), Color(0.3, 0.32, 0.36))
	bm2.position = Vector3(0, 1.3, 0)
	back.add_child(bm2)
	var bc2 := CollisionShape3D.new()
	bc2.name = "Collision"
	var bs2 := BoxShape3D.new()
	bs2.size = Vector3(2.6, 2.6, 0.6)
	bc2.shape = bs2
	bc2.position = Vector3(0, 1.3, 0)
	back.add_child(bc2)
	root.add_child(back)

	_add_player(root, Vector3(0, 0.9, -12))
	_mark_owners(root, root)
	var packed := PackedScene.new()
	var err := packed.pack(root)
	if err != OK:
		return err
	return ResourceSaver.save(packed, "res://scenes/central_library.tscn")



func _save_playtest() -> Error:
	var root := Node3D.new()
	root.name = "Playtest"
	root.add_child(_underground_env(
		Color(0.06, 0.06, 0.08),
		Color(0.22, 0.22, 0.28),
		Color(0.18, 0.18, 0.22),
		0.01,
		0.55,
		1.0,
		0.9
	))
	_add_omni(root, "Fill", Vector3(0, 3.5, 0), Color(0.75, 0.72, 0.7), 0.55, 18.0, 1.0, false)

	var floor_c := C_STONE.lightened(0.08)
	var wall_c := C_STONE.lightened(0.02)
	var accent := C_PURPLE.lightened(0.1)
	# Arena box ~14x10
	_slab(root, "Floor", Vector3(14, 0.2, 10), Vector3(0, -0.1, 0), floor_c, TEX_FLOOR)
	_slab(root, "Ceil", Vector3(14, 0.2, 10), Vector3(0, 4.2, 0), C_INK.lightened(0.12), TEX_INK)
	_slab(root, "WallN", Vector3(14, 4.2, 0.25), Vector3(0, 2.1, -5.0), wall_c, TEX_STONE)
	_slab(root, "WallS", Vector3(14, 4.2, 0.25), Vector3(0, 2.1, 5.0), wall_c, TEX_STONE)
	_slab(root, "WallW", Vector3(0.25, 4.2, 10), Vector3(-7.0, 2.1, 0), wall_c, TEX_STONE)
	_slab(root, "WallE", Vector3(0.25, 4.2, 10), Vector3(7.0, 2.1, 0), wall_c, TEX_STONE)

	# Labeled stations (stubs for upcoming systems)
	var stations := [
		{"n": "PadMirror", "p": Vector3(-5.0, 0.0, -3.0), "c": accent, "t": "[E] Станция: Зеркало", "l": PackedStringArray(["Интерактивное зеркало слева — станция MirrorStation.", "Имя + силуэт: худой / обычный / тяжёлый."])},
		{"n": "PadDiary", "p": Vector3(-2.5, 0.0, -3.0), "c": C_PARCHMENT, "t": "[E] Станция: Дневник", "l": PackedStringArray(["Записи дня, флаги slice.", "Пока заглушка."])},
		{"n": "PadInv", "p": Vector3(0.0, 0.0, -3.0), "c": C_WOOD.lightened(0.1), "t": "[E] Станция: Инвентарь / глоссарий", "l": PackedStringArray(["Как в HTML: вещи + термины.", "Пока заглушка."])},
		{"n": "PadLock", "p": Vector3(2.5, 0.0, -3.0), "c": Color(0.35, 0.32, 0.28), "t": "[E] Станция: Взлом (слоты)", "l": PackedStringArray(["3 спина; цель — 2/3/4/5 подряд.", "1 замораживается; ловкость +1 попытка."])},
		{"n": "PadSkills", "p": Vector3(5.0, 0.0, -3.0), "c": C_PURPLE_GLOW.darkened(0.2), "t": "[E] Станция: Навыки", "l": PackedStringArray(["Мощь / Разум / Моторика / Стержень.", "Пока только подписи."])},
		{"n": "PadCombat", "p": Vector3(-4.0, 0.0, 2.5), "c": Color(0.45, 0.18, 0.16), "t": "[E] Станция: Бой", "l": PackedStringArray(["Тут манекен + оружие + FX ударов.", "Бой подключим отдельным OK."])},
		{"n": "PadMove", "p": Vector3(0.0, 0.0, 2.5), "c": Color(0.2, 0.35, 0.4), "t": "[E] Станция: Движение", "l": PackedStringArray(["Фаза 1: WASD, Shift бег, Ctrl присед, Пробел прыжок.", "Платформы справа и низкий лаз в центре."])},
		{"n": "PadFX", "p": Vector3(4.0, 0.0, 2.5), "c": Color(0.55, 0.45, 0.2), "t": "[E] Станция: FX", "l": PackedStringArray(["Pixel effects gigapack — сюда тестовые вспышки.", "Пока заглушка."])},
	]
	for s in stations:
		_poi(root, str(s["n"]), s["p"], Vector3(1.2, 0.15, 1.2), s["c"], str(s["t"]), s["l"])
		# tall marker post
		root.add_child(_static_box(str(s["n"]) + "_Post", Vector3(0.12, 1.6, 0.12), s["p"] + Vector3(0, 0.9, -0.55), s["c"]))

	# Phase 2 mirror station (interactive, not just dialogue stub)
	var mpad := StaticBody3D.new()
	mpad.name = "MirrorStation"
	mpad.position = Vector3(-5.0, 0.0, -3.0)
	mpad.set_script(load("res://scripts/mirror_interactable.gd"))
	mpad.set("prompt_text", "[E] Станция: Зеркало")
	var mpad_mesh := _box_mesh(Vector3(1.2, 0.15, 1.2), accent)
	mpad_mesh.position = Vector3(0, 0.08, 0)
	mpad.add_child(mpad_mesh)
	var mframe := _box_mesh(Vector3(0.08, 1.4, 0.7), Color(0.55, 0.6, 0.65))
	mframe.position = Vector3(0, 0.95, -0.4)
	mpad.add_child(mframe)
	var mcol := CollisionShape3D.new()
	mcol.name = "Collision"
	var mshape := BoxShape3D.new()
	mshape.size = Vector3(1.3, 1.6, 1.3)
	mcol.shape = mshape
	mcol.position = Vector3(0, 0.8, 0)
	mpad.add_child(mcol)
	root.add_child(mpad)

	# Movement course (phase 1)
	root.add_child(_static_box("JumpBlock1", Vector3(1.4, 0.45, 1.4), Vector3(2.2, 0.22, 1.0), C_STONE.lightened(0.12), TEX_STONE))
	root.add_child(_static_box("JumpBlock2", Vector3(1.2, 0.9, 1.2), Vector3(4.0, 0.45, 1.2), C_STONE.lightened(0.08), TEX_STONE))
	root.add_child(_static_box("JumpBlock3", Vector3(1.0, 1.4, 1.0), Vector3(5.6, 0.7, 1.4), C_STONE.lightened(0.05), TEX_STONE))
	# Low crawl tunnel
	root.add_child(_static_box("CrawlRoof", Vector3(3.5, 0.2, 1.6), Vector3(0.0, 1.15, 3.5), C_WOOD.darkened(0.05), TEX_WOOD))
	root.add_child(_static_box("CrawlWallL", Vector3(0.2, 1.1, 1.6), Vector3(-1.75, 0.55, 3.5), C_STONE, TEX_STONE))
	root.add_child(_static_box("CrawlWallR", Vector3(0.2, 1.1, 1.6), Vector3(1.75, 0.55, 3.5), C_STONE, TEX_STONE))
	_poi(root, "PadMoveCheck", Vector3(0.0, 0.0, 1.2), Vector3(1.4, 0.12, 0.8), Color(0.2, 0.4, 0.45),
		"[E] Чеклист движения",
		PackedStringArray([
			"Проверь: WASD, Shift-бег, Ctrl-присед под низкой крышей, прыжок по блокам.",
			"Подсказка управления всегда внизу экрана."
		]))

	# Dummy combat block
	root.add_child(_static_box("Mannequin", Vector3(0.55, 1.7, 0.35), Vector3(-4.0, 0.85, 3.6), Color(0.55, 0.5, 0.45), TEX_PLASTER))
	_add_mesh_prop(root, "WeaponRack", MESH_KENNEY + "detail-crate.glb", Vector3(-5.2, 0.0, 3.4), 0.0, 1.0, Vector3(0.7, 0.5, 0.6))

	# Back to attic
	var back := _make_interactable(
		"BackAttic",
		Vector3(0.0, 0.0, 4.4),
		"[E] Вернуться на чердак",
		PackedStringArray(["Хватит песочницы — обратно в каплю." ]),
		"res://scenes/attic.tscn"
	)
	var back_m := _box_mesh(Vector3(1.2, 2.0, 0.2), Color(0.25, 0.3, 0.38))
	back_m.position = Vector3(0, 1.0, 0)
	back.add_child(back_m)
	var bcol := CollisionShape3D.new()
	bcol.name = "Collision"
	var bshape := BoxShape3D.new()
	bshape.size = Vector3(1.4, 2.1, 0.5)
	bcol.shape = bshape
	bcol.position = Vector3(0, 1.05, 0)
	back.add_child(bcol)
	root.add_child(back)

	_add_player(root, Vector3(0.0, 0.9, 0.0))
	_mark_owners(root, root)
	var packed := PackedScene.new()
	var pack_err := packed.pack(root)
	if pack_err != OK:
		return pack_err
	return ResourceSaver.save(packed, "res://scenes/playtest.tscn")

