extends Control
## Functional interpretation of the selected warehouse concept. The backdrop is
## reconstructed from the concept; every label, portrait and button is live.

signal closed
signal changed

const FONT := preload("res://assets/fonts/Baloo2.ttf")
const BG := preload("res://assets/ui/selector/warehouse.jpg")
const GEM := preload("res://assets/ui/gem.png")
const WIDTH := 720.0
const MIN_HEIGHT := 1180.0

var stage: Control
var scroll: ScrollContainer
var roster: HBoxContainer
var hero: TextureRect
var character_name: Label
var speed_value: Label
var health_value: Label
var gems_value: Label
var selected_button: Button
var bonus_button: Button
var hint: Label
var preview_id := "v72_commando"
var preview_loadout := "ronin"
var design_h := 1280.0
var cards := {}
var scroll_tween: Tween
# Explicit collection drag works on both touch screens and desktop pointers.
# Button presses are suppressed briefly after a swipe, so browsing never equips
# or accidentally previews the card that happened to be under the finger.
var _browse_touch := -1
var _browse_mouse := false
var _browse_start_x := 0.0
var _browse_start_scroll := 0
var _browse_moved := false
var _suppress_cards_until := 0

func _ready() -> void:
	name = "AssassinSelector"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	preview_id = GameState.visible_character_id(GameState.selected_assassin)
	preview_loadout = GameState.selected_assassin
	_build()
	get_viewport().size_changed.connect(_fit)
	_fit()
	_refresh_preview()
	await get_tree().process_frame
	_center_current(false)

func _font(size: int, outline: int = 0) -> Label:
	var l := Label.new()
	var font := FontVariation.new()
	font.base_font = FONT
	font.variation_embolden = 0.45
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	if outline:
		l.add_theme_constant_override("outline_size", outline)
		l.add_theme_color_override("font_outline_color", Color("0b1721"))
	l.add_theme_color_override("font_color", Color.WHITE)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _box(bg: Color, border: Color, radius: int, border_width: int = 3) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	return style

func _portrait(id: String) -> Texture2D:
	return load(GameState.character_portrait_path(id))

func _build() -> void:
	var background := TextureRect.new()
	background.name = "WarehouseBackdrop"
	background.texture = BG
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	stage = Control.new()
	stage.name = "SafeCanvas"
	add_child(stage)
	var gem := TextureRect.new()
	gem.texture = GEM
	gem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	gem.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	gem.position = Vector2(24, 20)
	gem.size = Vector2(55, 55)
	gem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(gem)
	gems_value = _font(36, 3)
	gems_value.name = "GemValue"
	gems_value.position = Vector2(82, 20)
	gems_value.size = Vector2(150, 56)
	stage.add_child(gems_value)
	var close := Button.new()
	close.name = "CloseButton"
	close.text = "×"
	close.position = Vector2(642, 20)
	close.size = Vector2(58, 58)
	close.add_theme_font_override("font", FONT)
	close.add_theme_font_size_override("font_size", 39)
	close.add_theme_color_override("font_color", Color.WHITE)
	close.add_theme_stylebox_override("normal", _box(Color("e93538"), Color("ff7470"), 14, 3))
	close.add_theme_stylebox_override("hover", _box(Color("ff5555"), Color("ffc2a8"), 14, 3))
	close.add_theme_stylebox_override("pressed", _box(Color("b11c27"), Color("ff7470"), 14, 3))
	close.pressed.connect(func(): closed.emit())
	stage.add_child(close)
	var title := _font(52, 4)
	title.name = "Title"
	title.text = "CHOOSE ASSASSIN"
	title.position = Vector2(0, 93)
	title.size = Vector2(WIDTH, 78)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stage.add_child(title)
	hero = TextureRect.new()
	hero.name = "HeroArt"
	hero.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	hero.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hero.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hero.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(hero)
	character_name = _font(33, 4)
	character_name.name = "CharacterName"
	character_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stage.add_child(character_name)
	var speed := _stat_panel("SpeedPanel", "SPEED", Color("047bbd"), Color("46c5ff"))
	stage.add_child(speed)
	speed_value = speed.get_node("Value")
	var health := _stat_panel("HealthPanel", "HEALTH", Color("1dbb3b"), Color("6eff80"))
	stage.add_child(health)
	health_value = health.get_node("Value")
	bonus_button = Button.new()
	bonus_button.name = "BonusLoadoutButton"
	bonus_button.add_theme_font_override("font", FONT)
	bonus_button.add_theme_font_size_override("font_size", 22)
	bonus_button.add_theme_color_override("font_color", Color("fff1c4"))
	bonus_button.add_theme_color_override("font_disabled_color", Color("a6b1b5"))
	bonus_button.add_theme_stylebox_override("normal", _box(Color("243944"), Color("af945c"), 8, 2))
	bonus_button.add_theme_stylebox_override("hover", _box(Color("355563"), Color("ffe095"), 8, 2))
	bonus_button.add_theme_stylebox_override("pressed", _box(Color("162d36"), Color("ffe095"), 8, 2))
	bonus_button.add_theme_stylebox_override("disabled", _box(Color("26343a"), Color("52656a"), 8, 1))
	bonus_button.pressed.connect(_cycle_loadout)
	stage.add_child(bonus_button)
	selected_button = Button.new()
	selected_button.name = "SelectButton"
	selected_button.add_theme_font_override("font", FONT)
	selected_button.add_theme_font_size_override("font_size", 53)
	selected_button.add_theme_color_override("font_color", Color.WHITE)
	selected_button.add_theme_color_override("font_disabled_color", Color("fff0d8"))
	selected_button.add_theme_constant_override("outline_size", 5)
	selected_button.add_theme_color_override("font_outline_color", Color("a2350c"))
	selected_button.add_theme_stylebox_override("normal", _box(Color("ff7618"), Color("ffb45e"), 46, 5))
	selected_button.add_theme_stylebox_override("hover", _box(Color("ff912c"), Color("ffcf80"), 46, 5))
	selected_button.add_theme_stylebox_override("pressed", _box(Color("d94c0b"), Color("ffb45e"), 46, 5))
	selected_button.add_theme_stylebox_override("disabled", _box(Color("9d5a2c"), Color("d59c63"), 46, 4))
	selected_button.pressed.connect(_confirm)
	stage.add_child(selected_button)
	var roster_label := _font(24, 2)
	roster_label.name = "RosterLabel"
	roster_label.text = "YOUR ASSASSINS    •    SWIPE TO BROWSE"
	roster_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	roster_label.add_theme_color_override("font_color", Color("c4d7de"))
	stage.add_child(roster_label)
	scroll = ScrollContainer.new()
	scroll.name = "AssassinScroll"
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.follow_focus = true
	stage.add_child(scroll)
	roster = HBoxContainer.new()
	roster.name = "Roster"
	roster.add_theme_constant_override("separation", 18)
	scroll.add_child(roster)
	for id in GameState.CHARACTER_ORDER:
		var card := _roster_card(id)
		cards[id] = card
		roster.add_child(card)
	hint = _font(22, 2)
	hint.name = "Hint"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", Color("a7c0cc"))
	stage.add_child(hint)

func _stat_panel(node_name: String, title: String, fill: Color, border: Color) -> Panel:
	var panel := Panel.new()
	panel.name = node_name
	panel.add_theme_stylebox_override("panel", _box(fill, border, 15, 4))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var heading := _font(24)
	heading.text = title + ":"
	heading.position = Vector2(0, 5)
	heading.size = Vector2(246, 33)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_color_override("font_color", Color("092436"))
	panel.add_child(heading)
	var value := _font(32)
	value.name = "Value"
	value.position = Vector2(0, 34)
	value.size = Vector2(246, 45)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.add_theme_color_override("font_color", Color("061d2a"))
	panel.add_child(value)
	return panel

func _roster_card(id: String) -> Button:
	var card := Button.new()
	if GameState.is_reference_character(id):
		card.name = "ReferenceCard%02d" % GameState.reference_art_index(id)
	else:
		card.name = "LegacyCard_" + id
	card.custom_minimum_size = Vector2(132, 132)
	card.tooltip_text = String(GameState.CHARACTERS[id].name)
	card.focus_mode = Control.FOCUS_ALL
	card.clip_contents = true
	card.pressed.connect(_card_pressed.bind(id))
	var picture := TextureRect.new()
	picture.name = "Portrait"
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	picture.texture = _portrait(id)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.position = Vector2(5, 9)
	picture.size = Vector2(122, 109)
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not GameState.is_unlocked(id):
		picture.modulate = Color(0.48, 0.49, 0.53, 0.80)
	card.add_child(picture)
	if not GameState.is_unlocked(id):
		var price := _font(18, 3)
		price.name = "Price"
		price.text = "KEY REWARD" if id == GameState.VAULT_CHARACTER else "%d diamonds" % int(GameState.CHARACTERS[id].cost)
		price.position = Vector2(6, 100)
		price.size = Vector2(120, 25)
		price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		price.add_theme_color_override("font_color", Color("ffd45a"))
		card.add_child(price)
	return card

func _fit() -> void:
	var safe := ScreenUtil.safe_rect(get_viewport())
	var scale_factor := minf(safe.size.x / WIDTH, safe.size.y / MIN_HEIGHT)
	design_h = maxf(MIN_HEIGHT, safe.size.y / scale_factor)
	stage.scale = Vector2.ONE * scale_factor
	stage.position = safe.position + (safe.size - Vector2(WIDTH, design_h) * scale_factor) * 0.5
	stage.size = Vector2(WIDTH, design_h)
	hero.position = Vector2(100, design_h * 0.175)
	hero.size = Vector2(520, minf(360, design_h * 0.235))
	character_name.position = Vector2(35, design_h * 0.402)
	character_name.size = Vector2(650, 55)
	var speed := stage.get_node("SpeedPanel") as Panel
	var health := stage.get_node("HealthPanel") as Panel
	speed.position = Vector2(82, design_h * 0.448)
	speed.size = Vector2(246, 88)
	health.position = Vector2(392, design_h * 0.448)
	health.size = Vector2(246, 88)
	bonus_button.position = Vector2(110, design_h * 0.522)
	bonus_button.size = Vector2(500, 76)
	selected_button.position = Vector2(142, design_h * 0.598)
	selected_button.size = Vector2(436, 100)
	var roster_label := stage.get_node("RosterLabel") as Label
	roster_label.position = Vector2(0, design_h * 0.687)
	roster_label.size = Vector2(WIDTH, 36)
	scroll.position = Vector2(8, design_h * 0.735)
	scroll.size = Vector2(704, 156)
	hint.position = Vector2(16, design_h * 0.735 + 168)
	hint.size = Vector2(688, 40)

func _input(event: InputEvent) -> void:
	if not is_instance_valid(scroll) or not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		if event.pressed and _browse_touch == -1 and scroll.get_global_rect().has_point(event.position):
			_browse_touch = event.index
			_browse_begin(event.position)
		elif not event.pressed and event.index == _browse_touch:
			_browse_finish()
			_browse_touch = -1
	elif event is InputEventScreenDrag and event.index == _browse_touch:
		_browse_drag(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		# Godot also emits emulated mouse events for touch; do not pan twice.
		if event.device == InputEvent.DEVICE_ID_EMULATION:
			return
		if event.pressed and _browse_touch == -1 and scroll.get_global_rect().has_point(event.position):
			_browse_mouse = true
			_browse_begin(event.position)
		elif not event.pressed and _browse_mouse:
			_browse_finish()
			_browse_mouse = false
	elif event is InputEventMouseMotion and _browse_mouse and event.device != InputEvent.DEVICE_ID_EMULATION:
		_browse_drag(event.position)

func _browse_begin(pos: Vector2) -> void:
	_browse_start_x = (scroll.get_global_transform().affine_inverse() * pos).x
	_browse_start_scroll = scroll.scroll_horizontal
	_browse_moved = false

func _browse_drag(pos: Vector2) -> void:
	var displacement: float = (scroll.get_global_transform().affine_inverse() * pos).x - _browse_start_x
	if absf(displacement) < 8.0 and not _browse_moved:
		return
	if not _browse_moved and is_instance_valid(scroll_tween):
		scroll_tween.kill()
	_browse_moved = true
	_suppress_cards_until = Time.get_ticks_msec() + 200
	scroll.scroll_horizontal = _browse_start_scroll - roundi(displacement)
	get_viewport().set_input_as_handled()

func _browse_finish() -> void:
	if _browse_moved:
		_suppress_cards_until = Time.get_ticks_msec() + 200
	_browse_moved = false

func _card_pressed(id: String) -> void:
	if Time.get_ticks_msec() < _suppress_cards_until:
		return
	_preview(id)

func _preview(id: String) -> void:
	preview_id = id
	preview_loadout = GameState.selected_assassin if id == GameState.visible_character_id(GameState.selected_assassin) else id
	_refresh_preview()
	_center_current(true)

func _center_current(animate: bool) -> void:
	if not cards.has(preview_id) or not is_instance_valid(scroll):
		return
	var card: Button = cards[preview_id]
	var target := maxi(0, int(card.position.x + card.size.x * 0.5 - scroll.size.x * 0.5))
	if is_instance_valid(scroll_tween):
		scroll_tween.kill()
	if animate:
		scroll_tween = create_tween()
		scroll_tween.tween_property(scroll, "scroll_horizontal", target, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	else:
		scroll.scroll_horizontal = target

func _refresh_preview() -> void:
	if not GameState.CHARACTERS.has(preview_id):
		return
	var loadouts: Array[String] = GameState.character_loadouts(preview_id)
	if not loadouts.has(preview_loadout):
		preview_loadout = preview_id
	var equipped := preview_loadout == GameState.selected_assassin
	var data: Dictionary = GameState.CHARACTERS[preview_loadout]
	hero.texture = _portrait(preview_id)
	character_name.text = GameState.display_character_name(preview_id).to_upper()
	speed_value.text = "+%d%%" % roundi(float(data.speed_bonus) * 100.0)
	health_value.text = "+%d%%" % roundi(float(data.health_bonus) * 100.0)
	gems_value.text = str(GameState.gems)
	var speed_bonus := roundi(float(data.speed_bonus) * 100.0)
	var health_bonus := roundi(float(data.health_bonus) * 100.0)
	var bonus_text := "STANDARD" if speed_bonus == 0 and health_bonus == 0 else "+%d%% SPEED  /  +%d%% HEALTH" % [speed_bonus, health_bonus]
	bonus_button.text = "BONUS %d/%d:  %s  >" % [loadouts.find(preview_loadout) + 1, loadouts.size(), bonus_text]
	bonus_button.disabled = loadouts.size() < 2
	var unlocked := GameState.is_unlocked(preview_loadout)
	var locker_only := preview_id == GameState.VAULT_CHARACTER and not unlocked
	selected_button.disabled = equipped or locker_only
	selected_button.text = "SELECTED" if equipped else ("FIND IN LOCKERS" if locker_only else ("SELECT" if unlocked else "UNLOCK  %d" % int(data.cost)))
	hint.text = "Currently equipped" if equipped else ("Find in a three-key locker" if locker_only else ("Tap SELECT to equip" if unlocked else "Unlock for %d diamonds" % int(data.cost)))
	for id in cards:
		var card: Button = cards[id]
		var highlighted: bool = id == preview_id
		var fill := Color("46515a") if GameState.is_unlocked(id) else Color("2c343b")
		var edge := Color("ffcf55") if highlighted else Color("788189")
		card.add_theme_stylebox_override("normal", _box(fill, edge, 66, 5 if highlighted else 3))
		card.add_theme_stylebox_override("hover", _box(fill.lightened(0.08), edge, 66, 5 if highlighted else 3))
		card.add_theme_stylebox_override("pressed", _box(fill.darkened(0.08), edge, 66, 5 if highlighted else 3))
		if card.has_node("Portrait"):
			card.get_node("Portrait").modulate = Color.WHITE if GameState.is_unlocked(id) else Color(0.48, 0.49, 0.53, 0.80)
		if GameState.is_unlocked(id) and card.has_node("Price"):
			card.get_node("Price").queue_free()

func _cycle_loadout() -> void:
	var loadouts: Array[String] = GameState.character_loadouts(preview_id)
	if loadouts.size() < 2:
		return
	preview_loadout = loadouts[(loadouts.find(preview_loadout) + 1) % loadouts.size()]
	_refresh_preview()

func _confirm() -> void:
	if GameState.is_unlocked(preview_loadout):
		if GameState.select_character(preview_loadout):
			Sfx.play("upgrade")
			changed.emit()
	elif GameState.unlock_character(preview_id):
		Sfx.play("upgrade")
		changed.emit()
	else:
		hint.text = "Need %d diamonds to unlock" % int(GameState.CHARACTERS[preview_id].cost)
		return
	_refresh_preview()
