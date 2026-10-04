extends StaticBody3D

@export var prompt_text: String = "[E] Взломать"
@export var open_prompt: String = "[E] Уже открыто"
@export var lock_id: String = "lock"
@export var lock_title: String = "Замок"
@export var success_lines: PackedStringArray = PackedStringArray()
@export var practice: bool = false


func _ready() -> void:
	add_to_group("interactable")
	collision_layer = 1
	collision_mask = 0


func get_prompt() -> String:
	var gs := get_node_or_null("/root/GameState")
	if not practice and gs and gs.has_method("is_lock_open") and bool(gs.call("is_lock_open", lock_id)):
		return open_prompt
	var attempts := 3
	if gs and gs.has_method("lockpick_max_attempts"):
		attempts = int(gs.call("lockpick_max_attempts"))
	return "%s (попыток: %d)" % [prompt_text, attempts]


func interact() -> void:
	var ui := get_node_or_null("/root/Lockpick")
	if ui == null:
		return
	if ui.has_method("is_open") and bool(ui.call("is_open")):
		return
	var gs := get_node_or_null("/root/GameState")
	if not practice and gs and gs.has_method("is_lock_open") and bool(gs.call("is_lock_open", lock_id)):
		var dlg := get_node_or_null("/root/Dialogue")
		if dlg and dlg.has_method("start"):
			dlg.call("start", PackedStringArray(["Замок уже открыт — створки поддаются."]))
		return
	if ui.has_method("open_lockpick"):
		ui.call("open_lockpick", lock_id, lock_title, success_lines, practice)
