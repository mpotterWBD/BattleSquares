"""Render a supply truck as top-down sprites: an 8x8 tactical truck with a
knuckle-boom loader crane between the cab and a flatbed that takes two of
the game's pallets (Mike, 2026-11-03, after his reference photos of a
military wrecker and a crane truck lifting a container; no markings).

Run headless:
    blender --background --python supply_truck.py
    blender --background --python supply_truck.py -- draft <folder>
The second writes every image and the .blend into <folder> instead, to look
at before the project gets them (Godot imports a new PNG the moment it shows
up, and these need their .import, with mipmaps, written first).

Modelled straight at game size (metres), in proportion with the helicopter
(helicopter.py SCALE 0.55): 4.3 m long, 1.37 m wide over the tyres, the cab
roof 1.6 m up. Front to back (+x is forward):
  cab       flat-faced and armoured, a sloped two-pane windscreen, amber
            marker lights along the roof's front edge, two amber beacons,
            a roof hatch, mirrors out on arms, a bumper with tow shackles
  module    behind the cab: the engine's housing, louvred vents on top, an
            exhaust stack and an air intake with a rain cap
  crane bay the crane's pedestal (its turret is a separate image, below) and
            a stabiliser each side: a housing, and the beam and jack that
            come out of it (animated, a sheet of their own, below)
  bed       a steel flatbed, BED_L x BED_W, its deck BED_Z up, with a
            headboard, side rails, stake pockets and tie-down rings: room for
            two 0.8 m pallets (crates.py) one behind the other
  wheels    four axles, two under the cab and two under the bed, lugged
            off-road tyres showing a little past the body from above

Images, lit from straight overhead so the game can turn them to any heading
(like the helicopter; the game will draw the shadow), at RENDER_SCALE x the
game's pixel density (shown at 1/RENDER_SCALE with mipmaps):
  assets/vehicles/supply_truck_body.png   everything but the crane's turret,
                                          centred on the truck's middle, nose right
  assets/vehicles/supply_truck_crane.png  the turret (slewing column and the
                                          booms, stowed folded forward over the
                                          module), centred on its slewing axis
                                          (CRANE_X_M along the truck), so it can turn
  assets/vehicles/supply_truck_door.png   the driver's door (build_door()), shut,
                                          centred on its middle, for the game to
                                          swing open about its hinge (and mirror
                                          for the other door)
  assets/vehicles/supply_truck_stabilizer_sheet.png
                                          the left stabiliser coming out and
                                          down, STAB_FRAMES frames left to
                                          right, keyframed (build_stabs()); the
                                          game mirrors it for the right
plus half-density shadow outlines (supply_truck_shadow_<group>.png, SHADOW_GROUPS,
and _crane, _door, and _stabilizer_sheet frame by frame), which the game
sweeps toward the sun.
Reviews (assets/previews/): supply_truck_preview.png, top-down under the
standard sun on the field's grass with two ammo crates on the bed and a red
square beside it for scale; supply_truck_angle_preview.png, an angled look
like the reference photos; supply_truck_stabilizers_preview.png, the
stabilisers down, close up.

Blender axes: +x forward, +y to the left (port), +z up. In the image +y is up.
"""

import math
import os
import sys
import tempfile

import bmesh
import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bs_common as bs  # noqa: E402

ROOT = bs.ROOT
OUT_BODY = os.path.join(ROOT, "assets", "vehicles", "supply_truck_body.png")
OUT_CRANE = os.path.join(ROOT, "assets", "vehicles", "supply_truck_crane.png")
OUT_DOOR = os.path.join(ROOT, "assets", "vehicles", "supply_truck_door.png")
OUT_TYRE = os.path.join(ROOT, "assets", "vehicles", "supply_truck_tyre.png")
OUT_PREVIEW = os.path.join(ROOT, "assets", "previews", "supply_truck_preview.png")
OUT_ANGLE = os.path.join(ROOT, "assets", "previews", "supply_truck_angle_preview.png")
OUT_STABS = os.path.join(ROOT, "assets", "vehicles", "supply_truck_stabilizer_sheet.png")
OUT_STAB_PREVIEW = os.path.join(ROOT, "assets", "previews", "supply_truck_stabilizers_preview.png")
OUT_BLEND = os.path.join(ROOT, "blender", "source", "supply_truck.blend")
_args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
if _args[:1] == ["draft"]:
    _draft = _args[1]
    OUT_BODY, OUT_CRANE, OUT_DOOR, OUT_TYRE, OUT_PREVIEW, OUT_ANGLE, OUT_STABS, OUT_STAB_PREVIEW, OUT_BLEND = (
        os.path.join(_draft, os.path.basename(path)) for path in (OUT_BODY, OUT_CRANE, OUT_DOOR, OUT_TYRE, OUT_PREVIEW, OUT_ANGLE,
                                                                  OUT_STABS, OUT_STAB_PREVIEW, OUT_BLEND))

RENDER_SCALE = 2
SAMPLES = 96
BODY_FRAME_M = 4.7      # the truck (4.3 m) and a little room
CRANE_FRAME_M = 2.2     # the stowed turret, from its axis forward over the module

# Shadow outlines (like helicopter.py): one per group of parts at its own
# heights, at half the game's density, which the game sweeps across those
# heights toward the sun (scripts/supply_truck.gd SHADOW_PARTS has the heights).
# Group -> object name prefixes; anything else is "low" (wheels, chassis, the
# bed, bumpers, the crane's pedestal). The turret's is "crane", round its axis.
SHADOW_GROUPS = {
    "headboard": ["HeadPost", "HeadTop", "HeadMid", "HeadBar"],
    "cab": ["Cab", "Pillar", "SideWindow", "DoorSeam", "Handle", "Nose", "GrilleSlat", "RoofPanel", "Hatch",
            "Marker", "Beacon", "Antenna", "Mirror", "Convex", "Headlight", "Module", "Louvre", "VentFrame",
            "Exhaust", "Intake", "RainCap", "Toolbox"],
}
SHADOW_FRAME_M = 7.4        # the body, with room for its outlines to be swept ~1.3 m any way
CRANE_SHADOW_FRAME_M = 4.4  # the turret likewise
SHADOW_DIR = os.path.join(ROOT, "assets", "vehicles")

# Along the truck (x, metres from its middle; the nose at +FRONT_X).
FRONT_X = 2.15
CAB_BACK_X = 1.03
MODULE_BACK_X = 0.52
BED_FRONT_X = -0.05     # the headboard
BED_BACK_X = -2.05
REAR_X = -2.15
HALF_W = 0.62           # the cab; the bed is BED_W wide
AXLES_X = (1.70, 0.98, -0.90, -1.62)
TYRE_R = 0.33
TYRE_W = 0.17
TYRE_Y = 0.60           # the tyres' middles, either side
CAB_Z = (0.74, 1.74)    # its floor clears the tyres (TYRE_R x 2 = 0.66)
SCREEN_Z = 1.16         # the windscreen's slope starts here
BED_Z = 0.80            # the bed's deck top (its underside clears the tyres)
BED_L = BED_FRONT_X - BED_BACK_X
BED_W = 1.20
HATCH_M = 0.44          # the roof hatch, square: a 0.4 m square (soldier.gd SIZE_M) and a little
HATCH_AT = (1.48, -0.18)  # its middle on the roof, on the right (Mike, 2026-11-03: the passenger's side)
DOOR_X = (1.27, 1.89)   # the doors, back edge to the hinge at the front (Mike, 2026-11-03: where he marked it)
DOOR_T = 0.09           # their thickness (armoured; thick enough to read as a door from above, swung open)
DOOR_FRAME_M = 0.75     # the door's own picture, round its middle
TYRE_FRAME_M = 0.8      # one tyre's picture, round its middle
DOOR_SHADOW_FRAME_M = 2.2
CRANE_X_M = 0.23        # the crane's slewing axis, along the truck; supply_truck.gd will match
CRANE_BASE_Z = 0.86

# The stabilisers (Mike, 2026-11-11: a Blender animation, not shapes drawn in
# the game): each an inner beam that slides out of its housing on the
# pedestal, carrying a jack whose ram pushes a foot pad down to the ground.
# Keyframed over STAB_FRAMES frames (0 stowed .. last down), the beam out over
# the first 55% and the foot down over the last 55% (smoothed, overlapping, as
# the game's old drawing). Rendered, the left one only (the game mirrors it
# for the right), into supply_truck_stabilizer_sheet.png (one frame per
# column) with a half-density shadow outline sheet beside it.
STAB_FRAMES = 25
STAB_HOUSING_END_M = 0.62   # the housing's outer end, out from the middle
STAB_IN_M = 0.6             # the jack's middle, stowed (against the housing's end)...
STAB_OUT_M = 0.86           # ...and out (supply_truck.gd STAB_OUT_M)
STAB_FOOT_UP_M = 0.17       # the foot pad's underside off the ground, stowed
STAB_FRAME_M = 0.75         # each frame: 128 px at 2x, round STAB_FRAME_AT
STAB_FRAME_AT = (CRANE_X_M, 0.66)
STAB_SHADOW_FRAME_M = 2.625  # each shadow frame: 112 px at half density, with ~1 m all round for the sweep
STAB_TOP_M = 0.9            # the jack's top (its shadow's highest point)

# Colours (sRGB): olive drab, matte, a little greener and lighter than the
# helicopter's (helicopter.py), between it and the ammo cans' (crates.py),
# like the reference photos.
OLIVE = (0.26, 0.29, 0.19)
OLIVE_DARK = (0.18, 0.20, 0.14)
OLIVE_DECK = (0.22, 0.24, 0.165)
GLASS = (0.06, 0.08, 0.10)
RUBBER = (0.07, 0.07, 0.068)
STEEL = (0.32, 0.33, 0.33)
CHROME = (0.75, 0.76, 0.78)
SOOT = (0.07, 0.07, 0.07)
AMBER = (0.98, 0.55, 0.06)
RED_LAMP = (0.85, 0.08, 0.06)
LENS = (0.85, 0.86, 0.8)
YELLOW = (0.88, 0.70, 0.10)
SQUARE_RED = (0.85, 0.09, 0.07)   # the player's square (character_square.py)


# ---------------------------------------------------------------- helpers --
def material(name, rgb, metallic=0.0, roughness=0.6, shine=0.25, emit=0.0):
    """`shine` is the specular level: with the sun and camera overhead, flat
    tops mirror the sun, so matte parts need it low (helicopter.py)."""
    mat = bpy.data.materials.new(name)
    nt = bs.node_tree_of(mat)
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (*bs.srgb(*rgb), 1.0)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    if "Specular IOR Level" in bsdf.inputs:
        bsdf.inputs["Specular IOR Level"].default_value = shine
    if emit:
        bsdf.inputs["Emission Color"].default_value = (*bs.srgb(*rgb), 1.0)
        bsdf.inputs["Emission Strength"].default_value = emit
    return mat


def link(name, mesh, mats, smooth=False, parts=None):
    for m in mats:
        mesh.materials.append(m)
    if smooth:
        mesh.shade_smooth()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    if parts is not None:
        parts.append(obj)
    return obj


def box(name, x0, x1, y0, y1, z0, z1, mat, parts, bevel=0.0):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, verts=bm.verts, vec=(x1 - x0, y1 - y0, z1 - z0))
    bmesh.ops.translate(bm, verts=bm.verts, vec=((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2))
    if bevel:
        bmesh.ops.bevel(bm, geom=list(bm.edges), offset=bevel, segments=2, profile=0.5, affect="EDGES")
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    return link(name, me, [mat], parts=parts)


def cylinder(name, radius, z0, z1, at, mat, parts, segs=24, axis="z"):
    """An upright (or along `axis`) cylinder from z0 to z1 (or along its
    axis, z0..z1 from `at`), centred on `at` (x, y[, z])."""
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=segs, radius1=radius, radius2=radius, depth=z1 - z0)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    obj = link(name, me, [mat], smooth=True, parts=parts)
    if axis == "z":
        obj.location = (at[0], at[1], (z0 + z1) / 2)
    elif axis == "x":
        obj.rotation_euler = (0, math.radians(90), 0)
        obj.location = (at[0] + (z0 + z1) / 2, at[1], at[2])
    else:   # y
        obj.rotation_euler = (math.radians(90), 0, 0)
        obj.location = (at[0], at[1] + (z0 + z1) / 2, at[2])
    return obj


def beam(name, a, b, w, h, mat, parts, bevel=0.01):
    """A box beam from point `a` to `b` (x, y, z), `w` wide and `h` deep."""
    a, b = Vector(a), Vector(b)
    d = b - a
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, verts=bm.verts, vec=(d.length, w, h))
    if bevel:
        bmesh.ops.bevel(bm, geom=list(bm.edges), offset=bevel, segments=2, profile=0.5, affect="EDGES")
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    obj = link(name, me, [mat], parts=parts)
    obj.rotation_euler = d.to_track_quat("X", "Z").to_euler()
    obj.location = (a + b) / 2
    return obj


def profile_solid(name, pts_xz, y0, y1, bevel=0.0):
    """A solid from a side profile (x, z points, anticlockwise seen from +y)
    run across from y0 to y1."""
    bm = bmesh.new()
    left = [bm.verts.new((x, y1, z)) for x, z in pts_xz]
    right = [bm.verts.new((x, y0, z)) for x, z in pts_xz]
    bm.faces.new(left)
    bm.faces.new(list(reversed(right)))
    n = len(pts_xz)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((right[i], right[j], left[j], left[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    if bevel:
        bmesh.ops.bevel(bm, geom=list(bm.edges), offset=bevel, segments=2, profile=0.5, affect="EDGES")
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    return me


# ------------------------------------------------------------------ tyres --
def tyre_mesh():
    """One off-road tyre (axis along y, centred on the origin): the carcass
    with rounded shoulders and a ring of chunky lugs round the tread, in a
    chevron (each lug angled, alternating sides), and a hub on the outside."""
    bm = bmesh.new()
    segs = 40
    # The carcass: a lathe of a rounded profile (radius, y) round the y axis.
    profile = [(TYRE_R * 0.62, -TYRE_W / 2), (TYRE_R - 0.03, -TYRE_W / 2), (TYRE_R - 0.012, -TYRE_W / 2 + 0.018),
               (TYRE_R - 0.012, TYRE_W / 2 - 0.018), (TYRE_R - 0.03, TYRE_W / 2), (TYRE_R * 0.62, TYRE_W / 2)]
    rings = []
    for k in range(segs):
        a = 2 * math.pi * k / segs
        rings.append([bm.verts.new((r * math.cos(a), y, r * math.sin(a))) for r, y in profile])
    for k in range(segs):
        r0, r1 = rings[k], rings[(k + 1) % segs]
        for i in range(len(profile) - 1):
            bm.faces.new((r0[i], r0[i + 1], r1[i + 1], r1[i]))
    for side in (0, len(profile) - 1):   # the sidewalls' inner edges, closed off
        bm.faces.new([rings[k][side] for k in range(segs)])
    # The lugs: 24 round the tyre, two per step (one each side of the middle),
    # each a short block angled across the tread.
    lugs = 34
    for k in range(lugs):
        a = 2 * math.pi * (k + 0.5) / lugs
        for s in (-1, 1):
            if (k % 2 == 0) != (s > 0):
                y = s * TYRE_W * 0.2
                length = TYRE_W * 0.56
            else:
                y = s * TYRE_W * 0.3
                length = TYRE_W * 0.36
            geom = bmesh.ops.create_cube(bm, size=1.0)["verts"]
            bmesh.ops.scale(bm, verts=geom, vec=(0.034, length, 0.022))
            bmesh.ops.rotate(bm, verts=geom, cent=(0, 0, 0), matrix=Matrix.Rotation(math.radians(s * 22), 3, "Z"))
            bmesh.ops.translate(bm, verts=geom, vec=(TYRE_R - 0.012, y, 0))
            bmesh.ops.rotate(bm, verts=geom, cent=(0, 0, 0), matrix=Matrix.Rotation(-a, 3, "Y"))
    me = bpy.data.meshes.new("Tyre")
    bm.to_mesh(me)
    bm.free()
    return me


def build_wheels(rubber, hub, parts):
    tyre = tyre_mesh()
    tyre.materials.append(rubber)
    for i, x in enumerate(AXLES_X):
        for side in (1, -1):
            obj = bpy.data.objects.new(f"Tyre{i}{side}", tyre)
            bpy.context.scene.collection.objects.link(obj)
            obj.location = (x, side * TYRE_Y, TYRE_R)
            parts.append(obj)
            # The hub, on the outside: a dished olive wheel with a cap.
            cylinder(f"Hub{i}{side}", TYRE_R * 0.6, 0, 0.02, (x, side * (TYRE_Y + TYRE_W / 2 - 0.012), TYRE_R),
                     hub, parts, segs=24, axis="y")
            cylinder(f"HubCap{i}{side}", TYRE_R * 0.22, 0, 0.03, (x, side * (TYRE_Y + TYRE_W / 2 - 0.004), TYRE_R),
                     hub, parts, segs=16, axis="y")


# ------------------------------------------------------------------- body --
def build_body():
    m = {
        "olive": material("Olive", OLIVE, roughness=0.75, shine=0.22),
        "dark": material("OliveDark", OLIVE_DARK, roughness=0.8, shine=0.2),
        "deck": material("Deck", OLIVE_DECK, roughness=0.7, shine=0.25),
        "glass": material("Glass", GLASS, metallic=0.2, roughness=0.08, shine=0.5),
        "rubber": material("Rubber", RUBBER, roughness=0.92, shine=0.1),
        "steel": material("Steel", STEEL, metallic=0.35, roughness=0.65, shine=0.15),   # (dull: overhead, shiny steel mirrors the sun)
        "soot": material("Soot", SOOT, roughness=0.85, shine=0.1),
        "amber": material("Amber", AMBER, roughness=0.3, shine=0.4, emit=0.6),
        "red": material("RedLamp", RED_LAMP, roughness=0.3, shine=0.4, emit=0.4),
        "lens": material("Lens", LENS, roughness=0.2, shine=0.5),
    }
    p = []

    # Chassis rails, under everything.
    for s in (1, -1):
        box("Rail", REAR_X + 0.05, FRONT_X - 0.1, s * 0.28, s * 0.4, 0.42, 0.6, m["dark"], p)

    # --- The cab: a side profile with a sloped windscreen, run across, its
    # edges rounded; the slope's faces (inside the frame) are glass.
    cab_z0, cab_z1 = CAB_Z
    cab = profile_solid("Cab", [(CAB_BACK_X, cab_z0), (FRONT_X, cab_z0), (FRONT_X, SCREEN_Z),
                                (FRONT_X - 0.2, cab_z1 - 0.04), (FRONT_X - 0.24, cab_z1),
                                (CAB_BACK_X, cab_z1)], -HALF_W, HALF_W, bevel=0.035)
    cab.materials.append(m["olive"])
    cab.materials.append(m["glass"])
    for poly in cab.polygons:
        n, c = poly.normal, poly.center
        if n.x > 0.5 and n.z > 0.25 and abs(c.y) < HALF_W - 0.07 and SCREEN_Z + 0.03 < c.z < cab_z1 - 0.05:
            poly.material_index = 1
    link("Cab", cab, [], parts=p)
    # The windscreen's middle pillar, on the slope.
    pillar = profile_solid("Pillar", [(FRONT_X - 0.005, SCREEN_Z), (FRONT_X + 0.012, SCREEN_Z),
                                      (FRONT_X - 0.215, cab_z1 - 0.025), (FRONT_X - 0.232, cab_z1 - 0.04)],
                           -0.022, 0.022)
    link("Pillar", pillar, [m["olive"]], parts=p)
    # Its sides: a door each side with a window, and the seams round it.
    door_x = DOOR_X
    for s in (1, -1):
        box(f"SideWindow{s}", door_x[0] + 0.05, door_x[1] - 0.06, s * (HALF_W - 0.004), s * (HALF_W + 0.004),
            SCREEN_Z + 0.06, cab_z1 - 0.12, m["glass"], p)
        for x in door_x:
            box(f"DoorSeam{s}{x:.2f}", x - 0.006, x + 0.006, s * (HALF_W - 0.003), s * (HALF_W + 0.003),
                cab_z0 + 0.04, cab_z1 - 0.06, m["dark"], p)
        box(f"Handle{s}", door_x[0] + 0.06, door_x[0] + 0.16, s * HALF_W, s * (HALF_W + 0.015),
            SCREEN_Z - 0.06, SCREEN_Z - 0.035, m["steel"], p)
    # The nose under the cab's face: a grille between the wheels, over the bumper.
    box("Nose", FRONT_X - 0.3, FRONT_X - 0.005, -0.48, 0.48, 0.44, cab_z0 + 0.01, m["dark"], p, bevel=0.01)
    for k in range(4):
        z = 0.48 + k * 0.06
        box(f"GrilleSlat{k}", FRONT_X - 0.01, FRONT_X + 0.002, -0.36, 0.36, z, z + 0.022, m["soot"], p)
    # Roof: a raised panel, a hatch, amber marker lights along the front edge,
    # two beacons at the back corners and an antenna mount. The hatch is
    # square, sized for one of our squares to come up through (Mike,
    # 2026-11-03: not round): HATCH_M across, its lid on a hinge along the back.
    box("RoofPanel", CAB_BACK_X + 0.08, FRONT_X - 0.36, -HALF_W + 0.08, HALF_W - 0.08, cab_z1, cab_z1 + 0.012,
        m["olive"], p, bevel=0.005)
    hx, hy, h = HATCH_AT[0], HATCH_AT[1], HATCH_M / 2
    box("HatchRim", hx - h - 0.03, hx + h + 0.03, hy - h - 0.03, hy + h + 0.03, cab_z1, cab_z1 + 0.035,
        m["dark"], p, bevel=0.008)
    box("HatchLid", hx - h, hx + h, hy - h, hy + h, cab_z1 + 0.01, cab_z1 + 0.05, m["olive"], p, bevel=0.01)
    box("HatchHinge", hx - h - 0.045, hx - h - 0.005, hy - h + 0.06, hy + h - 0.06, cab_z1 + 0.03, cab_z1 + 0.06,
        m["steel"], p, bevel=0.005)
    box("HatchHandle", hx + h - 0.07, hx + h - 0.04, hy - 0.06, hy + 0.06, cab_z1 + 0.05, cab_z1 + 0.065, m["steel"], p)
    for k in range(5):
        y = (k - 2) * 0.22
        box(f"Marker{k}", FRONT_X - 0.285, FRONT_X - 0.255, y - 0.03, y + 0.03, cab_z1, cab_z1 + 0.025, m["amber"], p)
    for s in (1, -1):
        cylinder(f"BeaconBase{s}", 0.05, cab_z1, cab_z1 + 0.03, (CAB_BACK_X + 0.1, s * 0.5), m["soot"], p)
        cylinder(f"Beacon{s}", 0.04, cab_z1 + 0.03, cab_z1 + 0.11, (CAB_BACK_X + 0.1, s * 0.5), m["amber"], p)
    cylinder("AntennaMount", 0.035, cab_z1, cab_z1 + 0.06, (CAB_BACK_X + 0.12, -0.25), m["soot"], p)
    # Mirrors on arms out of the front corners, and a round convex one.
    for s in (1, -1):
        beam(f"MirrorArm{s}", (FRONT_X - 0.12, s * HALF_W, SCREEN_Z + 0.18), (FRONT_X - 0.1, s * (HALF_W + 0.17), SCREEN_Z + 0.22),
             0.025, 0.025, m["steel"], p, bevel=0.004)
        box(f"Mirror{s}", FRONT_X - 0.15, FRONT_X - 0.07, s * (HALF_W + 0.15), s * (HALF_W + 0.2), SCREEN_Z + 0.02,
            SCREEN_Z + 0.32, m["soot"], p, bevel=0.008)
        cylinder(f"Convex{s}", 0.045, 0, 0.03, (FRONT_X - 0.02, s * (HALF_W + 0.06), SCREEN_Z + 0.05), m["soot"], p, axis="x")
    # Front: bumper, tow shackles, headlights in the cab's face.
    box("Bumper", FRONT_X - 0.04, FRONT_X + 0.08, -HALF_W + 0.02, HALF_W - 0.02, 0.3, 0.46, m["dark"], p, bevel=0.012)
    for s in (1, -1):
        cylinder(f"Shackle{s}", 0.03, 0, 0.06, (FRONT_X + 0.08, s * 0.32, 0.38), m["steel"], p, axis="x")
        box(f"Headlight{s}", FRONT_X - 0.01, FRONT_X + 0.01, s * 0.4, s * 0.54, cab_z0 + 0.07, cab_z0 + 0.16, m["lens"], p)
    # Steps up to the doors, between the front wheels.
    for s in (1, -1):
        for k, z in enumerate((0.36, 0.56)):
            box(f"Step{s}{k}", door_x[0] + 0.02, door_x[0] + 0.3, s * (HALF_W - 0.1), s * (HALF_W - 0.02), z, z + 0.03,
                m["steel"], p)

    # --- The module behind the cab: the engine's housing.
    mx0, mx1 = MODULE_BACK_X, CAB_BACK_X - 0.01
    box("Module", mx0, mx1, -0.5, 0.5, 0.7, 1.4, m["olive"], p, bevel=0.03)
    for k in range(9):   # louvred vents across its top
        x = mx0 + 0.07 + k * 0.042
        box(f"Louvre{k}", x - 0.012, x + 0.012, -0.36, 0.2, 1.4, 1.408, m["soot"], p)
    box("VentFrame", mx0 + 0.035, mx0 + 0.43, -0.39, 0.23, 1.398, 1.402, m["dark"], p)
    cylinder("Exhaust", 0.045, 1.0, 1.85, (mx1 - 0.08, -0.47), m["soot"], p)
    cylinder("ExhaustCap", 0.05, 1.85, 1.88, (mx1 - 0.08, -0.47), m["soot"], p)
    box("ExhaustGuard", mx1 - 0.14, mx1 - 0.02, -0.55, -0.4, 1.0, 1.6, m["dark"], p, bevel=0.01)
    cylinder("Intake", 0.075, 1.0, 1.68, (mx1 - 0.1, 0.43), m["olive"], p)
    cylinder("RainCap", 0.1, 1.68, 1.72, (mx1 - 0.1, 0.43), m["dark"], p)
    box("Toolbox", mx0 + 0.04, mx0 + 0.3, 0.27, 0.47, 1.4, 1.5, m["dark"], p, bevel=0.01)

    # --- The crane bay: the turret's pedestal and the stabilisers' housings
    # (the beams and jacks that come out of them move: build_stabs()).
    box("Pedestal", BED_FRONT_X + 0.05, MODULE_BACK_X - 0.03, -0.42, 0.42, 0.55, CRANE_BASE_Z - 0.02, m["dark"], p, bevel=0.015)
    cylinder("SlewRing", 0.2, CRANE_BASE_Z - 0.04, CRANE_BASE_Z, (CRANE_X_M, 0), m["steel"], p, segs=40)
    for s in (1, -1):
        box(f"OutriggerBeam{s}", CRANE_X_M - 0.09, CRANE_X_M + 0.09, s * 0.42, s * STAB_HOUSING_END_M, 0.55, 0.7, m["olive"], p, bevel=0.01)
    box("Controls", CRANE_X_M - 0.1, CRANE_X_M + 0.08, -0.42, -0.36, 0.62, 0.9, m["dark"], p, bevel=0.008)
    for k in range(3):   # the operator's levers
        cylinder(f"Lever{k}", 0.008, 0.9, 0.97, (CRANE_X_M - 0.06 + k * 0.05, -0.39), m["soot"], p, segs=8)
    # Hydraulic tank and hoses to the turret.
    box("HydTank", MODULE_BACK_X - 0.2, MODULE_BACK_X - 0.04, 0.24, 0.42, CRANE_BASE_Z - 0.02, 1.0, m["olive"], p, bevel=0.012)

    # --- The flatbed.
    deck_t = 0.1
    by = BED_W / 2
    box("Deck", BED_BACK_X, BED_FRONT_X, -by, by, BED_Z - deck_t, BED_Z, m["deck"], p, bevel=0.008)
    for k in range(1, 10):   # the deck's plate seams
        x = BED_BACK_X + k * BED_L / 10
        box(f"Seam{k}", x - 0.004, x + 0.004, -by + 0.04, by - 0.04, BED_Z - 0.002, BED_Z + 0.001, m["dark"], p)
    for s in (1, -1):
        box(f"SideRail{s}", BED_BACK_X, BED_FRONT_X, s * (by - 0.03), s * by, BED_Z, BED_Z + 0.03, m["olive"], p, bevel=0.005)
        for k in range(6):
            x = BED_BACK_X + 0.12 + k * (BED_L - 0.24) / 5
            box(f"Pocket{s}{k}", x - 0.03, x + 0.03, s * by, s * (by + 0.03), BED_Z - 0.09, BED_Z + 0.015, m["dark"], p)
            ring = bpy.ops.mesh.primitive_torus_add(major_radius=0.022, minor_radius=0.006,
                                                    location=(x, s * (by - 0.06), BED_Z + 0.006))
            obj = bpy.context.active_object
            obj.name = f"TieDown{s}{k}"
            obj.data.materials.append(m["steel"])
            p.append(obj)
    # Headboard: a frame of posts and rails at the bed's front, protecting the crane.
    hx0, hx1 = BED_FRONT_X - 0.04, BED_FRONT_X
    for s in (1, -1):
        box(f"HeadPost{s}", hx0, hx1, s * (by - 0.05), s * by, BED_Z, 1.22, m["olive"], p, bevel=0.006)
    box("HeadTop", hx0, hx1, -by, by, 1.18, 1.22, m["olive"], p, bevel=0.006)
    box("HeadMid", hx0, hx1, -by, by, 0.96, 0.99, m["olive"], p, bevel=0.006)
    for k in range(5):
        y = (k - 2) * 0.22
        box(f"HeadBar{k}", hx0 + 0.008, hx1 - 0.008, y - 0.012, y + 0.012, BED_Z, 1.18, m["olive"], p)
    # Rear: bumper with tail lights and a pintle hook; mud flaps behind the tyres.
    box("RearBumper", REAR_X, BED_BACK_X, -0.55, 0.55, 0.46, 0.62, m["dark"], p, bevel=0.01)
    for s in (1, -1):
        box(f"TailLight{s}", REAR_X + 0.01, REAR_X + 0.07, s * 0.4, s * 0.5, 0.62, 0.66, m["red"], p)
    box("Pintle", REAR_X - 0.06, REAR_X, -0.05, 0.05, 0.47, 0.55, m["steel"], p, bevel=0.01)
    for s in (1, -1):
        box(f"MudFlap{s}", AXLES_X[3] - TYRE_R - 0.06, AXLES_X[3] - TYRE_R - 0.05, s * (TYRE_Y - TYRE_W / 2),
            s * (TYRE_Y + TYRE_W / 2), 0.2, 0.6, m["rubber"], p)
    # Fuel tank and battery box between the axles, under the crane bay.
    for s, name in ((1, "FuelTank"), (-1, "BatteryBox")):
        box(name, MODULE_BACK_X - 0.45, MODULE_BACK_X + 0.1, s * 0.4, s * 0.58, 0.3, 0.55, m["olive"], p, bevel=0.02)

    build_wheels(m["rubber"], m["olive"], p)
    return p, m


# ------------------------------------------------------------------- door --
def build_door(m):
    """The driver's door (the truck's left, +y), on its own so the game can
    swing it open about its hinge (DOOR_X[1], its front edge): a panel
    DOOR_T thick from the cab's floor to the windscreen's foot, then a window
    in a frame up to the roof's edge, a handle outside and one inside. In the
    body's picture the cab's side is shut; this is drawn only while it's open.
    Same for the other door, mirrored (it's lit from overhead)."""
    p = []
    x0, x1 = DOOR_X
    y0, y1 = HALF_W - DOOR_T, HALF_W
    z0, z_sill, z1 = CAB_Z[0] + 0.02, SCREEN_Z, CAB_Z[1] - 0.1
    box("DoorPanel", x0, x1, y0, y1, z0, z_sill, m["olive"], p, bevel=0.01)
    for name, (a, b) in (("DoorPostBack", (x0, x0 + 0.045)), ("DoorPostFront", (x1 - 0.045, x1))):
        box(name, a, b, y0, y1, z_sill, z1, m["olive"], p, bevel=0.008)
    box("DoorTop", x0, x1, y0, y1, z1 - 0.045, z1, m["olive"], p, bevel=0.008)
    box("DoorGlass", x0 + 0.04, x1 - 0.04, y0 + 0.02, y1 - 0.02, z_sill, z1 - 0.04, m["glass"], p)
    box("DoorHandleOut", x0 + 0.06, x0 + 0.16, y1, y1 + 0.015, z_sill - 0.06, z_sill - 0.035, m["steel"], p)
    box("DoorHandleIn", x0 + 0.06, x0 + 0.14, y0 - 0.015, y0, z_sill - 0.1, z_sill - 0.08, m["steel"], p)
    return p


# ------------------------------------------------------------------ crane --
def build_crane(m):
    """The turret, stowed: the slewing column on its ring at (CRANE_X_M, 0),
    the main boom raised steeply, the outer boom folded forward over the
    module, its hook hanging at the tip. Built in place on the truck."""
    p = []
    cx = CRANE_X_M
    z0 = CRANE_BASE_Z
    box("Turret", cx - 0.17, cx + 0.15, -0.15, 0.15, z0, z0 + 0.14, m["olive"], p, bevel=0.02)
    box("Column", cx - 0.11, cx + 0.09, -0.1, 0.1, z0 + 0.1, z0 + 0.82, m["olive"], p, bevel=0.02)
    pivot = Vector((cx - 0.02, 0, z0 + 0.78))
    knuckle = Vector((cx + 0.1, 0, z0 + 1.12))
    tip = Vector((cx + 0.95, 0, z0 + 1.0))
    beam("MainBoom", pivot, knuckle, 0.14, 0.15, m["olive"], p, bevel=0.015)
    beam("OuterBoom", knuckle + Vector((0.02, 0, -0.03)), tip, 0.11, 0.12, m["olive"], p, bevel=0.012)
    beam("Extension", tip - Vector((0.18, 0, 0.0)), tip + Vector((0.06, 0, -0.01)), 0.08, 0.085, m["dark"], p, bevel=0.01)
    # Hydraulic rams: the main one up the column's back to the boom, the
    # outer one along the outer boom's top; chrome rods out of olive barrels.
    beam("MainRamBarrel", Vector((cx - 0.12, 0, z0 + 0.25)), Vector((cx - 0.08, 0, z0 + 0.62)), 0.07, 0.07, m["olive"], p)
    beam("MainRamRod", Vector((cx - 0.08, 0, z0 + 0.62)), Vector((cx - 0.02, 0, z0 + 0.9)), 0.035, 0.035, m["steel"], p, bevel=0.0)
    beam("OuterRamBarrel", knuckle + Vector((0.05, 0, 0.1)), knuckle + Vector((0.4, 0, 0.07)), 0.065, 0.065, m["olive"], p)
    beam("OuterRamRod", knuckle + Vector((0.4, 0, 0.07)), knuckle + Vector((0.6, 0, 0.05)), 0.03, 0.03, m["steel"], p, bevel=0.0)
    # Hoses along the booms (black), either side.
    for s in (1, -1):
        beam(f"Hose{s}", pivot + Vector((0.02, s * 0.085, 0.02)), knuckle + Vector((0.03, s * 0.08, 0.02)),
             0.018, 0.018, m["rubber"], p, bevel=0.0)
        beam(f"HoseOuter{s}", knuckle + Vector((0.08, s * 0.07, 0.0)), tip - Vector((0.1, -s * 0.06, 0.0)),
             0.016, 0.016, m["rubber"], p, bevel=0.0)
    # The hook block, yellow, hanging under the tip, and a hook stowed against it.
    hook = material("Hook", YELLOW, roughness=0.5, shine=0.3)
    box("HookBlock", tip.x - 0.04, tip.x + 0.06, -0.05, 0.05, tip.z - 0.3, tip.z - 0.12, hook, p, bevel=0.012)
    cylinder("HookLine", 0.008, tip.z - 0.12, tip.z - 0.02, (tip.x + 0.01, 0), m["soot"], p, segs=8)
    cylinder("Sheave", 0.045, 0, 0.02, (tip.x + 0.05, -0.01, tip.z - 0.02), m["steel"], p, axis="y")
    return p


# ------------------------------------------------------------ stabilisers --
def smoothstep(a, b, t):
    t = min(max((t - a) / (b - a), 0.0), 1.0)
    return t * t * (3 - 2 * t)


def stab_pose(t):
    """How far out (m, from stowed) and how far down (m) at `t` (0 stowed .. 1 down)."""
    return (STAB_OUT_M - STAB_IN_M) * smoothstep(0.0, 0.55, t), STAB_FOOT_UP_M * smoothstep(0.45, 1.0, t)


def build_stabs(m):
    """The stabilisers' moving parts, stowed, either side (s 1 the left, -1 the
    right): an inner beam in the housing (most of it inside, hidden), a jack
    on its end (an olive barrel, a cap), and in the jack a steel ram with the
    foot pad on it. Each side's beam and jack hang from an empty that slides
    out ("StabSlide1"), the ram and pad from one under it that drops
    ("StabFoot1"), keyframed frame 0 to STAB_FRAMES - 1. Returns {s: parts}."""
    sides = {}
    scene = bpy.context.scene
    cx = CRANE_X_M
    for s in (1, -1):
        p = []
        slide = bpy.data.objects.new(f"StabSlide{s}", None)
        foot = bpy.data.objects.new(f"StabFoot{s}", None)
        scene.collection.objects.link(slide)
        scene.collection.objects.link(foot)
        foot.parent = slide
        y = s * STAB_IN_M
        moving = [
            box(f"StabBeam{s}", cx - 0.065, cx + 0.065, s * 0.3, s * (STAB_IN_M + 0.045), 0.57, 0.68, m["olive"], p, bevel=0.008),
            box(f"StabBeamEnd{s}", cx - 0.07, cx + 0.07, s * (STAB_IN_M + 0.02), s * (STAB_IN_M + 0.05), 0.555, 0.695, m["dark"], p, bevel=0.006),
            cylinder(f"StabBarrel{s}", 0.05, 0.3, 0.86, (cx, y), m["olive"], p),
            cylinder(f"StabCap{s}", 0.06, 0.86, STAB_TOP_M, (cx, y), m["dark"], p),
            cylinder(f"StabCapBolt{s}", 0.018, STAB_TOP_M, STAB_TOP_M + 0.01, (cx, y), m["steel"], p, segs=12),
        ]
        dropping = [
            cylinder(f"StabRam{s}", 0.03, STAB_FOOT_UP_M + 0.03, STAB_FOOT_UP_M + 0.36, (cx, y), m["steel"], p),
            cylinder(f"StabSwivel{s}", 0.045, STAB_FOOT_UP_M + 0.025, STAB_FOOT_UP_M + 0.055, (cx, y), m["dark"], p),
            cylinder(f"StabPad{s}", 0.1, STAB_FOOT_UP_M, STAB_FOOT_UP_M + 0.03, (cx, y), m["dark"], p, segs=32),
            cylinder(f"StabPadRim{s}", 0.104, STAB_FOOT_UP_M + 0.005, STAB_FOOT_UP_M + 0.022, (cx, y), m["steel"], p, segs=32),
        ]
        for obj in moving:
            obj.parent = slide
        for obj in dropping:
            obj.parent = foot
        for k in range(STAB_FRAMES):
            out, down = stab_pose(k / (STAB_FRAMES - 1))
            slide.location = (0, s * out, 0)
            foot.location = (0, 0, -down)
            slide.keyframe_insert("location", frame=k)
            foot.keyframe_insert("location", frame=k)
        sides[s] = p
    scene.frame_start, scene.frame_end = 0, STAB_FRAMES - 1
    scene.frame_set(0)
    return sides


def frame_pixels(scene, path):
    """Render the camera's view to `path`, and return it as an (h, w, 4) array."""
    import numpy as np
    bs.render_to(scene, path)
    img = bpy.data.images.load(path)
    w, h = img.size
    px = np.empty(w * h * 4, dtype=np.float32)
    img.pixels.foreach_get(px)
    bpy.data.images.remove(img)
    return px.reshape(h, w, 4)


def save_sheet(frames, path):
    """The frames side by side, left to right (as character_square.py's)."""
    import numpy as np
    sheet = np.concatenate(frames, axis=1)
    h, w = sheet.shape[:2]
    img = bpy.data.images.new(os.path.basename(path), w, h, alpha=True)
    img.pixels.foreach_set(sheet.ravel())
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()
    print(f"Saved {path} ({len(frames)} frames, {w}x{h})")


# -------------------------------------------------------------- previews --
def build_ground():
    """The field's own grass tile under everything (12 m square)."""
    img = bpy.data.images.load(os.path.join(ROOT, "assets", "textures", "field_grass_tile.png"))
    mat = bpy.data.materials.new("Grass")
    nt = bs.node_tree_of(mat)
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = img
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.9
    if "Specular IOR Level" in bsdf.inputs:
        bsdf.inputs["Specular IOR Level"].default_value = 0.1
    bpy.ops.mesh.primitive_plane_add(size=12.0, location=(0, 0, 0))
    plane = bpy.context.active_object
    plane.data.materials.append(mat)
    return plane


def build_crates():
    """Two of the game's ammo crates (crates.py) on the bed, one behind the other."""
    import crates
    gap = (BED_L - 0.04 - 2 * crates.PALLET_L) / 3
    first = BED_FRONT_X - 0.04 - gap - crates.PALLET_L / 2
    added = []
    for k, x in enumerate((first, first - crates.PALLET_L - gap)):
        before = set(bpy.data.objects)
        footprint, top = crates.build_ammo_load(seed=7 + k)
        crates.build_straps(footprint, top)
        crates.build_pallet(crates.wood_material())
        for obj in set(bpy.data.objects) - before:
            if obj.parent is None:
                obj.location = Vector(obj.location) + Vector((x, 0, BED_Z))
            added.append(obj)
    print(f"bed {BED_L:.2f} x {BED_W:.2f} m, deck {BED_Z} m up: two {crates.PALLET_L} m pallets, "
          f"{gap:.2f} m apart, at x {first:.2f} and {first - crates.PALLET_L - gap:.2f}")
    return added


def build_square(at):
    """The player's red square (character_square.py's block, roughly), for scale."""
    mat = material("SquareRed", SQUARE_RED, roughness=0.38, shine=0.5)
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=0.4)
    bmesh.ops.translate(bm, verts=bm.verts, vec=(0, 0, 0.2))
    bmesh.ops.bevel(bm, geom=list(bm.edges), offset=0.035, segments=4, profile=0.5, affect="EDGES")
    me = bpy.data.meshes.new("Square")
    bm.to_mesh(me)
    bm.free()
    obj = link("Square", me, [mat], smooth=True)
    obj.location = (at[0], at[1], 0)
    return obj


# ------------------------------------------------------------------- main --
def main():
    for path in (OUT_BODY, OUT_PREVIEW, OUT_BLEND):
        os.makedirs(os.path.dirname(path), exist_ok=True)
    px = bs.PX_PER_M * RENDER_SCALE
    scene = bs.new_scene(center=(0, 0), frame_m=BODY_FRAME_M, transparent=True, samples=SAMPLES, px_per_m=px)
    sun = bpy.data.objects["Sun"]
    sun.rotation_euler = (0, 0, 0)   # straight overhead: any heading looks right
    body, mats = build_body()
    crane = build_crane(mats)
    door = build_door(mats)
    stab_sides = build_stabs(mats)
    stabs = stab_sides[1] + stab_sides[-1]
    for obj in stabs:   # (out of the body's, the door's, the tyre's and the turret's pictures: their own, below)
        obj.hide_render = True

    # The door on its own, round its middle, and its shadow outline; then
    # it's out of everything else. Everything else is out of the render, not
    # just the camera's view: the cab's roof over it would leave it in shadow,
    # and it's drawn swung out from under it.
    door_mid = ((DOOR_X[0] + DOOR_X[1]) / 2, HALF_W - DOOR_T / 2)
    for obj in body + crane:
        obj.hide_render = True
    bs.frame_camera(scene, door_mid, DOOR_FRAME_M, px)
    bs.render_to(scene, OUT_DOOR)
    bs.frame_camera(scene, door_mid, DOOR_SHADOW_FRAME_M, bs.PX_PER_M / 2)
    bs.render_to(scene, os.path.join(os.path.dirname(OUT_DOOR) if _args[:1] == ["draft"] else SHADOW_DIR,
                                     "supply_truck_shadow_door.png"))
    for obj in body + crane:
        obj.hide_render = False
        obj.visible_camera = True
    for obj in door:
        obj.hide_render = True

    # One tyre on its own (the left front, with its hub), with nothing over
    # it: the game draws all eight from it (the right ones mirrored), under
    # the squares, so one getting in goes over the tyres and under the cab
    # (Mike, 2026-11-03), and turns the front ones as it steers. They're out
    # of the body's picture.
    wheels = [o for o in body if o.name.split(".")[0].startswith(("Tyre", "Hub"))]
    one = [o for o in wheels if o.name.split(".")[0] in ("Tyre01", "Hub01", "HubCap01")]
    for obj in body + crane:
        obj.hide_render = obj not in one
    bs.frame_camera(scene, (AXLES_X[0], TYRE_Y), TYRE_FRAME_M, px)
    bs.render_to(scene, OUT_TYRE)
    for obj in body + crane:
        obj.hide_render = obj in wheels
    bs.frame_camera(scene, (0, 0), BODY_FRAME_M, px)

    # The body, without the crane's turret (it turns: its own image) or the tyres.
    for obj in crane:
        obj.hide_render = True
    bs.render_to(scene, OUT_BODY)
    for obj in crane + wheels:
        obj.hide_render = False

    # The turret on its own, centred on its slewing axis; the body still
    # there for the light, but not seen.
    for obj in body:
        obj.visible_camera = False
    bs.frame_camera(scene, (CRANE_X_M, 0), CRANE_FRAME_M, px)
    bs.render_to(scene, OUT_CRANE)
    for obj in body:
        obj.visible_camera = True

    # Shadow outlines, half density: the body's groups round its middle, the
    # turret's round its axis.
    def group_of(obj):
        name = obj.name.split(".")[0]
        return next((g for g, prefixes in SHADOW_GROUPS.items() if any(name.startswith(p) for p in prefixes)), "low")
    shadow_dir = os.path.dirname(OUT_BODY) if _args[:1] == ["draft"] else SHADOW_DIR
    bs.frame_camera(scene, (0, 0), SHADOW_FRAME_M, bs.PX_PER_M / 2)
    for obj in crane:
        obj.hide_render = True
    for group in ["low", *SHADOW_GROUPS]:
        for obj in body:
            obj.hide_render = group_of(obj) != group
        bs.render_to(scene, os.path.join(shadow_dir, f"supply_truck_shadow_{group}.png"))
    for obj in body:
        obj.hide_render = True
    for obj in crane:
        obj.hide_render = False
    bs.frame_camera(scene, (CRANE_X_M, 0), CRANE_SHADOW_FRAME_M, bs.PX_PER_M / 2)
    bs.render_to(scene, os.path.join(shadow_dir, "supply_truck_shadow_crane.png"))
    for obj in body:
        obj.hide_render = False

    # The stabilisers' animation: the left one, frame by frame, round
    # STAB_FRAME_AT. The body's there as a holdout: it hides what's inside the
    # housing and under the pedestal (cut out of the picture, transparent), so
    # the game draws the sheet over the body. Then its shadow outline, alone.
    for obj in crane:
        obj.hide_render = True
    for obj in body:
        obj.is_holdout = True
    for obj in stab_sides[1]:
        obj.hide_render = False
    tmp = os.path.join(tempfile.gettempdir(), "bs_stab_frame_tmp.png")   # (not in the project: Godot would import it)
    bs.frame_camera(scene, STAB_FRAME_AT, STAB_FRAME_M, px)
    frames = []
    for k in range(STAB_FRAMES):
        scene.frame_set(k)
        frames.append(frame_pixels(scene, tmp))
    save_sheet(frames, OUT_STABS)
    for obj in body:
        obj.is_holdout = False
        obj.hide_render = True
    bs.frame_camera(scene, STAB_FRAME_AT, STAB_SHADOW_FRAME_M, bs.PX_PER_M / 2)
    frames = []
    for k in range(STAB_FRAMES):
        scene.frame_set(k)
        frames.append(frame_pixels(scene, tmp))
    save_sheet(frames, os.path.join(shadow_dir, "supply_truck_shadow_stabilizer_sheet.png"))
    os.remove(tmp)
    scene.frame_set(0)
    for obj in body + crane + stabs:
        obj.hide_render = False

    # Previews: the standard sun, the field's grass, two crates on the bed and
    # a red square beside it.
    sun.rotation_euler = (math.radians(bs.SUN_TILT_DEG), 0, math.radians(bs.SUN_HEADING_DEG))
    build_ground()
    build_crates()
    build_square((-0.3, -1.25))
    scene.render.film_transparent = False
    bs.frame_camera(scene, (0, -0.2), 6.0, px)
    bs.render_to(scene, OUT_PREVIEW)
    bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND)

    cam = bpy.data.objects.new("Review", bpy.data.cameras.new("Review"))
    scene.collection.objects.link(cam)
    cam.data.lens = 45
    target = Vector((0.1, 0, 0.75))
    cam.location = Vector((5.2, -5.6, 3.4))
    cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam
    scene.render.resolution_x, scene.render.resolution_y = 1400, 900
    bs.render_to(scene, OUT_ANGLE)

    # The stabilisers down, close up from the left side's front.
    scene.frame_set(STAB_FRAMES - 1)
    target = Vector((CRANE_X_M, 0.7, 0.4))
    cam.location = Vector((2.0, 3.0, 1.5))
    cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.render.resolution_x, scene.render.resolution_y = 1000, 800
    bs.render_to(scene, OUT_STAB_PREVIEW)
    scene.frame_set(0)


if __name__ == "__main__":
    main()
