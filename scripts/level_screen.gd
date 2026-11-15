extends Node2D

# Where each level leads. Levels 1-3 are authored scenes; anything beyond the
# table falls back to the generated scene, so the game never runs out of levels.
# Add a new authored level here and to GameStats.LEVELS.
const LEVEL_SCENES := {
	1: "res://scenes/level1/Level1.tscn",
	2: "res://scenes/level2/Level2.tscn",
	3: "res://scenes/level3/Level3.tscn",
}

# Everything past the authored levels is built from this scene at runtime.
const GENERATED_LEVEL_SCENE := "res://scenes/generated/EndlessLevel.tscn"

# Optional override. Left empty, the next scene comes from LEVEL_SCENES, which
# gives the wrap-around for free. Set it to send this level somewhere unusual.
@export_file("*.tscn") var next_level_scene := ""

# Drain opening at the bottom of the funnel. Tune these in the Inspector.
@export var drain_center := Vector2(480.0, 1075.0)
@export var drain_size := Vector2(180.0, 70.0)
@export_group("Screen Effects")
## Combo size at which the screen starts to shake.
@export var combo_shake_threshold := 8
## Peak shake distance in pixels while the combo is running hot.
@export var max_shake_offset := 4.5
## Extra zoom added per combo step, up to max_zoom_boost.
@export var zoom_per_combo := 0.0045
## Cap on the zoom-in, so 0.05 means the view can reach 105%.
@export var max_zoom_boost := 0.05

const SCREEN_FX := preload("res://scripts/screen_fx.gd")

# Impact-frame flash + hitstop on high combos. One per level, on the UI layer.
const IMPACT_FX := preload("res://scripts/impact_fx.gd")

const BALL_SCENE := preload("res://scenes/gameplay/PinBall.tscn")

const BOUNCY_DURATION := 5.0
const BOUNCY_BOUNCE := 0.95

var _bouncy_wall_originals := {}
var _bouncy_ball_originals := {}
var _bouncy_overlay: ColorRect = null
var _bouncy_timer: Timer = null

# DEVELOPER TOOL — remove this const and the _add_dev_tools() call below to
# strip the instant-kill button. It also stays out of exported release builds.
const DEV_TOOLS := preload("res://scripts/dev_tools.gd")

@onready var round_clear: Control = $UI/RoundClear
@onready var upgrade_screen: Control = $UI/UpgradeScreen
@onready var launcher: Node2D = $launcher


func _ready() -> void:
	_create_arena_bounds()
	_add_screen_fx()
	_add_impact_fx()
	_add_dev_tools()

	GameStats.ball_set_finished.connect(_on_ball_set_finished)
	round_clear.continue_pressed.connect(_on_round_continue)
	upgrade_screen.upgrade_chosen.connect(_on_upgrade_chosen)


# Sits on the UI layer so the shake/zoom never moves it.
func _add_dev_tools() -> void:
	$UI.add_child(DEV_TOOLS.new())


# Also on the UI layer: the flash must stay screen-fixed and draw over the HUD.
func _add_impact_fx() -> void:
	$UI.add_child(IMPACT_FX.new())


# Added in code so the shared LevelScreen scene stays free of a camera node and
# does not collide with upgrade-screen work.
func _add_screen_fx() -> void:
	var fx = SCREEN_FX.new()
	fx.shake_threshold = combo_shake_threshold
	fx.max_offset = max_shake_offset
	fx.zoom_per_combo = zoom_per_combo
	fx.max_extra_zoom = max_zoom_boost
	add_child(fx)


func _on_ball_set_finished(damage: int, boss_hp: int) -> void:
	# Wait for the boss bar tween/flash.
	await get_tree().create_timer(0.9).timeout

	if boss_hp <= 0:
		round_clear.open(GameStats.score, damage)
	else:
		if GameStats.consume_round():
			launcher.arm()
		else:
			$UI/GameOver.show_game_over()


func _on_round_continue() -> void:
	round_clear.hide()
	upgrade_screen.open()


func _on_upgrade_chosen(upgrade_id: String) -> void:
	if GameStats.ABILITIES.has(upgrade_id):
		GameStats.set_ability(upgrade_id)
	else:
		GameStats.apply_upgrade(upgrade_id)
	_load_next_level()


# Everything about the boss cycle lives here, so upgrade effects added to
# _on_upgrade_chosen() above stay independent of scene loading.
func _load_next_level() -> void:
	var next_level := GameStats.advance_level()
	var scene_path := next_level_scene

	if scene_path.is_empty():
		scene_path = LEVEL_SCENES.get(next_level, GENERATED_LEVEL_SCENE)

	if scene_path.is_empty():
		push_error("No scene configured for level %d" % next_level)
		return

	get_tree().change_scene_to_file(scene_path)


func _create_arena_bounds() -> void:
	var view := get_viewport_rect().size
	var thickness := 40.0

	_add_wall(Vector2(view.x * 0.5, -thickness), Vector2(view.x, thickness))
	_add_wall(Vector2(view.x * 0.5, view.y + thickness), Vector2(view.x, thickness))
	_add_wall(Vector2(-thickness, view.y * 0.5), Vector2(thickness, view.y))
	_add_wall(Vector2(view.x + thickness, view.y * 0.5), Vector2(thickness, view.y))

	var drain := Area2D.new()
	drain.name = "Drain"
	drain.collision_layer = 0
	drain.collision_mask = 1

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = drain_size
	shape.shape = rect
	drain.add_child(shape)
	drain.position = drain_center
	add_child(drain)
	drain.body_entered.connect(_on_drain_body_entered)


func _add_wall(at: Vector2, size: Vector2) -> void:
	var wall := StaticBody2D.new()
	wall.position = at
	wall.collision_layer = 1
	wall.collision_mask = 1

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	wall.add_child(shape)
	add_child(wall)


func _on_drain_body_entered(body: Node) -> void:
	if body is RigidBody2D:
		body.queue_free()


func _on_player_died() -> void:
	$UI/GameOver.show_game_over()


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("ability"):
		_use_ability()


func _use_ability() -> void:
	if GameStats.current_ability == "":
		return

	if get_tree().paused or upgrade_screen.visible or round_clear.visible:
		return

	# Top/split need a live ball to act on.
	if GameStats.current_ability != "bouncy_walls" and _active_balls().is_empty():
		return

	if not GameStats.try_use_ability():
		return

	match GameStats.current_ability:
		"top_balls":
			_ability_top_balls()
		"split_ball":
			_ability_split_ball()
		"bouncy_walls":
			_ability_bouncy_walls()


# Balls live as children of the level, but check the group too in case another
# scene spawned them somewhere else.
func _active_balls() -> Array:
	var balls: Array = []
	var seen := {}

	for node in get_tree().get_nodes_in_group("ball"):
		_add_ball(node, balls, seen)

	for child in get_children():
		_add_ball(child, balls, seen)

	return balls


func _add_ball(node: Node, balls: Array, seen: Dictionary) -> void:
	if not (node is RigidBody2D) or not is_instance_valid(node):
		return
	if node.freeze:
		return

	var id := node.get_instance_id()
	if seen.has(id):
		return

	seen[id] = true
	balls.append(node)


# ABILITY 1: lift every live ball to the top of the playfield.
func _ability_top_balls() -> void:
	var balls := _active_balls()
	if balls.is_empty():
		return

	var center := Vector2(get_viewport_rect().size.x * 0.5, 300.0)
	var count := balls.size()
	for i in range(count):
		var ball = balls[i]
		var offset := Vector2((float(i) - float(count - 1) * 0.5) * 52.0, 0.0)
		ball.global_position = center + offset
		ball.linear_velocity = Vector2.ZERO
		ball.angular_velocity = 0.0
		ball.sleeping = false

		if ball.has_method("clear_trail"):
			ball.clear_trail()


# ABILITY 2: split the highest live ball into three.
func _ability_split_ball() -> void:
	var balls := _active_balls()
	if balls.is_empty():
		return

	var highest: RigidBody2D = balls[0]
	for ball in balls:
		if ball.global_position.y < highest.global_position.y:
			highest = ball

	var base_position: Vector2 = highest.global_position
	var base_velocity: Vector2 = highest.linear_velocity

	for i in range(2):
		var extra = BALL_SCENE.instantiate()
		extra.freeze = false
		extra.sleeping = false
		extra.collision_layer = 1
		extra.collision_mask = 1
		add_child(extra)
		extra.global_position = base_position + Vector2((float(i) - 0.5) * 48.0, 0.0)
		extra.linear_velocity = base_velocity + Vector2((float(i) - 0.5) * 240.0, -140.0)
		extra.add_to_group("ball")
		extra.tree_exited.connect(GameStats.ball_drained, CONNECT_ONE_SHOT)
		GameStats.active_balls += 1

		if extra.has_method("clear_trail"):
			extra.clear_trail()


# ABILITY 3: bounce the walls for 5 seconds, tinting the table green.
func _ability_bouncy_walls() -> void:
	_restore_bouncy()

	var table := $pinballTable
	if table != null:
		for child in table.get_children():
			if child is StaticBody2D:
				_bouncy_wall_originals[child] = child.physics_material_override
				child.physics_material_override = _bouncy_material(child.physics_material_override)

	for ball in _active_balls():
		_bouncy_ball_originals[ball] = ball.physics_material_override
		ball.physics_material_override = _bouncy_material(ball.physics_material_override)

	_bouncy_overlay = ColorRect.new()
	_bouncy_overlay.color = Color(0.25, 1.0, 0.3, 0.16)
	_bouncy_overlay.size = get_viewport_rect().size
	_bouncy_overlay.position = Vector2.ZERO
	_bouncy_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bouncy_overlay.z_index = 100
	add_child(_bouncy_overlay)

	_bouncy_timer = Timer.new()
	_bouncy_timer.one_shot = true
	_bouncy_timer.wait_time = BOUNCY_DURATION
	_bouncy_timer.timeout.connect(_restore_bouncy)
	add_child(_bouncy_timer)
	_bouncy_timer.start()


func _bouncy_material(source: PhysicsMaterial) -> PhysicsMaterial:
	var material: PhysicsMaterial
	if source == null:
		material = PhysicsMaterial.new()
	else:
		material = source.duplicate() as PhysicsMaterial
	material.bounce = BOUNCY_BOUNCE
	return material


func _restore_bouncy() -> void:
	for body in _bouncy_wall_originals:
		if is_instance_valid(body):
			body.physics_material_override = _bouncy_wall_originals[body]
	_bouncy_wall_originals.clear()

	for ball in _bouncy_ball_originals:
		if is_instance_valid(ball):
			ball.physics_material_override = _bouncy_ball_originals[ball]
	_bouncy_ball_originals.clear()

	if _bouncy_overlay != null and is_instance_valid(_bouncy_overlay):
		_bouncy_overlay.queue_free()
	_bouncy_overlay = null

	if _bouncy_timer != null and is_instance_valid(_bouncy_timer):
		_bouncy_timer.stop()
		_bouncy_timer.queue_free()
	_bouncy_timer = null
