class_name BouncyTire
extends Area3D

## High-restitution tire stack providing vertical and forward impulse
@export var bounce_vertical: float = 9.5
@export var bounce_forward: float = 14.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if body.has_method("apply_bounce_impulse"):
		var impulse: Vector3 = Vector3(0.0, bounce_vertical, bounce_forward)
		body.apply_bounce_impulse(impulse)
