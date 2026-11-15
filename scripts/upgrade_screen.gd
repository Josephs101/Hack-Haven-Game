extends Control

signal upgrade_chosen(id: String)

const OFFER_COUNT := 3
const CARD_FONT := preload("res://assets/font(s)/Minecraft.ttf")
const CARD_TEXTURE := preload("res://assets/sprites/card.png")
const CARD_BORDER := 6

@onready var cards: HBoxContainer = %Cards


func _ready() -> void:
	hide()


func open() -> void:
	for child in cards.get_children():
		child.queue_free()

	for id in _pick_offers():
		cards.add_child(_make_card(id))

	show()
	await get_tree().process_frame

	if cards.get_child_count() > 0:
		var first_btn := cards.get_child(0).find_child("UpgradeButton", true, false)
		if first_btn is Button:
			(first_btn as Button).grab_focus()


func _pick_offers() -> Array:
	var ids: Array = GameStats.UPGRADES.keys()
	ids.shuffle()
	return ids.slice(0, mini(OFFER_COUNT, ids.size()))


func _make_card(id: String) -> Control:
	var data: Dictionary = GameStats.UPGRADES[id]

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(170, 240)
	panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	panel.add_theme_stylebox_override("panel", _make_card_style())

	var card := VBoxContainer.new()
	card.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_theme_constant_override("separation", 8)
	panel.add_child(card)

	var btn := Button.new()
	btn.name = "UpgradeButton"
	btn.custom_minimum_size = Vector2(120, 120)
	btn.icon = _load_icon(data)
	btn.expand_icon = true
	btn.tooltip_text = data["desc"]
	btn.pressed.connect(_on_choice.bind(id))
	card.add_child(btn)

	var name_label := Label.new()
	name_label.text = data["name"]
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 22)
	name_label.add_theme_font_override("font", CARD_FONT)
	card.add_child(name_label)

	var desc_label := Label.new()
	desc_label.text = data["desc"]
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.custom_minimum_size = Vector2(160, 56)
	desc_label.add_theme_font_size_override("font_size", 14)
	desc_label.add_theme_font_override("font", CARD_FONT)
	card.add_child(desc_label)

	return panel


func _make_card_style() -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = CARD_TEXTURE
	style.texture_margin_left = CARD_BORDER
	style.texture_margin_top = CARD_BORDER
	style.texture_margin_right = CARD_BORDER
	style.texture_margin_bottom = CARD_BORDER
	style.content_margin_left = 12
	style.content_margin_top = 12
	style.content_margin_right = 12
	style.content_margin_bottom = 12
	return style


func _load_icon(data: Dictionary) -> Texture2D:
	var path: String = data.get("icon", "")
	if path != "" and ResourceLoader.exists(path):
		var res = load(path)
		if res is Texture2D:
			return res
	return _make_placeholder(data.get("color", Color.WHITE))


func _make_placeholder(color: Color) -> Texture2D:
	var img := Image.create_empty(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(color)
	return ImageTexture.create_from_image(img)


func _on_choice(id: String) -> void:
	hide()
	upgrade_chosen.emit(id)
