extends SceneTree
## Repeated actual win -> Next Level transitions and resource-lifetime regression.
## Run only with an isolated XDG_DATA_HOME: game progress is saved.
var checks := 0
var failures := 0
func _init() -> void:
	call_deferred("_run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ", message)
func button_with_text(node: Node, text: String) -> Button:
	for child in node.find_children("*", "Button", true, false):
		if child.text == text:
			return child
	return null
func _run() -> void:
	var gs = root.get_node("GameState")
	gs.sound_enabled = false
	gs.current_level = 1
	gs.unlocked_level = 1
	gs.selected_assassin = "ronin"
	gs.start_level(1)
	await process_frame
	await process_frame
	var shared_depot: Texture2D = gs.depot_textures()["blue_cap_a"]
	var node_counts := []
	var transitions_usec := []
	for number in range(1, 10):
		var level = current_scene
		check(level != null and int(level.data.id) == number, "level %d loaded after Next Level" % number)
		check(level.map_backplate != null and level.map_backplate.show_behind_parent and level.map_cover != null, "level %d uses retained floor and cover layers" % number)
		check(gs.depot_textures()["blue_cap_a"] == shared_depot and gs._level_catalog.size() == 100, "level %d reuses art and parsed level data" % number)
		if number == 1:
			# Static floor and cover commands stay retained as dynamic actors move.
			await process_frame
			var floor_draws: int = level.map_backplate.draw_count
			var cover_draws: int = level.map_cover.draw_count
			for frame in range(6):
				await process_frame
			check(floor_draws > 0 and cover_draws > 0 and level.map_backplate.draw_count == floor_draws and level.map_cover.draw_count == cover_draws, "floor and cover are not re-recorded every frame")
		level.set_physics_process(false)
		var previous_id: int = level.get_instance_id()
		level.kills = level.total
		level._win()
		var button := button_with_text(level.overlay, "Next Level")
		check(button != null and gs.current_level == number + 1, "level %d awards and offers the next level" % number)
		var started := Time.get_ticks_usec()
		if button:
			button.pressed.emit()
		await process_frame
		await process_frame
		await process_frame
		transitions_usec.append(Time.get_ticks_usec() - started)
		check(instance_from_id(previous_id) == null, "level %d was freed after transition" % number)
		node_counts.append(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
	check(node_counts.max() < 200, "scene nodes do not accumulate over repeated transitions")
	print("TRANSITIONS node_counts=", node_counts, " transition_usec=", transitions_usec)
	print("TRANSITION %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
