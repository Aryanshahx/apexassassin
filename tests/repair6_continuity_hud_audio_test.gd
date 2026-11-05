extends SceneTree
## Isolated checks: intact animated Superior art and grips, safe resource rows,
## square/prop visual seam, suppressed notices and real-damage audio behavior.
const Choice := preload("res://scripts/game/ten_character_selection.gd")
const Rig := preload("res://scripts/game/ten_character_player.gd")
const Meta := preload("res://scripts/game/ten_character_art_meta.gd")
var checks := 0
var failures := 0
func _init() -> void: call_deferred("_run")
func check(ok: bool, message: String) -> void:
 checks += 1
 if not ok:
  failures += 1
  printerr("FAIL: ", message)
func rect_of(c: Control) -> Rect2:
 return Rect2(c.position, c.size * c.scale)
func clear_players(sfx: Node) -> void:
 for p in sfx.players:
  p.stop(); p.stream = null
func playing_stream(sfx: Node, stream: AudioStream) -> bool:
 for p in sfx.players:
  if p.stream == stream: return true
 return false
func _run() -> void:
 var sandbox := OS.get_environment("APEX_REDSCARF_TEST_ROOT").simplify_path()
 if sandbox in ["", "/"] or not OS.get_user_data_dir().simplify_path().begins_with(sandbox + "/"):
  printerr("Refusing test outside disposable user data"); quit(1); return
 var gs = root.get_node("GameState")
 var sfx = root.get_node("Sfx")
 gs.sound_enabled = false; gs.haptics_enabled = false
 var combinations := 0
 for id in Choice.SUPERIOR_LOOKS:
  var actor := Rig.new(); root.add_child(actor); actor.setup(id, "player"); actor.set_process(false)
  var body: Sprite2D = actor.superior_body
  var size: Vector2 = body.texture.get_size()
  var mat: ShaderMaterial = actor.superior_material
  check(body.texture == Choice.portrait(id) and mat != null, id + " uses exact supplied art, not a reconstruction")
  check(Vector2(mat.get_shader_parameter("grip_shift")) == Vector2.ZERO and Vector2(mat.get_shader_parameter("other_shift")) == Vector2.ZERO, id + " begins without deformation")
  actor.set_moving(true)
  for pose in range(7):
   if pose == 4: actor.play_anim("attack", true)
   actor._process(0.05)
   var shift: Vector2 = mat.get_shader_parameter("grip_shift")
   var other: Vector2 = mat.get_shader_parameter("other_shift")
   var center: Vector2 = mat.get_shader_parameter("grip_center")
   check((shift * size).length() < 14.0 and (other * size).length() < 14.0, id + " pose %d uses bounded smooth deformation" % pose)
   check(not actor.leg_a.visible and not actor.leg_b.visible and not actor.ankle_a.visible and not actor.ankle_b.visible, id + " pose %d has no alien limb sprites" % pose)
   for weapon in Choice.WEAPONS:
    actor.set_knife(weapon); combinations += 1
    var g: Array = Meta.WEAPON_GRIP[weapon]
    var pos := Vector2(float(g[0]),float(g[1]))
    var grip_uv: Vector2 = body.to_local(actor.weapon_art.to_global(pos)) / size
    check(grip_uv.distance_to(center + shift) * size.x < 0.04, id + "/" + weapon + " pose %d keeps its weapon at the original moving fist" % pose)
  actor.free()

 gs.cash = 123456789; gs.gems = 987654321; gs.keys_collected = 2; gs.locker_board = {}
 gs.current_level = 4; gs.active_bonus_level = 0; gs.pending_bonus_level = 0
 var level = load("res://scenes/level/level.tscn").instantiate()
 root.add_child(level); current_scene = level; level.set_physics_process(false)
 await process_frame
 for safe in [Rect2(0,0,320,568),Rect2(13,19,400,860),Rect2(5,10,600,1000),Rect2(0,0,720,1280),Rect2(8,9,900,500)]:
  level._layout_hud_for_rect(safe); await process_frame
  var icons: Array[TextureRect] = [level.money_icon, level.gem_icon, level.key_icon]
  var labels: Array[Label] = [level.money_label, level.gem_label, level.key_label]
  var centers: Array[Vector2] = []
  for i in range(3):
   var ir := rect_of(icons[i]); var lr := rect_of(labels[i]); centers.append(ir.get_center())
   check(safe.encloses(ir) and safe.encloses(lr), "HUD icon/value stays in safe rect " + str(safe.size) + " / " + str(i))
   check(not ir.intersects(lr,false) and absf(ir.get_center().y-lr.get_center().y)<0.6, "HUD icon/value align and do not overlap " + str(safe.size) + " / " + str(i))
   if i < 2: check(not lr.intersects(rect_of(icons[i+1]),false), "HUD value never overlaps next icon " + str(safe.size) + " / " + str(i))
  check(absf((centers[1].x-centers[0].x)-(centers[2].x-centers[1].x))<0.05, "three resource icons have exactly equal spacing " + str(safe.size))
  check(absf(centers[0].y-centers[1].y)<0.05 and absf(centers[1].y-centers[2].y)<0.05, "three resource icons share a straight row " + str(safe.size))
  check(not rect_of(level.counter).intersects(rect_of(icons[0]),false) and not rect_of(labels[2]).intersects(rect_of(level.pause_btn),false), "wallet does not collide with target or pause " + str(safe.size))
  check(level.money_label.text == "123456789" and level.gem_label.text == "987654321" and level.key_label.text == "2/3", "correct cash, diamonds and key totals " + str(safe.size))
 check(level.key_guide.position == level.key_icon.position and level.key_guide.size == level.key_icon.size, "key guide remains on its icon")

 # Optional user MP3 overrides the WAV if installed/imported. Baseline source
 # without that user's file must gracefully retain the existing WAV instead.
 var expected := "res://assets/audio/hurt.mp3" if ResourceLoader.exists("res://assets/audio/hurt.mp3") else "res://assets/audio/hurt.wav"
 check(sfx.streams.has("hurt") and sfx.streams.hurt.resource_path == expected, "correct optional hurt audio resolves: " + expected)
 gs.sound_enabled = true; sfx.enabled = true
 level.finished = false; level.is_bonus_level = false; level.invuln = 0.0
 clear_players(sfx)
 check(level._damage_player(5.0) and playing_stream(sfx,sfx.streams.hurt), "actual positive damage plays hurt sound")
 clear_players(sfx); level.invuln = 0.2
 check(not level._damage_player(5.0) and not playing_stream(sfx,sfx.streams.hurt), "invulnerable contact does not play hurt")
 clear_players(sfx); level.invuln = 0.0
 check(not level._damage_player(0.0) and not playing_stream(sfx,sfx.streams.hurt), "zero damage does not play hurt")
 clear_players(sfx); level.is_bonus_level = true
 check(not level._damage_player(5.0) and not playing_stream(sfx,sfx.streams.hurt), "bonus immunity does not play hurt")
 level.is_bonus_level = false; clear_players(sfx); gs.sound_enabled = false
 check(level._damage_player(5.0) and not playing_stream(sfx,sfx.streams.hurt), "sound-disabled damage remains silent")
 gs.sound_enabled = true; clear_players(sfx)
 for p in sfx.players:
  p.stream = sfx.streams.coin; p.play()
 sfx.play("hurt")
 check(sfx.players[0].stream == sfx.streams.hurt, "hurt effect is prioritized when the sound pool is full")
 clear_players(sfx); gs.sound_enabled = false
 level.queue_free(); await process_frame

 var home = load("res://scenes/home/home.tscn").instantiate()
 root.add_child(home); current_scene = home; await process_frame
 check(home.cash_label.text == "123456789" and home.gems_label.text == "987654321" and home.keys_label.text == "2", "home resource row reads the actual cash, diamond and key values")
 gs.keys_collected = 1; home._refresh_values()
 check(home.keys_label.text == "1", "home key amount refreshes without resetting progress")
 check(home.find_child("CashCaption",true,false) == null and home.find_child("DiamondsCaption",true,false) == null and home.find_child("CashButton",true,false) == null and home.find_child("DiamondsButton",true,false) == null, "home resource captions and popup buttons are absent")
 gs.mission2_claimed = false; var before: int = gs.cash
 home._claim_mission(2); await process_frame
 check(gs.cash == before + 200 and home.find_child("CenteredToast",true,false) == null, "claim still pays once without displaying a notice")
 home._claim_mission(2); home._toast("suppressed")
 check(gs.cash == before + 200 and home.find_child("CenteredToast",true,false) == null, "repeat claim and other transient messages stay silent")
 home.queue_free(); await process_frame
 print("REPAIR-6 CONTINUITY / HUD / HURT: ", checks, " checks, ", failures, " failures; ", combinations, " moving weapon/hand combinations; audio=", expected)
 quit(1 if failures else 0)
