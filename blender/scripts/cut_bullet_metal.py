"""Splits Mike's BulletImpactMetal.mp3 (2026-11-03: 8 s, eight rounds into
steel, each in its own stretch between digital silences) into one WAV per
impact, assets/sfx/bullet_metal/bullet_metal_<n>.wav: from 4 ms before it
starts to where it has rung down to RING_DB, a short fade out, mono (heard
from where it hit), all brought to the same peak. impact_sound.gd plays them
as the "metal" kind. Run with Blender (its `aud` reads the MP3):
    blender --background --factory-startup --python blender/scripts/cut_bullet_metal.py
"""
import os
import shutil
import tempfile

import aud
import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(ROOT, "assets", "sfx", "BulletImpactMetal.mp3")
OUT = os.path.join(ROOT, "assets", "sfx", "bullet_metal")
SOUND_DB = -60.0     # a 10 ms window louder than this is part of an impact
GAP_S = 0.1          # this much quieter between two is a new one
RING_DB = -62.0      # each ends where it's rung down to this
PEAK_DB = -3.0

s = aud.Sound(SRC)
r = int(s.specs[0])
d = s.data()
m = (d.mean(axis=1) if d.ndim > 1 else d).astype(np.float64)
w = int(0.01 * r)
lv = np.array([20 * np.log10(np.sqrt((m[i:i + w] ** 2).mean()) + 1e-12) for i in range(0, len(m) - w, w)])
loud = lv > SOUND_DB
events, k = [], 0
while k < len(loud):
    if loud[k]:
        j = k
        while j < len(loud) and (loud[j] or loud[j:j + int(GAP_S / 0.01)].any()):
            j += 1
        events.append((k, j))
        k = j
    k += 1
os.makedirs(OUT, exist_ok=True)
for n, (a, b) in enumerate(events):
    seg_lv = lv[a:b]
    end = a + max(np.where(seg_lv > RING_DB)[0]) + 1
    x = m[max(a * w - int(0.004 * r), 0):end * w]
    f = int(0.03 * r)
    x[-f:] *= np.linspace(1, 0, f)
    x *= 10 ** (PEAK_DB / 20) / np.abs(x).max()
    if len(x) % 64 == 0:   # (Blender's writer fails on a length that's an exact multiple of its frame: one more sample of silence)
        x = np.append(x, 0.0)
    buf = aud.Sound.buffer(x.astype(np.float32).reshape(-1, 1), r)
    path = os.path.join(OUT, f"bullet_metal_{n}.wav")
    tmp = os.path.join(tempfile.gettempdir(), f"bullet_metal_{n}.wav")   # written whole, then moved in: the open editor imports a WAV as soon as it appears
    buf.write(tmp, rate=r, channels=aud.CHANNELS_MONO, format=aud.FORMAT_S16,
              container=aud.CONTAINER_WAV, codec=aud.CODEC_PCM)
    shutil.move(tmp, path)
    print(f"bullet_metal_{n}.wav: {a * 0.01:.2f} s, {len(x) / r:.2f} s long")
