extends RigidBody2D


func _ready() -> void:
	contact_monitor = true
	max_contacts_reported = 8
	body_entered.connect(_on_body_entered)
	gravity_scale *= GameStats.gravity_multiplier


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("scoreable"):
		GameStats.register_hit()
