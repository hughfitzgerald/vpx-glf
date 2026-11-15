# Match

The match mode runs the end-of-game number match. It follows MPF's built-in match mode.

`EnableGlfMatch()` creates a mode called **match** that starts on *game_ending* and holds the end of the game. Each player's match number is the last two digits of their score. The mode draws a winning number and posts *match_has_match* or *match_no_match*. Both are queue events: the mode ends once every listener is done, so a show or slide that blocks the queue holds the mode open for as long as it runs.

What a match is worth is up to the table. To give a credit, add the event to the [credits mode](credits.md).

## Example

```
With EnableGlfMatch()
    .MatchPercentage = 7

    With .Mode.SlidePlayer()
        With .EventName("match_no_match")
            .Slide = "match"
            .Action = "play"
        End With
        With .EventName("match_has_match")
            .Slide = "match_won"
            .Action = "play"
        End With
    End With
End With

With EnableGlfCredits()
    With .Events("match_has_match")
        .Credits = 1
    End With
End With
```

## Settings

### MatchPercentage
```Number``` Default: 10

The chance, in percent, that the winning number is one of the players' numbers.

### NonMatchNumberStep
```Number``` Default: 10

When nobody wins, the winning number is drawn from 0, step, 2 x step and so on, leaving out the players' own numbers. Scores usually end in 0, so the default draws from 00, 10, 20 ... 90.

### DisplayTimeMs
```Number``` Default: 0

Milliseconds the mode stays up after every listener of the result is done. Use it for a fixed pause when nothing blocks the queue.

### EndMatchEvent
```String``` Default: None

An event that ends the mode at once, whatever is still waiting.

## Events

### match_has_match and match_no_match

One or the other is posted once per game, as a queue event.

| Argument | |
| --- | --- |
| `winner_number` | The winning number |
| `winners` | How many players matched it |
| `match_number0`, `match_number1` ... | Each player's number, counted from 0. Empty for players not in the game |
| `match_number0_won`, `match_number1_won` ... | Whether that player matched |

## Machine variables

### match_number

The winning number of the last match.

## Differences from MPF

`DisplayTimeMs` and `EndMatchEvent` are GLF additions. MPF raises the match percentage to the power of the number of different player numbers; here the percentage is used as given. High scores start on *game_ending* too and run first, because that mode has the higher priority.
