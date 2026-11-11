class_name Sfx
extends RefCounted

## Small helpers for the 3D sound slots on objects. A slot is an exported AudioStream on the
## object (empty = silent); the sound is played by an AudioStreamPlayer3D created on the object,
## so it comes from where the object is.


## Plays `stream` once, from `owner`'s position.
static func play_at(owner: Node3D, stream: AudioStream, volume_db := 0.0) -> void:
	if stream == null or owner == null or not owner.is_inside_tree():
		return
	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	player.volume_db = volume_db
	owner.add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


## A looping player for `stream` on `owner` (not playing yet; see set_playing). Null without a stream.
static func loop_player(owner: Node3D, stream: AudioStream) -> AudioStreamPlayer3D:
	if stream == null:
		return null
	TrainAmbience.make_loop(stream)
	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	owner.add_child(player)
	return player


## Starts or stops a player from loop_player (null is fine).
static func set_playing(player: AudioStreamPlayer3D, on: bool) -> void:
	if player == null:
		return
	if on and not player.playing:
		player.play()
	elif not on and player.playing:
		player.stop()
