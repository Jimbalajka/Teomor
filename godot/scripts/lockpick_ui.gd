extends CanvasLayer

## 3 барабана 1..5. Успех: значения подряд слева направо (↑ или ↓).
## Одна заморозка. Попытки: 3 + бонус Моторики.

var _panel: PanelContainer
var _title: Label
var _status: Label
var _reels_row: HBoxContainer
var _reel_labels: Array = []
var _freeze_buttons: Array = []
var _spin_btn: Button
var _hint: Label

var _lock_id: String = ""
var _lock_title: String = "Замок"
var _success_lines: PackedStringArray = PackedStringArray()
var _practice: bool = false
var _values: Array = [1, 1, 1]
var _frozen: int = -1  # 0..2 or -1
var _attempts_left: int = 3
var _busy: bool = false
var _resolved: bool = false


func _ready() -> void:
	layer = 118
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_panel.visible = false


func is_open() -> bool:
	return _panel != null and _panel.visible


func _game_state() -> Node:
	return get_node_or_null("/root/GameState")


func _ui_blocked_by_other() -> bool:
	var dlg := get_node_or_null("/root/Dialogue")
	if dlg and dlg.has_method("is_open") and bool(dlg.call("is_open")):
		return true
	for path in ["/root/Diary", "/root/NameEntry", "/root/Inventory", "/root/Skills"]:
		var n := get_node_or_null(path)
		if n and n.has_method("is_open") and bool(n.call("is_open")):
			return true
	return false


func open_lockpick(lock_id: String, title: String = "Замок", success_lines: PackedStringArray = PackedStringArray(), practice: bool = false) -> void:
	if is_open():
		return
	if _ui_blocked_by_other():
		return
	var gs := _game_state()
	if gs and gs.has_method("is_lock_open") and bool(gs.call("is_lock_open", lock_id)) and not practice:
		var dlg := get_node_or_null("/root/Dialogue")
		if dlg and dlg.has_method("start"):
			dlg.call("start", PackedStringArray(["Этот замок уже открыт."]))
		return
	_lock_id = lock_id
	_lock_title = title if not title.is_empty() else "Замок"
	_success_lines = success_lines
	_practice = practice
	_frozen = -1
	_resolved = false
	_busy = false
	_values = [randi_range(1, 5), randi_range(1, 5), randi_range(1, 5)]
	if gs and gs.has_method("lockpick_max_attempts"):
		_attempts_left = int(gs.call("lockpick_max_attempts"))
	else:
		_attempts_left = 3
	_title.text = _lock_title
	_refresh()
	_panel.visible = true
	if gs:
		gs.set("input_locked", true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close_lockpick() -> void:
	if not is_open():
		return
	_panel.visible = false
	_busy = false
	var gs := _game_state()
	if gs:
		gs.set("input_locked", false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _build() -> void:
	_panel = PanelContainer.new()
	_panel.anchor_left = 0.18
	_panel.anchor_right = 0.82
	_panel.anchor_top = 0.16
	_panel.anchor_bottom = 0.84
	add_child(_panel)
	var margin := MarginContainer.new()
	for s in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(s, 16)
	_panel.add_child(margin)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	margin.add_child(v)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_title)

	var rules := Label.new()
	rules.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rules.text = "3 барабана (1–5). Нужны числа подряд слева направо: 2-3-4 или 5-4-3.\nМожно заморозить один барабан. Крутятся только незамороженные."
	v.add_child(rules)

	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_status)

	_reels_row = HBoxContainer.new()
	_reels_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_reels_row.add_theme_constant_override("separation", 16)
	v.add_child(_reels_row)

	_reel_labels.clear()
	_freeze_buttons.clear()
	for i in range(3):
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 8)
		var lab := Label.new()
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lab.add_theme_font_size_override("font_size", 42)
		lab.text = "1"
		col.add_child(lab)
		_reel_labels.append(lab)
		var fb := Button.new()
		fb.text = "Заморозить"
		var idx := i
		fb.pressed.connect(func(): _toggle_freeze(idx))
		col.add_child(fb)
		_freeze_buttons.append(fb)
		_reels_row.add_child(col)

	var ops := HBoxContainer.new()
	ops.alignment = BoxContainer.ALIGNMENT_CENTER
	ops.add_theme_constant_override("separation", 10)
	v.add_child(ops)
	_spin_btn = Button.new()
	_spin_btn.text = "Крутить"
	_spin_btn.pressed.connect(_on_spin)
	ops.add_child(_spin_btn)
	var clear_f := Button.new()
	clear_f.text = "Снять заморозку"
	clear_f.pressed.connect(func(): _frozen = -1; _refresh())
	ops.add_child(clear_f)

	var row := HBoxContainer.new()
	v.add_child(row)
	_hint = Label.new()
	_hint.text = "Esc — закрыть"
	_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_hint)
	var close_btn := Button.new()
	close_btn.text = "Закрыть"
	close_btn.pressed.connect(close_lockpick)
	row.add_child(close_btn)


func _refresh() -> void:
	for i in range(3):
		_reel_labels[i].text = str(_values[i])
		var frozen_here := (_frozen == i)
		_freeze_buttons[i].text = "❄ держа" if frozen_here else "Заморозить"
		_freeze_buttons[i].disabled = _resolved or _busy or (_frozen != -1 and not frozen_here)
	_spin_btn.disabled = _resolved or _busy or _attempts_left <= 0
	var gs := _game_state()
	var motor_mod := 0
	if gs and gs.has_method("skill_modifier"):
		motor_mod = int(gs.call("skill_modifier", "motor"))
	var mod_s := ("+%d" % motor_mod) if motor_mod >= 0 else str(motor_mod)
	var mode := "плейтест (можно снова)" if _practice else "замок: %s" % _lock_id
	_status.text = "Попытки: %d · Моторика мод %s · %s\n%s" % [
		_attempts_left, mod_s, mode,
		("Заморожен барабан %d" % (_frozen + 1)) if _frozen >= 0 else "Заморозки нет"
	]


func _toggle_freeze(idx: int) -> void:
	if _resolved or _busy:
		return
	if _frozen == idx:
		_frozen = -1
	else:
		_frozen = idx
	_refresh()


func _is_consecutive(vals: Array) -> bool:
	if vals.size() != 3:
		return false
	var a := int(vals[0])
	var b := int(vals[1])
	var c := int(vals[2])
	# подряд вверх или вниз
	if b - a == 1 and c - b == 1:
		return true
	if a - b == 1 and b - c == 1:
		return true
	return false


func _on_spin() -> void:
	if _resolved or _busy or _attempts_left <= 0:
		return
	_busy = true
	_refresh()
	await _animate_spin()
	_attempts_left -= 1
	_busy = false
	if _is_consecutive(_values):
		_on_success()
	elif _attempts_left <= 0:
		_on_fail()
	else:
		_status.text += "\nНе подряд. Ещё попытки есть."
		_refresh()


func _animate_spin() -> void:
	# короткая прокрутка незамороженных
	for _tick in range(8):
		for i in range(3):
			if i == _frozen:
				continue
			_values[i] = randi_range(1, 5)
			_reel_labels[i].text = str(_values[i])
		await get_tree().create_timer(0.04).timeout
	for i in range(3):
		if i == _frozen:
			continue
		_values[i] = randi_range(1, 5)
		_reel_labels[i].text = str(_values[i])


func _on_success() -> void:
	_resolved = true
	_refresh()
	var gs := _game_state()
	if not _practice and gs and gs.has_method("set_lock_open"):
		gs.call("set_lock_open", _lock_id, true)
	var lines: PackedStringArray = _success_lines.duplicate()
	if lines.is_empty():
		lines = PackedStringArray([
			"Щёлк. Барабаны встали подряд: %d-%d-%d." % [_values[0], _values[1], _values[2]],
			"Замок поддался."
		])
	_status.text = "УСПЕХ: %d-%d-%d" % [_values[0], _values[1], _values[2]]
	close_lockpick()
	var dlg := get_node_or_null("/root/Dialogue")
	if dlg and dlg.has_method("start"):
		dlg.call("start", lines)


func _on_fail() -> void:
	_resolved = true
	_refresh()
	_status.text = "Провал. Попытки кончились. %d-%d-%d" % [_values[0], _values[1], _values[2]]
	var lines := PackedStringArray([
		"Штифты не встали. Пальцы заныли.",
		"Пока замок держится — можно подойти снова позже." if _practice else "Замок молчит. Попробуешь ещё — с холодной головой."
	])
	# в плейтесте и в мире разрешаем повторный подход (не ставим permanent jam)
	_resolved = false
	if _practice:
		var gs := _game_state()
		_attempts_left = int(gs.call("lockpick_max_attempts")) if gs and gs.has_method("lockpick_max_attempts") else 3
	close_lockpick()
	var dlg := get_node_or_null("/root/Dialogue")
	if dlg and dlg.has_method("start"):
		dlg.call("start", lines)


func _unhandled_input(event: InputEvent) -> void:
	if not is_open():
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if _busy:
			return
		close_lockpick()
		get_viewport().set_input_as_handled()
