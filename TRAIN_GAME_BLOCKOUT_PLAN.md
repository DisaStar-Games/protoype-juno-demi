# Night Train – Blockout Demo Implementation Plan (Godot 4)

> **For the coding AI:** This is the starting brief for a first-person horror/management game set on a night train. Build a **gray-box blockout demo**: primitive meshes (CSG/MeshInstance3D boxes), no final art, no real moving train. The goal is to make every **interaction and event loop playable and testable**. Work through the milestones in order; each has acceptance criteria. Use **GDScript, Godot 4.x, static typing**, and expose tuning values as `@export` vars.

---

## 0. Current status (keep this section up to date)

**Last updated:** after Milestone 8 (cabin encounters: the stalker and ghosts; the track events of Milestone 6 are still deferred). Engine: Godot 4.7 (Forward Plus, Jolt Physics).

| Milestone | Status |
|---|---|
| 0 – Project & gray-box train | **Done** – `res://levels/TrainBlockout.tscn` |
| 1 – Player & interaction | **Done** – `Interactable`, `Interactor`, `HeldItem`, `ItemPickup`, HUD prompts, hold-to-interact, 5 item types placed |
| 2 – TrainState & cockpit controls | **Done** – `TrainState`, F1 debug panel, throttle/brake levers, dashboard gauges + warning lights, horn/boost/track-switch/radio placeholders, furnace feeds fuel |
| 3 – Core loop | **Done** – fuel drain, coal throwing, delivery timer, win/lose, end screen, restart. The optional shovel was deliberately skipped (throwing stays the only way) |
| 4 – Fake movement | **Done** – real window openings, night world outside, scrolling poles/trees, camera rumble. Audio pitch skipped on purpose (sound waits for Milestone 10) |
| 5 – Event framework | **Done** – `TrainEvent`, route resources, `EventManager`, hazard beacon, penalties, debug start. Only a throwaway `TestEvent` exists |
| 6 – Track events | Not started, **deferred by choice** (in-train events were built first; nothing here depends on it) |
| 7 – Repair events | **Done**, with changes: brake leak, gas leak with hallucinations, and a furnace *temperature + overheating fire* instead of the cabin fire (see below) |
| 8 – Cabin encounters | **Done**: blocky stalker (trespasser) and harmless ghosts, room zones, look-at effects. Triggered from F2 only (no random encounters), ghosts come from the gas leak |
| 9–10 | Not started |

### How to run it
- Press **F5**: `levels/TrainBlockout.tscn` is the project's main scene.
- `scenes/main.tscn` is the older flat test world (crates, ramp, sun light). It still has the furnace and coal, and is useful as a sandbox.
- **Esc** frees the mouse cursor, a click recaptures it. Close the window normally.

### What exists today
- **Player** – `res://player/player.tscn` + `player.gd`: first-person `CharacterBody3D` (WASD, mouse look, jump, crouch, walk, footsteps). This is the project's own controller and lives in `player/` as `player.gd`, not `Player.gd` as in the structure in section 4.
- **Controls** – **F1** train-values debug panel and **F2** events debug panel (both free the cursor while open), WASD move, mouse look, **E** interact (hold E for hold-interactions), **Shift+E** the "alt" interaction (levers step down), **LMB** throw the held item, **Q** drop it, Esc frees the cursor.
- **Interaction system (Milestone 1)**
  - `interactables/interactable.gd` – `class_name Interactable` (a `StaticBody3D`). Override `get_prompt(player)`, `can_interact(player)`, `interact(player)`, `interact_hold(player, delta)`; export `prompt_text` and `hold_time` (0 = press, >0 = hold E that many seconds). Use it for levers, buttons, the furnace-side things, repair points, etc.
  - `interactables/item_pickup.gd` + `item_pickup.tscn` – `class_name ItemPickup` (a `RigidBody3D`, so it cannot extend `Interactable`; it implements the **same four methods** and the Interactor duck-types on `interact`). Exports: `item_id` (StringName), `display_name`, `throwable`. The base scene holds a real `MeshInstance3D` + `CollisionShape3D` (a plain yellow box).
  - **Every item is its own scene in `items/` that inherits `item_pickup.tscn`** (`wrench`, `extinguisher`, `brake_fluid`, `shovel`, `coal`). Each sets its `item_id`/`display_name` and has its own mesh, shape and material, so open the scene in the editor and restyle it freely (replace the box mesh with anything, keep the collision roughly matching, keep the origin near the item's centre because that is what sits in the hand). To add an item: *New Inherited Scene* from `item_pickup.tscn`, save into `items/`, set the two exports, then drop it into a level as a normal scene instance.
  - `player/interactor.gd` – `class_name Interactor`, attached to the camera's `InteractRay` (`RayCast3D`, 3 m). Finds the target under the crosshair, shows the prompt, runs press and hold interaction (hold must be released before it can fire again). Signals `prompt_changed`, `hold_progress_changed`. Exports `require_captured_mouse` (turn off only in headless tests, where the mouse can't be captured).
  - `player/held_item.gd` – `class_name HeldItem`, the node at the bottom-right of the view. One item at a time. `pick_up()` (swaps if already holding), `drop()`, `throw()`, `consume()` (deletes the held item, for repairs). A held item is frozen with collision off and its transform is driven to this node every physics frame (**do not reparent it**; a frozen rigidbody ignores its parent). Exports `throw_force` 8, `throw_up` 3, `drop_speed` 1.5, `require_captured_mouse`. It reads LMB/Q in `_input` and all HUD `Control`s must keep `mouse_filter = Ignore`; otherwise Godot's GUI swallows the click before `_unhandled_input` sees it (this made LMB-throw silently do nothing once). Interactables reach it as `player.held_item`.
  - `player/hud.gd` – prompt label, hold-progress bar, held-item label ("Holding: X  [LMB] throw  [Q] drop"), crosshair turns yellow on a usable target.
- **`TrainState` (autoload, `autoload/train_state.tscn` + `.gd`)** – the virtual train. Properties (each emits a `*_changed` signal): `speed`, `throttle` (0–1), `brake` (0–1), `fuel`, `brake_fluid`, `distance`, `boost_active`, `current_track` (`&"A"`/`&"B"`), `hallucinating`. `simulate(delta)` runs every physics frame: speed accelerates toward `throttle × max_speed` (only with fuel; `× boost_speed_multiplier` while boosting), coasts down at `coast_decel` when throttle is lowered or fuel is out, brakes subtract `brake_decel × brake × brake_effectiveness()` (weaker with low brake fluid, down to `empty_fluid_brake_factor`), fuel drains in proportion to speed. `add_fuel()`, `reset()`. Speed snaps to exactly 0 below 0.001. Tuning lives in `@export` groups on the autoload scene (plan section 6 values; **`start_fuel` is 50 of `max_fuel` 100** so thrown coal visibly raises the bar). In headless `-s` tests, autoload names are not known at compile time: fetch them with `root.get_node("TrainState")` and start in `_initialize()`, not `_init()`.
- **`GameState` (autoload, `autoload/game_state.gd`) – PLACEHOLDER.** Only a 7:00 delivery countdown (`time_left`, `format_time()`, `reset()`, `time_left_changed`) that stops at 0. Win/lose screens, route length and restart are Milestone 3.
- **F1 debug panel – train values (autoload `DebugPanel`, `ui/debug_panel.tscn` + `.gd`)** – F1 toggles it (action `debug_panel`). Live speed/distance/fuel%/brake strength/timer, sliders for throttle, brake, speed, fuel, brake fluid, furnace temp and hallucination, toggles for boost, hallucinating and the fire/gas lamps, a track flip button, "+20 fuel", "Reset train + timer" and Force win / Force lose. **Events are not here any more, they are on F2.**
- **F2 debug panel – events (autoload `EventsDebugPanel`, `ui/events_debug_panel.tscn` + `.gd`)** – F2 toggles it (action `debug_events_panel`). A left-hand scrolling panel with: **IN THE TRAIN** (events with `category = INSIDE`: furnace fire, brake leak, gas leak) and **ON THE TRACK (outside the train)** (`category = OUTSIDE`: the test hazard now, the Milestone 6 track events later), each with a **Start** button (starts in WARNING with the normal lead, like the number key) and **Active now**; a **LIVE EVENTS** list (`Name [STATE] distance`, updating every frame, `(hallucination)` tag for fake hazards) with **Resolve** and **Fail** buttons per live event (Fail applies the event's real penalty); "N more scheduled on the route"; **Clear all events** and **Reload the route**. The number keys 1-9 start the same events with the panel open or closed.
- **`DebugWindow` (`ui/debug_window.gd`, `class_name DebugWindow`)** – base of both panels: `toggle()` / `set_open()`, frees the cursor while any panel is open and captures it again when the last one closes (if it was captured before); `DebugWindow.any_open()` is what the player's click-to-recapture waits for. New debug panels should extend it.
- **Furnace shows fuel directly** – `objects/furnace.gd`: a coal entering the intake calls `TrainState.add_fuel(fuel_per_coal)` (+20) and the 3D bar always mirrors `fuel / max_fuel`. The old separate decaying "progress" value is gone. Fuel only drains while the train moves, so in a fresh run (speed 0) the bar stays put until you set the throttle (debug panel for now, levers in slice 3).
- **Cockpit levers (slice 3)** – `interactables/lever.gd` (`class_name Lever`, extends `Interactable`) + `lever.tscn`: a stepped lever bound to a 0..1 `TrainState` value by name (`property` export + that value's `<name>_changed` signal; `title`, `steps` = 4 → 0/25/50/75/100 %). **E steps up, Shift+E steps down**, clamped at the ends; an off-step value (e.g. set from the debug panel) snaps to the next step. `TrainState` stays the single source of truth: the handle tween (tilted back at 0 %, pushed away at 100 %) and the Label3D follow the value whoever changes it. The two placed levers are inherited scenes in `cockpit/`: `throttle_lever.tscn` (blue knob) and `brake_lever.tscn` (red knob), instanced under `Controls` on the console in `TrainBlockout.tscn`. To add another stepped control: new inherited scene of `lever.tscn`, set `property` and `title`.
- **Alt interaction** – `Interactable.interact_alt(player)` (default: same as `interact`). The `Interactor` calls it instead of `interact` when the `alt_modifier` action (Shift) is held and the target has the method. Items and the coal pile fall back to normal `interact`.
- **Dashboard (slice 4)** – `cockpit/dashboard.tscn` + `dashboard.gd`, placed at the back of the console under `Controls/Dashboard` (tilted 10° toward the player). It is a pure view: it only reads `TrainState`/`GameState` signals. Built from two reusable scenes you can restyle: `cockpit/gauge.tscn` (`class_name Gauge`: `title`, `fill_color`, `show_bar`; `set_value(ratio, text)`) and `cockpit/warning_light.tscn` (`class_name WarningLight`: `warning_id`, `title`, `color`; dim when off, emissive and pulsing when on). Readouts: SPEED (bar vs boosted top speed), FUEL %, BRAKE FLUID %, DELIVERY (timer text, no bar), ROUTE % (`TrainState.distance / GameState.route_length`, `route_length` 6000 is a placeholder export on the `GameState` stub). Lamps: BRAKES, FIRE, GAS, FUEL. The levers were moved to the console sides (x ±1.35) to make room, and the player spawns at x=0, z=3.3.
- **Warning API** – `TrainState.set_warning(id, active)`, `is_warning(id)`, signal `warning_changed(id, active)`; ids `&"brakes"`, `&"fire"`, `&"gas"`, `&"fuel"`. FUEL lights below `low_fuel_threshold` (20) and BRAKES below `low_brake_fluid_threshold` (40) automatically; **FIRE and GAS are for events to set** (Milestones 5–7), the debug panel has toggles for them. `reset()` clears fire/gas. When the faulty-brakes event (M7) drains brake fluid the BRAKES light follows by itself.
- **Cockpit placeholders (slice 5)** – front row of the console, all inherited/instanced scenes in `cockpit/` you can restyle:
  - `interactables/push_button.gd` + `push_button.tscn` (`class_name PushButton`, extends `Interactable`): cap sinks when pressed, per-button cap material, signal `pressed`, virtual `_on_pressed(player)`. `horn_button.tscn` and `boost_button.tscn` inherit it and swap in their own script.
  - **Horn** (`horn_button.gd`): emits `TrainState.horn_sounded` and posts "HONK!". Milestone 6 (people/animals on the track) listens for the signal and judges the timing from `TrainState.distance`. No sound yet.
  - **Boost** (`boost_button.gd`): PLACEHOLDER toggle of `TrainState.boost_active`; the cap glows while on and follows changes made elsewhere. Milestone 9 adds the real rules (boost item, duration).
  - **Track switch** (`track_switch.gd`, `class_name TrackSwitch`): flips `TrainState.current_track` between A and B, handle swings left/right, label shows the current track. Milestone 6 (track split) checks it.
  - **Radio** (`radio.gd`): PLACEHOLDER, only posts a "static" message. Milestone 6 adds the dialogue with the track regulator.
- **Messages** – `GameState.post_message(text)` / signal `message_posted(text)`. The player HUD (`MessageLabel` in `hud.gd`) shows the latest line for 3 s, then fades. Milestone 10 can turn this into a proper log.
- **Run state (`GameState`)** – `enum State { RUNNING, WON, LOST }`, `state`, signals `state_changed(state)` and `game_over(won, reason)`. `tick(delta)` (every physics frame): reaching `route_length` wins (`"Delivered on time"`, checked first so it beats a same-frame timeout), the timer reaching 0 loses (`"Late delivery"`). `end_run(won, reason)` ends the run once and sets `TrainState.frozen = true` (speed, fuel and distance then hold). `reset()` goes back to RUNNING in the same scene (debug panel); `restart()` = `reset()` + `TrainState.reset()` + `get_tree().reload_current_scene()`, so stray coal/items, the player position, held item and event lights are all reset by the reload. Coal is still the only fuel source (thrown into the furnace, +20).
- **End screen (autoload `EndScreen`, `ui/end_screen.tscn` + `.gd`)** – dimmed overlay with "DELIVERED" / "DELIVERY FAILED", the reason, distance / time left / fuel, and a **Restart** button. It frees the cursor, hides itself when `GameState` is RUNNING again, and survives the scene reload. While the run is over the player's click-to-recapture is disabled, so the button can be used. The debug panel has **Force win / Force lose** buttons.
- **Windows are real openings (Milestone 4)** – each side wall has 10 windows (z = 2, 6, ... 38; 2 m wide, 1.4 m tall, **sill at 1.2 m so you see out at eye level**) and the cockpit front wall has one (3 m x 1.4 m, y 1.9-3.3, above the dashboard). They are CSG subtractions (`Cut*` children with `operation = 2` under `SideWall1/2` and `FrontWall1`), each closed by a faint transparent `Glass*` pane (`Mat_glass`, no shadow, **with collision** so the player cannot walk out). A physics ray through a window hits the glass, one through the wall beside it hits the wall. To move or add a window, edit the `Cut`/`Glass` pair together.
- **Outside world (`world/outside.tscn`, instanced as `Outside`)** – `Ground`, `Ballast`, two `Rail*` boxes below the train, a dim `Moon` DirectionalLight3D (shadows on, so the interior stays dark), and two scenery strips. The level's environment now uses a procedural night sky with a lighter horizon (so silhouettes read) and light fog that hides the pop-in at the far end.
- **Scenery strips (`world/scenery_strip.gd`, `class_name SceneryStrip`)** – the train never moves; each strip spawns a handful of `prop_scene` instances on both sides and slides them toward +Z at `TrainState.world_speed()`, recycling them from the rear (`z_start` 45) to the far end ahead (`length` 180). Exports: `spacing`, `x_offset`, `jitter_x`, `scale_jitter`, `random_seed`. Two strips: `Poles` (`telegraph_pole.tscn`, 12 m apart, 5 m from the track, lamp on top) and `FarTrees` (`tree_block.tscn`, 7 m apart, 10-22 m out, random sizes). Restyle by editing those prop scenes; add more strips (signal posts, a station...) by adding another `SceneryStrip` node.
- **`TrainState.world_speed()`** – the speed things outside should move at: the train's speed, but **0 once the run has ended** (the train's own `speed` is held when frozen). Use it for anything that should react to motion (scenery, shake, future sound).
- **Camera rumble (`player/camera_shake.gd`, `class_name CameraShake`, on the player's Camera3D)** – wobbles `h_offset`/`v_offset` (max 0.012 m) and roll (max 0.12 deg) in proportion to `world_speed() / max_speed`; zero at standstill. It only touches roll and the offsets, so mouse-look pitch is unaffected. Tune with the two exports.
- **Event framework (Milestone 5)**
  - `events/train_event.gd` (`class_name TrainEvent`, a `Node3D` so events can carry visuals): states `PENDING -> WARNING -> ACTIVE -> RESOLVED | FAILED`. WARNING starts `warning_distance` (400 u) before `trigger_distance`, ACTIVE when the train reaches it. Subclasses override `on_warning()`, `on_start()`, `process_event(delta)` (runs while WARNING/ACTIVE), `on_resolve()`, `on_fail()` and call `resolve()` / `fail()`. Helpers: `remaining_distance()`, `is_live()`, `is_finished()`, `force_start(active_now := false)`, `params` (from the route entry), signal `state_changed`. Failure consequences are exports on the event: `fail_time_penalty` (**default 30 s, adjustable per event**), `fail_fuel_loss`, `fail_ends_run`. A finished event frees itself after `cleanup_delay` (4 s). Warning, resolve and fail each post a HUD message.
  - `events/route_entry.gd` (`RouteEntry`: `event_scene`, `trigger_distance`, `warning_distance` override or -1, `params`) and `events/route_data.gd` (`RouteData.entries`). The demo route is `data/route_demo.tres` (swap it in `events/event_manager.tscn` for another).
  - `events/event_manager.gd` (autoload `EventManager`, scene `events/event_manager.tscn`): builds every route event up front as a PENDING child and advances them in `_physics_process` via `advance_events(delta)` (stops when the run is not RUNNING). Signals `event_warning/started/resolved/failed(event)` and `events_changed`. `live_events()`, `clear()`, `load_route()`. It **rebuilds the schedule whenever `GameState` goes back to RUNNING** (restart or debug reset).
  - **Debug / forcing:** `EventManager.debug_events` (a list of event scenes, set in the manager scene) feeds the **F2 events panel** (a **Start** and an **Active now** button per event, grouped by the event's `category`: `TrainEvent.Category.INSIDE` for repairs inside the train, `OUTSIDE` for hazards on the track, set per event scene; the default is OUTSIDE) and the **number keys 1-9** (input actions `debug_event_1..9`, always on): `force_start(index, active_now)`. Add every new event scene to `debug_events` so it is force-startable, as the plan requires.
  - **Penalties:** `GameState.apply_time_penalty(seconds, reason)` takes time off the timer (ignored once the run is over), posts "reason: -N s" and emits `penalty_applied`, which makes the HUD flash red (`Flash` rect in the player HUD). Running the timer out loses the run on the next tick.
  - `TrainState.radio_called` (new) is emitted by the radio next to `horn_sounded`; events can resolve on either.
  - **`HazardMarker` (`events/hazard_marker.tscn`, child of an event):** a thin pillar of light on the track ahead plus a sign (event name and distance left). Because the front window sits above the dashboard, ground-level objects ahead stay hidden, so the pillar always reaches above the window's top edge and the sign sits on a fixed 14 degree line of sight, scaled to keep the same apparent size. The beacon's distance is compressed (`visual_scale` 0.3: 400 u of warning = 120 m), closes in as the event nears, stops 4 m ahead of the windscreen when reached, and hides when the event is not WARNING/ACTIVE. Exports: `color`, `visual_scale`, `min_visual_distance`, `pillar_width`, `eye_position`, `sign_elevation_degrees`, `sign_angular_size`.
  - **`TestEvent` (`events/test_event.tscn` + `.gd`) - throwaway:** resolves when the horn or radio is used within `resolve_window` (250 u) of the hazard ("Too early!" before that); fails `grace_time` (2 s) after reaching it. To make a new event: new scene with a `TrainEvent`-extending script (+ a `HazardMarker` child if it should show ahead), add it to `debug_events`, and reference it from a `RouteEntry`.
- **Furnace temperature and fire (Milestone 7)**
  - `TrainState.furnace_temp` (0..`max_furnace_temp` 100). It rises **2/s while the throttle is at 100 %** (`heat_rate_full_throttle`) and **6/s while boost is on** (`heat_rate_boost`, even at a low throttle: boost always overheats it, ~17 s alone, ~12 s with full throttle), both only while there is fuel; otherwise it cools 5/s (`cool_rate`). Signals `furnace_temp_changed`, `furnace_overheated`, `furnace_fire_changed`.
  - Shown on a **FURNACE** gauge on the dashboard (bar goes green -> yellow -> red), a **TEMP** lamp (from 70, `high_temp_threshold`) and a **temperature bar on the furnace** under the fuel bar (labelled FUEL / TEMPERATURE).
  - At 100 it overheats: `EventManager` starts `events/furnace_fire_event.tscn` (id `furnace_fire`, only one at a time). `TrainState.furnace_on_fire` lights the FIRE lamp, holds the temperature at max (no cooling), ignites the `Fire` child of the furnace (`world/fire_spot.tscn`) and cuts the top speed to 50 % (`fire_power_factor`, 1 = off). Put the fire out with the extinguisher and the event resolves, the furnace drops to 50 (`temp_after_fire`) and power returns. If it burns for 25 s (`burn_time_limit`) the event fails: **45 s penalty**, the fire is put out for you, temp 50. Keeping boost on re-overheats it.
- **Extinguisher and fire (Milestone 7)** – `items/extinguisher.gd` (`class_name Extinguisher`, extends `ItemPickup`): **hold LMB to spray** water in the direction you look (HUD hint "[LMB] spray water"); it cannot be thrown. Every fire within the spray's reach (`spray_range` 5 m, hit if the spray line passes within the fire's `radius`) loses `extinguish_rate` (40) health per second. Items can now have their own LMB action: define `use_held(delta, origin, direction)` and `stop_use()` (called by `HeldItem` while LMB is held / when released or dropped) plus `use_hint`. `world/fire_spot.gd` (`class_name FireSpot`, group `fire`): `ignite()`, `extinguish(amount)`, `put_out()`, signal `extinguished`; flames shrink with its health. **Particles are blocky `CPUParticles3D`** (fire in `fire_spot.tscn`, water in the `Spray` child of `extinguisher.tscn`, drips on the reservoir, gas puffs on the leak points); tune amount, lifetime, colour ramp and velocity in those scenes.
- **Repair points (Milestone 7)** – `interactables/repair_point.gd` (`class_name RepairPoint`, extends `Interactable`): only interactable while an event sets `needs_repair`; hold E for `repair_time` with `required_item_id` in hand (prompt "Hold E: <action_text>"); without the item a press just says "You need the <item>!" and the prompt reads "Needs <item>"; `consume_item` uses the item up; signal `repaired`. This needed `Interactable.get_hold_time(player)` (the Interactor now asks it, so a hold can depend on what the player holds).
- **Brake leak (Milestone 7)** – `events/brake_leak_event.tscn`: forces the BRAKES lamp, drains **5 fluid/s** (so the brakes weaken) and makes `objects/brake_reservoir.tscn` (a `RepairPoint` in the mechanical room; drips, has a fluid level bar that turns red) interactable. Fix: carry the **brake fluid bottle** (cargo cabin crate) to it and hold E for 2 s; the bottle is used up, fluid refills, event resolves. Fails after the reservoir stays empty for 10 s: **30 s penalty**, fluid back to 30 %, leak stops.
- **Gas leak and hallucinations (Milestone 7)** – `events/gas_leak_event.tscn`: starts silently. One of the 4 `objects/leak_point.tscn` joints on the gas chamber pipes (group `gas_leak_points`, `LeakPoints` node in the level) hisses green gas. `TrainState.hallucination_intensity` (0..1; `hallucinating` is now just `intensity > 0`) grows **2 %/s**; the GAS lamp and a message come on at 40 %; once the leak is fixed it fades out by itself (`hallucination_decay`). Fix: take the **wrench** (cockpit shelf) to the leaking joint and hold E for 3 s (the wrench is kept). Intensity 100 % for 10 s fails it: **45 s penalty**, leak stops. Effects: `ui/hallucination_overlay.tscn` (autoload `HallucinationOverlay`, screen wobble, green tint, pulsing dark edges via `ui/hallucination.gdshader`, hidden at 0) and **fake hazards** (`events/fake_hazard.tscn`: silent events with a real-looking `HazardMarker` beacon that just vanish when "reached"; at most 2 at once, more often as it gets worse; marked "(hallucination)" in the debug list). Ghost figures in the cabins are left for Milestone 8.
- **Event framework additions (Milestone 7)** – `TrainEvent` got overridable `warning_message()`, `resolved_message()`, `failed_message()` (return "" to stay quiet) and `silent` (no messages, not relayed by `EventManager`). `EventManager.start_event(scene, active_now)` starts any scene outside the route; `has_live_event(id)`; `furnace_fire_event` export starts the fire automatically. **In-train events use `warning_distance = 0`** so they go straight to ACTIVE at their trigger distance and have no beacon. **Warning lights** are now "forced by an event" OR "derived from a level": `TrainState.set_warning(id, on)` forces a light, the lamps FUEL (< 20), BRAKES (< 40) and TEMP (>= 70) also stay on by themselves. The dashboard has a third row of 5 lamps (BRAKES, FIRE, GAS, FUEL, TEMP) and the FURNACE gauge (it is taller; it sits at y 1.6).
- **No softlocks** – `ItemPickup.ensure_available(tree, id)` puts a fresh item back at its home spot when it was used up (events call it for the bottle, wrench and extinguisher at their start), and any item that falls below y = -10 returns home by itself.
- **Routes** – `data/route_demo.tres` is now brake leak @ 1000, gas leak @ 2600, brake leak @ 4300 (the furnace fire comes from play, not from the route). `data/route_framework_test.tres` keeps the three throwaway test hazards for testing the framework. The F2 panel / number keys start: **1** test hazard (outside), **2** furnace fire, **3** brake leak, **4** gas leak, **5** trespasser (inside); F1 also has Furnace temp and Hallucination sliders.
- **Cabin encounters (Milestone 8)**
  - **Room zones** – `world/cabin_zone.gd` (`class_name CabinZone`, a `Node3D` with a `size` box, `zone_name`, `encounters_allowed`; group `cabin_zones`). The level has five under `CabinZones` (Cockpit, Cabin A, Cabin B, Mechanical room, Gas chamber); **only Cabin A and B allow encounters**. API: `contains(point)`, `random_floor_point()`, `floor_point_away_from(point, min_distance, rng)` (falls back to the farthest corner in a small room), static `CabinZone.at(tree, point)`. The player is in group `player`.
  - **The figure** – `characters/figure.tscn` + `figure.gd` (`class_name Figure`): a blocky humanoid (boxes, glowing eyes on its -Z front), no collision, so it never blocks a doorway. `setup(mode, player, zone)`. **Looking at it** (`is_looked_at(camera)`): within 14 m, within 32 degrees of the middle of the view, and with a clear line of sight (walls/crates block it). Everything freezes when the run is over.
  - **TRESPASSER mode (the stalker):** frozen while looked at, creeps toward the player at 1.5 u/s (`creep_speed`, slower than walking) while not; stare at it for 1.5 s (`vanish_after`, the stare fades at half speed when you look away) and it vanishes (`vanished(&"stared")`); reaching 0.9 m (`catch_distance`) is the **jump scare** (`caught`): it snaps in front of the camera for 0.7 s with a red flash, a heavy glitch and a hard camera kick. If the player leaves its room for 1.5 s (`leave_grace`) it gives up (`&"left"`).
  - **GHOST mode:** pale, see-through (alpha 0.32), never moves or hurts; vanishes after 0.8 s of staring, when you come within 2.5 m (`&"approached"`), or after 8 s (`&"expired"`).
  - **Look-at effects:** the first time you look at a figure: a screen glitch and the eyes flare (`noticed`); when it vanishes because of you (stared / approached): a bigger glitch, a white flash and a burst of blocky shards (`characters/vanish_burst.tscn`, tinted red for a stalker, green for a ghost); quiet exits (left / expired) only burst.
  - **Trespasser event** – `events/trespasser_event.tscn` (id `trespasser`, INSIDE, **20 s penalty on failure**): arms, and the stalker appears at least 5 m away in the cabin it picked as soon as the player is in it (right away if the player is already in a cabin; `params.zone` picks a cabin by name). It gives up after `armed_timeout` (120 s) if the player never goes there. Outcomes: staring it down or leaving it behind resolve the event, being caught fails it. It is **not scheduled randomly**: start it from F2 (key **5**) or a route entry. Removing the event (reset, F2 Resolve/Fail) removes the figure.
  - **Ghosts** – `characters/ghost_spawner.gd` (`GhostSpawner` node in the level, group `ghost_spawner`): while the gas leak keeps `hallucination_intensity` above 0.5, one ghost at a time appears in the player's cabin 4+ m away, every 14 s at 0.5 shrinking to 5 s at 1.0. `spawn_ghost()` is also behind the F2 **Spawn ghost here** button (works at any hallucination level, cabins only).
  - **Screen effects** – autoload `ScreenEffects` (`ui/screen_effects.tscn`, shader `ui/screen_effects.gdshader`): `glitch(strength, duration)` (tearing + colour split) and `flash(color, alpha, duration)`; the layer hides itself when idle. `CameraShake.kick(strength, duration)` is a sudden hard shake that dies down (exports `kick_offset`, `kick_roll_degrees`).
- **Items placed in the train** – instances of the `items/` scenes under the `Items` node in `TrainBlockout.tscn`, so they can be selected and moved in the editor: Wrench (cockpit shelf), Extinguisher (Cabin A seat), Brake fluid (Cabin B crate), Shovel (by the furnace). They can be picked up, swapped, dropped and thrown but have **no function yet** (repairs come in Milestone 7, shovel in Milestone 3).
- **Coal** – `res://items/coal.tscn`: an `ItemPickup` with `item_id = &"coal"`. Throwing re-enables physics and applies an impulse.
- **Coal pile** – `res://objects/coal_pile.tscn`, an `Interactable` ("[E] Take coal", only usable with empty hands). Endless supply.
- **Furnace** – `res://objects/furnace.tscn` + `furnace.gd`: block with a 3D progress bar above it. An `Intake` `Area3D` wraps the whole furnace; any `ItemPickup` with `item_id == &"coal"` that enters is consumed and calls `add_coal()`, which adds fuel to `TrainState` (see the fuel bullet above).
- **Train scene** – `res://levels/TrainBlockout.tscn`: 40 m corridor along **+Z** (front window at z=0, back at z=40), 4 m wide and 4.5 m tall, five 8 m rooms (Cockpit, Cabin A, Cabin B cargo, Mechanical room, Gas chamber) joined by doorways. Built from `CSGBox3D`/`CSGCylinder3D` under a `Geometry` node, with `Label3D` names under `Labels` and one `OmniLight3D` per room under `Lights`. Night look: dark ambient, a night sky, and **real window openings** (see below). Props: console, shelf, bed (cockpit); seats (Cabin A); crates (Cabin B); brake reservoir, coal pile, furnace (mechanical room); green pipes (gas chamber). The player spawns in the cockpit facing the front window.

### Deviations from this plan (decided with the project owner)
- **Coal is thrown, not only shovelled.** Coal is a physics object the player grabs from a pile and throws into the furnace. The shovel (Milestone 3) may be added **alongside** throwing, not instead of it.
- **Script file names are snake_case** (`player.gd`, `interactor.gd`, `held_item.gd`), not PascalCase as in the structure in section 4; the `class_name`s are PascalCase as planned. `Interactor.gd`/`HeldItem.gd` live in `player/`, `Interactable`/`ItemPickup` in `interactables/`.
- **`ItemPickup` does not extend `Interactable`** (rigid body vs static body); both share the same duck-typed API. New static interactables extend `Interactable`.
- **Controls differ from the plan's input list:** **LMB (`use_item`) throws** the held item and **Q (`drop_item`) drops** it. Items that get their own use (extinguisher) should set `throwable = false` and use LMB for that instead.
- The prototype objects (coal, coal pile, furnace) still live in `res://objects/`; reusable interactable bases are in `res://interactables/`.
- `levels/TrainBlockout.tscn` was generated once from a script and is now the source of truth. Edit it directly in the editor; there is no generator to re-run.

### Tips for whoever picks this up
- Colour code in the blockout: red = danger, yellow = item, blue = control, orange = fire, green = gas.
- Visual check: a non-headless `godot --path . --resolution 1280x720 -s shot.gd` script can set values, `await` a few frames and save `root.get_texture().get_image()` to a PNG (it briefly opens a window); useful for checking Label3D sizes and layouts. Headless check used so far: `godot --headless --quit --editor --path .` to import, then run a scene for a few frames and look for `SCRIPT ERROR`. Scripted tests via `godot --headless -s <script.gd>` work for checking throw/furnace/interaction behaviour (extend `SceneTree`, load the train scene, call `interact()` on nodes, await timers). To simulate key presses use `Input.parse_input_event(InputEventAction)`: `Input.action_press()` sets the held state but never `is_action_just_pressed`. Never name your own helper `_set` / `_get` (they clash with Object's built-ins) and BSD `sed` on macOS has no `\\b`; use Python for scripted edits. GDScript lambdas capture local variables **by value**: count things in a member variable or an array, not a local `int`. Do not declare variables typed as a `class_name` whose script touches an autoload (e.g. `Lever`, `TrainEvent`), or reference its enum (`TrainEvent.State.X`), in a test script: it fails to compile there and hangs the run; use untyped vars and plain numbers (create such classes with `load("res://...gd").new()`). Headless can't capture the mouse, so set `Interactor.require_captured_mouse = false` in such tests. After adding a new `class_name`, run the import command once so it is registered.

---

## 1. Concept summary (from the design sketches)

The player is the lone driver of a train at night, delivering cargo before a **delivery timer** runs out. They drive from the **cockpit** (throttle, brake, horn, boost, radio, track switch) and must leave the cockpit to walk through the **cabins** to fix problems (fuel the boiler, refill brake fluid, put out fires, repair gas leaks). The longer they're away from the controls, the more can go wrong ahead on the track. Walking through cabins can also trigger scary encounters (trespassers, hallucinations).

**Core tension:** stay at the controls to react to track events vs. leave to fix the train.

---

## 2. Full feature list (extracted from the sketches)

### 2.1 Cockpit controls & dashboard (sketch 2)
| Element | Function in demo |
|---|---|
| Speed pedal / throttle | Increases target speed (consumes fuel faster) |
| Brake lever | Decreases speed; effectiveness depends on brake fluid level |
| Speedometer (3 gauges) | Speed, boiler pressure/fuel, brake fluid |
| Warning lights | Light up per active problem (brakes, fire, gas, fuel) |
| Speed boost (button/lever) | Temporary speed increase, needs a fuel/boost item (optional) |
| Delivery timer | Countdown display, e.g. `10:15` |
| Map | Shows route progress + upcoming track split |
| Mirrors | Show what's behind (later: mist chase) – blockout can be a static panel |
| Radio / phone | Call the track regulator (used for track split) |
| Horn | Scare people/animals off the track |
| Shelf with items + bed | Part of the cockpit/living area; items spawn here |

### 2.2 Track events (sketch 1) – handled from the cockpit
1. **Slower train in front** → brake in time so you don't hit it.
2. **Bandits at the side of the track** → speed up to pass them before they board/rob you.
3. **People or animal on the track** → honk in time so they get off.
4. **Track divides in two** → switch the lever to the correct track; optionally learn the correct track by **calling the track regulator** on the radio and giving him info.

### 2.3 Repair events (sketch 1) – require leaving the cockpit
5. **Dash warning: faulty brakes** → find brake fluid somewhere in the cabins → find the brake reservoir and add fluid.
6. **Fire on the train** → find the extinguisher → put out the fire with it (hold to spray).
7. **Hallucination on track → gas leak** → hallucinations are the symptom; find the wrench in the cockpit → find and repair the leak with the correct tool. (Sticky note: a **"gas chamber" area** exists on the train.)

### 2.4 Core / maintenance loop (sketch 3)
8. **Shovelling coal** into the furnace to keep the train powered.
9. **Refuel / repair train**: gas leak, refuel, brakes.

### 2.5 Atmosphere / encounters
10. **Trespassers / dangerous people or animals in cabins** when walking through.
11. **Hallucination monsters/ghosts** (tied to the gas leak).

### 2.6 Optional (marked optional in the sketches)
12. **Speed boost** for the train (temporary), using a fuel item.
13. **Leave the train to grab fuel** (step off at a stop in a dark forest, grab fuel, get back on).
14. **Train chased by mist**; enemies appear when the mist passes you.

### 2.7 Areas to block out (concept art list)
- Cockpit (controls, shelf with items, bed)
- 2–3 different passenger/cargo cabins
- Mechanical room (furnace/boiler, brake reservoir)
- Gas chamber area (gas pipes, leak points)
- Optional: outside platform / dark forest stop

---

## 3. Blockout approach: the "virtual train"

The train does **not** physically move. Instead:
- A `TrainState` singleton simulates **speed, distance travelled, fuel, brake fluid**, etc.
- Track events are scheduled by **distance along the route**. Each event has a "distance until reached" that shrinks with the train's speed.
- The player sees upcoming hazards through: a **debug HUD**, a **Label3D/sprite in front of the cockpit window** that scales up as it gets closer, and (Milestone 4) scrolling sleepers/poles outside the windows to sell the speed.

This keeps everything testable while leaving room to swap in a real moving train later — only the visuals change, not the logic.

---

## 4. Project structure

```
res://
  autoload/
    TrainState.gd        # speed, fuel, brakes, distance, flags
    GameState.gd         # delivery timer, win/lose, run state
    EventManager.gd      # schedules & runs events
  player/
    Player.tscn / Player.gd          # first-person CharacterBody3D
    Interactor.gd                    # raycast + prompt
    HeldItem.gd                      # what the player is holding
  interactables/
    Interactable.gd                  # base class
    ItemPickup.gd                    # wrench, brake fluid, extinguisher, coal, fuel can
    CockpitLever.gd / CockpitButton.gd
    Furnace.gd, BrakeReservoir.gd, GasLeakPoint.gd, FireSpot.gd, Radio.gd, TrackSwitch.gd
  events/
    TrainEvent.gd                    # base class
    SlowerTrainEvent.gd, BanditsEvent.gd, ObstacleEvent.gd, TrackSplitEvent.gd
    FaultyBrakesEvent.gd, FireEvent.gd, GasLeakEvent.gd, TrespasserEvent.gd
  ui/
    HUD.tscn                         # crosshair, interaction prompt, held item, messages
    Dashboard.tscn                   # in-world dashboard (SubViewport or Label3D)
    DebugPanel.tscn                  # live values + buttons to force events
  levels/
    TrainBlockout.tscn               # the whole train interior
  data/
    route_demo.tres                  # list of scheduled events by distance
```

### Input map
`move_forward/back/left/right`, `jump` (optional), `interact` (E), `use_item` (LMB, hold for extinguisher/shovel), `drop_item` (Q), `horn` (H, also usable via button), `debug_panel` (F1, train values), `debug_events_panel` (F2, events), `debug_event_1..9` (number keys).

### Conventions
- All communication between systems through **signals** on the autoloads (e.g. `TrainState.speed_changed`, `EventManager.event_started(event)`, `GameState.game_over(reason)`).
- Every interactable extends `Interactable` with: `prompt_text: String`, `func can_interact(player) -> bool`, `func interact(player) -> void`, optional `func interact_hold(player, delta)`.
- Items are identified by a `StringName` id: `&"wrench"`, `&"brake_fluid"`, `&"extinguisher"`, `&"coal"`, `&"fuel_can"`, `&"shovel"`.
- Player carries **one item at a time** (keeps it readable and creates trips).

---

## 5. Step-by-step milestones

### Milestone 0 — Project & gray-box train  ✅ DONE
1. Create Godot 4 project, folders above, input map.
2. Build `TrainBlockout.tscn` as one long box corridor split into rooms with doorways, front to back:
   **Cockpit** (desk/console, window, shelf, bed) → **Cabin A** (seats) → **Cabin B** (cargo/crates) → **Mechanical room** (furnace, brake reservoir, coal pile) → **Gas chamber** (pipes on walls).
3. Dark lighting (night): low ambient, a few OmniLight3D per room, emissive window planes showing dark blue.
4. Label3D on each room/object for clarity during testing.

**Done when:** you can open the scene and see a readable, labelled train interior.

### Milestone 1 — Player & interaction system  ✅ DONE
> Verified with a scripted headless test (pickup, swap, drop, throw into furnace, raycast prompt, press and hold interaction, no re-fire while held). Still untested by hand in a real window; playtest the HUD layout.

1. First-person `CharacterBody3D` with mouse look, walk, collision.
2. `Interactor`: RayCast3D from camera (~2 m), detects `Interactable`, shows prompt in HUD ("[E] Pick up wrench").
3. `HeldItem` system: pick up, drop, swap; show held item name in HUD and as a simple box in front of the camera.
4. `ItemPickup` interactable; place one of each item around the train (wrench in cockpit, extinguisher in a cabin, brake fluid in cargo cabin, shovel by the furnace).
5. Support **press** and **hold** interactions (hold shows a progress bar).

**Done when:** you can walk around, pick up/drop every item, and see prompts.

### Milestone 2 — TrainState & cockpit controls  ✅ DONE
> Verified with scripted headless tests and rendered screenshots. The horn, boost, track switch and radio are **placeholders** (see section 0); their real behavior lands in Milestones 6 and 9. Still untested by hand in a real window.

1. `TrainState` autoload: `speed`, `target_speed`, `throttle (0–1)`, `brake (0–1)`, `max_speed`, `fuel`, `brake_fluid`, `distance`, `boost_active`, `current_track (A/B)`, `hallucinating`.
2. Simple simulation in `_physics_process`: speed accelerates toward throttle × max_speed (only if fuel > 0); braking decelerates with strength × `brake_fluid` factor; distance += speed × delta.
3. Cockpit interactables: **throttle lever** and **brake lever** (interact + scroll or hold to adjust; or discrete steps 0/25/50/75/100%), **horn button**, **boost button**, **track switch lever**, **radio**.
4. In-world **dashboard**: speedometer, fuel gauge, brake fluid gauge, warning lights (one per problem), delivery timer, map/progress bar. Use Label3D or a SubViewport with a Control UI.
5. `DebugPanel` (F1): all TrainState values live, sliders to override.

**Done when:** you can sit at the console, accelerate, brake, and see the gauges respond.

### Milestone 3 — Core loop: fuel, coal, delivery timer  ✅ DONE
> Shovel skipped on purpose (coal is thrown). Values are the plan's defaults and **not balanced yet**: the 6000 u route at 30 u/s is about 200 s of driving against a 7:00 timer and roughly 4 coals of fuel, so a first playtest will probably want a tighter timer or higher fuel drain (tune `GameState.delivery_time`, `GameState.route_length`, `TrainState.fuel_drain_at_max_speed`, `TrainState.start_fuel`).

1. Fuel drains proportional to speed. At 0 the train coasts to a stop.
2. **Coal into the furnace**: **already prototyped as throwing** (grab coal from the pile, throw it into the furnace; see section 0). In this milestone, connect the furnace's `add_coal()` to `TrainState.fuel` (+20 per coal). Shovelling (shovel → pile → furnace, optional hold-to-shovel) may be added as a second way, **without removing throwing**.
3. `GameState`: delivery timer counts down; route length is fixed (e.g. 5000 units). Reach the end → **win screen**. Timer hits zero → **lose screen** ("Late delivery").
4. Restart button on end screens.

**Done when:** a full run is possible: drive, refuel, arrive or fail.

### Milestone 4 — Fake movement (cheap but sells it)  ✅ DONE
> Audio pitch was deliberately left out (all sound is Milestone 10). Windows are now real openings, which Milestone 5's `HazardMarker` (in front of the cockpit window) relies on.

1. Outside each window, spawn a strip of poles/sleepers that scroll backward at `TrainState.speed` and wrap around.
2. Subtle camera shake / audio pitch scaled by speed (placeholder audio OK).

**Done when:** speed is readable from inside the train without looking at the gauge.

### Milestone 5 — Event framework  ✅ DONE
> Built as described below, with a throwaway `TestEvent` (resolve by horn or radio inside the last 250 u). Milestone 6 replaces it with the real events and decides the real penalties. Note the demo route currently schedules three test hazards (at 1200, 2800 and 4500 u), so they will show up in normal runs until Milestone 10 authors the real route.

1. `TrainEvent` base (Node or Resource + Node runner):
   - `id`, `trigger_distance`, `warning_distance`, states `PENDING → WARNING → ACTIVE → RESOLVED / FAILED`.
   - Virtual methods: `on_warning()`, `on_start()`, `process_event(delta)`, `on_resolve()`, `on_fail()`.
   - Signals for UI (warning light, HUD message, dashboard).
2. `EventManager` loads a route resource (`route_demo.tres`) = array of `{event_scene, trigger_distance, params}` and activates events as `TrainState.distance` passes them.
3. Failure consequences are **simple and configurable**: lose time, lose fuel, damage counter, or game over. Start with "lose X seconds + screen flash" so testing isn't frustrating.
4. Debug keys / DebugPanel buttons to **force-start any event immediately**.
5. Hazard visual: a `HazardMarker` (colored box + Label3D) placed in front of the cockpit window that moves closer/scales as the event's remaining distance shrinks.

**Done when:** a dummy event can be scheduled, warns, starts, and resolves/fails, visible in the debug panel.

### Milestone 6 — Track events (cockpit)
Implement each as a `TrainEvent`:

| Event | Warning | Success condition | Fail |
|---|---|---|---|
| **Slower train ahead** | Red box appears ahead, gets closer | Speed ≤ slow train speed before distance reaches 0; hold below it for N sec until it "pulls away" | Collision: big time/damage penalty |
| **Bandits by the track** | Figures by the track ahead, HUD "Bandits!" | Pass them with speed ≥ threshold (boost helps) | Robbed: lose fuel/cargo/time; optional: a trespasser spawns in a cabin |
| **People/animal on track** | Shape on track | Horn pressed while within the honk window (not too early, not too late) | Hit: penalty + scary feedback |
| **Track split** | Map shows the junction, radio blinks | Track switch set to the correct track when junction is reached | Wrong track: time penalty (detour) |

**Track split + radio:** the correct track is random. Interacting with the radio starts a short dialogue: the regulator asks for info (e.g. your train number/current location, shown somewhere on the dashboard or a note on the shelf), the player picks the right answer from 2–3 options, the regulator tells them A or B. Without calling, it's a 50/50 guess.

**Done when:** all four are playable from the cockpit and can be forced via debug.

### Milestone 7 — Repair events (leave the cockpit)  ✅ DONE (with changes)
> Built: faulty brakes (brake reservoir leak), gas leak with hallucinations, and a furnace that overheats and catches fire (put out with the extinguisher). **Not built:** the plan's separate fire that spawns in a random cabin (the extinguisher is used on the furnace fire instead), and ghost figures in the cabins (they need the Milestone 8 figure). The furnace malfunction is not in the original plan: it is a temperature system, fixed with the extinguisher only (no wrench or shovel). All numbers below are defaults for Milestone 10 to balance.

| Event | Steps | Consequence while unresolved |
|---|---|---|
| **Faulty brakes** | Warning light → find **brake fluid** (cargo cabin) → bring it to **brake reservoir** (mechanical room) → hold interact to pour | `brake_fluid` drains; brake effectiveness drops (makes "slower train" dangerous) |
| **Fire** | Fire spot spawns in a random cabin (orange box + light + particles placeholder), warning light → get **extinguisher** → hold `use_item` while aiming at fire until its health is 0 | Fire grows over time; if it maxes out → game over or heavy penalty; may spread |
| **Gas leak** | Starts silently. Symptom: **hallucinations** (fake hazards appear on the track that aren't real, ghost shapes in cabins, screen distortion). Warning light comes on later. Get **wrench** (cockpit shelf) → find the hissing leak point in the gas chamber (one of several pipes, random) → hold interact to repair | Hallucination intensity increases over time |

Notes:
- **Hallucination system** (`TrainState.hallucinating` / intensity 0–1): spawns fake `HazardMarker`s (which vanish when "reached"), ghost figures in cabins, post-process tint/wobble. Interaction-wise this teaches the player to distrust what they see.
- "Correct tool" rule: interacting with a leak without the wrench shows "You need a wrench".

**Done when:** each repair can be completed end to end and its consequence is felt if ignored.

### Milestone 8 — Cabin encounters  ✅ DONE
> Built as a **stalker** (the plan's "stands still" and "chases briefly, ends in a jump-scare" combined) plus ghosts for the gas leak. Triggers are **F2 / route only** (no random encounters, by choice). The bandits of the deferred Milestone 6 can start a trespasser with `EventManager.start_event`.

1. **Trespasser**: a capsule figure appears in a cabin when the player walks through (trigger Area3D, random chance or scheduled). Demo behaviour options (pick one, keep simple): stands still and vanishes when looked at; or blocks the door until you shine/shout/wait; or chases briefly and ends in a jump-scare + time penalty.
2. Ghosts from hallucinations reuse the same figure with a different material and no collision.

**Done when:** walking through cabins can trigger at least one encounter.

### Milestone 9 — Optional features
- **Speed boost**: fuel/boost item from a shelf → insert into the boost slot → `boost_active` for N seconds (higher max speed, extra fuel use).
- **Leave the train to grab fuel**: scheduled stop event; train stops at a platform, door opens, a small dark-forest area with a fuel can; get back on before the departure timer ends.
- **Mist chase**: a mist wall behind the train (visible in mirrors / rear window) with distance tied to train speed; if speed stays low it catches up and spawns enemies in the rear cabins.

### Milestone 10 — Demo run & polish
1. Author `route_demo.tres`: a ~5–8 minute run mixing events, e.g.
   start → coal refuel needed → people on track → faulty brakes → slower train ahead (tests brakes) → track split → fire → bandits → gas leak/hallucinations → arrival.
2. Balance the delivery timer so the run is tight but possible.
3. HUD message log for what just happened ("Brake fluid low!", "You were robbed").
4. Placeholder SFX: horn, hiss, fire crackle, alarm beep per warning light.
5. Playtest checklist: every event can succeed, every event can fail, no softlocks (items always reachable/respawn if lost), restart works.

---

## 6. Suggested starting tuning values (all `@export`)
- `max_speed` 30 u/s, accel 3 u/s², brake decel 8 u/s² at full fluid
- `route_length` 6000 u, delivery timer 7:00
- fuel 100, drain 0.4/s at max speed, coal shovel +20
- `warning_distance` for track events: 400 u; honk window: 80–250 u ahead
- slow train speed 12 u/s; bandit escape speed 22 u/s
- brake fluid drain during faulty brakes: 5/s; pour refill takes 2 s hold
- fire grow rate 5%/s, extinguish rate 25%/s
- gas leak: hallucination intensity +2%/s, warning light at 40%

---

## 7. Open design questions (decide later; don't block the blockout)
- What exactly happens on collision: instant game over or damage system?
- Is the train coal-powered (furnace) or fuel-powered (refuel)? Sketches show both — demo supports both: coal for the furnace, fuel can for boost. (Coal is thrown into the furnace; decided.)
- What is the info the player gives the track regulator?
- What do bandits do if they catch you — rob cargo, or board and become trespassers?
- What's in the "gas chamber" area beyond the leak?

---

## 8. Instructions for the coding AI
- Implement **one milestone at a time**; after each, make sure the scene runs with no errors and the acceptance criteria are met.
- Prefer small, single-purpose scripts and signals over tight coupling.
- Keep all numbers as `@export` or in the route/config resources.
- Every event must be **force-triggerable from the debug panel**.
- Use only primitive meshes, Label3D and placeholder colors (red = danger, yellow = item, blue = control, orange = fire, green = gas).
- Ask before adding new mechanics not in this document.
- **After finishing any milestone or deviating from this plan, update section 0 (status table, "What exists today", "Deviations")** so the next person is up to speed.
