"""Render the enemy's blue square: the player's block in blue plastic.

Run headless:
    blender --background --factory-startup --python enemy_square.py

Same block, size, bevel, sun and frame layout as the player's red square
(character_square.py, which this reuses), so it drops into soldier.tscn's
Body sprite as-is: FRAMES angles across 90 degrees, frame k turned
k * 90/FRAMES degrees clockwise. The shadow is the same shape too, so the
game reuses red_square_shadow_sheet.png and only the body sheet is made here.
fall_square.py imports dress_as_enemy() for the blue toppling sheet.
"""

import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bs_common as bs  # noqa: E402
import character_square as sq  # noqa: E402

ROOT = bs.ROOT
OUT_BODY = os.path.join(ROOT, "assets", "characters", "blue_square_sheet.png")
OUT_BLEND = os.path.join(ROOT, "blender", "source", "enemy_square.blend")

# A strong blue that reads against the grass and next to the red, about as
# saturated and as dark as the red.
BLUE = bs.srgb(0.08, 0.32, 0.88)


def dress_as_enemy(block):
    """Swap the red plastic for the same plastic in blue."""
    mat = bpy.data.materials.new("BluePlastic")
    nt = bs.node_tree_of(mat)
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (*BLUE, 1.0)
    bsdf.inputs["Roughness"].default_value = 0.38
    if "Coat Weight" in bsdf.inputs:
        bsdf.inputs["Coat Weight"].default_value = 0.25
    block.data.materials.clear()
    block.data.materials.append(mat)
    block.name = block.data.name = "BlueSquare"


def main():
    for path in (OUT_BODY, OUT_BLEND):
        os.makedirs(os.path.dirname(path), exist_ok=True)

    scene = bs.new_scene(center=(0, 0), frame_m=sq.BODY_FRAME_M,
                         transparent=True, samples=sq.SAMPLES)
    block = sq.build_block()
    dress_as_enemy(block)
    sq.save_sheet(sq.render_turns(scene, block), OUT_BODY)
    bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND)


if __name__ == "__main__":   # fall_square.py imports this module for dress_as_enemy()
    main()
