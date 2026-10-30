extends Control

const FONT := preload("res://assets/fonts/Baloo2.ttf")
const W := 720.0
const H := 1280.0

var canvas: Control
var cash_label: Label
var gems_label: Label
var card_art: TextureRect
var overlay: Control

func _ready() -> void:
	var bg := TextureRect.new()
	bg.texture = preload("res://assets/home/home_bg.jpg")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	canvas = Control.new()
	canvas.custom_minimum_size = Vector2(W, H)
	add_child(canvas)
	get_viewport().size_changed.connect(_fit)
	_fit()

	_build_resources()
	_build_side_icons()
	_build_action_cards()
	_build_missions()
	_build_start()

func _fit() -> void:
	var vs := get_viewport_rect().size
	var s := minf(vs.x / W, vs.y / H)
	canvas.scale = Vector2(s, s)
	canvas.position = (vs - Vector2(W, H) * s) * 0.5

func _font(size: int, outline: int = 0) -> Label:
	var l := Label.new()
	var fv := FontVariation.new()
	fv.base_font = FONT
	fv.variation_embolden = 0.6
	l.add_theme_font_override("font", fv)
	l.add_theme_font_size_override("font_size", size)
	if outline > 0:
		l.add_theme_constant_override("outline_size", outline)
		l.add_theme_color_override("font_outline_color", Color("1d1f2a"))
	return l

func _box(bg: Color, border: Color, radius: int, bw: int = 3) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	return s

func _icon_button(tex: Texture2D, pos: Vector2, size: float, cb: Callable) -> TextureButton:
	var b := TextureButton.new()
	b.texture_normal = tex
	b.ignore_texture_size = true
	b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	b.position = pos
	b.custom_minimum_size = Vector2(size, size)
	b.size = Vector2(size, size)
	b.pressed.connect(cb)
	canvas.add_child(b)
	return b

func _badge(parent_pos: Vector2) -> void:
	var l := _font(20, 3)
	l.text = "!"
	l.add_theme_color_override("font_color", Color.WHITE)
	l.position = parent_pos
	l.size = Vector2(26, 26)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var p := Panel.new()
	p.add_theme_stylebox_override("panel", _box(Color("e63946"), Color("ffffff"), 13, 2))
	p.position = parent_pos
	p.size = Vector2(26, 26)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(p)
	l.position = Vector2(0, -3)
	l.size = Vector2(26, 26)
	p.add_child(l)

# ---------------- Resources ----------------
func _build_resources() -> void:
	var gem_pill := _resource_pill(Vector2(30, 88), preload("res://assets/ui/gem.png"), str(GameState.gems), Color("ff5a6e"), func(): _popup("Gems", "Guards drop gems. Collect them to unlock Nova."), 190)
	gems_label = gem_pill.get_meta("value_label")
	var cash_pill := _resource_pill(Vector2(252, 88), preload("res://assets/ui/cash.png"), str(GameState.cash), Color("7CFC7C"), func(): _popup("Cash", "Earn cash by completing levels and missions."), 196)
	cash_label = cash_pill.get_meta("value_label")
	_icon_button(preload("res://assets/ui/gear.png"), Vector2(618, 80), 76, _open_settings)
	_badge(Vector2(672, 74))

func _resource_pill(pos: Vector2, icon: Texture2D, value: String, _c: Color, cb: Callable, width: float = 212) -> Panel:
	var p := Panel.new()
	p.position = pos
	p.size = Vector2(width, 58)
	p.add_theme_stylebox_override("panel", _box(Color(0.04, 0.05, 0.08, 0.92), Color("000000"), 29, 2))
	canvas.add_child(p)
	var ic := TextureRect.new()
	ic.texture = icon
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.position = Vector2(-14, -8)
	ic.size = Vector2(66, 66)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(ic)
	var v := _font(28, 0)
	v.text = value
	v.add_theme_color_override("font_color", Color.WHITE)
	v.position = Vector2(58, 8)
	v.size = Vector2(width - 116, 42)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(v)
	p.set_meta("value_label", v)
	var plus := TextureButton.new()
	plus.texture_normal = preload("res://assets/ui/plus.png")
	plus.ignore_texture_size = true
	plus.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	plus.position = Vector2(width - 52, 5)
	plus.size = Vector2(48, 48)
	plus.pressed.connect(cb)
	p.add_child(plus)
	return p

# ---------------- Side icons ----------------
func _build_side_icons() -> void:
	_icon_button(preload("res://assets/ui/vip.png"), Vector2(12, 168), 92, func(): _popup("VIP", "VIP is not enabled in this offline build."))
	_icon_button(preload("res://assets/ui/noads.png"), Vector2(18, 272), 82, func(): _popup("No Ads", "This build has no ads. Enjoy!"))
	_icon_button(preload("res://assets/ui/offer.png"), Vector2(22, 366), 82, func(): _popup("Offers", "Special offers are coming later."))
	_badge(Vector2(78, 360))
	_icon_button(preload("res://assets/ui/wheel.png"), Vector2(614, 168), 96, _spin_wheel)
	_badge(Vector2(680, 162))
	_icon_button(preload("res://assets/ui/shop.png"), Vector2(618, 280), 92, func(): _popup("Shop", "The shop is coming in a later update."))

func _spin_wheel() -> void:
	var prize := GameState.spin_wheel()
	_refresh_values()
	if prize > 0:
		Sfx.play("upgrade")
		_popup("Lucky Wheel", "You won %d cash!\nCome back tomorrow for another spin." % prize)
	else:
		_popup("Lucky Wheel", "Already spun today. Come back tomorrow!")

# ---------------- Action cards ----------------
func _build_action_cards() -> void:
	var change := Button.new()
	change.position = Vector2(36, 430)
	change.size = Vector2(468, 150)
	change.add_theme_stylebox_override("normal", _box(Color("9a45ee"), Color("2a0a4a"), 20, 4))
	change.add_theme_stylebox_override("hover", _box(Color("a855f7"), Color("2a0a4a"), 20, 4))
	change.add_theme_stylebox_override("pressed", _box(Color("7e35cf"), Color("2a0a4a"), 20, 4))
	change.pressed.connect(_open_assassins)
	canvas.add_child(change)
	var ct := _font(36, 5)
	ct.text = "Change\nAssassin"
	ct.add_theme_color_override("font_color", Color.WHITE)
	ct.position = Vector2(56, 30)
	ct.mouse_filter = Control.MOUSE_FILTER_IGNORE
	change.add_child(ct)
	var art := TextureRect.new()
	card_art = art
	art.texture = load("res://assets/home/card_%s.png" % GameState.selected_assassin)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.position = Vector2(238, -18)
	art.size = Vector2(230, 180)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	change.add_child(art)

	var up := Button.new()
	up.position = Vector2(520, 430)
	up.size = Vector2(164, 150)
	up.add_theme_stylebox_override("normal", _box(Color("9a45ee"), Color("2a0a4a"), 20, 4))
	up.add_theme_stylebox_override("hover", _box(Color("a855f7"), Color("2a0a4a"), 20, 4))
	up.add_theme_stylebox_override("pressed", _box(Color("7e35cf"), Color("2a0a4a"), 20, 4))
	up.pressed.connect(_open_upgrades)
	canvas.add_child(up)
	var ua := TextureRect.new()
	ua.texture = preload("res://assets/home/card_upgrade.png")
	ua.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ua.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ua.position = Vector2(22, -16)
	ua.size = Vector2(120, 110)
	ua.mouse_filter = Control.MOUSE_FILTER_IGNORE
	up.add_child(ua)
	var ut := _font(28, 4)
	ut.text = "Upgrade"
	ut.add_theme_color_override("font_color", Color.WHITE)
	ut.position = Vector2(0, 100)
	ut.size = Vector2(164, 40)
	ut.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ut.mouse_filter = Control.MOUSE_FILTER_IGNORE
	up.add_child(ut)

# ---------------- Missions ----------------
func _build_missions() -> void:
	_mission_card(Vector2(36, 600), "Eliminate 30 targets", "%d / 30" % mini(GameState.total_kills, 30), 150,
		GameState.total_kills >= 30, GameState.mission1_claimed, _claim_mission.bind(1))
	_mission_card(Vector2(36, 744), "Free supply drop", "Offline bonus", 200,
		true, GameState.mission2_claimed, _claim_mission.bind(2))
	_mission_card(Vector2(36, 888), "Complete a level with\nno damage taken", "%d / 1" % mini(GameState.flawless_count, 1), 200,
		GameState.flawless_count >= 1, GameState.mission3_claimed, _claim_mission.bind(3))

func _mission_card(pos: Vector2, title: String, progress: String, prize: int, complete: bool, claimed: bool, cb: Callable) -> void:
	var p := Panel.new()
	p.position = pos
	p.size = Vector2(648, 128)
	p.add_theme_stylebox_override("panel", _box(Color("6a6d85"), Color("23252e"), 16, 4))
	canvas.add_child(p)
	var inner := Panel.new()
	inner.position = Vector2(6, 6)
	inner.size = Vector2(636, 116)
	inner.add_theme_stylebox_override("panel", _box(Color(0, 0, 0, 0), Color(0.75, 0.78, 0.9, 0.35), 12, 2))
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(inner)
	var t := _font(26, 4)
	t.text = title
	t.add_theme_color_override("font_color", Color.WHITE)
	t.position = Vector2(22, 12)
	t.size = Vector2(400, 64)
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(t)
	var pr := _font(24, 4)
	pr.text = progress
	pr.add_theme_color_override("font_color", Color.WHITE)
	pr.position = Vector2(22, 88)
	pr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(pr)

	var btn := Button.new()
	btn.position = Vector2(432, 14)
	btn.size = Vector2(200, 100)
	var claimable := complete and not claimed
	if claimed:
		btn.add_theme_stylebox_override("normal", _box(Color("4a4d60"), Color("23252e"), 14, 3))
		btn.disabled = true
	elif claimable:
		btn.add_theme_stylebox_override("normal", _box(Color("4caf20"), Color("1d5a10"), 14, 3))
		btn.add_theme_stylebox_override("hover", _box(Color("5ccf3a"), Color("1d5a10"), 14, 3))
	else:
		btn.add_theme_stylebox_override("normal", _box(Color("9aa0b4"), Color("23252e"), 14, 3))
		btn.add_theme_stylebox_override("hover", _box(Color("aab0c4"), Color("23252e"), 14, 3))
	btn.pressed.connect(cb)
	p.add_child(btn)

	if claimable:
		var cl := _font(30, 4)
		cl.text = "Claim"
		cl.add_theme_color_override("font_color", Color("ffe23f"))
		cl.position = Vector2(60, 8)
		cl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(cl)
	else:
		var tg := TextureRect.new()
		tg.texture = preload("res://assets/ui/target.png")
		tg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tg.position = Vector2(12, 26)
		tg.size = Vector2(48, 48)
		tg.modulate = Color(1, 1, 1, 0.85) if not claimed else Color(0.6, 0.6, 0.6, 0.6)
		tg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(tg)
		var pz := _font(26, 4)
		pz.text = "Done" if claimed else "Prize"
		pz.add_theme_color_override("font_color", Color("3fc6ff") if not claimed else Color("8a8fa3"))
		pz.position = Vector2(66, 6)
		pz.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(pz)
	var ci := TextureRect.new()
	ci.texture = preload("res://assets/ui/cash.png")
	ci.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ci.position = Vector2(66, 52)
	ci.size = Vector2(36, 36)
	ci.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(ci)
	var amt := _font(26, 4)
	amt.text = str(prize)
	amt.add_theme_color_override("font_color", Color.WHITE)
	amt.position = Vector2(106, 50)
	amt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(amt)

func _claim_mission(index: int) -> void:
	var reward := 0
	if index == 1 and GameState.total_kills >= 30 and not GameState.mission1_claimed:
		GameState.mission1_claimed = true
		reward = 150
	elif index == 2 and not GameState.mission2_claimed:
		GameState.mission2_claimed = true
		reward = 200
	elif index == 3 and GameState.flawless_count >= 1 and not GameState.mission3_claimed:
		GameState.mission3_claimed = true
		reward = 200
	if reward > 0:
		GameState.cash += reward
		GameState.save_game()
		_toast("+%d cash claimed!" % reward)
		get_tree().reload_current_scene()
	else:
		_toast("Mission not completed yet.")

# ---------------- Start ----------------
func _build_start() -> void:
	var b := Button.new()
	b.position = Vector2(170, 1064)
	b.size = Vector2(380, 140)
	b.add_theme_stylebox_override("normal", _box(Color("ffc93c"), Color("6b4a00"), 22, 5))
	b.add_theme_stylebox_override("hover", _box(Color("ffd76a"), Color("6b4a00"), 22, 5))
	b.add_theme_stylebox_override("pressed", _box(Color("e0a800"), Color("6b4a00"), 22, 5))
	b.pressed.connect(func(): GameState.start_level(GameState.current_level))
	canvas.add_child(b)
	var t := _font(46, 6)
	t.text = "Start Game"
	t.add_theme_color_override("font_color", Color.WHITE)
	t.position = Vector2(0, 16)
	t.size = Vector2(380, 60)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(t)
	var lv := _font(28, 0)
	lv.text = "Level %d" % GameState.current_level
	lv.add_theme_color_override("font_color", Color("d2691e"))
	lv.position = Vector2(0, 84)
	lv.size = Vector2(380, 40)
	lv.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(lv)

# ---------------- Overlays ----------------
func _refresh_values() -> void:
	if cash_label:
		cash_label.text = str(GameState.cash)
	if gems_label:
		gems_label.text = str(GameState.gems)

func _open_settings() -> void:
	var box := _popup_base("Settings")
	var sound := Button.new()
	sound.text = "Sound: %s" % ("ON" if GameState.sound_enabled else "OFF")
	sound.custom_minimum_size = Vector2(300, 60)
	sound.pressed.connect(func():
		GameState.sound_enabled = not GameState.sound_enabled
		GameState.save_game()
		sound.text = "Sound: %s" % ("ON" if GameState.sound_enabled else "OFF"))
	box.add_child(sound)
	var haptics := Button.new()
	haptics.text = "Haptics: %s" % ("ON" if GameState.haptics_enabled else "OFF")
	haptics.custom_minimum_size = Vector2(300, 60)
	haptics.pressed.connect(func():
		GameState.haptics_enabled = not GameState.haptics_enabled
		GameState.save_game()
		haptics.text = "Haptics: %s" % ("ON" if GameState.haptics_enabled else "OFF"))
	box.add_child(haptics)
	var levels := Button.new()
	levels.text = "Select Level"
	levels.custom_minimum_size = Vector2(300, 60)
	levels.pressed.connect(func():
		_close_overlay()
		_open_level_select())
	box.add_child(levels)
	_add_close(box)

func _open_assassins() -> void:
	var box := _popup_base("Change Assassin")
	var preview := Control.new()
	preview.custom_minimum_size = Vector2(420, 220)
	box.add_child(preview)
	var rig := preload("res://scripts/game/actor_rig.gd").new()
	rig.setup(GameState.selected_assassin, "player")
	rig.scale = Vector2.ONE * 2.6
	rig.position = Vector2(210, 120)
	preview.add_child(rig)
	var anim_row := HBoxContainer.new()
	anim_row.add_theme_constant_override("separation", 8)
	box.add_child(anim_row)
	for a in ["idle", "run", "attack"]:
		var ab := Button.new()
		ab.text = a.capitalize()
		ab.custom_minimum_size = Vector2(128, 44)
		ab.pressed.connect(func(): rig.play_anim(a, true))
		anim_row.add_child(ab)
	for id in GameState.CHARACTERS:
		var c: Dictionary = GameState.CHARACTERS[id]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var portrait := TextureRect.new()
		portrait.texture = load("res://assets/home/card_%s.png" % id)
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.custom_minimum_size = Vector2(72, 72)
		row.add_child(portrait)
		var info := VBoxContainer.new()
		info.custom_minimum_size = Vector2(210, 0)
		var nm := _font(26, 3)
		nm.text = c.name + ("  ✓" if GameState.selected_assassin == id else "")
		nm.add_theme_color_override("font_color", Color.WHITE)
		info.add_child(nm)
		var st := _font(18, 0)
		st.text = "Speed %d   HP %d" % [int(c.speed), int(c.health)]
		st.add_theme_color_override("font_color", Color("aab0c4"))
		info.add_child(st)
		row.add_child(info)
		var b := Button.new()
		b.custom_minimum_size = Vector2(130, 56)
		if GameState.selected_assassin == id:
			b.text = "Selected"
			b.disabled = true
		elif GameState.is_unlocked(id):
			b.text = "Select"
			b.pressed.connect(func():
				GameState.select_character(id)
				Sfx.play("upgrade")
				_close_overlay()
				_open_assassins()
				_refresh_card())
		else:
			b.text = "%d gems" % int(c.cost)
			b.disabled = GameState.gems < int(c.cost)
			b.pressed.connect(func():
				if GameState.unlock_character(id):
					Sfx.play("upgrade")
					_close_overlay()
					_open_assassins()
					_refresh_values()
					_refresh_card()
					_toast("%s unlocked!" % c.name))
		row.add_child(b)
		box.add_child(row)
	var blurb := _font(20, 0)
	blurb.text = GameState.character().blurb
	blurb.add_theme_color_override("font_color", Color("aab0c4"))
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	blurb.custom_minimum_size = Vector2(420, 40)
	box.add_child(blurb)
	_add_close(box)

func _refresh_card() -> void:
	if card_art:
		card_art.texture = load("res://assets/home/card_%s.png" % GameState.selected_assassin)

func _open_upgrades() -> void:
	var box := _popup_base("Upgrade")
	var kinds := [["health", "Health (+1 heart)"], ["damage", "Damage (+1)"], ["speed", "Speed (+18)"]]
	for k in kinds:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var l := _font(24, 0)
		l.text = "%s  Lv %d" % [k[1], int(GameState.upgrades[k[0]])]
		l.custom_minimum_size = Vector2(300, 50)
		row.add_child(l)
		var b := Button.new()
		var maxed: bool = int(GameState.upgrades[k[0]]) >= 5
		b.text = "MAX" if maxed else "%d cash" % GameState.upgrade_cost(k[0])
		b.disabled = maxed or GameState.cash < GameState.upgrade_cost(k[0])
		b.custom_minimum_size = Vector2(140, 50)
		b.pressed.connect(func():
			if GameState.buy_upgrade(k[0]):
				_close_overlay()
				_open_upgrades()
				_refresh_values())
		row.add_child(b)
		box.add_child(row)
	_add_close(box)

func _open_level_select() -> void:
	var box := _popup_base("Select Level")
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(480, 420)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.add_child(grid)
	box.add_child(scroll)
	for i in range(1, GameState.TOTAL_LEVELS + 1):
		var b := Button.new()
		var st := int(GameState.best_stars.get(str(i), 0))
		b.text = str(i) + ("\n" + "★".repeat(st) if st > 0 else "")
		b.custom_minimum_size = Vector2(84, 64)
		b.disabled = i > GameState.unlocked_level
		b.pressed.connect(func(): GameState.start_level(i))
		grid.add_child(b)
	_add_close(box)

func _popup(title: String, body: String) -> void:
	var box := _popup_base(title)
	var l := _font(24, 0)
	l.text = body
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(420, 80)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(l)
	_add_close(box)

func _popup_base(title: String) -> VBoxContainer:
	_close_overlay()
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _box(Color("2b2f45"), Color("14161f"), 20, 4))
	center.add_child(panel)
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 24)
	m.add_theme_constant_override("margin_right", 24)
	m.add_theme_constant_override("margin_top", 20)
	m.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(m)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	m.add_child(box)
	var t := _font(36, 4)
	t.text = title
	t.add_theme_color_override("font_color", Color.WHITE)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(t)
	return box

func _add_close(box: VBoxContainer) -> void:
	var close := Button.new()
	close.text = "Close"
	close.custom_minimum_size = Vector2(300, 56)
	close.pressed.connect(_close_overlay)
	box.add_child(close)

func _close_overlay() -> void:
	if overlay:
		overlay.queue_free()
		overlay = null

func _toast(msg: String) -> void:
	var l := _font(26, 4)
	l.text = msg
	l.add_theme_color_override("font_color", Color("ffe23f"))
	l.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	l.position = Vector2(0, -220)
	l.size = Vector2(720, 50)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(l)
	var tw := create_tween()
	tw.tween_interval(1.4)
	tw.tween_property(l, "modulate:a", 0.0, 0.4)
	tw.tween_callback(l.queue_free)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if overlay:
			_close_overlay()
