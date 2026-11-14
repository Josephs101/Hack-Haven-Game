extends Node2D

func _on_player_died() -> void:
	$UI/GameOver.show_game_over()
