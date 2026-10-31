extends Node2D
## Screenshot-derived overhead actors. Original RGB pixels are used for the
## displayed pose; the source screenshot did not contain animation frames, so
## the movement/attack/shoot clips below are new, approximate 2D animations.
## The knife is split from each still so the existing weapon selection remains
## functional. The player rig is enlarged for readability; guard scales and
## the player-following camera are unchanged.

const REF_PATH := "res://assets/reference/"
const CUT_X := [61.0, 59.0, 63.0, 60.0, 51.0, 60.0, 60.0, 57.0, 62.0, 58.0, 62.0, 58.0]
const CUT_Y := [68.0, 55.0, 70.0, 57.0, 45.0, 48.0, 39.0, 49.0, 55.0, 47.0, 55.0, 48.0]
const ART_WORLD_EXTENT := 55.0
const GUARD_WORLD_EXTENT := 60.0

var kind := "ronin"
var role := "player"
var moving := false
var dead := false
var knife_id := "standard"
var body: Node2D
var art: Node2D
var blade: Node2D
var original_blade: Sprite2D
var custom_blade: Sprite2D
var foot_a: Node2D
var foot_b: Node2D
var muzzle: Sprite2D
# Guard-only layers reconstructed from the supplied still, not original frames.
var guard_gun: Node2D
var guard_aim_amount := 0.0
var guard_aim_target := 0.0
var guard_aim_offset := 0.0
var guard_aim_offset_target := 0.0
var guard_raise_angle := 0.0
# Head is a real separately layered part, not a duplicate drawn over a still.
var head: Node2D
var head_rest := Vector2.ZERO
var head_phase := 0.0
var anim: AnimationPlayer
var _current := ""
var _source_extent := 248.0
var foot_rest_a := Vector2.ZERO
var foot_rest_b := Vector2.ZERO

func setup(p_kind: String, p_role: String = "player") -> void:
	kind = p_kind
	role = p_role
	body = Node2D.new()
	body.name = "Body"
	add_child(body)
	art = Node2D.new()
	art.name = "Art"
	body.add_child(art)
	if role == "guard":
		_build_guard()
	else:
		_build_player()
	_build_animations()
	play_anim("idle")

func _region_sprite(tex: Texture2D, region: Rect2, pos: Vector2) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = false
	s.region_enabled = true
	s.region_rect = region
	s.position = pos
	return s

func _build_player() -> void:
	var index := clampi(GameState.reference_art_index(kind), 1, 12)
	var is_vault := kind == "vault_phantom"
	var tex: Texture2D = load(REF_PATH + "characters/vault_phantom.png" if is_vault else REF_PATH + "characters/%02d.png" % index)
	var body_tex: Texture2D = load(REF_PATH + "characters/parts/v64_vault_body.png" if is_vault else REF_PATH + "characters/parts/v64_%02d_body.png" % index)
	var head_tex: Texture2D = load(REF_PATH + "characters/parts/v64_vault_head.png" if is_vault else REF_PATH + "characters/parts/v64_%02d_head.png" % index)
	var boot_tex: Texture2D = null if is_vault else load(REF_PATH + "characters/parts/%02d_boot.png" % index)
	var sz := tex.get_size()
	_source_extent = maxf(sz.x, sz.y)
	var pivot := Vector2(sz.x * 0.64, sz.y * 0.50)
	art.rotation = PI / 2.0 # source pose faces left; default rig faces up
	art.scale = Vector2.ONE * (ART_WORLD_EXTENT / _source_extent)
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	# Each still has one visible trailing boot. Animate that real boot around
	# its attachment point instead of cloning a second patch or warping limbs.
	var boot_anchor := Vector2(round(sz.x * 0.82), sz.y * 0.5)
	foot_a = Node2D.new()
	foot_a.name = "FootA"
	foot_rest_a = boot_anchor - pivot
	foot_a.position = foot_rest_a
	art.add_child(foot_a)
	if boot_tex:
		var boot := Sprite2D.new()
		boot.texture = boot_tex
		boot.centered = false
		boot.position = -boot_anchor
		foot_a.add_child(boot)
	var cut: float = 74.0 if is_vault else CUT_X[index - 1]
	var cut_y: float = 70.0 if is_vault else CUT_Y[index - 1]
	var torso := _region_sprite(body_tex, Rect2(cut, 0, sz.x - cut, sz.y), Vector2(cut, 0) - pivot)
	torso.name = "Pose"
	art.add_child(torso)
	_add_head(head_tex, Vector2(sz.x * 0.66, sz.y * 0.42), pivot)
	blade = Node2D.new()
	blade.name = "Blade"
	blade.position = Vector2(cut, cut_y) - pivot
	art.add_child(blade)
	original_blade = _region_sprite(tex, Rect2(0, 0, cut, sz.y), Vector2(-cut, -cut_y))
	original_blade.name = "ScreenshotBlade"
	blade.add_child(original_blade)
	custom_blade = Sprite2D.new()
	custom_blade.name = "EquippedBlade"
	custom_blade.centered = false
	custom_blade.rotation = -PI / 2.0
	custom_blade.scale = Vector2.ONE * 0.38
	blade.add_child(custom_blade)
	set_knife(knife_id)

func _add_head(texture: Texture2D, anchor: Vector2, pivot: Vector2) -> void:
	head = Node2D.new()
	head.name = "Head"
	head_rest = anchor - pivot
	head.position = head_rest
	art.add_child(head)
	var part := Sprite2D.new()
	part.name = "HeadArtwork"
	part.texture = texture
	part.centered = false
	part.position = -anchor
	head.add_child(part)

func _process(delta: float) -> void:
	if head != null and not dead:
		head_phase += delta * (6.8 if moving else 2.4)
		var head_turn := sin(head_phase) * (0.055 if moving else 0.024)
		if role == "guard" and guard_aim_target > 0.0:
			head_turn += clampf(guard_aim_offset_target * 0.22, -0.09, 0.09)
		head.rotation = head_turn
		head.position = head_rest + Vector2(0.0, sin(head_phase * 0.5) * 0.6)
	if role == "guard" and guard_gun != null and not dead:
		# Pivot from patrol pose toward the player, compensating for body turn.
		guard_aim_amount = move_toward(guard_aim_amount, guard_aim_target, delta * 4.5)
		guard_aim_offset = lerp_angle(guard_aim_offset, guard_aim_offset_target, 1.0 - exp(-12.0 * delta))
		guard_gun.rotation = guard_aim_amount * (guard_raise_angle + guard_aim_offset)

func set_aiming(value: bool, relative_angle: float = 0.0, immediate: bool = false) -> void:
	if role != "guard" or dead:
		return
	guard_aim_target = 1.0 if value else 0.0
	guard_aim_offset_target = clampf(relative_angle, -0.65, 0.65) if value else 0.0
	if immediate and guard_gun != null:
		guard_aim_amount = guard_aim_target
		guard_aim_offset = guard_aim_offset_target
		guard_gun.rotation = guard_aim_amount * (guard_raise_angle + guard_aim_offset)

func _build_guard() -> void:
	var guard_name := "elite" if kind == "elite" else "guard"
	var tex: Texture2D = load(REF_PATH + "guards/" + guard_name + ".png")
	var sz := tex.get_size()
	_source_extent = maxf(sz.x, sz.y)
	var pivot := sz * 0.5
	art.scale = Vector2.ONE * (GUARD_WORLD_EXTENT / _source_extent)
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	# Unlike the old duplicate patches/UV warp, these two separate foot pieces
	# alternate in counterphase behind an undistorted screenshot-derived torso.
	var parts := REF_PATH + "guards/parts/" + guard_name + "_"
	foot_a = Node2D.new()
	foot_a.name = "FootA"
	var front_anchor := Vector2(32, 12) if kind == "elite" else Vector2(35, 12)
	foot_rest_a = front_anchor - pivot
	foot_a.position = foot_rest_a
	art.add_child(foot_a)
	var front := Sprite2D.new()
	front.texture = load(parts + "foot_front.png")
	front.centered = false
	front.position = -front_anchor
	foot_a.add_child(front)
	foot_b = Node2D.new()
	foot_b.name = "FootB"
	var back_anchor := Vector2(25, 58) if kind == "elite" else Vector2(25, 52)
	foot_rest_b = back_anchor - pivot
	foot_b.position = foot_rest_b
	art.add_child(foot_b)
	var back := Sprite2D.new()
	back.texture = load(parts + "foot_back.png")
	back.centered = false
	back.position = -back_anchor
	foot_b.add_child(back)
	var pose := Sprite2D.new()
	pose.name = "Pose"
	pose.texture = load(REF_PATH + "guards/parts/v64_" + guard_name + "_body.png")
	pose.centered = false
	pose.position = -pivot
	art.add_child(pose)
	_add_head(load(REF_PATH + "guards/parts/v64_" + guard_name + "_head.png"), Vector2(sz.x * 0.44, sz.y * 0.57), pivot)
	# The rifle is cut from the same supplied image and pivots at the hand.
	var anchor := Vector2(38, 22) if kind == "elite" else Vector2(39, 16)
	var tip := Vector2(3, 5) if kind == "elite" else Vector2(9, 13)
	guard_raise_angle = deg_to_rad(60.0 if kind == "elite" else 82.0)
	guard_gun = Node2D.new()
	guard_gun.name = "Gun"
	guard_gun.position = anchor - pivot
	art.add_child(guard_gun)
	var weapon := Sprite2D.new()
	weapon.name = "Weapon"
	weapon.texture = load(parts + "weapon.png")
	weapon.centered = false
	weapon.position = -anchor
	guard_gun.add_child(weapon)
	muzzle = Sprite2D.new()
	muzzle.name = "Muzzle"
	muzzle.texture = preload("res://assets/fx/spark.png")
	muzzle.scale = Vector2.ONE * 0.23
	muzzle.position = tip - anchor
	muzzle.modulate = Color(1, 1, 1, 0)
	guard_gun.add_child(muzzle)

func set_knife(id: String) -> void:
	knife_id = id
	if original_blade == null or custom_blade == null:
		return
	var path := "res://assets/knives/%s.png" % id
	if id != "standard" and ResourceLoader.exists(path):
		custom_blade.texture = load(path)
		var sz := custom_blade.texture.get_size()
		# Existing knife art points up; rotate it into the reference's left-hand pose.
		custom_blade.offset = Vector2(-sz.x * 0.5, -sz.y * 0.80)
		custom_blade.visible = true
		original_blade.visible = false
	else:
		custom_blade.visible = false
		original_blade.visible = true

func _draw() -> void:
	# Existing contact-shadow footprint, independent of the larger environment.
	draw_set_transform(Vector2(0, 10), 0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, 18.0, Color(0, 0, 0, 0.28))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

func _track(a: Animation, path: NodePath, times: Array, values: Array, smooth := false) -> void:
	var track := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(track, path)
	for i in range(times.size()):
		a.track_insert_key(track, times[i], values[i])
	a.track_set_interpolation_type(track, Animation.INTERPOLATION_CUBIC if smooth else Animation.INTERPOLATION_LINEAR)

func _build_animations() -> void:
	anim = AnimationPlayer.new()
	anim.name = "AnimationPlayer"
	add_child(anim)
	var lib := AnimationLibrary.new()
	var idle := Animation.new()
	idle.length = 1.5
	idle.loop_mode = Animation.LOOP_LINEAR
	_track(idle, NodePath("Body:position"), [0.0, 0.75, 1.5], [Vector2.ZERO, Vector2(0, -0.7), Vector2.ZERO])
	_track(idle, NodePath("Body:scale"), [0.0, 0.75, 1.5], [Vector2.ONE, Vector2(1.01, 0.99), Vector2.ONE])
	_track(idle, NodePath("Body:rotation"), [0.0, 0.75, 1.5], [0.0, 0.015, 0.0])
	_track(idle, NodePath("Body/Art/FootA:position"), [0.0], [foot_rest_a])
	_track(idle, NodePath("Body/Art/FootA:rotation"), [0.0], [0.0])
	if role == "player":
		_track(idle, NodePath("Body/Art/Blade:rotation"), [0.0, 0.75, 1.5], [0.0, 0.018, 0.0], true)
	else:
		_track(idle, NodePath("Body/Art/FootB:position"), [0.0], [foot_rest_b])
		_track(idle, NodePath("Body/Art/FootB:rotation"), [0.0], [0.0])
	lib.add_animation("idle", idle)

	var run := Animation.new()
	run.length = 0.60 if role == "guard" else 0.54
	run.loop_mode = Animation.LOOP_LINEAR
	var half := run.length * 0.5
	var quarter := run.length * 0.25
	var times := [0.0, quarter, half, quarter * 3.0, run.length]
	var bob := 0.55 if role == "guard" else 0.70
	_track(run, NodePath("Body:position"), times, [Vector2.ZERO, Vector2(0,-bob), Vector2.ZERO, Vector2(0,-bob), Vector2.ZERO], true)
	_track(run, NodePath("Body:rotation"), times, [0.0, -0.018, 0.0, 0.018, 0.0], true)
	_track(run, NodePath("Body:scale"), [0.0], [Vector2.ONE])
	if role == "player":
		var stride := 6.0 * _source_extent / 248.0
		_track(run, NodePath("Body/Art/FootA:position"), times, [foot_rest_a, foot_rest_a + Vector2(-stride, -1.0), foot_rest_a, foot_rest_a + Vector2(stride, 1.0), foot_rest_a], true)
		_track(run, NodePath("Body/Art/FootA:rotation"), times, [0.0, -0.045, 0.0, 0.045, 0.0], true)
		_track(run, NodePath("Body/Art/Blade:rotation"), times, [0.0, -0.035, 0.0, 0.035, 0.0], true)
	else:
		var step := Vector2(0.0, 1.5)
		_track(run, NodePath("Body/Art/FootA:position"), times, [foot_rest_a, foot_rest_a-step, foot_rest_a, foot_rest_a+step, foot_rest_a], true)
		_track(run, NodePath("Body/Art/FootB:position"), times, [foot_rest_b, foot_rest_b+step, foot_rest_b, foot_rest_b-step, foot_rest_b], true)
		_track(run, NodePath("Body/Art/FootA:rotation"), times, [0.0, -0.10, 0.0, 0.10, 0.0], true)
		_track(run, NodePath("Body/Art/FootB:rotation"), times, [0.0, 0.10, 0.0, -0.10, 0.0], true)
	lib.add_animation("run", run)

	var attack := Animation.new()
	attack.length = 0.30
	_track(attack, NodePath("Body:position"), [0.0, 0.10, 0.30], [Vector2.ZERO, Vector2(0,-5), Vector2.ZERO])
	_track(attack, NodePath("Body:rotation"), [0.0, 0.09, 0.18, 0.30], [0.0, -0.18, 0.16, 0.0])
	_track(attack, NodePath("Body:scale"), [0.0, 0.30], [Vector2.ONE, Vector2.ONE])
	if role == "player":
		_track(attack, NodePath("Body/Art/Blade:rotation"), [0.0, 0.08, 0.16, 0.30], [0.0, -0.27, 0.30, 0.0])
	lib.add_animation("attack", attack)

	var shoot := Animation.new()
	shoot.length = 0.18
	_track(shoot, NodePath("Body:position"), [0.0, 0.05, 0.18], [Vector2.ZERO, Vector2(0,3), Vector2.ZERO])
	_track(shoot, NodePath("Body:rotation"), [0.0, 0.18], [0.0, 0.0])
	if muzzle:
		_track(shoot, NodePath("Body/Art/Gun/Muzzle:modulate"), [0.0, 0.03, 0.10, 0.18], [Color(1,1,1,0), Color.WHITE, Color(1,1,1,0.6), Color(1,1,1,0)])
	lib.add_animation("shoot", shoot)

	var hurt := Animation.new()
	hurt.length = 0.28
	_track(hurt, NodePath("Body:position"), [0.0, 0.08, 0.28], [Vector2.ZERO, Vector2(0,4), Vector2.ZERO])
	_track(hurt, NodePath("Body:modulate"), [0.0, 0.07, 0.14, 0.28], [Color.WHITE, Color(1,0.35,0.35), Color.WHITE, Color.WHITE])
	_track(hurt, NodePath("Body:rotation"), [0.0, 0.28], [0.0, 0.0])
	lib.add_animation("hurt", hurt)

	var death := Animation.new()
	death.length = 0.55
	_track(death, NodePath("Body:rotation"), [0.0, 0.25, 0.55], [0.0, 1.0, 1.35])
	_track(death, NodePath("Body:scale"), [0.0, 0.25, 0.55], [Vector2.ONE, Vector2(0.95,0.88), Vector2(0.90,0.80)])
	_track(death, NodePath("Body:modulate"), [0.0, 0.55], [Color.WHITE, Color(0.55,0.50,0.50,0.75)])
	lib.add_animation("death", death)
	anim.add_animation_library("", lib)
	anim.animation_finished.connect(_on_finished)

func play_anim(name: String, force: bool = false) -> void:
	if dead and name != "death":
		return
	if _current == name and not force:
		return
	_current = name
	anim.play(name, 0.08 if name in ["idle", "run"] else -1.0)

func set_moving(value: bool) -> void:
	moving = value
	if dead:
		return
	if _current in ["idle", "run"]:
		play_anim("run" if moving else "idle")

func die() -> void:
	dead = true
	play_anim("death", true)

func _on_finished(name: StringName) -> void:
	if dead:
		return
	if String(name) in ["attack", "shoot", "hurt"]:
		_current = ""
		play_anim("run" if moving else "idle")
