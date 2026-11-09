class_name PendulumCrane
extends AnimatableBody3D

## Crane suspended concrete counterweight swinging like a harmonic pendulum
@export var swing_amplitude: float = 6.5
@export var swing_period: float = 3.8

var origin_z: float = 0.0
var elapsed_time: float = 0.0

func _ready() -> void:
	origin_z = position.z
	sync_to_physics = true

func _physics_process(delta: float) -> void:
	elapsed_time += delta
	var phase: float = sin((elapsed_time / swing_period) * TAU)
	position.z = origin_z + (phase * swing_amplitude)
