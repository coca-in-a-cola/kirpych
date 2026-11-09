extends SceneTree

const GameManagerScript = preload("res://src/scripts/game_manager.gd")
const MainMenuScript = preload("res://src/ui/main_menu.gd")

func _init() -> void:
	print("=====================================================")
	print("🧪 RUNNING CAMPAIGN & MENU TEST SUITE")
	print("=====================================================")
	
	var test1_ok = false
	var test2_ok = false
	var test3_ok = false
	
	# TEST 1: Main Menu instantiation & button bindings
	print("[TEST 1] Testing MainMenu scene and components...")
	var menu_res = load("res://src/ui/main_menu.tscn")
	if menu_res:
		var menu = menu_res.instantiate()
		root.add_child(menu)
		menu._ready()
		if menu.get_script() == MainMenuScript:
			print("  -> PASS: MainMenu instantiated cleanly")
			var controls_dlg = menu.get_node_or_null("ControlsDialog")
			if controls_dlg:
				menu._on_controls_pressed()
				if controls_dlg.visible:
					print("  -> PASS: Controls guide opens on button click")
					menu._on_close_controls_pressed()
					if not controls_dlg.visible:
						print("  -> PASS: Controls guide closes on close button")
						test1_ok = true
		menu.free()
	
	# TEST 2: GameManager Campaign Lifecycle & Scoring
	print("[TEST 2] Testing GameManager Scoring & Ranking Engine...")
	var gm = GameManagerScript.new()
	gm.record_level_finish(1, 54.0)
	gm.record_level_finish(2, 60.0)
	gm.record_level_finish(3, 76.5)
	
	var rank_data = gm.calculate_campaign_rank()
	var avg = rank_data["avg_speed"]
	var max_s = rank_data["max_speed"]
	var rank = rank_data["rank"]
	
	if is_equal_approx(avg, 63.5) and is_equal_approx(max_s, 76.5) and rank.begins_with("S+"):
		print("  -> PASS: Campaign ranking calculated: Avg=", avg, " km/h, Max=", max_s, " km/h -> Rank=", rank)
		test2_ok = true
	
	# TEST 3: All Level Scene Files Path Validation
	print("[TEST 3] Validating all 3 level scenes...")
	var l1 = ResourceLoader.exists(gm.level_scenes[1])
	var l2 = ResourceLoader.exists(gm.level_scenes[2])
	var l3 = ResourceLoader.exists(gm.level_scenes[3])
	if l1 and l2 and l3:
		print("  -> PASS: All 3 level scenes exist on disk and are valid")
		test3_ok = true
	gm.free()
	
	print("=====================================================")
	if test1_ok and test2_ok and test3_ok:
		print("✅ ALL CAMPAIGN & MENU TESTS PASSED CLEANLY!")
		print("=====================================================")
		quit(0)
	else:
		push_error("❌ SOME CAMPAIGN TESTS FAILED (T1:" + str(test1_ok) + " T2:" + str(test2_ok) + " T3:" + str(test3_ok) + ")")
		print("=====================================================")
		quit(1)
