# From log to code

Names only: read the current values in the scripts before recommending a
change (they get tuned). `@export` values can also be overridden per node
in the scenes (`enemy.tscn`, `main.tscn`), and the Inspector is the
easiest place for Mike to change them. Check the `.tscn` for overrides.

## Log keys → what sets them

| Log | Comes from |
|---|---|
| `~ state` (squad) | `squadmate.gd` `state` (`State` enum); changes in `_move_intent()`, `order_*()`, `_surprise()`, `_check_pinned()`/`_unpin()`, `_take_cover()`/`_stand_down()`, `_arrive()`, `_tick_idle()` |
| `~ state` (enemy) | `enemy.gd` `mode` (`Mode` enum); `alert()`, `_engage()`, `_surprise()`, `_look_for_targets()` (to SEARCH), `_surprised()` |
| `~ target` | `ai_soldier.gd` `attack_target`. Squad: `order_attack()` (Fire order, or `ordered=false` from `take_hit`, `_surprise`, `_look_for_return_fire`, `_take_window`). Enemy: `_look_for_targets()`, `_take_window()`, `_surprised()` |
| `~ threat` | `enemy.gd` `threat`: who it's fighting (`alert()`, `_look_for_targets()`) |
| `~ alert` | `enemy.gd` `alerted`: `alert()` from `_check_intruders()` (detection circle), `_check_shots()` (hearing), `take_hit()`, `_wake_neighbours()` |
| `~ cover` | first set of `_hide_cover` (surprised/pinned: `ai_soldier.gd _find_hide()`), `_cover` (squad defending a wall), `cover_wall` (enemy: `_take_cover()`, `_dig_in_calm()`) |
| `~ hide` | `ai_soldier.gd _hide_phase` in `_tick_hide()`: GOING → HIDING ⇄ PEEKING |
| `~ spot` | `enemy.gd tactical_spot` from `_best_spot()` every `rethink_s` in ENGAGE |
| `~ blocked` | `ai_soldier.gd holding_fire` = `_line_blocked()` (`LINE_CLEAR_M` + spread) |
| `~ standoff` | `ai_soldier.gd _in_standoff()` / `_shielded()` (class 3 cover anywhere on the muzzle-to-target line, not cover it's at) |
| `~ stop` / `ordered` | `squadmate.gd hold_fire` (Stop order) / `_fire_ordered` (target from a Fire order) |
| `~ reload` | `rifle.gd reloading` (`start_reload()`, `auto_reload`) |
| `F` / `X` | `rifle.gd fire()` → `bullet.gd` (`_ready`, hit / `_hit_ground` / spent). Range `-`: within the rifle's accurate range, flies its full `LIFETIME_S` |
| `H` | `soldier.gd take_hit()`; damage is `rifle.gd damage` |
| `O` | `squadmate.gd order_*()`; callers in `command.gd` (player), `insertion.gd` (drop-off), `squadmate.gd _cover_lost()` (respot) |

## Behaviour → tunables

**Spotting and waking (enemy):** `sight_m`, `hearing_m`, `detection_radius_m`
and `_check_intruders()` (calm enemies don't see over sandbags), `_wake_neighbours()`,
`reaction_s` (delay before the first shot at a new target).

**Choosing where to fight (enemy, ENGAGE):** `_best_spot()` scoring:
`min_range_m`, `max_range_m`, `flank_weight`, `spacing_m`, `SPACING_WEIGHT`,
`COVER_WEIGHT`, `SPOT_RINGS`, `SPOT_ANGLES`, `SPOT_KEEP_BONUS`, `rethink_s`;
`_route()` and `ARC_STEP_DEG` for swinging round; `JOG_FROM_M`, `JOG_SPEED`.
Dodging: `dodge_m`, `DODGE_COOLDOWN_S`, `_aimed_at_by()`.

**Cover (enemy):** `cover_seek_m`, `COVER_REACH_M`, `COVER_SPOT_M`,
`FLANK_GRACE_S`, `_take_cover()`, `_hold_cover()`, `_in_cover()`; calm
dig-in `_dig_in_calm()`.

**Losing contact (enemy):** `lose_contact_s` → SEARCH for `search_s`
(`SEARCH_LOOK_S`) → RETURN to post.

**Shooting (both):** `SHOT_GAP_S`, `LINED_UP_DEG`, `LINE_CLEAR_M`
(ai_soldier.gd); enemy bursts `burst_shots`, `burst_pause_s`;
`moving_spread_deg` (enemy), `SHOT_SPREAD_DEG` (squad); rifle
`aim_accurate_m`, `aim_falloff_m`, `fire_interval_s`, `damage`.

**Standoff (both):** `_shielded()` (any class 3 cover on the line protects, Mike 2026-11-01), `STANDOFF_FOE_M`, `STANDOFF_CHECK_S`;
`_take_window()` per side; enemy `_look_for_targets()` weighs dug-in
hostiles (`_shielded()`) ×3. `DUG_IN_M` / `_dug_in()` now only feed PINNED. `PEEK_RIFLE_M`: a peek spot needs a clear view from either side of the body (the muzzle). No hysteresis yet: a window that opens and shuts can switch
targets every check.

**Surprised (both):** trigger `NEAR_MISS_M` (`_near_miss()`) or a hit
while idle/calm; cover search `HIDE_SEARCH_M`, `HIDE_TOWARD_M`,
`HIDE_MIN_WIDTH_M`, `HIDE_GAP_M`, `HIDE_ROOM_M`, `HIDE_COVERED_M`,
`HIDE_RUN_SPEED`; flanked `HIDE_FLANK_S`; peeking `HIDE_S`, `PEEK_STEP_M`,
`PEEK_MAX_M`, `PEEK_S`, `PEEK_SHOTS`.

**Pinned (squad):** `PIN_CHECK_S`, `PIN_ENEMY_M`, `_outnumbered()`,
`_pinned_down()`, `_tick_pinned()`.

**Squad return fire and defending:** `RETURN_FIRE_M`,
`RETURN_FIRE_CHECK_S`, `DEFEND_FIRE_M`, `DEFEND_SCAN_DEG`, `RESPOT_M`,
`DEFEND_ARRIVE_M`.

**Moving and getting stuck (both):** `ai_soldier.gd` `STUCK_TIME_S`,
`PROGRESS_M`, `DETOUR_SWAP_S`, `AVOID_M`, `LOOK_AHEAD_M`, `SKIRT_M`,
`DETOUR_LIMIT_S`, `_avoid_obstacles()`, `_steer()`.

**Ammo (both):** `AMMO_SEARCH_M`, `AMMO_TOPUP_M`, `_ammo_run()`, `_may_top_up()`.

**Cover classes:** `cover.gd LIGHT_MAX`, `MEDIUM_MAX`; each object's
`cover_stop_chance()` (`partial_cover.gd hit_chance`, `sandbags.gd
through_chance`, `crate.gd`).
