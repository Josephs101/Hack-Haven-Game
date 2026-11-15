extends Control

## Big centre-screen damage readout, shown when a ball drains.
##
## The number comes from GameStats.damage_from_points(), the single conversion
## point, so whatever that formula becomes later this readout stays correct.
## It fades in, holds a beat and clears well before the round-clear panel opens.

const FONT := preload("res://assets/font(s)/Minecraft.ttf")

const CAPTION_COLOR := Color(1.0, 0.62, 0.58, 1.0)
const AMOUNT_COLOR := Color(1.0, 0.22, 0.18, 1.0)
const TOTAL_COLOR := Color(0.93, 0.9, 0.9, 1.0)
const OUTLINE_COLOR := Color(0.09, 0.02, 0.02, 1.0)

@export var fade_in := 0.10
@export var hold := 0.45
@export var fade_out := 0.25

var _block: VBoxContainer
var _amount: Label
var _total: Label
var _tween: Tween = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

	_build()
	GameStats.ball_damage.connect(_on_ball_damage)


func _build() -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	_block = VBoxContainer.new()
	_block.alignment = BoxContainer.ALIGNMENT_CENTER
	_block.add_theme_constant_override("separation", -4)
	center.add_child(_block)

	_block.add_child(_make_label("DAMAGE", 28, CAPTION_COLOR, 5))

	_amount = _make_label("+0", 84, AMOUNT_COLOR, 11)
	_block.add_child(_amount)

	_total = _make_label("TOTAL 0", 24, TOTAL_COLOR, 4)
	_block.add_child(_total)


func _make_label(text: String, size: int, color: Color, outline: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", OUTLINE_COLOR)
	label.add_theme_constant_override("outline_size", outline)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _on_ball_damage(amount: int, total: int) -> void:
	if amount <= 0:
		return

	_amount.text = "+%d" % amount
	_total.text = "TOTAL %d" % total

	visible = true
	modulate.a = 0.0

	_block.pivot_offset = _block.size * 0.5
	_block.scale = Vector2(0.85, 0.85)

	if _tween != null and _tween.is_valid():
		_tween.kill()

	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(self, "modulate:a", 1.0, fade_in)
	_tween.tween_property(_block, "scale", Vector2.ONE, 0.22) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	_tween.chain().tween_interval(hold)
	_tween.chain().tween_property(self, "modulate:a", 0.0, fade_out)
	_tween.chain().tween_callback(_hide)


func _hide() -> void:
	visible = false
