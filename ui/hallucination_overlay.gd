extends CanvasLayer

## Full-screen hallucination effect (wobble, sickly tint, pulsing dark edges) that grows
## with TrainState.hallucination_intensity. Hidden entirely while the player is fine.
## Autoload `HallucinationOverlay`.

@onready var screen: ColorRect = $Screen


func _ready() -> void:
	TrainState.hallucination_changed.connect(_on_intensity_changed)
	_on_intensity_changed(TrainState.hallucination_intensity)


func _on_intensity_changed(intensity: float) -> void:
	visible = intensity > 0.0
	(screen.material as ShaderMaterial).set_shader_parameter("intensity", intensity)
