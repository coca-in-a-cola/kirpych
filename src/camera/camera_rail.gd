class_name CameraRail
extends Camera3D

## Camera following the brick along an authored spline/forward corridor per GDD 5.0
@export var target: Node3D
@export var follow_speed: float = 6.0
@export var camera_offset: Vector3 = Vector3(0.0, 2.4, -4.8)
@export var base_fov: float = 75.0
@export var max_fov: float = 92.0
@export var speed_fov_threshold: float = 35.0 ## km/h

func _ready() -> void:
	fov = base_fov

func _physics_process(delta: float) -> void:
	if not target:
		return
	
	var target_pos: Vector3 = target.global_position
	# Follow behind the target along Z corridor (target.z + offset.z)
	var desired_pos: Vector3 = Vector3(
		lerp(global_position.x, target_pos.x * 0.7, follow_speed * delta),
		lerp(global_position.y, target_pos.y + camera_offset.y, follow_speed * delta),
		target_pos.z + camera_offset.z
	)
	global_position = desired_pos
	
	# Look at a point slightly ahead of the brick
	var look_target: Vector3 = target_pos + Vector3(0.0, 0.4, 3.5)
	look_at(look_target, Vector3.UP)
	
	# Dynamic FOV based on speed
	if target.has_method("get_speed_kmh"):
		var speed_kmh: float = target.get_speed_kmh()
		var fov_factor: float = clampf((speed_kmh - 15.0) / (speed_fov_threshold * 1.5), 0.0, 1.0)
		var target_fov: float = lerp(base_fov, max_fov, fov_factor)
		fov = lerp(fov, target_fov, 4.0 * delta)
