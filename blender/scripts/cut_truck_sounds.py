"""Cuts the supply truck's sounds from Mike's recordings (assets/sfx/supply_truck/),
from the sections chosen in assets/sfx/supply_truck/truck_sound_cuts.tres
(scripts/truck_sound_cuts.gd: its Cut Sounds button in the Inspector runs this).
Run with Blender (its `aud` module is the only MP3 reader here):
    blender --background --factory-startup --python blender/scripts/cut_truck_sounds.py -- <file.json or json>
It's given the sections in seconds (CUTS below are the defaults, used with none):
  start [from, to]   TransportVehicle.mp3: ignition to idle -> truck_start.wav (a quiet
                     lead-in, quieter than the take's background + QUIET_RISE_DB, trimmed off)
  stop [from, to]    ...: idle dying away                 -> truck_stop.wav
  idle [[from, to], ...]  steady idle stretches, joined into one loop -> truck_idle.wav
                     (Mike: short loops sounded periodic). Each join, and the
                     wrap back to the start, is cut where the waveforms line up
                     best (cross-correlation), so the firing rhythm carries
                     straight through, then cross-faded briefly.
  door_open, door_slam [from, to]  front_door.mp3, trimmed to the sound in there
                     (silence either side cut off) -> door_open.wav, door_slam.wav
The engine pieces share one gain (the loudest peak at -3 dB) so they keep their
levels to each other; so do the two door sounds.

The take, mapped 2026-11-03 (DEVLOG): the starter from 2.95 s, catching and
revving to 5.5 s, idle by 6.4 s; steady idle 12.4-16.6 s and 23.6-27.0 s;
switched off at 17 s; doors, two cycles: open 5.7 / 18.4 s, slam 11.65 / 24.1 s.
"""
import json
import os
import sys

import aud
import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(ROOT, "assets", "sfx", "supply_truck") + os.sep
CUTS = {
    "engine": "TransportVehicle.mp3",   # which of the engine recordings (in assets/sfx/supply_truck/)
    "start": [2.85, 6.6],
    "stop": [16.3, 17.7],
    "blend": 1.0,                       # the loops' joins and wraps: this long a constant-power blend
    "idle": [[12.4, 16.6], [23.6, 27.0]],
    "run": [],                          # driving stretches (loop, pitch levelled), none: idle alone
    "door_open": [18.2, 19.4],
    "door_slam": [23.9, 25.4],
    # The crane (Mike, 2026-11-09): Crane2.mp3 (46 s) has a thin, hissy run to
    # 18.5 s, a change-over 18.75-22 s, then the hydraulics working hard: lower
    # and louder, steadiest 26.75-33.25 s, pulsing from 34 s. (The first take,
    # Crane.mp3, ran steadily 1.75-10 s.) Winch.mp3 is a short take (0.25-2.5 s)
    # and a long one (3.25-10.5 s), steadiest 3.4-7 s. Each stretch list -> one
    # seamless loop.
    "crane_recording": "Crane2.mp3",
    "crane": [[27.0, 33.0]],
    "crane_start": [0.0, 0.25],         # Crane2's opening click (0-0.13 s; hiss from 0.4 s): crane_start.wav
    "winch": [[3.4, 7.0]],
    # The stabilisers (Mike, 2026-11-09): Stablizer2.wav (4.1 s) builds up
    # 0.25-1.5 s, then a steady hydraulic hiss to the end -> stabilizer.wav.
    # (The first take, Stablizer.mp3: steady 0.25-3.2 and 4.25-7.5 s.)
    "stabilizer_recording": "Stablizer2.wav",
    "stabilizer": [[1.6, 4.0]],
    # The crane's motor (Mike, 2026-11-09): CraneMotor.mp3 is 3 min of it
    # running steadily (-30 dB throughout, no start or stop) -> crane_motor.wav;
    # Switch.wav (0.52 s) is a click at 0.26 s, a little rattle before it from 0.18 s.
    "motor_recording": "CraneMotor.mp3",
    "motor": [[5.0, 15.0]],
    "switch_recording": "Switch.wav",
    "switch": [0.15, 0.5],
    "crane_blend": 0.4,                 # their loops' joins and wraps
    "only": [],                         # e.g. ["crane", "winch"]: cut just those (the rest left as they are)
}
args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
if args:   # a JSON file of them (truck_sound_cuts.gd), or the JSON itself
    CUTS.update(json.load(open(args[0])) if os.path.isfile(args[0]) else json.loads(args[0]))
MATCH_S = 0.06      # the stretch compared when lining two pieces up
SEARCH_S = 0.4      # how far back from a piece's end to look for the best line-up
JOIN_S = 0.05       # the cross-fade at each join
WRAP_SEARCH_S = 1.2 # the loop's wrap back to its start: looks further back for a good line-up
START_SEARCH_S = 0.5  # ...and where in its first half second it starts
QUIET_RISE_DB = 5.0   # the start sound begins where it first gets this much louder than the background
GOOD_MATCH = 0.7      # a hand-over lining up at least this well gets the short cross-fade...
LONG_JOIN_S = 0.3     # ...one that doesn't, this long a constant-power one
MAX_SHIFT = 1.25      # levelling a loop's pitch, never playing it more than this much faster or slower
GOOD_WRAP = 0.85      # a loop's wrap lining up this well near its ends is taken (it keeps its length)

def load(name):
    s = aud.Sound(SRC + name)
    d = s.data()
    x, rate = (d.mean(axis=1) if d.ndim > 1 else d).astype(np.float64), int(s.specs[0])
    if rate > 48000:
        # (Switch.wav and Stablizer2.wav are 96 kHz: written as is, they come
        # out in a WAV form Godot won't read. Down to 48 kHz, smoothed first so
        # nothing aliases.)
        k = rate // 48000
        x = np.convolve(x, np.ones(k) / k, mode="same")
        x = np.interp(np.arange(0, len(x) / rate, 1 / 48000) * rate, np.arange(len(x)), x)
        rate = 48000
    return x, rate
def db(x): return 20 * np.log10(np.sqrt((x ** 2).mean()) + 1e-12)
def fade(x, rate, fin=0.01, fout=0.03):
    x = x.copy(); a = int(fin * rate); b = int(fout * rate)
    if a: x[:a] *= np.linspace(0, 1, a)
    if b: x[-b:] *= np.linspace(1, 0, b)
    return x
def best_cut(x, y, rate, search_s=SEARCH_S):
    """Where in x's last SEARCH_S to hand over to y's start: the point whose
    next MATCH_S looks most like y's first MATCH_S."""
    m, s = int(MATCH_S * rate), int(search_s * rate)
    target = y[:m] / (np.linalg.norm(y[:m]) + 1e-12)
    lo = len(x) - s - m
    region = x[lo:]
    # Every position's match at once: the correlation by FFT, over each
    # window's own size (a running sum of squares).
    n = 1 << int(np.ceil(np.log2(len(region) + m)))
    corr = np.fft.irfft(np.fft.rfft(region, n) * np.conj(np.fft.rfft(target, n)), n)[:len(region) - m]
    sq = np.concatenate([[0.0], np.cumsum(region ** 2)])
    norms = np.sqrt(sq[m:m + len(corr)] - sq[:len(corr)]) + 1e-12
    scores = corr / norms
    k = int(np.argmax(scores))
    return lo + k, float(scores[k])
def handover(score, rate, room, blend_s=0.0):
    """The cross-fade for a hand-over whose waveforms line up `score`: short
    and straight where they match; where they don't (noisy driving, no clean
    match to be had), LONG_JOIN_S at constant power, so it doesn't dip. At
    most `room` samples. With `blend_s` (a loop's joins: Mike, 2026-11-03, the
    pieces sounded like different sounds swapping) it's that long, at constant
    power, whatever the match: one piece melts into the next. Returns its
    length and the fade-in / fade-out weights."""
    if blend_s > 0.0:
        f = min(int(blend_s * rate), room)
        a = np.linspace(0, np.pi / 2, f)
        return f, np.sin(a), np.cos(a)
    if score >= GOOD_MATCH:
        f = int(JOIN_S * rate)
        w = np.linspace(0, 1, f)
        return f, w, 1 - w
    f = min(int(LONG_JOIN_S * rate), room)
    a = np.linspace(0, np.pi / 2, f)
    return f, np.sin(a), np.cos(a)


def join(x, y, rate, blend_s=0.0):
    p, score = best_cut(x, y, rate)
    f, w_in, w_out = handover(score, rate, min(len(x), len(y)) // 2, blend_s)
    p = min(p, len(x) - f)
    return np.concatenate([x[:p], x[p:p + f] * w_out + y[:f] * w_in, y[f:]]), score
def seamless(x, rate, blend_s=0.0, keep_length=False):
    """A loop: its end handed over to its own start where they line up, the
    start's first JOIN_S then dropped (it's in the hand-over). Where it
    starts is chosen too, in its first START_SEARCH_S, for the best line-up.
    A good one near the ends (SEARCH_S of them) is taken first, so the loop
    keeps its length; only if there's none does it look further in (unless
    `keep_length`: noise, a hiss, never lines up, and looking further in only
    shortens it; Stablizer2.wav's came out 0.76 s that way)."""
    for start_s, end_s in ((SEARCH_S, SEARCH_S),) + (() if keep_length else ((START_SEARCH_S, WRAP_SEARCH_S),)):
        best = (-2.0, 0, 0)
        for st in range(0, int(start_s * rate), int(0.002 * rate)):
            p, score = best_cut(x, x[st:], rate, end_s)
            if score > best[0]:
                best = (score, st, p)
        if best[0] >= GOOD_WRAP:
            break
    score, st, p = best
    # (A wrap that lines up well gets the short join: a long blend of the same
    # sound over itself drifts in and out of phase, a swoosh.)
    f, w_in, w_out = handover(score, rate, len(x) // 4, 0.0 if score >= GOOD_WRAP else blend_s)
    p = min(p, len(x) - f)
    looped = np.concatenate([x[st + f:p], x[p:p + f] * w_out + x[st:st + f] * w_in])
    return looped, score
def write(x, rate, name):
    if len(x) % 64 == 0:   # (Blender's writer fails on a length that's an exact multiple of its frame: one more sample of silence)
        x = np.append(x, 0.0)
    buf = aud.Sound.buffer(x.astype(np.float32).reshape(-1, 1), rate)
    buf.write(SRC + name, rate=rate, channels=aud.CHANNELS_MONO, format=aud.FORMAT_S16,
              container=aud.CONTAINER_WAV, codec=aud.CODEC_PCM)
    print(f"{name}: {len(x)/rate:.2f} s, level {db(x):.1f} dB, peak {20*np.log10(np.abs(x).max()):.1f} dB")
def bounds(m, rate, t0, t1, thr=-50.0):
    w = int(0.01 * rate); seg = m[int(t0*rate):int(t1*rate)]
    lv = np.array([db(seg[i:i+w]) for i in range(0, len(seg) - w, w)])
    loud = np.where(lv > thr)[0]
    return t0 + max(loud[0] - 2, 0) * 0.01, t0 + (loud[-1] + 3) * 0.01


def quiet_lead(x, rate, floor_db, rise_db=QUIET_RISE_DB):
    """How long `x` stays quiet at the front (seconds): until it first gets
    `rise_db` louder than `floor_db` (the take's background), less 150 ms."""
    w = int(0.05 * rate)
    lv = np.array([db(x[i:i + w]) for i in range(0, len(x) - w, w)])
    loud = np.where(lv > floor_db + rise_db)[0]
    return max(loud[0] - 3, 0) * 0.05 if len(loud) else 0.0   # (150 ms early: not to clip the first click)


def firing_hz(x, rate, t, win=0.5):
    """The engine's firing rate (its strongest frequency, 20-200 Hz) around `t` s into `x`."""
    seg = x[int(t * rate):int((t + win) * rate)]
    seg = seg * np.hanning(len(seg))
    n = 8 * len(seg)   # padded, for a finer estimate
    spec = np.abs(np.fft.rfft(seg, n))
    f = np.fft.rfftfreq(n, 1 / rate)
    band = (f > 20) & (f < 200)
    return f[band][np.argmax(spec[band])]


def pitch_line(x, rate):
    """The engine's firing rate across `x` (measured every 0.5 s), fitted
    with a straight line: (slope, intercept) in Hz against seconds, and its middle."""
    ts = np.arange(0, len(x) / rate - 0.5, 0.5) + 0.25
    hz = np.array([firing_hz(x, rate, t - 0.25) for t in ts])
    slope, icept = np.polyfit(ts, hz, 1)
    return slope, icept, float(np.median(hz))


def level_pitch(x, rate, target_hz):
    """`x` played at `target_hz` all through: faster where the engine's
    lower, slower where it's higher (its drift fitted with a straight line,
    pitch_line()), so the pieces of a loop match and a loop of them doesn't
    jump back in pitch where it wraps (Mike, 2026-11-03: the cruise in his
    second recording climbs 62 to 74 Hz). Never by more than MAX_SHIFT
    either way (or it sounds sped up). Returns it, and the drift (from, to Hz)."""
    slope, icept, _ = pitch_line(x, rate)
    t = np.arange(len(x)) / rate
    ratio = np.clip(target_hz / (icept + slope * t), 1 / MAX_SHIFT, MAX_SHIFT)   # how much faster to play each moment
    pos = np.cumsum(ratio)                             # where each output sample reads from (in samples)
    pos = pos[pos < len(x) - 1]
    return np.interp(pos, np.arange(len(x)), x), (icept, icept + slope * t[-1])


def loop_of(engine, rate, stretches, name, blend_s=0.0):
    """The stretches joined into one seamless loop (see join(), seamless()),
    each first played at the same pitch (their middle one's, level_pitch())
    and brought to the same loudness, so the joins don't jump."""
    length = len(engine) / rate
    cut = lambda a, b: engine[int(max(a, 0) * rate):int(min(b, length) * rate)]
    pieces = [cut(*s) for s in stretches]
    target = float(np.median([pitch_line(p, rate)[2] for p in pieces]))
    loud = float(np.median([np.sqrt((p ** 2).mean()) for p in pieces]))
    for k, (s, p) in enumerate(zip(stretches, pieces)):
        p, (h0, h1) = level_pitch(p, rate, target)
        pieces[k] = p * loud / (np.sqrt((p ** 2).mean()) + 1e-12)
        print(f"{name}: {s[0]}-{s[1]} s, the engine at {h0:.0f} -> {h1:.0f} Hz, played at {target:.0f} Hz")
    out = pieces[0]
    for s, p in zip(stretches[1:], pieces[1:]):
        out, score = join(out, p, rate, blend_s)
        print(f"{name}: joined {s[0]}-{s[1]} s, lining up {score:.2f} (1 = identical)")
    out, score = seamless(out, rate, blend_s)
    print(f"{name}: the loop's wrap lines up {score:.2f}")
    return out


def plain_loop(x, rate, stretches, name, blend_s, keep_length=False):
    """As loop_of(), for a machine's steady run (the crane, the winch): the
    stretches joined and wrapped where they line up, brought to one loudness;
    no pitch levelling (that's the engine's firing rate)."""
    length = len(x) / rate
    pieces = [x[int(max(a, 0) * rate):int(min(b, length) * rate)] for a, b in stretches]
    loud = float(np.median([np.sqrt((p ** 2).mean()) for p in pieces]))
    pieces = [p * loud / (np.sqrt((p ** 2).mean()) + 1e-12) for p in pieces]
    out = pieces[0]
    for s, p in zip(stretches[1:], pieces[1:]):
        out, score = join(out, p, rate, blend_s)
        print(f"{name}: joined {s[0]}-{s[1]} s, lining up {score:.2f} (1 = identical)")
    out, score = seamless(out, rate, blend_s, keep_length)
    print(f"{name}: {', '.join(f'{a}-{b} s' for a, b in stretches)}; the loop's wrap lines up {score:.2f}")
    return out


def cut_crane():
    """The crane's two loops: its hydraulics (the boom moving: crane_move.wav)
    and its winch (the line going up or down: winch.wav), each with its loudest
    peak at -3 dB (the truck sets their volumes)."""
    long_enough = lambda key: [s for s in CUTS.get(key, []) if s[1] - s[0] > 1.0]
    blend = float(CUTS.get("crane_blend", 0.4))
    for key, src, out in (("crane", CUTS.get("crane_recording", "Crane2.mp3"), "crane_move.wav"), ("winch", "Winch.mp3", "winch.wav"),
                          ("stabilizer", CUTS.get("stabilizer_recording", "Stablizer.mp3"), "stabilizer.wav"),
                          ("motor", CUTS.get("motor_recording", "CraneMotor.mp3"), "crane_motor.wav")):
        if CUTS.get("only") and key not in CUTS["only"]:
            continue
        stretches = long_enough(key)
        if not stretches:
            print(f"{key}: no stretch longer than 1 s: {out} left as it is")
            continue
        x, rate = load(src)
        loop = plain_loop(x, rate, stretches, key, blend, keep_length=(key == "stabilizer"))   # (a hiss)
        gain = 10 ** (-3 / 20) / np.abs(loop).max()
        write(loop * gain, rate, out)
        start = CUTS.get("crane_start", [])
        if key == "crane" and len(start) == 2 and start[1] - start[0] > 0.02:
            # The click as the crane's hydraulics start (Mike, 2026-11-09): a
            # one-shot at the loop's own gain, so it's as loud against the loop
            # as in the recording (held under -1 dB peak).
            a, b = int(start[0] * rate), int(start[1] * rate)
            click = fade(x[a:b], rate, 0.002, min(0.06, (b - a) / rate / 3)) * gain
            click *= min(1.0, 10 ** (-1 / 20) / (np.abs(click).max() + 1e-12))
            print(f"crane start: {start[0]}-{start[1]} s")
            write(click, rate, "crane_start.wav")
    # The switch the operator throws at the controls (Mike, 2026-11-09): a
    # one-shot, its loudest at -3 dB (the truck sets its volume).
    sw = CUTS.get("switch", [])
    if (not CUTS.get("only") or "switch" in CUTS["only"]) and len(sw) == 2 and sw[1] - sw[0] > 0.02:
        x, rate = load(CUTS.get("switch_recording", "Switch.wav"))
        a, b = int(sw[0] * rate), int(sw[1] * rate)
        click = fade(x[a:b], rate, 0.002, min(0.05, (b - a) / rate / 3))
        print(f"switch: {sw[0]}-{sw[1]} s")
        write(click * 10 ** (-3 / 20) / (np.abs(click).max() + 1e-12), rate, "crane_switch.wav")


def main():
    if CUTS.get("only") and not any(k in CUTS["only"] for k in ("engine", "doors")):
        cut_crane()   # (just the crane's: the engine and doors left as they are)
        return
    cut_crane()
    engine, r = load(CUTS["engine"])
    print(f"engine recording: {CUTS['engine']}")
    length = len(engine) / r
    cut = lambda a, b: engine[int(max(a, 0) * r):int(min(b, length) * r)]
    long_enough = lambda key: [s for s in CUTS.get(key, []) if s[1] - s[0] > 1.0]
    if not long_enough("idle"):
        raise SystemExit("cut_truck_sounds: no idle stretch longer than 1 s")
    blend = float(CUTS.get("blend", 1.0))
    print(f"loops: each join and wrap blended over {blend:.2f} s")
    idle = loop_of(engine, r, long_enough("idle"), "idle", blend)
    run = loop_of(engine, r, long_enough("run"), "driving", blend) if long_enough("run") else None
    start, stop = cut(*CUTS["start"]), cut(*CUTS["stop"])
    # The start from where the sound does: a quiet lead-in (the take is just
    # background for its first 2.9 s) would play as silence after the door
    # shuts, as if nothing had happened (Mike, 2026-11-03).
    w = int(0.05 * r)
    levels = np.array([db(engine[i:i + w]) for i in range(0, len(engine) - w, w)])
    floor = np.percentile(levels[levels > -70], 5)   # the take's background (its room tone: not a fade to digital silence)
    lead = quiet_lead(start, r, floor)
    if lead > 0:
        start = start[int(lead * r):]
        print(f"start: {lead:.2f} s of quiet trimmed off the front (it starts at {CUTS['start'][0] + lead:.2f} s)")
    pieces = [idle, start, stop] + ([run] if run is not None else [])
    gain = 10 ** (-3 / 20) / max(np.abs(c).max() for c in pieces)   # one gain: the loudest at -3 dB
    write(fade(start * gain, r, 0.02, 0.0), r, "truck_start.wav")
    write(fade(stop * gain, r, 0.0, 0.4), r, "truck_stop.wav")
    write(idle * gain, r, "truck_idle.wav")
    if run is not None:
        write(run * gain, r, "truck_run.wav")
    elif os.path.exists(SRC + "truck_run.wav"):   # no driving loop: the truck uses the idle one alone
        os.remove(SRC + "truck_run.wav")
        print("truck_run.wav: removed (no driving stretch)")

    doors, r = load("front_door.mp3")
    o0, o1 = bounds(doors, r, *CUTS["door_open"])
    s0, s1 = bounds(doors, r, *CUTS["door_slam"])
    print(f"doors: open {o0:.2f}-{o1:.2f} s, slam {s0:.2f}-{s1:.2f} s (trimmed to the sound)")
    dg = 10 ** (-3 / 20) / max(np.abs(doors[int(o0*r):int(o1*r)]).max(), np.abs(doors[int(s0*r):int(s1*r)]).max())
    write(fade(doors[int(o0*r):int(o1*r)] * dg, r, 0.004, 0.04), r, "door_open.wav")
    write(fade(doors[int(s0*r):int(s1*r)] * dg, r, 0.004, 0.06), r, "door_slam.wav")


main()
