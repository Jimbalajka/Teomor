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

## Phase 4 inventory / glossary
const INV_CAPACITY := 12
var inventory: Array = []  # {id, name, description, consumable}
var quest_items: Array = []  # {id, name, description}
var money_nb: int = 10
var money_vb: int = 0
var glossary: Dictionary = {}  # id -> {name, description}

const APPEARANCE_LABELS := {
	"gaunt": "Худой, впалый",
	"common": "Обычный дес",
	"stocky": "Тяжёлый, узловатый",
}

const GLOSSARY_BASE := {
	"faidych": {"name": "Фаидыч", "description": "Легендарная фигура в истории Теомора, самый известный работник Биржи Наемничества, символ целой Эпохи и идеал, к которому стремятся все наёмники Биржи."},
	"birzha_naemn": {"name": "Биржа Наемничества", "description": "Коллегия, которая занимается контрактным трудоустройством десов. Будь то умелый боец, волшебник или уборщица — все найдут работу и плату. Биржа принимает заказы от дворян до сельских бедняков.\n\nИстория: основана в начале 5 Эры после смерти Зюбания IV Стремительного для предотвращения Хаоса. В 6 Эре пережила кризис, но после реорганизации стала монополистом к 10 Эре."},
	"des": {"name": "Десы", "description": "Раса разумных существ, населяющая Теомор."},
	"zyubaniy": {"name": "Зюбаний", "description": "Имя Великого Зверя и первого Императора СА."},
	"imperia_sa": {"name": "Империя СА", "description": "Империя СА — старая власть Зверя; в Вастерса её тень всё ещё давит на кварталы."},
	"era": {"name": "Эра", "description": "Эры — крупные эпохи истории Теомора. Сейчас дальняя Эра после хаоса биржи."},
	"klany_tuo": {"name": "Кланы Туо", "description": "Кланы Туо — восточные роды; с Тройным Султанатом делят старые договоры."},
	"kongregacia": {"name": "Конгрегация Лосана", "description": "Конгрегация Лосана — учёные и писцы. Библиотеки, контракты, странные ритуалы."},
	"suhodzhuy_el": {"name": "Сухожуйный эль", "description": "Сухожуйный эль — дешёвое пойло Грибного. Согревает рот, не голову."},
	"gornoe_vino": {"name": "Горное вино", "description": "Горное вино — дороже эля; в лавках странностей бывает подделкой."},
	"sferidy": {"name": "Сфериды", "description": "Сфериды — кристаллическая магия. Никчемыш к ним глух."},
	"vastersa": {"name": "Вастерса", "description": "Прекрасный многоярусный город посреди озера, через который проходит множество искусственных каналов. Контраст между богатыми и бедными кварталами огромен."},
	"troynoy_sultanat": {"name": "Тройной Султанат Туо", "description": "Тройной Султанат Туо — три трона, одна тень на торговых путях."},
	"vsegrib": {"name": "Всегриб", "description": "Тип грибов, растущих преимущественно в Вастерса. Могут прорасти где угодно: в камне, на земле, на лице. Требуют постоянного приёма лекарств. Вкус зависит от места: Каменные всегрибы ценятся поварами, Дес-всегрибы запрещены (приравниваются к каннибализму)."},
	"nikchemysh": {"name": "Никчемыш", "description": "Проклятый от рождения дес, который не обладает и никогда не сможет обладать магией. Не может пользоваться кристаллами, свитками, магическими предметами. Зелья действуют намного слабее."},
	"pokoy_trava": {"name": "Покой-трава", "description": "Популярный наркотик среди бедняков Вастерса. Курится в гамаках и на улицах Грибного района."},
}


func _ready() -> void:
	_seed_diary()
	_seed_inventory()


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


func _seed_inventory() -> void:
	# базовые термины — ты уже знаешь, кто ты и где живёшь
	unlock_glossary("des")
	unlock_glossary("nikchemysh")
	unlock_glossary("vastersa")
	add_quest_item({
		"id": "diary_book",
		"name": "Потёртый дневник",
		"description": "Сырые страницы. Без него легко забыть, зачем вообще вставал.",
	})


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
			unlock_glossary("vsegrib")
			unlock_glossary("pokoy_trava")
		"warehouse":
			add_note("wh_first", "Верфи за стенами. Пахнет рыбой, смолой и чужим орём.")
			set_quest_status("quest_work", "Склад/верфи")
			unlock_glossary("birzha_naemn")
			unlock_glossary("faidych")
		"library":
			add_note("lib_first", "Конгрегационная библиотека. Платят лучше. Минус один: безумный Раф Лат Телий.")
			set_quest_status("quest_work", "Библиотека")
			unlock_glossary("kongregacia")
			unlock_glossary("sferidy")
		"shop":
			add_note("shop_first", "Лавка странностей без вывески. Масло, пыль, что-то сладкое.")
			unlock_glossary("suhodzhuy_el")
			unlock_glossary("gornoe_vino")
		"central_library":
			add_note("central_first", "Центральная — пока только порог и заглушка пропуска.")
			if has_central_pass:
				set_quest_status("quest_work", "Пропуск есть")
			unlock_glossary("imperia_sa")
		"playtest":
			add_note("playtest_lab", "Серый короб для механик. Сюжетный маршрут — по лестнице вниз.")


func add_note(note_id: String, text: String) -> void:
	if note_id.is_empty() or text.is_empty():
		return
	for n in diary_notes:
		if str(n.get("id", "")) == note_id:
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
	bits.append("НБ: %d" % money_nb)
	if not shop_choice.is_empty():
		bits.append("Покупка: %s" % shop_choice)
	if has_central_pass:
		bits.append("Пропуск: да")
	else:
		bits.append("Пропуск: нет")
	return " · ".join(bits)


func has_item(item_id: String) -> bool:
	for it in inventory:
		if str(it.get("id", "")) == item_id:
			return true
	for it in quest_items:
		if str(it.get("id", "")) == item_id:
			return true
	return false


func add_item(item: Dictionary) -> bool:
	if item.is_empty():
		return false
	var iid := str(item.get("id", ""))
	if iid.is_empty():
		return false
	if has_item(iid):
		return false
	if inventory.size() >= INV_CAPACITY:
		return false
	inventory.append({
		"id": iid,
		"name": str(item.get("name", iid)),
		"description": str(item.get("description", "")),
		"consumable": bool(item.get("consumable", false)),
	})
	return true


func add_quest_item(item: Dictionary) -> bool:
	if item.is_empty():
		return false
	var iid := str(item.get("id", ""))
	if iid.is_empty():
		return false
	if has_item(iid):
		return false
	quest_items.append({
		"id": iid,
		"name": str(item.get("name", iid)),
		"description": str(item.get("description", "")),
	})
	return true


func unlock_glossary(term_id: String) -> bool:
	if term_id.is_empty():
		return false
	if glossary.has(term_id):
		return false
	if not GLOSSARY_BASE.has(term_id):
		return false
	var src: Dictionary = GLOSSARY_BASE[term_id]
	glossary[term_id] = {
		"name": str(src.get("name", term_id)),
		"description": str(src.get("description", "")),
	}
	return true


func unlock_glossary_many(ids: PackedStringArray) -> void:
	for term_id in ids:
		unlock_glossary(str(term_id))


func inventory_status_line() -> String:
	return "Слоты %d/%d · Квест. %d · Глоссарий %d · НБ %d" % [
		inventory.size(), INV_CAPACITY, quest_items.size(), glossary.size(), money_nb
	]
