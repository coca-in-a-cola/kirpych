class_name MainMenu
extends Control

## Industrial style Main Menu with Lilita One typography and 100% reliable click bindings
@onready var btn_play: Button = $ContentContainer/BtnPlay
@onready var btn_lvl1: Button = $ContentContainer/HBoxLevels/BtnLvl1
@onready var btn_lvl2: Button = $ContentContainer/HBoxLevels/BtnLvl2
@onready var btn_lvl3: Button = $ContentContainer/HBoxLevels/BtnLvl3
@onready var btn_controls: Button = $ContentContainer/BtnControls
@onready var btn_quit: Button = $ContentContainer/BtnQuit
@onready var controls_dialog: Panel = $ControlsDialog
@onready var btn_close_controls: Button = $ControlsDialog/BtnCloseControls

func _ready() -> void:
	if btn_play:
		btn_play.pressed.connect(_on_play_pressed)
	if btn_lvl1:
		btn_lvl1.pressed.connect(func(): _load_level(1))
	if btn_lvl2:
		btn_lvl2.pressed.connect(func(): _load_level(2))
	if btn_lvl3:
		btn_lvl3.pressed.connect(func(): _load_level(3))
	if btn_controls:
		btn_controls.pressed.connect(_on_controls_pressed)
	if btn_close_controls:
		btn_close_controls.pressed.connect(_on_close_controls_pressed)
	if btn_quit:
		btn_quit.pressed.connect(_on_quit_pressed)
	
	if controls_dialog:
		controls_dialog.visible = false

func _on_play_pressed() -> void:
	_load_level(1)

func _load_level(idx: int) -> void:
	var scenes: Dictionary = {
		1: "res://src/levels/level_01.tscn",
		2: "res://src/levels/level_02.tscn",
		3: "res://src/levels/level_03.tscn"
	}
	if scenes.has(idx):
		get_tree().change_scene_to_file(scenes[idx])

func _on_controls_pressed() -> void:
	if controls_dialog:
		controls_dialog.visible = true

func _on_close_controls_pressed() -> void:
	if controls_dialog:
		controls_dialog.visible = false

func _on_quit_pressed() -> void:
	get_tree().quit()
