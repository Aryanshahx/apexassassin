extends "res://scripts/game/v72_sprite_rig.gd"
## Six reference-guided enemy redraws. Existing guard AI and animation API are
## retained; each image depicts its own gun already held between both fists.

const Art := preload("res://scripts/game/six_enemy_art_meta.gd")
const BODY_WIDTH := 54.0

func setup(p_kind: String, p_role: String = "guard") -> void:
	# Reuse the original guard animation, aim state and muzzle-flash system.
	super.setup("guard", "guard")
	role = "guard"
	kind = p_kind if Art.ENEMY_ART.has(p_kind) else "guard"
	look = kind
	var spec: Dictionary = Art.ENEMY_ART[kind]
	art.texture = load(String(spec.file))
	var image_size: Vector2 = art.texture.get_size()
	var pivot := Vector2(float(spec.center[0]), float(spec.center[1]))
	var tip := Vector2(float(spec.tip[0]), float(spec.tip[1]))
	var to_tip := tip - pivot
	# Graphics face down in their reference; game rig rest direction faces up.
	# Align the pictured gun barrel with the real guard firing direction.
	var correction := atan2(to_tip.x, to_tip.y)
	if absf(correction) < 0.015:
		correction = 0.0
	var angle := PI + correction
	var factor := BODY_WIDTH / float(spec.width)
	art.scale = Vector2.ONE * factor
	art.rotation = angle
	art.position = -(pivot - image_size * 0.5).rotated(angle) * factor
	muzzle.position = to_tip.rotated(angle) * factor
	muzzle.z_index = 2
