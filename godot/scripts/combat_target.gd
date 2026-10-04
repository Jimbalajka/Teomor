extends StaticBody3D

@export var max_hp: int = 30
@export var target_name: String = "Манекен"
@export var reset_on_death: bool = true

var hp: int = 30
var _mesh: MeshInstance3D
var _dead: bool = false
var _base_modulate := Color(1, 1, 1, 1)


func _ready() -> void:
	add_to_group("combat_target")
	add_to_group("interactable")
	collision_layer = 1
	collision_mask = 0
	hp = max_hp
	_mesh = _find_mesh(self)


func _find_mesh(n: Node) -> MeshInstance3D:
	if n is MeshInstance3D:
		return n
	for c in n.get_children():
		var m := _find_mesh(c)
		if m:
			return m
	return null


func is_alive() -> bool:
	return not _dead and hp > 0


func get_prompt() -> String:
	if _dead:
		return "%s повержен" % target_name
	return "%s · HP %d/%d · ЛКМ/F удар" % [target_name, hp, max_hp]


func interact() -> void:
	var dlg := get_node_or_null("/root/Dialogue")
	if dlg and dlg.has_method("start"):
		if _dead:
			dlg.call("start", PackedStringArray(["Манекен ещё поднимется. Ударь снова, когда встанет."]))
		else:
			dlg.call("start", PackedStringArray(["Учебный мешок. Бей ЛКМ или F — урон от Мощи и оружия."]))


func take_hit(damage: int, hit_pos: Vector3 = Vector3.ZERO) -> Dictionary:
	if _dead:
		return {"ok": false, "hp": hp, "dead": true}
	var dmg := maxi(1, damage)
	hp = maxi(0, hp - dmg)
	var pos := hit_pos
	if pos == Vector3.ZERO:
		pos = global_position + Vector3(0, 1.0, 0)
	var fx = load("res://scripts/fx_burst.gd")
	if fx and fx.has_method("spawn"):
		fx.spawn(get_tree().current_scene, "hit_spark", pos, 1.2)
	_flash()
	var died := hp <= 0
	if died:
		_die()
	return {"ok": true, "hp": hp, "damage": dmg, "dead": died}


func _flash() -> void:
	if _mesh == null:
		_mesh = _find_mesh(self)
	if _mesh == null:
		return
	var mat := _mesh.material_override
	if mat == null:
		mat = StandardMaterial3D.new()
		_mesh.material_override = mat
	if mat is StandardMaterial3D:
		var sm := mat as StandardMaterial3D
		var old := sm.albedo_color
		sm.albedo_color = Color(1.0, 0.35, 0.25)
		var tw := create_tween()
		tw.tween_property(sm, "albedo_color", old, 0.15)


func _die() -> void:
	_dead = true
	var fx = load("res://scripts/fx_burst.gd")
	if fx and fx.has_method("spawn"):
		fx.spawn(get_tree().current_scene, "boom_orange", global_position + Vector3(0, 1.0, 0), 1.6)
	# лёгкий завал
	var tw := create_tween()
	tw.tween_property(self, "rotation_degrees:z", 75.0, 0.35)
	if reset_on_death:
		await get_tree().create_timer(2.2).timeout
		_reset()


func _reset() -> void:
	hp = max_hp
	_dead = false
	rotation_degrees = Vector3.ZERO
	var fx = load("res://scripts/fx_burst.gd")
	if fx and fx.has_method("spawn"):
		fx.spawn(get_tree().current_scene, "smoke_white", global_position + Vector3(0, 0.4, 0), 1.0)
