class_name DebugWindow
extends CanvasLayer

## Base of the F1 (train values) and F2 (events) debug panels. While any of them is open
## the cursor is free so the buttons and sliders can be used; when the last one closes the
## cursor is captured again if it was captured before.

static var _open_count := 0
static var _cursor_was_captured := false


## True while any debug panel is open (the player's click-to-recapture waits for it).
static func any_open() -> bool:
	return _open_count > 0


func toggle() -> void:
	set_open(not visible)


func set_open(open: bool) -> void:
	if open == visible:
		return
	visible = open
	if open:
		if _open_count == 0:
			_cursor_was_captured = Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		_open_count += 1
	else:
		_open_count = maxi(_open_count - 1, 0)
		if _open_count == 0 and _cursor_was_captured:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
