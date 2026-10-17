extends SceneTree

## godot4 --path . --headless -s res://scripts/tools/test_grid_inventory.gd

func _init() -> void:
	var gs = load("res://scripts/game_state.gd").new()
	# без дерева — вызываем сиды сами
	gs._seed_diary()
	gs._seed_inventory()
	gs._seed_skills()
	var ok := true
	if int(gs.item_count("lockpick")) != 3:
		push_error("lockpick seed fail count=%s" % gs.item_count("lockpick"))
		ok = false
	if not gs.add_item({"id": "test_sword", "name": "Тест-клинок", "kind": "weapon", "w": 2, "h": 1, "weapon_damage": 5}):
		push_error("weapon place fail")
		ok = false
	if gs.add_item({"id": "test_sword", "name": "dup", "kind": "weapon"}):
		push_error("dup weapon should fail")
		ok = false
	var n := 0
	while gs.find_free_slot(1, 1).x >= 0:
		var id := "junk_%d" % n
		if not gs.add_item({"id": id, "name": id, "w": 1, "h": 1, "kind": "misc"}):
			break
		n += 1
	if gs.find_free_slot(1, 1).x >= 0:
		push_error("grid should be full free=%s" % gs.find_free_slot(1, 1))
		ok = false
	gs.remove_item("junk_0", 1)
	gs.remove_item("junk_1", 1)
	gs.rotate_item("test_sword")
	if not gs.break_lockpick():
		push_error("break_lockpick failed")
		ok = false
	if int(gs.item_count("lockpick")) != 2:
		push_error("lockpick after break = %s" % gs.item_count("lockpick"))
		ok = false
	if ok:
		print("GRID_INV_OK items=%d occupied=%d" % [gs.inventory.size(), gs.occupied_cells()])
		quit(0)
	else:
		print("GRID_INV_FAIL")
		quit(1)
