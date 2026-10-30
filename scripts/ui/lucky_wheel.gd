extends Control
## Lucky Wheel overlay: a real spinning 8-segment wheel. The wheel decelerates and
## lands the winning segment under the pointer, then the prize is claimed once.

signal closed

const FONT := preload("res://assets/fonts/Baloo2.ttf")
const SEG_COLORS := [
	Color("e63946"), Color("1f6fb2"), Color("ff9d2e"), Color("6a3a9f"),
	Color("4caf20"), Color("20c7c9"), Color("d7a54a"), Color("9a45ee"),
]
const RADIUS := 232.0

var dial: Control
var pointer: Control
var spin_btn: Button
var result_lbl: Label
var note_lbl: Label
var angle := 0.0
var spinning := false
var win_index := 0
var prize_gems := 0
var prize_cash := 0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.08, 0.88)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var safe := ScreenUtil.safe_rect(get_viewport())
	var center := CenterContainer.new()
	center.position = safe.position
	center.size = safe.size
	add_child(center)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _box(Color("1b2f8a"), Color("0d1440"), 24, 4))
	center.add_child(panel)
	var m := MarginContainer.new()
	for side in ["left", "right"]:
		m.add_theme_constant_override("margin_" + side, 22)
	m.add_theme_constant_override("margin_top", 18)
	m.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(m)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	m.add_child(box)

	var title := _label(40, 5)
	title.text = "Lucky Wheel"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var wheel_wrap := Control.new()
	wheel_wrap.custom_minimum_size = Vector2(RADIUS * 2 + 40, RADIUS * 2 + 40)
	box.add_child(wheel_wrap)
	dial = Control.new()
	dial.position = wheel_wrap.custom_minimum_size * 0.5
	dial.draw.connect(_draw_dial)
	wheel_wrap.add_child(dial)
	pointer = Control.new()
	pointer.position = wheel_wrap.custom_minimum_size * 0.5
	pointer.draw.connect(_draw_pointer)
	wheel_wrap.add_child(pointer)

	result_lbl = _label(32, 5)
	result_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_lbl.custom_minimum_size = Vector2(0, 46)
	result_lbl.add_theme_color_override("font_color", Color("ffe23f"))
	box.add_child(result_lbl)

	spin_btn = Button.new()
	spin_btn.text = "SPIN"
	spin_btn.custom_minimum_size = Vector2(300, 68)
	spin_btn.add_theme_stylebox_override("normal", _box(Color("ffc93c"), Color("6b4a00"), 16, 4))
	spin_btn.add_theme_stylebox_override("hover", _box(Color("ffd76a"), Color("6b4a00"), 16, 4))
	spin_btn.add_theme_stylebox_override("disabled", _box(Color("6a6d85"), Color("23252e"), 16, 4))
	spin_btn.add_theme_font_override("font", FONT)
	spin_btn.add_theme_font_size_override("font_size", 32)
	spin_btn.add_theme_color_override("font_color", Color("14161f"))
	spin_btn.pressed.connect(_spin)
	box.add_child(spin_btn)

	note_lbl = _label(22, 3)
	note_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note_lbl.custom_minimum_size = Vector2(420, 44)
	box.add_child(note_lbl)

	var close := Button.new()
	close.text = "Close"
	close.custom_minimum_size = Vector2(300, 56)
	close.add_theme_stylebox_override("normal", _box(Color("e63946"), Color("7a1020"), 14, 3))
	close.add_theme_font_override("font", FONT)
	close.add_theme_font_size_override("font_size", 26)
	close.pressed.connect(func(): closed.emit(); queue_free())
	box.add_child(close)

	_refresh_state()

func _refresh_state() -> void:
	if GameState.can_spin_wheel():
		spin_btn.disabled = false
		spin_btn.text = "SPIN"
		note_lbl.text = "One free spin every day."
		result_lbl.text = ""
	else:
		spin_btn.disabled = true
		spin_btn.text = "COME BACK TOMORROW"
		note_lbl.text = "Today's spin is used. A new spin unlocks tomorrow."

func _spin() -> void:
	if spinning or not GameState.can_spin_wheel():
		return
	spinning = true
	spin_btn.disabled = true
	result_lbl.text = ""
	note_lbl.text = "Spinning..."
	win_index = GameState.roll_wheel()
	# Land segment centre under the top pointer after 4 full turns.
	var seg := TAU / float(GameState.WHEEL_PRIZES.size())
	var target := TAU * 4.0 + (TAU - (float(win_index) + 0.5) * seg)
	var start := angle
	Sfx.play("upgrade")
	var tw := create_tween()
	tw.tween_method(func(v: float):
		angle = v
		dial.queue_redraw(), start, start + target, 3.4)\
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.tween_callback(_landed)

func _landed() -> void:
	spinning = false
	angle = fmod(angle, TAU)
	var prize := GameState.claim_wheel(win_index)
	if prize.is_empty():
		_refresh_state()
		return
	var amount := int(prize.amount)
	if String(prize.kind) == "gems":
		prize_gems = amount
		result_lbl.text = "+%d GEMS!" % amount
	else:
		prize_cash = amount
		result_lbl.text = "+%d CASH!" % amount
	Sfx.play("win")
	GameState.vibrate(30)
	spin_btn.text = "COME BACK TOMORROW"
	spin_btn.disabled = true
	note_lbl.text = "Prize added to your balance. New spin tomorrow!"

func _draw_dial() -> void:
	var n := GameState.WHEEL_PRIZES.size()
	var seg := TAU / float(n)
	# Rim
	dial.draw_circle(Vector2.ZERO, RADIUS + 14, Color("0d1440"))
	dial.draw_circle(Vector2.ZERO, RADIUS + 8, Color("ffd23f"))
	for i in range(n):
		var a0 := angle + i * seg - PI / 2.0
		var a1 := a0 + seg
		var pts := PackedVector2Array([Vector2.ZERO])
		var steps := 18
		for s in range(steps + 1):
			pts.append(Vector2.from_angle(a0 + (a1 - a0) * float(s) / steps) * RADIUS)
		dial.draw_colored_polygon(pts, SEG_COLORS[i % SEG_COLORS.size()])
		dial.draw_line(Vector2.ZERO, Vector2.from_angle(a0) * RADIUS, Color("0d1440"), 3.0)
		# Prize label along the segment centre.
		var mid := a0 + seg * 0.5
		var p: Dictionary = GameState.WHEEL_PRIZES[i]
		var txt := str(int(p.amount))
		var fv := FontVariation.new()
		fv.base_font = FONT
		fv.variation_embolden = 0.8
		var fs := 30
		var w := fv.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var tp := Vector2.from_angle(mid) * (RADIUS * 0.66)
		# Flip labels on the far half so no number ever reads upside-down.
		var text_rot := mid + PI / 2.0
		var wrapped := fposmod(mid + PI / 2.0, TAU)
		if wrapped > PI / 2.0 and wrapped < PI * 1.5:
			text_rot += PI
		dial.draw_set_transform(tp, text_rot, Vector2.ONE)
		dial.draw_string_outline(fv, Vector2(-w * 0.5, 0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, Color("101218"))
		dial.draw_string(fv, Vector2(-w * 0.5, 0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
		# Small gem / cash marker under the number.
		var mark := Color("7fd7ff") if String(p.kind) == "gems" else Color("7CFC7C")
		dial.draw_circle(Vector2(0, 22), 8, mark)
		dial.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	dial.draw_circle(Vector2.ZERO, 42, Color("0d1440"))
	dial.draw_circle(Vector2.ZERO, 34, Color("ffd23f"))
	dial.draw_circle(Vector2.ZERO, 22, Color("e63946"))

func _draw_pointer() -> void:
	var tip := Vector2(0, -RADIUS + 6)
	var pts := PackedVector2Array([tip, Vector2(-22, -RADIUS - 40), Vector2(22, -RADIUS - 40)])
	pointer.draw_colored_polygon(pts, Color("ffffff"))
	pointer.draw_polyline(pts + PackedVector2Array([tip]), Color("101218"), 4.0)

func _label(size: int, outline: int) -> Label:
	var l := Label.new()
	var fv := FontVariation.new()
	fv.base_font = FONT
	fv.variation_embolden = 0.7
	l.add_theme_font_override("font", fv)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_constant_override("outline_size", outline)
	l.add_theme_color_override("font_outline_color", Color("101218"))
	l.add_theme_color_override("font_color", Color.WHITE)
	return l

func _box(bg: Color, border: Color, radius: int, bw: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	return s
