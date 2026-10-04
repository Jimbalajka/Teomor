extends StaticBody3D

@export var prompt_text: String = "[E] Навыки"


func _ready() -> void:
	add_to_group("interactable")
	collision_layer = 1
	collision_mask = 0


func get_prompt() -> String:
	var gs := get_node_or_null("/root/GameState")
	if gs and gs.has_method("skills_status_line"):
		var pts := int(gs.get("skill_points"))
		return "[E] Навыки (очки: %d)" % pts
	return prompt_text


func interact() -> void:
	var ui := get_node_or_null("/root/Skills")
	if ui == null:
		return
	if ui.has_method("is_open") and bool(ui.call("is_open")):
		return
	if ui.has_method("open_skills"):
		ui.call("open_skills")
