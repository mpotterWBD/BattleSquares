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
  comms  the kit a radio station is built from (scripts/radio_station.gd),
         one item per part, side by side so each shows from above
         (COMMS_PARTS, in the order they're taken): the field desk folded
         into a bundle (panels with the legs strapped on), the electronics
         in a black rugged case, the dish's legs in an olive case, the dish
         in a rounded desert-tan case, and the wiring on a cable reel. As
         the station is built the game swaps in a sprite with one fewer
         (crate_comms_1..4.png, no straps); crate_comms.png is it full.
  sandbags  filled burlap sandbags (the same bags as the sandbag wall,
         blender/scripts/sandbags.py), SAND_ACROSS x SAND_ALONG to a layer,
         SAND_LAYERS high, each layer turned 90 degrees from the one below.
         The crate holds 10 walls' worth; as they're used the game swaps in
         a smaller stack (SAND_STAGES: crate_sandbags_1..3.png, no straps).

Also a lone ammo can (`-- can`; render_can()): one of the same cans, on
its own, for assets/props/ammo_can.png (CAN_FRAME_M square) and its review.

Output, per kind: assets/props/crate_<kind>.png, the load and straps only,
and crate_<kind>_open.png, the same load with the straps cut off
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
## The smaller stacks as the bags are used: how many bags are left in each
## (from the bottom up), for crate_sandbags_1..3.png.
SAND_STAGES = [24, 15, 3]
SAND_BAG_OBJECTS = []   # every bag, bottom layer first (filled by build_sandbag_load())
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
                SAND_BAG_OBJECTS.append(obj)
    bpy.context.view_layer.update()
    lo = Vector((1e9, 1e9, 1e9))
    hi = Vector((-1e9, -1e9, -1e9))
    for obj in bags:
        for corner in obj.bound_box:
            w = obj.matrix_world @ Vector(corner)
            lo = Vector(map(min, lo, w))
            hi = Vector(map(max, hi, w))
    return (hi.x - lo.x, hi.y - lo.y), hi.z


DESK_GREY = srgb(0.3, 0.32, 0.27)   # radio_station.py's desk
POLYMER = srgb(0.06, 0.06, 0.06)
DISH_TAN = srgb(0.80, 0.72, 0.58)   # radio_station.py's dish


def rugged_case(name, center, size, body, trim, label=None, bevel=0.014, handles="top"):
    """A rugged equipment case (Pelican-style) standing on `center` (x, y,
    z of its base): a bevelled shell, the lid's seam a little proud round it
    near the top, latches along its long sides, a carry handle on top, and
    a label plate or stencil (`label`: a material) on the long sides."""
    w, d, h = size
    x, y, z = center
    block(name, (x, y, z + h / 2), size, body, bevel=bevel)
    seam_z = z + h * 0.72
    block(name + "Seam", (x, y, seam_z), (w + 0.008, d + 0.008, 0.012), trim, bevel=0.003)
    long_x = w >= d
    for side in (-1, 1):
        for k in (-1, 1):
            offset = k * (w if long_x else d) * 0.28
            if long_x:
                at, latch = (x + offset, y + side * (d / 2 + 0.006), seam_z), (0.05, 0.012, 0.045)
            else:
                at, latch = (x + side * (w / 2 + 0.006), y + offset, seam_z), (0.012, 0.05, 0.045)
            block(f"{name}Latch{side}{k}", at, latch, trim, bevel=0.003)
        if label is not None:
            if long_x:
                block(f"{name}Label{side}", (x, y + side * (d / 2 + 0.001), z + h * 0.38), (w * 0.35, 0.002, h * 0.18), label)
            else:
                block(f"{name}Label{side}", (x + side * (w / 2 + 0.001), y, z + h * 0.38), (0.002, d * 0.35, h * 0.18), label)
    if handles == "top":
        top = z + h
        along = (0.14, 0.025, 0.012) if long_x else (0.025, 0.14, 0.012)
        block(name + "Handle", (x, y, top + 0.012), along, trim, bevel=0.004)
        for k in (-1, 1):
            pivot = (x + k * 0.075, y, top + 0.006) if long_x else (x, y + k * 0.075, top + 0.006)
            block(f"{name}Pivot{k}", pivot, (0.02, 0.03, 0.012) if long_x else (0.03, 0.02, 0.012), trim)


def cable_reel(name, center, radius, height, flange, cable):
    """A cable reel standing on end: two flanges and a drum wound with cable."""
    x, y, z = center
    for k, fz in enumerate((z + 0.008, z + height - 0.008)):
        bpy.ops.mesh.primitive_cylinder_add(vertices=40, radius=radius, depth=0.016, location=(x, y, fz))
        obj = bpy.context.active_object
        obj.name = f"{name}Flange{k}"
        obj.data.materials.append(flange)
    bpy.ops.mesh.primitive_cylinder_add(vertices=40, radius=radius * 0.86, depth=height - 0.03, location=(x, y, z + height / 2))
    wound = bpy.context.active_object
    wound.name = name + "Cable"
    wound.data.materials.append(cable)
    # Turns of cable showing as ridges round the drum.
    for k in range(6):
        bpy.ops.mesh.primitive_torus_add(major_radius=radius * 0.86, minor_radius=0.009,
                                         location=(x, y, z + 0.03 + k * (height - 0.06) / 5))
        ring = bpy.context.active_object
        ring.name = f"{name}Turn{k}"
        ring.data.materials.append(cable)
    bpy.ops.mesh.primitive_cylinder_add(vertices=24, radius=0.03, depth=0.01, location=(x, y, z + height + 0.002))
    hub = bpy.context.active_object
    hub.name = name + "Hub"
    hub.data.materials.append(flange)


## The comms crate's parts, in the order they're taken off it (radio_station.gd
## PARTS), and the objects that make up each (filled by build_comms_load()).
COMMS_PARTS = ["desk", "electronics", "legs", "dish", "wiring"]
COMMS_OBJECTS = {}


def build_comms_load(seed):
    """The radio station's kit, centred on the pallet, each part its own item
    and all showing from above: the folded desk along the north side, and
    in front of it the electronics case and the legs case, then the dish
    case and the cable reel. Returns the load's footprint (x, y) and top
    height, measured. Fills COMMS_OBJECTS."""
    desk = paint_material("DeskGrey", DESK_GREY, 0.8, 0.1)
    polymer = paint_material("Polymer", POLYMER, 0.55, 0.0, wear=False)
    trim = paint_material("CaseTrim", srgb(0.2, 0.2, 0.2), 0.45, 0.4, wear=False)
    olive = paint_material("Olive", OLIVE)
    tan = paint_material("DishTan", DISH_TAN, 0.6, 0.0)
    stencil = paint_material("Stencil", STENCIL, 0.7, 0.0, wear=False)
    plate = paint_material("Plate", srgb(0.75, 0.75, 0.72), 0.5, 0.3, wear=False)
    cable = paint_material("Cable", srgb(0.04, 0.04, 0.04), 0.7, 0.0, wear=False)
    z = PALLET_H
    black = paint_material("LegBundle", srgb(0.05, 0.05, 0.05), 0.5, 0.3, wear=False)

    def part(name, make):
        before = set(bpy.data.objects)
        make()
        COMMS_OBJECTS[name] = [o for o in bpy.data.objects if o not in before]

    def desk_bundle():
        # The desk's two top halves, stacked, with its folded legs and a
        # webbing strap round them.
        for k in range(2):
            block(f"DeskHalf{k}", (0, 0.24, z + 0.0175 + k * 0.036), (0.72, 0.24, 0.035), desk, bevel=0.006)
        for k in range(4):
            block(f"DeskLegFolded{k}", (0, 0.17 + k * 0.045, z + 0.082), (0.66, 0.022, 0.022), black, bevel=0.004)
        for x in (-0.22, 0.22):
            block(f"DeskTie{x:+.2f}", (x, 0.24, z + 0.05), (0.035, 0.25, 0.104), trim)

    part("desk", desk_bundle)
    part("electronics", lambda: rugged_case("ElectronicsCase", (-0.18, -0.02, z), (0.35, 0.22, 0.26), polymer, trim, label=plate))
    part("legs", lambda: rugged_case("LegsCase", (0.18, -0.02, z), (0.35, 0.22, 0.26), olive, trim, label=stencil))
    part("dish", lambda: rugged_case("DishCase", (-0.18, -0.25, z), (0.35, 0.22, 0.26), tan, trim, bevel=0.045))
    part("wiring", lambda: cable_reel("Reel", (0.18, -0.25, z), 0.11, 0.24, olive, cable))
    bpy.context.view_layer.update()
    lo = Vector((1e9, 1e9, 1e9))
    hi = Vector((-1e9, -1e9, -1e9))
    for obj in bpy.data.objects:
        if obj.type == "MESH" and obj.matrix_world.translation.z > PALLET_H - 0.001:
            for corner in obj.bound_box:
                w = obj.matrix_world @ Vector(corner)
                lo = Vector(map(min, lo, w))
                hi = Vector(map(max, hi, w))
    return (hi.x - lo.x, hi.y - lo.y), hi.z


KINDS = {
    "ammo": build_ammo_load,
    "comms": build_comms_load,
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
    straps_from = set(bpy.data.objects)
    build_straps(footprint, top)
    straps = [o for o in bpy.data.objects if o not in straps_from]
    bs.render_to(scene, os.path.join(ROOT, "assets", "props", f"crate_{kind}.png"))   # the load only
    # The same load with its straps cut off (the game swaps it in, crate.gd).
    for obj in straps:
        obj.hide_render = True
    bs.render_to(scene, os.path.join(ROOT, "assets", "props", f"crate_{kind}_open.png"))
    for obj in straps:
        obj.hide_render = False
    if kind == "comms":
        # As the station's built: the straps cut, then one part fewer each time.
        for obj in straps:
            obj.hide_render = True
        for k, name in enumerate(COMMS_PARTS[:-1]):
            for obj in COMMS_OBJECTS[name]:
                obj.hide_render = True
            bs.render_to(scene, os.path.join(ROOT, "assets", "props", f"crate_{kind}_{k + 1}.png"))
        for name in COMMS_PARTS:
            for obj in COMMS_OBJECTS[name]:
                obj.hide_render = False
        for obj in straps:
            obj.hide_render = False
    if kind == "sandbags":
        # As the walls are used: the straps cut, and smaller stacks.
        for obj in straps:
            obj.hide_render = True
        for k, left in enumerate(SAND_STAGES):
            for i, obj in enumerate(SAND_BAG_OBJECTS):
                obj.hide_render = i >= left
            bs.render_to(scene, os.path.join(ROOT, "assets", "props", f"crate_{kind}_{k + 1}.png"))
        for obj in SAND_BAG_OBJECTS + straps:
            obj.hide_render = False
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
