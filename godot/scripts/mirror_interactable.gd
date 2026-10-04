extends StaticBody3D

@export var prompt_text: String = "[E] Посмотреть в зеркало"


func _ready() -> void:
	add_to_group("interactable")
	collision_layer = 1
	collision_mask = 0


func get_prompt() -> String:
	var gs := get_node_or_null("/root/GameState")
	if gs and gs.has_method("has_mirror_setup") and bool(gs.call("has_mirror_setup")):
		return "[E] Снова глянуть в зеркало"
	return prompt_text


func interact() -> void:
	var ui := get_node_or_null("/root/NameEntry")
	if ui == null:
		return
	if ui.has_method("is_open") and bool(ui.call("is_open")):
		return
	if ui.has_method("open_mirror"):
		ui.call("open_mirror")
