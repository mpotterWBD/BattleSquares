"""Generate the deployable sandbag wall's tiles for Battle Squares, seen from straight above.

Run headless:
    blender --background --python sandbags.py

A wall of burlap sandbags (after Mike's reference photo, 2026-10-30): one
stack of COURSES layers, a single bag deep, laid in a running bond. It's
built from tiles TILE_M long (about two squares) that join end to end into
one continuous wall, the bond carrying on across each join:
  - even courses have two bags per tile, butting at the tile's ends
  - odd courses are offset half a bag, so one bag straddles each join, half
    in each tile, with one whole bag between
The bags are big (0.4 m long; 1.6x the first version's, 2026-10-30), so
three courses make a knee-high wall.
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

Damage (scripts/sandbags.gd, a wall shot to pieces): every tile is also
rendered at two damage stages, sandbags_<kind>_d1.png and _d2.png
(apply_damage()): d1 has one of the top course's own bags blown off and the
rest torn and slumped, with sand spilt at its foot; d2 has the whole top
course gone, the middle course sagging with a bag burst open, and more sand
about. Only a tile's own bags are taken (not the ones it shares with a
neighbour), so joins with undamaged walls still meet. Collapsed, a wall is
sandbags_collapsed.png: a puddle of sand with a few burlap scraps.

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
TILE_M = 68 / bs.PX_PER_M        # one tile: 68 game px (272 rendered, 0.797 m), two squares
FRAME_H_M = 0.375                # the image's height (across the wall): 128 rendered px
SAMPLES = 128

BAG_L = TILE_M / 2               # two bags to a tile
BAG_W, BAG_H = 0.256, 0.136      # a top-course bag's width and height
COURSES = 3
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
        lump = noise.noise(p * 14 + seed) * 0.0095 + noise.noise(p * 38 + seed) * 0.0032
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
        # Two bags, each reaching a join.
        for side in (-1, 1):
            capped = capped_left if side < 0 else capped_right
            if capped:   # finished end: the bag stops short of the edge
                bags.append((side * (half - END_INSET) / 2, half - END_INSET,
                             ("even", course, "end", side)))
            else:
                bags.append((side * L / 2, L, ("even", course, "edge", side)))
                # The neighbour's bag on this side, reaching over the join.
                bags.append((side * (half + L / 2), L, ("even", course, "edge", -side)))
    else:
        # One middle bag, and one straddling each join (the same bag both tiles draw).
        bags.append((0.0, L, ("odd", course, "middle", variant)))
        for side in (-1, 1):
            capped = capped_left if side < 0 else capped_right
            if capped:   # finished end: a half bag
                length = half - L / 2 - END_INSET
                bags.append((side * (L / 2 + length / 2), length, ("odd", course, "end", side)))
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


SAND = srgb(0.80, 0.70, 0.50)
DAMAGE_FRAME_H_M = 0.5625          # damaged and collapsed tiles: 192 rendered px tall


def sand_material():
    """Loose sand: a pale, blotchy tan, very rough."""
    mat = bpy.data.materials.new("Sand")
    nt = bs.node_tree_of(mat)
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Roughness"].default_value = 1.0
    coord = nt.nodes.new("ShaderNodeTexCoord")
    noise_tex = nt.nodes.new("ShaderNodeTexNoise")
    noise_tex.inputs["Scale"].default_value = 60.0
    nt.links.new(coord.outputs["Object"], noise_tex.inputs["Vector"])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].color = (*(Vector(SAND) * 0.85), 1)
    ramp.color_ramp.elements[1].color = (*(Vector(SAND) * 1.08), 1)
    nt.links.new(noise_tex.outputs["Fac"], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], bsdf.inputs["Base Color"])
    # Grain: a fine bump.
    grain = nt.nodes.new("ShaderNodeTexNoise")
    grain.inputs["Scale"].default_value = 900.0
    nt.links.new(coord.outputs["Object"], grain.inputs["Vector"])
    bump = nt.nodes.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.35
    bump.inputs["Distance"].default_value = 0.002
    nt.links.new(grain.outputs["Fac"], bump.inputs["Height"])
    nt.links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
    return mat


def sand_mound(name, x, y, rx, ry, h, mat, seed):
    """A low, lumpy heap of spilt sand centred at (x, y) on the ground."""
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=4, radius=1.0)   # even all over: no poles to pinch
    off = Vector((seed * 7.1, seed * 3.3, seed * 1.7))
    for v in bm.verts:
        vx, vy, vz = v.co
        edge = noise.noise(Vector((vx * 2.5, vy * 2.5, 0)) + off) * 0.35
        lump = 0.55 + noise.noise(Vector((vx * 3.0, vy * 3.0, 1.0)) + off) * 0.6 + noise.noise(Vector((vx * 9.0, vy * 9.0, 2.0)) + off) * 0.2
        v.co = Vector((vx * rx * (1 + edge), vy * ry * (1 + edge), max(vz, 0) ** 0.6 * h * max(lump, 0.15)))
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    me.shade_smooth()
    me.materials.append(mat)
    obj = bpy.data.objects.new(name, me)
    obj.location = (x, y, 0.0)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def burlap_scrap(name, x, y, size, turn, mat, lift=0.0):
    """A torn-off piece of empty sack lying flat (`lift` up off the ground, on sand)."""
    bm = bmesh.new()
    bmesh.ops.create_grid(bm, x_segments=4, y_segments=3, size=1.0)
    for v in bm.verts:
        v.co = Vector((v.co.x * size, v.co.y * size * 0.6, lift + 0.004 + abs(v.co.x * v.co.y) * 0.015))
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    me.materials.append(mat)
    obj = bpy.data.objects.new(name, me)
    obj.location = (x, y, 0.0)
    obj.rotation_euler = (0, 0, turn)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def apply_damage(kind, stage, burlap, sand):
    """Damages a built tile (its bags are in the scene): stage 1 or 2 (see
    the docstring), or 3 for the collapsed puddle (every bag gone)."""
    rng = bag_rng("damage", kind, stage)
    half = TILE_M / 2
    bags = [o for o in bpy.data.objects if o.name.startswith(f"Bag_{kind}_")]
    def course(o):
        return int(o.name.split("_")[-2])
    def own(o):
        # Inside this tile and not a bag it shares with a neighbour.
        return abs(o.location.x) < half - BAG_L * 0.3
    top = [o for o in bags if course(o) == COURSES - 1]
    middle = [o for o in bags if course(o) == COURSES - 2]
    removed = []
    if stage >= 3:
        removed = bags
    elif stage == 2:
        removed = top
    else:
        mine = [o for o in top if own(o)] or top
        removed = [mine[int(rng.integers(len(mine)))]]
    for o in removed:
        bpy.data.objects.remove(o)
    left = [o for o in bpy.data.objects if o.name.startswith(f"Bag_{kind}_")]
    # Torn and slumped.
    slumped = [o for o in left if course(o) == COURSES - 1] if stage == 1 else [o for o in left if course(o) == COURSES - 2]
    for o in slumped:
        o.scale = (1.0 + rng.uniform(0.0, 0.08), 1.0 + rng.uniform(0.0, 0.08), rng.uniform(0.6, 0.78))
        o.location.z -= BAG_H * 0.15
        o.rotation_euler.y += rng.normal(0, 0.08)
    if stage == 2:
        burst = [o for o in left if course(o) == COURSES - 2 and own(o)]
        if burst:
            b = burst[int(rng.integers(len(burst)))]
            b.scale = (1.12, 1.2, 0.42)
            b.location.z -= BAG_H * 0.3
    # Spilt sand, more the worse it is.
    if stage == 1:
        spots = [(rng.uniform(-0.2, 0.2), side * rng.uniform(0.1, 0.14), 0.12, 0.06, 0.03) for side in (-1, 1)]
    elif stage == 2:
        spots = [(rng.uniform(-0.3, 0.3), side * rng.uniform(0.1, 0.15), rng.uniform(0.13, 0.18), 0.07, 0.04)
                 for side in (-1, 1, -1, 1)]
    else:
        spots = [(x, rng.uniform(-0.02, 0.02), rng.uniform(0.15, 0.18), rng.uniform(0.12, 0.15), rng.uniform(0.07, 0.1))
                 for x in (-0.19, 0.0, 0.19)]   # kept inside the tile's width, so it tapers off instead of being cut
        spots += [(rng.uniform(-0.3, 0.3), side * 0.12, 0.1, 0.05, 0.03) for side in (-1, 1)]
    for k, (x, y, rx, ry, h) in enumerate(spots):
        sand_mound(f"Spill_{kind}_{stage}_{k}", x, y, rx, ry, h, sand, seed=k + 3 * stage)
    if stage >= 2:
        for k in range(2 if stage == 2 else 5):
            burlap_scrap(f"Scrap_{kind}_{stage}_{k}", rng.uniform(-0.32, 0.32), rng.uniform(-0.12, 0.12),
                         rng.uniform(0.07, 0.11), rng.uniform(0, math.pi), burlap,
                         lift=0.05 if stage >= 3 else 0.0)


def render_tile(kind, stage=0):
    """One tile; `stage` 1 or 2 for its damaged looks, 3 for the collapsed puddle."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bs.new_scene(center=(0.0, 0.0), frame_m=TILE_M, transparent=True, samples=SAMPLES,
                         px_per_m=bs.PX_PER_M * RENDER_SCALE)
    scene.render.resolution_x = round(TILE_M * bs.PX_PER_M * RENDER_SCALE)
    # Damaged, the frame is taller so spilt sand isn't cut off (centred, so it
    # still lines up with the wall).
    scene.render.resolution_y = round((DAMAGE_FRAME_H_M if stage else FRAME_H_M) * bs.PX_PER_M * RENDER_SCALE)
    burlap = burlap_material()
    top = build_tile(kind, burlap)
    if stage:
        apply_damage(kind, stage, burlap, sand_material())
    name = {0: f"sandbags_{kind}.png", 1: f"sandbags_{kind}_d1.png", 2: f"sandbags_{kind}_d2.png",
            3: "sandbags_collapsed.png"}[stage]
    bs.render_to(scene, os.path.join(OUT_DIR, name))
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
    only_damage = "--damage" in sys.argv
    for kind in KINDS:
        if not only_damage:
            top = render_tile(kind)
        render_tile(kind, 1)
        render_tile(kind, 2)
    render_tile("single", 3)
    if not only_damage:
        print(f"Tile {TILE_M} m, top at {top:.3f} m, foot {FOOT_M:.3f} m wide"
              " (sandbags.gd WALL_HEIGHT_M, FOOT_PX)")
        bpy.ops.wm.read_factory_settings(use_empty=True)
        render_review()


if __name__ == "__main__":
    main()
