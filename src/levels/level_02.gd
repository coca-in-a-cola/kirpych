class_name Level02
extends Node3D

## Level 02: Vertical Unfinished Building ("Нарушение ТБ")
@onready var brick: BrickController = $Brick
@onready var camera_rail: CameraRail = $CameraRail
@onready var metal_door: Node3D = $MetalDoor
@onready var worker: WorkerNPC = $WorkerNPC
@onready var hud: GameHUD = $GameHUD

var is_game_over: bool = false
var respawn_position: Vector3 = Vector3(0.0, 1.2, 0.0)

func _ready() -> void:
	if brick and hud:
		brick.speed_changed.connect(_on_brick_speed_changed)
	
	if camera_rail and brick:
		camera_rail.target = brick
	
	if metal_door and metal_door.has_signal("door_breached"):
		metal_door.connect("door_breached", _on_door_breached)
	
	if worker:
		worker.helmet_hit.connect(_on_worker_helmet_hit)

func _physics_process(_delta: float) -> void:
	if not brick:
		return
	
	if brick.global_position.y < -6.0:
		_respawn_brick()
	
	if Input.is_action_just_pressed("restart"):
		get_tree().reload_current_scene()

func _on_brick_speed_changed(speed_kmh: float) -> void:
	if hud and not is_game_over:
		hud.update_speed(speed_kmh)

func _on_door_breached(speed_kmh: float) -> void:
	_finish_level(speed_kmh)

func _on_worker_helmet_hit(speed_kmh: float) -> void:
	_finish_level(speed_kmh)

func _finish_level(speed_kmh: float) -> void:
	if is_game_over:
		return
	is_game_over = true
	GameManager.record_level_finish(2, speed_kmh)
	if hud:
		hud.show_victory(speed_kmh, "res://src/levels/level_03.tscn")

func _respawn_brick() -> void:
	brick.global_position = respawn_position
	brick.velocity = Vector3.ZERO
