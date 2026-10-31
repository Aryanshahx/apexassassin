extends SceneTree
## Faster bullets, alerted movement, real saved wallets and rare diamond carriers.
var checks := 0
var failures := 0
func _init() -> void:
	call_deferred("_run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ", message)
func _lane(lv: Node2D) -> Vector2:
	for y in range(2, int(lv.data.height)-2):
		for x in range(2, int(lv.data.width)-8):
			var p: Vector2 = lv._cell_center(x,y)
			var end: Vector2 = p + Vector2(200,0)
			if not lv._guard_solid(p) and lv._guard_line_clear(p, end) and lv._los(p,end):
				return p
	return Vector2.ZERO
func _run() -> void:
	var gs = root.get_node("GameState")
	gs.sound_enabled = false
	gs.cash = 500
	gs.gems = 42
	gs.upgrades = {"speed": 0, "health": 0, "damage": 0}
	gs.start_level(1)
	await process_frame
	await process_frame
	var lv = current_scene
	lv.set_physics_process(false)
	check(lv.money_label.text == "500" and lv.gem_label.text == "42", "top HUD shows saved total money and diamonds")
	check(not lv.money_caption.visible and not lv.gem_caption.visible and not lv.money_panel.visible and not lv.gem_panel.visible, "currency backgrounds and words are hidden during gameplay")
	for safe in [Rect2(0,0,720,1280), Rect2(12,20,640,1100), Rect2(20,40,600,900)]:
		lv._layout_hud_for_rect(safe)
		check(not Rect2(lv.money_label.position, lv.money_label.size).intersects(Rect2(lv.gem_icon.position, lv.gem_icon.size)) and not Rect2(lv.gem_label.position, lv.gem_label.size).intersects(Rect2(lv.pause_btn.position, lv.pause_btn.size)), "wallet totals do not overlap at safe width %s" % safe.size.x)
	lv._layout_hud()
	gs.cash = 1234567890
	gs.gems = 987654321
	lv._refresh_wallet()
	var money_font: Font = lv.money_label.get_theme_font("font")
	var money_font_size: int = lv.money_label.get_theme_font_size("font_size")
	check(lv.money_label.text == "1234567890" and money_font.get_string_size(lv.money_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, money_font_size).x <= lv.money_label.size.x, "large balances stay exact and fit instead of being clipped")
	gs.cash = 500
	gs.gems = 42
	lv._refresh_wallet()
	var original: Array = lv.guards.duplicate()
	var g: Dictionary = original[0]
	var h: Dictionary = original[1]
	lv.guards.clear()
	lv.guards.append(g)
	var start := _lane(lv)
	check(start != Vector2.ZERO, "alert test has a clear 200-unit lane")
	g.pos = start
	g.rig.position = start
	g.face = 0.0
	g.state = lv.GState.PATROL
	g.sees_player = false
	g.speed = 58.0
	g.shoot = 0.0
	g.path.clear()
	lv.player_pos = start + Vector2(200,0)
	lv.bullets.clear()
	lv._update_guards(0.1)
	check(g.state == lv.GState.ALERT, "flashlight contact enters alert immediately")
	check(lv.bullets.size() == 1 and absf(lv.bullets[0].vel.length() - 660.0) < 0.01, "first-contact bullet travels at 660 units per second")
	check(g.pos.distance_to(start) > g.speed * 0.1 * 1.5, "alert guard visibly pursues faster than patrol while firing")
	check(g.rig.guard_aim_target > 0.0, "moving alert guard keeps gun raised")
	check(lv.INVESTIGATE_SPEED_MULTIPLIER > 1.0 and lv.ALERT_SPEED_MULTIPLIER > lv.INVESTIGATE_SPEED_MULTIPLIER, "investigation and pursuit both accelerate")
	# Even faster projectiles must not tunnel through cover at low frame rates.
	lv.bullets.clear()
	lv.blocking_rects.append(Rect2(start + Vector2(90,-32), Vector2(10,64)))
	lv.invuln = 0.0
	var health_before: float = lv.player_hp
	lv._fire(g)
	lv._update_bullets(0.5)
	check(is_equal_approx(lv.player_hp, health_before) and lv.bullets.is_empty(), "faster bullets still stop at cover even after a long frame")
	lv.blocking_rects.remove_at(lv.blocking_rects.size() - 1)
	lv.guards.append(h)
	g.alive = true
	g.elite = false
	g.diamond_carrier = false
	h.alive = true
	h.elite = true
	h.diamond_carrier = true
	lv._kill_guard(0)
	check(gs.cash == 510 and gs.gems == 42, "ordinary enemy awards money but no diamond")
	check(lv.money_label.text == "510" and lv.gem_label.text == "42", "wallet totals refresh immediately")
	var diamonds_before: int = lv.gems_collected
	lv._kill_guard(1, true)
	check(gs.cash == 535 and gs.gems == 43, "silent heavy carrier awards bonus money plus one diamond")
	check(lv.money_label.text == "535" and lv.gem_label.text == "43", "HUD shows both updated totals")
	check(lv.gems_collected == diamonds_before + 1 and lv.money_collected == 35, "level collection totals reflect both kills")
	var visual_money := 0
	var visual_diamond := 0
	for e in lv.effects:
		if e.kind == "moneytext": visual_money += 1
		if e.kind == "diamondtext": visual_diamond += 1
	check(visual_money == 2 and visual_diamond == 1, "every kill has money feedback, only carrier has diamond feedback")
	lv._kill_guard(1, true)
	check(gs.cash == 535 and gs.gems == 43, "repeated kill call cannot pay twice")
	gs.cash = 0
	gs.gems = 0
	gs.load_game()
	check(gs.cash == 535 and gs.gems == 43, "loot and historical gems save key persist immediately")
	lv.total = 2
	lv.finished = false
	lv.hit_stop = 0.0
	lv.bullets.clear()
	lv.player_path.clear()
	lv._physics_process(1.0 / 60.0)
	check(not lv.finished and lv.victory_delay > 0.0, "last-kill loot remains visible before the victory panel")
	for frame in range(80):
		lv._physics_process(1.0 / 60.0)
	check(lv.finished and gs.gems == 43 and gs.cash == 590, "automatic victory adds the level reward without double-crediting diamonds")
	check(lv.money_label.text == "590" and lv.gem_label.text == "43", "top totals include the level-clear money")
	lv._win()
	check(gs.gems == 43 and gs.cash == 590, "finished level cannot pay twice")
	var carrier_levels := 0
	var valid := true
	for n in range(1,101):
		var data: Dictionary = gs.level_data(n)
		var index: int = lv._diamond_carrier_for_level(n, data.guards.size())
		if index >= 0:
			carrier_levels += 1
			if index >= data.guards.size(): valid = false
	check(valid and carrier_levels >= 30 and carrier_levels <= 80, "diamonds are rare: zero or one carrier in a subset of levels")
	print("DIAMOND CARRIER LEVELS ", carrier_levels)
	print("LOOT + SPEED %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
