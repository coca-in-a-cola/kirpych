extends SceneTree

## Camera honesty probe (t_kp_18). Drives the production brick.tscn + camera_rail.gd and measures:
##  A. Input-meaning yaw drift from lateral position (what W/D actually mean vs. the rail direction).
##  B. Roll pollution of the movement basis (D direction error while the roll tilt is active).
##  C. Visual-vs-input consistency (camera visual forward vs. W world direction).
##  D. Curved-rail following + airborne basis freeze (GDD 2.6 / 3.1: no basis jump mid-jump).
##  E. Wall occlusion pull-in.
## Implementation-agnostic: the movement basis is selected exactly as brick.gd selects it, and W is
## also measured as the real velocity change of the brick from rest (ground truth).
## Usage: godot-xvfb --headless --path <project> --script res://tools/audit/camera_drift_probe.gd

const InputCtl = preload("res://src/scripts/input_controller.gd")

var brick: CharacterBody3D
var cam: Camera3D
var ic: Node
var straight_rail: Path3D


func _initialize() -> void:
	_run.call_deferred()


func _box(size: Vector3, pos: Vector3, layer: int = 2) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = layer
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	body.add_child(cs)
	body.position = pos
	root.add_child(body)
	return body


func _path(points: Array[Vector3]) -> Path3D:
	var p := Path3D.new()
	var c := Curve3D.new()
	for pt in points:
		c.add_point(pt)
	p.curve = c
	root.add_child(p)
	return p


func _make_world() -> void:
	_box(Vector3(400, 1, 2000), Vector3(0, -0.5, 900))
	straight_rail = _path([Vector3(0, 0, -50), Vector3(0, 0, 1800)] as Array[Vector3])
	brick = (load("res://src/entities/brick/brick.tscn") as PackedScene).instantiate()
	root.add_child(brick)
	brick.global_position = Vector3(0, 0.05, 0)
	cam = Camera3D.new()
	cam.set_script(load("res://src/camera/camera_rail.gd"))
	root.add_child(cam)
	cam.make_current()
	_set_rail(straight_rail)
	cam.set("target", brick)
	ic = brick.get_node("InputController")


func _set_rail(p: Path3D) -> void:
	if "rail_path" in cam:
		cam.set("rail_path", p)


## Exactly the basis selection brick.gd performs.
func _movement_basis() -> Basis:
	if cam.has_method("get_movement_basis"):
		return cam.call("get_movement_basis")
	return cam.global_transform.basis


func _dir_for(d: int) -> Vector3:
	ic.set("current_direction", d)
	var v: Vector3 = ic.call("get_movement_vector", _movement_basis())
	ic.set("current_direction", InputCtl.Direction.NONE)
	return v


func _visual_forward() -> Vector3:
	var f: Vector3 = -cam.global_transform.basis.z
	f.y = 0.0
	return f.normalized()


func _visual_right() -> Vector3:
	# Roll-free screen-right on the ground plane: perpendicular to the visual forward.
	return _visual_forward().cross(Vector3.UP).normalized()


func _yaw_deg(v: Vector3) -> float:
	return rad_to_deg(atan2(v.x, v.z))


func _angle_deg(a: Vector3, b: Vector3) -> float:
	return rad_to_deg(Vector2(a.x, a.z).angle_to(Vector2(b.x, b.z)))


func _steps(n: int) -> void:
	for i in n:
		await physics_frame


func _reset(pos: Vector3, vel: Vector3 = Vector3.ZERO) -> void:
	ic.set("current_direction", InputCtl.Direction.NONE)
	ic.set("direction_stack", [] as Array[InputCtl.Direction])
	brick.global_position = pos
	brick.velocity = vel
	brick.set("current_friction", 1.8)
	await _steps(3)


func _run() -> void:
	_make_world()
	await _steps(10)
	print("PROBE|BEGIN|camera_has_movement_basis=%s|camera_has_rail=%s" % [
		str(cam.has_method("get_movement_basis")), str("rail_path" in cam)])

	# A. Lateral-position drift. Rail direction is +Z (yaw 0).
	var worst_a: float = 0.0
	for x in [0.0, 4.0, 8.0, 11.0]:
		await _reset(Vector3(x, 0.05, 10))
		await _steps(120)
		var w: Vector3 = _dir_for(InputCtl.Direction.FORWARD)
		var vis: Vector3 = _visual_forward()
		# Ground truth: one physics frame of W from rest -> velocity direction.
		brick.velocity = Vector3.ZERO
		ic.set("current_direction", InputCtl.Direction.FORWARD)
		await physics_frame
		ic.set("current_direction", InputCtl.Direction.NONE)
		var gt: Vector3 = Vector3(brick.velocity.x, 0, brick.velocity.z).normalized()
		worst_a = maxf(worst_a, absf(_yaw_deg(gt)))
		print("PROBE|A_LATERAL_DRIFT|brick_x=%.1f|cam_x=%.2f|W_basis_yaw=%.2f|W_groundtruth_yaw=%.2f|visual_yaw=%.2f|input_vs_visual=%.2f" % [
			x, cam.global_position.x, _yaw_deg(w), _yaw_deg(gt), _yaw_deg(vis), _angle_deg(w, vis)])
	print("PROBE|A_SUMMARY|max_abs_W_yaw_error_vs_rail_deg=%.2f" % worst_a)

	# B. Roll pollution: slide sideways so the roll tilt saturates, then compare D with roll-free screen-right.
	var worst_b: float = 0.0
	for vx in [-7.0, 7.0]:
		await _reset(Vector3(0, 0.05, 200), Vector3(vx, 0, 0))
		var max_roll: float = 0.0
		var err: float = 0.0
		var err_tf: float = 0.0
		for i in 20:
			brick.velocity = Vector3(vx, 0, 0)
			await physics_frame
			var roll: float = absf(rad_to_deg(cam.rotation.z))
			if roll > max_roll:
				max_roll = roll
				var d: Vector3 = _dir_for(InputCtl.Direction.RIGHT)
				err = _angle_deg(d, _visual_right())
				# Counterfactual: what D would be if the rolled Camera3D transform fed the input basis.
				ic.set("current_direction", InputCtl.Direction.RIGHT)
				var d_tf: Vector3 = ic.call("get_movement_vector", cam.global_transform.basis)
				ic.set("current_direction", InputCtl.Direction.NONE)
				err_tf = _angle_deg(d_tf, _visual_right())
		worst_b = maxf(worst_b, absf(err))
		print("PROBE|B_ROLL|lateral_vx=%.1f|camera_roll_deg=%.2f|D_vs_rollfree_right_deg=%.3f|D_if_rolled_transform_fed_input=%.3f" % [vx, max_roll, err, err_tf])
	print("PROBE|B_SUMMARY|max_abs_D_skew_deg=%.3f" % worst_b)

	# C/D. Curved rail: straight +Z then 90 deg turn to +X (only meaningful for a rail camera).
	if "rail_path" in cam:
		var bend := _path([Vector3(-500, 0, 0), Vector3(-500, 0, 40), Vector3(-460, 0, 80), Vector3(-300, 0, 80)] as Array[Vector3])
		_set_rail(bend)
		_box(Vector3(240, 1, 200), Vector3(-420, -0.5, 50))  # ground under the bend
		var stations: Array[Vector3] = [Vector3(-500, 0.05, 20), Vector3(-485, 0.05, 66), Vector3(-400, 0.05, 80)]
		for s in stations:
			await _reset(s)
			await _steps(240)
			var w2: Vector3 = _dir_for(InputCtl.Direction.FORWARD)
			print("PROBE|C_CURVED_RAIL|brick=(%.0f,%.0f)|visual_yaw=%.2f|W_yaw=%.2f|input_vs_visual=%.3f|roll_deg=%.2f" % [
				s.x, s.z, _yaw_deg(_visual_forward()), _yaw_deg(w2), _angle_deg(w2, _visual_forward()), rad_to_deg(cam.rotation.z)])
		# D. Real jump across the straight->bend segment change: basis yaw must not change in the air.
		await _reset(Vector3(-500, 0.05, 36))
		await _steps(240)
		var yaw_before: float = _yaw_deg(_dir_for(InputCtl.Direction.FORWARD))
		brick.velocity = Vector3(3, 12, 8)
		await physics_frame
		var max_dev: float = 0.0
		var air_frames: int = 0
		while not brick.is_on_floor() and air_frames < 400:
			await physics_frame
			air_frames += 1
			if brick.is_on_floor():
				break  # landing tick: the basis is allowed to start easing from here on
			var yaw_air: float = _yaw_deg(_dir_for(InputCtl.Direction.FORWARD))
			max_dev = maxf(max_dev, absf(yaw_air - yaw_before))
		# Post-landing easing: largest per-tick basis rotation (must be smooth, no jump).
		var prev_yaw: float = _yaw_deg(_dir_for(InputCtl.Direction.FORWARD))
		var max_tick: float = 0.0
		for i in 240:
			await physics_frame
			var y_now: float = _yaw_deg(_dir_for(InputCtl.Direction.FORWARD))
			max_tick = maxf(max_tick, absf(y_now - prev_yaw))
			prev_yaw = y_now
		print("PROBE|D_POST_LANDING_EASE|max_yaw_step_per_tick_deg=%.3f" % max_tick)
		print("PROBE|D_AIRBORNE_FREEZE|air_frames=%d|yaw_before=%.2f|max_yaw_change_in_air=%.3f|yaw_after_landing_settle=%.2f" % [
			air_frames, yaw_before, max_dev, _yaw_deg(_dir_for(InputCtl.Direction.FORWARD))])
		_set_rail(straight_rail)

	# E. Occlusion: a wall 2.5 m behind the brick, between it and the ideal camera spot.
	await _reset(Vector3(0, 0.05, 600))
	await _steps(120)
	var free_dist: float = cam.global_position.distance_to(brick.global_position)
	var free_z: float = cam.global_position.z
	var wall := _box(Vector3(20, 12, 0.4), Vector3(0, 6, 600 - 2.5))
	await _steps(30)
	var wall_face: float = wall.position.z + 0.2
	var occ_z: float = cam.global_position.z
	print("PROBE|E_OCCLUSION|free_cam_z=%.2f|free_dist=%.2f|wall_face_z=%.2f|occluded_cam_z=%.2f|occluded_dist=%.2f|camera_in_front_of_wall=%s" % [
		free_z, free_dist, wall_face, occ_z, cam.global_position.distance_to(brick.global_position), str(occ_z > wall_face)])
	wall.queue_free()
	await _steps(180)
	print("PROBE|E_RELEASE|cam_dist_after_wall_removed=%.2f" % cam.global_position.distance_to(brick.global_position))

	# F. Production levels: each authored CameraRailPath is bound and drives an honest +rail basis.
	brick.queue_free()
	cam.queue_free()
	await _steps(2)
	for lvl in ["res://src/levels/level_01.tscn", "res://src/levels/level_02.tscn", "res://src/levels/level_03.tscn"]:
		var inst: Node = (load(lvl) as PackedScene).instantiate()
		root.add_child(inst)
		await _steps(90)
		var lc: Camera3D = inst.get_node("CameraRail")
		var lb: Node3D = inst.get_node("Brick")
		var rp: Path3D = lc.get("rail_path")
		var mb: Basis = lc.call("get_movement_basis")
		var fwd: Vector3 = -mb.z
		print("PROBE|F_LEVEL|%s|rail_bound=%s|rail_points=%d|rail_len=%.1f|W_yaw=%.2f|cam=(%.2f,%.2f,%.2f)|brick=(%.2f,%.2f,%.2f)|roll_deg=%.2f|fov=%.1f" % [
			lvl.get_file(), str(rp != null), rp.curve.point_count if rp else 0, rp.curve.get_baked_length() if rp else 0.0,
			_yaw_deg(fwd), lc.global_position.x, lc.global_position.y, lc.global_position.z,
			lb.global_position.x, lb.global_position.y, lb.global_position.z, rad_to_deg(lc.rotation.z), lc.fov])
		inst.queue_free()
		await _steps(3)

	print("PROBE|END")
	quit(0)
