class_name GameHUD
extends CanvasLayer

## Speedometer HUD and victory results overlay
@onready var speed_label: Label = $SpeedContainer/SpeedLabel
@onready var victory_panel: Control = $VictoryPanel
@onready var final_speed_label: Label = $VictoryPanel/FinalSpeedLabel
@onready var rank_label: Label = $VictoryPanel/RankLabel
@onready var restart_hint: Label = $VictoryPanel/RestartHint

func _ready() -> void:
	if victory_panel:
		victory_panel.visible = false
	update_speed(0.0)

func update_speed(speed_kmh: float) -> void:
	if not speed_label:
		return
	speed_label.text = "%.1f КМ/Ч" % speed_kmh
	
	# Dynamic color gradient
	if speed_kmh < 25.0:
		speed_label.modulate = Color(0.9, 0.9, 0.9)
	elif speed_kmh < 50.0:
		speed_label.modulate = Color(0.95, 0.75, 0.1) # Yellow
	elif speed_kmh < 75.0:
		speed_label.modulate = Color(0.95, 0.45, 0.1) # Orange
	else:
		speed_label.modulate = Color(0.95, 0.15, 0.15) # Red hot!

func show_victory(speed_kmh: float) -> void:
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
