"""Shared render setup for every Battle Squares asset, so all the art matches.

One world unit is 1 metre. Every asset renders straight down with an
orthographic camera at the same pixel density and under the same sun, so
things keep the right size relative to each other and their shading agrees.
"""

import math
import os

import bpy
import numpy as np

# The Godot project folder (this file is in blender/scripts/), which every
# script saves into. Worked out from here so it keeps working if the project
# moves (it was once hard-coded to F:\Projects\BattleSquares).
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# Pixels per metre in every render: this sets the game's zoom level. Godot's
# scripts/world.gd holds the same number. History: 1024/1 (first close-up),
# 1024/3 (3x farther), 1024/12 now (another 4x), so a grass tile covers 12 m.
PX_PER_M = 1024 / 12

# Sun: tilted 40 degrees from straight overhead, shining from the top-left of
# the screen so shadows fall to the bottom-right. The game's shadow code
# (scripts/player.gd) assumes these same values.
SUN_TILT_DEG = 40
SUN_HEADING_DEG = -135
SUN_ENERGY = 3.0
SUN_SOFTNESS_DEG = 8
SKY_COLOR = (0.55, 0.70, 0.95, 1.0)
SKY_STRENGTH = 0.45


def srgb(*c):
    """sRGB 0-1 colour -> linear, for vertex and material colours."""
    return np.array(c, dtype=np.float64) ** 2.2


def node_tree_of(idblock):
    if idblock.node_tree is None:
        idblock.use_nodes = True
    return idblock.node_tree


def new_scene(center, frame_m, transparent=False, samples=96, px_per_m=PX_PER_M):
    """Empty scene with the standard sky, sun and top-down camera, framing a
    frame_m x frame_m square of ground centred on `center` (x, y). Pass a
    higher px_per_m to render extra detail that the game shrinks back down."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene

    world = bpy.data.worlds.new("Sky")
    scene.world = world
    bg = next(n for n in node_tree_of(world).nodes if n.type == "BACKGROUND")
    bg.inputs["Color"].default_value = SKY_COLOR
    bg.inputs["Strength"].default_value = SKY_STRENGTH

    sun = bpy.data.lights.new("Sun", "SUN")
    sun.energy = SUN_ENERGY
    sun.angle = math.radians(SUN_SOFTNESS_DEG)
    sun_obj = bpy.data.objects.new("Sun", sun)
    sun_obj.rotation_euler = (math.radians(SUN_TILT_DEG), 0, math.radians(SUN_HEADING_DEG))
    scene.collection.objects.link(sun_obj)

    cam = bpy.data.cameras.new("TopDown")
    cam.type = "ORTHO"
    cam_obj = bpy.data.objects.new("TopDown", cam)
    scene.collection.objects.link(cam_obj)
    scene.camera = cam_obj
    frame_camera(scene, center, frame_m, px_per_m)

    r = scene.render
    r.engine = "CYCLES"
    r.resolution_percentage = 100
    r.film_transparent = transparent
    r.image_settings.file_format = "PNG"
    r.image_settings.color_mode = "RGBA" if transparent else "RGB"
    scene.view_settings.view_transform = "Standard"
    scene.cycles.samples = samples
    scene.cycles.use_denoising = True
    print("Render device:", use_gpu_if_available(scene))
    return scene


def frame_camera(scene, center, frame_m, px_per_m=PX_PER_M):
    """Point the top-down camera at `center`, covering frame_m metres square
    at px_per_m pixels per metre (the standard density by default)."""
    scene.camera.data.ortho_scale = frame_m
    scene.camera.location = (center[0], center[1], 10.0)
    res = round(frame_m * px_per_m)
    scene.render.resolution_x = scene.render.resolution_y = res
    return res


def render_to(scene, path):
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    print("Saved", path)


def use_gpu_if_available(scene):
    try:
        prefs = bpy.context.preferences.addons["cycles"].preferences
        for backend in ("OPTIX", "CUDA", "HIP", "ONEAPI"):
            try:
                prefs.compute_device_type = backend
            except TypeError:
                continue
            prefs.refresh_devices()
            if any(d.type == backend for d in prefs.devices):
                for d in prefs.devices:
                    d.use = d.type == backend
                scene.cycles.device = "GPU"
                return backend
    except Exception as exc:  # noqa: BLE001 - fall back to CPU on any failure
        print("GPU setup failed:", exc)
    return "CPU"
