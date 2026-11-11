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

## Start Here: Current State (updated 2026-11-03)

**Read this first in a new session.** The dated Log at the bottom has every change in detail (what, why, how it was tested); this is the summary. The watch tower work is finished for now (Mike, 2026-11-03: taking a break from it) and merged into `main` (pushed); `watch_tower` is at the same commit.

### Controls

| Input | Action |
|-------|--------|
| WASD / arrows | Walk (screen directions; you can strafe) |
| **Shift** (hold) | Run (the Player's `run_speed_mps`, 3.2 m/s; walking 1.6). Not while carrying or commanding. Running shots stray more |
| Mouse / left click | Aim / fire (one shot per click). Accurate to 6 m past the rifle, then a spreading cone; some shots go into the ground at range. Standing still steadies the aim |
| **Right mouse** (hold) | The aiming line and spread wedge, and the ammo panel (rounds, spare magazines) |
| **R** | Reload (the player's rifle doesn't reload by itself; empty, the trigger clicks) |
| **Space** (hold) | Command mode: the 8 m command circle, the ORDERS and DEPLOY menus left of you (folded away to start with: the small triangle beside you opens and folds them). Click a squadmate to select (Shift-click adds, drag a box). Left click orders the selection (nobody selected: everyone in the circle): open ground, go there; a sandbag wall's box, dig in along it; a supply crate, build from it (a strapped one with nothing to build: the nearest free one unstraps it); an ammo can, load from it; a spot on a watch tower, the nearest place to stand up there. Right click: the selection only |
| **X** | Back: out of placing equipment or aiming the dish to the menu; X again closes it |
| **F** | Interact with the closest thing: the radio desk (RADIO menu, hang up radio command), take a part off a crate, deliver it to a site; hold F at a strapped crate to undo its straps |
| **Q** | Debug mode: each square's number (the battle log's) and state over it; click a square, crate, tower part or anything solid for its panel (cover class, height class, protection, and for a tower part its height profile and section circles). Enemy detection circles show only here. Wheel-button drag pans |
| **F9** | Start / stop the battle log (`logs/battle_log.txt`; the battle-log skill reads it). It records the squares and the supply truck: who is in which seat, its driving and its crane |

### What's in the game

- **The level** (`scenes/main.tscn`): field and road, the Player (Inspector: Drop Off Animation off, Unlimited Ammo on, as Mike has it), 10 squadmates (`Squadmate`…`Squadmate10`), supply crates (ammo, sandbags, comms, watch tower), three sandbag walls, a watch tower with a radio station on it, the Command node (Menu Toggle Px 51), Arrival (the helicopter drop-off) and the EnemySpawner (a HUD top right: How many, 1-10, then Drop by helicopter and a click anywhere on the field; an enemy helicopter lands them there; no enemies are placed). The field is 2 square miles (2276 m square) with this level in its middle; roads can meet at T and crossroads junctions (`scenes/road_junction.tscn`).
- **Squares** (`soldier.gd`, everyone): health, hit reactions, ragdoll deaths, a rifle with magazines (everyone carries 2 spares, can be empty; ammo from cans, crates and the dead), climbing sandbags, going up the watch tower's stairs.
- **Squadmates** (`squadmate.gd`, `ai_soldier.gd`): states IDLE, MOVE, FOLLOW (Follow me / Lead), ATTENTION, DEFEND (dug in at a sandbag wall), BUILD (fetch parts from crates to sites), SURPRISED (attacked while idle: run for cover, fight from it), PINNED (outnumbered against dug-in enemies: get down). Any order puts them **under orders** (no surprises, no ammo runs on their own) until Disperse. Fire / Stop orders; the standoff (hold fire with no window on a dug-in foe).
- **Enemies** (`enemy.gd`): CALM, ENGAGE, SEARCH, RETURN, SURPRISED; 10 m detection circles, sight, hearing shots; take cover, dig in at sandbags, use ammo crates.
- **Cover** (`cover.gd`): cover classes 1-3 by how much they stop; sandbags (exposed while you fire over them), crates, the radio desk and dish, the tower. Height classes 1-3 (sandbags 1, crates 2, the tower 3).
- **Watch tower** (`watch_tower.gd`, built from its crate in 5 parts): climbable stair with seamless steps on and off, railings, roof and stairs fade to show who's in or under them, places to stand (top landing, east walkway by the door, south walkway, mid landing, shelter), squadmates route up and down, a radio station can go on it. Squares killed up there lie on it, or hit a railing and go over it to the ground (`death_fall.gd`). **Height profiles** (`height_profile.gd`, files in `assets/height_profiles/`), one per part (Lower Stairs, Upper Stairs, Top, Shelter): Height Class, Pass Through, **Shots Away** (firing from there: per section by the cover's distance, pass-through per cover class, for cover as high as the part or lower) and **Shots Into** (shot at there: per section by the shooter's distance, the part's Pass Through from that far, Seen, Above %). Saving a profile while the game runs is picked up live. Sections are measured from each part's own middle and drawn in debug mode.
- **Radio station** (`radio_station.gd`, `radio_terminal.gd`): built from a comms crate; the RADIO menu: radio command (through radio operators in the dish beam), troop requests by helicopter, equipment drops by parachute (ammo, sandbag, comms and watch tower crates), the dish aimed from the menu.
- **Deploy** (command mode): radio station, sandbags (unlimited), ammo cans, watch tower; crate-built ones go down as sites and get built from crates.
- **Supply truck** (`supply_truck.tscn`, `supply_truck.gd`; branch `Supply_Truck`): an 8x8 truck with a loader crane and a flatbed for two pallets. F at the driver's door gets in and out; W/S throttle and reverse, A/D steer (car style). Clicking it in command mode sends the selection (or whoever's in the circle) in; with a squadmate driving, the **Park** order places a ghost of where it parks and which way it faces (scroll turns it) and the driver gets it there. While the player drives, command mode's orders are Hatch and Crane. Delivered by helicopter from a radio station (Deploy > Vehicles: slung under it, set down at the LZ). The crane and bed don't work yet.

### Next steps

1. **Enemies going up a nearby watch tower** (agreed with Mike, 2026-11-02; not crates).
2. **Seen in Shots Into:** Mike was offered making Seen off mean "can't be seen from this distance" (now it only means cover isn't ignored). Undecided.
3. Older ideas: vehicles in the Deploy menu, more unit types, the dish heading mattering for comms, helicopter extraction.

### Loose ends and known issues

- **Testing values to restore:** `seconds_per_troop` and `seconds_per_crate` 1 s in `radio_terminal.gd`; `max_health` 2 in `soldier.gd`; enemies' health 4 in the EnemySpawner; unlimited sandbags (`player.gd deployables`); the Player's Unlimited Ammo on.
- The AI doesn't weigh Shots Into Above % when choosing whom to shoot (it's a roll per shot).
- A crate on the ground under the tower's deck counts as up on the tower to the AI (a squadmate sent to it climbs the stair). A drop can land one there.
- `scenes/main.tscn5089658625.tmp` is a leftover Godot temp file; safe to delete.
- Tests: `tests/` (see its README). `test_ammo_can.gd`'s mate 2 doesn't fetch ammo: it's under orders, so by the ORDERS rule it won't (the test predates the rule).

### How to work on this project

See `CLAUDE.md` for the working rules (scratch-copy testing while Mike's editor is open, headless tests, art scale and lighting) and `tests/README.md` for rerunning the tests.

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
│   ├── road_junction.gd ← a T or crossroads tile; road ends snap onto its arms
│   ├── tree.gd          ← a tree: Type, Growth, Size; shadow, fading crown, solid trunk
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
│   ├── battle_log.gd    ← F9 battle log: records every square's actions to logs/battle_log.txt; numbers the squares; logs vehicles (V lines, seats, crane)
│   ├── debug_overlay.gd ← Q debug mode: each square's log number over it
│   └── sandbags.gd      ← deployable sandbag wall: solid cover, sand puffs, swept shadow
├── logs/                ← battle logs (has a .gdignore; not in git)
├── tests/               ← headless test scripts (has a .gdignore; README.md says how to run them)
├── .claude/skills/battle-log/ ← Claude skill for reading a battle log and tuning the AI
├── blender/             ← ignored by Godot
│   ├── scripts/         ← Python generators (source of truth for assets)
│   │   ├── bs_common.py ← shared sun, sky, camera and pixel scale; all scripts use it
│   │   ├── field_grass.py
│   │   ├── road_asphalt.py
│   │   ├── road_junction.py
│   │   ├── trees.py
│   │   ├── sandbags.py
│   │   ├── character_square.py
│   │   ├── rifle.py
│   │   ├── radio_pack.py
│   │   ├── helicopter.py
│   │   ├── supply_truck.py  ← the supply truck (`-- draft <folder>` renders outside the project)
│   │   └── radio_station.py
│   └── source/          ← saved .blend files (written by the scripts)
└── assets/
    ├── textures/        ← tiling ground images
    ├── characters/      ← character sprites and their shadows
    ├── vehicles/        ← helicopter and supply truck parts (the truck's stabiliser animation sheet too), and their shadow outlines
    ├── props/           ← static props (comms station) and their shadows
    ├── height_profiles/ ← height profiles (height_profile.gd .tres): the watch tower's parts' Shots Away / Shots Into
    ├── sfx/             ← sound effects (.wav / .ogg)
    └── previews/        ← review renders, ignored by Godot
```

---

## Screen Resolution

- The game is designed at **1920×1080**. All art is sized for that: the grass tile is 1024 px, so about 1.9 tiles span the screen width.
- Stretch mode `canvas_items`: the game scales smoothly to any window size, so 1080p, 1440p and 4K all show the same view, just sharper.
- Aspect `expand`: on screens that aren't 16:9 (ultrawide, 16:10, odd window sizes), the player sees *more* of the field instead of black bars. `field.gd` resizes the grass to cover whatever area is visible. Tested at 1280×720 (shows 1920×1080) and 1720×720 ultrawide (shows 2580×1080).
- Keep anything important (UI, the playable area) inside the central 1920×1080; extra width or height is only for show.
- **Arena:** the play area is `World.ARENA`: 2 square miles, 2276 m square (2026-11-09; it was 3840×2160 px, 45 × 25.3 m), centred on the old field's middle, so main.tscn's level sits in its middle. The player can't leave it; `arena_edge.gd` draws the barrier, and the camera can show 2 m past it. At the furthest zoom out you see about 105 m of it.
- **Camera zoom (scroll wheel):** from 0.5× to 3×, at 1.15× per notch, easing smoothly.
  - (Written for the old 45 m arena: the camera now always follows the player, stopping only at the 2 km field's edges.)
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
| Road junctions: T and crossroads, 4 conditions each (1024×1024, 12 m square) | Done, **in the game** (`scenes/road_junction.tscn`: Kind, Condition) | `blender/scripts/road_junction.py` (`-- clean ok medium bad` to render only some; about 25 s a tile) | `assets/textures/road_junction_{t,cross}{,_ok,_medium,_bad}.png`. The asphalt is the strips' 5 m bands crossing (the T's stem toward the image's bottom), inside corners rounded (2 m), edge lines following them round and stopping at the openings, no centre dashes; each arm ends at the tile's edge as a strip does, so a road meets it. The damage is made as the strips' (road_asphalt.py's settings, noise and colours), from the distance to the asphalt's outline. A damaged road's ragged edge and wear can't line up exactly at a join (a road ends anywhere along its 12 m pattern); the edge, paint and verge do. Previews: `assets/previews/road_junction_*_preview.png` (each tile with a strip of the same condition on every arm). |
| Trees: pine, spruce, oak, maple, cottonwood × sapling, young, mature | Done, **in the game** (`scenes/tree.tscn`: Type, Growth, Size) | `blender/scripts/trees.py` (`-- oak maple mature` to render only some; all 15 in about 2 minutes) | `assets/props/trees/tree_<type>_<growth>.png` (the tree, centred on its trunk, at the game's density) and `_shadow.png` (half density, shown at 2x, alpha 0.71), `trees.json` (each one's height, crown and trunk radius, where its shadow goes: tree.gd reads it). Mature: pine 22 m tall, 7 m across; spruce 12 m, 7 m; oak 14 m, 19 m; maple 15.5 m, 13 m; cottonwood 21.6 m, 18 m. Broadleaves: a trunk and limbs, and the crown as rounded clusters of diamond-shaped leaves over a dome (oak dense; maple and cottonwood with gaps the limbs show through). Conifers: whorls of drooping branches packed with needle twigs and tufts, tips lighter. Previews: `assets/previews/trees_<type>_preview.png` (its three growths over the field, with shadows). The .import files (mipmaps on) were written before the PNGs. |
| Sandbag wall (deployable), 6 tiles | Done (v2: tiles that join into one wall), **in the game via DEPLOY** | `blender/scripts/sandbags.py` | `assets/props/sandbags_{single,start,end,mid_0,mid_1,mid_2}.png` (272 × 128 px = 0.797 × 0.375 m, **rendered at 4× density**, shown at 0.25 with mipmaps; each has a `.import` with mipmaps on). After Mike's reference photo: one stack of 3 courses, a single bag deep (the two-deep base of v1 is gone), 0.354 m high, 0.282 m wide at the foot, the courses stepping in 5% each as they rise. Big, boxy, lumpy tan burlap bags (0.4 × 0.256 × 0.136 m; 1.6× v2's) in a running bond: even courses two bags a tile, odd ones offset half a bag, so one bag straddles each join. Tiles are 0.797 m (68 game px, two squares) and join end to end seamlessly: each is rendered with the neighbours' bags that reach into it, and the bags at a join are keyed by position (`bag_rng()`) so every tile builds them the same, then cropped to the tile. **single:** both ends finished with half bags. **start / end:** finished at −x / +x. **mid_0–2:** joined at both ends, with different middle bags so long rows don't repeat. Lit by the standard sun; the game draws the shadow. Review: `assets/previews/sandbags_preview.png` (an angled run of five), `sandbags_tiles_preview.png` (the tiles laid edge to edge), `sandbags_rows_preview.png` and `sandbags_join_closeup.png` (in the game). All six render in about 15 s. **Damage** (since 2026-10-30): every tile also as `sandbags_<kind>_d1.png` and `_d2.png` (272 × 192 px, a taller frame for spilt sand, centred), and `sandbags_collapsed.png` (a puddle of sand with burlap scraps). |
| Ammo crate (first of the supply crates) | Done, **scene ready to place** (`scenes/crate_ammo.tscn`) | `blender/scripts/crates.py` (`-- ammo`) | `assets/props/crate_ammo.png` (384 × 384 px = 1.125 m square, **rendered at 4× density**, shown at 0.25 with mipmaps; `.import` has mipmaps on). After Mike's reference photo (a tarped pallet), without the tarp: a 0.8 m square four-way wooden pallet (0.144 m high: bottom boards, nine blocks, stringers, seven deck boards, pine with grain) loaded with 24 olive-drab M2A1-size ammo cans in a square block (4 across × 2 deep × 3 high; each with a rimmed lid, folding handle, end latch and yellow stencil marks, a little out of true) under black ratchet straps both ways with buckles on top. Load 0.632 × 0.618 m, top at 0.732 m. Lit by the standard sun; the game draws the shadow (`scripts/crate.gd`). Review: `assets/previews/crate_ammo_preview.png` (angled). Other crate kinds will be added to `KINDS` in the same script. |
| Sandbag crate | Done, **scene ready to place** (`scenes/crate_sandbags.tscn`) | `blender/scripts/crates.py` (`-- sandbags`) | `assets/props/crate_sandbags.png` (384 × 384 px = 1.125 m square, 4× density, mipmaps). The ammo crate's pallet and straps, loaded with 30 filled burlap sandbags (the wall's bag model and burlap from `sandbags.py`, a touch smaller: 0.37 × 0.235 m), 2 × 3 to a layer, 5 layers, each turned 90° from the one below. Straps as on the ammo crate. Load 0.768 × 0.772 m, top at 0.747 m. A supply of 10 sandbag walls; as they're used it shows smaller stacks: `crate_sandbags_1.png` … `_3.png` (24, 15 and 3 bags left, no straps; `SAND_STAGES`). Review: `assets/previews/crate_sandbags_preview.png`. |
| Comms crate | Done, **in the game** (equipment drops; the radio station is built from it) | `blender/scripts/crates.py` (`-- comms`) | `assets/props/crate_comms.png` (full, strapped) and `crate_comms_1.png` … `_4.png` (1–4 parts taken, no straps), 384 × 384 px, 4× density, mipmaps. One item per station part, side by side so each shows from above, in the order they come off: the desk folded into a grey bundle (two panels, folded legs, webbing ties) along the north side; the electronics in a black rugged case; the dish's legs in an olive case; the dish in a rounded desert-tan case; the wiring on an olive cable reel. Load 0.720 × 0.737 m, top at 0.422 m. Review: `assets/previews/crate_comms_preview.png`. |
| Ammo can (lone) | Done, **scene ready to place** (`scenes/ammo_can.tscn`) | `blender/scripts/crates.py` (`-- can`) | `assets/props/hold_ammo_can.png` (128 × 128 px = 0.375 m square, 4× density, mipmaps). One of the ammo crate's cans on its own: olive drab, rimmed lid, folding handle, end latch, yellow stencils. 0.16 × 0.32 m, top at 0.207 m. Review: `assets/previews/hold_ammo_can_preview.png`. |
| Cargo parachute | Done, **in the game** (equipment drops) | `blender/scripts/parachute.py` | `assets/vehicles/parachute.png` (938 × 938 px = 5.5 m square, **rendered at 2×**, shown at 0.5 with mipmaps). A round 5 m cargo canopy, top-down: 16 gores in two olive drabs, sewn radial seam tapes, a darker hem, an apex vent, the skirt scalloped between the lines. Review: `assets/previews/parachute_preview.png` (on its lines over an ammo crate). |
| Rifle | Done (v2, detailed) | `blender/scripts/rifle.py` | `assets/characters/hold_rifle.png` (384 px, **rendered at 4× density**, shown at 0.25 scale with mipmaps so it stays sharp when zoomed in). 0.48 m from pivot to muzzle (0.28 m beyond the front face). Parts: gunmetal receiver, red-dot sight with a red lens, polymer handguard, front sight post, barrel, muzzle brake, and a forward-raked magazine. **Canted 30°** so the magazine shows from above (it pokes out to the gun's right). Lit from straight overhead so it can rotate; its shadow is drawn in Godot. With it, `hold_rifle_no_mag.png` and `hold_magazine.png` for the reload. v1 (plain bar) is in `assets/previews/rifle_v1_plain.png`. |
| Radio pack (radio operator) | Done (v1) | `blender/scripts/radio_pack.py` | `assets/characters/radio_pack.png` (614 px = 1.8 m, **rendered at 4× density**, shown at 0.25 scale with mipmaps), centred on the square's centre, square facing +x. Brown canvas pack on the square's back (0.16 m deep, 0.3 m wide, top at 0.44 m, just above the square), darker top flap and side pouches, shoulder straps over the square's top, the radio's top with two knobs, and a 0.6 m whip antenna raked 32° back with a tip cap. Lit from straight overhead so it turns with the square; its shadow is drawn in Godot (`radio_pack.gd`). |
| Helicopter (UH-60-style transport) | Done (v3, 0.55 scale, cockpit, flies insertions) | `blender/scripts/helicopter.py` | Modelled at real size, then shrunk by `SCALE` = 0.55 (`helicopter.gd SCALE` must match): fuselage 8.4 m, rotor 9 m. Cockpit (laid out for scale 0.5 and grown with `SCALE`): two red pilot squares, 0.44 m, corners rounded like the player's (upright edges only, top edges sharp), under dark tinted glass (alpha 0.85); an instrument panel with screens, switch strips and a centre console with lamps. `assets/vehicles/helicopter_body.png` (939 px = 11 m, nose to +x; cockpit interior without pilots or glass), `helicopter_pilot.png` (one pilot, lit as in the cockpit; the game draws two and animates them), `helicopter_glass.png` (glass only, drawn over the pilots) and `helicopter_rotor.png` (centred on the mast), both lit from straight overhead so they can face any heading. Plus 4 half-res shadow outlines `helicopter_shadow_{body,stabilator,fin,tailrotor}.png` (padded for sweeping). Olive drab, matte, no markings; black blades with yellow tip bands. Renders in about 15 s. |
| Supply truck (8x8, loader crane, flatbed for two pallets) | Done (v1, look only: no scene yet) | `blender/scripts/supply_truck.py` | `assets/vehicles/supply_truck_body.png` (802 px = 4.7 m, **rendered at 2x**, shown at 0.5 with mipmaps; nose to +x, centred on the truck's middle) and `supply_truck_crane.png` (376 px = 2.2 m, centred on the slewing axis, CRANE_X_M 0.23 m ahead of the middle), both lit from straight overhead so they can turn (the game will draw the shadow). Olive drab, unmarked, after Mike's reference photos: 4.3 m long, 1.37 m over the tyres, cab roof 1.74 m; cab, engine module, crane bay with stabiliser legs, flatbed 2.0 x 1.2 m (deck 0.8 m up) for two 0.8 m pallets, four axles. The crane is stowed: main boom up, outer boom folded forward over the module. Reviews: `assets/previews/supply_truck_preview.png` (top-down, standard sun, two ammo crates on the bed, a red square) and `supply_truck_angle_preview.png`. Renders in about 10 s. |
| Supply truck stabilisers (animation) | Done, **in the game** (2026-11-11) | `blender/scripts/supply_truck.py` (`build_stabs()`) | `assets/vehicles/supply_truck_stabilizer_sheet.png` (25 frames × 128 px = 0.75 m, 2×, mipmaps), the left stabiliser keyframed from stowed to down: the inner beam slides out of its housing (0.6 → 0.86 m out), then the jack's ram pushes the foot pad 0.17 m down to the ground. The body is a holdout in it, so what's inside the housing is cut out. `supply_truck_shadow_stabilizer_sheet.png` (25 × 112 px, half density, ~1 m spare round each for the sweep). The game mirrors both for the right. Review: `assets/previews/supply_truck_stabilizers_preview.png` (down, angled). The keyframes are in `blender/source/supply_truck.blend` (frames 0–24). |
| Deployable comms station (desk, laptop, small satellite dish; no platform since 2026-10-30) | Done, **in the game via DEPLOY** | `blender/scripts/radio_station.py` | Its parts rendered separately, all 2× density (show at scale 0.5), since 2026-10-30: `radio_station_desk.png`, `_electronics.png`, `_stand.png` (z −1), their shadows `radio_station_shadow_desk.png`, `_electronics.png`, `_stand.png` (z −10), `radio_station_ground.png` (the ground cable, z −5), `radio_station_shadow.png` (1109 px = 6.5 m, centred on the station's middle), and `radio_station_dish.png` (2.4 m, centred on the dish post, lit from overhead, rotated in game). **Compact since 2026-10-29:** a 2 m square plank operator platform centred 1.05 m north of the origin, with a field desk along its east edge carrying a radio (whip antenna, handset), the detailed rugged laptop (lit mapping-app screen, mouse), a power unit, a headset, a notebook and a mug; the antenna (since 2026-10-30) is a desert-tan flyaway satellite terminal 1.1 m south of the origin, inside the platform's width: four splayed outrigger legs on round grey foot pads braced to a centre column, a pan/tilt head and yoke, a 1.2 m dish at 40° elevation with a rolled rim and a centre feed boom, and a black cable down the column. The head, yoke, dish, rim, boom and feed are the turning image; the base stays in the station image; one cable from the desk to the dish. The 7 m guyed mast and its stakes are gone. Lit by the normal top-left sun (it doesn't turn), with its shadow rendered separately and normalised like the squares'. Review images: `assets/previews/radio_station_preview.png` (an in-game screenshot) and `radio_station_dish_preview.png` (an angled close-up of the antenna). Renders in about 20 s. |
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

### 2026-10-30 — Equipment requests: crates dropped by parachute
- Mike: another Deploy item, **Equipment**, with a window like Troop Request but 2 × 2. For now it can hold an ammo crate or a sandbag crate. He also asked for a parachute model. When equipment is summoned, the helicopter drops it from a realistic height, the parachute deploys, and the crates land right where they were summoned. Placing it should show a ghost formation, like lining up troops.
- **Parachute** (new `blender/scripts/parachute.py`; see the Asset List). It's 5 m across, a compromise: a real cargo chute is 10–20 m, which would fill the screen.
- **`radio_terminal.gd`:**
  - Deploy's pop-out is now Troops / **Equipment** / Vehicles.
  - **The request:** Equipment opens the **EQUIPMENT REQUEST** panel: 4 slots in a 2 × 2 grid (`EQUIP_SLOTS`, `EQUIP_PER_ROW`). Each slot has a hold pop-out (`EQUIPMENT_TYPES`: Ammo crate or Sandbag crate, with drawn crate icons; a quick click gives an ammo crate), plus Send helicopter and Clear.
  - **Readying:** the filled slots ready one after another, `seconds_per_crate` each (**1 s for testing**), alongside the troop request. The pad timer shows both, one line each.
  - **The drop zone** (new screen DZ): the ghost (`_draw_dz_ghost()`) shows each crate as it will land (pallet and load sprites, see-through) in its grid position, `DROP_PITCH_M` 1.6 m apart.
    - It follows the mouse, and the wheel turns it on the 15° grid (`_turned()`, a copy of command.gd's, since preloading command.gd here would be a cycle).
    - A crate's spot is red if it's off the field or anything solid overlaps its `DROP_CLEAR_M` 0.85 m square (`_drop_spot_ok()`, a physics shape query).
    - A click with every spot green sends the drop. Right click or Esc goes back.
- **New `scripts/supply_drop.gd`:** the helicopter's run. It comes in from the west at 25 m along the line through the drops' middle, slowing to 8 m/s and letting down to 20 m over the last 30 m. It releases each crate as it passes over its spot (west to east), then speeds up, climbs and leaves east. The hull is never solid.
- **New `scripts/air_drop.gd`:** a crate coming down.
  - **Falling:** 0.9 s free fall, then the canopy blossoms open over 0.7 s (a little overshoot) and brakes it to 5 m/s. It sways ±4°.
  - **On target:** it steers from where it was let go to its exact spot as it comes down.
  - **In the air:** it grows 1% per metre up, like the helicopter. Its footprint and the canopy cast shadows on the ground, offset by their heights. It isn't solid, and it's drawn over everyone.
  - **Touchdown:** exactly on the spot and turned as set. The crate becomes solid with its own shadows, there's a ring of dust and a thud (concrete on a road, dirt elsewhere), and the canopy flattens, drifts 2.2 m downwind and fades over 2.5 s.
  - The crate is the real crate scene throughout (its collision and shadows off while airborne).
- Tested (`test_airdrop.gd`):
  - **Request:** the station's terminal opened Equipment with 4 slots; 3 were filled (ammo, sandbags, ammo).
  - **Ghost:** laid out 1.6 m apart at 15°. Spots on the station's desk or on a crate were refused.
  - **Drop:** the drop sent one helicopter. All 3 crates landed **0.000 m off** their spots, about 4 s after release, solid, at 15°. The parachutes and the helicopter cleared up afterwards.
  - Screenshots: three canopies coming down together; the three crates down on the road with dust.
- At 1.6 m apart the 5 m canopies overlap heavily on the way down. Smaller canopies or wider spacing would fix that if it bothers.

### 2026-10-30 — Dropped crates draw under the helicopter
- Mike: just as the helicopter lets a crate go, the crate looks like it's in front of (over) the helicopter.
- **Verified** with a screenshot 8 ticks after release: the crate was drawn over the tail boom and a rotor blade. `air_drop.gd` drew the falling crate at z 40 and the canopy at z 41, over the helicopter's body (z 5) and rotor (z 19–20).
- **Fix:** the falling crate is at `CRATE_Z` 3 and the canopy at `CANOPY_Z` 4: over the squares (z 0), under any helicopter. The crate drops back to z 0 on landing, as before.

### 2026-10-30 — The canopy settles straight down onto the crate
- Mike: instead of collapsing off to the side, the parachute should drift straight down, with a little physics if it's worth it.
- **`air_drop.gd _settle_canopy()`:** after touchdown the canopy comes down on its own, straight down over its crate.
  - **Physics:** its speed changes by g − drag·v|v|, where drag = g / `CANOPY_SINK_MPS`² × inflation, so fully open it sinks at 1.5 m/s. The load's gone, so it brakes hard from the 5 m/s it was doing and nearly floats.
  - **Deflating:** it spills air as `_inflation` falls toward `DEFLATED` 0.4 over about `DEFLATE_S` 1 s. With less drag it sinks faster (≈2.4 m/s at 0.4).
  - **Look:** drawn from 100% down to `DEFLATED_LOOK` 55% of its open size as it deflates. It ripples (`FLUTTER` ±6% at 1.6 Hz, fading as it deflates) and wanders up to 0.12 m over the crate, less as it gets lower. Its shadow closes in as its height drops.
  - **Draping:** once it's down to the load's top (`crate.load_height_m`), it spreads 15% (`DRAPE_SPREAD`) and fades over `DRAPE_S` 1.6 s, then it's removed.
- The sideways drift (`WIND`, `COLLAPSE_*`) is gone.

### 2026-10-30 — Radio station: no wooden platform
- Mike: what bothered him about the radio station was the wooden platform. It should just be the desk and the satellite.
- **`radio_station.py`:**
  - `build_platform()` (the plank deck, joists and edging) and `PLATFORM_H` are removed.
  - The desk stands on the ground at the same spot (`DESK_AT` = `PLATFORM_AT` + (0.65, 0, 0)).
  - The cable is one run along the ground from the desk to the dish.
  - `GROUND_PARTS` is just the cable now.
  - `PLATFORM_AT` and `PLATFORM_M` stay as the operator's spot (2 m square) so nothing else moves.
- Re-rendered `radio_station.png`, `_ground.png`, `_shadow.png`, `_dish.png` and the desk close-up.
- **Game:** no changes needed. The desk collision, the green operator box (OperatorZone and StandBox), the dish and its tuning box are all in the same places. Comments in `radio_station.gd` and `radio_terminal.gd` no longer mention the platform.
- Checked in game (screenshot): the desk on the grass with its kit and shadow, the cable over the ground to the dish, the green boxes as before, and the player registers on the operator box.

### 2026-10-30 — The settling canopy spreads instead of shrinking
- Mike: when the parachute collapses after touchdown it shouldn't shrink. If anything it would get slightly bigger.
- **`air_drop.gd _canopy_look()`:** going slack (as `_inflation` falls), the canopy is drawn growing from its open size to `SLACK_LOOK` 112% (the dome flattening and spreading), instead of shrinking to 55%. It spreads `DRAPE_SPREAD` 6% more as it drapes over the load (was 15%).
- **Never smaller:** its on-screen size is held at the biggest it's been since touchdown (`_canopy_size`), so coming down (lower looks smaller) can't make it shrink.
- The shadow uses the same size without the height factor.
- The physics are unchanged: it still spills air and sinks faster.

### 2026-10-30 — The station's desk: partial cover
- Mike: give the desk collision like a sandbag's but with different odds: a 30% chance a bullet hits the desk, the rest go through, using the metal impact sound.
- **New `scripts/partial_cover.gd`** (StaticBody2D):
  - `lets_bullet_through()`: true 1 − `hit_chance` of the time (default 0.3).
  - `bullet_hit()`: sparks (`hit_sparks.gd`) and the "metal" impact sound (`impact` export; another kind gives dust instead).
  - `sees_through()`: true.
- **`radio_station.tscn`:** the Desk shape moved off `Solid` onto its own `DeskBody` with that script. It stays on the squares' layer, so it's still solid to walk into. The Dish stays on `Solid`, solid to everything.
- **`ai_soldier.gd _clear_view()`:** sight lines now look past anything that `sees_through()`. A desk doesn't hide a square standing behind it; sandbags still do while calm.
- Bullets ask once per body (bullet.gd `_passed`), as with sandbags: 30% stop with sparks and a clang, 70% fly on.

### 2026-10-30 — No green interaction squares at the station
- Mike: get rid of the green interaction squares.
- **`radio_station.tscn`:** `StandBox` (the operator's spot) and `DishStandBox` (the dish's tuning spot) were green Polygon2D squares with outlines. They're now plain Node2D anchors at the same places, with the outline Line2Ds gone. They still carry the "[F] Interact" prompt, the request timer and the "F" key on the dish spot.
- The interaction areas (OperatorZone, DishZone) are unchanged, so standing in the same places works as before. The prompt still appears when you're on a spot.
- Comments in `radio_terminal.gd` and `radio_station.gd` updated.

### 2026-10-30 — No DEPLOY menu in radio command mode
- Mike: when giving orders over the radio, remove Deploy.
- **`command.gd`:** the DEPLOY menu is hidden while `World.radio_commanding`. Equipment is put down in person; the radio's own Deploy covers troops and supply drops.
  - Switching to radio command mid-placement stops the placing.
  - `_start_placing()` refuses in radio command mode.
  - ORDERS is unchanged.

### 2026-10-30 — Placing equipment no longer needs Space held
- Mike: once something is picked from DEPLOY (Space), you should be able to let go of Space.
- **`world.gd`:** new `World.placing`. `commanding()` is true while it's set, as well as with Space held or over the radio.
- **`command.gd`:** `_start_placing()` sets it and `_stop_placing()` clears it, so command mode stays on through the placing until the item's put down (left click, or a dragged row on release) or cancelled (right click). Then it drops out if Space isn't held. The banner reads "DEPLOY SANDBAGS   click, or drag out a row, to put it down   [scroll] turn   [right click] cancel" meanwhile.
- `player.gd _ready()` clears it with the other statics on a restart.

### 2026-10-30 — Shots over and under the desk; the dish as partial cover
- Mike: make shots go above and below the desk, and give the dish a similar hit statistic: 60% hit, 40% over.
- **Bullets drawn over** (`bullet.gd go_over()`): a shot going over something tall is drawn at `OVER_Z` 6, over the station's body (z 4) and dish (z 5), for `OVER_CLEAR_M` 1.5 m past it, then back at z 0. Bullets were always at z 0, so every shot passing the desk was drawn under it.
- **`partial_cover.gd`:**
  - New `over_chance`: of the shots that get past, the share that go over (and are drawn over); the rest go under or through.
  - New `see_through` export (`sees_through()` returns it).
- **`radio_station.tscn`:**
  - The desk: `over_chance` 0.5, so 30% hit, 35% over, 35% under.
  - The **dish** moved off `Solid` onto its own `DishBody` (partial_cover): `hit_chance` 0.6, `over_chance` 1.0 (40% over) and `see_through` off (the 1.2 m dish hides whoever's behind it). Still solid to walk into.
  - `Solid` is now empty and left in place.

### 2026-10-30 — Station: rifle over the desk; green F prompts
- Mike: close to the desk, the gun should be in front of it, not behind. Get rid of the "[F] Interact" and dish text prompts, and show a green F instead (like the big white one) in front of the desk or round the dish.
- **Draw order:**
  - The station's `Body` (the desk and the dish's stand) moves from z 4 to **−1**, under the squares, so a square at the desk has its rifle (and itself) drawn over the desk. The turning dish stays at z 5, over them.
  - Bullets passing **under** the desk now dip to `UNDER_Z` −3 (`bullet.gd go_under()`, called by `partial_cover.gd` for the shots that don't go over). Over-the-top shots still rise to z 6.
- **Prompts:**
  - `ui_style.gd pad_key()` takes a colour.
  - The terminal's "[F] Interact" label is now a big green F (`COMMAND_COLOR`, the white one's style) centred on the desk (`StandBox` moved to the desk's middle). It shows while the player is in the OperatorZone.
  - The dish's "[F] Tune dish" label (`DishPrompt`, and its LabelSettings) is removed. Its big F is green and centred on the dish (`DishStandBox` moved there).
  - The request timer sits just above the desk (`DESK_HALF_PX`).
- **Dish zone:** `DishZone` is now a ring all round the dish (a 115 px, 1.35 m circle centred on it; the dish itself is solid to 0.6 m), instead of a box on its west side. You can tune it from any side.

### 2026-10-30 — See-through F, a grey dish stand, and the comms crate
- Mike: make the F more transparent; make the comms dish's legs the same colour as the table; and another crate, of desk tech and computer equipment, which will be used to build the comm station.
- **F:**
  - `ui_style.gd pad_key()` fades the outline with the letter's alpha.
  - The desk's and dish's green F are at 0.55 alpha (`radio_terminal.gd PAD_KEY_ALPHA`).
- **Dish stand** (`radio_station.py`): the legs, braces, column and collars use a new `DishStand` material in the desk's `DESK_GREY`. The dish, head and yoke stay tan, and the foot pads and screws as they were. Re-rendered.
- **Comms crate** (`crates.py` `comms` kind; see the Asset List):
  - New helpers `rugged_case()` (a Pelican-style case with a lid seam, latches on the long sides, a top handle and a label or stencil) and `cable_reel()`.
  - The load's footprint and top are measured.
  - `scenes/crate_comms.tscn`: `crate.gd`, load 0.728 × 0.724, top 0.654, impact "metal" (there's no plastic impact sound yet).
  - It's the third option in the radio's Equipment request ("Comms crate", with a drawn icon), so it can be dropped by parachute.
  - Building a station from it is still to come.

### 2026-10-30 — Building the radio station from the comms crate
- Mike: break the comm station into 5 pieces: the desk, the electronics on the desk, the dish, the legs and the wiring. You can only deploy a comm desk within a certain detection circle of the crate. Once you build, your character goes to the crate, grabs the desk and brings it to the spot where it's being built, and the same for every part, with parts disappearing from the crate as you go. (Units doing this comes later.)
- **Art, `radio_station.py`:**
  - The station renders as parts: the desk frame (`DESK_FRAME_PARTS`), the electronics (everything else under the Desk empty), the dish's stand, the dish (as before) and the ground cable.
  - Each has its own shadow render (desk, electronics, stand), on the catcher.
  - `radio_station.png` and `radio_station_shadow.png` are deleted.
- **Art, `crates.py` comms:** re-laid as one item per part, all visible from above (`COMMS_PARTS`, `COMMS_OBJECTS`). Stages 1–4 are rendered with the straps cut and that many parts hidden.
- **`crate.gd`** gains generic build-from support:
  - `parts` (taken in order), `stage_textures` and `build_radius_m`.
  - `site` (what's being built from it) and `taken`.
  - `take_part()` and `return_part()`. The sprite follows the stage; empty, the Body is hidden, it stops being solid and its load shadow goes, leaving just the pallet.
  - In command mode a faint green circle shows round a crate that's ready (`can_set_up()`).
  - A see-through green F shows on it when the player is within `TAKE_M` 1.25 m with empty hands and something's being built from it.
- **`crate_comms.tscn`:** `parts` desk, electronics, legs, dish, wiring; the five stage textures; `build_radius_m` **8 m**; load 0.72 × 0.737, top 0.422.
- **`radio_station.tscn`:** the Body and Shadow sprites are replaced by Desk, Electronics and Stand sprites (z −1) and ShadowDesk, ShadowElectronics and ShadowStand (z −10).
- **`radio_station.gd`:**
  - New `built` export (default true, for hand-placed stations), `installed`, `site_crate`, `PARTS` and `PART_NODES`.
  - `start_site(crate)` makes it a site: parts not yet in are drawn as faint green ghosts (`GHOST`), with no shadows and not solid.
  - `needs()`, `can_deliver_at()` (within `DELIVER_M` 2.6 m of its middle) and `install()`. With all five in, it's `built`.
  - A see-through green F over its middle shows when the player brings a part it needs.
  - Unbuilt, there's no dish tuning, no beam, and the terminal doesn't answer (`radio_terminal.gd _player_on_box()` checks `built`).
- **`command.gd`:**
  - "Radio station" in DEPLOY is available only while the player is inside an unused comms crate's build circle (`_build_crate()`, used by `_carried()`).
  - Placing it calls `start_site(crate)` instead of using up a carried station.
- **`player.gd`, carrying:**
  - F at a crate with empty hands takes the next part (`carrying`). F at a site that needs it installs it.
  - While carrying it moves at `CARRY_SPEED` 0.65, has no rifle (hidden, can't fire or reload), and shows the part held 0.36 m in front (`_draw_carried()`: grey desk bundle, black, olive or tan case, or the cable reel).
  - Killed while carrying, the part goes back on its crate.
- Tested (`test_build_station.gd`):
  - **Circle:** no radio station at 12 m from the crate, one at 5 m.
  - **Site:** placed, linked to the crate, ghosts at 0.3 alpha, desk not solid, terminal dead.
  - **Five trips:** each took the right part with the F on the crate, at 0.65× speed with no rifle, delivered with the F on the site; the crate counted down 4, 3, 2, 1, 0.
  - **Built:** desk and dish solid, terminal working, rifle back. The crate is just a pallet, not solid.
  - **Death:** a part taken from a second crate went back on it when the player was killed.
  - Screenshots: mid-build (two parts in, carrying the legs, the crate down to two items) and finished (the station, the empty pallet).

### 2026-10-30 — The Build order; sandbag walls come from sandbag crates
- Mike: a new order, **Build**. If the right container is near, things can be built, so a unit can build the comm tower or a sandbag wall. Each sandbag crate has 10 sandbag walls. The stack needn't change every time, but have 3 or 4 versions so it looks like it's getting smaller.
- **Supply crates** (`crate.gd`, generalised from the comms crate's build support):
  - New exports: `builds` (the DEPLOY id it supplies), `single_site` (one station takes all five parts) and `stage_heights` (the load's shadow height per stage).
  - `reserve(site, count)` promises parts when something's laid. `available()` is what's left to promise. `wanted()` (some taken < reserved) is whether a part is worth fetching. `site_for(part, at)` finds the nearest site of its own that needs it.
  - The `site` field is now `sites` and `reserved`.
  - Returned parts (`return_part()`, a carrier killed or called off) go on a stack and are taken again first, so the comms crate copes with parts coming back out of order.
  - Stage pictures spread over the parts (stage = taken × pictures / parts), so 4 pictures cover 10 walls.
- **Sandbag crate** (`crate_sandbags.tscn`): `builds` "sandbags", 10 "sandbags" parts, 4 stage pictures (`crates.py` renders the smaller stacks), `stage_heights` 0.747 / 0.638 / 0.529 / 0.311 m, `build_radius_m` 8.
- **Comms crate:** `builds` "radio_station", `single_site`.
- **`command.gd`:**
  - `CRATE_BUILT` (radio_station, sandbags) are counted from supply crates in reach (`_supply_crates()`, `_supply_count()`): a station per comms crate, a wall per bag part not yet promised.
  - Laying one starts it as a site on the nearest crate. Sandbags are no longer carried (the unlimited count no longer applies).
  - New **Build** order in ORDERS (`order_build()` on the selection, or everyone in earshot).
- **Sandbag walls** (`sandbags.gd`):
  - New `built` export. `start_site(crate)` makes it a site: a faint green ghost, no shadow, not solid, no proximity box, no climbing (`in_zone()` and `climb_at()` say no).
  - It's in "build_sites" with `needs()`, `can_deliver_at()` (1.4 m) and `install()`. A smaller green F shows on it when the player brings bags.
  - Hand-placed walls start built.
- **Radio station:** `start_site()` reserves all five parts and joins "build_sites"; it leaves the group once built.
- **New `scripts/carry_art.gd`:** how a carried part looks (`draw()`), shared by the player and squadmates. Adds a sandbag bundle.
- **Player:** delivers to the nearest site in "build_sites" that needs what it carries; takes from any supply crate that owes a part.
- **`squadmate.gd`, State BUILD:**
  - **Fetching:** it heads for the nearest crate within `BUILD_RANGE_M` 30 m that's `wanted()` and takes a part (`_crate_with_work()`).
  - **Delivering:** it carries the part (`CARRY_SPEED` 0.65, rifle away, no firing or returning fire, the part shown in front) to its crate's nearest site needing it, else any site (`_site_needing()`), and installs it. Then it repeats.
  - **Finishing:** with nothing left it goes idle where it is.
  - **Stopping:** move, follow, lead, attention and disperse stop it (`_stop_building()`), and so does being killed; a part it holds goes back on its crate.
  - It looks where it's walking while building.
- Tested:
  - **`test_build_order.gd`:**
    - **Supply:** near both crates there were 10 sandbag walls and 1 station available. Laying 3 walls left 7; they were ghosts and not solid.
    - **Building:** a station site was placed, then Build was ordered for 2 squadmates. Everything was built in **16.2 s**, both carrying at once at times.
    - **After:** the walls were solid, the station built, the sandbag crate at stage 1 with 7 left, the comms crate down to its pallet. The squadmates were idle with rifles back.
    - **Interrupted:** a squadmate called away while carrying put its bag back (taken 4 → 3).
  - **`test_build_station.gd`** (the player building alone) still passes.
  - Screenshots: mid-build (one loading bags at the crate, the first wall up, two ghosts) and done.

### 2026-10-30 — No distance limit from supply crates
- Mike: no limit on how far something can be from its crate; it encourages smart drop locations.
- **`command.gd`:** sandbag walls and radio stations can be laid anywhere while some crate on the map has stock (`_supply_crates()` no longer checks the player's distance). DEPLOY's count is the total over every crate. Each site draws from the crate **nearest the spot it's laid on**.
- **`crate.gd`:** `build_radius_m` and the command-mode build circle are removed (and from both crate scenes).
- **`squadmate.gd`:** Build fetches from the nearest crate that owes a part, however far (`BUILD_RANGE_M` removed).

### 2026-10-30 — Fix: the player couldn't turn
- Mike: his character can't turn any more.
- **Cause:** the Build-order change moved the carried-part drawing out of `player.gd` (into `carry_art.gd`) by cutting from `_draw_carried()` to `_wants_to_fire()`. That cut also took out the four player functions between them:
  - `_aim_point()`: aiming at the mouse. Without it the soldier default kept the current facing, so the player couldn't turn.
  - `_turn_toward()`: holding still in command mode.
  - `_shot_spread_deg()` and `_shot_distance_m()`: the player's own accuracy and ground-hit distance. The AI defaults were being used.
- **Fix:** all four restored verbatim from `209c91e` (unchanged since).
- **Checked:**
  - Every script's function list matches `209c91e`'s apart from intended changes; nothing else was lost.
  - In a test the player turned from 115° off the mouse to on it within 1.5 s.
  - Spread inside the accurate line is 0 again.

### 2026-10-30 — Build picks and places like DEPLOY
- Mike: Build should work like the equipment menu: show the options and place it anywhere. If he has units selected, they're the ones who build it.
- **`command.gd`:**
  - The Build order (`picks = true`) opens its own hold pop-out (`_build_popout`, to the left like the formation pop-out). It lists what's built from supply crates (`CRATE_BUILT`: Radio station, Sandbags) with DEPLOY's icons and how many the crates can supply (greyed at 0).
  - Choosing one notes the crew, the selection or else everyone in earshot (`_order_targets()`), as `_build_crew`, and starts the usual placing: ghost, scroll to turn, drag a sandbag row, anywhere on the map.
  - When it's down the crew get `order_build()` and set to work. Cancelling (right click) or placing clears the crew.
  - The banner reads "BUILD SANDBAGS   … to put it down   2 to build it …".
  - DEPLOY is unchanged: it still lays sites for the player to build himself.
- **Anywhere:** what's built from supply crates (`CRATE_BUILT`) ignores the player's `deploy_reach_m` and can be laid anywhere on the field (`_can_place_at()`), through Build or DEPLOY. The reach ring isn't drawn while placing it. Carried equipment keeps the reach.

### 2026-10-30 — Click a crate to build from it
- Mike: if the thing is already laid, select a unit, then click the crate, and the unit starts building.
- **`command.gd _click()`:** with squadmates selected, a left click on a supply crate that owes parts (`wanted()`; the pallet's footprint plus `CRATE_PICK_PX` 6 px, `_crate_at()`) sends them to build from it (`order_build(crate)`), with pings on them and the crate. A click anywhere else is the usual move.
- **`squadmate.gd order_build(from)`:** given a crate, it only fetches that crate's parts (to that crate's sites, or any site that needs them), and stands down once that crate owes nothing. Without one (from the Build order), it fetches from the nearest crate with work, as before. `_stop_building()` clears it.

### 2026-10-30 — Destructible sandbags; two spare magazines each
- Mike: sandbags need to be destructible, with 3 stages of damage, the last collapsing into a puddle of sand. A unit behind a wall that goes should try to fill another available spot, or else stay defensive where it is. Walls are pretty strong: full health 60, divided between the stages. Also, everyone only has two magazines.
- **Art (`sandbags.py`, `--damage` renders just these):**
  - `apply_damage()` damages each built tile, deterministically per tile (`bag_rng("damage", kind, stage)`):
    - **d1:** one of the top course's own bags gone, the rest torn and slumped (z 0.6–0.78), two spills of sand.
    - **d2:** the whole top course gone, the middle slumped with one bag burst (1.12 × 1.2 × 0.42), four spills and two burlap scraps.
    - **Collapsed:** every bag gone; three lumpy sand heaps along the tile, two side spills and five scraps lying on the sand.
  - Only a tile's own bags are taken, never those shared at a join.
  - Sand: `sand_material()` (blotchy tan, fine grain bump) and `sand_mound()` (icosphere, so there's no pole pinch; noisy edge and height). Scraps: `burlap_scrap()`.
  - Damaged frames are `DAMAGE_FRAME_H_M` 0.5625 m (192 px) so spills aren't cut off; the heaps stay inside the tile's width so the puddle tapers off.
- **`sandbags.gd`:**
  - `max_health` 60 (30 rifle hits), `health`, `damage_stage` (0 whole, 1, 2, 3 collapsed).
  - `bullet_hit(point, direction, damage)` now takes the bullet's damage, via `take_damage()` (bullet.gd passes it; crate.gd and partial_cover.gd accept and ignore it). Shots that go over do none.
  - Past 2/3 health it shows d1, past 1/3 d2, at 0 it collapses. The tile name is kept (`_tile_name`) so the damaged version matches its single, start, end or mid tile (`DAMAGED_TILES`, `_show_tile()`).
  - Its shadow shortens with each stage (`STAGE_HEIGHT` 1, 0.82, 0.6).
  - **Collapsed** (`_collapse()`): not solid, no shadow, no proximity box, no climbing. It moves from "deployed_sandbags" to "sand_puddles", the walls it joined retile as ends, and a burst of dust goes up. The puddle stays.
- **`squadmate.gd`:** dug in behind a wall that collapses (`_cover_lost()`), it moves to the nearest free spot (`_free_cover_spot()`) behind a standing wall facing out the same way, within `RESPOT_M` 10 m, and digs in there. With none, it stays where it is, still defending, without cover.
- **`enemy.gd`:** a collapsed wall counts as gone (`_in_cover()`), so it leaves cover and finds other cover or fights as usual.
- **Magazines:** `rifle.gd spare_mags` defaults to **2** for everyone (it was unlimited for the AI), and `player.tscn` is 6 → 2. So 30 in the rifle and 2 × 30 spare. The AI still reloads by itself but now runs dry.
- Tested (`test_sand_damage.gd`):
  - **Damage:** a mid wall showed `_d1` at 10 hits (health 40), `_d2` at 20 (health 20), collapsed at 30. Collapsed it wasn't solid, had no cover box and was out of the group; its two neighbours became single tiles.
  - **Defenders:** the defender behind it dug in behind the neighbouring wall, south side, 0.44 m from its middle. A defender behind a lone wall stayed put (moved 0.00 m), still defending, with no cover.
  - **Enemy:** an enemy in cover left it when its wall collapsed.
  - **Magazines:** player, squadmate and enemy each have 2 spares. A squadmate fired until dry, then had 0 spares and 0 rounds.
  - Screenshot: the four stages side by side.


### 2026-10-30 — Facing arrow removed
- Mike: remove the arrow in front of the characters. The see-through "Sight" triangle in front of every square is gone: the node from `soldier.tscn` (and its hidden override in `dummy.tscn`), and its constants and code from `soldier.gd`. A square's facing still shows from its body and rifle.

### 2026-10-30 — Sending units to any sandbag crate
- Mike: selecting a unit and clicking a crate didn't work for sandbags. A wall reserves its bag from the sandbag crate nearest to where it's placed, so clicking a *different* sandbag crate found nothing owed there and became a move order.
- `crate.gd could_take_over()` / `take_over()`: a crate of the same kind with bags to spare takes over what other crates owe to walls still waiting (the parts not yet taken off them), and those crates get the bags back. Not for single-site crates (a radio station's parts come from its own comms crate).
- `command.gd _crate_at()` accepts a crate that could take over, and a click on it calls `take_over()` before the order.
- Tested: 3 walls placed by crate A, a unit sent to crate B: B took over all 3 (A back to 10 free), and the unit built them all from B in 17.6 s. With nothing waiting, a click on a crate is still a move order.

### 2026-10-30 — Looking ahead to go round obstacles; parachute and landing sounds
- Mike: obstacle avoidance needs upgrading. Walking in front of something like the desk, units get stuck and wait, or slide along it; they need to see it in advance and go round it. And use the new sounds for the parachute and the boxes dropping.
- **Avoidance (`ai_soldier.gd`, so squadmates and enemies):** `_steer()` only bent round other squares; solid things weren't seen at all.
  - `_avoid_obstacles()` (from `_steer()`, every `AVOID_EVERY_S` 0.1 s): sweeps a circle of its room (`CLEAR_RADIUS_M` 0.3, its half-diagonal and a little) up to `LOOK_AHEAD_M` 3 m along the way (layer 1: crates, the desk and dish, helicopters; squares left to `_steer()`, sandbags left to climbing).
  - Something there: it turns off further and further (`SWERVE_DEG` 15…150) on the side it's committed to (first time: the side away from the obstacle), only then the other side, and takes the first heading clear for `SKIRT_M` 1.2 m. It keeps that side until the straight way is clear again, so it hugs round the corner without dithering.
  - What it's walking up to doesn't count (`_at_goal()`: the goal point is in it or within its room of it, e.g. a crate it's fetching from), nor what it's already against unless it would walk into it.
  - `_is_stuck()`: going round something while moving freely doesn't count as no progress (up to `DETOUR_LIMIT_S` 8 s), so it no longer flips sides or gives up halfway round.
  - `_steer()` now takes the vector to the goal (not just a direction), so callers in `squadmate.gd` and `enemy.gd` pass `to`.
- **Sounds (`air_drop.gd`):** `assets/sfx/parachuteFlapping.mp3` (18.9 s) loops on the canopy from a random point (first 80%; the end has one loud snap), fading in as it opens, out over `FLAP_FADE_S` 0.8 s after touchdown. `assets/sfx/HittingGround.mp3` is the crate landing (+4 dB, pitch ±6%), in place of the dirt/concrete impact. Heard to 40 m.
- Tested (`test_avoid.gd`): a squadmate walked across the desk both ways, across the dish, down past the desk's end, across an ammo crate, to a spot just behind the desk and right across the station: never once touching anything, at most 0.9 s slower than a straight line (before: slid along the desk, and the spot behind it was given up 1.3 m short). Build order (fetching from crates), the crate click and sandbag defence tests still pass. A supply drop: flapping silent in free fall, in at 1.0–1.5 s, steady to touchdown at 4.0 s, out by 4.8 s; the landing sound played.

### 2026-10-30 — DEPLOY's button renamed Build
- Mike: change my menu from Equipment to Build. The DEPLOY menu's one button (right of the player) now reads **Build** (`command.gd`); what it does is unchanged (pick an item, place it, carry its parts in). The radio terminal's Equipment drop request is unchanged.

### 2026-10-30 — Bodies stay on the field; ammo from a dead square's rifle
- Mike: bodies should stay on the field when they die, in the darker colour they have now. A little circle round their gun makes it a source of ammo: walking over it you only get its magazine and the ammo that was in it.
- **`death_fall.gd`:** every body now darkens (`DARKEN_TO`, as before) and stays; the fade-out and removal (`LIE_S`, `FADE_S`) and the player-only `lingers` flag are gone. Once body and rifle have come to rest (`came_to_rest`), `_offer_ammo()` puts an ammo pickup on the rifle if it's showing and its magazine has rounds. `drops_ammo` (off for the player's own, `player.gd`).
- **`ammo_pickup.gd` (new):** a green circle (`RADIUS_M` 0.32, breathing slightly) painted on the ground (z −1) round the gun, in the "ammo_pickups" group. The player's centre within `REACH_M` 0.32 m of the gun takes the magazine: `rifle.gd take_magazine()` empties the dead gun and shows it without a magazine (`rifle_no_mag.png`); `add_spare()` puts a magazine with those rounds in the player's spares; "+1 MAG (n)" floats up and fades. Only the magazine in the gun, not the dead square's spares.
- **`rifle.gd abandon_reload()`:** dying mid-reload after the old magazine dropped out and before the new one seated leaves the gun with no magazine (0 rounds, nothing to pick up).
- Tested (`test_bodies.gd`): two enemies killed, one with 17 rounds in its magazine, one empty: one pickup, at the 17-round gun. 13 s later both bodies were still there, darkened to 0.55. The player walked over both guns: spares 2 (60 rounds) → 3 (77); both dead guns 0 rounds; no pickups left; the gun shows no magazine. Screenshots checked: the circle round the loaded gun only, then "+1 MAG (17)".

### 2026-10-30 — Squadmates and enemies go for ammo when they run out
- Mike: squadmates and enemies can and should try to get more ammo if they run out.
- **`ai_soldier.gd`:** `is_out_of_ammo()` (nothing in the rifle, no spare with rounds, not reloading, limited spares). `_ammo_run()`, called first in `squadmate.gd` / `enemy.gd _move_intent()` (a squadmate carrying a part finishes first): while out, every `AMMO_LOOK_S` 0.5 s it looks for the nearest ammo pickup within `AMMO_SEARCH_M` 40 m that no live square has claimed, claims it, and jogs there (`AMMO_RUN_SPEED` 1.35, steering round obstacles). There it takes it (`give_to()`) and reloads, then its usual state takes over again (a defender goes back to its spot behind the wall, an enemy to its cover, formation to its slot). With nothing in reach it carries on as before. Dying drops its claim.
- **`ammo_pickup.gd`:** `claimed_by` (so two don't go for the same magazine); `give_to(square)` works for anyone, the "+1 MAG" note only for the player. The player can still take one an AI is heading for; it then looks again.
- Tested (`test_ammo_run.gd`): a squadmate dug in behind a wall ran dry with two magazines on the field (21 and 9 rounds): had the nearer 21 in its rifle 6.3 s later, then was back defending, 0.03 m from its spot. Two squadmates dry at once with one magazine left: one claimed it and got 9 rounds, the other stayed put, then claimed the next one dropped. An enemy ran dry next to a body: 30 rounds 2.8 s later.

### 2026-10-30 — The right-hand Build menu hands the job to selected units
- Mike (issues_features_report.txt): picking a crate-built item (e.g. sandbags) from Build with units selected, they didn't build it; it just went down, and he had to click the crate. Since the DEPLOY button was renamed Build there are two Build menus: the orders one (left) gave the job to `_order_targets()`, the DEPLOY one (right) never set `_build_crew`.
- `command.gd`: the DEPLOY pop-out's pick now sets `_build_crew` to the selected squadmates in earshot when the item is crate-built (`CRATE_BUILT`); nobody selected, it's as before (the player carries the parts). The left one still falls back to everyone in earshot.
- Tested (`test_deploy_crew.gd`): one squadmate selected, Sandbags from the right-hand Build: it went to build at once and the wall was up in 3.0 s. Nobody selected: nobody went; the wall waited for the player.

### 2026-10-30 — Dead squares' guns drawn under the living
- Mike: guns of dead folks should be below characters, not on top. The rifle stayed a child of its dead square at z 0, so it could draw over a square standing on it.
- `death_fall.gd`: once the rifle has come down (`_gun_down`) it goes to absolute z `GUN_DOWN_Z` −4 (on the ground, as a dropped magazine): under every square and their shadows. Its own shadow is hidden then (it's flat; drawn in the square's shadow group it would darken the gun). `ammo_pickup.gd`: the circle drops to z −5, under the gun.
- Checked (`test_gun_under.gd`, screenshot): both dead guns at z −4, shadow off; the player and a squadmate standing on them are drawn over the guns.
- Mike: yes, bodies should be on the ground too. `death_fall.gd _land()` puts the dead square at z `BODY_DOWN_Z` −3 once it first hits the ground: under every living square and their shadows, over its own gun (−4) and the ammo circle (−5). A body that settles on its first touch (too gentle to bounce) now goes through `_land()` too, so it also darkens (it didn't before). Checked: bodies at z −3; a squadmate standing on a body is drawn over it, with its shadow.
- Mike: don't move the bodies, you just walk over them, kind of like sandbags. A dead square was still a CharacterBody2D masking layer 1, so a square stepping onto it got it pushed aside (depenetration). `death_fall.gd`: from death it has a collision exception with every square (it still bounces off solid things as it skids); at rest its `collision_mask` is 0. Once down it's in the "bodies" group with `under_at(point)` (1 within `BODY_REACH_M` 0.22 m of where it lies, easing to 0 over `BODY_EDGE_M` 0.14). `soldier.gd _body_under()`: on a body a square is lifted `BODY_LIFT` 0.4 of a sandbag climb (with its clambering jolts) and slowed to `BODY_SPEED` 0.7.
- Tested (`test_walk_over.gd`): bodies at rest have mask 0. A squadmate walked straight across one: lifted 0.40, 1.12 m/s on it (walks 1.60), the body moved 0.000 m. The player put down on another: lifted 0.40, body moved 0.000 m. `test_ammo_run.gd` still passes.

### 2026-10-30 — Everyone starts with half a magazine
- Mike: give all of us half a mag. Asked: start with 15 rounds and no spares, and enemies too.
- `rifle.gd`: new `start_rounds` (15; −1 for a full magazine) is what's in the rifle at the start; `spare_mags` defaults to 0 (was 2), and `player.tscn`'s own `spare_mags = 2` is gone. So everyone (player, squadmates, enemies) has 15 rounds and nothing to reload with: more ammo has to come off the dead (`ammo_pickup.gd`). Magazines still hold 30 (`mag_size`), so a picked-up one can be full.
- Checked: player, squadmate and enemy each start with 15 rounds, 0 spares, and can't reload; `test_ammo_run.gd` still passes.

### 2026-10-30 — Short of ammo, they pick it up without waiting to run dry
- Mike: the enemies don't seem to do it: 3 dead and one not, and he didn't take their ammo. Reproduced: an AI only went for ammo once completely out (rifle and spares empty), so one with a few rounds left walked past loaded guns, and with everyone starting on 15 the dead often have nothing left in theirs anyway (no circle).
- `ai_soldier.gd`: `is_short_of_ammo()` (less than a full magazine in rifle and spares together). Short, it picks up any ammo within `AMMO_TOPUP_M` 12 m; out, it still searches `AMMO_SEARCH_M` 40 m. `_may_top_up()` (default yes) lets a subclass hold off topping up; given an order that rules it out, it drops the claim.
- `squadmate.gd _may_top_up()`: not while walking somewhere it was sent (MOVE), holding a wall (DEFEND) or building. Out of ammo it goes regardless. Enemies always top up.
- Tested (`test_ammo2.gd`, each case in a fresh scene): an enemy with 6 rounds took both nearby guns (12 and 7) within 5.4 s of their circles appearing. A squadmate with 15 ordered behind a wall dug in and stayed (3 s later still there, still 15) although a 21-round gun lay 8 m off; run dry, it had the 21 in 6.2 s and was dug in at its spot again 2.4 s later. An idle squadmate with 15 topped up from a 20-round gun 6 m off (35 after 3.7 s). Two dry squadmates, one magazine: one took it, the other didn't move. An enemy run dry went for the nearest guns.

### 2026-10-31 — Crates arrive strapped; hold F to undo the straps
- Mike: every crate gets a model without the straps. Either the player or a unit has to undo the straps by going up to the crate and holding F for 2 s; after that it can be used to build. He'll find a sound for it. (A break-away animation of the straps flying off was tried and removed at Mike's request: the straps just disappear.)
- **Art:** `crates.py` already rendered `crate_<kind>_open.png` (the full load, straps hidden) for ammo, comms and sandbags in an earlier session that was cut short; Godot had imported them with mipmaps off, now on (their `.import` files) like the other crate textures.
- **`crate.gd`:** `strapped` (default true) and `open_texture` (none: no straps, e.g. the lone ammo can). While strapped, `can_take()` is false. `work_unstrap(who, delta)`, called every physics tick by whoever's at it (`can_unstrap()`: empty hands, within `TAKE_M`, nobody else on it), adds up to `UNSTRAP_S` 2 s; a tick missed (let go, walked off, died) resets it (`_physics_process()`). A yellow ring (`UNSTRAP_RING_M` 0.62 m) round the crate fills meanwhile; the green F shows while the player could start. Done: `strapped` off, the load shows `open_texture` (stage 0; the smaller stages were already strapless), `unstrapped` is emitted, and `UNSTRAP_SOUND` plays (now `res://assets/sfx/BandBreak.mp3`, see 2026-11-01). `in_reach()` and `unstrapping_by_other()` are shared helpers.
- **`player.gd _tick_unstrap()`:** holding F (`interact`) with empty hands at a strapped crate works it. A fresh F press after that takes a part, as before.
- **`squadmate.gd _tick_build()`:** at a strapped crate it's sent to (Build order or crate click), it faces the crate and works the straps; others wait by it.
- Scenes: `crate_ammo.tscn`, `crate_comms.tscn`, `crate_sandbags.tscn` get `open_texture`. The ammo crate can be unstrapped but nothing comes off it yet.
- Tested (`test_unstrap.gd`, scratch copy, headless): sandbag and ammo crates start strapped, the ammo can doesn't. Strapped: can't take, can unstrap, F shows. Held 1 s: progress 1.02, ring on; let go: back to 0, still strapped. Held again: off at 2.02 s, `crate_sandbags_open.png`, and an F press took a part (the open texture stays at stage 0). Two squadmates on Build at a strapped comms crate: the nearer began at 0.92 s, straps off at 2.92 s (2.00 s of work, never handed over), part delivered at 5.60 s, crate now `crate_comms_1.png`.

### 2026-10-31 — Fix: two sides dug in behind sandbags never saw each other
- Mike: the two sides don't see each other if they're both behind sandbags. Reproduced (`test_wall_sight.gd`): a squadmate dug in behind a wall and a calm enemy behind another wall 15 m (and 25 m) away, facing each other: 8 s and no shot. A calm enemy only wakes on seeing someone (`enemy.gd _check_intruders()`), and `_clear_view()` let a viewer see over the wall *it* was at but not over the other wall; squadmates only shoot alerted enemies. So nobody started it.
- **`ai_soldier.gd _clear_view()`:** new `seen_over` flag: cover that whoever's at `to` is manning (they're in its proximity box) doesn't hide them, since they're looking over the top. Only `_check_intruders()` uses it, so enemies still score spots that see a dug-in target only over its wall as worse (`_best_spot()`), and only someone behind a wall but not at it (further back than its `zone_depth_m`, 0.8 m) is hidden from a calm enemy.
- Tested: at 15 m the enemy woke and the fight started at once (enemy killed, squadmate unhurt); at 25 m both were firing. Control: a squadmate 1.5 m behind its wall (not at it) stayed unseen for 8 s. `test_unstrap.gd` still passes.
- (A mistake in the first version of this edit left `ai_soldier.gd` failing to parse for a few minutes; fixed. If the editor showed errors for it, they should clear on its own; otherwise reopen the script.)

### 2026-10-31 — Surprised state: attacked while idle, run for cover, then fight from it
- Mike: a non-player character that's idle and then attacked should seek cover behind anything close and away from the enemy (sandbags, crates, anything on the field), unless the only thing is a couple of metres toward the enemy; once behind it, it starts engaging. Called the surprised state. Asked: the trigger is a hit or a near miss (a round passing or landing within 2–3 m); behind cover too tall to shoot over, they peek out to fire and step back; for squadmates, only idle ones.
- **`ai_soldier.gd`** (shared):
  - `_near_miss()`: a hostile round whose path (from its last step to where it goes into the ground, or its 1 s range) comes within `NEAR_MISS_M` 2.5 m. Judged on the whole path, so a shot at it counts the moment it's fired. Without that, a calm enemy *hears* the shot (40 m) and goes to ENGAGE before the round arrives.
  - `_find_hide(foe)`: anything on mask 1|4 (solid things and sandbags) within `HIDE_SEARCH_M` 8 m that isn't a square, a see-through desk, an unbuilt or collapsed wall, or narrower than a square across the line of fire (`HIDE_MIN_WIDTH_M` 0.4 m; the lone ammo can). Spot: behind a sandbag wall's middle (`WALL_SPOT_M` 0.42 m, in its box, so it can shoot over), or `HIDE_GAP_M` 0.32 m off anything else's far side from the attacker (`_footprint()` from its collision shapes). The spot must be on the field, clear (`HIDE_ROOM_M`), not taken (`_hide_taken()`: someone on it, or a surprised square heading there), and have that cover as the first thing toward the attacker within 1.5 m (`_hide_covers()`). It takes the nearest spot that isn't closer to the attacker; only with none, one toward it within `HIDE_TOWARD_M` 2.5 m.
  - `_tick_hide(foe)`: runs there (`HIDE_RUN_SPEED` 1.4). Behind sandbags (`_hide_low`) it fires from the spot. Behind anything taller, every `HIDE_S` 1–2 s (a quick 0.3–1 s first look) it steps out sideways to the nearest spot with room and a clear view (`_peek_spot_for()`, up to `PEEK_MAX_M` 1.5 m, either way), fires `PEEK_SHOTS` 3 (or `PEEK_S` 3 s), and steps back; it stays in to reload. `_may_fire_hidden()` gates `_wants_to_fire()`. Flanked for `HIDE_FLANK_S` 0.8 s: other cover, or `_hide_cover` goes null for the subclass to handle.
- **`enemy.gd`:** new `Mode.SURPRISED`. Calm, a hit (`take_hit()`) or `_near_miss()` (checked before `_check_shots()`) calls `_surprise()`: with cover, SURPRISED (alerted, wakes its neighbours as before, `threat` = the attacker); already dug in behind a wall facing that way, or no cover near, it's `alert()` as before. `_surprised()` keeps the attacker as its target and runs `_tick_hide()`; the attacker dead or no cover left: ENGAGE. `alert()` and `_look_for_targets()` don't knock it out of SURPRISED; `_ready_to_fire()` allows it.
- **`squadmate.gd`:** new `State.SURPRISED`. Idle (IDLE or SHUFFLE), a hit or near miss calls `_surprise()`: it shoots back (not on a near miss after Stop), and takes cover if there's any. In cover it fights the target it has, or anyone it picks up by returning fire, and stays until given an order. With no cover left it's IDLE where it stands. No topping up of ammo while surprised (out of ammo it still goes).
- **Fixed a regression from the strapped crates (earlier today):** `crate.gd _show_stage()` now ran for the ammo crate, which has no parts, and with 0 of 0 left it hid the load and turned its collision off: the ammo crate was invisible and not solid. With no parts it now only swaps the straps texture.
- Tested (`test_surprised.gd`, an idle square shot at from 12 m, both on 1000 health):
  - **away** (enemy; a crate 2 m behind it and one 1.5 m in front): surprised at 0.15 s, took the one behind, in cover at 1.72 s; the crate between it and the shooter. It peeked 4 times and fired 10 shots, all while peeking; not hit while tucked in.
  - **toward2** (only a crate 1.8 m toward the shooter): took it, in cover at 0.85 s; 4 peeks, 11 shots.
  - **toward4** (only a crate 4 m toward the shooter): no cover, straight to ENGAGE.
  - **wall** (a sandbag wall 2 m behind): in cover at 1.22 s at 0.42 m from its middle; 18 shots over it from the spot, no peeking.
  - **squad** (a squadmate shot at by an enemy, a crate behind it): SURPRISED at 0.23 s, in cover at 1.90 s; 4 peeks, 10 shots.
  - Ammo crate visible and solid again, before and after unstrapping. `test_unstrap.gd` and `test_wall_sight.gd` still pass.
- Two typing slips in this work stopped `ai_soldier.gd` and then `squadmate.gd` from parsing for a few minutes each; both fixed, and every edited script was checked to load.

### 2026-10-31 — Cover classes
- Mike: give every object a cover class, by how much of the fire it stops: 40% or less class 1, over 40% up to 60% class 2, above that class 3 (a desk class 1, sandbags and crates class 3). For the AI in later development; nothing uses it yet.
- **`scripts/cover.gd` (new):** `NONE` 0, `LIGHT` 1, `MEDIUM` 2, `HEAVY` 3; `class_for(stops)` (`LIGHT_MAX` 0.4 and `MEDIUM_MAX` 0.6, both inclusive); `stop_chance(node)` (the node's `cover_stop_chance()`; a square 0; any other solid body 1.0, e.g. a helicopter's hull); `class_of(node)`.
- `cover_stop_chance()` and `cover_class()` on `partial_cover.gd` (`hit_chance`), `sandbags.gd` (1 − `through_chance`; 0 unbuilt or collapsed) and `crate.gd` (1.0 with a load on it, 0 once it's down to the bare pallet).
- Tested (`test_cover_class.gd`): desk 30% class 1; dish 60% class 2; sandbag wall 90% class 3, class 0 once shot down; ammo, comms and sandbag crates, the lone ammo can and a helicopter's hull 100% class 3; a squadmate class 0. Boundaries: 0.4 → 1, 0.41 → 2, 0.6 → 2, 0.61 → 3.

### 2026-10-31 — Pinned state (squadmates)
- Mike: a new non-player state, pinned. If the enemy is behind class 3 cover and there are more enemies than our units, our units are pinned: they stop shooting and take cover, since shooting at solid cover wastes ammo. Asked: it's judged on each squadmate's own target; the count is alerted enemies within 35 m against every live squadmate plus the player; it ends once it no longer applies; orders still work, and a Fire order is carried out even pinned.
- **`squadmate.gd`:** new `State.PINNED`. Every `PIN_CHECK_S` 1 s (`_check_pinned()`), a squadmate fighting on its own account (IDLE, SHUFFLE, DEFEND or SURPRISED, its target not from a Fire order) is pinned when `_pinned_down()`: its target is an enemy with class 3 cover between them within `PIN_COVER_M` 1.5 m of the enemy (`_behind_heavy_cover()`: the first thing on a ray from the enemy toward it, `Cover.class_of()`; so its own wall doesn't count), and `_outnumbered()`: more alerted enemies within `PIN_ENEMY_M` 35 m than live squadmates and player.
  - Pinned (`_tick_pinned()`): no firing (`_wants_to_fire()`), still facing its target. From DEFEND it holds its spot behind the wall; from SURPRISED it stays tucked in (no peeking); from the open it runs for cover from its target (`_find_hide()`) or stays put with none.
  - `_unpin()` when the check fails (numbers even, target out of heavy cover, e.g. stepped out to peek, or dead): back to what it was doing (`_unpinned_state`); from the open, if it got into cover, SURPRISED (fighting from it).
  - Orders: any order sets its state, so it's out; `order_attack(target, ordered := true)`: the player's Fire order (command.gd) sets `_fire_ordered` and unpins, and it's never pinned over that target; its own picks (shooting back, surprised, return fire) pass `false`. Stop also unpins. No ammo top-ups while pinned.
- **`ai_soldier.gd`:** `_is_pinned()` (default false); `_hide_taken()` counts a pinned square's cover spot as taken.
- Tested (`test_pinned.gd`; enemies held still behind crates 15 m off, alerted):
  - **wall** (dug in, 2 enemies v 1): PINNED within a second; 0 shots over the next 2.5 s. One enemy killed: back to DEFEND, firing again (3 shots in 2.5 s).
  - **even** (1 v 1): never pinned, kept firing.
  - **exposed** (2 v 1, its target in the open): never pinned.
  - **fire** (pinned, then a Fire order on its target): DEFEND, 5 shots in 2.5 s.
  - **open** (in the open, a crate 3 m behind it): PINNED, went 3.7 m to behind the crate (cover between it and its target), 0 shots.
  - `test_surprised.gd` (away, wall, squad) still passes.

### 2026-10-31 — Standoff: hold fire until there's a window (both sides)
- Mike: if all the units on the other side are behind class 3 cover, hold fire until there's a window.
- **`ai_soldier.gd`** (squadmates and enemies alike): `_in_standoff()`, run every tick from `_wants_to_fire()` and looking again every `STANDOFF_CHECK_S` 0.25 s. If its target is dug in (`_dug_in()`: class 3 cover between them within `DUG_IN_M` 1.5 m of the target; this replaces squadmate.gd's `_behind_heavy_cover()`/`PIN_COVER_M`, and `const Cover` moved here), it looks over its foes in the fight (`_foes()`, within `STANDOFF_FOE_M` 35 m). If it can see one out of class 3 cover (a window), it switches to that foe (`_take_window()`) and fires; otherwise it holds fire. Nothing else changes: it stays where it is, still aiming. `_fire_on_order()` skips the standoff.
- **`squadmate.gd`:** foes are the alerted enemies; a window is taken like shooting back (`order_attack(foe, false)`) and also unpins it. A Fire order (`_fire_ordered`) shoots regardless. `_wants_to_fire()` now always calls `super()`, so a pinned squadmate still watches for a window.
- **`enemy.gd`:** foes are the player and the squad; a window makes that foe its target and threat (with a fresh reaction delay). `_look_for_targets()` weighs dug-in hostiles as 3x as far away, so it goes for anyone in the open first and doesn't flip back to a dug-in one.
- Tested (`test_standoff.gd`):
  - **walls** (both sides dug in behind sandbags 15 m apart, live AI): both target each other, 0 shots from either in 8 s.
  - **peek** (squadmate dug in, 1 enemy held still behind a crate): 0 shots in 3 s; the enemy steps 1.5 m out: 5 shots in 2.5 s; back behind the crate: 0.
  - **window** (2 enemies, one behind a crate, one in the open 3 m to the side; started on the dug-in one): switched to the open one, 7 shots in 3 s.
  - **order** (as peek, but a Fire order): 6 shots in 3 s at the crate.
  - `test_pinned.gd` all as before, except that after unpinning, "wall" now holds fire (0 shots) because the remaining enemy is dug in too. `test_surprised.gd` unchanged: units peeking out from cover are a window, so they still get shot at.
- First try's bugs, fixed before the above: the window check only counted down on ticks a shot was due (so it re-checked far too rarely), and a pinned squadmate never looked for a window.

### 2026-11-01 — Battle log (F9) and the battle-log skill
- Mike: a HUD control to start and stop a log of everything every character does (both sides, numbered 1.. as they turn up). Starting a log wipes the last one. The log is for Claude to assess a test, and a skill should explain how to read it and how the AI should change.
- **`scripts/battle_log.gd` (new):**
  - **Controls:** a BATTLE LOG panel at the top left. Its button and **F9** (`battle_log` in `world.gd KEY_CONTROLS`) start and stop it. While recording, the button shows the running time in red; after stopping, the line count and path.
  - **Created by:** `command.gd _ready()` creates it, so there's no scene change.
  - **Output:** plain text, tab-separated, one line per thing, in metres and seconds, with a legend at the top. It's readable as is, and only about 1 KB per second of fighting. Written to `logs/battle_log.txt` when run from the editor (`logs/` gets a `.gdignore` and is in `.gitignore`), `user://battle_log.txt` otherwise.
  - **What's recorded:**
    - **Line codes:** `U` turned up, `P` position and facing (every 0.2 s, once moved 0.05 m or turned 5°), `~` changes in what it's doing (checked every tick), `F`/`X` each shot and where it ended, `H` hits taken, `O` squadmate orders, `M`/`G` solid objects with their cover class (scanned every 1 s).
    - **Keys in `~` lines:** state/mode, target, threat, alert, cover, hide phase, the enemy's fighting spot, holding fire (blocked or standoff), Stop, Fire-ordered, carrying, follow, reloading (with rounds), the player's command mode/busy, dead.
  - Flushed every second. The log stops when the level restarts.
- **Hooks:**
  - `bullet.gd`: `_ready()` logs the shot, after the rifle has set its range, and its hit, ground and spent endings are logged.
  - `soldier.gd take_hit()`.
  - `squadmate.gd order_*()`: a Fire order, but not targets it picks itself, which show as target changes.
- **`player.gd _wants_to_fire()`:** no shot when the click is on a button on screen (the log's, the enemy spawner's). Before this, clicking a HUD button also fired the rifle.
- **`.claude/skills/battle-log/` (new):**
  - `SKILL.md`: where the log is; summarise first, then pull out windows; compare with the AI scripts' doc comments and Mike's rules; report what happened, what's wrong, what to change, what's right.
  - `summarize.awk`: per-unit shots and outcomes, hits, deaths, time in each state, standoff/blocked time, and a "looks wrong" list (friendly fire, no hits, shots into class 3 cover, alerted but silent, surprised but never in cover, stood still while moving, target flip-flopping), plus a timeline.
  - `ai-reference.md`: log keys → code, behaviours → tunables.
- Tested (`test_battle_log.gd` on the scratch copy, the main level with Arrival off, 4 spawned enemies, 6 squadmates: 3 sent forward, 3 given a Fire order, 15 s):
  - F9 started the log, and stopping saved it. About 500 lines and 16 KB.
  - A second run overwrote the file (lines on disk = lines saved).
  - Every line type appeared. The objects came out with the right class: desk 1, dish 2, sandbags and crates 3, with their straps. Shapeless bodies are skipped.
  - The summary script ran on the log.
- **Findings from that test log, for Mike (not changed):**
  1. A Fire-ordered squadmate standing idle drops its Fire order on a near miss. `_surprise()` calls `order_attack(by, false)` even when no cover is found, which goes against "orders override".
  2. With the order gone, the standoff's window-switching made it change target 26 times in 7 s. Enemies behind sandbags go in and out of "dug in" as they move, and `_take_window()` has no hysteresis.

### 2026-11-01 — Debug mode (Q): unit numbers over the squares
- Mike: Q toggles a debug mode. For now it shows each unit's battle-log number next to it, 0 up to however many are on the field including the player, so he can ask "why did 4 do that?".
- **Numbering moved from per-log to per-level (`battle_log.gd`):**
  - Every square is numbered as soon as it's in the level, whether or not a log is running (`_number()`, every physics tick). The player is always **0**; everyone else gets 1, 2... in the order they turn up. Enemies from the spawner and troops off a helicopter take the next numbers.
  - `number_of(unit)` gives a square's number to anything else (static; `_level` is this level's battle log).
  - A log no longer restarts the numbers at 1: it introduces the squares alive when it starts (`_introduced`) under their level numbers. A missing number is a square that died before the log started. The legend says so.
- **`scripts/debug_overlay.gd` (new), made by `command.gd`:**
  - **Q** (`debug` in `world.gd KEY_CONTROLS`) toggles `World.debug` (new static, off at level start).
  - While it's on, each live, visible square's number is drawn just past its top-right corner: green for our side, red for enemies, black outline. A small "DEBUG (Q)" shows bottom left.
  - It's drawn on a CanvasLayer at screen positions, so the numbers stay the same size at any zoom. The player isn't numbered on screen while still in the arrival helicopter (hidden).
- Skill: `SKILL.md` now says the numbers match what Mike sees with Q (player 0) and how to answer "why did N do that?".
- Tested (`test_debug_numbers.gd`, scratch copy, main level with Arrival off):
  - Q turned debug on (overlay showing) and off again.
  - The numbers were Player 0, Squadmate…Squadmate6 1–6; 3 enemies spawned afterwards got 7, 8, 9.
  - Squadmate 1 was killed, then a log was started. Its `U` lines used the same numbers (0, 2–9, with 1 missing), matching `number_of()` for every square.
  - Drawing with debug on raised no errors. Every edited script loads. The summary script handles unit 0.
  - The look of the numbers on screen hasn't been checked in a window (headless only).

### 2026-11-01 — Builders walk beside a sandbag wall, one carrier per tile
- Mike (battle log, unit 3): building a 10-tile wall, Squadmate3 walked along the top of the bags already laid, at climbing speed (about 0.37 m/s instead of 1.45 m/s), to get to the far end. Units shouldn't walk on the wall; they'd walk alongside it.
- Two causes:
  - Carriers headed for a tile's middle, and squares don't collide with sandbags (they climb them), so the straight way to a tile further along the row runs along the wall's top.
  - Several carriers were sent to the same tile (the nearest that still needed bags). Whoever got there first built it, and the others retargeted to the next tile along, so one carrier chased the row up its whole length (5 retargets in the test).
- **`sandbags.gd deliver_spot(from)`** (new, `DELIVER_SIDE_M` 0.7 m): the spot beside a tile on the carrier's side of the row, clear of climbing (which starts within about 0.3 m of the row's middle line). Bags still go in within `DELIVER_M` (1.4 m) of the middle, so it delivers from there.
- **`squadmate.gd _tick_build()`:** heads for the site's `deliver_spot()` if it has one, else its middle as before (radio station). **`_site_needing()`** (now used for the first pick too) and **`crate.gd site_for(part, at, claimed)`** prefer the nearest site no other squadmate is carrying a part to (`_sites_claimed()`), falling back to the nearest anyway (so a radio station's many parts still all go to it).
- Tested (`test_build_beside.gd`, scratch copy, headless): the log's setup (strapped sandbag crate at 15.6, 19.3, 10 tiles at x 19.5, six squadmates where they stood). Before: wall up in 14.3 s, mate 3 on the bags for 6.85 s, 2–5 retargets each. After: wall up in 9.7 s, no one on the bags, no retargets. `test_unstrap.gd` unchanged (comms part delivered at 5.60 s).

### 2026-11-01 — Walkers slip past a manned wall on the ground side, not over the bags
- Mike (battle log 00:52, units 1 and 6): six squadmates sent to man a 10-tile wall (move with cover). The four with near spots dug in within 1.3 s. 1 and 6, with spots at the far end, walked down the top of the wall at climbing speed and took 8.5 s and 10.7 s.
- Cause: `ai_soldier.gd _steer()` slips past a square in the way on the side it's already offset to. Walking down a manned row, they were a little on the wall side of each squadmate dug in there, so every sidestep pushed them up onto the bags.
- **`_steer()`:** if that side would put it on a sandbag wall (`soldier.gd _cover_under_at()`, new, split out of `_cover_under()`) and the other side wouldn't, it passes on the other side. It's shared, so enemies get it too. Climbing over a wall on purpose is unchanged.
- Tested (`test_man_wall.gd`, scratch copy, headless, the log's positions and order): before, 1 dug in at 8.98 s (7.9 s on the bags) and 6 at 12.47 s (11.4 s on the bags). After: 3.13 s and 4.35 s, no time on the bags; the other four unchanged (0.7–1.3 s). Re-run: `test_build_beside.gd` (wall up in 10.05 s, nobody on the bags), `test_surprised.gd` (away, wall, squad), `test_standoff.gd` (walls, peek), `test_pinned.gd` (wall, fire, open), `test_wall_hidden.gd`: all as before.

### 2026-11-01 — Band-break sound on crate straps
- Mike added `assets/sfx/BandBreak.mp3` (0.70 s) for the straps coming off a crate. `crate.gd UNSTRAP_SOUND` now points at it (it was waiting on a `StrapsBreak.mp3` that never came). It plays at the crate, at `UNSTRAP_DB` 0 dB, heard up to `SOUND_HEARING_M` 30 m, whoever undoes the straps (the player or a squadmate).
- Tested (`test_band_break.gd`, scratch copy, headless): the file loads, and breaking the straps starts a player at the crate with BandBreak.mp3. `test_unstrap.gd` unchanged.

### 2026-11-01 — Debug mode locks the player and shows a clicked square's ammo
- Mike: with Q on, debug mode takes over: no control of his square. A click on a unit shows its info (for now ammo and magazines). Q again hands control back.
- **`player.gd _hands_off()`** (new): `busy` or `World.debug`. It replaces `busy` in every input gate (aim line, reload, F, unstrapping, ammo panel, aim point, firing), and `_move_intent()` stands still in debug.
- **`world.gd commanding()`:** false in debug, so command mode (Space) won't open and its clicks don't go to `command.gd`.
- **`debug_overlay.gd`:** a left click (not on a button) picks the live, numbered square within `PICK_M` 0.4 m; a yellow ring goes round it and a panel beside it (as the player's ammo panel) shows `#n  name  (side)`, `AMMO rounds / mag size` (RELOADING while it reloads, red when empty) and `MAGS count (rounds)` or `unlimited`, every frame. Open ground, its death, or Q drops it. The corner tag reads "DEBUG (Q)  click a square for its details". Spawned squares (no node name) show just their number and side.
- Tested (`test_debug_inspect.gd`, scratch copy, main level, Arrival off): in debug, holding right and shoot for 0.5 s moved the player 0.00 m and fired nothing, and holding Space left command mode off. A click beside Squadmate3 picked it: "#3  Squadmate3  (squad) | AMMO 7 / 30 | MAGS 0 (0 rounds)", updating to 3 / 30 when its rounds changed; the click didn't fire the player's rifle. Clicking the player showed #0; open ground cleared it. Q again: debug off, pick cleared, and the player moved 0.69 m in 0.5 s. `test_debug_numbers.gd` unchanged.

### 2026-11-01 — Any class 3 cover on the line of fire protects: no shooting into walls
- Mike (battle logs 01:12 and 01:19): enemies 7–10 targeted the player the whole fight and emptied their magazines (15 rounds each) into the squad's sandbag wall, with the player 5.7 m behind it. The standoff only held fire when the target had class 3 cover within 1.5 m of it (`_dug_in()`), so a player standing well back from a wall didn't count, although the wall stops 90% of shots at any distance (`sandbags.gd lets_bullet_through()`). Mike: any wall on the line protects.
- **`ai_soldier.gd _shielded(foe)`** (new): class 3 cover anywhere on the line from its muzzle to the foe, skipping a sandbag wall it's at (`in_zone()` of the muzzle: its shots go over that one, as the bullets judge it). **`_in_standoff()`** uses it for the target and for windows; **`enemy.gd _look_for_targets()`** weighs shielded hostiles ×3 by it. Both sides. `_dug_in()` stays for PINNED (cover right in front of the enemy).
- Knock-on: a surprised square peeking past a crate picked a spot where its body saw past the edge but its muzzle (about 0.14 m to one side) didn't, so its shots went into the crate; now they'd be held. **`_peek_spot_for()`** also needs a clear view `PEEK_RIFLE_M` (0.2 m) to either side.
- Tested (`test_shielded.gd`, scratch copy, the 01:19 setup: player 5.7 m behind the squad's wall at x 19.1, squad dug in, four enemies arriving at their wall in the north-east, 25 s, battle log recorded): before, three enemies emptied their rifles at the player (60+ shots, none hitting him); after, 0 enemy shots, all 15 rounds kept, all four in standoff, target a squadmate. The squad fired 1–3 shots each while the enemies ran in, then held. Re-run: `test_surprised.gd` away/wall/squad (peek shots 9 and 9, against 10 and 11 before, the shooter now hit; wall unchanged), `test_standoff.gd` walls/peek, `test_pinned.gd` wall/fire/open, `test_wall_hidden.gd`, `test_wall_sight.gd`: as before.
- Open: two sides dug in at walls now simply hold fire on each other (a stalemate) until someone moves; enemies have no move to break it yet.

### 2026-11-01 — Sand thud when sandbags go up (placeholder)
- Mike: use one of the sand hit sounds for placing sandbags for now. **`sandbags.gd thud()`** (new) plays an `impact_sound.gd` "sand" sound (one of the eight bullet-into-sand cuts at random, pitched a little, never the same twice running) at the wall. **`install()`** calls it when the bags are brought in (player or squadmate). **`command.gd _place()`** calls it once per placement for walls that go straight up with no crate to build from (one thud for a dragged row, not one a tile). Walls placed by hand in a scene stay silent.
- Tested (`test_sandbag_thud.gd`, scratch copy): a site makes no sound; `install()` started `sand_impact_1.wav` at the wall. The main level still loads (`test_debug_inspect.gd`).

### 2026-11-01 — Shift to run, adjustable speed
- Mike: Shift to run faster, at an adjustable speed. **`world.gd`** registers `run` (Shift). **`player.gd run_speed_mps`** (Inspector on the Player, 0.5–8 m/s, default 3.2, double the 1.6 walk): holding Shift, `_move_intent()` scales the speed to it. Not while carrying a part (stays at `CARRY_SPEED`), nor in command mode (Shift adds to the selection there), nor in debug mode. The rifle's steadiness already goes by speed, so shots on the run stray more.
- Tested (`test_run.gd`, scratch copy, main level, measured over 1 s at full speed): walk 1.60 m/s; Shift 3.20; with `run_speed_mps` 5.0, 5.00; Shift while carrying 1.04 (the carry speed); Shift in command mode 1.60.

### 2026-11-01 — Running footfalls on dirt
- Mike added `assets/sfx/SprintOnDirt.mp3` (10.7 s, mono, a footfall about every 0.35 s, no long silence at either end). **`player.gd`**: loaded at `_ready()` (if the file's imported) as a looping copy on an `AudioStreamPlayer2D` on the player, at `RUN_STEPS_DB` -6 dB. **`_update_run_steps()`**: on while `_running` (Shift held and allowed, set in `_move_intent()`), faster than walking, alive and off the road's asphalt (`road.gd covers()`); it starts from a random point in the loop each time so short sprints don't all start on the same step; let go, it fades out over `RUN_STEPS_FADE_S` 0.15 s.
- Tested (`test_run_steps.gd`, scratch copy, main level): loaded, looping, 10.67 s. Walking: silent. Running on dirt: playing (from 6.85 s in, at -6 dB). Shift let go: fading (-17.3 dB 3 ticks later), stopped within 0.5 s. Running on the road: silent.

### 2026-11-01 — Player hops and waddles a little more
- Mike: make my character jostle a little more. (The code's `jostle_m` is the rocking of an anchored square when hit, e.g. the dummy; what shows while walking is the hop and the waddle.) **`soldier.gd waddle_deg`** (new export, default 3, was a fixed 3°): the side-to-side sway, one every two hops. **`scenes/player.tscn`**: the Player's `hop_height_m` 0.09 (squares 0.06) and `waddle_deg` 5.0, both in its Inspector. Squadmates and enemies unchanged. (Setting them in `_init()` didn't work: loading the scene put the defaults back.)
- Tested (`test_waddle.gd`, scratch copy, main level, walking 2 s): player hop 0.090 m and sway 5.0°; a squadmate still 0.06 m / 3.0°.


### 2026-11-01 — Left click with nobody selected orders everyone in the circle
- Mike: in command mode, a left click anywhere with no unit selected applies to everyone in the circle: on open ground a plain "go here", on a sandbag wall's box (the dig-in square) everyone in the circle tries to dig in. (A first go had put the dig-in on the right click; that's undone.)
- **`command.gd _click()`**: not on a squadmate (that still selects it), the click goes to `_order_targets()` (the selection, or everyone who hears): a supply crate owing parts, they build from it; anywhere else `_order_move(point, units)`, which mans a wall's row at a wall (`_man_sandbags()`) and otherwise lines them up there. **`_order_move()`** takes who goes (default the selection), so a **right click** still only ever moves a selection. **`_sandbags_at()`** (new) finds the wall whose box a point is in.
- Tested (`test_click_orders.gd`, scratch copy, main level, command mode, a 6-tile wall, five squadmates in the circle and one 16 m off): nobody selected, a left click on open ground sent the five there side by side, the far one stayed; at the wall the five went and were all dug in within 5 s; right clicks on ground and wall moved nobody; a left click on squadmate 3 selected it without moving anyone; then a left click at the wall sent only 3.

### 2026-11-01 — Air drops come down in a line, not a 2 x 2 block
- Mike: when you do air drops, don't do them in columns, do them in lines. **`radio_terminal.gd _dz_layout()`**: the filled slots' crates now lie in one line in slot order, `DROP_PITCH_M` 1.6 m apart, centred on the mouse (the drop-zone ghost shows the same); the scroll wheel still turns it 15° a notch. **`supply_drop.gd start(heli, drops, heading)`**: the helicopter flies in along that line (heading = the drop's turn, 0 = from the west, nose east) and lets each crate go as it passes overhead, then climbs away the same way. Before, it always flew east, letting go two crates side by side at a time.
- Tested (`test_line_drop.gd`, scratch copy, three crates turned 45°): in one diagonal line in slot order, the helicopter came in at 45° and was within 0.25 m of overhead at each release, then flew off and was removed.
### 2026-11-01 — Ordering a strapped crate unlocked; the straps snap
- Mike: select someone and click a crate when there's nothing to build from it, and they unlock it; and a quick snapping animation for the straps. **`command.gd _crate_at()`** also picks a crate that's still `strapped`, and `_click()` only calls `take_over()` when there's something to take over. **`squadmate.gd _crate_with_work()`**: sent to a crate (`_build_from`) it keeps at it while it's owed parts *or still strapped*, so with nothing owed it walks over, undoes the straps (UNSTRAP_S, one at a time as before) and goes idle. With nobody selected it's everyone in the circle, as for other clicks. Works for the ammo crate too.
- **`scripts/strap_snap.gd`** (new): spawned by `crate.gd _break_straps()` as a child of the crate (so it turns with it), alongside BandBreak. Each of the three straps (crates.py: two along y at ±0.3 of the load's width, one along x through the middle) parts near its middle and the two ends whip back past the load's edges (`WHIP_M` 0.22 m), the cut ends curling, fading out over `SNAP_S` 0.4 s. The player's F unstrap gets it too.
- Tested (`test_unlock_crate.gd`, scratch copy, main level, a crate turned 0.3 rad): one squadmate selected, clicked a sandbag crate with nothing laid: it went into BUILD, the straps broke at 4.3 s (open texture showing), the snap animation was there and gone 0.4 s later, the squadmate back to IDLE, the other five untouched. The same for a strapped ammo crate. `test_click_orders.gd` still passes. The animation itself hasn't been looked at in the running game yet.
### 2026-11-01 — DEPLOY moves under ORDERS; its button is now "Deploy"
- Mike: change the menu item Build to Deploy and put it on the left with the orders, with a gap so it's clear what's an order and what's deploying. **`command.gd`**: the DEPLOY column's button reads **Deploy** (it was Build, the same name as the Build order). `_place_menus()` stacks ORDERS over DEPLOY left of the player, `DEPLOY_GAP_PX` 28 px between them, the pair centred on the player as one (DEPLOY still hidden in radio command mode, and then ORDERS centres on its own). Its pop-out now opens to the left, like the orders'. The ORDERS menu's **Build** order is unchanged. Also removed a stale duplicate Space row from the controls table.
- Tested (`test_menu_stack.gd`, scratch copy, main level): ORDERS 711–1105 px, DEPLOY 1133–1209 px (28 px gap), both right-aligned the same distance left of the player, centred on its 960 px; the button reads Deploy.
### 2026-11-01 — Deployable ammo cans; everyone carries 2 magazines (can be empty)
- Mike: add deploy for ammo cans just like sandbags. A can is loose bullets, no magazines, so the magazine count doesn't go up; there's a short cooldown for opening the can and loading each round. All units keep a magazine count of 2, and each can be empty. His picks: 2 spares besides the rifle's own; ~120 rounds a can, gone when empty; loading time per round; a dead square's magazine swaps for your emptiest.
- **`rifle.gd`**: `spare_mags` now 2 (was 0) and means magazines carried, full or empty; new `spare_start_rounds` 0, so everyone still starts with 15 rounds in the rifle and nothing else. A reload always keeps the magazine coming out, empty or not (only endless-spare rifles drop empties now). New: `load_round()` (a loose round into the fullest spare that isn't full), `spare_room()`, `ready_to_load()` (not reloading or just fired), `swap_magazine(count)` (replaces the emptiest spare if it's better; returns what it held, or -1), `put_magazine()`. `add_spare()` is gone.
- **`ammo_pickup.gd`** (dead squares' magazines): now a swap. The taker's emptiest spare goes into the dead rifle, and the circle stays if that one still has rounds. `useful_to()` stops the player or AI swapping for something no better. The note reads "MAG n". `note()` is static so the can uses it too.
- **`scripts/ammo_supply.gd` + `scenes/ammo_supply.tscn`** (new): the deployed can. It goes down as a site like a sandbag wall (`start_site()`, `needs("ammo_can")`, `install()`), on the ground under the squares, not solid. Built, it holds `rounds` 120 and is in "ammo_pickups". Anyone within `REACH_M` 0.6 m with room in their spares loads from it (`work_load()`): `OPEN_S` 0.6 s for the lid, then a round every `round_s` 0.1 s. Two empty magazines take 6.6 s. Firing or reloading pauses it, and stepping away starts again with the lid. The player loads just by standing there, and "+n rds" floats up when they stop. A gold ring round the can shows the loader's spares filling. In command mode the rounds left show over it. Empty, it fades out.
- **`ai_soldier.gd`**: `_nearest_ammo()` skips ammo that wouldn't help (`useful_to()`). Cans aren't claimed (several can share). At a can it stands loading until its spares are full or the can's empty (`_loading_ammo` keeps it going once it's no longer "short"), then reloads. An order still pulls it away.
- **`crate_ammo.tscn`**: `builds = "ammo_can"`, 24 `ammo_can` parts (the 4 x 2 x 3 cans in the art). There are no stage pictures, so the load looks full until the last can goes. **`command.gd`**: "Ammo can" in DEPLOYABLES and CRATE_BUILT (so it's in DEPLOY and the Build order's pop-out), with a drawn can icon. **`carry_art.gd`**: an olive can held in front.
- Note: everyone starting on 15 rounds counts as short, so squadmates within `AMMO_TOPUP_M` 12 m of a new can all go and top up. Six of them empty a 120-round can.
- Tested (`test_ammo_can.gd`, scratch copy, main level): everyone starts at rifle 15, spares [0, 0]; a reload is refused. A squadmate built a can from a strapped ammo crate in 6.1 s (it undid the straps first). The player standing there loaded 60 rounds in 6.60 s (spares [30, 30], can 60 left), then a reload gave rifle 30, spares [30, 0], still 2 magazines. A squadmate out of ammo walked to the can, loaded 60 (can empty, gone) and reloaded. A dead rifle with 20 swapped into spares [0, 12] gave [20, 12] and the pickup went; it wasn't offered to spares [25, 30]. `test_unlock_crate.gd` and `test_click_orders.gd` still pass.

### 2026-11-01 — Build order removed from ORDERS
- Mike: get rid of the Build order in the menu. **`command.gd`**: the "build" entry is gone from ORDERS, along with its pop-out (`_build_popout`, `_open_build_popout()`, the `picks` button kind). Crate-built things (radio station, sandbags, ammo can) are laid from **Deploy**. With squadmates selected when the item's picked, they build it (`_build_crew`, as before); nobody selected, the player carries the parts in. Clicking a supply crate in command mode still sends the selection (or everyone in the circle) to build from it or unstrap it. Squadmates' BUILD state (`squadmate.gd order_build()`) is unchanged.
- Tested (scratch copy): `test_menu_stack.gd`, ORDERS now 341 px tall (was 394), DEPLOY still 28 px under it; `test_click_orders.gd` passes.

### 2026-11-01 — Ammo crate empties in stages; can ghost easier to see; AmmoCrate override removed
- Mike: the ammo can ghost doesn't show, and clicking the ammo crate doesn't send units like the sandbag crate. **Ghost:** it was there but a small dark-olive can tinted green on green grass (checked in a rendered frame). **`ammo_supply.gd`**: a green outline round the can and a ring at `REACH_M` (`_draw_mark()`) on a placing ghost, on a site, and on a placed can in command mode. The can is drawn brighter (`GHOST_BRIGHT`) on a ghost or site, and `SITE_GHOST` is less see-through (0.6). **Crate:** `scenes/main.tscn`'s AmmoCrate had `builds = ""` and `parts = []` overrides, written when the editor saved the level with the old crate scene still loaded (09:33), so it held no cans. Deploys took their can from AmmoCrate2 across the map, and a click on the near crate was a plain move. Overrides removed. Tested (`test_can_crate_click.gd`): with a can site laid, one squadmate selected and the near AmmoCrate clicked, it unstrapped it, picked up a can at 3.8 s and set it down at 6.1 s.
- Mike: add 3 more stages for the ammo crate. **`blender/scripts/crates.py`**: `AMMO_STAGES`, columns left per layer (bottom first), [[4,4,1], [4,2,0], [3,0,0]]: 18, 12 and 6 cans. From above, a whole layer gone looks just like the one under it (the first try, 16/8/3 cans by layer, gave near-identical pictures), so they go a column at a time and the stack steps down, each step casting a shadow on the lower cans. Rendered crate_ammo_1..3.png (and re-rendered crate_ammo.png, _open.png, the preview and the .blend, same seed). **`crate_ammo.tscn`**: `stage_textures` [full, _1, _2, _3], `stage_heights` [0.732, 0.732, 0.536, 0.34]. Tested (scratch copy): straps off it shows the open load; from 6 taken stage 1, 12 stage 2, 18 stage 3, 24 just the pallet; the shadow height follows. The new PNGs need importing by the editor (focus it).

### 2026-11-01 — One square at a time at an ammo can
- Mike: only one unit at a time should go to an ammo can; the grouping round it looks weird. **`ai_soldier.gd _nearest_ammo()`**: a can is claimed like a dead square's magazine (`claimed_by`), so others skip it while one is on its way or loading. The claim is let go when it's done (spares full or can empty), given an order, or killed. The next one picks it up on its next look (`AMMO_LOOK_S`). The player isn't held back by a claim. Doc comments in ai_soldier.gd and ammo_supply.gd updated.
- Tested (`test_can_queue.gd`, scratch copy, main level, six squadmates 3 m from a 400-round can, all short): they went one after another, each done (spares [30, 30]) about 8.5 s after the last (8.9, 17.5, 26.1, 34.2, 42.4, 50.7 s). Never more than one within 1 m of the can, nor more than one heading for it.

### 2026-11-01 — Debug mode (Q) shows what each unit is doing
- Mike: when I press Q, also show the units' state (defending, attacking, surprised...). **`debug_overlay.gd _status()`**: under each square's number, its state (squadmate.gd `State`, enemy.gd `Mode`; ATTENTION shortened to ATTN, SURPRISED to SURPRISE) coloured by kind (`STATE_COLORS`: orange ENGAGE, blue DEFEND, yellow SURPRISED, red PINNED, purple SEARCH, tan BUILD, grey the rest). On a line under that, short tags: `>n` the square it's shooting at, its cover phase (going / hiding / peeking), `hold` (a friend in the line), `standoff`, `stop`, `ammo` (on an ammo run) or `loading` (at a can), `reload`, and what it's carrying. The clicked unit's panel adds the state in full and the same things spelled out (shooting at #n, holding fire: a friend in the line, dug in at a wall, in formation, not alerted...). Nothing for the player but its number.
- Tested (`test_debug_state_shot.gd`, scratch copy, rendered frame): an enemy showed ENGAGE >1; squadmates ATTN >7 hold, DEFEND, PINNED, ATTN >7 hold standoff; the picked one's panel read ATTENTION / shooting at #7 / holding fire: a friend in the line.

### 2026-11-01 — Debug numbers and states bigger, states in the number's colour
- Mike: make the numbers and states larger, and the states green as well. **`debug_overlay.gd`**: numbers `FONT_SIZE` 28 (was 20, outline 6), state and tag lines `STATE_FONT_SIZE` 18 (was 12). The state and its tags are now in the number's colour (green for our side, red for enemies; tags a little fainter) instead of a colour per state (`STATE_COLORS` gone). Checked in a rendered frame (`test_debug_state_shot.gd`).

### 2026-11-01 — Debug mode: wheel-button drag pans the camera
- Mike: in Q mode, let me press in the wheel button to pan the camera. **`game_camera.gd`**: while `World.debug` is on, holding the middle button and dragging moves the view (`_pan`, the ground following the mouse: motion / zoom). It's kept within the camera's usual bounds (`_view_center_for()`), and re-clamped each frame so dragging past an edge doesn't store up slack. The wheel still zooms. Turning debug off clears the pan and eases back onto the player (`_easing_move`). Outside debug mode the middle button does nothing, as before. Controls table Q row updated.
- Tested (`test_debug_pan.gd`, scratch copy, main level, events fed to the camera): no pan outside debug; in debug a 300 px drag left moved the view 3.5 m right (zoom 1); a huge drag stopped at the arena edge (35.75 m) and a 500 px drag back moved it straight away (29.9 m); 1.5 s after Q off it was back by the player.

### 2026-11-01 — Held-item art renamed hold_*
- Mike: put "hold" at the start of the names of the items units hold (asset housekeeping, nothing in game changes). Renamed with `git mv`, each with its `.import` (its uid kept, its paths updated): `assets/characters/rifle.png` → `hold_rifle.png`, `rifle_no_mag.png` → `hold_rifle_no_mag.png`, `magazine.png` → `hold_magazine.png`, `assets/props/ammo_can.png` → `hold_ammo_can.png` (and `assets/previews/ammo_can_preview.png` → `hold_ammo_can_preview.png`). References updated: `scenes/soldier.tscn`, `scenes/ammo_can.tscn`, `scenes/ammo_supply.tscn`, `scripts/rifle.gd`, `scripts/ammo_supply.gd`, and the Blender scripts that render them (`rifle.py`, `crates.py`), so a re-render writes the new names. The radio pack (worn, not held) and the carried station parts / sandbags (drawn in code, `carry_art.gd`, no files) are unchanged. The Asset List above uses the new names. Older dated entries keep the names as they were.
- Tested (scratch copy, the same rename, re-imported): `test_ammo_can.gd` passes; no missing resources.

### 2026-11-01 — Carried items are their own pictures, as on their crates
- Mike: the carried items (desk parts, sandbag, ammo can) were simpler than the crate art; give each its own asset, identical to how it looks on its crate. **`blender/scripts/crates.py -- held`** (new `render_held()`, `HELD_FRAMES`): builds each part exactly as on its crate and renders it on its own, centred, top-down, 4x density, transparent. For the comms parts that's the comms load with every other part removed (desk 0.72 x 0.25 m in a 0.75 m frame; electronics, legs and dish cases 0.36 x 0.24 m and the cable reel 0.22 m in 0.5625 m frames). The sandbag is the sandbag crate's bottom bag (same key), 0.40 x 0.27 m. Output `assets/props/hold_desk.png`, `hold_electronics.png`, `hold_legs.png`, `hold_dish.png`, `hold_wiring.png`, `hold_sandbags.png`. The ammo can uses `hold_ammo_can.png` (the lone can, `-- can`, the crate's can model). Their `.import` files are written with the crate art's settings (mipmaps on).
- **`scripts/carry_art.gd`**: draws those pictures (0.25 scale) in place of the drawn shapes, held AHEAD_M in front, long side across the body (the can turned 90 degrees). **`player.gd`, `squadmate.gd`**: the carry view filters with mipmaps.
- `scenes/main.tscn`: the editor had again written AmmoCrate overrides on save (`stage_textures = []`, and `stage_heights` saved as a texture array), from its old copy of crate_ammo.tscn. Removed. The editor needs crate_ammo.tscn reloaded or it'll keep doing this.
- Tested (scratch copy, re-imported, rendered frame): six squadmates and the player each carrying one item. Each matches its crate (sandbag beside the sandbag crate, can beside the ammo crate).

### 2026-11-01 — Carried items held against the body, the square over them
- Mike: bring the held props in so they touch the unit and the unit is slightly over the box, so they look held, not floating in front. **`carry_art.gd`**: each part's centre is now `HALF_SQUARE_M` 0.2 + half its own depth (`DEPTH_M`) − `OVERLAP_M` 0.06 ahead of the carrier's middle (was a fixed 0.36 m), so its near edge sits 6 cm under the square's front face. **`player.gd`, `squadmate.gd`**: the carry view is z 0 (was 2) and moved just before `Body` in the tree, so it's drawn over the shadows and under the square.
- Checked in a rendered frame (`test_carry_shot.gd`, scratch copy, zoom 3): each square overlaps the back of what it carries (desk, cases, sandbag, the player's can).

### 2026-11-01 — Enemies use ammo crates: unstrap them, and set up ammo cans in a standoff
- Mike: an enemy that comes into an ammo crate's vicinity at least undoes its straps (in debug mode, clicking a crate shows its vicinity circle). If enemies are engaged and in standoff, still in the crate's vicinity, one of them sets up 1 ammo can for every 3 in the group, about 2 m from where the group is held up.
- **`crate.gd`**: `vicinity_m` (export, 8 m). `enemy_worker` (one enemy at a time) and `enemy_cans`. `take_unplanned()` / `give_back_unplanned()`: an enemy takes a can that nothing was set up for, reserving it as it's taken (so it never eats a squad site's reserved parts).
- **`enemy.gd`** (CRATES in the header; `_crate_work()`, checked every `CRATE_LOOK_S` 0.5 s, after the ammo run; `crate_task`):
  - "unstrap": a strapped ammo crate in vicinity, and it's free to (not SURPRISED, and not in ENGAGE unless held up). It goes and undoes the straps.
  - "ammo": held up (`_held_up()`: ENGAGE, attacking, ai_soldier.gd `_standoff`) by an open ammo crate. The group is every held-up enemy in that crate's vicinity. `_cans_wanted()` = ceil(group / `UNITS_PER_CAN` 3) less the enemy cans already round the group (group "enemy_ammo_cans", from any crate) and any another enemy's bringing. The worker takes a can, carries it (rifle away, `CARRY_SPEED`, carry_art.gd; can't fire) to `CAN_BACK_M` 2 m behind the group's middle, away from the foes they're targeting, `CAN_SPREAD_M` 1.2 m apart across. The spot is moved to clear ground if something solid is there (`_clear_ground_near()`, `CAN_CLEAR_M`). If it gets no closer for `CARRY_STUCK_S` 2 s it sets the can down where it is. The can's a normal ammo_supply.gd can (120 rounds, one at a time), so any enemy short of ammo tops up from it (ai_soldier.gd `_ammo_run()`).
  - It gives up if the standoff ends before it has a can, or the group has enough. Surprised while carrying, the can goes back on the crate. Killed: the same, and its rifle shows again for the fall.
- **`debug_overlay.gd`**: a click on a crate picks it: its vicinity circle (gold) and a panel (what it holds n / total, strapped or not, vicinity, parts owed, the enemy working at it and its job, enemy cans set up from it). Enemies show "unstrapping" or "can run" tags. Hint line mentions crates and the wheel-button pan.
- Found while testing: the first version put a can spot on top of the crate (the carrier stood there forever), and counted per crate (a second crate in range started a second can run for the same group). Both fixed as above.
- Tested (`test_enemy_crates.gd`, scratch copy, main level): a calm enemy 5 m from a strapped ammo crate undid the straps (4.8 s). Five enemies held up 9–12 m from the player boxed in by sandbags, by an open ammo crate (the rest held in place, as the box made them close in and lose sight otherwise): one took on the can run at 0.5 s and set a can down at 4.5 s, 1.8 m from the group's middle on the far side from the player. A second can at 7.1 s, 2.3 m from the middle, 1.5 m across from the first. No third. Two enemies topped up from the first (30 + 45 each). A third undid the strapped AmmoCrate2 in range. Rendered frame: the crate panel and circle.
- Not yet: the enemies' own fighting against a target boxed in on all sides closes in to the walls and loses sight (existing behaviour, seen while testing); that ends their standoff.

### 2026-11-01 — Early Deploy: crates parachuted in before the player's helicopter
- Mike: at the start, before the helicopter that drops the player off arrives, any crate with an Inspector setting Early Deploy ticked is dropped by a helicopter like a normal supply drop.
- **`crate.gd`**: `early_deploy` (export, off). **`arrival.gd`**: at the start it hides and switches off the player (as the insertion does) and gathers the crates with `early_deploy`. If there are none it flies the player in as before. Otherwise it takes them out of the level and sends a supply helicopter (`supply_drop.gd`) to parachute each one back onto its own spot, turned as placed. It's the crate node itself, so its Inspector settings (strapped, vicinity...) come with it. When the last has landed (`air_drop.gd` new `landed` signal, via `supply_drop.gd` new `released` signal) and `EARLY_PAUSE_S` 1 s has passed, the player's helicopter comes in. **`air_drop.gd setup()`** takes a crate node as well as a scene. With Arrival off (tests), early-deploy crates are just there.
- Tested (`test_early_deploy.gd`, scratch copy, main level with Arrival on, AmmoCrate and SandbagCrate ticked, the sandbag crate turned 0.5 rad): both off the field at 0.5 s, player hidden and aboard; supply helicopter at 0.1 s; both crates down at 6.5 s exactly on their placed spots (12.97, 16.37 and 12.97, 14.99), turned as placed, still strapped; the player's helicopter at 7.5 s; player out at 14.2 s.

## 2026-11-01 — Player Inspector: Drop Off Animation

- `player.gd` has a new export, `drop_off_animation` (on by default). Untick it on the Player node in `main.tscn` to start the level standing where the player is placed, with no helicopter fly-in.
- `arrival.gd` checks it: when it's off, the player isn't hidden or put aboard, and `_fly_in()` does nothing. Early-deploy crates still parachute in at the start; the player is already on the ground and can watch.
- Untick `enabled` on the Arrival node to skip both, as before.
- Tested headless on the scratch copy. With it off, the player is visible and active from the start, only the supply helicopter flies in, and the crate lands. With it on, the early-deploy test gives the same timings as before.

## 2026-11-01 — F goes to the closest thing only

- When two things in reach both answered F (a crate beside a station's desk, a build site beside the dish), each handled F on its own, so both could act, or whichever came first in the tree won.
- Now `player.gd` has `interact_target()`: of everything F would do something to right now, the closest. It considers crates (take a part, undo the straps), build sites needing what's carried (radio station, sandbags, ammo can), and anything in the new "interactables" group. That group's members answer `interact_point()` with a world position, or null when F does nothing there. The radio terminal (its desk) and the radio station (its dish) are in that group.
- Every F action checks it's the target: the player taking, delivering and unstrapping, the terminal opening, and the dish tuning. Every green F prompt (crate, desk, dish, site delivery keys) only shows on the target, so only one F shows at a time. Closing or leaving something already open (menu, hang up, stop tuning) isn't affected.
- Tested headless on the scratch copy (test_closest_f.gd). Standing at a station's desk with a strapped crate in reach, the crate at 0.8 m (desk 0.95 m) gets F and unstraps, and the desk stays shut. The crate at 1.2 m loses to the desk, which opens. Only the target's F showed. The unlock-crate, ammo-can, click-orders and early-deploy tests still pass.

## 2026-11-01 — Debug mode: enemy circles, cover class on click

- Enemies' detection circles (`enemy_ring.gd`) now only show in debug mode (Q), not in normal play. `show_detection` on an enemy still hides its circle even in debug mode.
- In debug mode, clicking anything solid that isn't a square or a crate picks it: a sandbag wall, the station's desk or dish, a helicopter, and so on. `debug_overlay.gd _object_at()` uses a physics point query, so it picks whatever a bullet would hit there.
  - Its panel shows its name (and what it's part of, e.g. DeskBody (RadioStation)), its cover class and the share of shots it stops, from `cover.gd`: sandbags class 3 HEAVY 90%, the desk class 1 LIGHT 30%, the dish class 2 MEDIUM 60%.
  - The ring and panel sit where you clicked. A crate's panel now has the same cover line (class 3 HEAVY, 100%).
- Tested headless on the scratch copy (test_debug_cover.gd). The ring was hidden in play, shown with Q on and hidden again with Q off. The sandbags, desk, dish and ammo crate panels all read as above, and clicking open ground clears the pick.

## 2026-11-01 — Firing over sandbags exposes you

- Mike: anyone firing over a sandbag wall has their head up, so the wall covers them only 40%, and an enemy held up in Engage + Standoff takes that chance to shoot them.
- `soldier.gd`: every square is exposed (`exposed_s`) for EXPOSED_S (0.8 s) after each shot it fires (the rifle's `fired`). That's the player, squadmates and enemies alike.
- `sandbags.gd`:
  - A shot reaching the wall that's heading for an exposed square is stopped only EXPOSED_STOP (40%) of the time, instead of 90%. "Heading for" means passing within EXPOSED_LINE_M (0.5 m) of them, with them beyond the wall and within EXPOSED_NEAR_M (1.2 m) of where it hits.
  - `cover_stop_chance_for(point, unit)` gives the same answer for the AI, and `cover.gd` has `stop_chance_for()` / `class_for_unit()`. 40% is class 1.
- `ai_soldier.gd _shielded()`: a wall only shields a foe while it's class 3 for them. Exposed, it isn't, so a square held up in a standoff sees a window (`_in_standoff()`, looked at every 0.25 s) and fires.
  - This is shared AI, so squadmates in a standoff also fire on an enemy who pops up over a wall.
- Debug view (Q): a square that's just fired from a sandbag wall's box gets an "exposed" tag.
- Tested headless on the scratch copy (test_exposed.gd), with a squadmate 0.5 m behind a wall and an enemy 10 m out, engaged with it:
  - Bullets at the wall got over 10% of the time normally and 60% with the squadmate exposed.
  - With the squadmate holding fire, the enemy was in standoff 82% of 4 s and fired 0 shots.
  - With the squadmate firing over the wall every 0.5 s, it was in standoff 4% and fired 6 shots.
  - test_cover_class, test_shielded, test_standoff, test_enemy_crates and test_debug_cover are unchanged.
- Note: two AI sides each dug in behind walls still sit in a standoff with neither firing (test_standoff), since nobody fires to expose themselves. It's the player's shots that break one.

## 2026-11-01 — Watch tower and its crate

- Mike asked for a new crate and asset, a watch tower (after his reference photo: a cream cabin with a band of dark windows on a galvanised frame, an air conditioner, a switchback stair), built in 5 pieces: the base, the roof, the stairs, another part of the base, and the details.
- **Art: `blender/scripts/watch_tower.py`** (new). Real size: a 2.8 m grating deck 3 m up on four splayed square-tube legs with X bracing, a 2 m cabin (roof at 5.3 m), and a stair down the east side with a mid landing.
  - It renders the 5 parts top-down, each with its own shadow: `assets/props/watch_tower_<part>.png` and `watch_tower_shadow_<part>.png`, 2048 px (12 m at 2x), shown at 0.5.
  - The parts:
    - **base:** legs, foot plates and lower bracing
    - **platform:** upper bracing, deck and railing
    - **stairs**
    - **roof:** the cabin and its roof
    - **details:** window frames, sign, air conditioner, searchlight, antenna, camera, vent, conduit
  - Each part is rendered as it shows in the finished tower. Anything of a part drawn under it in game that's in front of it is cut out (a holdout, e.g. the roof's overhang over the AC unit), and the other parts' shadows fall on it (the roof's on the deck). DRAW_ORDER must match the scene's z order.
  - Reviews: `assets/previews/watch_tower_preview.png` (top-down with shadow) and `watch_tower_angle_preview.png`.
- **Crate: `crates.py` "tower" kind** (`-- tower`): the 5 parts on the pallet like the comms kit (`TOWER_PARTS`):
  - a bundle of galvanised tubes (base)
  - a stack of grating panels (platform)
  - a stair flight laid flat
  - stacked cream cabin panels (roof)
  - the boxed AC unit (details)
  - It makes `crate_tower.png`, `_open` and `_1..4`. The comms stages loop now does both kinds.
  - Carried sprites: `hold_tower_<part>.png`. A held part can now be rendered on its own (`-- tower_base`) without redoing the rest.
- **Game:**
  - `scripts/watch_tower.gd` and `scenes/watch_tower.tscn` (new) are built like the radio station: `start_site` / `needs` / `can_deliver_at` / `install`, the parts as green ghosts until delivered, and a green F over the deck when the player brings a part (DELIVER_M 3 m).
  - Squares walk under the deck. The base is drawn under the squares, everything else over them, and the deck, cabin and details fade to 35% while the player's under the deck.
  - Solid: the four legs (`LegsBody`, partial_cover 100%, see-through, metal) and the stair's lower flight (`StairsBody`, stops 35%).
  - Shadows sit in a CanvasGroup (overlaps no darker), each moved for its own height when the tower's turned.
  - `scenes/crate_tower.tscn` (new): `builds` "watch_tower", single_site, the five parts in order.
  - `command.gd`: "watch_tower" is in CRATE_BUILT, plus a "Watch tower" DEPLOY entry with an icon (the cabin on X-braced legs with a stair).
  - `carry_art.gd`: the five held sprites and their depths.
- The new PNGs have hand-written .import files (mipmaps on, no uid; Godot adds the uid).
- **Not in main.tscn yet:** drag `scenes/crate_tower.tscn` into the level to have one. The tower does nothing yet beyond being built, solid and cover.
- Tested on the scratch copy:
  - test_watch_tower.gd: the player carries all 5 parts in order. The crate steps through its stages to empty, the F shows each time, and it ends built with the legs and stair solid; the deck and cabin fade while under it.
  - test_tower_squad.gd: two squadmates under a Build order put it up in 9 s.
  - A windowed screenshot shows a built tower beside a half-built site.
  - The unlock-crate, ammo-can, closest-F and menu tests still pass.

## 2026-11-01 — Watch tower: climbing it, railings, roof see-through

- Mike: squares should be able to get up on the tower (until now it was drawn over everyone), its side railings should keep them on it, they should get bigger the higher they climb, and the roof should go see-through whenever anyone's inside the cabin.
- **Two levels** (`watch_tower.gd`, `soldier.gd`):
  - On the ground, as before: the legs and the stair's lower flight are solid, and the deck and everything above it is drawn over you. The deck fades while the player's under it.
  - Walking up into the stair's foot (`steps_on()`: the FOOT_ON box, heading north) puts a square on the tower (`soldier.gd tower`). It moves to collision layer 32 and only bumps into the tower's railings and cabin walls (layer 64, made in code from WALLS, `scripts/tower_walls.gd`) and the others up there. Ground squares and tower squares don't push each other.
  - Its height (`elevation_m`, `height_at()`) climbs the lower flight to the mid landing (1.5 m), then the upper one to the deck (3 m). It's drawn over the deck (z 6; the roof is now z 7, the details z 8).
  - Walking back out of the foot (`steps_off()`) puts it on the ground.
  - Up there nothing on the ground underfoot counts (no sandbag climbing or bodies).
- **Bigger with height:** `soldier.gd view_scale()` = 1 + 0.08 a metre (GROW_PER_M), 1.24x on the deck. It applies to the body, its shadow, the rifle (`rifle.gd view_scale`), anything carried and a radio pack.
- **Railings:** round the deck, the top landing and both flights, open only at the stair's foot. The cabin's walls have the door in the east wall. Bullets pass them all (they don't know how high they fly). The art's top landing was moved (`watch_tower.py` STAIR_TOP_Y 1.0 -> 0.6) so the way from the stair onto the deck is 0.8 m wide, not one square.
- **Roof:** whenever any live square is inside the cabin, the roof and the details on it fade to 20%, and a new render of the cabin with its roof off fades in (`watch_tower_roof_open.png`, `RoofOpen`, drawn with the deck under the squares) so you see who's in there.
- **Squadmates take the stairs** (`ai_soldier.gd _walk_to()` / `_tower_way()`, `squadmate.gd _head_for()` and `_climbs_towers()`). A Move, or a formation slot, on the tower's outline (`on_surface()`) goes by `watch_tower.gd route()`:
  - up: to the stair's foot, up the flights, onto the deck and round the cabin by the south-east corner, in at the door lined up with it
  - down: the same way back
  - Up there they steer round the railings and walls (`_obstacle_mask()`), and only squares on the same level are in each other's way. Enemies don't climb it.
- Tested on the scratch copy:
  - test_tower_climb.gd (the player):
    - On at the foot: height 0.1, scale 1.01. Mid landing 1.5 m, 1.12x. Deck 3 m, 1.24x.
    - The cabin stops them going west on the north side. The railings stop them east and south.
    - In at the door the roof goes to 0.2, and back to 1 out of it. Down and off at the foot.
  - test_tower_squad_climb.gd (a squadmate):
    - Up to the deck's south-east corner in 17.5 s.
    - Into the cabin in 2.5 s and out again.
    - Onto the top landing, then down to the ground in 8.5 s.
  - Screenshots show a square in the cabin with the roof off, one on the deck, two on the stairs.
  - All the earlier tests still pass.
- **Not done yet:**
  - Height doesn't change shooting or sight (no seeing further or firing over things from up there; the railings and cabin give no cover).
  - Enemies don't climb.
  - Following the player up there: the squadmates whose formation spot lands on the tower go up, and the rest wait below.
  - A click anywhere on the deck's outline means up there, so squadmates can't be sent to stand under the deck.

## 2026-11-01 — Watch tower: stepping onto the stair is seamless

- Mike: walking up the stair he was briefly under it before it worked. His battle log (17:54) didn't help: it ran for 1.5 s and ended before he reached the tower, and the log doesn't record tower state yet.
- **The cause:** a square only stepped on (`steps_on()`) once its middle was in FOOT_ON, which reached only 0.05 m past the bottom step (y 4.1). A square is 0.4 m, so for about 0.15 m its front half was over the stair while it was still on the ground, drawn under the stair.
- **The fix** (`watch_tower.gd`):
  - FOOT_ON now reaches out to y 4.75, more than half a square past the bottom step, and is 1.1 m wide. Anyone coming up whose square would touch the foot is on the tower first.
  - Off is at FOOT_OFF_Y 4.9. In between it stays on the FOOT_APRON in front.
  - The squadmates' FOOT_OUT waypoint moved out to y 5.2, past the off line.
  - The tower-level railings now flare out at the foot (from just inside the stair at y 3.75 to 1.2 / 2.8 at y 4.8). A square coming up off the middle is guided in rather than caught head-on on the end of a railing.
  - On the ground, the stair's two side stringers at its foot are solid (StairsBody FootWest / FootEast, open at the front), so you can't walk in under the bottom of the stair from the side.
- Tested on the scratch copy (test_stair_seam.gd): walking up from 5 starting points across the foot (x 1.5 to 2.5) and back down, checking every frame.
  - All step on at y 4.73 and go all the way up.
  - None are ever on the ground while any of the square is over the stair, going up or coming down.
  - From the side you stop at the stringer.
  - The climb, squadmate climb and build tests still pass.

## 2026-11-01 — Height classes, and firing down from the watch tower

- Mike: every object has a height class (1, 2 or 3). Sandbags and the radio system are 1, crates 2, the watch tower 3. Anything you can go up on has 3 circles round it, and in each a setting for how much the smaller classes' cover is weakened, adjustable in the Inspector: sections 1-3, each with a radius and a debuff per class.
- **Height classes** (`cover.gd height_class_of()`, a `height_class` export on each):
  - 1: sandbags.gd; partial_cover.gd (the radio station's desk and dish)
  - 2: crate.gd
  - 3: the watch tower and its legs and stair (watch_tower.tscn), and anything solid that doesn't say (a helicopter)
- **Sections** (`watch_tower.gd`). The Inspector has groups Section 1 / 2 / 3, each with `section_<n>_radius_m` and `section_<n>_class_1_debuff` / `_class_2_debuff` (%). Defaults:
  - section 1: to 5 m, class 1 -75%, class 2 -50%
  - section 2: to 10 m, class 1 -50%, class 2 -25%
  - section 3: to 20 m, class 1 -25%, class 2 -10%
- **How it works:**
  - A shot fired by someone up on the tower that meets lower cover in section n is stopped that much less often: stop chance x (1 - debuff).
  - The section is where the shot meets the cover, measured from the tower's middle.
  - It's in full from the deck and scales down the lower they are on the stair (`cover_debuff()`, elevation / 3 m). Nothing past section 3, and nothing for class 3 cover.
  - Bullets: `bullet.gd _fired_down_past()`, asked once per cover after the cover's own `lets_bullet_through()`.
  - The AI: `ai_soldier.gd _shielded()` counts the weakened cover, so a squadmate up the tower doesn't sit in a standoff against a foe it can now hit.
  - Sandbag climbing raises you a little, but nothing is lower than class 1, so only the tower has sections.
- **Debug view (Q):**
  - Clicking a tower's deck or stair (or its legs) picks the tower. It draws its three section circles (red, orange, yellow, numbered) and a panel with its height class, how many are up on it, and each section's range and debuffs.
  - Every object's and crate's panel now also shows its HEIGHT CLASS.
- Tested on the scratch copy (test_height_class.gd), firing 2000 shots per case at sandbags and a crate from the tower deck vs the ground:

  | Cover | Section 1 | Section 2 | Section 3 | Past section 3 |
  |---|---|---|---|---|
  | Sandbags, from the deck (expected 77.5 / 55 / 32.5 / 10) | 75% through | 56% | 34% | 11% |
  | Crate, from the deck (expected 50 / 25 / 10 / 0) | 50% | 26% | 9% | 0% |
  | From the ground | about 10% (sandbags), 0% (crate) | same | same | same |

  - A squadmate on the deck no longer counts a foe 4.5 m out behind sandbags as shielded; on the ground it does.
  - The exposure, standoff, cover, debug, climb and orders tests still pass.

## 2026-11-01 — Watch tower: section 3 runs as far as a bullet goes

- Mike: the third region is always as far as a bullet can go.
- `watch_tower.gd`: `section_3_radius_m` is gone. Section 3 is everything past section 2's circle, out to wherever a bullet reaches (`sections()` gives it INF), so cover any distance past 10 m (by default) gets section 3's debuffs. The Inspector's Section 3 group now holds only its two debuffs.
- Debug view (Q): only circles 1 and 2 are drawn, with a "3" just outside circle 2. The panel reads "section 3  10.0 m - bullet range".
- Tested on the scratch copy (test_height_class.gd): from the deck, sandbags at 15, 25 and 40 m all let 32-34% through and the crate 10% (section 3). Sections 1 and 2 are unchanged.

## 2026-11-01 — Watch tower sections: "New Pass Through %" instead of a debuff

- Mike asked whether the debuff meant the pass-through percentage. It didn't: it was a cut in what the cover stops, so the pass-through depended on the cover. Now each section's setting is the share of shots fired down from the tower that get through, directly.
- `watch_tower.gd`: the Inspector groups use prefixes (`@export_group("Section 1", "section_1_")`), so each shows **Radius M**, **Class 1 New Pass Through** and **Class 2 New Pass Through** (%).
  - The vars are `section_<n>_class_<c>_new_pass_through`.
  - Defaults keep the old behaviour: section 1 class 1 78 / class 2 50, section 2 55 / 25, section 3 33 / 10.
- `fired_down_pass()` gives the pass-through for a shot: the setting, but never less than the cover lets through anyway (the radio desk lets 70% through, so a setting under 70 leaves it at 70). It's in full from the deck and less lower down the stair.
- `cover.gd fired_down_extra()` (was `elevation_debuff()`) turns that into the chance a shot the cover would stop gets through anyway, which is what `bullet.gd` and `ai_soldier.gd _shielded()` use.
- Debug view's tower panel reads "FIRING DOWN: new pass through" with the percentages per section.
- Tested on the scratch copy (test_height_class.gd), from the deck:
  - Sandbags let 79 / 56 / 33-34% through by section, and the crate 50 / 25 / 9-10%.
  - From the ground, sandbags let 10% through and the crate none.
  - The desk with a setting of 50 stays at 70%.
  - The exposure, debug and cover tests still pass.

## 2026-11-01 — The watch tower as cover for those in or under it

- Mike: the tower has stages of cover. Under it, 75% of shots get through; on the stairs 80%; on the top platform 50%; in the house (cabin) 30%.
- `watch_tower.gd`: a new Inspector group **Cover For Those On It** (prefix `cover_`), with Under / Stairs / Platform / Cabin Pass Through (%), defaults 75 / 80 / 50 / 30.
  - `zone_of(unit)` gives "under" (on the ground under the deck), "stairs", "platform" (the deck outside the cabin) or "cabin".
  - `cover_pass(target, shooter)` gives that zone's pass-through, or 100% if the target's in none of them or the shooter's in the same zone (two on the deck shoot each other freely).
- `cover.gd tower_pass()` / `tower_blocks()`: a bullet reaching a square in or under a tower rolls on it (`bullet.gd`). If the steel stops it, it ends in the tower's LegsBody instead (sparks and a metal clang, logged as hitting that) and the square isn't hit.
- `ai_soldier.gd _shielded()`: a foe in or under a tower counts as shielded when that zone is class 3 cover (stops over 60%). So with the defaults, the cabin (stops 70%) holds an enemy in a standoff until there's a window, and the deck (50%), stairs and under don't.
- Debug view (Q): the tower's panel lists the four pass-throughs. A square's panel says which zone it's in and how much gets through.
- Tested on the scratch copy (test_tower_cover.gd, an enemy 8 m west):
  - 2000 rolls each: under 76%, stairs 80%, deck 50%, cabin 30%, open ground 100%; deck to deck 100%.
  - The enemy counts only the cabin as shielded.
  - 200 real bullets at a squadmate in the cabin hit it 55 times (about 60 expected).
  - The height class, exposure, cover, standoff, climb and debug tests still pass.

## 2026-11-01 — Watch tower parts each with their own stats; standard debug panels

- Mike: each part of the watch tower has its own stats. The stairs have their own cover class (from their pass-through) and height class 2. The top is height class 3, but the top and the shelter are different cover classes, so selecting them in debug should show different values. The debug descriptions should be consistent (height class and cover class, all in capitals: the COVER line wasn't), and standardised.
- **The parts** (`watch_tower.gd PART_NAMES`, `part_of()`): **base** (on the ground under the deck), **stairs**, **top** (the deck outside the cabin) and **shelter** (the cabin). Each has an Inspector group (Base / Stairs / Top / Shelter) with its own Height Class and Pass Through. These replace the single `height_class` and the "Cover For Those On It" group.

  | Part | Height class | Pass through | Cover class |
  |---|---|---|---|
  | Base | 3 | 75% | 1 LIGHT |
  | Stairs | 2 | 80% | 1 LIGHT |
  | Top | 3 | 50% | 2 MEDIUM |
  | Shelter | 3 | 30% | 3 HEAVY |

  - A part's cover class always comes from its pass-through (`part_cover_class()`).
  - The legs and stair bodies take their parts' height classes when the tower's ready.
- **Height class at work:**
  - Firing down uses the shooter's part: from the top or shelter it's class 3 (classes 1 and 2 are weakened); from the stairs it's class 2 (only class 1). `fired_down_pass(..., from_height)`, `height_class_of_unit()`.
  - Someone in a tower part is that part's height class to someone firing down on them from higher up (another tower, or this one's top onto its stairs). Their part's pass-through is raised by the shooter's tower's sections (`cover_pass()`).
- **Debug view (Q):**
  - Clicking the shelter, the top or the stairs selects that part, and clicking a leg selects the base. Each shows its own values, "N in it", and (not for the base) firing down from it: each section's pass-through for the classes below its height. The section circles show for those three.
  - Every object panel now goes through one function (`debug_overlay.gd _show_object()`), all in capitals: NAME (KIND), COVER CLASS n NAME, HEIGHT CLASS n, STOPS n% OF SHOTS, then its own lines (a crate: contents, straps, vicinity, ...).
  - The square panel's text is all in capitals too (NO RIFLE, MAGS UNLIMITED, the detail lines).
  - A square in a tower part says which, with its cover and height class.
- Tested on the scratch copy:
  - test_debug_parts.gd: base COVER CLASS 1 LIGHT / HEIGHT CLASS 3 / STOPS 25%; stairs 1 LIGHT / 2 / 20% with class 1 only firing down; top 2 MEDIUM / 3 / 50%; shelter 3 HEAVY / 3 / 70%, 1 IN IT. Sandbags, the desk and a crate all show in the same layout.
  - test_tower_cover.gd: 75 / 80 / 49 / 30% through by part, and 59 of 200 real shots hit someone in the shelter.
  - The height class, exposure, cover, standoff, climb, debug and build tests still pass.
- (The height class test hung once: it still asked for the old tower-wide `height_class`, and a script error in a test leaves it waiting forever. Tests now run with a time limit.)

## 2026-11-01 — Watch tower: the stair's top landing is part of the top

- Mike (screenshot): the top is the deck and the stair's top landing, which is level with it. The landing was counted as stairs.
- `watch_tower.gd part_of()` / `part_at()`: "stairs" is now only the flights and the mid landing (`_on_flights()`: on the stair column, south of the top landing). The top landing is "top": height class 3, 50% through, and that's what clicking it in debug view shows. Routing still treats the landing as the way down (`_on_stair()`), so squadmates' paths are unchanged.
- Tested on the scratch copy (test_part_at.gd):
  - Both ends of the top landing and the deck: top.
  - The top of the upper flight, the mid landing and the lower flight: stairs.
  - The cabin: shelter.
  - The tower cover and debug panel tests still pass.

## 2026-11-01 — Watch tower overlook box

- Mike (screenshot with a box drawn round the tower): add this box, viewable in debug.
  - Inside it, if you're on the upper stairs, the top or in the shelter, any height class 1 or 2 is ignored and the protection comes only from where you are on the tower.
  - At that level enemies start shooting at you because you're in view.
  - The shelter is like being next to a sandbag: if you shoot you're exposed and the enemy starts shooting you.
- `watch_tower.gd`:
  - A new Inspector group **Overlook** with **Box** (`overlook_box`, a Rect2 in metres in the tower's frame, x right / y down from the deck's middle; default x -6..8.5, y -4..9, about Mike's drawing, reaching further on the stair side).
  - `is_up_high()`: the upper flight (between the mid landing and the top), the top, or the shelter.
  - `overlooks()`, `in_full_view(unit, from)`.
- **In full view** (someone up high, seen or shot at from inside the box), height class 1 and 2 cover in between doesn't count:
  - Sight: `ai_soldier.gd _clear_view(..., over_low)`, used by `enemy.gd _check_intruders()` (a calm enemy spots them) and `_look_for_targets()`, and by the standoff's window search.
  - Shots: `cover.gd overlook_past()`, so a bullet fired from inside the box flies on over sandbags and crates toward someone up high it passes within 0.5 m of (`bullet.gd`).
  - The AI's `_shielded()` skips that cover too.
  - So only the tower part protects them: the top 50%, the upper stairs 80% through.
- **Shelter like a sandbag:** seen, but heavy cover (30% through), so an enemy holds fire in a standoff. While its occupant is exposed from firing (`exposed_s`), the new **Shelter > Exposed Pass Through** (60%, light) applies instead, so the enemy takes the window (`cover_pass()`).
- Also fixed:
  - The tower's railings and cabin walls blocked sight (`_clear_view()` hit them), so nobody on the tower could be seen. `tower_walls.gd` now `sees_through()`.
  - A placing ghost tower (command.gd) joined "watch_towers", so squares could step onto it. Only real towers do now.
- Debug view (Q): every tower's overlook box is drawn in green, labelled OVERLOOK.
- Tested on the scratch copy (test_overlook.gd: an enemy and a squadmate with an unbreakable sandbag wall between; 300 real shots per case):

  | Squadmate | Enemy | Spots it | Shielded | Hits / 300 |
  |---|---|---|---|---|
  | On the top | In the box | yes | no | 151 (the top's 50%) |
  | On the top | Outside the box | no | yes | 12 (sandbags x top, about 5%) |
  | On the ground behind the wall | In the box | yes (manning it) | yes | 23 (sandbags' 10%) |
  | In the shelter, quiet | In the box | yes | yes | 30% through |
  | In the shelter, just fired | In the box | | no | 60% through |

  - The ghost isn't in "watch_towers".
  - The height class, exposure, cover, standoff, climb, tower cover, debug, enemy crate and orders tests still pass.

## 2026-11-01 — Debug panel layout

- Mike: format the debug info better. The title bold and larger, everything else smaller but still big, laid out like "COVER CLASS: 3 (Heavy) / HEIGHT CLASS: 3 / PASS THROUGH %: / OBJECT SPECIFIC INFO:".
- `debug_overlay.gd`: the panel is now two labels.
  - The title is bold (a FontVariation, embolden 1.0) at TITLE_FONT_SIZE 22.
  - The body is one label at BODY_FONT_SIZE 17, filled by `_show_panel(title, lines, heading, info, at)`: the "LABEL: value" lines, a gap, then the heading and the info lines indented, in capitals.
- **Objects** (crates, cover, watch tower parts; `_show_object()`):
  - "COVER CLASS: 3 (Heavy)", "HEIGHT CLASS: 2", "PASS THROUGH %: 0" (it was "STOPS n% OF SHOTS").
  - Then OBJECT SPECIFIC INFO:
    - a crate: AMMO CAN: 24 / 24 LEFT, STRAPS: ON, VICINITY: 8.0 M, ...
    - a tower part: UNITS IN IT, and firing down from it, "SECTION 1 (0.0 M - 5.0 M): CLASS 1: 78%, CLASS 2: 50%"
- **Squares:** the title "#4 SQUADMATE4 (SQUAD)", then AMMO: 15 / 30 (with "(EMPTY)" instead of turning red), MAGS: 2 (0 ROUNDS) and STATE: IDLE, then UNIT SPECIFIC INFO.
- Checked in screenshots on the scratch copy (a tower top, a crate, a square), and the debug panel tests run clean.

## 2026-11-01 — Watch tower: upper and lower stairs

- Mike (screenshot with two boxes on the stair): break the stairs into top and bottom stairs.
- `watch_tower.gd`: the "stairs" part is split at the bottom of the mid landing (y 2.0 m):
  - **lower_stairs:** the lower flight, from the ground up to the mid landing.
  - **upper_stairs:** the mid landing and the upper flight, up to the top landing (which stays part of the top).
  - Each has its own Inspector group (Lower Stairs / Upper Stairs) with Height Class and Pass Through, both starting at the old stairs' values (2, 80%). The Stairs group is gone.
  - `_stair_part()` decides it for `part_of()` and `part_at()`.
  - The solid lower flight's body takes the lower stairs' height class.
  - "Up high" for the overlook box is now the upper stairs, the top and the shelter (`is_up_high()`). That's the mid landing too; before, it was only the upper flight.
- Debug view: clicking either flight shows WATCHTOWER (UPPER STAIRS) or (LOWER STAIRS) with its own values. Clicking the solid lower flight from the ground also picks the lower stairs.
- Tested on the scratch copy:
  - test_part_at.gd: the top landing and deck are top. The top of the upper flight, the mid landing and its bottom edge are upper stairs. The top of the lower flight and the lower flight are lower stairs.
  - The debug parts, tower cover (79 / 81% through on the upper / lower stairs), overlook and climb tests still pass.

## 2026-11-01 — Debug panels show PROTECTION % instead of PASS THROUGH %

- Mike: debug's Pass Through makes more sense as protection %.
- `debug_overlay.gd`: object panels read "PROTECTION %: n", the share of shots it stops (100 minus pass-through): sandbags 90, the desk 30, a tower's top 50, its shelter 70.
- A tower part's firing-down lines are now "protection of cover below class n", e.g. section 1 class 1 22% (78% got through).
- The Inspector settings are unchanged: still the pass-through %.

## 2026-11-01 — Radio station on a watch tower

- Mike (two screenshots: the desk along the shelter's north wall, the dish on the roof): placing the comms desk over the watch tower puts it on the tower, the desk and dish as green ghosts. You then build it as with the comms kit, but on the tower.
- **Placing** (`command.gd`): with Radio station chosen from DEPLOY, the mouse over a built tower's top or shelter that has no station yet snaps it onto the tower (`_layout()`: `watch_tower.gd station_spot()`, with `mount`).
  - The ghost is laid out mounted (`_make_ghost(mount)`, rebuilt as it moves on or off a tower) and drawn over the roof, so you can see where the desk goes.
  - Placing it calls `mount_on()` and sets the tower's `station`. One per tower (`can_mount_station()`).
- **Mounted layout** (`radio_station.gd mount_on()`): the station sits at the tower's STATION_AT (0.75, -0.28 m: on the deck by the shelter's door), turned STATION_TURN (-90°).
  - **Desk:** along the shelter's north wall (centre -0.3, -0.93 m), the operator's spot in the shelter in front of it. Drawn with the deck, under the squares and under the roof while nobody's in.
  - **Dish and stand:** moved MOUNT_DISH_SHIFT_M up onto the roof (0.2, 0.3 m), drawn over the roof. `DISH_AT` became the variable `dish_at`.
  - **Hidden:** the ground cable and the desk's ground shadows (the wiring is still a part to deliver).
  - **Collisions:** the desk is solid only to squares up on the tower (WALL_LAYER) and lets every shot by. The dish isn't solid.
  - **Who it notices:** the operator's spot and the dish's ring only notice squares up on the tower. The dish is tuned from the top, outside the shelter (`_player_at_dish()`), so in the shelter F is always the radio.
  - The F prompts are raised over the deck and roof.
- **Building:**
  - `can_deliver_at(at, who)` (every build site now takes the deliverer; player.gd and squadmate.gd pass themselves). A mounted station only takes parts from someone up on its tower, so you can't hand them up from under the deck.
  - `deliver_spot()` is its origin on the deck, so squadmates take the stairs.
- **Squares on the tower now pass through each other** (`soldier.gd _set_tower()`: mask WALL_LAYER only). Two squadmates building, one going up the stair and one coming down, jammed head-on: the stair is 0.74 m clear and two squares need 0.8.
- **Squadmates on the tower** (`ai_soldier.gd _tower_step()`):
  - Up there they walk straight at each route step, sliding along the railings. `_avoid_obstacles()`' 0.6 m clearance circle kept swerving at the stair's sides.
  - One idle on the stairs goes up onto the deck (`watch_tower.gd on_stairs()`, `deck_in()`).
  - Going up from the ground, they only head into the foot once lined up in front of it (route()); from beside it they go round to FOOT_OUT first.
- Tested on the scratch copy:
  - test_tower_radio.gd:
    - Over the tower the layout snaps (0.75, -0.28 m, -90°), and off it, it doesn't. The ghost is mounted.
    - Placed, the desk is at (-0.3, -0.93), the operator's spot at (-0.3, 0.02), the dish at (0.2, 0.3) on the roof. No second station can mount.
    - Can't deliver from under the deck. From up on the tower all 5 parts go in.
    - In the shelter F is the radio. On the top walkway F is the dish. From the ground under it, neither.
  - test_tower_radio_squad.gd: two squadmates built it in 19 s.
  - Screenshots show the ghost, the half-built site, and the built station with a squadmate at the desk (roof open) and the dish on the roof.
  - The closest-F, unlock-crate, orders, tower build, ammo can, menu, overlook, climb and stair tests still pass.

## 2026-11-01 — Tower radio: desk by the west wall, an obvious door, the dish from the radio

- Mike (screenshot): the desk was where the door opening is, so make the door more obvious in the model; put the desk where his snippet shows; when someone's in the shelter, make the dish see-through with the roof; no more interacting with the dish, instead the computer gets a Dish option that controls it.
- **The door** (`watch_tower.py`, all parts re-rendered):
  - The shelter's east wall now has a real opening (DOOR_Y) with dark steel posts, a head and a lintel, and a yellow threshold. The door (light tan) stands open inward along the north wall.
  - On the deck in front there's a black mat edged in yellow (in the platform part), so the doorway shows with the roof on too.
- **The desk:** mounted stations now sit at STATION_AT (-0.22, -1.38 m) turned STATION_TURN PI. That puts the desk north-south along the shelter's west wall (centre -0.87, -0.33 m, as Mike drew it), the operator's spot east of it (0.08, -0.33), and the dish still at (0.2, 0.3) on the roof (MOUNT_DISH_SHIFT_M (-0.42, -2.78)).
  - The deliver F shows over the desk.
  - Squadmates bring parts to the shelter's door (`deliver_spot()`: `watch_tower.gd door_out()`), since the station's origin is now on the deck's north edge, which they can't reach.
- **Dish fades with the roof:** `watch_tower.gd` passes the roof's alpha to `radio_station.gd fade_dish()`. The dish and its stand fade, and their shadows go while see-through (the dish's is a shader a fade doesn't reach).
- **The dish is aimed from the radio** (every station, on a tower or on the ground):
  - The RADIO menu has a **Dish** button (`radio_terminal.gd _on_dish()`): the menu goes and the aiming wheel opens round the dish (`radio_station.gd start_tuning()`). F or a left click locks the heading in. Stepping away from the desk or Space closes it.
  - There's no F at the dish any more (`interact_point()` gives null, the dish's green F never shows).
- Tested on the scratch copy:
  - test_tower_radio.gd: the desk at (-0.87, -0.33) and the operator's spot at (0.08, -0.33). The deliver spot is the door, on the tower. The radio opens at the desk.
  - Dish from the menu opens the wheel with the menu gone and the player busy. F locks the heading (0.30) and frees the player. Walking away closes it.
  - Outside, F does nothing at the dish. Parts can't be delivered from under the deck.
  - test_tower_radio_squad.gd: two squadmates built it in 27 s.
  - A screenshot shows the desk on the west wall with a squadmate at it, the door's mat and threshold, and the dish faded with no shadow.
  - The closest-F, menu, unlock-crate, climb, overlook and tower tests still pass.

## 2026-11-01 — Tower door: white, no black mat

- Mike: for the door, get rid of the black and change the yellow to white.
- `watch_tower.py`: the black mat on the deck in front of the shelter's door is gone. Its edging is now white lines framing the doorway on the grating, and the threshold in the doorway is white too. All parts re-rendered. Checked in a screenshot on the scratch copy.

## 2026-11-01 — Watch tower Inspector: start with a radio station

- Mike asked for an Inspector item on the watch tower for the radio version.
- `watch_tower.gd`: a new Inspector group **Radio** (prefix `radio_`):
  - **Has Station** (`radio_has_station`, off by default): at the start a built tower is fitted with a radio station as if placed from DEPLOY (`_fit_radio()`, deferred so the level's crates are in): mounted (`radio_station.gd mount_on()`), at `station_spot()`, named "<tower>Radio".
  - **Built** (`radio_built`, on): unticked, the station starts as a site built from the nearest comms crate that can set one up. With no such crate it starts built, with a warning in the output.
- Tested on the scratch copy (test_tower_radio_export.gd):
  - Has Station: a built, mounted station, desk at (-0.87, -0.33).
  - Has Station with Built off: a site from CommsCrate.
  - Neither: no station.

## 2026-11-01 — Tower shelter: 100% protection, no firing out of it

- Mike: make the shelter's protection 100%, but you can't shoot out of it.
- `watch_tower.gd`: `shelter_pass_through` now defaults to 0 (PROTECTION 100%, cover class 3). `shelter_exposed_pass_through` is gone, along with the "firing from the shelter exposes you" rule, since nobody can fire from it now.
- `soldier.gd _sheltered()`: a square in a watch tower's shelter doesn't fire. The player's trigger does nothing, and the AI holds its shots.
- Tested on the scratch copy (test_shelter_fire.gd):
  - A squadmate told to attack an enemy 6 m out fired 0 shots in 4 s from the shelter, and 4 from the top.
  - Shots at it get through 0% in the shelter and 50% on the top.
  - The overlook, tower cover and debug panel tests show the shelter at 0% through, PROTECTION 100, cover class 3.

## 2026-11-01 — Watch tower stair: no catch at the foot going down

- Mike (screenshot): a little bump at the bottom of the stair hung his square up going down.
- Two causes, both in `watch_tower.gd`:
  - **A lip.** The flared guides at the stair's foot started 6 cm inside the stair's sides, so a square sliding down against a side met that lip. The sides now taper in over half a metre (3.3 to 3.75 m) before flaring out, so going down slides past and coming up off the middle is still guided in.
  - **Snagging box ends.** The railings and walls were thin boxes stretched a little past their ends, and where two met, a box's end corner poked out and caught a square's corner (found at (1.89, 3.53) against the guide's end). They're now line segments (SegmentShape2D, `_make_walls()`), with nothing to catch on; WALL_THICK_M is gone.
- Tested on the scratch copy:
  - test_stair_down.gd: walking down from the mid landing pressed into either side, or down the middle, takes 2.2 s each, never below 0.89 m/s. Before, hugging a side took 4.5 s with a full stop.
  - test_stair_seam.gd: up from 5 points across the foot, all the way to the top, never under the stair.
  - The climb test (railings stop you at 1.20 m now that they're lines), squadmate climb (11 s up, was 17.5) and tower radio build tests pass.

## 2026-11-01 — Squadmates under ORDERS; radio command camera, Deploy, Back and Exit

- Mike asked for four things:
  - In command mode the camera shouldn't move with his squares, and he has full control of the zoom.
  - Deploy, and Back to the menu, in radio command mode, like the player's command menu.
  - An Exit button on the RADIO menu.
  - Squadmates in his command circle or selected go to an ORDERS state: no surprise, no ammo, no automatic change from idle. Only Disperse breaks it, leaving them on their own (even in the circle or selected) until the next order.
- **ORDERS** (`squadmate.gd`):
  - `under_orders` latches on once a squadmate is in the player's command circle (`aura_radius_m`) or selected (`_update_orders()`, each tick), or is given any order (`_take_orders()`, in every order_*()).
  - Under orders:
    - Surprised, it shoots back from where it is but doesn't run for cover (`_surprise()`).
    - It never goes for ammo, even out (`_may_fetch_ammo()`, a new hook in ai_soldier.gd `_ammo_run()`).
    - It isn't pinned (`_check_pinned()`).
    - It doesn't shuffle when idle, only glances about (`_tick_idle()`).
  - **Disperse** (command.gd) now calls `order_disperse()`: it walks out as before and is then `on_own`. Not under orders, it's free to react, take cover and fetch ammo, even in the circle or selected, until its next order.
  - Debug view shows an idle squadmate under orders as **ORDERS**. The battle log has `orders` and `own` keys.
- **Camera** (`game_camera.gd`): radio command's overview frames the player and squad once going in (never closer than you had it), then stays put. It doesn't follow or re-fit as they move. The wheel zooms normally, and holding the wheel button and dragging pans (as in debug mode). Hanging up eases back to your zoom on the player. `_overview_scale` is gone.
- **Radio command menus** (`command.gd`):
  - DEPLOY now shows over the radio too. Placing works there (crate-built things anywhere; carried equipment still within your own reach).
  - Under it there's a **Back** button that hangs up and reopens the station's RADIO menu (`_back_to_radio()`).
- **RADIO menu** (`radio_terminal.gd`): an **Exit** button closes it.
- Tested on the scratch copy:
  - test_orders_state.gd:
    - A squadmate near the player is under orders; one 20 m off isn't.
    - Fired at, the one under orders stays IDLE (ORDERS) shooting back; the free one goes SURPRISED.
    - Out of ammo under orders, it doesn't move or go for ammo.
    - Dispersed and then selected, it's on its own and goes for ammo.
    - Given Follow me, it's under orders again.
  - test_radio_cam.gd:
    - In radio command, the camera stayed within 2 px while the squad moved 9 m.
    - Two wheel notches took the zoom from 1.00 to 1.32.
    - Back and DEPLOY show, and placing works.
    - Back leaves radio command with the RADIO menu open. Exit closes it and frees the player.
  - The orders, closest-F, menu, standoff, cover, exposure, ammo can, crate, tower radio and debug tests still pass.

## 2026-11-01 — Sandbag dig-in squares: none under things, drawn as separate squares

- Mike (screenshots: a sandbag row along a watch tower's stair, the stair-side boxes crossed out; separate boxes per wall): if there's an object on top of a dig-in square, disable it. Change the ghost for the dig-in squares to match his example: on the ground, the bags on top.
- `sandbags.gd`:
  - **Drawing** (`_draw_zone()`): each wall draws a dig-in square each side, the wall's length less ZONE_GAP_PX (6 px) out to `zone_depth_m`, on the ground under the bags. A row reads as separate squares (it was one 1 m box per wall over 0.8 m spacing, so neighbours overlapped and their edges doubled up). Redrawn in command mode, and as a placing ghost moves.
  - `side_open(side)` / `spot_open(spot)`: a side is closed when a watch tower is over its dig-in spot (COVER_SPOT_M out: its deck or stairs, `on_surface()`), or something solid is on it (a 0.2 m circle on layer 1: a crate, a station, a helicopter, a tower's legs; not squares). Closed sides aren't drawn.
- Nobody digs in on a closed side: command.gd `_man_sandbags()` skips those spots (anyone left over lines up behind the row as before), squadmate.gd `_free_cover_spot()` skips them, and so does enemy.gd `_take_cover()`. The proximity box itself (`in_zone()`, firing over the wall) is unchanged.
- Tested on the scratch copy:
  - Nine walls along a tower's stair: the stair side is closed on the eight under the stair and open on the last, past its foot. The far side is open on all.
  - A screenshot shows separate squares, none on the stair side.
  - test_digin_order.gd: manning the far side fills three spots in a row. Manning the stair side sends one to the only open spot and the rest line up behind.
  - The orders, standoff, exposure, enemy crate and overlook tests still pass.

## 2026-11-01 — Dish aiming: X goes back to the RADIO menu

- Mike: when in dish mode, add a press X to go back, to the main menu.
- `world.gd`: a new control, "back" (X).
- `radio_station.gd`: while the aiming wheel is open, X closes it without changing the heading and reopens the station's RADIO menu (the player stays at the menu). The wheel shows "[X] BACK" under its S mark.
- Tested on the scratch copy (test_dish_back.gd): Dish from the menu, then X: the wheel's closed, the RADIO menu is open, the heading is unchanged, and the player is still at the menu.

## 2026-11-02 — Placing equipment: X goes back to the menu

- Mike: same as the dish's X, when placing.
- `command.gd`: while placing from DEPLOY, X (the "back" control) cancels it and keeps the command menu open even with Space let go (`World.menu_held`, which `World.commanding()` now counts). You're back at ORDERS / DEPLOY to pick again.
  - The menu closes on X again, on Space, or once an order's carried out. For Fire and Attention that's after their click.
  - Over the radio the menu's open anyway.
  - The placing banner says "[X] back to the menu", and the held menu's banner "[X] close".
- Tested on the scratch copy (test_place_back.gd):
  - Placing sandbags, X: placing ends with the menu still showing ("[X] close").
  - X again: command mode closes.
  - Backing out and then giving Follow me also closes it.

## 2026-11-02 — Watch tower: stairs fade from under them, dust under them, squadmates in and out

- Mike asked for three things:
  - Make the upper stairs see-through when under them.
  - When shooting from under the tower, sandbag dust should be under the upper stairs.
  - Fix squadmates going in and out of the tower: his log (07:10) had one sitting in the shelter get stuck.
- **The log:**
  - Squadmate 8 was in the shelter (16.66, 15.26). At 2.78 s it was sent to the sandbags at (19.04, 20.94) on the ground.
  - It walked out of the door and stopped for good at (18.40, 14.84). In the tower's frame that's (1.53, -0.78), on the top landing beside the deck.
  - `route()` counted anywhere past the deck's edge as "on the stair" and sent it straight down to the foot. From the side of the landing that line runs into the corner where the stair's side starts, and up there squadmates walk straight at each step (no swerving), so it pushed into the corner for ever.
- **Squadmates in and out** (`watch_tower.gd route()`, `leave_way()`; `ai_soldier.gd`):
  - On the top landing off to one side, a squadmate going down steps to its middle (TOP_IN, lined up with the flights) before heading down.
  - **Stepping straight back on.** Testing found another catch: one coming down for anywhere but straight south stepped off, turned north for its goal through the stair's foot, and that counted as walking up into it, so it stepped back on, over and over. AI squares now only step onto a tower they're headed up (`soldier.gd _wants_onto()`; ai_soldier.gd: the tower its route is to). The player is unchanged. Enemies no longer step on by accident.
  - Just off the stair with a goal back past it (north), a squadmate goes round the side of the stair nearest its goal first (`leave_way()`): straight there walks into the solid lower flight. Coming up from beside the stair, it goes round to the front the same way (ROUND_STAIR_M).
  - On the east walkway it keeps to the middle rather than cutting along the shelter's wall (`_deck_step()`).
  - On a route step on the ground it gets the usual "getting nowhere, try the other way round" nudge, without ever giving up. Off the route, its progress check starts afresh (it was carrying the waypoint's distances over and giving up early).
- **Stairs fade:** while the player's on the ground under the top landing, upper flight or mid landing (UPPER_STAIRS_ABOVE), the stairs fade to UNDER_ALPHA like the deck.
- **Dust:** `hit_dust.gd tuck_under_towers()` draws dust off something on the ground (a sandbag wall, the dirt) at z 3, under a tower's stairs and deck and over the squares, when it's under them or within 0.4 m (the wall beside the stair). Sandbags and ground hits call it; dust off a square doesn't.
- Tested on the scratch copy:
  - test_tower_ways.gd (tower at Mike's spot, radio fitted): from 7 spots on the tower (the log's spot in the shelter, beside the desk, deck corner and walkway, both ends of the top landing, the upper flight) to 3 ground goals (the log's, west, north), and from 4 ground spots up to the deck and into the shelter. All 27 arrive.
  - test_stairs_fade_dust.gd: the stairs at 0.35 under the upper flight and top landing, 1.0 beside the lower flight and in the open. Dust off the wall beside the stair at z 3; off a wall in the open, z 15.
  - The climb, stair seam, stair down, squadmate climb, tower radio build, orders, overlook and cover tests still pass.

## 2026-11-02 — Log 08:15: stuck by the stair foot; closed dig-in squares weren't closed to clicks

- **The log:**
  - At 3.38 s squadmate 10 was sent to dig in at the sandbag wall at (19.04, 20.14), on its west side. That's just in front of the watch tower's stair foot (tower frame (2.19, 4.5)).
  - It walked over, ended up east of the wall at about (19.75, 20.75), and jittered there to the end of the log.
  - The cause was `watch_tower.gd leave_way()` (added this morning). It sent anyone near the foot with a goal north of it round the stair's side, this goal included, though it needs no detour. It went round the east side past the wall, turned back for the spot, came near the foot, and was sent round again.
  - (Also at 0.72 s the player's one shot hit squadmate 10: friendly fire.)
- `leave_way()` now only detours when the straight way to the goal runs into the stair's solid lower flight (STAIR_SOLID, `_crosses()`). That applies anywhere on the ground, not just near the foot. It goes round the front of the foot: to the corner on its own side when beside or behind the stair, or to the goal's side once out in front.
- **Mike (screenshot):** dig-in squares under the stair were still taking dig-in orders. A closed side was only skipped when spots were handed out; a click there still found the wall.
  - `command.gd _sandbags_at()` and `squadmate.gd _cover_at()` now only count a wall's box on an open side (`spot_open()`). A click on the stair beside the wall is a plain move, onto the stair.
- Tested on the scratch copy (the tower and wall as in Mike's level):
  - test_log_digin_foot.gd: sent to that spot from the log's start, from the east and from the west of the tower, all three dig in there in 3.5-6 s. From the west it used to get squeezed between the stair and the wall.
  - test_closed_click.gd: a click on the upper or lower stair beside the wall walks the squadmate up onto the stair, not digging in. A click on the wall's open east side digs in.
  - test_tower_ways.gd: 27 of 27 arrive.
  - The orders, standoff, squadmate climb, tower radio and enemy crate tests still pass.

## 2026-11-02 — Stair foot: no invisible curve going down; the tower's missing railings

- **Mike (screenshot):** coming down the stair and turning off it, his square followed an invisible curve at the end of the ramp.
  - The cause: a square stayed "on the tower" until 4.9 m out (FOOT_OFF_Y), well past the bottom step (4.1). Until then it bumped into the foot's flared guides (the walls that funnel anyone coming up into the stair), so turning down-left or down-right slid it along the flare.
  - `watch_tower.gd steps_off()` now takes the square's velocity: walking down (south) it's off as soon as it's clear of the bottom step (FOOT_CLEAR_Y, 4.35 m: the step plus half a square and a little). Otherwise it's still FOOT_OFF_Y, so one that's just stepped on walking up isn't put straight off again. `soldier.gd _update_tower()` passes its velocity.
- **Mike (screenshot):** three open edges on the model had no railing. `blender/scripts/watch_tower.py build_stairs()` now rails:
  - the top landing's west side, where it sticks out past the deck's north edge;
  - the top landing's south edge between the deck and the upper flight's handrail;
  - the mid landing's west side.
  - Also taken out: a rail straight across the stairway at the mid landing's south edge, where the lower flight starts down.
  - The game's walls already blocked all three edges (WALLS), so only the art changed. All five parts re-rendered (the parts' shadows fall on each other).
- Tested on the scratch copy:
  - test_foot_turn.gd: down the stair, then down-left or down-right off the bottom step. Before: 0.36 m sideways in the first 0.7 m down, off the tower at 4.92. After: 0.68 m (a free diagonal), off at 4.36. Up from the middle and either edge of the foot still gets on (4.73) and up to the top landing; stepping off and straight back up gets back on.
  - test_stair_down.gd (1.9 s down, never under 0.89 m/s), test_stair_seam.gd (never under the stair), test_tower_climb.gd, test_tower_squad_climb.gd, test_tower_ways.gd (all OK), test_log_digin_foot.gd and test_tower_squad.gd still pass.
- **Mike (screenshot), later:** a bump in the stair's sides near the foot. That was the walls' taper: the sides angled in 6 cm from 3.3 to 3.75 m before the flares, a fix for the old box walls' corners. With line walls there's nothing to catch on, so the sides (WALLS) now run straight to the bottom step (4.1) and flare out from there. test_stair_down.gd (hugging either side, 1.9 s, never under 0.89 m/s), test_foot_turn.gd, test_stair_seam.gd, test_log_digin_foot.gd, test_tower_squad_climb.gd and test_tower_ways.gd all still pass.
- **Mike, later:** "a small space I go behind when getting on the ramp". Coming at the foot slantwise from beside it (from the south-west going up-right, or the south-east going up-left), the square stepped on (FOOT_ON) while partly outside a flared guide. Up on the tower it was then outside the stair's side wall, and walked up beside the stair as if on the deck (height 3, drawn big). `steps_on()` now also needs the square wholly between the guides (`_in_funnel()`: the stair's width, widening FLARE_PER_M each side per metre past the bottom step). One that isn't keeps walking on the ground, slides off the stringer's end and steps on once it's inside.
  - test_foot_gap.gd: 39 approaches (13 starts in front of and beside the foot, walking up, up-left and up-right). Before: 2 ended up on the tower outside the wall. After: none. (Two runs slide up the stair's outside on the ground with its side just touching, at 1.60: that's beside it, not under.)
  - test_foot_turn.gd, test_stair_seam.gd, test_stair_down.gd, test_log_digin_foot.gd, test_tower_squad_climb.gd and test_tower_ways.gd (27 of 27) still pass.

## 2026-11-02 — Hugging the lower stair; a triangle to fold the command menus; one squadmate to unstrap a crate

- **Mike (screenshot):** a bump out on the ground beside the stair's lower flight, where he expected to walk smoothly along it.
  - The stair's ground collision (`watch_tower.tscn` StairsBody) is the lower flight's box plus a thin stringer box each side of the foot. The stringers stuck out past the flight's sides (west by 4.6 px, east by 3.6 px). Walking south along a side stopped dead on the stringer's end; walking north jogged out.
  - FootWest and FootEast moved in (x 135 → 139.59, 206 → 202.41) so their outer faces are flush with the flight's.
  - test_stair_hug.gd (on the ground, pressed into either side, both ways): before, south stopped at 0 m/s at the foot; after, a steady 1.58 m/s, 0.0 cm side to side, all four. test_foot_gap.gd, test_stair_seam.gd, test_log_digin_foot.gd and test_tower_ways.gd (27 of 27) still pass.
- **Mike:** a little triangle beside the player in command mode that shows and hides the menu.
  - `command.gd`: `_menu_toggle`, a small button in the menus' style, TOGGLE_GAP_PX left of the player's square, inside MENU_GAP_PX, so it never overlaps ORDERS. Clicking it folds ORDERS and DEPLOY away (closing any pop-out) and back. It points toward the menus' side while they're hidden and back toward the player while they're shown. `_menus_open` keeps the state from one go in command mode to the next.
- **Mike:** a click on a crate to undo its straps should send only one of the selected.
  - `command.gd _click()`: for a strapped crate with nothing to build, only the selected squadmate nearest it goes. A crate owing parts (or taking over another's) still sends them all, to carry.
- Tested on the scratch copy:
  - test_menu_toggle_crate.gd: commanding, the triangle shows 5 px left of the square, centred, with ORDERS 5 px left of it. A click hides ORDERS and DEPLOY; out and back into command mode they're still hidden; another click shows them. Three selected, a click on a strapped sandbag crate: only the nearest (2.4 m) goes, BUILD; the straps are off 2.6 s later; the other two stay put.
  - test_can_crate_click.gd, test_click_orders.gd, test_closed_click.gd and test_place_back.gd still pass.

## 2026-11-02 — Watch tower crate in the helicopter drop

- **Mike:** add the watch tower crate to the helicopter drop-off.
- `radio_terminal.gd EQUIPMENT_TYPES`: a fourth choice, "Watch tower crate" (`tower`: scenes/crate_tower.tscn, its load's sprite for the drop-zone ghost). It's on the standard pallet, so the drop's spacing and clear-spot check fit it as they are.
- `_draw_crate()` draws its icon for the slot and pop-out like its load: steel tubes across the top, the deck grating and a stair flight, then the cream roof panels and the white air conditioner, under the straps (TOWER_* colours, from watch_tower.py).
- Tested on the scratch copy (test_tower_drop.gd): the choices are Ammo, Sandbag, Comms and Watch tower crate. The icon draws without errors. Dropped with an ammo crate, both come down by parachute in line; the TowerCrate lands strapped, building a watch tower, with its five parts.

## 2026-11-02 — Unstrapping crate after crate; build walks don't get stuck; squares over the stair's foot

- **Mike:** with the whole squad in the circle, a click on a strapped crate sends one; if that one's busy undoing straps, the next click sends the next nearest, and so on.
  - `squadmate.gd unstrapping()`: the crate it was sent just to unstrap (strapped, nothing owed), while it's on its way or at it.
  - `command.gd _click()`: for a strapped crate with nothing to build, the nearest of the selection (or of everyone in the circle) that isn't already unstrapping another goes. A crate someone's already on gets nobody new (a ping). With everyone busy, a red ping (REFUSE_COLOR) and nobody goes.
- **Found while testing it: build walks never got unstuck.** `_tick_build()` walks with `_head_for()`, which never ran the "getting nowhere, try the other way round" check that every other walk has. A squadmate going to a crate in a dropped row (1.6 m apart) jammed on the next crate's pallet corner and pushed there for good. `_watch_build_progress()` now runs `_is_stuck()` on the way to a crate or a site (never giving up), restarting the watch when where it's going changes (`_build_goal`).
- **Noticed, not changed:** a crate on the ground under a watch tower's deck or top landing counts as up on the tower to the AI (`ai_soldier.gd _tower_way()` → `on_surface()`), so a squadmate sent to it heads up the stairs. A drop can land a crate there (only solid things block a drop spot). Worth a ground-only flag on build walks if it comes up.
- **Mike (screenshot):** a rail end drawn on top of his square at the stair's foot. Squares on the ground were always under the stairs (z 0 against 4), but down by the foot the rails are below head height. `watch_tower.gd FOOT_OVER` (within a turned square's reach either side of the lower flight, from 3.0 m, where it's under 0.8 m up, out past the foot): a square on the ground there is drawn at GROUND_OVER_FOOT_Z (5), over the stairs (`soldier.gd _update_tower()`, `by_foot()`). Everything else on the ground is under 0, so only the stairs change places with it.
- Tested on the scratch copy:
  - test_unstrap_next.gd (crates clear of the level's tower): clicks on crates 1, 2, 1 again, 3, 4, 5 with 4 in the circle and nobody selected send one each to 1-4, nobody new to 1 the second time, and a red ping for 5. All four sets of straps off in 16.2 s (before the stuck check: one never got there in 30 s). Once they're free, a click on 5 sends the nearest.
  - test_foot_z.gd: z 5 beside the foot either side and in front; 0 beside the flight higher up, under the deck and in the open; 6 up on the stair; walking north beside the flight drops back to 0.
  - test_tower_squad.gd, test_tower_radio_squad.gd, test_can_crate_click.gd, test_build_beside.gd, test_menu_toggle_crate.gd, and the stair tests (hug, foot gap, seam, foot turn) still pass. test_ammo_can.gd's mate 2 doesn't fetch ammo, the same with the committed code: it's at Attention, under orders, so it doesn't go (the ORDERS rule); the test predates that.

## 2026-11-02 — Places to stand on the watch tower; dust always under the stairs

- **Mike (screenshot):** dust off a shot sandbag clouded over the lower flight. Dust off ground-level things only went under the stairs within 0.4 m of the tower; his wall's a little further out, and the dust drifts. `hit_dust.gd tuck_under_towers()` now always draws it low (UNDER_TOWER_Z 3: over the squares on the ground, under the stairs, deck and anyone up there). UNDER_TOWER_SLACK_M is gone.
- **Mike (screenshot, blue and yellow):** squadmates sent onto the ramp went to the top. Only some places up there are for standing: the top landing, the east walkway from its north end past the door, the south walkway and the mid landing (and the shelter). Sent to a flight or the east walkway between the door and the shelter's south-east corner, a squadmate goes to the nearest of those.
  - `watch_tower.gd STAY_AREAS`, `stay_spots()`: the nearest place to stand, on the stair only its landings and on the deck only its walkways, never across a railing; the shelter only for a spot in it. Several sent together fill it on a STAY_PITCH_M (0.45 m) grid, nearest the click first, then the next nearest place. `can_stay()`, `on_stair_at()`.
  - `command.gd _send_in_line()`: a spot on a built tower sends them to `stay_spots()`, the nearest squadmate to each.
  - **Why they went to the top:** `squadmate.gd` sent anyone idle anywhere on the stairs up onto the deck "out of the way" (the mid landing too). Now one idle anywhere that isn't a place to stand walks to the nearest that is; on one, it stays.
  - Also `ai_soldier.gd _walk_to()`: on a tower's stair the last stretch to the spot is straight at it, as the route's steps are. Steering round the stair's railings turned it back up the flight, and it gave up there. On the deck it still steers, round the shelter's corners.
- Tested on the scratch copy (test_tower_stay.gd, the level's tower and its wall):
  - One squadmate sent to each place: lower flight near the foot and middle → mid landing; mid landing → stays; upper flight middle → mid landing (nearer); upper flight near the top → top landing; top landing, east walkway by the door, south walkway and the shelter → stay; east walkway past the door → by the door.
  - Three together: south walkway → spread along it (0.7 m apart); lower flight → two on the mid landing, one on the top landing; top landing → all three there.
  - Dust off a wall 1.2 m from the stair: z 3, under the stairs (4).
  - test_tower_ways.gd (27 of 27), test_tower_squad_climb.gd, test_tower_radio_squad.gd, test_log_digin_foot.gd and test_closed_click.gd still pass.

## 2026-11-02 — Menu triangle size, out-of-ammo sign, sending squadmates to an ammo can, tower dish and notch

- **Menu triangle size in the Inspector:** `command.gd menu_toggle_px` (the Command node in main.tscn: Menu Toggle Px, 12-80 px, default 26). Applied every frame, so it shows while running. Bigger than fits in the gap beside the player, the menus move out to stay TOGGLE_GAP_PX clear of it. TOGGLE_PX is gone.
- **Out-of-ammo sign** (Mike's drawing): while commanding, a squadmate that's out (`ai_soldier.gd is_out_of_ammo()`) gets a red "no" sign with a curved magazine in it over its upper right (`command.gd _draw_no_ammo()`, NO_AMMO_*). Drawn in the world, so it scales with the zoom. Not shown outside command mode.
- **Sending squadmates to an ammo can:** a click on a built ammo can in command mode sends the selection (nobody selected: everyone in the circle) with room in their spares to load from it (`command.gd _ammo_can_at()`, AMMO_CAN_PICK_M; nobody with room: a red ping).
  - `squadmate.gd order_load_ammo()`, `_tick_sent_ammo()`: it walks there (state MOVE, so its line shows), claims the can and loads (`ammo_supply.gd work_load()`) until its spares are full or the can's empty, reloads if its rifle's empty, and stands there. The can serves one at a time: the rest wait AMMO_WAIT_M off and go in turn. Any other order ends the trip (`_take_orders()`). Under orders it still never goes for ammo by itself.
- **Dish on a watch tower:** its stand's legs cast no shadow up there (`radio_station.gd MOUNTED_HIDDEN` + ShadowStand); it spilled off the roof across the deck. The dish's own shadow stays.
- **The notch over the player** at the deck's north-east corner was the power box on the north-east leg, modelled in the tower's details (drawn over everything). It and its conduit are now in the base (`watch_tower.py`: Base_Conduit, Base_PowerBox), drawn under the squares like the leg. All five parts re-rendered.
- Tested on the scratch copy:
  - test_ammo_order.gd: the triangle 26 px, then 40 px set live, ORDERS 5 px clear of it. Two squadmates out of ammo; the sign draws (no errors). A click on the can: both go; the first loads its spares to 30 and 30 and reloads (8.3 s); the second waits 0.77 m off, then loads 30 and 30 (15.1 s); both stand down. A tower-mounted station: stand shadow hidden, dish shadow shown; one on the ground keeps its stand shadow.
  - The re-rendered parts: the box is in watch_tower_base.png, gone from watch_tower_details.png.
  - test_menu_toggle_crate.gd, test_unstrap_next.gd, test_click_orders.gd, test_can_crate_click.gd and test_tower_radio.gd still pass.

## 2026-11-02 — Height profiles: Shots Away and Shots Into replace the sections and the overlook box

- **Mike:** anything you can stand on gets a Shots Away parent (sections; in each, a pass-through % per height class: firing from there past lower cover) and a Shots Into parent (the same, by how far the cover in between is from it, for shooting at someone standing there, plus whether that cover hides them: seen yes or no). The watch tower needs both for each part. His rules:
  - Cover as high as or higher than where you stand is just cover (the sections only count for lower cover).
  - Your own sandbag wall works as before (firing over it, exposed when you do).
  - Seeing is yes/no, in Shots Into.
  - No exposure setting for being up high: Seen covers it.
  - Only the tower has height for now (units don't stand on crates, only their pallets; sandbags as they are). More height assets will come; this is the engine.
  - Enemies going up a nearby tower: a later step.
- **The engine:** three resources, with class names so the Inspector's "+" offers the right kind:
  - `scripts/shot_section.gd` (ShotSection): Radius M, Class 1/2/3 Pass Through. The last section reaches as far as a bullet goes (its radius doesn't count).
  - `scripts/shot_into_section.gd` (ShotIntoSection): the same plus Class 1/2/3 Seen.
  - `scripts/height_profile.gd` (HeightProfile): Height Class, Pass Through (the place itself), Shots Away and Shots Into lists. Saved as files (`assets/height_profiles/`), so things of a kind can share one; Make Unique for one of its own.
- **Watch tower:** the Inspector's Height Profiles group: Lower Stairs, Upper Stairs, Top, Shelter, each a profile (`watch_tower_<part>.tres`). The Base keeps its height class and pass-through (it's the ground). The Section 1-3 groups, the Overlook box and the per-part height class / pass-through groups are gone. Each part's profile counts all over it (flat: no more ramping up the stairs with height). The shelter's Shots Away is empty (nobody fires out of it).
  - Starting values: the top's Shots Away are the old sections (78/50, 55/25, 33/10 for class 1/2 at 5 m, 10 m, beyond). The stairs' are lower (upper 60/45/30, lower 30/20/15, class 1 only). Shots Into, made gradual from the overlook box: the top and shelter 100/100 seen within 5 m, 80/50 seen to 10 m, then 40 seen / 20 hidden; the upper stairs 90/60/30 class 1 seen; the lower stairs 50 seen, 30 hidden, 15 hidden.
- `cover.gd`: `profile_of()`, `away_pass()`, `into_pass()`, `height_pass()` (the more of both ends), `height_extra()` (a bullet's roll after the cover's own), `seen_past()`, `shot_target()` (who a bullet's at: the nearest square standing somewhere with a profile ahead on its line). `fired_down_extra()`, `in_full_view()` and `overlook_past()` are gone. `watch_tower.gd`: `profile_for()`, `profile_of()`; `cover_pass()` uses the shooter's Shots Away for the part's height class. `bullet.gd _height_past()`. `ai_soldier.gd _shielded()` and `_clear_view()` (its last argument is now the square looked at, for its Shots Into Seen), and `enemy.gd`'s spotting.
- Debug (Q): clicking a tower part shows its profile file, and its Shots Away and Shots Into sections with each lower class's pass-through (and SEEN / HIDES). The Shots Away sections are drawn round the tower as filled circles numbered 1, 2, 3; the Shots Into as dashed blue circles numbered In 1, In 2, In 3.
- Also: CLAUDE.md said main.tscn places 4 enemies; it now has the EnemySpawner instead, and tests spawn their own.
- Tested on the scratch copy:
  - test_height_profiles.gd: all four profiles load (top 3 / 50%, shelter 3 / 0% with no Shots Away, stairs 2 / 80%). Someone on the top, shot at from 20 m away on the ground, bullets fired at them from just in front of the cover: sandbags 4.5 m from the tower 100% through (Shots Into section 1; seen, hidden before); sandbags 12 m out 41% (40%; seen); a crate 7 m out 48% (50%; seen); a crate 12 m out 23% (20%; hides). Firing from the top, the same cover gives 78%, 33%, 25%, 10%. The debug panel lists both.
  - test_height_smoke.gd: the level with 4 spawned enemies and 5 squadmates (3 up the tower) fighting for 25 s: no script errors.
  - test_tower_ways.gd (27 of 27), test_tower_radio_squad.gd and test_closed_click.gd still pass.
  - Old tests that called the overlook box (the overlook and shelter-fire tests) no longer apply.
- **Live tuning (Mike: "can those controls change live?"):** the game run from the editor has its own copy of the profile files, so Inspector edits didn't reach it. `watch_tower.gd _reload_saved_profiles()`: run from the editor (OS feature "editor"), every PROFILE_LOOK_S (1 s) each tower looks at its profile files, and one saved since is loaded afresh (into every tower sharing it; the stair body's height class follows the lower stairs'). Edit in the Inspector, save (Ctrl+S), and the running game has it a second later. A profile made unique lives in the scene and isn't watched. Tested (test_profile_live.gd): two towers, the lower stairs file saved with 5% while running: both read 5% a second later.
- **Mike: Pass Through 0 on the lower stairs, and he could still shoot through it.** The profile's Pass Through only judged shots at someone standing on the stairs; a shot across the stair at something past it asked the stair itself (StairsBody, partial_cover.gd), whose Hit Chance was a fixed 0.35. `watch_tower.gd _apply_stair_profile()` now sets StairsBody's Hit Chance to 1 - the lower stairs' Pass Through (and its height class), at start and on every live reload. (Also: his saved lower stairs file had no pass_through line, i.e. the default 50%: the 0 hadn't been saved yet.) Tested (test_stair_pass.gd, 300 shots across the flight from the ground): Pass Through 0% → 0% across, 50% → 56%, 100% → 100%.
- **Mike (screenshot): sections round the part, not the tower.** Each part's profile sections are now measured from that part's own middle (`watch_tower.gd part_middle()`): the lower stairs, the lower flight's middle (2.0, 3.05 m from the tower's); the upper stairs, the upper flight and mid landing's (2.0, 0.7); the top, the deck's (0, 0); the shelter, the cabin's (-0.3, -0.3). `cover.gd _profile_middle()` and the debug drawing use it, so the circles drawn are the ones the shots go by. Tested (test_part_middle.gd): the middles as above; sandbags 4.45 m from the lower flight's middle (7.8 m from the tower's) are in its section 1. test_debug_circles.gd (clicking each part in debug mode: picked, panel shown, drawn, no errors) and test_height_smoke.gd (no script errors) pass. (A type slip in the debug drawing broke debug mode for a minute; fixed.)
- **Mike: the Inspector numbers sections from 0, the circles from 1.** `height_profile.gd` is now a @tool script and names its sections by place whenever its lists change (`_name_sections()`): "Section 1", "Section 2"... in Shots Away, "Into Section 1"... in Shots Into, so each element shows its circle's number in place of "ShotSection" (Godot's own 0, 1, 2 beside them stay). Tested (test_section_names.gd): loaded, the top's read Section 1-3 / Into Section 1-3; a new one added first and the rest renumber; reversed, they renumber by their new places; empty slots are skipped.
- **Mike: the sections should also count cover the same height class as where you stand.** Rule 2 is now "cover higher than where you stand is just cover": `cover.gd away_pass()`, `into_pass()` and `seen_past()` go by cover as high as the profile's height class or lower (`cls > height_class` is just cover). The debug panel lists each class up to the part's own ("pass through of cover as high or lower"). Docs in height_profile.gd, shot_section.gd, shot_into_section.gd, watch_tower.gd updated. Tested (test_same_height.gd): a lower stairs profile of height 2 with Class 2 at 100% away and 60% into: a crate (height 2) 5 m off lets 100% through fired from the stairs and 60% fired at them, seen; sandbags (height 1) at 0% stay at their own 10%. The panel shows class 1 and class 2 for each section.
- **Mike: Local to Scene at the top of the profile, beside Height Class.** `height_profile.gd local_to_scene`: an editor-only property (not saved) at the top of the profile that reads and sets Godot's own `resource_local_to_scene` (still under Resource at the bottom too). Ticked, every tower placed in a scene gets its own copy of the profile at start; those copies aren't reached by live tuning (no file of their own). Tested (test_local_toggle.gd): it's listed first among the profile's own settings; ticking it ticks Godot's, unticking Godot's shows here; saved, the file has resource_local_to_scene and no extra line.
- **Undone at Mike's ask:** the Local to Scene shortcut at the top of the profile (he'd found Godot's own under Resource). Checked what Local to Scene does (test_local_scene.gd): on a profile set on towers in a scene, each tower gets its own copy of the profile at start, but the sections inside are still shared (children aren't copied); on a tower left at its default profile (the script's preload, not stored in the scene) it does nothing, they share it. For one tower's own settings in the editor: right-click the profile, Make Unique (Recursive).
- **Mike: Shots Into is about the shooter's distance, not cover.** "Someone far away has a harder time shooting someone on the stairs than someone really close." Shots Into sections now go by how far the SHOOTER is from the part's middle; each has a Radius, one Pass Through % (the part's pass-through for shots from that far, in place of its own), and Seen (from that far, low cover, height class 1 and 2, doesn't hide someone on the part; unticked, it does).
  - `shot_into_section.gd` (ShotIntoSection) is its own resource now: radius_m, pass_through, seen (the per-class pass-throughs and seens are gone).
  - `watch_tower.gd part_pass_from()`: the part's pass-through for a shooter, by its Shots Into section (its own Pass Through with no sections or no shooter); `cover_pass()` uses it. The stair as an obstacle (shots across it) keeps the lower stairs' own Pass Through.
  - `cover.gd`: `into_pass()`, `height_pass()` and `shot_target()` are gone; `height_extra()` is the shooter's Shots Away alone; `seen_past(node, target, from)` goes by the viewer's distance. `ai_soldier.gd _clear_view()` passes where it's looking from.
  - Debug panel: Shots Into lines read "section n (a - b m): x%, seen over low cover / hidden by low cover".
  - The top, upper stairs and shelter profiles rewritten (their Shots Away kept): top 70 / 50 / 35% (seen, seen, hidden), upper stairs 90 / 75 / 55%, shelter 0% all, each at 5 m, 10 m, beyond. Mike's lower stairs left as he has it (its three Shots Into sections are blank, so 50% seen each). Backups of all four from before in the session scratchpad (profile_backup).
  - Tested (test_into_distance.gd): on the top, shot at from 3.2, 8.1 and 15 m: 71, 51, 36% through the tower (70, 50, 35% set); over sandbags from 8 m seen, from 15 m hidden; firing from the top past sandbags 4.5 m out still 78%; the panel lists both. test_height_smoke.gd (no script errors) and test_debug_circles.gd pass.

## 2026-11-02 — Player: Unlimited Ammo in the Inspector

- **Mike:** a player Inspector item for unlimited ammo. `player.gd unlimited_ammo` (under Drop Off Animation): on, the rifle's spares are endless and always full (`spare_mags` -1, as rifle.gd already supported); you still reload with R, and the ammo panel says MAGS unlimited. `_apply_unlimited_ammo()` keeps the rifle's own count and puts it back when it's turned off, so it can be flipped mid-game from the Remote tree. (As with any endless-spare rifle, the empty magazines it swaps out drop on the ground.)
- Tested (test_unlimited_ammo.gd): on from the start: spare_mags -1; emptied and reloaded three times, 30 rounds each time; off: back to 2 spares (empty, as before); on again: -1.

## 2026-11-02 — Shots Into: Above %

- **Mike:** each Shots Into section gets Above (a percentage): set as the gun's fired, the shot goes above or below; above, it can hit someone on the part; below, someone under it.
  - `shot_into_section.gd above` (0-100%, default 50).
  - `bullet.gd`: `_height_roll` is rolled as it's fired; `_passes_by()` asks each tower's `passes_by()` when it reaches a square, and passes them if they're at the other height.
  - `watch_tower.gd passes_by(unit, from, roll)`: on a part here, the shot passes unless it's high (roll < that part's Above % for the section the shooter's distance from the part's middle falls in); on the ground under a part (`part_above()`: under the cabin the shelter, under the deck or top landing the top, under the upper flight and mid landing the upper stairs; nobody's under the lower flight), it passes if it's high. `above_share()`. No Shots Into sections: no effect. The steel (pass-through) still applies after.
  - The debug panel shows each Shots Into section's above %.
  - Not changed: the AI doesn't weigh Above % when picking who to shoot (it's a roll on each shot).
  - With the default 50%, shots at someone on the tower, or under it, now miss half the time from every section: tune it per part.
- (A type slip in passes_by() broke watch_tower.gd for a minute or two; fixed.)
- Tested (test_above_below.gd, the top's Above set to 80%, shot at from 8 m): someone on the top hit 43% of 300 (80% above x 50% through the steel = 40%); someone on the ground under the deck 18% (20% below x 75% through = 15%). test_height_smoke.gd (no script errors) and test_debug_circles.gd pass.

## 2026-11-03 — Start Here brought up to date; the tests kept in the project

- Mike's moving between accounts, so everything a new session needs has to live in the project.
- **Start Here** (top of this file) rewritten for the current game. It was last updated 2026-10-29, before enemies, crates, sandbags, the tower and height profiles. It now covers the controls, what's in the level, the AI states, cover and height, next steps and loose ends.
- **`tests/`** (with a .gdignore, so Godot never loads it): the headless test scripts from the last two sessions, which had only lived in temporary scratch folders. 82 current tests, `obsolete/` (four testing things since replaced: the overlook box, the old sections, cover-based Shots Into), `screenshots/` (windowed screenshot scripts), `tools/make_height_profiles.gd` (writes the tower's default profiles; overwrites Mike's tuning, so scratch copy only). `tests/README.md` says how to run them.
- CLAUDE.md: Testing points to `tests/`; the note on what `main.tscn` places is corrected (10 squadmates, crates, sandbag walls and the watch tower are placed; enemies come from the EnemySpawner).

## 2026-11-03 — Adding a height profile section works

- **Mike:** adding a section to Shots Away didn't add one, and he expected section 3's radius to become adjustable.
  - The last section reaches as far as a bullet goes, so its radius never counted, and the top's section 3 was saved with Radius 0. Once a 4th went after it, section 3 was an ordinary ring 0 m out: it covered nothing and drew as a dot. And the Inspector's Add Element only adds an empty slot, which counted as nothing, so past 10 m there was no section at all until one was made in it.
- `height_profile.gd _tidy_sections()` (was `_name_sections()`), run whenever either list changes (added to, taken from, reordered, loaded):
  - An empty slot gets a section: a copy of the one before it (a new one if it's the first). Add Element now adds a ring out past the rest, starting with the old outer ring's settings.
  - A section that isn't the last and reaches no further than the one inside it is put RADIUS_STEP_M (5 m) past it. The top's section 3 becomes 15 m, to adjust from.
  - Naming as before (Section 1..., Into Section 1...). Changing a radius by hand in a section doesn't come through here, so it's never undone.
- Tested on the scratch copy:
  - test_add_section.gd (new): the top as loaded keeps 5 / 10 / 0. Add Element on Shots Away: 4 sections, section 3 at 15 m, section 4 a separate copy with section 3's 33% / 10%, named Section 1-4; 12 m is in section 3, 20 m in section 4. Section 3 set to 25 m by hand stays; a 5th puts section 4 at 30 m. Shots Into the same (section 4 copies 35%, hidden). A first section in an empty list is a new ShotSection.
  - test_section_names.gd and test_height_smoke.gd (no script errors) still pass.

## 2026-11-03 — Shots Away greys out the classes a part doesn't count

- **Mike:** grey out the section settings that won't apply. Shots Away only counts cover as high as the part or lower (`cover.gd away_pass()`: higher is just cover), so on a height class 2 part (the stairs) every section's Class 3 Pass Through did nothing.
- `shot_section.gd` is now a @tool script with `height_class` (not saved) and `_validate_property()`: the class pass-throughs above it are read-only, which the Inspector shows greyed out. `height_profile.gd _share_height()` hands each Shots Away section the profile's height class, whenever the height class or the list changes (and on load), so changing Height Class greys or ungreys them at once. Greyed values are still saved, and come back if the height class goes up again.
- Shots Into has no per-class settings, so nothing there is greyed.
- Tested on the scratch copy (test_section_greyed.gd, new): upper stairs (2): Class 3 greyed in all three sections; top (3): none. The top set to 1: classes 2 and 3 greyed; a section added then is greyed the same; back to 3: none. Saved at height 1 with class 2 = 42: loads back as 42, greyed. test_add_section.gd, test_section_names.gd and test_height_smoke.gd (no script errors) still pass.
- **Mike, later: errors adding a section.** In the editor, sections loaded before `shot_section.gd` was a @tool script are placeholders, and `_share_height()` called a method on each (`set_height_class()`): "Attempt to call a method on a placeholder instance". `height_class` is now a property with a setter, set with `section.set("height_class", ...)`, which a placeholder ignores. (Those sections don't grey until Project > Reload Current Project.)
  - Reproduced and checked in a headless editor on the scratch copy (a throwaway plugin doing what Add Element does, through undo/redo): the method call on a placeholder gave the error; set() gives none; Mike's upper stairs file adds a section to both lists without errors (Shots Away 3 → 4, section 3 to 15 m; Shots Into 2 → 3). test_section_greyed.gd, test_add_section.gd and test_height_smoke.gd still pass.

## 2026-11-03 — Deaths up the watch tower: bodies stay up there, or go over the railing

- **Mike (screenshot):** a square killed on the top or the stairs always ended up on the ground below. He likes that when they fall over the side, but one falling back onto the tower should stay on it, and going over the side they clipped through the floor and the rails: make it look like they hit the rail and go over.
  - Why: the ragdoll (`death_fall.gd`) knew nothing about the tower. Landing, the body went to the ground's draw order (BODY_DOWN_Z, under the deck) and ground size, wherever it was, so it looked like it had dropped through.
- `death_fall.gd`, up a tower:
  - It lies where it falls, on the deck or stair: at their height (drawn bigger, as soldier.gd view_scale(); on a stair, the height under its middle), over them with the squares up there (watch_tower.gd UNIT_Z), moved first in the level so the living are drawn over it. Its shadow lies on them.
  - Toppling or skidding into a railing or the cabin's wall (`_meet_walls()`, and the skid's own collisions): a clang (the metal impact sound, a placeholder). Into a railing going outward faster than OVER_RAIL_MPS (0.9 m/s), it goes over (`_meet()`, `_roll_over()`): in OVER_S (0.35 s) it tips the rest of the way over the rail, turning to go over it square on and rising OVER_LIFT_M, its middle ending OVER_CLEAR_M past the rail. Then it drops under gravity (`_drop()`), drifting outward, turning a little, smaller as it falls, its shadow out on the ground below and fainter. It lands with dust, a thump (dirt, or metal on the stair) and a rock back up, and skids a short way.
  - Not over: slower than that, at the cabin's wall, or where what's past the rail is higher (off the upper flight toward the deck). It's stopped there and slides down against it.
  - It lands on the ground, or on the stair if that's under it (over the deck's east railing), pulled in between the stair's side rails.
  - Its rifle comes down on whatever's under it: the deck or stair, or the ground past their edge (the railings don't stop it). On a stair it follows the slope, and skidding off the deck's edge it falls again. Its magazine pickup (`ammo_pickup.gd tower`) is drawn on the deck, and the player only takes it from up there (and a ground one only from the ground).
  - A body up there isn't stepped over by squares walking underneath (`under_at()`).
- `watch_tower.gd`: WALLS split into RAILS and CABIN_WALLS (WALLS is both, as before). `wall_near()`: the railing or wall nearest a point, which way is across it, and whether it's a railing. `landing()`: the deck or stair under a point and its height.
- Tested on the scratch copy (test_tower_deaths.gd, new; 13 cases × 4 runs, a tower of its own): over the rail to the ground from the south walkway pushed south, the west of the deck pushed west, the upper flight pushed east, the top landing pushed north, the lower flight pushed west, and the mid landing pushed east (on the ground, BODY_DOWN_Z, after peaking 0.25 m over where it stood). Stays up there: the south walkway pushed north (the cabin's wall), pushed west along it, the upper flight pushed west (the deck's past its rail: slumps at x 1.80), pushed down the stair (lies 0.6-0.8 m lower down it), and in the shelter pushed west. The east walkway pushed east: over its rail onto the upper flight (1.5-1.9 m up, between its rails). On open ground: as before. Every run came to rest. (A first run had a body falling through the stair's slope to the ground under it; fixed by judging what's under it from where it was a tick before, with a small LAND_STEP_M step.)
  - test_height_smoke.gd (squadmates up the tower in a 25 s fight; no script errors), test_tower_ways.gd, test_tower_squad.gd, test_tower_squad_climb.gd, test_watch_tower.gd, test_tower_cover.gd, test_debug_circles.gd and test_ammo_can.gd still pass.
  - A windowed screenshot run showed a body landed on the ground below the deck in dust, but the window stopped redrawing partway, so the test's numbers are the check.

## 2026-11-03 — Shots between two squares up on the tower don't go through them

- **Mike:** shooting someone else on the top level with him, the shots went through them.
  - Why: Shots Into's Above % (`watch_tower.gd passes_by()`) rolls each shot high or low as it's fired, and a low shot flies under the part, past anyone on it. That's for shots from the ground, but it was rolled whoever fired, so from the top at someone beside him half went "under" them.
- `passes_by()` takes the shooter (`bullet.gd _passes_by()` passes it): a shooter up on the same tower as the square it reaches is firing at their level, so neither high nor low. The steel between parts (Shots Into Pass Through) still counts, as before; on the same part nothing's between.
- Tested on the scratch copy (test_same_level_shot.gd, new; 300 real bullets each): top to top along the south walkway, 1.4 m: before 49% hit, now 100%. Top to the upper flight: before 47%, now 97% (the upper stairs' Shots Into pass-through from there, 97%). From the ground 8 m off at someone on the top: 24% (Above 50% x steel 50%), as before. test_above_below.gd, test_tower_cover.gd and test_height_smoke.gd (no script errors) still pass.

## 2026-11-03 — Falling off the tower, faster

- **Mike:** increase the speed of the fall. `death_fall.gd`: FALL_GRAVITY 9.8 → 19.6 (twice real gravity: off the deck, 3 m in 0.55 s, was 0.78 s), and going over the rail OVER_S 0.35 → 0.25 s. From the hit to landing, off the top: about 0.8 s, was 1.1 s.
- Tested on the scratch copy: test_tower_deaths.gd, all 13 cases still pass (4 runs each).
- **Found by it:** falling faster, a body going over the deck's east railing landed on the stair with less drift, its pivot edge still on the deck's side of the railing, so the rock back up after landing swung it back over the rail onto the deck (at the stair's height). Landing on the stair it now doesn't rock back (wedged between its rails); on the ground it still does. test_tower_deaths.gd: all 13 pass, twice over (8 runs of each); test_height_smoke.gd, no script errors.
- **Mike, later: still a bit slow.** FALL_GRAVITY 19.6 → 29.4 (three times real gravity: 3 m in 0.45 s) and OVER_S 0.25 → 0.18 s. From the hit to landing off the top, about 0.65 s. test_tower_deaths.gd: all 13 pass, twice over.
  - (test_tower_deaths.gd: the stair case's check on where the body lies widened from x 1.75-2.25 to 1.7-2.3: one run in eight ended at 1.74, 6 cm over the stair's side rail, which doesn't show.)

## 2026-11-03 — The shelter stops every shot, from anywhere

- **Mike:** the shelter on the watch tower has 0% pass through regardless of where it's shot from, unless a bullet goes under.
  - With his saved profiles it already did (the shelter's Pass Through and Shots Into all 0%), but only through the tuning: shooting from the deck goes by the shooter's Shots Away for class 3 cover, and the top's could let shots in, as could the shelter's own settings.
- `watch_tower.gd cover_pass()`: a target in the shelter gets 0 through, before anything else, whatever the profiles say. Shots flying under it (Shots Into Above, `passes_by()`) still go on to whoever's on the ground under the deck. The shelter profile's Pass Through and Shots Into Pass Through now do nothing for shots at it (its Above and Seen still count).
- Tested on the scratch copy (test_shelter_sealed.gd, new; 200 real bullets from each place, at a square in the shelter): from the ground at 3, 7 and 15 m, from the deck east and south of the cabin, the top landing, the upper and lower flights: 0 hits each. With leaky settings (the shelter at 100% everywhere, the top's Shots Away class 3 at 100%): before the rule 93 of 200 from the ground and 200 of 200 from the deck; now 0. Someone on the ground under the shelter, from 7 m: 80 of 200 hit (low shots), as before. test_tower_cover.gd (the cabin 0%, 0 hits) passes.
  - test_same_level_shot.gd's top-to-stair check now expects what cover_pass() says (Mike's saved top lets class 2 past fully now, so 100%, not the stairs' steel alone).

## 2026-11-03 — From the top, the cabin stops shots through it

- **Mike:** still shooting through the shelter when on the top. Shots at someone in it were stopped (above), but shots past it, at someone beyond the cabin, went straight through: the railings and cabin walls (`tower_walls.gd`) let every bullet through, since a bullet doesn't know how high it flies, and one fired on the ground under the deck mustn't stop in walls 3 m up.
- `tower_walls.gd stops_bullet()`: a bullet reaching one of the cabin's walls (its shapes are WALLS in order, the railings first: `rail_count`, set by watch_tower.gd) stops there if its shooter's up on this tower on the top, in the shelter or on the upper stairs (CABIN_HIGH_PARTS: at the cabin's height). Sparks and a clang, as off the legs (`bullet_hit()`). `bullet.gd` asks it before letting anything else through. The railings still let shots through, and from the ground (and the lower stairs) shots still go under.
- The AI the same: `blocks_sight()`, asked by `ai_soldier.gd _clear_view()`: from up there it doesn't see (so doesn't fire) through the cabin.
- Not done: a shot from the ground at someone on the far side of the deck, past the cabin, still isn't stopped by it (those go by the deck part's Shots Into as before).
- Tested on the scratch copy (test_shelter_sealed.gd, added to; 200 real bullets each): from the south walkway through the cabin at someone on the ground north: 0 hit; from the east walkway through it at someone on the ground west: 0. From the south walkway at someone south (open): 200. Ground to ground under the cabin: 199. The AI on the south walkway can't see through the cabin to the north, can to the south; from the ground it sees under it. The shelter checks still pass. test_height_smoke.gd (no script errors), test_same_level_shot.gd, test_tower_cover.gd, test_tower_radio_squad.gd and test_wall_sight.gd pass.
- **Mike (screenshot), later:** shooting from the top (both walkways, the top landing, the stair by the deck), the tracer went under the deck and the cabin and came out the other side, under; he expected it over. The cabin stopped the shots, but the tracer couldn't be seen doing it: every tracer was drawn at ground level (z 0), under the tower.
  - `bullet.gd`: fired by someone up on a tower at the cabin's height (`watch_tower.gd up_high()`: the top, the shelter, the upper stairs; HIGH_PARTS, now shared with tower_walls.gd), a tracer is drawn at HIGH_Z (6): over the stairs, deck and squares up there, under the roof. Going over or under something it comes back to that, not 0. From the ground and the lower stairs it's as before.
  - Tested (test_shelter_sealed.gd, added to): tracer z from the top 6, the upper flight 6, the lower flight 0, the ground 0. The rest of that test, test_height_smoke.gd (no script errors), test_same_level_shot.gd and test_tower_cover.gd pass.

## 2026-11-03 — Supply truck: first look (branch Supply_Truck)

- **Mike (two reference photos: a military 10x10 wrecker and a crane truck lifting a container):** the next asset, a supply truck in our style: a working crane between the cab and a flatbed that holds two pallets. Look first, function after.
- `blender/scripts/supply_truck.py` (new): an olive-drab, unmarked 8x8 tactical truck, modelled at game size in proportion with the helicopter: 4.3 m long, 1.37 m over the tyres, the cab roof 1.74 m up.
  - Cab: flat-faced, sloped two-pane windscreen, amber marker lights and two beacons, roof hatch, mirrors on arms, doors with windows, a grille nose over the bumper and tow shackles.
  - Behind it the engine module (louvred vents, exhaust stack, air intake with rain cap, toolbox), then the crane bay (pedestal, slewing ring, a stabiliser leg each side, operator's levers), then the flatbed: 2.0 x 1.2 m, deck 0.8 m up, headboard, side rails, stake pockets, tie-down rings. Two of the game's 0.8 m pallets fit one behind the other, 0.12 m apart.
  - Four axles of lugged off-road tyres, showing a little past the body from above.
  - The crane's turret (column, main boom raised, outer boom folded forward over the module, yellow hook block) is its own image, centred on its slewing axis (CRANE_X_M), so it can turn.
  - Olive a little lighter and greener than the helicopter's, between it and the ammo cans', after the photos.
- Images: supply_truck_body.png and supply_truck_crane.png (lit from straight overhead, as the helicopter, since it turns; 2x density), and two reviews: top-down under the standard sun on the field's grass with two ammo crates (crates.py, imported) on the bed and a red square for scale, and an angled look.
  - Rendered as drafts outside the project first (`-- draft <folder>`): Godot imports a new PNG as soon as it appears, and these need their .import (mipmaps) first. **Mike: "its perfect".** Then the two .import files (mipmaps on, from radio_station_dish.png.import) went into assets/vehicles/ before the sprites; the reviews into assets/previews/, the .blend into blender/source/. No scene yet: the crane and loading come next.
- First draft fixed before showing: tyres read as gears (lugs too tall and few) and poked up into the cab and module (the cab, module and bed now sit above them); the olive was very dark; the steel slewing ring mirrored the overhead light.
- **Mike (screenshot), later:** no round hatch; these are square people, so if there's a top hatch, size it for our squares. `supply_truck.py`: the roof hatch is square, HATCH_M 0.44 m (a 0.4 m square and a little) at HATCH_AT, in a dark rim, its lid hinged along the back with a handle at the front. Re-rendered into the project (the body sprite, both reviews).

## 2026-11-03 — Supply truck: driving

- **Mike:** driving first. He chose: car-style controls (W/S throttle and reverse, A/D steer), F at the driver's door to get in and out, the camera following the truck, driver only for now.
- `scenes/supply_truck.tscn` + `scripts/supply_truck.gd` (new): a CharacterBody2D (layer 1, like squares and crates; mask 1 + 4, so sandbags stop it too), the body and crane sprites (z 3: over the squares, under a tower's stairs and deck), a 4.3 x 1.37 m box, and its shadows.
  - Getting in: walk to the driver's door (DOOR_M: outside the cab's left side) and a green F shows there (UiStyle.pad_key, kept upright), the truck being the player's interact_target() ("interactables"). F: the player is hidden, switched off, off the collision layers (nothing hits it) and rides at the truck's middle, so the camera (which follows the player) and command mode go with the truck. F again: out by the driver's door, or if something's there the other door, then behind it (a shape query for a clear spot); facing away from the truck.
  - Driving (`_drive()`): a bicycle model turning about the rear axles (REAR_AXLE_X_M, WHEELBASE_M 2.6 m): W up to `top_speed_mps` (6) at `accel_mps2`, S brakes (`brake_mps2`) then reverses up to `reverse_speed_mps` (2.5), neither coasts to a stop (`coast_mps2`); A/D turn the front wheels up to `max_steer_deg` (32) at `steer_dps`, straightening when let go. It only turns while rolling. Turning into something it doesn't turn; running into something, or a corner out of the play area, it stops dead. All the speeds are in the Inspector (Driving). No input in debug mode.
  - Shadows as the helicopter's: outlines per height group, swept toward the sun (`_place_shadow()`), the crane's turning with it. `blender/scripts/supply_truck.py` now renders them (SHADOW_GROUPS: low 0-0.95 m, headboard 0.8-1.22 m, cab and module 0.3-1.88 m, crane 0.86-2.08 m), half density, their .import files written first (no mipmaps, as the helicopter's). The shader's `steps` set to one per texture pixel of sweep: at its default 24, the mirrors' arms left dotted streaks across the cab's 60 px sweep.
  - Not yet: the front wheels don't turn in the picture, no engine sound, squares don't ride, the crane and bed do nothing. No truck is placed in main.tscn (Mike places it).
- Tested on the scratch copy (test_truck_drive.gd, new): the truck starts clear; at the door it's the interact target with its F shown; F gets in (hidden, layer 0, switched off). 2 s of W: 5.0 m straight ahead at 5 m/s, the player riding at its middle. 1 s of W+D: turned 69 degrees clockwise. Let go: stops, wheels straight. Standing, A doesn't turn it. 1.5 s of S: 2.5 m back. Into a crate 5 m ahead: stops 2.47 m from its middle (its front 0.32 m off the crate's middle), no overlap. North to the edge: stops inside. F: out at the driver's door, not overlapping anything, the F back. A bullet at it stops in it, 1.0 m from its middle. test_height_smoke.gd: no script errors. A screenshot (tests/screenshots/shot_truck.gd): two trucks in the level, east and turned 35 degrees, shadows falling bottom-right.

## 2026-11-03 — Supply truck: the door opens, the square gets in and out

- **Mike:** a door opening and the character getting in, for the immersive feel.
- `blender/scripts/supply_truck.py build_door()`: the driver's door on its own (DOOR_X, DOOR_T 0.09 m: armoured, and thick enough to read as a door from above), a panel up to the windscreen's foot, then a window in a frame, handles out and in; rendered shut, round its middle, with nothing else in the scene (the cab's roof left it in shadow). `supply_truck_door.png` (2x, mipmaps) and `supply_truck_shadow_door.png`, their .import files written first.
- `supply_truck.gd`: both doors are hinges (DOOR_HINGE_M, the right mirrored) with the door sprite under each (the right flipped), drawn only while open, swinging out to DOOR_OPEN_DEG (75) in DOOR_S (0.45 s), eased; each door's shadow swings with it.
  - Getting in (`get_in()`, `_tick_getting_in_or_out()`, steps in `Step`): the player walks itself to the door (`player.gd walk_to`, new: _move_intent() and _aim_point() head there, easing over WALK_TO_EASE_M; `busy` meanwhile, so no F or firing), the door opens, it steps up into the cab (through the cab's side, off everything solid, drawn under the truck so the roof hides it) to the driver's seat (SEAT_M), it's hidden, the door shuts, and only then does it drive. It now rides in the seat, not the truck's middle, so the camera doesn't jump.
  - Getting out (`get_out()`): only once it's stopped (STOPPED_MPS); the door opens, it steps out of the cab to beside the door (DOOR_M), solid and back in hand, the door shuts. Something there: the other door, the same mirrored; both blocked: out the back at once, as before.
  - Getting in given up (the way to the door blocked for WALK_GIVE_UP_S, or the player killed): back in hand, the door shuts on its own.
- Tested on the scratch copy (test_truck_drive.gd, updated): F at the door: at the door 0.2 s, the door opens to 75 degrees, out of sight in the cab 1.2 s, the door shut and driving 1.6 s, in the seat. F while it's moving: stays in. F stopped: out in 1.4 s, the door opening to 75 and shutting, at the door spot, not overlapping, solid, not busy. The driver's door blocked by a crate: out by the other door, which opens. The driving checks and the bullet still pass (17 of 17). A screenshot (tests/screenshots/shot_truck_door.gd): the door swung open at the cab's front corner, the square stepping in behind it.

## 2026-11-03 — Supply truck: door and engine sounds, engine start before it moves, the door moved, tyres under the square

- **Mike:** added `assets/sfx/supply_truck/`: `front_door.mp3` (27.6 s, doors opening and closing; "pick your favourite") and `TransportVehicle.mp3` (54.8 s; the start at the beginning, for starting the truck), and a pause after ignition before it moves, to boot up. (A copy of TransportVehicle.mp3 is also loose in assets/sfx/; left alone.)
  - Mapped in headless Blender (`aud`, loudness and the engine's firing frequency every 0.1-0.5 s). Doors: two cycles of handle click, door opening, click, heavy slam; the second is the cleaner and louder (the deepest slam). Engine: ambient to 2.9 s; the starter cranks from 2.95 s; it catches and revs to 5.5 s (80 Hz); settles to idle (40-44 Hz) by 6.4 s; idles 12.5-16.5 s; is switched off at 17 s; a steady harder-working stretch at 42-45 s (46-56 Hz); off again from 46 s.
  - Cut (`tests/tools/cut_truck_sounds.py`, kept this time; run with Blender) into assets/sfx/supply_truck/, mono 48 kHz 16-bit: `truck_start.wav` (2.85-6.6 s), `truck_stop.wav` (16.3-17.7 s), loops `truck_idle.wav` (12.5-16.5 s) and `truck_run.wav` (42-45 s) (the last 0.5 s cross-faded into the start), all four at one gain (the loudest peak at -3 dB) so they keep their levels; `door_open.wav` (18.39-18.77 s) and `door_slam.wav` (24.06-24.57 s), the two at one gain.
- `supply_truck.gd`:
  - The door's opening sound as it starts to open, the slam as it shuts (`_swing()`, `_door_noise()`, from that door).
  - The engine (`_engine`, `EngineState`): started once the driver's in and the door's shut (`_start_engine()`): the start sound; over its last START_BLEND_S the idle loop fades in under it; `boot_pause_s` (0.6 s, Inspector) after it ends it's RUNNING, and only then does W/S do anything (steering does). Running, the idle and running loops are mixed by speed (and a little by the throttle), their pitch climbing up to `speed_pitch` (0.3) at top speed. Getting out (`_stop_engine()`): the stop sound, the loops fading over LOOP_FADE_S. `engine_volume_db`, `door_volume_db` in the Inspector (Sound).
- **Mike (screenshot), during this:** the door further to where he marked it, and the square getting in above the tyres but below the cab.
  - `supply_truck.py` DOOR_X (1.45, 1.93) -> (1.27, 1.89): a 0.62 m door, hinged by the windscreen; DOOR_FRAME_M 0.75. `supply_truck.gd` DOOR_HINGE_M (1.89, -0.575), DOOR_MIDDLE_M (-0.31, 0).
  - The tyres out of the body's picture: one tyre (the left front, with its hub) rendered on its own, `supply_truck_tyre.png` (2x, mipmaps; its .import first), drawn eight times (`_tyres`, the right ones flipped) at TYRE_Z (-1): under the squares (0) and the body (3), so a square getting in goes over them and under the cab. The front two axles' tyres turn with the steering (`_turn_tyres()`), each to roll round the same middle (the front axle more). They're still in the low shadow outline.
- Tested on the scratch copy (test_truck_drive.gd, 22 of 22): in, the engine starting with its start sound; W held from getting in, it set off after 4.47 s (start 3.77 + boot 0.6), the idle loop heard; running, the running loop on and the start done; turning right, the front tyres at 35 and 28 degrees, the rear straight; getting out, the engine off with its stop sound and the door's opening sound; the rest as before. A screenshot (shot_truck_door.gd): the longer door open by the windscreen, the square stepping in over the tyre and under the cab's edge.
- **Mike, later: driving, the engine sounds periodic and repetitive; the idle loop isn't smooth enough.** The loops were short (idle 3.5 s, running 2.5 s), their ends cross-faded into their starts without lining up the engine's firing (a small wobble every time round), and the running stretch's pitch climbs across it (46 to 56 Hz), so each repeat dropped back.
  - `tests/tools/cut_truck_sounds.py`: `truck_idle.wav` is now the two steady idle stretches (12.4-16.6 s and 23.6-27.0 s) joined into one 6.9 s loop. Each join, and the wrap back to its start, is cut where the waveforms line up best (normalised cross-correlation over MATCH_S, by FFT; the wrap also chooses where in the first 0.5 s the loop starts), then cross-faded over 50 ms. Line-ups: the join 0.90, the wrap 0.95 (1 = identical). `truck_run.wav` is gone.
  - `supply_truck.gd`: one engine loop, its pitch climbing up to `speed_pitch` (0.3) and its volume up to `speed_gain_db` (4 dB, new) with speed (and a little with the throttle down).
  - Checked (the loop played twice in a row, 25 ms windows): the level steps 0.80 and 0.21 dB across the wrap against 0.38 typical and 2.09 at most anywhere, the waveform jump at it smaller than a typical sample step. test_truck_drive.gd 22 of 22 (running: the engine loop playing, pitched up).
- **Mike, later: how do I tweak the sounds; I want to change which section of the MP3 is used.**
  - `scripts/truck_sound_cuts.gd` (new, @tool, class TruckSoundCuts) saved as `assets/sfx/supply_truck/truck_sound_cuts.tres`, on the truck as Sound > Sound Cuts (`supply_truck.gd sound_cuts`, editor only): the sections in seconds (Engine Start, Engine Running: up to three idle stretches, Engine Stop, Door Open, Door Slam), and a **Cut Sounds** button (@export_tool_button). It writes the sections to user://truck_sound_cuts.json and runs Blender headless on `blender/scripts/cut_truck_sounds.py` (moved there from tests/tools; it now takes the sections, the old ones as its defaults), prints what it made in the Output panel, and has the editor reimport the WAVs. A Blender failure (`--python-exit-code 1`) leaves the sounds as they were, with its output as an error.
  - (Found testing it: Windows stripped the quotes off JSON passed on Blender's command line, and Blender exited 0 on a script error, so the first try said "done" and changed nothing. Hence the file and the exit code.)
  - Tested on the scratch copy (test_sound_cuts.gd, new): the resource is on the truck with its sections; the second idle stretch set to 24-26 s and Cut Sounds: the idle loop re-cut 6.9 -> 5.4 s (joins 0.93, wrap 0.94), the other four made again, no errors. test_truck_drive.gd still 22 of 22.
- **Mike, later: getting in, the truck doesn't start until you press W.**
  - Not reproduced. A windowed run on the scratch copy recorded the game's own output (AudioEffectRecord on the Master bus, muted after it) while the player got in and nothing else was pressed: the door at 0.25 s, the slam at 1.5 s, the start sound from 1.75 s (cranking -22 dB, catching at 4.25 s), idle from 6 s; the engine STARTING the tick the door shut, RUNNING at 6.03 s. Nothing waits on W (W only moves it once it's RUNNING).
  - But his saved Sound Cuts had Engine Start at 0.0-7.45 s (not cut yet): the take is background for its first 2.9 s, so once cut that would play as ~3 s of nothing after the door shuts, then the starter, much as he describes. `cut_truck_sounds.py quiet_lead()`: the start sound now begins where it first gets QUIET_RISE_DB (5 dB) louder than the take's background (the 5th percentile of its 50 ms levels), less 50 ms, and says so in the Output. (Measured against the section itself first, it took the cranking for background and cut to the catch at 5.0 s; hence the whole take's.) Checked: 0.0-7.45 s -> starts at 3.00 s (4.45 s long); 2.85-6.6 s -> starts at 3.00 s (3.60 s).
- **Mike, later: "that's what I want": getting in, the ignition shouldn't start until you press W.** `supply_truck.gd`: the engine stays OFF once the driver's in and the door's shut; the first press of W (`_physics_process()`: OFF and move_up held) calls `_start_engine()`; held, it moves once the start sound and `boot_pause_s` are done. Getting out with it never started: no stop sound. test_truck_drive.gd: in, 2 s with nothing pressed: off and silent; W: the start sound; set off 4.45 s after the ignition.
- **Mike, later: cut up his new recording, `TransporetVehicle2.mp3` (65.6 s, his spelling), and see if it sounds better.** Mapped: silence to 0.8 s; the ignition at 0.9 s, catching at once, idle 1.75-4.5 s (36-40 Hz); a rev 4.8-7.5 s; pulling away 7.8-12 s; a steady idle 14.5-18.5 s (46-48 Hz); bits of revving 19-36 s; idle 36-40 s; 41-54 s a steady cruise under load (-18 dB, the firing rate climbing 58 to 74 Hz), which the first recording didn't have; winding down 55-62 s; switched off 62-63.5 s, then a fade to digital silence.
  - `cut_truck_sounds.py`: the engine recording is chosen (`engine`), and an optional driving loop (`run`: truck_run.wav; none and it's deleted). Loops are now made from their stretches each played at one common pitch (`level_pitch()`: the firing rate fitted with a line across each piece and resampled to the pieces' median, never more than MAX_SHIFT 1.25 either way) and loudness, so pieces at different revs join and a climbing cruise doesn't jump back at the wrap. A hand-over that lines up under GOOD_MATCH (0.7) gets a LONG_JOIN_S (0.3 s) constant-power cross-fade instead of the short straight one (the noisy cruise had no clean match: its wrap was 0.32 before levelling, 0.87 after). The background for the quiet start is measured from windows over -70 dB (this take ends in digital silence), and the start begins 150 ms before it gets loud, not to clip the first click.
  - `truck_sound_cuts.gd`: Engine Recording (a file pick) and Engine Driving (two stretches); times to 120 s; reimports truck_run.wav when there is one. `supply_truck.gd`: a driving loop, if the cuts made one (loaded at start, `_run`), blends in over RUN_BLEND (0.15-0.6 of the way to top speed) at constant power, its pitch climbing from (1 - speed_pitch) to its own; `driving_volume_db` (-4 dB) balances it. Without one it's as before.
  - Cut into the project from recording 2, Sound Cuts set to match (`truck_sound_cuts.tres`): start 0.0-4.6 s (from 0.95 s, the quiet trimmed), running 1.8-4.6 + 13.4-18.9 + 36.0-40.0 s (a 9.9 s loop at 38 Hz; joins 0.88, 0.64, wrap 0.92), driving 42.0-54.2 s (11.3 s at 67 Hz; wrap 0.87), stop 61.4-64.0 s. His earlier settings (recording 1, start 0.0-7.45 s, the rest at the defaults) are in the message to him, to go back to.
  - Tested on the scratch copy: test_truck_drive.gd all pass (at 5 m/s with W held the driving loop fully in, the running one out); recording 1 with no driving stretch removes truck_run.wav and the truck falls back to the one loop.

## 2026-11-03 — A new sound for bullets hitting metal

- **Mike:** added `assets/sfx/BulletImpactMetal.mp3` (8.0 s, stereo); use it for bullets hitting metal.
  - Mapped: eight rounds into steel, at 0.0, 0.9, 1.9, 3.2, 4.1, 5.2, 6.3 and 7.3 s, each in its own stretch between digital silences, ringing out 0.6-0.9 s.
  - `blender/scripts/cut_bullet_metal.py` (new, kept): each impact from 4 ms before it to where it's rung down to -62 dB, a 30 ms fade, mono, all at a -3 dB peak: `assets/sfx/bullet_metal/bullet_metal_0..7.wav` (0.34-0.85 s). Each written to a temp file and moved in (the open editor imports a WAV as it appears). Blender's audio writer fails ("filling the audio frame failed with ffmpeg") on a length that's an exact multiple of its frame (clip 4 was 18432 samples): such a clip gets one more sample of silence (the same guard added to cut_truck_sounds.py).
- `impact_sound.gd`: "metal" is the eight new clips: the ammo, comms and tower crates, the lone ammo can, the watch tower's legs, stair and cabin (partial_cover.gd, tower_walls.gd), anything with impact "metal". The first set (MetalImpact.mp3) is now "clang", for something heavy against steel that isn't a bullet: `death_fall.gd`'s body hitting a tower railing or landing on its stair, which had borrowed "metal".
- `supply_truck.gd bullet_hit()`: a bullet stopped in the truck now throws sparks and plays "metal" (it was silent).
- Tested on the scratch copy (test_metal_impacts.gd, new): real bullets into the truck (bullet_metal_0, sparks), an ammo crate (_2, sparks) and a lone ammo can (_4, sparks); a "clang" plays metal_impact_1. test_truck_drive.gd and test_tower_deaths.gd still pass.
- **Mike, later: the truck sounds really good, except the idle goes through a lot of weird, inconsistent sounds; and Boot Pause S doesn't work: at 0.2 s it takes about 2 s to move.**
  - The idle: its third stretch (36-40 s) wasn't steady (the engine drifting 28-41 Hz with small revs; levelled, it sounded odd), and the second started at 13.4 s on the tail of a rev. Measured (0.25 s windows): the 9.9 s loop held 37-38 Hz, then wandered 35-42 Hz with bumps to -20 dB over its last 1.5 s. Now from the two steady stretches only, 1.8-4.6 s and 14.0-18.8 s: a 6.3 s loop at 42 Hz, spread 0.5 dB and 0.7 Hz (was 0.8 dB, 1.3 Hz); joins 0.91, wrap 0.88.
  - `cut_truck_sounds.py seamless()`: a wrap lining up at least GOOD_WRAP (0.85) within SEARCH_S of the loop's ends is taken first, so the loop keeps its length; only without one does it look further in.
  - Boot Pause: it counts from the end of the start sound, and the start cut from recording 2 (0.0-4.6 s) ran on with ~3 s of idling after the engine caught. Now 0.0-2.4 s: 1.45 s from the ignition (0.95 s) through the catch, then the pause. With Mike's 0.2 s, it moves about 1.7 s after W. test_truck_drive.gd: set off 2.15 s after W with the default 0.6 s (1.47 s + 0.6 s + rolling the first metre); all pass.
  - truck_sound_cuts.tres updated to these (start 0.0-2.4; running 1.8-4.6, 14.0-18.8; driving 42.0-54.2; stop 61.4-64.0).
- **Mike, later: the idle still sounds weird; it needs a smooth transition, it sounds like different sounds changing.** The two idle stretches have their own character, and the 50 ms joins switched from one to the other.
  - `cut_truck_sounds.py`: a loop's joins between stretches now blend over `blend` (1.0 s, constant power: `handover()`'s `blend_s`), so one melts into the next; Sound Cuts > Engine Running > Blend S (`idle_blend_s`, 0.05-3 s) sets it, for the driving loop too. Measured with the two stretches: in the first second's overlap the two near-identical idles drift in and out of phase and partly cancel (a dip to -24 dB, the fundamental lost to its harmonic, 85 Hz): a swoosh. So a loop's wrap that lines up at least GOOD_WRAP keeps the short matched join (a long blend of a sound over itself does that), and only joins between different stretches get the long blend.
  - Idle now from the one steadiest stretch, 14.0-18.8 s: no change of sound at all, just a matched wrap (0.93). Measured: 4.1 s, spread 0.36 dB and 0.6 Hz (46-48 Hz); at the wrap, steps of 2.2 and 0.9 dB against 0.7 typical and 2.8 at most anywhere. The driving loop: spread 0.58 dB, 0.9 Hz.
  - `supply_truck.gd`: so a short loop of a steady idle doesn't sound the same each time round, its pitch wanders slowly, IDLE_WANDER (1.5%) either way, on two out-of-step swells.
  - truck_sound_cuts.tres: running 14.0-18.8 s only, Blend S 1.0. test_truck_drive.gd and test_sound_cuts.gd pass.

## 2026-11-03 — Supply truck: the hatch on the right, a squadmate riding as passenger, Hatch and Crane orders

- **Mike:** move the hatch to the right side; let him send a unit to ride inside (not drive yet): with a group selected only one goes in, by the passenger's side of the cab; and in the truck his commands change: Hatch, Crane.
- **Hatch:** `supply_truck.py` HATCH_AT (1.48, 0.18) -> (1.48, -0.18): the right (passenger's) side of the roof. Re-rendered.
- **Seats** (`supply_truck.gd`): the getting-in-and-out sequence is now per seat (`class Seat`: the driver's, side -1, and the passenger's, 1), each with its occupant, rider, door, step, saved collision layer/mask and `want_out`; `driver` and `passenger` read the seats. Doors are shared: one rider at a time per door (`_door_free()`). Getting out, by one's own door if there's room, else the other door if that seat's empty and idle, else out the back at once.
  - Walking round to a door (`_route_to_door()`): if the truck's in the way (a squadmate on the far side pushed into its side and never got there), round its front or back, whichever's shorter, by corners ROUND_M off it, each passed within CORNER_M; a squadmate gets SQUAD_WALK_GIVE_UP (4) x WALK_GIVE_UP_S before it's given up.
  - `board(square)` (a squadmate, the passenger's seat; false if taken), `passenger_free()`, `unload(square)` (in: out once it's stopped; on its way: it stops), `busy()`. `vehicle_order(id)`: Hatch and Crane, a placeholder (prints) until they're worked out.
- **Squadmate** (`squadmate.gd`): `riding`, `walk_to` (as the player's: round things to the door with _head_for(), straight through the cab's side once it's off everything solid), `order_ride(truck)`. Any other order (`_take_orders()`) gets it out: once the truck's stopped it climbs out by its door and carries the order out.
- **Command mode** (`command.gd`): a click on a truck (`_vehicle_at()`) sends only the one of the selection (nobody selected: everyone in the circle) nearest the passenger door to ride; the seat taken or nobody to send, a red ping. Orders with nobody selected leave anyone riding alone (`_order_targets()`); select one (click the cab) to get it out with an order. While the player's driving (`player.gd vehicle`, set once the door's shut), ORDERS shows VEHICLE_ORDERS, Hatch and Crane, instead of the squad's orders, and DEPLOY is hidden (`_place_menus()`); they go to the truck (`_give_vehicle_order()`).
- Tested on the scratch copy (test_truck_passenger.gd, new): three selected on the left side, a click on the bed: only the one nearest the passenger door goes; it walks round and is in after 5.3 s, the passenger door opening to 75 degrees and shutting (the driver's never moves), hidden, in the passenger seat; a second click: nobody else goes. The player gets in: ORDERS are Hatch and Crane, no DEPLOY; Hatch pressed (no error); an order with nobody selected leaves the passenger; it drives off with the passenger in its seat; ordered out while moving, it stays in; stopped, it gets out by its door (75 degrees) and walks to where it was sent (0.07 m off, 6 s after getting out: the truck had driven on past). test_truck_drive.gd (all pass), test_height_smoke.gd (no script errors), test_click_orders.gd, test_ammo_order.gd, test_menu_toggle_crate.gd and test_place_back.gd behave as before.
  - (A type slip in `_route_to_door()` was a parse error for a minute, which would have broken the truck in the editor: fixed.)

## 2026-11-03 — The supply truck delivered by helicopter

- **Mike:** make the truck deployable by helicopter, just like soldiers.
- `radio_terminal.gd`: Deploy > **Vehicles** works now (it was "Vehicles (soon)"). A VEHICLE REQUEST panel like the others: one slot (VEHICLE_TYPES: Supply truck; press it for the pop-out, a quick click gives one), readied over `seconds_per_vehicle` (1 s for testing, as the others), then Send helicopter: a ghost of the helicopter with the truck under it, nose east, follows the mouse to mark the LZ (`_vlz_ok()`: the truck's footprint wholly inside the play area and on nothing solid, layers 1 and 4; red if not); a click sends it (`_send_vehicle()`), right click or Esc goes back. The desk's timer shows "Supply truck  0:01" / "Supply truck READY" with the troops and crates.
- `scripts/sling_drop.gd` (new): the run, as a troop insertion's (insertion.gd's numbers): in from the west, nose east, at cruise height, with the truck SLING_M (7 m) under it on four cables (drawn from its hook to the truck's lifting points); slowing and coming down over the approach until the truck's HOVER_M (1 m) off the ground over the LZ; lowering it the rest of the way over LOWER_S (2 s); letting go (`set_down`: the cables gone); hovering RELEASE_S; climbing away east and removed. Its hull never goes solid (it never lands).
- `supply_truck.gd`: `airborne` and `altitude_m`: slung, it's off every collision layer (`set_airborne()`), can't be got into or sent a passenger, is drawn bigger by its height (CLIMB_SCALE_PER_M, 1%/m, as the helicopter), and its shadows lie out on the ground below. command.gd's truck click skips one still in the air.
- Tested on the scratch copy (test_truck_heli.gd, new): Vehicles shows the request; the slot filled, readying, then ready (Send on); the LZ ghost OK in the open, red on a crate and off the field; sent: the request cleared, a helicopter and the truck on their way, the truck under it all the way in, up to 18 m (drawn 1.18x), off every collision layer; set down at the LZ after 7.9 s: on the ground, solid (layer 1, mask 5), nose east, its size back to 1; the helicopter gone 8.1 s later; the player gets in and drives it. test_truck_drive.gd, test_truck_passenger.gd, test_tower_drop.gd, test_early_deploy.gd and test_tower_radio.gd behave as before.

## 2026-11-04 — Supply truck: S starts the engine, and the crane

- **Mike:** pressing S also starts the truck. And the crane: in command mode a circle shows round the crane (how far it picks up a crate, his red example circle, "doesn't have to be exact"); select Crane, then click a crate in it, and only then does the passenger get out and go to the spot he marked (his blue box, beside the crane's controls on the passenger's side); after half a second standing there, stabilisers come down; the crane starts lifting. A hidden boom inside the current crane model slides out to reach. It loads the furthest back bed spot first, then the nearer, and unloads the opposite way. The driver can still get out meanwhile.
- **S:** `supply_truck.gd`: the ignition's W *or* S (the same start, boot pause and all).
- **Order of events** (`CranePhase`): Crane (`vehicle_order("crane")`; false and a red ping if nobody's riding as passenger) arms it and the circle shows in command mode (REACH_RING red, `crane_reach_m` 3 m from the slewing axis: Mike's drawn circle was ~2.1 m radius and didn't take in the crates he drew beside the truck, so 3). A click (command.gd `_crane_click()` ahead of the squad's own clicks; units still select): on a crate (with a pallet) in the circle, a load job; on clear ground in the circle, an unload job (nothing solid under the 0.84 m footprint); outside the circle, a full bed (counting jobs already queued), an empty bed: refused, a red ping. A job taken pings green. Then: WAIT_STOP (the passenger gets out once it's stopped, always by its own door, the door sequence as getting out) -> WALKING to STATION_M (0.75, 1.12) -> SETTLING `station_hold_s` (0.5 s) -> DEPLOYING (`_stab` 0..1 over `stabilizer_s`: the beams run out from the pedestal then the jack pads push down and widen) -> WORKING -> STOWING (boom in, turret forward, then the stabilisers up) -> RETURNING (the operator walks back and gets in: the same steps as boarding). Nothing more for IDLE_STOW_S (1.5 s) after the last job counts as finished; a click while it's stowing puts the stabilisers back down.
- **A job** (`JobStep`): REACH (the turret slews at `crane_slew_dps` by the shortest way, the boom slides out at `boom_mps`; it never goes in past the arm, ARM_M 1 m), LIFT (the crate comes off, to CARRY_M 1.9 m, drawn bigger by its height as the helicopter's and its shadow pushed out along the sun, turning to line up with the truck), SWING, LOWER onto the bed spot (SLOT_X_M: -1.53 then -0.61, from supply_truck.py's pallet layout; BED_Z_M 0.8 high) or the ground at the click. The boom: two sections drawn under the arm's sprite (so what's inside the arm is hidden) and a hook block, a sweep shadow; the turret's sprite is now under `_rig`, turned about the axis, z 4 over the crates on the bed.
- **Crates** (`crate.gd`): `mount()` / `unmount()` and `height_m`. Mounted, a crate's a child of the truck (so it rides it), not solid, out of the "crates" group (nobody can click it, take parts, unstrap it or send enemies to it), its pallet and load drawn at the truck's body level, its shadow out along the sun by the height (and redrawn as the truck turns). Unmounted it's put back solid and in the group, aligned with the truck.
- **While it's working** the truck can't be driven (`locked`: speed held at zero from when the operator's out until it's back in). The driver can get out (F): the engine goes off, the order's put away (`_armed`), and the operation carries on to the end. The operator given another order (a click on it, then an order): `unload()` lets it go, the jobs are dropped (a crate on the hook goes in its bed spot if the hook's over the bed, else on the ground), the crane stows itself. If it's killed, the same; if it can't get to the controls in 8 s it gives up the same way.
- Tested on the scratch copy (test_truck_crane.gd, new; 33 checks, all pass): S starts the engine; click out of reach, onto empty ground with nothing on the bed, and a crate twice (no second job): refused / not queued; two crates: phases in order, 0.5 s standing at the station before the stabilisers, the boom out 1.8 m, the driver out meanwhile and W doing nothing, both crates on the bed (the first at -1.53, the second at -0.61), mounted, not solid or in the group, stowed after, the operator back in the seat hidden; a third refused with the bed full; unloading: the nearer crate comes off first, both on the ground solid and in the group at the clicked spots, the bed empty; an operation started then the operator ordered away: the crane stows and it's its own again. test_truck_passenger.gd, test_truck_drive.gd, test_truck_heli.gd, test_metal_impacts.gd, test_can_crate_click.gd and test_menu_toggle_crate.gd behave as before. A screenshot run (tests/screenshots/shot_truck_crane.gd) of the circle, the stabilisers coming down, a crate swinging on the boom and both on the bed looks right.
- Not done (Mike's to say): sounds for the stabilisers, boom and lift; the Hatch order; whether the operator stays out and the stabilisers down between jobs rather than stowing after IDLE_STOW_S; picking up crates under another order (the squad's own unstrap/build clicks still work as usual with the crane not armed).

## 2026-11-04 — Supply truck: crane slowed down, the passenger's side, the HUD, no clipping

- **Mike (pictures of the bed, the exit box, and the cab corner):** the crate and its contents' shadow should fall on the truck's bed and out past its back; the crane's far too fast, slower and more realistic (his vision: later the driver's automated and the squad commands drop-offs; for now he drives and the passenger runs the crane), the operator's gun disabled while he does, the stabilisers slower; Crane offered among the normal orders when a passenger's in the truck and the player's outside it; the circle 20% smaller; the passenger's side blocked (the box he drew) and he won't get out, it's cancelled; the whole truck's the click in command mode, with a small HUD of how many units are in it; and the passenger clipping the cab's corner getting out.
- **Shadows on the deck** (`supply_truck.gd _draw_bed_shadow()`): each bed crate's pallet and load, swept along the sun from the deck up to their tops, cut to the deck, one CanvasGroup (so overlaps aren't doubly dark) over the body and under the crates (z 3, added before them). Past the deck's edge the crate's own ground shadow, pushed out by its height, shows (crate.gd, as before).
- **Slower:** turret 22 deg/s (was 120), boom 0.4 m/s (1.8), lifting and setting down 2.5 s (0.7), stabilisers 4 s (1.4); two crates now take about 45 s start to finish (test). Reach 2.4 m (was 3). All exports in the Crane group.
- **Rifle** (`soldier.gd weapon_away`, `squadmate.gd`): the operator's rifle (and its shadow) is hidden and it won't fire from the moment it's out of the cab until it's back in or let go (`_drop_operator()`).
- **Normal orders** (`command.gd`): a Crane button after the squad's orders while the player's out of the truck and a truck within earshot has a passenger (`crane_available()`), pressed to the nearest such truck; while driving, Hatch and Crane as before. The armed crane's clicks go to the truck whoever's driving; it's put away when the driver gets out (as before).
- **Blocked side:** `EXIT_BOX_M` (1.54, 0.945), `EXIT_BOX_SIZE_M` (1.24 x 0.51) is Mike's box in metres, from his picture, on the passenger's side; the spot at the crane and the clear spot below are checked too (layers 1 and 4, ignoring the truck and the operator, so a square, crate or sandbag in them counts). Blocked when the order's clicked: refused, a red ping. Blocked when the truck's stopped and it's time to get out: cancelled, a red ping at the box (`refuse_ping()`); the operator doesn't go out the back any more (the other exits still serve the normal passenger).
- **HUD and select:** a click anywhere on a truck in command mode (`_vehicle_at()` was already the whole truck) shows "Units inside: n" over it for 3 s (`_show_truck_hud()`; "(1 at the crane)" if the operator's out); with the passenger seat taken it selects the rider (shift toggles) instead of the old red ping, so they can be given orders.
- **No clipping** (frames of the exit, tests/screenshots/shot_truck_exit.gd): the open door hangs over where the rider stood and walked, and then swung shut through them. Now a rider waits at `CLEAR_M` (outside the door's swing: 0.95+ m from its hinge) while it opens, goes in square through the gap (door spot, then the seat: `Seat.leg`), and coming out goes through the gap and on to the clear spot before the door shuts (`SWEEP_CLEAR_M`); `_get_out()` also needs the clear spot free. The driver ends about half a metre further out than before. Measured by test_truck_crane.gd (distance of the rider's middle to the door panel every frame): 0.32 m getting in, 0.30 m out and back in (a square's half-width is 0.2).
- Tested on the scratch copy: test_truck_crane.gd (now 46 checks: S start, circle 2.4 m, slow settings, HUD and rider select, an exit box blocked: refused, the door gap, the rifle, Crane among the normal orders with a passenger and the player out), test_truck_passenger.gd, test_truck_drive.gd (its two driver-exit checks now expect the clear spot, not the door spot), test_truck_heli.gd, test_metal_impacts.gd pass; the older command/crate tests (click_orders, menu_stack, orders_state, can_crate_click, menu_toggle_crate) show no errors. Screenshots (shot_truck_crane.gd, shot_truck_exit.gd) look right.

## 2026-11-04 — Supply truck: selecting Crane deploys it; it stays out until deselected or driven off

- **Mike:** selecting Crane is when the stabilisers come out. They stay out until Crane's deselected or the driver starts to drive off; before it moves they have to come back up, then the vehicle starts.
- `supply_truck.gd`: Crane pressed (no crate click needed) arms it and starts the operation at once: the passenger gets out once it's stopped, walks to the controls, 0.5 s, stabilisers down, then it waits deployed (`CranePhase.WORKING`) for crate and ground clicks. Refused (red ping, nothing starts) with nobody riding, while it's still putting away, or if the passenger's side is blocked (the exit box, the clear spot, the controls).
  - Put away (`_end_crane()`) when Crane's pressed again, or when W or S is pressed with the driver in (it also deselects Crane): jobs still waiting are dropped, the one on the hook is finished, the boom goes in and the turret turns forward, the stabilisers come up, the operator walks back in; the truck stays locked until all that's done (`locked`), then drives off as usual (held W carries it on). Pressing Crane while it's stowing changes its mind and deploys again; while the operator's walking back in it's refused.
  - Gone: the 1.5 s auto-stow after the last job (IDLE_STOW_S) and putting Crane away when the driver gets out (it stays deployed, with the driver out or in; the Crane button among the normal orders deselects it). Operator killed or ordered away: it stows, and Crane has to be selected again.
- test_truck_crane.gd rewritten for this (51 checks): nothing before the order; blocked exit box refuses Crane; deploying phase by phase with no crate clicked; two crates loaded (driver out meanwhile); still deployed ten seconds later; unloading; W: stowing, returning, idle, and only then moving (no movement before), 0.4 s later it's rolling; deselecting; the operator ordered away mid-deploy. test_truck_passenger.gd, test_truck_drive.gd, test_truck_heli.gd pass.

## 2026-11-04 — Supply truck: squadmates drive it, seats by the side clicked, and it drives itself by road

- **Mike:** one unit selected, a click on the right of the cab sends it to the passenger's seat, on the left the driver's; several selected and just the truck clicked: two go, a seat each. With a driver in it the truck can be told where to go, as a unit would be (click the truck, then the ground). Work on the AI of driving, since there'll be a lot of it: always stay on roads, and back into and drive forward into spots reasonably.
- **Seats** (`supply_truck.gd`): `seat_free(side)`, `board(square, side)` (squadmate.gd `order_ride(truck, side)`); a squadmate can take the driver's seat now (`ai_driver`; `player_driving` for the keyboard's). `unload()` works for both seats (the driver stops first); `dismount_all()`.
- **Clicks** (`command.gd _click()`): a click on the truck, anywhere on it, shows the HUD (now counting both seats). With nobody selected it **selects the truck** (a box round it, and its planned path while it's driving; hidden riders aren't click targets of their own any more). With units selected: one goes to the seat on the side of the cab clicked (left y<0 driver, right passenger), two or more fill both seats (each seat the nearest unit to its door, the clicked side's first); a taken seat is a red ping. With the truck selected: a click or right click on the ground sends it (`order_drive_to()`; red ping if only the player's driving it); **Stop** halts it, **Disperse** gets everyone out. Units selected win: the click sends them, not the truck. Space let go or a unit selected drops the truck selection.
- **The driver's brain** (`scripts/vehicle_ai.gd`, new; it's `RefCounted`, one per truck): all in metres on the rear axle's path.
  - Roads (group "roads", road.gd): a graph (curves sampled every 1.5 m, ends and crossings joined), the route by A*, driven in the **right-hand lane** (1.3 m off the centre line).
  - Joining the lane from where it is: a Hermite spline if the way's gentle, else the shortest **Dubins path** (an arc, a straight, an arc, or three arcs for close poses; none sharper than the truck's turning circle, 5.3 m radius with a margin); on a road a join must stay within 3.4 m of its centre line, so a wrong-way start is a **K-turn** instead (`_reposition()`: short forward/reverse moves, each side, up to two, the cheapest that lets it join): B in the test turns round with two changes of gear and stays within 4.1 m of the centre line.
  - Spots: a click on the asphalt stops in the lane, the middle on the click. A click off the road: nearer than 5 m, drives **forward in**; farther, **backs in** (pulls past, stops, reverses along a curve, nose out toward the road); the other if the first can't be driven. Several entry angles are tried (square first; a tight spot beside a road can't be turned into square-on, so it angles in, 0.3 per degree off square in the cost) and several places to leave the lane; the cheapest wins; a path must stay in the corridor from the road's far side to 2.5 m past the spot (no loops across the field); the truck can also go straight in from where it stands.
  - Obstacles: every candidate and the lane are checked against whatever the truck would hit (layers 1 and 4, its whole body at every 1 m), so it plans round blocked spots and stops 2 m short of anything on its route (`short`); found while testing: a sandbag wall in Mike's map reaches across the road at x 36 m.
  - Following: pure pursuit (the same steering formula steers a reverse), speed set by the bends ahead (2 m/s² lateral), braking to the end of each run, 5 m/s on a road, 3 off it, 1.5 reversing; a 0.6 s pause at each change of gear; blocked for 2 s it backs off and plans again, three goes, then gives up (`failed`). The truck's own physics are as the player's (`_drive()`), the AI sets its target speed and steering; the engine starts first and it waits for the crane to be put away.
  - Planning takes at most ~120 ms.
- Tested on the scratch copy: test_truck_ai.gd (new, 20 checks): no driver, no drive; along the road (0.35 m off, 4 m/s); behind it (K-turn, 0.4 m); forward into a spot 4.3 m off (0.25 m off); backed into one 7.6 m off (0.16 m off, nose out); out of the bay and along the road; a crate across the lane (stops 1.1 m short, doesn't hit it). test_truck_seats.gd (new, 19): seats by the side clicked, taken seat refused, truck selected / HUD, a click and a right click send it, Stop, units selected win, Disperse, three selected fill both seats. test_truck_passenger.gd (now two go, driver sent out again), test_truck_crane.gd (the click selects the truck), test_truck_drive.gd, test_truck_heli.gd, test_metal_impacts.gd pass; the older command tests show no errors. Screenshots (shot_truck_ai.gd): selected with its path drawn, mid-reverse, parked.
- Not done: other traffic (a second vehicle in the way is just an obstacle to stop short of), junction rules, speed changes on bad road condition, a way to choose the heading it parks at (it picks), the tower's own legs as parking-bay walls.

## 2026-11-04 — Supply truck: crates are picked up from two squares, and set down by holding Crane

- **Mike (pictures with blue boxes and green ghosts):** the two boxes beside the bed are where a crate has to be for the crane to take it, instead of the circle. Setting crates down: holding Crane gives two options, 1 or 2 boxes; then a green ghost of the drop-off shows on the right or left depending where the mouse is; the ghost's spot is by the bed's rear.
- **Pickup squares** (`supply_truck.gd` PICKUP_X_M (-2.54..0.32 along the truck) x PICKUP_Y_M (0.6..1.95 out), both sides, measured off Mike's picture): a crane click on a crate whose middle's in one of them takes the job; a crate outside: refused; a click that isn't on a crate isn't the crane's any more (the squad's own click happens, rather than a red refusal). Drawn in command mode, once Crane's selected, as two red boxes (the circle's gone); `crane_reach_m` (3.6 m now) is just how far the boom can go (the far corner's 3.4 m).
- **Setting down:** holding the Crane button (driving, or the one among the normal orders) opens a pop-out (HoldPopout) of **1 box / 2 boxes** (2 greyed out with one loaded; nothing opens with none on the bed); a quick click still selects or puts Crane away. Choosing one starts the placing mode (`command.gd _crane_drop_truck`): a ghost follows the mouse on whichever side of the truck it's on (`_crane_drop_side()`, left / right of the truck's own middle), a green square per box (red if the ground's taken), 0.84 m, 1.3 m out from the truck's middle (DROP_Y_M), at the bed spot (SLOT_X_M) each crate comes from (the nearest first). A left click sets them there (`crane_drop(count, side)`: deploys the crane if it isn't, queues the unloads, pings the spots), right click or X cancels; so does Space let go or pressing Crane. Banner: "CRANE click to set 2 boxes down on the right".
- The ground click that used to unload is gone. `_unload_slots()` takes waiting unloads into account, so a second drop doesn't claim a crate that's spoken for.
- Tested on the scratch copy: test_truck_crane.gd (updated, 62 checks): crates in the squares loaded (right and left side, the third outside refused), loaded count, drop spots for 1 box right and 2 boxes left at the right bed spots, 3 boxes refused, a crate on a spot blocks it, the pop-out, the ghost's side following the mouse, a click queues one unload, the nearer crate comes off first on the right, the other on the left. test_truck_seats, test_truck_ai, test_truck_passenger, test_truck_drive, test_truck_heli pass. Screenshots (shot_truck_drop.gd): the two red squares with crates in them; the 2-box ghost beside the bed.

## 2026-11-09 — Battle log: the supply truck and who's in it

- **Mike:** does the battle log pick up the supply truck and what everyone inside it is doing? It didn't: the truck was just a solid object (an `M` line rewritten each second as it moved), and squares inside it looked like squares sliding across the map with a frozen state. Now it's logged in full (log **format 2**).
- `battle_log.gd`: anything in the "vehicles" group with a `log_status()` gets
  - **`V <o#> <x> <y> <heading> <speed>`** lines (every 0.2 s once it's moved 0.05 m, turned 5° or changed speed by 0.2 m/s);
  - **its own `~` lines**: `engine`, `slung`, `driver` / `passenger` (who's sitting there), `driver_door` / `passenger_door` (`<step>,<unit>` while someone's getting in or out: TO_DOOR OPENING STEP_IN CLOSING, OPENING_OUT STEP_OUT CLOSING_OUT), `*_wants_out`, `ai` / `ai_to` (the squadmate driver's status and destination), `crane` (phase), `armed`, `operator`, `job` (`load,o12,LIFT`), `jobs`, `bed`;
  - **`O o# ...`** for orders to it: `drive <x,y> <driver> ok|refused`, `stop`, `dismount`, `crane on|off`, `lift <x,y>`, `drop <count> <side>`, `hatch unbuilt`.
  - Each square has a **`vehicle=`** key while it's in or by one: `o#:driver`, `o#:passenger`, `o#:boarding_<seat>`, `o#:leaving_<seat>`, `o#:crane`, then `-`. (A `~` key that's gone is now written once as `key=-`.)
  - The truck's `M` line isn't rewritten as it moves (only for a new class or extra), and it isn't written as gone (`G`) while it's slung under a helicopter (off every layer). Crates swinging on the hook don't get an `M` line every tick (`_ref()`).
  - The legend in the file's header explains all of it.
- `supply_truck.gd`: `log_status()`, `seat_of()`, and the `O` lines from `order_drive_to()`, `vehicle_order()`, `crane_click()`, `crane_drop()`, `dismount_all()`; `command.gd` logs the truck's Stop.
- Battle-log skill: `summarize.awk` reads format 2 (a Vehicles section: distance, top speed, orders, crane jobs; the seats, AI driving and crane phases in the timeline; `ai=failed` flagged); `SKILL.md` and `ai-reference.md` explain the new lines.
- Tested on the scratch copy: `tests/test_battle_log_truck.gd` (new, 20 checks): two squadmates get in (driver and passenger), it's sent along the road, Crane on, a crate lifted on, put away, slung a moment, Disperse; the file read back has one truck `M` line and no `G`, `V` lines to 4 m/s, the seats, door steps, engine, ai, crane phases, operator, job and bed, slung 1/0, each square's `vehicle=` sequence, and the seven orders. The awk summary of that log reads correctly. test_battle_log.gd (no errors; the truck in main.tscn now shows), test_truck_crane.gd and test_truck_seats.gd pass.

## 2026-11-09 — The truck in command mode: get in from the circle; Park instead of selecting the truck

- **Mike:** with the command circle open and one or two units in it, clicking the truck should send them in (one alone the same). With a unit driving, you're not driving the truck, you're commanding its driver: a drive order (a better word welcome) that shows only when a truck with a driver is in the circle; pressed, a ghost rectangle of where the truck will end up and which way it faces; the AI has to get it to that spot at that orientation.
- **Getting in** (`command.gd _click()`): a click on the truck goes to the selection, or with nobody selected to whoever's in the circle (not already riding). One unit: the seat on the side of the cab clicked, or the other if that's taken (it used to be refused). Two or more: the free seats, each the nearest unit to its door (so with three in the circle, the two nearest go). The units-inside HUD still shows.
- **The truck isn't selectable any more** (`_truck_sel`, `selected_truck()`, the ground click / right click that sent it, Stop and Disperse on it: gone). **Park** (named so: the ghost is where it parks and which way it faces) is among the orders while a truck with a squadmate at the wheel is in the command circle (`_park_candidate()`). Pressed: a ghost of the truck (its outline, the cab line, an arrow the way it faces; green, red where it won't fit or is outside the play area) follows the mouse at the truck's own heading; the scroll wheel turns it 15° a notch (the Attention / Deploy grid); a left click sends the driver (`order_drive_to(point, heading)`), right click or X cancels; a click on a spot it can't reach is a red ping and the ghost stays. While a squadmate drives, command mode shows its route and a faint ghost where it'll park. **Disperse with nobody selected** now also gets everyone out of trucks in the circle (it was the way to empty the selected truck); the driver stops first.
- **Parking at a heading** (`vehicle_ai.gd`): `drive_to(point, fresh, heading)`; `_finish_pose()` finds the cheapest way to end exactly there, from places along the lane near the spot (or from where the truck is, within 15 m): one move (forward in, or backing in from a stop on the lane) or two (back up then drive in, or drive on then back in: found by running the truck away from the spot, since a bicycle's path is the same either way). All compared on cost (reversing ×1.5, 4 m a change of gear), no reverse over 15 m (no more 40 m reversing loops), every move checked against anything solid **and now the play area's edge** (`_body_free()`: the truck stops dead at the edge, so plans that brushed it stalled). Each ends with 2.5 m straight; the follower's aim point now runs on past a path's end along it (it used to aim at the end point, finishing pointed at it, up to 12° off when backing in). Parked more than 0.45 m or 4° off, it plans again from there (up to 3 times).
- Battle log: `O o# drive <x,y> <heading|-> <driver> ok|refused`; `ai_heading` in the truck's ~ lines. The truck "stop" order line is gone (nothing sends it now).
- Tested on the scratch copy: `tests/test_truck_park.gd` (new, 23 checks): one in the circle to the driver's side; one more to the taken side takes the other seat; three in the circle, the two nearest go; Park only with a driver; the ghost at the truck's heading, a notch is 15°; seven parks, all arrived within 0.4 m and 3.5° (ahead on the road; behind it facing west, a K-turn; off the road nose out; nose to the road, backed in; at 45°; just behind; across the road facing north), planning 113 ms at most; a crate in the spot: red, refused, ghost stays; Disperse empties it. test_truck_seats.gd (rewritten for the new rules), test_truck_crane.gd, test_truck_ai.gd pass; test_truck_passenger, test_truck_drive, test_truck_heli show no failures. test_battle_log_truck.gd (updated for the new drive line) passes. test_click_orders.gd (an older command test) hangs: it needs six squadmates in main.tscn, which now has two, so it errors on `squad[5]` and never quits. Not from this change; it needs updating for the current level.

## 2026-11-09 — Park: a proper search for the way in (hybrid A*); next to a crate; the order that stopped short

- **Mike (a screenshot and a log):** the truck got hung up on a box when it had to end right next to it; a test for parking near a crate from different starting points; the way there as fast and efficient as possible; and an order where it drove a little and stopped.
- **The log showed:** the first Park (9 m away, beside a crate, facing west) was a 60 m, 28 s drive: back 4 m, a loop right round the south of the field, back 10 m, then in. The last (to the road, east) drove toward the field's west edge and stopped after 3 s ("arrived"): the old way in left the field, was cut short at its edge, and the shuffle from there found nothing. The old way (`_finish_pose()`: one or two curve shapes from places along the lane) is gone.
- **Now** (`vehicle_ai.gd`, "Parking"): **hybrid A*** (as self-parking cars use). Moves are 1.39 m arcs (forward or reversing; straight, 5° or 15° either way); 72 headings, a 0.5 m grid. Cost is **time** as the follower really drives it: 5 m/s on a road, 3 off it, 2.5 m/s turning, 1.5 reversing, 1.8 s a change of gear, plus 0.15 s a metre (of two nearly as quick, the shorter: fewer loops), plus a little for passing within 0.3 m of something. The estimate of time left: the larger of a Dijkstra over the field (for something that could turn on the spot, round what's in the way) and the turn still to make at full lock. Collisions: a 0.1 m clearance map of everything solid on the truck's mask (rectangles, circles, capsules, polygons; read once per plan), the truck as 8 discs; 0.12 m kept spare, except on the last straight in. Near the spot it tries driving or backing straight in (a smooth curve, checked bend by bend — `_drivable()`: a short curve had been hiding a 90° kink between its sample points, which is what sent the truck crawling at full lock and ending 2.7 m off), ending on 2.5 m of straight (1 m where that won't fit). It keeps looking until nothing left could be quicker.
  - **No freeze:** it runs 5 ms a tick (`think()`, from supply_truck.gd) while the engine starts. Most plans take 20–700 ms of searching; the hardest in the tests (backing in by the field's west edge) about 3 s, so that truck waits ~10 s before it moves. (A worker thread was tried first: script ran ~50 times slower there.)
  - **Following** (parking only): shorter lookahead (1.6 m+), turns at 2.5 m/s at most, the last metres at a crawl, slowing only when more than 0.25 m off the line, every run followed to within 0.08 m of its end. A 32-bit/64-bit float slip in the estimate's Dijkstra (it threw most squares away) found and fixed on the way.
  - Battle log: `ai=planning` while it searches; `ai_stuck` (times stuck and backed off on this order).
- Tested on the scratch copy (headless, `--fixed-fps 60` so it doesn't wait on the clock): `tests/test_truck_crate_park.gd` (new): a crate where Mike's was; parked beside it, nose to it, tail to it and on its road side, each from four starts (on the road both ways, south, west), and Mike's last order: all 17 arrive within 0.32 m and 4°, never stuck, the crate never touched, 5.5–24.8 s each (260 s in all, from 592 s on the first working version), no frame over 11 ms while planning. U-turns loop round (36–40 m, ~18 s): about as quick as a three-point turn here, so allowed. test_truck_park.gd (all seven within 0.2 m and 2.7°), test_truck_seats, test_truck_ai, test_truck_crane, test_battle_log_truck pass; test_truck_passenger, test_truck_heli no failures; test_truck_drive passes in real time (with `--fixed-fps` one engine-sound check fails: the audio runs on the real clock).
- Not done: the parking search doesn't keep to the right-hand lane on the road (it just drives faster there); a truck parked in a tight corner may wait several seconds while it plans.

## 2026-11-09 — The RADIO menu stays open

- **Mike:** at a radio station, always stay in the main menu (Deploy, Command, Dish, Exit): changing the dish bumped you out and you had to open it again; same after sending a helicopter from Deploy; for all of them.
- `radio_terminal.gd back_to_menu()`: sending troops, equipment or a vehicle (after the LZ / drop click) now comes back to the RADIO menu instead of closing it; the player stays busy (no firing) while it's open. Esc **or X** on a request (troops, equipment, vehicles) steps back to the menu; at the menu they close it. Exit, F, walking off the box and Space still close it; Command still goes into radio command mode (its Back returns here, as before).
- `radio_station.gd`: locking the dish's heading in (a click on the wheel, or F) comes back to the RADIO menu (X already did); the terminal leaves F alone while the wheel's up, so F locks the dish rather than reopening the menu under it. The click no longer frees the player on release (the menu's open).
- Fixed on the way: the drop-zone ghost's draw could run once after it was cleared (a script error when a drop was sent).
- Tested on the scratch copy: `tests/test_radio_menu_stays.gd` (new, 13 checks): troops, equipment and a vehicle each sent and back at the menu (ghosts gone, player busy); the dish locked by a click (still at the menu after the button comes up) and by F; Esc and X on requests back to the menu; X at the menu and Exit close it. `test_dish_back.gd` (now places its own station: main.tscn has none) passes; test_truck_heli no failures. `test_radio_cam.gd` hangs the same way (it expects a station in main.tscn): not from this change, needs updating.

## 2026-11-09 — Command menus folded away to start with

- **Mike:** make the command menu closed as the default.
- `command.gd _menus_open` starts false: holding Space shows the command circle and the little triangle beside the player, with ORDERS and DEPLOY folded away; a click on the triangle opens them. As before, they stay as they were left from one go in command mode to the next (until the level's reloaded).
- Tested on the scratch copy: test_menu_toggle_crate.gd: on entering command mode ORDERS and DEPLOY are hidden, the triangle shows; one click shows both; leaving and coming back keeps them shown; another click hides them. (Its printed labels were written for the old default: "stays folded" now reads as "stays open".)

## 2026-11-09 — Park ghost: the divider where the bed starts

- **Mike:** the truck's Park ghost's divider should be where the pickup box (the bed) starts.
- `command.gd _draw_truck_ghost()`: the line across the ghost is at the bed's front edge (`supply_truck.gd BED_FRONT_X_M`, 0.05 m behind the middle; the deck shadow uses the same), not 1.25 m back from the nose. The arrow still points the way it'll face.
- Checked headless: the ghost draws with no errors, the divider 0.05 m behind the middle (4.3 px). Not looked at in a window.

## 2026-11-09 — A 2-square-mile field, the enemy drop by helicopter, road junctions (T and crossroads)

- **Mike:** T and 4-way intersection road tiles that snap with the current road tiles, and the playable map extended to 2 square miles. Asked: square (2 sq mi of area, 2.28 km a side), the current level in the middle; and change the enemy drop HUD: pick up to 10 units, then click anywhere on the playable map, and an enemy helicopter drops them off there.
- **The field** (`world.gd`): `ARENA_SIDE_M` 2276 m (the square root of 2 miles), `ARENA` that square centred on the old field's middle (1920, 1080 px), so main.tscn's level sits in the middle with new grass all round and nothing in the scene moved. Most scripts only kept things inside it and needed nothing. The camera already followed the player and clamps to the edge; at its furthest zoom you see about 105 m. Friendly helicopters already started 70 m from their LZ, so they arrive as quickly as before. Comments that described the old 45 × 25 m field updated (field.gd, game_camera.gd, Start Here).
- **The parking search on a 2 km field** (`vehicle_ai.gd`): it now works in a window round the truck and the spot (`HA_WINDOW_M` 25 m to spare; its edge is a wall to it): a clearance map of the whole field at 0.1 m would have been 500 million squares. A Park up to `HA_FAR_M` (150 m) away goes straight to the search; farther, the ordinary road planner drives it there by road first and the search parks it once it's close (`_run_done()`'s shuffle). Its estimate (the Dijkstra) now also counts COST_PER_M (it was a third under the search's real costs, so a long trip's search spread everywhere and gave up), runs a slice a tick like the search (on a 120 m trip's window it froze the game 0.7 s), and a 32-bit rounding slip in it that looped forever is fixed. The last straight into a spot is checked against the truck's exact outline (the discs bulge 0.47 m past its bumpers along its middle: a spot 0.5 m off a crate only fitted by luck of the grid's rounding).
- **Enemy drop** (`enemy_spawner.gd`, rewritten; the old patrols-from-the-right-edge and their formations are gone; `patrol.gd` stays for enemy.gd but nothing makes one now): the ENEMY DROP panel, How many (1–10), **Drop by helicopter**: a ghost helicopter (enemy blue) follows the mouse, red off the field; a left click sends an enemy helicopter (the same one, tinted blue) to land there (`insertion.gd` with `enemy` on: it comes in from the west like ours); each enemy steps out, walks to a post a step clear of the door (enemy.gd RETURN) and stands calm, fighting anyone it spots. Right click, Esc or X cancels; command mode cancels it too. The player's busy (no firing) while placing. Enemy health is the spawner's (4 in main.tscn). test_battle_log.gd and test_debug_numbers.gd now place their enemies directly.
- **Road junctions:** `scenes/road_junction.tscn` (`scripts/road_junction.gd`, @tool): Kind T or Crossroads, Condition as a road's; a 12 m square tile (`blender/scripts/road_junction.py`, all 8 rendered: see the Asset List) with arms to its edges, 6 m out: the through road east and west, the T's stem south (down), the crossroads' north too; turn it with the rotate tool. Drag a road's first or last point within 1 m of an arm's end and it clicks on, its handle turned to carry straight on out of the arm (road.gd `_nearest_end()` takes junction arms as road ends). It's in the "roads" group with no curve (bullets and footsteps on it count as on the road: `covers()`), and the drivers' road map runs through it (`centre_lines()`: the through road, and each other arm from the middle).
- Tested on the scratch copy (headless, `--fixed-fps 60`): `tests/test_big_map.gd` (new, 11): the arena's 2276 m square round the old field; the player walks past the old edge; the drop's ghost (busy, cancel frees); 6 enemies dropped 60 m out land, spread round the LZ (4.9 m across), calm, health 4; a Park near (window, the order 7 ms) and one 120 m away (arrived 0.04 m, 0.2°, no frame over 10 ms). `tests/test_road_junction.gd` (new, 9): the 8 textures; a T turned 90° (arm ends and directions); covers(); a road end 0.6 m off the stem snaps on, handle straight out; one 20 m off isn't pulled in; the truck driven from a road through a crossroads and down the road off its south arm (its route through the middle, on the roads; arrived 0.3 m off). test_truck_crate_park.gd: 16 of 17 (one 26.0 s against its 25 s bar: a reshuffle), planning at most 970 ms, no frame over 12 ms. test_truck_park, _seats, _ai, _crane, _heli (its off-the-field point moved past the new edge), test_battle_log_truck, test_radio_menu_stays pass; test_truck_passenger no failures; test_battle_log and test_debug_numbers run clean.
- Not done / known: the new ground is plain grass; a Park more than 150 m away goes by road and stops short of anything across the road (the sandbag wall at x 36 m in main.tscn); the drivers' road map joins road points pairwise (fine for these roads, slow for kilometres of them); junction tiles' baked lighting turns with them, as roads' does.

## 2026-11-09 — The editor shows the 2 km field

- **Mike:** the 2D editor still shows the original size. Why: main.tscn's grass sprite (Field) only covers the old 45 × 25 m field in the editor (field.gd tiles grass round the camera in the game, not in the editor), and the edge line is 3 px wide in world pixels, far thinner than a screen pixel at the zoom that fits 2.28 km.
- `arena_edge.gd` (@tool), in the editor only: grass drawn over the whole arena under everything (an internal node at z -101, under the Field's -100; not saved with the scene), and the edge also drawn as a bright yellow line one screen pixel wide at any zoom (width -1). It redraws if the arena changes (after a script reload). main.tscn untouched.
- Checked headless (the game side: the edge drawn 2276 m square, no editor grass in the game). The editor side wasn't run: Mike to look after Project > Reload Current Project.

## 2026-11-09 — Start On Top: squares placed up on a watch tower

- **Mike:** give an enemy and a unit a parameter that lets them be placed on top of an object like the watch tower.
- `soldier.gd` (so squadmates, enemies and the player all have it): **Start On Top** (`start_on_top`, in the Inspector). Placed in main.tscn over a built watch tower's deck, top landing or stairs, it starts up there (`_place_on_top()`, once the towers are in): its tower set, standing at that height, drawn over the deck, as if it had climbed. On a spot that's somewhere to stand (a walkway, a landing, the shelter) it stays put; anywhere else over the tower (a flight, the deck past the walkways) it's moved to the nearest place that is. Off any tower it stays on the ground and says so in the Output. An enemy's post becomes its spot up there.
- A squadmate up there behaves as one that climbed: it idles and shuffles on the deck, and ordered to the ground it comes down the stairs. An enemy can't use the stairs yet (Next steps), so up a tower it holds its spot and fights from it (`enemy.gd`: its modes run as ever, spotting, searching, calming down; it turns, aims and fires; its walking is dropped, or it'd only press into the railings). The shelter's rule holds: placed in the shelter, it can't fire out.
- Tested on the scratch copy (headless, --fixed-fps 60): `tests/test_start_on_top.gd` (new, 7; three runs, all pass): a squadmate and an enemy placed on the open deck start up there, 3 m high, the enemy's post up there; one with it on but off a tower stays on the ground; one over the deck with it off is on the ground under it; the enemy, alerted to a squadmate on the ground, fires from up there and never walks (squadmates firing back may knock it about or kill it: that's not walking); the squadmate, ordered to the ground from four places on the deck (the west end of the south walkway too), comes down the stair each time (12.9 s at most). test_enemy_crates, test_surprised, test_tower_squad run with no errors.

## 2026-11-09 — Trees: pine, spruce, oak, maple, cottonwood; Type, Growth and Size

- **Mike (five reference photos):** a tree asset that lets you change size, growth and type: pine, oak, maple, spruce, cottonwood.
- `blender/scripts/trees.py` (new): every type at three growths (sapling, young, mature: each its own proportions and seed, not one shrunk), modelled at real size and rendered straight down under the standard sun; its shadow rendered alone on a catcher (normalised: open-ground shadow = 1) at half density. Broadleaves: a trunk, limbs, and the crown as rounded clusters of diamond leaves spread over a dome (a jittered Fibonacci spiral), leafy outside and dark within, each cluster its own tint; maple and cottonwood leave clusters out (gaps the limbs show through). Conifers: whorls of drooping branches up the trunk, shorter toward the top, packed with needle twigs at varied angles and needle tufts, and shorter branches between the whorls; tips lighter. First tries (flat square leaves; chunky fern-like branches; a too-blue spruce) reworked after looking at them. See the Asset List.
- `scripts/tree.gd` + `scenes/tree.tscn` (new, @tool: shows in the editor): **Type**, **Growth**, **Size** (50–160%, on top of the type's usual for its growth). Its shadow on the ground (z -45: over roads, under squares) at 0.71; the tree at z 12 (over squares and a tower's roof, under a helicopter), fading to 35% while any square's under its crown; its trunk a solid circle (layer 1, as a crate): squares, the truck's route-finding and shots meet it, heavy cover (class 3) to hide behind. Its measurements come from `assets/props/trees/trees.json` (an exported game needs `*.json` in the export's include filter). Don't rotate one: its light would turn with it.
- Import: the 30 PNGs' .import files (mipmaps on) were written before rendering. Mike's open editor caught `tree_oak_mature.png` while Blender was rewriting it and marked it `valid=false`; its .import was reset to the template so the editor imports it again.
- Tested on the scratch copy: `tests/test_trees.gd` (new, 6): all 15 have measurements, picture and shadow, the shadow to the bottom right; each type grows sapling < young < mature; Size 150% scales crown, trunk and shadow offset; the oak's crown fades over the player (0.35) and comes back (1.0); the trunk's heavy cover; the player walking into a trunk stops at it.
- Not done: one look per type and growth (a stand of the same type repeats; variants could be rendered with other seeds); no wind; leaves don't stop shots or sight; a tree's shadow doesn't darken squares or the trees under it.

## 2026-11-09 — Crane sounds: the hydraulics while the boom moves, the winch while the line does

- **Mike:** play a snippet of the crane sound (assets/sfx/supply_truck/Crane.mp3) that makes the most sense when the boom moves, fading out right before it stops; and a winch sound (Winch.mp3) when the line starts lowering or raising.
- The recordings, mapped (loudness every 0.25 s): Crane.mp3 (20.5 s) spins up at 0.75 s, runs steadily at about -31 dB 1.75-10 s, then thinner (-37 dB) 10.5-14 s, and winds down to nothing by 19.5 s. Winch.mp3 (10.5 s): a short take 0.25-2.5 s, silence, a long one 3.25-10.5 s, steadiest 3.4-7 s.
- Cut (`blender/scripts/cut_truck_sounds.py`, `plain_loop()`: joined and wrapped where the waveforms line up, a 0.4 s constant-power blend; no pitch levelling, that's the engine's): `crane_move.wav` from 1.75-7.0 s (a 4.4 s loop), `winch.wav` from 3.4-7.0 s (2.4 s). The cuts are in the truck's Sound Cuts (Inspector: Crane Moving, Winch; Cut Sounds re-cuts them with the rest); the cutter takes `"only": ["crane", "winch"]` to cut just those.
- `supply_truck.gd`: both looped from the crane's turret (Sound: Crane Volume Db -6, Winch Volume Db -4). The hydraulics play while the turret turns or the boom slides (`_aim_at()` now also works out the move's time left: the slower of the turn and the slide); the winch while a job's LIFT or LOWER runs (a little lower, 0.93, letting a crate down). Each fades in over 0.15 s and out over the last 0.4 s before its movement stops (CRANE_FADE_S), so it's gone as it stops; a move cut short (a job cancelled), out in 0.1 s.
- Tested on the scratch copy: `tests/test_crane_sound.gd` (new, 7): a crate lifted onto the bed, tick by tick: reaching and swinging, the hydraulics full and down to 0.04 / 0.02 as each stops, no winch; lifting and lowering, the winch full and down to 0.04, pitch 0.93 going down; the most either dropped in a tick 0.042 (a smooth fade); quiet while the boom isn't moving; both stopped after. test_truck_crane passes; test_sound_cuts (the Cut Sounds button, now cutting these too) OK.

### 2026-11-09: the crane's hydraulics from Crane2.mp3
- **Mike:** added Crane2.mp3, a better crane sound.
- Mapped (loudness and brightness every 0.25 s): 46.4 s. To 18.5 s it's a thin, hissy run (about -37 dB, bright); from 18.75 to 22 s it changes over; from 22 s the hydraulics work hard, lower and louder (about -30 dB). That stretch is steadiest from 26.75 to 33.25 s, then pulses about every 1.5 s from 34 s on.
- `crane_move.wav` is now cut from 27.0-33.0 s of Crane2.mp3: a 5.2 s loop whose wrap lines up at 0.86.
- The crane's recording is now a setting:
  - Sound Cuts has `crane_recording` under Crane Moving (default Crane2.mp3), and its time ranges go up to 60 s.
  - The cutter takes `"crane_recording"`.
  - To go back to the old take, pick Crane.mp3 there with 1.75-7.0 s.
- Tested on the scratch copy: `tests/test_crane_sound.gd` passes (all 7). It reports full while the boom moves and 0.04 / 0.02 as it stops, and the most dropped in a tick is 0.042.

### 2026-11-09: the crane's start click
- **Mike:** Crane2.mp3 opens with a click; use it as the crane starts.
- Mapped every 10 ms: the click runs 0.00-0.13 s, about 15 dB over the hiss that follows from 0.4 s.
- The cutter now writes `crane_start.wav` from 0.0-0.25 s (`"crane_start"`) as a one-shot.
  - It uses the crane loop's own gain, so the click and loop keep their recorded balance, held to a -1 dB peak (which it reached).
  - The times are in Sound Cuts: Crane Moving, `crane_start_from_s` / `_to_s`.
- `supply_truck.gd`: `_crane_start_snd`, at the turret, plays at Crane Volume Db whenever the hydraulics start up from silence. That's the start of each boom move: reach and swing, and deploying or stowing. It doesn't play for the winch, or for a move that follows another before the sound has died away.
- Tested on the scratch copy:
  - `tests/test_crane_sound.gd` now has 8 checks, all passing. It counts one click at the reach and one at the swing, none at the lift or lower.
  - The test stops each click once it's counted: headless audio runs in real time, slower than the fixed-fps test, so the reach's click could still be "playing" when the swing's started.
  - test_truck_crane passes.

### 2026-11-09: quieter boom and winch; the stabilisers' sound
- **Mike:** lower the boom 20%, and the pulley (winch) 20%; add his new Stablizer.mp3 for the stabilisers deploying.
- Volumes: "20% lower" was read as ×0.8 amplitude, which is -2 dB.
  - Crane Volume Db went from -6 to -8 (that's the boom's hydraulics and its start click).
  - Winch Volume Db went from -4 to -6.
  - If it's not quiet enough: to sound 20% quieter to the ear is about -3 dB more.
- Stablizer.mp3 (8.8 s) runs steadily from 0.25 to 8.25 s, with a dip from 3.25 to 4 s.
  - The cutter joins 0.25-3.2 and 4.25-7.5 s into `stabilizer.wav`, a 4.8 s loop whose wrap lines up at 0.75 (`"stabilizer"`, `"stabilizer_recording"`).
  - Sound Cuts has a new Stabilizer group with the recording and two stretches.
- `supply_truck.gd`: `_stab_snd` (at the turret, Stabilizer Volume Db -6) plays while `_stab` changes, both coming down (DEPLOYING) and going up (STOWING).
  - It fades in over 0.15 s and out over the last 0.4 s before they're fully down or up, using the crane's `_ease_level`.
- Tested on the scratch copy:
  - `tests/test_crane_sound.gd` now has 11 checks, all passing. Coming down, the sound reaches full, then 0.00 as the stabilisers land, at most 0.042 a tick, then off. Going up, the same. The volumes are -8, -6 and -6.
  - test_truck_crane passes.

### 2026-11-09: the crane's start-up sequence: switch, motor, stabilisers
- **Mike's sequence:**
  1. The passenger gets out and reaches the controls.
  2. A half-second wait, then the switch (Switch.wav).
  3. The crane motor on at once (CraneMotor.mp3).
  4. After a second of motor, the stabilisers drop.
  5. Once they're down, the crane works.
- Recordings:
  - CraneMotor.mp3 is 181 s of steady running at -30 dB, with no start or stop. Its 5-15 s goes to `crane_motor.wav`, a 9.4 s loop whose wrap lines up at 0.96.
  - Switch.wav (0.52 s, 96 kHz) is a click at 0.26 s with a rattle from 0.18 s. Its 0.15-0.5 s goes to `crane_switch.wav`.
  - The cutter brings 96 kHz down to 48 kHz first: Blender writes 96 kHz in a WAV form Godot won't import ("not PCM").
  - Both are in Sound Cuts, under the new groups Crane Motor and Switch.
- `supply_truck.gd`:
  - The motor runs while the crane is in DEPLOYING, WORKING or STOWING. The switch (at STATION_M) plays each time it turns on or off.
  - So: SETTLING (station_hold_s 0.5), then the switch and motor, up to speed in 0.15 s.
  - DEPLOYING now holds the stabilisers for the new `motor_lead_s` (1.0) before they drop. That's skipped if they're already partly down, e.g. a stow it changed its mind on.
  - When it's put away, the motor runs until the stabilisers are up, then the switch, and it runs down over 0.6 s.
  - New exports: Motor Volume Db -10, Switch Volume Db 0, Motor Lead S 1.0.
- Tested on the scratch copy:
  - `tests/test_crane_sound.gd` now has 16 checks, all passing. At the controls at 1.73 s, the switch at 2.25 (0.52 later), the motor full at 2.38, the stabilisers moving at 3.25 (1.00 after the switch). The motor ran through the job. Put away: it ran until the stabilisers were up, then the switch, then off.
  - test_truck_crane passes.

### 2026-11-09: stabilisers from Stablizer2.wav
- **Mike:** replace the stabiliser sound with Stablizer2.
- Stablizer2.wav (4.1 s, 96 kHz) is quiet at first, builds up from 0.25 to 1.5 s, then holds a steady hydraulic hiss (about -26 dB) to its end. `stabilizer.wav` is now looped from 1.6-4.0 s. Sound Cuts > Stabilizer defaults to it, and it takes .wav as well as .mp3.
- Cutter changes:
  - `load()` now brings any recording over 48 kHz down to 48 kHz. That used to be done for the switch alone.
  - `seamless()` takes `keep_length`, used for the stabiliser. Hiss never lines up, so its usual second search (further in) only shortened the loop, to 0.76 s. It now keeps the stretch's length (1.66 s) and wraps with the 0.4 s constant-power blend.
- Its level is -23 dB against the old -16.5 at the same peak (the hiss is spikier), so at the same Stabilizer Volume Db (-6) it's quieter than the first take.
- Tested on the scratch copy: `tests/test_crane_sound.gd` passes (all 16). Coming down and going up, the sound reaches full, then 0.00 as the stabilisers land.

### 2026-11-11: separate times for the stabilisers coming down and going up
- **Mike:** split the stabiliser animation into coming out and going in.
- `supply_truck.gd`: `stabilizer_s` is replaced by `stabilizer_down_s` (deploying) and `stabilizer_up_s` (stowing), both 4.0 s, in the Inspector's Crane group as Stabilizer Down S and Stabilizer Up S. The stabiliser sound's fade-out uses whichever applies, so it still lands at 0 as they stop. No scene had overridden the old value.
- Mike had also set `station_hold_s` to 1.5 (was 0.5). `tests/test_crane_sound.gd` now checks the switch against `station_hold_s` rather than a fixed 0.5 s.
- Tested on the scratch copy: `tests/test_truck_crane.gd` passes, and `tests/test_crane_sound.gd` passes (all 16; the switch 1.52 s after reaching the controls).

### 2026-11-11: stabilisers from Stablizer3.wav, played once
- **Mike:** use his new Stablizer3 for the stabilisers; it should be 4 s long.
- Stablizer3.wav (4.6 s, 96 kHz, stereo) is the whole movement, not a steady hiss: quiet to 0.4 s, building, a clunk at 3.4 s, gone by 4.2 s. So it's no longer looped.
  - Cutter (`cut_truck_sounds.py`): the stabiliser is a one-shot now, `"stabilizer": [from, to]`, 0.2-4.2 s, with a 0.05 s fade in, a 0.15 s fade out and its peak at -3 dB. It comes out 4.0 s, at -24.6 dB (the old loop was -23). The old loop-stretch form is still read (first stretch).
  - Sound Cuts > Stabilizer: one From/To pair (was two stretches), defaulting to Stablizer3.wav 0.2-4.2.
  - `supply_truck.gd`: `_stab_snd` isn't looped. It starts once as the stabilisers set off, sped up or slowed (pitch_scale, held to 0.5-2) so it lasts Stabilizer Down S or Up S. If they turn round partway it restarts from the matching point; if they stop short it's cut over CRANE_CUT_S; when they land it plays out its own ending.
- Tested on the scratch copy: `tests/test_crane_sound.gd` passes (16). Its stabiliser checks are rewritten for the single take: it's 4.01 s and not looped; coming down it's heard at full all 240 ticks at pitch 1.00; going up with Up S set to 3.0 it's heard all 180 ticks at pitch 1.34. A tick or two quiet at the very end is allowed (headless audio keeps its own clock), but no gaps. `tests/test_truck_crane.gd` passes.

### 2026-11-11: the stabilisers as a Blender animation
- **Mike:** make the stabilisers a Blender animation (they were rectangles and circles drawn in `supply_truck.gd _draw_stabs()`).
- `supply_truck.py`:
  - The stowed legs are out of the body; only their housings stay (`OutriggerBeam`, to STAB_HOUSING_END_M).
  - `build_stabs()` builds each side's moving parts: an inner beam (most of it in the housing), a jack on its end (olive barrel, cap and bolt), and a steel ram, swivel and foot pad. They hang from two empties, `StabSlide1` (out) and `StabFoot1` (down), keyframed over frames 0–24 with the same timing the game's drawing had (`stab_pose()`: out over the first 55%, down over the last 55%, smoothed).
  - The left one is rendered frame by frame with the body as a holdout (`is_holdout`), so whatever's inside the housing or under the pedestal is cut out. That gives `supply_truck_stabilizer_sheet.png` (25 × 128 px, 2×) and `supply_truck_shadow_stabilizer_sheet.png` (25 × 112 px, half density, ~1 m spare round each, because the sweep reads the whole sheet). Frames go to a temp file outside the project.
  - New review image: `supply_truck_stabilizers_preview.png`, the stabilisers down, angled. The `.blend` has the animation (scrub the timeline 0–24).
  - Re-rendered: the body and the low shadow (without the legs) and the previews. The other truck images re-rendered identically apart from noise, so they were left as committed.
- `supply_truck.gd`: `_stabs` are two Sprite2Ds (hframes 25, the right one `flip_v`), z 3 over the body, at `STAB_SHEET_AT_M`. `_place_stabs()` picks frame `round(_stab × 24)` each frame. Their shadows are swept from the foot's height (`STAB_FOOT_UP_M` × (1 − down): it comes in under the foot as it lands) to `STAB_TOP_M`. The flipped one's sweep has its y negated (its texture runs the other way). They're also lifted with the truck when it's slung. `_draw_stabs()` and the STAB_BEAM/PAD colours are gone. Stabilizer Down S / Up S still set the timing.
- Note: the right door's shadow sweep (`flip_v` too) isn't negated like this, so it may lean the wrong way. Not checked.
- Testing note: piping a headless `--import` into `Select-Object -First N` stops it early, before the new images are imported.
- Tested on the scratch copy:
  - `tests/test_truck_crane.gd` and `tests/test_crane_sound.gd` pass.
  - New `tests/screenshots/shot_truck_stabilizers.gd` (windowed) passes its 9 checks: at `_stab` 0, 0.3, 0.6 and 1 both stabilisers and both shadows are on frames 0, 7, 14 and 24; the right one's sweep is the left's mirrored; the left one is at −y and the right one is mirrored at +y. The screenshots show them stowed against the pedestal, and out with their pads beyond the sides, both sides.
