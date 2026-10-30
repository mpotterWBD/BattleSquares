"""Render the player's rifle as a top-down sprite, plus the pieces for reloading.

Run headless:
    blender --background --python rifle.py

A compact rifle pointing right (+x) from its pivot at the centre of the
image (the square's centre). Parts: receiver, red-dot sight, handguard,
front sight post, barrel, muzzle brake and a magazine.

Seen straight from above, a magazine hanging under the gun would be hidden,
so the whole rifle is rolled CANT_DEG onto its side and the magazine pokes
out to the gun's right. Anything closer than ~0.2 m to the pivot is under
the square's body, so the sight and magazine sit just beyond that.

The game rotates the rifle freely to follow the mouse, so it is lit from
straight overhead: that looks the same at every angle. Its shadow isn't
rendered; the game draws it as the same shape, darkened and offset away from
the sun (scripts/rifle.gd).

It renders at RENDER_SCALE x the game's pixel density so the small parts stay
crisp when zoomed in; Godot shrinks it back (with mipmaps).

For the reload (scripts/rifle.gd) it also renders, the same way:
  rifle_no_mag.png  the rifle with its magazine out (same frame as rifle.png)
  magazine.png      the magazine alone, seen from above as it's carried and
                    as it lies on the ground: long axis along +x, centred,
                    in a MAG_FRAME_M square
"""

import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bs_common as bs  # noqa: E402

ROOT = bs.ROOT
OUT_RIFLE = os.path.join(ROOT, "assets", "characters", "rifle.png")
OUT_NO_MAG = os.path.join(ROOT, "assets", "characters", "rifle_no_mag.png")
OUT_MAG = os.path.join(ROOT, "assets", "characters", "magazine.png")
OUT_BLEND = os.path.join(ROOT, "blender", "source", "rifle.blend")

LENGTH_M = 0.48      # pivot (square's centre) to muzzle; scripts/rifle.gd must match
CANT_DEG = 30        # roll onto its side so the magazine shows from above
RENDER_SCALE = 4     # scripts/rifle.gd must match
FRAME_M = 1.125      # centred on the pivot -> 384 px at 4x density
MAG_FRAME_M = 0.1875 # the lone magazine's image -> 64 px at 4x density
MAG_SIZE = (0.036, 0.024, 0.13)   # across the gun, side to side, length: the box below
SAMPLES = 128


def material(name, rgb, metallic=0.0, roughness=0.5):
    mat = bpy.data.materials.new(name)
    nt = bs.node_tree_of(mat)
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (*bs.srgb(*rgb), 1.0)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    return mat


def add_part(name, bm, mat, parent, bevel=0.0):
    if bevel:
        bmesh.ops.bevel(bm, geom=list(bm.edges), offset=bevel, segments=2,
                        profile=0.5, affect="EDGES")
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    me.shade_smooth()
    me.set_sharp_from_angle(angle=math.radians(35))
    me.materials.append(mat)
    obj = bpy.data.objects.new(name, me)
    obj.parent = parent
    bpy.context.scene.collection.objects.link(obj)
    return obj


def box(x0, x1, width, z0, z1):
    """Box spanning x0..x1 along the gun, `width` across, z0..z1 up."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, verts=bm.verts, vec=(x1 - x0, width, z1 - z0))
    bmesh.ops.translate(bm, verts=bm.verts, vec=((x0 + x1) / 2, 0, (z0 + z1) / 2))
    return bm


def tube(x0, x1, radius, z=0.0):
    """Cylinder along the gun from x0 to x1, centred at height z."""
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=20, radius1=radius,
                          radius2=radius, depth=x1 - x0)
    bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0),
                     matrix=Matrix.Rotation(math.pi / 2, 3, "Y"))
    bmesh.ops.translate(bm, verts=bm.verts, vec=((x0 + x1) / 2, 0, z))
    return bm


def build_rifle():
    # Everything hangs off one empty on the bore line, so rolling the empty
    # cants the whole gun about its own axis.
    root = bpy.data.objects.new("RifleRoot", None)
    root.rotation_euler = (-math.radians(CANT_DEG), 0, 0)   # magazine swings to the gun's right
    bpy.context.scene.collection.objects.link(root)

    gunmetal = material("Gunmetal", (0.33, 0.34, 0.36), metallic=0.6, roughness=0.38)
    polymer = material("Polymer", (0.15, 0.15, 0.14), roughness=0.7)
    steel = material("DarkSteel", (0.10, 0.10, 0.11), metallic=0.8, roughness=0.3)
    optic = material("Optic", (0.05, 0.05, 0.06), metallic=0.3, roughness=0.25)
    lens = material("Lens", (0.85, 0.15, 0.10), roughness=0.1)

    add_part("Receiver", box(0.04, 0.345, 0.055, -0.03, 0.03), gunmetal, root, bevel=0.006)
    add_part("Handguard", box(0.345, 0.425, 0.048, -0.024, 0.024), polymer, root, bevel=0.006)
    add_part("Barrel", tube(0.425, 0.47, 0.011), steel, root)
    add_part("MuzzleBrake", tube(0.465, LENGTH_M, 0.016), steel, root)

    # Red-dot sight on top of the receiver: a mount, a short tube, a red lens.
    add_part("SightMount", box(0.29, 0.335, 0.02, 0.03, 0.04), optic, root)
    add_part("SightTube", tube(0.288, 0.338, 0.016, z=0.055), optic, root)
    add_part("SightLens", tube(0.336, 0.340, 0.012, z=0.055), lens, root)
    # Front sight post at the end of the handguard.
    add_part("FrontPost", box(0.405, 0.415, 0.008, 0.024, 0.05), steel, root)

    # Magazine, raked slightly forward like a real one.
    mag = box(-0.018, 0.018, 0.024, -0.13, 0.0)
    bmesh.ops.rotate(mag, verts=mag.verts, cent=(0, 0, 0),
                     matrix=Matrix.Rotation(math.radians(-12), 3, "Y"))
    bmesh.ops.translate(mag, verts=mag.verts, vec=(0.315, 0, -0.025))
    add_part("Magazine", mag, polymer, root, bevel=0.004)
    return root


def build_lone_magazine():
    """The magazine on its own, lying on its side: its length along +x, its
    wide face up, centred on the origin."""
    polymer = material("PolymerMag", (0.15, 0.15, 0.14), roughness=0.7)
    w, d, length = MAG_SIZE
    add_part("LoneMagazine", box(-length / 2, length / 2, w, -d / 2, d / 2), polymer, None, bevel=0.004)


def main():
    for path in (OUT_RIFLE, OUT_BLEND):
        os.makedirs(os.path.dirname(path), exist_ok=True)
    scene = bs.new_scene(center=(0, 0), frame_m=FRAME_M, transparent=True,
                         samples=SAMPLES, px_per_m=bs.PX_PER_M * RENDER_SCALE)
    # Straight-overhead sun: shading that looks right at any rotation.
    bpy.data.objects["Sun"].rotation_euler = (0, 0, 0)
    build_rifle()
    bs.render_to(scene, OUT_RIFLE)
    bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND)
    # Magazine out.
    bpy.data.objects["Magazine"].hide_render = True
    bs.render_to(scene, OUT_NO_MAG)
    # The magazine alone, in its own small frame.
    for obj in list(bpy.data.objects):
        if obj.type == "MESH" or obj.name == "RifleRoot":
            bpy.data.objects.remove(obj)
    build_lone_magazine()
    px = round(MAG_FRAME_M * bs.PX_PER_M * RENDER_SCALE)
    scene.render.resolution_x = px
    scene.render.resolution_y = px
    cam = scene.camera
    cam.data.ortho_scale = MAG_FRAME_M
    bs.render_to(scene, OUT_MAG)


main()
