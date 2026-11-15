# Kickback

A kickback fires a ball back into play when its switch is hit, usually from an outlane. It only fires while it is enabled, so the table's rules decide when the kickback is lit. It follows MPF's kickback device.

## Example

```
With CreateGlfKickback("left_outlane")
    .Switch = "s_left_outlane"
    .ActionCallback = "LeftKickbackAction"
    .EnableEvents = Array("light_kickback")
    .DisableEvents = Array("kickback_left_outlane_fired", "ball_will_end")
End With

Sub LeftKickbackAction(args)
    If args(0) = 1 Then
        KickbackPlunger.Fire
    End If
End Sub
```

The kickback is lit by *light_kickback* and goes out again as soon as it has fired once.

## Settings

### Switch
```String```

The switch that fires the kickback.

### ActionCallback
```String```

Name of a Sub that moves the ball. It is called with `Array(1, ball)` when the kickback fires and `Array(0, ball)` when the ball has left the switch.

### EnableEvents
```Array``` Default: None

Events that enable the kickback. A kickback starts disabled.

### DisableEvents
```Array``` Default: `ball_will_end`, `service_mode_entered`

Events that disable the kickback. Setting this replaces the defaults.

### EnabledCallback and DisabledCallback
```String``` Default: None

Subs called when the kickback is enabled and disabled, for a light or a post.

## Events

| Event | |
| --- | --- |
| `kickback_<name>_fired` | The kickback fired a ball |
| `kickback_<name>_enabled` | The kickback was enabled |
| `kickback_<name>_disabled` | The kickback was disabled |

## Reading a kickback from script

`glf_kickbacks("left_outlane").Enabled` is True while the kickback is enabled.
