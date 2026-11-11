class_name TrainAmbience
extends AudioStreamPlayer

## The ambient sound of the train (rattling, engine hum). Put the sound in this node's Stream
## slot; it loops by itself while the level is open. The volume follows the train's speed:
## silent when standing still, `quietest_moving_db` as soon as it moves, up to `loudest_db` at
## cruising speed.

## Fade the sound with the speed of the train. Off = always at the node's own volume.
@export var follow_speed := true
## Volume at cruising speed (and above), in dB.
@export var loudest_db := -7.0
## Volume when the train has just started to move, in dB. (Standing still it is silent.)
@export var quietest_moving_db := -15.0
## Below this speed the train counts as standing still.
@export var standstill_speed := 0.1
## How quickly the volume follows the speed.
@export var smoothing := 2.0


func _ready() -> void:
	make_loop(stream)
	if stream != null and not playing:
		play()


func _process(delta: float) -> void:
	if not follow_speed:
		return
	var speed := TrainState.world_speed()
	var target := 0.0 # linear, so standing still is true silence (-infinite dB)
	if speed > standstill_speed:
		var t := clampf(speed / TrainState.max_speed, 0.0, 1.0)
		target = db_to_linear(lerpf(quietest_moving_db, loudest_db, t))
	volume_linear = lerpf(volume_linear, target, clampf(smoothing * delta, 0.0, 1.0))


## Makes a stream loop (shared with TrainMusic).
static func make_loop(audio: AudioStream) -> void:
	if audio is AudioStreamOggVorbis or audio is AudioStreamMP3:
		audio.loop = true
	elif audio is AudioStreamWAV and audio.loop_mode == AudioStreamWAV.LOOP_DISABLED:
		# Loop the whole clip (8/16 bit; for other formats set the loop in the import dock).
		var bytes := 2 if audio.format == AudioStreamWAV.FORMAT_16_BITS else 1
		if audio.format > AudioStreamWAV.FORMAT_16_BITS:
			push_warning("This WAV is compressed: set Loop Mode to Forward (and Compress Mode to Disabled) in its Import tab to make it loop.")
		else:
			audio.loop_begin = 0
			audio.loop_end = audio.data.size() / (bytes * (2 if audio.stereo else 1))
			audio.loop_mode = AudioStreamWAV.LOOP_FORWARD
