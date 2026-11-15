# Attract

The attract mode is what the table does when nobody is playing. It follows MPF's built-in attract mode.

`EnableGlfAttract()` creates a mode called **attract** that starts on *reset_complete* and *game_ended* and stops on *game_start*. It returns the mode, so shows, sounds and slides are added to it in the usual way.

## Example

```
With EnableGlfAttract()
    With .ShowPlayer()
        With .EventName("mode_attract_started")
            .Key = "attract_lights"
            .Show = "attract_sweep"
            .Loops = -1
        End With
    End With

    With .Carousel()
        .SelectableItems = Array("title", "high_scores", "credits")
        .NextItemEvents = Array("timer_attract_screens_complete", "s_right_flipper_active")
        .PreviousItemEvents = Array("s_left_flipper_active")
    End With

    With .Timers("attract_screens")
        .StartValue = 0
        .EndValue = 8
        .RestartOnComplete = True
        .StartRunning = True
    End With

    With .SlidePlayer()
        With .EventName("attract_title_highlighted")
            .Slide = "title"
            .Action = "play"
        End With
        With .EventName("attract_high_scores_highlighted")
            .Slide = "high_scores"
            .Action = "play"
        End With
    End With
End With
```

The light show runs for as long as the mode does. The [carousel](carousel.md) steps through three screens, every eight seconds or when a flipper is pressed.

## Notes

- Calling `EnableGlfAttract()` again returns the same mode, so different parts of a table script can each add to it.
- The mode is not a game mode: it is not stopped when a game ends, only by *game_start*.
- GLF's start button posts *request_to_start_game* by itself. Unlike MPF's attract mode, this one plays no part in starting a game, and a table does not need it to be able to start one.
