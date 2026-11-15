extends Control

@onready var score_value: Label = %ScoreValue
@onready var boss_bar: ProgressBar = %BossBar
@onready var balls_value: Label = %BallsValue
@onready var rounds_value: Label = %RoundsValue
@onready var boss_value: Label = %BossHealthLabel
@onready var boss_sprite: AnimatedSprite2D = %AnimatedSprite2D
@export var min_jump_interval: float = 2.0
@export var max_jump_interval: float = 5.0
@onready var combo_value: Label = %ComboValue
@onready var boss_name_label: Label = %BossName
@onready var modifiers_list: VBoxContainer = %ModifiersList

var _boss_tween: Tween = null
const HUD_FONT := preload("res://assets/font(s)/Minecraft.ttf")

var rng = RandomNumberGenerator.new()

func _ready() -> void:
	GameStats.score_changed.connect(_on_score_changed)
	GameStats.combo_changed.connect(_on_combo_changed)
	GameStats.boss_health_changed.connect(_on_boss_health_changed)
	GameStats.boss_name_changed.connect(_on_boss_name_changed)
	GameStats.balls_changed.connect(_on_balls_changed)
	GameStats.rounds_changed.connect(_on_rounds_changed)
	GameStats.upgrades_changed.connect(_on_upgrades_changed)

	boss_bar.max_value = GameStats.boss_max_hp
	boss_bar.value = GameStats.boss_hp
	boss_value.text = "%d / %d" % [GameStats.boss_hp, GameStats.boss_max_hp]

	_on_score_changed(GameStats.score)
	_on_combo_changed(GameStats.combo, GameStats.multiplier)
	_on_boss_name_changed(GameStats.boss_name)
	_on_balls_changed(GameStats.balls_left)
	_on_rounds_changed(GameStats.rounds_left)
	_on_upgrades_changed()

	rng.randomize()
	boss_sprite.animation_finished.connect(_on_boss_animation_finished)
	boss_sprite.play("idle")
	_schedule_boss_jump()


func _on_combo_changed(value: int, mult: float) -> void:
	combo_value.text = "COMBO %d  x%.1f" % [value, mult]


func _on_boss_name_changed(value: String) -> void:
	boss_name_label.text = value


func _on_score_changed(value: int) -> void:
	score_value.text = str(value)


func _on_boss_health_changed(hp: int, max_hp: int) -> void:
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


func _on_balls_changed(left: int) -> void:
	balls_value.text = str(left)


func _on_rounds_changed(left: int) -> void:
	rounds_value.text = str(left)


func _schedule_boss_jump() -> void:
	var wait_time = rng.randf_range(
		min_jump_interval,
		max_jump_interval
	)

	await get_tree().create_timer(wait_time).timeout

	boss_sprite.play("bouncy")


func _on_boss_animation_finished() -> void:
	if boss_sprite.animation == "bouncy":
		boss_sprite.play("idle")
		_schedule_boss_jump()


func _on_upgrades_changed() -> void:
	for child in modifiers_list.get_children():
		child.queue_free()

	for upgrade in GameStats.get_upgrades():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)

		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(32, 32)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = _load_upgrade_icon(upgrade)
		row.add_child(icon)

		var label := Label.new()
		label.add_theme_font_override("font", HUD_FONT)
		label.text = str(upgrade.get("name", ""))
		label.add_theme_font_size_override("font_size", 16)
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
