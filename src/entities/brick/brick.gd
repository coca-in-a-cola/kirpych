class_name BrickController
extends CharacterBody3D

## Living Brick controller implementing inertia, sliding, jump flip, and speed metrics per GDD 0.4.
## GDD 4: player input is a WEAK force that never sets speed; gravity along slopes and mechanisms
## (tires, conveyors, lifts) are the primary speed source. Velocity is never renormalised.
signal speed_changed(speed_kmh: float)
signal jumped()
signal bounced()
signal landed(impact_velocity: float)

@export var control_accel: float = 7.0          ## Peak self-propulsion force at rest (m/s^2), identical on ground and in air (GDD 3.3)
@export var self_propel_max_speed: float = 9.0  ## Input thrust fades linearly to zero at this speed along the input direction (m/s)
@export var ground_friction: float = 1.8         ## Base sliding friction (m/s^2) of a standard surface at rest
@export var friction_speed_ref: float = 18.0     ## Speed (m/s) at which sliding friction doubles: f = mu * (1 + v / ref)
@export var air_drag: float = 0.15              ## Minimal air drag (GDD: equal air control, no artificial penalty)
@export var gravity: float = 18.0               ## Crisp world gravity
@export var jump_impulse: float = 8.5           ## Instant vertical impulse
@export var max_safe_speed: float = 40.0        ## Simulation-stability limit on |horizontal velocity| and |vertical velocity| (m/s) ~ 144 km/h

## Ghostrunner / Surf standard responsive tuning
@export var coyote_time: float = 0.15           ## 0.15s window after leaving floor where jump still triggers
@export var jump_buffer_time: float = 0.12      ## 0.12s window before landing where pressing jump buffers input

## Below this horizontal speed input is applied as a plain vector force (no heading to steer yet)
const STEER_MIN_SPEED: float = 0.5

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
	current_friction = ground_friction

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

	# 2. Gravity & slope acceleration
	if not on_floor:
		velocity.y -= gravity * delta
	else:
		# Real projected gravity: the component of g along the floor plane is g * sin(angle).
		var floor_normal: Vector3 = get_floor_normal()
		var slope_angle: float = floor_normal.angle_to(Vector3.UP)
		if slope_angle > 0.04:
			var slope_dir: Vector3 = Vector3.DOWN.slide(floor_normal).normalized()
			velocity += slope_dir * (gravity * sin(slope_angle)) * delta

	# 3. Camera-relative weak input force
	var cam: Camera3D = get_viewport().get_camera_3d() if get_viewport() else null
	# Use the camera's roll/pitch-free movement basis when it provides one (CameraRail), so the visual
	# roll-tilt juice can never skew WASD; fall back to the raw camera transform otherwise.
	var cam_basis: Basis = Basis.IDENTITY
	if cam:
		cam_basis = cam.call("get_movement_basis") if cam.has_method("get_movement_basis") else cam.global_transform.basis
	var steer_dir: Vector3 = Vector3.ZERO
	if input_controller:
		steer_dir = input_controller.get_movement_vector(cam_basis)

	if steer_dir.length_squared() > 0.001:
		_apply_input_force(Vector2(steer_dir.x, steer_dir.z).normalized(), delta)

	# 4. Surface friction (speed-dependent) / air drag
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

			# Friction grows with speed so flat ground has a natural low equilibrium for self-propulsion
			# and long flat coasts bleed off; it scales with the surface coefficient (awnings stay slick).
			var decel: float = eff_friction * (1.0 + spd / friction_speed_ref) * delta
			h_vel = h_vel.move_toward(Vector2.ZERO, decel)
			velocity.x = h_vel.x
			velocity.z = h_vel.y
	else:
		# Minimal air resistance, applied to the horizontal vector (not per axis)
		var a_vel: Vector2 = Vector2(velocity.x, velocity.z).move_toward(Vector2.ZERO, air_drag * delta)
		velocity.x = a_vel.x
		velocity.z = a_vel.y

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

	# 6. External Boosts (from bouncy tires / mechanisms) — primary speed source, not input-limited
	if external_boost != Vector3.ZERO:
		velocity += external_boost
		external_boost = Vector3.ZERO
		if audio_bounce and audio_bounce.stream:
			audio_bounce.play()
		bounced.emit()

	# Simulation-stability clamp: limit the horizontal VECTOR length (no diagonal leak), vertical separately.
	var horiz: Vector2 = Vector2(velocity.x, velocity.z).limit_length(max_safe_speed)
	velocity = Vector3(horiz.x, clampf(velocity.y, -max_safe_speed, max_safe_speed), horiz.y)

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

## Applies the weak control force (same on ground and in air, GDD 3.3).
## - Thrust along the current heading fades to zero at self_propel_max_speed: input alone cannot
##   push the brick fast; slopes and mechanisms can, because their acceleration is not faded.
## - Braking (input against the heading) always gets the full force.
## - The lateral component only ROTATES the existing velocity (magnitude preserved) by the angle
##   the same force would deflect it, so carving redirects momentum and never adds kinetic energy.
##   Turning gets slower at high speed purely from inertia (angle ~ a*dt / v), per the GDD
##   acceptance rule "harder to turn at speed because of inertia, not artificial control cuts".
func _apply_input_force(wish: Vector2, delta: float) -> void:
	var horiz_vel: Vector2 = Vector2(velocity.x, velocity.z)
	var speed: float = horiz_vel.length()
	var dv: float = control_accel * delta

	if speed < STEER_MIN_SPEED:
		horiz_vel += wish * dv * _propulsion_factor(maxf(horiz_vel.dot(wish), 0.0))
	else:
		var heading: Vector2 = horiz_vel / speed
		var along: float = wish.dot(heading)
		var lateral: Vector2 = wish - heading * along

		var new_speed: float = speed
		if along > 0.0:
			new_speed += along * dv * _propulsion_factor(speed)
		else:
			new_speed += along * dv  # full braking force

		var lateral_len: float = lateral.length()
		if lateral_len > 0.0001:
			var turn: float = atan2(lateral_len * dv, speed)
			heading = heading.rotated(signf(heading.cross(lateral)) * turn)

		horiz_vel = heading * new_speed

	velocity.x = horiz_vel.x
	velocity.z = horiz_vel.y

func _propulsion_factor(speed_along_input: float) -> float:
	return clampf(1.0 - speed_along_input / self_propel_max_speed, 0.0, 1.0)

func trigger_decorative_flip() -> void:
	is_flipping = true
	flip_progress = 0.0

func apply_bounce_impulse(impulse: Vector3) -> void:
	external_boost = impulse

func set_surface_friction(f: float) -> void:
	current_friction = f

## Horizontal (X/Z) speed only — falling must not spike the speedometer.
func get_speed_kmh() -> float:
	return Vector2(velocity.x, velocity.z).length() * 3.6
