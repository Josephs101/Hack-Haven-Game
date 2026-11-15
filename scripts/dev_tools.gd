extends Control

## DEVELOPER TOOLS — not part of the game.
##
## Adds a "KILL BOSS" button (and an F10 shortcut) that finishes the current
## boss instantly, so you can cycle through the endless levels quickly.
##
## It only builds in debug builds, so an exported release never shows it.
## To remove it entirely: delete this file and take out the DEV_TOOLS const and
## the _add_dev_tools() call in scripts/level_screen.gd.

const KILL_KEY := KEY_F10


func _ready() -> void:
	if not OS.is_debug_build():
		queue_free()
		return

	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_button()


func _build_button() -> void:
	var button := Button.new()
	button.name = "KillBossButton"
	button.text = "KILL BOSS (F10)"
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP

	button.anchor_left = 1.0
	button.anchor_right = 1.0
	button.anchor_top = 1.0
	button.anchor_bottom = 1.0
	button.offset_left = -230.0
	button.offset_top = -86.0
	button.offset_right = -16.0
	button.offset_bottom = -30.0

	button.add_theme_font_size_override("font_size", 20)
	button.pressed.connect(kill_boss)
	add_child(button)


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return

	if not event.pressed or event.echo or event.keycode != KILL_KEY:
		return

	kill_boss()
	get_viewport().set_input_as_handled()


# Feeds the simulator enough points to finish the boss through the normal
# damage path, so scoring, the round-clear screen and the upgrade flow all run
# exactly as they would in a real fight.
func kill_boss() -> void:
	if GameStats.boss_hp <= 0:
		return

	var points_per_damage := float(GameStats.POINTS_PER_DAMAGE)
	var multiplier := maxf(0.01, GameStats.damage_multiplier)
	var damage_needed := float(GameStats.level_damage + GameStats.boss_max_hp + 5)

	GameStats.pending_points = int(ceil(damage_needed * points_per_damage / multiplier))
	GameStats.finish_ball_set()
