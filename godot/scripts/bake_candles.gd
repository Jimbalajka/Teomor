extends SceneTree

const DIR := "res://assets/meshes/props/propslite/"

func _init() -> void:
	var files: PackedStringArray = PackedStringArray(["Candle_01.fbx", "Candle_02.fbx", "Candle_03.fbx", "Fire_01.fbx"])
	for i in range(files.size()):
		var fn: String = files[i]
		var src_res: String = DIR + fn
		var dst_res: String = DIR + fn.get_basename() + ".glb"
		var src: String = ProjectSettings.globalize_path(src_res)
		var dst: String = ProjectSettings.globalize_path(dst_res)
		if not FileAccess.file_exists(src):
			push_warning("missing " + src_res)
			continue
		var fdoc := FBXDocument.new()
		var fstate := FBXState.new()
		var aerr: Error = fdoc.append_from_file(src, fstate)
		if aerr != OK:
			push_warning("fbx fail " + src_res)
			continue
		var werr: Error = GLTFDocument.new().write_to_filesystem(fstate, dst)
		if werr != OK:
			push_warning("write fail " + dst_res)
			continue
		print("OK ", dst_res)
	print("BAKE_CANDLES_OK")
	quit()
