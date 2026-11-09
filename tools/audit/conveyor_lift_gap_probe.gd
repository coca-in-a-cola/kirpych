extends SceneTree

## Conveyor -> MovingLift gap probe (t_kp_16, extended t_kp_17).
## Drives the real brick with real move_and_slide physics through the L2 loading bay from the
## level spawn, sweeping lift phase offsets and player strategies, and reports whether the brick
## ever reaches Floor2_Mezzanine (on floor, y > 12.4, z > 39.5).
## Usage:
##   /opt/agents/mcp/godot-mcp/godot-xvfb --headless --fixed-fps 60 --path <project> \
##     --script res://tools/audit/conveyor_lift_gap_probe.gd
## Lines are prefixed GAP|...

const LEVEL: String = "res://src/levels/level_02.tscn"
const MAX_SECS: float = 20.0
const LIFT_FRONT_Z: float = 33.0
const CONVEYOR_END_Z: float = 28.5
## strategy ids: passive, jump@Z, brake (hold back after the belt), jump@Z+brake, all with
## "push forward once the lift deck is high enough" so the brick rolls onto Floor2.
const STRATEGIES: Array[Dictionary] = [
	{"id": "passive", "jump_z": -1.0, "brake": false},
	{"id": "brake", "jump_z": -1.0, "brake": true},
	{"id": "jump@26+brake", "jump_z": 26.0, "brake": true},
	{"id": "jump@28+brake", "jump_z": 28.0, "brake": true},
	{"id": "jump@28", "jump_z": 28.0, "brake": false},
	## board: idle at the Floor1 edge until the deck is back down, then push forward onto it.
	{"id": "board", "jump_z": -1.0, "brake": false, "board": true},
	{"id": "brake+board", "jump_z": -1.0, "brake": true, "board": true},
]

var total_ok: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var lvl0: Node = (load(LEVEL) as PackedScene).instantiate()
	var conv: Node3D = lvl0.get_node("ConveyorBelt")
	var lift: Node3D = lvl0.get_node("MovingLift")
	var f1: Node3D = lvl0.get_node("Floor1_LoadingBay")
	var f2: Node3D = lvl0.get_node("Floor2_Mezzanine")
	var f1_half_z: float = ((f1.get_node("CollisionShape3D") as CollisionShape3D).shape as BoxShape3D).size.z * 0.5
	print("GAP|GEOM|conveyor_z=%.2f..%.2f top_y=%.2f | floor1_z=%.2f..%.2f top_y=%.2f | lift_z=%.2f..%.2f top_y=%.2f..%.2f period=%.2fs | floor2_z=%.2f..%.2f top_y=%.2f" % [
		conv.position.z - 12.5, conv.position.z + 12.5, conv.position.y + 0.2,
		f1.position.z - f1_half_z, f1.position.z + f1_half_z, f1.position.y + 0.5,
		lift.position.z - 3.0, lift.position.z + 3.0, lift.position.y + 0.3, lift.position.y + 0.3 + float(lift.get("travel_distance")),
		float(lift.get("cycle_duration")),
		f2.position.z - 13.0, f2.position.z + 13.0, f2.position.y + 0.5])
	lvl0.free()
	for st in STRATEGIES:
		var ok: int = 0
		var n: int = 0
		var off: float = 0.0
		while off < 4.5 - 0.001:
			var r: Dictionary = await _trial(st, off)
			n += 1
			if r["ok"]:
				ok += 1
			print("GAP|%s|lift_offset=%.2f|%s|t=%.2f|end=(%.2f,%.2f,%.2f)|leave_belt_v=%.2f|max_z=%.2f|edge_t=%.2f|edge_lift_top=%.2f|edge_v=%.2f|boarded_lift_top=%.2f|note=%s" % [
				st["id"], off, "REACH_FLOOR2" if r["ok"] else "FAIL", r["t"], r["p"].x, r["p"].y, r["p"].z, r["v_leave"], r["max_z"],
				r["edge_t"], r["edge_lift_top"], r["edge_v"], r["board_lift_top"], r["note"]])
			off += 0.25
		total_ok += ok
		print("GAP|SUMMARY|%s|%d/%d lift phases reach Floor2" % [st["id"], ok, n])
	print("GAP|END|total_success=%d" % total_ok)
	quit(0)


func _dir_for(ic: Node, cam_basis: Basis, want_z_sign: float) -> int:
	for d in [1, 2]:  # FORWARD, BACKWARD
		ic.set("current_direction", d)
		var v: Vector3 = ic.get_movement_vector(cam_basis)
		if signf(v.z) == want_z_sign:
			return d
	return 0


func _trial(st: Dictionary, lift_offset: float) -> Dictionary:
	var lvl: Node = (load(LEVEL) as PackedScene).instantiate()
	root.add_child(lvl)
	var lift: Node = lvl.get_node("MovingLift")
	lift.set("elapsed_time", lift_offset)
	await physics_frame
	var brick: CharacterBody3D = lvl.get_node("Brick")
	var ic: Node = brick.get_node("InputController")
	var cam: Camera3D = brick.get_viewport().get_camera_3d()
	var jumped: bool = false
	var v_leave: float = -1.0
	var max_z: float = -INF
	var edge_t: float = -1.0
	var edge_lift_top: float = NAN
	var edge_v: float = NAN
	var board_lift_top: float = NAN
	var res: Dictionary = {"ok": false, "t": MAX_SECS, "note": "timeout"}
	var frames: int = int(MAX_SECS * Engine.physics_ticks_per_second)
	for f in frames:
		var p: Vector3 = brick.global_position
		max_z = maxf(max_z, p.z)
		if v_leave < 0.0 and p.z > CONVEYOR_END_Z:
			v_leave = brick.velocity.z
		var lift_top: float = (lift as Node3D).global_position.y + 0.3
		# First frame the brick's front face reaches the lift front edge (z=33): record the lift phase.
		if edge_t < 0.0 and p.z + 0.4 >= LIFT_FRONT_Z:
			edge_t = f / 60.0
			edge_lift_top = lift_top
			edge_v = brick.velocity.z
		# Deck height when the brick's centre first passes over the deck front edge.
		if is_nan(board_lift_top) and p.z > LIFT_FRONT_Z + 0.05 and p.z < 39.0:
			board_lift_top = lift_top
		# Re-resolve camera-relative directions every frame (the rail camera turns after spawn).
		var cb: Basis = cam.global_transform.basis if cam else Basis.IDENTITY
		var d_back: int = _dir_for(ic, cb, -1.0)
		var d_fwd: int = _dir_for(ic, cb, 1.0)
		# Jump trigger
		if not jumped and st["jump_z"] > 0.0 and p.z >= st["jump_z"]:
			ic.set("jump_requested", true)
			jumped = true
		# Steering: brake after the belt until the lift deck is up at Floor2 height, then push on.
		var on_lift_zone: bool = p.z > 32.0 and p.z < 39.0
		if on_lift_zone and lift_top > 12.3 and brick.is_on_floor():
			ic.set("current_direction", d_fwd)
		elif st.get("board", false) and p.z > CONVEYOR_END_Z and p.z < LIFT_FRONT_Z and brick.is_on_floor() and absf(brick.velocity.z) < 1.0:
			# Waiting at the Floor1 edge: push on only while the deck is down level with Floor1.
			ic.set("current_direction", d_fwd if lift_top < 0.2 else 0)
		elif on_lift_zone and st.get("board", false) and brick.is_on_floor() and lift_top < 6.0 and absf(brick.velocity.z) < 1.0:
			ic.set("current_direction", d_fwd)
		elif st["brake"] and p.z > CONVEYOR_END_Z and p.z < 39.0 and brick.velocity.z > 0.3:
			ic.set("current_direction", d_back)
		elif on_lift_zone and brick.is_on_floor() and st["brake"]:
			ic.set("current_direction", 0)
		else:
			ic.set("current_direction", 0)
		await physics_frame
		p = brick.global_position
		if brick.is_on_floor() and p.y > 12.4 and p.z > 39.5:
			res = {"ok": true, "t": f / 60.0, "note": "on_floor2"}
			break
		if p.y < -3.0:
			res = {"ok": false, "t": f / 60.0, "note": "fell_into_shaft"}
			break
		if (p.z < 6.0 and f > 30 and max_z > 20.0):
			res = {"ok": false, "t": f / 60.0, "note": "fell/respawned"}
			break
	res["p"] = brick.global_position
	res["v_leave"] = v_leave
	res["max_z"] = max_z
	res["edge_t"] = edge_t
	res["edge_lift_top"] = edge_lift_top
	res["edge_v"] = edge_v
	res["board_lift_top"] = board_lift_top
	lvl.queue_free()
	await process_frame
	await process_frame
	return res
