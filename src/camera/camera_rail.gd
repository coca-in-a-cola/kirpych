class_name CameraRail
extends Camera3D

## High-feel runner camera following the brick with roll tilt, speed FOV punch, and landing dip
@export var target: Node3D
@export var follow_speed: float = 7.5
@export var camera_offset: Vector3 = Vector3(0.0, 2.3, -4.6)
@export var base_fov: float = 75.0
@export var max_fov: float = 96.0
@export var max_roll_tilt: float = 0.08  ## ~4.5 degrees in radians
@export var tilt_responsiveness: float = 0.35

var landing_dip_offset: float = 0.0
var connected_target: Node3D = null

func _ready() -> void:
	fov = base_fov

func _physics_process(delta: float) -> void:
	if not target:
		return
	
	# Connect landing signal once
	if connected_target != target:
		connected_target = target
		if target.has_signal("landed"):
			target.connect("landed", _on_target_landed)
	
	# Smooth landing dip recovery
	landing_dip_offset = lerpf(landing_dip_offset, 0.0, 10.0 * delta)
	
	var target_pos: Vector3 = target.global_position
	var desired_pos: Vector3 = Vector3(
		lerpf(global_position.x, target_pos.x * 0.75, follow_speed * delta),
		lerpf(global_position.y, target_pos.y + camera_offset.y + landing_dip_offset, follow_speed * delta),
		target_pos.z + camera_offset.z
	)
	global_position = desired_pos
	
	# Look ahead along track
	var look_target: Vector3 = target_pos + Vector3(0.0, 0.35, 4.0)
	look_at(look_target, Vector3.UP)
	
	# Dynamic Roll Tilt on lateral movement (Ghostrunner / Surf feel)
	var lateral_speed: float = 0.0
	if "velocity" in target:
		lateral_speed = target.velocity.x
	var target_roll: float = -clampf(lateral_speed * tilt_responsiveness * 0.03, -max_roll_tilt, max_roll_tilt)
	rotation.z = lerpf(rotation.z, target_roll, 8.0 * delta)
	
	# Dynamic Speed FOV Punch
	if target.has_method("get_speed_kmh"):
		var speed_kmh: float = target.get_speed_kmh()
		var fov_t: float = clampf((speed_kmh - 15.0) / 60.0, 0.0, 1.0)
		var target_fov: float = lerpf(base_fov, max_fov, fov_t)
		fov = lerpf(fov, target_fov, 5.0 * delta)

func _on_target_landed(impact_speed: float) -> void:
	# Subtle camera dip on hard landing
	landing_dip_offset = -clampf(impact_speed * 0.04, 0.08, 0.25)
