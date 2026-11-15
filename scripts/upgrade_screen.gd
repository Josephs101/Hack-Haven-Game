extends Control

signal upgrade_chosen(upgrade: Dictionary)

const OFFERS := [
	{"name": "EXTRA BALL", "desc": "+1 ball next set."},
	{"name": "HEAVY BONES", "desc": "50% boss damage next level."},
	{"name": "LOW GRAVITY", "desc": "Your balls have lower gravity"},
]

@onready var cards: HBoxContainer = %Cards


func _ready() -> void:
	hide()


func open() -> void:
	for child in cards.get_children():
		child.queue_free()

	for i in range(OFFERS.size()):
		var button := Button.new()
		button.custom_minimum_size = Vector2(200, 240)
		button.text = "%s - %s" % [OFFERS[i]["name"], OFFERS[i]["desc"]]
		button.pressed.connect(_on_choice.bind(i))
		cards.add_child(button)

	show()
	await get_tree().process_frame

	var first := cards.get_child(0)
	if first is Button:
		(first as Button).grab_focus()


func _on_choice(index: int) -> void:
	hide()
	upgrade_chosen.emit(OFFERS[index])
