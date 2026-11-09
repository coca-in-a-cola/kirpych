class_name Level03
extends Node3D

## Level 03: Rooftop & Tower Cranes ("Высотные работы" — Гранд-финал)
@onready var brick: BrickController = $Brick
@onready var camera_rail: CameraRail = $CameraRail
@onready var cradle_finish: CradleFinish = $CradleFinish
@onready var hud: GameHUD = $GameHUD

var is_game_over: bool = false
var respawn_position: Vector3 = Vector3(0.0, 29.0, 0.0)

func _ready() -> void:
	if brick and hud:
		brick.speed_changed.connect(_on_brick_speed_changed)
	
	if camera_rail and brick:
		camera_rail.target = brick
	
	if cradle_finish:
		cradle_finish.campaign_completed.connect(_on_campaign_completed)

func _physics_process(_delta: float) -> void:
	if not brick:
		return
	
	# Fall bounds: falling off the rooftop structure
	if brick.global_position.y < 15.0:
		_respawn_brick()
	
	# Restart input
	if Input.is_action_just_pressed("restart"):
		Engine.time_scale = 1.0
		get_tree().reload_current_scene()

func _on_brick_speed_changed(speed_kmh: float) -> void:
	if hud and not is_game_over:
		hud.update_speed(speed_kmh)

func _on_campaign_completed(speed_kmh: float) -> void:
	is_game_over = true
	if hud:
		hud.show_victory(speed_kmh)

func _respawn_brick() -> void:
	brick.global_position = respawn_position
	brick.velocity = Vector3.ZERO
