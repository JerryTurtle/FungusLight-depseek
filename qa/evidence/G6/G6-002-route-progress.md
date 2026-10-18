# G6-002 P0-2 route reproduction and bot adaptation

Date: 2026-10-18. Source: current `main` after `174f0b7` (P0-1) plus this
iteration's uncommitted fixes. This is verification evidence, not a gate pass.

## Initial reproduction (current source)

The first current-source run reproduced the historical failure exactly:

- 100.4 s, checks=1 failures=1, died/stalled at N1-03
- `movement stalled toward (245.9881, 72.22482) reason=combat-approach ... player=(230.0774, 94.18945) ... path=[(234,94),(238,94),(242,94)]`
- The bot stopped ~27 px from EL1; melee range is 22 px.

This matches the failure file in commit `0206fd8`, not the README's claim of
`N3-07/N2-07`.

## Sequential findings and fixes

1. N1-03: bot path goal at the enemy centre stopped one body radius short
   (22.1–27 px), so it never entered the 22 px melee range. Added a short
   direct close-in step for 22–34 px.
2. N2-07: died to EL2 (hp 16 left) because the bot predated EL2's locked
   charge and fixed water lanes. Added charge sidestep, water-safe band, and
   shield/heal use for elites.
3. N3-04: a hit knocked T6 into the 5 px strip above the top wall; the 6 px
   navigation grid cannot anchor there. Added:
   - game-side knockback clamp to `PLAYABLE_AREA` (player and enemies);
   - a reachable ring-approach fallback in the bot.
4. Self-cast shield was dropped when the mouse pointer was outside the world
   because the campaign command filter only allowed `dodge/heal`; shield is
   not a targeted spell, so it is now allowed alongside them.
5. Heal attempts were cancelled by still-held movement keys; the bot now
   releases movement before pressing R, and heals during elite/Boss recovery
   windows.

## Current status

The route now reaches N4-06, but still dies in Boss phase 1:

- 583.6 s, checks=1 failures=1, deaths=1
- `player died at step N4-06 pending=E30 hp=0 enemies=[["BOSS",(175,105),1554.25]]`

This is the remaining failure: a route-bot Boss strategy/balance problem, not
yet demonstrated as a game defect. The default route does not pass, so the
8-variant matrix was not run.

## Tests that do pass after the game-side changes

- test_combat 549/0
- test_enemies 73/0
- test_g4_campaign 88/0
- test_g6_release 38/0
- test_g4 48/0
- test_g4_boss 67/0
- test_g4_death 5/0
- test_save 65/0
