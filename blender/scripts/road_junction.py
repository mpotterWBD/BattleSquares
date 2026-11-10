"""Generate top-down road junction tiles for Battle Squares: a T and a
crossroads (4-way), in the same four conditions as the road strips
(road_asphalt.py: clean, ok, medium, bad), to join them (scripts/road_junction.gd).

Run headless (all, or just the conditions named):
    blender --background --python road_junction.py
    blender --background --python road_junction.py -- clean bad

Each tile is TILE metres square (1024 x 1024 px, the strip's density), centred
on the crossing. Its arms run to the tile's edges, where a strip carries on:
the asphalt there is the strip's 5 m wide, with its white edge lines and its
verge, so a road laid up to an arm's end meets it. Through the junction:
  - the asphalt is the union of a band along x (the through road) and one
    along y (both ways for the crossroads; for the T only toward -y, the
    image's bottom, which is +y, down, in the game), with the inside corners
    rounded off (FILLET_M)
  - the white edge lines follow the asphalt's edge round those corners, and
    stop at each opening; there are no yellow centre dashes in the junction
    (a road's own dashes stop where it meets it)
  - everything else (the asphalt's tone and grain, worn tracks, stains,
    patches, potholes, cracks, the verge's grass, dirt and gravel) is made as
    the strip makes it (road_asphalt.py, whose noise, colours and settings it
    uses), worked from how far each point is past the asphalt's edge
    (`outside()`) instead of from the strip's straight sides.

The strips repeat every 12 m, and a road can end anywhere along that, so a
damaged junction's ragged edge, cracks and wear can't line up exactly with
the road meeting it; the edge's line, the paint and the verge do.

Also writes previews (assets/previews/road_junction_*_preview.png): each tile
over the field with a strip of the same condition on every arm, to check the
joins.
"""

import math
import os
import sys

import bmesh
import bpy
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bs_common as bs  # noqa: E402
import field_grass as fg  # noqa: E402
import road_asphalt as ra  # noqa: E402

ROOT = bs.ROOT
TILE = 12.0                   # metres square
RES = 1024                    # pixels square (the strip's density: 1024 px = 12 m)
HALF_T = TILE / 2
GRID = TILE / RES
FILLET_M = 2.0                # the inside corners' radius
KINDS = ("t", "cross")
SAMPLES = 96
NOISE_SHIFT = 3.7             # the cross band's edge noise: the along band's, read this far off (so they differ)

KIND = "cross"


def out_path(kind, name, folder="textures", extra=""):
    suffix = "" if name == "clean" else "_" + name
    ext = ".png"
    sub = os.path.join(ROOT, "assets", folder)
    return os.path.join(sub, f"road_junction_{kind}{suffix}{extra}{ext}")


# ------------------------------------------------------------- geometry --
def has_cross_arm(y):
    """Whether the band across (along y) is there at y: everywhere for the
    crossroads, only toward -y for the T."""
    return np.ones_like(y, dtype=bool) if KIND == "cross" else (y <= 0.0)


def outside(x, y):
    """How far (m) past the asphalt's edge a point is (negative: on it)."""
    x = np.asarray(x, dtype=np.float64)
    y = np.asarray(y, dtype=np.float64)
    C = ra.C
    rag = C["rag"]
    e_up = ra.ROAD_HALF + rag * (0.07 * ra.edge_low[0](x) + 0.022 * ra.edge_high[0](x))
    e_dn = ra.ROAD_HALF + rag * (0.07 * ra.edge_low[1](x) + 0.022 * ra.edge_high[1](x))
    along = np.where(y >= 0, y - e_up, -y - e_dn)
    e_rt = ra.ROAD_HALF + rag * (0.07 * ra.edge_low[1](y + NOISE_SHIFT) + 0.022 * ra.edge_high[1](y + NOISE_SHIFT))
    e_lt = ra.ROAD_HALF + rag * (0.07 * ra.edge_low[0](y + NOISE_SHIFT) + 0.022 * ra.edge_high[0](y + NOISE_SHIFT))
    across = np.where(x >= 0, x - e_rt, -x - e_lt)
    arm = has_cross_arm(y)
    across = np.where(arm, across, 1e3)
    # The rounded inside corners: between the two bands' edges and an arc.
    px = np.abs(x) - ra.ROAD_HALF
    py = np.abs(y) - ra.ROAD_HALF
    to_arc = np.hypot(FILLET_M - px, FILLET_M - py) - FILLET_M   # (+: past the arc, on the asphalt)
    near = (px < FILLET_M) & (py < FILLET_M) & arm              # the corner's square (and the bands beside it)
    zone = near & (px > 0) & (py > 0)
    corner = np.where(zone, -to_arc, 1e3)
    wobble = rag * 0.05 * ra.edge_high[0](x + y)   # (a little of the bands' raggedness on the corners too)
    # Off the asphalt: the nearest of the bands' edges and the arcs.
    off = np.minimum(np.minimum(along, across), corner + wobble)
    # On it: how far in from its real outline. A band's edge isn't the outline
    # where a corner's rounded off beside it, or where the other road opens out
    # of it: there the arc is (so the edge lines follow the corners round and
    # stop at the openings, rather than running on to a square corner).
    big = np.full(np.shape(x), 1e3)
    along_edge = np.where(arm & (np.abs(x) < ra.ROAD_HALF + FILLET_M), big, np.abs(along))
    across_edge = np.where(arm & (np.abs(y) > ra.ROAD_HALF + FILLET_M), np.abs(across), big)
    arc_edge = np.where(near, np.abs(to_arc + wobble), big)
    depth = np.minimum(np.minimum(along_edge, across_edge), arc_edge)
    return np.where(off < 0, -depth, off)


def lateral(x, y, out):
    """What the strip's distance from its centre line is here (its verge fades
    out by it): along an arm, as the strip has it, so they meet; in the
    middle, by the distance from the asphalt."""
    ax, ay = np.abs(x), np.abs(y)
    reach = ra.ROAD_HALF + FILLET_M
    return np.where(ax > reach, ay, np.where((ay > reach) & has_cross_arm(y), ax, out + ra.ROAD_HALF))


def lane_offset(x, y):
    """The distance from the middle of the road being driven (for the worn
    tracks): the through road's in the middle and along its arms, the cross
    road's along its."""
    ax, ay = np.abs(x), np.abs(y)
    return np.where((ay > ax) & has_cross_arm(y), ax, ay)


def ground_z(x, y):
    return ra.LIP_M * (1 - ra.smoothstep(0.0, 0.015, outside(x, y)))


def asphalt_points(n, inside=-0.5):
    """`n` random points at least `-inside` m in on the asphalt."""
    if n <= 0:
        return np.zeros((0, 2))
    pts = []
    while sum(len(p) for p in pts) < n:
        x = ra.rng.uniform(-HALF_T, HALF_T, n * 4)
        y = ra.rng.uniform(-HALF_T, HALF_T, n * 4)
        keep = outside(x, y) < inside
        pts.append(np.column_stack([x[keep], y[keep]]))
    return np.concatenate(pts)[:n]


def band_points(n, lo, hi):
    """`n` random points between `lo` and `hi` m past the asphalt's edge, inside the tile."""
    if n <= 0:
        return np.zeros((0, 2))
    pts = []
    tries = 0
    while sum(len(p) for p in pts) < n and tries < 200:
        tries += 1
        x = ra.rng.uniform(-HALF_T, HALF_T, n * 8 + 64)
        y = ra.rng.uniform(-HALF_T, HALF_T, n * 8 + 64)
        o = outside(x, y)
        keep = (o > lo) & (o < hi)
        pts.append(np.column_stack([x[keep], y[keep]]))
    return np.concatenate(pts)[:n] if pts else np.zeros((0, 2))


# ------------------------------------------------------------- surface --
potholes = []


def pothole_depth(x, y):
    depth = np.zeros(len(x))
    inside = np.zeros(len(x))
    for h in potholes:
        dx, dy = x - h["x"], y - h["y"]
        a = np.arctan2(dy, dx)
        w = h["waves"]
        r = h["r"] * (1 + 0.2 * np.sin(3 * a + w[0]) + 0.12 * np.sin(5 * a + w[1]) + 0.06 * np.sin(9 * a + w[2]))
        t = np.clip(1 - np.hypot(dx, dy) / r, 0, 1)
        depth = np.maximum(depth, h["depth"] * ra.smoothstep(0.0, 0.3, t))
        inside = np.maximum(inside, t)
    return depth, inside


def build_surface(mat):
    """As road_asphalt.build_surface(), over the junction's square."""
    global potholes
    C, rng = ra.C, ra.rng
    xs = (np.arange(-4, RES + 4) + 0.5) * GRID - HALF_T
    gx, gy = np.meshgrid(xs, xs)
    gx, gy = gx.ravel(), gy.ravel()
    n = len(gx)
    out = outside(gx, gy)
    lat = lateral(gx, gy, out)

    shade = 1 + C["tone"] * ra.tone(gx, gy) + 0.02 * ra.fine_tone(gx, gy)
    grain = rng.uniform(0.9, 1.1, n)
    grain[rng.uniform(size=n) < 0.015 + 0.015 * C["tracks"]] *= 1.35
    col = ra.ASPHALT[None, :] * (shade * grain)[:, None]
    lane_off = lane_offset(gx, gy) - ra.LANE_Y
    tracks = C["tracks"] * 0.35 * np.exp(-((np.abs(lane_off) - 0.8) / 0.22) ** 2)[:, None]
    col = col * (1 - tracks) + ra.ASPHALT_WORN * grain[:, None] * tracks
    col *= (1 - C["tracks"] * 0.12 * np.exp(-(lane_off / 0.3) ** 2))[:, None]
    age = C["edge_age"] * 0.4 * ra.smoothstep(-0.5, 0.0, out)[:, None]
    col = col * (1 - age) + ra.ASPHALT_WORN * grain[:, None] * age

    for cx, cy in asphalt_points(C["stains"], -0.8):
        sx, sy = rng.uniform(0.25, 0.6), rng.uniform(0.12, 0.25)
        a = rng.uniform(0, math.pi)
        dx, dy = gx - cx, gy - cy
        u, v = dx * math.cos(a) + dy * math.sin(a), -dx * math.sin(a) + dy * math.cos(a)
        k = np.exp(-(u / sx) ** 2 - (v / sy) ** 2)[:, None] * 0.55
        col = col * (1 - k) + ra.STAIN * grain[:, None] * k

    patch_mask = np.zeros(n, dtype=bool)
    seam_mask = np.zeros(n, dtype=bool)
    for w, h in C["patches"]:
        cx, cy = asphalt_points(1, -max(w, h) / 2 - 0.4)[0]
        ex, ey = np.abs(gx - cx) - w / 2, np.abs(gy - cy) - h / 2
        patch_mask |= (ex < 0) & (ey < 0)
        seam_mask |= (np.maximum(ex, ey) > -0.015) & (np.maximum(ex, ey) < 0.01)

    wear = ra.paint_wear(gx, gy)
    strength = np.clip(1 - C["wear"] * (0.75 + 0.45 * wear), 0, 1)
    strength *= rng.uniform(size=n) > C["flake"]
    strength = strength[:, None] * rng.uniform(0.93, 1.03, (n, 1))
    edge_line = (out > -ra.EDGE_LINE_IN - ra.EDGE_LINE_W) & (out < -ra.EDGE_LINE_IN) & ~patch_mask
    col[edge_line] = col[edge_line] * (1 - strength[edge_line]) + ra.WHITE * strength[edge_line]
    col[patch_mask] = ra.PATCH * (shade * grain)[patch_mask, None]
    col[seam_mask] = col[seam_mask] * 0.55

    potholes = []
    for r in C["potholes"]:
        cx, cy = asphalt_points(1, -r - 0.35)[0]
        potholes.append(dict(x=cx, y=cy, r=r, depth=0.025 + 0.06 * r, waves=rng.uniform(0, 2 * np.pi, 3)))
    depth, inside = pothole_depth(gx, gy)
    hole = inside > 0
    floor = ra.POTHOLE * rng.uniform(0.6, 1.3, (n, 1))
    blend = ra.smoothstep(0.0, 0.25, inside)[:, None]
    col[hole] = col[hole] * (1 - blend[hole]) + floor[hole] * blend[hole]

    verge = out > 0
    mix = np.clip(0.5 + 0.35 * ra.dirt_mix(gx, gy) - out / 0.5 * 0.6, 0, 1)[:, None]
    dirt_col = (ra.GRAVEL * mix + ra.DIRT * (1 - mix)) * rng.uniform(0.8, 1.2, (n, 1))
    plain = ra.VERGE * rng.uniform(0.8, 1.2, (n, 1))
    col[verge] = (plain * (1 - C["dirt"]) + dirt_col * C["dirt"])[verge]
    side_w = ra.verge_width[0](gx + gy)
    reach = 0.2 + C["dirt"] * 0.35 * (1 + 0.35 * side_w)
    alpha = 1 - ra.smoothstep(0.0, reach, out + C["dirt"] * 0.08 * ra.fine_tone(gx, gy))
    alpha = np.where(verge, alpha, 1.0)
    alpha *= 1 - ra.smoothstep(ra.HALF - 0.3, ra.HALF - ra.CLEAR_M, lat)

    nx = len(xs)
    verts = np.column_stack([gx, gy, ground_z(gx, gy) - depth])
    r, c = np.meshgrid(np.arange(nx - 1), np.arange(nx - 1), indexing="ij")
    i = (r * nx + c).ravel()
    faces = np.column_stack([i, i + 1, i + nx + 1, i + nx])
    ra.mesh_object("Road", verts, faces, np.column_stack([col, alpha]), mat)


# ------------------------------------------------------------- cracks --
def build_cracks(mat, tufts):
    C, rng = ra.C, ra.rng
    paths = []
    if C["long_crack"]:   # down the through road's middle, in pieces
        x = -HALF_T
        while x < HALF_T:
            seg = rng.uniform(1.2, 3.5)
            paths.append((ra.walk((x, rng.uniform(-0.45, 0.45)), 0.0, seg, wobble=0.12), 0.016))
            x += seg + rng.uniform(0.4, 2.0) * (1.5 - C["tracks"])
    for p in band_points(C["cross"], -0.05, -0.01):   # in from the edge
        heading = math.atan2(-p[1], -p[0]) + rng.normal(0, 0.4)   # (roughly toward the middle)
        length = rng.uniform(0.6, 1.2 + 2.4 * C["tracks"])
        paths.append((ra.walk(p, heading, length, wobble=0.18), 0.010 + 0.006 * C["tracks"]))
    for p in band_points(C["web"] * 2, -0.55, -0.03):   # short ones along the edges
        paths.append((ra.walk(p, rng.uniform(0, 2 * math.pi), rng.uniform(0.12, 0.45), step=0.03, wobble=0.5), 0.010))
    for centre in asphalt_points(C["alligator"], -1.0):
        rx, ry = rng.uniform(0.5, 1.0), rng.uniform(0.3, 0.5)
        for _ in range(int(70 * rx * ry)):
            a = rng.uniform(0, 2 * math.pi)
            d = math.sqrt(rng.uniform())
            start = (centre[0] + rx * d * math.cos(a), centre[1] + ry * d * math.sin(a))
            paths.append((ra.walk(start, rng.uniform(0, 2 * math.pi), rng.uniform(0.08, 0.2), step=0.025, wobble=0.6), 0.009))
    verts, faces = [], []
    for pts, width in paths:
        keep = outside(pts[:, 0], pts[:, 1]) < -0.02   # (cracks stay on the asphalt)
        if keep.sum() < 3:
            continue
        p = pts[keep]
        d = np.gradient(p, axis=0)
        d /= np.maximum(np.linalg.norm(d, axis=1, keepdims=True), 1e-9)
        nrm = np.column_stack([-d[:, 1], d[:, 0]])
        w = width * rng.uniform(0.7, 1.3, len(p)) * np.sin(np.linspace(0.15, math.pi - 0.15, len(p)))
        z = ground_z(p[:, 0], p[:, 1]) + 0.0008
        start = len(verts)
        for k in range(len(p)):
            verts.append((*(p[k] + nrm[k] * w[k] / 2), z[k]))
            verts.append((*(p[k] - nrm[k] * w[k] / 2), z[k]))
        for k in range(len(p) - 1):
            a = start + 2 * k
            faces.append((a, a + 1, a + 3, a + 2))
        if width > 0.012 and C["tufts"] > 0:
            for k in rng.choice(len(p), size=int(len(p) * C["tufts"]) + 1, replace=False):
                tufts.append(p[k])
    if not verts:
        return
    n = len(verts)
    rgba = np.column_stack([np.tile(ra.CRACK, (n, 1)) * rng.uniform(0.8, 1.2, (n, 1)), np.ones(n)])
    ra.mesh_object("Cracks", verts, faces, rgba, mat)
    print(f"Cracks: {len(paths)}")


# -------------------------------------------------------------- grass --
def blade_mesh(x, y, mat):
    """As road_asphalt.blade_mesh(), without copying blades across the strip's ends."""
    rng = ra.rng
    count = len(x)
    z0 = ground_z(x, y)
    lush = ra.grass_patch(x, y)
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
    cols = (color[:, None, :] * shade).reshape(-1, 3)
    tri = np.array([[0, 1, 3], [0, 3, 2], [2, 3, 4]])
    faces = (tri[None] + 5 * np.arange(count)[:, None, None]).reshape(-1, 3)
    ra.mesh_object("Grass", v.reshape(-1, 3), faces, np.column_stack([cols, np.ones(len(cols))]), mat)
    return count


def build_grass(mat, tufts):
    C, rng = ra.C, ra.rng
    per_m2 = fg.BLADES / fg.TILE ** 2
    cand_n = int(per_m2 * TILE * TILE * 1.1)
    x = rng.uniform(-HALF_T, HALF_T, cand_n)
    y = rng.uniform(-HALF_T, HALF_T, cand_n)
    out = outside(x, y)
    near = (out > -0.3) & (out < 1.0)
    x, y, out = x[near], y[near], out[near]
    wobble = (0.06 + 0.06 * C["dirt"]) * ra.grass_patch(x, y)
    start = -0.04 * C["dirt"]
    keep = (ra.smoothstep(start, start + 0.05 + 0.15 * C["dirt"], out + wobble)
            * (1 - ra.smoothstep(ra.GRASS_OUT_M * 0.5, ra.GRASS_OUT_M + 0.3 * C["dirt"], out + wobble)))
    keep *= 1 - ra.smoothstep(ra.HALF - 0.4, ra.HALF - ra.CLEAR_M - 0.04, lateral(x, y, out))
    sel = rng.uniform(size=len(x)) < keep
    x, y = x[sel], y[sel]
    tx, ty = [], []
    for p in tufts:
        k = rng.integers(5, 14)
        tx.append(p[0] + rng.normal(0, 0.012, k))
        ty.append(p[1] + rng.normal(0, 0.012, k))
    x = np.concatenate([x] + tx)
    y = np.concatenate([y] + ty)
    inside = (np.abs(x) < HALF_T - 0.02) & (np.abs(y) < HALF_T - 0.02)
    n = blade_mesh(x[inside], y[inside], mat)
    print(f"Grass: {n} blades")


# ------------------------------------------------------------- stones --
def build_stones(mat):
    C, rng = ra.C, ra.rng
    verts, faces, cols = [], [], []

    def stone(cx, cy, r, flat, tint, z0=None):
        bm = bmesh.new()
        bmesh.ops.create_icosphere(bm, subdivisions=1, radius=1.0)
        sx, sy = rng.uniform(0.7, 1.3, 2)
        rot = rng.uniform(0, 2 * np.pi)
        if z0 is None:
            z0 = float(ground_z(np.array([cx]), np.array([cy]))[0])
        start = len(verts)
        for v in bm.verts:
            px, py, pz = v.co * rng.uniform(0.85, 1.15)
            px, py = px * sx * r, py * sy * r
            verts.append((cx + px * math.cos(rot) - py * math.sin(rot),
                          cy + px * math.sin(rot) + py * math.cos(rot),
                          z0 + max(pz, -0.2) * r * flat + r * 0.05))
            cols.append(tint * (0.7 + 0.3 * max(pz, 0)))
        faces.extend(tuple(start + v.index for v in f.verts) for f in bm.faces)
        bm.free()

    # (the strip has them along 12 m of two edges; a junction's edges are about as long)
    for p in band_points(C["gravel"], -0.08, 0.25 + 0.2 * C["dirt"]):
        stone(p[0], p[1], rng.uniform(0.006, 0.016), 0.5, ra.GRAVEL * rng.uniform(0.7, 1.2))
    for p in band_points(C["chunks"], 0.02, 0.25):
        stone(p[0], p[1], rng.uniform(0.025, 0.06), 0.18, ra.ASPHALT * rng.uniform(0.9, 1.3))
    for h in potholes:
        for _ in range(int(250 * h["r"] ** 2) + 3):
            a, d = rng.uniform(0, 2 * math.pi), h["r"] * 0.75 * math.sqrt(rng.uniform())
            stone(h["x"] + d * math.cos(a), h["y"] + d * math.sin(a), rng.uniform(0.008, 0.02), 0.5,
                  ra.GRAVEL * rng.uniform(0.6, 1.1), z0=ra.LIP_M - h["depth"])
    if verts:
        rgba = np.column_stack([np.array(cols), np.ones(len(cols))])
        ra.mesh_object("Stones", verts, np.array(faces), rgba, mat, smooth=True)


# ------------------------------------------------------------- preview --
def preview(kind, name):
    """The tile over the field with a strip (the same condition, no centre
    line) on every arm: to check the joins."""
    tex = out_path(kind, name)
    strip = ra.load_pixels(ra.out_paths(name, False)[0])          # 512 rows x 1024 columns, bottom-up
    junction = ra.load_pixels(tex)
    grass = ra.load_pixels(ra.GRASS_TEX)
    size = RES * 3
    canvas = np.tile(grass, (size // grass.shape[0] + 1, size // grass.shape[1] + 1, 1))[:size, :size].copy()

    def paste(img, row0, col0):
        h, w = img.shape[:2]
        a = img[:, :, 3:4]
        band = canvas[row0:row0 + h, col0:col0 + w]
        band[:, :, :3] = img[:, :, :3] * a + band[:, :, :3] * (1 - a)

    mid = RES + (RES - strip.shape[0]) // 2          # the strip's rows, centred on the middle row of tiles
    paste(strip, mid, 0)                               # west arm
    paste(strip, mid, 2 * RES)                         # east arm
    upright = np.rot90(strip)                          # along the image's rows
    if kind == "cross":
        paste(upright, 2 * RES, mid)                   # (rows are bottom-up: the top)
    paste(upright, 0, mid)                             # the bottom (the T's stem)
    paste(junction, RES, RES)
    ra.save_image(canvas, out_path(kind, name, "previews", "_preview"))


# ---------------------------------------------------------------- main --
def build(kind, name):
    global KIND
    KIND = kind
    tex = out_path(kind, name)
    os.makedirs(os.path.dirname(tex), exist_ok=True)
    ra.setup(name)
    scene = bs.new_scene(center=(0.0, 0.0), frame_m=TILE, transparent=True, samples=SAMPLES)
    scene.render.resolution_x = RES
    scene.render.resolution_y = RES
    road_mat = ra.color_material("Asphalt", roughness=0.85, specular=0.25)
    tufts = []
    build_surface(road_mat)
    build_cracks(road_mat, tufts)
    build_grass(ra.color_material("Grass", roughness=0.65, specular=0.2), tufts)
    build_stones(road_mat)
    bs.render_to(scene, tex)
    preview(kind, name)


def main():
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    names = [a for a in args if a in ra.CONDITIONS] or list(ra.CONDITIONS)
    for name in names:
        for kind in KINDS:
            print(f"--- {kind} {name} ---")
            build(kind, name)


if __name__ == "__main__":
    main()
