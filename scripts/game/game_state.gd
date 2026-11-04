extends Node

const SAVE_PATH := "user://apex_save_v3.json"
const OLD_SAVE_PATH := "user://apex_save_v2.json"
const TOTAL_LEVELS := 100
const BASE_SPEED := 190.0
const PLAYER_SPEED_MULTIPLIER := 1.20
const VAULT_CHARACTER := "v72_elite"
const LEGACY_VAULT_CHARACTER := "vault_phantom"
const KEY_LEVEL_CHANCE := 0.42
const BASE_HEALTH := 1000.0
# One purchased upgrade still adds one standard enemy hit of protection.
const HEALTH_UPGRADE_AMOUNT := 100.0
# Additive one-time milestones use statistics already present in old saves.
const MISSION_MILESTONES := [
	{"id": "levels_10", "title": "CLEAR 10 LEVELS", "stat": "levels", "goal": 10, "reward": 250, "icon": "key"},
	{"id": "stars_10", "title": "10 THREE-STAR LEVELS", "stat": "stars", "goal": 10, "reward": 400, "icon": "target"},
]

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
	# The twelve user-selected screenshot characters are immediately selectable.
	# Their bonuses match the screenshot; the older roster and its bonuses remain.
	"ref01": {"name": "Bandaged", "cost": 0, "speed_bonus": 0.10, "health_bonus": 0.0, "blurb": "+10% speed"},
	"ref02": {"name": "Orange Beast", "cost": 0, "speed_bonus": 0.0, "health_bonus": 0.10, "blurb": "+10% health"},
	"ref03": {"name": "Yellow Goggles", "cost": 0, "speed_bonus": 0.15, "health_bonus": 0.0, "blurb": "+15% speed"},
	"ref04": {"name": "Blue Beast", "cost": 0, "speed_bonus": 0.0, "health_bonus": 0.15, "blurb": "+15% health"},
	"ref05": {"name": "Green Visor", "cost": 0, "speed_bonus": 0.20, "health_bonus": 0.0, "blurb": "+20% speed"},
	"ref06": {"name": "Purple Outfit", "cost": 0, "speed_bonus": 0.0, "health_bonus": 0.20, "blurb": "+20% health"},
	"ref07": {"name": "Festive Bird", "cost": 0, "speed_bonus": 0.25, "health_bonus": 0.0, "blurb": "+25% speed"},
	"ref08": {"name": "Clown", "cost": 0, "speed_bonus": 0.0, "health_bonus": 0.25, "blurb": "+25% health"},
	"ref09": {"name": "Green Creature", "cost": 0, "speed_bonus": 0.30, "health_bonus": 0.0, "blurb": "+30% speed"},
	"ref10": {"name": "Boxer", "cost": 0, "speed_bonus": 0.0, "health_bonus": 0.30, "blurb": "+30% health"},
	"ref11": {"name": "Blonde and Pink", "cost": 0, "speed_bonus": 0.35, "health_bonus": 0.0, "blurb": "+35% speed"},
	"ref12": {"name": "Green Shell", "cost": 0, "speed_bonus": 0.0, "health_bonus": 0.35, "blurb": "+35% health"},
	# An original secret character, earned only through the three-key lockers.
	"vault_phantom": {"name": "Vault Phantom", "cost": 0, "speed_bonus": 0.15, "health_bonus": 0.15, "blurb": "Legacy locker reward"},
	# Five supplied stills are freely selectable; Elite is the unique key prize.
	"v72_commando": {"name": "Commando", "cost": 0, "speed_bonus": 0.0, "health_bonus": 0.0, "blurb": "Tactical operative"},
	"v72_agent": {"name": "Agent", "cost": 0, "speed_bonus": 0.0, "health_bonus": 0.0, "blurb": "Covert operative"},
	"v72_mercenary": {"name": "Mercenary", "cost": 0, "speed_bonus": 0.0, "health_bonus": 0.0, "blurb": "Experienced fighter"},
	"v72_swat": {"name": "SWAT", "cost": 0, "speed_bonus": 0.0, "health_bonus": 0.0, "blurb": "Armored operative"},
	"v72_hunter": {"name": "Hunter", "cost": 0, "speed_bonus": 0.0, "health_bonus": 0.0, "blurb": "Stealth specialist"},
	"v72_elite": {"name": "Elite", "cost": 0, "speed_bonus": 0.15, "health_bonus": 0.15, "blurb": "Locker reward: +15% speed and health"},

}
const REFERENCE_ORDER := ["ref01", "ref02", "ref03", "ref04", "ref05", "ref06", "ref07", "ref08", "ref09", "ref10", "ref11", "ref12"]
const LEGACY_ORDER := ["ronin", "sable", "nova", "aegis", "dash", "sentinel", "sage", "crimson", "fiesta", "oni"]
# Retain old IDs and their saved stats, but only the six new designs are shown.
const V72_FREE_ORDER := ["v72_commando", "v72_agent", "v72_mercenary", "v72_swat", "v72_hunter"]
const CHARACTER_ORDER := V72_FREE_ORDER + [VAULT_CHARACTER]
# Give previously saved assassins the approved visual style without changing
# their IDs, bonuses, selected state, unlocks or save schema.
const LEGACY_ART_INDEX := {"ronin": 1, "sable": 2, "nova": 3, "aegis": 4, "dash": 5, "sentinel": 6, "sage": 7, "crimson": 8, "fiesta": 9, "oni": 10}

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
# The first three old boolean claims remain separate and unmodified.
var mission_claims := {}
# New fields are additive. Unknown/removed mission claims are retained.
var superior_unlocks := {}
var pending_bonus_level := 0
var completed_bonus_levels := {}
var active_bonus_level := 0
var sound_enabled := true
var haptics_enabled := true
var upgrades := {"health": 0, "damage": 0, "speed": 0}
var selected_assassin := "ronin"
var unlocked_assassins := {"ronin": true}
var selected_knife := "standard"
var unlocked_knives := {"standard": true}
var best_stars := {}
var last_wheel_day := ""
# Key/locker fields are additive: old schema-4 saves continue to load intact.
var keys_collected := 0
var key_levels_claimed := {}
var locker_board := {}
# Keep immutable level data and depot textures alive across level changes. This
# avoids re-parsing the full 100-level file and re-uploading map art every win.
var _level_catalog: Array = []
var _depot_texture_cache := {}

func level_data(number: int) -> Dictionary:
	if _level_catalog.is_empty():
		var f := FileAccess.open("res://data/levels/levels.json", FileAccess.READ)
		if f == null:
			push_error("levels.json missing")
			return {}
		var parsed: Variant = JSON.parse_string(f.get_as_text())
		if not parsed is Dictionary or not parsed.has("levels"):
			push_error("Invalid levels.json")
			return {}
		_level_catalog = parsed.levels
	if _level_catalog.is_empty():
		return {}
	return _level_catalog[clampi(number - 1, 0, _level_catalog.size() - 1)]

func depot_textures() -> Dictionary:
	if _depot_texture_cache.is_empty():
		for color in ["blue", "red", "olive"]:
			for part in ["cap_a", "cap_b", "cap_l", "cap_r", "mid", "mid_h", "depth", "depth_h"]:
				_depot_texture_cache[color + "_" + part] = load("res://assets/environment/depot/c_%s_%s.png" % [color, part])
	return _depot_texture_cache

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
	mission_claims = {}
	var saved_missions: Variant = p.get("mission_claims", {})
	if saved_missions is Dictionary:
		for id in saved_missions:
			if bool(saved_missions[id]):
				mission_claims[String(id)] = true
	superior_unlocks = {}
	var saved_superior: Variant = p.get("superior_unlocks", {})
	if saved_superior is Dictionary:
		for id in saved_superior:
			if bool(saved_superior[id]): superior_unlocks[String(id)] = true
	completed_bonus_levels = {}
	var saved_bonus: Variant = p.get("completed_bonus_levels", {})
	if saved_bonus is Dictionary:
		for id in saved_bonus:
			var milestone := int(id)
			if milestone >= 10 and milestone <= TOTAL_LEVELS and milestone % 10 == 0 and bool(saved_bonus[id]):
				completed_bonus_levels[str(milestone)] = true
	pending_bonus_level = int(p.get("pending_bonus_level", 0))
	if pending_bonus_level < 10 or pending_bonus_level > TOTAL_LEVELS or pending_bonus_level % 10 != 0 or bool(completed_bonus_levels.get(str(pending_bonus_level), false)):
		pending_bonus_level = 0
	active_bonus_level = 0
	sound_enabled = bool(p.get("sound_enabled", true))
	haptics_enabled = bool(p.get("haptics_enabled", true))
	var old_sel: Variant = p.get("selected_assassin", "ronin")
	if old_sel is String and CHARACTERS.has(old_sel):
		selected_assassin = old_sel
	elif old_sel is int or old_sel is float:
		selected_assassin = "nova" if int(old_sel) == 1 else "ronin"
	else:
		# Removed v0.5.6 roster IDs are no longer playable. Keep every other
		# saved field and fall back safely to the original free assassin.
		selected_assassin = "ronin"
	var u: Variant = p.get("upgrades", {})
	if u is Dictionary:
		for k in upgrades:
			upgrades[k] = clampi(int(u.get(k, 0)), 0, 5)
	var unlocked: Variant = p.get("unlocked_assassins", {})
	unlocked_assassins = {}
	if unlocked is Dictionary:
		for k in unlocked:
			# Do not discard old/unknown entitlement fields during migration.
			if bool(unlocked[k]):
				unlocked_assassins[k] = true
	unlocked_assassins["ronin"] = true
	# The old unique locker prize becomes Elite at no extra cost. Keep the
	# original ID and a selected legacy character's existing gameplay bonuses.
	if bool(unlocked_assassins.get(LEGACY_VAULT_CHARACTER, false)):
		unlocked_assassins[VAULT_CHARACTER] = true
	if not is_unlocked(selected_assassin):
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
	keys_collected = clampi(int(p.get("keys_collected", 0)), 0, 2)
	key_levels_claimed = {}
	var saved_keys: Variant = p.get("key_levels_claimed", {})
	if saved_keys is Dictionary:
		for k in saved_keys:
			var number := int(k)
			if number >= 1 and number <= TOTAL_LEVELS and bool(saved_keys[k]):
				key_levels_claimed[str(number)] = true
	locker_board = _validated_locker_board(p.get("locker_board", {}))

func save_game() -> void:
	var data := {
		"schema": 4, "gems": gems, "cash": cash, "current_level": current_level,
		"unlocked_level": unlocked_level, "total_kills": total_kills,
		"flawless_count": flawless_count,
		"mission1_claimed": mission1_claimed, "mission2_claimed": mission2_claimed,
		"mission3_claimed": mission3_claimed, "mission_claims": mission_claims, "sound_enabled": sound_enabled,
		"haptics_enabled": haptics_enabled, "upgrades": upgrades,
		"selected_assassin": selected_assassin, "unlocked_assassins": unlocked_assassins,
		"selected_knife": selected_knife, "unlocked_knives": unlocked_knives,
		"best_stars": best_stars, "last_wheel_day": last_wheel_day,
		"keys_collected": keys_collected, "key_levels_claimed": key_levels_claimed,
		"locker_board": locker_board, "superior_unlocks": superior_unlocks,
		"pending_bonus_level": pending_bonus_level, "completed_bonus_levels": completed_bonus_levels,
	}
	var tmp := SAVE_PATH + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("Could not write save file")
		return
	f.store_string(JSON.stringify(data))
	f.close()
	DirAccess.rename_absolute(tmp, SAVE_PATH)

func mission_progress(stat: String) -> int:
	match stat:
		"kills": return total_kills
		"perfect": return flawless_count
		"levels":
			# Old saves may only retain their unlocked level; level 100 is
			# complete once it has an actual recorded result.
			var completed := maxi(unlocked_level - 1, best_stars.size())
			if best_stars.has("100"): completed = 100
			return clampi(completed, 0, TOTAL_LEVELS)
		"stars":
			var count := 0
			for stars in best_stars.values():
				if int(stars) >= 3: count += 1
			return count
	return 0

func is_superior_unlocked(id: String) -> bool:
	return bool(superior_unlocks.get(id, false))

func buy_superior(id: String, cost: int) -> bool:
	# The caller supplies the published price; validate it against one canonical
	# catalogue so no arbitrary/negative cost can bypass the diamond balance.
	var catalogue = load("res://scripts/game/ten_character_selection.gd")
	if not catalogue.SUPERIOR_LOOKS.has(id) or int(catalogue.SUPERIOR_COSTS[id]) != cost or is_superior_unlocked(id) or gems < cost:
		return false
	gems -= cost
	superior_unlocks[id] = true
	save_game()
	return true

func start_level(level: int) -> void:
	# A queued bonus survives closing the app or returning home. Replaying a
	# previously completed milestone does not give another completion reward.
	if pending_bonus_level > 0:
		active_bonus_level = pending_bonus_level
	else:
		active_bonus_level = 0
		current_level = clampi(level, 1, TOTAL_LEVELS)
	save_game()
	get_tree().change_scene_to_file("res://scenes/level/level.tscn")

func complete_level(kills: int, flawless: bool, stars: int) -> void:
	var cleared := current_level
	if cleared >= 10 and cleared % 10 == 0 and pending_bonus_level == 0 and not bool(completed_bonus_levels.get(str(cleared), false)):
		pending_bonus_level = cleared
	total_kills += kills
	if flawless:
		flawless_count += 1
	cash += 50 + current_level * 5
	var key := str(current_level)
	best_stars[key] = maxi(int(best_stars.get(key, 0)), clampi(stars, 1, 3))
	unlocked_level = maxi(unlocked_level, mini(current_level + 1, TOTAL_LEVELS))
	current_level = unlocked_level
	_refresh_level_knives()
	# A newly queued board becomes eligible only at a genuine level win.
	if locker_pending():
		locker_board["eligible"] = true
	save_game()

func complete_bonus_level(milestone: int, bonus_kills: int) -> bool:
	if pending_bonus_level != milestone or milestone < 10 or milestone > TOTAL_LEVELS or milestone % 10 != 0 or bool(completed_bonus_levels.get(str(milestone), false)):
		return false
	total_kills += maxi(0, bonus_kills)
	cash += 100 + milestone * 5
	gems += 10
	completed_bonus_levels[str(milestone)] = true
	pending_bonus_level = 0
	active_bonus_level = 0
	save_game()
	return true

func character() -> Dictionary:
	return CHARACTERS.get(selected_assassin, CHARACTERS.ronin)

func knife() -> Dictionary:
	return KNIVES.get(selected_knife, KNIVES.standard)

func max_health() -> float:
	return BASE_HEALTH * (1.0 + float(character().get("health_bonus", 0.0))) + float(upgrades.health) * HEALTH_UPGRADE_AMOUNT

func player_damage() -> int:
	return int(knife().damage) + int(upgrades.damage)

func player_speed() -> float:
	return (BASE_SPEED * (1.0 + float(character().get("speed_bonus", 0.0))) + int(upgrades.speed) * 14.0) * PLAYER_SPEED_MULTIPLIER

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

# Legacy IDs continue to own the same bonuses/unlocks; map only their *visible*
# presentation to the supplied roster. Thus old saves neither show obsolete art
# nor lose purchased progress when the game is upgraded.
func visible_character_id(id: String) -> String:
	if CHARACTER_ORDER.has(id):
		return id
	if id == LEGACY_VAULT_CHARACTER:
		return VAULT_CHARACTER
	var reference_index := REFERENCE_ORDER.find(id)
	if reference_index >= 0:
		return V72_FREE_ORDER[reference_index % V72_FREE_ORDER.size()]
	var legacy_index := LEGACY_ORDER.find(id)
	return V72_FREE_ORDER[legacy_index % V72_FREE_ORDER.size()] if legacy_index >= 0 else V72_FREE_ORDER[0]

func display_character_name(id: String) -> String:
	return String(CHARACTERS[visible_character_id(id)].name)

func character_loadouts(visible_id: String) -> Array[String]:
	# All previously available stat profiles remain re-equippable as bonuses
	# on a six-design roster. This preserves purchases without resurrecting old
	# character artwork as extra visible character cards.
	var out: Array[String] = []
	if not CHARACTER_ORDER.has(visible_id):
		return out
	out.append(visible_id)
	for legacy in REFERENCE_ORDER + LEGACY_ORDER + [LEGACY_VAULT_CHARACTER]:
		if visible_character_id(legacy) == visible_id and is_unlocked(legacy):
			out.append(legacy)
	return out

func is_reference_character(id: String) -> bool:
	return REFERENCE_ORDER.has(id) or V72_FREE_ORDER.has(id)

func reference_art_index(id: String) -> int:
	# Historical rig/tests still resolve their twelve source images correctly;
	# the active v72 rig resolves through visible_character_id instead.
	var index := REFERENCE_ORDER.find(id)
	if index >= 0:
		return index + 1
	if LEGACY_ART_INDEX.has(id):
		return int(LEGACY_ART_INDEX[id])
	return CHARACTER_ORDER.find(visible_character_id(id)) + 1

func character_portrait_path(id: String) -> String:
	var visible := visible_character_id(id).trim_prefix("v72_")
	return "res://assets/actors/v72/players/%s.png" % visible

func is_unlocked(id: String) -> bool:
	return CHARACTERS.has(id) and (is_reference_character(id) or bool(unlocked_assassins.get(id, false)))

func unlock_character(id: String) -> bool:
	if not CHARACTERS.has(id) or is_unlocked(id) or id == VAULT_CHARACTER:
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

func add_combat_loot(money: int, diamonds: int) -> void:
	# Keep the historical `gems` save key: existing gems are now diamonds.
	cash += maxi(0, money)
	gems += maxi(0, diamonds)
	save_game()

func level_has_key(number: int) -> bool:
	if number < 1 or number > TOTAL_LEVELS:
		return false
	var key_rng := RandomNumberGenerator.new()
	key_rng.seed = 640019 + number * 97
	return key_rng.randf() < KEY_LEVEL_CHANCE

func key_available(number: int) -> bool:
	return level_has_key(number) and not bool(key_levels_claimed.get(str(number), false)) and locker_board.is_empty()

func collect_level_key(number: int) -> bool:
	if not key_available(number):
		return false
	key_levels_claimed[str(number)] = true
	keys_collected += 1
	if keys_collected >= 3:
		keys_collected -= 3
		_make_locker_board()
	save_game()
	return true

func _make_locker_board(seed_value: int = -1) -> void:
	var roll := RandomNumberGenerator.new()
	if seed_value < 0:
		roll.randomize()
	else:
		roll.seed = seed_value
	var amounts := []
	for i in range(9):
		amounts.append(roll.randi_range(5, 15))
	locker_board = {"character_slot": roll.randi_range(0, 8) if not is_unlocked(VAULT_CHARACTER) else -1,
		"amounts": amounts, "opened": [], "eligible": false}

func _validated_locker_board(value: Variant) -> Dictionary:
	if not value is Dictionary or value.is_empty():
		return {}
	var amounts: Variant = value.get("amounts", [])
	var opened: Variant = value.get("opened", [])
	var character_slot := int(value.get("character_slot", -1))
	if not amounts is Array or amounts.size() != 9 or not opened is Array or opened.size() > 3 or character_slot < -1 or character_slot > 8:
		return {}
	var safe_amounts := []
	for amount in amounts:
		safe_amounts.append(clampi(int(amount), 1, 50))
	var safe_opened := []
	var seen := {}
	for prize in opened:
		if not prize is Dictionary:
			return {}
		var index := int(prize.get("index", -1))
		var kind := String(prize.get("kind", ""))
		if index < 0 or index > 8 or seen.has(index) or kind not in ["diamonds", "character"]:
			return {}
		seen[index] = true
		safe_opened.append({"index": index, "kind": kind, "amount": maxi(0, int(prize.get("amount", 0)))})
	# Earlier versions already displayed boards immediately; treat their pending
	# and partially revealed boards as eligible, preserving recovery semantics.
	return {"character_slot": character_slot, "amounts": safe_amounts, "opened": safe_opened,
		"eligible": bool(value.get("eligible", true))}

func locker_pending() -> bool:
	return not locker_board.is_empty()

func locker_ready() -> bool:
	return locker_pending() and bool(locker_board.get("eligible", true))

func displayed_key_count() -> int:
	return 3 if locker_pending() else keys_collected

func open_locker(index: int) -> Dictionary:
	if not locker_ready() or index < 0 or index >= 9 or locker_board.opened.size() >= 3:
		return {}
	for previous in locker_board.opened:
		if int(previous.index) == index:
			return {}
	var prize := {"index": index, "kind": "diamonds", "amount": int(locker_board.amounts[index])}
	if index == int(locker_board.character_slot) and not is_unlocked(VAULT_CHARACTER):
		unlocked_assassins[VAULT_CHARACTER] = true
		prize = {"index": index, "kind": "character", "amount": 1}
	else:
		gems += int(prize.amount)
	locker_board.opened.append(prize)
	save_game()
	return prize

func finish_locker_board() -> bool:
	if not locker_ready() or locker_board.opened.size() < 3:
		return false
	locker_board = {}
	# A completed board starts a fresh key cycle, including replayed key levels.
	key_levels_claimed = {}
	save_game()
	return true

func can_spin_wheel() -> bool:
	return last_wheel_day != Time.get_date_string_from_system()

## Lucky wheel: 8 segments, weighted. Rolling does not award; claiming does.
const WHEEL_PRIZES := [
	{"kind": "cash", "amount": 50, "weight": 22},
	{"kind": "gems", "amount": 10, "weight": 18},
	{"kind": "cash", "amount": 100, "weight": 18},
	{"kind": "gems", "amount": 20, "weight": 12},
	{"kind": "cash", "amount": 150, "weight": 12},
	{"kind": "gems", "amount": 30, "weight": 8},
	{"kind": "cash", "amount": 250, "weight": 7},
	{"kind": "gems", "amount": 60, "weight": 3},
]

func roll_wheel() -> int:
	var total := 0
	for p in WHEEL_PRIZES:
		total += int(p.weight)
	var roll := randi() % maxi(1, total)
	for i in range(WHEEL_PRIZES.size()):
		roll -= int(WHEEL_PRIZES[i].weight)
		if roll < 0:
			return i
	return 0

func claim_wheel(index: int) -> Dictionary:
	if not can_spin_wheel():
		return {}
	var i := clampi(index, 0, WHEEL_PRIZES.size() - 1)
	var prize: Dictionary = WHEEL_PRIZES[i]
	if String(prize.kind) == "gems":
		gems += int(prize.amount)
	else:
		cash += int(prize.amount)
	last_wheel_day = Time.get_date_string_from_system()
	save_game()
	return prize

## Legacy helper kept so older callers still work.
func spin_wheel() -> int:
	if not can_spin_wheel():
		return 0
	var prize := claim_wheel(roll_wheel())
	return int(prize.get("amount", 0)) if String(prize.get("kind", "")) == "cash" else 0

func vibrate(ms: int) -> void:
	if haptics_enabled and OS.has_feature("mobile"):
		Input.vibrate_handheld(ms)
