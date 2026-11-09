extends Node

## Global Game Manager coordinating campaign progression, scoring, and level transitions.
##
## Registered as the `GameManager` autoload in project.godot ([autoload] section), so
## gameplay code calls it directly: `GameManager.record_level_finish(...)`.
## Deliberately has NO `class_name`: Godot 4 refuses to compile a global class whose name
## equals an autoload ("Class \"GameManager\" hides an autoload singleton").
##
## `instance` is kept as an explicit accessor to the live singleton. It is bound in
## _enter_tree (not _init), so a throwaway `GameManagerScript.new()` (as unit tests do)
## can never hijack the singleton or leave it pointing at a freed object.
static var instance: Node = null

var current_level_index: int = 1
var level_speeds: Dictionary = {1: 0.0, 2: 0.0, 3: 0.0}
var level_scenes: Dictionary = {
	1: "res://src/levels/level_01.tscn",
	2: "res://src/levels/level_02.tscn",
	3: "res://src/levels/level_03.tscn"
}

func _enter_tree() -> void:
	if instance == null:
		instance = self

func _exit_tree() -> void:
	if instance == self:
		instance = null

func start_campaign() -> void:
	current_level_index = 1
	level_speeds = {1: 0.0, 2: 0.0, 3: 0.0}
	load_level(1)

func load_level(idx: int) -> void:
	current_level_index = idx
	if level_scenes.has(idx) and is_inside_tree():
		get_tree().change_scene_to_file(level_scenes[idx])

func record_level_finish(level_idx: int, speed_kmh: float) -> void:
	current_level_index = level_idx
	level_speeds[level_idx] = speed_kmh

func get_next_level() -> int:
	if current_level_index < 3:
		return current_level_index + 1
	return -1 # Campaign completed

func calculate_campaign_rank() -> Dictionary:
	var total_speed: float = 0.0
	var max_speed: float = 0.0
	for idx in [1, 2, 3]:
		var s: float = level_speeds.get(idx, 0.0)
		total_speed += s
		if s > max_speed:
			max_speed = s
	
	var avg_speed: float = total_speed / 3.0
	var rank: String = "C"
	if avg_speed >= 65.0 or max_speed >= 75.0:
		rank = "S+ (ГРОЗА СТРОИТЕЛЕЙ)"
	elif avg_speed >= 45.0:
		rank = "A (МАСТЕР ТБ)"
	elif avg_speed >= 30.0:
		rank = "B (УДАРНИК ТРУДА)"
	else:
		rank = "C (СТАЖЕР С КИРПИЧОМ)"
	
	return {
		"avg_speed": avg_speed,
		"max_speed": max_speed,
		"rank": rank,
		"details": level_speeds
	}
