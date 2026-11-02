extends SceneTree
## Save/restart/loss and sound-dispatch regression; synthetic streams are in
## memory only and are never distributed as the user's two MP3 recordings.
var checks := 0
var failures := 0
func _init() -> void: call_deferred("_run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ", message)
func stop_sounds(sfx: Node) -> void:
	for p in sfx.players: p.stop()
func played(sfx: Node, stream: AudioStream) -> bool:
	for p in sfx.players:
		if p.stream == stream and p.playing: return true
	return false
func _run() -> void:
	var gs = root.get_node("GameState")
	var sfx = root.get_node("Sfx")
	gs.sound_enabled = true
	gs.haptics_enabled = false
	gs.selected_assassin = "ronin"
	gs.unlocked_assassins = {"ronin":true}
	gs.gems = 40
	gs.cash = 123
	gs.unlocked_level = 40
	gs.current_level = 1
	gs.keys_collected = 0
	gs.key_levels_claimed = {}
	gs.locker_board = {}
	gs.save_game()
	var key_levels: Array[int] = []
	for n in range(1,101):
		if gs.level_has_key(n): key_levels.append(n)
	check(key_levels.size() >= 3, "three real key levels exist")
	if key_levels.size() < 3:
		quit(1)
		return
	check(gs.collect_level_key(key_levels[0]) and gs.collect_level_key(key_levels[1]), "first two real level keys are saved")
	var pick_audio := AudioStreamWAV.new()
	pick_audio.format = AudioStreamWAV.FORMAT_8_BITS
	pick_audio.mix_rate = 22050
	pick_audio.data = PackedByteArray([128,128,128,128])
	pick_audio.loop_mode = AudioStreamWAV.LOOP_FORWARD
	pick_audio.loop_end = 4
	var unlock_audio := AudioStreamWAV.new()
	unlock_audio.format = AudioStreamWAV.FORMAT_8_BITS
	unlock_audio.mix_rate = 22050
	unlock_audio.data = PackedByteArray([128,128,128,128])
	unlock_audio.loop_mode = AudioStreamWAV.LOOP_FORWARD
	unlock_audio.loop_end = 4
	sfx.streams["pickkey"] = pick_audio
	sfx.streams["unlockkey"] = unlock_audio
	gs.start_level(key_levels[2])
	await process_frame
	await process_frame
	var lv = current_scene
	lv.set_physics_process(false)
	check(lv.key_on_floor, "third actual key is present")
	lv.player_pos = lv.key_position
	lv._collect_key_if_close()
	check(played(sfx,pick_audio), "collecting a key dispatches the requested pickup stream")
	stop_sounds(sfx)
	check(gs.locker_pending() and not gs.locker_ready() and lv.locker_ui == null and lv.key_label.text == "3/3", "third pickup queues a board and shows 3/3 without interrupting the level")
	var board: Dictionary = gs.locker_board.duplicate(true)
	check(gs.open_locker(0).is_empty(), "direct callers cannot bypass the win gate")
	gs.load_game()
	check(gs.locker_board == board and not gs.locker_ready() and gs.displayed_key_count() == 3, "board, secret slot, amounts and win gate survive a reload")
	lv._lose()
	await create_timer(0.8).timeout
	check(gs.locker_board == board and not gs.locker_ready(), "losing does not open, reroll or discard the queued board")
	change_scene_to_file("res://scenes/home/home.tscn")
	await process_frame
	await process_frame
	await process_frame
	check(current_scene.find_child("LockerRewards",true,false) == null and not gs.locker_ready(), "returning home before a win does not open the locker")
	gs.start_level(key_levels[2])
	await process_frame
	await process_frame
	lv = current_scene
	lv.set_physics_process(false)
	check(lv.locker_ui == null and not lv.key_on_floor and gs.locker_board == board, "retry neither reopens the board nor duplicates the key")
	var before_cash: int = gs.cash
	lv._win()
	await process_frame
	await process_frame
	check(gs.locker_ready() and lv.locker_ui != null and gs.cash == before_cash + 50 + key_levels[2] * 5, "a genuine completed level releases the same board and awards the normal cash")
	if lv.locker_ui == null:
		quit(1)
		return
	var ui = lv.locker_ui
	var secret: int = int(gs.locker_board.character_slot)
	var diamond := (secret + 1) % 9
	var before_gems: int = gs.gems
	var amount: int = int(gs.locker_board.amounts[diamond])
	ui._pick(diamond)
	check(played(sfx,unlock_audio), "opening a locker dispatches the requested unlock stream")
	stop_sounds(sfx)
	check(gs.gems == before_gems + amount and gs.locker_board.opened.size() == 1, "first reward is credited exactly once")
	ui._pick(diamond)
	check(gs.gems == before_gems + amount and gs.locker_board.opened.size() == 1, "the same locker cannot be opened twice")
	gs.load_game()
	check(gs.locker_ready() and gs.gems == before_gems + amount and gs.locker_board.opened.size() == 1 and int(gs.locker_board.character_slot) == secret, "partial reward, readiness and secret location survive a quit")
	change_scene_to_file("res://scenes/home/home.tscn")
	await process_frame
	await process_frame
	await process_frame
	var recovered = current_scene.find_child("LockerRewards",true,false)
	check(recovered != null and recovered.buttons[diamond].disabled, "home resumes an eligible partially revealed board")
	if recovered != null:
		recovered._pick(secret)
		check(gs.is_unlocked(gs.VAULT_CHARACTER) and gs.selected_assassin == "ronin", "Elite unlocks without silently changing the current selection")
		recovered._pick((secret + 2) % 9)
		check(gs.locker_board.opened.size() == 3 and recovered.done.visible, "third unique reward enables continue")
		check(gs.open_locker((secret + 3) % 9).is_empty(), "a fourth pick is rejected")
		recovered._finish()
		check(not gs.locker_pending() and gs.keys_collected == 0 and gs.key_levels_claimed.is_empty(), "finishing starts a clean next-key cycle")
		gs.load_game()
		check(gs.is_unlocked(gs.VAULT_CHARACTER) and not gs.locker_pending(), "finished board and Elite entitlement persist")

	# Existing v0.7.1 boards lack 'eligible': recover them instead of trapping or
	# resetting a previously revealed reward, including the old unique prize.
	var legacy := {"gems":88,"cash":222,"selected_assassin":"vault_phantom",
		"unlocked_assassins":{"ronin":true,"vault_phantom":true},
		"locker_board":{"character_slot":4,"amounts":[6,7,8,9,10,11,12,13,14],
			"opened":[{"index":1,"kind":"diamonds","amount":7}]}}
	var f := FileAccess.open(gs.SAVE_PATH,FileAccess.WRITE)
	f.store_string(JSON.stringify(legacy))
	f.close()
	gs.load_game()
	check(gs.locker_ready() and gs.locker_board.opened.size()==1 and gs.gems==88, "pre-v72 partial boards remain immediately recoverable without paying twice")
	check(gs.is_unlocked(gs.VAULT_CHARACTER) and gs.is_unlocked("vault_phantom") and gs.selected_assassin=="vault_phantom", "previous secret entitlement and selection grant Elite without deleting old progress")
	gs.save_game()
	gs.load_game()
	check(gs.locker_ready() and gs.locker_board.opened.size()==1 and int(gs.locker_board.character_slot)==4, "migrated board stays unchanged on another restart")
	stop_sounds(sfx)
	for player in sfx.players: player.stream = null
	sfx.streams.erase("pickkey")
	sfx.streams.erase("unlockkey")
	pick_audio = null
	unlock_audio = null
	print("V72 DEFERRED LOCKERS %d checks, %d failures" % [checks,failures])
	current_scene.queue_free()
	await process_frame
	await create_timer(0.2).timeout
	quit(1 if failures else 0)
