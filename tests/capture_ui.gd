extends SceneTree
## Visual capture helper: xvfb-run godot --path . --resolution 720x1600 --script tests/capture_ui.gd
var out := OS.get_environment("APEX_CAPTURE_DIR")
func _capture_dir() -> String:
	return out if out != "" else ProjectSettings.globalize_path("user://captures")
func _init() -> void:
	DirAccess.make_dir_recursive_absolute(_capture_dir())
	call_deferred("_run")
func _save(name: String) -> void:
	await process_frame
	await process_frame
	var img := root.get_texture().get_image()
	img.save_png(_capture_dir().path_join(name + ".png"))
	print("saved ", name)
func _run() -> void:
	var gs = root.get_node("GameState")
	gs.sound_enabled = false
	gs.gems = 1000
	gs.cash = 5000
	gs.unlocked_level = 60
	gs.current_level = 4
	gs.unlock_character("nova")
	gs.unlock_character("oni")
	gs.buy_knife("apex")
	gs.select_knife("apex")
	change_scene_to_file("res://scenes/home/home.tscn")
	await process_frame
	await process_frame
	await _save("home")
	var home = current_scene
	home._open_assassins()
	await _save("characters")
	home._open_knives()
	await _save("knives")
	home._close_overlay()
	gs.start_level(4)
	await process_frame
	await process_frame
	await create_timer(0.5).timeout
	await _save("level")
	quit()
