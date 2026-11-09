class_name Level01
extends Node3D

## Level 01: Open Construction Yard
@onready var brick: BrickController = $Brick
@onready var camera_rail: CameraRail = $CameraRail
@onready var worker: WorkerNPC = $WorkerNPC
@onready var hud: GameHUD = $GameHUD

var is_game_over: bool = false
var respawn_position: Vector3 = Vector3(0.0, 12.5, 0.0)

func _ready() -> void:
	if brick and hud:
		brick.speed_changed.connect(_on_brick_speed_changed)
	
	if camera_rail and brick:
		camera_rail.target = brick
	
	if worker:
		worker.helmet_hit.connect(_on_worker_helmet_hit)

func _physics_process(_delta: float) -> void:
	if not brick:
		return
	
	if brick.global_position.y < -8.0:
		_respawn_brick()
	
	if Input.is_action_just_pressed("restart"):
		get_tree().reload_current_scene()

func _on_brick_speed_changed(speed_kmh: float) -> void:
	if hud and not is_game_over:
		hud.update_speed(speed_kmh)

func _on_worker_helmet_hit(speed_kmh: float) -> void:
	is_game_over = true
	if GameManager.instance:
		GameManager.instance.record_level_finish(1, speed_kmh)
	if hud:
		hud.show_victory(speed_kmh, "res://src/levels/level_02.tscn")

func _respawn_brick() -> void:
	brick.global_position = respawn_position
	brick.velocity = Vector3.ZERO
