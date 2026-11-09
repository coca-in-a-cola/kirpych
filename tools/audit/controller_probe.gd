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

	# 6b. Same comparison from rest (input force parity, away from the flat-ground equilibrium).
	await _reset(Vector3(0, 0.05, 0), Vector3.ZERO)
	ic.set("current_direction", InputCtl.Direction.FORWARD)
	await _steps(30)
	var ground_dv0: float = _hspeed()
	await _reset(Vector3(0, 30, 0), Vector3.ZERO)
	ic.set("current_direction", InputCtl.Direction.FORWARD)
	await _steps(30)
	print("PROBE|ACCEL_W_0.5s_FROM_REST|ground_dv=%.2f|air_dv=%.2f|ratio=%.2f" % [ground_dv0, _hspeed(), ground_dv0 / maxf(_hspeed(), 0.001)])

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
	print("PROBE|DIAG|coyote_time=%.2f|jump_buffer=%.2f|max_safe_speed=%.1f" % [
		brick.get("coyote_time"), brick.get("jump_buffer_time"), brick.get("max_safe_speed")])

	# 9. Per-axis clamp leak: diagonal speed allowed above max_safe_speed.
	await _reset(Vector3(0, 0.05, 0), Vector3(39.9, 0, 39.9))
	await _steps(1)
	print("PROBE|CLAMP_DIAGONAL|hspeed_after_clamp=%.1f m/s (max_safe_speed=40)" % _hspeed())

	# --- t_kp_13 extensions -------------------------------------------------------------
	# 10. Flat hold-W speed profile: must plateau, not keep climbing.
	await _reset()
	ic.set("current_direction", InputCtl.Direction.FORWARD)
	var profile: Array[String] = []
	for i in 600:
		await physics_frame
		if (i + 1) % 60 == 0:
			profile.append("%.1f" % (_hspeed() * 3.6))
	print("PROBE|FLAT_HOLD_W_PROFILE_kmh_per_s|%s" % ",".join(profile))

	# 11. Carve monotonicity: hold D / A from 20 m/s; count frames where speed increased.
	for dir in [InputCtl.Direction.RIGHT, InputCtl.Direction.LEFT]:
		await _reset(Vector3(0, 0.05, 0), Vector3(0, 0, 20))
		ic.set("current_direction", dir)
		var prev: float = _hspeed()
		var start: float = prev
		var peak: float = prev
		var up_frames: int = 0
		for i in 180:
			await physics_frame
			var s: float = _hspeed()
			if s > prev + 1e-4:
				up_frames += 1
			peak = maxf(peak, s)
			prev = s
		print("PROBE|CARVE_MONOTONIC|dir=%d|start=%.3f|peak=%.3f|end=%.3f|frames_speed_increased=%d" % [dir, start, peak, prev, up_frames])

	# 12. Slalom A/D alternating every 0.5 s for 4 s from 20 m/s: no net gain allowed.
	await _reset(Vector3(0, 0.05, 0), Vector3(0, 0, 20))
	var sl_start: float = _hspeed()
	var sl_peak: float = sl_start
	for i in 240:
		ic.set("current_direction", InputCtl.Direction.LEFT if (i / 30) % 2 == 0 else InputCtl.Direction.RIGHT)
		await physics_frame
		sl_peak = maxf(sl_peak, _hspeed())
	print("PROBE|SLALOM_4s_FROM_72kmh|start=%.3f|peak=%.3f|end=%.3f" % [sl_start, sl_peak, _hspeed()])

	# 13. Bunny-hop: hold W and re-jump on every landing for 10 s (input-only, must stay bounded).
	await _reset()
	ic.set("current_direction", InputCtl.Direction.FORWARD)
	var bh_peak: float = 0.0
	for i in 600:
		if brick.is_on_floor():
			ic.set("jump_requested", true)
		await physics_frame
		bh_peak = maxf(bh_peak, _hspeed())
	print("PROBE|BUNNYHOP_W_10s|peak_kmh=%.1f|final_kmh=%.1f" % [bh_peak * 3.6, _hspeed() * 3.6])

	# 14. Diagonal clamp from a large impulse (e.g. stacked mechanism boosts).
	await _reset(Vector3(0, 0.05, 0), Vector3(60, 0, 60))
	await _steps(1)
	print("PROBE|CLAMP_DIAGONAL_60_60|hspeed_after_clamp=%.2f m/s" % _hspeed())

	# 15. Speedometer must report horizontal speed only (falling must not spike km/h).
	await _reset(Vector3(0, 60, 0), Vector3(3, -25, 0))
	await _steps(1)
	print("PROBE|SPEEDO_WHILE_FALLING|vy=%.1f|hspeed_kmh=%.1f|get_speed_kmh=%.1f" % [
		brick.velocity.y, _hspeed() * 3.6, brick.get_speed_kmh()])

	# 16. Coyote time: slide off a ledge, press jump N s after leaving the floor.
	var ledge := StaticBody3D.new()
	ledge.collision_layer = 2
	var lcs := CollisionShape3D.new()
	var lbox := BoxShape3D.new()
	lbox.size = Vector3(4, 1, 4)
	lcs.shape = lbox
	ledge.add_child(lcs)
	ledge.position = Vector3(-1000, 49.5, 0)
	root.add_child(ledge)
	for delay in [0.10, 0.20]:
		await _reset(Vector3(-1000, 50.05, 0), Vector3(0, 0, 4))
		var off_frames: int = -1
		var jumped_vy: float = 0.0
		for i in 120:
			await physics_frame
			if off_frames < 0 and not brick.is_on_floor():
				off_frames = 0
			elif off_frames >= 0:
				off_frames += 1
				if off_frames == int(round(delay * 60.0)):
					ic.set("jump_requested", true)
				jumped_vy = maxf(jumped_vy, brick.velocity.y)
		print("PROBE|COYOTE|press_after_leaving=%.2fs|jump_fired=%s|max_vy=%.2f" % [delay, str(jumped_vy > 1.0), jumped_vy])

	# 17. Jump buffer: drop from 2 m and press jump N s before predicted touchdown.
	for early in [0.08, 0.25]:
		var drop_h: float = 2.0
		var t_land: float = sqrt(2.0 * drop_h / float(brick.get("gravity")))
		await _reset(Vector3(0, drop_h + 0.05, 0), Vector3.ZERO)
		brick.global_position = Vector3(0, drop_h + 0.05, 0)
		brick.velocity = Vector3.ZERO
		var press_frame: int = int(round((t_land - early) * 60.0))
		var landed_frame: int = -1
		var fired: bool = false
		for i in 150:
			if i == press_frame:
				ic.set("jump_requested", true)
			await physics_frame
			if landed_frame < 0 and brick.is_on_floor():
				landed_frame = i
			if landed_frame >= 0 and i <= landed_frame + 3 and brick.velocity.y > 1.0:
				fired = true
		print("PROBE|JUMP_BUFFER|pressed_before_touchdown=%.2fs|jump_fired_on_landing=%s" % [early, str(fired)])

	# 18. Slope (no input): real projected gravity must still drive speed far past the input cap.
	var slope := StaticBody3D.new()
	slope.collision_layer = 2
	var scs := CollisionShape3D.new()
	var sbox := BoxShape3D.new()
	sbox.size = Vector3(20, 1, 600)
	scs.shape = sbox
	slope.add_child(scs)
	var ang: float = deg_to_rad(20.0)
	slope.position = Vector3(1000, 0, 0)
	slope.rotation = Vector3(ang, 0, 0)
	root.add_child(slope)
	var n: Vector3 = Vector3(0, cos(ang), sin(ang))
	var downhill: Vector3 = Vector3(0, -sin(ang), cos(ang))
	await _reset(slope.position + n * 0.55 - downhill * 200.0, Vector3.ZERO)
	var slope_on_floor_frames: int = 0
	for i in 180:
		await physics_frame
		if brick.is_on_floor():
			slope_on_floor_frames += 1
	print("PROBE|SLOPE_20deg_3s_NO_INPUT|speed_3d=%.2f m/s|hspeed_kmh=%.1f|on_floor_frames=%d/180|ideal_g_sin=%.2f m/s^2" % [
		brick.velocity.length(), _hspeed() * 3.6, slope_on_floor_frames, float(brick.get("gravity")) * sin(ang)])

	print("PROBE|END")
	quit(0)
