extends CPUParticles3D

## One-shot burst of blocky shards where a figure vanished. Frees itself afterwards.


func _ready() -> void:
	emitting = true
	get_tree().create_timer(lifetime + 0.3).timeout.connect(queue_free)
