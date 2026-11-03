class_name CabinZone
extends Node3D

## One room of the train as a box around this node, so the game can ask "which room is
## the player in" and pick spots inside it. Encounters (trespassers, ghosts) only happen
## in zones with `encounters_allowed`. Place and resize the zones in the level.

@export var zone_name := "Cabin"
## The box around this node: x across, y high, z along the train.
@export var size := Vector3(4.0, 4.5, 8.0)
@export var encounters_allowed := true


func _ready() -> void:
	add_to_group("cabin_zones")


func contains(point: Vector3) -> bool:
	var local := to_local(point)
	return absf(local.x) <= size.x * 0.5 and absf(local.y) <= size.y * 0.5 and absf(local.z) <= size.z * 0.5


## A random spot on the floor of the zone, away from the walls.
func random_floor_point(rng: RandomNumberGenerator, margin := 0.8) -> Vector3:
	var local := Vector3(
		rng.randf_range(-size.x * 0.5 + margin, size.x * 0.5 - margin),
		-size.y * 0.5,
		rng.randf_range(-size.z * 0.5 + margin, size.z * 0.5 - margin))
	return to_global(local)


## A floor spot at least `min_distance` from `from`. If the room is too small for that
## (the player stands in the middle), the farthest corner is used instead.
func floor_point_away_from(from: Vector3, min_distance: float, rng: RandomNumberGenerator, margin := 0.8) -> Vector3:
	for i in 24:
		var candidate := random_floor_point(rng, margin)
		if Vector2(candidate.x - from.x, candidate.z - from.z).length() >= min_distance:
			return candidate
	var best := random_floor_point(rng, margin)
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var point := to_global(Vector3(corner.x * (size.x * 0.5 - margin), -size.y * 0.5, corner.y * (size.z * 0.5 - margin)))
		if Vector2(point.x - from.x, point.z - from.z).length() > Vector2(best.x - from.x, best.z - from.z).length():
			best = point
	return best


## The zone that contains `point`, or null.
static func at(tree: SceneTree, point: Vector3) -> CabinZone:
	for zone in tree.get_nodes_in_group("cabin_zones"):
		if zone.contains(point):
			return zone
	return null
