extends SceneTree

## Ramp/beam traversal probe (t_kp_17). Drives the real brick forward from L2 Floor2 over
## RampConveyor_F2toF3 onto Floor3, and from the L3 RoofPlatform onto the NarrowBeam end.
## Usage:
##   /opt/agents/mcp/godot-mcp/godot-xvfb --headless --fixed-fps 60 --path <project> \
##     --script res://tools/audit/ramp_beam_traversal_probe.gd
## Lines are prefixed RAMP|...

const L2: String = "res://src/levels/level_02.tscn"
const L3: String = "res://src/levels/level_03.tscn"


func _initialize() -> void:
	_run.call_deferred()


func _dir_for(ic: Node, cb: Basis, s: float) -> int:
	for d in [1, 2]:
		ic.set("current_direction", d)
		var v: Vector3 = ic.get_movement_vector(cb)
		if signf(v.z) == s:
			return d
	return 0


func _trial(path: String, start: Vector3, push: bool, goal: Callable, secs: float) -> Dictionary:
	var lvl: Node = (load(path) as PackedScene).instantiate()
	root.add_child(lvl)
	await physics_frame
	var brick: CharacterBody3D = lvl.get_node("Brick")
	var ic: Node = brick.get_node("InputController")
	var cam: Camera3D = brick.get_viewport().get_camera_3d()
	brick.global_position = start
	brick.velocity = Vector3.ZERO
	var res: Dictionary = {"ok": false, "t": secs, "max_z": -INF, "max_y": -INF}
	for f in int(secs * 60):
		var cb: Basis = cam.global_transform.basis if cam else Basis.IDENTITY
		ic.set("current_direction", _dir_for(ic, cb, 1.0) if push else 0)
		await physics_frame
		var p: Vector3 = brick.global_position
		res["max_z"] = maxf(res["max_z"], p.z)
		res["max_y"] = maxf(res["max_y"], p.y)
		if goal.call(brick):
			res["ok"] = true
			res["t"] = f / 60.0
			break
	res["end"] = brick.global_position
	lvl.queue_free()
	await process_frame
	await process_frame
	return res


func _run() -> void:
	var g2 := func(b: CharacterBody3D) -> bool: return b.is_on_floor() and b.global_position.y > 16.4 and b.global_position.z > 66.0
	for push in [false, true]:
		for z0 in [46.0, 50.0, 52.0]:
			var r: Dictionary = await _trial(L2, Vector3(0, 12.8, z0), push, g2, 12.0)
			print("RAMP|L2|push=%s|start_z=%.1f|%s|t=%.2f|end=%s|max_y=%.2f" % [push, z0, "REACH_FLOOR3" if r["ok"] else "FAIL", r["t"], r["end"], r["max_y"]])
	var g3 := func(b: CharacterBody3D) -> bool: return b.global_position.z > 34.0 and b.global_position.y > 27.5
	for z0 in [12.0, 16.0]:
		var r: Dictionary = await _trial(L3, Vector3(0, 28.3, z0), true, g3, 8.0)
		print("RAMP|L3|push=true|start_z=%.1f|%s|t=%.2f|end=%s" % [z0, "REACH_BEAM_END" if r["ok"] else "FAIL", r["t"], r["end"]])
	quit(0)
