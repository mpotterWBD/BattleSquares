# Battle Squares — Development Log

A running record of how Battle Squares is designed and built: decisions, progress, and open questions.

---

## Project Overview

| Item | Value |
|------|-------|
| Project folder | `F:\Projects\BattleSquares` |
| Started | 2026-10-28 |
| Game engine | Godot 4.7.2 (`C:\Users\mpott\Desktop\Godot_v4.7.2-stable_win64.exe`) |
| Art style | Realistic proportions at **real-world scale**, clean rendered look (squares are glossy red blocks; vehicles and kit are detailed but unmarked) |
| 2D / 3D | 2D, top-down (art is rendered in Blender, then used as 2D images) |
| Target platform(s) | PC (Windows), mouse + keyboard |
| Design resolution | 1920×1080; the window opens at 1280×720 and can be resized freely |
| Renderer | Godot "Compatibility" (best fit for a 2D game) |
| Asset tool | Blender 5.2 (scripted via Python `bpy`, run headless) |

### Concept

A top-down tactical squad game. You are a red square with a rifle, leading a squad of identical squares. Hold Space to talk to them: only those in your voice cone or close by hear you, and you can move them, form them up, or deploy equipment such as a field comms station. Helicopters will insert and extract the squad, and long-range radio comms (via the station's dish) are planned.

### Core Gameplay Loop

Still forming. So far: move and aim, command the squad, deploy and set up equipment. Enemies, objectives and win conditions don't exist yet.

---

## Start Here: Current State (updated 2026-10-29, morning)

**Read this first in a new session.** Details are in the sections below and the dated Log.

### Controls

| Input | Action |
|-------|--------|
| WASD / arrows | Walk (screen directions; you can strafe) |
| Mouse | Aim: the square turns loosely toward the cursor, and the rifle aims within its sweep |
| Left click | Fire (one shot per click) |
| Scroll wheel | Zoom 0.5×–3× |
| **Space** (hold) | Command mode: voice cone and aura, ORDERS menu (left), DEPLOY menu (right), selection and move orders |
| **F** | Interact: at a station's desk (platform box), open/close the RADIO menu or hang up radio command; in the dish box, open/close the dish tuning wheel |
| Esc | Close the RADIO menu (or step back out of marking an LZ) |
| Right click | In command mode: move order (or cancel equipment placement); while marking an LZ: back to the request |

### What's in the game (`scenes/main.tscn`)

- The **grass field** fills whatever the camera sees.
- The **player** (`player.tscn`, inheriting `soldier.tscn`). As of the 2026-10-29 morning session, Mike's `main.tscn` holds only Field, Player, Camera and Command: **no squadmates or helicopters are placed**. Troops now arrive by helicopter from a radio station (below), and tests add their own squadmates.
- **Helicopters** (`helicopter.tscn`) appear only when sent from a station's terminal (`scripts/insertion.gd` flies them in and out).
- **Command system** (`scripts/command.gd`):
  - a voice cone (8 m, ±40°) plus a command aura (2.475 m radius);
  - selection by box or click;
  - move orders to anywhere;
  - an ORDERS menu: Follow me / Lead (hold for a Line/Column pop-out) and Disperse; with nothing selected, an order goes to everyone who can hear;
  - a DEPLOY menu: Equipment → Radio station, placed as a ghost inside the aura. The player carries 1 (`player.gd` `deployables`).
- **Deployed radio station** (`radio_station.tscn` + `scripts/radio_station.gd`):
  - a guyed mast, and an operator platform with a desk;
  - **the radio terminal** (`Terminal` node, `scripts/radio_terminal.gd`). In the platform's green box (`OperatorZone`), F opens the **RADIO** menu:
    - **Command:** radio command mode (`World.radio_commanding`, `World.radio_station`). **The command structure:** your voice (cone + aura) still works. On top of it, radio operators (`kit = "radio"`) inside *this station's* dish beam are linked, and they and anyone within their **command circle** (2× the player's aura, 4.95 m) can be commanded. You see your cone, the beam, and a circle round each operator: solid when linked, dashed when out of the beam. F or stepping off the box hangs up.
    - **Deploy** (hold) → **Troops** / Vehicles (disabled, "soon"). Troops opens **10 slots** (2 rows of 5); fill as many as you want sent. Press a slot for the unit-type pop-out, which opens left of the panel: **Infantry** or **Radio** (a radio operator: infantry with a radio pack, `kit = "radio"`); a quick click = Infantry. **Clear** empties them.
    - Filled slots ready one after another, `seconds_per_troop` = **30 s each**. Then **Send helicopter** gives a ghost helicopter to mark the LZ (anywhere inside the play area). A click sends the real one: it flies in from the west at 25 m, lands, unloads the troopers (who join the squad and disperse about 6 m to either side), lifts off and flies away. The request survives walking away from the desk, and while the menu is closed a timer above the box shows "3 troopers  1:30" (total time left), then "3 troopers READY";
  - a satellite dish with its own green box. F there opens a tuning wheel. The mouse only picks a heading (white line; a green line shows where the dish points now). A left click or F locks the pick in (`target_heading`), and the dish turns to it slowly: at most 12°/s, easing in and out, so 180° takes about 15 s. A 60 m, ±18° beam shows where it actually points, drawn like the voice cone (same green and see-through; the alphas are shared in `world.gd`). It shows while tuning and in command mode, not while the dish turns on its own. The current heading is in `dish_heading`, and `dish_tuned(heading)` is emitted when the dish arrives. **Nothing consumes it yet.**
- **Menu building blocks:** `scripts/ui_style.gd` (shared button and panel look) and `scripts/hold_popout.gd` (the reusable press-hold-slide-release pop-out), used by command mode and the terminal.

### Next steps (Mike's stated direction)

1. **Vehicles** in the terminal's Deploy menu (currently a disabled "soon" option).
2. **More unit types** for troop slots (only Infantry so far; add to `UNIT_TYPES` in `radio_terminal.gd`, and spawn the right scene in `insertion.gd`).
3. **Radio soldiers / long-range comms:** the dish heading (`dish_tuned`) should matter, e.g. a contact must be inside the beam.
4. **Helicopter extraction** (insertion is done, from the terminal). Open questions: who boards (listeners or selected? the player?) and how it's called.
5. **Gunshot sound:** proposed a generated placeholder now and a Sonniss/Kenney recording later; the rifle's `fired` signal is ready. Not done yet.

### Loose ends and known issues

- **No version control yet.** Mike plans to set up git (said "tomorrow" just after midnight on 2026-10-29). Offer to help: `git init`, a `.gitignore` that excludes `.godot/` (the existing `.gitignore` already does), and a first commit of the working state.

- The `Field` node in `main.tscn` was scaled to (0.9896, 1.0028) and moved to (0, 3), probably by an accidental drag in the editor. Mike was told and it was left alone.
- Soldier collision boxes don't rotate with facing.
- Art is rendered for 1× zoom: at 3× the grass and squares are soft (the rifle and station are rendered at 2–4× density and stay sharp). At 0.5× the 12 m grass tile repeats visibly.
- Flowers in the far-zoom grass are fairly dense.
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
│   ├── game_camera.gd   ← scroll-wheel zoom, follows the player within the arena
│   ├── soldier.gd       ← every square: movement, facing, hop, shadows, rifle
│   ├── player.gd        ← keyboard/mouse control of a soldier
│   ├── squadmate.gd     ← AI soldier: idle glances/shuffles, move orders
│   ├── command.gd       ← hold Space: voice cone/aura, selection, orders menu, HUD
│   ├── helicopter.gd    ← rotor spin, altitude, swept shadows, hull outline
│   ├── radio_station.gd ← deployed station: stand boxes, F to tune the dish (wheel + beam)
│   ├── radio_terminal.gd ← the station's desk: RADIO menu, radio command, troop requests, LZ
│   ├── insertion.gd     ← flies a helicopter in to an LZ, unloads troops, flies it out
│   ├── ui_style.gd      ← shared look of the menus (buttons, panels, labels)
│   ├── hold_popout.gd   ← press-hold-slide-release pop-out used by every menu
│   ├── rifle.gd         ← mouse aim within a sweep, recoil, muzzle flash, firing
│   ├── radio_pack.gd    ← radio operator's backpack + antenna (soldier `kit = "radio"`)
│   └── bullet.gd        ← tracer projectile
├── blender/             ← ignored by Godot
│   ├── scripts/         ← Python generators (source of truth for assets)
│   │   ├── bs_common.py ← shared sun, sky, camera and pixel scale; all scripts use it
│   │   ├── field_grass.py
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
| Rifle | Done (v2, detailed) | `blender/scripts/rifle.py` | `assets/characters/rifle.png` (384 px, **rendered at 4× density**, shown at 0.25 scale with mipmaps so it stays sharp when zoomed in). 0.48 m from pivot to muzzle (0.28 m beyond the front face). Parts: gunmetal receiver, red-dot sight with a red lens, polymer handguard, front sight post, barrel, muzzle brake, and a forward-raked magazine. **Canted 30°** so the magazine shows from above (it pokes out to the gun's right). Lit from straight overhead so it can rotate; its shadow is drawn in Godot. v1 (plain bar) is in `assets/previews/rifle_v1_plain.png`. |
| Radio pack (radio operator) | Done (v1) | `blender/scripts/radio_pack.py` | `assets/characters/radio_pack.png` (614 px = 1.8 m, **rendered at 4× density**, shown at 0.25 scale with mipmaps), centred on the square's centre, square facing +x. Brown canvas pack on the square's back (0.16 m deep, 0.3 m wide, top at 0.44 m, just above the square), darker top flap and side pouches, shoulder straps over the square's top, the radio's top with two knobs, and a 0.6 m whip antenna raked 32° back with a tip cap. Lit from straight overhead so it turns with the square; its shadow is drawn in Godot (`radio_pack.gd`). |
| Helicopter (UH-60-style transport) | Done (v3, 0.55 scale, cockpit, flies insertions) | `blender/scripts/helicopter.py` | Modelled at real size, then shrunk by `SCALE` = 0.55 (`helicopter.gd SCALE` must match): fuselage 8.4 m, rotor 9 m. Cockpit (laid out for scale 0.5 and grown with `SCALE`): two red pilot squares, 0.44 m, corners rounded like the player's (upright edges only, top edges sharp), under dark tinted glass (alpha 0.85); an instrument panel with screens, switch strips and a centre console with lamps. `assets/vehicles/helicopter_body.png` (939 px = 11 m, nose to +x; cockpit interior without pilots or glass), `helicopter_pilot.png` (one pilot, lit as in the cockpit; the game draws two and animates them), `helicopter_glass.png` (glass only, drawn over the pilots) and `helicopter_rotor.png` (centred on the mast), both lit from straight overhead so they can face any heading. Plus 4 half-res shadow outlines `helicopter_shadow_{body,stabilator,fin,tailrotor}.png` (padded for sweeping). Olive drab, matte, no markings; black blades with yellow tip bands. Renders in about 15 s. |
| Deployable comms station (radio mast, small antenna, satellite dish, laptop) | Done, **in the game via DEPLOY** | `blender/scripts/radio_station.py` | Four images, all 2× density (show at scale 0.5): `radio_station.png` (tall parts, z 4), `radio_station_ground.png` (deck, cables, stakes, z −5), `radio_station_shadow.png` (2133 px = 12.5 m, centred on the mast base), and `radio_station_dish.png` (2.4 m, centred on the dish post, lit from overhead, rotated in game). Guyed 7 m tripod mast with dipole and whip, 3 orange-flagged stakes 4.5 m out; 1 m dish on a tripod at 40° elevation with feed arm; a 2 m square plank operator platform with a field desk carrying a radio (whip antenna, handset), the detailed rugged laptop (lit mapping-app screen, mouse), a power unit, a headset, a notebook and a mug; cables to the mast and dish. Lit by the normal top-left sun (it doesn't turn), with its shadow rendered separately and normalised like the squares'. Review image: `assets/previews/radio_station_preview.png`. Renders in about 30 s. |
| Red square: player (body + shadow) | Done (v3, turning sheets) | `blender/scripts/character_square.py` | `assets/characters/red_square_sheet.png` (30 frames × 64 px; the block is about 34 px = 0.4 m) and `red_square_shadow_sheet.png` (30 × 128 px). Frame k = the block turned k × 3° clockwise; 30 frames cover 90°, because a square repeats every quarter turn. Pre-lit at every angle, so the highlight and the shadow's shape stay correct as it turns. Glossy red plastic with rounded edges. Renders in about 20 s. Older single images are in `assets/previews/`. |

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
