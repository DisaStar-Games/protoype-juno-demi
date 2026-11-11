extends CanvasLayer

## Short full-screen effects for scares: a glitch (screen tearing and colour split) and a
## colour flash. Hidden while nothing is playing. Autoload `ScreenEffects`.

@onready var screen: ColorRect = $Screen

var _glitch_tween: Tween
var _flash_tween: Tween


func _ready() -> void:
	visible = false
	_set_param("glitch", 0.0)
	_set_param("flash", Color(0, 0, 0, 0))


## Tears the picture for `duration` seconds, fading from `strength` (0..1) to nothing.
func glitch(strength := 1.0, duration := 0.4) -> void:
	if _glitch_tween != null:
		_glitch_tween.kill()
	visible = true
	_set_param("glitch", strength)
	_glitch_tween = create_tween()
	_glitch_tween.tween_method(func(v: float) -> void: _set_param("glitch", v), strength, 0.0, duration)
	_glitch_tween.tween_callback(_update_visibility)


## Washes the screen with `color` at `alpha`, fading out over `duration` seconds.
func flash(color: Color, alpha := 0.6, duration := 0.4) -> void:
	if _flash_tween != null:
		_flash_tween.kill()
	visible = true
	_set_param("flash", Color(color.r, color.g, color.b, alpha))
	_flash_tween = create_tween()
	_flash_tween.tween_method(func(a: float) -> void: _set_param("flash", Color(color.r, color.g, color.b, a)), alpha, 0.0, duration)
	_flash_tween.tween_callback(_update_visibility)


func current_glitch() -> float:
	return (screen.material as ShaderMaterial).get_shader_parameter("glitch")


func current_flash() -> float:
	return ((screen.material as ShaderMaterial).get_shader_parameter("flash") as Color).a


func _set_param(param: String, value: Variant) -> void:
	(screen.material as ShaderMaterial).set_shader_parameter(param, value)


func _update_visibility() -> void:
	visible = current_glitch() > 0.001 or current_flash() > 0.001
