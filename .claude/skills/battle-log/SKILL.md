---
name: battle-log
description: Read and assess a BattleSquares battle log (logs/battle_log.txt, recorded in game with F9 or the BATTLE LOG button) and explain how the enemy or squadmate AI should be adjusted. Use when Mike gives a battle log, says he's logged a test or fight, asks about a unit by its debug number ("why did 4 do that?"), or asks what the AI did wrong or how to tune it.
---

# Assessing a battle log

Mike plays a test in the editor with the battle log on (F9 or the button
at the top left; `scripts/battle_log.gd`). He then hands over the file and
wants to know what the AI did, what went wrong, and what to change. The
log is a record of play, not a test that passes or fails: your job is to
compare what happened with what the AI is *meant* to do, and say where
the gap is, with a concrete change.

## 1. Find the log

- Default: `logs/battle_log.txt` in the project (written when running from
  the editor). From an exported build: `%APPDATA%\Godot\app_userdata\<project>\battle_log.txt`.
- If Mike gives another path, use that. One log per file; a new log wipes
  the last, so if he's describing an earlier run that's been overwritten,
  say so.
- If it's missing or only a header, he probably didn't start it (F9) or
  stopped too soon.

## 2. Read the summary first, then the parts that matter

The file explains itself: its `#` header lists every line code and key.
Read the header if you don't remember the format. Then summarise:

```bash
awk -f .claude/skills/battle-log/summarize.awk logs/battle_log.txt
```

This gives you:
- each square's shots and where they went (foe, own side, into cover,
  ground or spent), hits taken, when it died, seconds in standoff and
  blocked, target changes, orders and peeks;
- time spent in each state;
- a "Looks wrong" list: friendly fire, shots that hit nobody, shots into
  class 3 cover, alerted enemies that never fired, surprised units that
  never got into cover, units that stood still while meant to move,
  target flip-flopping;
- a timeline of state, target, cover, alert, order and death events.

Use `-v timeline=0` for a long log, then pull out the time windows and
units that matter:

```bash
awk -F'\t' '$1>=12 && $1<=18' logs/battle_log.txt                  # a time window
awk -F'\t' '$3=="5" || $4=="5"' logs/battle_log.txt                # everything about unit 5 (incl. shots at it)
awk -F'\t' '$2=="~" && $3=="5"' logs/battle_log.txt                # just its decisions
awk -F'\t' '$2=="F" && $4=="5" {print $1, $3, $5}' logs/battle_log.txt  # its shots and targets
```

Join F to X by shot number (`s12`) to see where a shot went. Positions
are metres. Use the `M` lines for the cover nearby (centre, size, class)
to judge whether a square was really in cover, in the open, or flanked:
work out geometry (distance, which side of the cover it's on, line
between shooter and target) rather than guessing.

Don't read the whole file into context if it's large (over about 3000
lines): summarise, then pull out windows.

## 3. Compare with what the AI is meant to do

The intended behaviour is written in the doc comments at the top of the
AI scripts. These are the source of truth, and they change, so **read the
current ones** rather than going from memory:

- `scripts/ai_soldier.gd`: shared by both sides: shooting, holding fire
  for someone in the line, standoff (hold fire until there's a window),
  surprised (cover-seeking, peeking), ammo runs.
- `scripts/enemy.gd`: enemy modes (CALM, ENGAGE, SEARCH, RETURN,
  SURPRISED), spotting, fighting positions, cover, dodging, bursts.
- `scripts/squadmate.gd`: squadmate states and orders, defending a wall,
  building, PINNED.
- `scripts/cover.gd`: cover classes.

[ai-reference.md](ai-reference.md) maps each log key to the code that
sets it, and lists which tunables govern which behaviour. Read it when
you need to go from "this looked wrong" to "this constant or function".

Mike has set rules along the way (orders override the AI, a Fire order
fires even when pinned, and so on). The DEVLOG's dated entries record
them. When a behaviour breaks one of his rules, say so plainly: that's a
bug, not tuning.

## 4. Report

Write for Mike: he's new to Godot, playtests while you work, and wants
plain, short answers. Structure:

1. **What happened**: a few lines on the fight: how long, who was in it,
   who won, the key moments with times (so he can match them to what he
   saw).
2. **What the AI got wrong**: each issue with the evidence (unit numbers,
   times, the lines that show it), why it happened in the code
   (function, constant), and whether it's a bug against his rules or a
   judgement call.
3. **What to change**: for each issue, the concrete change: which
   constant and to what, or what logic to add, and the trade-off. Put the
   most important first. Give a recommendation, not a menu.
4. **What looked right**: briefly, so he knows what not to touch.

Unit numbers are the ones Mike sees in game in debug mode (Q shows each
square's number over it): the player is 0, everyone else 1, 2... in the
order they turned up in the level. A new log doesn't renumber, so a
missing number is a square that died before the log started. When he asks
"why did 4 do that?", 4 is the log's unit 4: pull its lines (and shots at
it) around the moment he means. Use his numbers in your answer, adding
side and node name where it helps (e.g. "4 (squad, Squadmate4)").

Don't change the AI code unless Mike asks. When he does, follow CLAUDE.md:
- Test on the scratch copy, headless.
- Ideally reproduce the problem as a test first, using the log's
  positions to set it up.
- Add a DEVLOG entry.

## Things to keep in mind

- `P` lines are only written once a square moves 0.05 m or turns 5°.
  No `P` lines for a while means it stood still.
- `O` lines include internal orders: a helicopter drop-off's move, a
  squadmate's move to a new wall spot. A Fire order is `O <unit> fire
  <target>`; targets the AI picks itself only show as `~ target=`.
- `blocked=1` means a friend is in the line of fire. `standoff=1` means
  every foe is dug in and there's no window. Both mean holding fire on
  purpose, not a fault.
- Shots that end on an object (`X sN oM`) hit cover. If it's class 3,
  the shot was mostly wasted. Ground or spent means a miss in the open.
- The log stops when the level restarts (the death menu's Restart).
- Testing values may still be in play (health and troop timers; see the
  DEVLOG's "Start Here"). Check `max_health` in the `U` lines before
  judging how fast squares die.
