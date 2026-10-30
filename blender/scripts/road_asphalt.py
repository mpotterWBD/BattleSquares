"""Generate top-down strips of two-lane asphalt road for Battle Squares, in
four conditions: clean, ok, medium and bad, each with and without the
yellow centre dashes (road.gd's Centre Line). A strip without them is the
same strip, dashes left off, so the two swap or join seamlessly.

Run headless (all four, or just the ones named; both versions of each):
    blender --background --python road_asphalt.py
    blender --background --python road_asphalt.py -- medium bad

Each strip is ROAD_LEN metres long (along x, the way the road runs) and
STRIP_W metres across, and tiles end to end: every random field is periodic
along x, and cracks, stones and grass near either end are copied to the
other end. The game lays it along a path (scripts/road.gd, its Condition
picks the strip), so the image's x is along the road and its y is across it.
All four are the same size, so they swap freely.

The clean road (after Mike's reference picture, 2026-10-30):
  - the asphalt: 5 m wide with straight, crisp edges, an even dark grey
    with a fine grain
  - markings: solid white edge lines just inside each edge, and short yellow
    centre dashes (DASH_M on, GAP_M off)
  - the verge: the field's grass (blades built like field_grass.py's: same
    colours, size and density) runs right up to the edge; past that the
    strip is transparent, so the real field shows through underneath
  - no shadow catcher: blades over the transparent part don't shade the
    field below, because the field's own grass has its shadows baked in and
    doubling them left a dark band along the verge

Damage (CONDITIONS) adds, more of it the worse the road: faded and
flaking paint, broader tone variation, worn wheel tracks and darker lane
centres, oil stains, repair patches, cracks (a broken one down the middle,
some across, a web along each edge, patches of crazed "alligator"
cracking), potholes, ragged crumbling edges, a gravel-and-dirt verge,
loose gravel and broken asphalt chunks, and grass growing in the cracks.

Lit by the standard sun (bs_common.py). The road turns with its path in the
game, which turns the baked lighting with it; the relief is kept low so
that doesn't show much (potholes are the deepest thing, a few cm).
"""

import math
import os
import sys

import bmesh
import bpy
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bs_common as bs  # noqa: E402
from bs_common import srgb  # noqa: E402
import field_grass as fg  # noqa: E402

# ---------------------------------------------------------------- settings --
ROOT = bs.ROOT
GRASS_TEX = os.path.join(ROOT, "assets", "textures", "field_grass_tile.png")
OUT_COMPARE = os.path.join(ROOT, "assets", "previews", "road_conditions_preview.png")
OUT_COMPARE_NO_CENTRE = os.path.join(ROOT, "assets", "previews", "road_conditions_no_centre_preview.png")


def out_paths(name, centre=True):
    """The texture, review preview and .blend for one condition, with or
    without its centre dashes."""
    suffix = ("" if name == "clean" else "_" + name) + ("" if centre else "_no_centre")
    return (os.path.join(ROOT, "assets", "textures", f"road_asphalt{suffix}.png"),
            os.path.join(ROOT, "assets", "previews", f"road_asphalt{suffix}_preview.png"),
            os.path.join(ROOT, "blender", "source", f"road_asphalt{suffix}.blend"))


SAMPLES = 96
RES_X = 1024                      # along the road; one grass tile's length
RES_Y = 512                       # across it
ROAD_LEN = RES_X / bs.PX_PER_M    # 12 m: the strip repeats every 12 m
STRIP_W = RES_Y / bs.PX_PER_M     # 6 m across, verges included
HALF = STRIP_W / 2
ROAD_HALF = 2.5                   # the asphalt is 5 m wide
LANE_Y = 1.25                     # lane centres, either side of the middle
GRASS_OUT_M = 0.45                # the verge's extra grass reaches this far past the edge
CLEAR_M = 0.08                    # nothing at all this close to the strip's edge
LIP_M = 0.01                      # the asphalt's height above the verge
GRID = ROAD_LEN / RES_X           # a vertex per pixel

DASH_M = 1.0                      # yellow centre dashes: this long...
GAP_M = 1.0                       # ...with this gap (DASH_M + GAP_M must divide ROAD_LEN)
CENTRE_W = 0.12                   # the dashes' width
EDGE_LINE_IN = 0.15               # white edge lines: this far in from the asphalt's edge...
EDGE_LINE_W = 0.12                # ...and this wide

ASPHALT = srgb(0.27, 0.27, 0.28)
ASPHALT_WORN = srgb(0.38, 0.38, 0.38)
PATCH = srgb(0.235, 0.235, 0.245)
STAIN = srgb(0.17, 0.17, 0.18)
CRACK = srgb(0.06, 0.06, 0.06)
POTHOLE = srgb(0.30, 0.27, 0.23)
YELLOW = srgb(0.93, 0.76, 0.18)
WHITE = srgb(0.92, 0.92, 0.90)
DIRT = srgb(0.40, 0.33, 0.23)
GRAVEL = srgb(0.50, 0.48, 0.44)
VERGE = fg.UNDERGROWTH            # under the blades at a tidy road's edge, as in the field

# How damaged each condition is. 0 or empty = none of that.
#   rag        how ragged the edges are (x a 7 cm wander and 2 cm crumbling)
#   tone       broad light/dark variation of the asphalt
#   tracks     worn lighter wheel tracks and darker lane centres (0..1)
#   edge_age   greyer, older asphalt along the edges (0..1)
#   wear       paint worn away (0..1), and `flake` of it flaked off in spots
#   stains     oil stains, patches (w, h in m), potholes (radius in m)
#   long_crack whether there's a broken crack down the middle
#   cross      cracks across the road; `web` short ones along the edges
#   alligator  patches of crazed cracking
#   tufts      share of points on the bigger cracks with grass growing out
#   dirt       how much the verge is gravel and dirt instead of grass (0..1)
#   gravel     loose stones along the edges; `chunks` broken-off asphalt
CONDITIONS = {
    "clean": dict(seed=11, rag=0.0, tone=0.03, tracks=0.0, edge_age=0.0, wear=0.0, flake=0.0,
                  stains=0, patches=[], potholes=[], long_crack=False, cross=0, web=0,
                  alligator=0, tufts=0.0, dirt=0.0, gravel=0, chunks=0),
    "ok": dict(seed=21, rag=0.12, tone=0.045, tracks=0.25, edge_age=0.15, wear=0.2, flake=0.04,
               stains=3, patches=[(1.0, 0.7)], potholes=[], long_crack=False, cross=2, web=8,
               alligator=0, tufts=0.0, dirt=0.15, gravel=150, chunks=0),
    "medium": dict(seed=31, rag=0.55, tone=0.06, tracks=0.6, edge_age=0.4, wear=0.65, flake=0.15,
                   stains=4, patches=[(1.3, 0.8), (0.7, 1.1)], potholes=[0.24],
                   long_crack=True, cross=4, web=30, alligator=1, tufts=0.03, dirt=0.5,
                   gravel=600, chunks=20),
    "bad": dict(seed=41, rag=1.2, tone=0.08, tracks=0.9, edge_age=0.8, wear=1.0, flake=0.35,
                stains=3, patches=[(1.4, 0.9), (0.8, 1.2)], potholes=[0.5, 0.38, 0.3, 0.22, 0.15],
                long_crack=True, cross=7, web=70, alligator=3, tufts=0.07, dirt=1.0,
                gravel=1500, chunks=80),
}

rng = None   # set per condition (setup()), so each strip is the same every run
CENTRE = True   # whether the strip being built has its yellow centre dashes
C = None     # the condition being built


# ------------------------------------------------------- periodic noise --
class StripNoise:
    """Sum of sine waves, periodic along x over ROAD_LEN (integer waves per
    strip) and free across y (unless `across` is off). Roughly mean 0,
    std 1. `kmax` is in waves per metre, so feature sizes don't depend on
    the strip's length."""

    def __init__(self, terms=40, kmax=3.0, falloff=1.0, across=True):
        nmax = max(1, round(kmax * ROAD_LEN))
        kx = rng.integers(-nmax, nmax + 1, terms).astype(np.float64)
        ky = rng.uniform(-kmax, kmax, terms) * ROAD_LEN if across else np.zeros(terms)
        kx[(kx == 0) & (ky == 0)] = 1
        self.kx, self.ky = kx, ky
        self.a = 1.0 / np.maximum(np.hypot(kx, ky), 1) ** falloff
        self.p = rng.uniform(0, 2 * np.pi, terms)
        self.norm = np.sqrt((self.a ** 2).sum() / 2)

    def __call__(self, x, y=0.0, chunk=200_000):
        x = np.asarray(x, dtype=np.float64).ravel() / ROAD_LEN
        y = np.broadcast_to(np.asarray(y, dtype=np.float64), x.shape).ravel() / ROAD_LEN
        out = np.empty(len(x))
        for s in range(0, len(x), chunk):
            phase = (2 * np.pi * (self.kx * x[s:s + chunk, None] + self.ky * y[s:s + chunk, None])
                     + self.p)
            out[s:s + chunk] = (self.a * np.sin(phase)).sum(-1)
        return out / self.norm


def setup(name):
    """Fresh random numbers and noise fields for one condition."""
    global rng, C, edge_low, edge_high, verge_width, tone, fine_tone, paint_wear, \
        dirt_mix, grass_patch, potholes
    C = CONDITIONS[name]
    rng = np.random.default_rng(C["seed"])
    edge_low = [StripNoise(terms=12, kmax=0.6, across=False) for _ in range(2)]
    edge_high = [StripNoise(terms=30, kmax=4.0, across=False) for _ in range(2)]
    verge_width = [StripNoise(terms=10, kmax=0.5, across=False) for _ in range(2)]
    tone = StripNoise(terms=40, kmax=0.8)
    fine_tone = StripNoise(terms=60, kmax=6.0)
    paint_wear = StripNoise(terms=60, kmax=5.0)
    dirt_mix = StripNoise(terms=40, kmax=3.0)
    grass_patch = StripNoise(terms=30, kmax=1.5)
    # Potholes: where, how big, and the shape of their rims. In the wheel
    # tracks and near the edges, where roads break up first.
    potholes = []
    for i, r in enumerate(C["potholes"]):
        lane = rng.choice([-1, 1])
        cy = lane * (LANE_Y + rng.choice([-0.8, 0.8, 0.95]) + rng.normal(0, 0.1))
        cy = float(np.clip(cy, -ROAD_HALF + r + 0.1, ROAD_HALF - r - 0.1))
        potholes.append(dict(x=(i + rng.uniform(0.2, 0.8)) * ROAD_LEN / len(C["potholes"]), y=cy,
                             r=r, depth=0.025 + 0.06 * r, waves=rng.uniform(0, 2 * np.pi, 3)))


def smoothstep(a, b, v):
    t = np.clip((v - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


def edge_y(side, x):
    """How far the asphalt reaches from the centre line on `side` (0 = +y,
    1 = -y) at x: straight on a tidy road, ragged on a damaged one."""
    e = ROAD_HALF + C["rag"] * (0.07 * edge_low[side](x) + 0.022 * edge_high[side](x))
    return e if np.ndim(x) else float(e[0])


def outside(x, y):
    """How far (m) past the asphalt edge on its own side a point is
    (negative = on the asphalt)."""
    e = np.where(y >= 0, edge_y(0, x), edge_y(1, x))
    return np.abs(y) - e


def wrap_dx(x, cx):
    """x - cx, wrapped into [-ROAD_LEN/2, ROAD_LEN/2): distance along the strip."""
    return (x - cx + ROAD_LEN / 2) % ROAD_LEN - ROAD_LEN / 2


def pothole_depth(x, y):
    """How far below the surface the ground is (0 outside every pothole), and
    how far into the nearest pothole each point is (0 at the rim, 1 middle)."""
    depth = np.zeros(len(x))
    inside = np.zeros(len(x))
    for h in potholes:
        dx, dy = wrap_dx(x, h["x"]), y - h["y"]
        a = np.arctan2(dy, dx)
        w = h["waves"]
        r = h["r"] * (1 + 0.2 * np.sin(3 * a + w[0]) + 0.12 * np.sin(5 * a + w[1])
                      + 0.06 * np.sin(9 * a + w[2]))
        t = np.clip(1 - np.hypot(dx, dy) / r, 0, 1)
        depth = np.maximum(depth, h["depth"] * smoothstep(0.0, 0.3, t))   # steep walls, flat floor
        inside = np.maximum(inside, t)
    return depth, inside


def ground_z(x, y):
    """Surface height: the asphalt stands LIP_M above the verge."""
    return LIP_M * (1 - smoothstep(0.0, 0.015, outside(x, y)))


# ------------------------------------------------------------- helpers --
def color_material(name, roughness, specular):
    """Vertex colour and alpha (attribute "Col") into a principled shader."""
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
    nt.links.new(attr.outputs["Alpha"], bsdf.inputs["Alpha"])
    bsdf.inputs["Roughness"].default_value = roughness
    if "Specular IOR Level" in bsdf.inputs:
        bsdf.inputs["Specular IOR Level"].default_value = specular
    return mat


def mesh_object(name, verts, faces, rgba, material, smooth=False):
    """Like field_grass.make_mesh_object(), with per-vertex alpha."""
    verts = np.asarray(verts, dtype=np.float32).reshape(-1, 3)
    faces = np.asarray(faces, dtype=np.int32)
    n_faces, corners = faces.shape
    me = bpy.data.meshes.new(name)
    me.vertices.add(len(verts))
    me.vertices.foreach_set("co", verts.ravel())
    me.loops.add(faces.size)
    me.loops.foreach_set("vertex_index", faces.ravel())
    me.polygons.add(n_faces)
    me.polygons.foreach_set("loop_start", np.arange(0, faces.size, corners, dtype=np.int32))
    me.update(calc_edges=True)
    attr = me.color_attributes.new("Col", "FLOAT_COLOR", "POINT")
    attr.data.foreach_set("color", np.asarray(rgba, dtype=np.float32).ravel())
    if smooth:
        me.shade_smooth()
    me.materials.append(material)
    obj = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(obj)
    return obj


# ------------------------------------------------------- road surface --
def build_surface(mat):
    """One grid over the whole strip (a vertex per pixel): asphalt, paint,
    stains, patches and potholes in the middle; past the edges undergrowth or
    dirt and gravel, fading out."""
    xs = (np.arange(-8, RES_X + 8) + 0.5) * GRID
    ys = np.linspace(-HALF - 0.05, HALF + 0.05, round((STRIP_W + 0.1) / GRID) + 1)
    gx, gy = np.meshgrid(xs, ys)
    gx, gy = gx.ravel(), gy.ravel()
    n = len(gx)
    out = outside(gx, gy)
    ay = np.abs(gy)

    # Asphalt: fine grain, broad variation, and (worn) polished wheel tracks,
    # darker lane centres and greyer old asphalt along the edges.
    shade = 1 + C["tone"] * tone(gx, gy) + 0.02 * fine_tone(gx, gy)
    grain = rng.uniform(0.9, 1.1, n)
    grain[rng.uniform(size=n) < 0.015 + 0.015 * C["tracks"]] *= 1.35
    col = ASPHALT[None, :] * (shade * grain)[:, None]
    lane_off = ay - LANE_Y
    tracks = C["tracks"] * 0.35 * np.exp(-((np.abs(lane_off) - 0.8) / 0.22) ** 2)[:, None]
    col = col * (1 - tracks) + ASPHALT_WORN * grain[:, None] * tracks
    col *= (1 - C["tracks"] * 0.12 * np.exp(-(lane_off / 0.3) ** 2))[:, None]
    age = C["edge_age"] * 0.4 * smoothstep(-0.5, 0.0, out)[:, None]
    col = col * (1 - age) + ASPHALT_WORN * grain[:, None] * age

    # Oil stains: soft dark blobs in the lane centres.
    for _ in range(C["stains"]):
        cx, cy = rng.uniform(0, ROAD_LEN), rng.choice([-1, 1]) * LANE_Y + rng.normal(0, 0.12)
        sx, sy = rng.uniform(0.25, 0.6), rng.uniform(0.12, 0.25)
        k = np.exp(-(wrap_dx(gx, cx) / sx) ** 2 - ((gy - cy) / sy) ** 2)[:, None] * 0.55
        col = col * (1 - k) + STAIN * grain[:, None] * k

    # Repair patches: darker, fresher rectangles. They go over old paint.
    patch_mask = np.zeros(n, dtype=bool)
    seam_mask = np.zeros(n, dtype=bool)
    for w, h in C["patches"]:
        cx = rng.uniform(0, ROAD_LEN)
        cy = rng.choice([-1, 1]) * rng.uniform(0.6, ROAD_HALF - h / 2 - 0.4)
        ex, ey = np.abs(wrap_dx(gx, cx)) - w / 2, np.abs(gy - cy) - h / 2
        patch_mask |= (ex < 0) & (ey < 0)
        seam_mask |= (np.maximum(ex, ey) > -0.015) & (np.maximum(ex, ey) < 0.01)

    # Paint: crisp on a tidy road; faded, worn through and flaking on a bad one.
    wear = paint_wear(gx, gy)
    strength = np.clip(1 - C["wear"] * (0.75 + 0.45 * wear), 0, 1)
    strength *= rng.uniform(size=n) > C["flake"]
    strength = strength[:, None] * rng.uniform(0.93, 1.03, (n, 1))
    dash = ((gx % (DASH_M + GAP_M)) < DASH_M) & (ay < CENTRE_W / 2)
    edge_line = (out > -EDGE_LINE_IN - EDGE_LINE_W) & (out < -EDGE_LINE_IN)
    for mask, paint in ((dash, YELLOW), (edge_line, WHITE)) if CENTRE else ((edge_line, WHITE),):
        mask = mask & ~patch_mask
        col[mask] = col[mask] * (1 - strength[mask]) + paint * strength[mask]
    col[patch_mask] = PATCH * (shade * grain)[patch_mask, None]
    col[seam_mask] = col[seam_mask] * 0.55   # the sealed join round each patch

    # Potholes: sunk into the surface, gritty broken stone at the bottom.
    depth, inside = pothole_depth(gx, gy)
    hole = inside > 0
    floor = (POTHOLE * rng.uniform(0.6, 1.3, (n, 1)))
    blend = smoothstep(0.0, 0.25, inside)[:, None]
    col[hole] = col[hole] * (1 - blend[hole]) + floor[hole] * blend[hole]

    # Past the edge: undergrowth on a tidy road; gravel then dirt on a worn
    # one, reaching further out. Then transparent.
    verge = out > 0
    mix = np.clip(0.5 + 0.35 * dirt_mix(gx, gy) - out / 0.5 * 0.6, 0, 1)[:, None]
    dirt_col = (GRAVEL * mix + DIRT * (1 - mix)) * rng.uniform(0.8, 1.2, (n, 1))
    plain = VERGE * rng.uniform(0.8, 1.2, (n, 1))
    col[verge] = (plain * (1 - C["dirt"]) + dirt_col * C["dirt"])[verge]
    side_w = np.where(gy >= 0, verge_width[0](gx), verge_width[1](gx))
    reach = 0.2 + C["dirt"] * 0.35 * (1 + 0.35 * side_w)
    alpha = 1 - smoothstep(0.0, reach, out + C["dirt"] * 0.08 * fine_tone(gx, gy))
    alpha = np.where(verge, alpha, 1.0)
    alpha *= 1 - smoothstep(HALF - 0.3, HALF - CLEAR_M, ay)

    nx, ny = len(xs), len(ys)
    verts = np.column_stack([gx, gy, ground_z(gx, gy) - depth])
    r, c = np.meshgrid(np.arange(ny - 1), np.arange(nx - 1), indexing="ij")
    i = (r * nx + c).ravel()
    faces = np.column_stack([i, i + 1, i + nx + 1, i + nx])
    mesh_object("Road", verts, faces, np.column_stack([col, alpha]), mat)


# ----------------------------------------------------------------- cracks --
def walk(start, heading, length, step=0.05, wobble=0.25):
    """A crack's path: a random walk from `start` that keeps roughly to `heading`."""
    pts = [np.array(start, dtype=np.float64)]
    a = heading
    for _ in range(max(2, int(length / step))):
        a += rng.normal(0, wobble) - 0.15 * math.sin(a - heading)   # drifts back toward the heading
        pts.append(pts[-1] + step * np.array([math.cos(a), math.sin(a)]))
    return np.array(pts)


def build_cracks(mat, tufts):
    """Dark strips along random-walk paths; some get grass growing out of them."""
    paths = []
    if C["long_crack"]:   # one long wandering crack near the middle, in broken pieces
        x = 0.0
        while x < ROAD_LEN:
            seg = rng.uniform(1.2, 3.5)
            paths.append((walk((x, rng.uniform(-0.45, 0.45)), 0.0, seg, wobble=0.12), 0.016))
            x += seg + rng.uniform(0.4, 2.0) * (1.5 - C["tracks"])
    for _ in range(C["cross"]):   # across the road, from an edge part way in
        side = rng.choice([-1, 1])
        x0 = rng.uniform(0, ROAD_LEN)
        start = (x0, side * edge_y(0 if side > 0 else 1, x0))
        length = rng.uniform(0.6, 1.2 + 2.4 * C["tracks"])
        paths.append((walk(start, -side * math.pi / 2, length, wobble=0.18),
                      0.010 + 0.006 * C["tracks"]))
    for side in (1, -1):          # a web of short cracks along each edge
        for _ in range(C["web"]):
            x0 = rng.uniform(0, ROAD_LEN)
            y0 = side * (edge_y(0 if side > 0 else 1, x0) - rng.uniform(0.03, 0.55))
            paths.append((walk((x0, y0), rng.uniform(0, 2 * math.pi), rng.uniform(0.12, 0.45),
                               step=0.03, wobble=0.5), 0.010))
    for _ in range(C["alligator"]):   # crazed patches in a wheel track
        cx = rng.uniform(0, ROAD_LEN)
        cy = rng.choice([-1, 1]) * (LANE_Y + rng.choice([-0.8, 0.8]))
        rx, ry = rng.uniform(0.5, 1.0), rng.uniform(0.3, 0.5)
        for _ in range(int(70 * rx * ry)):
            a = rng.uniform(0, 2 * math.pi)
            d = math.sqrt(rng.uniform())
            start = (cx + rx * d * math.cos(a), cy + ry * d * math.sin(a))
            paths.append((walk(start, rng.uniform(0, 2 * math.pi), rng.uniform(0.08, 0.2),
                               step=0.025, wobble=0.6), 0.009))
    if not paths:
        return

    verts, faces = [], []
    for pts, width in paths:
        for shift in (-ROAD_LEN, 0.0, ROAD_LEN):
            p = pts + np.array([shift, 0.0])
            if p[:, 0].max() < -0.5 or p[:, 0].min() > ROAD_LEN + 0.5:
                continue
            d = np.gradient(p, axis=0)
            d /= np.linalg.norm(d, axis=1, keepdims=True)
            nrm = np.column_stack([-d[:, 1], d[:, 0]])
            # Wider in the middle of the crack, closing up at the ends.
            w = width * rng.uniform(0.7, 1.3, len(p)) * np.sin(np.linspace(0.15, math.pi - 0.15, len(p)))
            z = ground_z(p[:, 0], p[:, 1]) + 0.0008
            start = len(verts)
            for k in range(len(p)):
                verts.append((*(p[k] + nrm[k] * w[k] / 2), z[k]))
                verts.append((*(p[k] - nrm[k] * w[k] / 2), z[k]))
            for k in range(len(p) - 1):
                a = start + 2 * k
                faces.append((a, a + 1, a + 3, a + 2))
        # Grass in the bigger cracks now and then.
        if width > 0.012 and C["tufts"] > 0:
            for k in rng.choice(len(pts), size=int(len(pts) * C["tufts"]) + 1, replace=False):
                tufts.append(pts[k])
    n = len(verts)
    rgba = np.column_stack([np.tile(CRACK, (n, 1)) * rng.uniform(0.8, 1.2, (n, 1)), np.ones(n)])
    mesh_object("Cracks", verts, faces, rgba, mat)
    print(f"Cracks: {len(paths)}")


# ------------------------------------------------------------------ grass --
def blade_mesh(x, y, mat):
    """Grass blades rooted at (x, y), built like field_grass.build_grass():
    same colours, lengths, widths and shading; leaning every which way."""
    count = len(x)
    z0 = ground_z(x, y)
    lush = grass_patch(x, y)
    dryness = np.clip(0.2 - 0.4 * lush + rng.normal(0, 0.08, count), 0, 1)[:, None]
    deep = rng.uniform(0, 1, count)[:, None]
    color = fg.GRASS_LUSH * (1 - deep) + fg.GRASS_DEEP * deep
    color = color * (1 - dryness) + fg.GRASS_DRY * dryness
    color *= rng.uniform(0.85, 1.15, (count, 1))
    length = rng.uniform(0.018, 0.045, count) * (0.85 + 0.25 * np.clip(lush, -1, 1)) * fg.BLADE_SCALE
    lean = rng.uniform(0.35, 0.95, count)
    width = rng.uniform(0.0025, 0.0045, count) * fg.BLADE_SCALE
    theta = rng.uniform(0, 2 * np.pi, count)
    reach = length * lean
    height = length * np.sqrt(1 - lean ** 2)
    d = np.column_stack([np.cos(theta), np.sin(theta)])
    nrm = np.column_stack([-d[:, 1], d[:, 0]])
    p0 = np.column_stack([x, y])
    hw = (width / 2)[:, None]

    def pt(xy, z):
        return np.column_stack([xy, z0 + z])

    v = np.stack([
        pt(p0 - nrm * hw, np.zeros(count)),
        pt(p0 + nrm * hw, np.zeros(count)),
        pt(p0 + d * (reach * 0.35)[:, None] - nrm * hw * 0.8, height * 0.65),
        pt(p0 + d * (reach * 0.35)[:, None] + nrm * hw * 0.8, height * 0.65),
        pt(p0 + d * reach[:, None], height),
    ], axis=1)
    shade = np.array([0.35, 0.35, 0.8, 0.8, 1.1])[None, :, None]
    c = color[:, None, :] * shade
    # Copy blades near either end onto the other end, so the strip tiles.
    all_v, all_c = [v], [c]
    for shift in (-ROAD_LEN, ROAD_LEN):
        sel = (x + shift > -0.15) & (x + shift < ROAD_LEN + 0.15)
        moved = v[sel].copy()
        moved[:, :, 0] += shift
        all_v.append(moved)
        all_c.append(c[sel])
    verts = np.concatenate(all_v)
    cols = np.concatenate(all_c).reshape(-1, 3)
    tri = np.array([[0, 1, 3], [0, 3, 2], [2, 3, 4]])
    faces = (tri[None] + 5 * np.arange(len(verts))[:, None, None]).reshape(-1, 3)
    mesh_object("Grass", verts.reshape(-1, 3), faces, np.column_stack([cols, np.ones(len(cols))]), mat)
    return count


def build_grass(mat, tufts):
    """The verges: field density from the asphalt's edge (just onto it on a
    worn road), thinning out into the field's own grass below; plus tufts
    in cracks."""
    per_m2 = fg.BLADES / fg.TILE ** 2
    band = HALF - ROAD_HALF + 0.3
    cand_n = int(per_m2 * ROAD_LEN * band * 2 * 1.1)
    x = rng.uniform(0, ROAD_LEN, cand_n)
    y = rng.choice([-1, 1], cand_n) * rng.uniform(ROAD_HALF - 0.3, HALF, cand_n)
    out = outside(x, y)
    wobble = (0.06 + 0.06 * C["dirt"]) * grass_patch(x, y)
    start = -0.04 * C["dirt"]
    keep = (smoothstep(start, start + 0.05 + 0.15 * C["dirt"], out + wobble)
            * (1 - smoothstep(GRASS_OUT_M * 0.5, GRASS_OUT_M + 0.3 * C["dirt"], out + wobble)))
    keep *= 1 - smoothstep(HALF - 0.4, HALF - CLEAR_M - 0.04, np.abs(y))
    sel = rng.uniform(size=cand_n) < keep
    x, y = x[sel], y[sel]
    tx, ty = [], []
    for p in tufts:
        k = rng.integers(5, 14)
        tx.append(p[0] + rng.normal(0, 0.012, k))
        ty.append(p[1] + rng.normal(0, 0.012, k))
    x = np.concatenate([x] + tx) % ROAD_LEN
    y = np.concatenate([y] + ty)
    n = blade_mesh(x, y, mat)
    print(f"Grass: {n} blades ({sum(len(t) for t in tx)} in crack tufts)")


# ------------------------------------------------------- gravel & chunks --
def build_stones(mat):
    """Loose gravel along the edges and in potholes, and broken-off flakes of
    asphalt."""
    verts, faces, cols = [], [], []

    def stone(cx, cy, r, flat, tint, z0=None):
        bm = bmesh.new()
        bmesh.ops.create_icosphere(bm, subdivisions=1, radius=1.0)
        sx, sy = rng.uniform(0.7, 1.3, 2)
        rot = rng.uniform(0, 2 * np.pi)
        if z0 is None:
            z0 = float(ground_z(np.array([cx]), np.array([cy]))[0])
        for shift in (-ROAD_LEN, 0.0, ROAD_LEN):
            if not -0.1 < cx + shift < ROAD_LEN + 0.1:
                continue
            start = len(verts)
            for v in bm.verts:
                px, py, pz = v.co * rng.uniform(0.85, 1.15)
                px, py = px * sx * r, py * sy * r
                verts.append((cx + shift + px * math.cos(rot) - py * math.sin(rot),
                              cy + px * math.sin(rot) + py * math.cos(rot),
                              z0 + max(pz, -0.2) * r * flat + r * 0.05))
                cols.append(tint * (0.7 + 0.3 * max(pz, 0)))
            faces.extend(tuple(start + v.index for v in f.verts) for f in bm.faces)
        bm.free()

    for _ in range(C["gravel"]):
        side = rng.choice([-1, 1])
        x = rng.uniform(0, ROAD_LEN)
        off = rng.gamma(1.5, 0.08 + 0.06 * C["dirt"]) - 0.08   # mostly just past the edge
        y = side * min(edge_y(0 if side > 0 else 1, x) + off, HALF - CLEAR_M - 0.05)
        stone(x, y, rng.uniform(0.006, 0.016), 0.5, GRAVEL * rng.uniform(0.7, 1.2))
    for _ in range(C["chunks"]):
        side = rng.choice([-1, 1])
        x = rng.uniform(0, ROAD_LEN)
        y = side * (edge_y(0 if side > 0 else 1, x) + rng.uniform(0.02, 0.25))
        stone(x, y, rng.uniform(0.025, 0.06), 0.18, ASPHALT * rng.uniform(0.9, 1.3))
    for h in potholes:   # broken stone in the bottom of each pothole
        for _ in range(int(250 * h["r"] ** 2) + 3):
            a, d = rng.uniform(0, 2 * math.pi), h["r"] * 0.75 * math.sqrt(rng.uniform())
            stone((h["x"] + d * math.cos(a)) % ROAD_LEN, h["y"] + d * math.sin(a),
                  rng.uniform(0.008, 0.02), 0.5, GRAVEL * rng.uniform(0.6, 1.1),
                  z0=LIP_M - h["depth"])
    if verts:
        rgba = np.column_stack([np.array(cols), np.ones(len(cols))])
        mesh_object("Stones", verts, np.array(faces), rgba, mat, smooth=True)


# ----------------------------------------------------------------- main --
def load_pixels(path):
    img = bpy.data.images.load(path, check_existing=False)
    w, h = img.size
    px = np.empty(w * h * 4, dtype=np.float32)
    img.pixels.foreach_get(px)
    return px.reshape(h, w, 4)


def over_grass(strips):
    """The given strips laid twice end to end, stacked over the grass, to
    check the ends meet and the verges blend into the field."""
    road_h = RES_Y
    rows = road_h * len(strips)
    tile = load_pixels(GRASS_TEX)
    grass = np.tile(tile, (rows // tile.shape[0] + 2, 2, 1))
    y0 = (grass.shape[0] - rows) // 2
    # Pixel rows run bottom-up, so the first strip goes in the top band.
    for k, path in enumerate(reversed(strips)):
        road = np.tile(load_pixels(path), (1, 2, 1))
        a = road[:, :, 3:4]
        band = grass[y0 + k * road_h:y0 + (k + 1) * road_h]
        band[:, :, :3] = road[:, :, :3] * a + band[:, :, :3] * (1 - a)
    pad = max(0, y0 - road_h // 2)
    return grass[pad:grass.shape[0] - pad]


def save_image(px, dst):
    out = bpy.data.images.new("out", px.shape[1], px.shape[0], alpha=True)
    out.pixels.foreach_set(px.ravel())
    out.filepath_raw = dst
    out.file_format = "PNG"
    out.save()
    print("Saved", dst)


def fade_edges(path, fade_px=10):
    """Fade the strip's outermost rows to fully transparent, so nothing
    (a stray blade tip, render noise) can end in a hard line along its edge."""
    px = load_pixels(path)
    rows = np.arange(px.shape[0], dtype=np.float64)
    to_edge = np.minimum(rows, px.shape[0] - 1 - rows)
    px[:, :, 3] *= smoothstep(0.0, fade_px, to_edge)[:, None]
    save_image(px, path)


def build(name, centre=True):
    """Render one strip. Without its centre dashes it's otherwise the same
    (same seed and damage), and only the texture is saved."""
    global CENTRE
    CENTRE = centre
    tex, preview, blend = out_paths(name, centre)
    for path in (tex, preview, blend):
        os.makedirs(os.path.dirname(path), exist_ok=True)
    setup(name)
    scene = bs.new_scene(center=(ROAD_LEN / 2, 0.0), frame_m=ROAD_LEN, transparent=True,
                         samples=SAMPLES)
    scene.render.resolution_x = RES_X   # ortho_scale spans the wider side (the length)
    scene.render.resolution_y = RES_Y
    road_mat = color_material("Asphalt", roughness=0.85, specular=0.25)
    tufts = []
    build_surface(road_mat)
    build_cracks(road_mat, tufts)
    build_grass(color_material("Grass", roughness=0.65, specular=0.2), tufts)
    build_stones(road_mat)
    if centre:
        bpy.ops.wm.save_as_mainfile(filepath=blend)
    bs.render_to(scene, tex)
    fade_edges(tex)
    if centre:
        save_image(over_grass([tex]), preview)


def main():
    assert abs(ROAD_LEN / (DASH_M + GAP_M) - round(ROAD_LEN / (DASH_M + GAP_M))) < 1e-6, \
        "the dash pattern must fit the strip a whole number of times, or the ends won't meet"
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    names = [a for a in args if a in CONDITIONS] or list(CONDITIONS)
    for name in names:
        for centre in (True, False):
            print(f"--- {name}{'' if centre else ' (no centre line)'} ---")
            build(name, centre)
    for centre, dst in ((True, OUT_COMPARE), (False, OUT_COMPARE_NO_CENTRE)):
        strips = [out_paths(n, centre)[0] for n in CONDITIONS]
        save_image(over_grass([t for t in strips if os.path.exists(t)]), dst)


if __name__ == "__main__":
    main()
