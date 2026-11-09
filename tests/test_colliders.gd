extends SceneTree

## Collider/visual extent regression suite (t_kp_16).
## Every authored platform/prop touched by the collider pass must have a solid PhysicsBody3D
## collider whose world AABB equals its visual mesh AABB within TOL, and coplanar top faces
## (z-fighting) must be separated by at least ZFIGHT_MIN while staying within floor_snap_length.

const TOL: float = 0.01
const ZFIGHT_MIN: float = 0.05
const BRICK_FLOOR_SNAP: float = 0.35

## [scene, visual node (mesh or GLB instance), solid CollisionShape3D]
const PAIRS: Array = [
	["res://src/levels/level_01.tscn", "StartScaffold/PlatformMesh", "StartScaffold/CollisionShape3D"],
	["res://src/levels/level_02.tscn", "Floor1_LoadingBay/MeshInstance3D", "Floor1_LoadingBay/CollisionShape3D"],
	["res://src/levels/level_02.tscn", "Floor2_Mezzanine/MeshInstance3D", "Floor2_Mezzanine/CollisionShape3D"],
	["res://src/levels/level_02.tscn", "Floor3_UpperBay/MeshInstance3D", "Floor3_UpperBay/CollisionShape3D"],
	["res://src/levels/level_03.tscn", "RoofPlatform/MeshInstance3D", "RoofPlatform/CollisionShape3D"],
	["res://src/levels/level_03.tscn", "NarrowBeam/MeshInstance3D", "NarrowBeam/CollisionShape3D"],
	["res://src/entities/props/bouncy_tire.tscn", "MeshInstance3D", "SolidBody/CollisionShape3D"],
	["res://src/entities/props/awning_slide.tscn", "MeshInstance3D", "SolidBody/CollisionShape3D"],
	["res://src/entities/props/conveyor_belt.tscn", "MeshInstance3D", "SolidBody/CollisionShape3D"],
	["res://src/entities/props/exhaust_fan.tscn", "MeshInstance3D", "SolidBody/CollisionShape3D"],
	["res://src/entities/props/cradle_finish.tscn", "CradleBase", "CradleBaseBody/CollisionShape3D"],
	["res://src/entities/props/cradle_finish.tscn", "SafetyNetMesh", "SafetyNetBody/CollisionShape3D"],
]

var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	print("=====================================================")
	print("🧪 RUNNING COLLIDER EXTENT SUITE")
	print("=====================================================")
	var cache: Dictionary = {}
	for p in PAIRS:
		if not cache.has(p[0]):
			var inst: Node3D = (load(p[0]) as PackedScene).instantiate()
			inst.process_mode = Node.PROCESS_MODE_DISABLED
			root.add_child(inst)
			cache[p[0]] = inst
	await process_frame

	print("[TEST 1] Visual AABB == solid collider AABB (tol %.3f m)" % TOL)
	for p in PAIRS:
		var base: Node = cache[p[0]]
		var vis: Node3D = base.get_node_or_null(p[1])
		var cs: CollisionShape3D = base.get_node_or_null(p[2])
		if vis == null or cs == null or cs.shape == null:
			_fail("%s: missing %s or %s" % [p[0].get_file(), p[1], p[2]])
			continue
		if not (cs.get_parent() is PhysicsBody3D) or cs.disabled:
			_fail("%s: %s is not a solid PhysicsBody3D shape" % [p[0].get_file(), p[2]])
			continue
		var va: AABB = _visual_aabb(vis)
		var ca: AABB = cs.global_transform * cs.shape.get_debug_mesh().get_aabb()
		var d: float = maxf((va.position - ca.position).abs()[(va.position - ca.position).abs().max_axis_index()],
			(va.end - ca.end).abs()[(va.end - ca.end).abs().max_axis_index()])
		var line: String = "%s | %s visual=%s..%s collider=%s..%s max_dev=%.4f" % [
			p[0].get_file(), p[1], _v(va.position), _v(va.end), _v(ca.position), _v(ca.end), d]
		if d <= TOL:
			print("  -> PASS: " + line)
		else:
			_fail(line)

	print("[TEST 2] L3 RoofPlatform / NarrowBeam top faces no longer coincide")
	var l3: Node = cache["res://src/levels/level_03.tscn"]
	var roof_top: float = _visual_aabb(l3.get_node("RoofPlatform/MeshInstance3D")).end.y
	var beam_top: float = _visual_aabb(l3.get_node("NarrowBeam/MeshInstance3D")).end.y
	var gap: float = absf(roof_top - beam_top)
	if gap >= ZFIGHT_MIN - 0.0001 and gap <= BRICK_FLOOR_SNAP and beam_top < roof_top:
		print("  -> PASS: roof_top=%.3f beam_top=%.3f step_down=%.3f (>= %.2f, <= snap %.2f)" % [roof_top, beam_top, gap, ZFIGHT_MIN, BRICK_FLOOR_SNAP])
	else:
		_fail("roof_top=%.3f beam_top=%.3f gap=%.3f" % [roof_top, beam_top, gap])

	print("[TEST 3] L2 floors use distinct mesh resources")
	var l2: Node = cache["res://src/levels/level_02.tscn"]
	var m1: Mesh = (l2.get_node("Floor1_LoadingBay/MeshInstance3D") as MeshInstance3D).mesh
	var m2: Mesh = (l2.get_node("Floor2_Mezzanine/MeshInstance3D") as MeshInstance3D).mesh
	var m3: Mesh = (l2.get_node("Floor3_UpperBay/MeshInstance3D") as MeshInstance3D).mesh
	if m1 != m2 and m2 != m3 and m1 != m3:
		print("  -> PASS: three independent BoxMesh resources")
	else:
		_fail("floors still share a mesh resource")

	print("[TEST 4] Prop trigger Area3Ds still present alongside solid bodies")
	for path in ["res://src/entities/props/bouncy_tire.tscn", "res://src/entities/props/awning_slide.tscn",
			"res://src/entities/props/conveyor_belt.tscn", "res://src/entities/props/exhaust_fan.tscn"]:
		var prop: Node = cache[path]
		var trig: CollisionShape3D = prop.get_node_or_null("CollisionShape3D")
		if prop is Area3D and trig and trig.shape and prop.get_node_or_null("SolidBody") is StaticBody3D:
			print("  -> PASS: %s Area3D trigger + StaticBody3D SolidBody" % path.get_file())
		else:
			_fail("%s lost its Area3D trigger or SolidBody" % path.get_file())

	for k in cache:
		(cache[k] as Node).queue_free()
	await process_frame
	print("=====================================================")
	if failures == 0:
		print("✅ ALL COLLIDER TESTS PASSED CLEANLY!")
		print("=====================================================")
		quit(0)
	else:
		push_error("❌ %d COLLIDER TEST(S) FAILED" % failures)
		print("=====================================================")
		quit(1)


func _fail(msg: String) -> void:
	failures += 1
	push_error("FAIL: " + msg)


func _v(v: Vector3) -> String:
	return "(%.3f,%.3f,%.3f)" % [v.x, v.y, v.z]


func _visual_aabb(n: Node) -> AABB:
	var out: AABB = AABB()
	var first: bool = true
	var stack: Array[Node] = [n]
	while not stack.is_empty():
		var c: Node = stack.pop_back()
		if c is VisualInstance3D:
			var a: AABB = (c as VisualInstance3D).global_transform * (c as VisualInstance3D).get_aabb()
			out = a if first else out.merge(a)
			first = false
		for ch in c.get_children():
			stack.append(ch)
	return out
