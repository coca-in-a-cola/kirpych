class_name MovingLift
extends AnimatableBody3D

## Vertical construction hoist moving smoothly between bottom and top positions
@export var travel_distance: float = 12.0
@export var cycle_duration: float = 4.5

var origin_y: float = 0.0
var elapsed_time: float = 0.0

func _ready() -> void:
	origin_y = position.y
	sync_to_physics = true

func _physics_process(delta: float) -> void:
	elapsed_time += delta
	# Smooth sinusoidal motion 0.0 -> 1.0 -> 0.0
	var phase: float = (sin((elapsed_time / cycle_duration) * TAU - (PI * 0.5)) + 1.0) * 0.5
	position.y = origin_y + (phase * travel_distance)
