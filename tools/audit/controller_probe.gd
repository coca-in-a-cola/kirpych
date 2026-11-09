extends SceneTree

## Read-only controller-feel probe (t_kp_12). Drives the production brick.tscn + camera_rail.gd
## on a flat 400 m test slab through InputController.current_direction / jump_requested
## (the same fields the production _unhandled_input path writes) and reports kinematic metrics.
## Usage: /opt/agents/mcp/godot-mcp/godot-xvfb --headless --path <project> --script res://tools/audit/controller_probe.gd

const InputCtl = preload("res://src/scripts/input_controller.gd")

var brick: CharacterBody3D
var cam: Camera3D
var ic: Node


func _initialize() -> void:
	_run.call_deferred()


func _make_world() -> void:
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 2
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(400, 1, 2000)
	cs.shape = box
	floor_body.add_child(cs)
	floor_body.position = Vector3(0, -0.5, 900)
	root.add_child(floor_body)
	brick = (load("res://src/entities/brick/brick.tscn") as PackedScene).instantiate()
	root.add_child(brick)
	brick.global_position = Vector3(0, 0.05, 0)
	cam = Camera3D.new()
	cam.set_script(load("res://src/camera/camera_rail.gd"))
	root.add_child(cam)
	cam.make_current()
	cam.set("target", brick)
	ic = brick.get_node("InputController")


func _steps(n: int) -> void:
	for i in n:
		await physics_frame


func _reset(pos: Vector3 = Vector3(0, 0.05, 0), vel: Vector3 = Vector3.ZERO) -> void:
	ic.set("current_direction", InputCtl.Direction.NONE)
	ic.set("direction_stack", [] as Array[InputCtl.Direction])
	brick.global_position = pos
	brick.velocity = vel
	brick.set("current_friction", 1.8)
	await _steps(3)


func _hspeed() -> float:
	return Vector2(brick.velocity.x, brick.velocity.z).length()


func _run() -> void:
	_make_world()
	await _steps(10)
	print("PROBE|BEGIN|physics_tps=%d" % Engine.physics_ticks_per_second)

	# 1. Hold W from rest for 8 s on flat ground: does input alone reach unbounded speed?
	await _reset()
	ic.set("current_direction", InputCtl.Direction.FORWARD)
	var t_36: float = -1.0
	var t_100: float = -1.0
	for i in 480:
		await physics_frame
		var kmh: float = _hspeed() * 3.6
		if t_36 < 0.0 and kmh >= 36.0:
			t_36 = (i + 1) / 60.0
		if t_100 < 0.0 and kmh >= 100.0:
			t_100 = (i + 1) / 60.0
	print("PROBE|FLAT_HOLD_W_8s|final_kmh=%.1f|t_to_36kmh=%.2fs|t_to_100kmh=%.2fs" % [_hspeed() * 3.6, t_36, t_100])

	# 2. Coast-down from 20 m/s, no input: stopping time and distance.
	await _reset(Vector3(0, 0.05, 0), Vector3(0, 0, 20))
	var z0: float = brick.global_position.z
	var frames: int = 0
	while _hspeed() > 0.05 and frames < 60 * 30:
		await physics_frame
		frames += 1
	print("PROBE|COAST_FROM_72kmh|stop_time=%.2fs|stop_distance=%.1fm" % [frames / 60.0, brick.global_position.z - z0])

	# 3. Brake with S from 20 m/s.
	await _reset(Vector3(0, 0.05, 0), Vector3(0, 0, 20))
	ic.set("current_direction", InputCtl.Direction.BACKWARD)
	z0 = brick.global_position.z
	frames = 0
	while brick.velocity.z > 0.05 and frames < 60 * 30:
		await physics_frame
		frames += 1
	print("PROBE|BRAKE_S_FROM_72kmh|stop_time=%.2fs|stop_distance=%.1fm" % [frames / 60.0, brick.global_position.z - z0])

	# 4. Hold D at 20 m/s for 3 s: speed must not be preserved by renormalisation (GDD 4: no velocity normalisation).
	await _reset(Vector3(0, 0.05, 0), Vector3(0, 0, 20))
	ic.set("current_direction", InputCtl.Direction.RIGHT)
	var s0: float = _hspeed()
	await _steps(180)
	var heading_deg: float = rad_to_deg(atan2(brick.velocity.x, brick.velocity.z))
	print("PROBE|CARVE_D_3s_FROM_72kmh|speed_before=%.2f|speed_after=%.2f|heading_change_deg=%.1f|lateral_x=%.1fm" % [
		s0, _hspeed(), heading_deg, brick.global_position.x])

	# 5. Jump apex & air time from rest.
	await _reset()
	var y0: float = brick.global_position.y
	ic.set("jump_requested", true)
	var apex: float = y0
	frames = 0
	var left_floor: bool = false
	while frames < 240:
		await physics_frame
		frames += 1
		apex = maxf(apex, brick.global_position.y)
		if not brick.is_on_floor():
			left_floor = true
		elif left_floor:
			break
	print("PROBE|JUMP_FROM_REST|apex_height=%.2fm|air_time=%.2fs" % [apex - y0, frames / 60.0])

	# 6. Air vs ground acceleration with W over 0.5 s (GDD 3.3: equal control force).
	await _reset(Vector3(0, 0.05, 0), Vector3(0, 0, 5))
	ic.set("current_direction", InputCtl.Direction.FORWARD)
	var v_a: float = brick.velocity.z
	await _steps(30)
	var ground_dv: float = brick.velocity.z - v_a
	await _reset(Vector3(0, 30, 0), Vector3(0, 0, 5))
	ic.set("current_direction", InputCtl.Direction.FORWARD)
	v_a = brick.velocity.z
	await _steps(30)
	var air_dv: float = brick.velocity.z - v_a
	print("PROBE|ACCEL_W_0.5s|ground_dv=%.2f|air_dv=%.2f" % [ground_dv, air_dv])

	# 7. Camera input-basis drift purely from lateral position (GDD 2.6/5: no hidden WASD basis change).
	for x in [0.0, 4.0, 8.0, 11.0]:
		await _reset(Vector3(x, 0.05, 10), Vector3.ZERO)
		await _steps(120)
		var fwd: Vector3 = -cam.global_transform.basis.z
		fwd.y = 0.0
		fwd = fwd.normalized()
		print("PROBE|CAM_BASIS_AT_X|brick_x=%.1f|cam_x=%.2f|W_world_dir=(%.3f,%.3f)|yaw_error_deg=%.1f" % [
			x, cam.global_position.x, fwd.x, fwd.z, rad_to_deg(atan2(fwd.x, fwd.z))])

	# 8. Coyote: walk off a ledge and press jump 0.1 s later.
	print("PROBE|DIAG|coyote_time=%.2f|jump_buffer=%.2f|max_safe_speed=%.1f(per-axis clamp)" % [
		brick.get("coyote_time"), brick.get("jump_buffer_time"), brick.get("max_safe_speed")])

	# 9. Per-axis clamp leak: diagonal speed allowed above max_safe_speed.
	await _reset(Vector3(0, 0.05, 0), Vector3(39.9, 0, 39.9))
	await _steps(1)
	print("PROBE|CLAMP_DIAGONAL|hspeed_after_clamp=%.1f m/s (max_safe_speed=40)" % _hspeed())

	print("PROBE|END")
	quit(0)
