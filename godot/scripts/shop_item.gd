extends StaticBody3D

## Выбор в лавке странностей: даёт сюжетный «пропуск»-заглушку.
@export var prompt_text: String = "[E] Выбрать"
@export var dialogue_lines: PackedStringArray = []
@export var choice_id: String = ""
@export var change_scene_to: String = ""


func _ready() -> void:
	add_to_group("interactable")
	collision_layer = 1
	collision_mask = 0


func get_prompt() -> String:
	return prompt_text


func _game_state() -> Node:
	return get_node_or_null("/root/GameState")


func interact() -> void:
	var gs := _game_state()
	if gs:
		gs.set("shop_choice", choice_id)
		gs.set("has_central_pass", true)
		if gs.has_method("add_note"):
			gs.call("add_note", "shop_choice", "В лавке взял: %s. Пропуск на Центральную — в кармане, пока заглушка." % choice_id)
		if gs.has_method("set_quest_status"):
			gs.call("set_quest_status", "quest_work", "Пропуск из лавки")
	var dlg := get_node_or_null("/root/Dialogue")
	if not dialogue_lines.is_empty() and dlg and dlg.has_method("start"):
		dlg.call("start", dialogue_lines)
		if change_scene_to != "":
			await _wait_dialogue_closed(dlg)
			_go()
		return
	if change_scene_to != "":
		_go()


func _go() -> void:
	if change_scene_to == "":
		return
	var gs := _game_state()
	if gs and gs.has_method("mark_scene"):
		gs.call("mark_scene", change_scene_to)
	get_tree().change_scene_to_file(change_scene_to)


func _wait_dialogue_closed(dlg: Node) -> void:
	while dlg and dlg.has_method("is_open") and dlg.call("is_open"):
		await get_tree().process_frame
