extends StaticBody3D

@export var prompt_text: String = "[E] Листать дневник"


func _ready() -> void:
	add_to_group("interactable")
	collision_layer = 1
	collision_mask = 0


func get_prompt() -> String:
	var gs := get_node_or_null("/root/GameState")
	if gs:
		var notes: Array = gs.get("diary_notes")
		var n := notes.size() if notes else 0
		if n > 1:
			return "[E] Дневник (%d записей)" % n
	return prompt_text


func interact() -> void:
	var ui := get_node_or_null("/root/Diary")
	if ui == null:
		return
	if ui.has_method("is_open") and bool(ui.call("is_open")):
		return
	if ui.has_method("open_diary"):
		ui.call("open_diary")
