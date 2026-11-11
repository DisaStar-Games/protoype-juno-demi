class_name MapScreen
extends ScreenPanel

## The route map: the line from the start to the destination with the train on it, a few
## landmarks, the upcoming hazards the events warn about, and the junction with the switch
## position. Pure view: reads TrainState, GameState and EventManager.

func build_screen() -> void:
	var view := MapView.new()
	view.set_anchors_preset(Control.PRESET_FULL_RECT)
	viewport.add_child(view)


## The drawing. A Control so it can use the canvas draw calls.
class MapView extends Control:
	const TRACK_X := 150.0
	const Y_START := 410.0
	const Y_END := 90.0

	var _font: Font = ThemeDB.fallback_font

	func _process(_delta: float) -> void:
		queue_redraw()

	func _y_for(ratio: float) -> float:
		return lerpf(Y_START, Y_END, clampf(ratio, 0.0, 1.0))

	func _text(pos: Vector2, text: String, size: int, color: Color) -> void:
		draw_string(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, color)

	func _draw() -> void:
		var route_length: float = GameState.route_length
		var progress := clampf(TrainState.distance / route_length, 0.0, 1.0)
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.05, 0.08))
		for i in range(1, 10):
			draw_line(Vector2(0, i * 50.0), Vector2(size.x, i * 50.0), Color(1, 1, 1, 0.03))
		_text(Vector2(14, 30), "ROUTE MAP", 24, Color(0.45, 0.7, 1.0))
		draw_line(Vector2(14, 42), Vector2(size.x - 14, 42), Color(0.45, 0.7, 1.0, 0.5), 1.0)

		# The track: dim ahead of the train, bright behind it.
		var train_y := _y_for(progress)
		draw_line(Vector2(TRACK_X, Y_START), Vector2(TRACK_X, Y_END), Color(0.3, 0.33, 0.4), 6.0)
		draw_line(Vector2(TRACK_X, Y_START), Vector2(TRACK_X, train_y), Color(0.4, 0.9, 0.5), 6.0)

		_text(Vector2(TRACK_X + 18, Y_START + 5), "START", 16, Color(0.6, 0.65, 0.7))
		_text(Vector2(TRACK_X + 18, Y_END + 5), "DESTINATION", 16, Color(1.0, 0.95, 0.6))
		draw_circle(Vector2(TRACK_X, Y_START), 8.0, Color(0.6, 0.65, 0.7))
		draw_circle(Vector2(TRACK_X, Y_END), 10.0, Color(1.0, 0.95, 0.6))
		for i in GameState.checkpoint_ratios.size():
			var ratio: float = GameState.checkpoint_ratios[i]
			var wy := _y_for(ratio)
			var color := Color(0.4, 0.9, 0.5) if progress >= ratio else Color(0.6, 0.65, 0.7)
			draw_circle(Vector2(TRACK_X, wy), 6.0, color)
			_text(Vector2(14, wy + 5), GameState.checkpoint_names[i], 16, color)

		for event in EventManager.events:
			if not event.is_live() or event.silent or event.category != TrainEvent.Category.OUTSIDE:
				continue
			_draw_hazard(event, route_length)

		# The train: a marker pointing along the route.
		var tip := Vector2(TRACK_X, train_y - 14.0)
		draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-11, 26), tip + Vector2(11, 26)]), Color(1.0, 0.85, 0.2))
		draw_polyline(PackedVector2Array([tip, tip + Vector2(-11, 26), tip + Vector2(11, 26), tip]), Color(0.1, 0.1, 0.1), 2.0)

		var remaining: float = maxf(route_length - TrainState.distance, 0.0)
		var eta := "--:--"
		if TrainState.speed > 0.5:
			eta = GameState.format_time(remaining / TrainState.speed)
		_draw_chase()
		_text(Vector2(14, 492), "ETA %s    %d%%    %.0f u/s" % [eta, roundi(progress * 100.0), TrainState.speed], 18, Color(0.8, 0.85, 0.9))

	## While bandits chase the train: a bar with the bandits (red) behind the train (yellow). The
	## further apart, the safer; it also says how many seconds of boost are still needed.
	func _draw_chase() -> void:
		var chase = null
		for event in EventManager.events:
			if event.id == &"bandits" and event.state == TrainEvent.State.ACTIVE:
				chase = event
		if chase == null:
			return
		var left_x := 20.0
		var right_x := size.x - 30.0
		var y := 462.0
		var danger: float = 1.0 - chase.gap
		var blink: float = 0.6 + 0.4 * sin(Time.get_ticks_msec() / 120.0) if danger > 0.7 else 1.0
		_text(Vector2(14, 446), "BANDITS  boost %d s" % ceili(chase.boost_time_left()) if TrainState.speed > chase.escape_speed else "BANDITS  BOOST NOW!", 16, Color(1.0, 0.4, 0.35, blink))
		draw_line(Vector2(left_x, y), Vector2(right_x, y), Color(0.3, 0.33, 0.4), 4.0)
		var bandit_x: float = right_x - lerpf(10.0, right_x - left_x, chase.gap)
		draw_circle(Vector2(bandit_x, y), 8.0, Color(1.0, 0.3, 0.25))
		draw_colored_polygon(PackedVector2Array([Vector2(right_x + 14, y), Vector2(right_x - 4, y - 9), Vector2(right_x - 4, y + 9)]), Color(1.0, 0.85, 0.2))

	func _draw_hazard(event: TrainEvent, route_length: float) -> void:
		var y := _y_for(event.trigger_distance / route_length)
		var remaining := maxi(0, roundi(event.remaining_distance()))
		if event.id == &"track_split":
			var on_a: bool = TrainState.current_track == &"A"
			var a_color := Color(0.4, 0.9, 0.5) if on_a else Color(0.45, 0.48, 0.55)
			var b_color := Color(0.45, 0.48, 0.55) if on_a else Color(0.4, 0.9, 0.5)
			draw_polyline(PackedVector2Array([Vector2(TRACK_X, y + 12), Vector2(TRACK_X - 30, y - 10), Vector2(TRACK_X - 30, y - 34)]), a_color, 5.0)
			draw_polyline(PackedVector2Array([Vector2(TRACK_X, y + 12), Vector2(TRACK_X + 30, y - 10), Vector2(TRACK_X + 30, y - 34)]), b_color, 5.0)
			_text(Vector2(TRACK_X - 42, y - 40), "A", 16, a_color)
			_text(Vector2(TRACK_X + 36, y - 40), "B", 16, b_color)
			_text(Vector2(TRACK_X + 50, y + 8), "JUNCTION %du" % remaining, 16, Color(1.0, 0.7, 0.2))
			return
		var color := Color(1.0, 0.35, 0.3)
		var center := Vector2(TRACK_X, y)
		draw_colored_polygon(PackedVector2Array([center + Vector2(0, -11), center + Vector2(11, 0), center + Vector2(0, 11), center + Vector2(-11, 0)]), color)
		_text(Vector2(TRACK_X + 18, y + 5), "%s %du" % [event.display_name.to_upper(), remaining], 16, color)
