extends RefCounted
## PRIVATE DRAFT: Five appearance choices and five melee weapon appearances.
## Selection is written ONLY to a separate cosmetic file.  The existing game
## save, legacy IDs, purchases, character bonuses and weapon statistics are not
## modified by this script.  The image edits are reference-derived draft art.

const COSMETIC_PATH := "user://apex_five_look_draft_v1.json"
const TEMP_PATH := "user://apex_five_look_draft_v1.json.tmp"
const ROOT := "res://assets/characters/five-look-draft/"
const LOOKS := ["red_scarf", "white_hood", "blue_tactical", "green_fighter", "yellow_hazmat"]
const WEAPONS := ["aurora", "thor", "wolverine", "dracula", "leviathan"]
const LOOK_NAMES := {
	"red_scarf": "Red Scarf", "white_hood": "White Hood", "blue_tactical": "Blue Tactical",
	"green_fighter": "Green Fighter", "yellow_hazmat": "Yellow Hazmat"
}
const WEAPON_NAMES := {
	"aurora": "Aurora Fang", "thor": "Thor Hammer", "wolverine": "Wolverine Claws",
	"dracula": "Dracula Blade", "leviathan": "Leviathan Axe"
}

static func read_selection() -> Dictionary:
	var result := {"look": "red_scarf", "weapon": "aurora"}
	if not FileAccess.file_exists(COSMETIC_PATH):
		return result
	var f := FileAccess.open(COSMETIC_PATH, FileAccess.READ)
	if f == null:
		return result
	var data: Variant = JSON.parse_string(f.get_as_text())
	if not data is Dictionary:
		return result
	if data.get("look") is String and LOOKS.has(data.look):
		result.look = data.look
	if data.get("weapon") is String and WEAPONS.has(data.weapon):
		result.weapon = data.weapon
	return result

static func save_selection(look: String, weapon: String) -> bool:
	if not LOOKS.has(look) or not WEAPONS.has(weapon):
		return false
	var f := FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("Could not save cosmetic selection; existing game save is unchanged")
		return false
	f.store_string(JSON.stringify({"schema": 1, "look": look, "weapon": weapon}))
	f.flush()
	var write_error := f.get_error()
	f.close()
	if write_error != OK:
		DirAccess.remove_absolute(TEMP_PATH)
		return false
	var err := DirAccess.rename_absolute(TEMP_PATH, COSMETIC_PATH)
	if err != OK:
		DirAccess.remove_absolute(TEMP_PATH)
		push_warning("Could not replace cosmetic selection; existing game save is unchanged")
		return false
	return true

static func portrait(id: String) -> Texture2D:
	var safe := id if LOOKS.has(id) else "red_scarf"
	return load(ROOT + safe + "/portrait.png")

static func weapon_icon(id: String) -> Texture2D:
	var safe := id if WEAPONS.has(id) else "aurora"
	return load(ROOT + "weapons/" + safe + "-icon.png")
