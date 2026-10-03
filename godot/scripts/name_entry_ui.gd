extends CanvasLayer

var _panel: PanelContainer
var _edit: LineEdit
var _shown: bool = false


func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_panel.visible = false
	call_deferred("_maybe_show")


func is_open() -> bool:
	return _panel != null and _panel.visible


func _game_state() -> Node:
	return get_node_or_null("/root/GameState")


func _build() -> void:
	_panel = PanelContainer.new()
	_panel.anchor_left = 0.25
	_panel.anchor_right = 0.75
	_panel.anchor_top = 0.3
	_panel.anchor_bottom = 0.55
	add_child(_panel)
	var margin := MarginContainer.new()
	for s in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(s, 16)
	_panel.add_child(margin)
	var v := VBoxContainer.new()
	margin.add_child(v)
	var title := Label.new()
	title.text = "Как тебя зовут?"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	_edit = LineEdit.new()
	_edit.placeholder_text = "Имя героя"
	_edit.max_length = 24
	v.add_child(_edit)
	var hint := Label.new()
	hint.text = "Enter — подтвердить"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(hint)
	_edit.text_submitted.connect(_on_submit)


func _maybe_show() -> void:
	var gs := _game_state()
	if gs == null:
		return
	if str(gs.get("player_name")).is_empty():
		_show()


func _show() -> void:
	_shown = true
	_panel.visible = true
	var gs := _game_state()
	if gs:
		gs.set("input_locked", true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_edit.grab_focus()


func _on_submit(text: String) -> void:
	var gs := _game_state()
	if gs and gs.has_method("set_player_name"):
		gs.call("set_player_name", text)
	elif gs:
		var n := text.strip_edges()
		gs.set("player_name", n if not n.is_empty() else "Безымянный")
	_panel.visible = false
	if gs:
		gs.set("input_locked", false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var dlg := get_node_or_null("/root/Dialogue")
	var shown_name := "Безымянный"
	if gs:
		if gs.has_method("display_name"):
			shown_name = str(gs.call("display_name"))
		else:
			shown_name = str(gs.get("player_name"))
	if dlg and dlg.has_method("start"):
		dlg.call("start", PackedStringArray([
			"Значит, тебя зовут %s." % shown_name,
			"Ещё один тошнотворный день в Вастерсе."
		]))


func _unhandled_input(event: InputEvent) -> void:
	if not is_open():
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ENTER:
		_on_submit(_edit.text)
		get_viewport().set_input_as_handled()
