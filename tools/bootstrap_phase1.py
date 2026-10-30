#!/usr/bin/env python3
from __future__ import annotations
import json, random, shutil, time
from pathlib import Path

ROOT = Path.cwd()
STAMP = time.strftime('%Y%m%d-%H%M%S')
BACKUP = ROOT / '.apex-backup' / STAMP

def write(rel: str, text: str):
    p = ROOT / rel
    p.parent.mkdir(parents=True, exist_ok=True)
    if p.exists():
        b = BACKUP / rel
        b.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(p, b)
    p.write_text(text.strip() + '\n', encoding='utf-8')

def mkdirs():
    for d in [
        'assets/ui','assets/splash','assets/home','assets/level','assets/audio',
        'scenes/splash','scenes/home','scenes/level',
        'scripts/ui','scripts/game','scripts/data',
        'data/levels','tools','.github/workflows'
    ]:
        (ROOT / d).mkdir(parents=True, exist_ok=True)

mkdirs()

write('project.godot', '''
; Apex Assassin — Godot 4.7.2
config_version=5

[application]
config/name="Apex Assassin"
config/version="0.1.0"
run/main_scene="res://scenes/splash/splash.tscn"
config/features=PackedStringArray("4.7", "GL Compatibility")
boot_splash/bg_color=Color(0.04, 0.06, 0.12, 1)
config/icon="res://assets/ui/icon.svg"
config/quit_on_go_back=false

[autoload]
GameState="*res://scripts/game/game_state.gd"

[display]
window/size/viewport_width=720
window/size/viewport_height=1280
window/size/window_width_override=450
window/size/window_height_override=800
window/stretch/mode="canvas_items"
window/stretch/aspect="expand"
window/handheld/orientation=1

[input_devices]
pointing/emulate_mouse_from_touch=true
pointing/emulate_touch_from_mouse=false

[rendering]
renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
environment/defaults/default_clear_color=Color(0.04, 0.06, 0.12, 1)

[physics]
common/physics_ticks_per_second=60
''')

write('assets/ui/icon.svg', '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 128 128"><rect width="128" height="128" rx="28" fill="#101828"/><path d="M64 18 98 38v34c0 22-18 34-34 38-16-4-34-16-34-38V38Z" fill="#59efc0"/><path d="M44 56h40l-6 18H50Z" fill="#101828"/><path d="M52 62h24" stroke="#e8fff6" stroke-width="5"/></svg>
''')

write('scripts/game/game_state.gd', '''
extends Node

var gems: int = 0
var cash: int = 119
var current_level: int = 1
var unlocked_level: int = 1
var total_levels: int = 100

func start_level(level: int) -> void:
    current_level = clampi(level, 1, total_levels)
    get_tree().change_scene_to_file("res://scenes/level/level.tscn")

func complete_level() -> void:
    unlocked_level = maxi(unlocked_level, mini(current_level + 1, total_levels))
    cash += 50 + current_level * 5
    get_tree().change_scene_to_file("res://scenes/home/home.tscn")
''')

write('scenes/splash/splash.tscn', '''
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/ui/splash.gd" id="1"]

[node name="Splash" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
script = ExtResource("1")
''')

write('scripts/ui/splash.gd', '''
extends Control

var bar: ProgressBar

func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var bg := ColorRect.new()
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    bg.color = Color("101a33")
    add_child(bg)

    var center := VBoxContainer.new()
    center.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
    center.grow_horizontal = Control.GROW_DIRECTION_BOTH
    center.grow_vertical = Control.GROW_DIRECTION_BOTH
    center.add_theme_constant_override("separation", 18)
    add_child(center)

    var title := Label.new()
    title.text = "APEX"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 92)
    title.add_theme_color_override("font_color", Color("ff5a5f"))
    title.add_theme_color_override("font_outline_color", Color("2b0b12"))
    title.add_theme_constant_override("outline_size", 12)
    center.add_child(title)

    var subtitle := Label.new()
    subtitle.text = "ASSASSIN"
    subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    subtitle.add_theme_font_size_override("font_size", 64)
    subtitle.add_theme_color_override("font_outline_color", Color("2b0b12"))
    subtitle.add_theme_constant_override("outline_size", 10)
    center.add_child(subtitle)

    var tag := Label.new()
    tag.text = "STAY UNSEEN. STRIKE FIRST."
    tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    tag.add_theme_font_size_override("font_size", 20)
    tag.add_theme_color_override("font_color", Color("9fb4d8"))
    center.add_child(tag)

    bar = ProgressBar.new()
    bar.custom_minimum_size = Vector2(420, 26)
    bar.max_value = 100
    bar.value = 0
    bar.show_percentage = false
    center.add_child(bar)

    var status := Label.new()
    status.text = "Loading Assets"
    status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    status.add_theme_font_size_override("font_size", 20)
    center.add_child(status)

    var tween := create_tween()
    tween.tween_property(bar, "value", 100.0, 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    tween.tween_interval(0.25)
    tween.tween_callback(func(): get_tree().change_scene_to_file("res://scenes/home/home.tscn"))
''')

write('scenes/home/home.tscn', '''
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/ui/home.gd" id="1"]

[node name="Home" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
script = ExtResource("1")
''')

write('scripts/ui/home.gd', '''
extends Control

func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var bg := ColorRect.new()
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    bg.color = Color("2a3145")
    add_child(bg)

    var root := VBoxContainer.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.offset_left = 28
    root.offset_right = -28
    root.offset_top = 28
    root.offset_bottom = -28
    root.add_theme_constant_override("separation", 18)
    add_child(root)

    root.add_child(_top_bar())
    root.add_child(_spacer(24))
    root.add_child(_action_cards())
    root.add_child(_mission_card("Eliminate 30 targets", "0 / 30", "Prize 150"))
    root.add_child(_mission_card("Complete a level with no damage", "Not completed", "Prize 200"))
    root.add_child(_spacer(0))
    root.add_child(_start_button())

func _top_bar() -> Control:
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 14)
    row.add_child(_pill("GEMS  %d" % GameState.gems, Color("3a1f2b"), Color("ff6b81")))
    row.add_child(_pill("CASH  %d" % GameState.cash, Color("173324"), Color("7CFC7C")))
    var spacer := Control.new()
    spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(spacer)
    var settings := _small_button("Settings")
    row.add_child(settings)
    return row

func _action_cards() -> Control:
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 16)
    var change := _big_card("Change\\nAssassin", Color("8e3df0"))
    change.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    change.size_flags_stretch_ratio = 2.0
    row.add_child(change)
    var upgrade := _big_card("Upgrade", Color("8e3df0"))
    upgrade.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(upgrade)
    return row

func _mission_card(title: String, progress: String, prize: String) -> Control:
    var panel := PanelContainer.new()
    panel.add_theme_stylebox_override("panel", _box(Color("5c6079"), Color("20263a"), 14))
    var margin := MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 18)
    margin.add_theme_constant_override("margin_right", 18)
    margin.add_theme_constant_override("margin_top", 14)
    margin.add_theme_constant_override("margin_bottom", 14)
    panel.add_child(margin)
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 14)
    margin.add_child(row)
    var text := VBoxContainer.new()
    text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var t := Label.new()
    t.text = title
    t.add_theme_font_size_override("font_size", 26)
    t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    text.add_child(t)
    var p := Label.new()
    p.text = progress
    p.add_theme_font_size_override("font_size", 22)
    text.add_child(p)
    row.add_child(text)
    var prize_label := Label.new()
    prize_label.text = prize
    prize_label.add_theme_font_size_override("font_size", 24)
    prize_label.add_theme_color_override("font_color", Color("7CFC7C"))
    row.add_child(prize_label)
    return panel

func _start_button() -> Control:
    var btn := Button.new()
    btn.text = "Start Game\\nLevel %d" % GameState.current_level
    btn.custom_minimum_size = Vector2(0, 110)
    btn.add_theme_font_size_override("font_size", 34)
    btn.add_theme_color_override("font_color", Color("4a2b00"))
    btn.add_theme_stylebox_override("normal", _box(Color("ffc93c"), Color("7a4b00"), 18))
    btn.add_theme_stylebox_override("hover", _box(Color("ffd76a"), Color("7a4b00"), 18))
    btn.add_theme_stylebox_override("pressed", _box(Color("e0a800"), Color("7a4b00"), 18))
    btn.pressed.connect(func(): GameState.start_level(GameState.current_level))
    return btn

func _pill(text: String, bg: Color, fg: Color) -> Control:
    var panel := PanelContainer.new()
    panel.add_theme_stylebox_override("panel", _box(bg, fg.darkened(0.4), 12))
    var label := Label.new()
    label.text = text
    label.add_theme_font_size_override("font_size", 24)
    label.add_theme_color_override("font_color", fg)
    panel.add_child(label)
    return panel

func _big_card(text: String, color: Color) -> Control:
    var btn := Button.new()
    btn.text = text
    btn.custom_minimum_size = Vector2(0, 140)
    btn.add_theme_font_size_override("font_size", 30)
    btn.add_theme_stylebox_override("normal", _box(color, Color("2b0b50"), 18))
    btn.add_theme_stylebox_override("hover", _box(color.lightened(0.1), Color("2b0b50"), 18))
    btn.add_theme_stylebox_override("pressed", _box(color.darkened(0.1), Color("2b0b50"), 18))
    return btn

func _small_button(text: String) -> Button:
    var btn := Button.new()
    btn.text = text
    btn.custom_minimum_size = Vector2(120, 54)
    btn.add_theme_font_size_override("font_size", 20)
    btn.add_theme_stylebox_override("normal", _box(Color("4a5168"), Color("20263a"), 12))
    return btn

func _spacer(height: int) -> Control:
    var c := Control.new()
    c.custom_minimum_size = Vector2(0, height)
    c.size_flags_vertical = Control.SIZE_EXPAND_FILL if height == 0 else Control.SIZE_SHRINK_BEGIN
    return c

func _box(bg: Color, border: Color, radius: int) -> StyleBoxFlat:
    var s := StyleBoxFlat.new()
    s.bg_color = bg
    s.border_color = border
    s.set_border_width_all(3)
    s.set_corner_radius_all(radius)
    s.content_margin_left = 16
    s.content_margin_right = 16
    s.content_margin_top = 10
    s.content_margin_bottom = 10
    return s
''')

write('scenes/level/level.tscn', '''
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/game/level.gd" id="1"]

[node name="Level" type="Node2D"]
script = ExtResource("1")
''')

write('scripts/game/level.gd', '''
extends Node2D

var level_data: Dictionary = {}
var player_pos := Vector2.ZERO
var target_label: Label

func _ready() -> void:
    _load_level(GameState.current_level)
    _build_hud()
    queue_redraw()

func _load_level(level: int) -> void:
    var file := FileAccess.open("res://data/levels/levels.json", FileAccess.READ)
    if file == null:
        push_error("Missing levels.json")
        return
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if parsed is Dictionary and parsed.has("levels"):
        var levels: Array = parsed.levels
        level_data = levels[clampi(level - 1, 0, levels.size() - 1)]
    player_pos = Vector2(360, 1000)

func _build_hud() -> void:
    var canvas := CanvasLayer.new()
    add_child(canvas)
    var hud := Control.new()
    hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
    canvas.add_child(hud)

    target_label = Label.new()
    target_label.text = "0 / %d" % int(level_data.get("guards", []).size())
    target_label.position = Vector2(28, 28)
    target_label.add_theme_font_size_override("font_size", 44)
    target_label.add_theme_color_override("font_outline_color", Color.BLACK)
    target_label.add_theme_constant_override("outline_size", 8)
    hud.add_child(target_label)

    var back := Button.new()
    back.text = "Pause / Back"
    back.position = Vector2(520, 28)
    back.custom_minimum_size = Vector2(170, 56)
    back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/home/home.tscn"))
    hud.add_child(back)

func _draw() -> void:
    var floor_rect := Rect2(24, 120, 672, 1040)
    draw_rect(floor_rect, Color("6f7488"))
    draw_rect(floor_rect, Color("20263a"), false, 4.0)
    for crate: Variant in level_data.get("crates", []):
        var r := Rect2(float(crate[0]) * 32.0 + 24.0, float(crate[1]) * 32.0 + 120.0, float(crate[2]) * 32.0, float(crate[3]) * 32.0)
        draw_rect(r, Color("3d6f8e"))
        draw_rect(r, Color("17334a"), false, 3.0)
    for guard: Variant in level_data.get("guards", []):
        var p := Vector2(float(guard["x"]) * 32.0 + 40.0, float(guard["y"]) * 32.0 + 136.0)
        draw_circle(p, 14, Color("d98c4a"))
    draw_circle(player_pos, 16, Color("59efc0"))

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        player_pos = event.position
        queue_redraw()
''')

write('tools/generate_levels.py', '''
#!/usr/bin/env python3
import json, random
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
levels = []
for i in range(1, 101):
    rng = random.Random(4700 + i)
    crates = []
    for _ in range(6 + min(10, i // 8)):
        w = rng.choice([1, 2, 3])
        h = rng.choice([1, 2, 3])
        x = rng.randint(2, 18 - w)
        y = rng.randint(3, 26 - h)
        crates.append([x, y, w, h])
    guards = []
    count = min(10, 3 + i // 12)
    for g in range(count):
        guards.append({"x": rng.randint(3, 17), "y": rng.randint(4, 24), "type": "elite" if i > 20 and g == 0 else "normal"})
    levels.append({
        "id": i,
        "name": f"Contract {i:03d}",
        "width": 21,
        "height": 30,
        "spawn": [10, 28],
        "exit": [10, 1],
        "crates": crates,
        "guards": guards,
        "reward_cash": 50 + i * 5
    })
(ROOT / "data/levels").mkdir(parents=True, exist_ok=True)
(ROOT / "data/levels/levels.json").write_text(json.dumps({"schema": 1, "levels": levels}, indent=2))
print("Generated", len(levels), "levels")
''')

write('.github/workflows/android.yml', '''
name: Android APK

on:
  workflow_dispatch:
  push:
    branches: [main]
  pull_request:
    branches: [main]

permissions:
  contents: read

env:
  GODOT_VERSION: "4.7.2"
  GODOT_RELEASE: stable

jobs:
  apk:
    name: Build debug APK
    runs-on: ubuntu-24.04
    timeout-minutes: 45
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: "17"
      - name: Install Android SDK packages
        run: |
          set -euo pipefail
          yes | sdkmanager --licenses >/dev/null 2>&1 || true
          sdkmanager "platform-tools" "platforms;android-35" "platforms;android-36" "build-tools;35.0.1" "build-tools;36.0.0"
      - name: Export debug APK
        run: |
          set -euo pipefail
          VERSION="${GODOT_VERSION}-${GODOT_RELEASE}"
          TPL="$HOME/.local/share/godot/export_templates/${GODOT_VERSION}.${GODOT_RELEASE}"
          mkdir -p "$TPL" "$HOME/.android" "$HOME/.config/godot" .ci build/android
          curl -fL --retry 3 "https://github.com/godotengine/godot/releases/download/${VERSION}/Godot_v${VERSION}_linux.x86_64.zip" -o .ci/godot.zip
          unzip -q -o .ci/godot.zip -d .ci
          GODOT=".ci/Godot_v${VERSION}_linux.x86_64"
          chmod +x "$GODOT"
          if [ ! -f "$TPL/android_debug.apk" ]; then
            curl -fL --retry 3 "https://github.com/godotengine/godot/releases/download/${VERSION}/Godot_v${VERSION}_export_templates.tpz" -o .ci/templates.tpz
            unzip -q -o .ci/templates.tpz -d "$TPL"
            if [ -d "$TPL/templates" ]; then mv "$TPL/templates"/* "$TPL"/; rmdir "$TPL/templates"; fi
          fi
          DEBUG_KEYSTORE="$HOME/.android/debug.keystore"
          if [ ! -f "$DEBUG_KEYSTORE" ]; then
            keytool -genkeypair -keystore "$DEBUG_KEYSTORE" -storepass android -keypass android -alias androiddebugkey -dname "CN=Android Debug,O=Android,C=US" -keyalg RSA -keysize 2048 -validity 10000
          fi
          cat > "$HOME/.config/godot/editor_settings-4.7.tres" <<EOF
          [gd_resource type="EditorSettings" format=3]
          [resource]
          export/android/java_sdk_path = "$JAVA_HOME"
          export/android/android_sdk_path = "$ANDROID_HOME"
          export/android/debug_keystore = "$DEBUG_KEYSTORE"
          export/android/debug_keystore_user = "androiddebugkey"
          export/android/debug_keystore_pass = "android"
          EOF
          export GODOT_ANDROID_KEYSTORE_DEBUG_PATH="$DEBUG_KEYSTORE"
          export GODOT_ANDROID_KEYSTORE_DEBUG_USER="androiddebugkey"
          export GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD="android"
          "$GODOT" --headless --path . --editor --quit
          "$GODOT" --headless --path . --export-debug "Android" build/android/apex-assassin-debug.apk
      - uses: actions/upload-artifact@v4
        with:
          name: apex-assassin-debug-${{ github.sha }}
          path: build/android/*.apk
          if-no-files-found: error
          retention-days: 14
''')

write('export_presets.cfg', '''
[preset.0]
name="Android"
platform="Android"
runnable=true
advanced_options=false
dedicated_server=false
custom_features=""
export_filter="all_resources"
include_filter="data/levels/*.json"
exclude_filter="tools/*,.github/*,.apex-backup/*"
export_path="build/android/apex-assassin-debug.apk"
script_export_mode=2

[preset.0.options]
custom_template/debug=""
custom_template/release=""
gradle_build/use_gradle_build=false
gradle_build/export_format=0
architectures/armeabi-v7a=false
architectures/arm64-v8a=true
architectures/x86=false
architectures/x86_64=false
version/code=1
version/name="0.1.0"
package/unique_name="com.aryanshahx.apexassassin"
package/name="Apex Assassin"
package/signed=true
package/app_category=2
launcher_icons/main_192x192="res://assets/ui/icon.svg"
launcher_icons/adaptive_foreground_432x432="res://assets/ui/icon.svg"
launcher_icons/adaptive_background_432x432="res://assets/ui/icon.svg"
screen/immersive_mode=true
screen/edge_to_edge=false
screen/background_color=Color(0.04, 0.06, 0.12, 1)
permissions/internet=false
permissions/vibrate=true
''')

write('.gitignore', '''
.godot/
.ci/
.apex-backup/
build/
*.apk
*.aab
*.keystore
*.jks
__pycache__/
*.pyc
.DS_Store
''')

print('Phase 1 files written.')
print('Next: python3 tools/generate_levels.py')
