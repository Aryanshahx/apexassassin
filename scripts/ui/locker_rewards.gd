extends Control
## A board is available after three saved keys and a level win. Each of the
## three real picks is awarded and saved before it is displayed.
signal completed
const FONT := preload("res://assets/fonts/Baloo2.ttf")
const DIAMOND_TEX := preload("res://assets/ui/gem.png")
const SECRET_TEX := preload("res://assets/actors/v72/players/elite.png")
# Exact supplied Special Rewards artwork, with live buttons placed on its crates.
const BOARD_ART := preload("res://assets/ui/special-rewards-v2/board-reference.webp")
const DESIGN := Vector2(1109, 1625)
var stage: Control
var remaining: Label
var status: Label
var buttons: Array[Button] = []
var used_key_overlays: Array[Control] = []
var done: Button

func _ready() -> void:
	name = "LockerRewards"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.name = "VaultBackdrop"
	bg.color = Color("101948")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	stage = Control.new()
	stage.name = "LockerStage"
	stage.size = DESIGN
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stage)
	var art := TextureRect.new()
	art.name = "SpecialRewardsReference"
	art.texture = BOARD_ART
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_SCALE
	art.position = Vector2.ZERO
	art.size = Vector2(1109, 1419)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(art)

	# Their hit rectangles follow the nine pictured crates. The default style is
	# empty, keeping the supplied artwork visible; focused/hovered cards outline.
	var xs := [97.0, 410.0, 722.0]
	var ys := [296.0, 589.0, 875.0]
	for index in range(9):
		var card := Button.new()
		card.name = "Locker%d" % index
		card.tooltip_text = "Open locker %d" % (index + 1)
		card.position = Vector2(xs[index % 3], ys[int(index / 3)])
		card.size = Vector2(290, 270)
		card.focus_mode = Control.FOCUS_ALL
		card.clip_contents = true
		card.set_meta("apex_suppress_ui_tap", true)
		card.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		card.add_theme_stylebox_override("disabled", StyleBoxEmpty.new())
		card.add_theme_stylebox_override("hover", _box(Color(1, 1, 1, 0.10), Color("ffffff"), 42, 5))
		card.add_theme_stylebox_override("pressed", _box(Color(1, 0.85, 0.2, 0.18), Color("ffe982"), 42, 5))
		card.add_theme_stylebox_override("focus", _box(Color(0, 0, 0, 0), Color("ffffff"), 42, 5))
		card.pressed.connect(_pick.bind(index))
		stage.add_child(card)
		buttons.append(card)

	# Each of the reference's three keys represents a remaining real pick.
	# Dimming used keys follows the saved board when reopening after interruption.
	for i in range(3):
		var used := Panel.new()
		used.name = "UsedKey%d" % i
		used.position = Vector2(326 + i * 148, 1205)
		used.size = Vector2(144, 170)
		used.add_theme_stylebox_override("panel", _box(Color(0.04, 0.02, 0.11, 0.72), Color(0, 0, 0, 0), 24, 0))
		used.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var label := _label(26, 2)
		label.text = "USED"
		label.position = Vector2(0, 115)
		label.size = Vector2(144, 40)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		used.add_child(label)
		stage.add_child(used)
		used_key_overlays.append(used)

	remaining = _label(37, 3)
	remaining.name = "RemainingPicks"
	remaining.position = Vector2(30, 1423)
	remaining.size = Vector2(1049, 47)
	remaining.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	remaining.add_theme_color_override("font_color", Color("ffe38c"))
	stage.add_child(remaining)
	status = _label(28, 2)
	status.name = "PrizeMessage"
	status.position = Vector2(35, 1470)
	status.size = Vector2(1039, 45)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.add_theme_color_override("font_color", Color.WHITE)
	stage.add_child(status)
	done = Button.new()
	done.name = "ContinueButton"
	done.text = "CONTINUE  ›"
	done.position = Vector2(344, 1528)
	done.size = Vector2(421, 80)
	done.add_theme_font_override("font", FONT)
	done.add_theme_font_size_override("font_size", 38)
	done.add_theme_color_override("font_color", Color("352204"))
	done.add_theme_stylebox_override("normal", _box(Color("ffc548"), Color("fff2a9"), 20, 4, 9))
	done.add_theme_stylebox_override("hover", _box(Color("ffe187"), Color.WHITE, 20, 5, 9))
	done.add_theme_stylebox_override("pressed", _box(Color("d39e37"), Color("ffe59b"), 20, 4, 3))
	done.pressed.connect(_finish)
	stage.add_child(done)
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
	remaining.text = "%d OF 3 PICKS REMAINING" % (3 - opened) if opened < 3 else "ALL REWARDS SECURED"
	done.visible = opened >= 3
	status.text = "Choose a crate to reveal your reward" if opened < 3 else "Your rewards are saved"
	for i in range(used_key_overlays.size()):
		used_key_overlays[i].visible = i < opened
	for i in range(buttons.size()):
		var card := buttons[i]
		for child in card.get_children():
			card.remove_child(child)
			child.queue_free()
		var prize := _opened_prize(i)
		card.disabled = not prize.is_empty() or opened >= 3
		if prize.is_empty():
			if opened >= 3:
				var lock_text := _label(25, 3)
				lock_text.name = "Caption"
				lock_text.text = "LOCKED"
				lock_text.position = Vector2(20, 216)
				lock_text.size = Vector2(250, 38)
				lock_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				card.add_child(lock_text)
			continue
		# Replace only an actually opened crate with its saved prize. Remaining
		# crates are still the exact reference image, not fabricated rewards.
		var reveal := Panel.new()
		reveal.name = "RevealedPrize"
		reveal.position = Vector2(5, 5)
		reveal.size = card.size - Vector2(10, 10)
		reveal.mouse_filter = Control.MOUSE_FILTER_IGNORE
		reveal.add_theme_stylebox_override("panel", _box(Color("301660"), Color("ffdb65"), 39, 7))
		card.add_child(reveal)
		var artwork := TextureRect.new()
		artwork.name = "Artwork"
		artwork.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		artwork.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		artwork.mouse_filter = Control.MOUSE_FILTER_IGNORE
		artwork.position = Vector2(63, 27)
		artwork.size = Vector2(154, 145)
		var caption := _label(26, 3)
		caption.name = "Caption"
		caption.position = Vector2(8, 185)
		caption.size = Vector2(264, 48)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if String(prize.kind) == "character":
			artwork.texture = SECRET_TEX
			caption.text = "ELITE UNLOCKED"
			caption.add_theme_color_override("font_color", Color("ffdf78"))
		else:
			artwork.texture = DIAMOND_TEX
			caption.text = "+%d DIAMONDS" % int(prize.amount)
			caption.add_theme_color_override("font_color", Color("93eaff"))
		reveal.add_child(artwork)
		reveal.add_child(caption)

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
