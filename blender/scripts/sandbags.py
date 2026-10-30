"""Generate the deployable sandbag wall's tiles for Battle Squares, seen from straight above.

Run headless:
    blender --background --python sandbags.py

A wall of burlap sandbags (after Mike's reference photo, 2026-10-30): one
stack of COURSES layers, a single bag deep, laid in a running bond. It's
built from tiles TILE_M long (about two squares) that join end to end into
one continuous wall, the bond carrying on across each join:
  - even courses have three bags per tile, butting at the tile's ends
  - odd courses are offset half a bag, so one bag straddles each join, half
    in each tile
Every tile is rendered with the neighbouring bags that reach into it (the
ones at a join use the same random shape in every tile, so neighbours
agree), and cropped to exactly TILE_M, so tiles sit side by side seamlessly.

Tiles (assets/props/sandbags_<kind>.png; scripts/sandbags.gd picks one by
which neighbours a wall has):
  single  a lone wall: both ends finished (half bags in the odd courses)
  start   finished at -x, joining on at +x
  end     joining on at -x, finished at +x
  mid_0, mid_1, mid_2   joining on at both ends; their middle bags differ,
          so a long row doesn't repeat
The courses step in slightly as they rise (BATTER), so from above the lower
bags peek out and it reads as a stack. Tan burlap with a woven bump and
blotchy tone; lumpy, boxy bags.

Rendered at RENDER_SCALE x the game's pixel density so it stays sharp zoomed
in (the game shows it at 1 / RENDER_SCALE), lit by the standard sun
(bs_common.py), transparent. The game draws the wall's shadow itself
(sandbags.gd), from WALL_HEIGHT_M (printed here) and FOOT_M.
"""

import hashlib
import math
import os
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Vector, noise

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bs_common as bs  # noqa: E402
from bs_common import srgb  # noqa: E402

ROOT = bs.ROOT
OUT_DIR = os.path.join(ROOT, "assets", "props")
OUT_PREVIEW = os.path.join(ROOT, "assets", "previews", "sandbags_preview.png")
OUT_BLEND = os.path.join(ROOT, "blender", "source", "sandbags.blend")

RENDER_SCALE = 4                 # shown at 0.25 in the game
TILE_M = 0.75                    # one tile: 64 game px (256 rendered), about two squares
FRAME_H_M = 0.375                # the image's height (across the wall): 128 rendered px
SAMPLES = 128

BAG_L = TILE_M / 3               # three bags to a tile
BAG_W, BAG_H = 0.16, 0.085       # a top-course bag's width and height
COURSES = 5
SETTLE = 0.8                     # courses sink into each other this much
BATTER = 0.05                    # each course down is this much wider (fraction)
END_INSET = 0.03                 # a finished end stops this far inside the tile
FOOT_M = BAG_W * (1 + BATTER * (COURSES - 1))   # the bottom course's width

BURLAP = srgb(0.80, 0.71, 0.55)
BURLAP_DARK = srgb(0.58, 0.49, 0.35)
KINDS = ["single", "start", "end", "mid_0", "mid_1", "mid_2"]


def burlap_material():
    """Tan woven burlap: a fine weave bump, blotchy tone, and each bag
    tinted a little differently (Object Info random)."""
    mat = bpy.data.materials.new("Burlap")
    nt = bs.node_tree_of(mat)
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Roughness"].default_value = 0.95
    if "Specular IOR Level" in bsdf.inputs:
        bsdf.inputs["Specular IOR Level"].default_value = 0.15
    coord = nt.nodes.new("ShaderNodeTexCoord")
    blotch = nt.nodes.new("ShaderNodeTexNoise")
    blotch.inputs["Scale"].default_value = 18.0
    nt.links.new(coord.outputs["Object"], blotch.inputs["Vector"])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].color = (*BURLAP_DARK, 1)
    ramp.color_ramp.elements[1].color = (*BURLAP, 1)
    ramp.color_ramp.elements[0].position = 0.3
    ramp.color_ramp.elements[1].position = 0.7
    nt.links.new(blotch.outputs["Fac"], ramp.inputs["Fac"])
    info = nt.nodes.new("ShaderNodeObjectInfo")
    tint = nt.nodes.new("ShaderNodeMapRange")
    tint.inputs["To Min"].default_value = 0.85
    tint.inputs["To Max"].default_value = 1.08
    nt.links.new(info.outputs["Random"], tint.inputs["Value"])
    mul = nt.nodes.new("ShaderNodeMix")
    mul.data_type = "RGBA"
    mul.blend_type = "MULTIPLY"
    mul.inputs["Factor"].default_value = 1.0
    nt.links.new(ramp.outputs["Color"], mul.inputs["A"])
    nt.links.new(tint.outputs["Result"], mul.inputs["B"])
    nt.links.new(mul.outputs["Result"], bsdf.inputs["Base Color"])
    weave_x = nt.nodes.new("ShaderNodeTexWave")
    weave_x.inputs["Scale"].default_value = 180.0
    weave_y = nt.nodes.new("ShaderNodeTexWave")
    weave_y.inputs["Scale"].default_value = 180.0
    weave_y.bands_direction = "Y"
    for w in (weave_x, weave_y):
        nt.links.new(coord.outputs["Object"], w.inputs["Vector"])
    add = nt.nodes.new("ShaderNodeMath")
    add.operation = "ADD"
    nt.links.new(weave_x.outputs["Fac"], add.inputs[0])
    nt.links.new(weave_y.outputs["Fac"], add.inputs[1])
    bump = nt.nodes.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.25
    bump.inputs["Distance"].default_value = 0.002
    nt.links.new(add.outputs["Value"], bump.inputs["Height"])
    nt.links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
    return mat


def bag_rng(*key):
    """Random numbers for one bag, from its key: the same key always gives the
    same bag, in every tile (so the bags at a join match their neighbours')."""
    digest = hashlib.sha256(repr(key).encode()).digest()
    return np.random.default_rng(int.from_bytes(digest[:8], "little"))


def bag(name, x, course, length, width, key, mat):
    """One filled sandbag: a boxy, lumpy pillow (squared-off ends and sides,
    a gently domed top, a flat bottom), pinched in at the ends, centred at x
    on `course`. Its jitter and lumps come from `key` (bag_rng())."""
    rng = bag_rng(*key)
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=40, v_segments=20, radius=1.0)
    sl, sw, sh = rng.uniform(0.97, 1.03), rng.uniform(0.93, 1.05), rng.uniform(0.9, 1.1)
    seed = Vector(rng.uniform(0, 100, 3))
    for v in bm.verts:
        vx, vy, vz = v.co
        vx = math.copysign(abs(vx) ** 0.3, vx)
        vy = math.copysign(abs(vy) ** 0.4, vy)
        vz = math.copysign(abs(vz) ** 0.7, vz) if vz > 0 else vz * 0.35
        vz *= 1 - 0.35 * abs(vx) ** 6           # the ends slump down
        vy *= 1 - 0.18 * abs(vx) ** 8           # pinched where it's tied
        p = Vector((vx * length / 2 * sl, vy * width / 2 * sw, (vz + 0.35) / 1.35 * BAG_H * sh))
        lump = noise.noise(p * 22 + seed) * 0.006 + noise.noise(p * 60 + seed) * 0.002
        v.co = p + Vector((0, 0, lump if vz > -0.2 else 0.0))
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    me.shade_smooth()
    me.materials.append(mat)
    obj = bpy.data.objects.new(name, me)
    obj.location = (x + rng.normal(0, 0.004), rng.normal(0, 0.006), course * BAG_H * SETTLE)
    obj.rotation_euler = (rng.normal(0, 0.03), rng.normal(0, 0.04), rng.normal(0, math.radians(2.5)))
    bpy.context.scene.collection.objects.link(obj)
    return obj


def course_bags(course, variant, capped_left, capped_right):
    """The bags of one course of one tile, in its own frame (x from -TILE_M/2
    to +TILE_M/2), as (x, length, key). Includes the neighbours' bags that
    reach into this tile where it joins on. Keys: bags at a join are keyed
    by where they sit relative to the join, so every tile builds the same
    one; middle bags are keyed by the tile's variant."""
    L, half = BAG_L, TILE_M / 2
    bags = []
    if course % 2 == 0:
        # Three bags; the outer two are shared with the joins.
        bags.append((0.0, L, ("even", course, "middle", variant)))
        for side in (-1, 1):
            capped = capped_left if side < 0 else capped_right
            if capped:   # finished end: the outer bag stops short of the edge
                bags.append((side * (L / 2 + half - END_INSET) / 2, half - L / 2 - END_INSET,
                             ("even", course, "end", side)))
            else:
                bags.append((side * L, L, ("even", course, "edge", side)))
                # The neighbour's outer bag on this side, reaching over the join.
                bags.append((side * (half + L / 2), L, ("even", course, "edge", -side)))
    else:
        # Two middle bags, and one straddling each join (the same bag both tiles draw).
        for side in (-1, 1):
            bags.append((side * L / 2, L, ("odd", course, "middle", side, variant)))
            capped = capped_left if side < 0 else capped_right
            if capped:   # finished end: a half bag
                length = half - L - END_INSET
                bags.append((side * (L + length / 2), length, ("odd", course, "end", side)))
            else:
                bags.append((side * half, L, ("odd", course, "join")))
    return bags


def build_tile(kind, mat, x_offset=0.0, skip_right_join=False):
    """All the bags of one tile, its middle at x_offset. `skip_right_join`
    leaves out the bags it shares with a tile to its right (for building a
    whole run in one scene)."""
    capped_left = kind in ("single", "start")
    capped_right = kind in ("single", "end")
    variant = int(kind.split("_")[1]) if kind.startswith("mid") else {"single": 10, "start": 11, "end": 12}[kind]
    for c in range(COURSES):
        width = BAG_W * (1 + BATTER * (COURSES - 1 - c))
        for x, length, key in course_bags(c, variant, capped_left, capped_right):
            shared_right = not capped_right and x > BAG_L * 0.9 and key[2] != "middle"
            if skip_right_join and shared_right and (key[2] == "join" or key[3] == -1):
                continue
            bag(f"Bag_{kind}_{c}_{x:+.3f}", x + x_offset, c, length, width, key, mat)
    return (COURSES - 1) * BAG_H * SETTLE + BAG_H


def render_tile(kind):
    scene = bs.new_scene(center=(0.0, 0.0), frame_m=TILE_M, transparent=True, samples=SAMPLES,
                         px_per_m=bs.PX_PER_M * RENDER_SCALE)
    scene.render.resolution_x = round(TILE_M * bs.PX_PER_M * RENDER_SCALE)
    scene.render.resolution_y = round(FRAME_H_M * bs.PX_PER_M * RENDER_SCALE)
    top = build_tile(kind, burlap_material())
    bs.render_to(scene, os.path.join(OUT_DIR, f"sandbags_{kind}.png"))
    return top


def render_review():
    """An angled look at a run of five tiles (start, three middles, end),
    like the reference photo; also saved as the .blend."""
    scene = bs.new_scene(center=(0.0, 0.0), frame_m=4.0, transparent=False, samples=64)
    mat = burlap_material()
    run = ["start", "mid_0", "mid_1", "mid_2", "end"]
    for i, kind in enumerate(run):
        build_tile(kind, mat, x_offset=(i - 2) * TILE_M, skip_right_join=i < len(run) - 1)
    bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND)
    cam = bpy.data.objects.new("Review", bpy.data.cameras.new("Review"))
    scene.collection.objects.link(cam)
    cam.data.lens = 50
    target = Vector((0, 0, 0.15))
    cam.location = Vector((0.6, -3.4, 1.4))
    cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam
    scene.render.resolution_x, scene.render.resolution_y = 1000, 450
    bg = next(n for n in scene.world.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs["Color"].default_value = (0.9, 0.9, 0.9, 1)
    bs.render_to(scene, OUT_PREVIEW)


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    os.makedirs(os.path.dirname(OUT_BLEND), exist_ok=True)
    top = 0.0
    for kind in KINDS:
        top = render_tile(kind)
    print(f"Tile {TILE_M} m, top at {top:.3f} m, foot {FOOT_M:.3f} m wide"
          " (sandbags.gd WALL_HEIGHT_M, FOOT_PX)")
    render_review()


if __name__ == "__main__":
    main()
