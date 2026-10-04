extends StaticBody3D

@export var prompt_text: String = "[E] Инвентарь / глоссарий"


func _ready() -> void:
	add_to_group("interactable")
	collision_layer = 1
	collision_mask = 0


func get_prompt() -> String:
	var gs := get_node_or_null("/root/GameState")
	if gs:
		var n := 0
		var inv: Array = gs.get("inventory")
		var q: Array = gs.get("quest_items")
		var g: Dictionary = gs.get("glossary")
		n = (inv.size() if inv else 0) + (q.size() if q else 0)
		var gk := g.size() if g else 0
		return "[E] Инвентарь (%d) / глоссарий (%d)" % [n, gk]
	return prompt_text


func interact() -> void:
	var ui := get_node_or_null("/root/Inventory")
	if ui == null:
		return
	if ui.has_method("is_open") and bool(ui.call("is_open")):
		return
	if ui.has_method("open_inventory"):
		ui.call("open_inventory")
