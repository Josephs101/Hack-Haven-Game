extends Node2D

# Where each level leads. The keys are the boss order; the last entry loops back
# to the first, so beating the final boss restarts at level 1 with tougher HP
# (see GameStats.LOOP_HP_GROWTH). Add a level here and to GameStats.LEVELS.
const LEVEL_SCENES := {
	1: "res://scenes/level1/Level1.tscn",
	2: "res://scenes/level2/Level2.tscn",
	3: "res://scenes/level3/Level3.tscn",
}

# Optional override. Left empty, the next scene comes from LEVEL_SCENES, which
# gives the wrap-around for free. Set it to send this level somewhere unusual.
@export_file("*.tscn") var next_level_scene := ""

@export_group("Screen Effects")
## Combo size at which the screen starts to shake.
@export var combo_shake_threshold := 6
## Peak shake distance in pixels while the combo is running hot.
@export var max_shake_offset := 7.0
## Extra zoom added per combo step, up to max_zoom_boost.
@export var zoom_per_combo := 0.006
## Cap on the zoom-in, so 0.08 means the view can reach 108%.
@export var max_zoom_boost := 0.08

const SCREEN_FX := preload("res://scripts/screen_fx.gd")

@onready var round_clear: Control = $UI/RoundClear
@onready var upgrade_screen: Control = $UI/UpgradeScreen
@onready var launcher: Node2D = $launcher


func _ready() -> void:
	_create_arena_bounds()
	_add_screen_fx()

	GameStats.ball_set_finished.connect(_on_ball_set_finished)
	round_clear.continue_pressed.connect(_on_round_continue)
	upgrade_screen.upgrade_chosen.connect(_on_upgrade_chosen)


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


func _on_upgrade_chosen(upgrade: Dictionary) -> void:
	GameStats.apply_upgrade(upgrade)
	_load_next_level()


# Everything about the boss cycle lives here, so upgrade effects added to
# _on_upgrade_chosen() above stay independent of scene loading.
func _load_next_level() -> void:
	var next_level := GameStats.advance_level()
	var scene_path := next_level_scene

	if scene_path.is_empty():
		scene_path = LEVEL_SCENES.get(next_level, "")

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
	rect.size = Vector2(view.x, 80.0)
	shape.shape = rect
	drain.add_child(shape)
	drain.position = Vector2(view.x * 0.5, view.y - 40.0)
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
