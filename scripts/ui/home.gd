extends Control

const FONT := preload("res://assets/fonts/Baloo2.ttf")
const W := 720.0
const MIN_H := 1180.0
const HOME_BG := preload("res://assets/home/home_bg_v59.jpg")
const STAGE := preload("res://assets/home/character_stage.svg")
const ActorRigScript := preload("res://scripts/game/actor_rig.gd")
const LuckyWheelScript := preload("res://scripts/ui/lucky_wheel.gd")
const AssassinSelectorScript := preload("res://scripts/ui/assassin_selector.gd")

var canvas: Control
var cash_label: Label
var gems_label: Label
var card_art: TextureRect
var selected_name_label: Label
var overlay: Control
var start_button: Button
var hero_stage: TextureRect
var change_button: Button
var mission_panel: Panel
var mission_nodes: Array[Control] = []
var action_nodes: Array[Control] = []
var design_h := 1280.0
var wheel_button: BaseButton
var wheel_badge_pos := Vector2.ZERO
var wheel_badge: Control

func _ready() -> void:
	# The warehouse remains the approved game artwork. The selected character,
	# stage, missions, resources and buttons are separate live controls.
	var bg := TextureRect.new()
	bg.name = "SelectedHomeConcept"
	bg.texture = HOME_BG
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var shade := ColorRect.new()
	shade.color = Color(0.07, 0.05, 0.07, 0.23)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	canvas = Control.new()
	canvas.name = "HomeCanvas"
	canvas.size = Vector2(W, 1280)
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(canvas)
	get_viewport().size_changed.connect(_fit)
	_build_resources()
	_build_logo()
	_build_character_stage()
	_build_action_cards()
	_build_missions()
	_build_start()
	_fit()

func _fit() -> void:
	_layout_in_safe_rect(ScreenUtil.safe_rect(get_viewport()))

func _layout_in_safe_rect(safe: Rect2) -> void:
	var s := minf(safe.size.x / W, safe.size.y / MIN_H)
	design_h = maxf(MIN_H, safe.size.y / s)
	canvas.scale = Vector2(s, s)
	canvas.position = safe.position + (safe.size - Vector2(W, design_h) * s) * 0.5
	# Anchoring the menu and missions to the bottom leaves a spacious spotlight
	# on tall phones and compresses it gracefully on shorter phone screens.
	var start_y := design_h - 164.0
	if start_button:
		start_button.position = Vector2(112, start_y)
	var missions_y := start_y - 376.0
	if mission_panel:
		mission_panel.position = Vector2(34, missions_y)
	var actions_y := missions_y - 154.0
	for n in action_nodes:
		n.position.y = actions_y
	if wheel_button:
		wheel_badge_pos = wheel_button.position + Vector2(118, -9)
		if wheel_badge:
			wheel_badge.position = wheel_badge_pos
	var change_y := actions_y - 64.0
	if change_button:
		change_button.position = Vector2(203, change_y)
	if selected_name_label:
		selected_name_label.position = Vector2(140, change_y - 40.0)
	var stage_top := 210.0
	var stage_bottom := change_y + 20.0
	var stage_size := minf(440.0, maxf(190.0, stage_bottom - stage_top))
	var stage_y := stage_top + (stage_bottom - stage_top - stage_size) * 0.5
	if hero_stage:
		hero_stage.position = Vector2((W - stage_size) * 0.5, stage_y)
		hero_stage.size = Vector2(stage_size, stage_size)
	if card_art:
		card_art.position = Vector2((W - stage_size * 0.68) * 0.5, stage_y + stage_size * 0.21)
		card_art.size = Vector2(stage_size * 0.68, stage_size * 0.57)

func _font(size: int, outline: int = 0) -> Label:
	var l := Label.new()
	var fv := FontVariation.new()
	fv.base_font = FONT
	fv.variation_embolden = 1.2
	l.add_theme_font_override("font", fv)
	l.add_theme_font_size_override("font_size", size)
	if outline > 0:
		l.add_theme_constant_override("outline_size", outline)
		l.add_theme_color_override("font_outline_color", Color("121a21"))
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

func _raised_box(bg: Color, border: Color, radius: int, bw: int = 4) -> StyleBoxFlat:
	var s := _box(bg, border, radius, bw)
	s.shadow_color = Color(0.03, 0.02, 0.04, 0.65)
	s.shadow_size = 5
	s.shadow_offset = Vector2(0, 4)
	return s

func _icon_button(tex: Texture2D, pos: Vector2, size: float, cb: Callable, node_name: String) -> TextureButton:
	var b := TextureButton.new()
	b.name = node_name
	b.texture_normal = tex
	b.ignore_texture_size = true
	b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	b.position = pos
	b.custom_minimum_size = Vector2(size, size)
	b.size = Vector2(size, size)
	b.pressed.connect(cb)
	canvas.add_child(b)
	return b

func _badge(parent_pos: Vector2) -> Panel:
	var p := Panel.new()
	p.add_theme_stylebox_override("panel", _box(Color("ffbd38"), Color("17242c"), 15, 3))
	p.position = parent_pos
	p.size = Vector2(31, 31)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(p)
	var l := _font(23, 0)
	l.text = "!"
	l.add_theme_color_override("font_color", Color("15252c"))
	l.position = Vector2(0, -3)
	l.size = Vector2(31, 31)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(l)
	return p

func _build_resources() -> void:
	var gems := _resource_pill("GEMS", Vector2(24, 20), preload("res://assets/ui/gem.png"), func(): _popup("Gems", "Guards drop gems. Unlock assassins and special knives."))
	gems_label = gems.get_meta("value_label")
	gems_label.name = "GemsValue"
	var cash := _resource_pill("CASH", Vector2(285, 20), preload("res://assets/ui/cash.png"), func(): _popup("Cash", "Earn cash by completing levels and missions."))
	cash_label = cash.get_meta("value_label")
	cash_label.name = "CashValue"
	_refresh_values()
	var setting := Button.new()
	setting.name = "SettingsButton"
	setting.tooltip_text = "Settings"
	setting.position = Vector2(553, 20)
	setting.size = Vector2(143, 98)
	setting.add_theme_stylebox_override("normal", _raised_box(Color("34434c"), Color("15242c"), 20, 5))
	setting.add_theme_stylebox_override("hover", _raised_box(Color("4a5c64"), Color("15242c"), 20, 5))
	setting.add_theme_stylebox_override("pressed", _raised_box(Color("27353e"), Color("15242c"), 20, 5))
	setting.pressed.connect(_open_settings)
	canvas.add_child(setting)
	var gear := TextureRect.new()
	gear.texture = preload("res://assets/ui/gear.png")
	gear.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	gear.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	gear.position = Vector2(34, 10)
	gear.size = Vector2(76, 76)
	gear.mouse_filter = Control.MOUSE_FILTER_IGNORE
	setting.add_child(gear)

func _resource_pill(title: String, pos: Vector2, icon: Texture2D, cb: Callable) -> Panel:
	var p := Panel.new()
	p.position = pos
	p.size = Vector2(257, 98)
	p.add_theme_stylebox_override("panel", _raised_box(Color("34434c"), Color("15242c"), 20, 5))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(p)
	var ic := TextureRect.new()
	ic.texture = icon
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.position = Vector2(12, 10)
	ic.size = Vector2(58, 58)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(ic)
	var heading := _font(25, 3)
	heading.text = title
	heading.position = Vector2(70, 3)
	heading.size = Vector2(135, 34)
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(heading)
	var value := _font(35, 3)
	value.position = Vector2(24, 45)
	value.size = Vector2(168, 47)
	value.clip_text = true
	value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(value)
	p.set_meta("value_label", value)
	var plus := Button.new()
	plus.name = title.capitalize() + "Button"
	plus.tooltip_text = "About " + title.to_lower()
	plus.text = "+"
	plus.position = Vector2(193, 43)
	plus.size = Vector2(48, 47)
	plus.add_theme_font_override("font", FONT)
	plus.add_theme_font_size_override("font_size", 34)
	plus.add_theme_color_override("font_color", Color("0e534f"))
	var plus_style := _box(Color("ffcc50"), Color("6c4319"), 11, 3)
	plus_style.content_margin_left = 0
	plus_style.content_margin_right = 0
	plus_style.content_margin_top = 0
	plus_style.content_margin_bottom = 0
	plus.add_theme_stylebox_override("normal", plus_style)
	plus.add_theme_stylebox_override("hover", _box(Color("ffe083"), Color("6c4319"), 11, 3))
	plus.pressed.connect(cb)
	p.add_child(plus)
	return p

func _build_logo() -> void:
	var title := _font(68, 7)
	title.name = "HomeTitle"
	title.text = "APEX ASSASSIN"
	title.add_theme_color_override("font_color", Color("ffce45"))
	title.add_theme_color_override("font_outline_color", Color("17141b"))
	title.position = Vector2(16, 126)
	title.size = Vector2(688, 86)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(title)

func _build_character_stage() -> void:
	hero_stage = TextureRect.new()
	hero_stage.name = "CharacterSpotlight"
	hero_stage.texture = STAGE
	hero_stage.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hero_stage.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hero_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(hero_stage)
	card_art = TextureRect.new()
	card_art.name = "SelectedAssassinPortrait"
	card_art.texture = _character_portrait(GameState.selected_assassin)
	card_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	card_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	card_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(card_art)
	selected_name_label = _font(29, 4)
	selected_name_label.name = "SelectedAssassinName"
	selected_name_label.text = str(GameState.character().get("name", "Ronin")).to_upper()
	selected_name_label.size = Vector2(440, 38)
	selected_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	selected_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	selected_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(selected_name_label)
	change_button = Button.new()
	change_button.name = "AssassinButton"
	change_button.size = Vector2(314, 58)
	change_button.add_theme_stylebox_override("normal", _raised_box(Color("8839a7"), Color("28152e"), 15, 4))
	change_button.add_theme_stylebox_override("hover", _raised_box(Color("aa53c5"), Color("28152e"), 15, 4))
	change_button.add_theme_stylebox_override("pressed", _raised_box(Color("682a86"), Color("28152e"), 15, 4))
	change_button.pressed.connect(_open_assassins)
	canvas.add_child(change_button)
	var label := _font(30, 4)
	label.text = "CHANGE ASSASSIN"
	label.position = Vector2(0, 2)
	label.size = Vector2(314, 52)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	change_button.add_child(label)

func _build_action_cards() -> void:
	var knives := _action_card("KnivesButton", "KNIVES", preload("res://assets/home/card_upgrade.png"), Color("17b7a7"), 108.0, _open_knives)
	action_nodes.append(knives)
	wheel_button = _action_card("WheelButton", "WHEEL", preload("res://assets/ui/wheel.png"), Color("8d48b7"), 286.0, _spin_wheel)
	action_nodes.append(wheel_button)
	var shop := _action_card("ShopButton", "SHOP", preload("res://assets/ui/shop.png"), Color("17b7a7"), 464.0, _open_knives)
	action_nodes.append(shop)
	if GameState.can_spin_wheel():
		wheel_badge = _badge(Vector2.ZERO)

func _action_card(node_name: String, title: String, icon: Texture2D, color: Color, x: float, cb: Callable) -> Button:
	var b := Button.new()
	b.name = node_name
	b.position = Vector2(x, 0)
	b.size = Vector2(148, 132)
	b.add_theme_stylebox_override("normal", _raised_box(color, Color("11252c"), 20, 5))
	b.add_theme_stylebox_override("hover", _raised_box(color.lightened(0.15), Color("11252c"), 20, 5))
	b.add_theme_stylebox_override("pressed", _raised_box(color.darkened(0.15), Color("11252c"), 20, 5))
	b.pressed.connect(cb)
	canvas.add_child(b)
	var art := TextureRect.new()
	art.texture = icon
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.position = Vector2(31, 4)
	art.size = Vector2(86, 82)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(art)
	var label := _font(29, 4)
	label.text = title
	label.position = Vector2(0, 88)
	label.size = Vector2(148, 38)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(label)
	return b

func _spin_wheel() -> void:
	_close_overlay()
	overlay = LuckyWheelScript.new()
	add_child(overlay)
	overlay.closed.connect(_on_wheel_closed)

func _on_wheel_closed() -> void:
	overlay = null
	_refresh_values()
	_sync_wheel_badge()

func _sync_wheel_badge() -> void:
	if wheel_button == null:
		return
	if wheel_badge != null and not GameState.can_spin_wheel():
		wheel_badge.queue_free()
		wheel_badge = null
	elif wheel_badge == null and GameState.can_spin_wheel():
		wheel_badge = _badge(wheel_badge_pos)

func _build_missions() -> void:
	mission_panel = Panel.new()
	mission_panel.name = "MissionsPanel"
	mission_panel.size = Vector2(652, 360)
	mission_panel.add_theme_stylebox_override("panel", _raised_box(Color("374b55"), Color("14232b"), 24, 5))
	mission_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(mission_panel)
	var title := _font(34, 4)
	title.text = "MISSIONS"
	title.add_theme_color_override("font_color", Color("6be2bd"))
	title.position = Vector2(24, 8)
	title.size = Vector2(330, 48)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mission_panel.add_child(title)
	mission_nodes.append(_mission_card(1, "ELIMINATE TARGETS", "Progress: %d / 30" % mini(GameState.total_kills, 30), 150, GameState.total_kills >= 30, GameState.mission1_claimed, preload("res://assets/ui/target.png")))
	mission_nodes.append(_mission_card(2, "FREE SUPPLY DROP", "OFFLINE BONUS", 200, true, GameState.mission2_claimed, preload("res://assets/environment/depot/crate_real_top.png")))
	mission_nodes.append(_mission_card(3, "NO DAMAGE CHALLENGE", "Level perfect: %d / 1" % mini(GameState.flawless_count, 1), 200, GameState.flawless_count >= 1, GameState.mission3_claimed, preload("res://assets/ui/heart.png")))
	for i in range(mission_nodes.size()):
		mission_nodes[i].position = Vector2(20, 61 + i * 96)

func _mission_card(index: int, title: String, progress: String, prize: int, complete: bool, claimed: bool, icon: Texture2D) -> Panel:
	var p := Panel.new()
	p.name = "Mission%d" % index
	p.size = Vector2(612, 88)
	p.add_theme_stylebox_override("panel", _box(Color("253a44"), Color("1a2b34"), 16, 3))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mission_panel.add_child(p)
	var ic := TextureRect.new()
	ic.texture = icon
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.position = Vector2(10, 11)
	ic.size = Vector2(63, 63)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(ic)
	var t := _font(25, 3)
	t.text = title
	t.position = Vector2(80, 9)
	t.size = Vector2(325, 38)
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	t.clip_text = true
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(t)
	var pr := _font(20, 2)
	pr.text = progress
	pr.add_theme_color_override("font_color", Color("c7d2d9"))
	pr.position = Vector2(80, 48)
	pr.size = Vector2(310, 30)
	pr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(pr)
	var btn := Button.new()
	btn.name = "Mission%dButton" % index
	btn.position = Vector2(408, 15)
	btn.size = Vector2(190, 58)
	var claimable := complete and not claimed
	var bg := Color("5ce662") if claimable else (Color("40535c") if claimed else Color("596874"))
	var edge := Color("1c6937") if claimable else Color("20343c")
	var style := _raised_box(bg, edge, 13, 3)
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("disabled", style)
	btn.add_theme_stylebox_override("hover", style)
	btn.disabled = claimed or not complete
	btn.pressed.connect(_claim_mission.bind(index))
	p.add_child(btn)
	var label := _font(25, 3)
	label.text = "CLAIMED" if claimed else ("CLAIM %d" % prize if claimable else "PRIZE %d" % prize)
	label.position = Vector2(0, 3)
	label.size = Vector2(190, 50)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(label)
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
	b.name = "StartGameButton"
	start_button = b
	b.size = Vector2(496, 140)
	b.add_theme_stylebox_override("normal", _raised_box(Color("ffbf35"), Color("8c5b13"), 25, 6))
	b.add_theme_stylebox_override("hover", _raised_box(Color("ffd261"), Color("9e6c1f"), 25, 6))
	b.add_theme_stylebox_override("pressed", _raised_box(Color("e5a521"), Color("744a0d"), 25, 6))
	b.pressed.connect(func(): GameState.start_level(GameState.current_level))
	canvas.add_child(b)
	var title := _font(60, 0)
	title.text = "START GAME"
	title.add_theme_color_override("font_color", Color("251b16"))
	title.position = Vector2(0, 4)
	title.size = Vector2(496, 75)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(title)
	var lv := _font(30, 0)
	lv.name = "CurrentLevelLabel"
	lv.text = "LEVEL %d" % GameState.current_level
	lv.add_theme_color_override("font_color", Color("754419"))
	lv.position = Vector2(0, 87)
	lv.size = Vector2(496, 40)
	lv.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(lv)

func _refresh_values() -> void:
	if cash_label:
		cash_label.text = str(GameState.cash)
	if gems_label:
		gems_label.text = str(GameState.gems)

func _character_portrait(id: String) -> Texture2D:
	return load("res://assets/reference/characters/%02d.png" % GameState.reference_art_index(id))

func _refresh_card() -> void:
	if card_art:
		card_art.texture = _character_portrait(GameState.selected_assassin)
	if selected_name_label:
		selected_name_label.text = str(GameState.character().get("name", "Ronin")).to_upper()

# ---------------- Full-screen collection screens ----------------
func _screen_base(title: String, reference_palette := false) -> VBoxContainer:
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
	var panel_colour := Color("74169d") if reference_palette else Color("1b2f8a")
	panel.add_theme_stylebox_override("panel", _box(panel_colour, Color("0d1440"), 22, 4))
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
	_close_overlay()
	overlay = AssassinSelectorScript.new()
	add_child(overlay)
	overlay.closed.connect(_close_overlay)
	overlay.changed.connect(_on_assassin_changed)

func _on_assassin_changed() -> void:
	_refresh_values()
	_refresh_card()

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
		_refresh_values()
		_sync_wheel_badge()

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
