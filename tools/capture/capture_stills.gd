extends Node

const OUT_DIR := "res://artifacts/screenshots"

var scenes := [
	{"name": "screenshot_main_menu.png", "path": "res://src/ui/main_menu.tscn"},
	{"name": "screenshot_level_01.png", "path": "res://src/levels/level_01.tscn"},
	{"name": "screenshot_level_02.png", "path": "res://src/levels/level_02.tscn"},
	{"name": "screenshot_level_03.png", "path": "res://src/levels/level_03.tscn"}
]

func _ready() -> void:
	_capture_all.call_deferred()

func _capture_all() -> void:
	var out := ProjectSettings.globalize_path(OUT_DIR)
	DirAccess.make_dir_recursive_absolute(out)
	
	for item in scenes:
		var fname: String = item["name"]
		var spath: String = item["path"]
		print("Capturing: ", spath)
		
		var scn_res = load(spath)
		if not scn_res:
			continue
		
		var inst = scn_res.instantiate()
		get_tree().root.add_child(inst)
		
		# Wait 10 frames for models, shaders, and camera to render
		for f in 10:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		
		var vp := get_viewport()
		if vp:
			var tex := vp.get_texture()
			if tex:
				var img := tex.get_image()
				if img:
					var save_path := out + "/" + fname
					img.save_png(save_path)
					print("  -> Saved ", fname, " (", img.get_width(), "x", img.get_height(), ")")
		
		inst.queue_free()
		get_tree().root.remove_child(inst)
		for f in 3:
			await get_tree().process_frame
	
	print("All captures completed.")
	get_tree().quit(0)
