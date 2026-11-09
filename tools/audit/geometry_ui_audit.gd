extends SceneTree

## Read-only architectural audit probe (t_kp_12).
## Usage:
##   /opt/agents/mcp/godot-mcp/godot-xvfb --headless --path <project> --script res://tools/audit/geometry_ui_audit.gd
## Prints machine-greppable lines prefixed with AUDIT|<category>|...
## It never edits scenes; it instantiates them, measures world-space bounds and drives real GUI input.

const LEVELS: Array[String] = [
	"res://src/levels/level_01.tscn",
	"res://src/levels/level_02.tscn",
	"res://src/levels/level_03.tscn",
]
const PRIMITIVES: Array[String] = ["BoxMesh", "CylinderMesh", "SphereMesh", "CapsuleMesh",
	"PlaneMesh", "PrismMesh", "QuadMesh", "TorusMesh"]
const ZFIGHT_EPS: float = 0.05
const MIN_OVERLAP_AREA: float = 0.02


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	print("AUDIT|BEGIN")
	await _audit_glb_native_bounds()
	for lvl in LEVELS:
		await _audit_level(lvl)
	await _audit_fonts()
	await _audit_ui("res://src/ui/main_menu.tscn", false)
	await _audit_ui("res://src/ui/hud.tscn", true)
	for lvl in LEVELS:
		await _audit_ui(lvl, true)
	print("AUDIT|END")
	quit(0)


# ---------------------------------------------------------------- helpers

func _rel(n: Node, base: Node) -> String:
	return str(base.get_path_to(n))


func _glb_ancestor(n: Node, base: Node) -> String:
	var p: Node = n
	while p and p != base:
		if p.scene_file_path.ends_with(".glb"):
			return p.scene_file_path.get_file()
		p = p.get_parent()
	return ""


func _scene_ancestor(n: Node, base: Node) -> String:
	var p: Node = n.get_parent()
	while p and p != base:
		if p.scene_file_path.ends_with(".tscn"):
			return p.scene_file_path.get_file()
		p = p.get_parent()
	return ""


func _axis_aligned(b: Basis) -> bool:
	for v in [b.x.normalized(), b.y.normalized(), b.z.normalized()]:
		var m: float = maxf(absf(v.x), maxf(absf(v.y), absf(v.z)))
		if m < 0.999:
			return false
	return true


func _merged_aabb(n: Node) -> AABB:
	var out: AABB = AABB()
	var first: bool = true
	var stack: Array[Node] = [n]
	while not stack.is_empty():
		var c: Node = stack.pop_back()
		if c is VisualInstance3D:
			var a: AABB = (c as VisualInstance3D).global_transform * (c as VisualInstance3D).get_aabb()
			if first:
				out = a
				first = false
			else:
				out = out.merge(a)
		for ch in c.get_children():
			stack.append(ch)
	return out


func _fmt(a: AABB) -> String:
	return "pos=(%.3f,%.3f,%.3f) end=(%.3f,%.3f,%.3f) size=(%.3f,%.3f,%.3f)" % [
		a.position.x, a.position.y, a.position.z, a.end.x, a.end.y, a.end.z, a.size.x, a.size.y, a.size.z]


func _vol(a: AABB) -> float:
	return maxf(a.size.x, 0.0) * maxf(a.size.y, 0.0) * maxf(a.size.z, 0.0)


func _collect(n: Node, out: Array[Node]) -> void:
	out.append(n)
	for c in n.get_children():
		_collect(c, out)


# ---------------------------------------------------------------- GLB native bounds

func _audit_glb_native_bounds() -> void:
	for f in DirAccess.get_files_at("res://assets/models"):
		if not f.ends_with(".glb"):
			continue
		var res: PackedScene = load("res://assets/models/" + f)
		if res == null:
			print("AUDIT|GLB_LOAD_FAIL|%s" % f)
			continue
		var inst: Node = res.instantiate()
		root.add_child(inst)
		var a: AABB = _merged_aabb(inst)
		var cols: int = 0
		var meshes: int = 0
		var all: Array[Node] = []
		_collect(inst, all)
		for c in all:
			if c is CollisionObject3D:
				cols += 1
			if c is MeshInstance3D:
				meshes += 1
		print("AUDIT|GLB_NATIVE|%s|meshes=%d|collision_objects=%d|%s" % [f, meshes, cols, _fmt(a)])
		inst.free()
	await process_frame


# ---------------------------------------------------------------- level audit

func _audit_level(path: String) -> void:
	var res: PackedScene = load(path)
	var lvl: Node3D = res.instantiate()
	# Freeze gameplay so measurements reflect authored layout.
	lvl.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(lvl)
	await process_frame
	var name: String = path.get_file()
	print("AUDIT|LEVEL|%s" % name)

	var nodes: Array[Node] = []
	_collect(lvl, nodes)

	var meshes: Array[Dictionary] = []
	var colliders: Array[Dictionary] = []
	for n in nodes:
		if n is MeshInstance3D and (n as MeshInstance3D).mesh:
			var mi: MeshInstance3D = n
			var cls: String = mi.mesh.get_class()
			var d: Dictionary = {
				"path": _rel(mi, lvl), "cls": cls, "prim": PRIMITIVES.has(cls),
				"glb": _glb_ancestor(mi, lvl), "scene": _scene_ancestor(mi, lvl),
				"aabb": mi.global_transform * mi.get_aabb(),
				"aligned": _axis_aligned(mi.global_transform.basis),
				"scale": mi.global_transform.basis.get_scale(),
			}
			meshes.append(d)
		elif n is CollisionShape3D and (n as CollisionShape3D).shape:
			var cs: CollisionShape3D = n
			var parent: Node = cs.get_parent()
			var solid: bool = parent is PhysicsBody3D and not cs.disabled
			var dm: ArrayMesh = cs.shape.get_debug_mesh()
			var a: AABB = cs.global_transform * dm.get_aabb()
			colliders.append({
				"path": _rel(cs, lvl), "owner_cls": parent.get_class(), "solid": solid,
				"shape": cs.shape.get_class(), "aabb": a,
				"layer": (parent as CollisionObject3D).collision_layer if parent is CollisionObject3D else 0,
				"scene": _scene_ancestor(cs, lvl),
			})

	# 1. Primitive meshes
	var prim_count: int = 0
	for m in meshes:
		if m["prim"]:
			prim_count += 1
			print("AUDIT|PRIMITIVE|%s|%s|%s|in_scene=%s|%s" % [name, m["path"], m["cls"], m["scene"], _fmt(m["aabb"])])
	var glb_mesh_count: int = 0
	for m in meshes:
		if m["glb"] != "":
			glb_mesh_count += 1
	print("AUDIT|COUNTS|%s|meshes=%d|primitive=%d|glb_meshes=%d|colliders=%d" % [name, meshes.size(), prim_count, glb_mesh_count, colliders.size()])

	# 2. GLB instance roots, scale anomalies, collision presence
	for n in nodes:
		if n != lvl and n.scene_file_path.ends_with(".glb") and n is Node3D:
			var n3: Node3D = n
			var s: Vector3 = n3.global_transform.basis.get_scale()
			var a: AABB = _merged_aabb(n3)
			var overl_solid: Array[String] = []
			for c in colliders:
				if c["solid"] and (c["aabb"] as AABB).intersects(a):
					overl_solid.append(str(c["path"]))
			var nonuni: bool = absf(s.x - s.y) > 0.01 or absf(s.y - s.z) > 0.01
			print("AUDIT|GLB_INSTANCE|%s|%s|%s|scale=(%.2f,%.2f,%.2f)%s|%s|solid_colliders_touching=%s" % [
				name, _rel(n3, lvl), n3.scene_file_path.get_file(), s.x, s.y, s.z,
				"|NONUNIFORM_SCALE" if nonuni else "", _fmt(a), ",".join(overl_solid)])

	# 3. Colliders: list + solidity
	for c in colliders:
		var a: AABB = c["aabb"]
		print("AUDIT|COLLIDER|%s|%s|owner=%s|solid=%s|shape=%s|layer=%d|top_y=%.3f|%s" % [
			name, c["path"], c["owner_cls"], str(c["solid"]), c["shape"], c["layer"], a.end.y, _fmt(a)])

	# 4. Visual meshes (non-GLB, i.e. authored platforms/props) without matching solid collider
	for m in meshes:
		if m["glb"] != "" :
			continue
		var ma: AABB = m["aabb"]
		var best: float = 0.0
		var best_path: String = ""
		for c in colliders:
			if not c["solid"]:
				continue
			var inter: AABB = ma.intersection(c["aabb"])
			var f: float = _vol(inter) / maxf(_vol(ma), 0.000001)
			if f > best:
				best = f
				best_path = c["path"]
		if best < 0.9:
			print("AUDIT|VISUAL_WITHOUT_SOLID|%s|%s|%s|best_solid_cover=%.2f|by=%s|%s" % [
				name, m["path"], m["cls"], best, best_path, _fmt(ma)])

	# 5. Solid collider top surface not covered by authored visual (invisible floor / ghost collider)
	for c in colliders:
		if not c["solid"]:
			continue
		var ca: AABB = c["aabb"]
		var best2: float = 0.0
		for m in meshes:
			var inter2: AABB = ca.intersection(m["aabb"])
			best2 = maxf(best2, _vol(inter2) / maxf(_vol(ca), 0.000001))
		if best2 < 0.9:
			print("AUDIT|SOLID_NOT_FULLY_VISIBLE|%s|%s|best_visual_cover=%.2f|%s" % [name, c["path"], best2, _fmt(ca)])
		# mesh-vs-collider mismatched extents for sibling primitive meshes
		var body_path: String = str(c["path"]).get_base_dir()
		for m in meshes:
			if m["prim"] and str(m["path"]).get_base_dir() == body_path:
				var ma2: AABB = m["aabb"]
				var dx: float = absf(ma2.size.x - ca.size.x)
				var dy: float = absf(ma2.size.y - ca.size.y)
				var dz: float = absf(ma2.size.z - ca.size.z)
				var dtop: float = ma2.end.y - ca.end.y
				if dx > 0.01 or dy > 0.01 or dz > 0.01:
					print("AUDIT|MESH_COLLIDER_MISMATCH|%s|%s vs %s|d_size=(%.2f,%.2f,%.2f)|visual_top_minus_collider_top=%.3f" % [
						name, m["path"], c["path"], dx, dy, dz, dtop])

	# 6. Z-fighting: same-facing faces within ZFIGHT_EPS with overlapping projected area
	for i in meshes.size():
		for j in range(i + 1, meshes.size()):
			var a1: AABB = meshes[i]["aabb"]
			var a2: AABB = meshes[j]["aabb"]
			if not a1.grow(ZFIGHT_EPS).intersects(a2):
				continue
			for axis in 3:
				var o1: int = (axis + 1) % 3
				var o2: int = (axis + 2) % 3
				var ov1: float = minf(a1.end[o1], a2.end[o1]) - maxf(a1.position[o1], a2.position[o1])
				var ov2: float = minf(a1.end[o2], a2.end[o2]) - maxf(a1.position[o2], a2.position[o2])
				if ov1 <= 0.0 or ov2 <= 0.0 or ov1 * ov2 < MIN_OVERLAP_AREA:
					continue
				var dmax: float = absf(a1.end[axis] - a2.end[axis])
				var dmin: float = absf(a1.position[axis] - a2.position[axis])
				var exact: bool = meshes[i]["aligned"] and meshes[j]["aligned"] and meshes[i]["prim"] and meshes[j]["prim"]
				var kind: String = "EXACT_PRIMITIVE" if exact else "AABB_ESTIMATE"
				var ax: String = ["X", "Y", "Z"][axis]
				if dmax < ZFIGHT_EPS:
					print("AUDIT|ZFIGHT|%s|%s|%s <-> %s|axis=%s+|gap=%.4f|overlap_area=%.2f" % [
						name, kind, meshes[i]["path"], meshes[j]["path"], ax, dmax, ov1 * ov2])
				if dmin < ZFIGHT_EPS:
					print("AUDIT|ZFIGHT|%s|%s|%s <-> %s|axis=%s-|gap=%.4f|overlap_area=%.2f" % [
						name, kind, meshes[i]["path"], meshes[j]["path"], ax, dmin, ov1 * ov2])

	# 7. Camera + brick spawn info
	for n in nodes:
		if n is Camera3D:
			var cam: Camera3D = n
			print("AUDIT|CAMERA|%s|%s|script=%s|pos=%s" % [name, _rel(cam, lvl), str(cam.get_script().resource_path if cam.get_script() else ""), str(cam.global_position)])
		if n is CharacterBody3D:
			print("AUDIT|BODY|%s|%s|pos=%s" % [name, _rel(n, lvl), str((n as Node3D).global_position)])

	lvl.queue_free()
	await process_frame
	await process_frame


# ---------------------------------------------------------------- fonts

const UI_FONT_PATH := "res://assets/fonts/russo_one_regular.ttf"


func _audit_fonts() -> void:
	var font: FontFile = load(UI_FONT_PATH)
	var samples: Dictionary = {
		"cyrillic_upper": "АБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯ",
		"cyrillic_lower": "абвгдеёжзийклмнопрстуфхцчшщъыьэюя",
		"latin": "ABCabc0123456789",
		"symbols_used_in_ui": "▶⌨➔💥°",
	}
	for k in samples:
		var missing: String = ""
		for ch in samples[k]:
			if not font.has_char(ch.unicode_at(0)):
				missing += ch
		print("AUDIT|FONT|%s|%s|missing=%d|%s" % [UI_FONT_PATH.get_file(), k, missing.length(), missing])
	print("AUDIT|FONT|allow_system_fallback=%s" % str(font.allow_system_fallback))
	await process_frame


# ---------------------------------------------------------------- UI clickability

func _audit_ui(path: String, is_hud: bool) -> void:
	var res: PackedScene = load(path)
	var ui: Node = res.instantiate()
	root.add_child(ui)
	await process_frame
	await process_frame
	if is_hud:
		var hud_node: Node = ui if ui.has_method("show_victory") else ui.get_node_or_null("GameHUD")
		hud_node.call("show_victory", 55.0, "res://src/levels/level_02.tscn")
		await process_frame
		await process_frame
	# Synthetic mouse events are ignored for hover/click until the viewport believes
	# the OS cursor is inside the window (headless/xvfb has no real cursor).
	root.notification(Node.NOTIFICATION_VP_MOUSE_ENTER)
	root.notification(Node.NOTIFICATION_WM_MOUSE_ENTER)
	print("AUDIT|UI|%s|viewport=%s|window=%s" % [path.get_file(), str(root.get_visible_rect().size), str(root.size)])

	var nodes: Array[Node] = []
	_collect(ui, nodes)
	for n in nodes:
		if not (n is Button):
			continue
		var b: Button = n
		if not b.is_visible_in_tree():
			print("AUDIT|UI_BUTTON|%s|%s|HIDDEN" % [path.get_file(), _rel(b, ui)])
			continue
		# Neutralise production handlers so a click cannot change scene.
		for conn in b.pressed.get_connections():
			b.pressed.disconnect(conn["callable"])
		var hits: Array[int] = [0]
		b.pressed.connect(func() -> void: hits[0] += 1)
		var r: Rect2 = b.get_global_rect()
		var c: Vector2 = r.get_center()
		var mm := InputEventMouseMotion.new()
		mm.position = c
		mm.global_position = c
		root.push_input(mm)
		await process_frame
		var hovered: Control = root.gui_get_hovered_control()
		var down := InputEventMouseButton.new()
		down.button_index = MOUSE_BUTTON_LEFT
		down.pressed = true
		down.position = c
		down.global_position = c
		root.push_input(down)
		await process_frame
		var up := InputEventMouseButton.new()
		up.button_index = MOUSE_BUTTON_LEFT
		up.pressed = false
		up.position = c
		up.global_position = c
		root.push_input(up)
		await process_frame
		var styles: Array[String] = []
		for st in ["normal", "hover", "pressed", "focus", "disabled"]:
			styles.append("%s=%s" % [st, "override" if b.has_theme_stylebox_override(st) else "DEFAULT_THEME"])
		var on_screen: bool = root.get_visible_rect().encloses(r)
		print("AUDIT|UI_BUTTON|%s|%s|text=%s|rect=%s|on_screen=%s|hovered=%s|clicks=%d|focus_mode=%d|%s" % [
			path.get_file(), _rel(b, ui), b.text.replace("\n", " "), str(r), str(on_screen),
			(_rel(hovered, ui) if hovered and ui.is_ancestor_of(hovered) else str(hovered)),
			hits[0], b.focus_mode, ",".join(styles)])
	# Keyboard focus availability
	var fo: Control = root.gui_get_focus_owner()
	print("AUDIT|UI_FOCUS|%s|initial_focus_owner=%s" % [path.get_file(), str(fo)])
	ui.queue_free()
	await process_frame
