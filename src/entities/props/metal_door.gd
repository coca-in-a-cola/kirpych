class_name MetalDoor
extends StaticBody3D

## Heavy industrial metal door breached by high speed impacts
signal door_breached(speed_kmh: float)

@export var breach_speed_threshold: float = 35.0 ## km/h
@export var is_breached: bool = false

@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var door_mesh: MeshInstance3D = $DoorMesh
@onready var impact_area: Area3D = $ImpactArea
@onready var audio_clang: AudioStreamPlayer3D = $AudioClang

func _ready() -> void:
	if impact_area:
		impact_area.body_entered.connect(_on_impact_body_entered)

func _physics_process(delta: float) -> void:
	if is_breached and door_mesh:
		# Blast door swinging open on hinge
		door_mesh.rotation.y = lerpf(door_mesh.rotation.y, deg_to_rad(110.0), 12.0 * delta)

func _on_impact_body_entered(body: Node3D) -> void:
	if is_breached:
		return
	
	var speed_kmh: float = 0.0
	if body.has_method("get_speed_kmh"):
		speed_kmh = body.get_speed_kmh()
	
	if speed_kmh >= breach_speed_threshold:
		is_breached = true
		door_breached.emit(speed_kmh)
		
		if collision_shape:
			collision_shape.set_deferred("disabled", true)
		if audio_clang and audio_clang.stream:
			audio_clang.play()
