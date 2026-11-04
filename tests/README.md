# Tests

Headless Godot test scripts (SceneTree scripts), kept so any session can rerun
them. Godot ignores this folder (`.gdignore`), so they never load in the game or
the editor. Each one's top comment says what it checks and what it prints; the
DEVLOG entry for a change names the tests run for it and their results.

## Running one

Never on the real project (see CLAUDE.md "Testing"). On the scratch copy:

1. Copy `project.godot`, `icon.svg`, `scenes`, `scripts`, `shaders` and
   `assets` into a scratch folder, and run `--headless --import` there once
   (again after adding a script with a new `class_name`).
2. Copy the test into the scratch folder's root (they use `res://` paths).
3. Run it:
   `godot --headless --path <scratch> -s test_name.gd`

Godot prints a few leak warnings at exit; they don't matter.

## Folders

- `tests/` — the current tests (stairs, tower routes and places to stand,
  height profiles, command mode, crates, ammo, debug panel, AI behaviour).
  Notes:
  - `main.tscn` no longer places enemies (it has the EnemySpawner): newer
    tests spawn `scenes/enemy.tscn` themselves. Some older ones expected four
    placed enemies.
  - Freeze a square in a test with `set_physics_process(false)` and
    `set_process(false)`. `PROCESS_MODE_DISABLED` also takes it out of physics,
    so bullets fly through it.
- `obsolete/` — tests of things since replaced (the overlook box, the old
  watch tower sections, cover-based Shots Into). Kept for reference; they
  won't run against the current code.
- `screenshots/` — scripts that open a window to take screenshots. They pop
  up on screen and can steal keyboard focus while Mike's playtesting, so use
  them only when a picture's needed.
- `tools/make_height_profiles.gd` — writes the watch tower's default height
  profiles (top, upper stairs, shelter) into `assets/height_profiles/`. It
  overwrites them: Mike tunes these, so only run it on the scratch copy.
