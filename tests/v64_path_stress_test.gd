extends SceneTree
func _init() -> void:
	call_deferred("run")
func run() -> void:
	var script = load("res://scripts/game/level.gd")
	var lv = script.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 640123
	var checked := 0
	var failed := 0
	var empty := 0
	var example := 0
	for n in range(1, 101):
		lv.wall_rects.clear()
		lv.crate_rects.clear()
		lv._load_level(n)
		lv._build_grid()
		lv._build_walkable_regions()
		var region: Array = lv.walkable_regions[int(lv.region_by_cell[lv._to_cell(lv.player_pos)])]
		for t in range(100):
			var c: Vector2i = region[rng.randi_range(0, region.size()-1)]
			var center: Vector2 = lv._cell_center(c.x, c.y)
			var p: Vector2 = center + Vector2(rng.randf_range(-15.9, 15.9), rng.randf_range(-15.9, 15.9))
			if lv._solid(p):
				p = center
			lv.player_pos = p
			var d: Vector2i = region[rng.randi_range(0, region.size()-1)]
			var dest: Vector2 = lv._cell_center(d.x, d.y) + Vector2(rng.randf_range(-15.9,15.9), rng.randf_range(-15.9,15.9))
			if lv._solid(dest):
				dest = lv._cell_center(d.x, d.y)
			lv._path_to(dest)
			if lv.player_path.is_empty() and p.distance_to(dest) > 2.0:
				empty += 1
				if example < 15:
					print("EMPTY level=",n," start=",p," cell=",c," dest=",dest)
					example += 1
			var previous: Vector2 = p
			for point in lv.player_path:
				checked += 1
				if not lv._los(previous, point):
					failed += 1
					if example < 15:
						print("BADSEG level=",n," start=",p," seg=",previous,"->",point," dest=",dest)
						example += 1
				previous = point
	print("V64 PATH STRESS segments=",checked," invalid=",failed," empty=",empty)
	lv.free()
	quit(1 if failed or empty else 0)
