"""Procedural sound generator for KATANA / SHOTGUN.

Run:  python3 tools/gen_audio.py        (from the project root; everything)
      python3 tools/gen_audio.py rain   (only the rain beds)
Writes .wav SFX and .ogg loops into assets/audio/. Requires numpy, scipy, ffmpeg.
Everything is synthesized so the prototype has no third-party audio.
"""
import os
import subprocess
import sys
import numpy as np
from scipy.io import wavfile
from scipy.signal import butter, lfilter

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")
rng = np.random.default_rng(1337)


# ---------------------------------------------------------------- helpers
def t_axis(dur):
    return np.arange(int(SR * dur)) / SR


def noise(dur):
    return rng.uniform(-1, 1, int(SR * dur))


def env_exp(dur, k):
    return np.exp(-t_axis(dur) * k)


def lp(x, cutoff, order=2):
    b, a = butter(order, min(cutoff, SR / 2 - 100) / (SR / 2), "low")
    return lfilter(b, a, x)


def hp(x, cutoff, order=2):
    b, a = butter(order, cutoff / (SR / 2), "high")
    return lfilter(b, a, x)


def bp(x, lo, hi, order=2):
    b, a = butter(order, [lo / (SR / 2), min(hi, SR / 2 - 100) / (SR / 2)], "band")
    return lfilter(b, a, x)


def sweep_sine(f0, f1, dur, curve=1.0):
    t = t_axis(dur)
    f = f0 + (f1 - f0) * (t / dur) ** curve
    return np.sin(2 * np.pi * np.cumsum(f) / SR)


def sweep_square(f0, f1, dur):
    return np.sign(sweep_sine(f0, f1, dur))


def sweep_bp_noise(lo0, lo1, dur, width=1.6, chunks=40):
    """Band-pass noise whose centre frequency glides (approximated in chunks)."""
    n = noise(dur)
    out = np.zeros_like(n)
    edges = np.linspace(0, len(n), chunks + 1).astype(int)
    for i in range(chunks):
        c = lo0 + (lo1 - lo0) * i / chunks
        seg = bp(n, c / width, c * width)
        out[edges[i]:edges[i + 1]] = seg[edges[i]:edges[i + 1]]
    return out


def pad_to(x, n):
    return np.pad(x, (0, max(0, n - len(x))))[:n]


def mix(*parts):
    n = max(len(p) for p in parts)
    return sum(pad_to(p, n) for p in parts)


def at(x, offset, total):
    out = np.zeros(int(SR * total))
    s = int(SR * offset)
    e = min(len(out), s + len(x))
    out[s:e] += x[: e - s]
    return out


def crush(x, bits=8):
    q = 2 ** (bits - 1)
    return np.round(x * q) / q


def norm(x, peak=0.95):
    m = np.max(np.abs(x)) or 1.0
    return x / m * peak


def fade(x, fin=0.002, fout=0.01):
    x = x.copy()
    a, b = int(SR * fin), int(SR * fout)
    if a:
        x[:a] *= np.linspace(0, 1, a)
    if b:
        x[-b:] *= np.linspace(1, 0, b)
    return x


def save(name, x, peak=0.95):
    x = fade(norm(x, peak))
    wavfile.write(os.path.join(OUT, name + ".wav"), SR, (x * 32767).astype(np.int16))


# ---------------------------------------------------------------- SFX
def crackle(dur, density=900, lo=1200, hi=9000, k=6.0):
    """Electrical crackle: a sparse train of tiny noise clicks, thinning out."""
    n = int(SR * dur)
    out = np.zeros(n)
    t = 0.0
    while True:
        t += rng.exponential(1.0 / density) * (1.0 + t * k)
        s = int(t * SR)
        if s >= n:
            break
        ln = int(SR * rng.uniform(0.0006, 0.003))
        click = rng.uniform(-1, 1, ln) * rng.uniform(0.3, 1.0)
        out[s:s + ln] += click[: max(0, min(ln, n - s))]
    return bp(out, lo, hi) * np.exp(-t_axis(dur) * k * 0.5)


def reverb(x, tail=2.0, k=2.6, wet=0.5):
    from scipy.signal import fftconvolve
    ir = rng.uniform(-1, 1, int(SR * tail)) * np.exp(-t_axis(tail) * k)
    ir = lp(ir, 5000)
    w = fftconvolve(x, ir)[: len(x) + int(SR * tail)]
    w = w / (np.max(np.abs(w)) or 1.0) * (np.max(np.abs(x)) or 1.0)
    return mix(x, w * wet)


def sfx_shotgun():
    """The arc shotgun: a hard electrical crack, a crackling discharge, a buzz
    and a deep thump so it still hits like a shotgun."""
    d = 0.95
    t = t_axis(d)
    snap = mix(noise(0.006) * 1.2, np.sin(2 * np.pi * 2400 * t_axis(0.01)) * env_exp(0.01, 300))
    zap = sweep_sine(4200, 160, 0.22, 0.35) * env_exp(0.22, 14) * 0.8
    buzz = crush(((np.cumsum(98 + 30 * np.sin(2 * np.pi * 31 * t)) / SR) % 1.0) * 2 - 1, 5) * np.exp(-t * 9) * 0.6
    disch = crackle(d, 1600, 1500, 10000, 7.0) * 2.4
    hiss = hp(noise(d), 4000) * np.exp(-t * 16) * 0.5
    boom = sweep_sine(120, 34, d, 0.5) * np.exp(-t * 5.5) * 1.7
    return np.tanh(mix(snap, zap, lp(buzz, 3000), disch, hiss, boom) * 2.2)


def sfx_recharge():
    """Capacitor whine climbing as the drum turns, then the cell locks in."""
    total = 0.48
    d = 0.32
    t = t_axis(d)
    whine = (sweep_sine(500, 3400, d, 1.6) * 0.5 + sweep_square(250, 1700, d) * 0.12) * (t / d) ** 1.4
    hum = np.sin(2 * np.pi * 120 * t) * 0.15 * (t / d)
    clack = mix(bp(noise(0.03), 1800, 5200) * env_exp(0.03, 120), np.sin(2 * np.pi * 170 * t_axis(0.06)) * env_exp(0.06, 60) * 0.7)
    zip_ = crackle(0.12, 2500, 3000, 10000, 20.0) * 0.8
    return at(mix(whine, hum), 0.0, total) + at(clack, d, total) + at(zip_, d, total)


def sfx_empty():
    """Dead cell: a short fizzle and a power-down blip."""
    d = 0.2
    return mix(crackle(0.12, 900, 1000, 6000, 18.0) * 0.8, sweep_square(700, 140, d) * env_exp(d, 14) * 0.25)


def sfx_zap():
    """Arc hitting a body."""
    d = 0.2
    return np.tanh(mix(crackle(d, 2200, 1500, 9000, 12.0) * 2.0, sweep_sine(1800, 300, 0.08) * env_exp(0.08, 30) * 0.4) * 1.5)


def sfx_felled():
    """Boss defeated: a glitch crunch, a sub boom and a dark synth swell with a
    long reverb tail, like the end of a fight in a FromSoftware game."""
    total = 4.6
    out = np.zeros(int(SR * total))
    # glitch crunch: stuttered bit-crushed bursts
    for k in range(6):
        b = crush(bp(noise(0.035), 300, 6000), 3) * (0.9 - k * 0.12)
        out += at(b, k * 0.045, total)
    t = t_axis(3.6)
    boom = sweep_sine(62, 26, 3.6, 0.45) * np.exp(-t * 1.3) * 2.2
    out += at(boom, 0.02, total)
    # minor add9 pad swelling in
    pad = np.zeros(len(t))
    for f in [55.0, 110.0, 164.8, 220.0, 261.6, 329.6, 493.9]:
        for det in (0.996, 1.004):
            pad += ((f * det * t) % 1.0) * 2 - 1
    env = np.minimum(1, t / 0.9) * np.exp(-np.maximum(0, t - 1.0) * 1.1)
    pad = lp(pad, 1800) * env * 0.09
    out += at(pad, 0.15, total)
    bell = sum(np.sin(2 * np.pi * f * t) * np.exp(-t * kk) for f, kk in [(880, 2.2), (1318.5, 2.8), (1760, 3.4)]) * 0.12
    out += at(bell, 0.12, total)
    return np.tanh(reverb(out, 2.4, 2.0, 0.55)[: len(out)] * 1.4)


def sfx_cutin():
    """Persona-style cut-in: a fast whoosh and a bright metallic shing."""
    d = 0.6
    t = t_axis(d)
    whoosh = sweep_bp_noise(800, 6000, 0.18, 1.6, 20) * np.sin(np.pi * np.clip(t_axis(0.18) / 0.18, 0, 1))
    shing = sum(np.sin(2 * np.pi * f * t) * np.exp(-t * k) for f, k in [(2093, 7), (3136, 9), (4186, 12), (5274, 15)]) * 0.25
    return mix(whoosh * 0.9, at(shing, 0.06, d))


def sfx_finish():
    """The all-out finish hit: chord stab, crash and a sub drop."""
    d = 1.3
    t = t_axis(d)
    chord = sum(((f * t) % 1.0) * 2 - 1 + ((f * 1.007 * t) % 1.0) * 2 - 1 for f in [130.8, 196.0, 261.6, 311.1, 392.0, 523.3])
    stab = lp(chord, 4200) * np.exp(-t * 3.2) * 0.16
    crash = hp(noise(d), 3500) * np.exp(-t * 3.0) * 0.55
    sub = sweep_sine(90, 30, d, 0.4) * np.exp(-t * 2.4) * 1.6
    return np.tanh(reverb(mix(stab, crash, sub, sfx_stamp() * 0.5), 1.2, 3.0, 0.3)[: len(t)] * 1.6)


def sfx_flatline():
    """You died: the heart monitor flatlines over a low drone."""
    total = 3.2
    t = t_axis(2.8)
    tone = (np.sin(2 * np.pi * 988 * t) + 0.25 * np.sin(2 * np.pi * 1976 * t)) * np.minimum(1, t / 0.01) * np.exp(-np.maximum(0, t - 1.6) * 2.2) * 0.32
    drone = lp(((55 * t) % 1.0) * 2 - 1 + ((55.3 * t) % 1.0) * 2 - 1, 500) * np.minimum(1, t / 0.4) * np.exp(-t * 0.9) * 0.35
    thud = sweep_sine(80, 28, 1.2, 0.5) * env_exp(1.2, 3.0) * 1.3
    out = at(mix(tone, drone), 0.0, total) + at(thud, 0.0, total)
    return np.tanh(reverb(out, 1.6, 2.5, 0.35)[: int(SR * total)] * 1.2)


def sfx_swing(pitch=1.0):
    d = 0.22
    t = t_axis(d)
    shape = np.sin(np.pi * np.clip(t / d, 0, 1)) ** 1.5
    w = sweep_bp_noise(900 * pitch, 3800 * pitch, d) * shape
    whistle = sweep_sine(2600 * pitch, 1400 * pitch, d) * shape * 0.08
    return mix(w, whistle)


def sfx_slice():
    d = 0.35
    t = t_axis(d)
    ring = sum(np.sin(2 * np.pi * f * t) * np.exp(-t * k) for f, k in [(3150, 22), (4720, 30), (6230, 40), (2210, 18)])
    thwack = lp(noise(0.14), 900) * env_exp(0.14, 30) * 2.0
    thump = np.sin(2 * np.pi * 110 * t_axis(0.12)) * env_exp(0.12, 30) * 1.2
    wet = lp(noise(0.25), 500) * (np.abs(np.sin(t_axis(0.25) * 90)) ** 3) * env_exp(0.25, 12)
    return np.tanh(mix(ring * 0.35, thwack, thump, at(wet, 0.03, d)) * 1.6)


def sfx_gore(seed_shift=0, big=False):
    d = 0.75 if big else 0.42
    r = np.random.default_rng(99 + seed_shift)
    t = t_axis(d)
    squish = lp(r.uniform(-1, 1, len(t)), 700 if not big else 500)
    bumps = np.zeros_like(t)
    for _ in range(14 if big else 7):
        c = r.uniform(0, d * 0.7)
        bumps += np.exp(-((t - c) ** 2) / (2 * 0.012 ** 2))
    wet = squish * (0.25 + bumps) * np.exp(-t * (4 if big else 7))
    splort = sweep_sine(320, 70, d, 0.6) * np.exp(-t * 9) * 0.7
    crunch = bp(r.uniform(-1, 1, len(t)), 1500, 4500) * np.exp(-t * 30) * (0.9 if big else 0.4)
    thud = np.sin(2 * np.pi * 70 * t) * np.exp(-t * 10) * (1.5 if big else 0.6)
    return np.tanh(mix(wet * 2.2, splort, crunch, thud) * 1.5)


def sfx_execution():
    d = 1.7
    t = t_axis(d)
    boom = sweep_sine(85, 38, d, 0.4) * np.exp(-t * 2.6) * 2.0
    taiko = lp(noise(0.25), 300) * env_exp(0.25, 14) * 2.0
    shing = sum(np.sin(2 * np.pi * f * t) * np.exp(-t * k) for f, k in [(2093, 2.2), (2637, 2.6), (3136, 3.0), (4186, 4.0), (2100, 2.3)]) * 0.28
    swish = sweep_bp_noise(4000, 900, 0.35) * env_exp(0.35, 6) * 0.7
    return np.tanh(mix(boom, taiko, shing, swish, sfx_gore(5, True) * 0.7) * 1.4)


def sfx_deflect():
    d = 0.6
    t = t_axis(d)
    ting = sum(np.sin(2 * np.pi * f * t) * np.exp(-t * k) for f, k in [(2217, 6), (3322, 8), (5130, 12), (6644, 16)])
    zap = sweep_square(1800, 400, 0.12) * env_exp(0.12, 20) * 0.3
    return mix(ting * 0.5, zap, bp(noise(0.02), 3000, 9000))


def sfx_headshot():
    d = 0.25
    t = t_axis(d)
    return mix(sum(np.sin(2 * np.pi * f * t) * np.exp(-t * k) for f, k in [(3520, 18), (5280, 24), (7040, 30)]), bp(noise(0.01), 4000, 9000) * 0.6)


def sfx_hurt():
    d = 0.3
    return np.tanh(mix(np.sin(2 * np.pi * 85 * t_axis(d)) * env_exp(d, 10) * 1.5, lp(noise(0.18), 1200) * env_exp(0.18, 18), sweep_square(220, 90, 0.18) * env_exp(0.18, 14) * 0.25) * 2.0)


def sfx_enemy_shot():
    d = 0.35
    z = sweep_square(1100, 180, d) * env_exp(d, 7)
    return crush(mix(z * 0.6, sweep_sine(700, 120, d) * env_exp(d, 6) * 0.5), 6)


def sfx_windup():
    d = 0.32
    t = t_axis(d)
    return mix(sweep_square(260, 720, d) * np.sin(np.pi * t / d) * 0.35, sweep_sine(520, 1440, d) * np.sin(np.pi * t / d) * 0.3)


def sfx_roar():
    d = 1.1
    t = t_axis(d)
    vib = 1 + 0.06 * np.sin(2 * np.pi * 7 * t)
    saw = ((np.cumsum(70 * vib) / SR) % 1.0) * 2 - 1
    growl = bp(saw + noise(d) * 0.6, 150, 1400)
    envl = np.minimum(1, t / 0.12) * np.exp(-np.maximum(0, t - 0.6) * 5)
    return np.tanh(growl * envl * 3)


def sfx_slam():
    d = 1.2
    t = t_axis(d)
    return np.tanh(mix(sweep_sine(70, 25, d) * np.exp(-t * 3) * 2.2, lp(noise(d), 600) * np.exp(-t * 4) * 1.4, bp(noise(0.15), 1000, 5000) * env_exp(0.15, 20) * 0.6) * 1.6)


def sfx_dash():
    d = 0.24
    t = t_axis(d)
    return mix(sweep_bp_noise(500, 2600, d, 1.8, 24) * np.sin(np.pi * t / d), sweep_sine(160, 60, d) * env_exp(d, 10) * 0.4)


def sfx_jump():
    return mix(lp(noise(0.09), 1500) * env_exp(0.09, 35), sweep_sine(180, 320, 0.08) * env_exp(0.08, 30) * 0.3)


def sfx_land():
    return mix(np.sin(2 * np.pi * 70 * t_axis(0.15)) * env_exp(0.15, 25), lp(noise(0.08), 800) * env_exp(0.08, 40) * 0.6)


def sfx_jumppad():
    d = 0.5
    return crush(mix(sweep_square(140, 900, d) * env_exp(d, 4) * 0.4, sweep_bp_noise(400, 3000, d) * env_exp(d, 5)), 7)


def sfx_pickup():
    total = 0.22
    a = np.sign(np.sin(2 * np.pi * 988 * t_axis(0.07))) * env_exp(0.07, 25)
    b = np.sign(np.sin(2 * np.pi * 1480 * t_axis(0.12))) * env_exp(0.12, 22)
    return (at(a, 0, total) + at(b, 0.06, total)) * 0.4


def sfx_levelup():
    total = 1.1
    out = np.zeros(int(SR * total))
    for i, f in enumerate([523.25, 659.25, 783.99, 1046.5, 1318.5]):
        n = np.sign(np.sin(2 * np.pi * f * t_axis(0.4))) * env_exp(0.4, 7) * 0.35
        out += at(n, i * 0.07, total)
    echo = np.zeros_like(out)
    s = int(SR * 0.16)
    echo[s:] = out[:-s] * 0.4
    return out + echo


def sfx_alarm():
    d = 1.2
    t = t_axis(d)
    f = np.where((t * 4).astype(int) % 2 == 0, 620, 830)
    saw = ((np.cumsum(f) / SR) % 1.0) * 2 - 1
    return crush(lp(saw, 2500) * np.minimum(1, t / 0.02) * np.exp(-np.maximum(0, t - 0.9) * 10) * 0.7, 6)


def sfx_wave_clear():
    total = 1.0
    out = np.zeros(int(SR * total))
    for f in [261.6, 329.6, 392.0, 523.3]:
        tt = t_axis(0.9)
        saw = ((f * tt) % 1.0) * 2 - 1
        saw2 = ((f * 1.007 * tt) % 1.0) * 2 - 1
        out += at(lp(saw + saw2, 3000) * np.exp(-tt * 3) * 0.25, 0, total)
    return out


def sfx_spawn():
    d = 0.5
    t = t_axis(d)
    return crush(mix(sweep_sine(150, 1300, d, 1.5) * np.sin(np.pi * t / d) * 0.5, bp(noise(d), 2000, 7000) * np.sin(np.pi * t / d) * 0.3), 6)


def sfx_player_death():
    d = 2.2
    t = t_axis(d)
    return np.tanh(mix(sweep_sine(220, 30, d, 0.7) * np.exp(-t * 1.2), lp(noise(d), 400) * np.exp(-t * 1.5) * 0.8, sfx_execution() * 0.4) * 1.5)


def sfx_ui_click():
    return np.sign(np.sin(2 * np.pi * 1200 * t_axis(0.05))) * env_exp(0.05, 50) * 0.4


def sfx_ui_hover():
    return np.sign(np.sin(2 * np.pi * 700 * t_axis(0.03))) * env_exp(0.03, 80) * 0.25


def sfx_ignite():
    d = 0.5
    return lp(noise(d), 1600) * np.sin(np.pi * t_axis(d) / d) ** 0.7 * 0.9


def sfx_bolt_hit():
    return crush(mix(bp(noise(0.12), 800, 4000) * env_exp(0.12, 25), sweep_square(600, 150, 0.1) * env_exp(0.1, 25) * 0.4), 6)


def sfx_wave_blade():
    d = 0.45
    t = t_axis(d)
    return mix(sweep_bp_noise(3000, 600, d, 1.5, 30) * np.sin(np.pi * t / d), sweep_sine(900, 300, d) * env_exp(d, 6) * 0.2)



def sfx_explosion():
    d = 1.4
    t = t_axis(d)
    boom = sweep_sine(90, 28, d, 0.4) * np.exp(-t * 3.2) * 2.0
    crack = bp(noise(0.05), 1500, 8000) * env_exp(0.05, 60)
    rumble = lp(noise(d), 500) * np.exp(-t * 2.5) * 1.6
    debris = bp(noise(d), 2000, 6000) * np.exp(-t * 6) * 0.4
    return np.tanh(mix(boom, crack, rumble, debris) * 1.8)


def sfx_missile():
    d = 0.7
    t = t_axis(d)
    whoosh = sweep_bp_noise(600, 3500, d, 1.6, 28) * np.sin(np.pi * t / d) ** 0.6
    tone = sweep_sine(300, 900, d) * env_exp(d, 3) * 0.2
    return mix(whoosh, tone)


def sfx_beep():
    return np.sign(np.sin(2 * np.pi * 1760 * t_axis(0.07))) * env_exp(0.07, 30) * 0.35


def sfx_boss_intro():
    d = 2.6
    t = t_axis(d)
    hit = sweep_sine(70, 30, d, 0.5) * np.exp(-t * 1.6) * 2.0
    gong = sum(np.sin(2 * np.pi * f * t) * np.exp(-t * k) for f, k in [(110, 1.0), (165.4, 1.3), (247, 1.7), (330.8, 2.2)]) * 0.35
    noise_tail = lp(noise(d), 900) * np.exp(-t * 2.0) * 0.8
    return np.tanh(mix(hit, gong, noise_tail) * 1.5)


def sfx_riser():
    d = 1.6
    t = t_axis(d)
    return mix(sweep_bp_noise(300, 6000, d, 1.5, 40) * (t / d) ** 2, sweep_square(110, 880, d) * (t / d) ** 3 * 0.15)


def sfx_blink():
    d = 0.35
    t = t_axis(d)
    return crush(mix(sweep_sine(1800, 200, d, 0.5) * env_exp(d, 8) * 0.5, bp(noise(d), 3000, 9000) * env_exp(d, 12) * 0.4), 6)


def sfx_shuriken():
    d = 0.3
    t = t_axis(d)
    return mix(sweep_bp_noise(4000, 1500, d, 1.3, 18) * np.sin(np.pi * t / d), sum(np.sin(2 * np.pi * f * t) * np.exp(-t * 30) for f in [3300, 4950]) * 0.15)


def sfx_gatling():
    d = 0.12
    return crush(mix(sweep_square(900, 300, d) * env_exp(d, 25) * 0.5, bp(noise(d), 1000, 5000) * env_exp(d, 40) * 0.5), 6)


def sfx_coin():
    total = 0.5
    a = np.sign(np.sin(2 * np.pi * 987.8 * t_axis(0.08))) * env_exp(0.08, 10)
    b = np.sign(np.sin(2 * np.pi * 1318.5 * t_axis(0.4))) * env_exp(0.4, 6)
    return (at(a, 0, total) + at(b, 0.08, total)) * 0.4


def sfx_highscore():
    total = 1.6
    out = np.zeros(int(SR * total))
    for i, f in enumerate([523.25, 659.25, 783.99, 1046.5, 783.99, 1046.5, 1318.5]):
        dur = 0.5 if i == 6 else 0.14
        n = np.sign(np.sin(2 * np.pi * f * t_axis(dur))) * env_exp(dur, 5 if i == 6 else 14) * 0.35
        out += at(n, i * 0.12, total)
    return out


def sfx_type():
    return np.sign(np.sin(2 * np.pi * 1500 * t_axis(0.03))) * env_exp(0.03, 60) * 0.3


def sfx_thunder():
    d = 2.5
    t = t_axis(d)
    crack = bp(noise(0.2), 800, 6000) * env_exp(0.2, 12)
    roll = lp(noise(d), 300) * (np.exp(-t * 1.4) * (0.6 + 0.4 * np.sin(t * 9) ** 2)) * 1.8
    return np.tanh(mix(crack, roll) * 1.4)


# ---- arcade / "juice" sounds
def sfx_tick():
    t = t_axis(0.035)
    return (np.sign(np.sin(2 * np.pi * 1320 * t)) * 0.6 + np.sin(2 * np.pi * 2640 * t) * 0.4) * env_exp(0.035, 70) * 0.5


def sfx_stamp():
    d = 0.7
    t = t_axis(d)
    thud = sweep_sine(120, 40, d, 0.4) * np.exp(-t * 9) * 1.8
    crack = bp(noise(0.06), 1200, 7000) * env_exp(0.06, 50)
    ring = sum(np.sin(2 * np.pi * f * t) * np.exp(-t * k) for f, k in [(523, 7), (784, 9), (1046, 11)]) * 0.18
    return np.tanh(mix(thud, crack, ring) * 1.6)


def sfx_chime():
    total = 0.9
    out = np.zeros(int(SR * total))
    for i, f in enumerate([1046.5, 1318.5, 1568.0, 2093.0]):
        tt = t_axis(0.6)
        n = (np.sin(2 * np.pi * f * tt) + 0.4 * np.sin(2 * np.pi * f * 2.01 * tt)) * np.exp(-tt * 6) * 0.3
        out += at(n, i * 0.05, total)
    return out


def sfx_cash():
    d = 1.1
    t = t_axis(d)
    bell = sum(np.sin(2 * np.pi * f * t) * np.exp(-t * k) for f, k in [(1568, 3.5), (2093, 4.5), (2637, 5.5), (3136, 7)]) * 0.3
    hit = sweep_sine(200, 60, 0.3) * env_exp(0.3, 14) * 1.2
    rattle = np.zeros(int(SR * d))
    for k in range(8):
        rattle += at(bp(noise(0.03), 4000, 9000) * env_exp(0.03, 90) * 0.4, 0.04 + k * 0.035, d)
    return np.tanh(mix(bell, hit, rattle) * 1.3)


def sfx_count():
    t = t_axis(0.16)
    return (np.sin(2 * np.pi * 880 * t) * 0.7 + np.sign(np.sin(2 * np.pi * 440 * t)) * 0.2) * env_exp(0.16, 14)


def sfx_go():
    d = 0.8
    t = t_axis(d)
    chord = sum(((f * t) % 1.0) * 2 - 1 for f in [523.25, 659.25, 783.99, 1046.5])
    stab = lp(chord, 3500) * np.exp(-t * 4) * 0.35
    return np.tanh(mix(stab, sfx_stamp() * 0.6) * 1.4)


def sfx_mult():
    d = 0.35
    t = t_axis(d)
    return (sweep_square(300, 1400, d) * 0.35 + sweep_sine(600, 2800, d) * 0.3) * np.sin(np.pi * np.clip(t / d, 0, 1)) ** 0.5


def sfx_deal():
    d = 0.18
    t = t_axis(d)
    return sweep_bp_noise(1200, 4500, d, 1.6, 16) * np.sin(np.pi * t / d) * 0.8


def sfx_fanfare():
    total = 2.2
    out = np.zeros(int(SR * total))
    seq = [(0.0, [392.0, 493.9, 587.3]), (0.18, [440.0, 554.4, 659.3]), (0.36, [523.3, 659.3, 784.0]), (0.62, [523.3, 659.3, 784.0, 1046.5])]
    for i, (st, chord) in enumerate(seq):
        dur = 1.4 if i == 3 else 0.2
        tt = t_axis(dur)
        c = sum(((f * tt) % 1.0) * 2 - 1 + ((f * 1.006 * tt) % 1.0) * 2 - 1 for f in chord)
        c = lp(c, 2800) * np.minimum(1, tt / 0.01) * np.exp(-tt * (1.5 if i == 3 else 8)) * 0.18
        out += at(c, st, total)
    return out


# ---------------------------------------------------------------- loops (music + rain)
def to_ogg(name, x, q=4, stereo=None, normalise=True):
    tmp = os.path.join(OUT, name + "_tmp.wav")
    if normalise:
        x = norm(x, 0.9)
    if stereo is not None:
        data = np.stack([x, norm(stereo, 0.9) if normalise else stereo], axis=1)
    else:
        data = x
    wavfile.write(tmp, SR, (data * 32767).astype(np.int16))
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-c:a", "libvorbis", "-q:a", str(q), os.path.join(OUT, name + ".ogg")], check=True)
    os.remove(tmp)


def music_loop():
    bpm = 132
    beat = 60 / bpm
    bars = 16
    total = bars * 4 * beat
    n = int(SR * total)
    kick_bus = np.zeros(n)
    drums = np.zeros(n)
    bass = np.zeros(n)
    lead = np.zeros(n)
    pad = np.zeros(n)
    duck = np.ones(n)

    def place(buf, x, time):
        s = int(SR * time)
        e = min(n, s + len(x))
        if s < n:
            buf[s:e] += x[: e - s]

    def kick():
        d = 0.35
        t = t_axis(d)
        return mix(np.sin(2 * np.pi * np.cumsum(45 + 110 * np.exp(-t * 30)) / SR) * np.exp(-t * 9), bp(noise(0.006), 2000, 8000) * 0.4)

    def snare():
        d = 0.4
        t = t_axis(d)
        return bp(noise(d), 900, 7000) * np.exp(-t * 11) + np.sin(2 * np.pi * 190 * t) * np.exp(-t * 18) * 0.6 + lp(noise(d), 3000) * np.exp(-t * 5) * 0.15

    def hat(open_=False):
        d = 0.18 if open_ else 0.05
        return hp(noise(d), 7000) * env_exp(d, 14 if open_ else 70)

    def saw_note(freq, dur, cutoff=900, det=0.006):
        t = t_axis(dur)
        s = ((freq * t) % 1.0) * 2 - 1 + ((freq * (1 + det) * t) % 1.0) * 2 - 1
        return lp(s, cutoff) * np.minimum(1, t / 0.004) * np.exp(-t * 3)

    def sq_note(freq, dur):
        t = t_axis(dur)
        s = np.sign(np.sin(2 * np.pi * freq * t)) * 0.6 + np.sign(np.sin(2 * np.pi * freq * 1.004 * t)) * 0.4
        return lp(s, 3200) * np.minimum(1, t / 0.003) * np.exp(-t * 6)

    def midi(m):
        return 440 * 2 ** ((m - 69) / 12)

    # E minor: Em - C - D - B   (roots)
    prog = [(40, [64, 67, 71]), (36, [64, 67, 72]), (38, [66, 69, 74]), (35, [63, 66, 71])]
    k = kick()
    for bar in range(bars):
        root, chord = prog[bar % 4]
        for b in range(4):
            tb = (bar * 4 + b) * beat
            place(kick_bus, k, tb)
            s0 = int(SR * tb)
            dl = int(SR * beat * 0.45)
            duck[s0:s0 + dl] = np.minimum(duck[s0:s0 + dl], np.linspace(0.25, 1, len(duck[s0:s0 + dl])))
            if b in (1, 3) and bar >= 1:
                place(drums, snare() * 0.8, tb)
            for h in range(4):
                if bar >= 2 or h % 2 == 0:
                    place(drums, hat(open_=(h == 2)) * (0.35 if h % 2 else 0.22), tb + h * beat / 4)
            # bass: driving 16ths, octave jump on the last 16th of each beat
            for s in range(4):
                m = root + (12 if s == 3 else 0)
                cutoff = 500 + 700 * (bar >= 8)
                place(bass, saw_note(midi(m), beat / 4 * 0.95, cutoff), tb + s * beat / 4)
            # lead arp from bar 4
            if bar >= 4:
                arp = chord + [chord[1] + 12, chord[2] + 12, chord[0] + 12] if bar >= 12 else chord + [chord[0] + 12]
                for s in range(4):
                    idx = (bar * 16 + b * 4 + s) % len(arp)
                    place(lead, sq_note(midi(arp[idx]), beat / 4 * 0.9) * 0.5, tb + s * beat / 4)
        # pad: whole bar chord
        t = t_axis(4 * beat)
        chord_wave = sum(((midi(m - 12) * t) % 1.0) * 2 - 1 + ((midi(m - 12) * 1.008 * t) % 1.0) * 2 - 1 for m in chord)
        envp = np.minimum(1, t / 0.6) * np.minimum(1, (4 * beat - t) / 0.3)
        place(pad, lp(chord_wave, 1400) * envp * 0.12, bar * 4 * beat)

    # simple delay on lead
    d = int(SR * beat * 0.75)
    lead_d = lead.copy()
    lead_d[d:] += lead[:-d] * 0.35
    master = kick_bus * 1.1 + drums * 0.55 + bass * duck * 0.9 + lead_d * 0.32 * duck ** 0.5 + pad * duck
    master = np.tanh(master * 1.3)
    # wrap the delay/pad tail into the start so the loop is seamless
    return master


# ---- rain (spec §10.3): far back, band-limited, never a flat hiss. Built from
# separate patter, droplet and drip layers with slow gusts so it comes and
# goes. Events are placed on a circular buffer and filtered over three tiled
# copies, so the loop has no seam.
RAIN_SECONDS = 20.0


def _loop_filter(x, f):
    """Apply filter f to a looping buffer without an edge click at the seam."""
    n = len(x)
    return f(np.tile(x, 3))[n:2 * n]


def _rain_events(r, n, count, ln_range, make):
    out = np.zeros(n)
    for _ in range(count):
        s = int(r.uniform(0, n))
        ev = make(int(r.uniform(*ln_range)))
        idx = (np.arange(len(ev)) + s) % n
        np.add.at(out, idx, ev)
    return out


def _gusts(r, n, period_lo=2.5, period_hi=6.0, depth=0.55):
    """A slow, smooth, looping swell between (1 - depth) and 1."""
    secs = n / SR
    env = np.zeros(n)
    t = np.arange(n) / SR
    for _ in range(4):
        cycles = max(1, round(secs / r.uniform(period_lo, period_hi)))
        env += np.sin(2 * np.pi * cycles * t / secs + r.uniform(0, 2 * np.pi)) * r.uniform(0.5, 1.0)
    env = (env - env.min()) / (np.ptp(env) or 1.0)
    return 1.0 - depth + depth * env


def rain_layers(heavy=False, seed=7):
    r = np.random.default_rng(seed + (100 if heavy else 0))
    n = int(SR * RAIN_SECONDS)

    def patter_hit(ln):
        k = r.uniform(250, 600)
        return r.uniform(-1, 1, ln) * np.exp(-np.arange(ln) / SR * k) * r.uniform(0.05, 0.3)

    def droplet(ln):
        tt = np.arange(ln) / SR
        f = r.uniform(1400, 3200)
        return np.sin(2 * np.pi * f * tt * (1 - tt * 2.5)) * np.exp(-tt * r.uniform(120, 220)) * r.uniform(0.15, 0.5)

    def drip(ln):
        tt = np.arange(ln) / SR
        f = r.uniform(600, 1300)
        return np.sin(2 * np.pi * f * tt * (1 + tt * 4)) * np.exp(-tt * r.uniform(28, 45)) * r.uniform(0.3, 0.6)

    patter = _rain_events(r, n, int(RAIN_SECONDS * (900 if heavy else 380)), (30, 140), patter_hit)
    patter = _loop_filter(patter, lambda x: bp(x, 350, 2600 if heavy else 3200))
    drops = _rain_events(r, n, int(RAIN_SECONDS * (40 if heavy else 22)), (300, 900), droplet)
    drops = _loop_filter(drops, lambda x: bp(x, 700, 4200))
    drips = _rain_events(r, n, int(RAIN_SECONDS * (1.2 if heavy else 0.7)), (2500, 5000), drip)
    drips = _loop_filter(drips, lambda x: bp(x, 400, 2500))
    # a little low body so heavy rain is felt; low-passed, never a hiss
    body = _loop_filter(r.uniform(-1, 1, n), lambda x: lp(hp(x, 90), 420)) * (0.35 if heavy else 0.12)
    g1 = _gusts(r, n, depth=0.5 if heavy else 0.65)
    g2 = _gusts(r, n, 4.0, 9.0, 0.6)
    left = patter * g1 + drops * g2 * 0.8 + drips + body * g1
    # the right channel takes its own events so the bed is wide, not mono
    patter_r = _loop_filter(_rain_events(r, n, int(RAIN_SECONDS * (900 if heavy else 380)), (30, 140), patter_hit),
                            lambda x: bp(x, 350, 2600 if heavy else 3200))
    drops_r = _loop_filter(_rain_events(r, n, int(RAIN_SECONDS * (40 if heavy else 22)), (300, 900), droplet),
                           lambda x: bp(x, 700, 4200))
    right = patter_r * g2 + drops_r * g1 * 0.8 + np.roll(drips, int(SR * 7.3)) * 0.7 + body * g2
    # gentle top-end roll-off: nothing above about 5 kHz reaches the speakers
    left = _loop_filter(left, lambda x: lp(x, 4800, 4))
    right = _loop_filter(right, lambda x: lp(x, 4800, 4))
    return left, right


def rain_ogg():
    for name, heavy in [("rain", False), ("rain_heavy", True)]:
        left, right = rain_layers(heavy)
        peak = max(np.max(np.abs(left)), np.max(np.abs(right))) or 1.0
        # to_ogg normalises each channel; scale both by the same peak instead
        to_ogg(name, left / peak * 0.9, 3, right / peak * 0.9, normalise=False)


def main():
    os.makedirs(OUT, exist_ok=True)
    if sys.argv[1:] == ["rain"]:
        rain_ogg()
        return
    save("shotgun", sfx_shotgun())
    save("recharge", sfx_recharge(), 0.6)
    save("empty", sfx_empty(), 0.6)
    save("zap", sfx_zap(), 0.6)
    save("felled", sfx_felled(), 0.9)
    save("flatline", sfx_flatline(), 0.8)
    save("cutin", sfx_cutin(), 0.7)
    save("finish", sfx_finish(), 0.95)
    for i, p in enumerate([1.0, 0.85, 1.18]):
        save(f"swing{i}", sfx_swing(p), 0.7)
    save("slice", sfx_slice())
    for i in range(3):
        save(f"gore{i}", sfx_gore(i), 0.85)
    save("gore_big", sfx_gore(7, True))
    save("execution", sfx_execution())
    save("deflect", sfx_deflect(), 0.8)
    save("headshot", sfx_headshot(), 0.6)
    save("hurt", sfx_hurt())
    save("enemy_shot", sfx_enemy_shot(), 0.6)
    save("windup", sfx_windup(), 0.5)
    save("roar", sfx_roar())
    save("slam", sfx_slam())
    save("dash", sfx_dash(), 0.7)
    save("jump", sfx_jump(), 0.5)
    save("land", sfx_land(), 0.6)
    save("jumppad", sfx_jumppad(), 0.7)
    save("pickup", sfx_pickup(), 0.5)
    save("levelup", sfx_levelup(), 0.7)
    save("alarm", sfx_alarm(), 0.6)
    save("wave_clear", sfx_wave_clear(), 0.7)
    save("spawn", sfx_spawn(), 0.5)
    save("player_death", sfx_player_death())
    save("ui_click", sfx_ui_click(), 0.5)
    save("ui_hover", sfx_ui_hover(), 0.4)
    save("ignite", sfx_ignite(), 0.6)
    save("bolt_hit", sfx_bolt_hit(), 0.6)
    save("wave_blade", sfx_wave_blade(), 0.7)
    save("explosion", sfx_explosion())
    save("missile", sfx_missile(), 0.6)
    save("beep", sfx_beep(), 0.5)
    save("boss_intro", sfx_boss_intro())
    save("riser", sfx_riser(), 0.6)
    save("blink", sfx_blink(), 0.6)
    save("shuriken", sfx_shuriken(), 0.6)
    save("gatling", sfx_gatling(), 0.55)
    save("coin", sfx_coin(), 0.6)
    save("highscore", sfx_highscore(), 0.6)
    save("type", sfx_type(), 0.4)
    save("thunder", sfx_thunder(), 0.8)
    save("tick", sfx_tick(), 0.45)
    save("stamp", sfx_stamp(), 0.85)
    save("chime", sfx_chime(), 0.6)
    save("cash", sfx_cash(), 0.75)
    save("count", sfx_count(), 0.6)
    save("go", sfx_go(), 0.85)
    save("mult", sfx_mult(), 0.6)
    save("deal", sfx_deal(), 0.5)
    save("fanfare", sfx_fanfare(), 0.7)
    rain_ogg()
    print("audio written to", os.path.abspath(OUT))


if __name__ == "__main__":
    main()
