extends Node2D
## TEMPORARY REFERENCE-PIXEL PREVIEW ONLY; not final recreated artwork.
## Legs use new vector art aligned along the body. The new still reference is
## a pose cue, not a motion clip. Weapon and hand remain one source layer.
## All animation here is visual-only; gameplay, AI, melee rules and saves are unchanged.
const TORSO := preload("res://assets/characters/red-scarf-preview/test-v2-cropped-torso.png")
const KNIFE_UPPER := preload("res://assets/characters/red-scarf-preview/test-v3-knife-upper.png")
const KNIFE_FOREARM := preload("res://assets/characters/red-scarf-preview/test-v3-knife-forearm.png")
const FREE_ARM := preload("res://assets/characters/red-scarf-preview/test-v2-cropped-free-arm.png")
const HEAD := preload("res://assets/characters/red-scarf-preview/test-v2-cropped-head.png")
const FREE_HAND := preload("res://assets/characters/red-scarf-preview/test-v2-cropped-free-hand.png")
const KNIFE_HAND := preload("res://assets/characters/red-scarf-preview/test-v2-cropped-knife-hand.png")
const LEG := preload("res://assets/characters/red-scarf-preview/test-v2-leg.png")
const FOOT := preload("res://assets/characters/red-scarf-preview/test-v2-foot.png")
# Origins retain the original 1514×784 canvas coordinates after lossless crops.
const TORSO_ORIGIN := Vector2(654.0, 51.0)
const KNIFE_UPPER_ORIGIN := Vector2(524.0, 6.0)
const KNIFE_FOREARM_ORIGIN := Vector2(468.0, 60.0)
const FREE_ARM_ORIGIN := Vector2(534.0, 450.0)
const HEAD_ORIGIN := Vector2(856.0, 218.0)
const FREE_HAND_ORIGIN := Vector2(534.0, 451.0)
const KNIFE_HAND_ORIGIN := Vector2(12.0, 252.0)
const PIXEL_CENTRE := Vector2(970.0, 390.0)
const HEAD_PIVOT := Vector2(1040.0, 390.0)
const KNIFE_SHOULDER := Vector2(950.0, 154.0)
const KNIFE_ELBOW := Vector2(635.0, 135.0)
const FREE_SHOULDER := Vector2(990.0, 625.0)
const FREE_PIVOT := Vector2(690.0, 590.0)
const WRIST := Vector2(529.0, 300.0)
const HIP_A := Vector2(1015.0, 370.0)
const HIP_B := Vector2(1015.0, 410.0)
var visual: Node2D
var knife_shoulder: Node2D
var knife_elbow: Node2D
var free_shoulder: Node2D
var wrist: Node2D
var free_pivot: Node2D
var head_pivot: Node2D
var leg_a: Node2D
var leg_b: Node2D
var ankle_a: Node2D
var ankle_b: Node2D
var leg_art_a: Sprite2D
var leg_art_b: Sprite2D
var moving := false
var dead := false
var state := "idle"
var elapsed := 0.0
var walk_time := 0.0
var held_gait := 1.0
var target_a := Vector2.ZERO
var target_b := Vector2.ZERO
var ankle_flex_a := 0.0
var ankle_flex_b := 0.0

func setup(_kind: String, _role: String = "player") -> void:
    if visual != null:
        return
    visual = Node2D.new()
    visual.name = "ReferenceOnlyVisual"
    # The supplied reference faces left; the old level's rest direction is up.
    visual.rotation = PI / 2.0
    visual.scale = Vector2.ONE * (55.0 / 1514.0)
    add_child(visual)
    leg_a = _leg_pivot("LegA")
    leg_b = _leg_pivot("LegB")
    leg_art_a = leg_a.get_node("LegArt")
    leg_art_b = leg_b.get_node("LegArt")
    ankle_a = _ankle_pivot("AnkleA")
    ankle_b = _ankle_pivot("AnkleB")
    var torso := Sprite2D.new()
    torso.name = "ReferenceBody"
    torso.centered = false
    torso.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
    torso.texture = TORSO
    torso.position = TORSO_ORIGIN - PIXEL_CENTRE
    visual.add_child(torso)
    knife_shoulder = _shoulder("KnifeShoulder", KNIFE_UPPER, KNIFE_SHOULDER, KNIFE_UPPER_ORIGIN)
    knife_elbow = _elbow_pivot(knife_shoulder, KNIFE_FOREARM, KNIFE_ELBOW, KNIFE_SHOULDER, KNIFE_FOREARM_ORIGIN)
    wrist = _hand_pivot(knife_elbow, "KnifeHandPivot", KNIFE_HAND, WRIST, KNIFE_ELBOW, KNIFE_HAND_ORIGIN)
    free_shoulder = _shoulder("FreeShoulder", FREE_ARM, FREE_SHOULDER, FREE_ARM_ORIGIN)
    free_pivot = _hand_pivot(free_shoulder, "ReferenceFreeHand", FREE_HAND, FREE_PIVOT, FREE_SHOULDER, FREE_HAND_ORIGIN)
    head_pivot = _shoulder("ReferenceHead", HEAD, HEAD_PIVOT, HEAD_ORIGIN)
    _set_leg(leg_a, leg_art_a, ankle_a, HIP_A, Vector2(730.0, 355.0), 0.0)
    _set_leg(leg_b, leg_art_b, ankle_b, HIP_B, Vector2(1270.0, 425.0), 0.0)

func _leg_pivot(node_name: String) -> Node2D:
    var node := Node2D.new()
    node.name = node_name
    visual.add_child(node)
    var art := Sprite2D.new()
    art.name = "LegArt"
    art.centered = false
    art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
    art.texture = LEG
    art.offset = Vector2(-4, -60)
    node.add_child(art)
    return node

func _ankle_pivot(node_name: String) -> Node2D:
    var node := Node2D.new()
    node.name = node_name
    visual.add_child(node)
    var art := Sprite2D.new()
    art.name = "FootArt"
    art.centered = false
    art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
    art.texture = FOOT
    art.offset = Vector2(-12, -50)
    art.scale = Vector2(1.0, 1.4)
    node.add_child(art)
    return node

func _shoulder(node_name: String, texture: Texture2D, anchor: Vector2, crop_origin: Vector2) -> Node2D:
    var node := Node2D.new()
    node.name = node_name
    node.position = anchor - PIXEL_CENTRE
    visual.add_child(node)
    var art := Sprite2D.new()
    art.name = "Art"
    art.centered = false
    art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
    art.texture = texture
    art.position = crop_origin - anchor
    node.add_child(art)
    return node

func _elbow_pivot(parent: Node2D, texture: Texture2D, elbow: Vector2, shoulder: Vector2, crop_origin: Vector2) -> Node2D:
    var node := Node2D.new()
    node.name = "KnifeElbow"
    node.position = elbow - shoulder
    parent.add_child(node)
    var art := Sprite2D.new()
    art.name = "ForearmArt"
    art.centered = false
    art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
    art.texture = texture
    art.position = crop_origin - elbow
    node.add_child(art)
    return node

func _hand_pivot(parent: Node2D, node_name: String, texture: Texture2D, hand: Vector2, parent_anchor: Vector2, crop_origin: Vector2) -> Node2D:
    var node := Node2D.new()
    node.name = node_name
    node.position = hand - parent_anchor
    parent.add_child(node)
    var art := Sprite2D.new()
    art.name = "HandArt"
    art.centered = false
    art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
    art.texture = texture
    art.position = crop_origin - hand
    node.add_child(art)
    return node

func _set_leg(pivot: Node2D, art: Sprite2D, ankle: Node2D, hip: Vector2, target: Vector2, flex_degrees: float) -> void:
    var delta := target - hip
    var direction := delta.angle()
    pivot.position = hip - PIXEL_CENTRE
    pivot.rotation = direction
    art.scale = Vector2(maxf(0.01, delta.length() / 346.0), 1.4)
    ankle.position = target - PIXEL_CENTRE
    ankle.rotation = direction + deg_to_rad(flex_degrees)

func set_knife(_legacy_id: String) -> void:
    # The supplied knife stays attached to its supplied hand in this test.
    pass

func set_moving(value: bool) -> void:
    moving = value
    if not dead and state in ["idle", "run"]:
        state = "run" if moving else "idle"

func play_anim(next: String, force: bool = false) -> bool:
    if dead and next != "death":
        return false
    if next == state and not force:
        return true
    if next == "attack":
        held_gait = cos(walk_time * TAU * 1.5) if moving else 1.0
    state = next
    elapsed = 0.0
    return true

func die() -> void:
    dead = true
    state = "death"
    elapsed = 0.0

func _process(delta: float) -> void:
    if visual == null or delta < 0.0:
        return
    elapsed += delta
    if moving and not dead:
        walk_time += delta
    var gait := cos(walk_time * TAU * 1.5) if moving and not dead else 1.0
    var wave := 0.0
    var cycle := 0.0
    var attack_active := state == "attack" and not dead
    if attack_active:
        var progress := clampf(elapsed / 0.30, 0.0, 1.0)
        if progress >= 1.0:
            state = "run" if moving else "idle"
            elapsed = 0.0
            attack_active = false
        else:
            gait = held_gait
            wave = sin(PI * progress)
            cycle = sin(TAU * progress)
    if state == "hurt" and elapsed >= 0.28:
        state = "run" if moving else "idle"
        elapsed = 0.0
    knife_shoulder.rotation = deg_to_rad(-3.0 * cycle)
    knife_elbow.rotation = deg_to_rad(-15.0 * cycle + 7.0 * wave)
    free_shoulder.rotation = deg_to_rad(2.5 * cycle)
    wrist.rotation = deg_to_rad(-4.5 * wave)
    free_pivot.rotation = deg_to_rad(-3.0 * sin(walk_time * TAU * 1.5)) if moving and not attack_active and not dead else deg_to_rad(2.0 * wave)
    head_pivot.rotation = deg_to_rad(2.5 * sin(walk_time * TAU * 1.5)) if moving and not attack_active and not dead else 0.0
    ankle_flex_a = 10.0 * wave
    ankle_flex_b = -8.0 * wave
    target_a = Vector2(1000.0 - 270.0 * gait - 18.0 * wave, 355.0)
    target_b = Vector2(1000.0 + 270.0 * gait + 12.0 * wave, 425.0)
    _set_leg(leg_a, leg_art_a, ankle_a, HIP_A, target_a, ankle_flex_a)
    _set_leg(leg_b, leg_art_b, ankle_b, HIP_B, target_b, ankle_flex_b)
    visual.position.y = -0.7 * absf(sin(walk_time * TAU * 1.5)) if moving and not dead else 0.0
