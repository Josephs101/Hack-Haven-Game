extends Control

const MENU_SCENE:= "res://scenes/start_menu.tscn"
@onready var resume_button: Button = %Resume

func _ready() -> void:
	hide()
	%Resume.pressed.connect(_close)
	%Quit.pressed.connect(_on_quit)
	%Restart.pressed.connect(_on_restart)
	
func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause"):
		return

	get_viewport().set_input_as_handled()

	if visible:
		_close()
	elif not get_tree().paused:
		_open()


func _open() -> void:
	show()
	get_tree().paused = true
	resume_button.grab_focus()

func _close() -> void:
	hide()
	get_tree().paused = false

func _on_restart() -> void:
	get_tree().paused = false
	GameStats.reset()
	get_tree().reload_current_scene()

func _on_quit() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(MENU_SCENE)
	
	
