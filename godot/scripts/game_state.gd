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

## Phase 5 skills (столбы; полное древо — отдельный OK)
var madness: int = 0
var skill_points: int = 2

## Phase 6 lockpick
var locks_open: Dictionary = {}  # lock_id -> true

## Phase 7 combat (playtest stub)
var weapon_id: String = ""
var weapon_name: String = "Кулаки"
var weapon_damage: int = 2
var skills: Dictionary = {
	"might": 10,
	"mind": 10,
	"motor": 10,
	"core": 10,
}
var skill_floor: Dictionary = {
	"might": 10,
	"mind": 10,
	"motor": 10,
	"core": 10,
}

const APPEARANCE_LABELS := {
	"gaunt": "Худой, впалый",
	"common": "Обычный дес",
	"stocky": "Тяжёлый, узловатый",
}

const SKILL_ORDER := ["might", "mind", "motor", "core"]
const SKILL_META := {
	"might": {
		"name": "Мощь",
		"blurb": "Тело, удар, ноша, стойкость. Дар силы без магии.",
	},
	"mind": {
		"name": "Разум",
		"blurb": "Память, чтение людей и схем. Для никчемыша — без сферидов, но с головой.",
	},
	"motor": {
		"name": "Моторика",
		"blurb": "Точность рук, шаг, взлом, уклонение. То, что спасает в сырых щелях.",
	},
	"core": {
		"name": "Стержень",
		"blurb": "Воля против вони Вастерса и безумия. Держит деса собранным.",
	},
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
	_seed_skills()


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
	apply_appearance_skills(appearance_id)
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


func _seed_skills() -> void:
	apply_appearance_skills(appearance_id if not appearance_id.is_empty() else "common")
	# стартовый запас на плейтест; зеркало может сбросить шаблон, очки вернём
	skill_points = 2


func apply_appearance_skills(appearance: String) -> void:
	var a := appearance
	if a.is_empty():
		a = "common"
	var template := {"might": 10, "mind": 10, "motor": 10, "core": 10}
	match a:
		"gaunt":
			template = {"might": 8, "mind": 12, "motor": 12, "core": 10}
		"stocky":
			template = {"might": 13, "mind": 9, "motor": 8, "core": 12}
		_:
			template = {"might": 10, "mind": 10, "motor": 10, "core": 10}
	for k in SKILL_ORDER:
		var v := int(template[k])
		skills[k] = v
		skill_floor[k] = v
	skill_points = 2


func skill_name(skill_id: String) -> String:
	if SKILL_META.has(skill_id):
		return str(SKILL_META[skill_id].get("name", skill_id))
	return skill_id


func skill_blurb(skill_id: String) -> String:
	if SKILL_META.has(skill_id):
		return str(SKILL_META[skill_id].get("blurb", ""))
	return ""


func get_skill(skill_id: String) -> int:
	return int(skills.get(skill_id, 10))


func skill_modifier(skill_id: String) -> int:
	return int(floor((float(get_skill(skill_id)) - 10.0) / 2.0))


func can_raise_skill(skill_id: String) -> bool:
	if not skills.has(skill_id):
		return false
	return skill_points > 0 and get_skill(skill_id) < 18


func can_lower_skill(skill_id: String) -> bool:
	if not skills.has(skill_id):
		return false
	return get_skill(skill_id) > int(skill_floor.get(skill_id, 8))


func raise_skill(skill_id: String) -> bool:
	if not can_raise_skill(skill_id):
		return false
	skills[skill_id] = get_skill(skill_id) + 1
	skill_points -= 1
	return true


func lower_skill(skill_id: String) -> bool:
	if not can_lower_skill(skill_id):
		return false
	skills[skill_id] = get_skill(skill_id) - 1
	skill_points += 1
	return true


func skills_status_line() -> String:
	var bits: PackedStringArray = []
	for k in SKILL_ORDER:
		var mod := skill_modifier(k)
		var mod_s := ("+%d" % mod) if mod >= 0 else str(mod)
		bits.append("%s %d (%s)" % [skill_name(k), get_skill(k), mod_s])
	bits.append("очки: %d" % skill_points)
	bits.append("безумие: %d" % madness)
	return " · ".join(bits)


## d20 + модификатор; для плейтеста/будущих проверок.
func roll_skill_check(skill_id: String, dc: int = 12) -> Dictionary:
	var roll := int(randi_range(1, 20))
	var mod := skill_modifier(skill_id)
	var total := roll + mod
	var ok := total >= dc
	return {
		"skill": skill_id,
		"name": skill_name(skill_id),
		"roll": roll,
		"mod": mod,
		"total": total,
		"dc": dc,
		"ok": ok,
	}


func format_skill_check(result: Dictionary) -> String:
	var mod := int(result.get("mod", 0))
	var mod_s := ("+%d" % mod) if mod >= 0 else str(mod)
	var verdict := "успех" if bool(result.get("ok", false)) else "провал"
	return "%s: d20=%d %s = %d против DC %d — %s." % [
		str(result.get("name", "?")),
		int(result.get("roll", 0)),
		mod_s,
		int(result.get("total", 0)),
		int(result.get("dc", 0)),
		verdict,
	]


func is_lock_open(lock_id: String) -> bool:
	if lock_id.is_empty():
		return false
	return bool(locks_open.get(lock_id, false))


func set_lock_open(lock_id: String, value: bool = true) -> void:
	if lock_id.is_empty():
		return
	var first := value and not bool(locks_open.get(lock_id, false))
	locks_open[lock_id] = value
	if value:
		add_note("lock_" + lock_id, "Замок «%s» поддался. Щёлкнуло тихо, как сырой сустав." % lock_id)
		if first and lock_id == "alley_chest":
			add_item({"id": "nb_token_alley", "name": "Жетон НБ", "description": "Из сундука в Грибном. Счётный жетон Биржи.", "consumable": false})
			add_item({"id": "damp_wrap", "name": "Сырой свёрток", "description": "Тряпка с чем-то твёрдым внутри. Пока не разворачивал.", "consumable": false})
			money_nb += 2


func lockpick_max_attempts() -> int:
	# база 3; положительная Моторика даёт доп. попытки (макс +2)
	var bonus := maxi(0, skill_modifier("motor"))
	bonus = mini(bonus, 2)
	return 3 + bonus


func equip_weapon(wid: String, wname: String, dmg: int) -> void:
	weapon_id = wid
	weapon_name = wname if not wname.is_empty() else wid
	weapon_damage = maxi(1, dmg)
	add_note("weapon_equip", "Взял в руки: %s." % weapon_name)


func attack_damage() -> int:
	var bonus := maxi(0, skill_modifier("might"))
	return maxi(1, weapon_damage + bonus)


func combat_status_line() -> String:
	return "Оружие: %s (+%d) · удар %d" % [weapon_name, weapon_damage, attack_damage()]

