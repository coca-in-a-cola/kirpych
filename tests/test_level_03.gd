extends SceneTree

const FanScript = preload("res://src/entities/props/exhaust_fan.gd")
const CraneScript = preload("res://src/entities/props/pendulum_crane.gd")
const CradleScript = preload("res://src/entities/props/cradle_finish.gd")
const BrickScript = preload("res://src/entities/brick/brick.gd")

# Runs in _initialize (not _init): autoloads such as GameManager are only added to the
# tree and registered as global identifiers after the SceneTree script is constructed.
func _initialize() -> void:
	print("=====================================================")
	print("🧪 RUNNING LEVEL 03 SUITE: 'ВЫСОТНЫЕ РАБОТЫ'")
	print("=====================================================")
	
	var all_passed = true
	
	# TEST 1: Level 03 Scene Instantiation
	print("[TEST 1] Loading Level 03 Scene...")
	var lvl3_res = load("res://src/levels/level_03.tscn")
	if lvl3_res == null:
		push_error("FAIL: Could not load level_03.tscn")
		all_passed = false
	else:
		var inst = lvl3_res.instantiate()
		if inst != null:
			print("  -> PASS: Level 03 instantiated cleanly. Child nodes: ", inst.get_child_count())
			inst.free()
		else:
			push_error("FAIL: instantiate returned null")
			all_passed = false
	
	# TEST 2: Exhaust Fan Aerodynamic Updraft
	print("[TEST 2] Testing Exhaust Fan Wind Acceleration...")
	var fan_res = load("res://src/entities/props/exhaust_fan.tscn")
	if fan_res:
		var fan = fan_res.instantiate()
		var test_body = CharacterBody3D.new()
		test_body.velocity = Vector3.ZERO
		fan._on_body_entered(test_body)
		fan._physics_process(0.5) # 0.5s in updraft
		if test_body.velocity.y > 8.0 and test_body.velocity.z > 4.0:
			print("  -> PASS: Exhaust fan applied updraft: Vy=", test_body.velocity.y, " Vz=", test_body.velocity.z)
		else:
			push_error("FAIL: Fan did not apply wind acceleration: " + str(test_body.velocity))
			all_passed = false
		fan.free()
		test_body.free()
	else:
		push_error("FAIL: Could not load exhaust_fan.tscn")
		all_passed = false
	
	# TEST 3: Pendulum Crane Harmonic Swing
	print("[TEST 3] Testing Pendulum Crane Motion...")
	var crane_res = load("res://src/entities/props/pendulum_crane.tscn")
	if crane_res:
		var crane = crane_res.instantiate()
		crane._ready()
		var initial_z = crane.position.z
		crane._physics_process(0.95) # 1/4 of swing_period (3.8s) -> max amplitude
		var displacement = abs(crane.position.z - initial_z)
		if displacement > 4.0:
			print("  -> PASS: Pendulum crane swung to amplitude: ", displacement, " m")
		else:
			push_error("FAIL: Crane did not swing properly: " + str(displacement))
			all_passed = false
		crane.free()
	else:
		push_error("FAIL: Could not load pendulum_crane.tscn")
		all_passed = false
	
	# TEST 4: Cradle Finish & Slow-Mo Trigger
	print("[TEST 4] Testing Cradle Finish & Slow Motion Trigger...")
	var cradle_res = load("res://src/entities/props/cradle_finish.tscn")
	if cradle_res:
		var cradle = cradle_res.instantiate()
		var campaign_finished = {"val": false, "speed": 0.0}
		cradle.campaign_completed.connect(func(s):
			campaign_finished["val"] = true
			campaign_finished["speed"] = s
		)
		cradle._on_helmet_hit(78.5) # 78.5 km/h impact
		if cradle.is_finished and campaign_finished["val"] and is_equal_approx(campaign_finished["speed"], 78.5):
			print("  -> PASS: Cradle finish recorded impact: ", campaign_finished["speed"], " km/h")
			if is_equal_approx(Engine.time_scale, 0.25):
				print("  -> PASS: Comedic slow-motion triggered (time_scale = 0.25)")
				Engine.time_scale = 1.0 # Restore normal scale
			else:
				push_error("FAIL: Engine.time_scale not 0.25")
				all_passed = false
		else:
			push_error("FAIL: Cradle finish signal emission failed")
			all_passed = false
		cradle.free()
	else:
		push_error("FAIL: Could not load cradle_finish.tscn")
		all_passed = false
	
	print("=====================================================")
	if all_passed:
		print("✅ ALL LEVEL 03 TESTS PASSED CLEANLY!")
		print("=====================================================")
		quit(0)
	else:
		push_error("❌ SOME LEVEL 03 TESTS FAILED")
		print("=====================================================")
		quit(1)
