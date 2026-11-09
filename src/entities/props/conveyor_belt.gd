class_name ConveyorBelt
extends Area3D

## High-speed industrial conveyor belt transferring forward momentum
@export var belt_speed: float = 16.0       ## Target velocity along Z (m/s) ~ 57.6 km/h
@export var belt_acceleration: float = 35.0 ## Acceleration applied to bodies on belt

var tracked_bodies: Array[CharacterBody3D] = []

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _physics_process(delta: float) -> void:
	var forward_dir: Vector3 = transform.basis.z.normalized()
	for body in tracked_bodies:
		if is_instance_valid(body):
			body.velocity = body.velocity.move_toward(forward_dir * belt_speed, belt_acceleration * delta)

func _on_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D and not tracked_bodies.has(body):
		tracked_bodies.append(body)

func _on_body_exited(body: Node3D) -> void:
	if body is CharacterBody3D:
		tracked_bodies.erase(body)
