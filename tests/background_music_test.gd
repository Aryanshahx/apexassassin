extends SceneTree
## Run only with isolated synthetic saves. Requires both intended MP3s after
## Godot import, and exercises real home/level scenes and the existing mute.
const HOME_PATH := "res://assets/audio/homeaudio.mp3"
const GAME_PATH := "res://assets/audio/gameplay3.mp3"
const HOME_SCENE := "res://scenes/home/home.tscn"
const LEVEL_SCENE := "res://scenes/level/level.tscn"
var checks := 0
var failures := 0

func _init() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", message)

func _run() -> void:
	var gs = root.get_node("GameState")
	var sfx = root.get_node("Sfx")
	var music = sfx.get_node_or_null("BackgroundMusic")
	check(music != null, "Sfx has a separate background music controller")
	if music == null:
		quit(1)
		return
	var player: AudioStreamPlayer = music.get_node_or_null("MusicPlayer")
	check(player != null, "music has its own audio player")
	if player == null:
		quit(1)
		return
	check(sfx.players.size() == 10 and not sfx.players.has(player), "music does not consume an effects voice")
	for path in [HOME_PATH, GAME_PATH]:
		var bytes := FileAccess.get_file_as_bytes(path)
		check(not bytes.is_empty(), path + " exists and is nonempty")
		check(ResourceLoader.exists(path), path + " was imported by Godot")
		var stream: Variant = load(path) if ResourceLoader.exists(path) else null
		check(stream is AudioStreamMP3, path + " is an MP3 stream")
		if stream is AudioStreamMP3:
			check(stream.data == bytes, path + " imported the exact source bytes")
			check(stream.get_length() > 0.0, path + " has playable duration")
			check(stream.resource_path == path, path + " uses the intended path")
		else:
			check(false, path + " imported the exact source bytes")
			check(false, path + " has playable duration")
			check(false, path + " uses the intended path")
	gs.sound_enabled = true
	sfx.enabled = true
	var home := (load(HOME_SCENE) as PackedScene).instantiate()
	root.add_child(home)
	current_scene = home
	await process_frame
	music.call("_process", 0.0)
	check(music.context == "home", "the actual home scene selects home music")
	check(music.selected_path == HOME_PATH, "home uses homeaudio.mp3")
	check(player.stream is AudioStreamMP3 and player.stream.resource_path == HOME_PATH, "home stream attached to music player")
	check(player.playing and not player.stream_paused, "home music starts when sound is enabled")
	check(player.stream is AudioStreamMP3 and player.stream.loop, "home music loops")
	var home_stream := player.stream
	music.call("_process", 0.0)
	check(player.stream == home_stream and player.playing, "same scene does not restart the music")
	gs.sound_enabled = false
	music.call("_process", 0.0)
	check(player.stream == home_stream and player.stream_paused, "existing sound OFF pauses home music")
	gs.sound_enabled = true
	music.call("_process", 0.0)
	check(player.stream == home_stream and not player.stream_paused, "existing sound ON resumes the same music")
	sfx.enabled = false
	music.call("_process", 0.0)
	check(player.stream_paused, "global Sfx disable also pauses music")
	sfx.enabled = true
	music.call("_process", 0.0)
	check(not player.stream_paused, "music resumes when Sfx is enabled")
	gs.sound_enabled = false
	music.call("_process", 0.0)
	var level := (load(LEVEL_SCENE) as PackedScene).instantiate()
	root.add_child(level)
	current_scene = level
	home.queue_free()
	await process_frame
	music.call("_process", 0.0)
	check(music.context == "gameplay", "the actual level scene selects gameplay music")
	check(music.selected_path == GAME_PATH, "level uses gameplay3.mp3")
	check(player.stream is AudioStreamMP3 and player.stream.resource_path == GAME_PATH, "gameplay stream replaces home music")
	check(player.stream_paused, "transitioning scenes while muted keeps gameplay music muted")
	gs.sound_enabled = true
	music.call("_process", 0.0)
	check(player.playing and not player.stream_paused, "gameplay music starts when unmuted")
	check(player.stream is AudioStreamMP3 and player.stream.loop, "gameplay music loops")
	gs.sound_enabled = false
	music.call("_process", 0.0)
	check(player.stream_paused, "existing sound OFF pauses gameplay music")
	gs.sound_enabled = true
	music.call("_process", 0.0)
	check(not player.stream_paused, "existing sound ON resumes gameplay music")
	var home_again := (load(HOME_SCENE) as PackedScene).instantiate()
	root.add_child(home_again)
	current_scene = home_again
	level.queue_free()
	await process_frame
	music.call("_process", 0.0)
	check(music.context == "home" and player.stream is AudioStreamMP3 and player.stream.resource_path == HOME_PATH, "returning home restores the home track")
	current_scene = null
	home_again.queue_free()
	music.call("_process", 0.0)
	check(music.context == "" and not player.playing and player.stream == null, "unknown or absent scenes are silent")
	player.stop()
	player.stream = null
	await create_timer(0.2).timeout
	print("BACKGROUND MUSIC %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
