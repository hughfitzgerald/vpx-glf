# Credits

The credits mode handles coin play. It follows MPF's built-in credits mode.

`EnableGlfCredits()` creates a mode called **credits** that runs from *reset_complete*. On free play it only keeps the credit strings up to date. On credit play it:

- counts the money put in through the coin switches and turns it into credits,
- refuses to start a game or add a player when there is no credit,
- takes one credit for each player who joins.

## Example

```
With EnableGlfCredits()
    .FreePlay = False
    .MaxCredits = 12
    .ServiceCreditsSwitch = "s_service_credit"

    With .Switches("s_add_credit_key")
        .Value = 0.25
    End With
    With .Switches("s_add_credit_key2")
        .Value = 1
    End With

    .AddPricingTier 0.50, 1
    .AddPricingTier 2, 5

    With .Events("match_has_match")
        .Credits = 1
    End With
End With
```

A game costs 50 cents. Two dollars buys five credits. Winning the [match](match.md) awards a credit. `s_add_credit_key` and `s_add_credit_key2` are the switches GLF posts for the two *Add Credit* keys.

## Settings

### FreePlay
```Boolean``` Default: True

Start on free play. The events below switch between free play and credit play while the table is running.

### MaxCredits
```Number``` Default: 0

The most credits the machine holds. `0` means no limit.

### Switches(switch)

A coin switch. `Value` is the money each closure is worth (default 0.25), `SwitchType` a label such as `money` or `token`, and `Label` a display name.

### AddPricingTier price, credits

What a sum of money buys. Add tiers from the cheapest up. The first tier must buy exactly one credit; later tiers give a discount. Without tiers one credit costs 1.

### Events(event)

An event that awards credits directly, such as a replay. `Credits` is how many (default 0.25) and `EventType` a label (default `replay`). These credits do not count toward the pricing tiers.

### ServiceCreditsSwitch
```String or Array``` Default: None

Switches that add one credit each.

### FractionalCreditExpirationTime
```Number``` Default: 0

Milliseconds after the last coin before part-credits are cleared. `0` keeps them.

### CreditExpirationTime
```Number``` Default: 0

Milliseconds after the last coin before all credits are cleared. `0` keeps them. Starting a game stops both timers.

### PersistCredits
```Boolean``` Default: True

Keep the credits when the table is closed.

### FreePlayString and CreditsString
```String``` Default: `FREE PLAY`, `CREDITS`

Text used in the `credits_string` machine variable.

### ResetCreditsEvents
```Array``` Default: `credits_reset`, `factory_reset`

Events that clear all credits.

## Events the mode listens for

| Event | |
| --- | --- |
| `enable_free_play` | Switch to free play |
| `enable_credit_play` | Switch to credit play |
| `toggle_credit_play` | Switch to the other one |
| `slam_tilt` | Clear all credits |

## Events the mode posts

| Event | |
| --- | --- |
| `credits_added` | Credits, or part of one, were added |
| `max_credits_reached` | More credits were added than the machine holds |
| `not_enough_credits` | A game or a player was refused |
| `enabling_free_play` | Free play was switched on |
| `enabling_credit_play` | Credit play was switched on |

## Machine variables

| Variable | |
| --- | --- |
| `credits_string` | For display: `CREDITS 2 1/2`, or `FREE PLAY` |
| `credits_value` | The number alone: `2 1/2` |
| `credits_whole_num` | `2` |
| `credits_numerator` | `1` |
| `credits_denominator` | `2` |
| `credit_units` | The internal count. A credit is `credits_denominator` units |
| `free_play` | 1 on free play, 0 on credit play |
| `price_per_game_raw_<n>`, `price_per_game_string_<n>` | The price and a display string for pricing tier `n`, counted from 0 |

## Differences from MPF

The earnings audits and the coin inhibit output are not part of this mode. Money that would take the machine over `MaxCredits` is capped at `MaxCredits`.
