class_name CradleFinish
extends Node3D

## Final rooftop construction cradle with worker helmet target and safety net catch
signal campaign_completed(speed_kmh: float)

@onready var worker: WorkerNPC = $WorkerNPC
@onready var safety_net_mesh: MeshInstance3D = $SafetyNetMesh

var is_finished: bool = false

func _ready() -> void:
	if worker:
		worker.helmet_hit.connect(_on_helmet_hit)

func _on_helmet_hit(speed_kmh: float) -> void:
	if is_finished:
		return
	is_finished = true
	
	# Trigger slow motion effect (0.25x scale for dramatic comedic impact)
	Engine.time_scale = 0.25
	
	if is_inside_tree():
		var tree: SceneTree = get_tree()
		if tree:
			var timer: SceneTreeTimer = tree.create_timer(0.20) # 0.20s in slowmo ~ 0.8s real
			timer.timeout.connect(func(): Engine.time_scale = 1.0)
	
	campaign_completed.emit(speed_kmh)
