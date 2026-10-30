extends Node2D
class_name ActorRig
## Original modular 2D actor rig. All art in assets/characters was authored for
## Apex Assassin. AnimationPlayer clips drive real node tracks (idle, run,
## attack, shoot, hurt, death) rather than swapping a static picture.

var kind := "ronin"
var role := "player"
var moving := false
var dead := false
var body: Node2D
var torso: Node2D
var head: Node2D
var arm_l: Node2D
var arm_r: Node2D
var leg_l: Node2D
var leg_r: Node2D
var scarf: Node2D
var weapon: Node2D
var muzzle: Sprite2D
var anim: AnimationPlayer
var _current := ""
var knife_id := "standard"
var knife_sprite: Sprite2D

func setup(p_kind: String, p_role: String = "player") -> void:
	kind = p_kind
	role = p_role
	_build()
	_build_animations()
	play_anim("idle")

func _tex(part: String) -> Texture2D:
	return load("res://assets/characters/%s/%s.png" % [kind, part])

func _sprite(part: String, pos: Vector2, offset: Vector2 = Vector2.ZERO) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = _tex(part)
	s.scale = Vector2.ONE / 3.0
	s.position = pos + offset
	return s

func _build() -> void:
	body = Node2D.new()
	body.name = "Body"
	add_child(body)
	# Legs behind torso. Pivots are hips.
	leg_l = Node2D.new(); leg_l.name = "LegL"; leg_l.position = Vector2(-7, 7); body.add_child(leg_l)
	leg_l.add_child(_sprite("leg", Vector2(0, 10)))
	leg_r = Node2D.new(); leg_r.name = "LegR"; leg_r.position = Vector2(7, 7); body.add_child(leg_r)
	leg_r.add_child(_sprite("leg", Vector2(0, 10)))
	scarf = Node2D.new(); scarf.name = "Scarf"; scarf.position = Vector2(0, 8); body.add_child(scarf)
	scarf.add_child(_sprite("scarf", Vector2(0, 18)))
	torso = Node2D.new(); torso.name = "Torso"; body.add_child(torso)
	torso.add_child(_sprite("torso", Vector2.ZERO))
	arm_l = Node2D.new(); arm_l.name = "ArmL"; arm_l.position = Vector2(-15, -3); torso.add_child(arm_l)
	arm_l.add_child(_sprite("arm", Vector2(0, 12)))
	arm_r = Node2D.new(); arm_r.name = "ArmR"; arm_r.position = Vector2(15, -3); torso.add_child(arm_r)
	arm_r.add_child(_sprite("arm", Vector2(0, 12)))
	head = Node2D.new(); head.name = "Head"; head.position = Vector2(0, -15); torso.add_child(head)
	head.add_child(_sprite("head", Vector2.ZERO))
	weapon = Node2D.new(); weapon.name = "Weapon"; weapon.position = Vector2(0, 20); arm_r.add_child(weapon)
	if role == "guard":
		var rifle := _sprite("rifle", Vector2(0, -18))
		weapon.add_child(rifle)
		muzzle = Sprite2D.new()
		muzzle.name = "Muzzle"
		muzzle.texture = preload("res://assets/fx/spark.png")
		muzzle.scale = Vector2.ONE * 0.5
		muzzle.position = Vector2(0, -42)
		muzzle.modulate.a = 0.0
		weapon.add_child(muzzle)
		# Both hands forward on the rifle.
		arm_l.rotation = -0.35
		arm_r.rotation = 0.35
	else:
		knife_sprite = Sprite2D.new()
		knife_sprite.name = "Knife"
		knife_sprite.position = Vector2(0, -24)
		knife_sprite.scale = Vector2.ONE * 0.30
		weapon.add_child(knife_sprite)
		set_knife(knife_id)

func set_knife(id: String) -> void:
	knife_id = id
	if knife_sprite == null:
		return
	var path := "res://assets/knives/%s.png" % id
	if ResourceLoader.exists(path):
		knife_sprite.texture = load(path)

func _draw() -> void:
	# Soft contact shadow.
	draw_set_transform(Vector2(0, 10), 0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, 18.0, Color(0, 0, 0, 0.28))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

func _track(a: Animation, path: NodePath, times: Array, values: Array, type: int = Animation.TYPE_VALUE) -> void:
	var idx := a.add_track(type)
	a.track_set_path(idx, path)
	for i in range(times.size()):
		a.track_insert_key(idx, times[i], values[i])
	if type == Animation.TYPE_VALUE:
		a.track_set_interpolation_type(idx, Animation.INTERPOLATION_LINEAR)

func _build_animations() -> void:
	anim = AnimationPlayer.new()
	anim.name = "AnimationPlayer"
	add_child(anim)
	var lib := AnimationLibrary.new()
	# Idle: breathing + scarf sway.
	var idle := Animation.new(); idle.length = 1.6; idle.loop_mode = Animation.LOOP_LINEAR
	_track(idle, NodePath("Body/Torso:scale"), [0, 0.8, 1.6], [Vector2.ONE, Vector2(1.02, 0.98), Vector2.ONE])
	_track(idle, NodePath("Body/Torso/Head:position"), [0, 0.8, 1.6], [Vector2(0, -15), Vector2(0, -14), Vector2(0, -15)])
	_track(idle, NodePath("Body/Scarf:rotation"), [0, 0.8, 1.6], [-0.08, 0.10, -0.08])
	lib.add_animation("idle", idle)
	# Run: alternating legs/arms, bob, scarf trail.
	var run := Animation.new(); run.length = 0.42; run.loop_mode = Animation.LOOP_LINEAR
	_track(run, NodePath("Body/LegL:rotation"), [0, 0.21, 0.42], [0.65, -0.65, 0.65])
	_track(run, NodePath("Body/LegR:rotation"), [0, 0.21, 0.42], [-0.65, 0.65, -0.65])
	_track(run, NodePath("Body/Torso:position"), [0, 0.105, 0.21, 0.315, 0.42], [Vector2.ZERO, Vector2(0, -2), Vector2.ZERO, Vector2(0, -2), Vector2.ZERO])
	_track(run, NodePath("Body/Scarf:rotation"), [0, 0.21, 0.42], [0.35, 0.55, 0.35])
	if role == "player":
		_track(run, NodePath("Body/Torso/ArmL:rotation"), [0, 0.21, 0.42], [-0.5, 0.5, -0.5])
		_track(run, NodePath("Body/Torso/ArmR:rotation"), [0, 0.21, 0.42], [0.5, -0.5, 0.5])
	lib.add_animation("run", run)
	# Attack: windup, slash, recover.
	var atk := Animation.new(); atk.length = 0.30
	_track(atk, NodePath("Body/Torso/ArmR:rotation"), [0, 0.08, 0.16, 0.30], [0.2, -1.9, 1.2, 0.0])
	_track(atk, NodePath("Body/Torso:position"), [0, 0.10, 0.30], [Vector2.ZERO, Vector2(0, -5), Vector2.ZERO])
	_track(atk, NodePath("Body/Torso/ArmL:rotation"), [0, 0.12, 0.30], [0.0, -0.6, 0.0])
	lib.add_animation("attack", atk)
	# Guard shoot: recoil + muzzle flash.
	var shoot := Animation.new(); shoot.length = 0.18
	_track(shoot, NodePath("Body/Torso/ArmR/Weapon:position"), [0, 0.05, 0.18], [Vector2(0, 20), Vector2(0, 25), Vector2(0, 20)])
	if muzzle:
		_track(shoot, NodePath("Body/Torso/ArmR/Weapon/Muzzle:modulate"), [0, 0.03, 0.10, 0.18], [Color(1,1,1,0), Color(1,1,1,1), Color(1,1,1,0.6), Color(1,1,1,0)])
	lib.add_animation("shoot", shoot)
	# Hurt.
	var hurt := Animation.new(); hurt.length = 0.28
	_track(hurt, NodePath("Body:modulate"), [0, 0.07, 0.14, 0.28], [Color.WHITE, Color(1, 0.35, 0.35), Color.WHITE, Color.WHITE])
	_track(hurt, NodePath("Body:position"), [0, 0.08, 0.28], [Vector2.ZERO, Vector2(0, 5), Vector2.ZERO])
	lib.add_animation("hurt", hurt)
	# Death: collapse and fade to a readable corpse.
	var death := Animation.new(); death.length = 0.55
	_track(death, NodePath("Body:rotation"), [0, 0.25, 0.55], [0.0, 1.25, 1.55])
	_track(death, NodePath("Body:scale"), [0, 0.25, 0.55], [Vector2.ONE, Vector2(0.95, 0.85), Vector2(0.9, 0.8)])
	_track(death, NodePath("Body:modulate"), [0, 0.55], [Color.WHITE, Color(0.55, 0.5, 0.5, 0.75)])
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
