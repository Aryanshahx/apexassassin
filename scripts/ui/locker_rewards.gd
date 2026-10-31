extends Control
## Three keys open one persistent nine-locker board. Each pick is saved before
## it is revealed, so quitting/reopening cannot reroll or duplicate a prize.
signal completed
const FONT := preload("res://assets/fonts/Baloo2.ttf")
const KEY_TEX := preload("res://assets/ui/v64_key.png")
const DIAMOND_TEX := preload("res://assets/ui/gem.png")
const SECRET_TEX := preload("res://assets/reference/characters/vault_phantom.png")
const DESIGN := Vector2(720, 1100)
var stage: Control
var remaining: Label
var status: Label
var buttons: Array[Button] = []
var done: Button

func _ready() -> void:
	name = "LockerRewards"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var veil := ColorRect.new()
	veil.color = Color(0.02, 0.035, 0.06, 0.86)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(veil)
	stage = Control.new()
	stage.name = "LockerStage"
	stage.size = DESIGN
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stage)
	var panel := Panel.new()
	panel.position = Vector2(18, 78)
	panel.size = Vector2(684, 950)
	panel.add_theme_stylebox_override("panel", _box(Color("172737"), Color("c9983d"), 24, 5))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(panel)
	var key := TextureRect.new()
	key.texture = KEY_TEX
	key.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	key.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	key.position = Vector2(317, 26)
	key.size = Vector2(86, 86)
	key.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(key)
	var title := _label(43, 4)
	title.name = "LockerTitle"
	title.text = "THREE-KEY LOCKERS"
	title.position = Vector2(36, 122)
	title.size = Vector2(648, 64)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stage.add_child(title)
	remaining = _label(25, 2)
	remaining.name = "RemainingPicks"
	remaining.position = Vector2(50, 188)
	remaining.size = Vector2(620, 42)
	remaining.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	remaining.add_theme_color_override("font_color", Color("f6d580"))
	stage.add_child(remaining)
	for index in range(9):
		var card := Button.new()
		card.name = "Locker%d" % index
		card.position = Vector2(75 + (index % 3) * 196, 254 + int(index / 3) * 194)
		card.size = Vector2(178, 176)
		card.focus_mode = Control.FOCUS_ALL
		card.clip_contents = true
		card.add_theme_stylebox_override("normal", _box(Color("274257"), Color("d3ad61"), 15, 4))
		card.add_theme_stylebox_override("hover", _box(Color("365b70"), Color("ffe49b"), 15, 4))
		card.add_theme_stylebox_override("pressed", _box(Color("173746"), Color("ffe49b"), 15, 4))
		card.add_theme_stylebox_override("disabled", _box(Color("25333f"), Color("8f805b"), 15, 4))
		card.pressed.connect(_pick.bind(index))
		stage.add_child(card)
		buttons.append(card)
	status = _label(24, 2)
	status.name = "PrizeMessage"
	status.position = Vector2(48, 840)
	status.size = Vector2(624, 45)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.add_theme_color_override("font_color", Color("e6f5fb"))
	stage.add_child(status)
	done = Button.new()
	done.name = "ContinueButton"
	done.text = "CONTINUE"
	done.position = Vector2(162, 908)
	done.size = Vector2(396, 79)
	done.add_theme_font_override("font", FONT)
	done.add_theme_font_size_override("font_size", 31)
	done.add_theme_color_override("font_color", Color("302009"))
	done.add_theme_stylebox_override("normal", _box(Color("ffcb52"), Color("ffed9c"), 20, 4))
	done.add_theme_stylebox_override("hover", _box(Color("ffe17b"), Color.WHITE, 20, 4))
	done.add_theme_stylebox_override("pressed", _box(Color("e4a530"), Color("ffed9c"), 20, 4))
	done.pressed.connect(_finish)
	stage.add_child(done)
	get_viewport().size_changed.connect(_fit)
	_fit()
	_refresh()

func _box(fill: Color, border: Color, radius: int, width: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(radius)
	return box

func _label(size: int, outline: int) -> Label:
	var label := Label.new()
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_constant_override("outline_size", outline)
	label.add_theme_color_override("font_outline_color", Color("101b23"))
	label.add_theme_color_override("font_color", Color.WHITE)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _fit() -> void:
	var safe := ScreenUtil.safe_rect(get_viewport())
	var s := minf(safe.size.x / DESIGN.x, safe.size.y / DESIGN.y)
	stage.scale = Vector2.ONE * s
	stage.position = safe.position + (safe.size - DESIGN * s) * 0.5

func _opened_prize(index: int) -> Dictionary:
	for prize in GameState.locker_board.get("opened", []):
		if int(prize.index) == index:
			return prize
	return {}

func _refresh() -> void:
	if not GameState.locker_pending():
		return
	var opened: int = GameState.locker_board.opened.size()
	remaining.text = "CHOOSE %d LOCKER%s" % [3-opened, "" if 3-opened == 1 else "S"] if opened < 3 else "ALL THREE LOCKERS OPENED"
	done.visible = opened >= 3
	status.text = "Pick any three — one may hide an assassin" if opened < 3 else "Your rewards are saved"
	for i in range(buttons.size()):
		var card := buttons[i]
		for child in card.get_children():
			child.queue_free()
		var prize := _opened_prize(i)
		card.disabled = not prize.is_empty() or opened >= 3
		var artwork := TextureRect.new()
		artwork.name = "Artwork"
		artwork.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		artwork.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		artwork.mouse_filter = Control.MOUSE_FILTER_IGNORE
		artwork.position = Vector2(32, 18)
		artwork.size = Vector2(114, 106)
		var caption := _label(24, 2)
		caption.name = "Caption"
		caption.position = Vector2(5, 122)
		caption.size = Vector2(168, 36)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if prize.is_empty():
			artwork.texture = KEY_TEX
			caption.text = "LOCKED"
			caption.add_theme_color_override("font_color", Color("ffe19b"))
		elif String(prize.kind) == "character":
			artwork.texture = SECRET_TEX
			caption.text = "ASSASSIN!"
			caption.add_theme_color_override("font_color", Color("ffda73"))
		else:
			artwork.texture = DIAMOND_TEX
			caption.text = "+%d" % int(prize.amount)
			caption.add_theme_color_override("font_color", Color("80e8ff"))
		card.add_child(artwork)
		card.add_child(caption)

func _pick(index: int) -> void:
	var prize: Dictionary = GameState.open_locker(index)
	if prize.is_empty():
		return
	Sfx.play("upgrade" if String(prize.kind) == "character" else "coin")
	_refresh()
	status.text = "VAULT PHANTOM UNLOCKED!" if String(prize.kind) == "character" else "+%d DIAMONDS" % int(prize.amount)

func _finish() -> void:
	if GameState.finish_locker_board():
		completed.emit()
		queue_free()
