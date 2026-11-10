"""Generate top-down trees for Battle Squares (Mike, 2026-11-09): pine,
spruce, oak, maple and cottonwood, each at three stages of growth (sapling,
young, mature), from his reference photos.

Run headless (all, or only the types or stages named):
    blender --background --python trees.py
    blender --background --python trees.py -- oak maple mature

Each is modelled at its real size and rendered straight down under the
standard sun (bs_common.py: top-left, 40 degrees from overhead), as the game's
other props. Trees don't turn in the game, so the baked light is right.
  - Broadleaf (oak, maple, cottonwood): a trunk and branches up into the
    crown, and the crown as clumps of small leaves (quads, every one its own
    shade of the type's two greens). How many clumps, how big, how spread,
    and how thick the leaves are on them makes each one: the oak a dense
    rounded dome wider than it's tall; the maple taller, airier, with gaps
    the branches show through; the cottonwood big, open and lobed, pale.
  - Conifers (pine, spruce): whorls of drooping branches up the trunk, each a
    spine with needle twigs off both sides, shorter toward the top (a cone),
    the tips lighter (new growth). The pine tall and narrow, dark green, bare
    of branches low down; the spruce a fuller, bluer cone to the ground.
  - A sapling's and a young tree's proportions are their own (STAGES), with
    their own random seed, not a mature one shrunk.

Outputs (assets/props/trees/):
  tree_<type>_<stage>.png         the tree, centred on its trunk, at the game's density
  tree_<type>_<stage>_shadow.png  its shadow alone (a shadow catcher; open-ground
                                  shadow = alpha 1, shown at 0.71 like every prop's),
                                  at half density (it's soft): shown at 2x
  trees.json                      each one's size, its trunk's, and where its
                                  shadow image goes (scripts/tree.gd reads it)
  assets/previews/trees_<type>_preview.png   its three stages over the field
"""

import json
import math
import os
import sys

import bpy
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bs_common as bs  # noqa: E402
from bs_common import srgb  # noqa: E402

ROOT = bs.ROOT
OUT_DIR = os.path.join(ROOT, "assets", "props", "trees")
PREVIEW_DIR = os.path.join(ROOT, "assets", "previews")
GRASS_TEX = os.path.join(ROOT, "assets", "textures", "field_grass_tile.png")
SAMPLES = 48
SHADOW_ALPHA = 0.71
SHADOW_DENSITY = 0.5          # the shadow image's pixels per metre, as a share of the game's
SUN_TAN = math.tan(math.radians(bs.SUN_TILT_DEG))
SUN_DIR = np.array([math.cos(math.radians(-45)), math.sin(math.radians(-45))])   # shadows fall this way (screen bottom-right)

BARK = (srgb(0.27, 0.22, 0.17), srgb(0.36, 0.31, 0.25))
BARK_PALE = (srgb(0.42, 0.40, 0.36), srgb(0.52, 0.50, 0.45))   # cottonwood: pale grey bark

# Mature sizes (m) and looks. Heights and spreads from the photos and the
# species: a 22 m pine 7 m across; a spruce 12 m, 6.5 m across; an oak 16 m
# tall and 18 across; a maple 18 m, 12 across; a cottonwood 24 m, 17 across.
TYPES = {
    "pine": dict(kind="conifer", height=22.0, width=7.0, trunk_r=0.28, crown_base=0.22, whorl_gap=0.55,
                 per_whorl=6, droop=0.30, twig=0.42, shape=0.95, bark=BARK,
                 greens=(srgb(0.09, 0.20, 0.08), srgb(0.17, 0.33, 0.11)), tips=srgb(0.27, 0.45, 0.15), seed=101),
    "spruce": dict(kind="conifer", height=12.0, width=6.5, trunk_r=0.20, crown_base=0.03, whorl_gap=0.38,
                   per_whorl=8, droop=0.22, twig=0.40, shape=1.05, bark=BARK,
                   greens=(srgb(0.17, 0.30, 0.22), srgb(0.29, 0.43, 0.35)), tips=srgb(0.45, 0.58, 0.50), seed=202),
    # Broadleaf crowns: `clumps` rounded leaf clusters (`clump_r` of the crown's
    # radius) over a dome, `missing` of them left out (gaps the branches show
    # through), leaves `density` to the square metre of a cluster's surface.
    "oak": dict(kind="broadleaf", height=16.0, width=18.0, trunk_r=0.55, crown_mid=0.58, crown_tall=0.42,
                clumps=85, clump_r=0.17, missing=0.0, density=95.0, leaf=0.15, bark=BARK,
                greens=(srgb(0.15, 0.32, 0.06), srgb(0.32, 0.53, 0.12)), seed=303),
    "maple": dict(kind="broadleaf", height=18.0, width=12.0, trunk_r=0.36, crown_mid=0.63, crown_tall=0.40,
                  clumps=55, clump_r=0.19, missing=0.22, density=70.0, leaf=0.17, bark=BARK,
                  greens=(srgb(0.24, 0.42, 0.12), srgb(0.44, 0.62, 0.22)), seed=404),
    "cottonwood": dict(kind="broadleaf", height=24.0, width=17.0, trunk_r=0.60, crown_mid=0.66, crown_tall=0.38,
                       clumps=40, clump_r=0.22, missing=0.30, density=60.0, leaf=0.17, bark=BARK_PALE,
                       greens=(srgb(0.30, 0.44, 0.18), srgb(0.50, 0.64, 0.32)), seed=505),
}
# Growth: height and spread as shares of a mature tree's (a young tree's
# crown is narrower for its height), its trunk's, and leaf/needle size.
STAGES = {
    "sapling": dict(h=0.22, w=0.20, trunk=0.22, leaf=0.75, seed=1),
    "young": dict(h=0.55, w=0.48, trunk=0.50, leaf=0.9, seed=2),
    "mature": dict(h=1.0, w=1.0, trunk=1.0, leaf=1.0, seed=3),
}

rng = None


# ------------------------------------------------------------- meshes --
class Builder:
    """Collects quads and tubes with a colour per vertex, into one mesh."""

    def __init__(self):
        self.verts, self.faces, self.cols = [], [], []
        self.n = 0

    def add(self, v, f, c):
        self.verts.append(v)
        self.faces.append(f + self.n)
        self.cols.append(c)
        self.n += len(v)

    def quads(self, centre, along, across, half_len, half_wid, colour):
        """Leaf (or needle) shapes centred at `centre` (n x 3): diamonds, pointed
        at both ends along `along`, widest across `across`."""
        a = along * half_len[:, None]
        b = across * half_wid[:, None]
        v = np.stack([centre - a, centre - b, centre + a, centre + b], axis=1).reshape(-1, 3)
        k = len(centre)
        f = (np.arange(k)[:, None] * 4 + np.array([0, 1, 2, 3])[None, :])
        c = np.repeat(colour, 4, axis=0)
        self.add(v, f, c)

    def tube(self, p0, p1, r0, r1, colour, segs=7):
        p0, p1 = np.asarray(p0, float), np.asarray(p1, float)
        axis = p1 - p0
        length = np.linalg.norm(axis)
        if length < 1e-4:
            return
        w = axis / length
        u = np.cross(w, [0, 0, 1] if abs(w[2]) < 0.9 else [1, 0, 0])
        u /= np.linalg.norm(u)
        v = np.cross(w, u)
        ang = np.linspace(0, 2 * math.pi, segs, endpoint=False)
        ring = np.cos(ang)[:, None] * u + np.sin(ang)[:, None] * v
        verts = np.concatenate([p0 + ring * r0, p1 + ring * r1])
        faces = np.array([[i, (i + 1) % segs, segs + (i + 1) % segs, segs + i] for i in range(segs)])
        cols = np.repeat(np.asarray(colour)[None, :], 2 * segs, axis=0) * rng.uniform(0.85, 1.1, (2 * segs, 1))
        self.add(verts, faces, cols)

    def build(self, name, mat):
        verts = np.concatenate(self.verts).astype(np.float32)
        faces = np.concatenate(self.faces).astype(np.int32)
        cols = np.concatenate(self.cols).astype(np.float32)
        me = bpy.data.meshes.new(name)
        me.vertices.add(len(verts))
        me.vertices.foreach_set("co", verts.ravel())
        me.loops.add(faces.size)
        me.loops.foreach_set("vertex_index", faces.ravel())
        me.polygons.add(len(faces))
        me.polygons.foreach_set("loop_start", np.arange(0, faces.size, 4, dtype=np.int32))
        me.update(calc_edges=True)
        attr = me.color_attributes.new("Col", "FLOAT_COLOR", "POINT")
        rgba = np.column_stack([cols, np.ones(len(cols))]).astype(np.float32)
        attr.data.foreach_set("color", rgba.ravel())
        me.materials.append(mat)
        obj = bpy.data.objects.new(name, me)
        bpy.context.scene.collection.objects.link(obj)
        return obj, verts


def color_material(name, roughness, specular):
    mat = bpy.data.materials.new(name)
    nt = bs.node_tree_of(mat)
    bsdf = next((n for n in nt.nodes if n.type == "BSDF_PRINCIPLED"), None)
    if bsdf is None:
        bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
        out = next(n for n in nt.nodes if n.type == "OUTPUT_MATERIAL")
        nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    attr = nt.nodes.new("ShaderNodeAttribute")
    attr.attribute_name = "Col"
    nt.links.new(attr.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = roughness
    if "Specular IOR Level" in bsdf.inputs:
        bsdf.inputs["Specular IOR Level"].default_value = specular   # matte: overhead sun off flat leaves would read pale
    return mat


def random_frames(n, normal_tilt):
    """`n` random quad orientations, facing mostly up: (along, across) unit vectors."""
    az = rng.uniform(0, 2 * math.pi, n)
    tilt = rng.uniform(0, normal_tilt, n)
    nrm = np.column_stack([np.sin(tilt) * np.cos(az), np.sin(tilt) * np.sin(az), np.cos(tilt)])
    spin = rng.uniform(0, 2 * math.pi, n)
    ref = np.where(np.abs(nrm[:, 2:3]) < 0.9, np.array([[0, 0, 1.0]]), np.array([[1.0, 0, 0]]))
    u = np.cross(nrm, ref)
    u /= np.linalg.norm(u, axis=1, keepdims=True)
    v = np.cross(nrm, u)
    along = u * np.cos(spin)[:, None] + v * np.sin(spin)[:, None]
    across = np.cross(nrm, along)
    return along, across


def mix(c0, c1, t):
    return c0[None, :] * (1 - t[:, None]) + c1[None, :] * t[:, None]


# ------------------------------------------------------------ broadleaf --
def build_broadleaf(spec, st, wood, leaves):
    """A trunk and branches, and the crown as rounded clusters of leaves spread
    evenly over a dome (a Fibonacci spiral, jittered), each cluster leafy on its
    outside and dark within, so from above it's a head of rounded clumps with
    shaded hollows between, as the photos' oak and maple."""
    H = spec["height"] * st["h"]
    R = spec["width"] / 2 * st["w"]
    crown_z = H * spec["crown_mid"]
    crown_h = H * spec["crown_tall"]
    trunk_r = spec["trunk_r"] * st["trunk"]
    trunk_top = crown_z - crown_h * 0.3
    wood.tube((0, 0, 0), (0, 0, trunk_top), trunk_r, trunk_r * 0.7, spec["bark"][0], segs=10)
    n = max(6, int(spec["clumps"] * (0.3 + 0.7 * st["w"])))
    rc0 = R * spec["clump_r"] * (1.35 if st["w"] < 0.3 else (1.12 if st["w"] < 0.6 else 1.0))
    golden = math.pi * (3 - math.sqrt(5))
    centres = []
    for i in range(n):
        # Points spread evenly down the dome from its top (u 1) to below its middle (u -0.35).
        u = 1.0 - 1.35 * (i + 0.5) / n
        ring = math.sqrt(max(0.0, 1 - u * u))
        az = i * golden + rng.normal(0, 0.15)
        out = rng.uniform(0.80, 0.97)
        c = np.array([math.cos(az) * ring * (R - rc0 * 0.6) * out,
                      math.sin(az) * ring * (R - rc0 * 0.6) * out,
                      crown_z + u * (crown_h / 2 - rc0 * 0.4) * out])
        c += rng.normal(0, rc0 * 0.18, 3)
        if i > 2 and rng.uniform() < spec["missing"]:
            continue   # a gap in the crown
        centres.append(c)
    # A few inside, so the gaps aren't straight down to the ground.
    for _ in range(max(2, n // 8)):
        a = rng.uniform(0, 2 * math.pi)
        d = rng.uniform(0, R * 0.45)
        centres.append(np.array([math.cos(a) * d, math.sin(a) * d, crown_z + rng.uniform(-0.2, 0.15) * crown_h]))
    base = np.array([0.0, 0.0, trunk_top])
    for c in centres:
        # A limb from the trunk's top out toward it, forking half way (they show through the gaps).
        mid = base + (c - base) * 0.5 + rng.normal(0, rc0 * 0.2, 3)
        wood.tube(base, mid, trunk_r * 0.42, trunk_r * 0.22, spec["bark"][0], segs=6)
        wood.tube(mid, c, trunk_r * 0.22, trunk_r * 0.06, spec["bark"][1], segs=5)
    leaf = spec["leaf"] * st["leaf"]
    g0, g1 = spec["greens"]
    total = 0
    for c in centres:
        r = rc0 * rng.uniform(0.8, 1.2)
        tint = rng.uniform(0.82, 1.12) * np.array([rng.uniform(0.95, 1.05), 1.0, rng.uniform(0.9, 1.1)])
        k = int(spec["density"] * 4 * math.pi * r * r * 0.75 * (spec["leaf"] / leaf) ** 2 * 0.5)
        d = rng.normal(0, 1, (k, 3))
        d[:, 2] = np.abs(d[:, 2]) * 1.3 - 0.35   # (mostly the upper side: that's what shows)
        d /= np.linalg.norm(d, axis=1, keepdims=True)
        depth = rng.uniform(0, 1, k) ** 0.5        # (most near the surface)
        p = c + d * (r * (0.55 + 0.47 * depth))[:, None]
        along, across = random_frames(k, 1.2)
        size = leaf * rng.uniform(0.7, 1.35, k)
        shade = np.clip(rng.uniform(0, 1, k) * 0.7 + 0.3 * depth * (d[:, 2] > 0.2), 0, 1)
        col = mix(g0, g1, shade) * tint[None, :] * (0.55 + 0.45 * depth)[:, None] * rng.uniform(0.88, 1.1, (k, 1))
        leaves.quads(p, along, across, size / 2, size * 0.3, col)
        total += k
    print(f"  {len(centres)} clusters, {total} leaves")
    return trunk_r


# -------------------------------------------------------------- conifer --
def build_conifer(spec, st, wood, leaves):
    """Whorls of drooping branches up the trunk, shorter toward the top, each
    packed with needle twigs at varied angles and a fuzz of needle tufts, and
    shorter branches between the whorls: from above, a dense star of soft,
    layered boughs."""
    H = spec["height"] * st["h"]
    R = spec["width"] / 2 * st["w"]
    trunk_r = spec["trunk_r"] * st["trunk"]
    wood.tube((0, 0, 0), (0, 0, H), trunk_r, trunk_r * 0.15, spec["bark"][0], segs=9)
    z0 = H * spec["crown_base"] * (0.5 if st["h"] < 0.5 else 1.0)
    gap = spec["whorl_gap"] * (0.55 + 0.45 * st["h"])
    g0, g1 = spec["greens"]
    tips = spec["tips"]
    needles = 0

    def branch(z, az, length, tone):
        nonlocal needles
        dirn = np.array([math.cos(az), math.sin(az), 0.0])
        side = np.array([-dirn[1], dirn[0], 0.0])
        steps = max(3, int(length / 0.075))
        t = np.linspace(0.03, 1.0, steps)
        droop = spec["droop"] * length
        spine = (np.array([0, 0, z]) + dirn[None, :] * (length * t)[:, None]
                 - np.array([0, 0, 1.0])[None, :] * (droop * t * t)[:, None])
        # Twigs off both sides, at varied angles, shorter toward the tip.
        tl_full = spec["twig"] * min(1.0, 0.35 + length / 2.2) * st["leaf"]
        for s in (-1.0, 1.0):
            ang = np.radians(rng.uniform(35, 75, steps))
            tw = (dirn[None, :] * np.cos(ang)[:, None] + side[None, :] * (s * np.sin(ang))[:, None]
                  - np.array([[0, 0, 0.2]]))
            tw /= np.linalg.norm(tw, axis=1, keepdims=True)
            tl = tl_full * (1 - 0.65 * t) * rng.uniform(0.75, 1.15, steps)
            centre = spine + tw * (tl / 2)[:, None]
            across = np.cross(tw, np.array([0, 0, 1.0]))
            across /= np.maximum(np.linalg.norm(across, axis=1, keepdims=True), 1e-6)
            new = (t ** 2.5)[:, None] * 0.65
            col = mix(g0, g1, np.clip(tone + rng.uniform(-0.3, 0.3, steps), 0, 1)) * rng.uniform(0.85, 1.1, (steps, 1))
            col = col * (1 - new) + tips[None, :] * new
            leaves.quads(centre, tw, across, tl / 2, np.full(steps, 0.028 + 0.012 * st["leaf"]), col)
            # Needle fuzz along each twig.
            for f in range(3):
                frac = rng.uniform(0.2, 1.0, steps)
                fp = spine + tw * (tl * frac)[:, None] + rng.normal(0, 0.02, (steps, 3))
                fa, fc = random_frames(steps, 1.4)
                fs = rng.uniform(0.07, 0.13, steps) * st["leaf"]
                fcol = mix(g0, g1, rng.uniform(0.1, 1, steps)) * (1 - new) + tips[None, :] * new
                leaves.quads(fp, fa, fc, fs / 2, fs * 0.14, fcol)
            needles += steps * 4

    z = z0
    while z < H - 0.12:
        f = (H - z) / (H - z0)
        radius = R * f ** spec["shape"]
        n_br = spec["per_whorl"] + int(rng.integers(-1, 2))
        off = rng.uniform(0, 2 * math.pi)
        for b in range(n_br):
            az = off + b * 2 * math.pi / n_br + rng.normal(0, 0.15)
            branch(z, az, max(0.2, radius * rng.uniform(0.85, 1.08)), rng.uniform(0.2, 0.8))
        # Shorter branches between this whorl and the next, filling the gaps.
        for b in range(max(2, n_br // 2)):
            zz = z + gap * rng.uniform(0.3, 0.7)
            if zz >= H - 0.1:
                continue
            ff = (H - zz) / (H - z0)
            branch(zz, rng.uniform(0, 2 * math.pi), max(0.15, R * ff ** spec["shape"] * rng.uniform(0.45, 0.7)),
                   rng.uniform(0.3, 0.9))
        z += gap * rng.uniform(0.85, 1.15)
    # The leader at the very top.
    leaves.quads(np.array([[0, 0, H - 0.1]]), np.array([[0, 0, 1.0]]), np.array([[1.0, 0, 0]]),
                 np.array([0.25 * st["leaf"]]), np.array([0.04]), np.asarray(tips)[None, :])
    print(f"  {needles} needle twigs and tufts")
    return trunk_r


# ----------------------------------------------------------------- main --
def load_pixels(path):
    img = bpy.data.images.load(path, check_existing=False)
    w, h = img.size
    px = np.empty(w * h * 4, dtype=np.float32)
    img.pixels.foreach_get(px)
    return px.reshape(h, w, 4)


def save_image(px, dst):
    out = bpy.data.images.new("out", px.shape[1], px.shape[0], alpha=True)
    out.pixels.foreach_set(px.ravel())
    out.filepath_raw = dst
    out.file_format = "PNG"
    out.save()
    print("Saved", dst)


def normalise_shadow(path):
    px = load_pixels(path)
    px[:, :, 3] = np.minimum(px[:, :, 3], SHADOW_ALPHA) / SHADOW_ALPHA
    px[:, :, :3] = 0.0
    save_image(px, path)


def build(type_name, stage_name):
    global rng
    spec = TYPES[type_name]
    st = STAGES[stage_name]
    rng = np.random.default_rng(spec["seed"] * 10 + st["seed"])
    tex = os.path.join(OUT_DIR, f"tree_{type_name}_{stage_name}.png")
    shadow = os.path.join(OUT_DIR, f"tree_{type_name}_{stage_name}_shadow.png")
    scene = bs.new_scene(center=(0, 0), frame_m=4.0, transparent=True, samples=SAMPLES)
    wood, leaves = Builder(), Builder()
    if spec["kind"] == "conifer":
        trunk_r = build_conifer(spec, st, wood, leaves)
    else:
        trunk_r = build_broadleaf(spec, st, wood, leaves)
    bark_mat = color_material("Bark", 0.9, 0.1)
    leaf_mat = color_material("Leaves", 0.75, 0.15)
    _, wv = wood.build("Wood", bark_mat)
    _, lv = leaves.build("Leaves", leaf_mat)
    pts = np.concatenate([wv, lv])
    height = float(pts[:, 2].max())
    reach = float(np.max(np.abs(pts[:, :2]))) + 0.3

    # The tree: centred on its trunk.
    frame = 2 * reach
    bs.frame_camera(scene, (0.0, 0.0), frame)
    cam = scene.camera
    cam.location.z = height + 5.0
    cam.data.clip_end = height + 50.0
    bs.render_to(scene, tex)

    # Its shadow alone, on a catcher, framing where every part's shadow falls.
    flat = pts[:, :2] + SUN_DIR[None, :] * (pts[:, 2:3] * SUN_TAN)
    lo = np.minimum(flat.min(0), pts[:, :2].min(0)) - 0.6 - height * 0.07
    hi = np.maximum(flat.max(0), pts[:, :2].max(0)) + 0.6 + height * 0.07
    centre = (lo + hi) / 2
    sframe = float(max(hi - lo))
    catcher_mesh = bpy.data.meshes.new("Ground")
    s = sframe
    catcher_mesh.from_pydata([(centre[0] - s, centre[1] - s, 0), (centre[0] + s, centre[1] - s, 0),
                              (centre[0] + s, centre[1] + s, 0), (centre[0] - s, centre[1] + s, 0)], [], [(0, 1, 2, 3)])
    catcher = bpy.data.objects.new("Ground", catcher_mesh)
    catcher.is_shadow_catcher = True
    scene.collection.objects.link(catcher)
    for obj in scene.objects:
        if obj.type == "MESH" and obj is not catcher:
            obj.visible_camera = False
    bs.frame_camera(scene, (float(centre[0]), float(centre[1])), sframe, bs.PX_PER_M * SHADOW_DENSITY)
    cam.location.z = height + 5.0
    bs.render_to(scene, shadow)
    normalise_shadow(shadow)
    return {
        "height_m": round(height, 2),
        "canopy_radius_m": round(reach - 0.3, 2),
        "trunk_radius_m": round(trunk_r, 3),
        "image_m": round(frame, 3),
        "shadow_m": round(sframe, 3),
        "shadow_centre_m": [round(float(centre[0]), 3), round(-float(centre[1]), 3)],   # (the game's y is down)
        "shadow_density": SHADOW_DENSITY,
    }


def preview(type_name, info):
    """Its three stages side by side over the field, each with its shadow."""
    ppm = bs.PX_PER_M
    cells = []
    for stage in STAGES:
        key = f"{type_name}_{stage}"
        if key not in info:
            continue
        d = info[key]
        half = d["image_m"] / 2
        sc = d["shadow_centre_m"]
        x0 = min(-half, sc[0] - d["shadow_m"] / 2)
        x1 = max(half, sc[0] + d["shadow_m"] / 2)
        y0 = min(-half, -sc[1] - d["shadow_m"] / 2)   # (Blender y: up)
        y1 = max(half, -sc[1] + d["shadow_m"] / 2)
        cells.append((stage, d, x0, x1, y0, y1))
    if not cells:
        return
    width_m = sum(c[3] - c[2] for c in cells)
    height_m = max(c[5] - c[4] for c in cells)
    W, Hh = int(width_m * ppm) + 1, int(height_m * ppm) + 1
    grass = load_pixels(GRASS_TEX)
    canvas = np.tile(grass, (Hh // grass.shape[0] + 1, W // grass.shape[1] + 1, 1))[:Hh, :W].copy()
    left = 0.0
    for stage, d, x0, x1, y0, y1 in cells:
        ox = left - x0          # trunk's x on the canvas (m)
        oy = -y0                # trunk's y (m, from the bottom)
        sh = load_pixels(os.path.join(OUT_DIR, f"tree_{type_name}_{stage}_shadow.png"))
        k = int(round(1 / d["shadow_density"]))
        sh = np.repeat(np.repeat(sh, k, 0), k, 1)
        sc = d["shadow_centre_m"]
        c0 = int((ox + sc[0] - d["shadow_m"] / 2) * ppm)
        r0 = int((oy - sc[1] - d["shadow_m"] / 2) * ppm)
        h, w = min(sh.shape[0], Hh - r0), min(sh.shape[1], W - c0)
        a = sh[:h, :w, 3:4] * SHADOW_ALPHA
        canvas[r0:r0 + h, c0:c0 + w, :3] *= (1 - a)
        tree = load_pixels(os.path.join(OUT_DIR, f"tree_{type_name}_{stage}.png"))
        c0 = int((ox - d["image_m"] / 2) * ppm)
        r0 = int((oy - d["image_m"] / 2) * ppm)
        h, w = min(tree.shape[0], Hh - r0), min(tree.shape[1], W - c0)
        a = tree[:h, :w, 3:4]
        band = canvas[r0:r0 + h, c0:c0 + w]
        band[:, :, :3] = tree[:h, :w, :3] * a + band[:, :, :3] * (1 - a)
        left += x1 - x0
    save_image(canvas, os.path.join(PREVIEW_DIR, f"trees_{type_name}_preview.png"))


def main():
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    types = [a for a in args if a in TYPES] or list(TYPES)
    stages = [a for a in args if a in STAGES] or list(STAGES)
    os.makedirs(OUT_DIR, exist_ok=True)
    os.makedirs(PREVIEW_DIR, exist_ok=True)
    info_path = os.path.join(OUT_DIR, "trees.json")
    info = {}
    if os.path.exists(info_path):
        with open(info_path) as fh:
            info = json.load(fh)
    for t in types:
        for s in stages:
            print(f"--- {t} {s} ---")
            info[f"{t}_{s}"] = build(t, s)
            with open(info_path, "w") as fh:
                json.dump(info, fh, indent=1, sort_keys=True)
    for t in types:
        preview(t, info)


if __name__ == "__main__":
    main()
