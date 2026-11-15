extends Node2D

@export_file("*.tscn") var next_level_scene := ""

@onready var round_clear: Control = $UI/RoundClear
@onready var upgrade_screen: Control = $UI/UpgradeScreen
@onready var launcher: Node2D = $launcher


func _ready() -> void:
	_create_arena_bounds()

	GameStats.ball_set_finished.connect(_on_ball_set_finished)
	round_clear.continue_pressed.connect(_on_round_continue)
	upgrade_screen.upgrade_chosen.connect(_on_upgrade_chosen)


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
	GameStats.start_level(GameStats.current_level + 1)

	if next_level_scene != "":
		get_tree().change_scene_to_file(next_level_scene)


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
