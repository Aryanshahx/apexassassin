extends Control
## Three saved keys queue a board; only a level win makes it available. Each
## pick is awarded and saved before its artwork is revealed.
signal completed
const FONT := preload("res://assets/fonts/Baloo2.ttf")
const KEY_TEX := preload("res://assets/ui/v72/key.png")
const DIAMOND_TEX := preload("res://assets/ui/gem.png")
const SECRET_TEX := preload("res://assets/actors/v72/players/elite.png")
const BACKDROP := preload("res://assets/ui/v72/locker_vault_background.png")
const DESIGN := Vector2(720, 1280)
var stage: Control
var remaining: Label
var status: Label
var buttons: Array[Button] = []
var done: Button

func _ready() -> void:
	name = "LockerRewards"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := TextureRect.new()
	bg.name = "VaultBackdrop"
	bg.texture = BACKDROP
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var veil := ColorRect.new()
	veil.color = Color(0.01, 0.025, 0.045, 0.26)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(veil)
	stage = Control.new()
	stage.name = "LockerStage"
	stage.size = DESIGN
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stage)

	var eyebrow := _label(22, 2)
	eyebrow.text = "THREE KEYS  •  THREE CHANCES"
	eyebrow.position = Vector2(20, 61)
	eyebrow.size = Vector2(680, 35)
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	eyebrow.add_theme_color_override("font_color", Color("edc878"))
	stage.add_child(eyebrow)
	var title := _label(62, 5)
	title.name = "LockerTitle"
	title.text = "THE VAULT"
	title.position = Vector2(40, 91)
	title.size = Vector2(640, 82)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color("fff4d2"))
	stage.add_child(title)
	var key := TextureRect.new()
	key.name = "KeyArtwork"
	key.texture = KEY_TEX
	key.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	key.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	key.position = Vector2(322, 173)
	key.size = Vector2(76, 88)
	key.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(key)
	var panel := Panel.new()
	panel.name = "VaultPanel"
	panel.position = Vector2(29, 267)
	panel.size = Vector2(662, 743)
	panel.add_theme_stylebox_override("panel", _box(Color(0.025,0.055,0.075,0.94), Color("b89148"), 23, 3, 20))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(panel)
	remaining = _label(27, 2)
	remaining.name = "RemainingPicks"
	remaining.position = Vector2(65, 280)
	remaining.size = Vector2(590, 44)
	remaining.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	remaining.add_theme_color_override("font_color", Color("f8d78a"))
	stage.add_child(remaining)
	for index in range(9):
		var card := Button.new()
		card.name = "Locker%d" % index
		card.position = Vector2(68 + (index % 3) * 198, 338 + int(index / 3) * 216)
		card.size = Vector2(186, 202)
		card.focus_mode = Control.FOCUS_ALL
		card.clip_contents = true
		card.add_theme_stylebox_override("normal", _box(Color("1a3040"), Color("c49d55"), 14, 3, 7))
		card.add_theme_stylebox_override("hover", _box(Color("274b59"), Color("ffe3a1"), 14, 4, 7))
		card.add_theme_stylebox_override("pressed", _box(Color("142936"), Color("ffde82"), 14, 4, 3))
		card.add_theme_stylebox_override("disabled", _box(Color("192c38"), Color("7d7055"), 14, 3, 4))
		card.pressed.connect(_pick.bind(index))
		stage.add_child(card)
		buttons.append(card)
	status = _label(26, 2)
	status.name = "PrizeMessage"
	status.position = Vector2(30, 1024)
	status.size = Vector2(660, 48)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.add_theme_color_override("font_color", Color("f9e2aa"))
	stage.add_child(status)
	done = Button.new()
	done.name = "ContinueButton"
	done.text = "CONTINUE  ›"
	done.position = Vector2(162, 1091)
	done.size = Vector2(396, 84)
	done.add_theme_font_override("font", FONT)
	done.add_theme_font_size_override("font_size", 32)
	done.add_theme_color_override("font_color", Color("352204"))
	done.add_theme_stylebox_override("normal", _box(Color("f6c55d"), Color("ffebaa"), 19, 3, 9))
	done.add_theme_stylebox_override("hover", _box(Color("ffe187"), Color.WHITE, 19, 4, 9))
	done.add_theme_stylebox_override("pressed", _box(Color("d39e37"), Color("ffe59b"), 19, 3, 3))
	done.pressed.connect(_finish)
	stage.add_child(done)
	var footer := _label(19, 1)
	footer.text = "EVERY REWARD IS SAVED INSTANTLY"
	footer.position = Vector2(20, 1203)
	footer.size = Vector2(680, 32)
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.add_theme_color_override("font_color", Color("abc0c6"))
	stage.add_child(footer)
	get_viewport().size_changed.connect(_fit)
	_fit()
	_refresh()

func _box(fill: Color, border: Color, radius: int, width: int, shadow := 0) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(radius)
	box.shadow_color = Color(0, 0, 0, 0.42)
	box.shadow_size = shadow
	box.shadow_offset = Vector2(0, 4)
	return box

func _label(size: int, outline: int) -> Label:
	var label := Label.new()
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_constant_override("outline_size", outline)
	label.add_theme_color_override("font_outline_color", Color("09131c"))
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
	if not GameState.locker_ready():
		return
	var opened: int = GameState.locker_board.opened.size()
	remaining.text = "%d OF 3 PICKS REMAINING" % (3-opened) if opened < 3 else "ALL REWARDS SECURED"
	done.visible = opened >= 3
	status.text = "Choose a locker to reveal your reward" if opened < 3 else "Your rewards are saved"
	for i in range(buttons.size()):
		var card := buttons[i]
		for child in card.get_children():
			card.remove_child(child)
			child.queue_free()
		var prize := _opened_prize(i)
		card.disabled = not prize.is_empty() or opened >= 3
		var number := _label(19, 1)
		number.name = "Number"
		number.text = "%02d" % (i + 1)
		number.position = Vector2(11, 7)
		number.size = Vector2(45, 28)
		number.add_theme_color_override("font_color", Color("a8b7bc"))
		card.add_child(number)
		var artwork := TextureRect.new()
		artwork.name = "Artwork"
		artwork.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		artwork.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		artwork.mouse_filter = Control.MOUSE_FILTER_IGNORE
		artwork.position = Vector2(30, 35)
		artwork.size = Vector2(126, 107)
		var caption := _label(20, 2)
		caption.name = "Caption"
		caption.position = Vector2(4, 153)
		caption.size = Vector2(178, 34)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if prize.is_empty():
			artwork.texture = KEY_TEX
			caption.text = "TAP TO OPEN" if opened < 3 else "LOCKED"
			caption.add_theme_color_override("font_color", Color("ffe19b"))
		elif String(prize.kind) == "character":
			artwork.texture = SECRET_TEX
			caption.text = "ELITE UNLOCKED"
			caption.add_theme_color_override("font_color", Color("ffda73"))
		else:
			artwork.texture = DIAMOND_TEX
			caption.text = "+%d DIAMONDS" % int(prize.amount)
			caption.add_theme_color_override("font_color", Color("80e8ff"))
		card.add_child(artwork)
		card.add_child(caption)

func _pick(index: int) -> void:
	var prize: Dictionary = GameState.open_locker(index)
	if prize.is_empty():
		return
	Sfx.play("unlockkey", -3.0)
	_refresh()
	status.text = "ELITE UNLOCKED!" if String(prize.kind) == "character" else "+%d DIAMONDS" % int(prize.amount)
	var card := buttons[index]
	card.pivot_offset = card.size * 0.5
	card.scale = Vector2.ONE * 0.91
	var tween := create_tween()
	tween.tween_property(card, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _finish() -> void:
	if GameState.finish_locker_board():
		completed.emit()
		queue_free()
