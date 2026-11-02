# Night Train – Blockout Demo Implementation Plan (Godot 4)

> **For the coding AI:** This is the starting brief for a first-person horror/management game set on a night train. Build a **gray-box blockout demo**: primitive meshes (CSG/MeshInstance3D boxes), no final art, no real moving train. The goal is to make every **interaction and event loop playable and testable**. Work through the milestones in order; each has acceptance criteria. Use **GDScript, Godot 4.x, static typing**, and expose tuning values as `@export` vars.

---

## 0. Current status (keep this section up to date)

**Last updated:** after Milestone 1 (interaction system). Engine: Godot 4.7 (Forward Plus, Jolt Physics).

| Milestone | Status |
|---|---|
| 0 – Project & gray-box train | **Done** – `res://levels/TrainBlockout.tscn` |
| 1 – Player & interaction | **Done** – `Interactable`, `Interactor`, `HeldItem`, `ItemPickup`, HUD prompts, hold-to-interact, 5 item types placed |
| 2–10 | Not started (next: Milestone 2, `TrainState` + cockpit controls) |

### How to run it
- Open `levels/TrainBlockout.tscn` in the editor and press **F6** (Run Current Scene). It is **not** the project's main scene yet.
- `scenes/main.tscn` is the older flat test world (crates, ramp, sun light). It still has the furnace and coal, and is useful as a sandbox.
- **Esc** frees the mouse cursor, a click recaptures it. Close the window normally.

### What exists today
- **Player** – `res://player/player.tscn` + `player.gd`: first-person `CharacterBody3D` (WASD, mouse look, jump, crouch, walk, footsteps). This is the project's own controller and lives in `player/` as `player.gd`, not `Player.gd` as in the structure in section 4.
- **Controls** – WASD move, mouse look, **E** interact (hold E for hold-interactions), **LMB** throw the held item, **Q** drop it, Esc frees the cursor.
- **Interaction system (Milestone 1)**
  - `interactables/interactable.gd` – `class_name Interactable` (a `StaticBody3D`). Override `get_prompt(player)`, `can_interact(player)`, `interact(player)`, `interact_hold(player, delta)`; export `prompt_text` and `hold_time` (0 = press, >0 = hold E that many seconds). Use it for levers, buttons, the furnace-side things, repair points, etc.
  - `interactables/item_pickup.gd` + `item_pickup.tscn` – `class_name ItemPickup` (a `RigidBody3D`, so it cannot extend `Interactable`; it implements the **same four methods** and the Interactor duck-types on `interact`). Exports: `item_id` (StringName), `display_name`, `throwable`. The base scene holds a real `MeshInstance3D` + `CollisionShape3D` (a plain yellow box).
  - **Every item is its own scene in `items/` that inherits `item_pickup.tscn`** (`wrench`, `extinguisher`, `brake_fluid`, `shovel`, `coal`). Each sets its `item_id`/`display_name` and has its own mesh, shape and material, so open the scene in the editor and restyle it freely (replace the box mesh with anything, keep the collision roughly matching, keep the origin near the item's centre because that is what sits in the hand). To add an item: *New Inherited Scene* from `item_pickup.tscn`, save into `items/`, set the two exports, then drop it into a level as a normal scene instance.
  - `player/interactor.gd` – `class_name Interactor`, attached to the camera's `InteractRay` (`RayCast3D`, 3 m). Finds the target under the crosshair, shows the prompt, runs press and hold interaction (hold must be released before it can fire again). Signals `prompt_changed`, `hold_progress_changed`. Exports `require_captured_mouse` (turn off only in headless tests, where the mouse can't be captured).
  - `player/held_item.gd` – `class_name HeldItem`, the node at the bottom-right of the view. One item at a time. `pick_up()` (swaps if already holding), `drop()`, `throw()`, `consume()` (deletes the held item, for repairs). A held item is frozen with collision off and its transform is driven to this node every physics frame (**do not reparent it**; a frozen rigidbody ignores its parent). Exports `throw_force` 8, `throw_up` 3, `drop_speed` 1.5, `require_captured_mouse`. It reads LMB/Q in `_input` and all HUD `Control`s must keep `mouse_filter = Ignore`; otherwise Godot's GUI swallows the click before `_unhandled_input` sees it (this made LMB-throw silently do nothing once). Interactables reach it as `player.held_item`.
  - `player/hud.gd` – prompt label, hold-progress bar, held-item label ("Holding: X  [LMB] throw  [Q] drop"), crosshair turns yellow on a usable target.
- **Items placed in the train** – instances of the `items/` scenes under the `Items` node in `TrainBlockout.tscn`, so they can be selected and moved in the editor: Wrench (cockpit shelf), Extinguisher (Cabin A seat), Brake fluid (Cabin B crate), Shovel (by the furnace). They can be picked up, swapped, dropped and thrown but have **no function yet** (repairs come in Milestone 7, shovel in Milestone 3).
- **Coal** – `res://items/coal.tscn`: an `ItemPickup` with `item_id = &"coal"`. Throwing re-enables physics and applies an impulse.
- **Coal pile** – `res://objects/coal_pile.tscn`, an `Interactable` ("[E] Take coal", only usable with empty hands). Endless supply.
- **Furnace** – `res://objects/furnace.tscn` + `furnace.gd`: block with a 3D progress bar above it. An `Intake` `Area3D` wraps the whole furnace; any `ItemPickup` with `item_id == &"coal"` that enters is consumed and calls `add_coal()`. Progress rises by `fill_per_coal` (50) and decays at `decay_per_second` (4), max 100. All three are `@export`. The bar is not yet hooked to `TrainState` (does not exist yet).
- **Train scene** – `res://levels/TrainBlockout.tscn`: 40 m corridor along **+Z** (front window at z=0, back at z=40), 4 m wide and 4.5 m tall, five 8 m rooms (Cockpit, Cabin A, Cabin B cargo, Mechanical room, Gas chamber) joined by doorways. Built from `CSGBox3D`/`CSGCylinder3D` under a `Geometry` node, with `Label3D` names under `Labels` and one `OmniLight3D` per room under `Lights`. Night look: dark ambient, emissive blue window panels. Props: console, shelf, bed (cockpit); seats (Cabin A); crates (Cabin B); brake reservoir, coal pile, furnace (mechanical room); green pipes (gas chamber). The player spawns in the cockpit facing the front window.

### Deviations from this plan (decided with the project owner)
- **Coal is thrown, not only shovelled.** Coal is a physics object the player grabs from a pile and throws into the furnace. The shovel (Milestone 3) may be added **alongside** throwing, not instead of it.
- **Script file names are snake_case** (`player.gd`, `interactor.gd`, `held_item.gd`), not PascalCase as in the structure in section 4; the `class_name`s are PascalCase as planned. `Interactor.gd`/`HeldItem.gd` live in `player/`, `Interactable`/`ItemPickup` in `interactables/`.
- **`ItemPickup` does not extend `Interactable`** (rigid body vs static body); both share the same duck-typed API. New static interactables extend `Interactable`.
- **Controls differ from the plan's input list:** **LMB (`use_item`) throws** the held item and **Q (`drop_item`) drops** it. Items that get their own use (extinguisher) should set `throwable = false` and use LMB for that instead.
- The prototype objects (coal, coal pile, furnace) still live in `res://objects/`; reusable interactable bases are in `res://interactables/`.
- `levels/TrainBlockout.tscn` was generated once from a script and is now the source of truth. Edit it directly in the editor; there is no generator to re-run.

### Tips for whoever picks this up
- Colour code in the blockout: red = danger, yellow = item, blue = control, orange = fire, green = gas.
- Headless check used so far: `godot --headless --quit --editor --path .` to import, then run a scene for a few frames and look for `SCRIPT ERROR`. Scripted tests via `godot --headless -s <script.gd>` work for checking throw/furnace/interaction behaviour (extend `SceneTree`, load the train scene, call `interact()` on nodes, await timers). Headless can't capture the mouse, so set `Interactor.require_captured_mouse = false` in such tests. After adding a new `class_name`, run the import command once so it is registered.

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
`move_forward/back/left/right`, `jump` (optional), `interact` (E), `use_item` (LMB, hold for extinguisher/shovel), `drop_item` (Q), `horn` (H, also usable via button), `debug_panel` (F1), `debug_event_1..9` (number keys).

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

### Milestone 2 — TrainState & cockpit controls
1. `TrainState` autoload: `speed`, `target_speed`, `throttle (0–1)`, `brake (0–1)`, `max_speed`, `fuel`, `brake_fluid`, `distance`, `boost_active`, `current_track (A/B)`, `hallucinating`.
2. Simple simulation in `_physics_process`: speed accelerates toward throttle × max_speed (only if fuel > 0); braking decelerates with strength × `brake_fluid` factor; distance += speed × delta.
3. Cockpit interactables: **throttle lever** and **brake lever** (interact + scroll or hold to adjust; or discrete steps 0/25/50/75/100%), **horn button**, **boost button**, **track switch lever**, **radio**.
4. In-world **dashboard**: speedometer, fuel gauge, brake fluid gauge, warning lights (one per problem), delivery timer, map/progress bar. Use Label3D or a SubViewport with a Control UI.
5. `DebugPanel` (F1): all TrainState values live, sliders to override.

**Done when:** you can sit at the console, accelerate, brake, and see the gauges respond.

### Milestone 3 — Core loop: fuel, coal, delivery timer
1. Fuel drains proportional to speed. At 0 the train coasts to a stop.
2. **Coal into the furnace**: **already prototyped as throwing** (grab coal from the pile, throw it into the furnace; see section 0). In this milestone, connect the furnace's `add_coal()` to `TrainState.fuel` (+20 per coal). Shovelling (shovel → pile → furnace, optional hold-to-shovel) may be added as a second way, **without removing throwing**.
3. `GameState`: delivery timer counts down; route length is fixed (e.g. 5000 units). Reach the end → **win screen**. Timer hits zero → **lose screen** ("Late delivery").
4. Restart button on end screens.

**Done when:** a full run is possible: drive, refuel, arrive or fail.

### Milestone 4 — Fake movement (cheap but sells it)
1. Outside each window, spawn a strip of poles/sleepers that scroll backward at `TrainState.speed` and wrap around.
2. Subtle camera shake / audio pitch scaled by speed (placeholder audio OK).

**Done when:** speed is readable from inside the train without looking at the gauge.

### Milestone 5 — Event framework
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

### Milestone 7 — Repair events (leave the cockpit)
| Event | Steps | Consequence while unresolved |
|---|---|---|
| **Faulty brakes** | Warning light → find **brake fluid** (cargo cabin) → bring it to **brake reservoir** (mechanical room) → hold interact to pour | `brake_fluid` drains; brake effectiveness drops (makes "slower train" dangerous) |
| **Fire** | Fire spot spawns in a random cabin (orange box + light + particles placeholder), warning light → get **extinguisher** → hold `use_item` while aiming at fire until its health is 0 | Fire grows over time; if it maxes out → game over or heavy penalty; may spread |
| **Gas leak** | Starts silently. Symptom: **hallucinations** (fake hazards appear on the track that aren't real, ghost shapes in cabins, screen distortion). Warning light comes on later. Get **wrench** (cockpit shelf) → find the hissing leak point in the gas chamber (one of several pipes, random) → hold interact to repair | Hallucination intensity increases over time |

Notes:
- **Hallucination system** (`TrainState.hallucinating` / intensity 0–1): spawns fake `HazardMarker`s (which vanish when "reached"), ghost figures in cabins, post-process tint/wobble. Interaction-wise this teaches the player to distrust what they see.
- "Correct tool" rule: interacting with a leak without the wrench shows "You need a wrench".

**Done when:** each repair can be completed end to end and its consequence is felt if ignored.

### Milestone 8 — Cabin encounters
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
