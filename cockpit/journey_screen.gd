class_name JourneyScreen
extends ScreenPanel

## The journey screen (replaces the map in the journey level). Follows Journey.phase:
##   CRUISING    the main line with the train heading for the junction
##   CHOICE      two cards: the station, WHICH resources it has (not how many) and the trip time;
##               the card the track switch points at is highlighted
##   TO_STATION  the destination, its resources, progress and ETA
## Pure view: reads Journey, TrainState and Inventory.INFO.

func build_screen() -> void:
	var view := JourneyView.new()
	view.set_anchors_preset(Control.PRESET_FULL_RECT)
	viewport.add_child(view)


class JourneyView extends Control:
	const C_BG := Color(0.03, 0.05, 0.08)
	const C_TEXT := Color(0.8, 0.95, 1.0)
	const C_DIM := Color(0.45, 0.55, 0.62)
	const C_EDGE := Color(0.25, 0.32, 0.4)
	const C_CARD := Color(0.06, 0.09, 0.13)
	const C_SELECT := Color(1.0, 0.8, 0.25)
	const C_TRAVEL := Color(0.4, 0.85, 1.0)

	var _font: Font = ThemeDB.fallback_font

	func _process(_delta: float) -> void:
		queue_redraw()

	func _text(pos: Vector2, text: String, font_size: int, color: Color, width := -1.0, align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
		draw_string(_font, pos, text, align, width, font_size, color)

	func _draw() -> void:
		var w := size.x
		draw_rect(Rect2(Vector2.ZERO, size), C_BG)
		for i in range(1, 10):
			draw_line(Vector2(0, i * 50.0), Vector2(w, i * 50.0), Color(1, 1, 1, 0.03))
		_text(Vector2(14, 30), "ROUTE", 24, Color(0.45, 0.7, 1.0))
		_text(Vector2(0, 30), "%d km/h" % int(TrainState.speed * 3.6), 18, C_TEXT, w - 14, HORIZONTAL_ALIGNMENT_RIGHT)
		draw_line(Vector2(14, 42), Vector2(w - 14, 42), Color(0.45, 0.7, 1.0, 0.5), 1.0)
		if not Journey.is_active():
			_text(Vector2(0, 250), "NO ROUTE", 20, C_DIM, w, HORIZONTAL_ALIGNMENT_CENTER)
			return
		match Journey.phase:
			Journey.Phase.CRUISING:
				_draw_cruising(w)
			Journey.Phase.CHOICE:
				_draw_choice(w)
			Journey.Phase.TO_STATION:
				_draw_trip(w)
			_:
				_text(Vector2(0, 250), "AT STATION", 20, C_DIM, w, HORIZONTAL_ALIGNMENT_CENTER)
		if TrainState.fuel <= 0.0:
			_banner("OUT OF FUEL - FEED THE FURNACE", w)
		elif TrainState.furnace_on_fire:
			_banner("FIRE - TRAIN SLOWING", w)

	func _banner(text: String, w: float) -> void:
		var on := int(Time.get_ticks_msec() / 350.0) % 2 == 0
		draw_rect(Rect2(0, 52, w, 26), Color(0.8, 0.1, 0.05) if on else Color(0.3, 0.05, 0.03))
		_text(Vector2(0, 71), text, 14, Color.WHITE, w, HORIZONTAL_ALIGNMENT_CENTER)

	# --- CRUISING ---

	func _draw_cruising(w: float) -> void:
		var progress := Journey.leg_progress()
		var x := 120.0
		var y_start := 440.0
		var y_fork := 190.0
		draw_line(Vector2(x, y_start), Vector2(x, y_fork), C_EDGE, 6.0)
		draw_line(Vector2(x, lerpf(y_start, y_fork, progress)), Vector2(x, y_start), Color(0.4, 0.9, 0.5), 6.0)
		draw_line(Vector2(x, y_fork), Vector2(x - 55, y_fork - 70), C_EDGE, 4.0)
		draw_line(Vector2(x, y_fork), Vector2(x + 55, y_fork - 70), C_EDGE, 4.0)
		_text(Vector2(x - 66, y_fork - 78), "?", 22, C_DIM)
		_text(Vector2(x + 52, y_fork - 78), "?", 22, C_DIM)
		var ty := lerpf(y_start, y_fork, progress)
		var tip := Vector2(x, ty - 14.0)
		draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-11, 26), tip + Vector2(11, 26)]), Color(1.0, 0.85, 0.2))
		_text(Vector2(190, 120), "MAIN LINE", 22, C_TEXT)
		var sub := "Pulling out of %s" % RouteGraph.station_name(Journey.trip_from) if Journey.trip_from != &"" else "Departed"
		_text(Vector2(190, 144), sub, 13, C_DIM)
		_text(Vector2(190, 300), "JUNCTION", 14, C_DIM)
		var eta := Journey.leg_eta()
		_text(Vector2(190, 328), "--:--" if eta < 0.0 else Journey.format_time(eta), 30, C_TEXT)
		_text(Vector2(190, 360), "Pick a station at\nthe track switch.", 13, C_DIM)
		_bar(Vector2(14, 466), w - 28.0, progress, C_TEXT)

	# --- CHOICE ---

	func _draw_choice(w: float) -> void:
		for i in 2:
			var offer: Dictionary = Journey.offers[i]
			_card(Rect2(14, 58 + i * 178.0, w - 28.0, 168.0), offer, i == Journey.selected_index, "SWITCH A" if i == 0 else "SWITCH B")
		var frac := 1.0 - Journey.choice_left / Journey.CHOICE_WINDOW
		_text(Vector2(14, 440), "LOCKS IN %s" % Journey.format_time(maxf(Journey.choice_left, 0.0)), 16, C_SELECT)
		_bar(Vector2(14, 452), w - 28.0, frac, C_SELECT)

	func _card(r: Rect2, offer: Dictionary, selected: bool, tag: String) -> void:
		draw_rect(r, C_CARD)
		var border := C_SELECT if selected else C_EDGE
		draw_rect(r, border, false, 4.0 if selected else 2.0)
		_text(r.position + Vector2(10, 20), tag + ("   < SELECTED" if selected else ""), 12, border)
		_text(r.position + Vector2(10, 52), RouteGraph.station_name(offer["id"]), 28, C_TEXT)
		_chips(r.position + Vector2(10, 70), offer["supplies"])
		_text(r.position + Vector2(10, r.size.y - 12), "TRIP  %s" % Journey.format_time(offer["time"]), 20, C_SELECT if selected else C_TEXT)

	## One chip per resource the station holds: colour, name and a "?" for the hidden amount.
	func _chips(origin: Vector2, supplies: Dictionary) -> void:
		var x := origin.x
		for item in supplies:
			var info: Dictionary = Inventory.INFO[item]
			draw_rect(Rect2(x, origin.y, 96, 28), (info["color"] as Color).darkened(0.35))
			draw_rect(Rect2(x, origin.y, 96, 28), info["color"], false, 2.0)
			_text(Vector2(x + 8, origin.y + 20), String(info["name"]), 15, Color.WHITE)
			_text(Vector2(x, origin.y + 20), "?", 15, Color(1, 1, 1, 0.7), 90.0, HORIZONTAL_ALIGNMENT_RIGHT)
			x += 102.0

	# --- TO_STATION ---

	func _draw_trip(w: float) -> void:
		var progress := Journey.leg_progress()
		var r := Rect2(14, 58, w - 28.0, 330)
		draw_rect(r, C_CARD)
		draw_rect(r, C_TRAVEL, false, 3.0)
		_text(r.position + Vector2(12, 24), "DESTINATION", 13, C_TRAVEL)
		_text(r.position + Vector2(12, 62), RouteGraph.station_name(Journey.trip_target), 32, C_TEXT)
		_chips(r.position + Vector2(12, 84), Journey.trip_supplies)
		var ty := 270.0
		draw_line(Vector2(40, ty), Vector2(w - 40, ty), C_EDGE, 4.0)
		var tx := lerpf(40.0, w - 40.0, progress)
		draw_line(Vector2(40, ty), Vector2(tx, ty), C_TRAVEL, 4.0)
		draw_circle(Vector2(w - 40, ty), 8.0, C_SELECT)
		draw_colored_polygon(PackedVector2Array([Vector2(tx + 14, ty), Vector2(tx - 8, ty - 11), Vector2(tx - 8, ty + 11)]), Color(1.0, 0.85, 0.2))
		var eta := Journey.leg_eta()
		_text(r.position + Vector2(12, r.size.y - 18), "ETA  %s" % ("--:--" if eta < 0.0 else Journey.format_time(eta)), 24, C_TRAVEL)
		_bar(Vector2(14, 410), w - 28.0, progress, C_TRAVEL)
		_text(Vector2(14, 446), "EN ROUTE", 14, C_DIM)

	func _bar(pos: Vector2, width: float, frac: float, color: Color) -> void:
		draw_rect(Rect2(pos, Vector2(width, 8)), Color(0, 0, 0, 0.5))
		draw_rect(Rect2(pos, Vector2(width * clampf(frac, 0.0, 1.0), 8)), color)
