extends CanvasLayer

var _lines: PackedStringArray = []
var _index: int = 0
var _open: bool = false
var _panel: PanelContainer
var _label: Label
var _hint: Label


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_panel.visible = false


func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.anchor_left = 0.1
	_panel.anchor_right = 0.9
	_panel.anchor_top = 0.72
	_panel.anchor_bottom = 0.95
	_panel.offset_left = 0
	_panel.offset_right = 0
	_panel.offset_top = 0
	_panel.offset_bottom = 0
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	margin.add_child(vbox)

	_label = Label.new()
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_label)

	_hint = Label.new()
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vbox.add_child(_hint)


func is_open() -> bool:
	return _open


func start(lines: PackedStringArray) -> void:
	if lines.is_empty():
		return
	_lines = lines
	_index = 0
	_open = true
	_panel.visible = true
	_show_current()


func _unhandled_input(event: InputEvent) -> void:
	if not _open:
		return
	var advance := false
	if event.is_action_pressed("ui_accept"):
		advance = true
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_E, KEY_SPACE, KEY_ENTER]:
			advance = true
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		advance = true
	if advance:
		get_viewport().set_input_as_handled()
		_index += 1
		if _index >= _lines.size():
			_close()
		else:
			_show_current()


func _show_current() -> void:
	_label.text = _lines[_index]
	_hint.text = "E / ЛКМ — дальше"


func _close() -> void:
	_open = false
	_panel.visible = false
	_lines = []
	_index = 0
