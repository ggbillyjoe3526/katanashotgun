"""Procedural placeholder soundtrack for KATANA / SHOTGUN: fast tempos with a
dark electronic bass-music sound (talking wobble basses, sub, dark plucks and
leads, EDM drums, zaps and glitch edits).

Run:  python3 tools/gen_music.py      (needs numpy, scipy, ffmpeg)

Every track is composed from a seed: key, tempo, chord progression, drum and
bass styles, bass and lead instruments and generated melodies all differ, and each track is
arranged in sections (intro, groove, lead, breakdown, build, drop, outro).
The game shuffles the combat tracks per run and crossfades between them, so
the music doesn't loop the same phrase over and over.

Output (assets/music/):
  combat_*.ogg  ~95-100 s each, played as a shuffled playlist
  boss_*.ogg    looping boss themes
  title.ogg     looping title theme
"""
import os
import subprocess
import numpy as np
from scipy.signal import butter, lfilter, fftconvolve
from scipy.io import wavfile

SR = 32000
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "music")

SCALES = {
    "minor": [0, 2, 3, 5, 7, 8, 10],
    "dorian": [0, 2, 3, 5, 7, 9, 10],
    "harmonic": [0, 2, 3, 5, 7, 8, 11],
    "phrygian": [0, 1, 3, 5, 7, 8, 10],
}


def midi(m):
    return 440.0 * 2.0 ** ((m - 69) / 12.0)


def lp(x, fc, order=2):
    b, a = butter(order, min(max(fc, 30.0), SR / 2 - 200) / (SR / 2), "low")
    return lfilter(b, a, x)


def hp(x, fc, order=2):
    b, a = butter(order, min(fc, SR / 2 - 200) / (SR / 2), "high")
    return lfilter(b, a, x)


def bp(x, lo, hi, order=2):
    b, a = butter(order, [lo / (SR / 2), min(hi, SR / 2 - 200) / (SR / 2)], "band")
    return lfilter(b, a, x)


class Rng:
    def __init__(self, seed):
        self.r = np.random.default_rng(seed)

    def choice(self, seq):
        return seq[int(self.r.integers(0, len(seq)))]

    def f(self, a=0.0, b=1.0):
        return float(self.r.uniform(a, b))

    def i(self, a, b):
        return int(self.r.integers(a, b + 1))

    def noise(self, n):
        return self.r.uniform(-1, 1, n)


# ---------------------------------------------------------------- oscillators
def saw(f, n, phase=0.0):
    t = np.arange(n) / SR
    return ((t * f + phase) % 1.0) * 2.0 - 1.0


def square(f, n, pw=0.5, phase=0.0):
    t = np.arange(n) / SR
    return np.where(((t * f + phase) % 1.0) < pw, 1.0, -1.0)


def tri(f, n):
    t = np.arange(n) / SR
    return 2.0 * np.abs(2.0 * ((t * f) % 1.0) - 1.0) - 1.0


def env(n, a=0.005, d=0.1, s=0.7, r=0.1, hold=None):
    """ADSR over n samples; release starts at `hold` seconds (default n - r)."""
    t = np.arange(n) / SR
    total = n / SR
    hold = total - r if hold is None else hold
    e = np.where(t < a, t / max(a, 1e-4), 1.0)
    dec = np.clip((t - a) / max(d, 1e-4), 0, 1)
    e = np.where(t >= a, 1.0 - (1.0 - s) * dec, e)
    rel = np.clip((t - hold) / max(r, 1e-4), 0, 1)
    return e * (1.0 - rel)


# ---------------------------------------------------------------- instruments
def inst_supersaw(f, dur, rng, bright=2400.0, voices=5, detune=0.011):
    n = int(SR * (dur + 0.6))
    L = np.zeros(n)
    R = np.zeros(n)
    for v in range(voices):
        d = 1.0 + detune * (v - (voices - 1) / 2) / ((voices - 1) / 2)
        s = saw(f * d, n, rng.f())
        if v % 2 == 0:
            L += s
        else:
            R += s
        if v == voices // 2:
            L += s * 0.5
            R += s * 0.5
    e = env(n, a=0.25, d=0.4, s=0.85, r=0.55)
    return lp(L, bright) * e / voices, lp(R, bright) * e / voices


def inst_lead(f, dur, kind, glide_from=None):
    n = int(SR * (dur + 0.35))
    t = np.arange(n) / SR
    vib = 1.0 + 0.006 * np.sin(2 * np.pi * 5.6 * t) * np.clip((t - 0.18) / 0.3, 0, 1)
    if glide_from is not None:
        g = np.clip(t / 0.06, 0, 1)
        freq = (glide_from + (f - glide_from) * g) * vib
    else:
        freq = f * vib
    ph = np.cumsum(freq) / SR
    if kind == "saw":
        osc = (ph % 1.0) * 2 - 1 + ((ph * 1.005) % 1.0) * 2 - 1
        osc = lp(osc * 0.5, 3600)
    elif kind == "square":
        osc = np.where((ph % 1.0) < 0.5, 1.0, -1.0) * 0.6 + np.where(((ph * 0.5) % 1.0) < 0.5, 0.4, -0.4)
        osc = lp(osc, 3000)
    elif kind == "fm":
        idx = 2.6 * np.exp(-t * 4.0) + 0.4
        osc = np.sin(2 * np.pi * ph + idx * np.sin(2 * np.pi * ph * 2.0))
    else:  # "brass" - sync-ish bright saw
        osc = ((ph * 1.0) % 1.0) * 2 - 1
        osc = lp(osc + 0.5 * (((ph * 2.003) % 1.0) * 2 - 1), 2800)
    e = env(n, a=0.012, d=0.25, s=0.8, r=0.22, hold=dur)
    return osc * e


# ---- dark electronic bass-music instruments (owner, 2026-10-18: "no string
# instruments, more of an electronic EDM feel, think of the artist Rezz"):
# talking formant wobble basses, a clean sub, dark detuned leads and plucks,
# zaps and impacts. Glitch edits stay.
def _formant(x, v):
    """Morph x between an "oo" and an "ah" vowel as v goes 0..1 (a talking bass)."""
    oo = bp(x, 250, 450) + bp(x, 700, 1000) * 0.6
    ah = bp(x, 650, 900) + bp(x, 1050, 1350) * 0.7 + bp(x, 2300, 2700) * 0.25
    return oo * (1 - v) + ah * v


def inst_wob(f, dur, t_start, lfo_hz):
    """Distorted wobble bass. The LFO runs on song time, so back-to-back notes
    keep one continuous, hypnotic movement."""
    n = int(SR * (dur + 0.03))
    t = np.arange(n) / SR
    x = saw(f, n) + saw(f * 1.006, n, 0.4) * 0.8 + square(f * 0.5, n, 0.5) * 0.5
    x = np.tanh(x * 2.5)
    v = 0.5 - 0.5 * np.cos(2 * np.pi * lfo_hz * (t_start + t))
    y = _formant(x, v) * 2.2 + (lp(x, 220) * (1 - v) + lp(x, 1800) * v) * 0.6
    y = np.tanh(y * 2.0)
    return y * env(n, a=0.004, d=0.05, s=0.95, r=0.02, hold=dur) * 0.7


def inst_sub(f, dur):
    """Clean sine sub under the bass; kept off the distorted bus."""
    n = int(SR * (dur + 0.03))
    t = np.arange(n) / SR
    return np.sin(2 * np.pi * f * t) * env(n, a=0.004, d=0.05, s=1.0, r=0.02, hold=dur)


def inst_dark(f, dur):
    """Dark, detuned mono lead with a small pitch dip into each note."""
    n = int(SR * (dur + 0.12))
    t = np.arange(n) / SR
    bend = 1.0 + 0.03 * np.exp(-t * 40.0)
    ph = np.cumsum(f * bend) / SR
    x = np.where((ph % 1.0) < 0.3, 1.0, -1.0) + ((ph * 1.007) % 1.0 * 2 - 1) * 0.6 + ((ph * 0.993) % 1.0 * 2 - 1) * 0.6
    fenv = np.exp(-t * 6.0)
    x = np.tanh((lp(x, 1400) * (1 - fenv) + lp(x, 3200) * fenv) * 1.8)
    return x * env(n, a=0.004, d=0.2, s=0.8, r=0.1, hold=dur) * 0.6


def inst_pluck(f, dur):
    """Short, dark, filtered square pluck for the hypnotic sequences."""
    n = int(SR * (dur + 0.15))
    t = np.arange(n) / SR
    x = square(f, n, 0.35) + saw(f * 1.004, n) * 0.5
    fenv = np.exp(-t * 22.0)
    x = lp(x, 500) * (1 - fenv) + lp(x, 3500) * fenv
    return x * np.exp(-t * 9.0) * np.minimum(1.0, t / 0.002) * 0.6


def fx_zap(rng):
    """A laser zap: a fast falling FM sweep."""
    n = int(SR * rng.f(0.15, 0.35))
    t = np.arange(n) / SR
    f = 60 + rng.f(1500, 4000) * np.exp(-t * rng.f(12, 30))
    ph = np.cumsum(f) / SR
    x = np.sin(2 * np.pi * ph + 2.0 * np.sin(2 * np.pi * ph * 1.5))
    return x * np.exp(-t * 8.0) * 0.5


def fx_impact(rng):
    """Drop impact: a falling sub boom with a noise burst."""
    n = int(SR * 1.6)
    t = np.arange(n) / SR
    f = 32 + 70 * np.exp(-t * 4.0)
    boom = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 2.2)
    burst = lp(rng.noise(n), 2500) * np.exp(-t * 9.0) * 0.5
    return np.tanh((boom + burst) * 1.5) * 0.8


def inst_screech(f, dur, rng):
    """Bitcrushed FM screech for the more synthetic tracks."""
    n = int(SR * (dur + 0.05))
    t = np.arange(n) / SR
    idx = 4.0 + 2.0 * np.sin(2 * np.pi * 7.0 * t)
    x = np.sin(2 * np.pi * f * t + idx * np.sin(2 * np.pi * f * 1.01 * t))
    x = crush(np.tanh(x * 3.0), 5, 3)
    return lp(x, 5000) * env(n, a=0.003, d=0.1, s=0.85, r=0.04, hold=dur) * 0.5


def inst_reese(f, dur):
    """Detuned, phasing, distorted reese bass."""
    n = int(SR * (dur + 0.03))
    t = np.arange(n) / SR
    x = saw(f, n) + saw(f * 1.012, n, 0.3) + saw(f * 0.994, n, 0.6) * 0.6
    x = lp(x, 900 + 600 * np.sin(2 * np.pi * 0.7 * t[0]))
    x = np.tanh(x * 3.5) + np.sin(2 * np.pi * f * 0.5 * t) * 0.6
    return lp(x, 3200) * env(n, a=0.004, d=0.05, s=0.95, r=0.02, hold=dur) * 0.7


def inst_growl(f, dur, wobble_hz):
    """FM growl bass whose bite wobbles in time with the beat."""
    n = int(SR * (dur + 0.03))
    t = np.arange(n) / SR
    idx = 1.0 + 5.0 * (0.5 + 0.5 * np.sin(2 * np.pi * wobble_hz * t - np.pi / 2))
    x = np.sin(2 * np.pi * f * t + idx * np.sin(2 * np.pi * f * 2.0 * t))
    x = np.tanh(x * 4.0) + np.sin(2 * np.pi * f * t) * 0.5
    return lp(crush(x, 7, 2), 3800) * env(n, a=0.003, d=0.05, s=0.95, r=0.02, hold=dur) * 0.7


def glitch_blip(f, rng):
    """A tiny crushed metallic blip or noise burst, for glitch stabs and percussion."""
    kind = rng.choice(["fm", "metal", "noise"])
    n = int(SR * rng.f(0.03, 0.09))
    t = np.arange(n) / SR
    if kind == "fm":
        x = np.sin(2 * np.pi * f * t * (1 + 3 * np.exp(-t * 60)) + 6 * np.sin(2 * np.pi * f * 3.7 * t))
    elif kind == "metal":
        x = sum(square(f * r, n) for r in (1.0, 1.47, 2.13, 2.89)) * 0.25
    else:
        x = bp(rng.noise(n), 1200, 6000)
    return crush(x, rng.i(3, 6), rng.i(2, 8)) * np.exp(-t * rng.f(25, 60))


def inst_bell(f, dur):
    n = int(SR * (dur + 1.2))
    t = np.arange(n) / SR
    idx = 3.0 * np.exp(-t * 3.0)
    x = np.sin(2 * np.pi * f * t + idx * np.sin(2 * np.pi * f * 3.5 * t))
    return x * np.exp(-t * 2.2) * np.minimum(1, t / 0.003)


# ---------------------------------------------------------------- drums
def d_kick(rng, punch=1.0):
    n = int(SR * 0.5)
    t = np.arange(n) / SR
    f = 46 + 170 * np.exp(-t * 34) * punch
    x = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 5.5)
    click = hp(rng.noise(n), 3000) * np.exp(-t * 400) * 0.5
    return np.tanh((x + click) * 2.2)


def d_snare(rng, gated=True):
    n = int(SR * (0.42 if gated else 0.25))
    t = np.arange(n) / SR
    body = np.sin(2 * np.pi * 185 * t) * np.exp(-t * 22) * 0.7
    nz = bp(rng.noise(n), 900, 9000) * np.exp(-t * 16)
    tail = 0.0
    if gated:
        # 80s gated reverb: dense noise tail that is cut off abruptly
        tail = lp(rng.noise(n), 6500) * 0.35 * np.where(t < 0.24, np.exp(-t * 2.0), 0.0)
        tail = tail * np.clip((0.26 - t) / 0.02, 0, 1)
    return body + nz + tail


def d_clap(rng):
    n = int(SR * 0.3)
    t = np.arange(n) / SR
    x = np.zeros(n)
    for k in range(4):
        s = int(SR * 0.009 * k)
        seg = bp(rng.noise(n - s), 1000, 5000) * np.exp(-np.arange(n - s) / SR * (60 if k < 3 else 12))
        x[s:] += seg
    return x * 0.8


def d_hat(rng, open_=False):
    n = int(SR * (0.32 if open_ else 0.06))
    t = np.arange(n) / SR
    m = sum(square(f, n) for f in [205.3, 304.4, 369.6, 522.7, 540.0, 800.0])
    x = hp(bp(m, 6000, 12000) + rng.noise(n) * 0.4, 7000)
    return x * np.exp(-t * (9 if open_ else 70)) * 0.35


def d_crash(rng):
    n = int(SR * 2.2)
    t = np.arange(n) / SR
    m = sum(square(f, n) for f in [327.0, 445.0, 612.0, 793.0, 1011.0])
    return hp(m * 0.3 + rng.noise(n), 4500) * np.exp(-t * 2.2) * 0.3


def fx_riser(rng, dur):
    n = int(SR * dur)
    t = np.arange(n) / SR
    out = np.zeros(n)
    chunks = 24
    nz = rng.noise(n)
    edges = np.linspace(0, n, chunks + 1).astype(int)
    for c in range(chunks):
        fc = 400 + 7000 * (c / chunks) ** 2
        seg = bp(nz, fc * 0.7, fc * 1.4)
        out[edges[c]:edges[c + 1]] = seg[edges[c]:edges[c + 1]]
    return out * (t / dur) ** 2 * 0.6


# ---------------------------------------------------------------- mixing helpers
class Bus:
    def __init__(self, n):
        self.L = np.zeros(n)
        self.R = np.zeros(n)

    def add(self, x, t, pan=0.0, gain=1.0):
        s = int(t * SR)
        if s >= len(self.L):
            return
        e = min(len(self.L), s + len(x))
        a = np.cos((pan + 1) * np.pi / 4) * gain
        b = np.sin((pan + 1) * np.pi / 4) * gain
        self.L[s:e] += x[: e - s] * a
        self.R[s:e] += x[: e - s] * b

    def add_st(self, l, r, t, gain=1.0):
        s = int(t * SR)
        if s >= len(self.L):
            return
        e = min(len(self.L), s + len(l))
        self.L[s:e] += l[: e - s] * gain
        self.R[s:e] += r[: e - s] * gain


def delay(bus, seconds, fb=0.4, taps=4, pingpong=True):
    d = int(SR * seconds)
    L, R = bus.L.copy(), bus.R.copy()
    for k in range(1, taps + 1):
        g = fb ** k
        src_l, src_r = (bus.R, bus.L) if (pingpong and k % 2 == 1) else (bus.L, bus.R)
        L[d * k:] += src_l[:-d * k] * g
        R[d * k:] += src_r[:-d * k] * g
    bus.L, bus.R = L, R


def reverb_ir(seconds, seed, damp=6000.0):
    r = np.random.default_rng(seed)
    n = int(SR * seconds)
    t = np.arange(n) / SR
    decay = np.exp(-t * 6.9 / seconds)
    irl = lp(r.uniform(-1, 1, n), damp) * decay
    irr = lp(r.uniform(-1, 1, n), damp) * decay
    irl[:int(SR * 0.012)] = 0
    irr[:int(SR * 0.017)] = 0
    return irl / np.sqrt(np.sum(irl ** 2)), irr / np.sqrt(np.sum(irr ** 2))


def apply_reverb(bus, ir, mix):
    wl = fftconvolve(bus.L, ir[0])[: len(bus.L)]
    wr = fftconvolve(bus.R, ir[1])[: len(bus.R)]
    bus.L = bus.L + wl * mix
    bus.R = bus.R + wr * mix


# ---------------------------------------------------------------- composition
# ---------------------------------------------------------------- dirt and glitches
# Owner's call (2026-10-18): glitchy and distorted. Basses and leads are
# driven hard, drums get parallel grit, and phrase ends are cut up with
# stutters, tape stops, reverses, gates and bitcrush bursts.
def drive(bus, amount, tone=5000.0, mix=1.0):
    """Waveshaper distortion, low-passed so it growls rather than fizzes."""
    k = np.tanh(amount)
    for ch in ("L", "R"):
        x = getattr(bus, ch)
        wet = lp(np.tanh(x * amount) / k, tone)
        setattr(bus, ch, x * (1 - mix) + wet * mix)


def crush(x, bits=6, hold=4):
    """Bit depth and sample-rate reduction."""
    q = 2 ** (bits - 1)
    y = np.round(x * q) / q
    idx = (np.arange(len(y)) // hold) * hold
    return y[np.minimum(idx, len(y) - 1)]


def _ramp(n, k=64):
    w = np.ones(n)
    k = min(k, n // 2)
    if k > 0:
        w[:k] = np.linspace(0, 1, k)
        w[-k:] = np.linspace(1, 0, k)
    return w


def glitch(L, R, s, e, kind, s16, rng):
    """Rewrites L/R[s:e] with one glitch (the same edit on both channels)."""
    n = e - s
    if n <= 64:
        return
    ln = max(64, int(s16 * SR * rng.choice([0.5, 1.0])))
    gate_ln = max(64, int(s16 * SR / 2))
    mask = lp(np.repeat([1.0 if rng.f() < 0.55 else 0.0 for _ in range(n // gate_ln + 1)], gate_ln)[:n], 300)
    for x in (L, R):
        seg = x[s:e].copy()
        if kind == "stutter":
            piece = x[s:s + ln] * _ramp(ln, 32)
            out = np.tile(piece, n // ln + 1)[:n]
        elif kind == "tapestop":
            rate = (1.0 - np.arange(n) / n) ** 1.6
            out = np.interp(np.cumsum(rate), np.arange(n), seg) * _ramp(n, 32)
        elif kind == "reverse":
            out = seg[::-1] * _ramp(n, 64)
        elif kind == "gate":
            out = seg * mask
        else:  # crush
            out = crush(seg, 5, 6) * 0.9
        x[s:e] = out


GLITCHES = ["stutter", "tapestop", "reverse", "gate", "crush"]


def glitch_pass(L, R, rng, sections, bar, beat, kind):
    """Glitches the end of most phrases, plus quick stutters in drops."""
    s16 = beat / 4
    chance = 0.35 if kind == "title" else 0.8
    t0 = 0.0
    for sec, nb in sections:
        for b in range(nb):
            tb = t0 + b * bar
            if sec in ("intro", "outro"):
                continue
            if (b + 1) % 2 == 0 and rng.f() < chance:
                # the last beat (sometimes two) of the phrase
                beats = 2 if (sec == "build" or rng.f() < 0.25) else 1
                start = tb + bar - beats * beat
                glitch(L, R, int(start * SR), int((tb + bar) * SR), rng.choice(GLITCHES), s16, rng)
            elif sec in ("drop", "lead2", "lead", "groove") and rng.f() < 0.45:
                # a short stutter or crush on an off-beat
                start = tb + rng.choice([1, 2, 3]) * beat + 2 * s16
                kind_g = rng.choice(["stutter", "crush", "gate"])
                glitch(L, R, int(start * SR), int((start + 2 * s16) * SR), kind_g, s16, rng)
        t0 += nb * bar


def chord_notes(root, scale, degree, seventh=False):
    pcs = [scale[(degree + k) % 7] + 12 * ((degree + k) // 7) for k in ([0, 2, 4, 6] if seventh else [0, 2, 4])]
    return [root + p for p in pcs]


def voice(notes, low=55, high=74):
    out = []
    for m in notes:
        while m < low:
            m += 12
        while m > high:
            m -= 12
        out.append(m)
    return sorted(out)


def scale_notes(root, scale, low, high):
    out = []
    for octv in range(-3, 5):
        for s in scale:
            m = root + s + 12 * octv
            if low <= m <= high:
                out.append(m)
    return sorted(out)


RHYTHMS = [
    # (step, length) in 16ths over 2 bars (32 steps)
    [(0, 3), (3, 3), (6, 2), (8, 6), (16, 3), (19, 3), (22, 2), (24, 8)],
    [(0, 2), (2, 2), (4, 4), (8, 4), (12, 4), (16, 6), (22, 2), (24, 4), (28, 4)],
    [(0, 6), (6, 2), (8, 6), (14, 2), (16, 4), (20, 4), (24, 8)],
    [(2, 2), (4, 2), (6, 4), (10, 6), (18, 2), (20, 2), (22, 4), (26, 6)],
    [(0, 4), (4, 4), (8, 8), (16, 4), (20, 2), (22, 2), (24, 8)],
    [(0, 3), (3, 3), (6, 3), (9, 3), (12, 4), (16, 3), (19, 3), (22, 10)],
]


def gen_melody(rng, root, scale, chords_per_bar, bars, octave_low, octave_high):
    """chords_per_bar: list of chord note lists (one per bar). Returns (bar_offset_steps, step, length, midi)."""
    pool = scale_notes(root, scale, octave_low, octave_high)
    motif = rng.choice(RHYTHMS)
    notes = []
    prev = pool[len(pool) // 2]
    motif_pitches = None
    for phrase in range(bars // 2):
        base_bar = phrase * 2
        vary = phrase % 2 == 1
        pitches = []
        for i, (step, ln) in enumerate(motif):
            bar = base_bar + step // 16
            ch = chords_per_bar[bar % len(chords_per_bar)]
            strong = step % 8 == 0
            if motif_pitches is not None and not (vary and i >= len(motif) - 3) and rng.f() < 0.7:
                # reuse the motif contour, nudged into the current chord
                target = motif_pitches[i]
                cands = [m for m in pool if (m % 12) in [c % 12 for c in ch]] if strong else pool
                m = min(cands, key=lambda c: abs(c - target))
            elif strong:
                cands = [m for m in pool if (m % 12) in [c % 12 for c in ch]]
                cands = sorted(cands, key=lambda c: abs(c - prev))[:3]
                m = rng.choice(cands)
            else:
                idx = pool.index(min(pool, key=lambda c: abs(c - prev)))
                idx = int(np.clip(idx + rng.choice([-2, -1, -1, 1, 1, 2]), 0, len(pool) - 1))
                m = pool[idx]
            pitches.append(m)
            notes.append((base_bar * 16 + step, ln, m))
            prev = m
        if motif_pitches is None:
            motif_pitches = pitches
    return notes


def compose(name, seed, kind="combat", over=None):
    over = over or {}
    rng = Rng(seed)
    # fast tempos (owner's call, 2026-10-18) with a dark electronic bass-music
    # sound (Rezz): four-on-the-floor or driving kicks, 16th-note wobble basses,
    # hypnotic plucks, short intros and breaks so the energy never drops for long
    if kind == "combat":
        bpm = rng.choice([140, 144, 146, 148, 150, 152])
        scale_name = rng.choice(["minor", "minor", "dorian"])
        progs = [[0, 5, 2, 6], [0, 6, 5, 6], [0, 3, 5, 4], [5, 6, 0, 0], [0, 5, 3, 4], [0, 2, 6, 5], [3, 4, 0, 0]]
        sections = [("intro", 2), ("groove", 8), ("lead", 8), ("lead2", 8), ("break", 4), ("build", 2), ("drop", 8),
                    ("lead", 8), ("drop", 8), ("outro", 2)]
    elif kind == "boss":
        bpm = rng.choice([156, 160, 165])
        scale_name = rng.choice(["harmonic", "phrygian", "minor"])
        progs = [[0, 0, 5, 6], [0, 1, 0, 4], [0, 5, 1, 4], [0, 6, 5, 4]]
        sections = [("drop", 8), ("lead", 8), ("break", 4), ("build", 2), ("drop", 8), ("lead2", 8)]
    else:  # title: energetic but not combat
        bpm = 118
        scale_name = "dorian"
        progs = [[0, 5, 3, 4]]
        sections = [("intro", 4), ("groove", 8), ("lead", 8), ("dream", 4)]
    root = rng.choice([45, 46, 47, 48, 49, 50, 52])  # A2..E3 (bass register root)
    prog = rng.choice(progs)
    drum_style = rng.choice(["four", "four", "drive"]) if kind != "title" else "four"
    bass_style = rng.choice(["octave16", "pulse16", "gallop"]) if kind != "title" else "pulse8"
    use_bell = rng.f() < 0.4
    sev = rng.f() < 0.5
    # hand-picked identities per track (see main)
    bpm = over.get("bpm", bpm)
    scale_name = over.get("scale", scale_name)
    root = over.get("root", root)
    prog = over.get("prog", prog)
    drum_style = over.get("drums", drum_style)
    bass_style = over.get("bass", bass_style)
    use_bell = over.get("bell", use_bell)
    scale = SCALES[scale_name]

    beat = 60.0 / bpm
    bar = beat * 4
    s16 = beat / 4
    total_bars = sum(b for _, b in sections)
    length = total_bars * bar
    n = int(SR * (length + 4.0))
    drums, bass, subb, pad, lead, arp, fxb = (Bus(n) for _ in range(7))
    # instrument picks: a talking wobble bass on most tracks, else a growl or reese
    bass_synth = over.get("bass_synth", rng.choice(["wob", "wob", "growl", "reese"]))
    lead_inst = over.get("lead_inst", rng.choice(["dark", "dark", "screech"]))
    wobble = bpm / 60.0 * over.get("wob_rate", rng.choice([1, 2, 2, 3]))  # cycles per beat
    # one hypnotic 16th-step pluck rhythm per track
    pluck_steps = [k for k in range(16) if k % 4 == 0 or rng.f() < 0.4]

    def bass_note(f, dur, t):
        subb.add(inst_sub(f * 0.5, dur), t, 0.0, 0.8)
        if bass_synth == "wob":
            return bass.add(inst_wob(f, dur, t, wobble), t, 0.0, 0.75)
        x = inst_reese(f, dur) if bass_synth == "reese" else inst_growl(f, dur, wobble)
        bass.add(x, t, 0.0, 0.75)
    kick_env = np.ones(n)

    chord_cache = [chord_notes(root + 12, scale, d, sev) for d in prog]
    melodies = {
        "A": gen_melody(rng, root + 24, scale, chord_cache, 8, root + 19, root + 36),
        "B": gen_melody(rng, root + 24, scale, chord_cache, 8, root + 24, root + 41),
    }

    def place_kick(t):
        drums.add(d_kick(rng), t, 0.0, 1.0)
        # EDM pump: everything else ducks hard and swells back over the beat
        s0 = int(t * SR)
        dl = int(SR * beat * 0.8)
        seg = kick_env[s0:s0 + dl]
        kick_env[s0:s0 + dl] = np.minimum(seg, 0.12 + 0.88 * np.sqrt(np.linspace(0.0, 1.0, len(seg))))

    bar_i = 0
    t0 = 0.0
    for sec, nb in sections:
        for b in range(nb):
            tb = t0 + b * bar
            ci = (bar_i + b) % len(prog)
            ch = chord_cache[ci]
            croot = root + (scale[prog[ci] % 7]) + 12 * (prog[ci] // 7)
            last_bar = b == nb - 1
            full = sec in ("lead", "lead2", "drop", "groove", "outro")
            # ---- drums
            if drum_style != "none" and sec not in ("intro", "break", "dream"):
                if sec == "build":
                    # snare roll that speeds up
                    steps = 4 if b < nb - 2 else (8 if b < nb - 1 else 16)
                    for k in range(steps):
                        drums.add(d_snare(rng, False), tb + k * bar / steps, 0.1, 0.4 + 0.5 * (b * steps + k) / (nb * steps))
                    if b == 0:
                        fxb.add(fx_riser(rng, bar * nb), tb, 0.0, 0.8)
                else:
                    for k in range(4):
                        tk = tb + k * beat
                        if drum_style == "four" or (drum_style == "drive" and k in (0, 2)) or (drum_style == "halftime" and k == 0):
                            place_kick(tk)
                        if drum_style == "drive" and k in (1, 3) and rng.f() < 0.3:
                            place_kick(tk + beat * 0.5)
                        if drum_style == "halftime":
                            if k == 2:
                                drums.add(d_clap(rng), tk, 0.0, 0.9)
                                drums.add(d_snare(rng, False), tk, 0.0, 0.5)
                            if k == 1 and rng.f() < 0.5:
                                place_kick(tk + beat * 0.5)
                        elif k in (1, 3):
                            drums.add(d_clap(rng), tk, 0.0, 0.9)
                            drums.add(d_snare(rng, False), tk, 0.0, 0.45 if sec in ("drop", "lead2") else 0.3)
                        hats = 4 if drum_style in ("drive", "four") or sec == "drop" else 2
                        for h in range(hats):
                            sub = h * (beat / hats)
                            open_ = (h == 2 and drum_style != "drive") or (drum_style == "drive" and h == 2 and k % 2 == 1)
                            drums.add(d_hat(rng, open_), tk + sub, 0.35 * (1 if h % 2 else -1), 0.5 if h % 2 else 0.35)
                    if last_bar and sec != "outro":
                        # clap roll and a zap into the next section
                        for k in range(4):
                            drums.add(d_clap(rng), tb + 3 * beat + k * s16, 0.0, 0.4 + 0.15 * k)
                        fxb.add(fx_zap(rng), tb + 3 * beat + 2 * s16, rng.f(-0.5, 0.5), 0.6)
                if b == 0 and sec in ("drop", "lead", "groove"):
                    drums.add(d_crash(rng), tb, 0.0, 0.45)
                    if sec == "drop":
                        fxb.add(fx_impact(rng), tb, 0.0, 0.9)
                if sec != "build":
                    for k in range(16):
                        if k % 4 and rng.f() < 0.08:
                            drums.add(glitch_blip(rng.f(300, 2400), rng), tb + k * s16, rng.f(-0.8, 0.8), 0.4)
                    if b % 4 == 1 and rng.f() < 0.5:
                        fxb.add(fx_zap(rng), tb + rng.choice([6, 10, 14]) * s16, rng.f(-0.7, 0.7), 0.4)
            elif sec == "dream" and b % 2 == 0:
                drums.add(d_clap(rng), tb + 2 * beat, 0.0, 0.35)
                drums.add(d_kick(rng, 0.6), tb, 0.0, 0.5)
            # ---- bass
            if sec in ("intro", "break", "dream") or bass_style == "long":
                bass_note(midi(croot), bar * 0.95, tb)
            elif sec == "build":
                for k in range(16):
                    bass_note(midi(croot), s16 * 0.8, tb + k * s16)
            else:
                for k in range(16):
                    tk = tb + k * s16
                    m = croot
                    if bass_style == "pulse8":
                        if k % 2:
                            continue
                        if k in (6, 14) and rng.f() < 0.5:
                            m += 12
                    elif bass_style == "gallop":
                        if k % 4 == 1:
                            continue
                    elif bass_style == "offbeat":
                        if k % 4 != 2:
                            continue
                    elif bass_style == "octave16":
                        m = croot + (12 if k % 2 else 0)
                    elif bass_style == "pulse16" and k in (7, 15) and rng.f() < 0.4:
                        m += 12
                    dur = s16 * (1.6 if bass_style == "pulse8" else (0.7 if bass_style == "pulse16" else 0.85))
                    bass_note(midi(m), dur, tk)
            # ---- pad: a dark, filtered bed; louder in the calm sections
            v = voice(ch, 55, 74)
            bright = 900 if sec in ("intro", "break") else (1500 if full else 1200)
            if sec == "build":
                bright = 900 + 2400 * (b + 1) / nb
            pg = 0.3 if sec in ("intro", "break", "build", "dream") else 0.12
            for m in v:
                l, r = inst_supersaw(midi(m), bar, rng, bright)
                pad.add_st(l, r, tb, pg)
            # ---- hypnotic pluck sequence on chord tones, plus a few glitch stabs
            if sec in ("groove", "lead2", "drop", "build", "lead", "intro"):
                tones = voice(ch, 57, 70)
                for j, k in enumerate(pluck_steps):
                    m = tones[j % len(tones)] + (12 if sec == "drop" and j % 3 == 2 else 0)
                    arp.add(inst_pluck(midi(m), s16 * 0.9), tb + k * s16, -0.4 if j % 2 else 0.4, 0.5)
                for k in range(16):
                    if rng.f() < (0.12 if sec == "drop" else 0.05):
                        arp.add(glitch_blip(midi(rng.choice(tones) + 12), rng), tb + k * s16, rng.f(-0.7, 0.7), 0.35)
            if use_bell and sec in ("break", "dream") and b % 2 == 0:
                for k, m in enumerate(voice(ch, 72, 88)):
                    arp.add(inst_bell(midi(m), beat), tb + k * beat * 0.5, -0.3 + 0.3 * k, 0.25)
        # ---- lead melodies
        if sec in ("lead", "lead2", "drop", "break", "dream"):
            mel = melodies["B" if sec == "drop" else "A"]
            prev = None
            for (step, ln, m) in mel:
                bar_off = step // 16
                if bar_off >= nb:
                    continue
                if sec == "break" and step % 8 != 0:
                    continue
                if sec == "lead2" and rng.f() < 0.15:
                    m += 12
                tn = t0 + step * s16
                g = 0.42 if sec != "break" else 0.3
                if sec == "dream":
                    lead.add(inst_lead(midi(m), ln * s16 * 0.92, "fm"), tn, 0.0, g)
                elif lead_inst == "dark":
                    lead.add(inst_dark(midi(m), ln * s16 * 0.92), tn, 0.0, g)
                else:
                    lead.add(inst_screech(midi(m), ln * s16 * 0.92, rng), tn, 0.0, g)
                prev = m
        bar_i += nb
        t0 += nb * bar

    # ---- mixdown
    drive(bass, 3.0, 3000)
    drive(drums, 3.0, 9000, 0.5)
    subb.L, subb.R = lp(subb.L, 110), lp(subb.R, 110)
    delay(lead, beat * 0.75, 0.25, 3)
    delay(arp, beat * 0.5, 0.3, 2)
    ir_big = reverb_ir(2.6, seed + 1)
    ir_small = reverb_ir(1.1, seed + 2, 8000)
    apply_reverb(pad, ir_big, 0.5)
    apply_reverb(lead, ir_small, 0.3)
    apply_reverb(arp, ir_small, 0.25)
    apply_reverb(drums, ir_small, 0.15)
    apply_reverb(fxb, ir_big, 0.3)
    for bus in (bass, subb, pad, arp):
        bus.L *= kick_env
        bus.R *= kick_env
    lead.L *= 0.5 + 0.5 * kick_env
    lead.R *= 0.5 + 0.5 * kick_env
    L = drums.L * 1.0 + bass.L * 0.75 + subb.L * 0.7 + pad.L * 0.6 + lead.L * 0.7 + arp.L * 0.6 + fxb.L * 0.55
    R = drums.R * 1.0 + bass.R * 0.75 + subb.R * 0.7 + pad.R * 0.6 + lead.R * 0.7 + arp.R * 0.6 + fxb.R * 0.55
    L = hp(L, 28)
    R = hp(R, 28)
    glitch_pass(L, R, rng, sections, bar, beat, kind)
    end = int(SR * length)
    if kind in ("boss", "title"):
        # loopable: fold the tail back onto the start
        tail_l, tail_r = L[end:], R[end:]
        L, R = L[:end].copy(), R[:end].copy()
        L[: len(tail_l)] += tail_l
        R[: len(tail_r)] += tail_r
    else:
        fade = int(SR * 2.5)
        L, R = L[: end + fade].copy(), R[: end + fade].copy()
        L[-fade:] *= np.linspace(1, 0, fade)
        R[-fade:] *= np.linspace(1, 0, fade)
    peak = max(np.max(np.abs(L)), np.max(np.abs(R)), 1e-6)
    L = np.tanh(L / peak * 1.25) * 0.92
    R = np.tanh(R / peak * 1.25) * 0.92
    return np.stack([L, R], axis=1), dict(name=name, bpm=bpm, scale=scale_name, root=root, prog=prog, drums=drum_style, bass=bass_style, bass_synth=bass_synth, lead=lead_inst, seconds=round(len(L) / SR, 1))


# Every track is mastered to the same loudness so the mix (spec §10.1, measured
# against tracks at this level) holds whichever track plays.
TARGET_LUFS = -14.0


def _loudness(path):
    out = subprocess.run(["ffmpeg", "-nostats", "-i", path, "-af", "ebur128", "-f", "null", "-"],
                         capture_output=True, text=True).stderr
    return float(out.rsplit("I:", 1)[1].split("LUFS")[0])


def write_ogg(name, data, q):
    tmp = os.path.join(OUT, name + "_tmp.wav")
    wavfile.write(tmp, SR, (data * 32767).astype(np.int16))
    gain = TARGET_LUFS - _loudness(tmp)
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-af",
                    f"volume={gain:.2f}dB,alimiter=limit=0.89:level=false",
                    "-c:a", "libvorbis", "-q:a", str(q), os.path.join(OUT, name + ".ogg")], check=True)
    os.remove(tmp)


def main():
    import sys
    os.makedirs(OUT, exist_ok=True)
    # Each track gets its own key, tempo, progression, groove and lead voice.
    jobs = [
        ("combat_0", 1001, "combat", dict(bpm=148, scale="minor", root=45, prog=[0, 5, 2, 6], drums="four", bass="octave16", bell=False, bass_synth="wob", wob_rate=2, lead_inst="dark")),
        ("combat_1", 1037, "combat", dict(bpm=140, scale="minor", root=54 - 12, prog=[0, 6, 5, 6], drums="drive", bass="gallop", bell=True, bass_synth="growl", wob_rate=2, lead_inst="dark")),
        ("combat_2", 1074, "combat", dict(bpm=150, scale="minor", root=48, prog=[0, 3, 5, 4], drums="four", bass="pulse16", bell=False, bass_synth="wob", wob_rate=3, lead_inst="screech")),
        ("combat_3", 1111, "combat", dict(bpm=144, scale="dorian", root=52, prog=[5, 6, 0, 0], drums="four", bass="octave16", bell=True, bass_synth="reese", wob_rate=1, lead_inst="dark")),
        ("combat_4", 1148, "combat", dict(bpm=152, scale="minor", root=50, prog=[0, 5, 3, 4], drums="drive", bass="gallop", bell=False, bass_synth="wob", wob_rate=1, lead_inst="dark")),
        ("combat_5", 1185, "combat", dict(bpm=146, scale="dorian", root=55 - 12, prog=[0, 2, 6, 5], drums="four", bass="pulse16", bell=True, bass_synth="wob", wob_rate=2, lead_inst="screech")),
        ("boss_0", 5000, "boss", dict(bpm=160, scale="phrygian", root=52, prog=[0, 1, 0, 4], drums="four", bass="octave16", bass_synth="wob", wob_rate=3, lead_inst="dark")),
        ("boss_1", 5053, "boss", dict(bpm=156, scale="harmonic", root=48, prog=[0, 0, 5, 6], drums="four", bass="octave16", bass_synth="growl", wob_rate=2, lead_inst="screech")),
        ("boss_2", 5106, "boss", dict(bpm=165, scale="harmonic", root=45, prog=[0, 5, 1, 4], drums="drive", bass="pulse16", bass_synth="wob", wob_rate=2, lead_inst="dark")),
        ("title", 777, "title", dict(bass_synth="wob", wob_rate=0.5, lead_inst="dark")),
    ]
    only = sys.argv[1:]
    for name, seed, kind, over in jobs:
        if only and name not in only:
            continue
        data, info = compose(name, seed, kind, over)
        write_ogg(name, data, 3)
        print(info, flush=True)


if __name__ == "__main__":
    main()
