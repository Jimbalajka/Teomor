extends StaticBody3D

@export var prompt_text: String = "[E] Поднять"
@export var dialogue_lines: PackedStringArray = []
@export var item_id: String = ""
@export var item_name: String = ""
@export var item_description: String = ""
@export var consumable: bool = false
@export var is_quest_item: bool = false
@export var unlock_glossary: PackedStringArray = []
@export var taken_prompt: String = "[E] Пусто"

var _taken: bool = false


func _ready() -> void:
	add_to_group("interactable")
	collision_layer = 1
	collision_mask = 0
	var gs := get_node_or_null("/root/GameState")
	if gs and gs.has_method("has_item") and not item_id.is_empty():
		if bool(gs.call("has_item", item_id)):
			_taken = true


func get_prompt() -> String:
	if _taken:
		return taken_prompt
	return prompt_text


func interact() -> void:
	if _taken:
		var dlg0 := get_node_or_null("/root/Dialogue")
		if dlg0 and dlg0.has_method("start"):
			dlg0.call("start", PackedStringArray(["Здесь уже ничего нет."]))
		return
	var gs := get_node_or_null("/root/GameState")
	var ok := false
	if gs:
		var item := {
			"id": item_id,
			"name": item_name if not item_name.is_empty() else item_id,
			"description": item_description,
			"consumable": consumable,
		}
		if is_quest_item and gs.has_method("add_quest_item"):
			ok = bool(gs.call("add_quest_item", item))
		elif gs.has_method("add_item"):
			ok = bool(gs.call("add_item", item))
		if gs.has_method("unlock_glossary_many") and unlock_glossary.size() > 0:
			gs.call("unlock_glossary_many", unlock_glossary)
	var lines: PackedStringArray = dialogue_lines.duplicate()
	if ok:
		_taken = true
		if lines.is_empty():
			lines = PackedStringArray(["Взято: %s." % (item_name if not item_name.is_empty() else item_id)])
	elif gs and gs.has_method("has_item") and bool(gs.call("has_item", item_id)):
		_taken = true
		lines = PackedStringArray(["Уже есть при себе."])
	else:
		lines = PackedStringArray(["Карманы полны — или вещь не берётся."])
	var dlg := get_node_or_null("/root/Dialogue")
	if dlg and dlg.has_method("start") and not lines.is_empty():
		dlg.call("start", lines)
