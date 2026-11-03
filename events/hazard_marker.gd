class_name HazardMarker
extends Node3D

## Beacon that shows an approaching event through the cockpit's front window.
## It is a child of its TrainEvent. A thin pillar of light stands on the track ahead and
## closes in as the event's remaining distance shrinks, with a sign that names the
## event and counts the distance down.
##
## The front window sits above the dashboard, so ground-level objects far ahead stay
## hidden below it. The pillar therefore always reaches above the window's top edge, and
## the sign is kept on a fixed line of sight through the window.

@export var color := Color(1.0, 0.4, 0.2)
## Beacon distance in the world = remaining distance * this (400 u of warning -> 120 m).
@export var visual_scale := 0.3
## Closest the beacon gets: just ahead of the windscreen.
@export var min_visual_distance := 4.0
@export var pillar_width := 1.2
## Where the player's eyes are while driving; the sign is aligned to this view.
@export var eye_position := Vector3(0.0, 1.7, 3.3)
@export var sign_elevation_degrees := 14.0
## How tall the sign's text looks to the player, in radians (0.05 is about 3 degrees).
@export var sign_angular_size := 0.05

var event: TrainEvent

@onready var pillar: MeshInstance3D = $Pillar
@onready var sign_label: Label3D = $Sign


func _ready() -> void:
	event = get_parent() as TrainEvent
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.disable_fog = true # a beacon stays visible through the night fog
	pillar.material_override = material
	pillar.mesh = BoxMesh.new()
	sign_label.modulate = color.lightened(0.4)
	visible = false


func _process(_delta: float) -> void:
	if event == null:
		return
	visible = event.is_live()
	if not visible:
		return

	var remaining := event.remaining_distance()
	var beacon_distance := maxf(remaining * visual_scale, min_visual_distance)
	var eye_distance := beacon_distance + eye_position.z # horizontal distance from the player's eyes
	position = Vector3(0.0, 0.0, -beacon_distance)

	# Pillar: from the ground up past the top edge of the window as seen from the eyes.
	var ground := -1.0
	var top := eye_position.y + eye_distance * tan(deg_to_rad(40.0))
	(pillar.mesh as BoxMesh).size = Vector3(pillar_width, top - ground, pillar_width)
	pillar.position.y = (top + ground) * 0.5

	# Sign: on a fixed line of sight, scaled so it keeps the same apparent size.
	sign_label.position.y = eye_position.y + eye_distance * tan(deg_to_rad(sign_elevation_degrees))
	sign_label.pixel_size = eye_distance * sign_angular_size / sign_label.font_size
	sign_label.text = event.sign_text()
