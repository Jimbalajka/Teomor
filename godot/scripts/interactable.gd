extends StaticBody3D

@export var prompt_text: String = "[E] Взаимодействовать"
@export var dialogue_lines: PackedStringArray = []
@export var change_scene_to: String = ""


func _ready() -> void:
	add_to_group("interactable")
	collision_layer = 1
	collision_mask = 0


func get_prompt() -> String:
	return prompt_text


func _dialogue() -> Node:
	return get_node_or_null("/root/Dialogue")


func interact() -> void:
	var dlg := _dialogue()
	if not dialogue_lines.is_empty() and dlg and dlg.has_method("start"):
		dlg.call("start", dialogue_lines)
		if change_scene_to != "":
			await _wait_dialogue_closed(dlg)
			_go()
		return
	if change_scene_to != "":
		_go()


func _wait_dialogue_closed(dlg: Node) -> void:
	while dlg and dlg.has_method("is_open") and dlg.call("is_open"):
		await get_tree().process_frame


func _go() -> void:
	if change_scene_to != "":
		var gs := get_node_or_null("/root/GameState")
		if gs and gs.has_method("mark_scene"):
			gs.call("mark_scene", change_scene_to)
		get_tree().change_scene_to_file(change_scene_to)
