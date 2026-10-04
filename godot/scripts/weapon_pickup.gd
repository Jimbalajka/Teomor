extends StaticBody3D

@export var prompt_text: String = "[E] Взять оружие"
@export var weapon_id: String = "axe"
@export var weapon_name: String = "Топор"
@export var weapon_damage: int = 4


func _ready() -> void:
	add_to_group("interactable")
	collision_layer = 1
	collision_mask = 0


func get_prompt() -> String:
	var gs := get_node_or_null("/root/GameState")
	if gs and str(gs.get("weapon_id")) == weapon_id:
		return "[E] Уже в руках: %s" % weapon_name
	return "%s (%s, +%d)" % [prompt_text, weapon_name, weapon_damage]


func interact() -> void:
	var gs := get_node_or_null("/root/GameState")
	if gs and gs.has_method("equip_weapon"):
		gs.call("equip_weapon", weapon_id, weapon_name, weapon_damage)
	elif gs:
		gs.set("weapon_id", weapon_id)
		gs.set("weapon_name", weapon_name)
		gs.set("weapon_damage", weapon_damage)
	var dlg := get_node_or_null("/root/Dialogue")
	if dlg and dlg.has_method("start"):
		dlg.call("start", PackedStringArray([
			"В руках: %s." % weapon_name,
			"ЛКМ или F — удар по манекену. Урон считается от Мощи."
		]))
	# обновить viewmodel у игрока если есть
	var players := get_tree().get_nodes_in_group("player")
	for p in players:
		if p.has_method("refresh_weapon_view"):
			p.call("refresh_weapon_view")
