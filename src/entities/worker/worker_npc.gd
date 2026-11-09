class_name WorkerNPC
extends CharacterBody3D

## Construction worker in yellow helmet pursued by the brick
signal helmet_hit(speed_kmh: float)

@export var run_speed: float = 4.2
@export var target_door_z: float = 114.0

@onready var helmet_area: Area3D = $HelmetArea
@onready var helmet_mesh: MeshInstance3D = $HelmetMesh
@onready var audio_clang: AudioStreamPlayer3D = $AudioClang

var is_hit: bool = false
var has_escaped: bool = false
var helmet_detached: bool = false
var helmet_velocity: Vector3 = Vector3.ZERO
var anim_player: AnimationPlayer = null

func _ready() -> void:
	if helmet_area:
		helmet_area.body_entered.connect(_on_helmet_body_entered)
	_setup_animation()

func _setup_animation() -> void:
	if has_node("CharacterModel"):
		anim_player = $CharacterModel.get_node_or_null("AnimationPlayer")
	if anim_player == null:
		anim_player = find_child("AnimationPlayer", true, false) as AnimationPlayer
	if anim_player:
		if anim_player.has_animation("walk"):
			anim_player.play("walk")
		elif anim_player.has_animation("run"):
			anim_player.play("run")

func _physics_process(delta: float) -> void:
	if is_hit:
		# Comedic flight into the doorway
		velocity.y -= 15.0 * delta
		move_and_slide()
		
		if helmet_detached and helmet_mesh:
			helmet_velocity.y -= 20.0 * delta
			helmet_mesh.global_position += helmet_velocity * delta
			helmet_mesh.rotate_x(12.0 * delta)
			helmet_mesh.rotate_y(8.0 * delta)
		return
	
	# Normal run toward the door
	if global_position.z < target_door_z:
		velocity.z = run_speed
		# Slight comedic wobble
		rotation.y = sin(Time.get_ticks_msec() * 0.008) * 0.15
		if anim_player and not anim_player.is_playing():
			if anim_player.has_animation("walk"):
				anim_player.play("walk")
			elif anim_player.has_animation("run"):
				anim_player.play("run")
	else:
		velocity.z = 0.0
		if anim_player and anim_player.is_playing() and anim_player.current_animation in ["walk", "run"]:
			if anim_player.has_animation("idle"):
				anim_player.play("idle")
			else:
				anim_player.stop()
	
	# Real gravity while running, so the worker can never glide on air past a floor edge;
	# each level must place target_door_z on solid floor (GDD 8: NPC stays in a reachable end zone).
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= 15.0 * delta
	
	move_and_slide()

func _on_helmet_body_entered(body: Node3D) -> void:
	if is_hit:
		return
	
	var speed_kmh: float = 0.0
	if body.has_method("get_speed_kmh"):
		speed_kmh = body.get_speed_kmh()
	
	is_hit = true
	helmet_hit.emit(speed_kmh)
	
	if audio_clang and audio_clang.stream:
		audio_clang.play()
	
	# Knock helmet flying
	helmet_detached = true
	helmet_velocity = Vector3(
		randf_range(-2.0, 2.0),
		8.0 + (speed_kmh * 0.1),
		10.0 + (speed_kmh * 0.2)
	)
	
	# Knock worker forward into door
	velocity = Vector3(0.0, 4.0, 6.0 + (speed_kmh * 0.15))
	if anim_player:
		if anim_player.has_animation("jump"):
			anim_player.play("jump")
		elif anim_player.has_animation("static"):
			anim_player.play("static")
		else:
			anim_player.stop()
