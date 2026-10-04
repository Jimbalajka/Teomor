extends Node3D

## Одноразовая билборд-вспышка из res://assets/fx/<kind>/frame_XX.png

const FX_ROOT := "res://assets/fx/"
const KINDS := {
	"hit": "hit_spark",
	"hit_spark": "hit_spark",
	"hit_white": "hit_white",
	"boom": "boom_orange",
	"boom_orange": "boom_orange",
	"smoke": "smoke_white",
	"smoke_white": "smoke_white",
}


static func spawn(parent: Node, kind: String, pos: Vector3, scale: float = 1.0) -> void:
	if parent == null:
		return
	var node := Node3D.new()
	node.set_script(load("res://scripts/fx_burst.gd"))
	parent.add_child(node)
	node.global_position = pos
	if node.has_method("play"):
		node.call("play", kind, scale)


func play(kind: String = "hit", uniform_scale: float = 1.0, modulate: Color = Color(1, 1, 1, 1)) -> void:
	var folder := str(KINDS.get(kind, "hit_spark"))
	var frames := _load_frames(folder)
	if frames.is_empty():
		queue_free()
		return
	var spr := AnimatedSprite3D.new()
	spr.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	spr.pixel_size = 0.02 * uniform_scale
	spr.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	var mod := modulate
	if kind in ["hit", "hit_spark", "hit_purple"]:
		# удар — в пурпур якоря стиля
		mod = Color(0.72, 0.28, 1.0, 1.0) if modulate == Color(1, 1, 1, 1) else modulate
	elif kind in ["hit_white"]:
		mod = Color(0.85, 0.55, 1.0, 1.0) if modulate == Color(1, 1, 1, 1) else modulate
	spr.modulate = mod
	var sf := SpriteFrames.new()
	sf.add_animation("fx")
	sf.set_animation_speed("fx", 12.0)
	sf.set_animation_loop("fx", false)
	for tex in frames:
		sf.add_frame("fx", tex)
	spr.sprite_frames = sf
	add_child(spr)
	spr.play("fx")
	spr.animation_finished.connect(func(): queue_free())
	# safety timeout
	var t := get_tree().create_timer(1.2)
	t.timeout.connect(func(): if is_instance_valid(self): queue_free())


func _load_frames(folder: String) -> Array:
	var out: Array = []
	var dir_path := FX_ROOT + folder
	var da := DirAccess.open(dir_path)
	if da == null:
		# headless / missing import: try numbered paths
		for i in range(16):
			var p := "%s/frame_%02d.png" % [dir_path, i]
			if ResourceLoader.exists(p) or FileAccess.file_exists(ProjectSettings.globalize_path(p)):
				var tex := _load_tex(p)
				if tex:
					out.append(tex)
			else:
				break
		return out
	var names: PackedStringArray = da.get_files()
	names.sort()
	for fn in names:
		if not str(fn).begins_with("frame_") or not str(fn).ends_with(".png"):
			continue
		var tex := _load_tex(dir_path + "/" + str(fn))
		if tex:
			out.append(tex)
	return out


func _load_tex(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var res := load(path)
		if res is Texture2D:
			return res
	var img := Image.new()
	var disk := ProjectSettings.globalize_path(path) if path.begins_with("res://") else path
	var err := img.load(disk)
	if err != OK:
		err = img.load(path)
	if err != OK:
		return null
	return ImageTexture.create_from_image(img)
