class_name CameraRail
extends Camera3D

## Route-rail chase camera (GDD 2.6 / 3.1 / 5).
##
## Orientation comes from an authored route rail (a Path3D/Curve3D per level), never from the brick's
## lateral offset or its velocity vector: the camera yaw is the horizontal tangent of the rail at the
## point nearest the brick (plus a short look-ahead). The camera POSITION follows the brick (behind it
## along that rail direction), so the player can still roam freely in full 3D while "forward" stays
## the route's forward.
##
## Separation of concerns:
##  * get_movement_basis() -> yaw-only basis (no pitch, no roll). brick.gd feeds this to the
##    InputController, so WASD always matches what the player sees as forward/right on the ground.
##  * Pitch (framing) and roll (lean juice) are applied only to this Camera3D's visual transform.
##  * While the brick is airborne the rail yaw target is frozen (GDD 7: a rail segment change in the
##    air must not rotate the input basis); after landing the yaw eases toward the new segment with a
##    rate limit, so the basis never jumps.
##
## Smoothing: all three axes use the same frame-rate-independent exponential filter, decomposed in
## the rail frame (along-track / lateral / vertical). Along-track additionally gets motion
## feed-forward (the rig is carried by the brick's along-track displacement), so follow distance does
## not stretch at speed and there is no snap-vs-lerp axis mix. Teleports (respawn) snap.
##
## Occlusion: a sphere cast from a pivot above the brick toward the ideal camera spot; on a hit the
## camera is pulled in along that ray immediately and eases back out once the view clears.
##
## Juice (preserved): roll lean on lateral motion, speed FOV punch, landing dip.

@export var target: Node3D
## Authored route rail. If unset, a sibling named "CameraRailPath" is used; if none exists, the rail
## is a straight line along fallback_forward (only for test fixtures / unauthored scenes).
@export var rail_path: Path3D
@export var fallback_forward: Vector3 = Vector3(0.0, 0.0, 1.0)
## Rail-relative offset from the brick: x = lateral (screen-right), y = up, z = along-track (negative = behind).
@export var camera_offset: Vector3 = Vector3(0.0, 2.3, -4.6)
@export var follow_speed: float = 7.5          ## Lateral + vertical smoothing rate (1/s)
@export var along_track_smoothing: float = 12.0 ## Along-track smoothing rate (1/s), on top of feed-forward
@export var look_ahead: float = 4.0            ## Look point distance ahead of the brick along the rail (m)
@export var look_height: float = 0.35          ## Look point height above the brick (m)
@export var rail_lookahead: float = 2.0        ## Rail tangent sampled this far ahead of the nearest point (m)
@export var yaw_smoothing: float = 4.0         ## Yaw easing rate toward the rail tangent (1/s)
@export var max_yaw_rate_deg: float = 90.0     ## Hard cap on yaw rotation speed (deg/s)
@export var freeze_yaw_while_airborne: bool = true
@export var snap_distance: float = 12.0        ## Target jump larger than this in one tick = teleport -> snap

@export var base_fov: float = 75.0
@export var max_fov: float = 96.0
@export var max_roll_tilt: float = 0.08  ## ~4.5 degrees in radians
@export var tilt_responsiveness: float = 0.35
@export var roll_smoothing: float = 8.0

@export_flags_3d_physics var occlusion_mask: int = 2  ## Level geometry layer
@export var occlusion_radius: float = 0.25
@export var pivot_height: float = 0.6
@export var min_occluded_distance: float = 0.8
@export var occlusion_release_speed: float = 4.0

var landing_dip_offset: float = 0.0
var connected_target: Node3D = null

var _initialized: bool = false
var _heading: float = 0.0          ## Current camera yaw as atan2(forward.x, forward.z)
var _target_heading: float = 0.0
var _rig_pos: Vector3 = Vector3.ZERO   ## Smoothed, unoccluded camera position
var _prev_target_pos: Vector3 = Vector3.ZERO
var _roll: float = 0.0
var _occlusion_frac: float = 1.0
var _probe_shape: SphereShape3D = SphereShape3D.new()

func _ready() -> void:
	fov = base_fov
	if not rail_path and get_parent():
		rail_path = get_parent().get_node_or_null("CameraRailPath") as Path3D
	var ff: Vector3 = Vector3(fallback_forward.x, 0.0, fallback_forward.z)
	if ff.length_squared() < 1e-6:
		ff = Vector3(0.0, 0.0, 1.0)
	_heading = atan2(ff.x, ff.z)
	_target_heading = _heading

## Ground-plane forward of the camera (unit, y = 0).
func get_rail_forward() -> Vector3:
	return Vector3(sin(_heading), 0.0, cos(_heading))

## Roll-free, pitch-free basis for camera-relative input: -z = visual forward on the ground,
## +x = screen-right on the ground. Consumed by brick.gd -> InputController.get_movement_vector().
func get_movement_basis() -> Basis:
	var f: Vector3 = get_rail_forward()
	var r: Vector3 = f.cross(Vector3.UP)
	return Basis(r, Vector3.UP, -f)

## Horizontal rail tangent heading near world point p, or NAN if no usable rail.
func _rail_heading_at(p: Vector3) -> float:
	if rail_path == null or rail_path.curve == null or rail_path.curve.point_count < 2:
		var ff: Vector3 = Vector3(fallback_forward.x, 0.0, fallback_forward.z)
		return atan2(ff.x, ff.z) if ff.length_squared() > 1e-6 else NAN
	var curve: Curve3D = rail_path.curve
	var xf: Transform3D = rail_path.global_transform
	var length: float = curve.get_baked_length()
	if length < 0.01:
		return NAN
	var off: float = curve.get_closest_offset(xf.affine_inverse() * p) + rail_lookahead
	var a_off: float = clampf(off - 1.0, 0.0, length)
	var b_off: float = clampf(off + 1.0, 0.0, length)
	if b_off - a_off < 0.5:
		a_off = maxf(b_off - 2.0, 0.0)
	var t: Vector3 = xf.basis * (curve.sample_baked(b_off) - curve.sample_baked(a_off))
	t.y = 0.0
	if t.length_squared() < 1e-6:
		return NAN  # vertical rail piece: keep the previous heading
	return atan2(t.x, t.z)

func _target_on_floor() -> bool:
	if target is CharacterBody3D:
		return (target as CharacterBody3D).is_on_floor()
	return true

func _physics_process(delta: float) -> void:
	if not target:
		return

	# Connect landing signal once
	if connected_target != target:
		connected_target = target
		if target.has_signal("landed") and not target.is_connected("landed", _on_target_landed):
			target.connect("landed", _on_target_landed)

	var target_pos: Vector3 = target.global_position
	var teleported: bool = not _initialized or target_pos.distance_to(_prev_target_pos) > snap_distance

	# --- Yaw: rail tangent, frozen in the air, eased + rate-limited on the ground ---
	if teleported or not (freeze_yaw_while_airborne and not _target_on_floor()):
		var h: float = _rail_heading_at(target_pos)
		if not is_nan(h):
			_target_heading = h
	if teleported:
		_heading = _target_heading
	else:
		var step: float = angle_difference(_heading, _target_heading) * (1.0 - exp(-yaw_smoothing * delta))
		var max_step: float = deg_to_rad(max_yaw_rate_deg) * delta
		_heading = wrapf(_heading + clampf(step, -max_step, max_step), -PI, PI)

	var f: Vector3 = get_rail_forward()
	var r: Vector3 = f.cross(Vector3.UP)

	# --- Landing dip recovery ---
	landing_dip_offset = lerpf(landing_dip_offset, 0.0, 1.0 - exp(-10.0 * delta))

	# --- Position: consistent rail-frame exponential smoothing ---
	var ideal: Vector3 = target_pos + f * camera_offset.z + r * camera_offset.x \
		+ Vector3.UP * (camera_offset.y + landing_dip_offset)
	if teleported:
		_rig_pos = ideal
		_occlusion_frac = 1.0
		_roll = 0.0
	else:
		# Along-track feed-forward: carry the rig with the brick's along-track motion.
		_rig_pos += f * (target_pos - _prev_target_pos).dot(f)
		var err: Vector3 = ideal - _rig_pos
		_rig_pos += f * (err.dot(f) * (1.0 - exp(-along_track_smoothing * delta)))
		_rig_pos += r * (err.dot(r) * (1.0 - exp(-follow_speed * delta)))
		_rig_pos += Vector3.UP * (err.y * (1.0 - exp(-follow_speed * delta)))
	_prev_target_pos = target_pos
	_initialized = true

	# --- Occlusion: pull in along pivot -> camera when level geometry is in the way ---
	var pivot: Vector3 = target_pos + Vector3.UP * pivot_height
	var to_cam: Vector3 = _rig_pos - pivot
	var frac: float = _occlusion_fraction(pivot, to_cam)
	if frac < _occlusion_frac:
		_occlusion_frac = frac
	else:
		_occlusion_frac = lerpf(_occlusion_frac, frac, 1.0 - exp(-occlusion_release_speed * delta))
	var cam_pos: Vector3 = pivot + to_cam * _occlusion_frac

	# --- Orientation: yaw from rail; pitch frames the look point; roll is visual only ---
	var look_point: Vector3 = target_pos + f * look_ahead + Vector3.UP * look_height
	var d: Vector3 = look_point - cam_pos
	var pitch_down: float = clampf(atan2(-d.y, maxf(d.dot(f), 0.5)), -0.35, 1.2)

	var lateral_speed_left: float = 0.0
	if "velocity" in target:
		lateral_speed_left = (target.get("velocity") as Vector3).dot(-r)
	var target_roll: float = -clampf(lateral_speed_left * tilt_responsiveness * 0.03, -max_roll_tilt, max_roll_tilt)
	_roll = lerpf(_roll, target_roll, 1.0 - exp(-roll_smoothing * delta))

	var visual: Basis = get_movement_basis() * Basis(Vector3.RIGHT, -pitch_down) * Basis(Vector3.BACK, _roll)
	global_transform = Transform3D(visual, cam_pos)

	# --- Dynamic Speed FOV Punch ---
	if target.has_method("get_speed_kmh"):
		var speed_kmh: float = target.call("get_speed_kmh")
		var fov_t: float = clampf((speed_kmh - 15.0) / 60.0, 0.0, 1.0)
		var target_fov: float = lerpf(base_fov, max_fov, fov_t)
		fov = lerpf(fov, target_fov, 1.0 - exp(-5.0 * delta))

## Fraction (0..1] of pivot->camera that is free of level geometry (sphere cast).
func _occlusion_fraction(pivot: Vector3, to_cam: Vector3) -> float:
	var dist: float = to_cam.length()
	if dist < 0.01 or not is_inside_tree():
		return 1.0
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	if space == null:
		return 1.0
	_probe_shape.radius = occlusion_radius
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = _probe_shape
	q.transform = Transform3D(Basis.IDENTITY, pivot)
	q.motion = to_cam
	q.collision_mask = occlusion_mask
	q.collide_with_areas = false
	q.collide_with_bodies = true
	if target is CollisionObject3D:
		q.exclude = [(target as CollisionObject3D).get_rid()]
	var res: PackedFloat32Array = space.cast_motion(q)
	var safe: float = res[0] if res.size() >= 1 else 1.0
	return clampf(maxf(safe, min_occluded_distance / dist), 0.0, 1.0)

func _on_target_landed(impact_speed: float) -> void:
	# Subtle camera dip on hard landing
	landing_dip_offset = -clampf(impact_speed * 0.04, 0.08, 0.25)
