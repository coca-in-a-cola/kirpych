class_name MainMenu
extends Control

## Industrial style Main Menu with campaign launch, level select, and controls guide
@onready var btn_play: Button = $VBoxContainer/BtnPlay
@onready var btn_lvl1: Button = $VBoxContainer/HBoxLevels/BtnLvl1
@onready var btn_lvl2: Button = $VBoxContainer/HBoxLevels/BtnLvl2
@onready var btn_lvl3: Button = $VBoxContainer/HBoxLevels/BtnLvl3
@onready var btn_quit: Button = $VBoxContainer/BtnQuit
@onready var controls_dialog: Panel = $ControlsDialog
@onready var btn_controls: Button = $VBoxContainer/BtnControls
@onready var btn_close_controls: Button = $ControlsDialog/BtnCloseControls

func _ready() -> void:
	if btn_play:
		btn_play.pressed.connect(_on_play_pressed)
	if btn_lvl1:
		btn_lvl1.pressed.connect(func(): _load_direct(1))
	if btn_lvl2:
		btn_lvl2.pressed.connect(func(): _load_direct(2))
	if btn_lvl3:
		btn_lvl3.pressed.connect(func(): _load_direct(3))
	if btn_controls:
		btn_controls.pressed.connect(_on_controls_pressed)
	if btn_close_controls:
		btn_close_controls.pressed.connect(_on_close_controls_pressed)
	if btn_quit:
		btn_quit.pressed.connect(_on_quit_pressed)
	
	if controls_dialog:
		controls_dialog.visible = false

func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://src/levels/level_01.tscn")

func _load_direct(idx: int) -> void:
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
