extends Node

const SAVE_PATH := "user://apex_save_v3.json"
const OLD_SAVE_PATH := "user://apex_save_v2.json"
const TOTAL_LEVELS := 100

const CHARACTERS := {
	"ronin": {"name": "Ronin", "cost": 0, "speed": 190.0, "health": 1, "damage": 1, "blurb": "Balanced raven-blade specialist."},
	"nova": {"name": "Nova", "cost": 40, "speed": 225.0, "health": 1, "damage": 1, "blurb": "Faster twin-blade runner. Light armor."},
}

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
		selected_assassin = "nova" if int(old_sel) == 1 and bool(p.get("nova_unlocked", false)) else "ronin"
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
	var stars: Variant = p.get("best_stars", {})
	if stars is Dictionary:
		best_stars = stars
	last_wheel_day = String(p.get("last_wheel_day", ""))

func save_game() -> void:
	var data := {
		"schema": 3, "gems": gems, "cash": cash, "current_level": current_level,
		"unlocked_level": unlocked_level, "total_kills": total_kills,
		"flawless_count": flawless_count,
		"mission1_claimed": mission1_claimed, "mission2_claimed": mission2_claimed,
		"mission3_claimed": mission3_claimed, "sound_enabled": sound_enabled,
		"haptics_enabled": haptics_enabled, "upgrades": upgrades,
		"selected_assassin": selected_assassin, "unlocked_assassins": unlocked_assassins,
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
	save_game()

func character() -> Dictionary:
	return CHARACTERS.get(selected_assassin, CHARACTERS.ronin)

func max_health() -> int:
	return int(character().health) + int(upgrades.health)

func player_damage() -> int:
	return int(character().damage) + int(upgrades.damage)

func player_speed() -> float:
	return float(character().speed) + int(upgrades.speed) * 14.0

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
