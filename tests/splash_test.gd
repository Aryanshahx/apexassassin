extends SceneTree
## The old splash remains intact, with exactly two aligned label patches.
var checks := 0
var failures := 0
func _init() -> void:
	call_deferred("_run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ", message)
func _run() -> void:
	var scene = load("res://scenes/splash/splash.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	check(scene.bg.texture.resource_path.ends_with("/splash/splash.jpg"), "original splash image is preserved")
	check(scene.loading_patch.texture.resource_path.ends_with("/loading_v61.png"), "Loading Assets label is replaced")
	check(scene.publisher_patch.texture.resource_path.ends_with("/publisher_v61.png"), "APEX GAMES publisher label is replaced")
	check(scene.bar.visible and scene.bar.max_value == 100.0, "real loading progress bar remains visible")
	for dims in [Vector2i(720,1280), Vector2i(400,850), Vector2i(360,640), Vector2i(320,568), Vector2i(600,800)]:
		root.size = dims
		await process_frame
		scene._fit()
		var vp: Vector2 = scene.get_viewport_rect().size
		var cover: bool = vp.x / maxf(vp.y, 1.0) <= (720.0 / 1280.0) * 1.10
		var factor: float = maxf(vp.x / 720.0, vp.y / 1280.0) if cover else minf(vp.x / 720.0, vp.y / 1280.0)
		var offset: Vector2 = (vp - Vector2(720,1280) * factor) * 0.5
		check(scene.loading_patch.position.distance_to(offset + scene.LOADING_PATCH_RECT.position * factor) < 0.01, "loading label stays aligned at %s" % [dims])
		check(scene.publisher_patch.position.distance_to(offset + scene.PUBLISHER_PATCH_RECT.position * factor) < 0.01, "publisher label stays aligned at %s" % [dims])
		check(scene.loading_patch.size.distance_to(scene.LOADING_PATCH_RECT.size * factor) < 0.01, "loading patch scales with the art at %s" % [dims])
		check(scene.publisher_patch.size.distance_to(scene.PUBLISHER_PATCH_RECT.size * factor) < 0.01, "publisher patch scales with the art at %s" % [dims])
	scene.queue_free()
	print("SPLASH %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
