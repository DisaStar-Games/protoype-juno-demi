extends StaticBody3D

## Endless coal source: the player grabs a fresh coal cube straight from the pile.

@export var coal_scene: PackedScene


func spawn_coal() -> RigidBody3D:
	var coal := coal_scene.instantiate() as RigidBody3D
	get_tree().current_scene.add_child(coal)
	coal.global_position = global_position + Vector3(0, 0.8, 0)
	return coal
