extends CanvasLayer

var _panel: PanelContainer
var _status: Label
var _tabs: HBoxContainer
var _list: VBoxContainer
var _body: Label
var _hint: Label
var _tab: String = "notes"  # notes | quests
var _buttons: Array = []


func _ready() -> void:
	layer = 115
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_panel.visible = false


func is_open() -> bool:
	return _panel != null and _panel.visible


func _game_state() -> Node:
	return get_node_or_null("/root/GameState")


func open_diary() -> void:
	if is_open():
		return
	_tab = "notes"
	var gs0 := _game_state()
	if gs0 and gs0.has_method("mark_scene"):
		var scene := get_tree().current_scene
		if scene:
			gs0.call("mark_scene", str(scene.scene_file_path))
	_refresh()
	_panel.visible = true
	var gs := _game_state()
	if gs:
		gs.set("input_locked", true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close_diary() -> void:
	if not is_open():
		return
	_panel.visible = false
	var gs := _game_state()
	if gs:
		gs.set("input_locked", false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _build() -> void:
	_panel = PanelContainer.new()
	_panel.anchor_left = 0.12
	_panel.anchor_right = 0.88
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
	title.text = "Дневник"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)

	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_status)

	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 8)
	v.add_child(_tabs)
	var b_notes := Button.new()
	b_notes.text = "Заметки"
	b_notes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b_notes.pressed.connect(func(): _set_tab("notes"))
	_tabs.add_child(b_notes)
	var b_quests := Button.new()
	b_quests.text = "Маршрут"
	b_quests.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b_quests.pressed.connect(func(): _set_tab("quests"))
	_tabs.add_child(b_quests)

	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(split)

	var scroll_l := ScrollContainer.new()
	scroll_l.custom_minimum_size = Vector2(220, 280)
	scroll_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_l.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(scroll_l)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6)
	scroll_l.add_child(_list)

	var scroll_r := ScrollContainer.new()
	scroll_r.custom_minimum_size = Vector2(280, 280)
	scroll_r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_r.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(scroll_r)
	_body = Label.new()
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_r.add_child(_body)

	var row := HBoxContainer.new()
	v.add_child(row)
	_hint = Label.new()
	_hint.text = "Esc / Закрыть — убрать дневник"
	_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_hint)
	var close_btn := Button.new()
	close_btn.text = "Закрыть"
	close_btn.pressed.connect(close_diary)
	row.add_child(close_btn)


func _set_tab(whichtab: String) -> void:
	_tab = whichtab
	_refresh()


func _refresh() -> void:
	var gs := _game_state()
	if gs and gs.has_method("diary_status_line"):
		_status.text = str(gs.call("diary_status_line"))
	elif gs:
		_status.text = "%s · %s" % [gs.get("player_name"), gs.get("appearance_id")]
	else:
		_status.text = ""

	for c in _list.get_children():
		c.queue_free()
	_buttons.clear()
	_body.text = ""

	if gs == null:
		_body.text = "Нет GameState."
		return

	if _tab == "quests":
		var quests: Array = gs.get("diary_quests")
		if quests.is_empty():
			_body.text = "Задания появятся по мере продвижения."
			return
		for i in range(quests.size()):
			var q: Dictionary = quests[i]
			var btn := Button.new()
			btn.text = "%s [%s]" % [str(q.get("name", "?")), str(q.get("status", ""))]
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var idx := i
			btn.pressed.connect(func(): _show_quest(idx))
			_list.add_child(btn)
			_buttons.append(btn)
		_show_quest(0)
	else:
		var notes: Array = gs.get("diary_notes")
		if notes.is_empty():
			_body.text = "Заметки появятся автоматически."
			return
		# newest first
		for i in range(notes.size() - 1, -1, -1):
			var n: Dictionary = notes[i]
			var btn := Button.new()
			var preview := str(n.get("text", ""))
			if preview.length() > 42:
				preview = preview.substr(0, 42) + "…"
			btn.text = preview
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var idx := i
			btn.pressed.connect(func(): _show_note(idx))
			_list.add_child(btn)
			_buttons.append(btn)
		_show_note(notes.size() - 1)


func _show_note(idx: int) -> void:
	var gs := _game_state()
	if gs == null:
		return
	var notes: Array = gs.get("diary_notes")
	if idx < 0 or idx >= notes.size():
		return
	var n: Dictionary = notes[idx]
	_body.text = str(n.get("text", ""))


func _show_quest(idx: int) -> void:
	var gs := _game_state()
	if gs == null:
		return
	var quests: Array = gs.get("diary_quests")
	if idx < 0 or idx >= quests.size():
		return
	var q: Dictionary = quests[idx]
	_body.text = "%s
[%s]

%s" % [str(q.get("name", "")), str(q.get("status", "")), str(q.get("description", ""))]


func _unhandled_input(event: InputEvent) -> void:
	if not is_open():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			close_diary()
			get_viewport().set_input_as_handled()
