class_name TrainMusic
extends AudioStreamPlayer

## Background music for the level. Put the track in this node's Stream slot; it starts when the
## level opens and loops. The volume is just the node's Volume Db (not tied to the train).

@export var loop := true


func _ready() -> void:
	if loop:
		TrainAmbience.make_loop(stream)
	if stream != null and not playing:
		play()
