class_name SceneryStrip
extends Node3D

## A row of props (telegraph poles, trees...) that streams past the train. The train never
## really moves, so each prop slides toward +Z at TrainState.world_speed() and wraps from
## the rear back to the far end ahead. Only a handful of props exist, they are recycled.

@export var prop_scene: PackedScene
## Distance between props along the track.
@export var spacing := 12.0
## Distance from the track centre; props are mirrored to both sides.
@export var x_offset := 5.0
@export var both_sides := true
## Random sideways spread and size variation (0 = all props identical).
@export var jitter_x := 0.0
@export var scale_jitter := 0.0
@export var random_seed := 1
## Props wrap once they pass this z (behind the train, which spans z 0..40).
@export var z_start := 45.0
## How far ahead of z_start the row extends before props wrap.
@export var length := 180.0

## Total wrap distance (a whole number of spacings).
var span := 0.0

var _props: Array[Node3D] = []


func _ready() -> void:
	var count := ceili(length / spacing)
	span = count * spacing
	var rng := RandomNumberGenerator.new()
	rng.seed = random_seed
	var sides: Array[int] = [1]
	if both_sides:
		sides = [-1, 1]
	for i in count:
		for side in sides:
			var prop := prop_scene.instantiate() as Node3D
			var x := side * (x_offset + rng.randf_range(-jitter_x, jitter_x))
			# The two sides are staggered by half a spacing so they do not pass in lockstep.
			var z := z_start - i * spacing - (spacing * 0.5 if side > 0 else 0.0)
			prop.position = Vector3(x, 0.0, z)
			if scale_jitter > 0.0:
				prop.scale = Vector3.ONE * rng.randf_range(1.0 - scale_jitter, 1.0 + scale_jitter)
			add_child(prop)
			_props.append(prop)


func _process(delta: float) -> void:
	var step: float = TrainState.world_speed() * delta
	if step == 0.0:
		return
	for prop in _props:
		prop.position.z += step
		if prop.position.z > z_start:
			prop.position.z -= span
