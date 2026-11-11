class_name Extinguisher
extends ItemPickup

## Fire extinguisher. Hold LMB to spray water in the direction you look; fires within
## reach of the spray lose health (see FireSpot). It cannot be thrown.

@export var spray_range := 5.0
## Fire health removed per second while the spray hits.
@export var extinguish_rate := 40.0

## Water used per second of spraying, taken from the pockets (0 = free).
@export var water_per_second := 0.0

## Played once when spraying starts.
@export var spray_begin_sound: AudioStream
## Loops while the button is held and the extinguisher is actually spraying. Starts after the begin sound.
@export var spray_loop_sound: AudioStream
## Played once when spraying stops (button released, empty, or the item is put away mid-spray).
@export var spray_end_sound: AudioStream

## Seconds the sounds overlap and fade into each other (begin -> loop -> end, and each loop
## repeat into the next). 0 = hard cuts.
@export var crossfade_time := 0.2

var spraying := false
var _begin_player: AudioStreamPlayer3D
## Two players take turns playing the loop so each repeat can crossfade into the next.
var _loops: Array[AudioStreamPlayer3D] = []
var _cur := -1
var _tweens: Array[Tween] = []
var _water_used := 0.0

@onready var spray: CPUParticles3D = $Spray


func _ready() -> void:
	super()
	spray.emitting = false


## Called by HeldItem every physics frame while LMB is held.
func use_held(delta: float, origin: Vector3, direction: Vector3) -> void:
	if water_per_second > 0.0:
		_water_used += water_per_second * delta
		while _water_used >= 1.0:
			_water_used -= 1.0
			if not Inventory.remove(&"water", 1):
				_water_used = 0.0
				stop_use()
				GameState.post_message("Out of water! Fill up at the barrel.")
				return
		if Inventory.count(&"water") <= 0 and _water_used <= 0.0:
			stop_use()
			return
	if not spraying:
		_start_sounds()
	spraying = true
	spray.emitting = true
	_update_loop()
	var end := origin + direction * spray_range
	for fire in get_tree().get_nodes_in_group("fire"):
		if not fire.burning:
			continue
		var closest := Geometry3D.get_closest_point_to_segment(fire.global_position, origin, end)
		if closest.distance_to(fire.global_position) <= fire.radius:
			fire.extinguish(extinguish_rate * delta)


## Called by HeldItem when LMB is released or the item leaves the hand.
func stop_use() -> void:
	var was_spraying := spraying
	spraying = false
	spray.emitting = false
	if was_spraying:
		_fade_out_and_stop()
		Sfx.play_at(self, spray_end_sound)
	else:
		_stop_players()


func _start_sounds() -> void:
	_kill_fades()
	_stop_players()
	if _loops.is_empty() and spray_loop_sound != null:
		var stream := _non_looping_copy(spray_loop_sound)
		for n in 2:
			var player := AudioStreamPlayer3D.new()
			player.stream = stream
			add_child(player)
			_loops.append(player)
	if spray_begin_sound != null:
		if _begin_player == null:
			_begin_player = AudioStreamPlayer3D.new()
			_begin_player.stream = spray_begin_sound
			add_child(_begin_player)
		_begin_player.volume_db = 0.0
		_begin_player.play()


## The loop is made of overlapping one-shot plays, so the stream itself must not loop.
func _non_looping_copy(stream: AudioStream) -> AudioStream:
	var copy := stream.duplicate() as AudioStream
	if copy is AudioStreamOggVorbis or copy is AudioStreamMP3:
		copy.loop = false
	elif copy is AudioStreamWAV:
		copy.loop_mode = AudioStreamWAV.LOOP_DISABLED
	return copy


## Starts the loop near the end of the begin sound, then crossfades each repeat into the next.
func _update_loop() -> void:
	if _loops.is_empty():
		return
	var t := _fade_time()
	if _cur < 0:
		if _begin_remaining() <= t:
			_cur = 0
			_play_loop(_cur)
			if _begin_player != null and _begin_player.playing:
				_fade_player(_begin_player, t, true)
		return
	var current := _loops[_cur]
	var length := current.stream.get_length()
	if not current.playing or length - current.get_playback_position() <= t:
		var next := 1 - _cur
		_fade_player(current, t, true)
		_cur = next
		_play_loop(_cur)


func _play_loop(index: int) -> void:
	var player := _loops[index]
	var t := _fade_time()
	player.volume_db = -60.0 if t > 0.0 else 0.0
	player.play()
	if t > 0.0:
		var tween := create_tween()
		tween.tween_property(player, "volume_db", 0.0, t)
		_track(tween)


## Crossfade length, kept short enough that two overlaps never collide inside a short loop clip.
func _fade_time() -> float:
	var t := maxf(crossfade_time, 0.0)
	if not _loops.is_empty():
		t = minf(t, _loops[0].stream.get_length() * 0.4)
	return t


## Seconds left of the begin sound (0 when it is not playing or there is none).
func _begin_remaining() -> float:
	if _begin_player == null or not _begin_player.playing:
		return 0.0
	return maxf(0.0, spray_begin_sound.get_length() - _begin_player.get_playback_position())


func _fade_player(player: AudioStreamPlayer3D, t: float, stop_after: bool) -> void:
	if t <= 0.0:
		if stop_after:
			player.stop()
		return
	var tween := create_tween()
	tween.tween_property(player, "volume_db", -60.0, t)
	if stop_after:
		tween.tween_callback(player.stop)
	_track(tween)


func _fade_out_and_stop() -> void:
	_kill_fades()
	var t := _fade_time()
	var any := false
	for player in [_begin_player] + _loops:
		if player != null and player.playing:
			_fade_player(player, t, true)
			any = true
	_cur = -1
	if not any:
		_stop_players()


func _stop_players() -> void:
	Sfx.set_playing(_begin_player, false)
	for player in _loops:
		Sfx.set_playing(player, false)
	_cur = -1


func _track(tween: Tween) -> void:
	_tweens = _tweens.filter(func(t: Tween) -> bool: return t.is_valid())
	_tweens.append(tween)


func _kill_fades() -> void:
	for tween in _tweens:
		if tween.is_valid():
			tween.kill()
	_tweens.clear()
