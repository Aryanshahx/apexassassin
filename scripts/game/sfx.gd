extends Node
## Pooled sound effects plus opt-in user-supplied button audio.
## A global button-down hook gives all buttons a brief visual tap response.
var enabled := true
var players: Array[AudioStreamPlayer] = []
var streams := {}

func _ready() -> void:
	for n in ["blade", "shot", "alert", "coin", "hurt", "win", "lose", "upgrade"]:
		var path := "res://assets/audio/%s.wav" % n
		if ResourceLoader.exists(path):
			streams[n] = load(path)
	# This optional resource is supplied by the user; no unrelated substitute is
	# silently installed when it is absent.
	var user_audio := {
		"ui_tap": "res://assets/audio/ui_tap_audio.mp3",
		"stab": "res://assets/audio/stab2.mp3",
		"suspect": "res://assets/audio/suspect2.mp3",
	}
	for effect in user_audio:
		var path: String = user_audio[effect]
		if ResourceLoader.exists(path):
			streams[effect] = load(path)
	get_tree().node_added.connect(_register_button)
	for i in range(10):
		var p := AudioStreamPlayer.new()
		add_child(p)
		players.append(p)

func play(name: String, volume_db: float = -6.0) -> void:
	if not enabled or not GameState.sound_enabled or not streams.has(name):
		return
	for p in players:
		if not p.playing:
			p.stream = streams[name]
			p.volume_db = volume_db
			p.play()
			return
	# User-provided effects are important even if the ordinary pool is full.
	# Reuse a voice so a stab, detection or button press is not silently lost.
	if name in ["ui_tap", "stab", "suspect"] and not players.is_empty():
		var p := players[0]
		p.stop()
		p.stream = streams[name]
		p.volume_db = volume_db
		p.play()

func _register_button(node: Node) -> void:
	if node is not BaseButton:
		return
	var button: BaseButton = node
	if button.has_meta("apex_tap_feedback"):
		return
	button.set_meta("apex_tap_feedback", true)
	button.button_down.connect(_button_down.bind(button))

func _button_down(button: BaseButton) -> void:
	if not is_instance_valid(button) or button.disabled:
		return
	play("ui_tap", -3.0)
	# A scale pulse belongs to the pressed button itself. It does not draw a
	# destination ring or touch highlight on the gameplay field.
	if button.has_meta("apex_tap_tween"):
		var previous: Variant = button.get_meta("apex_tap_tween")
		if previous is Tween and previous.is_valid():
			previous.kill()
		button.scale = button.get_meta("apex_tap_original_scale", button.scale)
	var original: Vector2 = button.scale
	button.set_meta("apex_tap_original_scale", original)
	button.pivot_offset = button.size * 0.5
	var tween := button.create_tween()
	button.set_meta("apex_tap_tween", tween)
	tween.tween_property(button, "scale", original * 0.93, 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", original, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
