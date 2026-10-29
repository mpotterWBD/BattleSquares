"""Generate a seamless, top-down grass field tile for Battle Squares.

Run headless:
    blender --background --python field_grass.py

Builds real 3D grass blades, flowers and pebbles on a TILE x TILE patch, renders them
straight down with an orthographic camera, and saves a tileable PNG. Every
random field is periodic over the tile, and anything near an edge is copied
to the opposite side, so the left/right and top/bottom edges match up.
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

# ---------------------------------------------------------------- settings --
ROOT = r"F:\Projects\BattleSquares"
OUT_TEX = os.path.join(ROOT, "assets", "textures", "field_grass_tile.png")
OUT_PREVIEW = os.path.join(ROOT, "assets", "previews", "field_grass_3x3.png")
OUT_BLEND = os.path.join(ROOT, "blender", "source", "field_grass.blend")

SEED = 7
RES = 1024            # output tile is RES x RES pixels
SAMPLES = 96
# How much ground one tile covers, in metres. Blades, flowers and patches
# have fixed real-world sizes, so the zoom level comes from bs.PX_PER_M,
# shared with every other asset.
TILE = RES / bs.PX_PER_M
# Real blades are ~3 mm wide. Once that drops below about half a pixel they
# just blur into flat colour (and the count explodes), so when zoomed far out
# the blades are drawn bigger and fewer to keep a visible grass grain.
BLADE_SCALE = max(1.0, (1024 / 3) / bs.PX_PER_M / 2)
BLADES = int(70000 * TILE ** 2 / BLADE_SCALE ** 2)
FLOWER_CLUSTERS = round(4 * TILE ** 2)
LONE_FLOWERS = round(6 * TILE ** 2)
PEBBLES = round(7 * TILE ** 2)
WRAP_MARGIN = 0.06 * BLADE_SCALE  # copy blades this close to an edge onto the far side

rng = np.random.default_rng(SEED)


GRASS_LUSH = srgb(0.30, 0.58, 0.16)
GRASS_DEEP = srgb(0.17, 0.40, 0.10)
GRASS_DRY = srgb(0.60, 0.64, 0.26)
SOIL = srgb(0.28, 0.22, 0.12)
UNDERGROWTH = srgb(0.10, 0.20, 0.05)
DAISY_PETAL = srgb(0.96, 0.96, 0.92)
DAISY_CENTER = srgb(0.98, 0.78, 0.15)
BUTTERCUP = srgb(1.00, 0.85, 0.10)
PEBBLE = srgb(0.52, 0.50, 0.46)


# ------------------------------------------------------- periodic noise --
class PeriodicNoise:
    """Sum of sine waves with integer frequencies: tiles exactly over the tile.
    Output is roughly normally distributed with mean 0, std 1. `kmax` is in
    waves per world unit, so feature sizes stay the same whatever TILE is."""

    def __init__(self, terms=14, kmax=6, falloff=1.0):
        terms = round(terms * TILE)
        kmax = round(kmax * TILE)
        ks = []
        while len(ks) < terms:
            kx, ky = rng.integers(-kmax, kmax + 1, 2)
            if kx or ky:
                ks.append((kx, ky))
        self.k = np.array(ks, dtype=np.float64)
        self.a = 1.0 / np.hypot(self.k[:, 0], self.k[:, 1]) ** falloff
        self.p = rng.uniform(0, 2 * np.pi, terms)
        self.norm = np.sqrt((self.a ** 2).sum() / 2)

    def __call__(self, x, y, chunk=200_000):
        x = np.asarray(x, dtype=np.float64).ravel() / TILE
        y = np.asarray(y, dtype=np.float64).ravel() / TILE
        out = np.empty(len(x))
        # In chunks: millions of points x hundreds of waves won't fit at once.
        for s in range(0, len(x), chunk):
            phase = (2 * np.pi * (self.k[:, 0] * x[s:s + chunk, None]
                                  + self.k[:, 1] * y[s:s + chunk, None]) + self.p)
            out[s:s + chunk] = (self.a * np.sin(phase)).sum(-1)
        return out / self.norm


density_field = PeriodicNoise(kmax=4)
lush_field = PeriodicNoise(kmax=5)
wind_field = PeriodicNoise(kmax=3, falloff=1.5)


# ------------------------------------------------------------- helpers --
def make_mesh_object(name, verts, faces, colors, material, smooth=False):
    """Build a mesh straight from numpy arrays. `faces` is (n_faces, k): every
    face has the same number of corners. Much faster than from_pydata for
    millions of grass blades."""
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
    rgba = np.ones((len(colors), 4), dtype=np.float32)
    rgba[:, :3] = colors
    attr.data.foreach_set("color", rgba.ravel())
    if smooth:
        me.shade_smooth()
    me.materials.append(material)
    obj = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def make_vertex_color_material():
    mat = bpy.data.materials.new("FieldVertexColor")
    nt = bs.node_tree_of(mat)
    bsdf = next((n for n in nt.nodes if n.type == "BSDF_PRINCIPLED"), None)
    if bsdf is None:
        bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
        out = next(n for n in nt.nodes if n.type == "OUTPUT_MATERIAL")
        nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    attr = nt.nodes.new("ShaderNodeAttribute")
    attr.attribute_name = "Col"
    nt.links.new(attr.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.65
    if "Specular IOR Level" in bsdf.inputs:
        bsdf.inputs["Specular IOR Level"].default_value = 0.2
    return mat


# --------------------------------------------------------------- ground --
def build_ground(mat):
    n = int(60 * TILE) + 1   # a vertex every ~1.7 cm: plenty for soil colour
    lin = np.linspace(-0.2, TILE + 0.2, n)
    gx, gy = np.meshgrid(lin, lin)
    gx, gy = gx.ravel(), gy.ravel()
    verts = np.column_stack([gx, gy, np.zeros_like(gx)])
    r, c = np.meshgrid(np.arange(n - 1), np.arange(n - 1), indexing="ij")
    i = (r * n + c).ravel()
    faces = np.column_stack([i, i + 1, i + n + 1, i + n])
    bare = np.clip(-0.6 * density_field(gx, gy) - 0.2, 0, 1)[:, None]
    colors = UNDERGROWTH * (1 - bare) + SOIL * bare
    make_mesh_object("Ground", verts, faces, colors, mat)


# ---------------------------------------------------------------- grass --
def build_grass(mat):
    # Scatter blade roots, thinner where the density field is low.
    cand = rng.uniform(0, TILE, (int(BLADES * 2.2), 2))
    keep_p = np.clip(0.6 + 0.35 * density_field(cand[:, 0], cand[:, 1]), 0.08, 1)
    roots = cand[rng.uniform(size=len(cand)) < keep_p][:BLADES]
    x, y = roots[:, 0], roots[:, 1]
    count = len(x)

    lush = lush_field(x, y)
    dryness = np.clip(0.25 - 0.4 * lush + rng.normal(0, 0.08, count), 0, 1)[:, None]
    deep = rng.uniform(0, 1, count)[:, None]
    base_col = GRASS_LUSH * (1 - deep) + GRASS_DEEP * deep
    color = base_col * (1 - dryness) + GRASS_DRY * dryness
    color *= rng.uniform(0.85, 1.15, (count, 1))

    length = (rng.uniform(0.018, 0.045, count) * (0.85 + 0.25 * np.clip(lush, -1, 1))
              * BLADE_SCALE)
    lean = rng.uniform(0.35, 0.95, count)
    width = rng.uniform(0.0025, 0.0045, count) * BLADE_SCALE
    # Blades lean along a smooth "wind" direction, so they form natural swirls.
    theta = wind_field(x, y) * 1.3 + rng.normal(0, 0.55, count)

    reach = length * lean
    height = length * np.sqrt(1 - lean ** 2)
    d = np.column_stack([np.cos(theta), np.sin(theta)])
    nrm = np.column_stack([-d[:, 1], d[:, 0]])
    p0 = np.column_stack([x, y])
    hw = (width / 2)[:, None]

    def pt(xy, z):
        return np.column_stack([xy, z])

    blade_verts = np.stack([
        pt(p0 - nrm * hw, np.zeros(count)),
        pt(p0 + nrm * hw, np.zeros(count)),
        pt(p0 + d * (reach * 0.35)[:, None] - nrm * hw * 0.8, height * 0.65),
        pt(p0 + d * (reach * 0.35)[:, None] + nrm * hw * 0.8, height * 0.65),
        pt(p0 + d * reach[:, None], height),
    ], axis=1)                                             # (count, 5, 3)
    shade = np.array([0.35, 0.35, 0.8, 0.8, 1.1])[None, :, None]
    blade_cols = color[:, None, :] * shade                 # darker at the root

    # Wrap blades near an edge onto the opposite side so the tile is seamless.
    all_v, all_c = [blade_verts], [blade_cols]
    for ox in (-1, 0, 1):
        for oy in (-1, 0, 1):
            if ox == 0 and oy == 0:
                continue
            sx, sy = x + ox * TILE, y + oy * TILE
            sel = ((sx > -WRAP_MARGIN) & (sx < TILE + WRAP_MARGIN)
                   & (sy > -WRAP_MARGIN) & (sy < TILE + WRAP_MARGIN))
            shifted = blade_verts[sel].copy()
            shifted[:, :, 0] += ox * TILE
            shifted[:, :, 1] += oy * TILE
            all_v.append(shifted)
            all_c.append(blade_cols[sel])
    verts = np.concatenate(all_v)
    cols = np.concatenate(all_c)
    n_blades = len(verts)
    # Three triangles per blade (the root quad split in two, plus the tip).
    tri = np.array([[0, 1, 3], [0, 3, 2], [2, 3, 4]])
    faces = (tri[None] + 5 * np.arange(n_blades)[:, None, None]).reshape(-1, 3)
    print(f"Grass: {count} blades in tile, {n_blades} including wrapped copies"
          f" (blade scale {BLADE_SCALE:g}x)")
    make_mesh_object("Grass", verts, faces, cols.reshape(-1, 3), mat)


# -------------------------------------------------------------- flowers --
def flower(verts, faces, cols, cx, cy, z, petals, plen, pwid, pcol, ccol, crad):
    rot = rng.uniform(0, 2 * np.pi)
    for i in range(petals):
        a = rot + 2 * np.pi * i / petals
        ex, ey = cx + math.cos(a) * plen * 0.55, cy + math.sin(a) * plen * 0.55
        start = len(verts)
        for j in range(8):
            b = 2 * np.pi * j / 8
            lx, ly = math.cos(b) * plen * 0.5, math.sin(b) * pwid * 0.5
            verts.append((ex + lx * math.cos(a) - ly * math.sin(a),
                          ey + lx * math.sin(a) + ly * math.cos(a),
                          z + 0.0004 * i / petals))
            cols.append(pcol * (0.82 if math.cos(b) < 0 else 1.0))
        faces.append(tuple(range(start, start + 8)))
    start = len(verts)
    for j in range(8):
        b = 2 * np.pi * j / 8
        verts.append((cx + math.cos(b) * crad, cy + math.sin(b) * crad, z + 0.001))
        cols.append(ccol)
    faces.append(tuple(range(start, start + 8)))


def build_flowers(mat):
    verts, faces, cols = [], [], []
    spots = []
    for _ in range(FLOWER_CLUSTERS):
        c = rng.uniform(0.12, TILE - 0.12, 2)
        for _ in range(rng.integers(3, 7)):
            spots.append(np.clip(c + rng.normal(0, 0.03, 2), 0.05, TILE - 0.05))
    spots += list(rng.uniform(0.06, TILE - 0.06, (LONE_FLOWERS, 2)))
    for cx, cy in spots:
        z = rng.uniform(0.025, 0.04) * BLADE_SCALE  # stay above the grass
        if rng.uniform() < 0.65:
            s = rng.uniform(0.8, 1.2) * BLADE_SCALE
            flower(verts, faces, cols, cx, cy, z, int(rng.integers(8, 12)),
                   0.009 * s, 0.0032 * s, DAISY_PETAL, DAISY_CENTER, 0.0028 * s)
        else:
            s = rng.uniform(0.8, 1.1) * BLADE_SCALE
            flower(verts, faces, cols, cx, cy, z, 5, 0.0065 * s, 0.0048 * s,
                   BUTTERCUP, BUTTERCUP * 0.75, 0.0016 * s)
    print(f"Flowers: {len(spots)}")
    make_mesh_object("Flowers", verts, faces, np.array(cols), mat)


# -------------------------------------------------------------- pebbles --
def build_pebbles(mat):
    verts, faces, cols = [], [], []
    for _ in range(PEBBLES):
        bm = bmesh.new()
        bmesh.ops.create_icosphere(bm, subdivisions=2, radius=1.0)
        r = rng.uniform(0.006, 0.014) * BLADE_SCALE
        sx, sy = rng.uniform(0.8, 1.3, 2)
        rot = rng.uniform(0, 2 * np.pi)
        cx, cy = rng.uniform(0.06, TILE - 0.06, 2)
        tint = PEBBLE * rng.uniform(0.75, 1.15)
        start = len(verts)
        for v in bm.verts:
            px, py, pz = (v.co * rng.uniform(0.9, 1.1))
            px, py = px * sx * r, py * sy * r
            verts.append((cx + px * math.cos(rot) - py * math.sin(rot),
                          cy + px * math.sin(rot) + py * math.cos(rot),
                          max(pz, -0.2) * r * 0.5 + r * 0.1))
            cols.append(tint * (0.7 + 0.3 * max(pz, 0)))
        faces += [tuple(start + v.index for v in f.verts) for f in bm.faces]
        bm.free()
    make_mesh_object("Pebbles", verts, faces, np.array(cols), mat, smooth=True)


# ----------------------------------------------------------------- main --
def save_tiled_preview(src, dst, reps=3):
    img = bpy.data.images.load(src)
    w, h = img.size
    px = np.empty(w * h * 4, dtype=np.float32)
    img.pixels.foreach_get(px)
    tiled = np.tile(px.reshape(h, w, 4), (reps, reps, 1))
    out = bpy.data.images.new("preview", w * reps, h * reps)
    out.pixels.foreach_set(tiled.ravel())
    out.filepath_raw = dst
    out.file_format = "PNG"
    out.save()


def main():
    for path in (OUT_TEX, OUT_PREVIEW, OUT_BLEND):
        os.makedirs(os.path.dirname(path), exist_ok=True)

    scene = bs.new_scene(center=(TILE / 2, TILE / 2), frame_m=TILE, samples=SAMPLES)
    mat = make_vertex_color_material()
    build_ground(mat)
    build_grass(mat)
    build_flowers(mat)
    build_pebbles(mat)

    bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND)
    bs.render_to(scene, OUT_TEX)
    save_tiled_preview(OUT_TEX, OUT_PREVIEW)
    print("Saved", OUT_PREVIEW)


main()
