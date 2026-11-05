class_name RandomEntry
extends Resource

## One event that can happen at random (see RandomPool).

@export var event_scene: PackedScene
## Chance (0..1) that this event starts at each roll.
@export_range(0.0, 1.0) var chance := 0.05
## Seconds after it started before it can be rolled again.
@export var cooldown := 45.0
