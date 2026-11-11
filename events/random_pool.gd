class_name RandomPool
extends Resource

## The events that happen at random during a run, and how often. EventManager rolls the dice
## every `check_interval` seconds: each entry gets its own chance, at most one event starts
## per roll. Tune these numbers to balance the run.

@export var entries: Array[RandomEntry] = []
## Chances of events inside the train (the faults) are multiplied by this much at the end of
## the route, scaling up from 1 at the start.
@export var fault_multiplier_at_end := 3.0
## Same for events out on the track.
@export var track_multiplier_at_end := 2.0
## Seconds between rolls.
@export var check_interval := 15.0
## No random events in the first seconds of a run.
@export var start_delay := 20.0
## At least this many seconds between two random events.
@export var min_gap := 8.0
## Events out on the track need the train to be moving at least this fast to start.
@export var min_track_speed := 5.0
## At most this many events on the track at once...
@export var max_live_outside := 1
## ...and this many inside the train.
@export var max_live_inside := 2
