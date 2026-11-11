class_name MessageScreen
extends ScreenPanel

## The task monitor: lists only what needs doing right now (live events and broken parts) and
## nothing else; a task disappears the moment it is done. The messages the game posts are shown
## briefly on the HUD instead. Each live event provides its line with `task_text()`.

const TASK_COLOR := Color(1.0, 0.75, 0.25)
const IDLE_COLOR := Color(0.3, 0.6, 0.4)

var _tasks: Label
var _timer := 0.0


func build_screen() -> void:
	var background := ColorRect.new()
	background.color = Color(0.02, 0.05, 0.04)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	viewport.add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	viewport.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)

	var title := Label.new()
	title.text = "TASKS"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.4, 0.8, 0.5))
	column.add_child(title)
	column.add_child(HSeparator.new())

	_tasks = Label.new()
	_tasks.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tasks.custom_minimum_size.x = viewport.size.x - 28
	_tasks.add_theme_font_size_override("font_size", 20)
	column.add_child(_tasks)
	_refresh()


func _process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0 and _tasks != null:
		_timer = 0.2
		_refresh()


## The current tasks, one per line.
func task_lines() -> Array[String]:
	var lines: Array[String] = []
	if TrainState.is_system_damaged(&"controls"):
		lines.append("Repair the console (hold E at its panel)")
	for event in EventManager.live_events():
		if event.silent:
			continue
		var line := event.task_text()
		if line != "":
			lines.append(line)
	if TrainState.fuel < TrainState.low_fuel_threshold:
		lines.append("Furnace is low on coal: feed it")
	return lines


func _refresh() -> void:
	var lines := task_lines()
	if lines.is_empty():
		_tasks.text = "Nothing to do.\nKeep the train running."
		_tasks.add_theme_color_override("font_color", IDLE_COLOR)
	else:
		_tasks.text = "\n\n".join(lines.map(func(line: String) -> String: return "> " + line))
		_tasks.add_theme_color_override("font_color", TASK_COLOR)
