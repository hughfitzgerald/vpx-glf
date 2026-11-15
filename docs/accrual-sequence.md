# Accruals and Sequences

Accruals and sequences are logic blocks, like the [counter](counter.md). Each tracks a list of steps and posts an event when every step is done.

- An **accrual** lets the steps be completed in any order.
- A **sequence** only advances on the event for its next step.

Both follow the MPF devices of the same name.

## Example

```
With CreateGlfMode("base", 100)
    .StartEvents = Array("ball_started")
    .StopEvents = Array("ball_ended")

    With .Accruals("light_lock")
        .Events = Array("s_left_ramp_active", "s_right_ramp_active", "s_scoop_active, s_saucer_active")
        .EventsWhenComplete = Array("lock_lit")
        .PersistState = True
    End With

    With .Sequences("skill_combo")
        .Events = Array("s_left_orbit_active", "s_right_ramp_active", "s_scoop_active")
        .ResetEvents = Array("ball_started")
    End With
End With
```

The accrual **light_lock** posts *lock_lit* once both ramps and either the scoop or the saucer have been hit, in any order. The sequence **skill_combo** posts *logicblock_skill_combo_complete* once the left orbit, right ramp and scoop have been hit in that order.

## Required Settings

### Events
```Array```

One entry per step. An entry is an event name, several event names separated by commas, or an array of event names. When a step has several events, any one of them completes it.

## Optional Settings

### Enable Events
```Array``` Default: None

Events that enable the block. A block with no enable events starts enabled when its mode starts.

### Disable Events
```Array``` Default: None

Events that disable the block. A disabled block ignores its step events.

### Reset Events
```Array``` Default: None

Events that clear the block's progress.

### Restart Events
```Array``` Default: None

Events that reset the block and enable it.

### Advance Random Events
```Array``` Default: None

Accruals only. Events that complete one of the steps still open, picked at random.

### Events When Hit
```Array``` Default: `logicblock_<name>_hit`

Events posted each time a step is completed.

### Events When Complete
```Array``` Default: `logicblock_<name>_complete`

Events posted when every step is done.

### Reset On Complete
```Boolean``` Default: True

Clear the progress once the block completes.

### Disable On Complete
```Boolean``` Default: True

Disable the block once it completes.

### Persist State
```Boolean``` Default: False

Keep the block's progress, and whether it is enabled, per player. Without this the block starts again each time its mode starts.

### Start Enabled
```Boolean``` Default: True when there are no enable events

Whether the block is enabled when its mode starts.

### Logic Block Timeout
```Number``` Default: 0

Milliseconds after which the block resets itself. The timer starts when the block is enabled or reset, and stops when it completes. `0` turns it off.

## Events

### logicblock_*name*_hit

A step was completed. `step` is the zero-based step for an accrual, and the number of steps done so far for a sequence.

### logicblock_*name*_complete

Every step is done.

### logicblock_*name*_updated

The block changed. `value` is an array of True/False per step for an accrual and the number of steps done for a sequence. `enabled` says whether the block is enabled.

### *name*_timeout

The logic block timeout ran out and the block was reset.

## Reading a block from script

`glf_accruals("light_lock").GetValue("completed_steps")` returns how many steps are done. `GetValue` also takes `"value"`, `"enabled"` and `"completed"`. Sequences are in `glf_sequences`.
