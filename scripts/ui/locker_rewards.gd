extends Control
## Nine genuine buttons over a separately designed vault screen. Every prize,
## including its exact character ID, is saved before the card is revealed.
signal completed
const FONT := preload("res://assets/fonts/Baloo2.ttf")
const DIAMOND_TEX := preload("res://assets/ui/gem.png")
const KEY_TEX := preload("res://assets/ui/v72/key.png")
const SECRET_TEX := preload("res://assets/actors/v72/players/elite.png")
const VAULT_BG := preload("res://assets/ui/v72/locker_vault_background.png")
const Choice := preload("res://scripts/game/ten_character_selection.gd")
const DESIGN := Vector2(720, 1280)

# Vector-drawn individual chest: not a screenshot, and not a baked board.
class ChestGlyph extends Control:
	func _draw() -> void:
		var outline := Color("141338")
		draw_colored_polygon(PackedVector2Array([Vector2(8,35),Vector2(18,13),Vector2(112,13),Vector2(122,35),Vector2(122,88),Vector2(8,88)]),outline)
		draw_colored_polygon(PackedVector2Array([Vector2(14,34),Vector2(23,19),Vector2(107,19),Vector2(116,34)]),Color("8965d1"))
		draw_rect(Rect2(14,37,102,44),Color("573d9a"))
		draw_rect(Rect2(19,42,92,10),Color("7556b9"))
		draw_rect(Rect2(14,77,102,5),Color("35275f"))
		draw_rect(Rect2(17,20,9,60),Color("bc97e8"))
		draw_rect(Rect2(104,20,9,60),Color("bc97e8"))
		draw_line(Vector2(24,20),Vector2(105,20),Color("d7bef7"),3.0)
		draw_colored_polygon(PackedVector2Array([Vector2(65,35),Vector2(79,51),Vector2(65,68),Vector2(51,51)]),Color("31d8ea"))
		draw_colored_polygon(PackedVector2Array([Vector2(65,40),Vector2(74,51),Vector2(65,62),Vector2(56,51)]),Color("a0f7f6"))
		draw_circle(Vector2(20,75),2.5,Color("e8dcfa"))
		draw_circle(Vector2(110,75),2.5,Color("e8dcfa"))

var stage: Control
var remaining: Label
var status: Label
var feature_art: TextureRect
var feature_label: Label
var feature_name: Label
var feature_note: Label
var buttons: Array[Button] = []
var used_key_overlays: Array[Control] = []
var done: Button

func _ready() -> void:
	name = "LockerRewards"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := TextureRect.new()
	bg.name = "VaultBackdrop"
	bg.texture = VAULT_BG
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.modulate = Color(0.58, 0.49, 0.92)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var tint := ColorRect.new()
	tint.name = "VaultTint"
	tint.color = Color(0.045, 0.025, 0.13, 0.42)
	tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tint)
	stage = Control.new()
	stage.name = "LockerStage"
	stage.size = DESIGN
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stage)

	var title := _label(53, 3)
	title.name = "VaultTitle"
	title.text = "SPECIAL REWARDS"
	title.position = Vector2(20, 26)
	title.size = Vector2(680, 70)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color("fff3d1"))
	stage.add_child(title)
	var subtitle := _label(22, 1)
	subtitle.text = "THREE KEYS  •  NINE LOCKERS"
	subtitle.position = Vector2(30, 97)
	subtitle.size = Vector2(660, 30)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_color", Color("a9dbe9"))
	stage.add_child(subtitle)

	# The feature is the *actual saved board target*, or diamonds when no
	# Superior target remains. It is never the unrelated reference character.
	var feature := Panel.new()
	feature.name = "FeaturedReward"
	feature.position = Vector2(47, 144)
	feature.size = Vector2(626, 205)
	feature.mouse_filter = Control.MOUSE_FILTER_IGNORE
	feature.add_theme_stylebox_override("panel", _box(Color("27234e"), Color("826cc4"), 24, 3, 7))
	stage.add_child(feature)
	var art_back := Panel.new()
	art_back.position = Vector2(13, 13)
	art_back.size = Vector2(188, 179)
	art_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art_back.add_theme_stylebox_override("panel", _box(Color("171631"), Color("5c619b"), 18, 2))
	feature.add_child(art_back)
	feature_art = _art("FeaturedArtwork", Vector2(20, 17), Vector2(174, 169))
	feature.add_child(feature_art)
	feature_label = _label(21, 1)
	feature_label.name = "FeaturedLabel"
	feature_label.position = Vector2(223, 18)
	feature_label.size = Vector2(385, 30)
	feature_label.add_theme_color_override("font_color", Color("7ae8ef"))
	feature.add_child(feature_label)
	feature_name = _label(37, 2)
	feature_name.name = "FeaturedName"
	feature_name.position = Vector2(220, 50)
	feature_name.size = Vector2(392, 50)
	feature_name.add_theme_color_override("font_color", Color("fff0c5"))
	feature.add_child(feature_name)
	feature_note = _label(20, 1)
	feature_note.name = "FeaturedNote"
	feature_note.position = Vector2(223, 107)
	feature_note.size = Vector2(385, 81)
	feature_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feature_note.add_theme_color_override("font_color", Color("d7daf0"))
	feature.add_child(feature_note)

	var heading := _label(29, 2)
	heading.text = "CHOOSE YOUR LOCKERS"
	heading.position = Vector2(40, 365)
	heading.size = Vector2(640, 42)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stage.add_child(heading)
	for index in range(9):
		var card := Button.new()
		card.name = "Locker%d" % index
		card.tooltip_text = "Open locker %d" % (index + 1)
		card.position = Vector2(45 + (index % 3) * 215, 420 + int(index / 3) * 175)
		card.size = Vector2(200, 155)
		card.focus_mode = Control.FOCUS_ALL
		card.clip_contents = true
		card.set_meta("apex_suppress_ui_tap", true)
		card.add_theme_stylebox_override("normal", _box(Color("252048"), Color("7562ad"), 21, 3, 5))
		card.add_theme_stylebox_override("disabled", _box(Color("1c1937"), Color("524877"), 21, 3, 2))
		card.add_theme_stylebox_override("hover", _box(Color("373060"), Color("a8eff2"), 21, 4, 7))
		card.add_theme_stylebox_override("pressed", _box(Color("433574"), Color("e5fcfd"), 21, 4, 2))
		card.add_theme_stylebox_override("focus", _box(Color(0,0,0,0), Color("b4eff4"), 21, 3))
		card.pressed.connect(_pick.bind(index))
		stage.add_child(card)
		buttons.append(card)

	remaining = _label(29, 2)
	remaining.name = "RemainingPicks"
	remaining.position = Vector2(35, 953)
	remaining.size = Vector2(650, 45)
	remaining.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	remaining.add_theme_color_override("font_color", Color("ffe19a"))
	stage.add_child(remaining)
	for i in range(3):
		var key := _art("Key%d" % i, Vector2(244 + i * 78, 999), Vector2(60, 87))
		stage.add_child(key)
		key.texture = KEY_TEX
		var used := Panel.new()
		used.name = "UsedKey%d" % i
		used.position = Vector2(240 + i * 78, 997)
		used.size = Vector2(68, 92)
		used.mouse_filter = Control.MOUSE_FILTER_IGNORE
		used.add_theme_stylebox_override("panel", _box(Color(0.04, 0.03, 0.09, 0.75), Color(0,0,0,0), 12, 0))
		var used_label := _label(16, 1)
		used_label.text = "USED"
		used_label.position = Vector2(0, 59)
		used_label.size = Vector2(68, 25)
		used_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		used.add_child(used_label)
		stage.add_child(used)
		used_key_overlays.append(used)
	status = _label(24, 1)
	status.name = "PrizeMessage"
	status.position = Vector2(30, 1093)
	status.size = Vector2(660, 56)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.add_theme_color_override("font_color", Color("e9ecff"))
	stage.add_child(status)
	done = Button.new()
	done.name = "ContinueButton"
	done.text = "CONTINUE  ›"
	done.position = Vector2(188, 1163)
	done.size = Vector2(344, 76)
	done.add_theme_font_override("font", FONT)
	done.add_theme_font_size_override("font_size", 34)
	done.add_theme_color_override("font_color", Color("352204"))
	done.add_theme_stylebox_override("normal", _box(Color("ffc548"), Color("fff2a9"), 20, 4, 7))
	done.add_theme_stylebox_override("hover", _box(Color("ffe187"), Color.WHITE, 20, 4, 7))
	done.add_theme_stylebox_override("pressed", _box(Color("d39e37"), Color("ffe59b"), 20, 4, 2))
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
	label.add_theme_color_override("font_outline_color", Color("101025"))
	label.add_theme_color_override("font_color", Color.WHITE)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _art(node_name: String, where: Vector2, dimensions: Vector2) -> TextureRect:
	var artwork := TextureRect.new()
	artwork.name = node_name
	artwork.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	artwork.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	artwork.mouse_filter = Control.MOUSE_FILTER_IGNORE
	artwork.position = where
	artwork.size = dimensions
	return artwork

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

func _reward_id(prize: Dictionary) -> String:
	return String(prize.get("character_id", GameState.VAULT_CHARACTER))

func _character_name(id: String) -> String:
	return String(Choice.LOOK_LABELS.get(id, "Elite" if id == GameState.VAULT_CHARACTER else "Character"))

func _character_art(id: String) -> Texture2D:
	if Choice.SUPERIOR_LOOKS.has(id): return Choice.portrait(id)
	if id == GameState.VAULT_CHARACTER: return SECRET_TEX
	return DIAMOND_TEX

func _refresh_feature() -> void:
	var board: Dictionary = GameState.locker_board
	var legacy := int(board.get("reward_version", 1)) < 2
	var target := GameState.VAULT_CHARACTER if legacy else String(board.get("character_id", ""))
	if int(board.get("character_slot", -1)) < 0 or (not legacy and not Choice.SUPERIOR_LOOKS.has(target)):
		feature_art.texture = DIAMOND_TEX
		feature_label.text = "DIAMOND VAULT"
		feature_name.text = "DIAMONDS"
		feature_note.text = "Every locker contains diamonds.\nAll Superior characters are owned." if not legacy else "Every locker contains diamonds."
		return
	feature_art.texture = _character_art(target)
	feature_label.text = "CLASSIC REWARD" if legacy else "FEATURED SUPERIOR"
	feature_name.text = _character_name(target).to_upper()
	var already_revealed := false
	for prize in board.get("opened", []):
		if String(prize.kind) == "character" and _reward_id(prize) == target: already_revealed = true
	if already_revealed:
		feature_note.text = "Unlocked and saved.\n" + ("Find this character in Superior." if not legacy else "Your Elite reward is preserved.")
	elif (not legacy and GameState.is_superior_unlocked(target)) or (legacy and GameState.is_unlocked(target)):
		feature_note.text = "Already owned.\nDiamonds replace a duplicate."
	else:
		feature_note.text = (Choice.bonus_label(target) + "  •  " if not legacy else "") + "Hidden in one of nine lockers."

func _refresh() -> void:
	if not GameState.locker_ready(): return
	_refresh_feature()
	var opened: int = GameState.locker_board.opened.size()
	remaining.text = "%d OF 3 PICKS REMAINING" % (3 - opened) if opened < 3 else "ALL REWARDS SECURED"
	done.visible = opened >= 3
	status.text = "Choose a locker to reveal your reward" if opened < 3 else "Your rewards are saved"
	for i in range(used_key_overlays.size()): used_key_overlays[i].visible = i < opened
	for i in range(buttons.size()):
		var card := buttons[i]
		for child in card.get_children():
			card.remove_child(child)
			child.queue_free()
		var prize := _opened_prize(i)
		card.disabled = not prize.is_empty() or opened >= 3
		if prize.is_empty():
			var glyph := ChestGlyph.new()
			glyph.name = "LockerArtwork"
			glyph.position = Vector2(35, 12)
			glyph.size = Vector2(130, 95)
			glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
			if opened >= 3: glyph.modulate = Color(0.55, 0.55, 0.65)
			card.add_child(glyph)
			var lock_text := _label(19, 1)
			lock_text.name = "Caption"
			lock_text.text = "LOCKED" if opened >= 3 else "TAP TO OPEN"
			lock_text.position = Vector2(6, 112)
			lock_text.size = Vector2(188, 31)
			lock_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lock_text.add_theme_color_override("font_color", Color("aeb9dd") if opened >= 3 else Color("e3ddf8"))
			card.add_child(lock_text)
			continue
		var reveal := Panel.new()
		reveal.name = "RevealedPrize"
		reveal.position = Vector2(4, 4)
		reveal.size = card.size - Vector2(8, 8)
		reveal.mouse_filter = Control.MOUSE_FILTER_IGNORE
		reveal.add_theme_stylebox_override("panel", _box(Color("302553"), Color("e4b95b"), 18, 3))
		card.add_child(reveal)
		var artwork := _art("Artwork", Vector2(42, 8), Vector2(108, 91))
		var caption := _label(20, 1)
		caption.name = "Caption"
		caption.position = Vector2(4, 102)
		caption.size = Vector2(184, 27)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var sub := _label(15, 1)
		sub.position = Vector2(4, 126)
		sub.size = Vector2(184, 19)
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if String(prize.kind) == "character":
			var id := _reward_id(prize)
			artwork.texture = _character_art(id)
			caption.text = _character_name(id).to_upper()
			caption.add_theme_color_override("font_color", Color("ffe19a"))
			sub.text = "UNLOCKED"
		else:
			artwork.texture = DIAMOND_TEX
			caption.text = "+%d DIAMONDS" % int(prize.amount)
			caption.add_theme_color_override("font_color", Color("91edf4"))
			sub.text = "OWNED BONUS" if prize.has("replacement_for") else "SAVED"
		reveal.add_child(artwork)
		reveal.add_child(caption)
		reveal.add_child(sub)

func _pick(index: int) -> void:
	var prize: Dictionary = GameState.open_locker(index)
	if prize.is_empty(): return
	Sfx.play("unlockkey", -3.0)
	_refresh()
	if String(prize.kind) == "character":
		status.text = _character_name(_reward_id(prize)).to_upper() + " UNLOCKED!"
	elif prize.has("replacement_for"):
		status.text = "ALREADY OWNED  •  +%d DIAMONDS" % int(prize.amount)
	else:
		status.text = "+%d DIAMONDS SAVED" % int(prize.amount)
	var card := buttons[index]
	card.pivot_offset = card.size * 0.5
	card.scale = Vector2.ONE * 0.91
	var tween := create_tween()
	tween.tween_property(card, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _finish() -> void:
	if GameState.finish_locker_board():
		completed.emit()
		queue_free()
