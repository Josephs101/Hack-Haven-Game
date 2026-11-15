class_name LevelLayout
extends RefCounted

## Builds a fair, symmetric pinball layout for a generated (endless) level.
##
## Only the left half is drafted; everything is mirrored across the playfield
## centre so a level can never be lopsided and every route has a twin. Each
## candidate is then checked against the ones already placed — no sprite
## overlaps and always a little breathing room — so the result stays playable
## however the numbers are tuned.
##
## Layouts are seeded from the level number, so level 7 is always the same
## level 7: predictable for the player, and no risk of a lucky-dip unfair one.

const CENTER_X := 480.0
const MIN_X := 252.0
const MAX_X := 708.0
const MIN_Y := 300.0
const MAX_Y := 900.0

# Bumpers are 48px across, so they need their own inner limit or the sprite
# bleeds into the side wall.
const BUMPER_MIN_X := 280.0
const BUMPER_MAX_X := 680.0

# The upper flipper pair lives here; nothing may be generated on top of it.
const FLIPPER_BAND_MIN_Y := 795.0
const FLIPPER_BAND_MAX_Y := 870.0
const FLIPPER_BAND_MIN_X := 290.0

const PEG_RADIUS := 14.0
const BUMPER_RADIUS := 48.0
const GAP := 20.0

const PATTERNS := ["ring", "arcs", "diamond", "lanes"]

# Extra peg slots used to make later tiers busier.
const EXTRA_SLOTS := [
	Vector2(420, 320), Vector2(400, 860),
	Vector2(420, 400), Vector2(420, 780),
]


static func build(level: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261115 + level * 7919

	var tier := maxi(0, level - 3)
	var pattern: String = PATTERNS[tier % PATTERNS.size()]

	var half: Array = []
	match pattern:
		"ring":
			half = _ring_half(rng)
		"arcs":
			half = _arcs_half(rng)
		"diamond":
			half = _diamond_half(rng)
		_:
			half = _lanes_half(rng)

	half.append_array(_extra_pegs(rng, tier))
	half = _clean_half(half)

	var pegs: Array[Vector2] = []
	var red: Array[Vector2] = []
	var blue: Array[Vector2] = []

	for item in _mirror(half):
		match item["kind"]:
			"peg":
				pegs.append(item["pos"])
			"red":
				red.append(item["pos"])
			_:
				blue.append(item["pos"])

	return {"pegs": pegs, "red": red, "blue": blue, "pattern": pattern, "tier": tier}


# --- pattern drafts (left half only) ---------------------------------------

static func _ring_half(rng: RandomNumberGenerator) -> Array:
	var centre := Vector2(CENTER_X, 560.0)
	var items: Array = []

	for angle in [135.0, 180.0, 225.0]:
		var radians := deg_to_rad(angle)
		var pos := centre + Vector2(170.0 * cos(radians), 150.0 * sin(radians))
		items.append(_item("peg", _jitter(rng, pos, 8.0)))

	items.append(_item("peg", _jitter_y(rng, Vector2(CENTER_X, 390.0), 10.0)))
	items.append(_item("peg", _jitter_y(rng, Vector2(CENTER_X, 730.0), 10.0)))
	items.append(_item("blue", _jitter(rng, Vector2(400.0, 560.0), 10.0)))
	items.append(_item("red", _jitter(rng, Vector2(300.0, 340.0), 8.0)))
	items.append(_item("red", _jitter(rng, Vector2(300.0, 800.0), 8.0)))
	return items


static func _arcs_half(rng: RandomNumberGenerator) -> Array:
	var items: Array = []

	var upper := [Vector2(330, 430), Vector2(390, 370), Vector2(450, 320)]
	for pos in upper:
		items.append(_item("peg", _jitter(rng, pos, 10.0)))

	var lower := [Vector2(330, 690), Vector2(390, 750), Vector2(450, 800)]
	for pos in lower:
		items.append(_item("peg", _jitter(rng, pos, 10.0)))

	items.append(_item("blue", _jitter(rng, Vector2(350.0, 560.0), 10.0)))
	items.append(_item("red", _jitter_y(rng, Vector2(CENTER_X, 470.0), 12.0)))
	items.append(_item("red", _jitter_y(rng, Vector2(CENTER_X, 660.0), 12.0)))
	return items


static func _diamond_half(rng: RandomNumberGenerator) -> Array:
	var items: Array = [
		_item("peg", _jitter_y(rng, Vector2(CENTER_X, 330.0), 10.0)),
		_item("peg", _jitter_y(rng, Vector2(CENTER_X, 810.0), 10.0)),
		_item("peg", _jitter(rng, Vector2(400.0, 470.0), 10.0)),
		_item("peg", _jitter(rng, Vector2(400.0, 660.0), 10.0)),
		_item("blue", _jitter(rng, Vector2(325.0, 565.0), 10.0)),
		_item("red", _jitter(rng, Vector2(320.0, 370.0), 8.0)),
		_item("red", _jitter(rng, Vector2(320.0, 760.0), 8.0)),
	]
	return items


static func _lanes_half(rng: RandomNumberGenerator) -> Array:
	var items: Array = []

	for i in range(4):
		var pos := Vector2(330.0, 340.0 + i * 160.0)
		items.append(_item("peg", _jitter(rng, pos, 8.0)))

	items.append(_item("peg", _jitter_y(rng, Vector2(CENTER_X, 400.0), 10.0)))
	items.append(_item("peg", _jitter_y(rng, Vector2(CENTER_X, 720.0), 10.0)))
	items.append(_item("blue", _jitter(rng, Vector2(410.0, 560.0), 10.0)))
	items.append(_item("red", _jitter(rng, Vector2(292.0, 420.0), 6.0)))
	items.append(_item("red", _jitter(rng, Vector2(292.0, 740.0), 6.0)))
	return items


# Later tiers get a couple more pegs, so levels get busier without ever
# turning into a wall the ball can't get through.
static func _extra_pegs(rng: RandomNumberGenerator, tier: int) -> Array:
	var items: Array = []
	var count := mini(tier / 2, EXTRA_SLOTS.size())

	for i in range(count):
		items.append(_item("peg", _jitter(rng, EXTRA_SLOTS[i], 6.0)))

	return items


# --- helpers ---------------------------------------------------------------

static func _item(kind: String, pos: Vector2) -> Dictionary:
	return {"kind": kind, "pos": pos}


static func _jitter(rng: RandomNumberGenerator, pos: Vector2, amount: float) -> Vector2:
	return pos + Vector2(rng.randf_range(-amount, amount), rng.randf_range(-amount, amount))


# Centre-line pieces only wobble vertically, so they stay single pieces.
static func _jitter_y(rng: RandomNumberGenerator, pos: Vector2, amount: float) -> Vector2:
	return Vector2(CENTER_X, pos.y + rng.randf_range(-amount, amount))


static func _mirror(half: Array) -> Array:
	var out: Array = []

	for item in half:
		out.append(item)

		var pos: Vector2 = item["pos"]
		if not is_equal_approx(pos.x, CENTER_X):
			out.append(_item(item["kind"], Vector2(CENTER_X * 2.0 - pos.x, pos.y)))

	return out


# Keeps a candidate only if it is inside the playfield, has room to everything
# already kept (including their mirrors), and is not crowding its own mirror.
static func _clean_half(items: Array) -> Array:
	var kept: Array = []

	for item in items:
		var pos: Vector2 = item["pos"]

		# Anything drafted near the centre line belongs ON it, otherwise its
		# mirror would land almost on top of it.
		if absf(pos.x - CENTER_X) < 25.0:
			pos.x = CENTER_X

		if pos.x < MIN_X or pos.x > CENTER_X or pos.y < MIN_Y or pos.y > MAX_Y:
			continue

		# Bumpers are much wider than pegs, so they need more wall clearance.
		if item["kind"] != "peg" and pos.x < BUMPER_MIN_X:
			continue

		# Keep the upper flipper pair's swing area clear.
		if pos.y >= FLIPPER_BAND_MIN_Y and pos.y <= FLIPPER_BAND_MAX_Y and pos.x >= FLIPPER_BAND_MIN_X:
			continue

		if _clashes(item["kind"], pos, kept):
			continue

		if not is_equal_approx(pos.x, CENTER_X):
			if _clashes(item["kind"], Vector2(CENTER_X * 2.0 - pos.x, pos.y), kept):
				continue
			if pos.distance_to(Vector2(CENTER_X * 2.0 - pos.x, pos.y)) < _spacing(item["kind"], item["kind"]):
				continue

		kept.append({"kind": item["kind"], "pos": pos})

	return kept


static func _clashes(kind: String, pos: Vector2, kept: Array) -> bool:
	for other in kept:
		var needed := _spacing(kind, other["kind"])
		var other_pos: Vector2 = other["pos"]

		if pos.distance_to(other_pos) < needed:
			return true

		if not is_equal_approx(other_pos.x, CENTER_X):
			var mirrored := Vector2(CENTER_X * 2.0 - other_pos.x, other_pos.y)
			if pos.distance_to(mirrored) < needed:
				return true

	return false


# Visual radii plus a margin. Bumpers overlap visually below 96px, pegs below
# 28px, and a little air on top keeps the table readable.
static func _spacing(kind_a: String, kind_b: String) -> float:
	var radius_a := PEG_RADIUS if kind_a == "peg" else BUMPER_RADIUS
	var radius_b := PEG_RADIUS if kind_b == "peg" else BUMPER_RADIUS
	return radius_a + radius_b + GAP
