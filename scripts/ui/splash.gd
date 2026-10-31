extends Control

# Keep the existing splash art; only the two baked labels are locally replaced.
const IMAGE_SIZE := Vector2(720, 1280)
const LOADING_PATCH_RECT := Rect2(235, 1118, 250, 60)
const PUBLISHER_PATCH_RECT := Rect2(270, 1218, 180, 52)
var bar: ProgressBar
var bg: TextureRect
var loading_patch: TextureRect
var publisher_patch: TextureRect
var safe := Rect2()

func _ready() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color("041127")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	bg = TextureRect.new()
	bg.texture = preload("res://assets/splash/splash.jpg")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	loading_patch = _make_patch("LoadingTextPatch", preload("res://assets/splash/loading_v61.png"))
	publisher_patch = _make_patch("PublisherTextPatch", preload("res://assets/splash/publisher_v61.png"))

	bar = ProgressBar.new()
	bar.position = Vector2(180, 1180)
	bar.size = Vector2(360, 26)
	bar.max_value = 100
	bar.value = 0
	bar.show_percentage = false
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.08, 0.09, 0.14, 0.9)
	bg_style.set_corner_radius_all(13)
	bg_style.set_border_width_all(3)
	bg_style.border_color = Color("2b2410")
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("ffd23f")
	fill.set_corner_radius_all(13)
	bar.add_theme_stylebox_override("background", bg_style)
	bar.add_theme_stylebox_override("fill", fill)
	add_child(bar)
	get_viewport().size_changed.connect(_fit)
	_fit()

	var tween := create_tween()
	tween.tween_property(bar, "value", 100.0, 1.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_interval(0.3)
	tween.tween_callback(func(): get_tree().change_scene_to_file("res://scenes/home/home.tscn"))

func _make_patch(node_name: String, texture: Texture2D) -> TextureRect:
	var patch := TextureRect.new()
	patch.name = node_name
	patch.texture = texture
	patch.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	patch.stretch_mode = TextureRect.STRETCH_SCALE
	patch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(patch)
	return patch

func _fit() -> void:
	# Preserve the old full-bleed art on phones; on wider tablets use a
	# letterboxed fit so the requested bottom text is not cropped away.
	# Both replacement patches use the same transform as the background.
	var vp := get_viewport_rect().size
	var cover := vp.x / maxf(vp.y, 1.0) <= (IMAGE_SIZE.x / IMAGE_SIZE.y) * 1.10
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED if cover else TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var factor := maxf(vp.x / IMAGE_SIZE.x, vp.y / IMAGE_SIZE.y) if cover else minf(vp.x / IMAGE_SIZE.x, vp.y / IMAGE_SIZE.y)
	var origin := (vp - IMAGE_SIZE * factor) * 0.5
	loading_patch.position = origin + LOADING_PATCH_RECT.position * factor
	loading_patch.size = LOADING_PATCH_RECT.size * factor
	publisher_patch.position = origin + PUBLISHER_PATCH_RECT.position * factor
	publisher_patch.size = PUBLISHER_PATCH_RECT.size * factor
	var r := ScreenUtil.safe_rect(get_viewport())
	var w := minf(360.0, r.size.x * 0.65)
	bar.size = Vector2(w, 26)
	bar.position = Vector2(r.position.x + (r.size.x - w) * 0.5, r.end.y - 96)
