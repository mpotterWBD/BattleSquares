"""Render a square toppling over when it dies, as sprite sheets.

Run headless:
    blender --background --factory-startup --python fall_square.py
    blender --background --factory-startup --python fall_square.py -- blue
(with "-- blue", or "-- red" / "-- dummy" / "-- shadow", only those sheets)

The block (character_square.py's, red, dressed as the crash test dummy by
dummy_square.py, or blue for the enemy by enemy_square.py) tips over its bottom edge, from standing (0 degrees) to
lying on a face (90 degrees), toward each of DIRS directions all the way
round. The fixed top-left sun lights a block tipping north differently from
one tipping east, so every direction is rendered rather than rotated in the
game. The block is turned so a face points the way it falls: falling
forward it lands on its front, falling backward on its back (the game picks
the direction, scripts/soldier.gd).

Sheets: one row per direction (row k = falling toward k * 360/DIRS degrees,
clockwise on screen from east, Godot's angle), one column per tip step
(column j = j * 90/(TIPS - 1) degrees over). Every frame is centred on where
the block stood, so the sprite stays put while the block topples away from
the centre (it ends one block-width over).

  red_square_fall_sheet.png     the red block
  dummy_square_fall_sheet.png   the crash test dummy
  blue_square_fall_sheet.png    the enemy's blue block
  square_fall_shadow_sheet.png  the shadow, shared (same shape), normalised
                                like character_square.py's (open-ground
                                shadow = alpha 1)
"""

import math
import os
import sys
import tempfile

import bpy
import numpy as np
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bs_common as bs  # noqa: E402
import character_square as sq  # noqa: E402
import dummy_square as dummy  # noqa: E402
import enemy_square as enemy  # noqa: E402

ROOT = bs.ROOT
CHAR_DIR = os.path.join(ROOT, "assets", "characters")
OUT_RED = os.path.join(CHAR_DIR, "red_square_fall_sheet.png")
OUT_DUMMY = os.path.join(CHAR_DIR, "dummy_square_fall_sheet.png")
OUT_BLUE = os.path.join(CHAR_DIR, "blue_square_fall_sheet.png")
OUT_SHADOW = os.path.join(CHAR_DIR, "square_fall_shadow_sheet.png")

DIRS = 30              # fall directions, 12 degrees apart; soldier.gd FALL_DIRS must match
TIPS = 12              # steps from standing to lying flat; soldier.gd FALL_FRAMES must match
# The fallen block reaches 0.6 m out and 0.2 m to the side (corner ~0.63 m
# from the centre); its shadow reaches ~0.4 m further to the bottom-right.
BODY_FRAME_M = 1.5      # 128 px: an even size keeps the centred sprite on whole pixels
SHADOW_FRAME_M = 2.25   # 192 px
SAMPLES = 64
TMP_PNG = os.path.join(tempfile.gettempdir(), "bs_fall_frame.png")


def place(block, dir_index, tip_index):
    """Turn the block to face fall direction `dir_index` and tip it that way
    by tip step `tip_index`, pivoting on its bottom edge on that side."""
    angle = 2 * math.pi * dir_index / DIRS        # Godot angle: clockwise on screen
    tip = math.radians(90 * tip_index / (TIPS - 1))
    toward = Vector((math.cos(angle), -math.sin(angle), 0))   # screen y is down, Blender y up
    pivot = toward * (sq.SIZE_M / 2)
    axis = Vector((-toward.y, toward.x, 0))       # tipping about this lifts the top toward `toward`
    block.matrix_world = (Matrix.Translation(pivot) @ Matrix.Rotation(tip, 4, axis)
                          @ Matrix.Translation(-pivot) @ Matrix.Rotation(-angle, 4, "Z"))


def render_falls(scene, block):
    """Every direction and tip step; returns rows (one per direction) of
    frames, each frame an (h, w, 4) array with rows bottom-up."""
    rows = []
    for k in range(DIRS):
        row = []
        for j in range(TIPS):
            place(block, k, j)
            scene.render.filepath = TMP_PNG
            bpy.ops.render.render(write_still=True)
            img = bpy.data.images.load(TMP_PNG)
            w, h = img.size
            px = np.empty(w * h * 4, dtype=np.float32)
            img.pixels.foreach_get(px)
            row.append(px.reshape(h, w, 4))
            bpy.data.images.remove(img)
        rows.append(row)
        print(f"  direction {k + 1}/{DIRS}")
    block.matrix_world = Matrix.Identity(4)
    return rows


def even_out_shadow(rows):
    """As character_square.even_out_shadow: cap the darkness at the open
    cast-shadow level (sampled beside the standing block) and scale that to
    alpha 1, so the game can fade all of a square's shadows together."""
    sample_m = sq.SIZE_M / 2 + 0.12
    col = round((SHADOW_FRAME_M / 2 + sample_m) * bs.PX_PER_M)
    row = round((SHADOW_FRAME_M / 2 - sample_m) * bs.PX_PER_M)
    standing = rows[0][0]
    cast_alpha = float(standing[row - 2:row + 3, col - 2:col + 3, 3].mean())
    for frames in rows:
        for f in frames:
            f[:, :, 3] = np.minimum(f[:, :, 3], cast_alpha) / cast_alpha
    print(f"Shadow normalised: open-ground shadow alpha {cast_alpha:.2f} -> 1.0")


def save_grid(rows, path):
    """Directions top to bottom, tip steps left to right. Blender images
    run bottom-up, so the first direction's row goes in last."""
    sheet = np.concatenate([np.concatenate(r, axis=1) for r in reversed(rows)], axis=0)
    h, w = sheet.shape[:2]
    img = bpy.data.images.new(os.path.basename(path), w, h, alpha=True)
    img.pixels.foreach_set(sheet.ravel())
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()
    print(f"Saved {path} ({DIRS} x {TIPS} frames, {w}x{h})")


def main():
    # Which sheets to render: everything, or just those named after "--".
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    wanted = set(args) or {"red", "dummy", "blue", "shadow"}
    scene = bs.new_scene(center=(0, 0), frame_m=BODY_FRAME_M,
                         transparent=True, samples=SAMPLES)
    block = sq.build_block()
    ground = sq.build_shadow_catcher()
    ground.scale = (SHADOW_FRAME_M / sq.SHADOW_FRAME_M,) * 3   # cover the bigger frame

    # The bodies: the block alone, no ground.
    ground.hide_render = True
    if "red" in wanted:
        save_grid(render_falls(scene, block), OUT_RED)
    if "dummy" in wanted:
        dummy.dress_as_dummy(block)
        save_grid(render_falls(scene, block), OUT_DUMMY)
    if "blue" in wanted:
        enemy.dress_as_enemy(block)
        save_grid(render_falls(scene, block), OUT_BLUE)
    if "shadow" not in wanted:
        return

    # The shadow alone: the block casts it but isn't drawn.
    ground.hide_render = False
    block.visible_camera = False
    bs.frame_camera(scene, (0, 0), SHADOW_FRAME_M)
    shadows = render_falls(scene, block)
    even_out_shadow(shadows)
    save_grid(shadows, OUT_SHADOW)


if __name__ == "__main__":
    main()
