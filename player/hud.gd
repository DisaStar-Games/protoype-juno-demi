extends Control

## Interaction prompt, hold-progress bar, held-item label and crosshair highlight.

@onready var prompt_label: Label = %PromptLabel
@onready var hold_bar: ProgressBar = %HoldBar
@onready var held_label: Label = %HeldLabel
@onready var crosshair_dot: ColorRect = %ColorRect2
@onready var flash: ColorRect = %Flash

var _held: ItemPickup
var _flash_tween: Tween
var _message_label: Label
var _message_tween: Tween
var _slot_counts := {}   # item id -> amount Label


func _ready() -> void:
	%InteractRay.prompt_changed.connect(_on_prompt_changed)
	%InteractRay.hold_progress_changed.connect(_on_hold_progress_changed)
	%HeldItem.changed.connect(_on_held_changed)
	GameState.penalty_applied.connect(_on_penalty)
	flash.color.a = 0.0
	_build_message_line()
	_build_inventory()
	GameState.message_posted.connect(_on_message_posted)
	_on_prompt_changed("")
	_on_held_changed(null)


func _on_prompt_changed(text: String) -> void:
	prompt_label.text = text
	crosshair_dot.color = Color.YELLOW if text != "" else Color.WHITE


func _on_hold_progress_changed(progress: float) -> void:
	hold_bar.visible = progress > 0.0
	hold_bar.value = progress


func _process(_delta: float) -> void:
	# Items with a live status (the shotgun's shells) refresh their line every frame.
	if is_instance_valid(_held) and _held.has_method("hud_status"):
		_refresh_held_label()


func _on_held_changed(item: ItemPickup) -> void:
	_held = item
	_refresh_held_label()


func _refresh_held_label() -> void:
	if not is_instance_valid(_held):
		held_label.text = "Hands empty"
		return
	var hints := "[Q] drop"
	if _held.throwable:
		hints = "[LMB] throw   " + hints
	elif _held.use_hint != "":
		hints = "[LMB] %s   %s" % [_held.use_hint, hints]
	if _held.extra_hint != "":
		hints = "%s   %s" % [_held.extra_hint, hints]
	var text := "Holding: %s    %s" % [_held.display_name, hints]
	if _held.has_method("hud_status"):
		text += "    " + _held.hud_status()
	held_label.text = text


## Brief red flash over the whole screen when a failed event costs time.
func _on_penalty(_seconds: float, _reason: String) -> void:
	flash.color.a = 0.4
	if _flash_tween != null:
		_flash_tween.kill()
	_flash_tween = create_tween()
	_flash_tween.tween_property(flash, "color:a", 0.0, 0.7)


## A short feedback line under the top edge ("Boost on", "The console is broken!"). The cockpit
## screen only lists the tasks at hand; this is for one-off feedback.
func _build_message_line() -> void:
	_message_label = Label.new()
	_message_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_message_label.offset_left = -320.0
	_message_label.offset_right = 320.0
	_message_label.offset_top = 40.0
	_message_label.offset_bottom = 66.0
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_message_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_message_label.add_theme_constant_override("outline_size", 6)
	_message_label.modulate.a = 0.0
	add_child(_message_label)


func _on_message_posted(text: String) -> void:
	_message_label.text = text
	_message_label.modulate.a = 1.0
	if _message_tween != null:
		_message_tween.kill()
	_message_tween = create_tween()
	_message_tween.tween_interval(2.5)
	_message_tween.tween_property(_message_label, "modulate:a", 0.0, 0.5)


## The three inventory slots at the bottom of the screen: a placeholder logo (a letter on a
## coloured square) and the amount.
func _build_inventory() -> void:
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	row.offset_left = -130.0
	row.offset_right = 130.0
	row.offset_top = -92.0
	row.offset_bottom = -16.0
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	for id in Inventory.SLOTS:
		var info: Dictionary = Inventory.INFO[id]
		var slot := PanelContainer.new()
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.05, 0.05, 0.07, 0.7)
		style.set_corner_radius_all(6)
		style.set_content_margin_all(6)
		slot.add_theme_stylebox_override("panel", style)
		row.add_child(slot)
		var column := VBoxContainer.new()
		column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(column)
		var logo := ColorRect.new()
		logo.color = info["color"]
		logo.custom_minimum_size = Vector2(52, 40)
		logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(logo)
		var glyph := Label.new()
		glyph.text = info["glyph"]
		glyph.set_anchors_preset(Control.PRESET_FULL_RECT)
		glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		glyph.add_theme_font_size_override("font_size", 24)
		glyph.add_theme_color_override("font_outline_color", Color.BLACK)
		glyph.add_theme_constant_override("outline_size", 6)
		logo.add_child(glyph)
		var amount := Label.new()
		amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		amount.add_theme_font_size_override("font_size", 16)
		column.add_child(amount)
		_slot_counts[id] = amount
	Inventory.changed.connect(_on_inventory_changed)
	for id in Inventory.SLOTS:
		_on_inventory_changed(id)


func _on_inventory_changed(id: StringName) -> void:
	var label: Label = _slot_counts[id]
	label.text = "%d/%d" % [Inventory.count(id), Inventory.capacity(id)]
	label.modulate = Color(1, 1, 1) if Inventory.count(id) > 0 else Color(0.6, 0.6, 0.65)
