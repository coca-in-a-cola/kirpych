extends SceneTree

const ConveyorScript = preload("res://src/entities/props/conveyor_belt.gd")
const LiftScript = preload("res://src/entities/props/moving_lift.gd")
const DoorScript = preload("res://src/entities/props/metal_door.gd")
const BrickScript = preload("res://src/entities/brick/brick.gd")

# Runs in _initialize (not _init): autoloads such as GameManager are only added to the
# tree and registered as global identifiers after the SceneTree script is constructed.
func _initialize() -> void:
	print("=====================================================")
	print("🧪 RUNNING LEVEL 02 SUITE: 'НАРУШЕНИЕ ТБ'")
	print("=====================================================")
	
	var all_passed = true
	
	# TEST 1: Level 02 Scene Instantiation
	print("[TEST 1] Loading Level 02 Scene...")
	var lvl2_res = load("res://src/levels/level_02.tscn")
	if lvl2_res == null:
		push_error("FAIL: Could not load level_02.tscn")
		all_passed = false
	else:
		var inst = lvl2_res.instantiate()
		if inst != null:
			print("  -> PASS: Level 02 instantiated cleanly. Child nodes: ", inst.get_child_count())
			inst.free()
		else:
			push_error("FAIL: instantiate returned null")
			all_passed = false
	
	# TEST 2: Conveyor Belt Velocity Transfer
	print("[TEST 2] Testing Conveyor Belt Physics Transfer...")
	var conv_res = load("res://src/entities/props/conveyor_belt.tscn")
	if conv_res:
		var conv = conv_res.instantiate()
		var test_body = CharacterBody3D.new()
		test_body.velocity = Vector3.ZERO
		conv._on_body_entered(test_body)
		conv._physics_process(0.5) # 0.5s of conveyor acceleration
		if test_body.velocity.z > 5.0:
			print("  -> PASS: Conveyor transferred velocity along Z: ", test_body.velocity.z, " m/s")
		else:
			push_error("FAIL: Conveyor did not accelerate body: " + str(test_body.velocity))
			all_passed = false
		conv.free()
		test_body.free()
	else:
		push_error("FAIL: Could not load conveyor_belt.tscn")
		all_passed = false
	
	# TEST 3: Moving Lift Vertical Oscillation
	print("[TEST 3] Testing Moving Lift Motion...")
	var lift_res = load("res://src/entities/props/moving_lift.tscn")
	if lift_res:
		var lift = lift_res.instantiate()
		lift._ready()
		var initial_y = lift.position.y
		lift._physics_process(2.25) # half cycle duration -> peak elevation
		if lift.position.y > initial_y + 8.0:
			print("  -> PASS: Lift ascended smoothly to peak: ", lift.position.y)
		else:
			push_error("FAIL: Lift failed to ascend properly: " + str(lift.position.y))
			all_passed = false
		lift.free()
	else:
		push_error("FAIL: Could not load moving_lift.tscn")
		all_passed = false
	
	# TEST 4: Metal Door Breach Threshold
	print("[TEST 4] Testing Metal Door Breach Threshold...")
	var door_res = load("res://src/entities/props/metal_door.tscn")
	if door_res:
		var door = door_res.instantiate()
		
		var mock_brick = CharacterBody3D.new()
		mock_brick.set_script(BrickScript)
		
		# Test low impact (20 km/h < 35 km/h threshold)
		mock_brick.velocity = Vector3(0, 0, 5.55) # ~ 20 km/h
		door._on_impact_body_entered(mock_brick)
		if door.is_breached:
			push_error("FAIL: Door breached at low speed!")
			all_passed = false
		else:
			print("  -> PASS: Door resisted low speed impact (20 km/h)")
		
		# Test high impact (54 km/h >= 35 km/h threshold)
		var breach_detected = {"val": false, "speed": 0.0}
		door.door_breached.connect(func(s):
			breach_detected["val"] = true
			breach_detected["speed"] = s
		)
		mock_brick.velocity = Vector3(0, 0, 15.0) # 54 km/h
		door._on_impact_body_entered(mock_brick)
		if door.is_breached and breach_detected["val"] and is_equal_approx(breach_detected["speed"], 54.0):
			print("  -> PASS: Door breached at 54 km/h and emitted signal cleanly!")
		else:
			push_error("FAIL: Door breach failed at high speed")
			all_passed = false
		
		door.free()
		mock_brick.free()
	else:
		push_error("FAIL: Could not load metal_door.tscn")
		all_passed = false
	
	print("=====================================================")
	if all_passed:
		print("✅ ALL LEVEL 02 TESTS PASSED CLEANLY!")
		print("=====================================================")
		quit(0)
	else:
		push_error("❌ SOME LEVEL 02 TESTS FAILED")
		print("=====================================================")
		quit(1)
