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
| `fix/trough-elseif` | Fix unclosed `Else If` blocks from the P3 trough change (table fails to compile without it) |
| `feat/debug-ball-audit` | Debug-only check that `glf_BIP` matches where the balls are |
| `fix/ball-hold-queue-duplicate-key` | Second ball held in the same device raised an error |
| `fix/ball-hold-return-typo` | Hold returned Empty instead of the unclaimed count |
| `fix/ball-hold-default-capacity` | `BallsToHold` defaults to the hold devices' capacity |
| `fix/ball-device-failed-eject` | Device no longer sticks in its ejecting state when a kicked ball comes back |
| `fix/ball-device-confirm-switch` | Eject target switch only confirms an eject that is in progress |
| `fix/ball-device-eject-empty` | Eject request on an empty device is dropped after 3s instead of ejecting a later ball |
| `fix/multiball-lock-release-count` | Multiball start releases only as many locked balls as it needs |
| `fix/multiball-shoot-again` | Shoot again returns early when nothing needs saving and queues the right number of balls |
| `fix/ball-device-ball-missing` | Holds and `glf_BIP` are corrected when a held or locked ball leaves without being ejected |
| `fix/ball-search-claimed-balls` | Ball search no longer kicks out held and locked balls |
