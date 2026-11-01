"""Generate the cargo parachute for Battle Squares' supply drops, seen from
straight above.

Run headless:
    blender --background --python parachute.py

A round cargo canopy, DIAMETER_M across: GORES fabric panels alternating two
shades of olive drab, sewn seams (radial tapes) between them, a darker hem
round the skirt, and a vent at the apex. Inflated, it's a shallow dome, the
skirt a little scalloped between the lines.

Output: assets/vehicles/parachute.png, top-down, rendered at RENDER_SCALE x
the game's pixel density, lit by the standard sun, transparent; the game
(scripts/air_drop.gd) draws its shadow (the same shape, darkened) and its
opening and collapsing. Also an angled review, the canopy over its rigging
lines down to an ammo crate: assets/previews/parachute_preview.png, and the
.blend.
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
OUT = os.path.join(ROOT, "assets", "vehicles", "parachute.png")
OUT_PREVIEW = os.path.join(ROOT, "assets", "previews", "parachute_preview.png")
OUT_BLEND = os.path.join(ROOT, "blender", "source", "parachute.blend")

RENDER_SCALE = 2                   # shown at 0.5 in the game
DIAMETER_M = 5.0
DOME_H = 1.3                       # apex above the skirt
VENT_M = 0.35                      # the apex vent's diameter
GORES = 16
FRAME_M = 5.5                      # 938 rendered px
SAMPLES = 96
LINES_M = 4.0                      # skirt down to the load (for the review)

OLIVE_A = srgb(0.33, 0.35, 0.22)
OLIVE_B = srgb(0.28, 0.30, 0.19)
TAPE = srgb(0.20, 0.21, 0.14)


def cloth_material(name, rgb):
    mat = bpy.data.materials.new(name)
    nt = bs.node_tree_of(mat)
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (*rgb, 1)
    bsdf.inputs["Roughness"].default_value = 0.9
    if "Sheen Weight" in bsdf.inputs:
        bsdf.inputs["Sheen Weight"].default_value = 0.3
    return mat


def dome_z(r):
    """Height of the canopy at radius r (0 at the apex .. R at the skirt)."""
    R = DIAMETER_M / 2
    return DOME_H * (1 - (r / R) ** 2) ** 0.8


def build_canopy():
    """The dome, as GORES panels (two materials alternating), seams, hem."""
    mats = [cloth_material("OliveA", OLIVE_A), cloth_material("OliveB", OLIVE_B)]
    tape = cloth_material("Tape", TAPE)
    R = DIAMETER_M / 2
    rings = 24
    bm = bmesh.new()
    seg = 6   # facets per gore
    cols = GORES * seg
    grid = []
    for i in range(rings + 1):
        r = VENT_M / 2 + (R - VENT_M / 2) * i / rings
        row = []
        for j in range(cols):
            a = 2 * math.pi * j / cols
            # Scalloped skirt: the cloth bellies out between lines (at gore middles).
            belly = 1 + 0.035 * math.sin(math.pi * (j % seg) / seg) * (i / rings) ** 3
            row.append(bm.verts.new((r * belly * math.cos(a), r * belly * math.sin(a), dome_z(r))))
        grid.append(row)
    for i in range(rings):
        for j in range(cols):
            f = bm.faces.new((grid[i][j], grid[i][(j + 1) % cols], grid[i + 1][(j + 1) % cols], grid[i + 1][j]))
            f.material_index = (j // seg) % 2
            f.smooth = True
    me = bpy.data.meshes.new("Canopy")
    bm.to_mesh(me)
    bm.free()
    for m in mats:
        me.materials.append(m)
    canopy = bpy.data.objects.new("Canopy", me)
    bpy.context.scene.collection.objects.link(canopy)
    solid = canopy.modifiers.new("Thickness", "SOLIDIFY")
    solid.thickness = 0.01
    # Radial seam tapes along each gore edge, and the hem.
    for g in range(GORES):
        a = 2 * math.pi * g / GORES
        pts = []
        for i in range(rings + 1):
            r = VENT_M / 2 + (R - VENT_M / 2) * i / rings
            pts.append(Vector((r * math.cos(a), r * math.sin(a), dome_z(r) + 0.012)))
        _tube(f"Seam{g}", pts, 0.012, tape)
    hem = [Vector((R * 1.002 * math.cos(2 * math.pi * k / 96), R * 1.002 * math.sin(2 * math.pi * k / 96), dome_z(R) + 0.01))
           for k in range(97)]
    _tube("Hem", hem, 0.03, tape)
    vent = [Vector((VENT_M / 2 * math.cos(2 * math.pi * k / 48), VENT_M / 2 * math.sin(2 * math.pi * k / 48),
                    dome_z(VENT_M / 2) + 0.015)) for k in range(49)]
    _tube("Vent", vent, 0.025, tape)
    return canopy


def _tube(name, points, radius, mat):
    curve = bpy.data.curves.new(name, "CURVE")
    curve.dimensions = "3D"
    curve.bevel_depth = radius
    curve.bevel_resolution = 2
    spline = curve.splines.new("POLY")
    spline.points.add(len(points) - 1)
    for p, co in zip(spline.points, points):
        p.co = (co.x, co.y, co.z, 1)
    curve.materials.append(mat)
    obj = bpy.data.objects.new(name, curve)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def main():
    scene = bs.new_scene(center=(0.0, 0.0), frame_m=FRAME_M, transparent=True, samples=SAMPLES,
                         px_per_m=bs.PX_PER_M * RENDER_SCALE)
    build_canopy()
    bs.render_to(scene, OUT)
    # The review: lifted on its lines over an ammo crate.
    for obj in bpy.data.objects:
        if obj.type in ("MESH", "CURVE"):
            obj.location.z += LINES_M
    line_mat = cloth_material("Lines", srgb(0.75, 0.73, 0.62))
    R = DIAMETER_M / 2
    for g in range(GORES):
        a = 2 * math.pi * g / GORES
        top = Vector((R * math.cos(a), R * math.sin(a), LINES_M + dome_z(R)))
        bottom = Vector((0.0, 0.0, 0.85))
        _tube(f"Line{g}", [top, bottom], 0.006, line_mat)
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import crates
    crates.build_pallet(crates.wood_material())
    footprint, top = crates.build_ammo_load(seed=7)
    crates.build_straps(footprint, top)
    os.makedirs(os.path.dirname(OUT_BLEND), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND)
    cam = bpy.data.objects.new("Review", bpy.data.cameras.new("Review"))
    scene.collection.objects.link(cam)
    cam.data.lens = 35
    target = Vector((0, 0, 2.8))
    cam.location = Vector((7.5, -9.5, 5.5))
    cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam
    scene.render.resolution_x, scene.render.resolution_y = 800, 900
    scene.render.film_transparent = False
    bg = next(n for n in scene.world.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs["Color"].default_value = (0.75, 0.85, 0.95, 1)
    bs.render_to(scene, OUT_PREVIEW)
    print(f"parachute: {DIAMETER_M} m across, rendered at {RENDER_SCALE}x (air_drop.gd)")


if __name__ == "__main__":
    main()
