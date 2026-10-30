extends Node
## Tiny pooled sound effect player. All WAVs are original synthesized assets.
var enabled := true
var players: Array[AudioStreamPlayer] = []
var streams := {}

func _ready() -> void:
	for n in ["blade", "shot", "alert", "coin", "hurt", "win", "lose", "upgrade"]:
		var path := "res://assets/audio/%s.wav" % n
		if ResourceLoader.exists(path):
			streams[n] = load(path)
	for i in range(10):
		var p := AudioStreamPlayer.new()
		add_child(p)
		players.append(p)

func play(name: String, volume_db: float = -6.0) -> void:
	if not enabled or not GameState.sound_enabled or not streams.has(name):
		return
	for p in players:
		if not p.playing:
			p.stream = streams[name]
			p.volume_db = volume_db
			p.play()
			return
