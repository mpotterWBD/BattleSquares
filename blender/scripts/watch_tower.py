"""Render a guard watch tower as a top-down prop, at real size, in its five
build parts (after Mike's reference photo, 2026-11-01: a cream cabin with
a band of dark windows on a galvanised steel frame, an air conditioner on
the deck, and a switchback stair up the side).

Run headless:
    blender --background --python watch_tower.py

Pieces (metres; +x = screen right, +y = screen up; the origin is the middle
of the deck, so the deploy ghost centres on it):
  - "base": four splayed square-tube legs on foot plates, from about
    (+-1.6, +-1.6) on the ground up to the deck's corners, with a ring
    beam and X bracing on every face up to the first tier
  - "platform" (the rest of the base): the upper tier of X bracing, the deck
    frame, a DECK_M square grating deck DECK_Z up, and a railing with toe
    boards round it (open where the stair comes in)
  - "stairs": a switchback stair on the east side: a top landing level with
    the deck, a flight down south to a mid landing on posts, and a second
    flight down to the ground, with stringers, grating treads and handrails
  - "roof": the cabin, cream walls with a band of dark windows and a door
    toward the stair, under a flat overhanging roof
  - "details": the window frames, a sign on the south wall, the air
    conditioner (outdoor unit on the deck, indoor box on the wall), a
    searchlight, a whip antenna, a camera and a vent on the roof, and a
    conduit down the north-east leg

Lit by the normal top-left sun (bs_common), each part rendered on its own at
RENDER_SCALE x the game's pixel density, all in the same FRAME_M square
centred on the deck's middle, as it shows in the finished tower (cut where a
part the game draws under it is in front: DRAW_ORDER; the other parts'
shadows fall on it), and each part's shadow alone on a shadow
catcher (normalised to fully opaque: the game sets the shadows' strength):
  assets/props/watch_tower_<part>.png
  assets/props/watch_tower_shadow_<part>.png
  assets/props/watch_tower_roof_open.png         the cabin with its roof off (anyone inside)
  assets/previews/watch_tower_preview.png        top-down with its shadow, on grey
  assets/previews/watch_tower_angle_preview.png  an angled look, like the photo
scenes/watch_tower.tscn's collisions match LEG_FOOT, STAIR_* below.
"""

import math
import os
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bs_common as bs  # noqa: E402

ROOT = bs.ROOT
OUT_PART = os.path.join(ROOT, "assets", "props", "watch_tower_{}.png")
OUT_SHADOW = os.path.join(ROOT, "assets", "props", "watch_tower_shadow_{}.png")
OUT_PREVIEW = os.path.join(ROOT, "assets", "previews", "watch_tower_preview.png")
OUT_ANGLE = os.path.join(ROOT, "assets", "previews", "watch_tower_angle_preview.png")
OUT_BLEND = os.path.join(ROOT, "blender", "source", "watch_tower.blend")

RENDER_SCALE = 2
FRAME_M = 12.0          # 2048 rendered px: the tower, its stair and the roof's shadow
SAMPLES = 96
SHADOW_ALPHA = 0.71     # open-ground shadow level (character_square.py), for normalising
SUN_SOFTNESS_DEG = 1.0  # near-real sun width, so thin tubes still cast shadows (as radio_station.py)

PARTS = ["base", "platform", "stairs", "roof", "details"]
## The order the game draws them in, bottom first (watch_tower.tscn z_index).
DRAW_ORDER = ["base", "stairs", "platform", "roof", "details"]
## The roof's own pieces, left off for the cabin seen with its roof off.
ROOF_LID = {"Roof_Slab", "Roof_Top", "Roof_Seam"}
OUT_ROOF_OPEN = os.path.join(ROOT, "assets", "props", "watch_tower_roof_open.png")

# The frame.
DECK_Z = 3.0            # the deck's walking surface
DECK_M = 2.8            # the deck, square
LEG_FOOT = 1.6          # legs stand at (+-LEG_FOOT, +-LEG_FOOT) on the ground
LEG_TOP = 1.32          # and meet the deck frame at (+-LEG_TOP, +-LEG_TOP)
FRAME_TOP = DECK_Z - 0.2
TIER_Z = 1.5            # the ring beam between the two tiers of bracing

# The stair, on the east side: x STAIR_X0..STAIR_X1, top landing at deck level
# y STAIR_TOP_Y..DECK top edge, flights down to the south.
STAIR_X0, STAIR_X1 = 1.6, 2.4
STAIR_TOP_Y = 0.6                       # the top landing's south edge, where flight 1 starts down (0.8 m open onto the deck)
MID_Z = 1.5
MID_Y0, MID_Y1 = -1.1, -2.0             # the mid landing (north, south edge)
STAIR_FOOT_Y = -4.1                     # where flight 2 meets the ground

# The cabin.
CABIN_AT = Vector((-0.3, 0.3))
CABIN_M = 2.0
CABIN_H = 2.3
ROOF_OVER = 0.15
## The door in the shelter's east wall (y range; watch_tower.gd DOOR_Y, flipped).
DOOR_Y = (CABIN_AT.y + 0.45 - 0.425, CABIN_AT.y + 0.45 + 0.425)

GALV = (0.64, 0.65, 0.64)
GALV_DARK = (0.42, 0.43, 0.43)
CREAM = (0.86, 0.79, 0.6)
ROOF_TOP = (0.8, 0.77, 0.68)
GLASS = (0.04, 0.06, 0.09)
FRAME_GREY = (0.2, 0.21, 0.22)
WHITE = (0.88, 0.88, 0.85)
BLACK = (0.03, 0.03, 0.03)
SIGN_GREEN = (0.1, 0.32, 0.18)


# ------------------------------------------------------------- materials --

def material(name, rgb, metallic=0.0, roughness=0.6, emit=0.0):
    mat = bpy.data.materials.new(name)
    nt = bs.node_tree_of(mat)
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (*bs.srgb(*rgb), 1.0)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    if emit:
        bsdf.inputs["Emission Color"].default_value = (*bs.srgb(*rgb), 1.0)
        bsdf.inputs["Emission Strength"].default_value = emit
    return mat


def grating_material(name):
    """Galvanised bar grating: bright bars with dark gaps between them (a
    brick texture in metres, so every panel's bars are the same size)."""
    mat = material(name, GALV, metallic=0.8, roughness=0.45)
    nt = mat.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    coord = nt.nodes.new("ShaderNodeTexCoord")
    brick = nt.nodes.new("ShaderNodeTexBrick")
    brick.inputs["Scale"].default_value = 1.0
    brick.inputs["Brick Width"].default_value = 0.1
    brick.inputs["Row Height"].default_value = 0.035
    brick.inputs["Mortar Size"].default_value = 0.006
    brick.offset = 0.0
    brick.inputs["Color1"].default_value = (*bs.srgb(*GALV), 1)
    brick.inputs["Color2"].default_value = (*bs.srgb(*GALV_DARK), 1)
    brick.inputs["Mortar"].default_value = (*bs.srgb(0.22, 0.22, 0.21), 1)
    nt.links.new(coord.outputs["Object"], brick.inputs["Vector"])
    nt.links.new(brick.outputs["Color"], bsdf.inputs["Base Color"])
    return mat


# ---------------------------------------------------------------- shapes --

def add(name, mesh, mat, smooth=False):
    mesh.materials.append(mat)
    if smooth:
        mesh.shade_smooth()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def box(name, center, size, mat, bevel=0.0):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, verts=bm.verts, vec=size)
    if bevel:
        bmesh.ops.bevel(bm, geom=list(bm.edges), offset=bevel, segments=2, profile=0.5, affect="EDGES")
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    obj = add(name, me, mat)
    obj.location = center
    return obj


def beam(name, a, b, w, h, mat):
    """A box-section member from point a to point b, `w` wide and `h` deep,
    kept upright (its depth toward +z) unless it's vertical."""
    a, b = Vector(a), Vector(b)
    d = (b - a)
    length = d.length
    d.normalize()
    up = Vector((0, 0, 1)) if abs(d.z) < 0.99 else Vector((0, 1, 0))
    side = up.cross(d).normalized()
    up2 = d.cross(side)
    obj = box(name, (0, 0, 0), (length, w, h), mat)
    rot = Matrix((d, side, up2)).transposed().to_4x4()
    obj.matrix_world = Matrix.Translation((a + b) / 2) @ rot
    return obj


def rod(name, a, b, radius, mat, segs=12):
    a, b = Vector(a), Vector(b)
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=segs, radius1=radius, radius2=radius,
                          depth=(b - a).length)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    obj = add(name, me, mat, smooth=True)
    obj.location = (a + b) / 2
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(b - a)
    return obj


def leg_at(sx, sy, z):
    """Where the leg at corner (sx, sy) is at height z."""
    t = z / FRAME_TOP
    r = LEG_FOOT + (LEG_TOP - LEG_FOOT) * t
    return Vector((sx * r, sy * r, z))


# ------------------------------------------------------------------ build --

def build_base(galv, galv_dark):
    corners = [(1, 1), (-1, 1), (-1, -1), (1, -1)]   # round the square
    for sx, sy in corners:
        beam("Base_Leg", leg_at(sx, sy, 0.02), leg_at(sx, sy, FRAME_TOP), 0.12, 0.12, galv)
        foot = leg_at(sx, sy, 0)
        box("Base_FootPlate", foot + Vector((0, 0, 0.01)), (0.36, 0.36, 0.02), galv_dark)
        for bx in (-1, 1):
            for by in (-1, 1):
                rod("Base_Bolt", foot + Vector((bx * 0.13, by * 0.13, 0.02)),
                    foot + Vector((bx * 0.13, by * 0.13, 0.06)), 0.014, galv_dark, segs=6)
    for k in range(4):
        (ax, ay), (bx_, by_) = corners[k], corners[(k + 1) % 4]
        for z in (0.3, TIER_Z):
            beam("Base_Ring", leg_at(ax, ay, z), leg_at(bx_, by_, z), 0.07, 0.07, galv)
        beam("Base_Brace", leg_at(ax, ay, 0.3), leg_at(bx_, by_, TIER_Z), 0.05, 0.05, galv)
        beam("Base_Brace", leg_at(bx_, by_, 0.3), leg_at(ax, ay, TIER_Z), 0.05, 0.05, galv)


def railing(prefix, a, b, z, mat, posts=True):
    """A guard rail along a -> b (x, y) at walking height z: posts, a top
    and mid rail and a toe board."""
    a, b = Vector((a[0], a[1], z)), Vector((b[0], b[1], z))
    n = max(1, round((b - a).length / 0.7))
    if posts:
        for i in range(n + 1):
            p = a + (b - a) * (i / n)
            beam(prefix + "Post", p, p + Vector((0, 0, 1.1)), 0.05, 0.05, mat)
    beam(prefix + "Rail", a + Vector((0, 0, 1.1)), b + Vector((0, 0, 1.1)), 0.05, 0.05, mat)
    beam(prefix + "MidRail", a + Vector((0, 0, 0.55)), b + Vector((0, 0, 0.55)), 0.035, 0.035, mat)
    beam(prefix + "Toe", a + Vector((0, 0, 0.05)), b + Vector((0, 0, 0.05)), 0.01, 0.1, mat)


def build_platform(galv, galv_dark, grating):
    corners = [(1, 1), (-1, 1), (-1, -1), (1, -1)]
    for k in range(4):
        (ax, ay), (bx_, by_) = corners[k], corners[(k + 1) % 4]
        beam("Platform_Brace", leg_at(ax, ay, TIER_Z), leg_at(bx_, by_, FRAME_TOP), 0.05, 0.05, galv)
        beam("Platform_Brace", leg_at(bx_, by_, TIER_Z), leg_at(ax, ay, FRAME_TOP), 0.05, 0.05, galv)
        beam("Platform_Frame", leg_at(ax, ay, FRAME_TOP + 0.05), leg_at(bx_, by_, FRAME_TOP + 0.05), 0.1, 0.18, galv)
    h = DECK_M / 2
    # Joists across the frame, then the grating deck on them.
    for x in (-0.7, 0.0, 0.7):
        beam("Platform_Joist", (x, -h + 0.05, DECK_Z - 0.12), (x, h - 0.05, DECK_Z - 0.12), 0.08, 0.14, galv_dark)
    box("Platform_Deck", (0, 0, DECK_Z - 0.025), (DECK_M, DECK_M, 0.05), grating)
    box("Platform_Edge", (0, 0, DECK_Z - 0.06), (DECK_M + 0.04, DECK_M + 0.04, 0.1), galv_dark)
    # The railing round the edge, open on the east side where the stair comes in.
    railing("Platform_", (-h, h), (h, h), DECK_Z, galv)
    railing("Platform_", (-h, -h), (-h, h), DECK_Z, galv)
    railing("Platform_", (-h, -h), (h, -h), DECK_Z, galv)
    railing("Platform_", (h, -h), (h, STAIR_TOP_Y), DECK_Z, galv)
    # White lines on the deck framing the shelter's doorway (Mike, 2026-11-01:
    # no black mat, white not yellow), so it shows from above with the roof on.
    d0, d1 = DOOR_Y
    mat_x0 = CABIN_AT.x + CABIN_M / 2
    mat_x1 = mat_x0 + 0.55
    white = material("MatEdge", (0.92, 0.92, 0.9), roughness=0.6)
    for y_edge in (d0, d1):
        box("Platform_MatEdge", ((mat_x0 + mat_x1) / 2, y_edge, DECK_Z + 0.008), (mat_x1 - mat_x0, 0.05, 0.016), white)
    box("Platform_MatEdge", (mat_x1, (d0 + d1) / 2, DECK_Z + 0.008), (0.05, d1 - d0 + 0.05, 0.016), white)


def flight(prefix, y_top, z_top, y_bottom, z_bottom, galv, grating):
    """A straight flight of steps down from (y_top, z_top) to (y_bottom,
    z_bottom), between STAIR_X0 and STAIR_X1: two stringers, grating treads,
    a handrail each side."""
    rise = z_top - z_bottom
    steps = max(2, round(rise / 0.19))
    run = (y_top - y_bottom) / steps
    for sx in (STAIR_X0 + 0.04, STAIR_X1 - 0.04):
        beam(prefix + "Stringer", (sx, y_top, z_top - 0.12), (sx, y_bottom, z_bottom - 0.12), 0.06, 0.2, galv)
        a = Vector((sx, y_top, z_top + 1.0))
        b = Vector((sx, y_bottom, z_bottom + 1.0))
        beam(prefix + "Handrail", a, b, 0.045, 0.045, galv)
        for t in (0.0, 0.5, 1.0):
            p = a.lerp(b, t)
            beam(prefix + "RailPost", p - Vector((0, 0, 1.0)), p, 0.04, 0.04, galv)
    w = STAIR_X1 - STAIR_X0 - 0.12
    for i in range(1, steps + 1):
        y = y_top - run * (i - 0.5)
        z = z_top - rise * i / steps
        box(prefix + "Tread", ((STAIR_X0 + STAIR_X1) / 2, y, z - 0.015), (w, run + 0.02, 0.03), grating)


def build_stairs(galv, galv_dark, grating):
    xm, w = (STAIR_X0 + STAIR_X1) / 2, STAIR_X1 - STAIR_X0
    top_y1 = DECK_M / 2 + 0.4
    # Top landing, level with the deck, joined to its east edge.
    box("Stairs_TopLanding", (xm - 0.1, (STAIR_TOP_Y + top_y1) / 2, DECK_Z - 0.025),
        (w + 0.2, top_y1 - STAIR_TOP_Y, 0.05), grating)
    beam("Stairs_TopFrame", (STAIR_X0 - 0.2, top_y1, DECK_Z - 0.1), (STAIR_X1, top_y1, DECK_Z - 0.1), 0.08, 0.14, galv)
    railing("Stairs_", (STAIR_X0 - 0.2, top_y1), (STAIR_X1, top_y1), DECK_Z, galv)
    railing("Stairs_", (STAIR_X1, STAIR_TOP_Y), (STAIR_X1, top_y1), DECK_Z, galv)
    # Every open edge railed (Mike, 2026-11-02: three were missing): the
    # landing's west side where it sticks out past the deck's north edge, and
    # its south edge between the deck and the flight's handrail.
    railing("Stairs_", (STAIR_X0 - 0.2, DECK_M / 2), (STAIR_X0 - 0.2, top_y1), DECK_Z, galv)
    railing("Stairs_", (STAIR_X0 - 0.2, STAIR_TOP_Y), (STAIR_X0, STAIR_TOP_Y), DECK_Z, galv)
    flight("Stairs_", STAIR_TOP_Y, DECK_Z, MID_Y0, MID_Z, galv, grating)
    # Mid landing on four posts.
    box("Stairs_MidLanding", (xm, (MID_Y0 + MID_Y1) / 2, MID_Z - 0.025), (w, MID_Y0 - MID_Y1, 0.05), grating)
    for px in (STAIR_X0 + 0.05, STAIR_X1 - 0.05):
        for py in (MID_Y0 - 0.05, MID_Y1 + 0.05):
            beam("Stairs_LandingPost", (px, py, 0.0), (px, py, MID_Z - 0.05), 0.08, 0.08, galv)
            box("Stairs_PostFoot", (px, py, 0.01), (0.2, 0.2, 0.02), galv_dark)
    # Both sides of the mid landing (it's open to the flights at its ends: no
    # rail across the way down).
    railing("Stairs_", (STAIR_X1, MID_Y1), (STAIR_X1, MID_Y0), MID_Z, galv)
    railing("Stairs_", (STAIR_X0, MID_Y1), (STAIR_X0, MID_Y0), MID_Z, galv)
    flight("Stairs_", MID_Y1, MID_Z, STAIR_FOOT_Y, 0.0, galv, grating)


def build_roof(cream, roof_top, glass, galv_dark):
    """The cabin: walls with a band of dark windows (south, west and north)
    and a door in the east wall, under an overhanging flat roof."""
    cx, cy = CABIN_AT
    h = CABIN_M / 2
    z0, z1 = DECK_Z, DECK_Z + CABIN_H
    t = 0.07
    sill, head = z0 + 1.0, z0 + 1.95
    walls = [((cx, cy + h - t / 2), (CABIN_M, t)), ((cx, cy - h + t / 2), (CABIN_M, t)),
             ((cx - h + t / 2, cy), (t, CABIN_M)), ((cx + h - t / 2, cy), (t, CABIN_M))]
    for k, ((x, y), (sx, sy)) in enumerate(walls):
        windowed = k != 3   # the east wall has the door instead
        if windowed:
            box("Roof_WallLow", (x, y, (z0 + sill) / 2), (sx, sy, sill - z0), cream)
            box("Roof_WallHigh", (x, y, (head + z1) / 2), (sx, sy, z1 - head), cream)
            for end in (-1, 1):   # wall at the corners between the windows
                if sx > sy:
                    box("Roof_WallCorner", (x + end * (h - 0.12), y, (sill + head) / 2), (0.24, sy, head - sill), cream)
                else:
                    box("Roof_WallCorner", (x, y + end * (h - 0.12), (sill + head) / 2), (sx, 0.24, head - sill), cream)
            gx, gy = (sx - 0.48, 0.02) if sx > sy else (0.02, sy - 0.48)
            box("Roof_Glass", (x, y, (sill + head) / 2), (gx, gy, head - sill), glass)
        else:
            # The door: a real opening in the east wall (DOOR_Y), framed in dark
            # steel, a lintel over it, a threshold, and the door standing open
            # inward against the north wall, so it reads from above with the
            # roof off (Mike, 2026-11-01). White lines on the deck show it with
            # the roof on (build_platform()).
            d0, d1 = DOOR_Y
            frame = material("DoorFrame", (0.2, 0.21, 0.22), metallic=0.4, roughness=0.5)
            for a, b in ((cy - h, d0), (d1, cy + h)):
                box("Roof_Wall", (x, (a + b) / 2, (z0 + z1) / 2), (sx, b - a, z1 - z0), cream)
            box("Roof_Lintel", (x, (d0 + d1) / 2, (z0 + 2.05 + z1) / 2), (sx, d1 - d0, z1 - z0 - 2.05), cream)
            for y_edge in (d0, d1):
                box("Roof_DoorPost", (x, y_edge, z0 + 1.025), (sx + 0.05, 0.06, 2.05), frame)
            box("Roof_DoorHead", (x, (d0 + d1) / 2, z0 + 2.05), (sx + 0.05, d1 - d0 + 0.06, 0.06), frame)
            box("Roof_Threshold", (x, (d0 + d1) / 2, z0 + 0.05), (sx + 0.1, d1 - d0, 0.02),
                material("Threshold", (0.92, 0.92, 0.9), roughness=0.6))   # white, like the lines on the deck
            leaf = d1 - d0 - 0.06
            box("Roof_Door", (x - t / 2 - leaf / 2, d1 - 0.05, z0 + 1.0), (leaf, 0.04, 1.95),
                material("Door", (0.62, 0.56, 0.42), roughness=0.6))
            box("Roof_DoorHandle", (x - t / 2 - leaf + 0.08, d1 - 0.09, z0 + 1.0), (0.03, 0.05, 0.12), frame)
    box("Roof_Floor", (cx, cy, z0 + 0.02), (CABIN_M, CABIN_M, 0.04), galv_dark)
    box("Roof_Slab", (cx, cy, z1 + 0.07), (CABIN_M + 2 * ROOF_OVER, CABIN_M + 2 * ROOF_OVER, 0.14), cream, bevel=0.01)
    box("Roof_Top", (cx, cy, z1 + 0.145), (CABIN_M + 2 * ROOF_OVER - 0.12, CABIN_M + 2 * ROOF_OVER - 0.12, 0.01), roof_top)
    for k in (-1, 0, 1):   # seams between the roof's panels
        box("Roof_Seam", (cx + k * 0.6, cy, z1 + 0.152), (0.03, CABIN_M + 2 * ROOF_OVER - 0.14, 0.008),
            material("Seam", (0.66, 0.63, 0.55), roughness=0.8))


def build_details(galv, galv_dark, white, black):
    cx, cy = CABIN_AT
    h = CABIN_M / 2
    z0, z1 = DECK_Z, DECK_Z + CABIN_H
    frame = material("WindowFrame", FRAME_GREY, metallic=0.4, roughness=0.5)
    sill, head = z0 + 1.0, z0 + 1.95
    # Window frames: a sill and head on each windowed wall, and mullions.
    for (x, y, along_x, out) in ((cx, cy + h, True, 1), (cx, cy - h, True, -1), (cx - h, cy, False, -1)):
        for z in (sill, head):
            if along_x:
                box("Details_Sill", (x, y + out * 0.02, z), (CABIN_M - 0.44, 0.09, 0.05), frame)
            else:
                box("Details_Sill", (x + out * 0.02, y, z), (0.09, CABIN_M - 0.44, 0.05), frame)
        for k in (-1, 0, 1):
            if along_x:
                box("Details_Mullion", (x + k * 0.5, y + out * 0.02, (sill + head) / 2), (0.05, 0.06, head - sill), frame)
            else:
                box("Details_Mullion", (x + out * 0.02, y + k * 0.5, (sill + head) / 2), (0.06, 0.05, head - sill), frame)
    # A sign over the south windows.
    box("Details_Sign", (cx, cy - h - 0.03, head + 0.18), (0.8, 0.02, 0.22), material("Sign", SIGN_GREEN, roughness=0.5))
    box("Details_SignText", (cx, cy - h - 0.045, head + 0.18), (0.6, 0.01, 0.06), white)
    # Air conditioner: the outdoor unit on the deck by the cabin's east wall,
    # its fan facing east, and the indoor box high on the wall outside.
    ac = Vector((cx + h + 0.25, cy - 0.45, DECK_Z))
    box("Details_AcUnit", ac + Vector((0, 0, 0.3)), (0.32, 0.8, 0.58), white, bevel=0.015)
    rod("Details_AcFan", ac + Vector((0.16, 0, 0.3)), ac + Vector((0.18, 0, 0.3)), 0.21, black, segs=24)
    for k in range(4):
        box("Details_AcVent", ac + Vector((0, -0.3 + k * 0.2, 0.595)), (0.26, 0.04, 0.01), material("Vent", (0.6, 0.6, 0.58)))
    for y in (-0.3, 0.3):
        box("Details_AcFoot", ac + Vector((0, y, 0.01)), (0.36, 0.06, 0.02), black)
    rod("Details_AcPipe", ac + Vector((-0.12, 0.35, 0.45)), Vector((cx + h, cy - 0.05, z0 + 0.45)), 0.02, white, segs=8)
    box("Details_AcIndoor", (cx + h + 0.1, cy - 0.45, z1 - 0.35), (0.2, 0.7, 0.3), white, bevel=0.02)
    # Roof kit: a searchlight on the north-east corner, a whip antenna on the
    # north-west, a camera on the south-west, and a vent pipe.
    roof_z = z1 + 0.15
    sl = Vector((cx + h - 0.15, cy + h - 0.15, roof_z))
    rod("Details_LightPost", sl, sl + Vector((0, 0, 0.35)), 0.04, galv_dark, segs=10)
    box("Details_LightYoke", sl + Vector((0, 0, 0.4)), (0.22, 0.06, 0.12), galv_dark)
    lamp = sl + Vector((0, 0, 0.5))
    aim = Vector((0.6, -0.6, -0.15)).normalized()
    rod("Details_Lamp", lamp - aim * 0.15, lamp + aim * 0.15, 0.13, material("LampBody", (0.25, 0.27, 0.25), metallic=0.5, roughness=0.4), segs=20)
    rod("Details_LampLens", lamp + aim * 0.15, lamp + aim * 0.165, 0.11, material("Lens", (0.9, 0.92, 0.8), emit=1.5), segs=20)
    ant = Vector((cx - h + 0.15, cy + h - 0.15, roof_z))
    rod("Details_AntennaBase", ant, ant + Vector((0, 0, 0.12)), 0.05, black, segs=10)
    rod("Details_Antenna", ant + Vector((0, 0, 0.12)), ant + Vector((0.03, -0.02, 2.0)), 0.008, black, segs=6)
    cam = Vector((cx - h + 0.12, cy - h + 0.12, roof_z))
    rod("Details_CamPost", cam, cam + Vector((0, 0, 0.25)), 0.025, white, segs=8)
    beam("Details_Camera", cam + Vector((0, 0, 0.3)), cam + Vector((-0.12, -0.2, 0.25)), 0.08, 0.08, white)
    vent = Vector((cx + 0.3, cy + 0.35, roof_z))
    rod("Details_Vent", vent, vent + Vector((0, 0, 0.25)), 0.06, galv, segs=12)
    rod("Details_VentCap", vent + Vector((0, 0, 0.25)), vent + Vector((0, 0, 0.29)), 0.11, galv, segs=16)
    # Power conduit down the north-east leg, with its box. They go with the base
    # (drawn under the squares, like the leg they're on): in the details, drawn
    # over everything, the box poked out past the deck's corner over anyone on
    # the top landing (Mike, 2026-11-02).
    a, b = leg_at(1, 1, 0.1), leg_at(1, 1, FRAME_TOP)
    beam("Base_Conduit", a + Vector((-0.09, 0.0, 0)), b + Vector((-0.09, 0.0, 0)), 0.04, 0.04, galv_dark)
    box("Base_PowerBox", leg_at(1, 1, 1.1) + Vector((-0.14, -0.02, 0)), (0.12, 0.25, 0.32), galv_dark, bevel=0.01)


def build():
    galv = material("Galvanised", GALV, metallic=0.8, roughness=0.4)
    galv_dark = material("GalvanisedDark", GALV_DARK, metallic=0.7, roughness=0.5)
    grating = grating_material("Grating")
    cream = material("Cream", CREAM, roughness=0.75)
    roof_top = material("RoofTop", ROOF_TOP, roughness=0.85)
    glass = material("Glass", GLASS, metallic=0.2, roughness=0.08)
    white = material("White", WHITE, roughness=0.5)
    black = material("Black", BLACK, roughness=0.6)
    build_base(galv, galv_dark)
    build_platform(galv, galv_dark, grating)
    build_stairs(galv, galv_dark, grating)
    build_roof(cream, roof_top, glass, galv_dark)
    build_details(galv, galv_dark, white, black)


def normalise_shadow(path):
    img = bpy.data.images.load(path)
    px = np.empty(img.size[0] * img.size[1] * 4, dtype=np.float32)
    img.pixels.foreach_get(px)
    px = px.reshape(-1, 4)
    px[:, 3] = np.minimum(px[:, 3], SHADOW_ALPHA) / SHADOW_ALPHA
    px[:, :3] = 0.0
    img.pixels.foreach_set(px.ravel())
    img.save()


def main():
    only_parts = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else PARTS
    os.makedirs(os.path.dirname(OUT_PART), exist_ok=True)
    os.makedirs(os.path.dirname(OUT_BLEND), exist_ok=True)
    scene = bs.new_scene(center=(0, 0), frame_m=FRAME_M, transparent=True, samples=SAMPLES,
                         px_per_m=bs.PX_PER_M * RENDER_SCALE)
    bpy.data.lights["Sun"].angle = math.radians(SUN_SOFTNESS_DEG)
    build()
    shapes = [o for o in scene.objects if o.type == "MESH"]
    groups = {part: [o for o in shapes if o.name.lower().startswith(part + "_")] for part in PARTS}
    for part, objs in groups.items():
        print(f"{part}: {len(objs)} objects")

    def only(keep):
        for obj in shapes:
            obj.hide_render = obj not in keep

    # Each part on its own, as it shows in the finished tower: the game draws
    # them stacked in DRAW_ORDER, so anything of a part drawn under it that's
    # really in front of it is cut out of it (a holdout: the roof's overhang
    # over the air conditioner, the deck over the leg's conduit), and the
    # parts drawn over it are there but unseen. Every part casts its shadows
    # onto the others (the roof's on the deck).
    for part in only_parts:
        below = DRAW_ORDER[:DRAW_ORDER.index(part)]
        for other, objs in groups.items():
            for obj in objs:
                obj.hide_render = False
                obj.is_holdout = other in below
                obj.visible_camera = other == part or other in below
        bs.render_to(scene, OUT_PART.format(part))
    # The cabin with its roof off (and nothing on the roof), lit inside: the
    # game shows it while anyone's in the cabin, drawn with the deck, under
    # the squares (watch_tower.gd RoofOpen).
    if "roof" in only_parts:
        lid = [o for o in groups["roof"] if o.name.split(".")[0] in ROOF_LID]
        below = DRAW_ORDER[:DRAW_ORDER.index("roof")]
        for other, objs in groups.items():
            for obj in objs:
                obj.hide_render = obj in lid or other == "details"
                obj.is_holdout = other in below
                obj.visible_camera = True
        bs.render_to(scene, OUT_ROOF_OPEN)
    for obj in shapes:
        obj.hide_render = False
        obj.is_holdout = False
        obj.visible_camera = True
    catcher_mesh = bpy.data.meshes.new("Ground")
    s = FRAME_M
    catcher_mesh.from_pydata([(-s, -s, 0), (s, -s, 0), (s, s, 0), (-s, s, 0)], [], [(0, 1, 2, 3)])
    catcher = bpy.data.objects.new("Ground", catcher_mesh)
    catcher.is_shadow_catcher = True
    scene.collection.objects.link(catcher)
    for obj in shapes:
        obj.visible_camera = False
    for part in only_parts:
        only(groups[part])
        bs.render_to(scene, OUT_SHADOW.format(part))
        normalise_shadow(OUT_SHADOW.format(part))
    for obj in shapes:
        obj.visible_camera = True
    only(shapes)
    bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND)

    # Reviews: top-down with its shadow on grey, and an angled look.
    scene.render.film_transparent = False
    bg = next(n for n in scene.world.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs["Color"].default_value = (0.35, 0.38, 0.3, 1)
    bs.frame_camera(scene, (0, 0), FRAME_M, bs.PX_PER_M)
    bs.render_to(scene, OUT_PREVIEW)
    cam = bpy.data.objects.new("Review", bpy.data.cameras.new("Review"))
    scene.collection.objects.link(cam)
    cam.data.lens = 35
    target = Vector((0.3, -0.5, 2.6))
    cam.location = Vector((9.0, -11.0, 5.0))
    cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam
    scene.render.resolution_x, scene.render.resolution_y = 900, 900
    bg.inputs["Color"].default_value = (0.75, 0.85, 1.0, 1)
    bs.render_to(scene, OUT_ANGLE)


main()
