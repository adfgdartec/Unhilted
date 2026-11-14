"""Synthesizes every sound effect and the ambient music for the Heap.
Run from the project root:  python3 tools/audio/build_audio.py

Nothing is sampled: each sound is built from oscillators, filtered noise and
envelopes, so the whole soundtrack can be rebuilt (and tweaked) from code.
Palette: metal, wire hum and brass for the robot; dusty, warm low pads for
the Heap. SFX are 44.1 kHz mono WAV; music is looping OGG Vorbis.
"""
import os
import subprocess
import wave

import numpy as np
from scipy import signal

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SFX = os.path.join(ROOT, "audio", "sfx")
MUS = os.path.join(ROOT, "audio", "music")
os.makedirs(SFX, exist_ok=True)
os.makedirs(MUS, exist_ok=True)
SR = 44100
rng = np.random.default_rng(7)


def t_(dur):
    return np.arange(int(SR * dur)) / SR


def env(n, a=0.005, d=0.1, s=0.0, r=0.05, hold=0.0):
    """ADSR envelope in seconds, length n samples."""
    out = np.zeros(n)
    A, D, H, R = int(a * SR), int(d * SR), int(hold * SR), int(r * SR)
    i = 0
    seg = min(A, n - i); out[i:i + seg] = np.linspace(0, 1, max(A, 1))[:seg]; i += seg
    seg = min(D, n - i); out[i:i + seg] = np.linspace(1, s, max(D, 1))[:seg]; i += seg
    seg = min(H, n - i); out[i:i + seg] = s; i += seg
    seg = min(R, n - i); out[i:i + seg] = np.linspace(s, 0, max(R, 1))[:seg]; i += seg
    return out


def expdecay(n, tau):
    return np.exp(-np.arange(n) / (tau * SR))


def sine(f, dur, phase=0.0):
    f = np.broadcast_to(np.asarray(f, dtype=float), (int(SR * dur),))
    return np.sin(2 * np.pi * np.cumsum(f) / SR + phase)


def saw(f, dur):
    f = np.broadcast_to(np.asarray(f, dtype=float), (int(SR * dur),))
    ph = np.cumsum(f) / SR
    return 2 * (ph - np.floor(ph + 0.5))


def square(f, dur, duty=0.5):
    f = np.broadcast_to(np.asarray(f, dtype=float), (int(SR * dur),))
    ph = np.cumsum(f) / SR
    return np.where((ph % 1.0) < duty, 1.0, -1.0)


def noise(dur):
    return rng.uniform(-1, 1, int(SR * dur))


def lp(x, fc, order=2):
    b, a = signal.butter(order, min(fc / (SR / 2), 0.99), "low")
    return signal.lfilter(b, a, x)


def hp(x, fc, order=2):
    b, a = signal.butter(order, min(fc / (SR / 2), 0.99), "high")
    return signal.lfilter(b, a, x)


def bp(x, f0, q=4.0):
    lo, hi = f0 / (1 + 0.5 / q), f0 * (1 + 0.5 / q)
    b, a = signal.butter(2, [lo / (SR / 2), min(hi / (SR / 2), 0.99)], "band")
    return signal.lfilter(b, a, x)


def sweep_lp(x, f_start, f_end):
    """Crude time-varying low-pass: crossfade blocks filtered at stepped cutoffs."""
    n = len(x)
    out = np.zeros(n)
    blocks = 24
    for k in range(blocks):
        i0, i1 = k * n // blocks, (k + 1) * n // blocks
        fc = f_start * (f_end / f_start) ** (k / max(blocks - 1, 1))
        out[i0:i1] = lp(x, fc)[i0:i1]
    return out


def reverb(x, mix=0.25, size=0.06, decay=0.5):
    """Small feedback comb + allpass network: enough to put sounds in a space."""
    out = np.copy(x)
    for d, g in ((size, decay), (size * 1.37, decay * 0.9), (size * 1.79, decay * 0.8), (size * 2.3, decay * 0.7)):
        D = int(d * SR)
        y = np.zeros(len(x) + D * 8)
        y[:len(x)] = x
        for i in range(D, len(y)):
            y[i] += g * y[i - D]
        out = out + mix * 0.25 * y[:len(x)]
    return out


def pad_to(x, dur):
    n = int(SR * dur)
    return np.pad(x, (0, max(0, n - len(x))))[:n]


def mix(*xs):
    n = max(len(x) for x in xs)
    return sum(np.pad(x, (0, n - len(x))) for x in xs)


def norm(x, peak=0.9):
    m = np.max(np.abs(x)) or 1.0
    return x / m * peak


def tail(x, secs=0.25):
    return np.pad(x, (0, int(secs * SR)))


def write_wav(name, x, peak=0.85):
    x = norm(x, peak)
    f = min(64, len(x) // 4)
    x[:f] *= np.linspace(0, 1, f)
    x[-f:] *= np.linspace(1, 0, f)
    data = (x * 32767).astype(np.int16)
    with wave.open(os.path.join(SFX, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())


def metal_ping(f, dur, bright=1.0):
    """Inharmonic struck-metal partials (the robot's world is made of scrap)."""
    parts = [(1.0, 1.0), (2.76, 0.5), (5.40, 0.25 * bright), (8.93, 0.12 * bright)]
    x = sum(a * sine(f * r, dur) * expdecay(int(SR * dur), dur / (1 + i * 1.5)) for i, (r, a) in enumerate(parts))
    return x


def sfx():
    S = {}
    n = lambda d: int(SR * d)
    d = 0.16
    S["jump"] = lp(noise(d), 1800) * env(n(d), 0.004, 0.12) * 0.5 + sine(np.linspace(180, 340, n(d)), d) * env(n(d), 0.002, 0.08) * 0.4
    d = 0.18
    S["land"] = lp(noise(d), 600) * expdecay(n(d), 0.04) + sine(np.linspace(110, 60, n(d)), d) * expdecay(n(d), 0.05) * 0.8
    d = 0.22
    S["dash"] = sweep_lp(noise(d), 600, 5000) * env(n(d), 0.01, 0.2) + sine(np.linspace(300, 900, n(d)), d) * env(n(d), 0.01, 0.18) * 0.2
    d = 0.08
    S["step"] = lp(noise(d), 900) * expdecay(n(d), 0.015) * 0.6
    d = 0.32
    S["slide"] = sweep_lp(noise(d), 3200, 900) * env(n(d), 0.01, 0.22) * 0.55 + sine(np.linspace(95, 70, n(d)), d) * env(n(d), 0.01, 0.2) * 0.25
    d = 0.17
    S["swing"] = bp(noise(d), 2400, 2) * env(n(d), 0.01, 0.15) + sine(np.linspace(900, 500, n(d)), d) * env(n(d), 0.005, 0.1) * 0.15
    d = 0.24
    S["swing_rush"] = mix(bp(noise(d), 1800, 1.5) * env(n(d), 0.008, 0.22), saw(np.linspace(220, 110, n(d)), d) * env(n(d), 0.005, 0.2) * 0.25,
                          metal_ping(1320, d, 0.6) * 0.3)
    d = 0.3
    S["hit"] = tail(mix(metal_ping(620, d) * 0.9, lp(noise(0.05), 3000) * 0.9, sine(np.linspace(150, 70, n(0.12)), 0.12) * 0.8), 0.05)
    d = 0.28
    S["throw"] = mix(sine(np.linspace(600, 1500, n(d)), d) * env(n(d), 0.005, 0.25) * 0.5, hp(noise(d), 3000) * env(n(d), 0.01, 0.2) * 0.4)
    S["recall"] = S["throw"][::-1].copy()
    d = 0.4
    S["charged"] = mix(sine(np.linspace(500, 2200, n(d)), d) * env(n(d), 0.005, 0.35) * 0.4, metal_ping(1760, d, 1.2) * 0.4,
                       hp(noise(d), 5000) * env(n(d), 0.005, 0.3) * 0.3)
    d = 0.22
    S["pin"] = mix(lp(noise(0.04), 2500), metal_ping(440, d) * 0.6, sine(np.linspace(120, 60, n(0.1)), 0.1) * 0.7)
    d = 0.35
    S["zip"] = mix(sweep_lp(saw(np.linspace(80, 400, n(d)), d), 400, 4000) * env(n(d), 0.01, 0.3) * 0.5, hp(noise(d), 2000) * env(n(d), 0.05, 0.3) * 0.3)
    d = 0.25
    S["catch"] = mix(metal_ping(1568, d, 0.4) * 0.5, metal_ping(2093, d, 0.3) * 0.3)
    d = 0.3
    S["hook"] = mix(metal_ping(700, d) * 0.6, lp(noise(0.08), 2500) * 0.6, *(metal_ping(900 + 120 * k, 0.1) * 0.15 for k in range(3)))
    d = 0.2
    S["glance"] = mix(metal_ping(1900, d, 1.5) * 0.6, hp(noise(0.03), 4000) * 0.4)
    d = 0.4
    S["hurt"] = mix(lp(noise(d), 1500) * expdecay(n(d), 0.08), square(np.linspace(220, 80, n(d)), d, 0.3) * expdecay(n(d), 0.1) * 0.3)
    d = 1.2
    S["die"] = mix(saw(np.linspace(300, 40, n(d)), d) * env(n(d), 0.01, 1.1) * 0.5, lp(noise(d), 800) * expdecay(n(d), 0.3) * 0.5)
    d = 0.5
    S["enemy_die"] = mix(lp(noise(d), 2000) * expdecay(n(d), 0.12), sine(np.linspace(200, 40, n(d)), d) * expdecay(n(d), 0.15) * 0.8,
                         metal_ping(300, d) * 0.3)
    d = 0.3
    S["enemy_hit"] = mix(metal_ping(480, d) * 0.6, lp(noise(0.05), 2000) * 0.6)
    d = 0.35
    S["laser"] = sine(np.linspace(1800, 400, n(d)), d) * env(n(d), 0.003, 0.3) * 0.5 + square(np.linspace(900, 200, n(d)), d, 0.25) * env(n(d), 0.003, 0.25) * 0.15
    d = 0.6
    S["telegraph"] = sine(880, d) * (0.5 + 0.5 * square(12, d)) * env(n(d), 0.01, 0.5, 0.6, 0.08) * 0.5
    d = 1.4
    S["slam"] = mix(lp(noise(d), 400) * expdecay(n(d), 0.35), sine(np.linspace(70, 30, n(d)), d) * expdecay(n(d), 0.5),
                    metal_ping(160, d) * 0.4)
    d = 1.0
    S["horn"] = mix(saw(110, d) + saw(110 * 1.005, d) + saw(164.8, d) * 0.6) * env(n(d), 0.08, 0.2, 0.7, 0.3) * 0.3
    S["horn"] = lp(S["horn"], 1400)
    d = 0.5
    S["break"] = mix(lp(noise(d), 3000) * expdecay(n(d), 0.12), *(metal_ping(300 + 170 * k, 0.4) * 0.2 for k in range(4)))
    d = 0.18
    S["scrap"] = metal_ping(1400 + 200 * rng.random(), d, 0.5) * 0.6
    d = 0.45
    S["coin"] = mix(metal_ping(1318, 0.3) * 0.5, np.pad(metal_ping(1976, 0.35), (n(0.07), 0)) * 0.5)
    d = 0.9
    arp = [523.3, 659.3, 784.0, 1046.5]
    S["item"] = mix(*(np.pad(metal_ping(f, 0.6, 0.6) * 0.4, (n(0.08 * i), 0)) for i, f in enumerate(arp)))
    d = 0.6
    S["heal"] = mix(sine(np.linspace(400, 800, n(d)), d) * env(n(d), 0.05, 0.5) * 0.4, sine(np.linspace(600, 1200, n(d)), d) * env(n(d), 0.1, 0.4) * 0.2)
    d = 0.3
    S["chip_in"] = mix(lp(noise(0.03), 4000) * 0.7, np.pad(metal_ping(988, 0.25, 0.4) * 0.5, (n(0.04), 0)),
                       np.pad(sine(np.linspace(300, 600, n(0.12)), 0.12) * expdecay(n(0.12), 0.05) * 0.3, (n(0.05), 0)))
    S["chip_out"] = mix(sine(np.linspace(600, 250, n(0.15)), 0.15) * expdecay(n(0.15), 0.06) * 0.4, lp(noise(0.03), 3000) * 0.5)
    d = 0.5
    S["buy"] = mix(metal_ping(1568, 0.4) * 0.4, np.pad(metal_ping(2349, 0.4) * 0.4, (n(0.09), 0)), lp(noise(0.04), 5000) * 0.3)
    d = 0.05
    S["ui_move"] = square(1200, d, 0.5) * env(n(d), 0.001, 0.04) * 0.25
    d = 0.09
    S["ui_select"] = mix(square(880, 0.045, 0.5) * 0.25, np.pad(square(1320, 0.05, 0.5) * 0.25, (n(0.04), 0))) * env(n(0.09), 0.001, 0.09)
    S["ui_back"] = mix(square(1320, 0.045, 0.5) * 0.25, np.pad(square(880, 0.05, 0.5) * 0.25, (n(0.04), 0))) * env(n(0.09), 0.001, 0.09)
    d = 0.03
    S["blip"] = square(660, d, 0.25) * env(n(d), 0.001, 0.025) * 0.2
    d = 1.2
    S["dock"] = mix(sine(55, d) * 0.5, sine(110, d) * 0.3, sine(np.linspace(200, 800, n(d)), d) * 0.2) * env(n(d), 0.2, 0.6, 0.4, 0.3)
    d = 1.6
    S["shard"] = mix(*(np.pad(metal_ping(f, 1.2, 1.0) * 0.35, (n(0.12 * i), 0)) for i, f in enumerate([392, 523.3, 659.3, 784, 1046.5])),
                     sine(196, d) * env(n(d), 0.3, 1.0, 0.0, 0.2) * 0.3)
    d = 0.6
    S["door"] = mix(lp(noise(d), 500) * env(n(d), 0.05, 0.5) * 0.7, saw(np.linspace(60, 45, n(d)), d) * env(n(d), 0.05, 0.5) * 0.3)
    d = 2.5
    S["steam_door"] = mix(hp(noise(d), 1500) * env(n(d), 0.05, 0.6, 0.5, 1.4) * 0.5, lp(noise(d), 300) * env(n(d), 0.3, 1.5) * 0.6,
                          *(np.pad(metal_ping(180 * (k + 1), 0.8) * 0.2, (n(0.3 * k), 0)) for k in range(4)))
    d = 0.4
    S["sludge"] = lp(noise(d), 700) * env(n(d), 0.01, 0.35) * 0.8 + sine(np.linspace(90, 50, n(d)), d) * expdecay(n(d), 0.1) * 0.5
    d = 0.5
    S["crusher"] = mix(lp(noise(d), 600) * expdecay(n(d), 0.1), metal_ping(140, d) * 0.6, sine(np.linspace(80, 35, n(d)), d) * expdecay(n(d), 0.15))
    d = 0.9
    S["steam"] = hp(noise(d), 2200) * env(n(d), 0.02, 0.3, 0.5, 0.4, 0.2) * 0.55 + lp(noise(d), 500) * env(n(d), 0.05, 0.6) * 0.25
    d = 0.45
    S["valve"] = mix(*(np.pad(metal_ping(520 + 60 * k, 0.2, 0.5) * 0.3, (n(0.07 * k), 0)) for k in range(4)),
                     np.pad(hp(noise(0.25), 3000) * env(n(0.25), 0.01, 0.2) * 0.3, (n(0.18), 0)))
    d = 0.3
    S["gear"] = mix(metal_ping(210, d, 0.4) * 0.6, lp(noise(0.04), 1500) * 0.5)
    d = 0.35
    S["bat"] = lp(noise(d), 900) * (0.5 + 0.5 * np.sin(2 * np.pi * 9 * t_(d))) * env(n(d), 0.02, 0.3) * 0.6
    d = 0.7
    S["burst"] = mix(lp(noise(d), 2500) * expdecay(n(d), 0.12), hp(noise(d), 2000) * env(n(d), 0.005, 0.6) * 0.5,
                     sine(np.linspace(140, 40, n(d)), d) * expdecay(n(d), 0.15) * 0.8)
    d = 0.5
    S["creak"] = mix(bp(noise(d), 700, 6) * env(n(d), 0.05, 0.4) * 0.6, metal_ping(880, d, 0.3) * 0.15)
    for name, x in S.items():
        write_wav(name, reverb(x, 0.18, 0.03, 0.4) if name not in ("ui_move", "ui_select", "ui_back", "blip") else x)
    return list(S)


NOTE = {"C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5, "F#": 6, "G": 7, "G#": 8, "A": 9, "A#": 10, "B": 11}


def hz(name, octave):
    return 440.0 * 2 ** ((NOTE[name] + 12 * (octave + 1) - 69) / 12)


def pad_voice(f, dur, bright=900):
    x = saw(f, dur) + saw(f * 1.004, dur) * 0.8 + saw(f * 0.996, dur) * 0.8
    return lp(x, bright) * 0.3


def pluck(f, dur, decay=0.6, bright=3000):
    """Karplus-Strong-ish plucked string: a warm 'found guitar' for the camp."""
    n = int(SR * dur)
    period = int(SR / f)
    buf = rng.uniform(-1, 1, period)
    out = np.zeros(n)
    for i in range(n):
        out[i] = buf[i % period]
        buf[i % period] = 0.5 * (buf[i % period] + buf[(i + 1) % period]) * 0.996
    return lp(out, bright) * expdecay(n, decay)


def render_track(name, length, layers):
    x = np.zeros(int(SR * length))
    for start, sig in layers:
        i = int(start * SR)
        seg = sig[: max(0, len(x) - i)]
        x[i:i + len(seg)] += seg
    fade = int(2.0 * SR)
    head = x[:fade].copy()
    x[:fade] = head * np.linspace(0, 1, fade) + x[-fade:] * np.linspace(1, 0, fade)
    x = x[:-fade]
    x = norm(reverb(x, 0.35, 0.09, 0.55), 0.7)
    stereo = np.stack([x, np.roll(x, int(0.011 * SR))], axis=1)
    raw = os.path.join(MUS, name + ".wav")
    data = (stereo * 32767).astype(np.int16)
    with wave.open(raw, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", raw, "-c:a", "libvorbis", "-q:a", "4",
                    os.path.join(MUS, name + ".ogg")], check=True)
    os.remove(raw)


def music():
    L = 48.0
    layers = [(0, pad_voice(hz("D", 2), L, 320) * env(int(SR * L), 3, 0, 1, 3, L - 6))]
    layers.append((0, pad_voice(hz("A", 2), L, 260) * 0.6 * (0.6 + 0.4 * np.sin(2 * np.pi * t_(L) / 16))))
    for k in range(28):
        s = rng.uniform(0, L - 1)
        layers.append((s, metal_ping(rng.choice([1174.7, 1318.5, 1568.0, 880.0]), 0.8, 0.3) * 0.08))
    for s in (6, 22, 37):
        layers.append((s, lp(noise(4.0), 200) * env(int(SR * 4), 1.5, 2.5) * 0.25))
    render_track("cave", L, layers)

    beat = 0.5
    prog = [("D", "F#", "A"), ("B", "D", "F#"), ("G", "B", "D"), ("A", "C#", "E")]
    L = beat * 8 * len(prog) * 2
    layers = []
    for rep in range(2):
        for ci, chord in enumerate(prog):
            t0 = (rep * len(prog) + ci) * beat * 8
            layers.append((t0, sum(pad_voice(hz(n_, 3), beat * 8.5, 700) for n_ in chord) * 0.35 * env(int(SR * beat * 8.5), 0.6, 0, 1, 0.8, beat * 6)))
            pattern = [0, 1, 2, 1, 0, 2, 1, 2]
            for k, idx in enumerate(pattern):
                oct_ = 4 if k % 4 else 3
                layers.append((t0 + k * beat, pluck(hz(chord[idx], oct_), 1.2, 0.5) * 0.55))
            layers.append((t0, pluck(hz(chord[0], 2), 2.0, 0.9, 1200) * 0.6))
    render_track("camp", L, layers)

    L = 40.0
    layers = [(0, pad_voice(hz("F", 2), L, 500) * 0.6 * env(int(SR * L), 3, 0, 1, 3, L - 6))]
    bells = [hz("F", 5), hz("A#", 4), hz("C", 5), hz("G#", 4), hz("D#", 5)]
    for k in range(16):
        layers.append((k * 2.5, metal_ping(bells[k % len(bells)], 2.4, 0.8) * 0.18))
    for k in range(10):
        layers.append((k * 4.0 + 1.0, hp(noise(2.0), 2500) * env(int(SR * 2), 0.8, 1.2) * 0.07))
    render_track("hollow", L, layers)

    bpm = 104
    b = 60 / bpm
    L = b * 48
    layers = [(0, pad_voice(hz("E", 2), L, 400) * 0.5)]
    for k in range(48):
        tk = k * b
        if k % 3 == 0:
            layers.append((tk, sine(np.linspace(90, 45, int(SR * 0.25)), 0.25) * expdecay(int(SR * 0.25), 0.07) * 0.9))
        layers.append((tk, hp(noise(0.06), 6000) * expdecay(int(SR * 0.06), 0.015) * (0.25 if k % 3 else 0.4)))
        if k % 6 == 4:
            layers.append((tk, metal_ping(330, 0.5, 0.8) * 0.25))
    riff = [hz("E", 3), hz("G", 3), hz("B", 2), hz("A", 3)]
    for k in range(16):
        layers.append((k * b * 3, lp(square(riff[k % 4], b * 2.5, 0.3), 900) * env(int(SR * b * 2.5), 0.01, 0.4, 0.3, 0.2, b) * 0.2))
    render_track("industrial", L, layers)

    bpm = 148
    b = 60 / bpm
    L = b * 64
    layers = []
    bass = [hz("C", 2), hz("C", 2), hz("D#", 2), hz("F", 2), hz("C", 2), hz("C", 2), hz("G", 1), hz("A#", 1)]
    for k in range(64):
        tk = k * b
        if k % 2 == 0:
            layers.append((tk, sine(np.linspace(120, 40, int(SR * 0.3)), 0.3) * expdecay(int(SR * 0.3), 0.08) * 1.0))
        if k % 4 == 2:
            layers.append((tk, lp(noise(0.2), 4000) * expdecay(int(SR * 0.2), 0.05) * 0.6))
        layers.append((tk + b / 2, hp(noise(0.05), 7000) * expdecay(int(SR * 0.05), 0.01) * 0.25))
        f = bass[(k // 2) % len(bass)]
        layers.append((tk, np.tanh(3 * lp(saw(f, b * 0.9), 600)) * env(int(SR * b * 0.9), 0.005, 0.3, 0.5, 0.05, b * 0.4) * 0.35))
    for k in range(0, 64, 16):
        layers.append((k * b, lp(saw(hz("C", 3), b * 3) + saw(hz("G", 3), b * 3) * 0.7, 1500) * env(int(SR * b * 3), 0.02, 0.5, 0.4, 0.3, b) * 0.35))
    render_track("boss", L, layers)

    L = 36.0
    melody = [("D", 4, 2), ("F", 4, 1), ("E", 4, 1), ("A", 3, 3), ("C", 4, 1), ("D", 4, 2), ("A", 4, 2), ("G", 4, 3), ("F", 4, 1), ("E", 4, 4)]
    layers = [(0, (pad_voice(hz("D", 2), L, 500) + pad_voice(hz("A", 2), L, 500) * 0.7) * 0.6 * env(int(SR * L), 2, 0, 1, 3, L - 5))]
    tt = 2.0
    for nm, o, beats in melody:
        dur = beats * 0.8
        f = hz(nm, o)
        vib = f * (1 + 0.004 * np.sin(2 * np.pi * 5 * t_(dur + 0.6)))
        layers.append((tt, lp(sine(vib, dur + 0.6) + 0.3 * saw(vib, dur + 0.6), 2200) * env(int(SR * (dur + 0.6)), 0.05, 0.2, 0.6, 0.5, dur - 0.3) * 0.3))
        tt += dur
    render_track("title", L, layers)

    bpm = 84
    b = 60 / bpm
    prog = [("D", "F", "A"), ("A#", "D", "F"), ("G", "A#", "D"), ("A", "C#", "E")]
    L = b * 3 * 4 * len(prog)
    layers = []
    for rep in range(4):
        for ci, chord in enumerate(prog):
            t0 = (rep * len(prog) + ci) * b * 3
            layers.append((t0, lp(saw(hz(chord[0], 2), b * 1.2), 500) * env(int(SR * b * 1.2), 0.02, 0.4) * 0.35))
            for beat_i in (1, 2):
                stab = sum(lp(square(hz(n_, 3), b * 0.7, 0.4), 1100) for n_ in chord[1:])
                layers.append((t0 + beat_i * b, stab * env(int(SR * b * 0.7), 0.03, 0.2, 0.3, 0.2, b * 0.3) * 0.09))
        layers.append((rep * b * 3 * len(prog) + b * 6, metal_ping(hz("D", 5), 2.0, 0.6) * 0.12))
    for k in range(int(L / b)):
        layers.append((k * b, hp(noise(0.02), 5000) * expdecay(int(SR * 0.02), 0.004) * 0.12))
    for s_ in (3.0, 14.0, 27.0):
        layers.append((s_, hp(noise(2.5), 2000) * env(int(SR * 2.5), 0.6, 1.6) * 0.06))
    melody = [("A", 4, 3), ("F", 4, 2), ("E", 4, 1), ("D", 4, 3), ("A#", 3, 3), ("C", 4, 2), ("D", 4, 1), ("E", 4, 6)]
    tt = b * 3 * 4
    for nm, o, beats in melody:
        dur = beats * b
        f = hz(nm, o)
        vib = f * (1 + 0.005 * np.sin(2 * np.pi * 4.5 * t_(dur + 0.4)))
        layers.append((tt, lp(saw(vib, dur + 0.4) * 0.5 + square(vib, dur + 0.4, 0.3) * 0.3, 1400) * env(int(SR * (dur + 0.4)), 0.08, 0.2, 0.7, 0.4, dur - 0.2) * 0.16))
        tt += dur
    render_track("underworks", L, layers)

    bpm = 156
    b = 60 / bpm
    L = b * 96
    layers = []
    bass = [hz("D", 2), hz("D", 2), hz("F", 2), hz("E", 2), hz("D", 2), hz("D", 2), hz("A#", 1), hz("A", 1)]
    for k in range(96):
        tk = k * b
        if k % 3 == 0:
            layers.append((tk, sine(np.linspace(130, 40, int(SR * 0.28)), 0.28) * expdecay(int(SR * 0.28), 0.08)))
        else:
            layers.append((tk, hp(noise(0.08), 3500) * expdecay(int(SR * 0.08), 0.02) * 0.35))
        if k % 6 == 3:
            layers.append((tk, metal_ping(392, 0.4, 1.0) * 0.25))
        f = bass[(k // 3) % len(bass)]
        layers.append((tk, np.tanh(2.5 * lp(saw(f, b * 0.9), 700)) * env(int(SR * b * 0.9), 0.005, 0.3, 0.4, 0.05, b * 0.4) * 0.3))
    for k in range(0, 96, 24):
        layers.append((k * b, lp(saw(hz("D", 3), b * 5) + saw(hz("A", 3), b * 5) * 0.7, 1300) * env(int(SR * b * 5), 0.02, 0.5, 0.4, 0.4, b * 2) * 0.3))
        layers.append((k * b + b * 12, hp(noise(1.2), 1800) * env(int(SR * 1.2), 0.05, 1.0) * 0.25))
    render_track("governor", L, layers)


if __name__ == "__main__":
    names = sfx()
    music()
    print("sfx:", len(names), "music: 8 tracks")
