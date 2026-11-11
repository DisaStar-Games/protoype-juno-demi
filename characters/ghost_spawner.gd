extends Node

## Spawns harmless ghosts (Figure in GHOST mode) in the cabin the player is in while they
## are hallucinating from the gas leak. The stronger the hallucination, the more often.
## One per level; the F2 panel's "Spawn ghost" button calls spawn_ghost() too.

@export var figure_scene: PackedScene
## Ghosts start above this hallucination intensity.
@export_range(0.0, 1.0) var min_intensity := 0.5
## Seconds between ghosts: this long just above the minimum, shrinking toward `interval_min`.
@export var interval_max := 14.0
@export var interval_min := 5.0

var _rng := RandomNumberGenerator.new()
var _timer := 0.0
var _ghost: Figure


func _ready() -> void:
	add_to_group("ghost_spawner")
	_rng.randomize()
	_timer = interval_max


func _physics_process(delta: float) -> void:
	tick(delta)


## Separate from _physics_process so tests can drive it.
func tick(delta: float) -> void:
	var intensity: float = TrainState.hallucination_intensity
	if intensity < min_intensity or is_instance_valid(_ghost):
		return
	_timer -= delta
	if _timer <= 0.0:
		spawn_ghost()
		var t := inverse_lerp(min_intensity, 1.0, intensity)
		_timer = lerpf(interval_max, interval_min, t) * _rng.randf_range(0.7, 1.3)


## Puts a ghost in the player's room (only rooms that allow encounters). Returns it, or null.
func spawn_ghost() -> Figure:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null or figure_scene == null:
		return null
	var zone := CabinZone.at(get_tree(), player.global_position)
	if zone == null or not zone.encounters_allowed:
		return null
	var ghost := figure_scene.instantiate() as Figure
	add_child(ghost)
	ghost.global_position = zone.floor_point_away_from(player.global_position, 4.0, _rng)
	ghost.setup(Figure.Mode.GHOST, player, zone)
	_ghost = ghost
	return ghost
