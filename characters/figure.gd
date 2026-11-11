class_name Figure
extends Node3D

## A blocky humanoid with glowing eyes, in two modes:
##  - TRESPASSER (a stalker): it stands in a cabin facing the player. While the player looks
##    at it, it freezes; while the player looks away, it creeps closer. Stare at it long
##    enough and it vanishes; if it reaches the player it jump-scares them (`caught`).
##  - GHOST (a gas-leak hallucination): pale and see-through, it never moves or hurts. It
##    vanishes when looked at, approached, or after a while.
## Looking at a figure gives an effect: a screen glitch and flaring eyes when the player
## first notices it, and a shard burst plus a bigger glitch when it vanishes.
## It has no collision, so it can never block a doorway.

enum Mode { TRESPASSER, GHOST }

## The player looked at the figure for the first time (since last looking away).
signal noticed
## It disappeared. `reason`: &"stared" (stared down), &"approached", &"left" (the player
## left its room), &"expired", &"caught" (after the jump scare), &"cancelled".
signal vanished(reason: StringName)
## The trespasser reached the player (the jump scare starts).
signal caught

const BURST := preload("res://characters/vanish_burst.tscn")

@export_group("Looking")
## How far from the middle of the view still counts as looking at it, in degrees.
@export var look_cone_degrees := 32.0
@export var look_max_distance := 14.0
## Height (above the figure's feet) the player's gaze has to hit.
@export var look_height := 1.4
@export_group("Trespasser")
@export var creep_speed := 1.5
@export var catch_distance := 0.9
## Seconds of staring that make it vanish.
@export var vanish_after := 1.5
## Seconds the player may be outside its room before it gives up.
@export var leave_grace := 1.5
@export_group("Ghost")
@export var ghost_lifetime := 8.0
@export var ghost_vanish_after := 0.8
@export var ghost_approach_distance := 2.5

var mode := Mode.TRESPASSER
var zone: CabinZone
var player: Node
var looked_at := false
## Seconds the player has been looking at it (it decays when they look away).
var stare_time := 0.0
var done := false

var _was_looked_at := false
var _away := 0.0
var _age := 0.0
var _catching := false
var _catch_time := 0.0
var _eye_nodes: Array[Node3D] = []

@onready var visual: Node3D = $Visual


func _ready() -> void:
	set_physics_process(false) # waits for setup()
	for child in visual.get_children():
		if child.name.begins_with("Eye"):
			_eye_nodes.append(child)
	_apply_look()


## Puts the figure to work: `home_zone` is its room (it gives up when the player leaves it).
func setup(new_mode: Mode, player_node: Node, home_zone: CabinZone) -> void:
	mode = new_mode
	player = player_node
	zone = home_zone
	_apply_look()
	set_physics_process(true)


func is_catching() -> bool:
	return _catching


## True when the player's gaze is on the figure: close enough, near the middle of the view
## and with a clear line of sight (walls and crates block it).
func is_looked_at(camera: Camera3D) -> bool:
	var target := global_position + Vector3(0.0, look_height, 0.0)
	var eye := camera.global_position
	if eye.distance_to(target) > look_max_distance:
		return false
	var forward := -camera.global_transform.basis.z
	if forward.dot((target - eye).normalized()) < cos(deg_to_rad(look_cone_degrees)):
		return false
	var query := PhysicsRayQueryParameters3D.create(eye, target)
	if player is CollisionObject3D:
		query.exclude = [(player as CollisionObject3D).get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _physics_process(delta: float) -> void:
	if done or player == null or GameState.state != GameState.State.RUNNING:
		return # also frozen once the run has ended
	_age += delta
	if _catching:
		_update_catch(delta)
		return

	_face(player.global_position)
	var camera := _camera()
	looked_at = camera != null and is_looked_at(camera)
	if looked_at:
		if not _was_looked_at:
			_on_noticed()
		stare_time += delta
		if stare_time >= (ghost_vanish_after if mode == Mode.GHOST else vanish_after):
			_vanish(&"stared")
			return
	else:
		stare_time = maxf(stare_time - delta * 0.5, 0.0)
	_was_looked_at = looked_at

	# It stays in its room: when the player walks away it gives up.
	if zone != null and not zone.contains(player.global_position):
		_away += delta
		if _away >= leave_grace:
			_vanish(&"left")
			return
	else:
		_away = 0.0

	if mode == Mode.GHOST:
		if _age >= ghost_lifetime:
			_vanish(&"expired")
		elif _flat_distance(player.global_position) <= ghost_approach_distance:
			_vanish(&"approached")
		return

	# Stalker: frozen while watched, creeping while not.
	if not looked_at:
		var toward: Vector3 = player.global_position - global_position
		toward.y = 0.0
		if toward.length() > 0.01:
			global_position += toward.normalized() * creep_speed * delta
		if _flat_distance(player.global_position) <= catch_distance:
			_start_catch()


## Ends the figure without any effect or signal (the event ended some other way).
func cancel() -> void:
	if done:
		return
	done = true
	vanished.emit(&"cancelled")
	queue_free()


func _on_noticed() -> void:
	noticed.emit()
	ScreenEffects.glitch(0.5, 0.35)
	_flare_eyes(1.0)


func _start_catch() -> void:
	_catching = true
	_catch_time = 0.0
	_place_in_front_of_camera()
	_flare_eyes(1.0, 0.7)
	ScreenEffects.flash(Color(0.9, 0.05, 0.05), 0.7, 0.6)
	ScreenEffects.glitch(1.0, 0.7)
	var camera := _camera()
	if camera != null and camera.has_method("kick"):
		camera.kick(1.0, 0.7)
	caught.emit()


func _update_catch(delta: float) -> void:
	_catch_time += delta
	_place_in_front_of_camera()
	if _catch_time >= 0.7:
		_vanish(&"caught")


func _place_in_front_of_camera() -> void:
	var camera := _camera()
	if camera == null:
		return
	var forward := -camera.global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized() if forward.length() > 0.01 else Vector3.FORWARD
	global_position = Vector3(camera.global_position.x + forward.x * 0.8, global_position.y, camera.global_position.z + forward.z * 0.8)
	_face(camera.global_position)


func _vanish(reason: StringName) -> void:
	if done:
		return
	done = true
	# The player's gaze made it go: glitch + flash. Silent exits get only the shards.
	if reason == &"stared" or reason == &"approached":
		ScreenEffects.glitch(0.9, 0.45)
		ScreenEffects.flash(Color(1.0, 1.0, 1.0), 0.3, 0.3)
	_spawn_burst()
	vanished.emit(reason)
	queue_free()


func _spawn_burst() -> void:
	var burst := BURST.instantiate() as CPUParticles3D
	var host: Node = get_tree().current_scene if get_tree().current_scene != null else get_parent()
	host.add_child(burst)
	burst.global_position = global_position + Vector3(0.0, 1.0, 0.0)
	burst.color = Color(0.6, 1.0, 0.75) if mode == Mode.GHOST else Color(1.0, 0.35, 0.2)


func _flare_eyes(strength: float, duration := 0.35) -> void:
	for eye in _eye_nodes:
		var tween := create_tween()
		tween.tween_property(eye, "scale", Vector3.ONE * (1.0 + 1.2 * strength), duration * 0.3)
		tween.tween_property(eye, "scale", Vector3.ONE, duration * 0.7)


func _face(point: Vector3) -> void:
	var flat := Vector3(point.x, global_position.y, point.z)
	if flat.distance_to(global_position) > 0.05:
		look_at(flat, Vector3.UP) # the front (and the eyes) is -Z


func _flat_distance(point: Vector3) -> float:
	return Vector2(point.x - global_position.x, point.z - global_position.z).length()


func _camera() -> Camera3D:
	if player != null and "camera" in player:
		return player.camera
	return get_viewport().get_camera_3d()


func _apply_look() -> void:
	var body := StandardMaterial3D.new()
	var eyes := StandardMaterial3D.new()
	eyes.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	eyes.emission_enabled = true
	if mode == Mode.GHOST:
		body.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		body.albedo_color = Color(0.7, 1.0, 0.8, 0.32)
		body.emission_enabled = true
		body.emission = Color(0.4, 0.9, 0.6)
		body.emission_energy_multiplier = 0.8
		eyes.albedo_color = Color(0.9, 1.0, 0.95)
		eyes.emission = Color(0.7, 1.0, 0.85)
	else:
		body.albedo_color = Color(0.03, 0.03, 0.04)
		body.roughness = 1.0
		eyes.albedo_color = Color(1.0, 0.15, 0.1)
		eyes.emission = Color(1.0, 0.1, 0.05)
	eyes.emission_energy_multiplier = 3.0
	for part in visual.get_children():
		part.material_override = eyes if part.name.begins_with("Eye") else body
