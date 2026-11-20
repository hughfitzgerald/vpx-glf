# How this fork is organised

This file lives only on the `starshollow` branch. It is not meant for upstream.

## Branches

| Branch | What it is | Rule |
| --- | --- | --- |
| `main` | Exact copy of `mpcarr/vpx-glf` main | Never commit here. Only sync it. |
| `fix/...`, `feat/...` | One change each, started from `main` | Candidates for upstream pull requests |
| `local/...` | One change each that upstream will not want | Same shape, never opened as a pull request |
| `starshollow` | `main` plus every branch above, merged | `glf.vbs` for Stars Hollow Showdown is built from here |

The one habit that keeps pull requests easy: **start every change on its own
branch from `main`, then merge that branch into `starshollow`.** Never the
other way round.

## One-time setup on a new computer

```
git clone https://github.com/hughfitzgerald/vpx-glf
cd vpx-glf
git remote add upstream https://github.com/mpcarr/vpx-glf
cd scripts && npm install
```

Clone it next to the `starshollow` folder so the build script there finds it.

## Make a change

```
git checkout main
git checkout -b fix/short-description      # or feat/... or local/...
# edit files under scripts/src, never scripts/vpx-glf.vbs
cd scripts && npx grunt concat && cd ..    # rebuilds scripts/vpx-glf.vbs
git add scripts/src scripts/vpx-glf.vbs
git commit -m "What changed and why"
git push -u origin fix/short-description
```

Then bring it into the table build:

```
git checkout starshollow
git merge fix/short-description
```

If git reports a conflict in `scripts/vpx-glf.vbs`, do not edit it by hand.
Rebuild it and continue:

```
cd scripts && npx grunt concat && cd ..
git add scripts/vpx-glf.vbs
git commit
```

A conflict in a file under `scripts/src` is a real one and needs reading.

## Update Stars Hollow Showdown

From `starshollow/scripts`:

```
npm run update-glf
```

That builds this fork and writes `src/glf/glf.vbs` with a first line naming the
branch and commit it came from. Never edit that `glf.vbs` directly.

## Pick up new upstream work

```
git checkout main
git pull upstream main
git push origin main
git checkout starshollow
git merge main
```

## Send a change upstream

Open a pull request on GitHub from the `fix/...` or `feat/...` branch to
`mpcarr/vpx-glf` main. If the branch is old, first bring it up to date:

```
git checkout fix/short-description
git merge main
cd scripts && npx grunt concat && cd ..    # if vpx-glf.vbs conflicted
```

## Made a change directly on `starshollow` by mistake?

Copy that one commit onto a fresh branch:

```
git log --oneline            # find the commit id
git checkout main
git checkout -b fix/short-description
git cherry-pick <commit id>
```

## Current branches not yet upstream

| Branch | Change |
| --- | --- |
| `feat/counter-mpf-parity` | Counter rewritten to follow MPF's counter logic block |
| `feat/sound-priority` | Priority-based cut-off on sound buses, with mode priority |
| `feat/drop-target-getvalue` | `state` / `complete` placeholder values on drop targets |
| `fix/sound-stop-timer` | Clear the pending stop timer when a sound is stopped |
| `feat/debug-ball-audit` | Debug-only check that `glf_BIP` matches where the balls are |
| `fix/ball-hold-queue-duplicate-key` | Second ball held in the same device raised an error |
| `fix/ball-hold-return-typo` | Hold returned Empty instead of the unclaimed count |
| `fix/ball-hold-default-capacity` | `BallsToHold` defaults to the hold devices' capacity |
| `fix/ball-device-eject-empty` | An eject request waiting on an empty device is dropped after `WaitingEjectTimeout` (3s) instead of ejecting a later ball |
| `fix/ball-device-eject-all-settling` | `EjectAll` includes a ball still inside its entrance settling time, so a kicker that ejects from its own switch event works |
| `feat/test-bed` | Automated test table under `tests/`; run it with `npm test` in `scripts/` (see `tests/README.md`). `npm run test:unit` runs upstream's ball device unit tests without Windows |
| `fix/multiball-shoot-again` | Shoot again returns early when nothing needs saving and queues the right number of balls |
| `fix/ball-device-ball-missing` | Holds and `glf_BIP` are corrected when a held or locked ball goes missing or leaves without being ejected |
| `fix/ball-search-claimed-balls` | Ball search no longer kicks out held and locked balls (builds on `fix/ball-device-ball-missing`) |
| `fix/ball-hold-release-count` | A hold's count stays right when its device has already lost a ball |
| `fix/ball-search-empty-categories` | Ball search finishes on tables with no auto-fire devices, drop targets or diverters |
| `fix/drain-after-ball-end` | A ball that drains after the last ball in play has drained no longer ends the ball twice |
| `fix/random-event-player` | Random event player `ForceAll` plays every valid event once per round and `ForceDifferent` never repeats the last event unless it is the only one; already on upstream's current `main` |
| `fix/ball-device-tilt` | Ball devices follow their own switches during a tilt and eject any ball that arrives |
| `feat/ball-audit-extra-balls` | `glf_ball_audit_extra_balls` lets a table tell the ball audit about balls that did not come from the trough (builds on `feat/debug-ball-audit`) |
| `feat/logic-blocks` | Accruals and sequences (`.Accruals(name)`, `.Sequences(name)` on a mode) |
| `feat/bonus-mode` | `EnableGlfBonus()`: the end-of-ball bonus mode |
| `feat/game-players` | `MaxPlayers`, the `player_add_request` relay, player turn events, `ball_starting` as a queue event that holds the ball; player and trough code de-duplicated |
| `feat/credits` | `EnableGlfCredits()`: coin play (builds on `feat/game-players`) |
| `feat/kickbacks` | `CreateGlfKickback(name)` |
| `feat/carousel` | `.Carousel()` on a mode |
| `feat/attract` | `EnableGlfAttract()` (builds on `feat/carousel`) |
| `feat/match` | `EnableGlfMatch()`: the end-of-game match |
| `fix/ball-number-at-turn-start` | The `ball` player variable goes up when the next turn starts, as in MPF, and the game ends when the last player finishes ball `balls_per_game` (builds on `feat/game-players`) |

## Upstream's ball device rewrite (November 2026)

Upstream replaced the ball device (mpcarr/vpx-glf#24). This fork now uses that
device. The branches above that touch the device (`fix/ball-hold-default-capacity`,
`fix/ball-device-eject-empty`, `fix/ball-device-eject-all-settling`,
`fix/ball-device-ball-missing`, `fix/ball-search-claimed-balls`,
`fix/ball-device-tilt`) and `feat/test-bed` have had `main` merged in and their
change re-applied on the new device.

These branches are covered by upstream's rewrite and are no longer merged or
needed. They can be deleted:

| Branch | Covered by |
| --- | --- |
| `fix/trough-elseif` | Upstream fixed the `Else If` blocks |
| `fix/ball-device-failed-eject` | A returning ball is recognised and the eject retried |
| `fix/ball-device-confirm-switch` | Confirmation needs the ejected ball itself and an attempt in progress |
| `fix/ball-device-ball-shift` | Balls are counted by identity across all switches |
| `fix/ball-device-overlapping-ejects` | Eject requests are queued |
| `fix/multiball-lock-release-count` | `EjectAvailableBalls` |
| `fix/queue-event-wait` | Upstream consumes `wait_for` the same way |

The other branches still start from the older `main`. Merge `main` into one
before opening a pull request from it.
