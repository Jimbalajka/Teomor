extends CanvasLayer

## Сетка-инвентарь (маленькая, как в Deus Ex): перетаскивание, поворот R, расходники.

const CELL := 52
const GAP := 3

var _panel: PanelContainer
var _status: Label
var _grid_host: Control
var _cells: Array = []  # Panel
var _item_panels: Dictionary = {}  # id -> Panel
var _body: Label
var _tab: String = "items"  # items | quest | glossary
var _selected_id: String = ""
var _drag_id: String = ""
var _drag_ghost: Panel = null
var _list: VBoxContainer  # quest/glossary list
var _use_btn: Button
var _rot_btn: Button
var _equip_btn: Button


func _ready() -> void:
	layer = 116
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_panel.visible = false


func is_open() -> bool:
	return _panel != null and _panel.visible


func _game_state() -> Node:
	return get_node_or_null("/root/GameState")


func open_inventory() -> void:
	if is_open():
		return
	if _ui_blocked_by_other():
		return
	_tab = "items"
	_selected_id = ""
	_refresh()
	_panel.visible = true
	var gs := _game_state()
	if gs:
		gs.set("input_locked", true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close_inventory() -> void:
	if not is_open():
		return
	_end_drag()
	_panel.visible = false
	var gs := _game_state()
	if gs:
		gs.set("input_locked", false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func toggle_inventory() -> void:
	if is_open():
		close_inventory()
	else:
		open_inventory()


func _build() -> void:
	_panel = PanelContainer.new()
	_panel.anchor_left = 0.1
	_panel.anchor_right = 0.9
	_panel.anchor_top = 0.08
	_panel.anchor_bottom = 0.92
	add_child(_panel)
	var margin := MarginContainer.new()
	for s in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(s, 14)
	_panel.add_child(margin)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	margin.add_child(v)

	var title := Label.new()
	title.text = "Инвентарь"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)

	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_status)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	v.add_child(tabs)
	for pair in [["items", "Сетка"], ["quest", "Квестовые"], ["glossary", "Глоссарий"]]:
		var b := Button.new()
		b.text = str(pair[1])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var tid := str(pair[0])
		b.pressed.connect(func(): _set_tab(tid))
		tabs.add_child(b)

	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(split)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(left)

	_grid_host = Control.new()
	_grid_host.name = "GridHost"
	_grid_host.custom_minimum_size = Vector2(6 * (CELL + GAP) + 8, 4 * (CELL + GAP) + 8)
	_grid_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_grid_host.mouse_filter = Control.MOUSE_FILTER_STOP
	_grid_host.gui_input.connect(_on_grid_gui_input)
	left.add_child(_grid_host)

	var scroll_l := ScrollContainer.new()
	scroll_l.name = "ListScroll"
	scroll_l.custom_minimum_size = Vector2(240, 280)
	scroll_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_l.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_l.visible = false
	left.add_child(scroll_l)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6)
	scroll_l.add_child(_list)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 8)
	split.add_child(right)

	var scroll_r := ScrollContainer.new()
	scroll_r.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_child(scroll_r)
	_body = Label.new()
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_r.add_child(_body)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	right.add_child(actions)
	_use_btn = Button.new()
	_use_btn.text = "Использовать"
	_use_btn.pressed.connect(_on_use)
	actions.add_child(_use_btn)
	_rot_btn = Button.new()
	_rot_btn.text = "Повернуть (R)"
	_rot_btn.pressed.connect(_on_rotate)
	actions.add_child(_rot_btn)
	_equip_btn = Button.new()
	_equip_btn.text = "В руки"
	_equip_btn.pressed.connect(_on_equip)
	actions.add_child(_equip_btn)

	var row := HBoxContainer.new()
	v.add_child(row)
	var hint := Label.new()
	hint.text = "I/Esc — закрыть · тяни вещь · R — поворот"
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(hint)
	var close_btn := Button.new()
	close_btn.text = "Закрыть"
	close_btn.pressed.connect(close_inventory)
	row.add_child(close_btn)

	_build_empty_grid()


func _cols() -> int:
	var gs := _game_state()
	if gs and gs.get("INV_COLS") != null:
		return int(gs.get("INV_COLS"))
	return 6


func _rows() -> int:
	var gs := _game_state()
	if gs and gs.get("INV_ROWS") != null:
		return int(gs.get("INV_ROWS"))
	return 4


func _build_empty_grid() -> void:
	for c in _cells:
		if is_instance_valid(c):
			c.queue_free()
	_cells.clear()
	var cols := _cols()
	var rows := _rows()
	_grid_host.custom_minimum_size = Vector2(cols * (CELL + GAP) + 8, rows * (CELL + GAP) + 8)
	for y in range(rows):
		for x in range(cols):
			var cell := Panel.new()
			cell.name = "Cell_%d_%d" % [x, y]
			cell.position = Vector2(4 + x * (CELL + GAP), 4 + y * (CELL + GAP))
			cell.size = Vector2(CELL, CELL)
			cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var style := StyleBoxFlat.new()
			style.bg_color = Color(0.12, 0.11, 0.14, 0.92)
			style.border_color = Color(0.35, 0.3, 0.4, 1)
			style.set_border_width_all(1)
			cell.add_theme_stylebox_override("panel", style)
			_grid_host.add_child(cell)
			_cells.append(cell)


func _set_tab(tab_id: String) -> void:
	_tab = tab_id
	_end_drag()
	_refresh()


func _clear_item_panels() -> void:
	for id in _item_panels.keys():
		var p = _item_panels[id]
		if is_instance_valid(p):
			p.queue_free()
	_item_panels.clear()


func _clear_list() -> void:
	for c in _list.get_children():
		c.queue_free()


func _refresh() -> void:
	var gs := _game_state()
	_clear_list()
	_clear_item_panels()
	_body.text = ""
	if gs == null:
		_status.text = "Нет GameState"
		return
	if gs.has_method("inventory_status_line"):
		_status.text = str(gs.call("inventory_status_line"))
	else:
		_status.text = ""

	var show_grid := _tab == "items"
	_grid_host.visible = show_grid
	_list.get_parent().visible = not show_grid
	_use_btn.visible = show_grid
	_rot_btn.visible = show_grid
	_equip_btn.visible = show_grid

	if _tab == "quest":
		var qitems: Array = gs.get("quest_items")
		if qitems.is_empty():
			_body.text = "Квестовых вещей пока нет."
			return
		for i in range(qitems.size()):
			var it: Dictionary = qitems[i]
			var btn := Button.new()
			btn.text = "📜 %s" % str(it.get("name", "?"))
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var idx := i
			btn.pressed.connect(func(): _show_quest_item(idx))
			_list.add_child(btn)
		_show_quest_item(0)
	elif _tab == "glossary":
		var gloss: Dictionary = gs.get("glossary")
		if gloss.is_empty():
			_body.text = "Термины откроются по мере странствий."
			return
		var keys: Array = gloss.keys()
		keys.sort()
		for i in range(keys.size()):
			var key := str(keys[i])
			var entry: Dictionary = gloss[key]
			var btn := Button.new()
			btn.text = str(entry.get("name", key))
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var k := key
			btn.pressed.connect(func(): _show_glossary(k))
			_list.add_child(btn)
		_show_glossary(str(keys[0]))
	else:
		_paint_items()
		if _selected_id.is_empty():
			var items: Array = gs.get("inventory")
			if items.is_empty():
				_body.text = "Сетка пуста. Подбери оружие или расходник."
			else:
				_select_item(str(items[0].get("id", "")))
		else:
			_select_item(_selected_id)


func _paint_items() -> void:
	var gs := _game_state()
	if gs == null:
		return
	var items: Array = gs.get("inventory")
	for it in items:
		var iid := str(it.get("id", ""))
		if iid.is_empty():
			continue
		var gx := int(it.get("gx", 0))
		var gy := int(it.get("gy", 0))
		var w := maxi(1, int(it.get("w", 1)))
		var h := maxi(1, int(it.get("h", 1)))
		var panel := Panel.new()
		panel.name = "Item_%s" % iid
		panel.position = Vector2(4 + gx * (CELL + GAP), 4 + gy * (CELL + GAP))
		panel.size = Vector2(w * CELL + (w - 1) * GAP, h * CELL + (h - 1) * GAP)
		panel.mouse_filter = Control.MOUSE_FILTER_STOP
		var style := StyleBoxFlat.new()
		var kind := str(it.get("kind", "misc"))
		match kind:
			"weapon":
				style.bg_color = Color(0.42, 0.18, 0.22, 0.92)
			"tool":
				style.bg_color = Color(0.22, 0.28, 0.4, 0.92)
			"consumable":
				style.bg_color = Color(0.25, 0.38, 0.24, 0.92)
			_:
				style.bg_color = Color(0.3, 0.26, 0.22, 0.92)
		if iid == _selected_id:
			style.border_color = Color(0.85, 0.7, 0.35, 1)
			style.set_border_width_all(2)
		else:
			style.border_color = Color(0.55, 0.5, 0.45, 1)
			style.set_border_width_all(1)
		panel.add_theme_stylebox_override("panel", style)
		var label := Label.new()
		var count := int(it.get("count", 1))
		var nm := str(it.get("name", iid))
		if nm.length() > 10:
			nm = nm.substr(0, 9) + "…"
		label.text = nm if count <= 1 else "%s ×%d" % [nm, count]
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(label)
		var captured := iid
		panel.gui_input.connect(func(ev): _on_item_gui_input(ev, captured))
		_grid_host.add_child(panel)
		_item_panels[iid] = panel


func _select_item(item_id: String) -> void:
	_selected_id = item_id
	var gs := _game_state()
	if gs == null:
		return
	var items: Array = gs.get("inventory")
	for it in items:
		if str(it.get("id", "")) != item_id:
			continue
		var extra := ""
		if bool(it.get("consumable", false)):
			extra += "\n(расходник)"
		if str(it.get("kind", "")) == "weapon":
			extra += "\n(оружие, урон %d)" % int(it.get("weapon_damage", 0))
		var count := int(it.get("count", 1))
		if count > 1:
			extra += "\nколичество: %d" % count
		extra += "\nразмер: %d×%d · клетка %d,%d" % [
			int(it.get("w", 1)), int(it.get("h", 1)), int(it.get("gx", 0)), int(it.get("gy", 0))
		]
		_body.text = "%s%s\n\n%s" % [str(it.get("name", "")), extra, str(it.get("description", ""))]
		_use_btn.disabled = not bool(it.get("consumable", false)) or str(it.get("id", "")) == "lockpick"
		_rot_btn.disabled = int(it.get("w", 1)) == int(it.get("h", 1))
		_equip_btn.disabled = str(it.get("kind", "")) != "weapon"
		# обновить рамку выделения
		_clear_item_panels()
		_paint_items()
		return
	_body.text = "Вещь не найдена."
	_use_btn.disabled = true
	_rot_btn.disabled = true
	_equip_btn.disabled = true


func _show_quest_item(idx: int) -> void:
	var gs := _game_state()
	if gs == null:
		return
	var items: Array = gs.get("quest_items")
	if idx < 0 or idx >= items.size():
		return
	var it: Dictionary = items[idx]
	_body.text = "%s\n\n%s" % [str(it.get("name", "")), str(it.get("description", ""))]


func _show_glossary(term_id: String) -> void:
	var gs := _game_state()
	if gs == null:
		return
	var gloss: Dictionary = gs.get("glossary")
	if not gloss.has(term_id):
		return
	var entry: Dictionary = gloss[term_id]
	_body.text = "%s\n\n%s" % [str(entry.get("name", term_id)), str(entry.get("description", ""))]


func _cell_at(local_pos: Vector2) -> Vector2i:
	var x := int(floor((local_pos.x - 4) / float(CELL + GAP)))
	var y := int(floor((local_pos.y - 4) / float(CELL + GAP)))
	return Vector2i(x, y)


func _on_item_gui_input(event: InputEvent, item_id: String) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_select_item(item_id)
			_begin_drag(item_id)
			_grid_host.accept_event()
		elif mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			if _drag_id == item_id:
				_try_drop()
				_grid_host.accept_event()


func _on_grid_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed and not _drag_id.is_empty():
			_try_drop()
			_grid_host.accept_event()
	elif event is InputEventMouseMotion and not _drag_id.is_empty():
		_update_ghost()


func _begin_drag(item_id: String) -> void:
	_drag_id = item_id
	if _drag_ghost != null and is_instance_valid(_drag_ghost):
		_drag_ghost.queue_free()
	_drag_ghost = Panel.new()
	_drag_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.7, 0.55, 0.2, 0.35)
	style.border_color = Color(0.95, 0.85, 0.4, 1)
	style.set_border_width_all(2)
	_drag_ghost.add_theme_stylebox_override("panel", style)
	_grid_host.add_child(_drag_ghost)
	_update_ghost()


func _update_ghost() -> void:
	if _drag_ghost == null or _drag_id.is_empty():
		return
	var gs := _game_state()
	if gs == null:
		return
	var w := 1
	var h := 1
	for it in gs.get("inventory"):
		if str(it.get("id", "")) == _drag_id:
			w = maxi(1, int(it.get("w", 1)))
			h = maxi(1, int(it.get("h", 1)))
			break
	var local := _grid_host.get_local_mouse_position()
	var cell := _cell_at(local)
	_drag_ghost.position = Vector2(4 + cell.x * (CELL + GAP), 4 + cell.y * (CELL + GAP))
	_drag_ghost.size = Vector2(w * CELL + (w - 1) * GAP, h * CELL + (h - 1) * GAP)
	var ok := true
	if gs.has_method("can_place_item"):
		ok = bool(gs.call("can_place_item", w, h, cell.x, cell.y, _drag_id))
	var style := _drag_ghost.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	if style:
		style.bg_color = Color(0.25, 0.55, 0.28, 0.4) if ok else Color(0.55, 0.2, 0.2, 0.4)
		_drag_ghost.add_theme_stylebox_override("panel", style)


func _try_drop() -> void:
	if _drag_id.is_empty():
		return
	var gs := _game_state()
	var local := _grid_host.get_local_mouse_position()
	var cell := _cell_at(local)
	if gs and gs.has_method("move_item"):
		gs.call("move_item", _drag_id, cell.x, cell.y)
	var keep := _drag_id
	_end_drag()
	_refresh()
	_select_item(keep)


func _end_drag() -> void:
	_drag_id = ""
	if _drag_ghost != null and is_instance_valid(_drag_ghost):
		_drag_ghost.queue_free()
	_drag_ghost = null


func _on_use() -> void:
	if _selected_id.is_empty():
		return
	var gs := _game_state()
	if gs == null or not gs.has_method("use_consumable"):
		return
	var keep := _selected_id
	var result: Dictionary = gs.call("use_consumable", keep)
	_body.text = str(result.get("msg", ""))
	if gs.has_method("has_item") and bool(gs.call("has_item", keep)):
		_selected_id = keep
	else:
		_selected_id = ""
	_refresh()


func _on_rotate() -> void:
	if _selected_id.is_empty():
		return
	var gs := _game_state()
	if gs and gs.has_method("rotate_item"):
		gs.call("rotate_item", _selected_id)
	_refresh()
	_select_item(_selected_id)


func _on_equip() -> void:
	if _selected_id.is_empty():
		return
	var gs := _game_state()
	if gs == null:
		return
	for it in gs.get("inventory"):
		if str(it.get("id", "")) != _selected_id:
			continue
		if str(it.get("kind", "")) != "weapon":
			return
		var dmg := int(it.get("weapon_damage", 2))
		if gs.has_method("equip_weapon"):
			# не дублировать через add_item внутри — уже есть
			gs.set("weapon_id", _selected_id)
			gs.set("weapon_name", str(it.get("name", _selected_id)))
			gs.set("weapon_damage", maxi(1, dmg))
			if gs.has_method("add_note"):
				gs.call("add_note", "weapon_equip", "Взял в руки: %s." % str(it.get("name", _selected_id)))
		_body.text = "В руках: %s." % str(it.get("name", _selected_id))
		var players := get_tree().get_nodes_in_group("player")
		for p in players:
			if p.has_method("refresh_weapon_view"):
				p.call("refresh_weapon_view")
		return


func _ui_blocked_by_other() -> bool:
	var dlg := get_node_or_null("/root/Dialogue")
	if dlg and dlg.has_method("is_open") and bool(dlg.call("is_open")):
		return true
	for path in ["/root/Diary", "/root/NameEntry", "/root/Skills", "/root/Lockpick"]:
		var n := get_node_or_null(path)
		if n and n.has_method("is_open") and bool(n.call("is_open")):
			return true
	return false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_I:
			if is_open():
				close_inventory()
				get_viewport().set_input_as_handled()
				return
			if _ui_blocked_by_other():
				return
			open_inventory()
			get_viewport().set_input_as_handled()
			return
		if is_open() and event.keycode == KEY_R and _tab == "items":
			_on_rotate()
			get_viewport().set_input_as_handled()
			return
	if not is_open():
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		close_inventory()
		get_viewport().set_input_as_handled()
	if event is InputEventMouseMotion and not _drag_id.is_empty():
		_update_ghost()
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed and not _drag_id.is_empty():
			_try_drop()
