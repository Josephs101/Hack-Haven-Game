extends Node2D

func _on_player_died() -> void:
	$UI/GameOver.show_game_over()

func _unhandled_input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return

	match (event as InputEventKey).physical_keycode:
		KEY_K:
			GameStats.add_score(100)
		KEY_B:
			GameStats.set_boss_health(GameStats.boss_hp - 10, GameStats.boss_max_hp)
		KEY_N:
			GameStats.set_balls(GameStats.balls_left - 1)
		KEY_G:
			$UI/GameOver.show_game_over()
		KEY_R:
			GameStats.reset()
