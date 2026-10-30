"""Render a UH-60-style transport helicopter as top-down sprites.

Run headless:
    blender --background --python helicopter.py

Modelled at real-world proportions (metres): fuselage 15.3 long, cabin
about 2.4 wide, main rotor 16.4 across with 4 blades, tail rotor 3.35
across, canted, on the starboard side, stabilator 4.4 span. No markings.
Then the whole airframe is shrunk by SCALE. Two pilot squares sit side by
side in the cockpit, seen through the tinted, partly see-through glass,
and grow with the airframe: at SCALE 0.55 they're 0.44 m, 10% bigger than
the player's 0.4 m square, since they're higher up and closer to the camera.

Images, all lit from straight overhead so the game can turn them to any
heading (like the rifle):
  helicopter_body.png   the airframe, centred on the fuselage origin, nose
                        pointing right (+x). The cockpit glass is left out
                        (it still dims the light inside), so the cockpit
                        interior shows, without the pilots.
  helicopter_pilot.png  one pilot square, lit as it is inside the cockpit,
                        centred on itself. The game draws two and moves them
                        a little (scripts/helicopter.gd).
  helicopter_glass.png  just the cockpit glass, same frame as the body, drawn
                        over the pilots.
  helicopter_rotor.png  the main rotor and hub, centred on the mast
plus half-resolution outlines for the shadow, one per part that sits at
its own height (SHADOW_PARTS). The game sweeps each outline across that
part's height range toward the sun's direction (scripts/helicopter.gd and
shaders/shadow_sweep.gdshader), so a thin tail plane casts a crisp shadow
instead of smearing across the whole fuselage's height. The game also
spins the rotor.

Blender axes here: +x forward, +y to port (left), +z up. In the image +y
is up, so port is the top edge with the nose pointing right.
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
OUT_BODY = os.path.join(ROOT, "assets", "vehicles", "helicopter_body.png")
OUT_ROTOR = os.path.join(ROOT, "assets", "vehicles", "helicopter_rotor.png")
OUT_PILOT = os.path.join(ROOT, "assets", "vehicles", "helicopter_pilot.png")
OUT_GLASS = os.path.join(ROOT, "assets", "vehicles", "helicopter_glass.png")
OUT_BLEND = os.path.join(ROOT, "blender", "source", "helicopter.blend")

SHADOW_DIR = os.path.join(ROOT, "assets", "vehicles")
# Shadow outlines: file suffix -> the parts (object names) in it. Their
# height ranges are in helicopter.gd SHADOW_PARTS.
SHADOW_PARTS = {
    "body": None,                          # everything not listed below
    "stabilator": ["Stabilator"],
    "fin": ["Fin"],
    "tailrotor": ["TailRotorBlur"],
}

# All sizes below are real-size; SCALE shrinks the finished model (and the
# frames) to game size. helicopter.gd SCALE must match.
SCALE = 0.55
MAST_X_M = 1.5          # main rotor mast, forward of the fuselage origin; helicopter.gd must match
ROTOR_RADIUS_M = 8.18
BODY_FRAME_M = 20.0     # covers nose (+7.6) to tail rotor (-9.8)
SHADOW_FRAME_M = 26.0   # room for each outline to be swept up to ~3 m sideways at any heading
ROTOR_FRAME_M = 16.6

# The pilots and cockpit are laid out in game metres for a helicopter at
# COCKPIT_AT_SCALE, then grown with the airframe for the actual SCALE.
COCKPIT_AT_SCALE = 0.5

# The pilots: the player's red square (character_square.py), side by side
# in the cockpit; 0.4 m at COCKPIT_AT_SCALE. Seen from above their corners
# are rounded like the player's (the upright edges, same radius), but the
# top edges are left sharp: lit from straight overhead under tinted glass,
# a rounded top edge reads as a dark border that makes them look smaller.
PILOT_SIZE_M = 0.40
PILOT_CORNER_M = 0.035  # character_square.py BEVEL_M
PILOT_X_M = 2.84        # along the fuselage, toward the back of the cockpit glass
PILOT_Y_M = 0.245       # either side of the centre line
PILOT_Z_M = 0.26        # sitting on the cockpit floor
PILOT_RED = (0.85, 0.09, 0.07)
PILOT_FRAME_M = 0.6     # the pilot image (at COCKPIT_AT_SCALE): room to turn

# The cockpit in front of them (same metres as the pilots): instrument panel under a
# glare shield, a screen in front of each pilot, a centre console running
# back between the seats, and a few lit switches.
PANEL_X_M = (3.10, 3.30)
PANEL_HALF_W_M = 0.42
PANEL_Z_M = (0.50, 0.66)
SAMPLES = 96

# Colours (sRGB).
OLIVE = (0.21, 0.24, 0.18)
OLIVE_DARK = (0.15, 0.17, 0.13)
GLASS = (0.085, 0.12, 0.15)
GLASS_ALPHA = 0.85      # 15% see-through: dark tint, the pilots just show
# The glass image's opacity. The game stacks body, pilots and glass after
# Blender's view transform, which comes out darker than Blender blending
# them itself; at this the stack matches a single render at GLASS_ALPHA.
GLASS_OVERLAY_ALPHA = 0.78
PANEL = (0.06, 0.065, 0.07)
SCREEN = (0.25, 0.75, 0.45)
SOOT = (0.07, 0.07, 0.07)
BLADE = (0.05, 0.05, 0.055)
TIP = (0.85, 0.72, 0.12)
RUBBER = (0.05, 0.05, 0.05)


def material(name, rgb, metallic=0.0, roughness=0.55, alpha=1.0, shine=0.5):
    """`shine` is the specular level. With the sun and camera both straight
    overhead, flat tops reflect the sun right back at the camera, so matte
    parts need it low or they render as pale grey whatever their colour."""
    mat = bpy.data.materials.new(name)
    nt = bs.node_tree_of(mat)
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (*bs.srgb(*rgb), 1.0)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    if "Specular IOR Level" in bsdf.inputs:
        bsdf.inputs["Specular IOR Level"].default_value = shine
    if alpha < 1.0:
        bsdf.inputs["Alpha"].default_value = alpha
    return mat


def link(name, mesh, mats, smooth=True, subsurf=0):
    for m in mats:
        mesh.materials.append(m)
    if smooth:
        mesh.shade_smooth()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    if subsurf:
        mod = obj.modifiers.new("Smooth", "SUBSURF")
        mod.levels = mod.render_levels = subsurf
    return obj


def loft(name, stations, segs=24, exponent=2.6):
    """A closed tube through cross-sections (x, half_width, z_bottom, z_top),
    each a rounded box (superellipse), capped at both ends."""
    bm = bmesh.new()
    rings = []
    for x, hw, zb, zt in stations:
        zc, hh = (zb + zt) / 2, (zt - zb) / 2
        ring = []
        for j in range(segs):
            a = 2 * math.pi * j / segs
            c, s = math.cos(a), math.sin(a)
            y = hw * math.copysign(abs(c) ** (2 / exponent), c)
            z = zc + hh * math.copysign(abs(s) ** (2 / exponent), s)
            ring.append(bm.verts.new((x, y, z)))
        rings.append(ring)
    for r0, r1 in zip(rings, rings[1:]):
        for j in range(segs):
            bm.faces.new((r0[j], r0[(j + 1) % segs], r1[(j + 1) % segs], r1[j]))
    for ring in (rings[0], rings[-1]):
        bm.faces.new(ring)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    return me


def box_mesh(name, x0, x1, y0, y1, z0, z1, bevel=0.0):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, verts=bm.verts, vec=(x1 - x0, y1 - y0, z1 - z0))
    bmesh.ops.translate(bm, verts=bm.verts, vec=((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2))
    if bevel:
        bmesh.ops.bevel(bm, geom=list(bm.edges), offset=bevel, segments=3,
                        profile=0.5, affect="EDGES")
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    return me


def cylinder_mesh(name, radius, depth, segs=24):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=segs, radius1=radius,
                          radius2=radius, depth=depth)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    return me


# ---------------------------------------------------------------- airframe --
def build_body():
    olive = material("Olive", OLIVE, roughness=0.75, shine=0.25)   # matte military paint
    olive_dark = material("OliveDark", OLIVE_DARK, roughness=0.8, shine=0.2)
    glass = material("Glass", GLASS, metallic=0.2, roughness=0.06, alpha=GLASS_ALPHA)
    soot = material("Soot", SOOT, roughness=0.8)
    rubber = material("Rubber", RUBBER, roughness=0.9)
    blur = material("TailRotorBlur", BLADE, roughness=0.5, alpha=0.35)
    parts = []

    # Fuselage: nose (+x) to tail (-x).
    fuselage = loft("Fuselage", [
        (7.60, 0.15, 0.95, 1.30),
        (7.30, 0.60, 0.55, 1.75),
        (6.80, 0.95, 0.45, 2.05),
        (6.00, 1.12, 0.40, 2.35),
        (5.00, 1.18, 0.40, 2.45),
        (3.50, 1.20, 0.40, 2.45),
        (1.00, 1.20, 0.40, 2.45),
        (-0.50, 1.15, 0.50, 2.40),
        (-1.50, 1.00, 0.90, 2.30),
        (-2.50, 0.60, 1.35, 2.10),
        (-4.00, 0.42, 1.50, 1.95),
        (-6.00, 0.32, 1.60, 1.95),
        (-7.00, 0.28, 1.65, 2.00),
        (-7.60, 0.20, 1.75, 2.20),
    ])
    # Cockpit glass: the windscreen and upper side panels between the painted
    # nose and the cabin roof.
    fuselage.materials.append(olive)
    fuselage.materials.append(glass)
    for poly in fuselage.polygons:
        c = poly.center
        if 5.4 < c.x < 6.95 and c.z > 1.55 and abs(c.y) < 1.0:
            poly.material_index = 1
    parts.append(link("Fuselage", fuselage, [], subsurf=2))

    # Roof fairing between the engines, and the two engine nacelles.
    parts.append(link("Fairing", box_mesh("Fairing", -1.6, 2.4, -0.55, 0.55, 2.3, 3.0, bevel=0.2),
                      [olive_dark]))
    for side in (1, -1):
        nacelle = loft("Nacelle", [
            (1.10, 0.12, 2.73, 2.97),
            (0.85, 0.36, 2.48, 3.22),
            (-1.20, 0.42, 2.43, 3.27),
            (-1.70, 0.34, 2.51, 3.19),
        ], segs=20, exponent=2.0)
        obj = link("Nacelle", nacelle, [olive], subsurf=1)
        obj.location.y = side * 0.78
        parts.append(obj)
        # Exhaust, angled out and back from the rear of each engine.
        exhaust = link("Exhaust", cylinder_mesh("Exhaust", 0.27, 0.7), [soot])
        exhaust.rotation_euler = (0, math.radians(90), math.radians(side * 25))
        exhaust.location = (-1.95, side * 0.95, 2.85)
        parts.append(exhaust)

    # Main landing gear: wheels on short sponsons just outside the cabin.
    for side in (1, -1):
        parts.append(link("Sponson", box_mesh("Sponson", 0.7, 1.7, side * 1.05, side * 1.45, 0.45, 0.75, bevel=0.08),
                          [olive_dark]))
        wheel = link("Wheel", cylinder_mesh("Wheel", 0.36, 0.25), [rubber])
        wheel.rotation_euler = (math.radians(90), 0, 0)
        wheel.location = (1.2, side * 1.55, 0.36)
        parts.append(wheel)

    # Tail: swept fin, stabilator, canted tail rotor on the starboard side.
    fin = bmesh.new()
    pts = [(-7.0, 1.9), (-7.7, 1.9), (-8.55, 4.3), (-8.05, 4.3)]
    bottom = [fin.verts.new((x, -0.09, z)) for x, z in pts]
    top = [fin.verts.new((x, 0.09, z)) for x, z in pts]
    fin.faces.new(bottom)
    fin.faces.new(list(reversed(top)))
    for i in range(4):
        j = (i + 1) % 4
        fin.faces.new((bottom[i], bottom[j], top[j], top[i]))
    bmesh.ops.recalc_face_normals(fin, faces=fin.faces)
    fin_me = bpy.data.meshes.new("Fin")
    fin.to_mesh(fin_me)
    fin.free()
    parts.append(link("Fin", fin_me, [olive], smooth=False))
    parts.append(link("Stabilator", box_mesh("Stabilator", -8.0, -7.1, -2.2, 2.2, 1.95, 2.05, bevel=0.03),
                      [olive]))
    tail_rotor = link("TailRotorBlur", cylinder_mesh("TailRotor", 1.675, 0.04, segs=32), [blur])
    tail_rotor.rotation_euler = (math.radians(90 - 20), 0, 0)   # disc upright, canted 20 deg
    tail_rotor.location = (-8.1, -0.35, 3.5)
    parts.append(tail_rotor)
    return parts


# ------------------------------------------------------------------- rotor --
def build_rotor():
    blade_mat = material("Blade", BLADE, roughness=0.85, shine=0.08)
    tip_mat = material("BladeTip", TIP, roughness=0.8, shine=0.1)
    hub_mat = material("Hub", (0.2, 0.2, 0.2), metallic=0.6, roughness=0.35)
    parts = []
    hub = link("Hub", cylinder_mesh("Hub", 0.42, 0.35), [hub_mat])
    hub.location.z = 0.2
    parts.append(hub)
    cap = link("HubCap", cylinder_mesh("HubCap", 0.22, 0.2), [hub_mat])
    cap.location.z = 0.45
    parts.append(cap)
    chord, tip_band = 0.53, 0.35
    for k in range(4):
        angle = math.pi / 2 * k
        # Blade root to just short of the tip, then a bright caution band, with
        # the last stretch swept back like the real swept tips.
        segments = [
            (0.35, ROTOR_RADIUS_M - 0.9, blade_mat, 0.0),
            (ROTOR_RADIUS_M - 0.9, ROTOR_RADIUS_M - 0.9 + tip_band, tip_mat, 0.0),
            (ROTOR_RADIUS_M - 0.9 + tip_band, ROTOR_RADIUS_M, blade_mat, 0.18),
        ]
        for r0, r1, mat, sweep in segments:
            me = box_mesh("Blade", r0, r1, -chord / 2, chord / 2, 0.15, 0.21)
            if sweep:
                # Shear the tip back (toward -y, trailing edge) along its length.
                bm = bmesh.new()
                bm.from_mesh(me)
                for v in bm.verts:
                    v.co.y -= sweep * (v.co.x - r0) / (r1 - r0)
                bm.to_mesh(me)
                bm.free()
            obj = link("Blade", me, [mat], smooth=False)
            obj.rotation_euler.z = angle
            parts.append(obj)
    return parts


def scale_down(parts):
    """Shrinks finished real-size parts by SCALE about the model's origin."""
    for obj in parts:
        obj.location *= SCALE
        obj.scale *= SCALE


def build_pilots():
    """Two red squares in the cockpit, pilot and co-pilot, the same block as
    character_square.py's (kept in step by hand)."""
    mat = bpy.data.materials.new("PilotRed")
    nt = bs.node_tree_of(mat)
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (*bs.srgb(*PILOT_RED), 1.0)
    bsdf.inputs["Roughness"].default_value = 0.38
    parts = []
    for side in (1, -1):
        bm = bmesh.new()
        bmesh.ops.create_cube(bm, size=PILOT_SIZE_M)
        bmesh.ops.translate(bm, verts=bm.verts, vec=(0, 0, PILOT_SIZE_M / 2))
        upright = [e for e in bm.edges if abs(e.verts[0].co.z - e.verts[1].co.z) > 1e-6]
        bmesh.ops.bevel(bm, geom=upright, offset=PILOT_CORNER_M, segments=6,
                        profile=0.5, affect="EDGES")
        me = bpy.data.meshes.new("Pilot")
        bm.to_mesh(me)
        bm.free()
        me.set_sharp_from_angle(angle=math.radians(30))
        obj = link("Pilot", me, [mat])
        obj.location = (PILOT_X_M, side * PILOT_Y_M, PILOT_Z_M)
        parts.append(obj)
    return parts


def build_cockpit():
    """The instrument panel and console the pilots face (game size)."""
    panel_mat = material("Panel", PANEL, roughness=0.7, shine=0.15)
    screen_mat = material("Screen", (0.02, 0.05, 0.03), roughness=0.3)
    bsdf = next(n for n in screen_mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Emission Color"].default_value = (*bs.srgb(*SCREEN), 1.0)
    bsdf.inputs["Emission Strength"].default_value = 1.2
    lamps = {name: material(name, rgb, roughness=0.4) for name, rgb in
             (("LampAmber", (0.95, 0.6, 0.1)), ("LampGreen", (0.3, 0.9, 0.3)), ("LampRed", (0.9, 0.15, 0.1)))}
    for mat, rgb in zip(lamps.values(), ((0.95, 0.6, 0.1), (0.3, 0.9, 0.3), (0.9, 0.15, 0.1))):
        b = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
        b.inputs["Emission Color"].default_value = (*bs.srgb(*rgb), 1.0)
        b.inputs["Emission Strength"].default_value = 0.8
    x0, x1 = PANEL_X_M
    z0, z1 = PANEL_Z_M
    hw = PANEL_HALF_W_M
    parts = [link("Panel", box_mesh("Panel", x0, x1, -hw, hw, z0, z1, bevel=0.015), [panel_mat])]
    # A screen on the panel's top in front of each pilot, plus a small one
    # in the middle.
    for y, w in ((PILOT_Y_M, 0.14), (-PILOT_Y_M, 0.14), (0.0, 0.07)):
        parts.append(link("Screen", box_mesh("Screen", x0 + 0.04, x1 - 0.05, y - w / 2, y + w / 2, z1, z1 + 0.008),
                          [screen_mat], smooth=False))
    # Centre console between the seats, with a row of switches.
    parts.append(link("Console", box_mesh("Console", PILOT_X_M - 0.12, x0, -0.035, 0.035, z0 - 0.08, z0 + 0.04, bevel=0.01),
                      [panel_mat]))
    for k, name in enumerate(("LampAmber", "LampGreen", "LampAmber", "LampRed")):
        x = PILOT_X_M - 0.06 + k * 0.065
        parts.append(link("Lamp", box_mesh("Lamp", x - 0.012, x + 0.012, -0.012, 0.012, z0 + 0.04, z0 + 0.05),
                          [lamps[name]], smooth=False))
    # Switch strips along the panel's front edge.
    for y in (-0.33, -0.12, 0.12, 0.33):
        parts.append(link("Switches", box_mesh("Switches", x0 + 0.005, x0 + 0.025, y - 0.04, y + 0.04, z1, z1 + 0.006),
                          [lamps["LampAmber" if abs(y) > 0.2 else "LampGreen"]], smooth=False))
    return parts


def camera_sees_through(mat):
    """Makes `mat` invisible to the camera while it still shades everything
    else (shadow rays still pass through its alpha). Returns a function that
    switches that on (True) or off (False)."""
    nt = mat.node_tree
    out = next(n for n in nt.nodes if n.type == "OUTPUT_MATERIAL")
    shader = out.inputs["Surface"].links[0].from_socket
    path = nt.nodes.new("ShaderNodeLightPath")
    clear = nt.nodes.new("ShaderNodeBsdfTransparent")
    mix = nt.nodes.new("ShaderNodeMixShader")
    nt.links.new(shader, mix.inputs[1])
    nt.links.new(clear.outputs[0], mix.inputs[2])
    nt.links.new(mix.outputs[0], out.inputs["Surface"])
    mix.inputs["Fac"].default_value = 0.0

    def switch(on):
        for link in list(mix.inputs["Fac"].links):
            nt.links.remove(link)
        if on:
            nt.links.new(path.outputs["Is Camera Ray"], mix.inputs["Fac"])
    return switch


def show_only(objs, keep):
    """Camera sees only `keep`; everything still casts shadows and lights."""
    for obj in objs:
        obj.visible_camera = obj in keep


# -------------------------------------------------------------------- main --
def main():
    for path in (OUT_BODY, OUT_ROTOR, OUT_BLEND):
        os.makedirs(os.path.dirname(path), exist_ok=True)

    scene = bs.new_scene(center=(0, 0), frame_m=BODY_FRAME_M * SCALE, transparent=True, samples=SAMPLES)
    bpy.data.objects["Sun"].rotation_euler = (0, 0, 0)   # straight overhead: any heading looks right
    body = build_body()
    rotor = build_rotor()
    scale_down(body + rotor)
    pilots = build_pilots()
    cockpit = pilots + build_cockpit()
    grow = SCALE / COCKPIT_AT_SCALE
    for obj in cockpit:
        obj.location *= grow
        obj.scale *= grow
    body += cockpit
    glass_mat = bpy.data.materials["Glass"]
    glass_hidden = camera_sees_through(glass_mat)

    for obj in rotor:
        obj.hide_render = True
    # The body: no glass and no pilots in the picture, but the glass still
    # dims the cockpit. The pilots are left out entirely: they move in the
    # game, so a shadow baked under them would show as they shift.
    glass_hidden(True)
    for obj in pilots:
        obj.hide_render = True
    bs.render_to(scene, OUT_BODY)
    for obj in pilots:
        obj.hide_render = False

    # One pilot (the port one; the light is from straight overhead, so the
    # other looks the same), lit through the glass as it sits.
    show_only(body, [pilots[0]])
    bs.frame_camera(scene, (pilots[0].location.x, pilots[0].location.y), PILOT_FRAME_M * grow)
    bs.render_to(scene, OUT_PILOT)

    # Just the glass: the rest of the fuselage held out (cut to transparent).
    glass_hidden(False)
    glass_bsdf = next(n for n in glass_mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    glass_bsdf.inputs["Alpha"].default_value = GLASS_OVERLAY_ALPHA
    fuselage = next(o for o in body if o.name.split(".")[0] == "Fuselage")
    show_only(body, [fuselage])
    paint = fuselage.data.materials[0]
    holdout = bpy.data.materials.new("Holdout")
    nt = bs.node_tree_of(holdout)
    for n in list(nt.nodes):
        if n.type != "OUTPUT_MATERIAL":
            nt.nodes.remove(n)
    out = next(n for n in nt.nodes if n.type == "OUTPUT_MATERIAL")
    nt.links.new(nt.nodes.new("ShaderNodeHoldout").outputs[0], out.inputs["Surface"])
    fuselage.data.materials[0] = holdout
    bs.frame_camera(scene, (0, 0), BODY_FRAME_M * SCALE)
    bs.render_to(scene, OUT_GLASS)
    fuselage.data.materials[0] = paint
    glass_bsdf.inputs["Alpha"].default_value = GLASS_ALPHA
    show_only(body, body)

    # Shadow outlines, one per height group, at half resolution (shadows
    # are soft, and this keeps the textures small).
    listed = {name for names in SHADOW_PARTS.values() if names for name in names}
    bs.frame_camera(scene, (0, 0), SHADOW_FRAME_M * SCALE, bs.PX_PER_M / 2)
    for suffix, names in SHADOW_PARTS.items():
        for obj in body:
            in_group = obj.name.split(".")[0] in names if names else obj.name.split(".")[0] not in listed
            obj.hide_render = not in_group
        bs.render_to(scene, os.path.join(SHADOW_DIR, f"helicopter_shadow_{suffix}.png"))
    for obj in body:
        obj.hide_render = False

    for obj in rotor:
        obj.hide_render = False
    for obj in body:
        obj.hide_render = True
    bs.frame_camera(scene, (0, 0), ROTOR_FRAME_M * SCALE)
    bs.render_to(scene, OUT_ROTOR)

    # Put the rotor on its mast in the saved file, for looking around in Blender.
    for obj in rotor:
        obj.location.x += MAST_X_M * SCALE
        obj.location.z += 3.2 * SCALE
    for obj in body:
        obj.hide_render = False
    bs.frame_camera(scene, (0, 0), BODY_FRAME_M * SCALE)
    bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND)


main()
