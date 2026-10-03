extends Node

## Минимальное состояние для плейтеста.
var player_name: String = ""
var input_locked: bool = false
var shop_choice: String = ""  # potion | trinket | food
var has_central_pass: bool = false


func set_player_name(value: String) -> void:
	player_name = value.strip_edges()
	if player_name.is_empty():
		player_name = "Безымянный"


func display_name() -> String:
	if player_name.is_empty():
		return "ты"
	return player_name
