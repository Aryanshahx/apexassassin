extends Node2D
## Each appearance is cut from one user-supplied still, not an animation sheet.
## Body sway, recoil and the separately equipped knife are simple new animations.
## The drawn firearm/shield is decorative: the existing gameplay rules apply.

const PLAYER_EXTENT := 55.0
const GUARD_EXTENT := 60.0
const ENEMY_LOOK := {
	"guard": "guard", "scout": "soldier", "heavy": "heavy",
	"ranger": "sniper", "captain": "officer", "breacher": "shield",
	"elite": "heavy",
}
var kind := ""
var role := "player"
var body: Node2D
var art: Sprite2D
var blade: Node2D
var knife_sprite: Sprite2D
var muzzle: Sprite2D
var anim: AnimationPlayer
var moving := false
var dead := false
var _current := ""
var knife_id := "standard"
var look := ""
# Aim state is still exposed to the same gameplay/tests, while the supplied
# single still remains intact instead of inventing detachable limbs.
var guard_aim_target := 0.0
var guard_aim_amount := 0.0
var guard_aim_offset := 0.0
var guard_aim_offset_target := 0.0

func setup(p_kind: String, p_role: String = "player") -> void:
	kind = p_kind
	role = p_role
	body = Node2D.new()
	body.name = "Body"
	add_child(body)
	art = Sprite2D.new()
	art.name = "Art"
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	if role == "guard":
		look = String(ENEMY_LOOK.get(kind, "guard"))
		art.texture = load("res://assets/actors/v72/enemies/%s.png" % look)
	else:
		look = GameState.visible_character_id(kind).trim_prefix("v72_")
		art.texture = load(GameState.character_portrait_path(kind))
	var source_size := art.texture.get_size()
	var extent := GUARD_EXTENT if role == "guard" else PLAYER_EXTENT
	art.scale = Vector2.ONE * (extent / maxf(source_size.x, source_size.y))
	# The supplied characters face downward; the game rig's rest direction is up.
	art.rotation = PI
	body.add_child(art)
	if role == "player":
		blade = Node2D.new()
		blade.name = "Blade"
		blade.position = Vector2(17, -8)
		body.add_child(blade)
		knife_sprite = Sprite2D.new()
		knife_sprite.name = "EquippedKnife"
		knife_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		knife_sprite.scale = Vector2.ONE * 0.15
		knife_sprite.position = Vector2(0, -6)
		blade.add_child(knife_sprite)
		set_knife(knife_id)
	else:
		muzzle = Sprite2D.new()
		muzzle.name = "Muzzle"
		muzzle.texture = preload("res://assets/fx/spark.png")
		muzzle.scale = Vector2.ONE * 0.20
		muzzle.position = Vector2(0, -30)
		muzzle.modulate = Color(1, 1, 1, 0)
		body.add_child(muzzle)
	_build_animations()
	play_anim("idle")

func set_knife(id: String) -> void:
	knife_id = id
	if knife_sprite == null:
		return
	var path := "res://assets/knives/%s.png" % id
	if not ResourceLoader.exists(path):
		path = "res://assets/knives/standard.png"
	knife_sprite.texture = load(path)

func set_aiming(value: bool, relative_angle: float = 0.0, immediate: bool = false) -> void:
	# Facing is controlled by the existing guard AI. The still has no detachable
	# arm/weapon frames, so aiming never fabricates an extra gun or arm.
	if role != "guard" or dead:
		return
	guard_aim_target = 1.0 if value else 0.0
	guard_aim_offset_target = clampf(relative_angle, -0.65, 0.65) if value else 0.0
	if immediate:
		guard_aim_amount = guard_aim_target
		guard_aim_offset = guard_aim_offset_target

func _process(delta: float) -> void:
	if role == "guard" and not dead:
		guard_aim_amount = move_toward(guard_aim_amount, guard_aim_target, delta * 4.5)
		guard_aim_offset = lerp_angle(guard_aim_offset, guard_aim_offset_target, 1.0 - exp(-12.0 * delta))

func _draw() -> void:
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
	var library := AnimationLibrary.new()
	var idle := Animation.new()
	idle.length = 1.4
	idle.loop_mode = Animation.LOOP_LINEAR
	_track(idle, NodePath("Body:position"), [0.0, 0.7, 1.4], [Vector2.ZERO, Vector2(0,-0.6), Vector2.ZERO], true)
	_track(idle, NodePath("Body:rotation"), [0.0, 0.7, 1.4], [0.0, 0.012, 0.0], true)
	_track(idle, NodePath("Body:scale"), [0.0], [Vector2.ONE])
	if blade:
		_track(idle, NodePath("Body/Blade:rotation"), [0.0, 1.4], [0.0, 0.0])
	library.add_animation("idle", idle)
	var run := Animation.new()
	run.length = 0.54
	run.loop_mode = Animation.LOOP_LINEAR
	_track(run, NodePath("Body:position"), [0.0,0.135,0.27,0.405,0.54], [Vector2.ZERO,Vector2(0,-1.0),Vector2.ZERO,Vector2(0,-1.0),Vector2.ZERO], true)
	_track(run, NodePath("Body:rotation"), [0.0,0.135,0.27,0.405,0.54], [0.0,-0.035,0.0,0.035,0.0], true)
	_track(run, NodePath("Body:scale"), [0.0], [Vector2.ONE])
	if blade:
		_track(run, NodePath("Body/Blade:rotation"), [0.0,0.27,0.54], [-0.03,0.03,-0.03], true)
	library.add_animation("run", run)
	var attack := Animation.new()
	attack.length = 0.30
	_track(attack, NodePath("Body:position"), [0.0,0.10,0.30], [Vector2.ZERO,Vector2(0,-5),Vector2.ZERO])
	_track(attack, NodePath("Body:rotation"), [0.0,0.09,0.18,0.30], [0.0,-0.18,0.16,0.0])
	if blade:
		_track(attack, NodePath("Body/Blade:rotation"), [0.0,0.08,0.16,0.30], [0.0,-0.55,0.55,0.0])
	library.add_animation("attack", attack)
	var shoot := Animation.new()
	shoot.length = 0.18
	_track(shoot, NodePath("Body:position"), [0.0,0.05,0.18], [Vector2.ZERO,Vector2(0,3),Vector2.ZERO])
	if muzzle:
		_track(shoot, NodePath("Body/Muzzle:modulate"), [0.0,0.03,0.10,0.18], [Color(1,1,1,0),Color.WHITE,Color(1,1,1,0.6),Color(1,1,1,0)])
	library.add_animation("shoot", shoot)
	var hurt := Animation.new()
	hurt.length = 0.28
	_track(hurt, NodePath("Body:position"), [0.0,0.08,0.28], [Vector2.ZERO,Vector2(0,4),Vector2.ZERO])
	_track(hurt, NodePath("Body:modulate"), [0.0,0.07,0.14,0.28], [Color.WHITE,Color(1,0.35,0.35),Color.WHITE,Color.WHITE])
	library.add_animation("hurt", hurt)
	var death := Animation.new()
	death.length = 0.55
	_track(death, NodePath("Body:rotation"), [0.0,0.25,0.55], [0.0,1.0,1.35])
	_track(death, NodePath("Body:scale"), [0.0,0.55], [Vector2.ONE,Vector2(0.90,0.80)])
	_track(death, NodePath("Body:modulate"), [0.0,0.55], [Color.WHITE,Color(0.55,0.50,0.50,0.75)])
	library.add_animation("death", death)
	anim.add_animation_library("", library)
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
	if not dead and _current in ["idle", "run"]:
		play_anim("run" if moving else "idle")

func die() -> void:
	dead = true
	play_anim("death", true)

func _on_finished(name: StringName) -> void:
	if not dead and String(name) in ["attack", "shoot", "hurt"]:
		_current = ""
		play_anim("run" if moving else "idle")
