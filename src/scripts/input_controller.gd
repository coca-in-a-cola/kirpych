class_name InputController
extends Node

## Input manager enforcing discrete 4-direction last-pressed arbitration per GDD 3.1
enum Direction { NONE, FORWARD, BACKWARD, LEFT, RIGHT }

var current_direction: Direction = Direction.NONE
var direction_stack: Array[Direction] = []
var jump_requested: bool = false
var restart_requested: bool = false

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("jump"):
		jump_requested = true
	if event.is_action_pressed("restart"):
		restart_requested = true
	
	_update_direction_stack()

func _update_direction_stack() -> void:
	var actions: Array[Dictionary] = [
		{"dir": Direction.FORWARD, "action": "move_forward"},
		{"dir": Direction.BACKWARD, "action": "move_backward"},
		{"dir": Direction.LEFT, "action": "move_left"},
		{"dir": Direction.RIGHT, "action": "move_right"}
	]
	
	for a in actions:
		var d: Direction = a["dir"]
		var act: String = a["action"]
		if Input.is_action_just_pressed(act):
			direction_stack.erase(d)
			direction_stack.push_back(d)
		elif Input.is_action_just_released(act):
			direction_stack.erase(d)
	
	if direction_stack.is_empty():
		current_direction = Direction.NONE
	else:
		current_direction = direction_stack.back()

func get_movement_vector(camera_basis: Basis) -> Vector3:
	var move_dir: Vector3 = Vector3.ZERO
	var forward: Vector3 = -camera_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	
	var right: Vector3 = camera_basis.x
	right.y = 0.0
	right = right.normalized()
	
	match current_direction:
		Direction.FORWARD:
			move_dir = forward
		Direction.BACKWARD:
			move_dir = -forward
		Direction.LEFT:
			move_dir = -right
		Direction.RIGHT:
			move_dir = right
		Direction.NONE:
			move_dir = Vector3.ZERO
	
	return move_dir

func consume_jump() -> bool:
	var j: bool = jump_requested
	jump_requested = false
	return j

func consume_restart() -> bool:
	var r: bool = restart_requested
	restart_requested = false
	return r
