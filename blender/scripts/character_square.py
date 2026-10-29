"""Render the player's red square and its shadow as top-down sprite sheets.

Run headless:
    blender --background --python character_square.py

The square is a bevelled red block, 0.4 m on each side. It renders under the
shared sun (see bs_common.py) at FRAMES angles. The lighting stays fixed
while the block turns, so the game can't just rotate one image: the
highlights and the shadow's shape would turn with it. A square repeats every
90 degrees, so FRAMES angles across 90 degrees cover every direction.

Two sheets, one frame per angle, left to right:
  1. The block itself, on a transparent background.
  2. Only the shadow it casts on flat ground (a shadow catcher).
They're separate so the game can move and fade the shadow on its own, for
example when the square hops off the ground.

Frame k shows the block turned k * 90/FRAMES degrees clockwise on screen,
which is Godot's positive rotation direction. Every frame is centred on the
middle of the block, so the sheets line up when both Sprite2Ds sit at the
same position.
"""

import math
import os
import sys
import tempfile

import bmesh
import bpy
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bs_common as bs  # noqa: E402

ROOT = r"F:\Projects\BattleSquares"
OUT_BODY = os.path.join(ROOT, "assets", "characters", "red_square_sheet.png")
OUT_SHADOW = os.path.join(ROOT, "assets", "characters", "red_square_shadow_sheet.png")
OUT_BLEND = os.path.join(ROOT, "blender", "source", "character_square.blend")

SIZE_M = 0.40          # width, depth and height of the block
BEVEL_M = 0.035        # rounded edge radius
BODY_FRAME_M = 0.75    # each body frame covers this much ground
SHADOW_FRAME_M = 1.5   # the shadow reaches ~0.34 m to the bottom-right
FRAMES = 30            # angles across 90 degrees (3 degrees apart); scripts/player.gd must match
SAMPLES = 128

RED = bs.srgb(0.85, 0.09, 0.07)
TMP_PNG = os.path.join(tempfile.gettempdir(), "bs_character_frame.png")


def build_block():
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=SIZE_M)
    bmesh.ops.translate(bm, verts=bm.verts, vec=(0, 0, SIZE_M / 2))
    bmesh.ops.bevel(bm, geom=list(bm.edges), offset=BEVEL_M, segments=6,
                    profile=0.5, affect="EDGES")
    me = bpy.data.meshes.new("RedSquare")
    bm.to_mesh(me)
    bm.free()
    me.shade_smooth()
    me.set_sharp_from_angle(angle=math.radians(30))

    mat = bpy.data.materials.new("RedPlastic")
    nt = bs.node_tree_of(mat)
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (*RED, 1.0)
    bsdf.inputs["Roughness"].default_value = 0.38
    if "Coat Weight" in bsdf.inputs:
        bsdf.inputs["Coat Weight"].default_value = 0.25
    me.materials.append(mat)

    obj = bpy.data.objects.new("RedSquare", me)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def build_shadow_catcher():
    me = bpy.data.meshes.new("Ground")
    s = SHADOW_FRAME_M
    me.from_pydata([(-s, -s, 0), (s, -s, 0), (s, s, 0), (-s, s, 0)], [], [(0, 1, 2, 3)])
    obj = bpy.data.objects.new("Ground", me)
    obj.is_shadow_catcher = True
    bpy.context.scene.collection.objects.link(obj)
    return obj


def render_turns(scene, block):
    """Render the block at every angle; returns a list of (h, w, 4) arrays."""
    frames = []
    for k in range(FRAMES):
        # Blender's +Z rotation looks anticlockwise from above; negate it so
        # the frames turn clockwise on screen, like Godot's rotation.
        block.rotation_euler.z = -math.radians(k * 90 / FRAMES)
        scene.render.filepath = TMP_PNG
        bpy.ops.render.render(write_still=True)
        img = bpy.data.images.load(TMP_PNG)
        w, h = img.size
        px = np.empty(w * h * 4, dtype=np.float32)
        img.pixels.foreach_get(px)
        frames.append(px.reshape(h, w, 4))
        bpy.data.images.remove(img)
    block.rotation_euler.z = 0
    return frames


def even_out_shadow(frames):
    """Right under the block the catcher is blocked from the sky as well as
    the sun, so it renders solid black. That patch shows when the shadow
    slides out from under a hopping square, so cap the darkness at the
    level of the open cast shadow, sampled just past the block's corner in
    the unturned frame.

    Then scale it so that level is fully opaque. The game draws all of a
    character's shadows (body, rifle, ...) fully dark in one group and fades
    the group to SHADOW_ALPHA (scripts/player.gd), so overlapping shadows
    don't darken each other. Prints the level to use for SHADOW_ALPHA."""
    sample_m = SIZE_M / 2 + 0.12
    col = round((SHADOW_FRAME_M / 2 + sample_m) * bs.PX_PER_M)
    row = round((SHADOW_FRAME_M / 2 - sample_m) * bs.PX_PER_M)   # rows run bottom-up
    cast_alpha = float(frames[0][row - 2:row + 3, col - 2:col + 3, 3].mean())
    for f in frames:
        f[:, :, 3] = np.minimum(f[:, :, 3], cast_alpha) / cast_alpha
    print(f"Shadow normalised: open-ground shadow alpha {cast_alpha:.2f} -> 1.0 "
          f"(SHADOW_ALPHA in player.gd)")


def save_sheet(frames, path):
    sheet = np.concatenate(frames, axis=1)
    h, w = sheet.shape[:2]
    img = bpy.data.images.new(os.path.basename(path), w, h, alpha=True)
    img.pixels.foreach_set(sheet.ravel())
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()
    print(f"Saved {path} ({len(frames)} frames, {w}x{h})")


def main():
    for path in (OUT_BODY, OUT_SHADOW, OUT_BLEND):
        os.makedirs(os.path.dirname(path), exist_ok=True)

    scene = bs.new_scene(center=(0, 0), frame_m=BODY_FRAME_M,
                         transparent=True, samples=SAMPLES)
    block = build_block()
    ground = build_shadow_catcher()

    # Pass 1: the block alone. Hide the ground so it doesn't add a shadow.
    ground.hide_render = True
    save_sheet(render_turns(scene, block), OUT_BODY)

    # Pass 2: the shadow alone. The block still casts it but isn't drawn.
    ground.hide_render = False
    block.visible_camera = False
    bs.frame_camera(scene, (0, 0), SHADOW_FRAME_M)
    shadows = render_turns(scene, block)
    even_out_shadow(shadows)
    save_sheet(shadows, OUT_SHADOW)

    block.visible_camera = True
    bs.frame_camera(scene, (0, 0), BODY_FRAME_M)
    bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND)


main()
