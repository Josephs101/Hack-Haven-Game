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

# Peg-hit "pinball" ding. Its pitch climbs with the combo.
const PINBALL_SOUND := preload("res://assets/sound/PINBALL.wav")
const PINBALL_VOICES := 4

# Bumper hit. Played quietly and cut short so it reads as a tick, not the full clip.
const BOUNCER_SOUND := preload("res://assets/sound/BOUNCER_HIT.wav")
const BOUNCER_VOICES := 4
const BOUNCER_VOLUME_DB :=3.0
const BOUNCER_SECONDS := 0.14

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
@onready var ability_value: Label = $AbilityContainer/AbilityBlock/RoundsValue
@onready var ability_block: VBoxContainer = $AbilityContainer/AbilityBlock
@onready var ability_container: PanelContainer = $AbilityContainer
@onready var ability_background: TextureRect = $AbilityContainer/AbilityBlock/RoundsValue/TextureRect2
var ability_icon: TextureRect = null
var _pinball_players: Array[AudioStreamPlayer] = []
var _pinball_voice := 0
var _bouncer_players: Array[AudioStreamPlayer] = []
var _bouncer_voice := 0
@onready var best_reached: Label = %BestReached

const HUD_FONT := preload("res://assets/font(s)/Minecraft.ttf")

var _boss_tween: Tween = null
var _default_boss_frames: SpriteFrames = null
var _default_frame_height := 32.0
var _idle_anim := &"idle"
var _jump_anim := &"bouncy"

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
var _ability_short := "NONE"

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
	GameStats.ability_changed.connect(_on_ability_changed)
	GameStats.peg_hit.connect(_on_peg_hit)
	GameStats.bouncer_hit.connect(_on_bouncer_hit)
	GameStats.best_bosses_changed.connect(_on_best_bosses_changed)

	_setup_pinball_sound()
	_setup_bouncer_sound()

	boss_bar.max_value = GameStats.boss_max_hp
	boss_bar.value = GameStats.boss_hp
	boss_value.text = "%d / %d" % [GameStats.boss_hp, GameStats.boss_max_hp]

	_style_value_labels()
	_build_ability_icon()
	modifiers_list.add_theme_constant_override("separation", 2)
	_on_score_changed(GameStats.score)
	_on_combo_changed(GameStats.combo, GameStats.multiplier)
	_on_boss_name_changed(GameStats.boss_name)
	_on_balls_changed(GameStats.balls_left)
	_on_rounds_changed(GameStats.rounds_left)
	_on_upgrades_changed()
	_on_ability_changed(GameStats.current_ability)
	_refresh_best_reached()

	combo_value.resized.connect(_recenter_combo_pivot)
	call_deferred("_cache_combo_origin")

	rng.randomize()
	_default_boss_frames = boss_sprite.sprite_frames
	_default_frame_height = _first_frame_height(_default_boss_frames)
	_apply_boss_frames(GameStats.boss_frames_path)
	boss_sprite.animation_finished.connect(_on_boss_animation_finished)
	boss_sprite.play(_idle_anim)

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

	_update_ability_label()


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

	_pick_animations(frames)
	_align_boss_sprite(frames)

	if frames.has_animation(_idle_anim):
		boss_sprite.play(_idle_anim)


# Boss sheets don't agree on animation names: the slime and cyclops use
# idle / bouncy, while the mini boss ships mini-idle / mini-jump.
func _pick_animations(frames: SpriteFrames) -> void:
	if frames.has_animation(&"mini-idle"):
		_idle_anim = &"mini-idle"
		_jump_anim = &"mini-jump" if frames.has_animation(&"mini-jump") else &"mini-idle"
	else:
		_idle_anim = &"idle"
		_jump_anim = &"bouncy"


func _first_frame_height(frames: SpriteFrames) -> float:
	if frames == null or not frames.has_animation(&"idle"):
		return 32.0

	var texture := frames.get_frame_texture(&"idle", 0)
	if texture == null:
		return 32.0

	return float(texture.get_height())


# The mini boss sheet is 32x64, so its art would sit lower in the HUD than the
# 32x32 bosses. Nudge the sprite up by half the height difference.
func _align_boss_sprite(frames: SpriteFrames) -> void:
	if not frames.has_animation(_idle_anim):
		boss_sprite.offset = Vector2.ZERO
		return

	var texture := frames.get_frame_texture(_idle_anim, 0)
	if texture == null:
		boss_sprite.offset = Vector2.ZERO
		return

	boss_sprite.offset = Vector2(0, -(texture.get_height() - _default_frame_height) * 0.5)


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

	boss_sprite.play(_jump_anim)


func _on_boss_animation_finished() -> void:
	if boss_sprite.animation == _jump_anim:
		boss_sprite.play(_idle_anim)
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


# The furthest run ever, shown under the modifiers so the target is visible
# while playing. Updates the moment a new record is set.
func _refresh_best_reached() -> void:
	var best := GameStats.best_bosses

	if best <= 0:
		best_reached.text = "BEST: 0 BOSSES"
		return

	var noun := "BOSS" if best == 1 else "BOSSES"
	best_reached.text = "BEST: %d %s" % [best, noun]


func _on_best_bosses_changed(_best: int) -> void:
	_refresh_best_reached()


func _setup_pinball_sound() -> void:
	for i in range(PINBALL_VOICES):
		var player := AudioStreamPlayer.new()
		player.stream = PINBALL_SOUND
		player.volume_db = 24.0
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(player)
		_pinball_players.append(player)


# Fired by peg.gd every time a ball touches a peg. Pitch rises with the combo.
func _on_peg_hit(combo: int) -> void:
	if _pinball_players.is_empty():
		return

	var player := _pinball_players[_pinball_voice]
	_pinball_voice = (_pinball_voice + 1) % _pinball_players.size()
	player.pitch_scale = clampf(1.0 + float(combo) * 0.15, 1.0, 3.0)
	player.play()


func _setup_bouncer_sound() -> void:
	for i in range(BOUNCER_VOICES):
		var player := AudioStreamPlayer.new()
		player.stream = BOUNCER_SOUND
		player.volume_db = BOUNCER_VOLUME_DB
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(player)
		_bouncer_players.append(player)


# Fired by bumper.gd when a ball hits a bumper.
func _on_bouncer_hit() -> void:
	if _bouncer_players.is_empty():
		return

	var player := _bouncer_players[_bouncer_voice]
	_bouncer_voice = (_bouncer_voice + 1) % _bouncer_players.size()
	player.play()
	_stop_sound_after(player, BOUNCER_SECONDS)


# Cut the tail off the clip so the hit stays short.
func _stop_sound_after(player: AudioStreamPlayer, seconds: float) -> void:
	await get_tree().create_timer(seconds, true).timeout
	if is_instance_valid(player) and player.playing:
		player.stop()


func _build_ability_icon() -> void:
	ability_icon = TextureRect.new()
	ability_icon.name = "AbilityIcon"
	ability_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ability_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ability_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	ability_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ability_icon.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ability_icon.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ability_icon.visible = false
	ability_container.add_child(ability_icon)
	ability_container.move_child(ability_icon, 0)


# Shows the equipped ability in the HUD box.
func _on_ability_changed(_id: String) -> void:
	if ability_icon == null:
		_build_ability_icon()

	_ability_short = "NONE"
	var icon_path := ""

	if GameStats.ABILITIES.has(GameStats.current_ability):
		var data: Dictionary = GameStats.ABILITIES[GameStats.current_ability]
		_ability_short = str(data.get("short", "NONE"))
		icon_path = str(data.get("icon", ""))

	var show_icon := icon_path != "" and ResourceLoader.exists(icon_path)
	if show_icon:
		ability_icon.texture = load(icon_path) as Texture2D

	ability_icon.visible = show_icon
	ability_background.visible = not show_icon

	ability_value.add_theme_font_size_override("font_size", 16)
	_update_ability_label()


func _update_ability_label() -> void:
	if GameStats.ability_cooldown > 0.0:
		ability_value.text = "%s %ds" % [_ability_short, ceili(GameStats.ability_cooldown)]
	else:
		ability_value.text = _ability_short


# Rebuilds the little list of upgrades picked so far.
func _on_upgrades_changed() -> void:
	for child in modifiers_list.get_children():
		child.queue_free()

	for upgrade in GameStats.get_upgrades():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 2)

		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(50, 50)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon.texture = _load_upgrade_icon(upgrade)
		row.add_child(icon)

		var label := Label.new()
		label.add_theme_font_override("font", HUD_FONT)
		label.text = str(upgrade.get("name", ""))
		label.add_theme_font_size_override("font_size", 14)
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
