extends Node
## Separate looping music for the two real game scenes. Music uses the same
## saved sound switch as effects but never consumes an Sfx pool voice.
## The user's MP3s are loaded from the project at runtime; no recording is
## embedded in the updater. Unknown scenes are deliberately silent.

const HOME_SCENE := "res://scenes/home/home.tscn"
const GAME_SCENE := "res://scenes/level/level.tscn"
const HOME_MUSIC := "res://assets/audio/homeaudio.mp3"
const GAME_MUSIC := "res://assets/audio/gameplay2.mp3"
const MUSIC_VOLUME_DB := -10.0

var player: AudioStreamPlayer
var context := ""
var selected_path := ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	player = AudioStreamPlayer.new()
	player.name = "MusicPlayer"
	player.volume_db = MUSIC_VOLUME_DB
	player.bus = "Master"
	add_child(player)

func _process(_delta: float) -> void:
	var scene := get_tree().current_scene
	var scene_path := scene.scene_file_path if scene != null else ""
	var desired := ""
	if scene_path == HOME_SCENE:
		desired = "home"
	elif scene_path == GAME_SCENE:
		desired = "gameplay"
	if desired != context:
		_switch_to(desired)
	# Mute and unmute without restarting the track, and respond to the existing
	# Settings button without changing or extending the saved data schema.
	var sfx_enabled := bool(get_parent().get("enabled"))
	player.stream_paused = not (GameState.sound_enabled and sfx_enabled)

func _switch_to(desired: String) -> void:
	context = desired
	player.stop()
	player.stream = null
	selected_path = ""
	if desired == "home":
		selected_path = HOME_MUSIC
	elif desired == "gameplay":
		selected_path = GAME_MUSIC
	else:
		return
	if not ResourceLoader.exists(selected_path):
		push_warning("Background music is missing or not imported: " + selected_path)
		return
	var track: Resource = load(selected_path)
	if not track is AudioStreamMP3 or track.get_length() <= 0.0:
		push_warning("Background music is not a playable MP3: " + selected_path)
		return
	track.loop = true
	player.stream = track
	player.play()
