class_name Level03
extends Node3D

## Level 03: Rooftop & Tower Cranes ("Высотные работы" — Гранд-финал)
@onready var brick: BrickController = $Brick
@onready var camera_rail: CameraRail = $CameraRail
@onready var cradle_finish: Node3D = $CradleFinish
@onready var hud: GameHUD = $GameHUD

var is_game_over: bool = false
var respawn_position: Vector3 = Vector3(0.0, 29.0, 0.0)

func _ready() -> void:
	if brick and hud:
		brick.speed_changed.connect(_on_brick_speed_changed)
	
	if camera_rail and brick:
		camera_rail.target = brick
	
	if cradle_finish and cradle_finish.has_signal("campaign_completed"):
		cradle_finish.connect("campaign_completed", _on_campaign_completed)

func _physics_process(_delta: float) -> void:
	if not brick:
		return
	
	if brick.global_position.y < 15.0:
		_respawn_brick()
	
	if Input.is_action_just_pressed("restart"):
		Engine.time_scale = 1.0
		get_tree().reload_current_scene()

func _on_brick_speed_changed(speed_kmh: float) -> void:
	if hud and not is_game_over:
		hud.update_speed(speed_kmh)

func _on_campaign_completed(speed_kmh: float) -> void:
	is_game_over = true
	if GameManager.instance:
		GameManager.instance.record_level_finish(3, speed_kmh)
	if hud:
		hud.show_victory(speed_kmh)

func _respawn_brick() -> void:
	brick.global_position = respawn_position
	brick.velocity = Vector3.ZERO
