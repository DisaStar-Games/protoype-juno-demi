class_name ChestPanel
extends DebugWindow

## The chest's panel: one row per item with what is in your pockets and in the chest, and
## buttons to move one or all across. Esc or the Close button shuts it.

var chest: Chest
var _rows := {}   # item id -> Label


func _ready() -> void:
	layer = 90
	visible = false
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)

	var title := Label.new()
	title.text = "CHEST"
	title.add_theme_font_size_override("font_size", 26)
	column.add_child(title)
	var header := Label.new()
	header.text = "Your pockets are small. Keep your spare supplies here."
	column.add_child(header)

	for id in Inventory.SLOTS:
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 8)
		column.add_child(line)
		var info := Label.new()
		info.custom_minimum_size.x = 260
		line.add_child(info)
		_rows[id] = info
		_add_button(line, "Put 1", func() -> void: chest.put(id, 1))
		_add_button(line, "Put all", func() -> void: chest.put(id, 999))
		_add_button(line, "Take 1", func() -> void: chest.take(id, 1))
		_add_button(line, "Take all", func() -> void: chest.take(id, 999))

	var close := Button.new()
	close.text = "Close  (Esc)"
	close.pressed.connect(func() -> void: set_open(false))
	column.add_child(close)


func _process(_delta: float) -> void:
	if not visible:
		return
	for id in _rows:
		var name: String = Inventory.INFO[id]["name"]
		_rows[id].text = "%s   pockets %d/%d   chest %d" % [name, Inventory.count(id), Inventory.capacity(id), chest.count(id)]


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		set_open(false)
		get_viewport().set_input_as_handled()


func _add_button(line: HBoxContainer, text: String, action: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.pressed.connect(action)
	line.add_child(button)
