extends SceneTree

## Physics traversal probe (t_kp_16): drops/launches the real brick through prop sections with
## real move_and_slide physics and prints its trajectory, so solid prop bodies can be checked for
## pass-through (no collision) and for blockers (brick wedged against a new solid face).
## Usage:
##   /opt/agents/mcp/godot-mcp/godot-xvfb --headless --path <project> --script res://tools/audit/prop_traversal_probe.gd
## Lines are prefixed PROBE|<scenario>|...

const SCENARIOS: Array[Dictionary] = [
	{"id": "L1_scaffold_spawn", "level": "res://src/levels/level_01.tscn", "pos": Vector3(0, 12.6, -2), "vel": Vector3.ZERO, "secs": 1.0},
	{"id": "L1_scaffold_corner", "level": "res://src/levels/level_01.tscn", "pos": Vector3(2.9, 12.6, -4.5), "vel": Vector3.ZERO, "secs": 1.0},
	{"id": "L1_tire_awning", "level": "res://src/levels/level_01.tscn", "pos": Vector3(0, 0.05, 26), "vel": Vector3(0, 0, 12), "secs": 4.0},
	{"id": "L1_tire_top_drop", "level": "res://src/levels/level_01.tscn", "pos": Vector3(0, 2.0, 34.3), "vel": Vector3.ZERO, "secs": 0.5},
	{"id": "L1_tire_awning_fast", "level": "res://src/levels/level_01.tscn", "pos": Vector3(0, 0.05, 26), "vel": Vector3(0, 0, 20), "secs": 4.0},
	{"id": "L2_spawn_conveyor", "level": "res://src/levels/level_02.tscn", "pos": null, "vel": Vector3.ZERO, "secs": 3.0},
	{"id": "L2_floor2_edge", "level": "res://src/levels/level_02.tscn", "pos": Vector3(0, 13.2, 40), "vel": Vector3.ZERO, "secs": 1.0},
	{"id": "L2_respawn_conveyor", "level": "res://src/levels/level_02.tscn", "pos": Vector3(0, 1.2, 5), "vel": Vector3.ZERO, "secs": 2.0},
	{"id": "L3_roof_beam_fan", "level": "res://src/levels/level_03.tscn", "pos": Vector3(0, 28.3, 18), "vel": Vector3(0, 0, 12), "secs": 3.0},
	{"id": "L3_roof_beam_fan_slow", "level": "res://src/levels/level_03.tscn", "pos": Vector3(0, 28.3, 30), "vel": Vector3(0, 0, 3), "secs": 3.0},
	{"id": "L3_fan_drop", "level": "res://src/levels/level_03.tscn", "pos": Vector3(0, 29.0, 42), "vel": Vector3.ZERO, "secs": 0.4},
	{"id": "L3_net_drop", "level": "res://src/levels/level_03.tscn", "pos": Vector3(3.0, 23.0, 104), "vel": Vector3.ZERO, "secs": 1.0},
]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for sc in SCENARIOS:
		await _scenario(sc)
	print("PROBE|END")
	quit(0)


func _scenario(sc: Dictionary) -> void:
	var lvl: Node = (load(sc["level"]) as PackedScene).instantiate()
	root.add_child(lvl)
	await physics_frame
	var brick: CharacterBody3D = lvl.get_node("Brick")
	if sc["pos"] != null:
		brick.global_position = sc["pos"]
	brick.velocity = sc["vel"]
	var worker: Node3D = lvl.get_node_or_null("CradleFinish/WorkerNPC")
	var worker_y0: float = worker.global_position.y if worker else 0.0
	var frames: int = int(float(sc["secs"]) * Engine.physics_ticks_per_second)
	var max_y: float = -INF
	var max_z: float = -INF
	var bounced: Array[int] = [0]
	brick.bounced.connect(func() -> void: bounced[0] += 1)
	for f in frames:
		await physics_frame
		var p: Vector3 = brick.global_position
		max_y = maxf(max_y, p.y)
		max_z = maxf(max_z, p.z)
		if f % 15 == 0:
			print("PROBE|%s|t=%.2f|pos=(%.2f,%.3f,%.2f)|vel=(%.2f,%.2f,%.2f)|floor=%s" % [
				sc["id"], f / 60.0, p.x, p.y, p.z, brick.velocity.x, brick.velocity.y, brick.velocity.z, str(brick.is_on_floor())])
	var e: Vector3 = brick.global_position
	print("PROBE|%s|FINAL|pos=(%.2f,%.3f,%.2f)|speed=%.2f|on_floor=%s|max_y=%.2f|max_z=%.2f|bounces=%d%s" % [
		sc["id"], e.x, e.y, e.z, brick.velocity.length(), str(brick.is_on_floor()), max_y, max_z, bounced[0],
		("|worker_y0=%.3f|worker_y=%.3f" % [worker_y0, worker.global_position.y]) if worker else ""])
	lvl.queue_free()
	await process_frame
	await process_frame
