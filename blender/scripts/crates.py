"""Generate supply crates for Battle Squares: loads strapped to a wooden pallet,
seen from straight above.

Run headless:
    blender --background --python crates.py              (every kind)
    blender --background --python crates.py -- ammo      (just these)

Every crate is the same wooden pallet (build_pallet(): a 0.8 m square
four-way pallet, deck boards on stringer boards on nine blocks) with a load
on it and black ratchet straps over the load, both ways, buckled on top
(build_straps()). Each kind adds its own load to KINDS:

  ammo   olive-drab steel ammo cans (M2A1 size), PER_ROW across by ROWS deep,
         LAYERS high: lid with a raised rim, folding carry handle on top,
         latch on one end, yellow stencil marks on the sides; after Mike's
         reference photo (2026-10-30), without its tarp.
  sandbags  filled burlap sandbags (the same bags as the sandbag wall,
         blender/scripts/sandbags.py), SAND_ACROSS x SAND_ALONG to a layer,
         SAND_LAYERS high, each layer turned 90 degrees from the one below.

Also a lone ammo can (`-- can`; render_can()): one of the same cans, on
its own, for assets/props/ammo_can.png (CAN_FRAME_M square) and its review.

Output, per kind: assets/props/crate_<kind>.png, the load and straps only
(no pallet), top-down, rendered at RENDER_SCALE x the game's pixel density
in a FRAME_M square, lit by the standard sun (bs_common.py), transparent.
The pallet is its own sprite, assets/props/pallet.png (`-- pallet`;
render_pallet()), in the same frame, shared by every crate: the game draws
it under the squares and the load at their level, so a square can stand
over the pallet's edge without going under it (scripts/crate.gd). The game draws the shadow
(scripts/crate.gd) from the footprints and heights printed here. Also an
angled review render (assets/previews/crate_<kind>_preview.png) and the .blend.
"""

import math
import os
import sys

import bmesh
import bpy
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bs_common as bs  # noqa: E402
from bs_common import srgb  # noqa: E402

ROOT = bs.ROOT
RENDER_SCALE = 4
FRAME_M = 1.125                    # 384 rendered px, 96 game px
CAN_FRAME_M = 0.375                # the lone can: 128 rendered px, 32 game px
SAMPLES = 128

# The pallet (metres): length along x, width along y. Square, to suit a
# square load (Mike, 2026-10-30).
PALLET_L, PALLET_W = 0.8, 0.8
BOARD_T = 0.022                    # every board's thickness
BLOCK_H = 0.078
PALLET_H = BOARD_T * 3 + BLOCK_H   # bottom boards, blocks, stringers, deck

# Ammo cans (M2A1): across x, along y, body height; lid adds a little.
CAN_W, CAN_L, CAN_H = 0.154, 0.305, 0.17
LID_H = 0.022
PER_ROW, ROWS, LAYERS = 4, 2, 3    # 4 across x 2 deep: a square block (0.63 x 0.62 m)
CAN_GAP = 0.004

# Sandbags: bags per layer (two along their length, three side by side),
# layers high. Each layer is turned 90 degrees from the one below.
SAND_ALONG, SAND_ACROSS, SAND_LAYERS = 2, 3, 5
SAND_BAG_L, SAND_BAG_W = 0.37, 0.235   # a touch smaller than the wall's bags, so they sit on the pallet

STRAP_W, STRAP_T = 0.035, 0.003

WOOD = srgb(0.74, 0.58, 0.40)
WOOD_DARK = srgb(0.52, 0.38, 0.24)
OLIVE = srgb(0.30, 0.32, 0.21)
STENCIL = srgb(0.86, 0.72, 0.18)
STRAP = srgb(0.05, 0.05, 0.05)
BUCKLE = srgb(0.35, 0.35, 0.36)


# ------------------------------------------------------------- materials --

def wood_material():
    """Pine boards: a long grain (stretched noise) between a light and dark
    tone, each board a little different (Object Info random)."""
    mat = bpy.data.materials.new("PalletWood")
    nt = bs.node_tree_of(mat)
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Roughness"].default_value = 0.85
    coord = nt.nodes.new("ShaderNodeTexCoord")
    mapping = nt.nodes.new("ShaderNodeMapping")
    mapping.inputs["Scale"].default_value = (1.0, 14.0, 14.0)   # grain runs along the board's x
    nt.links.new(coord.outputs["Object"], mapping.inputs["Vector"])
    grain = nt.nodes.new("ShaderNodeTexNoise")
    grain.inputs["Scale"].default_value = 9.0
    grain.inputs["Detail"].default_value = 6.0
    nt.links.new(mapping.outputs["Vector"], grain.inputs["Vector"])
    info = nt.nodes.new("ShaderNodeObjectInfo")
    mix_in = nt.nodes.new("ShaderNodeMath")
    mix_in.operation = "MULTIPLY_ADD"
    mix_in.inputs[1].default_value = 0.6
    nt.links.new(grain.outputs["Fac"], mix_in.inputs[0])
    nt.links.new(info.outputs["Random"], mix_in.inputs[2])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].color = (*WOOD_DARK, 1)
    ramp.color_ramp.elements[1].color = (*WOOD, 1)
    ramp.color_ramp.elements[0].position = 0.35
    ramp.color_ramp.elements[1].position = 0.75
    nt.links.new(mix_in.outputs["Value"], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], bsdf.inputs["Base Color"])
    return mat


def paint_material(name, rgb, roughness=0.6, metallic=0.25, wear=True):
    """Painted steel: a slightly mottled tone, each object a little different,
    lighter where the paint is rubbed (noise)."""
    mat = bpy.data.materials.new(name)
    nt = bs.node_tree_of(mat)
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    base = Vector(rgb)
    if not wear:
        bsdf.inputs["Base Color"].default_value = (*rgb, 1)
        return mat
    coord = nt.nodes.new("ShaderNodeTexCoord")
    noise = nt.nodes.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = 40.0
    nt.links.new(coord.outputs["Object"], noise.inputs["Vector"])
    info = nt.nodes.new("ShaderNodeObjectInfo")
    add = nt.nodes.new("ShaderNodeMath")
    add.operation = "MULTIPLY_ADD"
    add.inputs[1].default_value = 0.35
    nt.links.new(info.outputs["Random"], add.inputs[0])
    nt.links.new(noise.outputs["Fac"], add.inputs[2])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].color = (*(base * 0.82), 1)
    ramp.color_ramp.elements[1].color = (*(base * 1.18), 1)
    ramp.color_ramp.elements[0].position = 0.3
    ramp.color_ramp.elements[1].position = 0.95
    nt.links.new(add.outputs["Value"], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], bsdf.inputs["Base Color"])
    return mat


# ---------------------------------------------------------------- shapes --

def block(name, center, size, mat, bevel=0.0, rot_z=0.0):
    """A box (`size` x, y, z) centred at `center`, optionally bevelled and turned."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, verts=bm.verts, vec=size)
    if bevel:
        bmesh.ops.bevel(bm, geom=list(bm.edges), offset=bevel, segments=2, profile=0.5, affect="EDGES")
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    me.materials.append(mat)
    obj = bpy.data.objects.new(name, me)
    obj.location = center
    obj.rotation_euler = (0, 0, rot_z)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def build_pallet(mat):
    """A four-way pallet (0.8 m square), centred on the origin, its deck top at PALLET_H:
    bottom boards, nine blocks, stringer boards across them, deck boards on top."""
    t = BOARD_T
    xs = (-PALLET_L / 2 + 0.05, 0.0, PALLET_L / 2 - 0.05)
    ys = (-PALLET_W / 2 + 0.05, 0.0, PALLET_W / 2 - 0.05)
    for i, y in enumerate(ys):   # bottom boards, along x
        block(f"Bottom{i}", (0, y, t / 2), (PALLET_L, 0.1, t), mat, bevel=0.002)
    for i, x in enumerate(xs):   # blocks
        for j, y in enumerate(ys):
            block(f"Block{i}{j}", (x, y, t + BLOCK_H / 2), (0.1, 0.1, BLOCK_H), mat, bevel=0.003)
    for i, x in enumerate(xs):   # stringer boards, along y
        block(f"Stringer{i}", (x, 0, t + BLOCK_H + t / 2), (0.1, PALLET_W, t), mat, bevel=0.002)
    deck = 7                     # deck boards, along x, with gaps
    board_w = 0.09
    for k in range(deck):
        y = -PALLET_W / 2 + board_w / 2 + k * (PALLET_W - board_w) / (deck - 1)
        block(f"Deck{k}", (0, y, PALLET_H - t / 2), (PALLET_L, board_w, t), mat, bevel=0.002)


def build_ammo_can(name, center, mats, flip, rot_z):
    """One ammo can standing on `center` (x, y, z of its base): the body, a
    lid with a raised rim, a folding handle lying flat on the lid, a latch
    lever on one end (`flip` picks which), yellow stencil marks on the sides."""
    paint, steel, stencil = mats
    x, y, z = center
    parts = [block(name, (x, y, z + CAN_H / 2), (CAN_W, CAN_L, CAN_H), paint, bevel=0.006)]
    parts.append(block(name + "Lid", (x, y, z + CAN_H + LID_H / 2),
                       (CAN_W + 0.006, CAN_L + 0.006, LID_H), paint, bevel=0.005))
    parts.append(block(name + "LidTop", (x, y, z + CAN_H + LID_H + 0.002),
                       (CAN_W - 0.03, CAN_L - 0.03, 0.006), paint, bevel=0.003))
    # The handle: a flat bail lying along the lid, on two pivots.
    top = z + CAN_H + LID_H + 0.005
    parts.append(block(name + "Handle", (x, y, top + 0.006), (0.022, 0.13, 0.008), steel, bevel=0.003))
    for s in (-1, 1):
        parts.append(block(name + f"Pivot{s}", (x, y + s * 0.07, top + 0.004), (0.03, 0.012, 0.012), steel, bevel=0.002))
    # The latch lever on one end.
    end = (CAN_L / 2 + 0.006) * (1 if flip else -1)
    parts.append(block(name + "Latch", (x, y + end, z + CAN_H - 0.01), (0.07, 0.012, 0.05), steel, bevel=0.003))
    # Stencil marks: two short yellow bars of "lettering" on each long side.
    for s in (-1, 1):
        for k, (w, dz) in enumerate(((0.16, 0.10), (0.10, 0.07))):
            parts.append(block(name + f"Mark{s}{k}", (x + s * (CAN_W / 2 + 0.0008), y, z + dz),
                               (0.0015, w, 0.012), stencil))
    for part in parts[1:]:
        part.parent = parts[0]
        part.location = Vector(part.location) - Vector(parts[0].location)
    parts[0].rotation_euler = (0, 0, rot_z)
    return parts[0]


def build_ammo_load(seed):
    """PER_ROW x ROWS x LAYERS ammo cans, centred on the pallet, a little
    out of true each. Returns the load's footprint (x, y) and top height."""
    import random
    rng = random.Random(seed)
    mats = (paint_material("Olive", OLIVE), paint_material("CanSteel", srgb(0.18, 0.19, 0.15), 0.45, 0.6),
            paint_material("Stencil", STENCIL, 0.7, 0.0, wear=False))
    pitch_x, pitch_y = CAN_W + CAN_GAP, CAN_L + CAN_GAP
    can_h = CAN_H + LID_H + 0.004
    for layer in range(LAYERS):
        for r in range(ROWS):
            for c in range(PER_ROW):
                x = (c - (PER_ROW - 1) / 2) * pitch_x + rng.gauss(0, 0.002)
                y = (r - (ROWS - 1) / 2) * pitch_y + rng.gauss(0, 0.003)
                build_ammo_can(f"Can{layer}{r}{c}", (x, y, PALLET_H + layer * can_h), mats,
                               flip=(r == 1), rot_z=math.radians(rng.gauss(0, 0.8)))
    return (PER_ROW * pitch_x, ROWS * pitch_y), PALLET_H + LAYERS * can_h


def build_straps(footprint, top):
    """Black ratchet straps over the load: two along y, one along x, each over
    the top and down the sides to the pallet, with a buckle on top."""
    strap = paint_material("Strap", STRAP, 0.9, 0.0, wear=False)
    buckle = paint_material("Buckle", BUCKLE, 0.35, 0.8, wear=False)
    fx, fy = footprint
    drop = top - PALLET_H
    for i, x in enumerate((-fx * 0.3, fx * 0.3)):   # along y
        block(f"StrapY{i}", (x, 0, top + STRAP_T / 2 + 0.008), (STRAP_W, fy + 0.01, STRAP_T), strap)
        for s in (-1, 1):
            block(f"StrapY{i}Side{s}", (x, s * (fy / 2 + STRAP_T), PALLET_H + drop / 2 + 0.004),
                  (STRAP_W, STRAP_T, drop + 0.01), strap)
        block(f"BuckleY{i}", (x, -fy * 0.18, top + 0.016), (0.05, 0.075, 0.014), buckle, bevel=0.003)
    block("StrapX", (0, 0, top + STRAP_T / 2 + 0.011), (fx + 0.01, STRAP_W, STRAP_T), strap)
    for s in (-1, 1):
        block(f"StrapXSide{s}", (s * (fx / 2 + STRAP_T), 0, PALLET_H + drop / 2 + 0.004),
              (STRAP_T, STRAP_W, drop + 0.01), strap)
    block("BuckleX", (fx * 0.12, 0, top + 0.019), (0.075, 0.05, 0.014), buckle, bevel=0.003)


def build_sandbag_load(seed):
    """SAND_LAYERS layers of filled sandbags, SAND_ALONG x SAND_ACROSS to a
    layer, alternate layers turned 90 degrees, centred on the pallet. Same
    bags as the wall (sandbags.py bag()), each one different. Returns the
    load's footprint (x, y) and top height, measured from the bags."""
    import sandbags as sb
    mat = sb.burlap_material()
    bags = []
    for layer in range(SAND_LAYERS):
        turned = layer % 2 == 1
        for i in range(SAND_ALONG):
            for j in range(SAND_ACROSS):
                along = (i - (SAND_ALONG - 1) / 2) * SAND_BAG_L
                across = (j - (SAND_ACROSS - 1) / 2) * SAND_BAG_W
                obj = sb.bag(f"Bag{layer}{i}{j}", 0.0, layer, SAND_BAG_L, SAND_BAG_W,
                             ("crate", seed, layer, i, j), mat)
                x, y = (across, along) if turned else (along, across)
                obj.location.x += x
                obj.location.y += y
                obj.location.z += PALLET_H
                if turned:
                    obj.rotation_euler.z += math.pi / 2
                bags.append(obj)
    bpy.context.view_layer.update()
    lo = Vector((1e9, 1e9, 1e9))
    hi = Vector((-1e9, -1e9, -1e9))
    for obj in bags:
        for corner in obj.bound_box:
            w = obj.matrix_world @ Vector(corner)
            lo = Vector(map(min, lo, w))
            hi = Vector(map(max, hi, w))
    return (hi.x - lo.x, hi.y - lo.y), hi.z


KINDS = {
    "ammo": build_ammo_load,
    "sandbags": build_sandbag_load,
}


# ---------------------------------------------------------------- render --

def clear():
    for obj in list(bpy.data.objects):
        if obj.type == "MESH":
            bpy.data.objects.remove(obj)


def render_kind(kind):
    scene = bs.new_scene(center=(0.0, 0.0), frame_m=FRAME_M, transparent=True, samples=SAMPLES,
                         px_per_m=bs.PX_PER_M * RENDER_SCALE)
    footprint, top = KINDS[kind](seed=7)
    build_straps(footprint, top)
    bs.render_to(scene, os.path.join(ROOT, "assets", "props", f"crate_{kind}.png"))   # the load only
    build_pallet(wood_material())   # for the .blend and the review
    blend = os.path.join(ROOT, "blender", "source", f"crate_{kind}.blend")
    os.makedirs(os.path.dirname(blend), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=blend)
    # An angled look, like the reference photo.
    cam = bpy.data.objects.new("Review", bpy.data.cameras.new("Review"))
    scene.collection.objects.link(cam)
    cam.data.lens = 50
    target = Vector((0, 0, 0.32))
    cam.location = Vector((2.0, -2.6, 1.9))
    cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam
    scene.render.resolution_x, scene.render.resolution_y = 900, 700
    scene.render.film_transparent = False
    bg = next(n for n in scene.world.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs["Color"].default_value = (0.9, 0.9, 0.9, 1)
    bs.render_to(scene, os.path.join(ROOT, "assets", "previews", f"crate_{kind}_preview.png"))
    print(f"crate_{kind}: pallet {PALLET_L} x {PALLET_W} m, {PALLET_H:.3f} m high; "
          f"load {footprint[0]:.3f} x {footprint[1]:.3f} m, top at {top:.3f} m (crate.gd)")


def render_pallet():
    """The pallet on its own, in the crates' frame: every crate stands on it."""
    scene = bs.new_scene(center=(0.0, 0.0), frame_m=FRAME_M, transparent=True, samples=SAMPLES,
                         px_per_m=bs.PX_PER_M * RENDER_SCALE)
    build_pallet(wood_material())
    bs.render_to(scene, os.path.join(ROOT, "assets", "props", "pallet.png"))
    print(f"pallet: {PALLET_L} x {PALLET_W} m, {PALLET_H:.3f} m high (crate.gd)")


def render_can():
    """One ammo can on its own, the same as the ones on the ammo crate."""
    scene = bs.new_scene(center=(0.0, 0.0), frame_m=CAN_FRAME_M, transparent=True, samples=SAMPLES,
                         px_per_m=bs.PX_PER_M * RENDER_SCALE)
    mats = (paint_material("Olive", OLIVE), paint_material("CanSteel", srgb(0.18, 0.19, 0.15), 0.45, 0.6),
            paint_material("Stencil", STENCIL, 0.7, 0.0, wear=False))
    build_ammo_can("Can", (0.0, 0.0, 0.0), mats, flip=False, rot_z=0.0)
    bpy.context.view_layer.update()
    lo = Vector((1e9, 1e9, 1e9))
    hi = Vector((-1e9, -1e9, -1e9))
    for obj in bpy.data.objects:
        if obj.type == "MESH":
            for corner in obj.bound_box:
                w = obj.matrix_world @ Vector(corner)
                lo = Vector(map(min, lo, w))
                hi = Vector(map(max, hi, w))
    bs.render_to(scene, os.path.join(ROOT, "assets", "props", "ammo_can.png"))
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT, "blender", "source", "ammo_can.blend"))
    cam = bpy.data.objects.new("Review", bpy.data.cameras.new("Review"))
    scene.collection.objects.link(cam)
    cam.data.lens = 50
    target = Vector((0, 0, 0.09))
    cam.location = Vector((0.62, -0.8, 0.6))
    cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam
    scene.render.resolution_x, scene.render.resolution_y = 700, 560
    scene.render.film_transparent = False
    bg = next(n for n in scene.world.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs["Color"].default_value = (0.9, 0.9, 0.9, 1)
    bs.render_to(scene, os.path.join(ROOT, "assets", "previews", "ammo_can_preview.png"))
    print(f"ammo_can: {hi.x - lo.x:.3f} x {hi.y - lo.y:.3f} m (centre {(hi.x + lo.x) / 2:+.3f}, {(hi.y + lo.y) / 2:+.3f}), "
          f"top at {hi.z:.3f} m (crate.gd)")


def main():
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else ["pallet"] + list(KINDS) + ["can"]
    for kind in args:
        bpy.ops.wm.read_factory_settings(use_empty=True)
        if kind == "pallet":
            render_pallet()
        elif kind == "can":
            render_can()
        else:
            render_kind(kind)


if __name__ == "__main__":
    main()
