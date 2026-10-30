"""Render a crash test dummy square: the player's block in crash-test colours.

Run headless:
    blender --background --factory-startup --python dummy_square.py

Same block, size, bevel, sun and frame layout as the player's red square
(character_square.py, which this reuses), so it drops into soldier.tscn's
Body sprite as-is: FRAMES angles across 90 degrees, frame k turned
k * 90/FRAMES degrees clockwise. The shadow is the same shape too, so the
game reuses red_square_shadow_sheet.png and only the body sheet is made here.

The colours are crash-test yellow with a black tracking target on top: a
ring with a cross through it. The classic half-black quadrant target isn't
used because the sheet only covers a quarter turn (a square looks the same
every 90 degrees); a quadrant target swaps black and yellow every quarter
turn, so it would flip colours each time the frames wrap round. Ring and
cross look the same every quarter turn.
"""

import os
import sys

import bpy
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bs_common as bs  # noqa: E402
import character_square as sq  # noqa: E402

ROOT = bs.ROOT
OUT_BODY = os.path.join(ROOT, "assets", "characters", "dummy_square_sheet.png")
OUT_BLEND = os.path.join(ROOT, "blender", "source", "dummy_square.blend")

YELLOW = (0.98, 0.80, 0.05)   # sRGB, crash-test yellow
BLACK = (0.03, 0.03, 0.03)
# The target on the top face, as fractions of the block's width.
TARGET_RADIUS = 0.30          # to the middle of the ring
RING_WIDTH = 0.07
CROSS_WIDTH = 0.06
DECAL_PX = 1024               # the top-face pattern image


def target_image():
    """The top-face pattern: yellow with the black ring-and-cross target,
    anti-aliased, as an sRGB image packed into the .blend."""
    half_px = 0.5 / DECAL_PX
    coords = (np.arange(DECAL_PX) + 0.5) / DECAL_PX - 0.5
    x, y = np.meshgrid(coords, coords)
    r = np.hypot(x, y)
    soft = 2 * half_px   # edge softening, about one pixel each way

    def inside(distance):   # 1 inside a shape (distance < 0), 0 outside
        return np.clip(0.5 - distance / soft, 0.0, 1.0)

    ring = inside(np.abs(r - TARGET_RADIUS) - RING_WIDTH / 2)
    bars = np.maximum(inside(np.abs(x) - CROSS_WIDTH / 2), inside(np.abs(y) - CROSS_WIDTH / 2))
    cross = bars * inside(r - TARGET_RADIUS)
    black = np.maximum(ring, cross)[..., None]

    rgb = np.array(YELLOW) * (1 - black) + np.array(BLACK) * black
    rgba = np.concatenate([rgb, np.ones_like(black)], axis=2).astype(np.float32)
    img = bpy.data.images.new("DummyTarget", DECAL_PX, DECAL_PX, alpha=False)
    img.colorspace_settings.name = "sRGB"
    img.pixels.foreach_set(rgba.ravel())
    img.pack()
    return img


def dress_as_dummy(block):
    """Swap the red plastic for the yellow-and-black pattern, projected
    straight down onto the block so the target sits on the top face (the
    sides and bevels pick up the plain yellow round it)."""
    mat = bpy.data.materials.new("DummyPlastic")
    nt = bs.node_tree_of(mat)
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Roughness"].default_value = 0.38
    if "Coat Weight" in bsdf.inputs:
        bsdf.inputs["Coat Weight"].default_value = 0.25

    coords = nt.nodes.new("ShaderNodeTexCoord")
    mapping = nt.nodes.new("ShaderNodeMapping")
    mapping.inputs["Scale"].default_value = (1 / sq.SIZE_M, 1 / sq.SIZE_M, 1)
    mapping.inputs["Location"].default_value = (0.5, 0.5, 0)
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = target_image()
    tex.extension = "EXTEND"
    nt.links.new(coords.outputs["Object"], mapping.inputs["Vector"])
    nt.links.new(mapping.outputs["Vector"], tex.inputs["Vector"])
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])

    block.data.materials.clear()
    block.data.materials.append(mat)
    block.name = block.data.name = "DummySquare"


def main():
    for path in (OUT_BODY, OUT_BLEND):
        os.makedirs(os.path.dirname(path), exist_ok=True)

    scene = bs.new_scene(center=(0, 0), frame_m=sq.BODY_FRAME_M,
                         transparent=True, samples=sq.SAMPLES)
    block = sq.build_block()
    dress_as_dummy(block)
    sq.save_sheet(sq.render_turns(scene, block), OUT_BODY)
    bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND)


if __name__ == "__main__":   # fall_square.py imports this module for dress_as_dummy()
    main()
