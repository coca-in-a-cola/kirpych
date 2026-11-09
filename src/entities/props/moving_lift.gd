class_name MovingLift
extends AnimatableBody3D

## Vertical construction hoist moving smoothly between bottom and top stations with dwell holds
@export var travel_distance: float = 12.0
@export var cycle_duration: float = 4.5
@export var dwell_time_bottom: float = 0.0
@export var dwell_time_top: float = 0.0

var origin_y: float = 0.0
var elapsed_time: float = 0.0

func _ready() -> void:
	origin_y = position.y
	sync_to_physics = true

func _physics_process(delta: float) -> void:
	elapsed_time += delta
	
	var move_half: float = cycle_duration * 0.5
	var total_period: float = dwell_time_bottom + move_half + dwell_time_top + move_half
	
	if total_period <= 0.001:
		return
	
	var t_in_cycle: float = fmod(elapsed_time, total_period)
	var phase: float = 0.0
	
	if t_in_cycle < dwell_time_bottom:
		# Holding at bottom station
		phase = 0.0
	elif t_in_cycle < (dwell_time_bottom + move_half):
		# Ascending smoothly from 0.0 to 1.0
		var t_asc: float = (t_in_cycle - dwell_time_bottom) / move_half
		phase = (1.0 - cos(t_asc * PI)) * 0.5
	elif t_in_cycle < (dwell_time_bottom + move_half + dwell_time_top):
		# Holding at top station
		phase = 1.0
	else:
		# Descending smoothly from 1.0 to 0.0
		var t_desc: float = (t_in_cycle - dwell_time_bottom - move_half - dwell_time_top) / move_half
		phase = (1.0 + cos(t_desc * PI)) * 0.5
	
	position.y = origin_y + (phase * travel_distance)
