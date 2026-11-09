class_name BrickController
extends CharacterBody3D

## Living Brick controller implementing inertia, sliding, jump flip, and speed metrics per GDD 0.4
signal speed_changed(speed_kmh: float)
signal jumped()
signal bounced()
signal landed(impact_velocity: float)

@export var control_accel: float = 8.5          ## Weak steering acceleration (GDD: input doesn't set speed)
@export var ground_friction: float = 1.8         ## Low sliding friction on flat surfaces
@export var air_drag: float = 0.15              ## Minimal air drag (GDD: equal air control, no artificial penalty)
@export var gravity: float = 18.0               ## Crisp world gravity
@export var jump_impulse: float = 8.5           ## Instant vertical impulse
@export var max_safe_speed: float = 40.0        ## Safety clamping speed (m/s) ~ 144 km/h

## Ghostrunner / Surf standard responsive tuning
@export var coyote_time: float = 0.15           ## 0.15s window after leaving floor where jump still triggers
@export var jump_buffer_time: float = 0.12      ## 0.12s window before landing where pressing jump buffers input
@export var slope_accel_factor: float = 1.8     ## Gravitational acceleration multiplier along slopes
@export var drift_responsiveness: float = 1.5   ## Lateral drift carving factor at high speeds

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

var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var was_on_floor_last_frame: bool = true
var previous_vertical_speed: float = 0.0

func _ready() -> void:
	floor_snap_length = 0.35
	floor_constant_speed = false
	floor_max_angle = deg_to_rad(65.0)

func _physics_process(delta: float) -> void:
	var on_floor: bool = is_on_floor()

	# 1. Coyote Time tracking
	if on_floor:
		coyote_timer = coyote_time
	else:
		coyote_timer = maxf(coyote_timer - delta, 0.0)

	# Hard landing signal detection for camera dip / juiciness
	if on_floor and not was_on_floor_last_frame:
		if previous_vertical_speed < -2.5:
			landed.emit(abs(previous_vertical_speed))
	was_on_floor_last_frame = on_floor
	previous_vertical_speed = velocity.y

	# 2. Gravity & Slope acceleration
	if not on_floor:
		velocity.y -= gravity * delta
	else:
		# Smooth slope acceleration down inclines
		var floor_normal: Vector3 = get_floor_normal()
		var slope_angle: float = floor_normal.angle_to(Vector3.UP)
		if slope_angle > 0.04:
			var slope_dir: Vector3 = Vector3.DOWN.slide(floor_normal).normalized()
			var slope_pull: float = gravity * sin(slope_angle) * slope_accel_factor
			velocity += slope_dir * slope_pull * delta

	# 3. Camera-relative input steering with lateral drift
	var cam: Camera3D = get_viewport().get_camera_3d() if get_viewport() else null
	var cam_basis: Basis = cam.global_transform.basis if cam else Basis.IDENTITY
	var steer_dir: Vector3 = Vector3.ZERO
	if input_controller:
		steer_dir = input_controller.get_movement_vector(cam_basis)

	var horiz_vel: Vector2 = Vector2(velocity.x, velocity.z)
	var speed: float = horiz_vel.length()

	if steer_dir.length_squared() > 0.001:
		var desired_steer_2d: Vector2 = Vector2(steer_dir.x, steer_dir.z).normalized()
		if speed > 2.0:
			# Lateral drift: steering deflects velocity smoothly without snapping
			var current_heading: Vector2 = horiz_vel.normalized()
			var lateral_normal: Vector2 = Vector2(-current_heading.y, current_heading.x)
			var lateral_input: float = desired_steer_2d.dot(lateral_normal)
			var forward_input: float = desired_steer_2d.dot(current_heading)

			var drift_force: Vector2 = lateral_normal * (lateral_input * control_accel * drift_responsiveness * delta)
			var throttle_force: Vector2 = current_heading * (forward_input * control_accel * delta)
			horiz_vel += drift_force + throttle_force

			# Surf standard: maintain momentum while drifting / carving
			if forward_input >= -0.1 and horiz_vel.length() < speed:
				horiz_vel = horiz_vel.normalized() * speed

			velocity.x = horiz_vel.x
			velocity.z = horiz_vel.y
		else:
			velocity.x += steer_dir.x * control_accel * delta
			velocity.z += steer_dir.z * control_accel * delta

	# 4. Surface Friction
	if on_floor:
		var h_vel: Vector2 = Vector2(velocity.x, velocity.z)
		var spd: float = h_vel.length()
		if spd > 0.01:
			var eff_friction: float = current_friction
			var floor_norm: Vector3 = get_floor_normal()
			if floor_norm.angle_to(Vector3.UP) > 0.04:
				var s_dir: Vector3 = Vector3.DOWN.slide(floor_norm).normalized()
				var v_norm: Vector3 = velocity.normalized()
				var downslope_dot: float = clampf(v_norm.dot(s_dir), 0.0, 1.0)
				# Reduce drag when sliding downhill for surf glide
				eff_friction = lerp(current_friction, current_friction * 0.15, downslope_dot)

			var decel: float = eff_friction * delta
			h_vel = h_vel.move_toward(Vector2.ZERO, decel)
			velocity.x = h_vel.x
			velocity.z = h_vel.y
	else:
		# Minimal air resistance
		velocity.x = move_toward(velocity.x, 0.0, air_drag * delta)
		velocity.z = move_toward(velocity.z, 0.0, air_drag * delta)

	# 5. Jump Handling with Jump Buffer & Coyote Time
	if input_controller and input_controller.consume_jump():
		jump_buffer_timer = jump_buffer_time
	elif jump_buffer_timer > 0.0:
		jump_buffer_timer = maxf(jump_buffer_timer - delta, 0.0)

	var can_jump: bool = (on_floor or coyote_timer > 0.0)
	if jump_buffer_timer > 0.0 and can_jump:
		velocity.y = jump_impulse
		jump_buffer_timer = 0.0
		coyote_timer = 0.0
		trigger_decorative_flip()
		if audio_jump and audio_jump.stream:
			audio_jump.play()
		jumped.emit()

	# 6. External Boosts (from bouncy tires / mechanisms)
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

	# 7. Decorative flip update (purely visual, zero effect on collider / body rotation)
	if is_flipping and visual_root:
		flip_progress += delta / flip_duration
		if flip_progress >= 1.0:
			is_flipping = false
			flip_progress = 0.0
			visual_root.rotation.x = 0.0
		else:
			visual_root.rotation.x = -TAU * flip_progress
			visual_root.rotation.y = 0.0
			visual_root.rotation.z = 0.0

	# 8. Speedometer report
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
