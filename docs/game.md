# Game and Players

Settings and events for the game as a whole: how many balls, how many players, and what is posted as players join and turns pass.

## Settings

Set these in your device configuration:

```
With GlfGameSettings()
    .BallsPerGame = 3
    .MaxPlayers = 4
End With
```

### BallsPerGame
```Number or dynamic value``` Default: 3

Balls each player gets. The *Balls Per Game* table option overrides it.

### MaxPlayers
```Number or dynamic value``` Default: 4

The most players one game can have.

## Adding players

The start button adds a player while a game is running. A player can join while there is room and the game is still on ball 1.

Before a player is added GLF posts the **player_add_request** relay. A listener that returns `False` refuses the player; the [credits mode](credits.md) does this when there are not enough credits. A listener on a relay must return a value: return `args(1)` to leave the request as it is.

## Events

| Event | When | Arguments |
| --- | --- | --- |
| `player_add_request` | Relay, before a player is added | |
| `player_will_add` | A player is about to be added | `number` |
| `player_added` | A player was added | `num`, `number` |
| `multiplayer_game` | The second player was added | |
| `player_turn_will_start` | A player's turn is about to start | `number` |
| `player_turn_starting` | Queue event, before the turn starts | `number` |
| `player_turn_started` | The turn has started | `number` |
| `ball_will_start` | A new ball is about to be served | `ball`, `player`, `balls_remaining` |
| `ball_starting` | Queue event. The ball is served once every listener is done, so a mode that starts on it with `UseWaitQueue` holds the ball back | `ball`, `player`, `balls_remaining` |
| `ball_started` | The ball has been served | |
| `single_player_ball_started` | With `ball_started`, in a one player game | |
| `multi_player_ball_started` | With `ball_started`, in a game with more players | |
| `player_<number>_ball_started` | With `multi_player_ball_started` | |
| `player_turn_will_end` | A player's turn is about to end | `number` |
| `player_turn_ending` | Queue event, before the turn ends | `number` |
| `player_turn_ended` | The turn has ended | `number` |

`number` counts players from 1. The turn events are not posted for an extra ball, because the turn carries on. The current player only changes after the turn-end events have been handled, so their listeners still see the player whose turn it was.

## Conditions

`game.max_players` and `game.num_players` can be used in conditions, alongside `game.balls_per_game`, `game.balls_in_play` and `game.tilted`.
