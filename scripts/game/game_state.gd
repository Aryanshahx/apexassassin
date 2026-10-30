extends Node

const SAVE_PATH := "user://apex_save_v3.json"
const OLD_SAVE_PATH := "user://apex_save_v2.json"
const TOTAL_LEVELS := 100
const BASE_SPEED := 190.0
const BASE_HEALTH := 3.0

const CHARACTERS := {
	"ronin": {"name": "Ronin", "cost": 0, "speed_bonus": 0.0, "health_bonus": 0.0, "blurb": "Standard raven-blade specialist."},
	"sable": {"name": "Sable", "cost": 20, "speed_bonus": 0.0, "health_bonus": 0.0, "blurb": "Standard night operative."},
	"nova": {"name": "Nova", "cost": 40, "speed_bonus": 0.10, "health_bonus": 0.0, "blurb": "+10% speed twin-blade runner."},
	"aegis": {"name": "Aegis", "cost": 60, "speed_bonus": 0.0, "health_bonus": 0.10, "blurb": "+10% health armored guard."},
	"dash": {"name": "Dash", "cost": 80, "speed_bonus": 0.20, "health_bonus": 0.0, "blurb": "+20% speed courier."},
	"sentinel": {"name": "Sentinel", "cost": 120, "speed_bonus": 0.0, "health_bonus": 0.20, "blurb": "+20% health warden."},
	"sage": {"name": "Sage", "cost": 140, "speed_bonus": 0.30, "health_bonus": 0.0, "blurb": "+30% speed elder."},
	"crimson": {"name": "Crimson", "cost": 180, "speed_bonus": 0.0, "health_bonus": 0.30, "blurb": "+30% health red hood."},
	"fiesta": {"name": "Fiesta", "cost": 220, "speed_bonus": 0.40, "health_bonus": 0.0, "blurb": "+40% speed festival mask."},
	"oni": {"name": "Oni", "cost": 260, "speed_bonus": 0.0, "health_bonus": 0.40, "blurb": "+40% health demon mask."},
}
const CHARACTER_ORDER := ["ronin", "sable", "nova", "aegis", "dash", "sentinel", "sage", "crimson", "fiesta", "oni"]

const KNIVES := {
	"standard": {"name": "Standard", "unlock_level": 1, "cost": 0, "damage": 1, "cooldown": 0.32, "range": 54.0},
	"spear": {"name": "Spearpoint", "unlock_level": 16, "cost": 0, "damage": 1, "cooldown": 0.30, "range": 60.0},
	"breaker": {"name": "Breaker", "unlock_level": 31, "cost": 0, "damage": 2, "cooldown": 0.34, "range": 54.0},
	"batwing": {"name": "Batwing", "unlock_level": 36, "cost": 0, "damage": 1, "cooldown": 0.26, "range": 58.0},
	"spearhead": {"name": "Spearhead", "unlock_level": 46, "cost": 0, "damage": 2, "cooldown": 0.30, "range": 62.0},
	"wingblade": {"name": "Wingblade", "unlock_level": 56, "cost": 0, "damage": 2, "cooldown": 0.26, "range": 60.0},
	"crimson": {"name": "Crimson Fang", "unlock_level": 1, "cost": 60, "damage": 2, "cooldown": 0.30, "range": 58.0},
	"hammer": {"name": "Storm Hammer", "unlock_level": 1, "cost": 80, "damage": 3, "cooldown": 0.40, "range": 52.0},
	"sickle": {"name": "Sickle", "unlock_level": 1, "cost": 90, "damage": 2, "cooldown": 0.28, "range": 60.0},
	"claws": {"name": "Triple Claws", "unlock_level": 1, "cost": 110, "damage": 2, "cooldown": 0.24, "range": 56.0},
	"butcher": {"name": "Butcher", "unlock_level": 1, "cost": 130, "damage": 3, "cooldown": 0.34, "range": 56.0},
	"frost": {"name": "Frost Wave", "unlock_level": 1, "cost": 150, "damage": 2, "cooldown": 0.26, "range": 64.0},
	"tree": {"name": "Holiday Tree", "unlock_level": 1, "cost": 170, "damage": 3, "cooldown": 0.32, "range": 58.0},
	"candy": {"name": "Candy Cane", "unlock_level": 1, "cost": 190, "damage": 2, "cooldown": 0.22, "range": 60.0},
	"bat": {"name": "Slugger", "unlock_level": 1, "cost": 210, "damage": 4, "cooldown": 0.42, "range": 54.0},
	"vip": {"name": "VIP Star", "unlock_level": 1, "cost": 260, "damage": 3, "cooldown": 0.24, "range": 66.0},
	"apex": {"name": "Apex Edge", "unlock_level": 1, "cost": 320, "damage": 4, "cooldown": 0.26, "range": 68.0},
}
const KNIFE_ORDER := ["standard", "spear", "breaker", "batwing", "spearhead", "wingblade", "crimson", "hammer", "sickle", "claws", "butcher", "frost", "tree", "candy", "bat", "vip", "apex"]

var gems: int = 0
var cash: int = 119
var current_level: int = 1
var unlocked_level: int = 1
var total_kills: int = 0
var flawless_count: int = 0
var mission1_claimed := false
var mission2_claimed := false
var mission3_claimed := false
var sound_enabled := true
var haptics_enabled := true
var upgrades := {"health": 0, "damage": 0, "speed": 0}
var selected_assassin := "ronin"
var unlocked_assassins := {"ronin": true}
var selected_knife := "standard"
var unlocked_knives := {"standard": true}
var best_stars := {}
var last_wheel_day := ""

func _ready() -> void:
	load_game()

func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var p: Variant = JSON.parse_string(f.get_as_text())
	return p if p is Dictionary else {}

func load_game() -> void:
	var p := _read_json(SAVE_PATH)
	if p.is_empty():
		p = _read_json(OLD_SAVE_PATH)
	if p.is_empty():
		return
	gems = maxi(0, int(p.get("gems", 0)))
	cash = maxi(0, int(p.get("cash", 119)))
	current_level = clampi(int(p.get("current_level", 1)), 1, TOTAL_LEVELS)
	unlocked_level = clampi(int(p.get("unlocked_level", 1)), 1, TOTAL_LEVELS)
	total_kills = maxi(0, int(p.get("total_kills", 0)))
	flawless_count = maxi(0, int(p.get("flawless_count", 0)))
	mission1_claimed = bool(p.get("mission1_claimed", false))
	mission2_claimed = bool(p.get("mission2_claimed", false))
	mission3_claimed = bool(p.get("mission3_claimed", false))
	sound_enabled = bool(p.get("sound_enabled", true))
	haptics_enabled = bool(p.get("haptics_enabled", true))
	var old_sel: Variant = p.get("selected_assassin", "ronin")
	if old_sel is String and CHARACTERS.has(old_sel):
		selected_assassin = old_sel
	else:
		selected_assassin = "nova" if int(old_sel) == 1 else "ronin"
	var u: Variant = p.get("upgrades", {})
	if u is Dictionary:
		for k in upgrades:
			upgrades[k] = clampi(int(u.get(k, 0)), 0, 5)
	var unlocked: Variant = p.get("unlocked_assassins", {})
	if unlocked is Dictionary:
		for k in unlocked:
			if CHARACTERS.has(k) and bool(unlocked[k]):
				unlocked_assassins[k] = true
	unlocked_assassins["ronin"] = true
	if not unlocked_assassins.has(selected_assassin):
		selected_assassin = "ronin"
	selected_knife = String(p.get("selected_knife", "standard"))
	if not KNIVES.has(selected_knife):
		selected_knife = "standard"
	var uk: Variant = p.get("unlocked_knives", {})
	if uk is Dictionary:
		for k in uk:
			if KNIVES.has(k) and bool(uk[k]):
				unlocked_knives[k] = true
	unlocked_knives["standard"] = true
	_refresh_level_knives()
	if not is_knife_unlocked(selected_knife):
		selected_knife = "standard"
	var stars: Variant = p.get("best_stars", {})
	if stars is Dictionary:
		best_stars = stars
	last_wheel_day = String(p.get("last_wheel_day", ""))

func save_game() -> void:
	var data := {
		"schema": 4, "gems": gems, "cash": cash, "current_level": current_level,
		"unlocked_level": unlocked_level, "total_kills": total_kills,
		"flawless_count": flawless_count,
		"mission1_claimed": mission1_claimed, "mission2_claimed": mission2_claimed,
		"mission3_claimed": mission3_claimed, "sound_enabled": sound_enabled,
		"haptics_enabled": haptics_enabled, "upgrades": upgrades,
		"selected_assassin": selected_assassin, "unlocked_assassins": unlocked_assassins,
		"selected_knife": selected_knife, "unlocked_knives": unlocked_knives,
		"best_stars": best_stars, "last_wheel_day": last_wheel_day,
	}
	var tmp := SAVE_PATH + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("Could not write save file")
		return
	f.store_string(JSON.stringify(data))
	f.close()
	DirAccess.rename_absolute(tmp, SAVE_PATH)

func start_level(level: int) -> void:
	current_level = clampi(level, 1, TOTAL_LEVELS)
	save_game()
	get_tree().change_scene_to_file("res://scenes/level/level.tscn")

func complete_level(kills: int, flawless: bool, stars: int) -> void:
	total_kills += kills
	if flawless:
		flawless_count += 1
	cash += 50 + current_level * 5
	var key := str(current_level)
	best_stars[key] = maxi(int(best_stars.get(key, 0)), clampi(stars, 1, 3))
	unlocked_level = maxi(unlocked_level, mini(current_level + 1, TOTAL_LEVELS))
	current_level = unlocked_level
	_refresh_level_knives()
	save_game()

func character() -> Dictionary:
	return CHARACTERS.get(selected_assassin, CHARACTERS.ronin)

func knife() -> Dictionary:
	return KNIVES.get(selected_knife, KNIVES.standard)

func max_health() -> float:
	return BASE_HEALTH * (1.0 + float(character().get("health_bonus", 0.0))) + float(upgrades.health)

func player_damage() -> int:
	return int(knife().damage) + int(upgrades.damage)

func player_speed() -> float:
	return BASE_SPEED * (1.0 + float(character().get("speed_bonus", 0.0))) + int(upgrades.speed) * 14.0

func attack_cooldown() -> float:
	return float(knife().cooldown)

func attack_range() -> float:
	return float(knife().range)

func upgrade_cost(kind: String) -> int:
	return 100 + int(upgrades.get(kind, 0)) * 150

func buy_upgrade(kind: String) -> bool:
	if not upgrades.has(kind):
		return false
	var cost := upgrade_cost(kind)
	if cash < cost or int(upgrades[kind]) >= 5:
		return false
	cash -= cost
	upgrades[kind] += 1
	save_game()
	return true

func is_unlocked(id: String) -> bool:
	return bool(unlocked_assassins.get(id, false))

func unlock_character(id: String) -> bool:
	if not CHARACTERS.has(id) or is_unlocked(id):
		return false
	var cost := int(CHARACTERS[id].cost)
	if gems < cost:
		return false
	gems -= cost
	unlocked_assassins[id] = true
	selected_assassin = id
	save_game()
	return true

func select_character(id: String) -> bool:
	if not is_unlocked(id):
		return false
	selected_assassin = id
	save_game()
	return true

func _refresh_level_knives() -> void:
	for id in KNIVES:
		var k: Dictionary = KNIVES[id]
		if int(k.unlock_level) > 1 and unlocked_level >= int(k.unlock_level):
			unlocked_knives[id] = true

func is_knife_unlocked(id: String) -> bool:
	return bool(unlocked_knives.get(id, false))

func knife_count() -> int:
	var n := 0
	for id in KNIVES:
		if is_knife_unlocked(id):
			n += 1
	return n

func buy_knife(id: String) -> bool:
	if not KNIVES.has(id) or is_knife_unlocked(id):
		return false
	var k: Dictionary = KNIVES[id]
	if int(k.unlock_level) > 1:
		return false
	var cost := int(k.cost)
	if gems < cost:
		return false
	gems -= cost
	unlocked_knives[id] = true
	selected_knife = id
	save_game()
	return true

func select_knife(id: String) -> bool:
	if not is_knife_unlocked(id):
		return false
	selected_knife = id
	save_game()
	return true

func add_gems(n: int) -> void:
	gems += maxi(0, n)
	save_game()

func can_spin_wheel() -> bool:
	return last_wheel_day != Time.get_date_string_from_system()

func spin_wheel() -> int:
	if not can_spin_wheel():
		return 0
	last_wheel_day = Time.get_date_string_from_system()
	var prize := 50 + randi() % 101
	cash += prize
	save_game()
	return prize

func vibrate(ms: int) -> void:
	if haptics_enabled and OS.has_feature("mobile"):
		Input.vibrate_handheld(ms)
