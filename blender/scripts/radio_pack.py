"""Render the radio operator's backpack as a single top-down sprite.

Run headless:
    blender --background --python radio_pack.py

A brown field-radio pack worn on the square's back, with a whip antenna.
The image is centred on the square's centre (the pivot) with the square
facing right (+x), so the pack sits on the left (-x) and the antenna leans
back away from it. Parts: the pack with a top flap and two side pouches,
shoulder straps running forward over the top of the square, the radio's
antenna mount, and a whip antenna raked back with a tip cap.

The pack top is a little higher than the square's top (0.4 m), so seen
from above it overlaps the square's back edge: the game draws it over the
body.

The game turns it with the square (scripts/radio_pack.gd), so it's lit from
straight overhead like the rifle, which looks the same at every angle. Its
shadow isn't rendered; the game draws the same shape darkened and offset
away from the sun.

It renders at RENDER_SCALE x the game's pixel density so the antenna stays
crisp when zoomed in; Godot shrinks it back (with mipmaps).
"""

import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bs_common as bs  # noqa: E402

ROOT = bs.ROOT
OUT_PACK = os.path.join(ROOT, "assets", "characters", "radio_pack.png")
OUT_BLEND = os.path.join(ROOT, "blender", "source", "radio_pack.blend")

SQUARE_M = 0.40       # the square (character_square.py SIZE_M)
RENDER_SCALE = 4      # scripts/radio_pack.gd must match
FRAME_M = 1.8         # centred on the pivot: room for the raked antenna
SAMPLES = 128

# The pack (metres; the square's back face is at x = -0.2).
PACK_X = (-0.345, -0.185)
PACK_HALF_W = 0.15
PACK_Z = (0.06, 0.44)
ANTENNA_AT = (-0.31, 0.10)   # mount on the pack top, toward its left
ANTENNA_LEN_M = 0.6
ANTENNA_RAKE_DEG = 32        # leaned back from upright

BROWN = (0.36, 0.25, 0.14)
BROWN_DARK = (0.27, 0.19, 0.11)
STRAP = (0.20, 0.15, 0.10)
RADIO = (0.13, 0.14, 0.12)
BLACK = (0.04, 0.04, 0.04)


def material(name, rgb, metallic=0.0, roughness=0.8, shine=0.2):
    """`shine` is the specular level: with sun and camera both overhead,
    flat tops mirror the sun back, so matte canvas needs it low."""
    mat = bpy.data.materials.new(name)
    nt = bs.node_tree_of(mat)
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (*bs.srgb(*rgb), 1.0)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    if "Specular IOR Level" in bsdf.inputs:
        bsdf.inputs["Specular IOR Level"].default_value = shine
    return mat


def add(name, bm, mat, bevel=0.0, smooth=True):
    if bevel:
        bmesh.ops.bevel(bm, geom=list(bm.edges), offset=bevel, segments=3,
                        profile=0.5, affect="EDGES")
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    if smooth:
        me.shade_smooth()
        me.set_sharp_from_angle(angle=math.radians(35))
    me.materials.append(mat)
    obj = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def box(x0, x1, y0, y1, z0, z1):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, verts=bm.verts, vec=(x1 - x0, y1 - y0, z1 - z0))
    bmesh.ops.translate(bm, verts=bm.verts, vec=((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2))
    return bm


def rod(start, direction, length, radius, segs=12):
    """A cylinder from `start` along `direction` (unit Vector)."""
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=segs, radius1=radius,
                          radius2=radius, depth=length)
    # create_cone runs along z, centred: rotate z onto the direction.
    rot = Vector((0, 0, 1)).rotation_difference(direction).to_matrix()
    bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=rot)
    mid = Vector(start) + direction * (length / 2)
    bmesh.ops.translate(bm, verts=bm.verts, vec=mid)
    return bm


def build_pack():
    canvas = material("Canvas", BROWN)
    canvas_dark = material("CanvasDark", BROWN_DARK)
    strap = material("Strap", STRAP, roughness=0.7)
    radio = material("Radio", RADIO, roughness=0.5, shine=0.3)
    black = material("Antenna", BLACK, metallic=0.4, roughness=0.4, shine=0.3)

    x0, x1 = PACK_X
    z0, z1 = PACK_Z
    hw = PACK_HALF_W
    add("Pack", box(x0, x1, -hw, hw, z0, z1), canvas, bevel=0.03)
    # Top flap, a touch wider than the pack and folded over its back edge.
    add("Flap", box(x0 - 0.01, x1 - 0.015, -hw - 0.005, hw + 0.005, z1 - 0.02, z1 + 0.025),
        canvas_dark, bevel=0.015)
    # Side pouches.
    for side in (1, -1):
        y_in, y_out = side * hw, side * (hw + 0.045)
        add("Pouch", box(x0 + 0.02, x1 - 0.02, min(y_in, y_out), max(y_in, y_out), z0 + 0.06, z1 - 0.12),
            canvas_dark, bevel=0.012)
    # Shoulder straps running forward over the top of the square.
    for side in (1, -1):
        y = side * 0.095
        add("Strap", box(x1 - 0.02, 0.06, y - 0.02, y + 0.02, SQUARE_M, SQUARE_M + 0.012),
            strap, bevel=0.004)
    # The radio's top showing at the back of the flap, with two knobs.
    add("RadioTop", box(x0 - 0.008, x0 + 0.05, -0.1, 0.06, z1 - 0.06, z1 + 0.01), radio, bevel=0.006)
    for y in (-0.06, -0.02):
        knob = bmesh.new()
        bmesh.ops.create_cone(knob, cap_ends=True, segments=16, radius1=0.012,
                              radius2=0.012, depth=0.02)
        bmesh.ops.translate(knob, verts=knob.verts, vec=(x0 + 0.02, y, z1 + 0.02))
        add("Knob", knob, black)

    # Antenna: a mount, then a whip raked back, with a cap on the tip.
    ax, ay = ANTENNA_AT
    add("AntennaMount", rod((ax, ay, z1), Vector((0, 0, 1)), 0.05, 0.016), black)
    rake = math.radians(ANTENNA_RAKE_DEG)
    direction = Vector((-math.sin(rake), 0.0, math.cos(rake)))
    base = Vector((ax, ay, z1 + 0.05))
    add("Whip", rod(base, direction, ANTENNA_LEN_M, 0.007, segs=10), black)
    tip = base + direction * ANTENNA_LEN_M
    cap = bmesh.new()
    bmesh.ops.create_uvsphere(cap, u_segments=12, v_segments=8, radius=0.014)
    bmesh.ops.translate(cap, verts=cap.verts, vec=tip)
    add("Tip", cap, black)


def main():
    for path in (OUT_PACK, OUT_BLEND):
        os.makedirs(os.path.dirname(path), exist_ok=True)
    scene = bs.new_scene(center=(0, 0), frame_m=FRAME_M, transparent=True,
                         samples=SAMPLES, px_per_m=bs.PX_PER_M * RENDER_SCALE)
    # Straight-overhead sun: shading that looks right at any rotation.
    bpy.data.objects["Sun"].rotation_euler = (0, 0, 0)
    build_pack()
    bs.render_to(scene, OUT_PACK)
    bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND)


main()
