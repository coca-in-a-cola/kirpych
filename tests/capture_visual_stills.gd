extends Node

const OUT_DIR := "res://artifacts/screenshots"

var scenes := [
	{"name": "screenshot_main_menu.png", "path": "res://src/ui/main_menu.tscn"},
	{"name": "screenshot_level_01.png", "path": "res://src/levels/level_01.tscn"},
	{"name": "screenshot_level_02.png", "path": "res://src/levels/level_02.tscn"},
	{"name": "screenshot_level_03.png", "path": "res://src/levels/level_03.tscn"}
]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_capture_all.call_deferred()

func _capture_all() -> void:
	var out := ProjectSettings.globalize_path(OUT_DIR)
	DirAccess.make_dir_recursive_absolute(out)
	
	for item in scenes:
		var fname: String = item["name"]
		var spath: String = item["path"]
		print("Rendering scene: ", spath)
		
		var scn_res = load(spath)
		if not scn_res:
			push_error("Failed to load " + spath)
			continue
		
		var inst = scn_res.instantiate()
		get_tree().root.add_child(inst)
		get_tree().current_scene = inst
		
		# Allow renderer to settle and draw
		for f in 5:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		
		var img := get_viewport().get_texture().get_image()
		if img:
			var save_path := out + "/" + fname
			var err := img.save_png(save_path)
			if err == OK:
				var fsize := FileAccess.get_file_as_bytes(save_path).size()
				print("  -> Captured ", fname, " (", img.get_width(), "x", img.get_height(), ", ", fsize, " bytes)")
			else:
				push_error("Failed to save " + save_path)
		
		inst.queue_free()
		get_tree().root.remove_child(inst)
		for f in 2:
			await get_tree().process_frame
	
	print("All visual stills rendered successfully.")
	get_tree().quit(0)
