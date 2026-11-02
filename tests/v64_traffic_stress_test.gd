extends SceneTree
## All 100 real levels: sustained shared-target pursuit, safe clearance and
## no long unexplained stationary/jitter episodes. Close visible guards are
## allowed to hold position while aiming and firing.
func _init() -> void:
	call_deferred("run")

func run() -> void:
	var gs = root.get_node("GameState")
	gs.sound_enabled = false
	var walls := []
	var overlaps := []
	var stalls := []
	var lowest := INF
	var longest := 0.0
	var all_guards := 0
	var substantial_moves := 0
	for number in range(1, 101):
		gs.start_level(number)
		await process_frame
		await process_frame
		var lv = current_scene
		lv.set_physics_process(false)
		var center: Vector2i = lv.guard_walkable_regions[0][int(lv.guard_walkable_regions[0].size() / 2)]
		var target: Vector2 = lv._cell_center(center.x, center.y)
		# The player is really at the shared target; putting the player off-map
		# would make live-target pursuit walk away from the congestion scenario.
		lv.player_pos = target
		var tracks := []
		for g in lv.guards:
			g.state = lv.GState.ALERT
			g.last_seen = target
			g.path.clear()
			g.sees_player = false
			g.chase_left = lv._chase_duration(g)
			tracks.append({"anchor": g.pos, "origin": g.pos, "age": 0.0, "max_wait": 0.0, "travel": 0.0})
		var min_gap := INF
		var solid_hits := 0
		for frame in range(720):
			var before := []
			for g in lv.guards:
				before.append(g.pos)
			lv._update_guards(1.0 / 60.0)
			for i in range(lv.guards.size()):
				var g: Dictionary = lv.guards[i]
				var track: Dictionary = tracks[i]
				track.travel += before[i].distance_to(g.pos)
				if lv._guard_solid(g.pos):
					solid_hits += 1
				for j in range(i):
					min_gap = minf(min_gap, g.pos.distance_to(lv.guards[j].pos))
				if g.state == lv.GState.ALERT and g.pos.distance_to(target) > 200.0 and not g.sees_player:
					# Require 20 units of net movement, so back-and-forth jitter is
					# not mistakenly counted as useful recovery.
					if track.anchor.distance_to(g.pos) > 20.0:
						track.anchor = g.pos
						track.age = 0.0
					else:
						track.age += 1.0 / 60.0
						track.max_wait = maxf(track.max_wait, track.age)
				else:
					track.anchor = g.pos
					track.age = 0.0
		for i in range(lv.guards.size()):
			var g: Dictionary = lv.guards[i]
			var track: Dictionary = tracks[i]
			all_guards += 1
			longest = maxf(longest, track.max_wait)
			if track.travel > 100.0 and g.pos.distance_to(track.origin) > 50.0:
				substantial_moves += 1
			if track.max_wait > 5.0:
				stalls.append([number, i, track.max_wait])
		if min_gap < lv.GUARD_GAP - 0.06:
			overlaps.append([number, min_gap])
		if solid_hits > 0:
			walls.append([number, solid_hits])
		lowest = minf(lowest, min_gap)
		if number % 20 == 0:
			print("through ", number, " overlaps=", overlaps.size(), " walls=", walls.size(), " long stalls=", stalls.size())
	print("ALERT TRAFFIC guards=", all_guards, " substantial_moves=", substantial_moves, " walls=", walls, " overlaps=", overlaps, " min_gap=", lowest, " max_unseen_wait=", longest, " stalls>5s=", stalls)
	quit(1 if not walls.is_empty() or not overlaps.is_empty() or not stalls.is_empty() or all_guards != 730 else 0)
