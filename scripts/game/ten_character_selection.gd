extends RefCounted
## The ten pictured characters live in a new, separate selection file.
## Legacy game saves, progression, and the older five-look file are untouched.
const SAVE_PATH := "user://apex_ten_character_v1.json"
const TEMP_PATH := "user://apex_ten_character_v1.json.tmp"
const LEGACY_SELECTION_PATH := "user://apex_five_look_draft_v1.json"
const LOOKS := ["standard", "shadow", "speed_10", "health_10", "speed_20", "health_20", "speed_30", "health_30", "speed_40", "health_40"]
const SUPERIOR_LOOKS := ["crimson_blade", "frost_tech", "gold_knight", "yellow_goggles", "green_ghillie", "blue_swat", "purple_reaper", "red_samurai", "neon_cyber", "warrior_monk"]
const ALL_LOOKS := LOOKS + SUPERIOR_LOOKS
const SUPERIOR_COSTS := {"crimson_blade": 20, "frost_tech": 20, "gold_knight": 30, "yellow_goggles": 30, "green_ghillie": 40, "blue_swat": 40, "purple_reaper": 50, "red_samurai": 50, "neon_cyber": 60, "warrior_monk": 60}
const WEAPONS := ["thor", "aurora", "wolverine", "dracula", "leviathan"]
const LOOK_LABELS := {
	"standard": "Standard", "shadow": "Shadow", "speed_10": "Violet Runner", "health_10": "Golden Guard",
	"speed_20": "Wrapped Runner", "health_20": "Fox Guard", "speed_30": "Electric Runner", "health_30": "Flame Guard",
	"speed_40": "Royal Runner", "health_40": "Straw Hat Guard",
	"crimson_blade": "Crimson Blade", "frost_tech": "Frost Tech", "gold_knight": "Gold Knight", "yellow_goggles": "Yellow Goggles",
	"green_ghillie": "Ghillie", "blue_swat": "SWAT", "purple_reaper": "Reaper", "red_samurai": "Samurai", "neon_cyber": "Neon", "warrior_monk": "Warrior Monk"
}
const WEAPON_LABELS := {"thor": "Thor", "aurora": "Aurora Fang", "wolverine": "Wolverine", "dracula": "Dracula", "leviathan": "Leviathan Axe"}
const LOOK_NAMES := LOOK_LABELS
const WEAPON_NAMES := WEAPON_LABELS
const SPEED_MULTIPLIERS := {"speed_10": 1.10, "speed_20": 1.20, "speed_30": 1.30, "speed_40": 1.40, "crimson_blade": 1.10, "gold_knight": 1.15, "green_ghillie": 1.20, "purple_reaper": 1.25, "neon_cyber": 1.30}
const HEALTH_MULTIPLIERS := {"health_10": 1.10, "health_20": 1.20, "health_30": 1.30, "health_40": 1.40, "frost_tech": 1.10, "yellow_goggles": 1.15, "blue_swat": 1.20, "red_samurai": 1.25, "warrior_monk": 1.30}

static func speed_multiplier(look: String) -> float:
	return float(SPEED_MULTIPLIERS.get(look, 1.0))

static func health_multiplier(look: String) -> float:
	return float(HEALTH_MULTIPLIERS.get(look, 1.0))

static func bonus_label(look: String) -> String:
	if SPEED_MULTIPLIERS.has(look):
		return "+%d%% SPEED" % roundi((speed_multiplier(look) - 1.0) * 100.0)
	if HEALTH_MULTIPLIERS.has(look):
		return "+%d%% HEALTH" % roundi((health_multiplier(look) - 1.0) * 100.0)
	return "NO BONUS"

static func portrait_path(look: String) -> String:
	if SUPERIOR_LOOKS.has(look):
		return "res://assets/characters/superior-update/%s/portrait.png" % look
	if look == "standard":
		return "res://assets/characters/five-look-draft/red_scarf/portrait.png"
	return "res://assets/characters/ten-character-update/%s/portrait.png" % look

static func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return {}
	var data: Variant = JSON.parse_string(file.get_as_text())
	return data if data is Dictionary else {}

static func _saved_superior_unlocked(id: String) -> bool:
	# Keep this standalone static helper independent of autoload initialization.
	var saved := _read_json("user://apex_save_v3.json")
	var owned: Variant = saved.get("superior_unlocks", {})
	return owned is Dictionary and bool(owned.get(id, false))

static func read_selection() -> Dictionary:
	var result := {"look": "standard", "weapon": "aurora"}
	if FileAccess.file_exists(SAVE_PATH):
		var data := _read_json(SAVE_PATH)
		if ALL_LOOKS.has(str(data.get("look", ""))) and (not SUPERIOR_LOOKS.has(str(data.look)) or _saved_superior_unlocked(str(data.look))):
			result.look = str(data.look)
		if WEAPONS.has(str(data.get("weapon", ""))):
			result.weapon = str(data.weapon)
	else:
		# Only migrate the independent equipped weapon; old looks are no longer
		# in the new active roster. Never edit or remove the old file.
		var old := _read_json(LEGACY_SELECTION_PATH)
		if WEAPONS.has(str(old.get("weapon", ""))):
			result.weapon = str(old.weapon)
	return result

static func portrait(look: String) -> Texture2D:
	return load(portrait_path(look if ALL_LOOKS.has(look) else "standard"))

static func weapon_icon(weapon: String) -> Texture2D:
	var safe := weapon if WEAPONS.has(weapon) else "aurora"
	return load("res://assets/characters/five-look-draft/weapons/%s-icon.png" % safe)

static func save_selection(look: String, weapon: String) -> bool:
	if not ALL_LOOKS.has(look) or not WEAPONS.has(weapon) or (SUPERIOR_LOOKS.has(look) and not _saved_superior_unlocked(look)):
		return false
	# Atomic write to our own file: an interrupted selection never overwrites
	# legacy saves, progression, or the previously valid selection.
	var file := FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	if not file:
		return false
	file.store_string(JSON.stringify({"schema": 1, "look": look, "weapon": weapon}))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		DirAccess.remove_absolute(TEMP_PATH)
		return false
	if DirAccess.rename_absolute(TEMP_PATH, SAVE_PATH) != OK:
		DirAccess.remove_absolute(TEMP_PATH)
		return false
	return true
