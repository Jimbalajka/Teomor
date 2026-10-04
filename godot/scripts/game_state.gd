extends Node

## Минимальное состояние для плейтеста / slice.
var player_name: String = ""
var appearance_id: String = ""  # gaunt | common | stocky
var input_locked: bool = false
var shop_choice: String = ""  # potion | trinket | food
var has_central_pass: bool = false

## Phase 3 diary
var flags: Dictionary = {}
var diary_notes: Array = []  # {id, text}
var diary_quests: Array = []  # {id, name, description, status}

const APPEARANCE_LABELS := {
	"gaunt": "Худой, впалый",
	"common": "Обычный дес",
	"stocky": "Тяжёлый, узловатый",
}


func _ready() -> void:
	_seed_diary()


func _seed_diary() -> void:
	add_note(
		"day_start",
		"Ещё один день. Если не сдохну — пойду на работу. Буквы расползаются от сырости."
	)
	add_quest(
		"quest_work",
		"Опять работа",
		"Спуститься в Грибной и выбрать: склад/верфи или Конгрегационная библиотека. Лавка странностей — по пути.",
		"Активен"
	)


func set_player_name(value: String) -> void:
	player_name = value.strip_edges()
	if player_name.is_empty():
		player_name = "Безымянный"


func set_appearance(value: String) -> void:
	if APPEARANCE_LABELS.has(value):
		appearance_id = value
	else:
		appearance_id = "common"
	if has_mirror_setup():
		add_note(
			"mirror_look",
			"В мутном зеркале — я, %s. Силуэт: %s. Стекло снова запотело." % [display_name(), appearance_label()]
		)


func appearance_label() -> String:
	if appearance_id.is_empty():
		return "не разглядел себя"
	return str(APPEARANCE_LABELS.get(appearance_id, appearance_id))


func has_mirror_setup() -> bool:
	return not player_name.is_empty() and not appearance_id.is_empty()


func display_name() -> String:
	if player_name.is_empty():
		return "ты"
	return player_name


func set_flag(flag_id: String, value: bool = true) -> void:
	if flag_id.is_empty():
		return
	flags[flag_id] = value


func has_flag(flag_id: String) -> bool:
	return bool(flags.get(flag_id, false))


func mark_scene(scene_path: String) -> void:
	var p := scene_path
	if p.begins_with("res://scenes/"):
		p = p.trim_prefix("res://scenes/")
	if p.ends_with(".tscn"):
		p = p.trim_suffix(".tscn")
	if p.is_empty():
		return
	set_flag("visited_" + p, true)
	match p:
		"alley":
			add_note("alley_first", "Грибной район: сырой T-стык, пурпурный чад, десы почти не двигаются.")
			set_quest_status("quest_work", "В пути")
		"warehouse":
			add_note("wh_first", "Верфи за стенами. Пахнет рыбой, смолой и чужим орём.")
			set_quest_status("quest_work", "Склад/верфи")
		"library":
			add_note("lib_first", "Конгрегационная библиотека. Платят лучше. Минус один: безумный Раф Лат Телий.")
			set_quest_status("quest_work", "Библиотека")
		"shop":
			add_note("shop_first", "Лавка странностей без вывески. Масло, пыль, что-то сладкое.")
		"central_library":
			add_note("central_first", "Центральная — пока только порог и заглушка пропуска.")
			if has_central_pass:
				set_quest_status("quest_work", "Пропуск есть")
		"playtest":
			add_note("playtest_lab", "Серый короб для механик. Сюжетный маршрут — по лестнице вниз.")


func add_note(note_id: String, text: String) -> void:
	if note_id.is_empty() or text.is_empty():
		return
	for n in diary_notes:
		if str(n.get("id", "")) == note_id:
			# refresh text if already present (mirror rewrite)
			n["text"] = text
			return
	diary_notes.append({"id": note_id, "text": text})


func add_quest(quest_id: String, qname: String, description: String, status: String = "Активен") -> void:
	if quest_id.is_empty():
		return
	for q in diary_quests:
		if str(q.get("id", "")) == quest_id:
			return
	diary_quests.append({
		"id": quest_id,
		"name": qname,
		"description": description,
		"status": status,
	})


func set_quest_status(quest_id: String, status: String) -> void:
	for q in diary_quests:
		if str(q.get("id", "")) == quest_id:
			q["status"] = status
			return


func diary_status_line() -> String:
	var bits: PackedStringArray = []
	bits.append("Имя: %s" % display_name())
	bits.append("Силуэт: %s" % appearance_label())
	if not shop_choice.is_empty():
		bits.append("Покупка: %s" % shop_choice)
	if has_central_pass:
		bits.append("Пропуск: да")
	else:
		bits.append("Пропуск: нет")
	return " · ".join(bits)
