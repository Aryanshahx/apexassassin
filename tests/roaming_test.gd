extends SceneTree
## Map-wide patrol, cover clearance and enemy separation, with isolated saves.
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
	gs.sound_enabled = false
	for number in [1, 2, 17, 50, 100]:
		gs.start_level(number)
		await process_frame
		await process_frame
		var level = current_scene
		level.set_physics_process(false)
		level.player_pos = Vector2(-10000, -10000)
		var distance := []
		var last := []
		var visited := []
		for guard in level.guards:
			distance.append(0.0)
			last.append(guard.pos)
			visited.append({level._to_cell(guard.pos): true})
		var min_gap := INF
		var solid_frames := 0
		for frame in range(1200):
			level._update_guards(1.0 / 60.0)
			for i in range(level.guards.size()):
				var guard: Dictionary = level.guards[i]
				distance[i] += guard.pos.distance_to(last[i])
				last[i] = guard.pos
				visited[i][level._to_cell(guard.pos)] = true
				if level._solid(guard.pos):
					solid_frames += 1
				for j in range(i + 1, level.guards.size()):
					min_gap = minf(min_gap, guard.pos.distance_to(level.guards[j].pos))
		check(solid_frames == 0, "level %d guards never enter cover" % number)
		check(min_gap >= level.GUARD_GAP - 0.06, "level %d guards maintain safe separation" % number)
		for i in range(level.guards.size()):
			check(distance[i] > 250.0 and visited[i].size() > 6, "level %d guard %d roams beyond its original patrol" % [number, i])
		print("ROAM level=", number, " min_gap=", snappedf(min_gap, 0.01), " cover_frames=", solid_frames, " visited=", visited.map(func(v): return v.size()))
	print("ROAMING %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
