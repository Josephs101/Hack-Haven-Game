extends Control

# Score and combo text heat up as they climb. Each stop is [value, color] and
# anything in between is blended, so these also control how fast the shift
# reads. Scores reset every ball set, which is why the top stop is modest.
const SCORE_COLOR_STOPS := [
	[0.0, Color(1, 1, 1, 1)],
	[250.0, Color(1, 0.878, 0.4, 1)],
	[700.0, Color(1, 0.69, 0.13, 1)],
	[1400.0, Color(1, 0.42, 0.21, 1)],
	[2400.0, Color(1, 0.23, 0.42, 1)],
]

const COMBO_COLOR_STOPS := [
	[0.0, Color(1, 1, 1, 1)],
	[3.0, Color(0.56, 0.94, 1, 1)],
	[6.0, Color(1, 0.878, 0.4, 1)],
	[10.0, Color(1, 0.62, 0.26, 1)],
	[15.0, Color(1, 0.37, 0.37, 1)],
	[20.0, Color(1, 0.36, 0.94, 1)],
]

# Balls and rounds fade from green (plenty left) through amber to red (running
# out). Keyed on the remaining fraction, so it works for 3 balls or 4 rounds
# alike and shifts a little with every single loss.
const REMAINING_COLOR_STOPS := [
	[0.0, Color(0.92, 0.2, 0.2, 1)],
	[0.45, Color(1, 0.78, 0.25, 1)],
	[1.0, Color(0.35, 0.9, 0.4, 1)],
]

@onready var score_value: Label = %ScoreValue
@onready var boss_bar: ProgressBar = %BossBar
@onready var balls_value: Label = %BallsValue
@onready var rounds_value: Label = %RoundsValue
@onready var boss_value: Label = %BossHealthLabel
@onready var boss_sprite: AnimatedSprite2D = %AnimatedSprite2D
@onready var damage_overlay: AnimatedSprite2D = %DamageOverlay
@export var min_jump_interval: float = 2.0
@export var max_jump_interval: float = 5.0
@onready var combo_value: Label = %ComboValue
@onready var boss_name_label: Label = %BossName
@onready var modifiers_list: VBoxContainer = %ModifiersList

const HUD_FONT := preload("res://assets/font(s)/Minecraft.ttf")

var _boss_tween: Tween = null
var _default_boss_frames: SpriteFrames = null

# Boss damage reaction animations. These names must match the animations in the
# boss SpriteFrames; change them if you named yours differently.
const BOSS_SMALL_DAMAGE := &"small_damage"
const BOSS_BIG_DAMAGE := &"big_damage"
const BOSS_KILL := &"kill"

## A hit that removes at least this fraction of the boss's max HP is "big".
@export var big_damage_fraction := 0.25

var _last_boss_hp := -1
var _boss_busy := false
var _jump_timer: Timer = null

@export_group("Combo Shake")
## Degrees of tilt added per combo step.
@export var combo_wobble_per_step := 0.1
## Ceiling on the tilt, in degrees.
@export var combo_wobble_max := 10
## Pixels of vertical shake added per combo step.
@export var combo_shake_per_step := 1.6
## Ceiling on the vertical shake, in pixels.
@export var combo_shake_max := 5.0
## Shake rate, in radians per second.
@export var combo_wobble_speed := 20.0

var _combo_wobble := 0.0
var _combo_wobble_target := 0.0
var _combo_shake := 0.0
var _combo_shake_target := 0.0
var _combo_phase := 0.0
var _combo_base_y := 0.0
var _combo_base_ready := false
var _color_tweens := {}

var rng = RandomNumberGenerator.new()

func _ready() -> void:
	GameStats.score_changed.connect(_on_score_changed)
	GameStats.combo_changed.connect(_on_combo_changed)
	GameStats.boss_health_changed.connect(_on_boss_health_changed)
	GameStats.boss_name_changed.connect(_on_boss_name_changed)
	GameStats.boss_visual_changed.connect(_on_boss_visual_changed)
	GameStats.balls_changed.connect(_on_balls_changed)
	GameStats.rounds_changed.connect(_on_rounds_changed)
	GameStats.upgrades_changed.connect(_on_upgrades_changed)

	boss_bar.max_value = GameStats.boss_max_hp
	boss_bar.value = GameStats.boss_hp
	boss_value.text = "%d / %d" % [GameStats.boss_hp, GameStats.boss_max_hp]

	_style_value_labels()
	_on_score_changed(GameStats.score)
	_on_combo_changed(GameStats.combo, GameStats.multiplier)
	_on_boss_name_changed(GameStats.boss_name)
	_on_balls_changed(GameStats.balls_left)
	_on_rounds_changed(GameStats.rounds_left)
	_on_upgrades_changed()

	combo_value.resized.connect(_recenter_combo_pivot)
	call_deferred("_cache_combo_origin")

	rng.randomize()
	_default_boss_frames = boss_sprite.sprite_frames
	_apply_boss_frames(GameStats.boss_frames_path)
	boss_sprite.animation_finished.connect(_on_boss_animation_finished)
	boss_sprite.play("idle")

	if damage_overlay != null:
		damage_overlay.visible = false
		damage_overlay.animation_finished.connect(_on_damage_overlay_finished)

	_jump_timer = Timer.new()
	_jump_timer.one_shot = true
	_jump_timer.timeout.connect(_on_jump_timeout)
	add_child(_jump_timer)
	_schedule_boss_jump()


func _process(delta: float) -> void:
	# Both motions grow with the combo and settle back to nothing when it
	# breaks. The vertical shake runs faster than the tilt and travels further,
	# so the label reads as shaking up and down rather than swinging.
	var ease_weight := 1.0 - exp(-10.0 * delta)
	_combo_wobble = lerpf(_combo_wobble, _combo_wobble_target, ease_weight)
	_combo_shake = lerpf(_combo_shake, _combo_shake_target, ease_weight)
	_combo_phase += delta * combo_wobble_speed

	combo_value.rotation = deg_to_rad(sin(_combo_phase) * _combo_wobble)

	if _combo_base_ready:
		combo_value.position.y = _combo_base_y + sin(_combo_phase * 1.7) * _combo_shake


# The label lives in a VBoxContainer, so its position belongs to the layout.
# Remember where the container put it, then shake around that point.
func _cache_combo_origin() -> void:
	_combo_base_y = combo_value.position.y
	_combo_base_ready = true
	_recenter_combo_pivot()


# Rotate about the middle of the text rather than the middle of the label box:
# the label is left aligned inside a wider column, so the box centre sits well
# to the right of the glyphs.
func _recenter_combo_pivot() -> void:
	var font := combo_value.get_theme_font("font")
	var font_size := combo_value.get_theme_font_size("font_size")
	var text_size := font.get_string_size(
		combo_value.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size
	)
	combo_value.pivot_offset = Vector2(text_size.x * 0.5, combo_value.size.y * 0.5)


func _on_combo_changed(value: int, mult: float) -> void:
	combo_value.text = "COMBO %d  x%.1f" % [value, mult]
	combo_value.add_theme_color_override(
		"font_color", _heat_color(float(value), COMBO_COLOR_STOPS)
	)

	_combo_wobble_target = clampf(
		float(value-1) * combo_wobble_per_step, 0.0, combo_wobble_max
	)
	_combo_shake_target = clampf(
		float(value-1) * combo_shake_per_step, 0.0, combo_shake_max
	)
	_recenter_combo_pivot()


# Gives both readouts a dark outline so the hotter colours stay readable on the
# wooden score banner.
func _style_value_labels() -> void:
	var outline := Color(0.08, 0.05, 0.02, 1.0)

	score_value.add_theme_color_override("font_outline_color", outline)
	score_value.add_theme_constant_override("outline_size", 6)

	combo_value.add_theme_color_override("font_outline_color", outline)
	combo_value.add_theme_constant_override("outline_size", 4)


func _heat_color(value: float, stops: Array) -> Color:
	if value <= float(stops[0][0]):
		return stops[0][1]

	for i in range(1, stops.size()):
		var high_value := float(stops[i][0])
		if value > high_value:
			continue

		var low_value := float(stops[i - 1][0])
		var low_color: Color = stops[i - 1][1]
		var high_color: Color = stops[i][1]

		var t := 0.0
		if not is_equal_approx(high_value, low_value):
			t = clampf((value - low_value) / (high_value - low_value), 0.0, 1.0)

		return low_color.lerp(high_color, t)

	return stops[stops.size() - 1][1]


func _on_boss_name_changed(value: String) -> void:
	boss_name_label.text = value


func _on_boss_visual_changed(frames_path: String) -> void:
	_apply_boss_frames(frames_path)


# Swaps the boss animation for the current level. A level with no
# "boss_frames" entry falls back to the frames authored in InGameUI.tscn, so
# this stays out of the way of edits made to that scene.
func _apply_boss_frames(frames_path: String) -> void:
	var frames: SpriteFrames = _default_boss_frames

	if not frames_path.is_empty():
		if ResourceLoader.exists(frames_path):
			var override := load(frames_path) as SpriteFrames
			if override != null:
				frames = override
			else:
				push_warning("Boss frames are not a SpriteFrames: %s" % frames_path)
		else:
			push_warning("Boss frames not found: %s" % frames_path)

	if frames == null:
		return

	# A new boss starts visible again, with no lingering kill overlay.
	boss_sprite.visible = true
	if damage_overlay != null:
		damage_overlay.visible = false
	_boss_busy = false

	if boss_sprite.sprite_frames != frames:
		boss_sprite.sprite_frames = frames

	if frames.has_animation(&"idle"):
		boss_sprite.play(&"idle")


func _on_score_changed(value: int) -> void:
	score_value.text = str(value)
	score_value.add_theme_color_override(
		"font_color", _heat_color(float(value), SCORE_COLOR_STOPS)
	)


func _on_boss_health_changed(hp: int, max_hp: int) -> void:
	var damage := 0
	if _last_boss_hp >= 0:
		damage = maxi(0, _last_boss_hp - hp)
	_last_boss_hp = hp

	boss_bar.max_value = max_hp
	boss_value.text = "%d / %d" % [hp, max_hp]

	if _boss_tween != null and _boss_tween.is_valid():
		_boss_tween.kill()

	_boss_tween = create_tween()
	_boss_tween.tween_property(boss_bar, "value", float(hp), 0.8) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	boss_bar.modulate = Color(2.0, 2.0, 2.0, 1.0)
	var flash := create_tween()
	flash.tween_property(boss_bar, "modulate", Color.WHITE, 0.35)

	if damage > 0:
		_play_damage_animation(damage, max_hp, hp)
		


func _on_balls_changed(left: int) -> void:
	balls_value.text = str(left)
	_tint_remaining(balls_value, left, GameStats.balls_per_set)


func _on_rounds_changed(left: int) -> void:
	rounds_value.text = str(left)
	_tint_remaining(rounds_value, left, GameStats.rounds_per_boss)


# Slides a counter from green to red as it runs out, easing between values so
# spending a ball reads as a fade rather than a snap.
func _tint_remaining(label: Label, left: int, maximum: int) -> void:
	var fraction := 0.0
	if maximum > 0:
		fraction = clampf(float(left) / float(maximum), 0.0, 1.0)

	var running: Tween = _color_tweens.get(label)
	if running != null and running.is_valid():
		running.kill()

	var tween := create_tween()
	tween.tween_method(
		func(c: Color) -> void: label.add_theme_color_override("font_color", c),
		label.get_theme_color("font_color"),
		_heat_color(fraction, REMAINING_COLOR_STOPS),
		0.3
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	_color_tweens[label] = tween


func _schedule_boss_jump() -> void:
	if _jump_timer == null:
		return
	_jump_timer.start(rng.randf_range(min_jump_interval, max_jump_interval))


func _on_jump_timeout() -> void:
	if _boss_busy:
		_schedule_boss_jump()
		return

	boss_sprite.play(&"bouncy")


func _on_boss_animation_finished() -> void:
	if boss_sprite.animation == &"bouncy":
		boss_sprite.play(&"idle")
		_schedule_boss_jump()


# Plays the shared damage overlay on top of the boss. Small vs big is decided
# by how much of the boss's max HP the hit removed; a killing blow uses kill.
func _play_damage_animation(damage: int, max_hp: int, hp: int) -> void:
	if damage_overlay == null or damage_overlay.sprite_frames == null:
		return

	var anim_name := BOSS_SMALL_DAMAGE
	var damage_sound: AudioStreamPlayer2D = $TextureRect/notkill
	if hp <= 0:
		anim_name = BOSS_KILL
		damage_sound = $TextureRect/kill
	elif max_hp > 0 and float(damage) / float(max_hp) >= big_damage_fraction:
		anim_name = BOSS_BIG_DAMAGE

	if not damage_overlay.sprite_frames.has_animation(anim_name):
		return

	if _jump_timer != null:
		_jump_timer.stop()
	_boss_busy = true

	damage_overlay.visible = true
	damage_overlay.play(anim_name)
	damage_sound.play()



func _on_damage_overlay_finished() -> void:
	var finished := damage_overlay.animation
	damage_overlay.visible = false
	_boss_busy = false

	if finished == BOSS_KILL:
		boss_sprite.visible = false
		return

	_schedule_boss_jump()


# Rebuilds the little list of upgrades picked so far.
func _on_upgrades_changed() -> void:
	for child in modifiers_list.get_children():
		child.queue_free()

	for upgrade in GameStats.get_upgrades():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)

		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(20, 20)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = _load_upgrade_icon(upgrade)
		row.add_child(icon)

		var label := Label.new()
		label.add_theme_font_override("font", HUD_FONT)
		label.text = str(upgrade.get("name", ""))
		label.add_theme_font_size_override("font_size", 12)
		label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(label)

		modifiers_list.add_child(row)


func _load_upgrade_icon(upgrade: Dictionary) -> Texture2D:
	var path: String = upgrade.get("icon", "")
	if path != "" and ResourceLoader.exists(path):
		var res = load(path)
		if res is Texture2D:
			return res

	var img := Image.create_empty(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(upgrade.get("color", Color.WHITE))
	return ImageTexture.create_from_image(img)
