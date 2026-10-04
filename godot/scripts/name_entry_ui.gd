extends CanvasLayer

var _panel: PanelContainer
var _edit: LineEdit
var _status: Label
var _buttons: Dictionary = {}
var _selected_appearance: String = "common"
var _mode: String = "boot"  # boot | mirror


func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_panel.visible = false
	call_deferred("_maybe_boot_prompt")


func is_open() -> bool:
	return _panel != null and _panel.visible


func _game_state() -> Node:
	return get_node_or_null("/root/GameState")


func _build() -> void:
	_panel = PanelContainer.new()
	_panel.anchor_left = 0.2
	_panel.anchor_right = 0.8
	_panel.anchor_top = 0.18
	_panel.anchor_bottom = 0.78
	add_child(_panel)
	var margin := MarginContainer.new()
	for s in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(s, 16)
	_panel.add_child(margin)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	margin.add_child(v)
	var title := Label.new()
	title.name = "Title"
	title.text = "Зеркало"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var sub := Label.new()
	sub.text = "Имя и силуэт. Модельку потом подставим."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(sub)
	_edit = LineEdit.new()
	_edit.placeholder_text = "Имя героя"
	_edit.max_length = 24
	v.add_child(_edit)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(row)
	for id in ["gaunt", "common", "stocky"]:
		var b := Button.new()
		b.toggle_mode = true
		b.text = str(_game_state_labels(id))
		b.custom_minimum_size = Vector2(140, 40)
		b.pressed.connect(_on_appearance_pressed.bind(id))
		row.add_child(b)
		_buttons[id] = b
	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_status)
	var ok := Button.new()
	ok.text = "Подтвердить"
	ok.pressed.connect(_confirm)
	v.add_child(ok)
	var hint := Label.new()
	hint.text = "Enter — подтвердить · Esc — закрыть (если уже настроено)"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(hint)
	_edit.text_submitted.connect(func(_t): _confirm())


func _game_state_labels(id: String) -> String:
	var gs := _game_state()
	if gs and "APPEARANCE_LABELS" in gs:
		var d = gs.get("APPEARANCE_LABELS")
		if typeof(d) == TYPE_DICTIONARY and d.has(id):
			return str(d[id])
	match id:
		"gaunt":
			return "Худой, впалый"
		"stocky":
			return "Тяжёлый, узловатый"
		_:
			return "Обычный дес"


func _maybe_boot_prompt() -> void:
	var gs := _game_state()
	if gs == null:
		return
	# Имя можно задать на старте; внешность — у зеркала.
	if str(gs.get("player_name")).is_empty():
		open_boot_name()


func open_boot_name() -> void:
	_mode = "boot"
	_prepare_fields()
	_show_panel()


func open_mirror() -> void:
	_mode = "mirror"
	_prepare_fields()
	_show_panel()


func _prepare_fields() -> void:
	var gs := _game_state()
	var nm := ""
	var ap := "common"
	if gs:
		nm = str(gs.get("player_name"))
		var a := str(gs.get("appearance_id"))
		if not a.is_empty():
			ap = a
	_edit.text = nm
	_selected_appearance = ap
	_refresh_appearance_buttons()
	_refresh_status()


func _show_panel() -> void:
	_panel.visible = true
	var gs := _game_state()
	if gs:
		gs.set("input_locked", true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_edit.grab_focus()


func _hide_panel() -> void:
	_panel.visible = false
	var gs := _game_state()
	if gs:
		gs.set("input_locked", false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_appearance_pressed(id: String) -> void:
	_selected_appearance = id
	_refresh_appearance_buttons()
	_refresh_status()


func _refresh_appearance_buttons() -> void:
	for id in _buttons.keys():
		var b: Button = _buttons[id]
		b.button_pressed = (id == _selected_appearance)


func _refresh_status() -> void:
	_status.text = "Выбрано: %s" % _game_state_labels(_selected_appearance)


func _confirm() -> void:
	var gs := _game_state()
	var text := _edit.text
	if gs and gs.has_method("set_player_name"):
		gs.call("set_player_name", text)
	elif gs:
		var n := text.strip_edges()
		gs.set("player_name", n if not n.is_empty() else "Безымянный")
	if gs and gs.has_method("set_appearance"):
		gs.call("set_appearance", _selected_appearance)
	elif gs:
		gs.set("appearance_id", _selected_appearance)
	_hide_panel()
	var shown_name := "Безымянный"
	var shown_ap := _game_state_labels(_selected_appearance)
	if gs:
		if gs.has_method("display_name"):
			shown_name = str(gs.call("display_name"))
		else:
			shown_name = str(gs.get("player_name"))
		if gs.has_method("appearance_label"):
			shown_ap = str(gs.call("appearance_label"))
	var dlg := get_node_or_null("/root/Dialogue")
	if dlg and dlg.has_method("start"):
		if _mode == "boot":
			dlg.call("start", PackedStringArray([
				"Значит, тебя зовут %s." % shown_name,
				"К зеркалу ещё подойдёшь — силуэт донастроишь там."
			]))
		else:
			dlg.call("start", PackedStringArray([
				"В мутном стекле — %s." % shown_name,
				"Силуэт: %s. Стекло снова запотело." % shown_ap
			]))


func _unhandled_input(event: InputEvent) -> void:
	if not is_open():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER:
			_confirm()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE:
			var gs := _game_state()
			# boot без имени закрывать нельзя
			if _mode == "boot" and gs and str(gs.get("player_name")).is_empty():
				return
			_hide_panel()
			get_viewport().set_input_as_handled()
