extends DebugWindow

## F2 events debug menu (F1 shows the train values). Start any event, in the train or on
## the track, watch the live ones, and resolve or fail them by hand. The number keys 1-9
## start the same events at any time. Autoload `EventsDebugPanel`, hidden by default;
## while open the cursor is free.

@onready var rows: VBoxContainer = %Rows

var _inside_rows: VBoxContainer
var _outside_rows: VBoxContainer
var _live_rows: VBoxContainer
var _summary: Label
var _chances: Label
var _live_labels := {} # TrainEvent -> its Label


func _ready() -> void:
	visible = false
	_build()
	EventManager.events_changed.connect(_rebuild_live)
	_rebuild_live()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_events_panel"):
		toggle()
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if not visible:
		return
	for event in _live_labels:
		if is_instance_valid(event):
			_live_labels[event].text = _event_line(event)
	_summary.text = "%d more scheduled on the route" % _pending_count()
	_chances.text = chances_text()


## The live list as text: one line per event that is not just waiting, then the number
## still scheduled on the route.
func live_text() -> String:
	var lines: Array[String] = []
	for event in EventManager.events:
		if event.state != TrainEvent.State.PENDING:
			lines.append(_event_line(event))
	lines.append("%d more scheduled on the route" % _pending_count())
	return "\n".join(lines)


## The random event chances as text: per roll, with the progress scaling, plus the rough
## number of times it starts per minute.
func chances_text() -> String:
	var pool := EventManager.random_pool
	if pool == null:
		return "No random pool"
	var progress := clampf(TrainState.distance / GameState.route_length, 0.0, 1.0)
	var lines: Array[String] = ["A roll every %d s (min %d s apart), route %d%%  ->  faults x%.1f, track x%.1f" % [
		roundi(pool.check_interval), roundi(pool.min_gap), roundi(progress * 100.0),
		lerpf(1.0, pool.fault_multiplier_at_end, progress), lerpf(1.0, pool.track_multiplier_at_end, progress)]]
	for row in EventManager.chance_table():
		var where := "train" if row.category == TrainEvent.Category.INSIDE else "track"
		var per_minute: float = row.chance * 60.0 / pool.check_interval
		lines.append("%-15s %-5s %4.1f%% per roll  (base %.1f%%)  ~%.2f/min  %s" % [
			row.name, where, row.chance * 100.0, row.base * 100.0, per_minute, row.note])
	return "\n".join(lines)


## Every row of buttons in the start sections and the live list (handy for tests).
func button_rows() -> Array[HBoxContainer]:
	var found: Array[HBoxContainer] = []
	for box in [_inside_rows, _outside_rows, _live_rows]:
		for child in box.get_children():
			if child is HBoxContainer and not child.is_queued_for_deletion():
				found.append(child)
	return found


func _build() -> void:
	var title := Label.new()
	title.text = "EVENTS  (F2 to close, number keys 1-9 start them too)"
	rows.add_child(title)

	rows.add_child(_header("IN THE TRAIN"))
	_inside_rows = _section()
	rows.add_child(_header("ON THE TRACK  (outside the train)"))
	_outside_rows = _section()

	for i in EventManager.debug_events.size():
		var inside := EventManager.debug_event_category(i) == TrainEvent.Category.INSIDE
		var line := HBoxContainer.new()
		(_inside_rows if inside else _outside_rows).add_child(line)
		var start := Button.new()
		start.text = "%d  Start: %s" % [i + 1, EventManager.debug_event_name(i)]
		start.pressed.connect(func() -> void: EventManager.force_start(i))
		line.add_child(start)
		var now := Button.new()
		now.text = "Active now"
		now.pressed.connect(func() -> void: EventManager.force_start(i, true))
		line.add_child(now)

	rows.add_child(HSeparator.new())
	rows.add_child(_header("RANDOM EVENT CHANCES  (right now)"))
	_chances = Label.new()
	rows.add_child(_chances)

	rows.add_child(HSeparator.new())
	rows.add_child(_header("LIVE EVENTS"))
	_live_rows = _section()
	_summary = Label.new()
	rows.add_child(_summary)

	rows.add_child(HSeparator.new())
	var tools := HBoxContainer.new()
	rows.add_child(tools)
	var clear := Button.new()
	clear.text = "Clear all events"
	clear.pressed.connect(EventManager.clear)
	tools.add_child(clear)
	var reload := Button.new()
	reload.text = "Reload the route"
	reload.pressed.connect(EventManager.load_route)
	tools.add_child(reload)
	var ghost := Button.new()
	ghost.text = "Spawn ghost here"
	ghost.pressed.connect(_spawn_ghost)
	tools.add_child(ghost)
	var systems_row := HBoxContainer.new()
	rows.add_child(systems_row)
	var wreck := Button.new()
	wreck.text = "Wreck the train (crash)"
	wreck.pressed.connect(EventManager.wreck_train)
	systems_row.add_child(wreck)
	var repair := Button.new()
	repair.text = "Repair console"
	repair.pressed.connect(func() -> void: TrainState.repair_system(&"controls"))
	systems_row.add_child(repair)
	var kill := Button.new()
	kill.text = "Kill bandits"
	kill.pressed.connect(_kill_bandits)
	systems_row.add_child(kill)

	var random_row := HBoxContainer.new()
	rows.add_child(random_row)
	var random_toggle := CheckBox.new()
	random_toggle.text = "Random events"
	random_toggle.button_pressed = EventManager.random_enabled
	random_toggle.toggled.connect(func(on: bool) -> void: EventManager.random_enabled = on)
	random_row.add_child(random_toggle)
	var idle_toggle := CheckBox.new()
	idle_toggle.text = "Idle bandits"
	idle_toggle.button_pressed = EventManager.idle_raid_enabled
	idle_toggle.toggled.connect(func(on: bool) -> void: EventManager.idle_raid_enabled = on)
	random_row.add_child(idle_toggle)
	var roll := Button.new()
	roll.text = "Roll one now"
	roll.pressed.connect(func() -> void: EventManager.roll_random_event(true))
	random_row.add_child(roll)


func _header(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	return label


func _section() -> VBoxContainer:
	var box := VBoxContainer.new()
	rows.add_child(box)
	return box


## Rebuilds the live list whenever an event is added, removed or changes state.
func _rebuild_live() -> void:
	for child in _live_rows.get_children():
		child.queue_free()
	_live_labels.clear()
	for event in EventManager.events:
		if event.state == TrainEvent.State.PENDING:
			continue
		var line := HBoxContainer.new()
		var label := Label.new()
		label.custom_minimum_size.x = 250
		label.text = _event_line(event)
		line.add_child(label)
		var resolve := Button.new()
		resolve.text = "Resolve"
		resolve.disabled = not event.is_live()
		resolve.pressed.connect(event.resolve)
		line.add_child(resolve)
		var fail := Button.new()
		fail.text = "Fail"
		fail.disabled = not event.is_live()
		fail.pressed.connect(event.fail)
		line.add_child(fail)
		_live_rows.add_child(line)
		_live_labels[event] = label


func _event_line(event: TrainEvent) -> String:
	var tag := "(hallucination) " if event.silent else ""
	return "%s%s  [%s]  %d u" % [tag, event.display_name, TrainEvent.State.keys()[event.state], maxi(0, roundi(event.remaining_distance()))]


func _pending_count() -> int:
	var pending := 0
	for event in EventManager.events:
		if event.state == TrainEvent.State.PENDING:
			pending += 1
	return pending


## Puts a harmless ghost in the player's room (cabins only), whatever the hallucination level.
func _spawn_ghost() -> void:
	var spawner := get_tree().get_first_node_in_group("ghost_spawner")
	if spawner != null:
		spawner.spawn_ghost()


## Stands in for the future weapon: every bandit on the train dies.
func _kill_bandits() -> void:
	for bandit in get_tree().get_nodes_in_group("bandit"):
		bandit.hit(9999.0)
