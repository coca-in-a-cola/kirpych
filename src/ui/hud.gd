class_name GameHUD
extends CanvasLayer

## Speedometer HUD and victory results overlay
@onready var speed_label: Label = $SpeedContainer/SpeedLabel
@onready var victory_panel: Control = $VictoryPanel
@onready var final_speed_label: Label = $VictoryPanel/FinalSpeedLabel
@onready var rank_label: Label = $VictoryPanel/RankLabel
@onready var restart_hint: Label = $VictoryPanel/RestartHint
@onready var btn_next: Button = $VictoryPanel/BtnNextLevel
@onready var btn_menu: Button = $VictoryPanel/BtnMenu

var next_level_scene: String = ""

func _ready() -> void:
	if victory_panel:
		victory_panel.visible = false
	update_speed(0.0)
	
	if btn_next:
		btn_next.pressed.connect(_on_next_pressed)
	if btn_menu:
		btn_menu.pressed.connect(_on_menu_pressed)

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

func _on_next_pressed() -> void:
	if next_level_scene != "":
		get_tree().change_scene_to_file(next_level_scene)

func _on_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://src/ui/main_menu.tscn")
