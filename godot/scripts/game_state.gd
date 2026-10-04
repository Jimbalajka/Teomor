extends Node

## Минимальное состояние для плейтеста / slice.
var player_name: String = ""
var appearance_id: String = ""  # gaunt | common | stocky
var input_locked: bool = false
var shop_choice: String = ""  # potion | trinket | food
var has_central_pass: bool = false

const APPEARANCE_LABELS := {
	"gaunt": "Худой, впалый",
	"common": "Обычный дес",
	"stocky": "Тяжёлый, узловатый",
}


func set_player_name(value: String) -> void:
	player_name = value.strip_edges()
	if player_name.is_empty():
		player_name = "Безымянный"


func set_appearance(value: String) -> void:
	if APPEARANCE_LABELS.has(value):
		appearance_id = value
	else:
		appearance_id = "common"


func appearance_label() -> String:
	if appearance_id.is_empty():
		return "не разглядел себя"
	return str(APPEARANCE_LABELS.get(appearance_id, appearance_id))


func has_mirror_setup() -> bool:
	return not player_name.is_empty() and not appearance_id.is_empty()


func display_name() -> String:
	if player_name.is_empty():
		return "ты"
	return player_name
