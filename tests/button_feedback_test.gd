extends SceneTree
## Global button-only tap pulse and user-audio hook. Uses an in-memory test tone.
var checks := 0
var failures := 0
func _init() -> void:
	call_deferred("_run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ", message)
func _run() -> void:
	var gs = root.get_node("GameState")
	var sfx = root.get_node("Sfx")
	var holder := Control.new()
	root.add_child(holder)
	var button := Button.new()
	button.text = "Test"
	button.size = Vector2(180, 60)
	holder.add_child(button)
	var texture_button := TextureButton.new()
	texture_button.size = Vector2(50,50)
	holder.add_child(texture_button)
	await process_frame
	check(button.has_meta("apex_tap_feedback") and texture_button.has_meta("apex_tap_feedback"), "normal and texture buttons are registered automatically")
	# This synthetic test stream never becomes the user's delivered audio.
	var test_audio := AudioStreamWAV.new()
	test_audio.format = AudioStreamWAV.FORMAT_8_BITS
	test_audio.mix_rate = 22050
	var samples := PackedByteArray()
	samples.resize(22050)
	test_audio.data = samples
	sfx.streams["ui_tap"] = test_audio
	gs.sound_enabled = true
	button.button_down.emit()
	var playing := false
	for player in sfx.players:
		if player.playing and player.stream == test_audio:
			playing = true
	check(playing, "button down triggers the registered tap stream when sound is enabled")
	# Advance the actual Tween deterministically; wall-clock sleeps can skip a
	# very short pulse on a busy CI host before the test gets CPU time.
	var pulse: Tween = button.get_meta("apex_tap_tween")
	pulse.pause()
	pulse.custom_step(0.035)
	check(button.scale.x < 0.995 and button.scale.y < 0.995, "button visibly compresses on tap")
	pulse.custom_step(0.3)
	check(button.scale.distance_to(Vector2.ONE) < 0.001, "button returns to its original scale")
	for player in sfx.players:
		player.stop()
	gs.sound_enabled = false
	texture_button.button_down.emit()
	playing = false
	for player in sfx.players:
		if player.playing: playing = true
	check(not playing, "sound toggle mutes the tap sound")
	var muted_pulse: Tween = texture_button.get_meta("apex_tap_tween")
	muted_pulse.pause()
	muted_pulse.custom_step(0.035)
	check(texture_button.scale.x < 0.995, "visual button feedback still works with sound muted")
	button.disabled = true
	button.remove_meta("apex_tap_tween")
	button.button_down.emit()
	check(not button.has_meta("apex_tap_tween"), "disabled buttons do not generate tap effects")
	for player in sfx.players:
		player.stop()
		player.stream = null
	sfx.streams.erase("ui_tap")
	holder.queue_free()
	await create_timer(0.3).timeout  # Release the test audio and deferred tweens.
	print("BUTTON FEEDBACK %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
