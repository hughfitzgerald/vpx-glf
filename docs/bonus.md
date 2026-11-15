# Bonus

The bonus mode counts up an end-of-ball bonus. It follows MPF's built-in bonus mode.

`EnableGlfBonus()` creates a mode called **bonus** that starts on *ball_ending* and holds the end of the ball until the bonus has been counted. It steps through the bonus entries one at a time, then the subtotal, the multiplier and the total, and adds the total to the player's score. Each step posts *bonus_entry*, which is what slides, shows and sounds hang on.

If the game is tilted the bonus is skipped.

## Example

```
With EnableGlfBonus()
    .DisplayDelayMs = 1500
    .HurryUpDelayMs = 200
    .HurryUpEvent = "flipper_cancel"

    With .Entries("ramps")
        .Score = 5000
        .PlayerScoreEntry = "ramps_made"
        .ResetPlayerScoreEntry = True
    End With
    With .Entries("modes")
        .Score = 25000
        .PlayerScoreEntry = "modes_completed"
    End With

    With .Mode.SlidePlayer()
        With .EventName("bonus_entry")
            .Slide = "bonus"
            .Action = "play"
        End With
    End With
End With
```

Each ramp made is worth 5,000 and the count goes back to zero for the next ball. Each completed mode is worth 25,000 and the count is kept. `.Mode` is the bonus mode itself, for adding players to it.

## Settings

### Entries(name)

One bonus entry. Entries are counted in the order they are first named. The names `subtotal`, `multiplier` and `total` are reserved.

| Setting | Type | Default | |
| --- | --- | --- | --- |
| `Score` | Number or dynamic value | 0 | Points per hit |
| `PlayerScoreEntry` | String | None | Player variable holding the number of hits. Without one the entry scores `Score` once |
| `ResetPlayerScoreEntry` | Boolean | False | Set the player variable back to 0 after it is counted |
| `SkipIfZero` | Boolean | True | Leave the entry out when it is worth nothing |
| `SkipIfNegative` | Boolean | False | Leave the entry out when it is worth less than nothing |
| `Text` | String | None | Passed along in *bonus_entry* |

### DisplayDelayMs
```Number``` Default: 2000

Milliseconds between steps.

### HurryUpDelayMs
```Number``` Default: 500

Milliseconds between steps once the player has hurried the bonus along.

### HurryUpEvent
```String``` Default: `flipper_cancel`

Event that switches to the hurry-up delay and moves to the next step at once. GLF does not post *flipper_cancel* itself; a [combo switch](combo-switches.md) on both flippers is the usual source.

### EndBonusEvent
```String``` Default: None

When set, the mode waits for this event after the total before it ends. Without it the mode ends one delay after the total.

### KeepMultiplier
```Boolean``` Default: False

Keep the player's `bonus_multiplier` for the next ball. Otherwise it goes back to 1 when the bonus ends.

### RoundingValue and RoundingDirection
```Number``` Default: 0, ```String``` Default: `up`

Round each entry's score to a multiple of `RoundingValue`, `up` or `down`. `0` turns rounding off.

## Player variables

### bonus_multiplier

The bonus is multiplied by this. When it is 1, or not set, the subtotal and multiplier steps are skipped.

## Events

### bonus_start

The bonus is starting. Not posted when the game is tilted.

### bonus_entry

Posted for each step.

| Argument | |
| --- | --- |
| `entry` | The entry's name, or `subtotal`, `multiplier` or `total` |
| `score` | The entry's score. For `multiplier` it is the multiplier itself |
| `bonus_score` | The running total, for entries |
| `hits` | The value of the player variable, for entries |
| `text` | The entry's text |
