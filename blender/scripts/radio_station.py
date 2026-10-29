"""Render a deployable field comms station as a top-down prop, at real size.

Run headless:
    blender --background --python radio_station.py

Pieces (metres; +x = screen right, +y = screen up):
  - radio mast at the origin: tripod base, three telescoping sections to
    7 m, dipole crossbar and whip on top, three guy wires to staked anchors
    with orange marker flags (4.5 m out)
  - 1 m portable satellite dish on a short tripod, tilted up, with feed arm
  - operator platform: a 2 m square plank deck east of the mast, between
    two guy wires; the operator stands on it to work the radio
  - field desk along the platform's far edge, facing the operator, with a
    field radio (controls on top, handset, 1.2 m whip antenna), the rugged
    laptop and mouse, a power unit, headset, notebook and pen, and a mug
  - cables linking the desk to the mast and the dish

It doesn't turn once set up, so unlike the helicopter it's lit by the
normal top-left sun (bs_common), with its shadow rendered separately (a
shadow catcher) like the squares'. Rendered at RENDER_SCALE x the game's
pixel density for the small parts; show it at 1/RENDER_SCALE in Godot.

Outputs (all centred on the mast base):
  assets/props/radio_station.png          the tall parts, drawn over squares
  assets/props/radio_station_ground.png   the deck, ground cables and
                                          stakes, drawn under squares
  assets/props/radio_station_shadow.png   its shadow, normalised so an
                                          open-ground shadow is fully opaque
  assets/previews/radio_station_preview.png  composited on grass, for review
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

ROOT = r"F:\Projects\BattleSquares"
OUT_BODY = os.path.join(ROOT, "assets", "props", "radio_station.png")
OUT_SHADOW = os.path.join(ROOT, "assets", "props", "radio_station_shadow.png")
OUT_BLEND = os.path.join(ROOT, "blender", "source", "radio_station.blend")

RENDER_SCALE = 2
FRAME_M = 12.5          # stakes 4.5 m out, plus the mast's ~6 m shadow to the bottom-right
SAMPLES = 128
SHADOW_ALPHA = 0.71     # open-ground shadow level (character_square.py), for normalising
# The shared sun is 8 degrees wide for soft character shadows. That blurs
# a 12 cm mast's shadow away entirely within a metre or so, so this prop
# uses a near-real sun width (the real sun is ~0.5 degrees).
SUN_SOFTNESS_DEG = 1.0

OLIVE = (0.27, 0.29, 0.2)
OLIVE_DARK = (0.17, 0.19, 0.14)
METAL = (0.55, 0.56, 0.55)
BLACK = (0.03, 0.03, 0.03)
TAN = (0.55, 0.47, 0.33)
DISH = (0.72, 0.72, 0.68)
ORANGE = (1.0, 0.42, 0.05)
GUNMETAL = (0.24, 0.25, 0.26)
RUBBER = (0.04, 0.04, 0.04)
LED = (0.3, 1.0, 0.35)

# Operator platform and desk. scenes/radio_station.tscn's desk collision and
# operator zone must match these.
PLATFORM_AT = Vector((3.0, 0.0, 0.0))
PLATFORM_M = 2.0
PLATFORM_H = 0.12
DESK_AT = Vector((3.65, 0.0, PLATFORM_H))   # desk centre, on the deck
DESK_SIZE = (1.4, 0.6)                      # length across the operator, depth
DESK_TOP_Z = 0.75                           # above the deck

WOOD = (0.5, 0.41, 0.28)
DESK_GREY = (0.3, 0.32, 0.27)
PAPER = (0.92, 0.9, 0.84)

OUT_CLOSEUP = os.path.join(ROOT, "assets", "previews", "radio_station_desk_closeup.png")
OUT_GROUND = os.path.join(ROOT, "assets", "props", "radio_station_ground.png")
# Parts low enough for a square to walk over or onto (the deck, ground
# cables, stakes and their flags), rendered as their own image that the
# game draws under the squares. Everything else is drawn over them.
GROUND_PARTS = {"Joist", "Plank", "DeckEdge", "Cable", "Stake", "Flag"}
# The dish turns in the game (it's aimed with the tuning wheel), so its
# turning parts are left out of the station images and rendered on their
# own, lit from straight overhead so the game can rotate them freely, like
# the helicopter. Its tripod and post stay in the station.
# scripts/radio_station.gd must match DISH_AT, and treats the dish as built
# facing south (screen down).
DISH_AT = Vector((-2.2, -1.6, 0.0))
DISH_PARTS = {"Dish", "FeedArm", "Feed"}
DISH_FRAME_M = 2.4
OUT_DISH = os.path.join(ROOT, "assets", "props", "radio_station_dish.png")
CLOSEUP_SCALE = 8       # close-up review render: 8x the game's pixel density


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


def add(name, mesh, mat, smooth=True):
    mesh.materials.append(mat)
    if smooth:
        mesh.shade_smooth()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def rod(name, a, b, radius, mat, segs=12):
    """A cylinder from point a to point b."""
    a, b = Vector(a), Vector(b)
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=segs, radius1=radius,
                          radius2=radius, depth=(b - a).length)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    obj = add(name, me, mat)
    obj.location = (a + b) / 2
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(b - a)
    return obj


def box(name, center, size, mat, bevel=0.0, rot_z=0.0):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, verts=bm.verts, vec=size)
    if bevel:
        bmesh.ops.bevel(bm, geom=list(bm.edges), offset=bevel, segments=3,
                        profile=0.5, affect="EDGES")
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    obj = add(name, me, mat)
    obj.location = center
    obj.rotation_euler.z = rot_z
    return obj


def cable(name, points, mat, radius=0.012, z=0.0):
    """A cable lying along a surface at height z (the ground by default)
    through the given (x, y) points."""
    curve = bpy.data.curves.new(name, "CURVE")
    curve.dimensions = "3D"
    curve.bevel_depth = radius
    curve.bevel_resolution = 2
    spline = curve.splines.new("BEZIER")
    spline.bezier_points.add(len(points) - 1)
    for bp, (x, y) in zip(spline.bezier_points, points):
        bp.co = (x, y, z + radius)
        bp.handle_left_type = bp.handle_right_type = "AUTO"
    curve.materials.append(mat)
    obj = bpy.data.objects.new(name, curve)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def screen_image(w=640, h=400):
    """What's on the laptop: a field mapping app. A dark topographic map
    with contour lines and a grid, a dashed route from friendly units (blue)
    to an objective (red), a status bar along the top and a side panel with
    text and signal-strength bars. Colours are sRGB."""
    y, x = np.mgrid[0:h, 0:w].astype(np.float64)
    img = np.zeros((h, w, 3))
    img[:] = (0.03, 0.06, 0.10)
    map_w, top = int(w * 0.72), int(h * 0.09)
    on_map = (x < map_w) & (y >= top)
    terrain = (np.sin(x * 0.045) + np.cos(y * 0.06) + 0.7 * np.sin((x + 1.3 * y) * 0.025)
               + 0.4 * np.cos((x - y) * 0.05))
    img[on_map & (terrain > 0.6)] = (0.05, 0.13, 0.09)                       # high ground
    img[on_map & (np.abs((terrain * 4) % 1 - 0.5) > 0.44)] = (0.2, 0.45, 0.28)  # contours
    img[on_map & (((x % 64) < 1.5) | (((y - top) % 64) < 1.5))] = (0.12, 0.25, 0.36)  # grid
    route = [(60, 330), (170, 250), (260, 270), (360, 170), (420, 110)]
    for (x0, y0), (x1, y1) in zip(route, route[1:]):
        for t in np.linspace(0, 1, 120):
            if int(t * 12) % 2:
                continue   # dashes
            cx, cy = int(x0 + (x1 - x0) * t), int(y0 + (y1 - y0) * t)
            img[cy - 2:cy + 2, cx - 2:cx + 2] = (1.0, 0.85, 0.2)
    for cx, cy in [(60, 330), (82, 346), (46, 352)]:
        img[cy - 6:cy + 6, cx - 6:cx + 6] = (0.35, 0.65, 1.0)                  # friendly units
    img[(np.abs(x - 420) + np.abs(y - 110)) < 13] = (1.0, 0.28, 0.22)         # objective
    img[:top] = (0.08, 0.17, 0.26)                                           # status bar
    for i in range(5):
        img[12:21, 18 + i * 72:18 + i * 72 + 46] = (0.72, 0.82, 0.9)
    img[top:, map_w:map_w + 2] = (0.2, 0.36, 0.46)                            # side panel
    for row in range(9):
        y0 = top + 18 + row * 24
        img[y0:y0 + 7, map_w + 16:map_w + 16 + (120 if row % 3 else 80)] = (0.6, 0.68, 0.75)
    for k in range(5):                                                       # signal bars
        bar_h = 10 + k * 9
        img[h - 24 - bar_h:h - 24, map_w + 20 + k * 18:map_w + 32 + k * 18] = (0.3, 0.95, 0.4)
    image = bpy.data.images.new("LaptopScreen", w, h)
    rgba = np.ones((h, w, 4), dtype=np.float32)
    rgba[..., :3] = img
    image.pixels.foreach_set(rgba[::-1].ravel())   # Blender's rows run bottom-up
    image.pack()
    return image


def screen_material():
    mat = bpy.data.materials.new("LaptopScreen")
    nt = bs.node_tree_of(mat)
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = screen_image()
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Emission Color"])
    bsdf.inputs["Emission Strength"].default_value = 1.6
    bsdf.inputs["Roughness"].default_value = 0.2
    if "Specular IOR Level" in bsdf.inputs:
        bsdf.inputs["Specular IOR Level"].default_value = 0.25
    return mat


def keys_mesh(name):
    """Five rows of keys plus a spacebar, as one mesh."""
    bm = bmesh.new()
    key, gap, top = 0.0175, 0.0035, 0.004
    for row in range(5):
        y = 0.095 - row * (key + gap)
        for col in range(14):
            x = -0.143 + col * (key + gap) + key / 2 + (0.006 if row % 2 else 0.0)
            if x > 0.145:
                continue
            bmesh.ops.create_cube(bm, size=1.0, matrix=Matrix.LocRotScale(
                (x, y, top / 2), None, (key, key * 0.95, top)))
    bmesh.ops.create_cube(bm, size=1.0, matrix=Matrix.LocRotScale(
        (0, 0.095 - 5 * (key + gap), top / 2), None, (0.11, key * 0.95, top)))   # spacebar
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    return me


def build_laptop(at, rot_z, parent=None):
    """A rugged field laptop, open and in use: gunmetal shell, rubber corner
    bumpers, front carry handle, hinge barrels, port covers, status lights,
    a keyboard of individual keys and a touchpad, and a thick lid opened 45
    degrees past upright so its screen faces up toward the camera. Local
    frame: x across, y away from the user (hinge at +y), z up from the
    base's underside."""
    gunmetal = material("Gunmetal", GUNMETAL, metallic=0.5, roughness=0.45)
    rubber = material("Rubber", RUBBER, roughness=0.9)
    keycap = material("Keycap", (0.06, 0.06, 0.065), roughness=0.55)
    pad = material("Touchpad", (0.12, 0.12, 0.13), roughness=0.3)
    led = material("Led", LED, emit=6.0)
    lens = material("Lens", (0.05, 0.08, 0.15), roughness=0.05)

    root = bpy.data.objects.new("Laptop", None)
    root.location = at          # relative to `parent` if given
    root.rotation_euler.z = rot_z
    root.parent = parent
    bpy.context.scene.collection.objects.link(root)
    parts = []

    # Base.
    parts.append(box("LaptopBase", (0, 0, 0.0225), (0.34, 0.27, 0.045), gunmetal, bevel=0.006))
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts.append(box("Bumper", (sx * 0.165, sy * 0.13, 0.024), (0.035, 0.035, 0.05), rubber, bevel=0.008))
        parts.append(box("PortCover", (sx * 0.171, 0.0, 0.022), (0.004, 0.06, 0.02), rubber))
        parts.append(rod("HandleArm", (sx * 0.11, -0.13, 0.02), (sx * 0.11, -0.165, 0.02), 0.008, rubber))
        parts.append(rod("Hinge", (sx * 0.07, 0.135, 0.05), (sx * 0.15, 0.135, 0.05), 0.012, gunmetal))
    parts.append(rod("Handle", (-0.11, -0.165, 0.02), (0.11, -0.165, 0.02), 0.009, rubber))
    parts.append(box("KeyWell", (0, 0.04, 0.0455), (0.31, 0.125, 0.002), rubber))
    keys = add("Keys", keys_mesh("Keys"), keycap, smooth=False)
    keys.location = (0, 0, 0.046)
    parts.append(keys)
    parts.append(box("Touchpad", (0, -0.06, 0.0455), (0.08, 0.05, 0.002), pad))
    for sx in (-1, 1):
        parts.append(box("PadButton", (sx * 0.021, -0.093, 0.0455), (0.038, 0.012, 0.002), rubber))
    for i in range(3):
        parts.append(box("StatusLed", (0.1 + i * 0.012, -0.105, 0.0458), (0.005, 0.005, 0.002), led))

    # Lid, on a hinge at the back edge, opened 45 degrees past upright.
    hinge = bpy.data.objects.new("LidHinge", None)
    hinge.location = (0, 0.135, 0.05)
    hinge.rotation_euler.x = math.radians(-45)
    hinge.parent = root
    bpy.context.scene.collection.objects.link(hinge)
    lid_parts = [box("LidShell", (0, 0, 0.13), (0.34, 0.022, 0.26), gunmetal, bevel=0.006),
                 box("Bezel", (0, -0.0115, 0.13), (0.32, 0.002, 0.24), rubber),
                 box("Webcam", (0, -0.0128, 0.237), (0.008, 0.002, 0.008), lens),
                 box("LidLatch", (0, -0.012, 0.255), (0.06, 0.01, 0.015), rubber)]
    for sx in (-1, 1):
        for z in (0.012, 0.25):
            lid_parts.append(box("LidBumper", (sx * 0.165, 0, z), (0.035, 0.03, 0.035), rubber, bevel=0.008))
    sw, sh, sz = 0.29, 0.19, 0.035   # screen width, height, and its bottom edge above the hinge
    me = bpy.data.meshes.new("ScreenPanel")
    me.from_pydata([(-sw / 2, -0.0127, sz), (sw / 2, -0.0127, sz),
                    (sw / 2, -0.0127, sz + sh), (-sw / 2, -0.0127, sz + sh)], [], [(0, 1, 2, 3)])
    uv = me.uv_layers.new()
    for loop, coord in zip(uv.data, [(0, 0), (1, 0), (1, 1), (0, 1)]):
        loop.uv = coord
    lid_parts.append(add("Screen", me, screen_material(), smooth=False))
    for obj in lid_parts:
        obj.parent = hinge

    # A mouse to the right, cabled to the side port.
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=20, v_segments=12, radius=1.0)
    bmesh.ops.scale(bm, verts=bm.verts, vec=(0.03, 0.05, 0.016))
    mouse_me = bpy.data.meshes.new("Mouse")
    bm.to_mesh(mouse_me)
    bm.free()
    mouse = add("Mouse", mouse_me, rubber)
    mouse.location = (0.26, -0.04, 0.008)
    parts.append(mouse)
    parts.append(cable("MouseCable", [(0.26, 0.01), (0.23, 0.06), (0.19, 0.03), (0.172, 0.0)],
                       rubber, radius=0.0025))
    for obj in parts:
        obj.parent = root


def build_platform():
    """A 2 m square deck of planks on three joists, with a darker frame."""
    rng = np.random.default_rng(3)
    joist = material("Joist", (0.2, 0.17, 0.12), roughness=0.9)
    frame = material("DeckFrame", (0.3, 0.25, 0.17), roughness=0.85)
    half = PLATFORM_M / 2
    for dy in (-0.75, 0.0, 0.75):
        box("Joist", PLATFORM_AT + Vector((0, dy, 0.04)), (PLATFORM_M - 0.1, 0.09, 0.08), joist)
    planks, gap = 10, 0.012
    width = (PLATFORM_M - 0.12 - gap * (planks - 1)) / planks
    for i in range(planks):
        x = -half + 0.06 + width / 2 + i * (width + gap)
        tint = rng.uniform(0.85, 1.1)
        plank = material("Plank", tuple(c * tint for c in WOOD), roughness=0.85)
        box("Plank", PLATFORM_AT + Vector((x, 0, PLATFORM_H - 0.02)), (width, PLATFORM_M - 0.12, 0.04),
            plank, bevel=0.004)
    for sx, sy, sizex, sizey in ((0, 1, PLATFORM_M, 0.06), (0, -1, PLATFORM_M, 0.06),
                                 (1, 0, 0.06, PLATFORM_M), (-1, 0, 0.06, PLATFORM_M)):
        box("DeckEdge", PLATFORM_AT + Vector((sx * (half - 0.03), sy * (half - 0.03), PLATFORM_H / 2)),
            (sizex, sizey, PLATFORM_H), frame)


def build_desk():
    """A folding field desk on the deck with the radio, laptop and kit on it.
    Local frame: x along the desk, y away from the operator, z up from the
    deck; the desk is turned so the operator faces it from the mast side."""
    black = material("DeskBlack", BLACK, roughness=0.6)
    olive_dark = material("RadioOlive", OLIVE_DARK, roughness=0.75)
    top_mat = material("DeskTop", DESK_GREY, roughness=0.8)
    metal = material("DeskMetal", METAL, metallic=0.8, roughness=0.35)
    grey = material("PowerGrey", (0.35, 0.36, 0.36), roughness=0.6)
    lcd = material("RadioLcd", (0.45, 1.0, 0.55), emit=3.0)
    led_green = material("LedGreen", LED, emit=6.0)
    led_red = material("LedRed", (1.0, 0.2, 0.15), emit=6.0)
    paper = material("Paper", PAPER, roughness=0.9)
    ink = material("Ink", (0.15, 0.2, 0.45), roughness=0.5)
    cushion = material("Cushion", (0.2, 0.2, 0.2), roughness=0.95)
    mug_mat = material("Mug", (0.33, 0.36, 0.25), roughness=0.5)
    coffee = material("Coffee", (0.12, 0.06, 0.03), roughness=0.15)

    root = bpy.data.objects.new("Desk", None)
    root.location = DESK_AT
    root.rotation_euler.z = -math.pi / 2   # operator side (-y) toward the mast (-x)
    bpy.context.scene.collection.objects.link(root)
    parts = []
    length, depth = DESK_SIZE
    top = DESK_TOP_Z

    # The desk: top and four folding legs with cross bars.
    parts.append(box("DeskTop", (0, 0, top - 0.015), (length, depth, 0.03), top_mat, bevel=0.01))
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts.append(rod("DeskLeg", (sx * (length / 2 - 0.05), sy * (depth / 2 - 0.05), 0),
                             (sx * (length / 2 - 0.05), sy * (depth / 2 - 0.05), top - 0.03), 0.015, black))
        parts.append(rod("LegBar", (sx * (length / 2 - 0.05), -(depth / 2 - 0.05), 0.15),
                         (sx * (length / 2 - 0.05), depth / 2 - 0.05, 0.15), 0.01, black))

    # Field radio lying flat, controls on its top face, with the whip antenna.
    rx, ry, rh = -0.45, 0.06, 0.16
    parts.append(box("Radio", (rx, ry, top + rh / 2), (0.42, 0.3, rh), olive_dark, bevel=0.012))
    parts.append(box("RadioPanel", (rx + 0.01, ry - 0.01, top + rh + 0.002), (0.34, 0.22, 0.004), black))
    parts.append(box("RadioLcd", (rx - 0.07, ry + 0.05, top + rh + 0.005), (0.13, 0.05, 0.003), lcd))
    for row in range(4):
        for col in range(3):
            parts.append(box("RadioKey", (rx + 0.06 + col * 0.026, ry + 0.06 - row * 0.026, top + rh + 0.006),
                             (0.018, 0.018, 0.005), grey))
    for k, kx in enumerate((-0.14, -0.08)):
        parts.append(rod("RadioKnob", (rx + kx, ry - 0.06, top + rh), (rx + kx, ry - 0.06, top + rh + 0.03),
                         0.018 if k == 0 else 0.013, black))
        parts.append(rod("KnobCap", (rx + kx, ry - 0.06, top + rh + 0.03),
                         (rx + kx, ry - 0.06, top + rh + 0.034), 0.008, metal))
    for hx in (-0.17, 0.17):
        parts.append(rod("HandlePost", (rx + hx, ry + 0.13, top + rh), (rx + hx, ry + 0.13, top + rh + 0.03), 0.008, black))
    parts.append(rod("RadioHandle", (rx - 0.17, ry + 0.13, top + rh + 0.03), (rx + 0.17, ry + 0.13, top + rh + 0.03),
                     0.009, black))
    whip_base = Vector((rx - 0.17, ry + 0.11, top + rh))
    parts.append(rod("WhipBase", whip_base, whip_base + Vector((0, 0, 0.05)), 0.016, black))
    parts.append(rod("RadioWhip", whip_base, whip_base + Vector((-0.05, 0.12, 1.2)), 0.006, black, segs=6))
    # Handset on its coiled cord.
    handset = box("Handset", (rx + 0.28, ry - 0.24, top + 0.022), (0.2, 0.05, 0.044), black, bevel=0.012)
    handset.rotation_euler.z = 0.35
    parts.append(handset)
    parts.append(cable("HandsetCord", [(rx + 0.2, ry - 0.21), (rx + 0.12, ry - 0.17), (rx + 0.16, ry - 0.12),
                                       (rx + 0.08, ry - 0.1)], black, radius=0.005, z=top))

    # The laptop, centre front.
    build_laptop(Vector((0.05, -0.05, top)), 0.0, parent=root)

    # Power unit with status lights, cabled to the radio and laptop.
    px_, py_ = 0.5, 0.13
    parts.append(box("PowerUnit", (px_, py_, top + 0.07), (0.26, 0.17, 0.14), grey, bevel=0.01))
    parts.append(box("PowerVent", (px_ + 0.05, py_, top + 0.141), (0.1, 0.12, 0.003), black))
    parts.append(box("PowerLedA", (px_ - 0.08, py_ - 0.05, top + 0.142), (0.012, 0.012, 0.003), led_green))
    parts.append(box("PowerLedB", (px_ - 0.08, py_ - 0.02, top + 0.142), (0.012, 0.012, 0.003), led_red))
    for tx in (-0.06, -0.03):
        parts.append(rod("Terminal", (px_ + tx, py_ + 0.05, top + 0.14), (px_ + tx, py_ + 0.05, top + 0.165), 0.008, metal))
    parts.append(cable("PowerToRadio", [(px_ - 0.13, py_ + 0.05), (0.0, 0.22), (-0.24, 0.16)], black, radius=0.006, z=top))
    parts.append(cable("PowerToLaptop", [(px_ - 0.13, py_ - 0.03), (0.3, 0.02), (0.22, -0.05)], black, radius=0.005, z=top))

    # Headset lying on the desk: a headband arc with two ear cups.
    hx, hy = 0.4, -0.18
    arc = [Vector((hx + 0.08 * math.cos(a), hy + 0.08 * math.sin(a), top + 0.012))
           for a in np.linspace(0.15 * math.pi, 0.85 * math.pi, 8)]
    for a, b in zip(arc, arc[1:]):
        parts.append(rod("Headband", a, b, 0.008, black, segs=8))
    for end in (arc[0], arc[-1]):
        parts.append(rod("EarCup", end + Vector((0, -0.02, -0.01)), end + Vector((0, -0.02, 0.02)), 0.035, black))
        parts.append(rod("EarPad", end + Vector((0, -0.02, 0.02)), end + Vector((0, -0.02, 0.026)), 0.028, cushion))

    # Notebook and pen, and a mug of coffee.
    note = box("Notebook", (0.6, -0.13, top + 0.006), (0.15, 0.21, 0.012), paper)
    note.rotation_euler.z = 0.2
    parts.append(note)
    for line in range(6):
        ruled = box("NoteLine", (0.6, -0.2 + line * 0.025, top + 0.0125), (0.12, 0.002, 0.001), ink)
        ruled.rotation_euler.z = 0.2
        parts.append(ruled)
    parts.append(rod("Pen", (0.53, -0.25, top + 0.006), (0.66, -0.2, top + 0.006), 0.005, ink, segs=8))
    parts.append(rod("Mug", (0.25, 0.19, top), (0.25, 0.19, top + 0.1), 0.045, mug_mat, segs=20))
    parts.append(rod("Coffee", (0.25, 0.19, top + 0.085), (0.25, 0.19, top + 0.095), 0.038, coffee, segs=20))

    for obj in parts:
        obj.parent = root


def build():
    olive = material("Olive", OLIVE, roughness=0.75)
    olive_dark = material("OliveDark", OLIVE_DARK, roughness=0.8)
    metal = material("Metal", METAL, metallic=0.8, roughness=0.35)
    black = material("Black", BLACK, roughness=0.6)
    dish = material("Dish", DISH, roughness=0.5)
    orange = material("Orange", ORANGE, roughness=0.6)

    # --- Radio mast: tripod, three telescoping sections, guyed. ---
    collar_z = 1.4
    for k in range(3):
        a = math.radians(90 + 120 * k)
        rod("TripodLeg", (1.2 * math.cos(a), 1.2 * math.sin(a), 0.0), (0, 0, collar_z), 0.03, olive)
    sections = [(0.0, 3.0, 0.06), (3.0, 5.2, 0.045), (5.2, 7.0, 0.032)]
    for z0, z1, r in sections:
        rod("MastSection", (0, 0, z0), (0, 0, z1), r, olive)
        rod("MastCollar", (0, 0, z1 - 0.05), (0, 0, z1 + 0.05), r + 0.018, metal)
    rod("Dipole", (-0.8, 0, 7.0), (0.8, 0, 7.0), 0.012, black)
    rod("TopWhip", (0, 0, 7.0), (0, 0, 8.2), 0.01, black)
    box("Coupler", (0, 0, 6.9), (0.16, 0.12, 0.14), olive_dark, bevel=0.01)
    for k in range(3):
        a = math.radians(30 + 120 * k)
        stake = Vector((4.5 * math.cos(a), 4.5 * math.sin(a), 0.0))
        rod("GuyWire", (0, 0, 6.5), stake + Vector((0, 0, 0.25)), 0.012, black, segs=6)
        rod("Stake", stake, stake + Vector((0, 0, 0.3)), 0.025, metal)
        # Orange marker flag tied near the top of each stake.
        box("Flag", stake + Vector((0.07, 0.0, 0.27)), (0.14, 0.02, 0.08), orange)


    # --- Satellite dish on a short tripod, aimed up and to the south. ---
    dish_at = DISH_AT
    for k in range(3):
        a = math.radians(90 + 120 * k)
        rod("DishLeg", dish_at + Vector((0.55 * math.cos(a), 0.55 * math.sin(a), 0)),
            dish_at + Vector((0, 0, 0.8)), 0.02, olive)
    rod("DishPost", dish_at, dish_at + Vector((0, 0, 0.95)), 0.035, olive)
    bm = bmesh.new()
    rings, segs, radius, depth = 8, 32, 0.5, 0.12
    verts = [[bm.verts.new((0, 0, 0))]]
    for i in range(1, rings + 1):
        r = radius * i / rings
        z = depth * (r / radius) ** 2
        verts.append([bm.verts.new((r * math.cos(2 * math.pi * j / segs),
                                    r * math.sin(2 * math.pi * j / segs), z)) for j in range(segs)])
    for j in range(segs):
        bm.faces.new((verts[0][0], verts[1][j], verts[1][(j + 1) % segs]))
    for i in range(1, rings):
        for j in range(segs):
            bm.faces.new((verts[i][j], verts[i + 1][j], verts[i + 1][(j + 1) % segs], verts[i][(j + 1) % segs]))
    bmesh.ops.solidify(bm, geom=bm.faces[:], thickness=0.015)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    dish_me = bpy.data.meshes.new("Dish")
    bm.to_mesh(dish_me)
    bm.free()
    dish_obj = add("Dish", dish_me, dish)
    elevation = math.radians(40)
    dish_obj.rotation_euler = (math.pi / 2 - elevation, 0, 0)   # tip the dish's axis down toward the south horizon
    dish_obj.location = dish_at + Vector((0, 0, 1.05))
    # Feed arm from the lower rim out to the focal point, with the feed box.
    axis = Vector((0, -math.cos(elevation), math.sin(elevation)))
    focus = dish_obj.location + axis * 0.55
    rim = dish_obj.location + Vector((0, -math.sin(elevation), -math.cos(elevation))) * 0.48
    rod("FeedArm", rim, focus, 0.012, black)
    box("Feed", focus, (0.09, 0.09, 0.09), olive_dark, bevel=0.01)

    # --- Operator platform and desk. ---
    build_platform()
    build_desk()

    # --- Cables: down the desk across the deck, then over the ground. ---
    # Each deck run ends exactly where its ground run starts, at the deck's edge.
    cable("Cable", [(3.35, 0.32), (2.7, 0.45), (2.0, 0.3)], black, z=PLATFORM_H)         # desk to deck edge
    cable("Cable", [(2.0, 0.3), (1.2, 0.4), (0.5, 0.15), (0.06, 0.02)], black)          # to the mast
    cable("Cable", [(3.35, -0.32), (2.6, -0.55), (2.0, -0.7)], black, z=PLATFORM_H)      # desk to deck edge
    cable("Cable", [(2.0, -0.7), (0.8, -1.6), (-0.8, -1.9), (-2.0, -1.65)], black)      # to the dish


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
    for path in (OUT_BODY, OUT_SHADOW, OUT_BLEND):
        os.makedirs(os.path.dirname(path), exist_ok=True)
    scene = bs.new_scene(center=(0, 0), frame_m=FRAME_M, transparent=True, samples=SAMPLES,
                         px_per_m=bs.PX_PER_M * RENDER_SCALE)
    bpy.data.lights["Sun"].angle = math.radians(SUN_SOFTNESS_DEG)
    build()
    dish = [o for o in scene.objects if o.name.split(".")[0] in DISH_PARTS]
    for obj in dish:
        obj.hide_render = True   # rendered on its own at the end
    props = [o for o in scene.objects if o not in dish]

    # The station in two layers. Hidden parts stay in the scene (just not
    # seen by the camera), so they still cast and catch shadows: the deck
    # keeps the desk's shadow on its planks.
    ground = [o for o in props if o.type in {"MESH", "CURVE"} and o.name.split(".")[0] in GROUND_PARTS]
    tall = [o for o in props if o.type in {"MESH", "CURVE"} and o not in ground]
    for obj in ground:
        obj.visible_camera = False
    bs.render_to(scene, OUT_BODY)
    for obj in ground:
        obj.visible_camera = True
    for obj in tall:
        obj.visible_camera = False
    bs.render_to(scene, OUT_GROUND)
    for obj in tall:
        obj.visible_camera = True

    # Its shadow alone, on a shadow catcher.
    ground = bpy.data.meshes.new("Ground")
    s = FRAME_M
    ground.from_pydata([(-s, -s, 0), (s, -s, 0), (s, s, 0), (-s, s, 0)], [], [(0, 1, 2, 3)])
    ground_obj = bpy.data.objects.new("Ground", ground)
    ground_obj.is_shadow_catcher = True
    scene.collection.objects.link(ground_obj)
    for obj in props:
        if obj.type in {"MESH", "CURVE"}:
            obj.visible_camera = False
    bs.render_to(scene, OUT_SHADOW)
    normalise_shadow(OUT_SHADOW)

    for obj in props:
        if obj.type in {"MESH", "CURVE"}:
            obj.visible_camera = True

    # Close-up of the laptop for review, shadows included (still on the
    # catcher), at much higher detail than the game uses.
    bs.frame_camera(scene, (PLATFORM_AT.x, PLATFORM_AT.y), PLATFORM_M + 0.4, bs.PX_PER_M * CLOSEUP_SCALE)
    bs.render_to(scene, OUT_CLOSEUP)

    # The dish on its own: nothing else in the picture, sun straight overhead.
    for obj in props:
        if obj.type in {"MESH", "CURVE"}:
            obj.hide_render = True
    ground_obj.hide_render = True
    for obj in dish:
        obj.hide_render = False
    sun = bpy.data.objects["Sun"]
    sun_rotation = tuple(sun.rotation_euler)
    sun.rotation_euler = (0, 0, 0)
    bs.frame_camera(scene, (DISH_AT.x, DISH_AT.y), DISH_FRAME_M, bs.PX_PER_M * RENDER_SCALE)
    bs.render_to(scene, OUT_DISH)

    # Leave the saved file showing the whole station as it stands.
    sun.rotation_euler = sun_rotation
    for obj in props:
        obj.hide_render = False
    ground_obj.hide_render = False
    bs.frame_camera(scene, (0, 0), FRAME_M, bs.PX_PER_M * RENDER_SCALE)
    bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND)


main()
