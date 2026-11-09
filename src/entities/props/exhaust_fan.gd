class_name ExhaustFan
extends Area3D

## High-powered industrial rooftop ventilation fan creating an aerodynamic updraft
@export var wind_force: Vector3 = Vector3(0.0, 22.0, 12.0) ## Upward and forward push

var airborne_bodies: Array[CharacterBody3D] = []

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _physics_process(delta: float) -> void:
	for body in airborne_bodies:
		if is_instance_valid(body):
			body.velocity += wind_force * delta

func _on_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D and not airborne_bodies.has(body):
		airborne_bodies.append(body)

func _on_body_exited(body: Node3D) -> void:
	if body is CharacterBody3D:
		airborne_bodies.erase(body)
