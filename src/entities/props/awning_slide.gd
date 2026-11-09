class_name AwningSlide
extends Area3D

## Ultra low-friction awning/tarp surface
@export var slide_friction: float = 0.05
@export var forward_boost_accel: float = 12.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node3D) -> void:
	if body.has_method("set_surface_friction"):
		body.set_surface_friction(slide_friction)

func _on_body_exited(body: Node3D) -> void:
	if body.has_method("set_surface_friction"):
		body.set_surface_friction(1.8) # Reset to standard ground friction
