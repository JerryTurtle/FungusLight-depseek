# G6-002 P0-2 current-source route reproduction and repair

Date: 2026-10-18. Source: current `main` after `174f0b7` (P0-1) plus this
iteration's route/game fixes. This is verification evidence for the local
G6-002 iteration, not a package or gate pass.

## Initial reproduction (current source)

The first current-source run reproduced the historical failure exactly:

- 100.4 s, checks=1 failures=1, stalled at N1-03
- `movement stalled toward (245.9881, 72.22482) ... player=(230.0774, 94.18945) ... path=[(234,94),(238,94),(242,94)]`
- The bot stopped ~27 px from EL1; melee range is 22 px.

This matches the old failure file, not the README claim of `N3-07/N2-07`.

## Route-bot fixes

1. N1-03: path goals at an enemy centre stopped one body radius short
   (22.1–27 px). Added a short direct close-in step for 22–34 px.
2. N2-07: the bot predated EL2's locked charge and fixed water lanes. Added
   charge sidestep, water-safe band, shield and heal use for elites.
3. N3-04: a hit knocked T6 into the 5 px strip above the top wall; the 6 px
   navigation grid cannot anchor there. Added a game-side knockback clamp and
   a reachable ring-approach fallback.
4. Self-cast shield was dropped when the pointer was outside the world because
   the campaign command filter only allowed `dodge/heal`; shield is not a
   targeted spell, so it is now allowed alongside them.
5. Heal attempts were cancelled by still-held movement keys; the bot now
   releases movement before pressing R, and heals during elite/Boss recovery.
6. Boss phase 0 still failed at Boss 1554.25/2200. The spore burst is centred
   exactly on the player, so `(player - hazard_pos)` was zero and the bot stood
   still through all nine warnings. Added a 24-direction probe that chooses
   the clear direction ending farthest outside every spore circle.
7. The Boss sweep is a 72 px, 100-degree sector locked at warning start. A
   34 px sidestep at 56 px remains inside it. Added a sweep-time retreat to
   beyond the radius instead of dodging into the arc.
8. N3-04 E25 on the alternate growth build died with three unused potions
   because the nearest target was a T1 and the old heal paths were elite-only
   or distance-gated. Added a low-HP potion response for ordinary groups.
9. Sidequest route crashed at the final equipment check by reading the removed
   `equipment().relic/token` fields; it now checks the current `owned` map.

## Game-side fixes found by the route work

- `PLAYABLE_AREA` clamp for player/enemy knockback: prevents the 5 px strip
  above the arena wall that the navigation grid cannot reach.
- Self-cast shield is allowed when the pointer is outside the world.
- N4-06 ending marker is no longer a solid portal blocker. It sat between the
  room entrance and the mother at (175,105), blocked the light line at 45 px,
  and split the arena during the final fight. It is a choice marker, not cover.
  `test_g4_campaign` now checks both line of sight and walkability.

## Final results

- Default route: **674.8 s, checks=9, failures=0, deaths=0**, ending restore.
  Boss step N4-06 is 136.4 s; route min HP is 42.
- 8-variant matrix: **8/8 passed** on current source.
  - A_restore 674.8 s, 9 checks
  - B_seal 678.0 s, 9 checks
  - A_alt_seal 706.0 s, 9 checks
  - B_alt_restore 705.5 s, 9 checks
  - C05 674.8 s, 9 checks
  - C06 705.5 s, 9 checks
  - sidequests 687.5 s, 10 checks
  - skip 619.3 s, 9 checks
- Full current suite (all 0 failures):
  campaign 90, g6_release 38, g4_state 48, g4_boss 67, g4_death 5,
  g4_visual 12, save 65, enemies 73, dialogue 175, props 2472, pressure 5,
  route 9, skip 9; plus test_combat 549 and cross-process restart write 2 /
  load 8.

## Evidence

- `G6-002-route-current.json/.log` — preserved first failure at N1-03.
- `G6-002-route-bossfix-preportal.json` — intermediate pass at 879.4 s before
  the ending-marker collision fix. Superseded, kept as history.
- `G6-002-route-default.json/.log` — final default pass.
- `G6-002-route-A_restore.json` etc. — per-variant reports.
- `G6-002-route-matrix.json/.log` — 8/8 summary.
- `G6-002-boss-trace` and `G6-002-combat-trace` were local debugging traces in
  `qa/local/`; they are not committed evidence.
- `G6-002-route-alt-failure.log` and `G6-002-sidequest-prefix-crash.log`
  preserve the two intermediate failures (unused potions at N3-04; stale
  `equipment().relic` access). The per-variant JSON reports were regenerated
  after the fixes and now all show failures=0.

## Limits

- The fastest bot replay is 619.3 s. It is not a human 20-minute play-through;
  `requirement_met=false` is honest and the 20-minute target remains unverified
  by this iteration.
- The `/tmp`-style wrappers used to set variant options were removed after the
  runs; only `route_test.gd` changes are committed.
- The historical `test_campaign.gd` is not in the current suite; its old G3
  assertions still fail/time out and it is not used as a gate here.
- Package, version and `qa/gates.json` still describe G6-001. G6/G7 remain
  `in_progress`; do not claim delivery.
