extends Node2D
## Ten reference-guided characters; Standard keeps the approved red-scarf rig.
## Approved red-scarf shoulder/elbow/ankle gait is retained.  The new looks
## use separately cut upper arm, elbow, hand and free-arm draft layers; all
## melee assets attach behind the gripping fist and follow its wrist.
## Equipped weapons stay independent from the selected character.

const Choice := preload("res://scripts/game/ten_character_selection.gd")
const Meta := preload("res://scripts/game/ten_character_art_meta.gd")
const SuperiorRigMeta := preload("res://scripts/game/superior_rig_meta_v5.gd")
const RepairMeta := preload("res://scripts/game/character_repair_meta.gd")
const RED_ROOT := "res://assets/characters/red-scarf-preview/"
const ROOT := "res://assets/characters/ten-character-update/"
const WEAPON_ROOT := "res://assets/characters/five-look-draft/weapons/"
const LEG := preload("res://assets/characters/red-scarf-preview/test-v2-leg.png")
const FOOT := preload("res://assets/characters/red-scarf-preview/test-v2-foot.png")
const RED_TORSO := preload("res://assets/characters/red-scarf-preview/test-v2-cropped-torso.png")
const RED_UPPER := preload("res://assets/characters/red-scarf-preview/test-v3-knife-upper.png")
const RED_FOREARM := preload("res://assets/characters/red-scarf-preview/test-v3-knife-forearm.png")
const RED_FREE_ARM := preload("res://assets/characters/red-scarf-preview/test-v2-cropped-free-arm.png")
const RED_HEAD := preload("res://assets/characters/red-scarf-preview/test-v2-cropped-head.png")
const RED_FREE_HAND := preload("res://assets/characters/red-scarf-preview/test-v2-cropped-free-hand.png")
const RED_HAND := preload("res://assets/characters/five-look-draft/red_scarf/hand.png")

var visual: Node2D
var knife_shoulder: Node2D
var knife_elbow: Node2D
var free_shoulder: Node2D
var wrist: Node2D
var free_pivot: Node2D
var head_pivot: Node2D
var leg_a: Node2D
var leg_b: Node2D
var ankle_a: Node2D
var ankle_b: Node2D
var leg_art_a: Sprite2D
var leg_art_b: Sprite2D
var weapon_art: Sprite2D
var current_look := "standard"
var current_weapon := "aurora"
var centre := Vector2(970.0, 390.0)
var hip_a := Vector2(1015.0, 370.0)
var hip_b := Vector2(1015.0, 410.0)
var weapon_fist := Vector2(490.0, 365.0)
var wrist_anchor := Vector2(529.0, 300.0)
var moving := false
var dead := false
var state := "idle"
var elapsed := 0.0
var walk_time := 0.0
var held_gait := 1.0
var target_a := Vector2.ZERO
var target_b := Vector2.ZERO
var ankle_flex_a := 0.0
var ankle_flex_b := 0.0

func _v(a: Array) -> Vector2:
	return Vector2(float(a[0]), float(a[1]))

func setup(kind: String, _role: String = "player") -> void:
	if visual != null:
		return
	current_look = kind if Choice.ALL_LOOKS.has(kind) else "standard"
	visual = Node2D.new()
	visual.name = "TenCharacterVisual"
	# Source art faces left; rest direction in the level is up.
	visual.rotation = PI / 2.0
	visual.scale = Vector2.ONE * (55.0 / 1514.0)
	add_child(visual)
	leg_a = _leg_pivot("LegA")
	leg_b = _leg_pivot("LegB")
	leg_art_a = leg_a.get_node("LegArt")
	leg_art_b = leg_b.get_node("LegArt")
	ankle_a = _ankle_pivot("AnkleA")
	ankle_b = _ankle_pivot("AnkleB")
	if current_look == "standard":
		_setup_red_scarf()
	elif Choice.SUPERIOR_LOOKS.has(current_look):
		_setup_superior()
	elif current_look in ["health_10", "health_30"]:
		_setup_repaired_guard()
	else:
		_setup_new_look()
	_set_leg(leg_a, leg_art_a, ankle_a, hip_a, Vector2(730.0, 355.0), 0.0)
	_set_leg(leg_b, leg_art_b, ankle_b, hip_b, Vector2(1270.0, 425.0), 0.0)
	set_knife(current_weapon)
	_update_leg_visibility()

func _setup_red_scarf() -> void:
	centre = Vector2(970.0,390.0)
	var shoulder := Vector2(950.0,154.0)
	var elbow := Vector2(635.0,135.0)
	wrist_anchor = Vector2(529.0,300.0)
	weapon_fist = _v(Meta.HAND_GRIP_CENTRES.red_scarf)
	_body(RED_TORSO,Vector2(654.0,51.0))
	knife_shoulder = _shoulder("KnifeShoulder",RED_UPPER,shoulder,Vector2(524.0,6.0))
	knife_elbow = _elbow_pivot(knife_shoulder,RED_FOREARM,elbow,shoulder,Vector2(468.0,60.0))
	wrist = _wrist_pivot(knife_elbow,RED_HAND,wrist_anchor,elbow,_v(Meta.RED_HAND_ORIGIN))
	free_shoulder = _shoulder("FreeShoulder",RED_FREE_ARM,Vector2(990.0,625.0),Vector2(534.0,450.0))
	free_pivot = _hand_pivot(free_shoulder,"ReferenceFreeHand",RED_FREE_HAND,Vector2(690.0,590.0),Vector2(990.0,625.0),Vector2(534.0,451.0))
	head_pivot = _shoulder("ReferenceHead",RED_HEAD,Vector2(1040.0,390.0),Vector2(856.0,218.0))

func _setup_new_look() -> void:
	var data: Dictionary = Meta.LOOK_DATA[current_look]
	var origins: Dictionary = data.origins
	centre = _v(data.centre)
	hip_a = _v(data.hip_a)
	hip_b = _v(data.hip_b)
	var shoulder := _v(data.shoulder)
	var elbow := _v(data.elbow)
	wrist_anchor = _v(data.wrist)
	weapon_fist = _v(Meta.HAND_GRIP_CENTRES[current_look])
	var free_anchor := _v(data.free_shoulder)
	var folder := ROOT + current_look + "/"
	_body(load(folder + "torso.png"),_v(origins.torso))
	knife_shoulder = _shoulder("KnifeShoulder",load(folder + "upper.png"),shoulder,_v(origins.upper))
	knife_elbow = _elbow_pivot(knife_shoulder,load(folder + "forearm.png"),elbow,shoulder,_v(origins.forearm))
	wrist = _wrist_pivot(knife_elbow,load(folder + "hand.png"),wrist_anchor,elbow,_v(origins.hand))
	free_shoulder = _shoulder("FreeShoulder",load(folder + "free_arm.png"),free_anchor,_v(origins.free_arm))
	# New references do not provide a separate face or free-hand frame.  They
	# stay within their parent layer rather than inventing hidden pixels.
	free_pivot = Node2D.new()
	free_pivot.name = "FreeHandAnchor"
	free_shoulder.add_child(free_pivot)
	head_pivot = Node2D.new()
	head_pivot.name = "HeadAnchor"
	visual.add_child(head_pivot)

func _setup_repaired_guard() -> void:
	# One coherent upper arm+hand and one coherent free arm avoid the old
	# dangling cut fragments. Both shoulders still swing; the chosen weapon
	# remains a separate wrist child and no art is changed for other looks.
	var data: Dictionary = Meta.LOOK_DATA[current_look]
	var origins: Dictionary = RepairMeta.ORIGINS[current_look]
	centre = _v(data.centre)
	hip_a = _v(data.hip_a)
	hip_b = _v(data.hip_b)
	var shoulder := _v(data.shoulder)
	wrist_anchor = _v(data.wrist)
	weapon_fist = _v(Meta.HAND_GRIP_CENTRES[current_look])
	var folder := "res://assets/characters/character-repair/" + current_look + "/"
	_body(load(folder + "body.png"), _v(origins.body))
	knife_shoulder = Node2D.new()
	knife_shoulder.name = "KnifeShoulder"
	knife_shoulder.position = shoulder - centre
	visual.add_child(knife_shoulder)
	knife_elbow = Node2D.new()
	knife_elbow.name = "KnifeElbow"
	knife_shoulder.add_child(knife_elbow)
	wrist = Node2D.new()
	wrist.name = "KnifeHandPivot"
	wrist.position = wrist_anchor - shoulder
	knife_elbow.add_child(wrist)
	weapon_art = Sprite2D.new()
	weapon_art.name = "SelectedMeleeWeapon"
	weapon_art.centered = false
	weapon_art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	wrist.add_child(weapon_art)
	var arm := Sprite2D.new()
	arm.name = "RepairedUpperAndHand"
	arm.centered = false
	arm.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	arm.texture = load(folder + "upper.png")
	arm.position = _v(origins.upper) - shoulder
	knife_shoulder.add_child(arm)
	free_shoulder = _shoulder("FreeShoulder", load(folder + "free_arm.png"), _v(data.free_shoulder), _v(origins.free_arm))
	free_pivot = Node2D.new()
	free_pivot.name = "FreeHandAnchor"
	free_shoulder.add_child(free_pivot)
	head_pivot = Node2D.new()
	head_pivot.name = "HeadAnchor"
	visual.add_child(head_pivot)

func _setup_superior() -> void:
	# Six overlapping cuts from the supplied figure form actual visible,
	# independently pivoted arms and hands. The original portrait remains
	# untouched; weapons stay separate and are drawn behind the gripping hand.
	centre = Vector2(970.0,390.0)
	hip_a = Vector2(1015.0,370.0)
	hip_b = Vector2(1015.0,410.0)
	var scale_art: float = SuperiorRigMeta.SCALE
	var origins: Dictionary = SuperiorRigMeta.ORIGINS[current_look]
	var shoulder := Vector2(758.0,108.8)
	var elbow := Vector2(571.0,244.8)
	wrist_anchor = Vector2(527.0,367.0)
	weapon_fist = wrist_anchor
	var free_anchor := Vector2(979.0,533.8)
	var free_hand_anchor := Vector2(717.2,493.0)
	var folder := "res://assets/characters/superior-rig-v5/" + current_look + "/"
	_body(load(folder + "body.webp"),_v(origins.body),scale_art)
	knife_shoulder = _shoulder("KnifeShoulder",load(folder + "upper.webp"),shoulder,_v(origins.upper),scale_art)
	knife_elbow = _elbow_pivot(knife_shoulder,load(folder + "forearm.webp"),elbow,shoulder,_v(origins.forearm),scale_art)
	wrist = _wrist_pivot(knife_elbow,load(folder + "hand.webp"),wrist_anchor,elbow,_v(origins.hand),scale_art)
	free_shoulder = _shoulder("FreeShoulder",load(folder + "free_arm.webp"),free_anchor,_v(origins.free_arm),scale_art)
	free_pivot = _hand_pivot(free_shoulder,"ReferenceFreeHand",load(folder + "free_hand.webp"),free_hand_anchor,free_anchor,_v(origins.free_hand),scale_art)
	head_pivot = Node2D.new()
	head_pivot.name = "HeadAnchor"
	visual.add_child(head_pivot)

func _body(texture: Texture2D, origin: Vector2, art_scale: float = 1.0) -> void:
	var torso := Sprite2D.new()
	torso.name = "ReferenceBody"
	torso.centered = false
	torso.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	torso.texture = texture
	torso.position = origin - centre
	torso.scale = Vector2.ONE * art_scale
	visual.add_child(torso)

func _leg_pivot(node_name: String) -> Node2D:
	var node := Node2D.new()
	node.name = node_name
	visual.add_child(node)
	var art := Sprite2D.new()
	art.name = "LegArt"
	art.centered = false
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	art.texture = LEG
	art.offset = Vector2(-4, -60)
	node.add_child(art)
	return node

func _ankle_pivot(node_name: String) -> Node2D:
	var node := Node2D.new()
	node.name = node_name
	visual.add_child(node)
	var art := Sprite2D.new()
	art.name = "FootArt"
	art.centered = false
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	art.texture = FOOT
	art.offset = Vector2(-12, -50)
	art.scale = Vector2(1.0, 1.55)
	node.add_child(art)
	return node

func _shoulder(node_name: String, texture: Texture2D, anchor: Vector2, crop_origin: Vector2, art_scale: float = 1.0) -> Node2D:
	var node := Node2D.new()
	node.name = node_name
	node.position = anchor - centre
	visual.add_child(node)
	var art := Sprite2D.new()
	art.name = "Art"
	art.centered = false
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	art.texture = texture
	art.position = crop_origin - anchor
	art.scale = Vector2.ONE * art_scale
	node.add_child(art)
	return node

func _elbow_pivot(parent: Node2D, texture: Texture2D, elbow: Vector2, shoulder: Vector2, crop_origin: Vector2, art_scale: float = 1.0) -> Node2D:
	var node := Node2D.new()
	node.name = "KnifeElbow"
	node.position = elbow - shoulder
	parent.add_child(node)
	var art := Sprite2D.new()
	art.name = "ForearmArt"
	art.centered = false
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	art.texture = texture
	art.position = crop_origin - elbow
	art.scale = Vector2.ONE * art_scale
	node.add_child(art)
	return node

func _wrist_pivot(parent: Node2D, texture: Texture2D, hand: Vector2, parent_anchor: Vector2, crop_origin: Vector2, art_scale: float = 1.0) -> Node2D:
	var node := Node2D.new()
	node.name = "KnifeHandPivot"
	node.position = hand - parent_anchor
	parent.add_child(node)
	weapon_art = Sprite2D.new()
	weapon_art.name = "SelectedMeleeWeapon"
	weapon_art.centered = false
	weapon_art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	node.add_child(weapon_art)
	var art := Sprite2D.new()
	art.name = "HandArt"
	art.centered = false
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	art.texture = texture
	art.position = crop_origin - hand
	art.scale = Vector2.ONE * art_scale
	node.add_child(art)
	return node

func _hand_pivot(parent: Node2D, node_name: String, texture: Texture2D, hand: Vector2, parent_anchor: Vector2, crop_origin: Vector2, art_scale: float = 1.0) -> Node2D:
	var node := Node2D.new()
	node.name = node_name
	node.position = hand - parent_anchor
	parent.add_child(node)
	var art := Sprite2D.new()
	art.name = "HandArt"
	art.centered = false
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	art.texture = texture
	art.position = crop_origin - hand
	art.scale = Vector2.ONE * art_scale
	node.add_child(art)
	return node

func _set_leg(pivot: Node2D, art: Sprite2D, ankle: Node2D, hip: Vector2, target: Vector2, flex_degrees: float) -> void:
	var delta := target - hip
	var direction := delta.angle()
	pivot.position = hip - centre
	pivot.rotation = direction
	art.scale = Vector2(maxf(0.01, delta.length() / 346.0), 1.55)
	ankle.position = target - centre
	ankle.rotation = direction + deg_to_rad(flex_degrees)

func set_knife(id: String) -> void:
	current_weapon = id if Choice.WEAPONS.has(id) else "aurora"
	if weapon_art == null:
		return
	weapon_art.texture = load(WEAPON_ROOT + current_weapon + "-grip.png")
	var grip: Array = Meta.WEAPON_GRIP[current_weapon]
	weapon_art.position = weapon_fist - wrist_anchor - _v(grip)

func _update_leg_visibility() -> void:
	# Legs/feet are real animation layers, so hiding them at rest does not
	# modify appearance, weapons or saved character selection.
	for limb in [leg_a, leg_b, ankle_a, ankle_b]:
		if is_instance_valid(limb):
			limb.visible = moving and not dead

func set_moving(value: bool) -> void:
	moving = value
	_update_leg_visibility()
	if not dead and state in ["idle", "run"]:
		state = "run" if moving else "idle"

func play_anim(next: String, force: bool = false) -> bool:
	if dead and next != "death":
		return false
	if next == state and not force:
		return true
	if next == "attack":
		held_gait = cos(walk_time * TAU * 1.5) if moving else 1.0
	state = next
	elapsed = 0.0
	return true

func die() -> void:
	dead = true
	_update_leg_visibility()
	state = "death"
	elapsed = 0.0

func _process(delta: float) -> void:
	if visual == null or delta < 0.0:
		return
	elapsed += delta
	if moving and not dead:
		walk_time += delta
	var gait := cos(walk_time * TAU * 1.5) if moving and not dead else 1.0
	var wave := 0.0
	var cycle := 0.0
	var attack_active := state == "attack" and not dead
	if attack_active:
		var progress := clampf(elapsed / 0.30, 0.0, 1.0)
		if progress >= 1.0:
			state = "run" if moving else "idle"
			elapsed = 0.0
			attack_active = false
		else:
			gait = held_gait
			wave = sin(PI * progress)
			cycle = sin(TAU * progress)
	if state == "hurt" and elapsed >= 0.28:
		state = "run" if moving else "idle"
		elapsed = 0.0
	# Opposite shoulder swings during every character's walking gait. The arm,
	# elbow, hand and weapon stay parented to their original shoulder pivots.
	var shoulder_gait := sin(walk_time * TAU * 1.5) if moving and not attack_active and not dead else 0.0
	knife_shoulder.rotation = deg_to_rad(-3.0 * cycle + 4.8 * shoulder_gait)
	knife_elbow.rotation = 0.0 if current_look in ["health_10", "health_30"] else deg_to_rad(-15.0 * cycle + 7.0 * wave + 2.0 * shoulder_gait)
	free_shoulder.rotation = deg_to_rad(2.5 * cycle - 5.0 * shoulder_gait)
	wrist.rotation = deg_to_rad(-4.5 * wave - 1.0 * shoulder_gait)
	free_pivot.rotation = deg_to_rad(-3.0 * sin(walk_time * TAU * 1.5)) if moving and not attack_active and not dead else deg_to_rad(2.0 * wave)
	head_pivot.rotation = deg_to_rad(2.5 * sin(walk_time * TAU * 1.5)) if moving and not attack_active and not dead else 0.0
	ankle_flex_a = 10.0 * wave
	ankle_flex_b = -8.0 * wave
	target_a = Vector2(1000.0 - 270.0 * gait - 18.0 * wave, 355.0)
	target_b = Vector2(1000.0 + 270.0 * gait + 12.0 * wave, 425.0)
	_set_leg(leg_a, leg_art_a, ankle_a, hip_a, target_a, ankle_flex_a)
	_set_leg(leg_b, leg_art_b, ankle_b, hip_b, target_b, ankle_flex_b)
	visual.position.y = -0.7 * absf(sin(walk_time * TAU * 1.5)) if moving and not dead else 0.0
