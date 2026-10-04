extends StaticBody3D

@export var prompt_text: String = "[E] Тест FX"
@export var fx_kind: String = "boom"
@export var fx_scale: float = 1.8

var _kinds := ["hit_spark", "boom_orange", "smoke_white", "hit_white"]
var _idx := 0


func _ready() -> void:
	add_to_group("interactable")
	collision_layer = 1
	collision_mask = 0


func get_prompt() -> String:
	return "%s (%s)" % [prompt_text, _kinds[_idx]]


func interact() -> void:
	var kind := str(_kinds[_idx])
	_idx = (_idx + 1) % _kinds.size()
	var fx = load("res://scripts/fx_burst.gd")
	if fx and fx.has_method("spawn"):
		fx.spawn(get_tree().current_scene, kind, global_position + Vector3(0, 1.2, 0), fx_scale)
	var dlg := get_node_or_null("/root/Dialogue")
	if dlg and dlg.has_method("start"):
		dlg.call("start", PackedStringArray(["FX: %s" % kind]))
