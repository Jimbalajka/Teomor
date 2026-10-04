extends CanvasLayer

var _panel: PanelContainer
var _status: Label
var _list: VBoxContainer
var _body: Label
var _selected: String = "might"


func _ready() -> void:
	layer = 117
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_panel.visible = false


func is_open() -> bool:
	return _panel != null and _panel.visible


func _game_state() -> Node:
	return get_node_or_null("/root/GameState")


func open_skills() -> void:
	if is_open():
		return
	if _ui_blocked_by_other():
		return
	_selected = "might"
	_refresh()
	_panel.visible = true
	var gs := _game_state()
	if gs:
		gs.set("input_locked", true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close_skills() -> void:
	if not is_open():
		return
	_panel.visible = false
	var gs := _game_state()
	if gs:
		gs.set("input_locked", false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func toggle_skills() -> void:
	if is_open():
		close_skills()
	else:
		open_skills()


func _ui_blocked_by_other() -> bool:
	var dlg := get_node_or_null("/root/Dialogue")
	if dlg and dlg.has_method("is_open") and bool(dlg.call("is_open")):
		return true
	for path in ["/root/Diary", "/root/NameEntry", "/root/Inventory", "/root/Lockpick"]:
		var n := get_node_or_null(path)
		if n and n.has_method("is_open") and bool(n.call("is_open")):
			return true
	return false


func _build() -> void:
	_panel = PanelContainer.new()
	_panel.anchor_left = 0.14
	_panel.anchor_right = 0.86
	_panel.anchor_top = 0.12
	_panel.anchor_bottom = 0.88
	add_child(_panel)
	var margin := MarginContainer.new()
	for s in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(s, 16)
	_panel.add_child(margin)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	margin.add_child(v)

	var title := Label.new()
	title.text = "Навыки"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)

	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_status)

	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(split)

	var scroll_l := ScrollContainer.new()
	scroll_l.custom_minimum_size = Vector2(260, 280)
	scroll_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_l.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(scroll_l)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 8)
	scroll_l.add_child(_list)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 8)
	split.add_child(right)
	_body = Label.new()
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(_body)

	var ops := HBoxContainer.new()
	ops.add_theme_constant_override("separation", 8)
	right.add_child(ops)
	var minus := Button.new()
	minus.text = "−"
	minus.pressed.connect(_on_minus)
	ops.add_child(minus)
	var plus := Button.new()
	plus.text = "+"
	plus.pressed.connect(_on_plus)
	ops.add_child(plus)
	var check := Button.new()
	check.text = "Проверка d20"
	check.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	check.pressed.connect(_on_check)
	ops.add_child(check)

	var row := HBoxContainer.new()
	v.add_child(row)
	var hint := Label.new()
	hint.text = "K / Esc — закрыть · полное древо позже"
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(hint)
	var close_btn := Button.new()
	close_btn.text = "Закрыть"
	close_btn.pressed.connect(close_skills)
	row.add_child(close_btn)


func _refresh() -> void:
	var gs := _game_state()
	for c in _list.get_children():
		c.queue_free()
	if gs == null:
		_status.text = "Нет GameState"
		_body.text = ""
		return
	if gs.has_method("skills_status_line"):
		_status.text = str(gs.call("skills_status_line"))
	else:
		_status.text = ""

	var order: Array = gs.get("SKILL_ORDER") if gs.get("SKILL_ORDER") != null else ["might", "mind", "motor", "core"]
	for skill_id in order:
		var sid := str(skill_id)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var btn := Button.new()
		var val := int(gs.call("get_skill", sid)) if gs.has_method("get_skill") else 10
		var mod := int(gs.call("skill_modifier", sid)) if gs.has_method("skill_modifier") else 0
		var mod_s := ("+%d" % mod) if mod >= 0 else str(mod)
		var nm := str(gs.call("skill_name", sid)) if gs.has_method("skill_name") else sid
		btn.text = "%s  %d (%s)" % [nm, val, mod_s]
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.button_pressed = (sid == _selected)
		btn.pressed.connect(func(): _select(sid))
		row.add_child(btn)
		_list.add_child(row)
	_show_selected()


func _select(skill_id: String) -> void:
	_selected = skill_id
	_refresh()


func _show_selected() -> void:
	var gs := _game_state()
	if gs == null:
		return
	var nm := str(gs.call("skill_name", _selected)) if gs.has_method("skill_name") else _selected
	var blurb := str(gs.call("skill_blurb", _selected)) if gs.has_method("skill_blurb") else ""
	var val := int(gs.call("get_skill", _selected)) if gs.has_method("get_skill") else 10
	var mod := int(gs.call("skill_modifier", _selected)) if gs.has_method("skill_modifier") else 0
	var mod_s := ("+%d" % mod) if mod >= 0 else str(mod)
	var pts := int(gs.get("skill_points"))
	var floor_v := 10
	var floors = gs.get("skill_floor")
	if typeof(floors) == TYPE_DICTIONARY and floors.has(_selected):
		floor_v = int(floors[_selected])
	_body.text = "%s\nЗначение: %d  модификатор: %s\nПол от силуэта: %d\nСвободные очки: %d\n\n%s\n\n+ тратит очко (макс 18). − возвращает очко до пола силуэта.\nПроверка: d20 + мод против DC 12." % [
		nm, val, mod_s, floor_v, pts, blurb
	]


func _on_plus() -> void:
	var gs := _game_state()
	if gs and gs.has_method("raise_skill"):
		gs.call("raise_skill", _selected)
	_refresh()


func _on_minus() -> void:
	var gs := _game_state()
	if gs and gs.has_method("lower_skill"):
		gs.call("lower_skill", _selected)
	_refresh()


func _on_check() -> void:
	var gs := _game_state()
	if gs == null or not gs.has_method("roll_skill_check"):
		return
	var result: Dictionary = gs.call("roll_skill_check", _selected, 12)
	var msg := str(gs.call("format_skill_check", result)) if gs.has_method("format_skill_check") else str(result)
	_body.text = (_body.text.split("\n\nПроверка:")[0] if "\n\nПроверка:" in _body.text else _body.text)
	_body.text += "\n\nПроверка:\n%s" % msg
	var dlg := get_node_or_null("/root/Dialogue")
	if dlg and dlg.has_method("start"):
		# не закрываем skills; короткий лог поверх не нужен — оставляем в панели
		pass


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_K:
			if is_open():
				close_skills()
				get_viewport().set_input_as_handled()
				return
			if _ui_blocked_by_other():
				return
			open_skills()
			get_viewport().set_input_as_handled()
			return
	if not is_open():
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		close_skills()
		get_viewport().set_input_as_handled()
