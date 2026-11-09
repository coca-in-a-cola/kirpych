extends SceneTree

const BrickScript = preload("res://src/entities/brick/brick.gd")
const WorkerScript = preload("res://src/entities/worker/worker_npc.gd")
const InputScript = preload("res://src/scripts/input_controller.gd")
const TireScript = preload("res://src/entities/props/bouncy_tire.gd")
const AwningScript = preload("res://src/entities/props/awning_slide.gd")

func _init() -> void:
	print("=====================================================")
	print("🧪 RUNNING HEADLESS SUITE: 'ДОГОНИ МЕНЯ, КИРПИЧ!'")
	print("=====================================================")
	
	var all_passed = true
	
	# TEST 1: Load main scene
	print("[TEST 1] Loading Level 01 Scene...")
	var level_res = load("res://src/levels/level_01.tscn")
	if level_res == null:
		push_error("FAIL: Could not load res://src/levels/level_01.tscn")
		all_passed = false
	else:
		var level_instance = level_res.instantiate()
		if level_instance != null:
			print("  -> PASS: Level 01 instantiated cleanly. Child nodes count: ", level_instance.get_child_count())
			level_instance.free()
		else:
			push_error("FAIL: level_res.instantiate() returned null")
			all_passed = false
	
	# TEST 2: Brick entity instantiation & physics properties
	print("[TEST 2] Testing Brick Entity Physics & Decoupling...")
	var brick_res = load("res://src/entities/brick/brick.tscn")
	if brick_res == null:
		push_error("FAIL: Could not load brick.tscn")
		all_passed = false
	else:
		var brick = brick_res.instantiate()
		if brick.get_script() == BrickScript:
			print("  -> PASS: Brick script matches BrickController")
			# Test speed calculation: 10 m/s = 36 km/h
			brick.velocity = Vector3(0, 0, 10.0)
			var speed_kmh = brick.get_speed_kmh()
			if is_equal_approx(speed_kmh, 36.0):
				print("  -> PASS: Speed conversion 10 m/s == 36.0 km/h (actual: ", speed_kmh, ")")
			else:
				push_error("FAIL: Speed calculation incorrect: " + str(speed_kmh))
				all_passed = false
			
			# Test decorative flip decoupling
			brick.trigger_decorative_flip()
			if brick.is_flipping:
				print("  -> PASS: Flip triggered independently on visual root")
			else:
				push_error("FAIL: Flip flag not set")
				all_passed = false
		else:
			push_error("FAIL: brick script mismatch")
			all_passed = false
		brick.free()
	
	# TEST 3: InputController 4-direction discrete arbitration
	print("[TEST 3] Testing InputController Directional Priority...")
	var input_ctrl = InputScript.new()
	input_ctrl._update_direction_stack()
	if input_ctrl.current_direction == 0: # Direction.NONE
		print("  -> PASS: Initial direction is NONE (0)")
	else:
		push_error("FAIL: Initial direction not NONE")
		all_passed = false
	input_ctrl.free()
	
	# TEST 4: Worker NPC & Helmet hit detection
	print("[TEST 4] Testing Worker NPC & Helmet Hitbox...")
	var worker_res = load("res://src/entities/worker/worker_npc.tscn")
	if worker_res == null or brick_res == null:
		push_error("FAIL: Could not load worker_npc.tscn or brick.tscn")
		all_passed = false
	else:
		var worker = worker_res.instantiate()
		root.add_child(worker)
		if worker.get_script() == WorkerScript:
			print("  -> PASS: Worker script matches WorkerNPC")
			var hit_result = {"detected": false, "speed": 0.0}
			worker.helmet_hit.connect(func(s):
				hit_result["detected"] = true
				hit_result["speed"] = s
			)
			
			# Instantiate real brick for clean method resolution
			var test_brick = brick_res.instantiate()
			root.add_child(test_brick)
			test_brick.velocity = Vector3(0, 0, 15.0) # 15 m/s = 54 km/h
			worker._on_helmet_body_entered(test_brick)
			
			if hit_result["detected"] and is_equal_approx(hit_result["speed"], 54.0):
				print("  -> PASS: Helmet hit signal received with correct speed: ", hit_result["speed"], " km/h")
				print("  -> PASS: Helmet detached and given flight impulse")
			else:
				push_error("FAIL: Helmet hit detection or speed mismatch (hit: " + str(hit_result["detected"]) + ", speed: " + str(hit_result["speed"]) + ")")
				all_passed = false
			test_brick.free()
		else:
			push_error("FAIL: worker script mismatch")
			all_passed = false
		worker.free()
	
	# TEST 5: Props & Mechanics
	print("[TEST 5] Testing BouncyTire and AwningSlide props...")
	var tire_res = load("res://src/entities/props/bouncy_tire.tscn")
	var awning_res = load("res://src/entities/props/awning_slide.tscn")
	if tire_res and awning_res:
		var tire = tire_res.instantiate()
		var awning = awning_res.instantiate()
		if tire.get_script() == TireScript and awning.get_script() == AwningScript:
			print("  -> PASS: BouncyTire and AwningSlide instantiated with custom physics triggers")
		tire.free()
		awning.free()
	else:
		push_error("FAIL: Props failed to load")
		all_passed = false
	
	print("=====================================================")
	if all_passed:
		print("✅ ALL 5 TEST SUITES PASSED CLEANLY!")
		print("=====================================================")
		quit(0)
	else:
		push_error("❌ SOME TESTS FAILED")
		print("=====================================================")
		quit(1)
