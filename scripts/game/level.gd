extends Node2D
## Apex Assassin core stealth loop.
## Tap floor to move, tap a guard to hunt. Auto-blade in range. Guards patrol,
## investigate noise, chase on sight, fire line-of-sight bullets, and search.
## Cover blocks sight/bullets; shadows slow detection. Kills drop gems.

const CELL := 32.0
const ORIGIN := Vector2(24, 140)
const FONT := preload("res://assets/fonts/Baloo2.ttf")
const FLOOR := preload("res://assets/level/floor_tile.png")
const CRATE_TEX := {
	"blue": preload("res://assets/level/crate_blue.png"),
	"olive": preload("res://assets/level/crate_olive.png"),
	"gray": preload("res://assets/level/crate_gray.png"),
}
const TARGET_TEX := preload("res://assets/ui/target.png")
const GEM_TEX := preload("res://assets/ui/gem_drop.png")
const SLASH_TEX := preload("res://assets/fx/slash.png")
const SPARK_TEX := preload("res://assets/fx/spark.png")
const HEART_TEX := preload("res://assets/ui/heart.png")
const ActorRigScript := preload("res://scripts/game/actor_rig.gd")

enum GState { PATROL, INVESTIGATE, ALERT, SEARCH, DEAD }

var data: Dictionary = {}
var grid := AStarGrid2D.new()
var wall_rects: Array[Rect2] = []
var crate_rects: Array[Rect2] = []
var shadow_rects: Array[Rect2] = []
var player_pos := Vector2.ZERO
var player_face := -PI / 2
var player_path := PackedVector2Array()
var player_hp := 3.0
var invuln := 0.0
var attack_cd := 0.0
var hunt_target := -1
var repath := 0.0
var player_rig: Node2D
var guards: Array[Dictionary] = []
var bullets: Array[Dictionary] = []
var effects: Array[Dictionary] = []
var gems: Array[Dictionary] = []
var kills := 0
var total := 0
var gems_collected := 0
var damage_taken := 0
var was_alerted := false
var finished := false
var elapsed := 0.0
var counter: Label
var gem_label: Label
var status_label: Label
var overlay: Control
var hud: Control
var hint: Label
var hearts: Array[TextureRect] = []
var rng := RandomNumberGenerator.new()
var pause_btn: Button
var target_icon: TextureRect
var gem_icon: TextureRect

func _ready() -> void:
	rng.seed = 9000 + GameState.current_level
	_load_level(GameState.current_level)
	_build_grid()
	_build_shadows()
	_build_guards()
	_build_player()
	_build_hud()
	player_hp = GameState.max_health()
	_build_hearts()
	get_viewport().size_changed.connect(_fit_world)
	get_viewport().size_changed.connect(_layout_hud)
	_fit_world()
	_layout_hud()
	if GameState.current_level == 1:
		hint.text = "Tap to move  •  Tap a guard to hunt  •  Stay out of the light"
		var tw := create_tween()
		tw.tween_interval(5.0)
		tw.tween_property(hint, "modulate:a", 0.0, 0.8)
	queue_redraw()

func _fit_world() -> void:
	if data.is_empty():
		return
	var safe := ScreenUtil.safe_rect(get_viewport())
	var map_size := Vector2(float(data.width), float(data.height)) * CELL
	var top := 140.0
	var avail := Rect2(safe.position + Vector2(12, top), safe.size - Vector2(24, top + 24))
	var s := minf(avail.size.x / map_size.x, avail.size.y / map_size.y)
	s = maxf(0.1, s)
	var pos := avail.position + (avail.size - map_size * s) * 0.5 - ORIGIN * s
	scale = Vector2.ONE * s
	position = pos
	queue_redraw()

func _layout_hud() -> void:
	var safe := ScreenUtil.safe_rect(get_viewport())
	if target_icon:
		target_icon.position = safe.position + Vector2(28, 24)
	if counter:
		counter.position = safe.position + Vector2(100, 20)
	if gem_icon:
		gem_icon.position = safe.position + Vector2(250, 32)
	if gem_label:
		gem_label.position = safe.position + Vector2(300, 30)
	if status_label:
		status_label.position = safe.position + Vector2(30, 96)
	if pause_btn:
		pause_btn.position = Vector2(safe.end.x - 84, safe.position.y + 24)
	var spacing := minf(30.0, safe.size.x * 0.42 / maxf(1.0, hearts.size()))
	for i in range(hearts.size()):
		hearts[i].size = Vector2(spacing - 2, spacing - 2)
		hearts[i].position = Vector2(safe.end.x - 24 - (hearts.size() - i) * spacing, safe.position.y + 96)
	if hint:
		hint.position = Vector2(safe.position.x, safe.end.y - 50)
		hint.size = Vector2(safe.size.x, 40)

func _load_level(n: int) -> void:
	var f := FileAccess.open("res://data/levels/levels.json", FileAccess.READ)
	if f == null:
		push_error("levels.json missing")
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	var levels: Array = parsed.levels
	data = levels[clampi(n - 1, 0, levels.size() - 1)]
	player_pos = _cell_center(data.spawn[0], data.spawn[1])
	for w in data.walls:
		wall_rects.append(Rect2(ORIGIN + Vector2(w[0], w[1]) * CELL, Vector2(w[2], w[3]) * CELL))
	for c in data.crates:
		crate_rects.append(Rect2(ORIGIN + Vector2(c[0], c[1]) * CELL, Vector2(c[2], c[3]) * CELL))

func _cell_center(x: int, y: int) -> Vector2:
	return ORIGIN + Vector2(x + 0.5, y + 0.5) * CELL

func _to_cell(p: Vector2) -> Vector2i:
	return Vector2i(int(floor((p.x - ORIGIN.x) / CELL)), int(floor((p.y - ORIGIN.y) / CELL)))

func _build_grid() -> void:
	grid.region = Rect2i(0, 0, int(data.width), int(data.height))
	grid.cell_size = Vector2.ONE * CELL
	grid.offset = ORIGIN + Vector2.ONE * CELL * 0.5
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.update()
	for y in range(int(data.height)):
		for x in range(int(data.width)):
			if _solid(_cell_center(x, y)):
				grid.set_point_solid(Vector2i(x, y), true)

func _solid(p: Vector2) -> bool:
	for r in wall_rects:
		if r.grow(4).has_point(p):
			return true
	for r in crate_rects:
		if r.grow(4).has_point(p):
			return true
	return false

func _build_shadows() -> void:
	# Cast short soft shadows down-right from every obstacle.
	for r in wall_rects + crate_rects:
		var s := Rect2(r.position + Vector2(6, 10), r.size + Vector2(10, 14))
		shadow_rects.append(s)

func in_shadow(p: Vector2) -> bool:
	for r in shadow_rects:
		if r.has_point(p):
			return true
	return false

func _build_player() -> void:
	player_rig = ActorRigScript.new()
	player_rig.setup(GameState.selected_assassin, "player")
	player_rig.set_knife(GameState.selected_knife)
	player_rig.scale = Vector2.ONE * 0.78
	player_rig.position = player_pos
	player_rig.rotation = player_face + PI / 2
	add_child(player_rig)

func _build_guards() -> void:
	for g in data.guards:
		var route := PackedVector2Array()
		for c in g.route:
			route.append(_cell_center(c[0], c[1]))
		var kind := "elite" if bool(g.get("elite", false)) else "guard"
		var rig := ActorRigScript.new()
		rig.setup(kind, "guard")
		rig.scale = Vector2.ONE * (0.82 if kind == "elite" else 0.76)
		rig.position = _cell_center(g.x, g.y)
		rig.rotation = deg_to_rad(float(g.face)) + PI / 2
		add_child(rig)
		guards.append({
			"pos": rig.position, "face": deg_to_rad(float(g.face)),
			"route": route, "ri": 0, "wait": rng.randf_range(0.0, 1.2),
			"hp": 2 if kind == "elite" else 1, "elite": kind == "elite",
			"state": GState.PATROL, "alert": 0.0, "shoot": 0.0, "burst": 0,
			"alive": true, "path": PackedVector2Array(), "pi": 0,
			"last_seen": Vector2.ZERO, "search_t": 0.0, "rig": rig,
			"speed": 48.0 if kind == "elite" else 58.0,
			"vision": 220.0 if kind == "elite" else 250.0,
		})
	total = guards.size()

func _build_hud() -> void:
	var cl := CanvasLayer.new()
	add_child(cl)
	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(hud)
	var icon := TextureRect.new()
	target_icon = icon
	icon.texture = TARGET_TEX
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.position = Vector2(28, 24)
	icon.size = Vector2(64, 64)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(icon)
	counter = _label(52, 10)
	counter.position = Vector2(100, 20)
	hud.add_child(counter)
	_update_counter()
	var gi := TextureRect.new()
	gem_icon = gi
	gi.texture = GEM_TEX
	gi.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	gi.position = Vector2(250, 32)
	gi.size = Vector2(44, 44)
	gi.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(gi)
	gem_label = _label(36, 6)
	gem_label.position = Vector2(300, 30)
	gem_label.text = "0"
	hud.add_child(gem_label)
	status_label = _label(24, 4)
	status_label.position = Vector2(30, 96)
	status_label.add_theme_color_override("font_color", Color("7CFC7C"))
	status_label.text = "HIDDEN"
	hud.add_child(status_label)
	var pause := Button.new()
	pause_btn = pause
	pause.text = "II"
	pause.position = Vector2(636, 24)
	pause.size = Vector2(60, 60)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.11, 0.16, 0.8)
	sb.set_corner_radius_all(14)
	pause.add_theme_stylebox_override("normal", sb)
	pause.add_theme_font_size_override("font_size", 28)
	pause.pressed.connect(_pause)
	hud.add_child(pause)
	hint = _label(22, 4)
	hint.position = Vector2(0, 1230)
	hint.size = Vector2(720, 40)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(hint)

func _build_hearts() -> void:
	for i in range(int(ceil(GameState.max_health()))):
		var h := TextureRect.new()
		h.texture = HEART_TEX
		h.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		h.position = Vector2(430 + i * 32, 96)
		h.size = Vector2(30, 30)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hud.add_child(h)
		hearts.append(h)

func _update_hearts() -> void:
	for i in range(hearts.size()):
		hearts[i].modulate = Color.WHITE if i < player_hp else Color(1, 1, 1, 0.18)

func _label(size: int, outline: int) -> Label:
	var l := Label.new()
	var fv := FontVariation.new()
	fv.base_font = FONT
	fv.variation_embolden = 0.7
	l.add_theme_font_override("font", fv)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_constant_override("outline_size", outline)
	l.add_theme_color_override("font_outline_color", Color("101218"))
	l.add_theme_color_override("font_color", Color.WHITE)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _update_counter() -> void:
	counter.text = "%d/%d" % [kills, total]

func _physics_process(delta: float) -> void:
	if finished or overlay != null:
		return
	elapsed += delta
	invuln = maxf(0, invuln - delta)
	attack_cd = maxf(0, attack_cd - delta)
	repath = maxf(0, repath - delta)
	_update_hunt()
	_move_player(delta)
	_auto_attack()
	_update_guards(delta)
	_update_bullets(delta)
	_update_gems(delta)
	_update_effects(delta)
	_update_stealth_hud()
	if kills >= total and not finished:
		_win()
	queue_redraw()

func _update_hunt() -> void:
	if hunt_target < 0 or hunt_target >= guards.size():
		return
	var g: Dictionary = guards[hunt_target]
	if not g.alive:
		hunt_target = -1
		return
	if repath <= 0:
		repath = 0.25
		_path_to(g.pos)

func _move_player(delta: float) -> void:
	var speed: float = GameState.player_speed()
	var budget := speed * delta
	var moved := false
	while player_path.size() > 0 and budget > 0:
		var target: Vector2 = player_path[0]
		var d := player_pos.distance_to(target)
		if d <= budget:
			player_pos = target
			player_path.remove_at(0)
			budget -= d
		else:
			var dir: Vector2 = (target - player_pos) / d
			player_pos += dir * budget
			player_face = dir.angle()
			budget = 0
		moved = true
	player_rig.position = player_pos
	player_rig.rotation = player_face + PI / 2
	player_rig.set_moving(moved)
	if invuln > 0 and int(invuln * 12) % 2 == 0:
		player_rig.modulate = Color(1, 0.5, 0.5)
	else:
		player_rig.modulate = Color.WHITE

func _path_to(target: Vector2) -> void:
	var from := _to_cell(player_pos)
	var to := _to_cell(target)
	to.x = clampi(to.x, 0, int(data.width) - 1)
	to.y = clampi(to.y, 0, int(data.height) - 1)
	if grid.is_in_boundsv(to) and not grid.is_point_solid(to):
		player_path = grid.get_point_path(from, to)

func _auto_attack() -> void:
	if attack_cd > 0:
		return
	var best := -1
	var best_d := GameState.attack_range()
	for i in range(guards.size()):
		var g: Dictionary = guards[i]
		if not g.alive:
			continue
		var d: float = player_pos.distance_to(g.pos)
		if d < best_d and _los(player_pos, g.pos):
			best_d = d
			best = i
	if best < 0:
		return
	var g: Dictionary = guards[best]
	attack_cd = GameState.attack_cooldown()
	player_face = (g.pos - player_pos).angle()
	player_rig.rotation = player_face + PI / 2
	player_rig.play_anim("attack", true)
	effects.append({"pos": g.pos, "t": 0.22, "max": 0.22, "kind": "slash", "angle": player_face})
	Sfx.play("blade")
	GameState.vibrate(18)
	g.hp -= GameState.player_damage()
	if g.hp <= 0:
		_kill_guard(best)
	else:
		g.alert = 1.0
		g.state = GState.ALERT
		g.last_seen = player_pos
		g.rig.play_anim("hurt", true)

func _kill_guard(index: int) -> void:
	var g: Dictionary = guards[index]
	g.alive = false
	g.state = GState.DEAD
	g.rig.die()
	kills += 1
	_update_counter()
	effects.append({"pos": g.pos, "t": 0.4, "max": 0.4, "kind": "poof"})
	var drop := 2 if g.elite else 1
	for i in range(drop):
		gems.append({"pos": g.pos + Vector2(rng.randf_range(-10, 10), rng.randf_range(-10, 10)),
			"vel": Vector2(rng.randf_range(-60, 60), rng.randf_range(-60, 60)), "t": 0.0})
	# Nearby guards hear the takedown unless deep in shadow.
	var noise := 70.0 if in_shadow(player_pos) else 130.0
	for other in guards:
		if other.alive and other.pos.distance_to(g.pos) < noise and other.state == GState.PATROL:
			_investigate(other, g.pos)
	if hunt_target == index:
		hunt_target = -1

func _investigate(g: Dictionary, p: Vector2) -> void:
	g.state = GState.INVESTIGATE
	g.last_seen = p
	g.search_t = 3.0
	g.path.clear()

func _update_guards(delta: float) -> void:
	for g in guards:
		if not g.alive:
			continue
		var sees := _can_see(g.pos, g.face, player_pos, g.vision)
		if sees:
			var rate := 2.6
			if in_shadow(player_pos):
				rate *= 0.45
			if player_pos.distance_to(g.pos) < 70:
				rate *= 2.0
			g.alert = minf(1.0, g.alert + delta * rate)
			g.last_seen = player_pos
			if g.alert >= 1.0:
				if g.state != GState.ALERT:
					Sfx.play("alert")
					was_alerted = true
				g.state = GState.ALERT
		else:
			g.alert = maxf(0, g.alert - delta * 0.7)
		match g.state:
			GState.PATROL:
				_patrol(g, delta)
			GState.INVESTIGATE:
				_seek(g, g.last_seen, delta, g.speed * 1.25)
				if g.pos.distance_to(g.last_seen) < 18:
					g.state = GState.SEARCH
					g.search_t = 2.5
			GState.ALERT:
				g.face = lerp_angle(g.face, (player_pos - g.pos).angle(), delta * 10)
				if sees:
					g.shoot -= delta
					if g.shoot <= 0:
						if g.burst <= 0:
							g.burst = 3 if g.elite else 2
						_fire(g)
						g.burst -= 1
						g.shoot = 0.14 if g.burst > 0 else (0.9 if g.elite else 1.15)
				else:
					_seek(g, g.last_seen, delta, g.speed * 1.5)
					if g.pos.distance_to(g.last_seen) < 18:
						g.state = GState.SEARCH
						g.search_t = 3.0
			GState.SEARCH:
				g.search_t -= delta
				g.face += delta * 1.6
				if g.search_t <= 0:
					g.state = GState.PATROL
					g.alert = 0.0
					g.path.clear()
		g.rig.position = g.pos
		g.rig.rotation = g.face + PI / 2
		g.rig.set_moving(g.state in [GState.PATROL, GState.INVESTIGATE, GState.ALERT] and g.path.size() > 0)

func _fire(g: Dictionary) -> void:
	var dir: Vector2 = Vector2.from_angle(g.face)
	bullets.append({"pos": g.pos + dir * 24, "vel": dir * 420.0, "life": 1.6})
	g.rig.play_anim("shoot", true)
	effects.append({"pos": g.pos + dir * 28, "t": 0.12, "max": 0.12, "kind": "muzzle"})
	Sfx.play("shot")
	# Gunfire is loud: nearby guards converge on the shooter's target.
	for other in guards:
		if other != g and other.alive and other.pos.distance_to(g.pos) < 320 and other.state == GState.PATROL:
			_investigate(other, player_pos)

func _patrol(g: Dictionary, delta: float) -> void:
	if g.route.size() < 2:
		g.face += delta * 0.45
		return
	if g.wait > 0:
		g.wait -= delta
		g.rig.set_moving(false)
		return
	_seek(g, g.route[g.ri], delta, g.speed)
	if g.pos.distance_to(g.route[g.ri]) < 10:
		g.ri = (g.ri + 1) % g.route.size()
		g.wait = rng.randf_range(0.6, 1.5)
		g.path.clear()

func _seek(g: Dictionary, target: Vector2, delta: float, speed: float) -> void:
	if g.path.size() == 0:
		var from := _to_cell(g.pos)
		var to := _to_cell(target)
		if grid.is_in_boundsv(from) and grid.is_in_boundsv(to) and not grid.is_point_solid(to):
			g.path = grid.get_point_path(from, to)
			g.pi = 0
	var budget := speed * delta
	while g.pi < g.path.size() and budget > 0:
		var t: Vector2 = g.path[g.pi]
		var d: float = g.pos.distance_to(t)
		if d <= budget:
			g.pos = t
			g.pi += 1
			budget -= d
		else:
			var dir: Vector2 = (t - g.pos) / d
			g.pos += dir * budget
			g.face = lerp_angle(g.face, dir.angle(), delta * 8)
			budget = 0
	if g.pi >= g.path.size():
		g.path.clear()

func _can_see(from: Vector2, face: float, target: Vector2, vision: float = 250.0) -> bool:
	var d := from.distance_to(target)
	if in_shadow(target):
		vision *= 0.6
	if d > vision:
		return false
	var ang := (target - from).angle()
	if absf(angle_difference(face, ang)) > deg_to_rad(32):
		return false
	return _los(from, target)

func _los(a: Vector2, b: Vector2) -> bool:
	var d := a.distance_to(b)
	var steps := int(d / 6.0) + 1
	for i in range(1, steps):
		var p := a.lerp(b, float(i) / steps)
		if _solid(p):
			return false
	return true

func _update_bullets(delta: float) -> void:
	for i in range(bullets.size() - 1, -1, -1):
		var b: Dictionary = bullets[i]
		var old: Vector2 = b.pos
		b.pos += b.vel * delta
		b.life -= delta
		var hit := false
		if _solid(b.pos) or b.life <= 0:
			hit = true
			effects.append({"pos": b.pos, "t": 0.15, "max": 0.15, "kind": "spark"})
		elif invuln <= 0 and _segment_circle(old, b.pos, player_pos, 14):
			player_hp -= 1.0
			damage_taken += 1
			invuln = 0.9
			_update_hearts()
			player_rig.play_anim("hurt", true)
			effects.append({"pos": player_pos, "t": 0.3, "max": 0.3, "kind": "hurt"})
			Sfx.play("hurt")
			GameState.vibrate(60)
			hit = true
			if player_hp <= 0:
				player_rig.die()
				_lose()
		if hit:
			bullets.remove_at(i)

func _segment_circle(a: Vector2, b: Vector2, c: Vector2, r: float) -> bool:
	var ab := b - a
	var t := clampf((c - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
	return (a + ab * t).distance_to(c) <= r

func _update_gems(delta: float) -> void:
	for i in range(gems.size() - 1, -1, -1):
		var gm: Dictionary = gems[i]
		gm.t += delta
		gm.pos += gm.vel * delta
		gm.vel = gm.vel.lerp(Vector2.ZERO, delta * 6)
		var d: float = gm.pos.distance_to(player_pos)
		if d < 90:
			gm.pos = gm.pos.lerp(player_pos, delta * 10)
		if d < 22:
			gems_collected += 1
			gem_label.text = str(gems_collected)
			Sfx.play("coin")
			gems.remove_at(i)

func _update_effects(delta: float) -> void:
	for i in range(effects.size() - 1, -1, -1):
		effects[i].t -= delta
		if effects[i].t <= 0:
			effects.remove_at(i)

func _update_stealth_hud() -> void:
	var seen := false
	for g in guards:
		if g.alive and g.state == GState.ALERT:
			seen = true
	if seen:
		status_label.text = "SPOTTED!"
		status_label.add_theme_color_override("font_color", Color("ff5a6e"))
	elif in_shadow(player_pos):
		status_label.text = "IN SHADOW"
		status_label.add_theme_color_override("font_color", Color("7CFC7C"))
	else:
		status_label.text = "EXPOSED"
		status_label.add_theme_color_override("font_color", Color("ffd23f"))

func _unhandled_input(event: InputEvent) -> void:
	if finished or overlay != null:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var target := make_input_local(event).position as Vector2
		# Tap a guard -> hunt it.
		var picked := -1
		var pd := 40.0
		for i in range(guards.size()):
			if guards[i].alive and guards[i].pos.distance_to(target) < pd:
				pd = guards[i].pos.distance_to(target)
				picked = i
		if picked >= 0:
			hunt_target = picked
			repath = 0.0
			effects.append({"pos": guards[picked].pos, "t": 0.4, "max": 0.4, "kind": "mark"})
		else:
			hunt_target = -1
			_path_to(target)
	if event.is_action_pressed("ui_cancel"):
		_pause()

func _draw() -> void:
	# Tiled floor, clipped to the map rectangle.
	var map_rect := Rect2(ORIGIN, Vector2(data.width, data.height) * CELL)
	var tw := 64.0
	var th := 64.0
	var x := ORIGIN.x
	while x < map_rect.end.x:
		var y := ORIGIN.y
		while y < map_rect.end.y:
			var tile := Rect2(x, y, tw, th)
			var vis := tile.intersection(map_rect)
			if vis.size.x > 0 and vis.size.y > 0:
				var region := Rect2((vis.position - tile.position) * (FLOOR.get_size() / Vector2(tw, th)), vis.size * (FLOOR.get_size() / Vector2(tw, th)))
				draw_texture_rect_region(FLOOR, vis, region)
			y += th
		x += tw
	# Shadows.
	for r in shadow_rects:
		var sr := r.intersection(map_rect)
		if sr.size.x > 0 and sr.size.y > 0:
			draw_rect(sr, Color(0.05, 0.07, 0.12, 0.18))
	# Vision cones.
	for g in guards:
		if g.alive:
			_draw_cone(g)
	# Walls.
	for r in wall_rects:
		_draw_wall(r)
	# Crates.
	for i in range(crate_rects.size()):
		var c: Array = data.crates[i]
		var tex: Texture2D = CRATE_TEX.get(c[4], CRATE_TEX.gray)
		var r: Rect2 = crate_rects[i]
		draw_texture_rect(tex, r, false)
	# Gems.
	for gm in gems:
		var bob := sin(gm.t * 6) * 3
		draw_texture_rect(GEM_TEX, Rect2(gm.pos + Vector2(-12, -12 + bob), Vector2(24, 24)), false)
	# Path dots.
	if player_path.size() > 1:
		for i in range(1, player_path.size()):
			draw_circle(player_path[i], 3, Color(1, 1, 1, 0.25))
	# Bullets.
	for b in bullets:
		draw_line(b.pos - b.vel.normalized() * 14, b.pos, Color(1, 0.9, 0.5, 0.9), 3)
		draw_circle(b.pos, 3, Color("ffd23f"))
	# Effects.
	for e in effects:
		var k: float = e.t / e.max
		if e.kind == "slash":
			draw_set_transform(e.pos, e.angle + PI / 2, Vector2.ONE * (1.2 - k * 0.3))
			draw_texture(SLASH_TEX, -SLASH_TEX.get_size() / 2, Color(1, 1, 1, k))
			draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
		elif e.kind == "poof":
			draw_circle(e.pos, 30 * (1 - k), Color(0.9, 0.9, 0.9, k * 0.5))
		elif e.kind == "spark" or e.kind == "muzzle":
			draw_set_transform(e.pos, 0, Vector2.ONE * (0.6 + k))
			draw_texture(SPARK_TEX, -SPARK_TEX.get_size() / 2, Color(1, 1, 1, k))
			draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
		elif e.kind == "hurt":
			draw_circle(e.pos, 26, Color(1, 0.2, 0.2, k * 0.5))
		elif e.kind == "mark":
			draw_arc(e.pos, 30, 0, TAU, 32, Color(1, 0.3, 0.3, k), 3)
	# Guard alert rings / state pips.
	for g in guards:
		if not g.alive:
			continue
		if g.alert > 0.05 and g.state != GState.ALERT:
			draw_arc(g.pos, 24, -PI / 2, -PI / 2 + TAU * g.alert, 24, Color(1, 0.8, 0.2), 3)
		elif g.state == GState.ALERT:
			draw_arc(g.pos, 26, 0, TAU, 24, Color(1, 0.25, 0.25), 3)
		elif g.state in [GState.INVESTIGATE, GState.SEARCH]:
			draw_circle(g.pos + Vector2(0, -34), 4, Color("ffd23f"))

func _draw_wall(r: Rect2) -> void:
	draw_rect(Rect2(r.position + Vector2(0, 4), r.size), Color(0, 0, 0, 0.35))
	draw_rect(r, Color("3a2417"))
	draw_rect(r.grow(-3), Color("8a5a33"))
	draw_rect(Rect2(r.position + Vector2(3, 3), Vector2(r.size.x - 6, 4)), Color("a8703f"))
	var n := int(max(r.size.x, r.size.y) / CELL)
	for i in range(n):
		var p := r.position + Vector2(8, 8)
		if r.size.x > r.size.y:
			p = r.position + Vector2(i * CELL + 16, 8)
		else:
			p = r.position + Vector2(8, i * CELL + 16)
		draw_circle(p, 2, Color("5c3a20"))
	var hz := Color("ff7a1a")
	if r.size.x > r.size.y:
		for e in [r.position.x + 5, r.end.x - 5]:
			for k in range(3):
				draw_circle(Vector2(e, r.position.y + 8 + k * 8), 2.5, hz)
	else:
		for e in [r.position.y + 5, r.end.y - 5]:
			for k in range(3):
				draw_circle(Vector2(r.position.x + 8 + k * 8, e), 2.5, hz)

func _draw_cone(g: Dictionary) -> void:
	var pts := PackedVector2Array([g.pos])
	var rays := 24
	var vision: float = g.vision
	for i in range(rays + 1):
		var a: float = g.face - deg_to_rad(30) + deg_to_rad(60) * i / rays
		var dir := Vector2.from_angle(a)
		var dist := vision
		var steps := 32
		for s in range(1, steps + 1):
			var p: Vector2 = g.pos + dir * (vision * s / steps)
			if _solid(p):
				dist = vision * (s - 1) / steps
				break
		pts.append(g.pos + dir * dist)
	var col := Color(1, 0.95, 0.75, 0.22)
	if g.state == GState.ALERT:
		col = Color(1, 0.35, 0.3, 0.3)
	elif g.state in [GState.INVESTIGATE, GState.SEARCH]:
		col = Color(1, 0.8, 0.3, 0.25)
	draw_polygon(pts, PackedColorArray([col]))

# ---------------- End states ----------------
func _win() -> void:
	finished = true
	var level_no := GameState.current_level
	player_rig.set_moving(false)
	var stars := 3
	if was_alerted:
		stars = 2
	if damage_taken > 0:
		stars = 1
	GameState.add_gems(gems_collected)
	GameState.complete_level(kills, damage_taken == 0, stars)
	Sfx.play("win")
	_end_panel("LEVEL COMPLETE!", Color("4caf20"), "★".repeat(stars) + "  +%d cash  +%d gems" % [50 + level_no * 5, gems_collected], [
		["Next Level", func(): GameState.start_level(GameState.current_level)],
		["Home", func(): get_tree().change_scene_to_file("res://scenes/home/home.tscn")],
	])

func _lose() -> void:
	finished = true
	Sfx.play("lose")
	get_tree().create_timer(0.7).timeout.connect(func():
		_end_panel("YOU WERE SPOTTED", Color("e63946"), "Use cover and shadows. Strike from behind.", [
			["Retry", func(): get_tree().reload_current_scene()],
			["Home", func(): get_tree().change_scene_to_file("res://scenes/home/home.tscn")],
		]))

func _pause() -> void:
	if overlay != null or finished:
		return
	_end_panel("PAUSED", Color("ffc93c"), "", [
		["Resume", func(): overlay.queue_free(); overlay = null],
		["Retry", func(): get_tree().reload_current_scene()],
		["Home", func(): get_tree().change_scene_to_file("res://scenes/home/home.tscn")],
	])

func _end_panel(title: String, color: Color, sub: String, buttons: Array) -> void:
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.add_child(overlay)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("2b2f45")
	sb.border_color = Color("14161f")
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(20)
	sb.content_margin_left = 30
	sb.content_margin_right = 30
	sb.content_margin_top = 26
	sb.content_margin_bottom = 26
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)
	var t := _label(40, 6)
	t.text = title
	t.add_theme_color_override("font_color", color)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(t)
	if sub != "":
		var s := _label(26, 0)
		s.text = sub
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(s)
	for b in buttons:
		var btn := Button.new()
		btn.text = b[0]
		btn.custom_minimum_size = Vector2(300, 60)
		var fv := FontVariation.new()
		fv.base_font = FONT
		fv.variation_embolden = 0.7
		btn.add_theme_font_override("font", fv)
		btn.add_theme_font_size_override("font_size", 26)
		var bs := StyleBoxFlat.new()
		bs.bg_color = color
		bs.set_corner_radius_all(14)
		bs.border_color = Color("14161f")
		bs.set_border_width_all(3)
		btn.add_theme_stylebox_override("normal", bs)
		btn.add_theme_color_override("font_color", Color("14161f"))
		btn.pressed.connect(b[1])
		box.add_child(btn)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_pause()
