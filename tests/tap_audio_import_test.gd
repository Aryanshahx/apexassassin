extends SceneTree
## After the real MP3 is installed and imported, test the exact user-provided
## stream, global button hook and mute setting without modifying any save.
const TAP_PATH := "res://assets/audio/ui_tap_audio.mp3"
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
	var sfx = root.get_node("Sfx")
	var gs = root.get_node("GameState")
	var button := Button.new()
	button.text = "Tap test"
	root.add_child(button)
	await process_frame
	var bytes := FileAccess.get_file_as_bytes(TAP_PATH)
	check(bytes.size() > 0, "the user's MP3 exists and is nonempty")
	check(ResourceLoader.exists(TAP_PATH), "Godot imported the MP3")
	var stream: Variant = sfx.streams.get("ui_tap")
	check(stream is AudioStreamMP3, "Sfx registered the imported MP3 stream")
	if stream is AudioStreamMP3:
		check(stream.data == bytes, "imported MP3 contains the original file bytes")
		check(stream.get_length() > 0.0, "MP3 stream has a playable duration")
	else:
		check(false, "imported MP3 contains the original file bytes")
		check(false, "MP3 stream has a playable duration")
	for player in sfx.players:
		player.stop()
	gs.sound_enabled = true
	button.button_down.emit()
	var played := false
	for player in sfx.players:
		if player.playing and player.stream == stream:
			played = true
	check(played, "pressing a button plays the registered MP3")
	# UI taps should not be lost even if every pooled voice is busy.
	var busy_audio := AudioStreamWAV.new()
	busy_audio.mix_rate = 22050
	var busy_samples := PackedByteArray()
	busy_samples.resize(22050)
	busy_audio.data = busy_samples
	for player in sfx.players:
		player.stop()
		player.stream = busy_audio
		player.play()
	button.button_down.emit()
	played = false
	for player in sfx.players:
		if player.playing and player.stream == stream:
			played = true
	check(played, "a full effects pool still plays the tap MP3")
	for player in sfx.players:
		player.stop()
	gs.sound_enabled = false
	button.button_down.emit()
	played = false
	for player in sfx.players:
		if player.playing:
			played = true
	check(not played, "muting sound prevents MP3 playback")
	for player in sfx.players:
		player.stop()
		player.stream = null
	sfx.streams.erase("ui_tap")
	stream = null
	button.queue_free()
	await create_timer(0.3).timeout  # Let the audio server release playback objects.
	print("TAP MP3 %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
