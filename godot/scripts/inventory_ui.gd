extends CanvasLayer

var _panel: PanelContainer
var _status: Label
var _list: VBoxContainer
var _body: Label
var _tab: String = "items"  # items | quest | glossary


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
	# не поверх зеркала/дневника
	var diary := get_node_or_null("/root/Diary")
	if diary and diary.has_method("is_open") and bool(diary.call("is_open")):
		return
	var name_ui := get_node_or_null("/root/NameEntry")
	if name_ui and name_ui.has_method("is_open") and bool(name_ui.call("is_open")):
		return
	var skills := get_node_or_null("/root/Skills")
	if skills and skills.has_method("is_open") and bool(skills.call("is_open")):
		return
	_tab = "items"
	_refresh()
	_panel.visible = true
	var gs := _game_state()
	if gs:
		gs.set("input_locked", true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close_inventory() -> void:
	if not is_open():
		return
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
	_panel.anchor_left = 0.12
	_panel.anchor_right = 0.88
	_panel.anchor_top = 0.1
	_panel.anchor_bottom = 0.9
	add_child(_panel)
	var margin := MarginContainer.new()
	for s in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(s, 16)
	_panel.add_child(margin)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	margin.add_child(v)

	var title := Label.new()
	title.text = "Инвентарь / глоссарий"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)

	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_status)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	v.add_child(tabs)
	for pair in [["items", "Вещи"], ["quest", "Квестовые"], ["glossary", "Глоссарий"]]:
		var b := Button.new()
		b.text = str(pair[1])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var tid := str(pair[0])
		b.pressed.connect(func(): _set_tab(tid))
		tabs.add_child(b)

	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(split)

	var scroll_l := ScrollContainer.new()
	scroll_l.custom_minimum_size = Vector2(240, 300)
	scroll_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_l.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(scroll_l)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6)
	scroll_l.add_child(_list)

	var scroll_r := ScrollContainer.new()
	scroll_r.custom_minimum_size = Vector2(280, 300)
	scroll_r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_r.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(scroll_r)
	_body = Label.new()
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_r.add_child(_body)

	var row := HBoxContainer.new()
	v.add_child(row)
	var hint := Label.new()
	hint.text = "I / Esc — закрыть"
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(hint)
	var close_btn := Button.new()
	close_btn.text = "Закрыть"
	close_btn.pressed.connect(close_inventory)
	row.add_child(close_btn)


func _set_tab(tab_id: String) -> void:
	_tab = tab_id
	_refresh()


func _clear_list() -> void:
	for c in _list.get_children():
		c.queue_free()
	_body.text = ""


func _refresh() -> void:
	var gs := _game_state()
	_clear_list()
	if gs == null:
		_status.text = "Нет GameState"
		return
	if gs.has_method("inventory_status_line"):
		_status.text = str(gs.call("inventory_status_line"))
	else:
		_status.text = ""

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
		var items: Array = gs.get("inventory")
		var cap := int(gs.get("INV_CAPACITY")) if gs.get("INV_CAPACITY") != null else 12
		# show occupied + empty slots
		for i in range(cap):
			var btn := Button.new()
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			if i < items.size():
				var it: Dictionary = items[i]
				var mark := "•" if bool(it.get("consumable", false)) else "·"
				btn.text = "%s %s" % [mark, str(it.get("name", "?"))]
				var idx := i
				btn.pressed.connect(func(): _show_item(idx))
			else:
				btn.text = "[ пусто ]"
				btn.disabled = true
			_list.add_child(btn)
		if items.is_empty():
			_body.text = "Карманы пусты. Подбери что-нибудь на локации или в плейтесте."
		else:
			_show_item(0)


func _show_item(idx: int) -> void:
	var gs := _game_state()
	if gs == null:
		return
	var items: Array = gs.get("inventory")
	if idx < 0 or idx >= items.size():
		return
	var it: Dictionary = items[idx]
	var extra := "\n(расходник)" if bool(it.get("consumable", false)) else ""
	_body.text = "%s%s\n\n%s" % [str(it.get("name", "")), extra, str(it.get("description", ""))]


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


func _ui_blocked_by_other() -> bool:
	var dlg := get_node_or_null("/root/Dialogue")
	if dlg and dlg.has_method("is_open") and bool(dlg.call("is_open")):
		return true
	var diary := get_node_or_null("/root/Diary")
	if diary and diary.has_method("is_open") and bool(diary.call("is_open")):
		return true
	var name_ui := get_node_or_null("/root/NameEntry")
	if name_ui and name_ui.has_method("is_open") and bool(name_ui.call("is_open")):
		return true
	var skills := get_node_or_null("/root/Skills")
	if skills and skills.has_method("is_open") and bool(skills.call("is_open")):
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
	if not is_open():
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		close_inventory()
		get_viewport().set_input_as_handled()
