extends Node2D

## Generated level: builds the playfield for one endless stage on top of the
## shared LevelScreen, so every level past the authored three gets its own
## layout instead of repeating a scene.

const PEG_SCENE := preload("res://scenes/gameplay/Peg.tscn")
const RED_SCENE := preload("res://scenes/gameplay/RedBumper.tscn")
const BLUE_SCENE := preload("res://scenes/gameplay/BlueBumper.tscn")


func _ready() -> void:
	# The level number already moved on in LevelScreen._load_next_level();
	# this applies its stats and then lays the table out.
	GameStats.start_level(GameStats.current_level)
	_build(GameStats.current_level)


func _build(level: int) -> void:
	var layout := LevelLayout.build(level)

	var index := 0
	for pos in layout["pegs"]:
		index += 1
		_spawn(PEG_SCENE, "Peg%d" % index, pos)

	index = 0
	for pos in layout["red"]:
		index += 1
		_spawn(RED_SCENE, "RedBumper%d" % index, pos)

	index = 0
	for pos in layout["blue"]:
		index += 1
		_spawn(BLUE_SCENE, "BlueBumper%d" % index, pos)


func _spawn(scene: PackedScene, node_name: String, pos: Vector2) -> void:
	var node := scene.instantiate()
	node.name = node_name
	node.position = pos
	add_child(node)
