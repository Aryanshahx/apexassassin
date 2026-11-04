extends Control
## Menu display only: the real equipped melee rig runs in place; no input or
## combat, save, collision, or gameplay movement logic is changed.
const PlayerRig := preload("res://scripts/game/ten_character_player.gd")

var rig
var appearance := "standard"
var weapon := "aurora"

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	resized.connect(_layout_actor)
	_update_actor()

func configure(look_id: String, weapon_id: String) -> void:
	appearance = look_id
	weapon = weapon_id
	if is_inside_tree():
		_update_actor()

func _update_actor() -> void:
	if rig != null and is_instance_valid(rig) and rig.current_look == appearance:
		rig.set_knife(weapon)
		rig.set_moving(true)
		_layout_actor()
		return
	if rig != null and is_instance_valid(rig):
		remove_child(rig)
		rig.queue_free()
	rig = PlayerRig.new()
	rig.name = "RunningEquippedCharacter"
	add_child(rig)
	rig.setup(appearance, "player")
	rig.set_knife(weapon)
	rig.set_moving(true)
	_layout_actor()

func _layout_actor() -> void:
	if rig == null or not is_instance_valid(rig):
		return
	var dim := maxf(1.0, minf(size.x, size.y))
	# The equipped weapon extends in front of the fist. Fit the complete rig,
	# not just the torso, so even the large Leviathan stays inside the card.
	rig.position = size * 0.5 + Vector2(0, dim * 0.17)
	rig.scale = Vector2.ONE * (dim / 60.0)
