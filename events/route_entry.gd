class_name RouteEntry
extends Resource

## One scheduled event in a route: which scene, and where along the route it is reached.

@export var event_scene: PackedScene
@export var trigger_distance := 1000.0
## Overrides the event's own warning lead. Negative = keep the event's default.
@export var warning_distance := -1.0
## Free-form settings handed to the event as `params`.
@export var params: Dictionary = {}
