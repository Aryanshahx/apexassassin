extends Control

const FONT := preload("res://assets/fonts/Baloo2.ttf")
const W := 720.0
const MIN_H := 1180.0
const ActorRigScript := preload("res://scripts/game/actor_rig.gd")
const LuckyWheelScript := preload("res://scripts/ui/lucky_wheel.gd")

var canvas: Control
var cash_label: Label
var gems_label: Label
var card_art: TextureRect
var overlay: Control
var start_button: Button
var mission_nodes: Array[Control] = []
var action_nodes: Array[Control] = []
var design_h := 1280.0
var wheel_button: TextureButton
var wheel_badge_pos := Vector2.ZERO

func _ready() -> void:
	var bg := TextureRect.new()
	bg.texture = preload("res://assets/home/home_bg.jpg")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	canvas = Control.new()
	add_child(canvas)
	get_viewport().size_changed.connect(_fit)
	_build_resources()
	_build_side_icons()
	_build_action_cards()
	_build_missions()
	_build_start()
	_fit()

func _fit() -> void:
	var safe := ScreenUtil.safe_rect(get_viewport())
	var s := minf(safe.size.x / W, safe.size.y / MIN_H)
	design_h = maxf(MIN_H, safe.size.y / s)
	canvas.scale = Vector2(s, s)
	canvas.position = safe.position + (safe.size - Vector2(W, design_h) * s) * 0.5
	var start_y := design_h - 250.0
	if start_button:
		start_button.position = Vector2(170, start_y)
	var mission_bottom := start_y - 24.0
	var mission_top := mission_bottom - (3 * 128 + 2 * 16)
	for i in range(mission_nodes.size()):
		mission_nodes[i].position = Vector2(36, mission_top + i * 144)
	var action_y := maxf(286.0, mission_top - 178.0)
	for n in action_nodes:
		n.position.y = action_y

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
	var p := Panel.new()
	p.add_theme_stylebox_override("panel", _box(Color("e63946"), Color("ffffff"), 13, 2))
	p.position = parent_pos
	p.size = Vector2(26, 26)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(p)
	var l := _font(20, 3)
	l.text = "!"
	l.add_theme_color_override("font_color", Color.WHITE)
	l.position = Vector2(0, -3)
	l.size = Vector2(26, 26)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(l)

func _build_resources() -> void:
	var gem_pill := _resource_pill(Vector2(30, 24), preload("res://assets/ui/gem.png"), str(GameState.gems), func(): _popup("Gems", "Guards drop gems. Unlock assassins and special knives."), 190)
	gems_label = gem_pill.get_meta("value_label")
	var cash_pill := _resource_pill(Vector2(252, 24), preload("res://assets/ui/cash.png"), str(GameState.cash), func(): _popup("Cash", "Earn cash by completing levels and missions."), 196)
	cash_label = cash_pill.get_meta("value_label")
	_icon_button(preload("res://assets/ui/gear.png"), Vector2(618, 16), 76, _open_settings)
	_badge(Vector2(672, 10))

func _resource_pill(pos: Vector2, icon: Texture2D, value: String, cb: Callable, width: float = 212) -> Panel:
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

func _build_side_icons() -> void:
	# VIP / No Ads / Offers removed. Wheel + shop only.
	wheel_button = _icon_button(preload("res://assets/ui/wheel.png"), Vector2(606, 104), 104, _spin_wheel)
	wheel_badge_pos = Vector2(678, 98)
	if GameState.can_spin_wheel():
		_badge(wheel_badge_pos)
	_icon_button(preload("res://assets/ui/shop.png"), Vector2(612, 226), 98, func(): _open_knives())

func _spin_wheel() -> void:
	_close_overlay()
	overlay = LuckyWheelScript.new()
	add_child(overlay)
	overlay.closed.connect(_on_wheel_closed)

func _on_wheel_closed() -> void:
	overlay = null
	_refresh_values()
	if wheel_button:
		wheel_button.modulate = Color.WHITE if GameState.can_spin_wheel() else Color(0.72, 0.72, 0.78)

func _build_action_cards() -> void:
	var change := Button.new()
	change.position = Vector2(36, 430)
	change.size = Vector2(468, 150)
	change.add_theme_stylebox_override("normal", _box(Color("9a45ee"), Color("2a0a4a"), 20, 4))
	change.add_theme_stylebox_override("hover", _box(Color("a855f7"), Color("2a0a4a"), 20, 4))
	change.add_theme_stylebox_override("pressed", _box(Color("7e35cf"), Color("2a0a4a"), 20, 4))
	change.pressed.connect(_open_assassins)
	canvas.add_child(change)
	action_nodes.append(change)
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
	up.pressed.connect(_open_knives)
	canvas.add_child(up)
	action_nodes.append(up)
	var ua := TextureRect.new()
	ua.texture = preload("res://assets/home/card_upgrade.png")
	ua.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ua.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ua.position = Vector2(22, -16)
	ua.size = Vector2(120, 110)
	ua.mouse_filter = Control.MOUSE_FILTER_IGNORE
	up.add_child(ua)
	var ut := _font(28, 4)
	ut.text = "Knives"
	ut.add_theme_color_override("font_color", Color.WHITE)
	ut.position = Vector2(0, 100)
	ut.size = Vector2(164, 40)
	ut.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ut.mouse_filter = Control.MOUSE_FILTER_IGNORE
	up.add_child(ut)

func _build_missions() -> void:
	mission_nodes.append(_mission_card(Vector2(36, 600), "Eliminate 30 targets", "%d / 30" % mini(GameState.total_kills, 30), 150,
		GameState.total_kills >= 30, GameState.mission1_claimed, _claim_mission.bind(1)))
	mission_nodes.append(_mission_card(Vector2(36, 744), "Free supply drop", "Offline bonus", 200,
		true, GameState.mission2_claimed, _claim_mission.bind(2)))
	mission_nodes.append(_mission_card(Vector2(36, 888), "Complete a level with\nno damage taken", "%d / 1" % mini(GameState.flawless_count, 1), 200,
		GameState.flawless_count >= 1, GameState.mission3_claimed, _claim_mission.bind(3)))

func _mission_card(pos: Vector2, title: String, progress: String, prize: int, complete: bool, claimed: bool, cb: Callable) -> Panel:
	var p := Panel.new()
	p.position = pos
	p.size = Vector2(648, 128)
	p.add_theme_stylebox_override("panel", _box(Color("6a6d85"), Color("23252e"), 16, 4))
	canvas.add_child(p)
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
	else:
		btn.add_theme_stylebox_override("normal", _box(Color("9aa0b4"), Color("23252e"), 14, 3))
	btn.pressed.connect(cb)
	p.add_child(btn)
	var lbl := _font(28, 4)
	lbl.text = "Done" if claimed else ("Claim" if claimable else "Prize")
	lbl.add_theme_color_override("font_color", Color("ffe23f") if claimable else Color.WHITE)
	lbl.position = Vector2(0, 12)
	lbl.size = Vector2(200, 40)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(lbl)
	var amt := _font(24, 4)
	amt.text = str(prize)
	amt.add_theme_color_override("font_color", Color.WHITE)
	amt.position = Vector2(0, 54)
	amt.size = Vector2(200, 36)
	amt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	amt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(amt)
	return p

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

func _build_start() -> void:
	var b := Button.new()
	start_button = b
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

func _refresh_values() -> void:
	if cash_label:
		cash_label.text = str(GameState.cash)
	if gems_label:
		gems_label.text = str(GameState.gems)

func _refresh_card() -> void:
	if card_art:
		card_art.texture = load("res://assets/home/card_%s.png" % GameState.selected_assassin)

# ---------------- Full-screen collection screens ----------------
func _screen_base(title: String) -> VBoxContainer:
	_close_overlay()
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.07, 0.16, 0.96)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)
	var safe := ScreenUtil.safe_rect(get_viewport())
	var margin := MarginContainer.new()
	margin.position = safe.position + Vector2(16, 12)
	margin.size = safe.size - Vector2(32, 24)
	overlay.add_child(margin)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _box(Color("1b2f8a"), Color("0d1440"), 22, 4))
	margin.add_child(panel)
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 18)
	m.add_theme_constant_override("margin_right", 18)
	m.add_theme_constant_override("margin_top", 14)
	m.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(m)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	m.add_child(box)
	var head := HBoxContainer.new()
	box.add_child(head)
	var t := _font(38, 5)
	t.text = title
	t.add_theme_color_override("font_color", Color.WHITE)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var close := Button.new()
	close.text = "X"
	close.custom_minimum_size = Vector2(64, 64)
	close.add_theme_stylebox_override("normal", _box(Color("e63946"), Color("7a1020"), 14, 3))
	close.add_theme_font_size_override("font_size", 30)
	close.pressed.connect(_close_overlay)
	head.add_child(close)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 14)
	scroll.add_child(content)
	return content

func _open_assassins() -> void:
	var box := _screen_base("Change Assassin")
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(grid)
	for id in GameState.CHARACTER_ORDER:
		grid.add_child(_character_card(id))

func _character_card(id: String) -> Control:
	var c: Dictionary = GameState.CHARACTERS[id]
	var unlocked := GameState.is_unlocked(id)
	var selected := GameState.selected_assassin == id
	var card := Button.new()
	card.custom_minimum_size = Vector2(0, 250)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var bg := Color("8a8f98") if not unlocked else Color("6a6d85")
	var border := Color("ffc93c") if selected else Color("23252e")
	card.add_theme_stylebox_override("normal", _box(bg, border, 18, 4))
	card.add_theme_stylebox_override("hover", _box(bg.lightened(0.08), border, 18, 4))
	card.add_theme_stylebox_override("pressed", _box(bg.darkened(0.08), border, 18, 4))
	card.pressed.connect(func(): _on_character_pressed(id))
	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 10
	vb.offset_right = -10
	vb.offset_top = 8
	vb.offset_bottom = -8
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(vb)
	var art := TextureRect.new()
	art.texture = load("res://assets/home/card_%s.png" % id)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.custom_minimum_size = Vector2(0, 140)
	art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not unlocked:
		art.modulate = Color(0.6, 0.6, 0.65, 0.9)
	vb.add_child(art)
	var bonus := "Standard"
	var col := Color.WHITE
	if float(c.speed_bonus) > 0:
		bonus = "+%d%% Speed" % int(float(c.speed_bonus) * 100)
		col = Color("3fc6ff")
	elif float(c.health_bonus) > 0:
		bonus = "+%d%% Health" % int(float(c.health_bonus) * 100)
		col = Color("4caf20")
	var bl := _font(26, 4)
	bl.text = bonus
	bl.add_theme_color_override("font_color", col)
	bl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(bl)
	var status := _font(20, 3)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if selected:
		status.text = "Selected"
		status.add_theme_color_override("font_color", Color("ffe23f"))
	elif unlocked:
		status.text = c.name
		status.add_theme_color_override("font_color", Color.WHITE)
	else:
		status.text = "Unlock %d gems" % int(c.cost)
		status.add_theme_color_override("font_color", Color("ffd23f"))
	vb.add_child(status)
	return card

func _on_character_pressed(id: String) -> void:
	if GameState.is_unlocked(id):
		GameState.select_character(id)
		Sfx.play("upgrade")
		_refresh_card()
		_open_assassins()
	elif GameState.unlock_character(id):
		Sfx.play("upgrade")
		_refresh_values()
		_refresh_card()
		_open_assassins()
		_toast("%s unlocked!" % GameState.CHARACTERS[id].name)
	else:
		_toast("Need %d gems." % int(GameState.CHARACTERS[id].cost))

func _open_knives() -> void:
	var box := _screen_base("Special Knives")
	var count := _font(28, 4)
	count.text = "%d / %d" % [GameState.knife_count(), GameState.KNIFE_ORDER.size()]
	count.add_theme_color_override("font_color", Color.WHITE)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(count)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 12)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(grid)
	for id in GameState.KNIFE_ORDER:
		grid.add_child(_knife_card(id))
	var stats := Button.new()
	stats.text = "Stat Upgrades"
	stats.custom_minimum_size = Vector2(0, 56)
	stats.pressed.connect(_open_upgrades)
	box.add_child(stats)

func _knife_card(id: String) -> Control:
	var k: Dictionary = GameState.KNIVES[id]
	var unlocked := GameState.is_knife_unlocked(id)
	var selected := GameState.selected_knife == id
	var wrap := VBoxContainer.new()
	wrap.custom_minimum_size = Vector2(0, 210)
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var icon_btn := Button.new()
	icon_btn.custom_minimum_size = Vector2(0, 140)
	icon_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var bg := Color("ff9d2e")
	if int(k.unlock_level) > 1 and not unlocked:
		bg = Color("6a6d85")
	if selected:
		bg = Color("1f6fb2")
	icon_btn.add_theme_stylebox_override("normal", _box(bg, Color("7CFC7C") if selected else Color("23252e"), 16, 4))
	icon_btn.pressed.connect(func(): _on_knife_pressed(id))
	var icon := TextureRect.new()
	icon.texture = load("res://assets/knives/%s.png" % id)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 12
	icon.offset_right = -12
	icon.offset_top = 10
	icon.offset_bottom = -10
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not unlocked:
		icon.modulate = Color(0.45, 0.45, 0.5, 0.9)
	icon_btn.add_child(icon)
	if not unlocked:
		var lock := TextureRect.new()
		lock.texture = preload("res://assets/ui/lock.png")
		lock.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		lock.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		lock.position = Vector2(6, 6)
		lock.size = Vector2(30, 30)
		lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_btn.add_child(lock)
	wrap.add_child(icon_btn)
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 52)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.add_theme_stylebox_override("normal", _box(Color("ffc93c"), Color("6b4a00"), 12, 3))
	btn.add_theme_font_size_override("font_size", 20)
	btn.add_theme_color_override("font_color", Color("14161f"))
	if selected:
		btn.text = "Equipped"
		btn.disabled = true
	elif unlocked:
		btn.text = "Equip"
	elif int(k.unlock_level) > 1:
		btn.text = "Level %d" % int(k.unlock_level)
		btn.disabled = true
	else:
		btn.text = "Buy %d" % int(k.cost)
	btn.pressed.connect(func(): _on_knife_pressed(id))
	wrap.add_child(btn)
	return wrap

func _on_knife_pressed(id: String) -> void:
	var k: Dictionary = GameState.KNIVES[id]
	if GameState.is_knife_unlocked(id):
		GameState.select_knife(id)
		Sfx.play("upgrade")
		_open_knives()
	elif int(k.unlock_level) > 1:
		_toast("Reach level %d to unlock." % int(k.unlock_level))
	elif GameState.buy_knife(id):
		Sfx.play("upgrade")
		_refresh_values()
		_open_knives()
		_toast("%s unlocked!" % k.name)
	else:
		_toast("Need %d gems." % int(k.cost))

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

func _open_upgrades() -> void:
	var box := _popup_base("Stat Upgrades")
	var kinds := [["health", "Health (+1)"], ["damage", "Damage (+1)"], ["speed", "Speed (+14)"]]
	for k in kinds:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var l := _font(24, 0)
		l.text = "%s  Lv %d" % [k[1], int(GameState.upgrades[k[0]])]
		l.custom_minimum_size = Vector2(260, 50)
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
	var safe := ScreenUtil.safe_rect(get_viewport())
	var center := CenterContainer.new()
	center.position = safe.position
	center.size = safe.size
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
