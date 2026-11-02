extends SceneTree
## Audio is private and absent from code-only builds. When both user files are
## present, verify Godot imported the real MP3 resources and Sfx dispatches them.
func _init() -> void: call_deferred("_run")
func _run() -> void:
	var gs = root.get_node("GameState")
	var sfx = root.get_node("Sfx")
	var pick := FileAccess.file_exists("res://assets/audio/pickkey.mp3")
	var unlock := FileAccess.file_exists("res://assets/audio/unlockkey.mp3")
	if not pick and not unlock:
		print("V72 KEY AUDIO SKIPPED: private Pi recordings are not in this checkout")
		quit(0)
		return
	if not pick or not unlock or not sfx.streams.has("pickkey") or not sfx.streams.has("unlockkey"):
		printerr("FAIL: both key MP3s must be present and imported together")
		quit(1)
		return
	var failures := 0
	for effect in ["pickkey", "unlockkey"]:
		var stream = sfx.streams[effect]
		if not stream is AudioStreamMP3 or not stream.resource_path.ends_with("/audio/%s.mp3" % effect):
			printerr("FAIL: imported stream is not the requested MP3: ",effect)
			failures += 1
		gs.sound_enabled = true
		sfx.play(effect, -3.0)
		var found := false
		for p in sfx.players:
			if p.stream == stream and p.playing: found = true
		if not found:
			printerr("FAIL: requested MP3 did not start: ",effect)
			failures += 1
	for p in sfx.players:
		p.stop()
		p.stream = null
	await create_timer(0.2).timeout
	print("V72 KEY AUDIO 4 checks, %d failures" % failures)
	quit(1 if failures else 0)
