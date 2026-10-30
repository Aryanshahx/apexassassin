extends Control

var bar: ProgressBar

func _ready() -> void:
	var bg := TextureRect.new()
	bg.texture = preload("res://assets/splash/splash.jpg")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

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

	var tween := create_tween()
	tween.tween_property(bar, "value", 100.0, 1.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_interval(0.3)
	tween.tween_callback(func(): get_tree().change_scene_to_file("res://scenes/home/home.tscn"))
