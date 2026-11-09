class_name GameHUD
extends CanvasLayer

## Speedometer HUD, victory results overlay, and industrial pause menu
@onready var speed_label: Label = $SpeedContainer/SpeedLabel
@onready var victory_panel: Control = $VictoryPanel
@onready var final_speed_label: Label = $VictoryPanel/FinalSpeedLabel
@onready var rank_label: Label = $VictoryPanel/RankLabel
@onready var restart_hint: Label = $VictoryPanel/RestartHint
@onready var btn_next: Button = $VictoryPanel/HBoxButtons/BtnNextLevel
@onready var btn_menu: Button = $VictoryPanel/HBoxButtons/BtnMenu

@onready var pause_panel: Control = $PausePanel
@onready var btn_pause_resume: Button = $PausePanel/VBoxButtons/BtnResume
@onready var btn_pause_restart: Button = $PausePanel/VBoxButtons/BtnRestart
@onready var btn_pause_menu: Button = $PausePanel/VBoxButtons/BtnMenu

var next_level_scene: String = ""

func _ready() -> void:
	if victory_panel:
		victory_panel.visible = false
	if pause_panel:
		pause_panel.visible = false
	update_speed(0.0)
	
	if btn_next:
		btn_next.pressed.connect(_on_next_pressed)
	if btn_menu:
		btn_menu.pressed.connect(_on_menu_pressed)
	
	if btn_pause_resume:
		btn_pause_resume.pressed.connect(_on_pause_resume_pressed)
	if btn_pause_restart:
		btn_pause_restart.pressed.connect(_on_pause_restart_pressed)
	if btn_pause_menu:
		btn_pause_menu.pressed.connect(_on_pause_menu_pressed)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if victory_panel and victory_panel.visible:
			return
		toggle_pause()

func toggle_pause() -> void:
	if not pause_panel:
		return
	var will_pause: bool = !get_tree().paused
	get_tree().paused = will_pause
	pause_panel.visible = will_pause
	if will_pause and btn_pause_resume:
		btn_pause_resume.grab_focus()

func _on_pause_resume_pressed() -> void:
	get_tree().paused = false
	if pause_panel:
		pause_panel.visible = false

func _on_pause_restart_pressed() -> void:
	get_tree().paused = false
	if pause_panel:
		pause_panel.visible = false
	get_tree().reload_current_scene()

func _on_pause_menu_pressed() -> void:
	get_tree().paused = false
	if pause_panel:
		pause_panel.visible = false
	get_tree().change_scene_to_file("res://src/ui/main_menu.tscn")

func update_speed(speed_kmh: float) -> void:
	if not speed_label:
		return
	speed_label.text = "%.1f КМ/Ч" % speed_kmh
	
	if speed_kmh < 25.0:
		speed_label.modulate = Color(0.9, 0.9, 0.9)
	elif speed_kmh < 50.0:
		speed_label.modulate = Color(0.95, 0.75, 0.1) # Yellow
	elif speed_kmh < 75.0:
		speed_label.modulate = Color(0.95, 0.45, 0.1) # Orange
	else:
		speed_label.modulate = Color(0.95, 0.15, 0.15) # Red hot!

func show_victory(speed_kmh: float, next_scene: String = "") -> void:
	next_level_scene = next_scene
	if pause_panel:
		pause_panel.visible = false
	if not victory_panel or not final_speed_label or not rank_label:
		return
	victory_panel.visible = true
	final_speed_label.text = "СКОРОСТЬ УДАРА: %.1f КМ/Ч" % speed_kmh
	
	var rank: String = "C"
	var rank_color: Color = Color.WHITE
	if speed_kmh >= 75.0:
		rank = "S+ (СВЕРХЗВУКОВОЙ КИРПИЧ!)"
		rank_color = Color(1.0, 0.85, 0.0)
	elif speed_kmh >= 55.0:
		rank = "A (ПРОБИЛ КАСКУ НАСКВОЗЬ)"
		rank_color = Color(0.2, 0.9, 0.3)
	elif speed_kmh >= 35.0:
		rank = "B (УВЕРЕННОЕ СОТРЯСЕНИЕ)"
		rank_color = Color(0.3, 0.7, 1.0)
	else:
		rank = "C (СЛАБЕНЬКИЙ ЩЕЛЧОК)"
		rank_color = Color(0.8, 0.8, 0.8)
	
	rank_label.text = "РАНГ: %s" % rank
	rank_label.modulate = rank_color
	
	if btn_next:
		btn_next.visible = (next_level_scene != "")
		if btn_next.visible:
			btn_next.grab_focus()
		elif btn_menu:
			btn_menu.grab_focus()

func _on_next_pressed() -> void:
	get_tree().paused = false
	if next_level_scene != "":
		get_tree().change_scene_to_file(next_level_scene)

func _on_menu_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://src/ui/main_menu.tscn")
