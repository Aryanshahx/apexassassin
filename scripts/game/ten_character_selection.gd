extends RefCounted
## The ten pictured characters live in a new, separate selection file.
## Legacy game saves, progression, and the older five-look file are untouched.
const SAVE_PATH := "user://apex_ten_character_v1.json"
const TEMP_PATH := "user://apex_ten_character_v1.json.tmp"
const LEGACY_SELECTION_PATH := "user://apex_five_look_draft_v1.json"
const LOOKS := ["standard", "shadow", "speed_10", "health_10", "speed_20", "health_20", "speed_30", "health_30", "speed_40", "health_40"]
const WEAPONS := ["thor", "aurora", "wolverine", "dracula", "leviathan"]
const LOOK_LABELS := {
	"standard": "Standard", "shadow": "Shadow", "speed_10": "Violet Runner", "health_10": "Golden Guard",
	"speed_20": "Wrapped Runner", "health_20": "Fox Guard", "speed_30": "Electric Runner", "health_30": "Flame Guard",
	"speed_40": "Royal Runner", "health_40": "Straw Hat Guard"
}
const WEAPON_LABELS := {"thor": "Thor", "aurora": "Aurora Fang", "wolverine": "Wolverine", "dracula": "Dracula", "leviathan": "Leviathan Axe"}
const LOOK_NAMES := LOOK_LABELS
const WEAPON_NAMES := WEAPON_LABELS
const SPEED_MULTIPLIERS := {"speed_10": 1.10, "speed_20": 1.20, "speed_30": 1.30, "speed_40": 1.40}
const HEALTH_MULTIPLIERS := {"health_10": 1.10, "health_20": 1.20, "health_30": 1.30, "health_40": 1.40}

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

static func read_selection() -> Dictionary:
	var result := {"look": "standard", "weapon": "aurora"}
	if FileAccess.file_exists(SAVE_PATH):
		var data := _read_json(SAVE_PATH)
		if LOOKS.has(str(data.get("look", ""))):
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
	return load(portrait_path(look if LOOKS.has(look) else "standard"))

static func weapon_icon(weapon: String) -> Texture2D:
	var safe := weapon if WEAPONS.has(weapon) else "aurora"
	return load("res://assets/characters/five-look-draft/weapons/%s-icon.png" % safe)

static func save_selection(look: String, weapon: String) -> bool:
	if not LOOKS.has(look) or not WEAPONS.has(weapon):
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
