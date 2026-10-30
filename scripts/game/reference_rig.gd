extends Node2D
## Screenshot-derived overhead actors. Original RGB pixels are used for the
## displayed pose; the source screenshot did not contain animation frames, so
## the movement/attack/shoot clips below are new, approximate 2D animations.
## The knife is split from each still so the existing weapon selection remains
## functional. The level's player/guard root scales and camera are unchanged.

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
var anim: AnimationPlayer
var _current := ""

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

func _build_feet(tex: Texture2D, region: Rect2, pivot: Vector2) -> void:
	# Small duplicate patches from the still act as alternating trailing feet.
	# They are hidden at rest, behind the full reference pose while running.
	foot_a = Node2D.new()
	foot_a.name = "FootA"
	art.add_child(foot_a)
	foot_a.add_child(_region_sprite(tex, region, region.position - pivot))
	foot_a.visible = false
	foot_b = Node2D.new()
	foot_b.name = "FootB"
	art.add_child(foot_b)
	foot_b.add_child(_region_sprite(tex, region, region.position - pivot))
	foot_b.visible = false

func _build_player() -> void:
	var index := clampi(GameState.reference_art_index(kind), 1, 12)
	var tex: Texture2D = load(REF_PATH + "characters/%02d.png" % index)
	var sz := tex.get_size()
	var pivot := Vector2(sz.x * 0.64, sz.y * 0.50)
	art.rotation = PI / 2.0 # source pose faces left; default rig faces up
	art.scale = Vector2.ONE * (ART_WORLD_EXTENT / maxf(sz.x, sz.y))
	var foot_region := Rect2(Vector2(sz.x * 0.83, sz.y * 0.25), Vector2(sz.x * 0.17, sz.y * 0.50))
	_build_feet(tex, foot_region, pivot)
	var cut: float = CUT_X[index - 1]
	var cut_y: float = CUT_Y[index - 1]
	var torso := _region_sprite(tex, Rect2(cut, 0, sz.x - cut, sz.y), Vector2(cut, 0) - pivot)
	torso.name = "Pose"
	art.add_child(torso)
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

func _build_guard() -> void:
	var file := "elite.png" if kind == "elite" else "guard.png"
	var tex: Texture2D = load(REF_PATH + "guards/" + file)
	var sz := tex.get_size()
	var pivot := sz * 0.5
	art.scale = Vector2.ONE * (GUARD_WORLD_EXTENT / maxf(sz.x, sz.y))
	var foot_region := Rect2(Vector2(sz.x * 0.30, sz.y * 0.66), Vector2(sz.x * 0.40, sz.y * 0.34))
	_build_feet(tex, foot_region, pivot)
	var pose := Sprite2D.new()
	pose.name = "Pose"
	pose.texture = tex
	art.add_child(pose)
	muzzle = Sprite2D.new()
	muzzle.name = "Muzzle"
	muzzle.texture = preload("res://assets/fx/spark.png")
	muzzle.scale = Vector2.ONE * 0.28
	muzzle.position = Vector2(0, -27)
	muzzle.modulate = Color(1, 1, 1, 0)
	body.add_child(muzzle)

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

func _track(a: Animation, path: NodePath, times: Array, values: Array) -> void:
	var track := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(track, path)
	for i in range(times.size()):
		a.track_insert_key(track, times[i], values[i])
	a.track_set_interpolation_type(track, Animation.INTERPOLATION_LINEAR)

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
	if role == "player":
		_track(idle, NodePath("Body/Art/Blade:rotation"), [0.0, 0.75, 1.5], [0.0, 0.03, 0.0])
	lib.add_animation("idle", idle)

	var run := Animation.new()
	run.length = 0.42
	run.loop_mode = Animation.LOOP_LINEAR
	_track(run, NodePath("Body:position"), [0.0, 0.105, 0.21, 0.315, 0.42], [Vector2.ZERO, Vector2(0,-2), Vector2.ZERO, Vector2(0,-2), Vector2.ZERO])
	_track(run, NodePath("Body:rotation"), [0.0, 0.21, 0.42], [-0.07, 0.07, -0.07])
	_track(run, NodePath("Body:scale"), [0.0, 0.105, 0.21, 0.315, 0.42], [Vector2.ONE, Vector2(1.025,0.975), Vector2.ONE, Vector2(1.025,0.975), Vector2.ONE])
	var stride := 15.0 if role == "player" else 5.0
	_track(run, NodePath("Body/Art/FootA:position"), [0.0, 0.21, 0.42], [Vector2(0,-stride), Vector2(0,stride), Vector2(0,-stride)])
	_track(run, NodePath("Body/Art/FootB:position"), [0.0, 0.21, 0.42], [Vector2(0,stride), Vector2(0,-stride), Vector2(0,stride)])
	if role == "player":
		_track(run, NodePath("Body/Art/Blade:rotation"), [0.0, 0.21, 0.42], [-0.08, 0.08, -0.08])
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
		_track(shoot, NodePath("Body/Muzzle:modulate"), [0.0, 0.03, 0.10, 0.18], [Color(1,1,1,0), Color.WHITE, Color(1,1,1,0.6), Color(1,1,1,0)])
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
	anim.play(name)

func set_moving(value: bool) -> void:
	moving = value
	if foot_a:
		foot_a.visible = value and not dead
	if foot_b:
		foot_b.visible = value and not dead
	if dead:
		return
	if _current in ["idle", "run"]:
		play_anim("run" if moving else "idle")

func die() -> void:
	dead = true
	if foot_a:
		foot_a.visible = false
	if foot_b:
		foot_b.visible = false
	play_anim("death", true)

func _on_finished(name: StringName) -> void:
	if dead:
		return
	if String(name) in ["attack", "shoot", "hurt"]:
		_current = ""
		play_anim("run" if moving else "idle")
