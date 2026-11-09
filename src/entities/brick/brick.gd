class_name BrickController
extends CharacterBody3D

## Living Brick controller implementing inertia, sliding, jump flip, and speed metrics per GDD 0.4
signal speed_changed(speed_kmh: float)
signal jumped()
signal bounced()

@export var control_accel: float = 8.5       ## Weak steering acceleration (GDD: input doesn't set speed)
@export var ground_friction: float = 1.8      ## Low sliding friction on flat surfaces
@export var air_drag: float = 0.15           ## Minimal air drag (GDD: equal air control, no artificial penalty)
@export var gravity: float = 18.0            ## Crisp world gravity
@export var jump_impulse: float = 8.5        ## Instant vertical impulse
@export var max_safe_speed: float = 40.0     ## Safety clamping speed (m/s) ~ 144 km/h

@onready var visual_root: Node3D = $VisualRoot
@onready var input_controller: InputController = $InputController
@onready var audio_jump: AudioStreamPlayer3D = $AudioJump
@onready var audio_slide: AudioStreamPlayer3D = $AudioSlide
@onready var audio_bounce: AudioStreamPlayer3D = $AudioBounce

var is_flipping: bool = false
var flip_progress: float = 0.0
var flip_duration: float = 0.55
var current_friction: float = 1.8
var external_boost: Vector3 = Vector3.ZERO

func _ready() -> void:
	floor_snap_length = 0.3
	floor_constant_speed = false

func _physics_process(delta: float) -> void:
	# 1. Gravity
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		# Apply slope gravity acceleration when sliding on an incline
		var floor_normal: Vector3 = get_floor_normal()
		if floor_normal.angle_to(Vector3.UP) > 0.05:
			var slope_dir: Vector3 = Vector3.DOWN.slide(floor_normal).normalized()
			velocity += slope_dir * gravity * delta * 1.5
	
	# 2. Camera-relative input steering
	var cam: Camera3D = get_viewport().get_camera_3d() if get_viewport() else null
	var cam_basis: Basis = cam.global_transform.basis if cam else Basis.IDENTITY
	var steer_dir: Vector3 = Vector3.ZERO
	if input_controller:
		steer_dir = input_controller.get_movement_vector(cam_basis)
	
	# Apply identical control acceleration grounded & airborne (GDD rule)
	velocity.x += steer_dir.x * control_accel * delta
	velocity.z += steer_dir.z * control_accel * delta
	
	# 3. Surface Friction
	if is_on_floor():
		var horiz_vel: Vector2 = Vector2(velocity.x, velocity.z)
		var speed: float = horiz_vel.length()
		if speed > 0.01:
			var decel: float = current_friction * delta
			horiz_vel = horiz_vel.move_toward(Vector2.ZERO, decel)
			velocity.x = horiz_vel.x
			velocity.z = horiz_vel.y
	else:
		# Minimal air resistance
		velocity.x = move_toward(velocity.x, 0.0, air_drag * delta)
		velocity.z = move_toward(velocity.z, 0.0, air_drag * delta)
	
	# 4. Jump Handling
	if input_controller and input_controller.consume_jump() and is_on_floor():
		velocity.y = jump_impulse
		trigger_decorative_flip()
		if audio_jump and audio_jump.stream:
			audio_jump.play()
		jumped.emit()
	
	# 5. External Boosts (from bouncy tires / mechanisms)
	if external_boost != Vector3.ZERO:
		velocity += external_boost
		external_boost = Vector3.ZERO
		if audio_bounce and audio_bounce.stream:
			audio_bounce.play()
		bounced.emit()
	
	# Clamping for simulation stability
	velocity = velocity.clamp(Vector3(-max_safe_speed, -max_safe_speed, -max_safe_speed),
							  Vector3(max_safe_speed, max_safe_speed, max_safe_speed))
	
	move_and_slide()
	
	# 6. Decorative flip update (purely visual, zero effect on collider)
	if is_flipping and visual_root:
		flip_progress += delta / flip_duration
		if flip_progress >= 1.0:
			is_flipping = false
			flip_progress = 0.0
			visual_root.rotation.x = 0.0
		else:
			visual_root.rotation.x = -TAU * flip_progress
	
	# 7. Speedometer report
	speed_changed.emit(get_speed_kmh())

func trigger_decorative_flip() -> void:
	is_flipping = true
	flip_progress = 0.0

func apply_bounce_impulse(impulse: Vector3) -> void:
	external_boost = impulse

func set_surface_friction(f: float) -> void:
	current_friction = f

func get_speed_kmh() -> float:
	return velocity.length() * 3.6
