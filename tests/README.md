# GLF test bed

An automated test table for GLF. It runs inside Visual Pinball, but it has no
playfield parts: the trough, the plunger lane and every ball device are script
objects. Balls go exactly where a test sends them, so nothing depends on
physics and a failed eject or an escaping ball can be produced on demand.

## Running it

```
cd scripts
npm install          # once
npm test
```

`npm test` builds `glf.vbs` from the branch you have checked out, assembles the
table in `tests/.work/glftest`, plays it in Visual Pinball and prints each
scenario as it finishes. It exits with an error if any scenario fails.

Visual Pinball is found through the `VPINBALL` environment variable, or at
`/Applications/VPinballX_BGFX.app/Contents/MacOS/VPinballX_BGFX`.

| Command | What it does |
| --- | --- |
| `npm test` | Run every scenario |
| `npm test -- --only hold_basic,smoke_game` | Run the named scenarios |
| `npm test -- --isolate` | Restart Visual Pinball for each scenario |
| `npm test -- --list` | List scenario names |
| `npm test -- --keep-open` | Leave Visual Pinball running afterwards |
| `npm test -- --glf path/to/glf.vbs` | Test an existing build instead of this checkout |
| `npm test -- --assemble` | Write the table folder and stop |

To show that a fix works, run the same scenario on two branches: it should fail
without the fix and pass with it.

If a run stops early, Visual Pinball's own output is in
`tests/.work/vpx-output.log`.

## How it is put together

| Path | Contents |
| --- | --- |
| `table/` | The table folder Visual Pinball loads: `Table1`, two timers and four empty GLF collections |
| `src/00_globals.vbs` | Globals GLF expects, and the test bed's timings |
| `src/10_virtual_table.vbs` | Balls, trough kickers, ball devices and the ball router |
| `src/20_config.vbs` | The GLF devices and modes under test |
| `src/30_runner.vbs` | The scenario runner, assertions and results file |
| `src/scenarios/` | One file per scenario, run in file-name order |
| `src/90_table.vbs` | Table events |
| `run-tests.js` | The launcher behind `npm test` |

GLF sees an ordinary table. `swTrough1` to `swTrough5` and `Drain` are script
objects that answer the calls GLF makes on trough kickers. Ball device switches
are not table parts at all; the test bed posts their `_active` and `_inactive`
events itself. Each device's eject callback hands the ball to a router, which
delivers it to wherever the scenario has routed that device.

## Writing a scenario

A scenario is a function called once per stage. It returns the number of
milliseconds to wait before the next stage, or `TB_DONE` when it has finished.

```vbs
TB_Scenario "my_test"

Function Scenario_my_test(stage)
    Scenario_my_test = 0
    If stage < TB_PRELUDE_STEPS Then
        Scenario_my_test = TB_OneBallInPlay(stage)    'start a game and plunge
        Exit Function
    End If
    Select Case stage - TB_PRELUDE_STEPS
        Case 0
            TB_Shoot "scoop"
            TB_WaitUntil "ball comes back", "TB_PenCount() = 1", 4000
        Case 1
            TB_CheckCounts "after the scoop", 1
        Case Else
            Scenario_my_test = TB_DONE
    End Select
End Function
```

Name the parameter `stage`, not `step`, and do not read a function's own name
inside the function. Both are legal in Microsoft's VBScript but not safe on
every engine Visual Pinball runs on.

### Making things happen

| Call | Effect |
| --- | --- |
| `TB_StartGame` | Press start |
| `TB_Plunge` | The player plunges the ball |
| `TB_Shoot "device"` | A ball in play goes into that device |
| `TB_DrainBall` | A ball in play drains |
| `TB_Escape "device"` | A ball leaves that device without GLF ejecting it |
| `TB_Post "event"` | Post a GLF event |
| `TB_Route "device", dest` | Where balls ejected from that device go from now on |
| `TB_RouteOnce "device", dest` | The same, for the next eject only |

Destinations are `"pen"` (back in play, the default), `"drain"`,
`"@other_device"`, `"self"` (the ball falls back in) and `"void"` (the ball is
never seen again).

### Checking results

| Call | Passes when |
| --- | --- |
| `TB_Eq label, actual, expected` | The two are equal |
| `TB_True label, condition` | The condition is True |
| `TB_CheckCounts label, n` | Every GLF ball device reports the balls physically in it, and `glf_BIP` is `n` |
| `TB_WaitUntil label, "expression", ms` | The expression becomes True within the time; otherwise the scenario ends as failed |
| `TB_Watch "event"` then `TB_Seen("event")` | Counts how often GLF posts an event |

Useful values: `TB_PenCount()`, `TB_TroughCount()`, `TB_Dev("device").Count()`,
`TB_Dev("device").EjectCount`, `glf_ball_devices("device").Balls`.

`TB_KnownIssueScenario "name", "reason"` registers a scenario for a bug that is
not fixed yet. It is reported, but does not fail the run.

## Devices and modes available to scenarios

| Device | Behaviour |
| --- | --- |
| `plunger` | Default device; manual plunge or auto-launch |
| `scoop` | One ball; ejects an unclaimed ball automatically |
| `saucer` | One ball; keeps an unclaimed ball until `tb_eject_saucer` |
| `lock` | Two balls on two switches |
| `passthru` | Ejects from its own switch-active event |
| `chain_a`, `chain_b` | `chain_a` uses `chain_b`'s switch as its eject target; eject with `tb_eject_chain_a` and `tb_eject_chain_b` |

| Mode | Start event | Contains |
| --- | --- | --- |
| `tb_hold` | `tb_start_hold` | One-ball hold on `scoop`; release with `tb_release_hold` |
| `tb_hold2` | `tb_start_hold2` | Two-ball hold on `lock`; release with `tb_release_hold2` |
| `tb_lock` | `tb_start_lock` | Two-ball multiball lock on `lock` |
| `tb_mb` | `tb_enable_mb` | Two-ball multiball; start it with `tb_start_mb` |

## Limits

- The trough and devices are simulated, so this tests GLF's logic, not kicker
  geometry or physics.
- Scenarios share one Visual Pinball session by default. After each one the
  runner cancels the game and sends every ball home, but a bug can leave GLF in
  a state that affects later scenarios. The runner notes when that happens; use
  `--isolate` or `--only` to confirm a failure on its own.
