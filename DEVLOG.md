# Battle Squares — Development Log

A running record of how Battle Squares is designed and built: decisions, progress, and open questions.

---

## Project Overview

| Item | Value |
|------|-------|
| Project folder | `C:\Users\mpott\Desktop\BattleSquares` (was `F:\Projects\BattleSquares`) |
| Started | 2026-10-28 |
| Game engine | Godot 4.7.2 (`C:\Users\mpott\Desktop\Godot_v4.7.2-stable_win64.exe`) |
| Art style | Realistic proportions at **real-world scale**, clean rendered look (squares are glossy red blocks; vehicles and kit are detailed but unmarked) |
| 2D / 3D | 2D, top-down (art is rendered in Blender, then used as 2D images) |
| Target platform(s) | PC (Windows), mouse + keyboard |
| Design resolution | 1920×1080; the window opens at 1280×720 and can be resized freely |
| Renderer | Godot "Compatibility" (best fit for a 2D game) |
| Asset tool | Blender 5.2 (scripted via Python `bpy`, run headless) |

### Concept

A top-down tactical squad game. You are a red square with a rifle, leading a squad of identical squares. Hold Space to talk to them: only those inside your 8 m command circle hear you, and you can move them, form them up, or deploy equipment such as a field comms station. Helicopters will insert and extract the squad, and long-range radio comms (via the station's dish) are planned.

### Core Gameplay Loop

Still forming. So far: move and aim, command the squad, deploy and set up equipment. Enemies, objectives and win conditions don't exist yet.

---

## Start Here: Current State (updated 2026-10-29, afternoon)

**Read this first in a new session.** Details are in the sections below and the dated Log.

### Controls

| Input | Action |
|-------|--------|
| WASD / arrows | Walk (screen directions; you can strafe) |
| Mouse | Aim: the square turns loosely toward the cursor, and the rifle aims within its sweep |
| Left click | Fire (one shot per click). Dead-on within the rifle's accurate range (6 m) of the click; strays more the further past it you click |
| **Right mouse** (hold) | Aim: shows the aiming line (solid = accurate range, then a red-shading spread wedge out to the mouse, labelled with the chance the shot goes into the ground) |
| Scroll wheel | Zoom 0.5×–3× (while placing an Attention formation: turn it 15° a notch) |
| **Space** (hold) | Command mode: command circle (8 m), ORDERS menu (left), DEPLOY menu (right), selection and move orders |
| **F** | Interact: at a station's desk (platform box), open/close the RADIO menu or hang up radio command; in the dish box, open/close the dish tuning wheel |
| Esc | Close the RADIO menu (or step back out of marking an LZ) |
| Right click | In command mode: move order (or cancel equipment placement); while marking an LZ: back to the request |

### What's in the game (`scenes/main.tscn`)

- The **grass field** fills whatever the camera sees.
- The **player** (`player.tscn`, inheriting `soldier.tscn`). Mike's `main.tscn` holds Field, Edge, Player, Camera, Command and **Arrival**: **no squadmates or helicopters are placed**. The game opens with the player **flown in by helicopter** (`scripts/arrival.gd`): it lands so the player steps out of the front starboard door exactly where the Player node is placed, after about 6.6 s. Until then the player is hidden and switched off and command mode is shut (`World.player_aboard`). Troops arrive by helicopter from a radio station (below), and tests add their own squadmates.
- **Helicopters** (`helicopter.tscn`) appear only when sent from a station's terminal (`scripts/insertion.gd` flies them in and out).
- **Command system** (`scripts/command.gd`):
  - a command circle all round the player (`aura_radius_m` 8 m; the voice cone was removed on 2026-10-29). Radio operators' circles are their own setting, `radio_circle_radius_m` 4.95 m, and equipment is placed within `deploy_reach_m` 4.95 m (a brighter ring while placing; 2.475 m until 2026-10-30);
  - selection by box or click;
  - move orders to anywhere;
  - an ORDERS menu: Follow me / Lead (hold for a Line/Column pop-out), **Attention** (hold for Line/Column, then click where they fall in: they form up there facing the player and stand still), Disperse, and the orange fighting orders **Fire** (arms everyone the order reaches; the next left click on a square picks the target, right click cancels; they shoot it until it dies, on top of whatever they were doing, holding fire while anyone is in the line of fire) and **Stop** (cease fire); with nothing selected, an order goes to everyone who can hear;
  - a DEPLOY menu: Equipment → Radio station, placed as a ghost inside the aura. The player carries 1 (`player.gd` `deployables`).
- **Deployed radio station** (`radio_station.tscn` + `scripts/radio_station.gd`):
  - compact: an operator platform with a desk, and just south of it (no wider than the platform) the antenna, a small steerable dish, with its green tuning box to its west;
  - **the radio terminal** (`Terminal` node, `scripts/radio_terminal.gd`). In the platform's green box (`OperatorZone`), F opens the **RADIO** menu:
    - **Command:** radio command mode (`World.radio_commanding`, `World.radio_station`). **The command structure:** your voice (cone + aura) still works. On top of it, radio operators (`kit = "radio"`) inside *this station's* dish beam are linked, and they and anyone within their **command circle** (2× the player's aura, 4.95 m) can be commanded. You see your cone, the beam, and a circle round each operator: solid when linked, dashed when out of the beam. F or stepping off the box hangs up.
    - **Deploy** (hold) → **Troops** / Vehicles (disabled, "soon"). Troops opens **10 slots** (2 rows of 5); fill as many as you want sent. Press a slot for the unit-type pop-out, which opens left of the panel: **Infantry** or **Radio** (a radio operator: infantry with a radio pack, `kit = "radio"`); a quick click = Infantry. **Clear** empties them.
    - Filled slots ready one after another, `seconds_per_troop` = **1 s each (testing value; it was 30 s)**. Then **Send helicopter** gives a ghost helicopter to mark the LZ (anywhere inside the play area). A click sends the real one: it flies in from the west at 25 m, lands, unloads the troopers (who join the squad and step about 1 m clear of the doors, spread over 3 m along each side), lifts off and flies away. The request survives walking away from the desk, and while the menu is closed a timer above the box shows "3 troopers  1:30" (total time left), then "3 troopers READY";
  - a satellite dish with its own green box. F there opens a tuning wheel. The mouse only picks a heading (white line; a green line shows where the dish points now). A left click or F locks the pick in (`target_heading`), and the dish turns to it slowly: at most 12°/s, easing in and out, so 180° takes about 15 s. A 60 m, ±18° beam shows where it actually points, in the same green and see-through as the command circles (the alphas are shared in `world.gd`). It shows while tuning and in command mode, not while the dish turns on its own. The current heading is in `dish_heading`, and `dish_tuned(heading)` is emitted when the dish arrives. **Nothing consumes it yet.**
- **Bullets hit.** A bullet traces a ray along each tick's flight (`bullet.gd`), ignores its shooter, and stops at the first solid thing (squares, a landed helicopter's hull, a radio station). A square that's hit (`soldier.gd take_hit()`) is shoved back 0.3 m along the shot in 0.12 s (`hit_knockback_m`, `hit_knockback_s`), twists up to 20° (`hit_twist_deg`) when the hit lands off-centre, and dust bursts off the hit spot back toward the shooter (`scripts/hit_dust.gd`). **Anchored** squares (`anchored`, on for the dummy) don't move: they rock on a spring, up to 0.1 m and the same twist, and settle back where they stand. **Health:** every square has `max_health` 2 for testing (normally 100) and a rifle hit does 25 (`rifle.gd damage`), so one hit kills (4 at 100). A dead square leaves every group and the collision layers (bullets and squares pass over it) and goes down as a **ragdoll** (`scripts/death_fall.gd`): the killing shot sends it skidding ~0.3–0.45 m and spinning (if hit off-centre), it topples over whichever face was pushed (front, back or a side) under gravity, bounces and settles with dust, and bumps off anything solid it skids into. Its rifle flies free under gravity: dropped to the side, or flung and spinning when it goes over backwards. It darkens, lies 5 s, fades and is removed. The player (`max_health` 4 in `main.tscn`: two hits) dies too: it falls in slow motion with the camera closing in, stays down, and a Restart / Quit menu comes up (see 2026-10-30). Friendly fire hits too. The dummy is `invincible` for now: it takes hits (rocks, dust) but never loses health.
- **Menu building blocks:** `scripts/ui_style.gd` (shared button and panel look) and `scripts/hold_popout.gd` (the reusable press-hold-slide-release pop-out), used by command mode and the terminal.

### Next steps (Mike's stated direction)

1. **Vehicles** in the terminal's Deploy menu (currently a disabled "soon" option).
2. **More unit types** for troop slots (only Infantry so far; add to `UNIT_TYPES` in `radio_terminal.gd`, and spawn the right scene in `insertion.gd`).
3. **Radio soldiers / long-range comms:** the dish heading (`dish_tuned`) should matter, e.g. a contact must be inside the beam.
4. **Helicopter extraction** (insertion is done, from the terminal). Open questions: who boards (listeners or selected? the player?) and how it's called.
5. **Gunshot sound:** proposed a generated placeholder now and a Sonniss/Kenney recording later; the rifle's `fired` signal is ready. Not done yet.

### Loose ends and known issues

- **Git:** the project is now in git (`main`, with an `origin` remote).
- **Testing values to restore:** `seconds_per_troop` is 1 s (was 30 s) in `radio_terminal.gd`; `max_health` is 2 (was 100) in `soldier.gd`.

- The `Field` node in `main.tscn` was scaled to (0.9896, 1.0028) and moved to (0, 3), probably by an accidental drag in the editor. Mike was told and it was left alone.
- Soldier collision boxes don't rotate with facing.
- Art is rendered for 1× zoom: at 3× the grass and squares are soft (the rifle and station are rendered at 2–4× density and stay sharp). At 0.5× the 12 m grass tile repeats visibly.
- Flowers in the far-zoom grass are fairly dense.
- `main.tscn` has a **Dummy nested inside another Dummy** (`Dummy/Dummy`, probably dropped onto the first one in the Scene panel). The inner one moves with the outer one, so when the outer one is shot both get shoved. Drag it onto Main to fix it. Left alone for Mike.
- Ideas raised but not built: a speed penalty for strafing or backing up; squadmates firing; a faint dish beam always visible; choosing the helicopter's approach direction.
- The LZ only needs its centre inside the play area: nothing stops a helicopter landing on squares, the station or another helicopter. Troopers dispersing past the play area's edge are held at the edge.

### How to work on this project

See `CLAUDE.md` in this folder for the working rules: testing on a scratch copy while Mike's editor is open, headless tests, and the scale and lighting rules for new art.

---

## Asset Pipeline

Assets are generated by Python scripts that run against Blender's API:

```
"C:\Program Files\Blender Foundation\Blender 5.2\blender.exe" --background --python <script>.py
```

- Generator scripts live in `blender/scripts/` so any asset can be rebuilt or tweaked later.
- Because the game is 2D, Blender builds 3D scenes and renders them straight down with an orthographic camera. The output is a PNG that Godot uses as a 2D image.
- Ground textures are **seamless tiles**: each tile repeats edge-to-edge with no visible join, so it can cover any size of field.
- Game-ready images go in `assets/`. Seam-check previews go in `assets/previews/`.

### Folder Layout

The `BattleSquares/` folder itself is the Godot project root (`project.godot` will live here), so Godot can see `assets/` directly. `blender/` contains a `.gdignore` file so Godot skips it.

```
BattleSquares/
├── DEVLOG.md            ← this file
├── CLAUDE.md            ← working rules for Claude sessions (read automatically)
├── project.godot        ← Godot project settings
├── scenes/              ← Godot scenes (.tscn)
│   ├── main.tscn        ← starting scene: field, helicopters, player, squadmates, camera, command
│   ├── soldier.tscn     ← the shared square: body, shadows group, rifle, sight, collision
│   ├── player.tscn      ← inherits soldier.tscn, script player.gd
│   ├── squadmate.tscn   ← inherits soldier.tscn, script squadmate.gd (turns at 300°/s)
│   ├── helicopter.tscn  ← transport helicopter: body, rotor, shadows group, hull collision
│   └── radio_station.tscn ← deployable comms station: layers, dish, stand boxes, zones, collisions
├── shaders/
│   └── shadow_sweep.gdshader ← sweeps a part's outline across its height range (helicopter, dish shadows)
├── scripts/             ← GDScript code (.gd)
│   ├── world.gd         ← shared constants: PX_PER_M, ARENA, sun, COMMAND_COLOR, controls
│   ├── field.gd         ← tiles the grass across whatever the camera sees
│   ├── road.gd          ← a road drawn as a Path2D: the asphalt strip tiled along its curve
│   ├── game_camera.gd   ← scroll-wheel zoom, follows the player within the arena
│   ├── soldier.gd       ← every square: movement, facing, hop, shadows, rifle
│   ├── player.gd        ← keyboard/mouse control of a soldier
│   ├── squadmate.gd     ← AI soldier: idle glances/shuffles, move orders
│   ├── command.gd       ← hold Space: command circle, selection, orders menu, HUD
│   ├── helicopter.gd    ← rotor spin, altitude, swept shadows, hull outline
│   ├── radio_station.gd ← deployed station: stand boxes, F to tune the dish (wheel + beam)
│   ├── radio_terminal.gd ← the station's desk: RADIO menu, radio command, troop requests, LZ
│   ├── insertion.gd     ← flies a helicopter in to an LZ, unloads troops, flies it out
│   ├── ui_style.gd      ← shared look of the menus (buttons, panels, labels)
│   ├── hold_popout.gd   ← press-hold-slide-release pop-out used by every menu
│   ├── rifle.gd         ← mouse aim within a sweep, recoil, muzzle flash, firing
│   ├── radio_pack.gd    ← radio operator's backpack + antenna (soldier `kit = "radio"`)
│   ├── bullet.gd        ← tracer projectile
│   └── sandbags.gd      ← deployable sandbag wall: solid cover, sand puffs, swept shadow
├── blender/             ← ignored by Godot
│   ├── scripts/         ← Python generators (source of truth for assets)
│   │   ├── bs_common.py ← shared sun, sky, camera and pixel scale; all scripts use it
│   │   ├── field_grass.py
│   │   ├── road_asphalt.py
│   │   ├── sandbags.py
│   │   ├── character_square.py
│   │   ├── rifle.py
│   │   ├── radio_pack.py
│   │   ├── helicopter.py
│   │   └── radio_station.py
│   └── source/          ← saved .blend files (written by the scripts)
└── assets/
    ├── textures/        ← tiling ground images
    ├── characters/      ← character sprites and their shadows
    ├── vehicles/        ← helicopter body, rotor and shadow outlines
    ├── props/           ← static props (comms station) and their shadows
    ├── sfx/             ← sound effects (.wav / .ogg)
    └── previews/        ← review renders, ignored by Godot
```

---

## Screen Resolution

- The game is designed at **1920×1080**. All art is sized for that: the grass tile is 1024 px, so about 1.9 tiles span the screen width.
- Stretch mode `canvas_items`: the game scales smoothly to any window size, so 1080p, 1440p and 4K all show the same view, just sharper.
- Aspect `expand`: on screens that aren't 16:9 (ultrawide, 16:10, odd window sizes), the player sees *more* of the field instead of black bars. `field.gd` resizes the grass to cover whatever area is visible. Tested at 1280×720 (shows 1920×1080) and 1720×720 ultrawide (shows 2580×1080).
- Keep anything important (UI, the playable area) inside the central 1920×1080; extra width or height is only for show.
- **Arena:** the play area is `World.ARENA`, 3840×2160 px (45 × 25.3 m), twice the 1920×1080 view each way. The player can't leave it; `arena_edge.gd` draws the barrier, and the camera can show 2 m past it.
- **Camera zoom (scroll wheel):** from 0.5× to 3×, at 1.15× per notch, easing smoothly.
  - At 1× the view is exactly the arena, and the camera stays still.
  - Zoomed in, it follows the player but stops at the arena edges.
  - Zoomed out, it centres on the arena, with extra field showing around it.

---

## World Scale & Lighting (keep every asset consistent)

- **1 world unit = 1 metre. 1 m = 85.33 px** (`PX_PER_M = 1024 / 12`), in Blender (`blender/scripts/bs_common.py`) and Godot (`scripts/world.gd`). Every asset renders at this density and is used at scale 1 in Godot. The screen shows about 22.5 × 12.7 m of field.
- Zoom history: 1024/1 m (first close-up) → 1024/3 (3× farther) → 1024/12 (another 4× farther, current).
- Godot gameplay values (speed, hop height and so on) are in **metres** and converted with `World.PX_PER_M`, so they stay physically correct when the zoom changes.
- **Sun:** 40° from straight overhead, light coming from the top-left, so shadows fall to the bottom-right.
- **Freely rotating objects** (such as the rifle) are rendered lit from straight overhead, which looks the same at any angle. Their shadow is drawn in Godot: the same sprite in black, offset by height × tan(40°) along the sun direction.
- **One shadow layer per character:** all of a character's shadows (body, rifle, …) are drawn **fully dark** inside a `CanvasGroup` called `Shadows`, and the group as a whole is faded to `SHADOW_ALPHA` = 0.71 (the open-ground shadow level, printed by `character_square.py`). Overlapping shadows therefore don't darken each other. Shadow sheets are rendered normalised, so a full shadow = alpha 1.
- **Turning objects:** never rotate a lit sprite in Godot, or its baked highlights and shadow turn with it. Render a sheet of angles in Blender under the fixed sun and pick the frame in Godot. Overlays such as the sight triangle are drawn in Godot and can rotate freely.
- **Shadows:** a character's shadow is rendered as a **separate image** (a Blender shadow catcher), so the game can move and fade it independently. Its darkness is capped at the level of an open-ground shadow, so no solid-black patch shows when it slides out from under the character.
- **Zooming the whole game in or out** later means changing `PX_PER_M` in both places and re-running every Blender script.
- **Far-zoom grass:** when real 3 mm blades would be under half a pixel wide, `field_grass.py` scales blades, flowers and pebbles up (`BLADE_SCALE`, currently 2×) and uses fewer blades. Otherwise the grass blurs into flat colour and the blade count becomes unmanageable (it would be about 10 million).

---

## Asset List

| Asset | Status | Script | Notes |
|-------|--------|--------|-------|
| Grass field tile (1024×1024, seamless) | Done (v3, 12× original distance) | `blender/scripts/field_grass.py` | Output `assets/textures/field_grass_tile.png`. The tile covers 12 × 12 m, with 2.52 M blades at 2× size, lush and dry patches, soil, about 3,400 daisies and buttercups, and pebbles; lit from the top-left. Takes about 57 s in total (mostly building the mesh). Older versions are in `assets/previews/` (`…closeup_v1`, `…3x_v2`). |
| Asphalt road strips, 4 conditions (1024×512 each, tile end to end) | Done (v3: clean, ok, medium, bad), **in the game** (`scenes/road.tscn`, Condition) | `blender/scripts/road_asphalt.py` (`-- clean ok medium bad` to render only some) | `assets/textures/road_asphalt.png` (clean), `road_asphalt_ok.png`, `road_asphalt_medium.png` and `road_asphalt_bad.png`: each 12 m along the road × 6 m across, RGBA, all the same size so they swap freely. **Clean**, after Mike's reference picture: 5 m of even dark asphalt, straight crisp edges, solid white edge lines (0.12 m wide, 0.15 m in) and yellow centre dashes (1 m dash, 1 m gap). **Ok:** slightly faded paint, faint wheel tracks, a few hairline cracks at the edges, one repair patch with a sealed seam, oil stains, edges barely wavy. **Medium:** paint worn through in places, a broken crack down the middle and four across, a patch of crazed cracking, two patches, a small pothole, ragged edges with some gravel and dirt, and grass in a few cracks. **Bad:** paint mostly gone and flaking, cracks everywhere (7 across, a web along the edges, 3 crazed patches), 5 potholes with broken stone in them, crumbling edges with a gravel-and-dirt verge, broken asphalt chunks, and grass in the cracks. Damage is set per condition in `CONDITIONS`. Field grass (same colours, size and density as `field_grass.py`, whose `main()` is guarded so it can be imported) grows over each verge, then the strip is transparent so the real field shows through, and its outermost 10 px are faded to nothing. No shadow catcher: the field's grass already has its shadows, and doubling them left a dark band. All four render in about 40 s. Previews: `assets/previews/road_conditions_preview.png` (all four over the grass, clean at the top), `road_asphalt{,_ok,_medium,_bad}_preview.png`, `road_conditions_ingame.png` (all four in the game, Clean to Bad from left to right) and `road_ingame_preview.png`. |
| Sandbag wall (deployable), 6 tiles | Done (v2: tiles that join into one wall), **in the game via DEPLOY** | `blender/scripts/sandbags.py` | `assets/props/sandbags_{single,start,end,mid_0,mid_1,mid_2}.png` (272 × 128 px = 0.797 × 0.375 m, **rendered at 4× density**, shown at 0.25 with mipmaps; each has a `.import` with mipmaps on). After Mike's reference photo: one stack of 3 courses, a single bag deep (the two-deep base of v1 is gone), 0.354 m high, 0.282 m wide at the foot, the courses stepping in 5% each as they rise. Big, boxy, lumpy tan burlap bags (0.4 × 0.256 × 0.136 m; 1.6× v2's) in a running bond: even courses two bags a tile, odd ones offset half a bag, so one bag straddles each join. Tiles are 0.797 m (68 game px, two squares) and join end to end seamlessly: each is rendered with the neighbours' bags that reach into it, and the bags at a join are keyed by position (`bag_rng()`) so every tile builds them the same, then cropped to the tile. **single:** both ends finished with half bags. **start / end:** finished at −x / +x. **mid_0–2:** joined at both ends, with different middle bags so long rows don't repeat. Lit by the standard sun; the game draws the shadow. Review: `assets/previews/sandbags_preview.png` (an angled run of five), `sandbags_tiles_preview.png` (the tiles laid edge to edge), `sandbags_rows_preview.png` and `sandbags_join_closeup.png` (in the game). All six render in about 15 s. |
| Ammo crate (first of the supply crates) | Done, **scene ready to place** (`scenes/crate_ammo.tscn`) | `blender/scripts/crates.py` (`-- ammo`) | `assets/props/crate_ammo.png` (384 × 384 px = 1.125 m square, **rendered at 4× density**, shown at 0.25 with mipmaps; `.import` has mipmaps on). After Mike's reference photo (a tarped pallet), without the tarp: a 0.8 m square four-way wooden pallet (0.144 m high: bottom boards, nine blocks, stringers, seven deck boards, pine with grain) loaded with 24 olive-drab M2A1-size ammo cans in a square block (4 across × 2 deep × 3 high; each with a rimmed lid, folding handle, end latch and yellow stencil marks, a little out of true) under black ratchet straps both ways with buckles on top. Load 0.632 × 0.618 m, top at 0.732 m. Lit by the standard sun; the game draws the shadow (`scripts/crate.gd`). Review: `assets/previews/crate_ammo_preview.png` (angled). Other crate kinds will be added to `KINDS` in the same script. |
| Sandbag crate | Done, **scene ready to place** (`scenes/crate_sandbags.tscn`) | `blender/scripts/crates.py` (`-- sandbags`) | `assets/props/crate_sandbags.png` (384 × 384 px = 1.125 m square, 4× density, mipmaps). The ammo crate's pallet and straps, loaded with 30 filled burlap sandbags (the wall's bag model and burlap from `sandbags.py`, a touch smaller: 0.37 × 0.235 m), 2 × 3 to a layer, 5 layers, each turned 90° from the one below. Straps as on the ammo crate. Load 0.768 × 0.772 m, top at 0.747 m. Review: `assets/previews/crate_sandbags_preview.png`. |
| Ammo can (lone) | Done, **scene ready to place** (`scenes/ammo_can.tscn`) | `blender/scripts/crates.py` (`-- can`) | `assets/props/ammo_can.png` (128 × 128 px = 0.375 m square, 4× density, mipmaps). One of the ammo crate's cans on its own: olive drab, rimmed lid, folding handle, end latch, yellow stencils. 0.16 × 0.32 m, top at 0.207 m. Review: `assets/previews/ammo_can_preview.png`. |
| Rifle | Done (v2, detailed) | `blender/scripts/rifle.py` | `assets/characters/rifle.png` (384 px, **rendered at 4× density**, shown at 0.25 scale with mipmaps so it stays sharp when zoomed in). 0.48 m from pivot to muzzle (0.28 m beyond the front face). Parts: gunmetal receiver, red-dot sight with a red lens, polymer handguard, front sight post, barrel, muzzle brake, and a forward-raked magazine. **Canted 30°** so the magazine shows from above (it pokes out to the gun's right). Lit from straight overhead so it can rotate; its shadow is drawn in Godot. v1 (plain bar) is in `assets/previews/rifle_v1_plain.png`. |
| Radio pack (radio operator) | Done (v1) | `blender/scripts/radio_pack.py` | `assets/characters/radio_pack.png` (614 px = 1.8 m, **rendered at 4× density**, shown at 0.25 scale with mipmaps), centred on the square's centre, square facing +x. Brown canvas pack on the square's back (0.16 m deep, 0.3 m wide, top at 0.44 m, just above the square), darker top flap and side pouches, shoulder straps over the square's top, the radio's top with two knobs, and a 0.6 m whip antenna raked 32° back with a tip cap. Lit from straight overhead so it turns with the square; its shadow is drawn in Godot (`radio_pack.gd`). |
| Helicopter (UH-60-style transport) | Done (v3, 0.55 scale, cockpit, flies insertions) | `blender/scripts/helicopter.py` | Modelled at real size, then shrunk by `SCALE` = 0.55 (`helicopter.gd SCALE` must match): fuselage 8.4 m, rotor 9 m. Cockpit (laid out for scale 0.5 and grown with `SCALE`): two red pilot squares, 0.44 m, corners rounded like the player's (upright edges only, top edges sharp), under dark tinted glass (alpha 0.85); an instrument panel with screens, switch strips and a centre console with lamps. `assets/vehicles/helicopter_body.png` (939 px = 11 m, nose to +x; cockpit interior without pilots or glass), `helicopter_pilot.png` (one pilot, lit as in the cockpit; the game draws two and animates them), `helicopter_glass.png` (glass only, drawn over the pilots) and `helicopter_rotor.png` (centred on the mast), both lit from straight overhead so they can face any heading. Plus 4 half-res shadow outlines `helicopter_shadow_{body,stabilator,fin,tailrotor}.png` (padded for sweeping). Olive drab, matte, no markings; black blades with yellow tip bands. Renders in about 15 s. |
| Deployable comms station (platform, desk, laptop, small satellite dish) | Done, **in the game via DEPLOY** | `blender/scripts/radio_station.py` | Four images, all 2× density (show at scale 0.5): `radio_station.png` (tall parts, z 4), `radio_station_ground.png` (deck and cable, z −5), `radio_station_shadow.png` (1109 px = 6.5 m, centred on the station's middle), and `radio_station_dish.png` (2.4 m, centred on the dish post, lit from overhead, rotated in game). **Compact since 2026-10-29:** a 2 m square plank operator platform centred 1.05 m north of the origin, with a field desk along its east edge carrying a radio (whip antenna, handset), the detailed rugged laptop (lit mapping-app screen, mouse), a power unit, a headset, a notebook and a mug; the antenna (since 2026-10-30) is a desert-tan flyaway satellite terminal 1.1 m south of the origin, inside the platform's width: four splayed outrigger legs on round grey foot pads braced to a centre column, a pan/tilt head and yoke, a 1.2 m dish at 40° elevation with a rolled rim and a centre feed boom, and a black cable down the column. The head, yoke, dish, rim, boom and feed are the turning image; the base stays in the station image; one cable from the desk to the dish. The 7 m guyed mast and its stakes are gone. Lit by the normal top-left sun (it doesn't turn), with its shadow rendered separately and normalised like the squares'. Review images: `assets/previews/radio_station_preview.png` (an in-game screenshot) and `radio_station_dish_preview.png` (an angled close-up of the antenna). Renders in about 20 s. |
| Red square: player (body + shadow) | Done (v3, turning sheets) | `blender/scripts/character_square.py` | `assets/characters/red_square_sheet.png` (30 frames × 64 px; the block is about 34 px = 0.4 m) and `red_square_shadow_sheet.png` (30 × 128 px). Frame k = the block turned k × 3° clockwise; 30 frames cover 90°, because a square repeats every quarter turn. Pre-lit at every angle, so the highlight and the shadow's shape stay correct as it turns. Glossy red plastic with rounded edges. Renders in about 20 s. Older single images are in `assets/previews/`. |
| Crash test dummy square (body) | Done (v1), `scenes/dummy.tscn` ready to place | `blender/scripts/dummy_square.py` | `assets/characters/dummy_square_sheet.png` (30 frames × 64 px, same layout, size, bevel and sun as the red square, so it drops into a soldier's Body sprite as-is). Crash-test yellow with a black ring-and-cross tracking target on top. Not the classic half-black quadrant target: the sheet covers only a quarter turn, and a quadrant target would swap black and yellow every time the frames wrap round. The shadow is the same shape, so it reuses `red_square_shadow_sheet.png`. Imports `character_square.py` for the block and render helpers (its `main()` is now guarded). Renders in about 8 s. Preview: `assets/previews/dummy_square_preview.png` (red square, then the dummy at 0°, 24° and 45°, 6×). |
| Blue enemy square (body and fall sheets) | Done, **in the game** (`scenes/enemy.tscn`) | `blender/scripts/enemy_square.py`, `fall_square.py -- blue` | `assets/characters/blue_square_sheet.png` (same layout as the red sheet) and `blue_square_fall_sheet.png` (same layout as the red fall sheet). The same block in blue plastic, `bs.srgb(0.08, 0.32, 0.88)`; the shadow sheets are shared. `fall_square.py` now takes `-- red/dummy/blue/shadow` to render only some sheets. Preview: `assets/previews/enemy_fight_preview.png`. |
| Square death falls (red, dummy, shared shadow) | Done (v1), **in the game** | `blender/scripts/fall_square.py` | `assets/characters/red_square_fall_sheet.png` and `dummy_square_fall_sheet.png` (1536×3840: 30 rows × 12 columns of 128 px = 1.5 m frames) and `square_fall_shadow_sheet.png` (2304×5760, 192 px = 2.25 m frames, normalised like the standing shadow). Row k = toppling toward k × 12° (Godot angle, clockwise from east); column j = j × 90/11° over, pivoting on the bottom edge on that side, so it ends one block-width (0.4 m) from where it stood. Every direction is rendered because the fixed sun lights each one differently. Frames are centred where the block stood. Reuses `character_square.py`'s block and `dummy_square.py`'s material (both scripts' `main()` are now guarded so they can be imported). 64 samples; about 6 min for all three. Preview: `assets/previews/death_falls_preview.png` (scripted falls) and `ragdoll_preview.png` (the ragdoll). |

Status values: `Planned` · `In progress` · `Done` · `Needs rework`

---

## Decisions

Major choices and the reasons behind them.

| Date | Decision | Reason |
|------|----------|--------|
| 2026-10-28 | Generate assets with scripted Blender (bpy) | Assets can be rebuilt and varied, and changes are tracked in version control |
| 2026-10-28 | 2D top-down game; render art from Blender in orthographic top-down view | Gives 3D-quality lighting and detail while keeping the game simple 2D |
| 2026-10-28 | Use the project folder itself as the Godot root | Godot can only use files inside its project folder |
| 2026-10-28 | Light all art from the top-left (shadows fall bottom-right) | Keeps shading consistent across every asset |
| 2026-10-28 | 1920×1080 design resolution, `canvas_items` stretch, `expand` aspect | 1080p is the most common screen size; on other aspect ratios the field extends instead of showing black bars |
| 2026-10-28 | Compatibility renderer | Mike's own new project picked it; it suits 2D and runs on more hardware |
| 2026-10-28 | Use Godot 4.7.2 as the engine | Free and lightweight; its project files are plain text, so Claude can edit them directly and run the game from the command line |
| 2026-10-28 | Everything at real-world scale, 85.33 px/m | Mike zoomed out twice and settled here; the helicopter at real size is "damn near perfect" |
| 2026-10-28 | All squares share `soldier.gd`; player and squadmates are subclasses | One body, movement and rifle for everyone; the behaviours differ only in intent, aim and fire |
| 2026-10-28 | Facing follows aim loosely (comfort zone); walking is independent of facing | Mike: "nailed that feeling" |
| 2026-10-28 | Command mode on **Space** (was C); voice cone + aura limit who can be commanded, not where they can go | Mike's design; the destination limit was a misread and was reversed |
| 2026-10-29 | Voice cone removed; the command circle is 8 m all round (the cone's old range). Radio operators' circles stay 4.95 m and deploy reach stays 2.475 m, as separate settings | Mike asked to remove the cone and grow the circle to the cone's radius; he chose to keep the radio circle and deploy reach as they were |
| 2026-10-28 | Menu orders go to the selection, or to everyone who can hear if nothing is selected | Mike: shouldn't need to select first |
| 2026-10-28 | Static props use the world sun + a separate shadow image; anything that rotates is lit from overhead with a swept outline shadow | Lighting stays consistent while things can turn |
| 2026-10-29 | Station split into a ground layer (under squares) and a tall layer (over them) | The deck was drawing over the player |
| 2026-10-29 | Helicopter at **0.55** of real size (`SCALE`), so the pilots seen through its glass are 0.44 m, 10% bigger than the player | Mike: first "too big" (0.5), then pilots should be ~10% bigger than the player since they're higher up, closer to the camera |

---

## Open Questions

- [x] Which game engine? → Godot 4.7.2
- [x] Art style? → realistic proportions at real scale, clean rendered look
- [x] What does a "square" represent? → a soldier (the player and squadmates)
- [ ] Single-player, local multiplayer, or online?
- [ ] Helicopter insert/extract: landing spot, who boards, do levels start with an insertion?
- [ ] What are the enemies, objectives and win conditions?
- [ ] What does radio operation / long-range comms actually do?

---

## Log

### 2026-10-28 — Project kickoff
- Created the project folder `F:\Projects\BattleSquares`.
- Confirmed Blender 5.2 is installed and can be driven headless for asset generation.
- Started this dev log.
- Chose Godot 4.7.2 as the engine and confirmed it runs from the command line (`--version` → `4.7.2.stable.official`).
- **Next:** settle the art style and core concept, then create the Godot project and build the first test asset.

### 2026-10-28 — Grass field tile
- Confirmed the game is **2D top-down**.
- Wrote `blender/scripts/field_grass.py` to generate a seamless 1024×1024 grass tile.
- How the tile stays seamless: every random pattern repeats exactly once across the tile, and any blade near an edge is copied to the opposite edge, so blades and their shadows continue across the seam.
- Checked the 3×3 preview: no visible seams. Repetition shows when zoomed far out because of the dirt patches and flower clusters, but one tile already covers most of a 1280×720 screen.
- **Next:** create the Godot project and a field scene that tiles this texture.

### 2026-10-28 — Godot project and field scene
- Created the Godot project at the folder root: `project.godot`, `scenes/main.tscn`, `scripts/field.gd`. Copied over the icon, `.gitignore`, `.gitattributes` and `.editorconfig` from Mike's starter project.
- The field is a `Sprite2D` with **region** and **texture repeat** turned on, so one 1024 px tile repeats to fill any area. `field.gd` sizes it to the visible screen and resizes it whenever the window changes.
- Tested by running the game and capturing screenshots: no errors, and the grass fills the screen at both 16:9 and ultrawide.
- Found an empty starter project Mike made at `BattleSquares/BattleSquares/battle-squares`. Godot ignores it inside the real project (it only causes a warning); deleting it is pending Mike's OK.
- **Next:** decide what the "squares" are and add the first player or unit.

### 2026-10-28 — Field zoomed out 3×
- Mike: the grass looked too close. Moved the view 3× farther away.
- Done in Blender, not by shrinking the image in Godot, which would blur it and repeat the pattern every 341 px. The script's new `TILE` setting sets how much ground one tile covers. Blades, flowers and patches keep their real-world size, so `TILE = 3.0` shows 9× the ground in the same 1024 px tile. The random patterns scale with it so the tile stays seamless.
- Godot needed no changes: same file, same size. Re-imported and checked in-game.
- To zoom further in or out later, change `TILE` and re-run the script (for example, `4.0` = 4× the original distance).
  - *Superseded the same day:* zoom is now the shared `PX_PER_M` (see World Scale & Lighting), and `TILE` is calculated from it.

### 2026-10-28 — Red square player
- Moved the sun, sky, camera and pixel scale into `blender/scripts/bs_common.py` so every asset matches. `field_grass.py` now uses it; its output is unchanged (re-rendered and compared: differences are at most 1/255, which is GPU noise).
- `character_square.py` renders a 0.4 m red block with rounded edges, plus its shadow as a separate image.
- Godot: `scenes/player.tscn` is a `CharacterBody2D` with `Shadow` and `Body` sprites and a 137 px collision box. `scripts/player.gd` does the following:
  - **Movement:** WASD or the arrow keys at 550 px/s (about 1.6 m/s), with acceleration and friction so starting and stopping feel smooth. The same speed applies on diagonals.
  - **Hop:** while moving, the square hops 6 cm, one hop per 0.45 m travelled, so it never looks like it's sliding. When it stops, it settles back down.
  - **Dynamic shadow:** as the square lifts, the body grows slightly (it's closer to the overhead camera) and tilts a little side to side. The shadow slides in the sun's direction by height × tan(40°) and fades slightly.
  - **Screen edges:** the square can't leave the visible area.
  - The controls are registered in code, not in Project Settings → Input Map, so `project.godot` didn't need editing while the editor was open.
- Tested on a copy of the project using real key presses (D+S, then A held): it moved, hopped up to about 5 cm with the shadow offset about 11 px, came to rest, and stopped at the left edge (x = 68 px). Screenshots look correct.
- **Next:** Mike to playtest the feel (speed, hop height). Then: what are we battling?

### 2026-10-28 — Zoomed out another 4× (12× original)
- Mike asked to zoom out another 400%. `PX_PER_M` went from 341.33 to 85.33 px/m; the screen now shows about 22.5 × 12.7 m.
- Re-rendered the field (12 m tile) and the square (now about 34 px).
- `field_grass.py` changes needed to scale this far:
  - Added `BLADE_SCALE` (see World Scale & Lighting).
  - Meshes are now built directly from numpy arrays instead of `from_pydata`. 2.6 M blades would otherwise be very slow.
  - The noise is evaluated in chunks to keep memory use down.
  - The ground grid is coarser.
- Godot:
  - New `scripts/world.gd` holds `PX_PER_M` and the sun direction for all scripts.
  - `player.gd` settings are now in metres (`speed_mps` 1.6, acceleration and friction in m/s², hop in metres), and the collision box is sized from `SIZE_M` in code.
- Tested on a copy of the project: it walks, hops, settles, and stops at the left edge (x = 17 px = half the square).
- **Side effect to review:** walking speed stayed at a realistic 1.6 m/s, so the square now covers 4× fewer pixels per second. Crossing the screen takes about 14 s (it was about 3.5 s). Mike to decide whether to raise `speed_mps`.
- Also to review: with 16× the area per tile, the flowers look quite dense, and the tile repeats about twice across the screen.

### 2026-10-28 — Scroll-wheel zoom
- Added a `Camera2D` (`scripts/game_camera.gd`) to `main.tscn`. The scroll wheel zooms from 0.5× to 3×; see Screen Resolution for how the camera follows.
- The player is now confined to the fixed arena (`World.ARENA`) instead of whatever is visible, so zooming doesn't change where it can walk.
- `field.gd` now fits the grass to the camera's view every frame (with a 64 px margin), so there are no gaps at any zoom level or camera position.
- Tested on a copy with simulated wheel notches and walking:
  - zoom 1 → 3 (clamped);
  - camera followed the player to x ≈ 1241, then stopped at the arena edge (x = 1600, the expected limit);
  - zoom → 0.5, camera re-centred at (960, 540);
  - no errors.
- **Known art limits:**
  - At 3× the art looks soft. It's rendered for 1×; rendering at 2× density and displaying at half scale would fix this.
  - At 0.5× the 12 m grass tile repeats visibly. Fixes: a bigger tile (2048 px = 24 m), or a large-scale colour-variation overlay in Godot.

### 2026-10-28 — Facing direction and line of sight
- Mike's choices:
  - **Turn to face movement:** WASD still moves in screen directions; the square swivels to face the way it walks.
  - **Line of sight:** a see-through triangle just in front of the front face, as wide as the square.
- `character_square.py` now renders 30 angles across 90° into sprite sheets (body and shadow), so lighting stays correct while turning.
- `player.gd` changes:
  - `facing` (radians; it starts facing up) swivels toward the input direction at `turn_speed_dps` = 540°/s, about a third of a second for a half turn, and stays wrapped to −180…180°.
  - Body and shadow pick the sheet frame for `facing` plus the hop waddle; the sprites themselves never rotate.
  - `Sight` is a `Polygon2D`: a white triangle at 35% opacity, 5 cm (about 4 px) in front of the face, as wide as the square (0.4 m) and 16 cm deep, rotated to `facing`.
- `player.tscn` uses the sheets (`hframes = 30`), has the new `Sight` node, and its collision box is 34 px (also set in code). The collision box doesn't rotate yet.
- Tested on a copy with real key presses, timed on physics ticks:
  - caught mid-swivel at −18°;
  - right → 0°, down-left → 135°, up → −90°;
  - the triangle matched every time, and the screenshots look correct.
  - (Waiting on screen frames instead gave false results when the frame rate was uncapped.)

### 2026-10-28 — Rifle and shooting
- Mike's spec: a long rectangle poking out of the front that tracks the mouse within a realistic sweep, so the square must turn for a full sweep; left click shoots.
- **Rifle** (`scripts/rifle.gd`, the `Rifle` node in `player.tscn`):
  - Pivots at the square's centre and sticks out 0.45 m (about 38 px) beyond the front face.
  - Follows the mouse within `sweep_deg` = ±45° of `facing` (the width of the front face), swinging at up to 720°/s. It stays inside the sweep while the body turns underneath it.
  - Drawn under the body, so the part over the square is hidden.
  - `RifleShadow` uses the same sprite, darkened, offset by its 0.22 m holding height (plus any hop) toward the bottom-right. It moves with the rifle and recoil.
- **Firing:** left click (`shoot` action, added in code), one shot per click, at most one every 0.12 s.
  - Each shot kicks the rifle back 4 cm (it recovers in 0.1 s), shows a muzzle flash for 0.05 s, and emits a `fired` signal for sound.
  - `scripts/bullet.gd` is a pale-yellow tracer at 120 m/s. It's added to `Main`, so it doesn't follow the player, and removes itself after 1 s or once it's outside the arena. Nothing to hit yet.
- `player.gd`:
  - New `_aim_point()` returns the mouse position; it can be swapped for a gamepad or AI later.
  - `MOUSE_CONTROLS` registers the left mouse button.
- Tested on a copy of the project with a fake mouse (a player subclass overriding `_aim_point()`):
  - aim clamps at −45° (mouse 90° right), points straight at −110° (inside the sweep), and stops at −135° with the mouse directly behind;
  - one press fires one shot, with the flash visible on the same tick (a one-tick delay was found and fixed);
  - a second click inside the cooldown is ignored;
  - after turning right, the aim is re-clamped to −45° relative to the new facing.
- The test window often stops drawing while in the background, so screenshots of the flash and tracer weren't captured. Tests now pause the game before each screenshot and skip it if no frame is drawn.
- **Noticed:** `main.tscn` was saved from the editor with `Field` scaled to (0.99, 1.003) and moved to (0, 3), probably by an accidental drag. `field.gd` resets position but not scale. Left as is, pending Mike.
- **Sound:** not added yet. Mike asked for the best way to make sounds; the `fired` signal is ready for a gunshot.

### 2026-10-28 — Shorter, detailed rifle
- Mike asked for a shorter rifle with more detail: a small sight and a magazine hanging underneath.
- Shortened it from 0.65 m to 0.48 m from the pivot; the muzzle now sits about 24 px past the front face at 1×, down from about 38 px.
- Rebuilt in `rifle.py` from parts. Seen straight down, a magazine under the gun would be hidden, so the gun is canted 30° and the magazine sticks out to the side. Detail sits beyond about 0.2–0.28 m from the pivot so the body doesn't cover it.
- **Supersampled sprite:**
  - `bs_common.new_scene`/`frame_camera` take an optional `px_per_m`; the rifle renders at 4× density.
  - `rifle.gd` shows it at `SPRITE_SCALE` 0.25 with `TEXTURE_FILTER_LINEAR_WITH_MIPMAPS`, and `rifle.png.import` now has `mipmaps/generate=true`.
  - This is the fix noted earlier for soft art at 3× zoom. Other assets could adopt it later.
- `rifle.gd`: `LENGTH_M` is 0.48, so bullets and the muzzle flash start at the new muzzle (checked: bullet spawned 41.0 px from the pivot, as expected).
- Checked at 3× zoom on a copy: the receiver, red dot, handguard, brake and magazine are all visible and sharp, and the shadow includes the magazine.

### 2026-10-28 — Rifle on the right shoulder
- Mike: the rifle swung across the front like a turret; he wanted it held realistically, on the right side.
- `rifle.gd`:
  - The pivot is now the **right shoulder**: `shoulder_right_m` = 0.13, `shoulder_forward_m` = 0, in the body's own frame, so it stays on the square's right as it turns.
  - The gun aims from the shoulder at the cursor.
  - The sweep is uneven: `sweep_right_deg` = 40 (outward), `sweep_left_deg` = 30 (across the body). These replace the single `sweep_deg`.
- **Shadow fix:**
  - The rifle's rear sits inside the square, so its shadow overlapped the body's and darkened it (a dark bar beside the square).
  - Added the `Shadows` CanvasGroup (see World Scale & Lighting). `character_square.py` now writes a normalised shadow sheet, and `player.gd` fades the group (with the hop) instead of the body shadow alone.
- Tested on a copy with a fake mouse; all checks passed:
  - shoulder at +11 px to the right when facing up, and at +11 px down (the square's right) when facing right;
  - aim −90° (ahead), −50° (right limit), −120° (left limit);
  - the bullet spawns exactly at the muzzle.
- Screenshots: the rifle runs along the right side; the rifle and body shadows merge without a darker overlap.

### 2026-10-28 — Body faces the aim; walking is independent
- Mike: the face should turn with the gun, loosely and realistically. WASD still moves in its own direction.
- `player.gd`:
  - Movement no longer sets `facing`. WASD moves in screen directions whatever the facing, so the square can strafe and back up.
  - New `_turn_toward(target)`: if the aim is more than `comfort_deg` (15°) off the nose, the body swings at `turn_speed_dps` (540°/s) until it's back inside 15°. Inside that zone it settles to face the target squarely at `settle_speed_dps` (60°/s). The rifle's sweep (40° right, 30° left) covers the gap while the body catches up.
  - It doesn't turn when the cursor is on top of the square, where there's no clear direction.
  - The aim point is read once per tick and shared by the body and the rifle.
- Tested on a copy with a fake mouse:
  - aim 90° right: facing −90 → −36 (6 ticks) → −12 (12 ticks) → 0 (settled), with the rifle leading;
  - aim behind: it turns to 90°;
  - walking up (W) while aiming right: velocity (0, −137) px/s (full speed straight up) while facing stays about 0°;
  - cursor on the square: no turn.
- Possible next step: a realistic speed penalty when backing up or strafing.

### 2026-10-28 — Squad and command mode
- Mike: add two squadmates identical to the player that idle naturally; holding C enters an RTS-style command mode (box or click select, then click to send them).
- **Restructure:**
  - `soldier.gd` / `soldier.tscn` hold everything a square is (from the old `player.gd`/`player.tscn`).
  - Subclasses override `_move_intent()`, `_aim_point()` and `_wants_to_fire()`.
  - `player.tscn` and `squadmate.tscn` inherit `soldier.tscn`.
  - Controls moved to `world.gd` (`register_controls()`, `commanding()`); added `command` = C.
- **Squadmates** (`squadmate.gd`, in the `squad` group):
  - States `IDLE` / `SHUFFLE` / `MOVE`.
  - Idle: every 1.5–5 s it either glances somewhere new (usually ±60°, sometimes ±135°) or shuffles to a spot within 0.25 m of its post at 35% speed.
  - Move order: walks there facing the way it's going, eases off over the last 0.3 m, and arrives within 8 cm, then makes that its new post and keeps looking the way it came.
  - Gives up after 1 s blocked (e.g. by another square).
  - Turns at 300°/s (the player turns at 540°/s).
- **Command mode** (`command.gd`, a node in `Main`):
  - Hold C. Left-drag box-selects; clicking a squadmate selects only it (Shift adds or removes); with a selection, left or right clicking the ground orders a move.
  - Several units line up 0.7 m apart across the direction of travel, sorted so nobody crosses.
  - HUD: a "COMMAND MODE" banner and a faint blue tint (mouse-transparent). Green rings on selected units (only while C is held), lines and dots to destinations, and a ping at each order.
  - Mouse positions are converted from the event, not the OS cursor, so the tests can drive it.
  - The player keeps walking but freezes its aim point and won't fire while C is held.
- Tested on a copy with real key, mouse-button and motion events:
  - 2 squadmates found, idling quietly;
  - box select → both selected; ground click → both ordered, destinations 59.7 px apart (= 0.7 m); after 6 s both within about 6 px of their spots;
  - click one → only it selected; ground click → only it moves; the other stays;
  - the player fired 0 shots during all command clicks;
  - screenshots show the banner, rings, destination lines and pings.
  - The test also showed an idle shuffle of 0.48 m after arriving, which is more than "a little", so the radius was cut from 0.5 to 0.25 m.
- Test gotcha: in a `-s` test script, `_ready` and group membership happen after the first frame, so wait a frame before looking up groups.

### 2026-10-28 — Talk waves; squad faces you in command mode
- Mike: when C is pressed, talk waves come out of the player and everyone faces him while in the mode.
- `command.gd`: while C is held, a white arc (±40° wide) leaves the player's front face every 0.3 s (the first immediately). Each grows from 0.28 m to 0.85 m and fades over 0.7 s. Arcs already in flight finish after C is released. The player is found through the new `player` group.
- `squadmate.gd`: while commanding, `_aim_point()` returns the player's position, so every squadmate turns to listen, even one walking under orders (it strafes). On release it carries on from its current facing (`_look_angle = facing`).
- **Bug fixed in `soldier._turn_toward`:** a square could hover exactly on the 15° comfort edge forever. It kept "swinging" to the edge and never started settling, which the test caught as a squadmate stuck at 15.0°. Now the slow settle is applied every tick after any fast swing. This applies to the player too.
- Tested on a copy, with both squadmates first turned 149° away:
  - C held 10 ticks: 95° off and turning; after 1 s, both 0.0° (facing the player);
  - waves spawning (3 in flight); a squadmate ordered to move while C was held walked at full speed still facing the player (1.3°);
  - 1 s after release it faced its travel direction (0.0°), and the waves had cleared.
  - The screenshot shows the arcs and both sight triangles pointing at the player.

### 2026-10-28 — Voice cone limits command mode; no remembered selection
- Mike's spec:
  - don't remember the selection between C presses;
  - replace the world tint with a cone out of the player that is the command width;
  - only units in the cone can be commanded or receive commands;
  - units outside can't hear, so they don't face the player.
- `player.gd`: new `voice_range_m` (8 m) and `voice_half_angle_deg` (40°), and `can_hear(point)` (within range and within ±40° of `facing`). The cone points where the player was aiming when C went down, since aim freezes in command mode. To address a different group, release C, aim, and press C again.
- `command.gd`:
  - The selection is cleared whenever C goes down or up.
  - The cone is drawn on its own ground layer (`z_index` −50, under the squares): a fan bright near the player, fading out, with edge lines.
  - The blue full-screen tint is removed, and the banner reads "only squadmates inside your cone can hear you".
  - Box and click selection only pick squadmates the player can hear, and anyone who walks out of the cone is deselected.
  - Move orders only go to points inside the cone; a click outside shows a red ping and does nothing.
  - Talk waves use the cone's angle.
- `squadmate.gd`: only faces the player while `can_hear(self)` is true.
- Tested on a copy, with one squadmate 2.9 m ahead (in the cone) and one behind (outside):
  - after 1 s with C held, the one ahead faced the player (0°) and the one behind didn't (90°);
  - a box around both selected only the one ahead; clicking the one behind gave a red ping and selected nothing;
  - a ground click outside the cone gave a red ping and no order; one inside sent the selected squadmate;
  - releasing C cleared the selection, and pressing it again started empty.
  - The screenshot shows the cone, the talk waves, the ring with its order line, and the red pings.
- Test gotcha: after a long pause (e.g. waiting for a screenshot), Godot runs several physics ticks back to back before the next `_process`. To check something done in `_process`, wait on `process_frame` too.

### 2026-10-28 — Fix: line-ups could reach outside the cone
- Mike: selected units could be moved outside the cone. He has also added two more squadmates in the editor (4 in total).
- Repro on a copy with all 4 selected, clicking at 9 spots:
  - clicks outside the cone (left, right, behind, beyond range, right-click, zoomed in) were all correctly refused;
  - **but a click just inside the cone's edge sent 2 of 4 to spots outside it.** The side-by-side line-up (0.7 m apart, about 2 m wide for 4) poked past the edge, because only the clicked point was checked.
- Fix: new `player.clamp_to_voice(point)`, which swings a point back in to just inside the cone's edge and within range. `command._order_move` applies it to every squadmate's spot. Re-run: 0 spots outside the cone in all 9 cases.
- Known side effect: near the edge, clamped spots can end up close together; the squares push apart on arrival.

### 2026-10-28 — Fix: destination clicks that didn't register
- Mike: sometimes he selects a squadmate but the destination click doesn't register.
- Repro (`test_lost`): select one squadmate, then click a destination. It failed in 3 of 5 cases:
  1. **A shaky click:** 12 screen px of mouse movement between press and release counted as a box drag. An empty box **cleared the selection** and nobody moved. (A 5 px wobble was fine.)
  2. **A click 25 cm from another squadmate** picked that one (pick radius 0.3 m) instead of ordering a move.
  3. **Cone drift:** after C went down, the player kept settling toward its aim (up to 15°), swinging the cone, so a selected squadmate near the edge could slip out and be deselected.
- Fixes:
  1. `command.gd`: a drag only box-selects if the box contains at least one squadmate that can hear; otherwise it's treated as a click where the button went down (`_box_has_listener`).
  2. `PICK_RADIUS_M` is now 0.24 (about the square's body), down from 0.3.
  3. `player.gd` overrides `_turn_toward`: no turning while commanding, so the cone stays exactly where it opened.
- Re-run: all 5 cases register. The cone regression (`test_reach`, which uses box selection) still passes, with 0 destinations outside the cone.
- Still by design: a destination click outside the cone is refused with a red ping. *(Reversed in the next entry.)*

### 2026-10-28 — Orders can send squadmates anywhere (reverses the cone limit on destinations)
- **My misread:** Mike's earlier "once selected they can be moved anywhere even if it's outside the cone" was a description of the behaviour he wants, not a bug report. The cone should limit **who hears and can be selected**, not **where they can be sent**.
- Removed:
  - the destination check in `command._order_move` (no more red "out of earshot" pings, and `REFUSE_COLOR` is gone);
  - `player.clamp_to_voice()` and its use on formation spots.
- Unchanged:
  - only squadmates inside the cone turn to listen and can be selected;
  - a selected squadmate that walks out of the cone drops out of the selection (it can't hear further orders);
  - the selection clears on C down or up;
  - the shaky-click, pick-radius and steady-cone fixes stay.
- Re-run on a copy: clicks left, right, behind and beyond the cone all order every selected squadmate. `test_lost` still registers all 5 click cases.

### 2026-10-28 — Orders menu: Follow me / Lead
- Mike: pressing C opens a transparent menu to the player's left with two options, built so more can be added. Clicking one makes the selected squadmates follow behind or in front of the player.
- **Menu** (`command.gd`):
  - Shown while C is held, positioned each frame just left of the player's square **on screen** (so the text never rotates), and kept on screen.
  - An "ORDERS" title plus one button per entry in the `ORDERS` list (`{id, text}`). To add an order, add an entry and handle its `id` in `_give_order()`.
  - Buttons are see-through dark with a green border, white text on hover, and dimmed and disabled while nobody is selected. `focus_mode` is none so keys don't press them.
  - GUI clicks don't reach the command click/box logic.
- **Formations** (`squadmate.gd`, new state `FOLLOW` with `follow_mode` "follow" or "lead"):
  - Slots are two abreast (0.9 m apart), rows 0.7 m apart, along the player's new `formation_heading`. That's `facing` smoothed at 90°/s, so sweeping the aim doesn't send followers running in circles.
  - Follow me starts 0.9 m behind; Lead starts 1.2 m ahead, clear of the muzzle. A lone member of a row is centred.
  - Members ease into their slot and stand still within 12 cm. They jog at 1.4× walking speed when more than 1 m out (new `_speed_scale` in `soldier.gd`).
  - In position they look along the player's heading; while catching up they look where they're going. Listening in command mode still overrides that.
  - `command._assign_formation_slots()` numbers each formation nearest-first and re-runs after every order, so a move order pulls a member out and the rest close up.
- **Steering** (`squadmate._steer`): squadmates bend around any square (player or squadmate) within 0.8 m that's in their way. This applies to move orders and formations.
  - The first test run showed why it was needed: a follower whose slot was on the far side of the player walked into the player and stopped 0.4 m in *front*.
- Tested on a copy (Mike's scene now has 3 squadmates):
  - the menu appears left of the player with buttons disabled while nobody is selected;
  - box-selected 2 → Follow me, 1 → Lead;
  - after the player walked right 3 s and stopped: followers at (−0.56, +0.90) m and (+0.34, +0.89) m, against slots (∓0.45, +0.9); the leader at (−0.11, −1.20) m, against (0, −1.2);
  - one follower given a move order leaves; the other closes up to the centre slot (+0.12, +0.90).
  - Screenshots show the menu and the formation.

### 2026-10-28 — Command aura
- Mike: a short circular aura around the player; anyone inside can be selected without being looked at.
- `player.gd`: new `aura_radius_m` = 1.5. `can_hear()` returns true for anything within the aura, whatever the facing, so squadmates there also turn to listen and can take orders. Otherwise the cone rule applies.
- `command.gd`: the aura is drawn on the cone's ground layer as a faint fill (alpha 0.08) with the cone's edge line. The banner now reads "only squadmates in your cone or close by can hear you".
- Tested on a copy, with the player facing up: 1 m behind → hears, faces the player, box- and click-selectable; 2 m behind (outside both) → doesn't hear, keeps looking away, not selectable; 3 m ahead (cone) → as before. The screenshot shows the circle and cone together.
- Note: clicking a squadmate who *can't* hear while others are selected counts as a ground click, so the selection is sent to that spot.

### 2026-10-28 — Disperse order
- Mike: a third menu item, Disperse, so squadmates can break away from Follow me or Lead.
- `command.gd`: added `{id = "disperse", text = "Disperse"}` to `ORDERS` (the first order added through the extensible list).
  - Like the other orders, it acts on the **selection**. Each selected squadmate gets a move order `DISPERSE_STEP_M` (0.9 m) out from the player, in its direction from the player ±`DISPERSE_JITTER_DEG` (30°) so they fan out, and stands at ease there. Anyone right on top of the player picks a random direction.
  - Formation slots are reassigned afterwards, so anyone still in formation closes up.
- Tested on a copy: 2 followers + 1 leader after a walk; box-selected all 3 (followers via the aura, leader via the cone) and clicked Disperse.
  - After 2.5 s all three were idle and out of formation, 1.0–1.2 m → 1.7–2.0 m from the player.
  - The followers' gap grew from 0.9 m to 2.1 m.

### 2026-10-28 — Menu orders don't need a selection
- Mike: pressing a menu item should apply to squadmates in the cone without having to select them.
- `command.gd`: new `_order_targets()` is the selection if there is one, otherwise **everyone who can hear** (cone or aura). `_give_order()` uses it, so Follow me, Lead and Disperse all work with nothing selected. The buttons dim only when nobody can hear and nothing is selected.
  - Selecting first still narrows an order to just those squadmates, so the squad can be split (e.g. some lead, some follow).
- Tested on a copy, with 2 squadmates in the cone and 1 behind out of earshot:
  - with nothing selected the buttons are enabled; Follow me put the 2 listeners into formation (slots 0/2 and 1/2) and left the third idle;
  - with everyone moved out of earshot, the buttons are disabled.

### 2026-10-28 — Bigger command aura
- Mike: make the circle about 65% larger. `aura_radius_m` 1.5 → 2.475 m (radius ×1.65). No scene overrides it, so the script default applies.

### 2026-10-28 — Space is the command key; steering fixes
- **Space replaces C** for command mode (`world.gd` `KEY_CONTROLS`), and the code comments are updated. Menu buttons already have `focus_mode` none, so Space can't "press" a focused button. Checked: holding C no longer enters command mode, holding Space does.
- **Steering bug found while checking that change:** a squadmate sent past the player could jam **corner-to-corner** against the player's square for ~0.5 s or more. The sideways push was only ~20% of its walking direction at that range, so it kept walking almost straight into the player, and `move_and_slide` can't slide off a corner at that angle. It only got free when the side-swap fired.
- Fixes in `squadmate.gd`:
  - `_steer`: the side push now grows from 0 at `AVOID_M` (0.8 m) to **2× the walking direction at contact**, so close up it mostly sidesteps.
  - **Stuck detection is now progress-based:** no 5 cm gain toward the destination in 0.7 s flips which side it passes obstacles on (`_detour`); none in 2 s gives up and makes the current spot its post. The old speed-based check missed squadmates that were pinned but still jiggling.
  - `_start_walk()` resets the tracking for move orders and shuffles.
- Re-run headless: the jam case now clears; walking past from four start positions keeps 0.54–0.72 m from the player (previously down to 0.42 m, touching); formations and Disperse are unchanged.
- **Test hygiene (see below):** windowed test runs pop up on Mike's screen and can take keyboard focus while he's playtesting. One run picked up his keypresses: the player moved and an order was lost. Logic tests now run `--headless`; windows only when a screenshot is needed.

### 2026-10-28 — Formation pop-out: Line / Column
- Mike: holding Follow me or Lead pops out an extended menu; hover Line or Column and let go to choose. Line's icon is 4 squares in a row; Column's is 4 squares in 2 columns of 2.
- `command.gd`:
  - `ORDERS` entries can set `shapes = true`. Those buttons open the pop-out on `button_down` instead of acting on `pressed`. New `SHAPES` list (`id`, `text`, icon `cells`), so more shapes can be added later.
  - The pop-out sits just left of the held button: one panel per shape with a drawn icon (7 px squares at the given cells) and a name. Hovering highlights a panel.
  - Hover and release are tracked in `_input` from event positions, because while a button is held the GUI keeps sending events to that button. The pop-out's controls ignore the mouse.
  - Let go on a shape → that order with that shape. A quick click (let go on the order button itself) → `DEFAULT_SHAPE` "column". Let go anywhere else → cancel. The pop-out closes when Space is released.
  - One shape per formation: choosing a shape re-forms everyone already in it. Slots are assigned nearest-first for a column and left-to-right across the heading for a line, so nobody crosses.
- `squadmate.gd`: `follow_shape` ("column"/"line"). In a line, everyone stands side by side in one row 0.9 m apart, centred, at the first-row distance (0.9 m behind / 1.2 m ahead).
- Tested headless with 3 squadmates:
  - hold Follow me → pop-out open; slide onto Line → hover "line"; let go → all follow/line. Settled at (−0.89, 0.79), (0.08, 0.82), (0.89, 0.79) m, against slots (−0.9, 0, +0.9) at 0.9 m behind.
  - hold Lead → Column → all lead/column, settled at (−0.48, −1.09), (0.40, −1.10), (0.05, −1.80), against (∓0.45, −1.2) and (0, −1.9).
  - a quick click on Follow me → follow/column; hold Lead and let go far away → unchanged, and the pop-out closed.
- One windowed screenshot: the pop-out beside Follow me with both icons and Line highlighted.

### 2026-10-28 — Helicopter asset (step 1 of insert/extract)
- Mike chose: **transport (Black Hawk-style)**, role **insert/extract the squad**, **real scale**. At 85 px/m that's about 1,700 px long with a 1,400 px rotor disc, close to the full arena width, so zooming out helps.
- **Blender** (`helicopter.py`):
  - Fuselage lofted from 14 rounded-box cross-sections (smoothed), with windscreen glass between the painted nose and the roof.
  - Roof fairing, two engine nacelles with outward-angled exhausts, sponsons and main wheels.
  - Swept vertical fin, 4.4 m stabilator, and the tail rotor as a translucent blur disc canted 20° on the starboard side.
  - 4-blade rotor with hub, swept tips and yellow tip bands.
  - **Lesson:** with the sun and camera both straight overhead, flat tops mirror the sun back at the camera. "Black" blades rendered pale grey until their specular level was cut to 0.08 (new `shine` parameter on materials).
- **Godot** (`helicopter.gd`, `helicopter.tscn`):
  - Rotate the node to set the heading.
  - `rotor_spin` (0–1): the blades turn (shown at up to 1.6 rev/s, since the real 4.3 rev/s strobes at 60 fps) and fade as a dark blur disc with a faint tip ring appears.
  - `altitude_m`: shadows slide away along the sun's direction, and the helicopter grows 1% per metre (closer to the camera).
  - `Hull` is a StaticBody2D with a 15-point fuselage outline, so squares can't walk through it.
  - Z order: shadows −10 (under squares), body 5, rotor disc 19, rotor 20.
- **Shadows** (new `shaders/shadow_sweep.gdshader`):
  - **First attempt:** the body outline stacked at 6 heights showed staircase edges, and thin high parts (the stabilator) smeared into a big wedge.
  - **Final:** per-part outlines, each swept in one shader pass (24 samples) across that part's own height range: body 0.1–3.25 m, stabilator 1.95–2.05, fin 1.9–4.3, tail rotor 1.85–5.15. Plus the rotor blade and disc shadows at 3.6 m. All are in one `CanvasGroup` at alpha 0.71, so overlaps don't double-darken.
- Placed in `main.tscn` at (1150, 230), nose right, rotor idling (`rotor_spin` 0.35), clear of the squad. Mike now has 6 squadmates on the left.
- Tested on a copy: loads cleanly; a squadmate walked into the fuselage stops at its side (119 px from the centre line against a ~102 px half-width). Screenshots parked and at 12 m: smooth swept shadow, crisp tail-plane shadow, blade shadows, and a shadow displaced ~10 m when airborne.
- **Next:** insert/extract behaviour.

### 2026-10-28 — Deployable comms station (asset only)
- Mike: loved the helicopter scale. Next, an asset (not added to the game) for a deployable radio tower with a small antenna, a satellite dish and a laptop.
- `radio_station.py` builds and renders it at real size (see the Asset List). It's a static prop, so it uses the world's top-left sun and a separately rendered shadow (shadow catcher, normalised to the 0.71 open-ground level), as the squares do.
- **Lesson:** the shared sun is 8° wide, which keeps character shadows soft, but at that width a 12 cm × 7 m mast's shadow blurs away completely (the penumbra outgrows the mast within about a metre). This prop overrides it to 1° (the real sun is about 0.5°), so the mast, guy wires and dish post cast long, crisp shadows. Thin, tall objects need this override.
- Reviewed as a composite on the grass tile (`assets/previews/radio_station_preview.png`): every piece reads at normal zoom; the laptop screen and dish are clearest when zoomed in.
- To use it later: two `Sprite2D`s at scale 0.5 (shadow below with modulate alpha 0.71 or in a shadow group, station above). If it should block movement, add collision for the cases, dish and mast base.

### 2026-10-28 — Better laptop on the comms station
- Mike: do a better job on the laptop. The old one was a few flat boxes.
- New `build_laptop()` in `radio_station.py`, modelled as a rugged field laptop at real size (0.34 × 0.27 m):
  - gunmetal shell, rubber corner bumpers on base and lid, front carry handle, hinge barrels, side port covers, three green status lights;
  - a keyboard of individual keys (5 rows + spacebar, one mesh), a touchpad with buttons;
  - a thick lid with bezel, webcam and latch, **opened 45° past upright** so the screen faces up toward the camera;
  - a mouse on the case, cabled to the side port.
- **Screen content** is generated in the script (`screen_image()`, 640×400, packed into the .blend): a mapping app with a dark topographic map (contours, high-ground tint, 64 px grid), a dashed yellow route from three blue friendly markers to a red objective, a status bar, and a side panel with text lines and green signal bars. It's emissive, so it glows.
- New review render `assets/previews/radio_station_laptop_closeup.png` (8× density, laptop and case with shadows).
- Checked at game zooms: at 1× it reads as a laptop with a lit map; at 3× the route, keys, bumpers and lights are visible.

### 2026-10-28 — DEPLOY menu: place a radio station
- Mike: in command mode, a second set of items on the right called Deploy. The player starts with one radio station. Holding the item shows the station in a pop-out (like Line/Column); choosing it gives a transparent ghost to place with a click, which must be inside the command circle.
- `command.gd`:
  - A **DEPLOY** column right of the player (mirroring ORDERS on the left) with an **Equipment** button.
  - Holding Equipment opens a pop-out to its right listing `DEPLOYABLES` ("Radio station x1", with a drawn mast-and-waves icon). Items at x0 are greyed out and can't be chosen, and the button dims once everything is used.
  - Choosing an item starts **placement**: an instance of the item's scene used as a ghost (collisions off, processing off) follows the mouse.
    - Tinted green inside the command aura and red outside; the aura's edge brightens while placing.
    - Left click inside places the real scene into `Main` and decrements the player's count. Left click outside gives a red ping and nothing else. Right click or releasing Space cancels.
  - **Pop-out code generalised:** new inner class `PopOut` and `_open_popout(popout, button, choose, default)`, shared by the formation shapes (opening left) and deployables (opening right). Hovering is still worked out in `_input` from positions.
  - Pings can carry a colour again (red for refused placement).
- `player.gd`: `@export var deployables := {"radio_station": 1}`. The editor has since saved this into `main.tscn`.
- New `scenes/radio_station.tscn`:
  - shadow (z −10, alpha 0.71) and station (z 4), both scale 0.5 with mipmapped filtering. The `.import` files were pre-written with `mipmaps/generate=true` before Godot first saw the PNGs, and the setting survived the import;
  - a StaticBody2D with collision on the transit case, radio case, dish tripod and mast base (positions from the Blender layout, with y and rotation signs flipped).
- Tested headless on a copy:
  - the pop-out opens with "Radio station x1"; hovering and letting go starts placing, with a ghost;
  - ghost at 4.7 m → red, click refused (still carried 1); at 1.9 m → green, click places it exactly at the cursor; then carried 0, placement ended, Equipment disabled;
  - a squadmate sent onto the transit case is stopped by it;
  - Follow me → Line still works through the shared pop-out (2 squadmates in earshot).
  - Screenshots show the DEPLOY menu, the ghost in the aura, and the placed station with shadows. The ghost was too faint, so its alpha went 0.5 → 0.7 (0.6 when red).
- Noted in Mike's scene: a second helicopter (`Helicopter2`) near the left edge.

### 2026-10-28 — Station: operator platform and desk
- Mike: where the laptop was, put a square platform and a desk with a radio, the laptop and other equipment, at the right scale. The operator must stand in that box to work the radio (operation itself comes later).
- `radio_station.py`:
  - **Removed** the ground radio case and the transit case.
  - **Platform** (`build_platform`): 2 m × 2 m, 0.12 m high, centred 3 m east of the mast, between two guy wires (they pass well clear above it). Ten planks with slight tint variation on three joists, with a darker frame.
  - **Desk** (`build_desk`): a 1.4 × 0.6 m folding field table, 0.75 m high, at the deck's east edge, turned so the operator faces it from the mast side. On it:
    - a field radio lying flat with its controls on top (green LCD, 12-key keypad, two knobs, carry handle) and the **1.2 m whip antenna**, with a handset on a coiled cord;
    - the rugged laptop (`build_laptop` now takes a `parent`) and mouse, its screen toward the operator;
    - a power unit with green and red LEDs and terminals, cabled to the radio and laptop;
    - a headset, a ruled notebook with a pen, and a mug of coffee.
  - **Cables** run off the desk across the deck and continue over the ground to the mast and the dish. Deck and ground runs meet exactly at the deck edge; a gap there showed in the first render.
  - `cable()` takes a `z` for surfaces above the ground. The close-up is now `assets/previews/radio_station_desk_closeup.png` (the platform at 8× density).
- `scenes/radio_station.tscn`:
  - collision is now the **desk** (plus the dish and mast base); the platform is walkable;
  - new **`OperatorZone`** Area2D covering the 2 m platform, ready for "stand here to operate". Nothing uses it yet.
- Tested headless: the player walked east onto the platform, stopped against the desk (17 px from its edge = half a square), and `OperatorZone.overlaps_body(player)` went false → true.

### 2026-10-28 — Stand box; deck drawn under the squares
- Mike: the platform needs a light green box showing where to stand. Also, walking onto the platform drew it *over* his square instead of under.
- **Cause:** the whole station was one sprite at z 4, above the squares.
- **Fix:** the station now renders as two layers (`radio_station.py` `GROUND_PARTS`):
  - `radio_station_ground.png` (deck planks, joists and frame, ground and deck cables, stakes and flags) at **z −5**, under the squares;
  - `radio_station.png` (desk and equipment, mast, dish, guy wires) at **z 4**, over them.
  - Each layer is rendered with the other layer's parts still in the scene but invisible to the camera, so shadows are kept (the desk's shadow stays baked onto the planks).
  - The ground layer's `.import` was pre-written with mipmaps, which survived the import.
- **Stand box** (`StandBox` Polygon2D + `StandEdge` Line2D in `radio_station.tscn`, z −4): a light green fill (alpha 0.22) with a brighter 2 px outline, 1.1 m × 1.7 m, filling the deck between its open edge and the desk.
- `OperatorZone` now matches the stand box exactly (it used to cover the whole platform), so what's shown is what counts.
- Tested on a copy: the zone is false off the platform and true standing at the desk. A zoomed screenshot shows the square drawn over the deck and green box, with its rifle passing under the taller desk.

### 2026-10-29 — Dish tuning wheel
- Mike: add another green box by the satellite dish. Standing there and pressing F opens a wheel with a line; the dish turns with the line, and a very big cone comes out of the dish along it. This is how the system is tuned; radio soldiers for long-range comms come later.
- **Dish split out** (`radio_station.py`):
  - The turning parts (`DISH_PARTS`: dish, feed arm, feed) are left out of the station images and rendered alone as `assets/props/radio_station_dish.png` (2.4 m at 2×, centred on the post, built facing south), **lit from straight overhead** so the game can rotate it freely.
  - The tripod and post stay baked into the station.
  - The station's baked shadow no longer includes the dish.
- **`scripts/radio_station.gd`** (new; the station scene's script):
  - `DishZone` Area2D and a green `DishStandBox` (1.0 × 0.9 m) just south of the dish, with a "[F] Tune dish" label shown while the player stands in it.
  - **F** (new `interact` action in `world.gd`) in the box opens the **tuning wheel**: a ring drawn around the dish on screen with 15° ticks, N/E/S/W marks, an `AZ ###` compass readout, and a white line showing the heading.
  - While tuning, the mouse sets `dish_heading` (the angle from the dish to the mouse). The `Dish` sprite rotates to match, and its shadow (`DishShadow`, `shadow_sweep` shader swept 0.7–1.45 m) rotates and re-sweeps with it.
  - A **beam** is drawn while tuning: a 60 m cone (±9°), fading out, with edge lines.
  - Left click or F locks the heading and closes the wheel. Stepping out of the box or entering command mode also closes it. `dish_tuned(heading)` is emitted; the heading persists for the comms system to come.
- `player.gd`: new `busy` flag. While it's set, the player keeps its last aim and won't fire, so the wheel can use the mouse.
- `shadow_sweep.gdshader`: new `opacity` uniform (default 1, so the helicopter is unchanged); the dish shadow uses 0.71.
- Tested headless on a copy:
  - the prompt shows in the box; F → tuning, beam visible, player busy;
  - mouse east → heading 0°, sprite −90°; mouse north-west → −135°;
  - click → locked, `dish_tuned(−135°)` emitted, player freed;
  - F away from the box does nothing; walking out while tuning closes it.
- Screenshot: the wheel with the line and AZ 315, the dish turned north-west with its shadow, and the beam across the field. The AZ readout then moved inside the ring, away from the stand box.

### 2026-10-29 — No shot on the lock-in click; wider beam
- Mike: clicking to set the dish shouldn't make the player shoot. Make the cone 200% wider.
- **Bug:** the left click that locks the dish heading set `player.busy = false` straight away, so on that same frame the player saw `shoot` just pressed and fired.
- **Fix** (`radio_station.gd`): `_stop_tuning(by_click)` keeps the player busy and sets `_free_player_on_release`; `_process` frees the player once the left button is up. Closing with F or by walking out frees it at once, as before.
- Beam `BEAM_HALF_DEG` 9° → **18°** (2× as wide, 36° across), reading "by 200%" the same way as the earlier "300% farther" (×3).
- Tested headless: lock-in click held 20 ticks → 0 shots, and the player is freed after release; the next normal click → 1 shot; the Deploy placement click (command mode) → 0 shots.

### 2026-10-29 — Dish beam also shows in command mode
- Mike: pressing Space should also show the satellite cone.
- `radio_station.gd`: the beam is visible while tuning **or** while commanding (`_process` sets it each frame; start/stop no longer toggle it), so every deployed station shows where its dish points while the player gives orders. The placement ghost's processing is off, so it never shows a beam.
- Tested headless: idle → hidden; Space held → shown (ghost's hidden); Space released → hidden; tuning → shown.
- Then: the beam is now the **same green as the command shapes**. New `World.COMMAND_COLOR` (0.45, 1, 0.45), used by `command.gd` `COLOR` and by `radio_station.gd` `BEAM_COLOR` and `WHEEL_COLOR` (the beam was a mint green before). Checked headless: the scripts load, and both colours read (0.45, 1, 0.45).

### 2026-10-29 (morning) — Radio terminal: radio command and troop requests by helicopter
- Mike: at the radio terminal, F opens a menu like Space's with **Deploy** and **Command**.
  - **Command** = radio command mode: every squadmate hears you, wherever they are.
  - **Deploy**: hold for Troops / Vehicles. Let go on Troops for a slider up to 10; confirm for that many boxes (5 over 5 for 10). Press a box for a unit-type sub-menu (Infantry only). Each filled box readies in 30 s. When finished, a ghost helicopter marks the LZ, and a click flies the helicopter in: it lands, drops the troops, and they disperse, then it rises and flies away.
- Mike's `main.tscn` now has no squadmates or helicopters (Field, Player, Camera, Command only), so troops arrive from the terminal.
- **Refactor first** (no behaviour change):
  - `scripts/ui_style.gd`: shared menu look, pulled out of `command.gd`.
  - `scripts/hold_popout.gd`: the press-hold-slide-release pop-out, now a reusable `VBoxContainer`. It emits `chosen(id, at)`, a quick click on its button picks a default, and options can be disabled.
  - `command.gd` uses both, and its old internal `PopOut` class is gone.
  - Regression checked headless: equipment deploy, Follow me → Line through the new pop-out, and the no-accidental-shot tests all pass.
- **Radio command mode:**
  - `world.gd` has a new `static var radio_commanding`, and `commanding()` is now true while it's set or Space is held.
  - `player.gd`: `can_hear()` is true for everyone over the radio; the old voice check is now `hears_voice()`.
  - `squadmate.gd` turns to face the player only on `hears_voice()`.
  - `command.gd`: no voice cone, aura or talk waves over the radio, and the banner reads "RADIO COMMAND ... [F] hang up".
- **`scripts/radio_terminal.gd`** (new `Terminal` node in `radio_station.tscn`):
  - Screens: CLOSED, MENU (the RADIO column left of the player), COUNT (slider panel), SLOTS (request panel), LZ (ghost placement).
  - The player is `busy` while it's open, and freed only once the left button is up (no shot from the closing click).
  - It closes on F, Esc, stepping off the box, or entering Space command mode. Radio command is owned by the terminal that started it and hangs up if the player leaves the box.
  - The request (`slots`, `_progress`, `_queue`) readies filled slots sequentially, `seconds_per_troop` (30) each, and persists while away. Slots draw "+" when empty, and the infantry icon with a rising green fill when filled (bright border when ready). Status shows "n of N filled - ready in m:ss" / "n ready - send the helicopter". **Clear** discards the request.
  - LZ: a ghost `helicopter.tscn` (processing, hull and shadows off) follows the mouse, green inside `World.ARENA` and red outside; right click or Esc goes back to the request.
- **`scripts/insertion.gd`**, attached to a new helicopter by the terminal:
  - Comes in from 70 m west at 25 m altitude, nose east. It slows near the LZ and descends over the last 45 m, landing exactly on the LZ.
  - Settles for 0.8 s, then unloads a trooper (`squadmate.tscn`) every 0.35 s from alternating side doors. Each faces out and moves 6 m out from the fuselage, spread along it.
  - Waits 2.5 s, climbs for 4 s, flies east, and is freed 80 m past the LZ.
  - The hull collides only while it's on the ground.
- **Bug caught by the test:** the terminal's `request_ready()` clashed with Godot's built-in `Node.request_ready()`, a parse error that would have broken the station scene. Renamed to `troops_ready()`. **Don't name methods after built-ins** (`request_ready`, `ready`, `process` and so on).
- Tested headless (readying shortened to 0.5 s):
  - F → menu, player busy. Command → radio on; a squadmate 17 m behind is commandable but doesn't hear the voice; the banner is right. F → off.
  - Hold Deploy → Troops/"Vehicles (soon)" → Troops → slider 7 → Confirm → 7 slots in 5 columns.
  - Filled with a quick click, a hold-and-slide, and a second-row click → "3 of 7 filled - ready in 0:02"; then "3 ready", Send enabled.
  - Send → LZ ghost: red off the arena (a click there is ignored), green inside → click → helicopter sent, menu closed, request cleared, player freed.
  - Flight: landed exactly on the LZ at 5.8 s; 3 troopers out by 7.4 s (squad 1 → 4); climbing at 9.9 s; gone at 16.9 s; hull solid only while landed.
- Screenshots (window): the RADIO menu; radio command (banner, menus, no cone); the slider; slots readying; the LZ ghost; troopers unloading beside the landed helicopter.

### 2026-10-29 — Big "F" on interaction pads
- Mike: while standing on an interaction pad, show a big white bold F centred on it, so it's clear F is the interact key.
- `UiStyle.pad_key()` builds the label: the default font emboldened, 64 px, white with a dark outline, z 30, so it draws over the player rather than hiding under it. It's centred on the pad's origin.
- The terminal adds one to `StandBox` (export `pad_path`). It shows while the player is on the box, the menu is closed and the radio isn't in use.
- `radio_station.gd` adds one to `DishStandBox`. It shows with the "[F] Tune dish" prompt, so not while tuning.
- Any new interaction pad should reuse `UiStyle.pad_key()`.
- Tested in a window: the right F shows on each pad, hides while the menu is open, and hides off the pads. Screenshots checked.

### 2026-10-29 — Dish: pick the heading first, then it turns slowly
- Mike: when tuning, you first select the heading and the dish shouldn't follow the mouse. Once it's selected, the dish rotates to it nice and slow.
- `radio_station.gd`:
  - The mouse now sets only `_pick` (the white line on the wheel). A short green line shows the dish's current heading, and the AZ readout is for the pick.
  - A left click or F locks the pick in: `target_heading = _pick`, `turning = true`. Walking off or pressing Space closes the wheel without locking anything in.
  - `_turn()` goes the short way round. It winds up at 10°/s² to 12°/s (`TURN_DEG_PER_S`), and slows near the end (speed ≤ 1.2 × degrees left).
  - `dish_tuned` is now emitted on **arrival**, not when the wheel closes.
  - The beam follows the real dish, and also shows while it's turning.
- Tested headless: moving the mouse east and then north-west left the dish at 90°. The lock-in click started a turn to −135°: 107° at 2 s, 179° at 8 s, arrived at 13.9 s, then emitted `dish_tuned(-135)` and hid the beam. The no-shoot test still gives A 0 / B 1 / C 0. The windowed screenshot shows the white pick line NW with the dish and beam still south.

### 2026-10-29 — Helicopter at half size, pilots visible through the glass
- Mike: the helicopter is too big; scale it down "just right". Make the cockpit windows slightly transparent so you can see two square guys next to each other in the cockpit.
- Read "just right" as: sized so the cockpit is just wide enough for two 0.4 m squares side by side. The real cockpit is about 2.3 m wide, so **`SCALE` = 0.5**: 7.7 m long, 8.2 m rotor (was 15.3 / 16.4).
- **Blender** (`helicopter.py`):
  - Everything is still modelled at real size; `scale_down()` shrinks the finished parts about the origin, and every frame is multiplied by `SCALE`.
  - `build_pilots()` adds two red squares, the same bevelled block as `character_square.py` but not scaled. They sit at x 3.0 m, y ±0.25 m (game size).
  - Cockpit glass: alpha 0.4, a slightly lighter blue-grey tint.
  - The old images are backed up in the session scratchpad only (no git yet).
- **Godot**:
  - `helicopter.gd`: new `SCALE` const; the mast, rotor radius and height, shadow height ranges, hull outline and rotor ring all multiply by it.
  - `insertion.gd`: door positions × `SCALE`; troopers now step out 0.9 m from the centre line (hull half-width 0.6 + a half square).
- Tested on the copy (reimported): the full terminal flow passes. It landed exactly on the LZ at 5.8 s, unloaded 3, and was gone at 16.9 s. Screenshots: the LZ ghost and the unloading helicopter at the new size, with both pilots clearly visible.

### 2026-10-29 — Pilots read as player-sized; glass less see-through
- Mike: scale it more so the squares are the same size as the player; decrease the transparency by 30%.
- The pilots were already 0.4 m like the player, but read smaller because the tinted glass darkens their bevelled edges. Mike chose "bigger-looking pilots" over shrinking the helicopter further.
- Glass alpha 0.4 → **0.58** (60% see-through → 42%).
- Pilots 0.4 → 0.45 m looked too big beside the player; **0.42 m** (y ±0.245) matches. Checked by compositing the cockpit crop next to the player's sheet frame on grass: both show about 33 px of red.
- Only `helicopter.py` changed (re-rendered); the Godot side is unchanged.

### 2026-10-29 — Cockpit detail, darker glass; 10 fixed slots and a pad timer
- Mike: the pilots' border breaks immersion, and they still don't look scaled with the player. Sit them further back, make the glass 15% darker, and add a control panel in front of them with slight details. In the terminal, drop the slider (always 10 slots; fill fewer for fewer troops), and show the total time left outside the interaction square when you're not in the menu.
- **Helicopter** (`helicopter.py`):
  - Pilot bevel 0.035 → **0.008**. Lit from straight overhead under tinted glass, the rounded edge read as a dark border and made them look smaller.
  - Without the border, 0.42 m read bigger than the player, so they're back to the player's true **0.40 m**. Composited beside the player sprite: about 34 px of red against 33.
  - Pilots moved back, x 3.0 → **2.84** m.
  - Glass 15% darker: tint × 0.85, alpha 0.58 → **0.64** (36% see-through).
  - New `build_cockpit()`: a dark instrument panel (x 3.10–3.30, ±0.42 m wide) with a green-lit screen in front of each pilot and a small middle one; amber/green switch strips on its front edge; a centre console between the seats with four lamps (amber, green, amber, red).
- **Terminal** (`radio_terminal.gd`):
  - The COUNT screen and slider are gone (`Screen` is now CLOSED, MENU, SLOTS, LZ). Troops always opens `MAX_TROOPS` (10) slots in rows of 5; `_new_request()` builds them, and Clear calls it again (it no longer returns to RADIO). The 10 slot buttons are built once.
  - New pad timer: a green outlined label centred just above the StandBox, z 30. It shows only while the menu is closed and something is filled: "N troopers  m:ss" (total time left, via the new `_clock()`), then "N troopers READY". It shows from anywhere, not just on the box.
- Tested (windowed): Troops → 10 slots / 5 columns. 3 filled → "3 of 10 filled - ready in 0:02". Closed → pad timer "3 troopers  0:01", still shown off the box, then "3 troopers READY". Reopened → timer hidden, Send enabled. LZ and insertion unchanged (landed on the LZ at 5.8 s, 3 unloaded, gone at 16.9 s); timer hidden after sending. Screenshots: the 10-slot panel, the pad timer, and the cockpit (panel, screens, lamps) in game.

### 2026-10-29 — Helicopter 10% bigger so the pilots read as closer to the camera
- Mike: the pilots look slightly smaller than the player. Make the helicopter bigger so they're 10% bigger than the player; they sit higher up, closer to the camera.
- `SCALE` 0.5 → **0.55** in `helicopter.py` and `helicopter.gd`. The cockpit (pilots, panel, console, lamps) was in fixed game metres; it's now laid out for `COCKPIT_AT_SCALE` = 0.5 and grown by `SCALE / COCKPIT_AT_SCALE`, so the pilots are 0.44 m and the cockpit keeps its fit.
- Measured: pilots about 37 px of red against the player's 33. The full terminal test still passes at the new size (landed on the LZ at 5.8 s, gone at 16.9 s); the in-game screenshot shows the pilots slightly bigger than the troopers.

### 2026-10-29 — Pilots' corners rounded; glass darker again
- Mike: round the pilots' corners just like the player; decrease the transparency by another 40%.
- `helicopter.py`: only the pilots' four **upright** edges are rounded, at the player's 0.035 m (`PILOT_CORNER_M`, × 1.1 with the cockpit). From above the outline matches the player's, but the top edges stay sharp, since a rounded top edge under the overhead light and glass is what read as the dark border. `PILOT_BEVEL_M` is gone.
- Glass alpha 0.64 → **0.78** (36% see-through → 22%). The pilots now read as dark maroon squares behind the tint.
- Checked by compositing beside the player's sprite.

### 2026-10-29 — Glass darker again
- Mike: decrease the transparency by another 30%. Glass alpha 0.78 → **0.85** (22% see-through → 15%), in `helicopter.py`; re-rendered.

### 2026-10-29 — Pilots move a little
- Mike: give the pilots some slight movements to give them some life.
- The pilots were baked into the body image, so the cockpit is now three layers:
  - `helicopter_body.png`: the glass is invisible to the camera (a Light Path "Is Camera Ray" mix to Transparent, `camera_sees_through()`) but still dims the light inside. The pilots are left out of this render entirely, so no black shadow is baked under them to show when they move.
  - `helicopter_pilot.png` (56 px): the port pilot alone, lit through the glass as it sits.
  - `helicopter_glass.png`: just the glass, with the rest of the fuselage held out.
- **Lesson:** stacking the layers happens after Blender's view transform, so glass at the material's 0.85 came out darker than a single render. `GLASS_OVERLAY_ALPHA` = 0.78 for the glass image matches the approved single render (pilot pixel 49,46,54 against 54,45,53). The material stays at 0.85 for the light.
- `helicopter.gd`:
  - `_add_cockpit()` adds two pilot sprites, then the glass, as children of `Body`, so they turn and grow with it.
  - `_move_pilots()`: a slow sway (±3°, two sines) and a seat shift (±1.5 cm). Each pilot also has its own random timer: every 2.5–7 s a glance of 10–28° to either side, held 0.6–1.8 s, eased at rate 6/s.
  - The LZ ghost (processing off) shows them still.
- Tested: 20 s headless gave rotations of about −17..3° and −18..2° with 1–2 glances each. Zoomed windowed screenshots show both pilots at different angles under the glass, with the panel's screens glowing. The terminal test still passes.

### 2026-10-29 — Unit pop-out opens left of the request panel
- Mike (with a sketch): holding a "+" in TROOP REQUEST should open the unit sub-menu to the left of the whole panel, top-aligned, not beside the slot.
- `hold_popout.gd`: `open(source, default, beside := null)`. With `beside` it opens beside that control (left or right per `side`), top-aligned with it; otherwise it's centred on the button as before. Command mode is unchanged.
- `radio_terminal.gd`: the unit pop-out opens to the left (`-1`) of `_slots_panel`.
- Tested: pop-out right edge 10 px left of the panel, tops level (520 = 520); hold-and-slide and quick clicks still fill slots; the rest of the terminal test passes. Windowed screenshot checked.

### 2026-10-29 — Dish beam: hidden while turning, drawn like the voice cone
- Mike: when the satellite moves, don't show its cone unless Space is pressed; make it the same colour and transparency as the player's command shapes.
- `radio_station.gd`: `_beam.visible = tuning or World.commanding()` (no longer `or turning`).
- `_draw_beam()` now draws like `command.gd _draw_cone()`: fill 0.16 at the dish fading to 0.03, edges and rim at 0.35, 1.5 px. It was 0.3 fading to 0 with brighter 2 px edges and no rim.
- The cone alphas moved to `world.gd` (`CONE_NEAR_ALPHA`, `CONE_FAR_ALPHA`, `CONE_EDGE_ALPHA`); `command.gd` aliases them, so the two can't drift apart.
- Tested: while the dish turns, no beam; Space held shows it; release hides it. The full dish test passes. Windowed screenshot: the cone and beam look alike.

### 2026-10-29 — New unit: radio operator
- Mike: a new unit, a radio unit: the same square and colour, with a brown backpack with an antenna on it.
- **Asset** (`blender/scripts/radio_pack.py`, new): built like the rifle, as a separate overhead-lit sprite, so the square's 30-frame body sheet is unchanged.
  - Brown pack on the square's back with a darker flap and side pouches, straps forward over the square's top, the radio's top with knobs, and a whip antenna raked back.
  - The first antenna (0.8 m at 38°) stuck out 0.5 m behind from above, which looked too long; it's now 0.6 m at 32°, and the pack is a bit deeper.
- **Godot:**
  - `soldier.gd`: new `@export var kit := ""`; `"radio"` adds `RadioPack` in `_ready` (after Body, so it's drawn over it) and updates it in `_update_visuals` with the facing and hop. Any square can wear it.
  - `radio_pack.gd` (new): the pack sprite (scale 1/4, mipmaps) plus a black copy in the square's Shadows group, offset by 0.35 m + hop along the sun.
  - `radio_terminal.gd`: `UNIT_TYPES` gains `radio` ("Radio"). `_draw_infantry` became `_draw_unit(canvas, unit, ...)`: the radio icon adds a brown pack and an antenna below the square, shifted up 4 px so it fits the pop-out row. Sending passes the unit type of each filled slot, in fill order.
  - `insertion.gd`: `start(heli, lz, unit_types: Array)` (was a count). `_unload_one` sets `kit = "radio"` for radio troopers.
  - Radio operators behave exactly like infantry for now: a carrier for the long-range comms still to come.
- Tested (windowed): slid onto Radio for slot 2 → `["infantry", "radio", ..., "infantry", ...]`. The helicopter unloaded 3, and the squad's kits are `[-, -, radio, -]`. Zoomed screenshot of the radio trooper (pack, straps, antenna, shadow); pop-out and slot icons checked after the shift.

### 2026-10-29 — Radio operators relay command: the command structure
- Mike: while the radio station's command cone (the dish beam) covers a radio operator, they can be controlled. The radio operator has a command circle twice the size of the player's, and any unit inside it can also be commanded. "This game will show the importance of communication infrastructure in battle."
- Radio command mode no longer reaches everyone. `player.gd can_hear(point)` = `hears_voice(point)` or (radio command and `radio_reaches(point)`):
  - `linked_radio_operators()`: squad members with `kit == "radio"` that the station in use's `beam_covers()`.
  - `radio_reaches(point)`: within `radio_circle_m()` (`aura_radius_m × RADIO_CIRCLE_SCALE` 2.0 = 4.95 m) of a linked operator, which includes the operator itself.
  - Selection, orders and "walked out of earshot" all go through `can_hear`, so nothing else needed changing.
- `radio_station.gd beam_covers(point)`: within `BEAM_LENGTH_M` of the dish and `BEAM_HALF_DEG` of `dish_heading`. It uses the dish's actual heading, so a turning dish moves the link with it.
- `world.gd`: `static var radio_station`, set by the terminal's Command and cleared on hang-up. Only the station you're on carries the link.
- `command.gd`: in radio mode the voice cone, aura and talk waves now show (the voice still counts). `_draw_radio_circles()`: linked operators get an aura-style filled circle; unlinked ones a dashed outline (alpha 0.3). The first try, a solid 0.12 outline, couldn't be seen on the grass. The banner explains the rule.
- Decisions taken (easy to change): one hop only (an operator's circle doesn't link another operator out of the beam); operator circles only matter over the radio, not in Space mode.
- **Test gotcha:** the arena (then 22.5 × 12.7 m, now 45 × 25.3 m) is smaller than the 60 m beam. Test units placed outside it get clamped in, and a player clamped off the desk pad hangs up. Lay tests out inside `World.ARENA`.
- Tested (`test_comms.gd`, windowed): dish east; operator in the beam, infantry 4 m and 7.2 m from it, a second operator out of the beam with infantry 2 m away.
  - Space only: all false.
  - Radio: `[true, true, false, false, false]`.
  - Dish swung onto operator 2: that operator and the units within 4.95 m of it become reachable, and operator 1 drops out.
  - Hung up: all false.
  - Screenshot: beam, solid linked circle, dashed unlinked circle, banner.
  - Regressions: terminal (a far squadmate is no longer reachable by radio, as intended), deploy and no-shoot all pass.

### 2026-10-29 — Map twice as big, with an edge barrier
- Mike: make the map 100% bigger and add line barriers for the edge. Read as ×2 each way (the old "X% = ×X/100" reading would mean no change here).
- `world.gd`: `ARENA` 1920×1080 → **3840×2160 px (45 × 25.3 m)**. Everything uses it: movement clamps, camera, bullets, the LZ check. The grass tiles itself (`field.gd`).
- New `scripts/arena_edge.gd`, as an `Edge` node in `main.tscn` (z −50: over the grass, under squares). It draws a light boundary line with a thin dark under-line, dark posts every 4 m, and dims the ground outside (black 0.3).
- `game_camera.gd`: the view now stays inside the arena grown by `EDGE_VIEW_M` = 2 m, so the barrier is visible instead of sitting exactly on the screen edge. `min_zoom` 0.5 → **0.43**, so fully zoomed out shows the whole arena and its barrier.
- The player still starts at (1137, 555), now in the top-left quarter. Not moved, since it's Mike's placement.
- Tested (windowed): zoomed all the way out the whole bordered field fits; walking into the top-left corner stops at (17, 17), half a square in; screenshot at 1x near the corner. Terminal (LZ red outside, green inside, insertion) and comms tests pass.

### 2026-10-29 — Radio command zooms out to an RTS overview
- Mike: when you hit Command, zoom out to take in every unit with some margin, like a typical RTS command view.
- `game_camera.gd`: while `World.radio_commanding`, the camera fits the player plus every squad member, grown by `OVERVIEW_MARGIN_M` = 4 m. It eases its zoom (never closer than your own zoom, never past `min_zoom`) and pans (`move_ease` 5) onto the group's centre, still kept inside the arena + 2 m, and keeps tracking as units move. The wheel is ignored meanwhile.
- On hang-up it restores your zoom, eases back to the player, then snaps to following exactly once within 1 px.
- Tested (`test_overview.gd`, windowed): zoom 1.4 at the desk with 3 squadmates spread across the map → Command → zoom 0.47 with every unit at least 2 m inside the view (screenshot) → hang up → zoom 1.4, centred on the player, following again. Terminal test passes.

### 2026-10-29 — Player arrives by helicopter; troop cooldown 5 s for testing
- Mike: when the game starts, have the helicopter drop the character off where he's placed; reduce all cooldowns to 5 s for testing.
- New `scripts/arrival.gd`, as an `Arrival` node in `main.tscn`. At start it sends a helicopter (`insertion.gd`) with the player aboard, landing at `player.position - Insertion.first_out_offset()` so the front starboard door's exit spot is exactly the Player's placed position. `enabled` turns it off.
- `insertion.gd`: `start(heli, lz, unit_types, riders = [])`. Riders are squares already in the scene: hidden and `PROCESS_MODE_DISABLED` (which also takes them out of physics) until they step out first, onto their door spot, with no move order. `passenger_out(unit)` signal. `first_out_offset()` static. Normal troop drops are unchanged.
- `world.gd`: `static var player_aboard`; `commanding()` returns false while it's set, so Space and radio command do nothing until the player is out.
- Cooldowns: the only gameplay cooldown is the terminal's troop readying, `seconds_per_troop` 30 → **5 s** (marked as a testing value; restore later). Not changed: the rifle's 0.12 s fire interval (a fire-rate limit), and the dish's turn speed (a rate, not a cooldown; 180° still takes ~15 s).
- Tested (headless, scratch copy): at start the player is hidden, switched off, `player_aboard` true, and holding Space doesn't enter command mode; the player steps out after 6.6 s at exactly (1137, 555), 0.00 px off, and walks with D; the helicopter leaves 8.9 s later; `seconds_per_troop` = 5. Regression: a terminal-style drop of infantry/radio/infantry with Arrival disabled still gives 3 squadmates with kits `["", "radio", ""]`.

### 2026-10-29 — Crash test dummy square (art only)
- Mike: using Blender, generate a dummy the same size as a player or unit, in crash test dummy colours.
- New `blender/scripts/dummy_square.py` → `assets/characters/dummy_square_sheet.png`. It reuses `character_square.py`'s block, size, bevel, frame size, frame count and sun, so it's an exact drop-in for `soldier.tscn`'s Body sheet. A ring-and-cross target (it looks the same every quarter turn) instead of the quadrant target (which would flip colours as the 90° sheet wraps). The shadow sheet is reused unchanged.
- `character_square.py`: `main()` now runs only when the script is run directly, so it can be imported.
- Every Blender script wrote to a hard-coded `ROOT = F:\Projects\BattleSquares`, which no longer exists. Fixed (same day): `bs_common.py` now has `ROOT`, worked out from its own location, and all seven scripts use `ROOT = bs.ROOT`. Checked: every script parses and every output folder exists; `dummy_square.py` re-rendered into the Desktop project.
- Not wired into the game yet. Checked with an enlarged comparison against the red square on grass: same size and shading, and the target turns with the frames.

### 2026-10-29 — Dummy scene
- Mike: how do I add the dummy to the scene? There was no `dummy.tscn` yet, so it was made for him.
- New `scenes/dummy.tscn`: inherits `soldier.tscn` (root renamed `Dummy`). Body uses `dummy_square_sheet.png`; Rifle, RifleShadow and Sight are hidden. It's a plain `soldier.gd`, so it stands still facing `facing`, isn't in the `player` or `squad` group, and blocks movement. Bullets don't hit anything yet.
- To place it: drag `scenes/dummy.tscn` from FileSystem into `main.tscn`'s 2D view. Not placed by Claude, since Mike places nodes himself.
- Tested (headless, scratch copy): instanced in main with Arrival off. It shows the dummy sheet (30 frames) and the red square's shadow, with the rifle, rifle shadow and sight hidden. It isn't in either group. Walking the player into it from the west stops at its left edge.

### 2026-10-29 — Hit detection and hit reaction
- Mike: work on hit detection and reaction; hits should hit hard; a hit unit jostles back, and hit dust comes off the unit where it was hit.
- `bullet.gd`: each tick a `PhysicsRayQueryParameters2D` ray over the step it's about to fly (2 m a tick at 120 m/s, so it can't tunnel through a 0.4 m square), excluding `shooter`. Any body stops it; one with `take_hit()` is hit. Areas (station zones) are ignored. `setup()` takes the shooter; `rifle.gd` passes its `owner`.
- `soldier.gd take_hit(point, direction)`:
  - **Knockback:** `_knock`, slowing evenly to a stop, so it covers `hit_knockback_m` 0.3 m in `hit_knockback_s` 0.12 s: a sharp jolt, not a slide. It's applied with `move_and_collide` after walking, so it doesn't make the square hop, and walls and the arena edge stop it. Each tick moves at the average speed over the tick, so the distance is exact (plain stepping overshot to 0.343 m).
  - **Twist:** `facing` turns by (hit offset × shot direction) / half-width, clamped to ±1, times `hit_twist_deg` 20°: a corner hit spins it that way, a centre hit doesn't. Controlled squares turn back toward their aim on their own; the dummy stays twisted.
  - **Dust:** `scripts/hit_dust.gd`, added to the level at the hit point. A 0.07 s bright pop, 8 tan puffs bursting back toward the shooter within ±65° (1.2–3.6 m/s, dragged to a stop, swelling 2.6× and fading over 0.4–0.8 s), and 7 dark grit streaks (4–8 m/s, 0.15–0.3 s). It frees itself.
- Tested (`test_hits.gd`, headless, Mike's dummies removed, a dummy 5 m east of the player): own shot from inside the player's box passes out and hits the dummy; centre hit 0.301 m east, 0 sideways, no twist; hit 0.1 m above centre +10.0°; hit 0.15 m below −15.0°; bullets gone; dust gone within about 2 s; a dummy against the east edge stays in the arena. Windowed screenshots 0.04, 0.12 and 0.3 s after a hit: the pop, then puffs billowing back toward the shooter.
- Not done (ideas): damage/health, a camera shake or brief hit-stop when the player is hit, a hit flash, dust or sparks when a bullet hits the helicopter or station.

### 2026-10-29 — The dummy stays put when hit
- Mike: make the dummy more static; let it jostle but not move around.
- `soldier.gd`: `@export var anchored` (on in `dummy.tscn`). An anchored square isn't shoved or turned for real. A hit kicks a damped spring instead, which moves only what's drawn (Body, Shadows, Sight and the radio pack) and adds an extra turn to the frame it shows, then rocks back to rest. `jostle_m` 0.1 m (how far the first swing goes), `jostle_hz` 7, `jostle_damping` 0.3 (fraction of critical damping). The twist is the same lever × `hit_twist_deg` as before. Dust is unchanged.
- The spring is stepped with its exact solution (`_spring_step`), and the kick is sized from `_spring_first_peak()` so the first swing is exactly `jostle_m`. The first try, simple stepping, only reached 0.042 m of 0.1, because at 7 Hz and 60 ticks a second that stepping loses most of the swing.
- Tested (`test_anchored.gd`, headless): a hit 0.1 m above centre rocks it 0.099 m and 9.9°, swings back past home 3 times, and is fully at rest by 1.5 s. The node itself never moves (0.0000 m) and its facing is unchanged. 8 rapid shots stay bounded and settle. A squadmate (not anchored) is still shoved 0.301 m.

### 2026-10-29 — Fire and Stop orders, health and death
- Mike: add two commands, Fire and Stop, in orange. Fire: any unit within selectable range can fire; after Fire you select the target, and the units attack it until it's dead or Stop is pressed.
- **Health** (`soldier.gd`): `max_health` 100, `health`, `dead`, `died` signal. `take_hit(point, dir, damage)`; `rifle.gd damage` 25, carried by the bullet. `_die()`: leaves every group (out of the squad, can't be targeted), collision off, rifle and sight hidden, Body tinted dark (0.15 s), lies 1.5 s, fades 0.8 s, freed. A dead square doesn't move, turn or fire, but finishes its knockback. Every live square is in the new `units` group. `player.gd` overrides `_die()` to top its health back up: there's no game over yet.
- **Squadmates fire** (`squadmate.gd`): `attack_target`, `order_attack()`, `order_stop_firing()`, `is_attacking()` (drops a dead or freed target). Firing is on top of their state (idle, move or formation): they aim at the target, even over listening to the player, and `_wants_to_fire()` shoots every 0.35–0.6 s (`SHOT_GAP_S`) once the rifle is within 4° (`LINED_UP_DEG`). Each shot strays up to ±1.5° (`SHOT_SPREAD_DEG`, via the new `_shot_spread_deg()` hook; `rifle.fire(spread_deg)`).
- **Orders** (`command.gd`): `ORDERS` gains `fire` and `stop`, with `color = World.FIRE_COLOR` (new, orange 1.0/0.6/0.15). `UiStyle.menu_button(text, size, color)` and `box(fill, alpha, edge)` take a colour.
  - Fire arms `_order_targets()` into `_arming`. The next left click is `_try_target()`: the nearest live `units` square within 0.3 m, excluding the player and the armed squadmates. A click on nothing gets a red ping and they stay armed; right click cancels; so does pressing or releasing Space.
  - Stop calls `order_stop_firing()` on everyone the order reaches.
  - While commanding: orange lines from shooters to targets, a ring on each target, rings on the armed squadmates, a crosshair on the square under the mouse (a small one when it's over nothing), and an orange banner while picking.
- Tested (`test_fire.gd`, headless): 3 squadmates within earshot, facing away, plus one out of earshot, and a dummy 6 m off. Fire armed 3 (not the far one); a click on nothing was refused and they stayed armed; the player and the armed squadmates couldn't be targeted. The dummy died after 1.05 s and 6 shots, then they stopped attacking; it left `units` and was removed after the fade. The second dummy took 1 hit in 0.5 s, then Stop: no hits after (75 health, 2 s later still 75, alive). Releasing Space cancelled picking. The player took 6 hits and is alive. Windowed screenshot: orange Fire/Stop buttons, banner, lines, target ring, armed ring and hover crosshair.
- Not done: no enemies yet, so targets are dummies or your own squadmates. (Line-of-fire check: added later the same day, below.)

### 2026-10-29 — Dummy invincible for now
- Mike: make the dummy invincible for now.
- `soldier.gd`: `@export var invincible`. It still gets the full hit reaction (shove or rock, twist, dust) but loses no health. On in `dummy.tscn`. A Fire order on a dummy now goes on until Stop.
- Tested (headless): a dummy hit 10 times stays at 100 health, alive and targetable, rocking with dust each time; a squadmate still dies after 4 hits.

### 2026-10-29 — Squadmates don't shoot through people
- Mike: adjust their AI so they don't shoot if someone is in the way; keep friendly fire on.
- `squadmate.gd _line_blocked()`: before each shot it checks every other live square in `units` (squadmates, the player, dummies) except itself and the target. Anyone between the rifle and the target (not behind the rifle or past the target) whose centre is within `LINE_CLEAR_M` 0.35 m of the line, plus the spread's widening with distance (tan 1.5°), is in the way. 0.35 m is half a square's diagonal (0.28) plus a margin. While blocked, `holding_fire` is true and it keeps aiming without firing or using up its shot timer, so it fires as soon as the line clears. Friendly fire is unchanged: stray shots and people stepping into a shot still get hit.
- `command.gd`: a shooter that's holding fire gets a dashed, fainter orange line to its target.
- Tested (`test_clear.gd`, headless, target 6 m off, bystander at 3 m): on the line or 0.3 m off it, 0 shots and holding fire 99–100% of the time; 0.9 m off, past the target, or behind the shooter, it fires (7/5/4 shots in 2–3 s). Player on the line: 0 shots; player moves away: 5 shots. No bystander hit in any case. `test_fire.gd` rerun (dummy made mortal for it): the player stood in front of one shooter and wasn't hit; the dummy died in 0.85 s with 4 shots, none wasted; Stop and the rest as before.

### 2026-10-29 — Dropped troops stay close to the helicopter
- Mike: reduce how far troops move away from the helicopter when deployed; have them end up pretty close to where they were dropped off.
- `insertion.gd`: `DISPERSE_OUT_M` 6 → **2 m** from the centreline (a step of about 1 m out from the door spot at 0.99 m), and `DISPERSE_SPREAD_M` 7 → **3 m** along the fuselage. Each side's spots are now spaced around the middle of the two doors, not each trooper's own door. At the smaller spread, door-relative spots put the 1st and 2nd trooper on a side 0.02 m apart.
- Tested (`test_drop_close.gd`, headless): 1, 4 and 10 troopers all unload and go idle. The furthest any ends from its own door is 2.2 m, and the furthest from the LZ centre 3.3 m (was about 6–7.5 m). With 10, the closest pair is 0.60 m apart, so nobody stacks.

### 2026-10-29 — Command cone removed; command circle 8 m
- Mike: remove the player's command cone and grow the player's command circle to the cone's radius.
- `player.gd`: `voice_range_m` and `voice_half_angle_deg` removed; `hears_voice()` is now just "within `aura_radius_m`", which is **8 m** (the cone's old reach; set in `main.tscn` too). Asked first, since two things were tied to the circle; Mike chose to keep both as they were, as their own settings: `radio_circle_radius_m` 4.95 m (a radio operator's circle; it was 2× the old 2.475 m aura via `RADIO_CIRCLE_SCALE`, now removed) and `deploy_reach_m` 2.475 m (where equipment may be placed).
- `command.gd`: `_draw_cone` → `_draw_circles` and `_cone_layer` → `_ground_layer`. It draws the 8 m circle (fill 0.08, edge 0.35), the radio circles over the radio, and while placing equipment a brighter deploy-reach ring. Talk waves are full rings now (there's no front face to talk out of). `_can_place_at` uses `deploy_reach_m`. The banner reads "only squadmates inside your command circle can hear you". Comments in `squadmate.gd`, `world.gd` and `radio_station.gd` no longer mention the cone.
- Tested (`test_circle.gd`): hears at 7.9 m ahead, behind and to the side, not at 8.1 m; radio circle 4.95, deploy reach 2.475 (placing at 2.4 m OK, 2.6 m refused); a squadmate 6 m behind the player (out of the old cone) is an order target and turns to listen. Screenshot: no cone, the 8 m circle, ring talk waves, menus unchanged.

### 2026-10-29 — Dramatic deaths: falling on the front or the back
- Mike: make deaths more dramatic, with a couple of animations: one falling on their front with the gun falling next to them, and one on their back with the gun falling to their side.
- **Art:** `blender/scripts/fall_square.py` renders the block toppling over its bottom edge toward 30 directions in 12 steps, for the red square and the dummy, plus a shared shadow (see the Asset List). Checked first with a 4-direction test render composited on grass: east, south, west and north each tip the right way. Frame sizes were made even (1.5 m = 128 px, 2.25 m = 192 px; 1.4 m gave 119 px, half a pixel off-centre).
- **Which fall:** `soldier.gd _die(direction)` (was `_die()`; `player.gd`'s override updated). If the killing shot travels along the way the square faces (shot from behind), it falls forward onto its front; otherwise backward onto its back. The fall direction snaps to the nearest 12° row. Chosen over random so the fall matches the hit.
- **`scripts/death_fall.gd`** (a child added on death; it swaps the Body and Shadow sprites to the fall sheets, 12 × 30 frames):
  - reels 0.12 s, topples over 0.42 s (tip ∝ t², slow then fast like a falling block), lands, and rebounds 12° over 0.2 s.
  - On landing, 3 `HitDust` bursts spray out from under the far edge and both sides. The body darkens to 0.55 over 1.5 s, lies for 5 s after landing, fades over 1 s, and the square is freed.
  - **Rifle:** leaves the shoulder from wherever it was. Forward: drops from 0.22 m in 0.38 s to lie along its right side (0.1 m ahead, 0.36 m right, within ±20° of its facing). Backward: flung out in 0.55 s on an arc 0.25 m higher to 0.75 m to its right (0.1 m back), spinning about 200° ±40° either way. Then a 3 cm bounce. Its shadow follows its height.
  - The hit's knockback still plays out while it falls. The radio pack is hidden (`radio_pack.gd drop()`), being drawn for a standing square.
- `soldier.gd`: `@export var fall_sheet` (red by default; `dummy.tscn` sets the dummy's). The `DEAD_*` tint and fade constants are gone. When dead, the physics tick only finishes the knockback; `death_fall.gd` draws the sprites.
- Tested (`test_death.gd`, headless): squadmates facing east, shot from the west and the east, fall on rows 0 (east, forward) and 15 (west, backward); a radio operator facing south falls on row 8, pack hidden. Tip columns over 0.8 s: 0,0,1,2,5,8,10,10,11,11 (speeding up, the bounce, flat). 9 dust bursts on landing. Forward rifle ends 0.15 m ahead and 0.32 m right; backward 0.12 m back and 0.76 m right, both on the ground. All removed after the fade. A mortal dummy uses `dummy_square_fall_sheet.png`. Windowed frame sequence (0.05–2.5 s) of both falls saved as `assets/previews/death_falls_preview.png`.

### 2026-10-29 — Ragdoll deaths
- Mike: add some ragdoll to the characters.
- The squares are rigid blocks, so "ragdoll" here means physics instead of a script: the killing shot's push decides how the body goes down, and every death comes out a little different. `scripts/death_fall.gd` was rewritten around it (same sheets, no new art):
  - **Skid:** shoved along the shot at 2.2 m/s ±25%, slowing at 4 m/s² while upright and 10 m/s² flat. It uses `move_and_collide` and bounces off solid things (keeping 40% of its speed): helicopter hull, stations, live squares. Scraping flat above 0.5 m/s kicks up light dust puffs.
  - **Spin:** an off-centre hit spins it (up to 360°/s at a corner, ±60°/s at random), dying away at 3/s (6/s flat). Spinning moves it along the sheet rows, so it stays correctly lit.
  - **Topple:** it tips over the edge of whichever face the shot pushed (front, back, left or right; the side falls are new). It's modelled as a block pivoting on its edge: kicked to 70°/s, pulled over by gravity (33 · sin(tip + 20°) rad/s²). It hits flat at about 0.32 s, bounces back 35% of its speed (dust again on a hard bounce) and settles by about 0.6 s. The reel delay is gone; the slow start of the tip does that job.
  - **Rifle:** now a free body in world space (it doesn't ride along with the skid). On front and side falls it's let go at 0.8 m/s ±30% out to the side away from the fall, spinning a little. On back falls it's flung at 1.3 m/s sideways and 1.4 m/s up, spinning 540°/s ±25%. It keeps half the body's skid, falls at 9.8 m/s², bounces at 30% until it's landing slower than 0.5 m/s, then skids at 6 m/s² and stops spinning.
  - Anchored squares (the dummy) topple and spin but don't skid.
- `soldier.gd _die(point, direction)` (was `_die(direction)`; `player.gd` updated). It now sets `collision_layer` to 0 instead of disabling the shape, so the body still collides as it skids while bullets and squares pass over it. The hit's own knockback is dropped, because the ragdoll shove replaces it.
- `hit_dust.gd setup(point, direction, strength := 1.0)`: under 1 gives fewer, slower puffs and no flash (skid and bounce dust).
- Tested (`test_ragdoll.gd`, headless), squares facing east:
  - Shot from behind: falls east and skids 0.45 m.
  - Shot from the front: falls west and skids 0.34 m.
  - Shot from the north: falls onto its right side (south) and skids 0.30 m.
  - Shot 0.15 m off-centre from behind: spins 66° counter-clockwise as it goes.
  - All land at about 0.32 s and settle at 0.55–0.62 s, with rifles on the ground. Tip trace: 3, 9, 18, 29, 44, 64, 88 → bounce 82 → 90.
  - A body shot into the player stops 0.44 m from it.
  - All bodies are removed after the fade. A mortal anchored dummy doesn't move.
  - The first test flung the rifle 1.7 m, so the fling was cut from 2.2/1.6 m/s to 1.3/1.4 m/s.
  - Windowed frame sequence saved as `assets/previews/ragdoll_preview.png`. Rows: shot from behind, from the front, off-centre.

### 2026-10-29 — Attention order
- Mike: add an order called Attention with a Line / Column sub-menu, telling everyone to get in line or in columns so everyone is together.
- `command.gd`: `{id = "attention", text = "Attention", shapes = true}` in `ORDERS`, between Lead and Disperse. Like Follow me and Lead, you hold it for the Line / Column pop-out; a quick click gives Column. It goes to the selection, or to everyone who can hear.
- `_fall_in(units, shape)` forms them up at a spot **fixed on the ground**, `ATTENTION_AHEAD_M` 1.5 m in front of the player, all facing the player:
  - **Line:** one rank across the player's view, 0.9 m apart.
  - **Column:** two abreast, rows 0.7 m apart, going away from the player. An odd one out stands in the middle of the last row.
  - Spacing reuses squadmate.gd `FILE_GAP_M` and `ROW_GAP_M`.
  - Places are dealt out so nobody crosses anybody: the front rows go to whoever is nearest the player, and each row is filled left to right.
  - Anyone who was in Follow me / Lead leaves it, and the rest close up.
- `squadmate.gd`:
  - New `State.ATTENTION` and `order_attention(spot, face_angle)`. The unit jogs or walks to its spot, steps in to within `AT_ATTENTION_M` (3 cm, so the ranks are straight), then stands still facing the way it was told.
  - At Attention it doesn't glance around or shuffle, and it doesn't follow the player. Any other order releases it, and it can still Fire.
  - `_keep_station()` became `_head_for(spot, close_enough)`, shared with Follow me / Lead.
- Unlike Follow me / Lead, the formation doesn't move with the player.
- Tested (`test_attention.gd`, headless; 5 squadmates scattered round the player, who faces up):
  - Line: ranked 1.5 m ahead at x = −1.8, −0.9, 0, 0.9, 1.8.
  - Column: rows at 1.5, 2.2 and 2.9 m ahead, ±0.45 m, with the fifth one centred.
  - Everyone ends within 0.03 m of their spot, facing the player.
  - When the player walked 3 m away they didn't move or turn at all over 3 s.

### 2026-10-29 — Health 2 for testing
- Mike: make everyone's health only 2.
- `soldier.gd max_health` changed from 100 to **2**. No scene overrides it, so this covers squadmates, the player and the dummy. A rifle hit does 25, so one hit kills.
- The player still can't die (its health tops back up), and the dummy is still `invincible`. Restore to 100 later (listed under Testing values to restore).

### 2026-10-29 — Cooldowns 1 s for testing
- Mike: make cooldowns 1 s.
- `radio_terminal.gd seconds_per_troop` changed from 5 s to **1 s**. This is still the only gameplay cooldown. The rifle's `fire_interval_s` is its rate of fire, left as it was. Restore to 30 s later (listed under Testing values to restore).

### 2026-10-29 — Sight triangle on the ground, under the rifle
- Mike: put the weapon in front of the direction triangle; the triangle should be on the ground in front of them.
- `scenes/soldier.tscn`: `Sight` gets `z_index = -1`. It was the soldier's last child, so it was drawn over the rifle (and the square's shadows). Now it's painted on the ground: under the shadows, the rifle and every square, while still above the field. No change in `dummy.tscn` (its Sight is hidden).
- Checked with a windowed screenshot: the rifle barrel crosses over the triangle, and the square's shadow falls across it.

### 2026-10-29 — Attention: click where they fall in
- Mike: after Line or Column is chosen for Attention, the next click picks where they line up.
- `command.gd`:
  - Choosing a shape now arms the order (`_attention_units`, `_attention_shape`), the same way Fire waits for its target.
  - While it's armed, the banner reads "ATTENTION click where N fall in (line) [right click] cancel". Each squadmate is ringed, with a faint line to a see-through square where it would stand; the preview follows the mouse and has a tick on the side it will face.
  - Left click anywhere on the field (`_fall_in(front)`) sends them, and right click cancels. Pressing or releasing Space, or giving any other order, drops a pending pick. Fire and Attention clear each other.
- **Layout** (`_attention_layout(front)`): the clicked point is the middle of the front row, and the formation faces the player from there.
  - Line: one rank across that facing.
  - Column: two abreast, rows going away from the player.
  - Clicked within `ATTENTION_MIN_M` (0.5 m) of the player, it faces the way the player does instead.
  - Places are still dealt out so nobody crosses anybody.
  - `ATTENTION_AHEAD_M` (the fixed 1.5 m in front) is gone.
- Tested (`test_attention.gd`):
  - Nobody moves while waiting for the click.
  - Line clicked 3 m east of the player: a north–south rank at 0, ±0.9 and ±1.8 m, all facing west at the player.
  - Column clicked 3 m up-left: rows going away along the diagonal, at ±0.45 m across, all facing the player (45°).
  - Everyone ends within 0.03 m of their spot.
  - The windowed screenshot shows the banner, the rings, the lines and the ghost squares.

### 2026-10-29 — Aiming line and accuracy at range
- Mike: pressing the right mouse button starts aiming. It shows a line, and the line decides how accurate the weapon is: click within its length and the shot is 100%, as before; the further past it you click, the more inaccurate and unpredictable the shot. Rifle only for now, but each gun will get its own, so make the line easy to adjust.
- **Per weapon** (`rifle.gd`, an "Aim" group in the Inspector):
  - `aim_accurate_m` 6 m: the length of the line.
  - `aim_falloff_m` 12 m: how far past it the spread takes to grow to its worst.
  - `aim_max_spread_deg` 8°: the worst, either side.
  - `aim_spread_curve` 1: 1 is steady growth, above 1 is gentle then fast, below 1 is fast then gentle.
  - `spread_at(distance_m)` turns these into a spread, and `muzzle_position()` is new too.
  - A future gun sets its own values: the line and the shots both read them from the weapon.
- **Shots:** `player.gd _shot_spread_deg()` is now `spread_at(distance from the muzzle to the clicked point)`. The shot is thrown at random within ± that, so it's unpredictable rather than biased. This applies to every player shot, whether or not right mouse is held; holding it only shows the line. Squadmates keep their fixed 1.5°.
- **The line** (new `scripts/aim_line.gd`, added by the player): it shows while `aim` (right mouse, `world.gd MOUSE_CONTROLS`) is held, except in command mode or while busy at a station. It's drawn in the world from the muzzle along the barrel:
  - A solid white line the full accurate length, with a tick across the end, wherever the mouse is.
  - Past that, if the mouse is further out, a wedge as wide as the spread at each distance, shading from white to red toward the weapon's worst. A dashed centre line runs through it, with an arc across it at the mouse marking how far either side the shot may land.
- Tested (`test_aim.gd`):
  - `spread_at` gives 0 at 3 and 6 m, 2° at 9 m, 4° at 12 m, and 8° at 18 and 30 m.
  - 40 shots per distance: clicked at 4 m they strayed 0.00° max; at 10 m, 2.31° max (2.35° allowed); at 25 m, 7.82° max (8°).
  - The line shows while right mouse is held.
  - Screenshots: aiming at about 9 m shows the line and a narrow wedge; at 4 m, only the full 6 m solid line. Saved as `assets/previews/aim_line_preview.png`.

### 2026-10-29 — Rifle settings described in the Inspector
- Mike: add descriptions to rifle.gd's settings.
- Every `@export` in `rifle.gd` now has a `##` comment directly above it, which Godot shows as the tooltip when you hover the setting in the Inspector. Before, most were end-of-line comments the Inspector doesn't show, and the Aim ones shared one block.
- The settings are now `@export_range`s with unit suffixes (m, °, °/s, s, m/s), so the Inspector shows units and gives sliders. They're grouped as **Holding** (shoulder, sweep, swing speed), **Firing** (interval, bullet speed, damage, recoil) and **Aim**; `shadow_path` comes after them, ungrouped. Names and values are unchanged, so scenes are unaffected. `test_aim.gd` re-run gives the same results.

### 2026-10-29 — Scroll wheel turns the Attention formation
- Mike: while placing Attention, make the scroll wheel rotate the previewed formation.
- `command.gd`: while an Attention order is waiting for its click, each scroll-wheel notch turns the formation `ATTENTION_TURN_DEG` (15°): wheel down turns it clockwise, up counter-clockwise.
  - The first notch starts from the way it faced at that moment (toward the player). From then on the facing stays fixed as the mouse moves (`_attention_facing`; NAN means it still faces the player).
  - A new Attention order starts facing the player again.
  - The wheel is used up by the order, so the camera doesn't zoom while placing; at any other time the wheel still zooms. Command's input runs before the camera's, as it comes later in `main.tscn`.
  - The preview, the spots and where the rows go all turn with it. The banner adds "[scroll] turn".
- Tested (`test_turn.gd`, with wheel events pushed through the viewport):
  - Before scrolling it faces the player.
  - 6 notches down turned it 90° clockwise, with no camera zoom; one notch up took it back 15°.
  - Moving the mouse kept the facing.
  - Everyone fell in facing that way, all 4 at the same angle.
  - A new order faced the player again, and the scroll wheel zooms again when not placing.
  - The screenshot shows the turned preview.

### 2026-10-29 — Fix: previews stuck over the command menus
- Mike: while placing (the green Attention helpers), dragging over one of the command buttons made the preview stick for a moment and feel laggy.
- **Cause:** `command.gd` only updated `_mouse_world` from mouse events reaching `_unhandled_input`. Over the ORDERS/DEPLOY buttons the GUI takes the motion events, so the preview froze until the mouse left them. The Fire crosshair and the equipment ghost had the same problem.
- **Fix:** `_process` now reads the mouse every frame while commanding (`get_viewport().get_mouse_position()` → `_to_world`).
- **Also:** while a click on the field is wanted (an Attention spot, a Fire target, equipment), the menus fade to `MENU_PICKING_ALPHA` (0.35) and stop taking the mouse. Before, a click there would have pressed a button (e.g. Disperse) instead of placing. Each control's own `mouse_filter` is remembered (in meta `mouse_filter_was`) and restored afterwards.
- Tested windowed (`test_menu_hover.gd`). Note: the window is 1280×720 while the viewport is 1920×1080 (canvas_items stretch), so the test converts viewport positions to window positions.
  - With the mouse over Disperse while placing Attention, the preview point stays 1.5 px from the mouse.
  - The menus fade, and the button ignores the mouse.
  - Clicking on the button placed the formation there; it didn't Disperse.
  - Afterwards the menus are opaque again, the buttons take the mouse, and the header label's filter is restored.

### 2026-10-29 — Compact radio station: no mast, small dish under the platform
- Mike: make the radio station just the platform and the desk, with a much smaller antenna no wider than the platform. He sketched where it goes: in a box directly below (south of) the platform. Asked first: the antenna is the existing **tunable dish** (the mast goes), and the tuning spot is a **small box beside the dish**.
- **`radio_station.py`:**
  - The 7 m guyed mast, its tripod, dipole, whip, guy wires, stakes and orange flags are removed. `"Stake"` and `"Flag"` are dropped from `GROUND_PARTS`, and `ORANGE` is gone.
  - New layout around the station's middle:
    - `PLATFORM_AT` (0, 1.05);
    - `DESK_AT` = the platform + (0.65, 0, deck height), which is still on the east edge, so the desk is the same;
    - `DISH_AT` (0, −1.1). The dish is 1 m, with tripod legs at 0.55 m and turning reach about 0.65 m, so it stays inside the 2 m width.
  - One cable now runs from the desk across the deck to its south edge and on to the dish post.
  - `FRAME_M` goes from 12.5 to 6.5 m.
  - Re-rendered all four images and the desk close-up (about 20 s).
- **`radio_station.tscn`:**
  - Positions follow the new layout:
    - `StandBox` and `OperatorZone` at (−25.6, −89.6);
    - the `Desk` collision at (55.5, −89.6);
    - the `Dish` sprite and collision at (0, 93.9);
    - `DishStandBox` and `DishZone` at (−132.3, 93.9), west of the dish;
    - the `DishPrompt` under that box.
  - `Solid/MastBase` and its shape are removed. The node origin is now the middle of the station, so the DEPLOY ghost centres on the mouse.
- **`radio_station.gd`:** `DISH_AT` is (0, 93.9), and the header comment is updated. There are no logic changes, since the beam, wheel and dish shadow all key off `DISH_AT`. No other code depended on the old offsets: the terminal uses node paths, and `main.tscn` has no pre-placed station.
- Tested (`test_station.gd`):
  - The operator box triggers only the terminal, the dish box only the dish, and open ground neither.
  - Walking east into the desk stops at x = 0.15 m (the desk's west face is 0.35 m), and walking into the dish post stops 0.76 m short of its centre.
  - The deck's west side is walkable.
  - Tuned east, the beam covers 20 m east of the new dish post and not 20 m west.
  - A windowed screenshot matches the sketch and is saved as `assets/previews/radio_station_preview.png`.

### 2026-10-29 — Blue enemies with tactical AI
- Mike: start on the enemy. Blue, the same square type and the same gun, with decent smarts: manoeuvre sensibly and flank. For testing, they only start firing if you shoot within their detection circle; otherwise they leave you alone.
- Mike's answers to the questions:
  - A shot **fired from inside** the circle or a bullet **passing through** it wakes them, and so does a hit.
  - An alerted enemy **wakes the others inside its own circle**, which can chain.
  - Enemies fight the player and the squad, and **squadmates return fire on their own**.
  - After losing contact they **search for about 10 s, then go back** to their posts.
- **Art:** new `blender/scripts/enemy_square.py` (`dress_as_enemy()`), plus a blue output in `fall_square.py` (see the Asset List). Body sheet 10 s, fall sheet about 1¾ min.
- **Shared AI base, new `scripts/ai_soldier.gd`:**
  - Walking, steering round squares, stuck detection and fire discipline moved here from `squadmate.gd`. Squadmate behaviour is unchanged: the Attention test gives identical results.
  - `_steer` now steers round every live square (the `"units"` group), not just squad and player.
  - Line-of-fire checks skip squares on the other side (`_is_hostile()`), so you may shoot past an enemy at another enemy.
  - New: `_clear_view()` (a ray that sees past squares but not stations or helicopters), and the hooks `_ready_to_fire()` and `_next_shot_gap()`.
- **Who shot whom:**
  - `soldier.gd take_hit(point, direction, damage, by)` now takes the shooter and keeps `last_hit_by`.
  - `bullet.gd` passes its shooter, and bullets in flight are in a `"bullets"` group with their `origin`.
- **`scripts/enemy.gd`** (`scenes/enemy.tscn` inherits `soldier.tscn` with the blue sheets; 4 placed in `main.tscn`):
  - **CALM:** stands at its post facing `start_facing_deg` (180, west), glancing about. Each tick it checks `"bullets"`: one fired from inside `detection_radius_m` (10 m) or currently inside it, by anyone not an enemy, calls `alert()`. A hit calls it too, *before* the damage, so even a killing shot raises the alarm. `alert()` wakes every calm enemy within the alerted one's own radius, recursively.
  - **ENGAGE:**
    - Every 0.25 s it looks for the nearest visible player or squadmate within `sight_m` (22 m), sticking with its current threat.
    - Every `rethink_s` (0.8 s ±25%, out of step with the others) it scores spots on 3 rings × 12 directions round the target, across `min_range_m`–`max_range_m` (5–9 m, about the rifle's accurate range). Each spot is scored for:
      - being in range;
      - being round the target's side or back (`flank_weight` 3 × angle off the target's facing / 180°);
      - spreading round the target from the others' spots (crossfire);
      - not bunching (`spacing_m` 2.5, weight 6, against the others' spots and positions);
      - distance to travel;
      - not crossing the target's 25° front cone;
      - clear view (−5 if blocked);
      - a clear line of fire past friends (−2 if not);
      - a small bonus for keeping its current spot.
    - **Flankers swing round in an arc** (`_route()`): if the straight way would pass inside its minimum range, it heads 35° further round at a range inside its band.
    - **Dodging:** if its target aims within 8° of it from within 1.5 × max range, it sidesteps `dodge_m` (1.2 m), jogging, with a 1.5–2.5 s cooldown.
    - **Firing:** first shot after `reaction_s` (0.3–0.6 s), then bursts of `burst_shots` (3) with `burst_pause_s` (0.9 s) between. Spread is the rifle's `spread_at(range)`, plus `moving_spread_deg` (3°) while moving. It never fires with a friend in the line.
  - **SEARCH:** with nobody in sight for `lose_contact_s` (3 s), it walks to the last seen spot and looks round for `search_s` (10 s).
  - **RETURN:** walks home and goes CALM again, no longer alerted.
  - The detection circle is drawn on the ground (`scripts/enemy_ring.gd`): faint blue when calm, bold dashed red-orange when alerted. `show_detection` turns it off.
  - Every setting is an Inspector export with a tooltip.
- **`squadmate.gd`:**
  - With nothing to shoot it returns fire at the nearest alerted enemy it can see within `RETURN_FIRE_M` (20 m), checked every 0.3 s, and at once at an enemy that hits it.
  - Stop now sets `hold_fire`: no return fire until the next Fire order, or until it's hit.
- Tested (`test_enemy.gd`, headless):
  - The player walking through the circles for 5 s: all stay calm, 0 enemy shots.
  - A shot far away: calm.
  - A bullet fired from outside but flying through a circle: all 4 alert (chained).
  - Fired from inside one circle, shooting away: that one and those within 10 m alert, and one moved 18 m away doesn't.
  - A hit from 20 m with 1 m circles: only the hit one alerts, with the player as its threat.
  - The fight, 3 runs of 10 s against a stationary player facing them:
    - They fan out round his front, sides and back, usually with one past 100° (almost behind him).
    - Ranges are 4.6–9.8 m, and the closest pair at the end is 2.0–3.2 m apart.
    - Brief close passes while repositioning: 0.1–9% of pair-time under 1.5 m.
    - About 60 shots each run, **0 fired with a friend in the line, 0 enemies hit by enemies**.
  - The first version walked straight past the player to reach his back (down to 0.7 m), which led to the `_route()` arc. Raising the spacing weight came from early bunching.
  - Losing contact: engage → search at 4 s → return at 14 s → calm at 24–26 s, all within 0.07 m of their posts and no longer alerted. The test shrinks `sight_m` here, because the 45 × 25 m arena is too small to get 22 m out of sight.
  - Squad return fire:
    - A squadmate auto-targets an alerted enemy.
    - After Stop it doesn't re-target until it's hit.
  - The windowed frame sequence (calm, alerted, flanking, a blue death) is saved as `assets/previews/enemy_fight_preview.png`.
  - Regression: `test_attention` and `test_ragdoll` give the same results.
- Noticed, not changed:
  - The enemies' hits shove the player about 6 m over a long fight, from the 0.3 m hit knockback adding up.
  - `main.tscn` again has dummies nested inside dummies (`Dummy2/Dummy2/Dummy2/Dummy2`).

### 2026-10-30 — Enemies also wake when you walk into their circle
- Mike: the blue enemies should also start attacking if he or his squadmates walk into their detection circle.
- `enemy.gd`: while CALM, every 0.25 s `_check_intruders()` wakes the enemy (`alert()`, with that person as its threat) if the player or a squadmate is inside `detection_radius_m` **where it can see them**. A station or helicopter in between blocks the view (`_clear_view()`). The alert chains as before. Shots in the circle still wake it too.
- `CLAUDE.md`'s note on the 4 enemies in `main.tscn` still holds: tests that place the player or squadmates within 10 m of them will now wake them.
- Tested (`test_intrude.gd`):
  - Player at 10.5 m for 1 s: calm. Stepping to 9.5 m alerts all 4, with the player as the threat.
  - A squadmate at 12 m: calm. Walking to 8 m alerts all 4, with the squadmate as the threat.
  - The player 6 m away with the station's dish between them: calm. Stepping out into view: alerted.

### 2026-10-30 — Editor shows the real field and boundary
- Mike asked why the enemies look off the field in the editor while the game's field is much bigger, and why scenes he places in `main.tscn` sometimes aren't where they were in the editor.
- **Cause:**
  - The `Field` sprite in `main.tscn` was saved at 1920×1080 (with an accidental ~1% stretch), only the top-left quarter of the 3840×2160 arena. `field.gd` refits it to the camera only while the game runs.
  - The arena boundary was also drawn only in the game. Anything placed outside the arena is moved inside it at start (`soldier.gd _stay_in_arena()`).
  - The other way things shift is nesting: dropping a scene into the viewport while a node is selected makes it that node's child, positioned relative to it. That's what happened with the dummies earlier; Mike has since removed them.
- **Fix:**
  - The `Field` now saves its `region_rect` as the whole arena, with no stretch, so the editor shows the real field. The game still refits it every frame.
  - `arena_edge.gd` is now a `@tool` script, so the boundary line, posts and dimmed outside show in the editor too.
- The editor had also written every enemy export into `main.tscn` at its default value, which would pin these four enemies to today's defaults. I removed those 64 lines, so `Enemy`–`Enemy4` keep only their positions and follow `enemy.gd`/`enemy.tscn` defaults. `test_intrude.gd` gives the same results.

### 2026-10-30 — The dish restyled as a flyaway satellite terminal
- Mike sent a photo of a desert-tan military flyaway satellite antenna, and asked for the dish to look more like it in our art style.
- `radio_station.py`:
  - The tripod dish is replaced by a desert-tan terminal (`DISH_TAN`, `DISH_TAN_DARK`, `FOOT_GREY`):
    - **Base:** four outrigger legs in an X, sloping from a hub on the column to round foot pads 0.6 m out, with braces back up to the column, jack screws and two collars. It's 0.78 m tall.
    - **Head and dish:** a pan/tilt head, and a yoke up to the back of a 1.2 m dish (was 1 m), 0.15 deep, at 40° with a rolled rim.
    - **Boom and cable:** a feed boom from the dish's centre to its focus (0.6 m) with the feed on the end, and a black flex cable down the column.
  - `DISH_PARTS` adds `DishRim`, `Head` and `Yoke`, so the head turns with the dish in the game while the legs stay put.
  - Removed the now-unused tripod materials, and re-rendered (about 20 s).
- **Game:**
  - `radio_station.gd`'s `DISH_LOW_M`/`DISH_HIGH_M` are now 0.78/1.72 m (the turning parts' height range, for the swept shadow).
  - The dish collision radius is now 51.2 px (0.6 m), to cover the feet.
  - The turning parts reach about 0.6 m from the post, so the antenna still fits inside the platform's 2 m width.
- Tested (`test_station.gd`):
  - The zones work as before.
  - The dish post blocks at 0.81 m.
  - Tuned east, the beam covers 20 m east and not 20 m west.
  - Screenshots saved: in-game as `assets/previews/radio_station_preview.png`, and an angled close-up rendered from the .blend as `assets/previews/radio_station_dish_preview.png`.

### 2026-10-30 — Thinner feed boom
- Mike: make the dish's black inner antenna line about 40% thinner.
- `radio_station.py`: the `FeedArm` radius goes from 0.02 to 0.012 m. Re-rendered, and both previews (`radio_station_preview.png` and `radio_station_dish_preview.png`) updated. `test_station.gd` still passes.

### 2026-10-30 — Platform prompt: "[F] Interact" instead of the big F
- Mike: when the player steps onto the platform, drop the big white F, and put a small "[F] Interact" under the box, like the dish's "[F] Tune dish".
- `radio_terminal.gd`: `_pad_key` (`UiStyle.pad_key()`) is replaced by `_pad_prompt` (`_make_pad_prompt()`): "[F] Interact" in the dish prompt's style (16 px, light green, dark outline), centred 3 px under the StandBox. It shows at the same times the F did: on the box, menu closed, not on the radio. The troop timer above the box is unchanged. The dish box still shows its big F along with "[F] Tune dish"; that wasn't asked.
- Checked with a windowed screenshot of the player on the platform: no big F, and "[F] Interact" sits under the box.

### 2026-10-30 — Ground hits past the aiming line
- Mike: when the player shoots past the accurate (solid) part of the aiming line, the further past, the likelier the shot goes into the ground; a ground hit kicks up a small dust cloud. The falloff and ground hits apply to squadmates and enemies too.
- `rifle.gd` (Aim group, with Inspector tooltips):
  - `aim_max_ground_hit_pct` (40%) and `aim_ground_hit_curve` (1) shape the chance like the spread: 0 within the solid line, growing to the max at `aim_falloff_m` past it.
  - `ground_hit_chance_at(distance_m)`; `spread_at()` and it share `_past_solid()`.
  - `fire(spread_deg, distance_m)`: a ground hit gives the bullet a `ground_at_m`, picked at random between the end of the solid line and the aim point.
- `bullet.gd`: if nothing stops it first, it goes into the ground at `ground_at_m` (the last tick's step is cut short there) and spawns the dust.
- `hit_dust.gd`: `setup(..., ground := true)` throws a smaller puff (`GROUND_STRENGTH` 0.85) forward and out to the sides along the round's path, and leaves a `Scuff`: a light dirt splash round a dark furrow, under the squares (z −40), lasting 4 s and fading over the last 1.5.
- Shooters: `soldier.gd` has a new hook, `_shot_distance_m()` (0 = no ground hits), passed to `fire()`.
  - Player: the distance to the click.
  - AI (`ai_soldier.gd`): the distance to `attack_target`. Enemies already used the rifle's spread at range; squadmates now get it too, on top of their own `SHOT_SPREAD_DEG` 1.5°, so they're much less accurate far off.
- `aim_line.gd`: shows "NN% ground" beside the arc at the mouse while the chance is above 0.
- The player's rifle overrides in `player.tscn` (solid line 3 m, falloff 3.1 m, 18° max spread, curve 0.1) are Mike's; the new ground settings use the defaults, so the player hits 40% ground from about 6 m out. Tune them on the player's Rifle node.
- Tested (`test_ground.gd`): 26% at 5 m and 40% from 6.1 m (player rifle). 200 shots aimed 18 m away: 90 went into the ground (80 expected), landing 3.2–18 m out. Each puff has a scuff, and all are gone after 5 s. A squadmate shooting at 16 m: 4.7° spread and 6 ground hits in 5 s. The enemy regression tests still pass. Checked with a windowed screenshot: scuffs and puffs inside the spread wedge, and the label at the mouse.

### 2026-10-30 — Standing still steadies the aim
- Mike: moving, the aiming line stays as it is; standing still, it grows 200%.
- `rifle.gd` (Aim group, with tooltips):
  - `aim_still_multiplier` (2.0, so twice as long) scales both the solid line and the falloff while standing still.
  - `aim_steady_s` (0.5 s): how long after stopping it takes to grow fully (smoothstep).
  - `aim_still_below_mps` (0.3 m/s): slower than this counts as still, so a hit's shove or a nudge doesn't spoil it.
  - Moving drops it straight back to normal.
  - `update_steadiness(speed, delta)` keeps `steady` (0..1); `accurate_m()` and `falloff_m()` are the current lengths, used by `spread_at()`, `ground_hit_chance_at()`, the ground-hit landing range and `aim_line.gd`.
- `soldier.gd` calls `update_steadiness(velocity.length(), delta)` every tick, so it applies to squadmates and enemies too: those standing still to shoot are more accurate. The enemies' `moving_spread_deg` penalty is still added on top when they move.
- If "200%" was meant as 3x, set `aim_still_multiplier` to 3.
- Tested (`test_still.gd`, player rifle):
  - Walking: solid line 3.0 m, and a shot at 6 m spreads 17.9° with a 39% ground-hit chance.
  - 0.5 s after letting go of the key: 5.5 m.
  - After 1 s still: 6.0 m, and the same 6 m shot is dead on with 0% ground.
  - Three ticks of walking: back to 3.0 m.

### 2026-10-30 — Asphalt road
- Mike: a road texture that blends seamlessly into the grass. His choices: paved asphalt, drawn as a path in the editor.
- `blender/scripts/road_asphalt.py` renders the strip (see the Asset List).
  - Everything random is periodic along the road (`StripNoise`), and cracks, blades and stones near either end are copied to the other end, so it tiles end to end. Across the road it doesn't need to tile: the verges fade to transparent and the real field shows through.
  - First render: the overgrown verge read as a lighter band and the patches as black boxes. So the blades now cover only about 0.75 m past the asphalt, the patches are near the asphalt's tone, and the edge lines are fainter.
- `scripts/road.gd` and `scenes/road.tscn`:
  - A Path2D (`@tool`) that keeps an internal Line2D on the curve's baked points (every 8 px). The strip tiles along it at real size: width 640 px, `LINE_TEXTURE_TILE`, repeat on, round joints. It redraws as the curve is edited.
  - Its z is −60: over the grass (−100), under the arena edge (−50), the scuffs (−40) and everything else.
  - The scene's default curve is a straight 12 m piece, and `resource_local_to_scene` gives each instance its own curve.
- **To add a road:** instance `scenes/road.tscn` in `main.tscn`, then edit its path with the Path2D toolbar. Keep bends wider than about 4 m radius, or the inside edge folds over. The baked lighting turns with the road; the relief is low, so this doesn't show.
- `main.tscn` has one example Road: a gentle S-bend across the south of the field, from off the west edge to off the east edge.
- Checked with screenshots in the game, wide and close: the curve follows smoothly, there are no seams between repeats, and the verges blend into the field.

### 2026-10-30 — Bigger command circle over the radio
- Mike: when using Command from the radio, increase his command circle by 100%.
- `player.gd`:
  - New export `radio_aura_multiplier` (2.0, with a tooltip).
  - `command_circle_m()` returns `aura_radius_m`, times the multiplier while `World.radio_commanding`: 8 m normally, 16 m over the radio.
  - `hears_voice()` uses it, so squadmates up to 16 m from the player can be commanded directly over the radio, on top of anyone the linked radio operators reach.
- `command.gd`: the player's circle is drawn at `command_circle_m()`, so it shows doubled in radio command mode. The radio operators' own circles (`radio_circle_radius_m`, 4.95 m) are unchanged.
- Tested (`test_radio_circle.gd`):
  - At 12 m and 15.5 m: not heard normally, heard over the radio.
  - At 16.5 m: heard by neither.
  - At 7.5 m: heard in both.

### 2026-10-30 — Road v2: clean, after Mike's reference
- Mike sent a picture of a clean cartoon road (crisp edges, solid white edge lines, short frequent yellow dashes, grass right up to the road) and asked for the road to look more like it, in our art style.
- `road_asphalt.py` is rewritten for the clean version:
  - **Removed:** cracks, repair patches, crumbling edges, the gravel and dirt verge, stones, worn wheel tracks and faded paint.
  - **Asphalt:** straight edges, an even tone, and fine grain only.
  - **Paint:** crisp white edge lines and yellow centre dashes, 1 m on and 1 m off, so 6 per 12 m strip. `main()` asserts that the dash pattern divides the strip's length.
  - **Verge:** the grass blades run from the edge to 0.45 m out, over undergrowth that fades out within 0.2 m.
  - The strip is now 6 m across (512 px, was 7.5 m), so the curves can be tighter: about 3 m radius before the inside edge folds.
- `road.gd` takes the width from the texture, so nothing else changed. Its comments are updated.
- Checked over the grass tile and in the game (wide and close).

### 2026-10-30 — Roads in four conditions: clean, ok, medium, bad
- Mike: three more roads with different levels of damage, from ok to medium to bad.
- `road_asphalt.py`:
  - Now renders all four from one base, with the damage set in `CONDITIONS` (see the Asset List).
  - Each condition has its own seed, so re-renders come out the same. `-- <names>` renders only those.
  - Brought back from v1, scaled by condition: cracks, patches, ragged edges, gravel and dirt verges, stones and asphalt chunks, and grass in the cracks.
  - New: oil stains, flaking paint, crazed "alligator" cracking, potholes (sunk into the surface with broken stone in the bottom), and a sealed seam round each patch.
- **Fixed on the way:** a thin dark line ran along the outside of each verge. It was the blades' shadows on the shadow catcher, on top of the field's own baked-in shadows, so the catcher is gone. Separately, the strip's outermost 10 px now fade to fully transparent.
- `road.gd`: a new `condition` export (enum Clean / Ok / Medium / Bad) picks the texture and updates at once in the editor. The width comes from the texture.
- Tested in the game: four roads side by side, one per condition, curving a little. Each shows its own texture at 512 px wide, with no dark lines at the verges. Screenshot: `assets/previews/road_conditions_ingame.png`.
- Mike's `main.tscn` currently uses two `Sprite2D`s of `road_asphalt.png` at z 0, which draw over the squares. Either set their Z Index to −60 or switch to `road.tscn` (explained to Mike).

### 2026-10-30 — Roads click together in the editor
- Mike: a way for a new road to click into the old road in the editor.
- Godot's own smart snapping only moves whole nodes, not a path's points, so `road.gd` (already a `@tool` script) does it. Roads join the `"roads"` group.
- **Snap** (`_snap_ends()`, every editor frame):
  - A road's first or last point within `SNAP_M` (1 m) of another road's first or last point is moved exactly onto it, in world space, so either road's node can be moved too.
  - Its handle there is turned to the way the other road comes out of the join (`end_outward()`), so it carries straight on. The handle keeps its length, or gets a third of the way to the next point if it had none.
  - Pulling the point more than 1 m away lets go.
  - The snap edits the curve directly, so it isn't a separate undo step.
- **Pattern carry-on:** the road's Line2D now has a small canvas shader (`u_offset`) that shifts the texture along the road.
  - `pattern_start()` follows the chain back through roads whose last point is on this road's first: the previous road's start plus its length in strips (baked length ÷ 1024 px), wrapped to 0..1, guarded against loops.
  - So the centre dashes keep their rhythm across a join, even between different conditions (the condition itself changes with a hard cut at the join).
  - It's worked out at start-up (deferred, once every road exists) and every editor frame.
- Joins are end to end only; there are no T-junctions or crossroads yet. To just make a road longer, add points to the end of the same Road.
- Tested (`test_road_join.gd`):
  - B (a medium road, its node moved, its start 0.6 m off A's end) snaps onto A's end and leaves at 0°, A's heading.
  - C, 2 m away, is left alone.
  - B's pattern starts at 0.171875 strips (A is 1.171875 long), and the shader offset matches.
  - A screenshot (`assets/previews/road_join_preview.png`) shows the clean road running into the medium one with no kink, and the dash at the join continuing across.

### 2026-10-30 — Roads without the centre line
- Mike: a road without the centre lines.
- Done as an option on every condition rather than one more road.
- `road_asphalt.py`:
  - Renders each condition twice: with the yellow centre dashes, and without them (`*_no_centre.png`: `road_asphalt_no_centre.png`, `road_asphalt_ok_no_centre.png`, `_medium_no_centre`, `_bad_no_centre`).
  - The two versions share their seed and damage, and differ only in the dashes. The white edge lines stay.
  - Only the dashed version saves a .blend and its own preview. The new comparison preview is `assets/previews/road_conditions_no_centre_preview.png`. All eight render in about 65 s.
- `road.gd`: a new `centre_line` export (a checkbox, on by default) picks between the two sets of textures and updates at once. Since the strips are otherwise identical, a dashed road joined to one without dashes lines up.
- Checked in the game: four roads with the Centre Line off show the four `_no_centre` textures at 512 px, with no dashes. Screenshot: `assets/previews/road_conditions_no_centre_ingame.png`.

### 2026-10-30 — Attention rotation snaps to the world's axes
- Mike: when turning an Attention formation with the scroll wheel, it could never line up exactly with the world's horizontal and vertical edges; the closest he could get was slightly off vertical.
- **Cause:** the wheel added 15° per notch to wherever the formation first faced (toward the player, any angle), so the steps never landed on 0° or 90°.
- **Fix:** `command.gd` has a new `_turned_attention(facing, notch)` (static, testable).
  - It steps on a fixed grid of `ATTENTION_TURN_DEG` in world angles: 0°, 15°, 30° and so on.
  - From off the grid, the first notch goes to the next grid angle in that direction; after that, each notch is exactly 15°.
  - So 0°, 90°, 180° and 270° are always reachable. Until the wheel is touched, the formation still faces the player.
- Tested (`test_attention_grid.gd`):
  - From 81.3°: one notch down lands on exactly 90°, then 105° and 120°. One notch up instead goes to 75°.
  - From −97.4° and 179° the steps also land on the grid.
  - 24 notches from 90° come back to exactly 90°.
- `test_attention.gd` still passes: line and column form up within 0.03 m of their spots, facing the player.

### 2026-10-30 — Turning equipment while deploying
- Mike: let deployed equipment be rotated the same way as Attention.
- `command.gd`: while placing, the scroll wheel turns the ghost with `_turned_attention()`, in 15° steps on the fixed world grid, so it can square up with the world's edges.
  - The turn (`_placing_turn`) is kept between placings, so several can face the same way.
  - The placed equipment gets the same rotation.
  - The wheel doesn't zoom while placing.
- `radio_station.gd` handles being turned:
  - **`dish_heading` is now a world heading.** The dish sprite, its swept shadow (position and sweep) and the beam are worked out against the node's turn, and `beam_covers()` no longer adds the node's rotation.
  - **The dish turns with the station:** a new station's dish faces the station's own south. `_apply_turn()` runs on `NOTIFICATION_TRANSFORM_CHANGED`, so the placement ghost's dish turns along with it even with processing off.
  - **The station's shadow:** the image is moved by `R(−turn)·d − d` (d = the sun's offset at `SHADOW_HEIGHT_M` 0.6 m), so it still falls bottom-right. This is exact at no turn and close otherwise.
  - **The baked lighting** turns with the station. That's a known compromise; it shows little on its flat parts.
  - **Labels stay upright:** `keep_upright(label, anchor)` keeps them on the same side of their box on screen. This covers the dish's "[F] Tune dish" and big F, and the terminal's "[F] Interact" and troop timer.
  - Boxes, zones and collisions just turn with the node.
- Tested (`test_station_turn.gd`), with stations at 0°, 90° and 45°:
  - The operator and dish boxes work.
  - The dish starts at the station's south (90°, −180°, 135°), and the beam covers 20 m ahead.
  - The shadow is corrected, and the prompts are at 0° in the world.
  - A ghost (processing off) turned 30° after it's in: its dish heading goes from 90° to 120°.
  - Screenshot: `assets/previews/radio_station_turned_preview.png`.

### 2026-10-30 — Deployable sandbag wall
- Mike sent a photo of a sandbag wall and asked for one as a deployable, twice the width of the characters.
- **Art:** `blender/scripts/sandbags.py` (see the Asset List).
  - The first render's bags looked like rounded loaves with gaps.
  - They were reshaped into boxy, lumpy pillows packed tight (rounded-box footprint, flat bottoms, slumped and pinched ends, noise lumps) and lightened to match the photo.
- **Game:** `scenes/sandbags.tscn` (a StaticBody2D root) and `scripts/sandbags.gd`.
  - It's solid: a 73 × 30 px collision box, about the bottom footprint.
  - Bullets stop in it. `bullet.gd` now calls `bullet_hit(point, direction)` on colliders that have one and aren't squares, and the wall puffs `HitDust` back toward the shooter.
  - It has no `take_hit()`, so enemies can't see through it (`ai_soldier.gd _clear_view()`): squares behind it are hidden.
  - **Shadow:** its own image's outline swept from the ground to `WALL_HEIGHT_M` (0.357 m) along the sun (`shadow_sweep.gdshader`), worked out against the node's turn, so it's correct at any angle. It's updated on `NOTIFICATION_TRANSFORM_CHANGED`, so the turning ghost's shadow follows.
- **Deploying:** `command.gd` `DEPLOYABLES` adds `sandbags` ("Sandbags", with a staggered-bags icon in the pop-out). It's placed and turned like the radio station.
- **Carried:** the player carries 6 (`player.gd` `deployables` and the override in `player.tscn`).
- Tested (`test_sandbags.gd`):
  - Three walls deployed through the command code, at 0°, 90° (6 notches) and 45° (3 back); 3 of the 6 left.
  - The player walking into one stops 0.38 m from its centre.
  - A bullet stops in it with one dust puff.
  - An enemy 2 m beyond can't see the player behind it, but can see past its end.
  - The shadow sweeps turn with each wall.
  - Screenshot: `assets/previews/sandbags_ingame_preview.png`.

### 2026-10-30 — Sandbags snap together and can be laid in rows
- Mike: let sandbags snap onto adjacent ones, and hold and drag to lay several at once.
- **Row-laid items:** `command.gd` `DEPLOYABLES` entries with a `line_px` (sandbags: 66 px = 0.77 m centre to centre) can be laid in rows.
  - The art is 0.855 m long with rounded bag ends. At 73 px the joins showed small gaps, so 66 px lets the bags butt up into one continuous wall.
- **Snapping** (`_snap_slot()`):
  - The ghost jumps onto the free end of a wall already down when the mouse is within `SNAP_M` (0.4 m) of it, turned to carry that wall straight on. Either end works.
  - Ends with a wall already there (`_occupied()`, within 0.6 × `line_px`) don't count.
  - Laid walls are in the `"deployed_sandbags"` group: `command.gd` adds them, and `sandbags.gd` adds itself unless it's a placing ghost, so hand-placed ones count too.
- **Hold and drag** (`_layout()`):
  - For row-laid items the left button now puts down on release.
  - While it's held, a row runs from the press point toward the mouse: one wall every `line_px`, as many as the drag covers and as the player carries.
  - The row is turned to the drag's direction on the 15° grid. A row started on a snapped free end carries that wall's line on.
  - There's one ghost per wall, red if out of reach or on top of another. On release `_place()` puts down every good one, with a refusal ping on the rest.
  - A plain click still lays one, and the next placing starts turned the same way.
- **Ghosts:** one ghost became a set (`_ghosts`). `_make_ghost()` now also clears the ghost's own collision layers when its root is a body (the sandbags' root is a StaticBody2D), so a ghost can't block anything. The radio station is unchanged: one ghost, click to place.
- Tested (`test_sandbag_rows.gd`, through real left press/release events):
  - **Click:** one wall, no ghosts left over.
  - **Snapping:** the ghost snaps to both ends of a wall (±66 px).
  - **Row:** a drag at about 95° lays 4 walls turned exactly 90°.
  - **From a free end:** a drag started on one, pulled 30 px off the line, lays 3 walls exactly on the line.
  - **Carry limit:** with 3 left, a 10-wall drag shows 3 ghosts (2 red, out of reach) and lays the 1 good one.
  - Screenshot: `assets/previews/sandbags_rows_preview.png`.

### 2026-10-30 — Sandbags: squares on top, proximity box, shooting over cover
- Mike: his character should draw over the sandbags, not under. Each sandbag wall gets a proximity box (his sketch: a rectangle round the wall). A character inside it can shoot through the wall; from outside, a bullet has a 10% chance to go through and a 90% chance to hit the wall.
- **Draw order:** the wall's Body sprite goes from z 2 to −2. It's now under the squares (0), whose shadows fall across it, under the sight triangles (−1), and over its own shadow (−10) and the ground.
- **Proximity box** (`sandbags.gd`):
  - Exports with tooltips: `zone_length_m` 1.0 along the wall, `zone_depth_m` 0.8 out from its middle on each side, and `through_chance` 0.1.
  - It's drawn faintly in the command colour on the ground (z −3): always on the placing ghost, and on placed walls in command mode.
  - `in_zone(point)` checks it in the wall's own frame, so it turns with the wall.
- **Shooting:** `bullet.gd` asks cover with `lets_bullet_through(bullet)` once per wall, when it reaches it.
  - **Inside:** the sandbags say yes if the shot was fired (`origin`) inside their box.
  - **Outside:** they say yes `through_chance` of the time.
  - **Going over:** the wall goes on the bullet's `_passed` list and is excluded from its ray from then on (up to 4 walls a tick).
  - **Stopped:** otherwise the bullet stops with a sand puff as before.
- **Sight:** `ai_soldier.gd _clear_view()` looks over cover whose `in_zone()` holds the viewer, so a square at a wall sees over it. From outside, the wall still hides whoever's behind it.
- Tested (`test_sandbag_cover.gd`):
  - 200 shots fired 0.5 m behind a wall: all 200 went over.
  - 1,000 shots from 3 m away: 112 went over (about 100 expected).
  - An enemy at the wall sees over it; 3 m back, the view is blocked.
  - Screenshot (command mode: the box, the player drawn over the bags): `assets/previews/sandbags_cover_preview.png`.

### 2026-10-30 — Climbing over sandbags
- Mike: any unit, enemy or the player can move over a sandbag wall by walking into it. The movement is jostly, the character is raised a little (for the top-down view), and it moves 75% slower.
- **Collision:** `sandbags.tscn` is now on collision layer 3 only (`collision_layer = 4`, mask 0). Squares' mask is layer 1, so they walk through it. Bullet rays and `_clear_view()` rays check every layer, so shots and sight lines still meet it.
- **`sandbags.gd climb_at(point)`:** 0..1 for how far up the wall a square centred there is. It's measured from the footprint (`FOOT_PX` 73 × 30): it starts as the square's edge touches (`CLIMB_MARGIN_PX` 14) and is fully on top a little inside.
- **`soldier.gd`:** each tick `_cover_under()` takes the most from walls within 80 px.
  - **Speed:** `CLIMB_SPEED` 0.25 times its speed (smoothed over the first 30% of the climb). Its velocity is capped too, so it can't coast over on its run-up.
  - **Lift:** `_climb_m` eases toward `climb × CLIMB_LIFT_M` (0.18 m) at 1.2 m/s. It adds to the hop height for the body's scale, the shadow's offset and the rifle.
  - **Jostle:** while it moves on cover, a random jolt every 0.09–0.2 s kicks the existing jostle spring: up to 3.5 cm aside and 8° of twist, scaled by the climb. That spring was only used by anchored squares before.
  - All of this is shared, so the player, squadmates and enemies all climb the same way.
- Tested (`test_climb.gd`):
  - **Player walking north across a wall:** 1.60 m/s, then 0.40 m/s on top with the lift rising to 0.180 m, then 1.60 m/s again past it. Crossing from 1 m south to 1 m north took 2.35 s (1.25 s on open ground), and it jolted.
  - **Squadmate:** ordered across a turned wall, it ended 1.13 m past it, lifted up to 0.180 m.
  - **Bullets:** 45 of 50 from 3 m still stopped.
  - Screenshot mid-climb: `assets/previews/sandbags_climb_preview.png`.
  - The earlier `test_sandbags.gd` check "player walking into the wall is blocked" no longer applies.

### 2026-10-30 — Enemies shoot at squares behind sandbags
- Mike: because about 10% of bullets get over sandbags, enemies should still shoot at anyone behind them.
- **Before:** enemies only targeted squares they had a clear line of sight to, and a sandbag wall blocked that, so a square behind one was never shot at.
- `ai_soldier.gd _clear_view(from, to, past_cover := false)`: with `past_cover`, cover that bullets can sometimes get over (`lets_bullet_through()`) doesn't block the view.
- **Uses of it:**
  - **Targeting (`enemy.gd _look_for_targets()`):** uses it, so an alerted enemy keeps shooting at someone behind sandbags, and some shots get over.
  - **Positioning (`enemy.gd _score_spot()`):** a spot that sees its target only over sandbags scores `COVER_WEIGHT` (2.5) lower than a clean view, so enemies still fire but prefer to work round the side.
  - **Noticing (`enemy.gd _check_intruders()`):** unchanged, so a calm enemy still doesn't notice someone hidden behind sandbags.
  - **Squadmates (`squadmate.gd` return fire):** they shoot back at alerted enemies behind sandbags the same way.
- Tested (`test_cover_ai.gd`), with a row of 3 walls and the player 0.45 m behind the middle one:
  - **Calm:** an enemy 6 m away stayed calm for 2 s.
  - **Alerted:** it targeted the player, fired 16 shots in 10 s and hit 11 times. It worked 3.7 m round the side, with a clean view 6.6 s of the 10.
  - **Squadmate:** one behind the wall returned fire at the alerted enemy.
- `test_enemy.gd` and `test_intrude.gd` still pass. With Mike's 16 enemies, one hadn't finished walking back to its post when the 40 s search-and-return window ended. That test has no sandbags, where the new code behaves exactly as before.

### 2026-10-30 — Sandbags v2: one coherent wall, single stack
- Mike: the tiling looked janky, like copies laid over each other instead of one wall. He also asked to drop the top strip of bags (in his screenshot, the upper single-bag courses sitting on the two-deep base) and keep just the horizontal stack.
- **Art:** `sandbags.py` is rewritten to render joinable tiles (see the Asset List).
  - It's a single stack now, with a slight step-in as it rises.
  - The running bond carries across the joins.
  - Finished ends use half bags.
  - There are three middle variants.
  - The first render's finished-end bags were placed half a bag too far out (cut at the image edge); fixed.
  - The old `sandbags.png` is deleted.
- **Game:** `sandbags.gd`.
  - **Picking tiles:** `joined(side)` finds a wall `TILE_PX` (64) along this one's length, turned the same way (or end for end). `_update_tile()` picks single, start, end or a middle tile; the middle variant is fixed by grid cell, so it doesn't flicker.
  - **Updating:** a new wall tells its neighbours to update (`_update_neighbours()`), and a leaving wall tells them once it's out of the group (`_on_leaving()`). The placing ghost picks its tile from the walls already down, so it shows as joining on when snapped.
  - **Shadow:** drawn by the script, no longer the sweep shader. The footprint is swept along the sun (convex hull, in the turned frame). At a join the footprint carries on past the join and the shadow is clipped there, so adjacent tiles draw one unbroken band without overlapping.
  - **Collision:** `FOOT_PX` and the collision box are now 64 × 16.4 px.
- **Laying:** `command.gd` sandbags `line_px` is now 64, the tile length.
- Tested (`test_sandbag_tiles.gd`, through real press/release events):
  - **Row:** a dragged row of 5 came out start, mid_1, mid_2, mid_0, end. A lone wall is single.
  - **Ghost:** snapped onto a row's end, it shows end.
  - **Removing:** taking the middle wall away turns its neighbours into end and start. Snapping it back restores the row.
  - **Turned:** a 30° dragged row joins the same way.
  - **Still passing:** the climb, cover and cover-AI tests (crossing now takes 2.1 s, with the thinner wall).

### 2026-10-30 — Bigger deploy reach, bigger sandbags, the player can die
- Mike: make the placement circle 2× bigger, make each sandbag 60% bigger, give the player 4 health, and when the player dies zoom in on them with some margin, play the ragdoll in slow motion, then show a small Restart / Quit menu.
- **Deploy reach:** `player.gd deploy_reach_m` 2.475 → **4.95 m** (also in `player.tscn`).
- **Sandbags 1.6×** (`sandbags.py`):
  - Bags are 0.4 × 0.256 × 0.136 m (were 0.25 × 0.16 × 0.085), lumps scaled to match.
  - Two bags per tile instead of three, so a tile is 0.797 m (68 game px): still two squares wide.
  - 3 courses instead of 5, so the wall stays about as high as before (0.354 m); the foot is 0.282 m wide.
  - Game side: `sandbags.gd` `TILE_PX` 68, `FOOT_PX` 68 × 24, `WALL_HEIGHT_M` 0.354; `sandbags.tscn` collision box 68 × 24; `command.gd` sandbags `line_px` 68.
  - Fix: `_update_tile()` returns when the wall is no longer in the tree. Reloading the level (the new Restart) had walls re-tiling after they'd left, which errored.
- **Player health:** `max_health` 4 on the Player in `main.tscn` (the rifle does 2 a hit: two hits).
- **Player death** (`player.gd _die()`, replacing the top-up):
  - It falls like any square (`death_fall.gd`), but `lingers`: it darkens and stays down instead of fading and being removed.
  - `World.player_dead` shuts command mode (`World.commanding()`), and radio command is dropped.
  - `Engine.time_scale` goes to `DEATH_TIME_SCALE` 0.3 while it falls.
  - `death_fall.gd` fires a new `came_to_rest` signal once the body has settled and stopped skidding and the rifle is down. Then the time scale goes back to 1 and, `DEATH_MENU_DELAY_S` 0.6 s later, the menu comes up.
  - **Camera** (`game_camera.gd _close_in()`): eases in on the body until `DEATH_VIEW_M` 3.5 m of ground shows top to bottom (past `max_zoom` if need be). It eases in real time, so it isn't slowed with the game. The wheel does nothing meanwhile.
  - **Menu** (new `scripts/death_menu.gd`): a dimmed screen and a small panel in the command menus' style, low on the screen so it doesn't cover the body: "KILLED IN ACTION", **Restart** (reloads the level) and **Quit**.
  - `player.gd _ready()` resets `World.player_dead`, radio command and the time scale, since statics outlive a scene reload.
- Tested (`test_death.gd`, windowed):
  - Health 4 → 2 after one hit, dead after the second.
  - Time scale 0.3 and command mode blocked while falling.
  - The menu came up 2.8 s (real) after death, at time scale 1 and zoom 3.6, with the body still there.
  - Restart gave a fresh, live player with `player_dead` cleared.
  - The sandbag tiling and cover-AI tests still pass at the new size.

### 2026-10-30 — Squadmates defend from behind sandbags
- Mike: moving a unit to a spot behind a sandbag wall should make it take up the defensive there, staying and fighting from the sandbags until another command cancels it.
- **`squadmate.gd`, new `DEFEND` state:**
  - **Triggered** by a command-mode move order (`order_move(point, true)` from `command.gd _order_move()`) whose spot is inside a wall's proximity box (`_cover_at()`). On arrival, if it actually got into the box, it takes cover (`_take_cover()`). A move that gets stuck short of the box just stands there. Disperse uses a plain move, so it never triggers this.
  - **Holding:** it holds the spot it arrived at, stepping back to within 3 cm if knocked off. No idle shuffling.
  - **Facing:** out over the wall (`defend_facing()`, across the wall from its side), scanning up to `DEFEND_SCAN_DEG` 35° either side every few seconds (`_tick_scan()`).
  - **Fighting:** it engages alerted enemies it can see over the wall out to `DEFEND_FIRE_M` 30 m (normal return fire is 20 m), and goes on guard again when its target dies.
  - **Ending it:** any other order (move, Follow me, Lead, Attention, Disperse, Stop) ends it. Stop leaves it standing where it is (`_stand_down()`). A Fire order only picks its target, so it stays in cover. If the wall disappears, it stands down.
- **`command.gd`:** in command mode, a defending squadmate shows a green bracket just outside its ring, on the side it faces out of (`DEFEND_MARK_M`, `DEFEND_MARK_HALF`).
- Tested (`test_defend.gd`):
  - **Arrival:** a single unit sent behind a row of 3 walls arrived and defended, facing straight out (−90°).
  - **On guard:** over 10 s it stayed within 0.07 m of the spot, looking at most 34° off straight out.
  - **Engaging:** an alerted enemy 26 m out was engaged (8 shots in 4 s) without the unit moving. When the enemy went, the unit stayed on guard.
  - **Knocked back:** 0.22 m off the spot, it stepped back.
  - **Ending it:** Stop ended it. Ordered back in, it defended again; moved to open ground, it didn't. A plain (disperse-style) move into the box doesn't trigger it.
  - Screenshot (command mode, the bracket): checked by eye, not kept.

### 2026-10-30 — Unlimited sandbags (for now)
- Mike asked for unlimited sandbags for the time being.
- A deployable count of **-1** now means unlimited: `command.gd _carried()` reports `UNLIMITED_COUNT`, placing doesn't use one up, and the DEPLOY pop-out shows "Sandbags  ∞".
- `player.gd` / `player.tscn` `deployables`: sandbags **-1** (was 6). Set it back to a number to limit them again.

### 2026-10-30 — Scroll to zoom in the radio command overview
- Mike: in command mode, let him scroll out. Holding Space already left the wheel zooming as normal; the radio command overview (`game_camera.gd`) ignored it, fitting the squad automatically.
- Now the wheel works there too: it scales the overview's fit (`_overview_scale`, `zoom_step` a notch, out to `min_zoom` and in to `max_zoom`), still centred on the units. It starts at the plain fit each time radio command begins.
- Placing equipment or turning an Attention formation still uses the wheel to turn things, as before.

### 2026-10-30 — Enemy spawner HUD (testing)
- Mike: a little HUD for summoning enemies, for testing only. Three regions on the far right (top, middle, bottom) they come out of, picked at random; inputs for how many and their formation. They patrol from right to left until they see us and fight, or just keep walking.
- **`scripts/enemy_spawner.gd`** (new; an `EnemySpawner` Node2D in `main.tscn`):
  - **Panel**, top right: "How many" (1–12), "Formation" (Column, Line, Wedge) and **Spawn**. A status line says what came from where.
  - **Regions:** the right edge's top, middle and bottom thirds, 3 m deep, drawn faintly in enemy blue on the ground. The one used flashes for 2 s.
  - **Spawning:** the formation's rearmost enemy starts 0.8 m in from the edge, at a random height within the region, kept inside the field. Members are `gap_m` (1.6 m) apart; the wedge is a leader then pairs further back each side. Spawned enemies get `enemy_health` 2, like the placed ones.
  - **Rifle:** while the mouse is over the panel (or its list is open), the player is `busy`, so clicking it doesn't fire.
- **`scripts/patrol.gd`** (new): moves the formation's anchor left at 0.8 of walking speed. It waits while any member is fighting or searching, then restarts from where they are, so they re-form. A member reaching the left edge walks off (is removed); the patrol goes when it has nobody left.
- **`enemy.gd`:**
  - On patrol, a calm enemy keeps its slot (`_keep_patrol_slot()`, jogging if well behind).
  - It notices people exactly as before (detection circle, shots, hits), and a patrol alerts together.
  - After searching, it goes straight back to calm and rejoins the patrol (`_go_calm()`) instead of returning to a post.
- Tested (`test_spawner.gd`):
  - **Regions:** all three came up over 30 spawns.
  - **Formations:** column, line and wedge of 5 each walked 10 m left in 8 s, within 0.22 m of their slots.
  - **Fighting:** a wedge meeting the player 7 m ahead alerted all 5 and fired. With the player gone they were calm after 13.5 s (3 s losing contact, 10 s searching), then re-formed and walked on 9.4 m in 6 s.
  - **Leaving:** a patrol at the left edge was removed entirely.

### 2026-10-30 — Enemies take cover behind sandbags
- Mike: an enemy near a sandbag wall should take up one of its defensive spots and defend from there, leaving only if flanked or if its sandbags are destroyed (destruction comes later).
- **`enemy.gd`, cover:**
  - **Taking cover:** fighting within `cover_seek_m` (6 m) of a wall, at each rethink it looks for a defensive spot (`_take_cover()`). Each wall has two spots, `COVER_SPOT_M` 0.42 m behind its middle on each side, inside its proximity box, so its shots go over.
  - **A usable spot** is free (`_spot_taken()`: nobody standing there and no other enemy claiming it) and covered: a ray from it to the fight meets a sandbag wall within `COVER_REACH_M` 1.5 m (`_covered()`, collision layer 4). It takes the nearest.
  - **Holding** (`_hold_cover()`): it goes to the spot and holds it, firing as usual. No rethinking, no dodging, and it doesn't drop to SEARCH when it loses sight of everyone.
  - **Leaving:**
    - Uncovered for `FLANK_GRACE_S` 0.8 s means flanked: it leaves, taking another covered spot if there's one in reach (often the other side of the same wall), otherwise fighting in the open.
    - It also leaves if its wall is gone (freed or queued for deletion).
    - Going calm (a patrol rejoining) clears it.
- Tested (`test_enemy_cover.gd`):
  - **Taking cover:** three alerted enemies 2.5 m south of a 3-wall row, the player 9 m north, each took a different spot on the south side, within 0.07 m.
  - **Holding:** 16 shots in 10 s without moving off the spot.
  - **Losing sight:** with nobody in sight for 16 s, they stayed in cover (still ENGAGE, no search).
  - **Flanked** from their side, one left after 1.1 s and took the spot on the far side of the wall.
  - **Wall gone:** with its wall freed, it left cover.
  - `test_enemy.gd`, `test_spawner.gd` and `test_cover_ai.gd` still pass. In the last, the enemy now takes cover on its own side of the wall and returns fire over it, instead of working round the side.

### 2026-10-30 — Rifle shot sound
- Mike added `assets/sfx/ES_Guns, Rifle, M40-Sniper Rifle, Barrel - Epidemic Sound - 0000-0305.wav` (Epidemic Sound; 0.3 s, stereo, 24-bit, 96 kHz) as the sound for every rifle shot. He later renamed it `assets/sfx/Rifle.wav`.
- **`rifle.gd`:** a new "Sound" group of exports:
  - `shot_sound` (that file, now `Rifle.wav`), `shot_volume_db` 0, `shot_pitch_jitter` 0.05 (each shot's pitch varies ±5%) and `shot_hearing_m` 45 m.
  - Each rifle gets an `AudioStreamPlayer2D` at the muzzle and plays it from `fire()`.
  - It's positional: the current camera is the listener, so distant shots are quieter and panned, fading out at 45 m (about the field's width).
  - `max_polyphony` 4 lets quick shots ring over each other.
- Since squadmates and enemies use the same rifle, they all get the sound. Per-scene overrides (e.g. a quieter enemy rifle) can go on their Rifle node.

### 2026-10-30 — Dirt impact sounds
- Mike added `assets/sfx/DirtImpact.mp3`: 7 s holding a set of bullet-into-dirt impacts. He asked for them mixed up, one per bullet hitting the dirt.
- **Splitting:** nothing here decodes MP3 except Blender's audio module (`aud`), so a one-off script run in headless Blender (in the session scratchpad, not kept) did it:
  - It found the 8 impacts by the silence between them (above −34 dB counts as sound; 0.25 s of quiet ends one).
  - Each one is trimmed (4 ms before, 60 ms after, 30 ms fade-out), mixed down to mono for positional playback and normalised to the same peak.
  - They're written as `assets/sfx/dirt_impact/dirt_impact_0.wav` … `_7.wav` (48 kHz, 16-bit, 0.25–0.34 s each). The MP3 stays as the source.
- **`bullet.gd _hit_ground()`:**
  - A round going into the ground plays one of `DIRT_SOUNDS` at random, never the same one twice in a row (`static var _last_dirt`).
  - Pitch varies ±8%, at `DIRT_VOLUME_DB` −4 dB, fading out at `DIRT_HEARING_M` 30 m from the camera.
  - It has its own short-lived `AudioStreamPlayer2D` at the landing spot (the bullet is freed straight away), which frees itself when it finishes.
- Only ground hits make the sound. Hits on squares and sandbags are silent for now.

### 2026-10-30 — Manning a sandbag row
- Mike: with several units selected and sent to a sandbag spot, they should fill the adjacent spots along that chain of sandbags until it's full or there are no more units.
- **`command.gd _order_move()`:** a point in a wall's proximity box now mans that wall's row (`_man_sandbags()`). Otherwise the line-abreast move is unchanged (now `_send_in_line()`).
  - **The row** (`_sandbag_row()`) is the walls joined end to end with the one clicked (`sandbags.gd joined()`), walking each way and coping with a neighbour turned end for end. It's ordered from the clicked wall outward, alternately each way.
  - **Spots:** one per wall, `COVER_SPOT_M` 0.42 m behind its middle on the side clicked, so everyone faces the same way. Spots someone else is standing on or walking to are skipped (`_spot_held()`).
  - **Who goes where:** each spot in turn gets the nearest unit still to place, and is sent there with `take_cover` (they dig in, squadmate.gd DEFEND).
  - **Overflow:** anyone left once the row is full lines up `OVERFLOW_BACK_M` 1.2 m behind the clicked wall.
  - A single unit works the same way: it snaps to the clicked wall's spot.
- **`squadmate.gd` fixes found while testing:**
  - **Squeezing past:** a manned row is a wall of squares 0.8 m apart, a hair too tight for a 0.4 m square to pass. While dug in, a squadmate is now on `DEFEND_LAYER` (collision layer 5) instead of the squares' layer 1 (`_dig_in()`), so others squeeze past. Bullet and sight rays check every layer, so it's still hit and still blocks views.
  - **Digging in:** only if it got within `DEFEND_ARRIVE_M` 0.3 m of its spot. A unit stopped short (stuck) used to dig in wherever it gave up if that was in the box, even on the wrong side.
- Tested (`test_man_row.gd`, a row of 5 walls):
  - **Three units** sent to the middle wall's south side took walls 2, 3, 1.
  - **Five more** to the same wall skipped those three, took the two ends (0, 4), and the last three lined up behind.
  - **Crossing:** two of those, sent to the north side of the end wall, squeezed past the manned south side and took 4N and 3N.
  - `test_defend.gd` still passes (the spot is now the wall's own, 0.24 m from the click).

### 2026-10-30 — "Extra Sandbags" in the Inspector
- Mike: an Inspector setting on a sandbag wall placed in the editor that adds more sandbags.
- **`sandbags.gd`** is now `@tool`, with a new export `extra_sandbags` (0–60):
  - **What it does:** lays that many more walls end to end after this one, along its length the way it's turned, so they join into one row.
  - **In the editor:** a preview child (not owned, so never saved) draws the whole row with the tiles it will get (start, middles, end), over the wall's own tile, and redraws as the number changes. Everything else in the script returns early in the editor (`Engine.is_editor_hint()`), so no gameplay code runs there.
  - **In the game:** `_lay_extras()` (deferred, since the parent is still adding children) instantiates the walls beside this one in the level, `TILE_PX` apart and turned the same, carrying its zone and through-chance settings (no extras of their own). They join up through the usual tile logic.
- Tested (`test_extra_sandbags.gd`): a wall turned 30° with 4 extras became 5 walls, all at 30°, exactly 68 px apart, tiled start, mid, mid, mid, end, with the original's `through_chance`. The project also loads in the editor (headless) without script errors. The preview itself hasn't been looked at in the editor yet.

### 2026-10-30 — Rifle shots: three variants with echo tails
- Mike: with everyone shooting, the single short rifle snippet (`Rifle.wav`) sounded like popcorn. He added `assets/sfx/Rifle.mp3` with several shots, to be broken up like the dirt impacts.
- **Wrong file:** the `Rifle.mp3` first in the folder was byte-identical to `DirtImpact.mp3` (a copy of the dirt download). The real one was in Downloads (`ES_Guns, Rifle, M40-Sniper Rifle, Barrel - Epidemic Sound.mp3`, 77,305 bytes, 4.1 s) and was copied over it.
- **Splitting** (headless Blender `aud` again; script in the session scratchpad):
  - It holds 3 shots, each a sharp crack and then an echo dying away (about −33 dB at 0.1 s, −45 at 0.5 s).
  - Each is cut at its onset (3 ms before), kept to **0.6 s** so the echo rings out, faded over the last 0.2 s, mixed to mono and normalised to the same peak.
  - Written as `assets/sfx/rifle_shot/rifle_shot_0.wav` … `_2.wav` (48 kHz, 16-bit).
- **`rifle.gd`:**
  - `shot_sound` → `shot_sounds` (array, those three).
  - The muzzle player's stream is an `AudioStreamRandomizer` in random-no-repeats mode, so a shot never repeats the last; pitch still varies ±5% (`shot_pitch_jitter`).
  - `max_polyphony` raised to 6 for the longer tails (the player can fire every 0.12 s).
- `Rifle.wav` (the original snippet) is no longer used; it's left in the folder.

### 2026-10-30 — Enemies dig in at open sandbag spots they detect
- Mike: if an enemy's detection circle picks up an open defensive spot, it should go there and dig in. Until now enemies only took cover once fighting, within 6 m, so calm patrols walked straight over his sandbag rows.
- **`enemy.gd _dig_in_calm()`:** checked while calm, at each THINK_S.
  - **The spot:** an open defensive spot within `detection_radius_m` (10 m), with a wall between it and the way the enemy faces. For a patrol that's the way it walks. It takes the nearest (`_take_cover()`, now with a reach argument).
  - **Digging in:** it leaves its patrol (`patrol.gd release()`), the spot becomes its post, and it faces out over the wall. It holds the spot while calm (`_hold_cover()` with no focus, so no flank check), and fights from it once alerted.
  - **Leaving:** as before, only when flanked in a fight or when its wall goes.
  - Placed enemies near sandbags will also leave their posts for an open spot in range.
- Tested (`test_patrol_cover.gd`, Mike's `main.tscn` rows):
  - **Digging in:** a 5-strong wedge from the right, with the player far off at the start, all dug in behind the first row within 9 s, facing west. The empty patrol removed itself.
  - **Fighting:** with the player 8 m west, all 5 alerted and fired 39 shots in 5 s, still dug in.

### 2026-10-30 — Opening music synced to the landing
- Mike added `assets/sfx/Song_Test.wav` (28.6 s, 48 kHz stereo). He wants the soft part before the helicopter lands, the beat dropping as it lands, then 5 s of the song and a fade out.
- **The song:**
  - Soft from 0 to ~12 s, a 1 s break, then the drop at **13.46 s** (bass (<150 Hz) and level jump about 7 dB; found from 10 ms frames).
  - Cut (headless Blender, script in the session scratchpad) into `assets/music/song_test_intro.wav` (0–13.46 s, 10 ms fade at the cut) and `assets/music/song_test_drop.wav` (from the drop: 5 s, then a 3 s fade; 8 s).
- **`insertion.gd`:**
  - New `landed` signal at touchdown (INBOUND → SETTLING).
  - New `static flight_time_s()`, which steps INBOUND exactly as the physics does to give the flight time (5.87 s at 60 ticks/s).
- **`arrival.gd`:**
  - Plays the intro from `length − flight time` (7.6 s in), fading in over `music_fade_in_s` 1 s, so it reaches the drop as the helicopter lands. If a flight were longer than the intro, it would wait instead.
  - On `landed`, it cuts the intro and plays the drop.
  - Exports `music_intro`, `music_drop`, `music_volume_db` (−4 dB). Non-positional.
- Tested (`test_arrival_audio.gd`): the intro started 7.60 s in; the drop took over at touchdown; it ran its 8 s and ended.

### 2026-10-30 — Helicopter sound
- Mike added `assets/sfx/Helicopter.mp3`: 141 s, one continuous take of a helicopter.
- **The take, mapped every 2 s by level and low/high-frequency balance:**
  - 0–36 s: far off (−46 to −33 dB), mostly low thump.
  - 36–56 s: closing.
  - 56–78 s: loudest (−19 dB), steady, overhead at full power.
  - 78–92 s: winding down.
  - 92–141 s: a steady, quieter whine, idling on the ground (−28 dB).
- **Three seamless loops** (mono, end cross-faded 1 s into the start, normalised), in `assets/sfx/helicopter/`:
  - `heli_distant.wav`: 4–14 s of the take, 10 s.
  - `heli_flight.wav`: 64–72 s, 8 s.
  - `heli_idle.wav`: 104–116 s, 12 s.
- **`helicopter.gd`:**
  - Three `AudioStreamPlayer2D`s at the rotor mast, looping (the WAVs are set to forward-loop in code), each starting at a random point.
  - **Mixing** (`_mix_sound()`, every frame):
    - flight × (in the air);
    - idle × (on the ground), cross-fading over the last `GROUND_BLEND_M` 3 m of height;
    - distant fades in from `DISTANT_FROM_M` 18 m to `DISTANT_FULL_M` 45 m from the camera, heard out to 140 m (the near loops to 60 m);
    - all scaled by `rotor_spin`.
  - Exports `sound_volume_db` −2, `idle_volume_db` −6 and `distant_volume_db` −4.
  - Every helicopter gets it: the opening one and radio-requested insertions.
  - The take's spool-down and approach stretches (36–56 s, 78–92 s) aren't used: the cross-fades cover those changes, and the helicopter is only on the ground for a few seconds.
- Tested (same test, each second): the distant thump at 70 m out, flight as it came in, flight handing over to idle in the last 3 m, idle on the ground, flight again on lift-off, and distant again as it flew away.

### 2026-10-30 — Opening music: just the drop
- Mike: cut it to only the beat dropping when he lands, then the fade out; get rid of the rest.
- `arrival.gd`: the intro is gone. On touchdown (Insertion `landed`) it plays `music_drop` (5 s from the song's drop, then a 3 s fade), and nothing plays before it. `music_intro` and `music_fade_in_s` are removed.
- `insertion.gd`: `flight_time_s()` is removed (it only timed the intro). The `landed` signal stays.
- `assets/music/song_test_intro.wav` is deleted. `song_test_drop.wav` is unchanged.

### 2026-10-30 — Calm enemies shoot at what they can see
- Mike: if they can see him, they can and should shoot at him. A calm enemy only noticed people inside its 10 m detection circle, so a dug-in enemy watched him walk about in plain view at 15 m and did nothing.
- **`enemy.gd _check_intruders()`:** a calm enemy now also alerts on a player or squadmate it can see out to `sight_m` (22 m), if they're in front of it: within the new `calm_view_deg` (70°) either side of where it's facing.
  - Inside the detection circle it still notices in any direction.
  - Sight lines work as before: stations block them, and someone hidden behind sandbags isn't spotted while it's calm.
  - Alerted, it fights as usual. Dug in, it fires from its spot.

### 2026-10-30 — Line of sight decides: seen means shot at, hidden means calm
- Mike: behind something, they can't see him and should stay calm; in the open they can see him and should shoot and be aggressive. The interaction distance wasn't realistic: he could shoot at them from outside their circle.
- **Seeing** (`enemy.gd _check_intruders()`):
  - A calm enemy alerts on any player or squadmate it has a clear line of sight to, in any direction, within `sight_m`.
  - Anything solid blocks the line: a station, a landed helicopter, sandbags.
  - The forward-view cone from earlier today (`calm_view_deg`) is removed; line of sight is the test.
  - `sight_m` default 22 → **35 m**.
- **Hearing** (`_check_shots()`):
  - A shot fired within the new `hearing_m` (**40 m**) of it alerts it, seen or not. The shooter becomes its threat; if it can't see them it searches where they were and calms down after `search_s`.
  - A bullet passing within its detection circle (10 m) still alerts it too.
- Unchanged: once fighting, it still sees and fires over sandbags (since ~10% of shots get over), and stations still block it.

### 2026-10-30 — Landing music adjustable in the Inspector
- Mike: the beat's timing against the landing is a little off, and he'd like to adjust it himself in the Inspector.
- **`arrival.gd`, a "Music" export group:**
  - Touchdown now plays the whole `Song_Test.wav` (`music`) from `music_start_s` (default 13.46 s, the drop) instead of the pre-cut drop file.
  - `music_delay_s` (default 0) waits after touchdown.
  - `music_play_s` 5 s at full volume, then a fade over `music_fade_s` 3 s, done by a tween (linear amplitude) instead of being baked into a file.
  - `music_volume_db` −4.
  - Raising `music_start_s` brings the beat sooner; lowering it adds lead-in.
- `assets/music/song_test_drop.wav` and the `assets/music/` folder are removed (nothing else used them).

### 2026-10-30 — Song removed; concrete and sand impacts
- **Song:** Mike asked for it removed and deleted.
  - `assets/sfx/Song_Test.wav` and its `.import` are deleted.
  - `arrival.gd`'s Music group and `_drop_the_beat()` are gone, along with `music_start_s` (13.6, Mike's tweak) from `main.tscn`.
  - `insertion.gd`'s `landed` signal stays: it's harmless and handy for later.
- **Impact sounds:** Mike added `assets/sfx/ConcreteImpact.mp3` (5.8 s) and `SandImpact.mp3` (7.5 s). Each was split like the dirt impacts (headless Blender, silence-gap detection, mono, normalised):
  - `assets/sfx/concrete_impact/concrete_impact_0.wav` … `_7.wav` (0.20–0.28 s each);
  - `assets/sfx/sand_impact/sand_impact_0.wav` … `_7.wav` (0.35–0.47 s each).
- **New `scripts/impact_sound.gd`:** `ImpactSound.play(parent, point, kind)` with kinds "dirt", "concrete" and "sand".
  - One sound of that kind at random, never the same one twice running per kind. Pitch varies ±8%, at −4 dB, fading out at 30 m.
  - Its own short-lived `AudioStreamPlayer2D`.
  - The dirt-sound code moved here out of `bullet.gd`.
- **Where each plays:**
  - **Ground hits** (`bullet.gd _hit_ground()`): concrete if the point is on a road's asphalt, otherwise dirt. On the asphalt means within `ASPHALT_HALF_M` 2.5 m of the road's centre line (new `road.gd covers()`), not counting the grassy verge.
  - **Sandbags** (`sandbags.gd bullet_hit()`): sand, wherever a bullet stops in a wall.

### 2026-10-30 — Bullet flybys
- Mike added `assets/sfx/BulletFlyBy.mp3` (14 s, a run of different whizzes) and asked for an adjustable flyby circle round his character: a bullet passing through it plays one of those sounds.
- **Splitting:** like the impacts (silence gaps, mono, normalised), into `assets/sfx/bullet_flyby/bullet_flyby_0.wav` … `_11.wav` (12 whizzes, 0.28–0.57 s each).
- **`player.gd`:** new exports:
  - `flyby_radius_m` (default **1.5 m**);
  - `show_flyby_circle` (off), which draws the circle round the player in yellow, to see it while tuning.
- **`bullet.gd _check_flyby()`:**
  - Each tick, a bullet not fired by the player checks the stretch it's about to fly. If any point of it comes within the player's `flyby_radius_m`, it plays a flyby once, from that closest point.
  - It runs after the hit test, so a bullet that hits the player this tick doesn't also whizz.
- **`impact_sound.gd`:** a new "flyby" kind (the 12 whizzes), so flybys pick at random without repeats, with the same pitch variation, level and fade with distance.

### 2026-10-30 — Magazines and an animated reload
- Mike asked for a reload animation. The rifle had no ammo yet, so this adds magazines and reloading too.
- **Art** (`blender/scripts/rifle.py`, run headless), besides `rifle.png`:
  - `assets/characters/rifle_no_mag.png`: the same rifle with the magazine hidden, same 384 px frame.
  - `assets/characters/magazine.png`: the magazine alone, lying on its side, 64 px (0.1875 m) at 4× density.
- **`rifle.gd`:**
  - New "Magazine" exports: `mag_size` 30 and `reload_s` 2.5 s. `rounds` counts down per shot; `reloading` and `reload_progress` (0..1) track a reload.
  - It reloads by itself when empty (after the last shot, or on a trigger pull with none left), and `start_reload()` starts one early. No firing while reloading.
  - New signals `reload_started` and `reload_finished`.
  - Everyone's rifle does this, so squadmates and enemies run dry and reload mid-fight.
- **The animation** (`_reload_pose()`, as fractions of `reload_s`):
  - 0–0.15: the rifle tips 25° out to the right, pulled back 3 cm and lowered 6 cm (its shadow comes in). Tipping it in across the body hid it under the square in the first try.
  - 0.15: the gun shows `rifle_no_mag.png`, and the empty magazine drops out.
  - 0.5–0.72: the fresh magazine travels from the body to the magazine well, turning upright.
  - 0.72: it seats (`rifle.png`), with a 1.5 cm jolt.
  - 0.74–0.84: a 3.5 cm charging-handle pull.
  - 0.84–1: back up to the aim.
  - The aim keeps tracking underneath, so it comes back up on target.
- **`DroppedMag`** (an inner class): the empty magazine falls from the rifle's height under gravity, drifting out to the gun's right and spinning, its shadow closing in. It bounces once, lies on the ground 5 s, fades over 1 s and is removed.
- **Player:**
  - **R** reloads (new `reload` control in `world.gd`; not while busy, commanding or dead).
  - A yellow arc round the player fills clockwise from the top while reloading.
- **Death:** `death_fall.gd` calls `abandon_reload()`, so no fresh magazine is left hanging in mid-air.
- No reload sound yet; one can hang off `reload_started` or the drop and seat moments.

### 2026-10-30 — Reload sound; reload time from it
- Mike added `assets/sfx/RifleReload.mp3` (12.3 s). He asked for it to be used, with the reload time set by its length, for everyone, at a volume set by distance from the player.
- **The recording:** 5 complete reload takes, each three sounds: the magazine release (about −8.5 dB), the magazine seating (−5.3 dB) and the charging handle (−0.3 dB). Found from a 10 ms loud-event map.
- **Cut** (headless Blender) into `assets/sfx/rifle_reload/rifle_reload_0.wav` … `_4.wav`:
  - from 60 ms before the release to 220 ms after the charge, with a 120 ms fade, mono, normalised;
  - 1.92–1.99 s long.
  - Each take's moments (release, seat, charge pull and release) are measured and stored with it.
- **`rifle.gd`:**
  - `RELOAD_TAKES` holds the five, with their timings. A reload picks one at random (never the same twice running), and **lasts exactly its length**. The `reload_s` export (2.5 s) is gone.
  - The animation is timed to the take's own sounds:
    - the tip-out starts with the release, and the empty magazine drops on the release click;
    - the fresh magazine travels 0.35 s (`LOAD_S`) and seats on the clack;
    - the charging-handle pull spans the charge sound;
    - the rifle comes back up after it.
  - The sound plays from the magazine well. `attenuation` is 0 so the camera doesn't attenuate it; instead `_set_reload_volume()` sets its loudness every tick from the distance to the player (or the camera, if there's no player): full at 0, falling as (1 − d / `reload_hearing_m`)², silent at 25 m. On-screen panning still applies.
  - New exports `reload_volume_db` −2 and `reload_hearing_m` 25.
  - `abandon_reload()` (death) cuts the sound.
- Everyone's rifle uses it (squadmates, enemies).

### 2026-10-30 — Dry fire, manual reloads, spare magazines and the ammo HUD
- Mike added `assets/sfx/GunOutofAmmo.mp3`. He asked that the player not reload automatically: the rifle clicks when it's out, and reloading is up to him. He also wants the magazines and ammo he has left in a little HUD while he holds the right mouse button.
- **Sound:** the file holds 5 dry-fire clicks, 2 s apart. They're cut (like the impacts) into `assets/sfx/dry_fire/dry_fire_0.wav` … `_4.wav`, 0.23–0.25 s each.
- **`rifle.gd`:**
  - **`auto_reload`** (default on): off, an empty rifle's trigger plays a dry-fire click (random, no repeats, ±4% pitch, heard to 15 m) and doesn't reload by itself.
  - **`spare_mags`** (default −1, as many as needed): counted spares are tracked by their rounds (`_spares`).
  - **Swapping:** a reload swaps in the fullest spare. The magazine coming out is kept as a spare if it still has rounds; only an empty one drops to the ground (DroppedMag). With no spare holding more than the current magazine, `start_reload()` refuses.
  - New `spare_count()` and `spare_rounds()`.
- **`player.tscn`** Rifle: `spare_mags` **6**, `auto_reload` **off**. Squadmates and enemies keep the defaults: auto-reload, unlimited.
- **`player.gd`, the ammo HUD:**
  - Shown while the right mouse button (`aim`) is held, and not when busy, commanding or dead.
  - A small panel (`ui_style.gd`) just right of and below the square on screen.
  - It reads "AMMO 23 / 30", in red at 0, or "RELOADING", and "MAGS 6 (180 rounds)".

### 2026-10-30 — Ammo crate (first supply crate)
- Mike: a new asset, an ammo crate, the first of many crate types, after his reference photo (a tarped load on a pallet), with the tarp removed and the pallet filled with ammo cans.
- **`blender/scripts/crates.py`** (new, headless; see the Asset List): every crate shares `build_pallet()` and `build_straps()`, with one loader per kind in `KINDS`, `ammo` first (`build_ammo_load()`).
  - It renders the top-down `assets/props/crate_<kind>.png`, an angled review render and the .blend.
  - It prints the footprints and heights the game's shadow uses.
  - `blender --background --python crates.py -- ammo` renders just that kind.
- **`scripts/crate.gd`** (new, shared by every crate):
  - A StaticBody2D on the squares' layer, so it's solid: squares walk round it, and bullets and sight lines stop at it, so it's full cover. It's in the "crates" group.
  - **Shadow:** the pallet footprint swept along the sun to its height, and the load's to its top, drawn in one CanvasGroup (no double-dark overlap). Worked out against the node's turn, so turned crates shadow correctly.
  - Exports `pallet_m`, `pallet_height_m`, `load_m` and `load_height_m`, defaulting to the ammo crate's.
- **`scenes/crate_ammo.tscn`** (new): the script, a Shadow group (z −10), the Body sprite (0.25, mipmaps) and a 102.4 × 68.3 px collision box (the pallet). Drop it into a level and turn it as needed. As with sandbags, a turned crate's baked lighting turns with it.
- Tested (`test_crate.gd`):
  - Walking into it, the player stopped 0.60 m from its centre (half the pallet plus half a square).
  - A bullet fired at it stopped.
  - An enemy on one side can't see the player hidden on the other.
  - Screenshot: one crate square-on and one turned 90°, both shadowing correctly.
- No pickup yet: it doesn't resupply anyone. That's the obvious next step for an ammo crate, along with a bullet-hit effect and sound for it.

### 2026-10-30 — Ammo crate squared off
- Mike liked it, but wants it squared off: a 2 × 4 block of ammo cans.
- **`crates.py`:**
  - The load is 4 cans across × 2 deep × 3 high (24 cans), 0.632 × 0.618 m, nearly square.
  - The pallet is 0.8 m square to match.
  - The frame is 1.125 m (384 px) instead of 1.5 m.
- **`crate.gd`** defaults `pallet_m` 0.8 × 0.8 and `load_m` 0.632 × 0.618. **`crate_ammo.tscn`**'s collision box is 68.27 px square.

### 2026-10-30 — Sandbag crate
- Mike: an identical crate, same pallet, with sandbags on it.
- **`crates.py`**, new `sandbags` kind (`build_sandbag_load()`):
  - Imports `sandbags.py` for its `bag()` model and burlap, so the bags match the wall's.
  - **Bags:** 0.37 × 0.235 m (`SAND_BAG_L`, `SAND_BAG_W`, a touch smaller than the wall's, so they sit on the pallet and its edge shows from above), 2 × 3 to a layer, 5 layers (`SAND_LAYERS`) with alternate layers turned 90°. Each bag is shaped differently (keyed `bag_rng`).
  - **Size:** the footprint and top are measured from the bags' bounding boxes: 0.768 × 0.772 m, top at 0.747 m, about the ammo crate's height.
  - **Straps:** they cinch `SAND_CINCH` 4 cm into the bags. Run through the bags' bulges, they first stood off them like a cage.
- **`crate.gd`:** new `impact` export. A crate with one shows a stopping bullet (`bullet_hit()`) with a dust puff and that `impact_sound.gd` sound. Empty (the ammo crate) shows nothing.
- **`scenes/crate_sandbags.tscn`** (new): like the ammo crate's, with `load_m` 0.768 × 0.772, `load_height_m` 0.747 and `impact` "sand".

### 2026-10-30 — Sandbag crate straps; a lone ammo can
- Mike: make the sandbag crate's straps the same as the ammo crate's, and add an ammo can asset the same size as the ones on the pallet.
- **Sandbag crate:** the cinch is gone (`SAND_CINCH` removed), so `build_straps()` runs over the load's top and down its sides as on the ammo crate. Re-rendered.
- **Lone ammo can** (`crates.py render_can()`, `-- can`, also rendered by default):
  - The same `build_ammo_can()` and materials as the crate's cans, on its own.
  - It renders `assets/props/ammo_can.png` (0.375 m frame, 128 px), an angled review and `blender/source/ammo_can.blend`.
  - It measures itself: 0.160 × 0.320 m, top 0.207 m.
- **`crate.gd`:** a zero `pallet_m` means no pallet, and its shadow part is skipped.
- **`scenes/ammo_can.tscn`** (new): `crate.gd` with no pallet, the can's footprint and height, and a 13.65 × 27.3 px collision box. Solid and small, like the crates.

### 2026-10-30 — The pallet is its own sprite: squares can stand over its edge
- Mike (screenshot): right up against a crate his square went under the pallet. He wants to be above the pallet but not clip into the load on it.
- **Why:** each crate was one sprite at the squares' level, and its collision box was the whole pallet.
- **`crates.py`:**
  - `crate_<kind>.png` is now the load and straps only.
  - The pallet is rendered once on its own (`render_pallet()`, `-- pallet`) to `assets/props/pallet.png`, in the same 1.125 m frame, with mipmaps.
  - The angled reviews and .blends still include the pallet.
- **Crate scenes** (`crate_ammo.tscn`, `crate_sandbags.tscn`):
  - A `Pallet` sprite at z −6, under the squares (their shadows, at z 0, fall on it).
  - The load (`Body`) at the squares' level.
  - The collision box is now the **load's** footprint (ammo 53.9 × 52.7 px, sandbags 65.5 × 65.9 px), so a square can step over the pallet's edge but not into the load.
- **`crate.gd`:** a new `PalletShadow` group (z −5, over the pallet, under the squares) draws the load's shadow across the deck: the load swept from the deck's height to its top, cut to the deck (`_draw_deck_shadow()`). Splitting the renders lost the load's own baked shadow on the deck. The sweep is shared as `_sweep()`. Scenes without a `PalletShadow` (the lone ammo can) skip it.

### 2026-10-30 — Metal impacts on the ammo cans
- Mike added `assets/sfx/MetalImpact.mp3` (5.2 s), to be broken apart and used for bullets hitting the ammo crate, with a contact effect.
- **Split** like the other impacts into `assets/sfx/metal_impact/metal_impact_0.wav` … `_2.wav` (3 clangs, 0.50–0.54 s each). They're added to `impact_sound.gd` as the "metal" kind.
- **New `scripts/hit_sparks.gd`:** a bright 0.06 s flash at the hit point and 9 short streaks glancing back toward the shooter (±70°). They fly at 3–7 m/s, slow quickly, and cool from white-yellow to orange as they fade over 0.08–0.22 s, then they're removed.
- **`crate.gd bullet_hit()`:** "metal" gives sparks; any other `impact` gives the dust puff as before; both play the impact sound.
- `crate_ammo.tscn` and `ammo_can.tscn` set `impact = "metal"` (the lone can is the same steel).

