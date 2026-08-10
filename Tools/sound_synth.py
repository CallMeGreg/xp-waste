#!/usr/bin/env python3
"""
XP Waste — OSRS-inspired sound design (generator for the game's SFX).

All sounds are ORIGINAL compositions synthesized from scratch. They evoke the
*spirit* of famous Old School RuneScape moments (the level-up fanfare, chopping
wood, mining ore, coins, bank deposits, prayer chimes) without sampling or
copying any copyrighted Jagex audio.

Deterministic (fixed RNG seed), so re-running reproduces byte-identical output.

Usage:
    python3 Tools/sound_synth.py            # write every option to ./sounds/ (audition set)
    python3 Tools/sound_synth.py --install  # also copy the CHOSEN cues into the app bundle
                                            #   (Sources/Resources/Sounds/sfx_*.wav)

See docs/SOUND_DESIGN.md for the option -> shipped-cue mapping and how to re-pick.
"""
import numpy as np
import wave
import os
import shutil
import sys

# The options wired into the game today. Key = generated option file (see build()),
# value = bundled cue name loaded by Sources/Models/SoundManager.swift.
CHOSEN = {
    'tap_a_click':          'sfx_tap',
    'slot_b_confirm':       'sfx_levelup',
    'supercharge_a_surge':  'sfx_supercharge',
    'energycell_b_electric':'sfx_energycell',
    'doublexp_a_shimmer':   'sfx_doublexp',
    'purchase_b_success':   'sfx_purchase',
    'ui_b_tab':             'sfx_ui',
}

SR = 44100
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "sounds")
os.makedirs(OUT, exist_ok=True)

rng = np.random.default_rng(42)

# ----------------------------------------------------------------------------
# Core helpers
# ----------------------------------------------------------------------------

def tarr(dur):
    return np.linspace(0, dur, int(dur * SR), endpoint=False)

def note(name):
    """Note name like 'A4', 'C#5', 'Eb3' -> frequency (Hz), A4=440."""
    names = {'C':0,'C#':1,'Db':1,'D':2,'D#':3,'Eb':3,'E':4,'F':5,'F#':6,
             'Gb':6,'G':7,'G#':8,'Ab':8,'A':9,'A#':10,'Bb':10,'B':11}
    i = 0
    while i < len(name) and (name[i].isalpha() or name[i] in '#b'):
        i += 1
    pitch, octave = name[:i], int(name[i:])
    semitone = names[pitch] + (octave + 1) * 12
    return 440.0 * 2 ** ((semitone - 69) / 12.0)

def adsr(n, a=0.005, d=0.05, s=0.7, r=0.1, curve=1.0):
    """ADSR envelope of length n samples (a/d/r in seconds, s sustain level)."""
    a_n = max(1, int(a * SR)); d_n = max(1, int(d * SR)); r_n = max(1, int(r * SR))
    sus_n = max(0, n - a_n - d_n - r_n)
    env = np.concatenate([
        np.linspace(0, 1, a_n) ** curve,
        s + (1 - s) * (1 - np.linspace(0, 1, d_n)) ** curve,
        np.full(sus_n, s),
        np.linspace(s, 0, r_n) ** curve,
    ])
    if len(env) < n:
        env = np.concatenate([env, np.zeros(n - len(env))])
    return env[:n]

def perc_env(n, attack=0.002, decay=0.25, curve=3.0):
    """Sharp percussive envelope (exp-ish decay)."""
    a_n = max(1, int(attack * SR))
    body = n - a_n
    e = np.concatenate([
        np.linspace(0, 1, a_n),
        (1 - np.linspace(0, 1, max(1, body))) ** curve,
    ])
    if len(e) < n:
        e = np.concatenate([e, np.zeros(n - len(e))])
    return e[:n]

def osc(freq, dur, kind='sine', detune=0.0, phase=0.0):
    t = tarr(dur)
    f = freq * (2 ** (detune / 1200.0))
    ph = 2 * np.pi * f * t + phase
    if kind == 'sine':
        return np.sin(ph)
    if kind == 'tri':
        return 2 / np.pi * np.arcsin(np.sin(ph))
    if kind == 'square':
        return np.sign(np.sin(ph))
    if kind == 'saw':
        return 2 * (f * t - np.floor(0.5 + f * t))
    raise ValueError(kind)

def supersaw(freq, dur, voices=5, spread=14.0, kind='saw'):
    """Detuned stacked oscillators for a fat synth-brass tone."""
    out = np.zeros(int(dur * SR))
    for i in range(voices):
        det = spread * (i - (voices - 1) / 2)
        out += osc(freq, dur, kind, detune=det, phase=rng.uniform(0, 2 * np.pi))
    return out / voices

def noise(dur):
    return rng.uniform(-1, 1, int(dur * SR))

def sweep(f0, f1, dur, kind='sine', log=True):
    t = tarr(dur)
    if log:
        f = f0 * (f1 / f0) ** (t / dur)
    else:
        f = np.linspace(f0, f1, len(t))
    ph = 2 * np.pi * np.cumsum(f) / SR
    if kind == 'sine':
        return np.sin(ph)
    if kind == 'saw':
        return 2 * ((ph / (2 * np.pi)) % 1) - 1
    if kind == 'square':
        return np.sign(np.sin(ph))
    return np.sin(ph)

def fft_filter(x, kind, f1, f2=None, order=4):
    N = len(x)
    if N == 0:
        return x
    X = np.fft.rfft(x)
    freqs = np.fft.rfftfreq(N, 1 / SR)
    fsafe = np.maximum(freqs, 1e-6)
    if kind == 'low':
        H = 1 / np.sqrt(1 + (freqs / f1) ** (2 * order))
    elif kind == 'high':
        H = 1 / np.sqrt(1 + (f1 / fsafe) ** (2 * order))
    elif kind == 'band':
        Hh = 1 / np.sqrt(1 + (f1 / fsafe) ** (2 * order))
        Hl = 1 / np.sqrt(1 + (freqs / f2) ** (2 * order))
        H = Hh * Hl
    else:
        raise ValueError(kind)
    return np.fft.irfft(H * X, n=N)

def bell(freq, dur, decay=0.5, partials=(1, 2.76, 5.4, 8.93), amps=(1, 0.6, 0.4, 0.25)):
    """Inharmonic bell/chime via detuned partials with independent decays."""
    t = tarr(dur)
    out = np.zeros(len(t))
    for p, a in zip(partials, amps):
        env = np.exp(-t / (decay / max(1.0, p ** 0.5)))
        out += a * np.sin(2 * np.pi * freq * p * t) * env
    return out / np.max(np.abs(out) + 1e-9)

def place(canvas, sound, at):
    """Add `sound` into `canvas` starting at time `at` seconds (in place)."""
    i = int(at * SR)
    j = min(len(canvas), i + len(sound))
    canvas[i:j] += sound[: j - i]
    return canvas

def pad(x, tail=0.1):
    return np.concatenate([x, np.zeros(int(tail * SR))])

def fftconvolve(x, h):
    n = len(x) + len(h) - 1
    nfft = 1 << (n - 1).bit_length()
    X = np.fft.rfft(x, nfft)
    H = np.fft.rfft(h, nfft)
    return np.fft.irfft(X * H, nfft)[:n]

def reverb(x, amount=0.25, decay=0.5, predelay=0.01):
    """Cheap lush reverb: convolve with a decaying, slightly-filtered noise IR."""
    ir_len = int(decay * SR)
    ir = rng.uniform(-1, 1, ir_len) * np.exp(-np.linspace(0, 6, ir_len))
    ir = fft_filter(ir, 'low', 6500, order=2)
    pre = np.zeros(int(predelay * SR))
    ir = np.concatenate([pre, ir])
    wet = fftconvolve(x, ir)
    wet = wet[: len(x)] if len(wet) >= len(x) else np.concatenate([wet, np.zeros(len(x) - len(wet))])
    wet /= (np.max(np.abs(wet)) + 1e-9)
    return (1 - amount) * x + amount * wet

def normalize(x, peak=0.92):
    m = np.max(np.abs(x))
    if m < 1e-9:
        return x
    return x / m * peak

def soft_clip(x, drive=1.0):
    return np.tanh(drive * x)

def save(name, x, gain=1.0, fade_out=0.01):
    x = np.asarray(x, dtype=np.float64) * gain
    x = normalize(x)
    fo = int(fade_out * SR)
    if fo > 0 and len(x) > fo:
        x[-fo:] *= np.linspace(1, 0, fo)
    fi = int(0.002 * SR)
    if len(x) > fi:
        x[:fi] *= np.linspace(0, 1, fi)
    data = np.clip(x, -1, 1)
    pcm = (data * 32767).astype('<i2')
    path = os.path.join(OUT, name + '.wav')
    with wave.open(path, 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    dur = len(x) / SR
    print(f"  {name+'.wav':32s} {dur:4.2f}s")
    return path

# ----------------------------------------------------------------------------
# Instrument helpers
# ----------------------------------------------------------------------------

def brass_note(freq, dur, a=0.01, d=0.08, s=0.65, r=0.12, voices=6, spread=12, cutoff=None):
    tone = supersaw(freq, dur, voices=voices, spread=spread)
    if cutoff is None:
        cutoff = min(9000, freq * 8)
    tone = fft_filter(tone, 'low', cutoff, order=3)
    return tone * adsr(len(tone), a, d, s, r)

def marimba_note(freq, dur, decay=0.35):
    t = tarr(dur)
    tone = (np.sin(2*np.pi*freq*t)
            + 0.4*np.sin(2*np.pi*freq*4.0*t)
            + 0.15*np.sin(2*np.pi*freq*9.2*t))
    return tone * np.exp(-t / decay)

def choir_note(freq, dur, a=0.12, r=0.3):
    t = tarr(dur)
    tone = np.zeros(len(t))
    for h, amp in [(1,1),(2,0.5),(3,0.28),(4,0.15),(5,0.08)]:
        vib = 1 + 0.006 * np.sin(2*np.pi*5.2*t)
        tone += amp * np.sin(2*np.pi*freq*h*t*vib)
    tone = fft_filter(tone, 'low', 4200, order=2)
    return tone * adsr(len(tone), a=a, d=0.2, s=0.85, r=r)

def sparkle(dur, n=14, fmin=1400, fmax=6000, spread=None):
    """Random high bell 'twinkles' — magical shimmer layer."""
    out = np.zeros(int((dur) * SR) + SR // 2)
    for _ in range(n):
        f = rng.uniform(fmin, fmax)
        d = rng.uniform(0.12, 0.3)
        at = rng.uniform(0, dur)
        s = np.sin(2*np.pi*f*tarr(d)) * np.exp(-tarr(d)/ (d*0.4))
        place(out, s * rng.uniform(0.2, 0.5), at)
    return out

# ----------------------------------------------------------------------------
# SFX definitions
# ----------------------------------------------------------------------------

def chord(freqs, dur, inst, **kw):
    out = None
    for f in freqs:
        n = inst(f, dur, **kw)
        out = n if out is None else out + n
    return out / len(freqs)

def build():
    print("Generating sounds ->", OUT)

    # ===================== TAP / TRAIN (core loop) =====================
    # A: crisp interface-style click (universal, subtle "tick")
    click = noise(0.03)
    click = fft_filter(click, 'band', 1400, 4200)
    click *= perc_env(len(click), attack=0.0005, decay=0.03, curve=4)
    tick = osc(2000, 0.02, 'sine') * perc_env(int(0.02*SR), 0.0005, 0.02, 4)
    save('tap_a_click', pad(place(np.zeros(int(0.05*SR)), click, 0.0)[:len(click)] + 0.5*pad(tick, 0.03)[:len(click)], 0.08), gain=0.9)

    # B: woody "thock" — chopping wood
    body = (osc(220, 0.12, 'sine') + 0.5*osc(330, 0.12, 'tri')) * perc_env(int(0.12*SR), 0.001, 0.12, 5)
    knock = fft_filter(noise(0.06), 'band', 400, 1600) * perc_env(int(0.06*SR), 0.0005, 0.05, 4)
    thock = pad(body, 0.05)
    thock[:len(knock)] += 0.8 * knock
    save('tap_b_thock', thock, gain=0.95)

    # C: metallic "clink" — mining / smithing pick strike
    clink = bell(1650, 0.18, decay=0.12, partials=(1,2.1,3.7,5.9), amps=(1,0.7,0.5,0.3))
    clink *= perc_env(len(clink), 0.0008, 0.16, 3)
    tap_metal = fft_filter(noise(0.02), 'high', 3000) * perc_env(int(0.02*SR), 0.0003, 0.02, 5)
    out = pad(clink, 0.05)
    out[:len(tap_metal)] += 0.5 * tap_metal
    save('tap_c_clink', out, gain=0.9)

    # D: soft "splash/plink" — fishing bob
    drop = sweep(1200, 500, 0.14, 'sine') * perc_env(int(0.14*SR), 0.001, 0.14, 3)
    water = fft_filter(noise(0.1), 'band', 600, 2500) * perc_env(int(0.1*SR), 0.002, 0.09, 2)
    splash = pad(drop, 0.05)
    splash[:len(water)] += 0.5*water
    save('tap_d_splash', reverb(splash, 0.15, 0.3), gain=0.9)

    # ===================== LEVEL UP (flagship) =====================
    # A: classic bright brass fanfare — rising arpeggio resolving to a major chord
    seq = [('G4',0.00,0.14),('C5',0.12,0.14),('E5',0.24,0.14),('G5',0.36,0.5)]
    total = 1.6
    canvas = np.zeros(int(total*SR))
    for nm, at, dur in seq:
        place(canvas, brass_note(note(nm), dur, a=0.008, d=0.06, s=0.7, r=0.16), at)
    # final triumphant chord
    ch = chord([note('C5'),note('E5'),note('G5'),note('C6')], 0.9, brass_note, a=0.01, d=0.1, s=0.75, r=0.5)
    place(canvas, ch*1.1, 0.5)
    place(canvas, sparkle(1.1, n=10, fmin=2500, fmax=7000)[:len(canvas)-int(0.4*SR)], 0.4)
    save('levelup_a_brass', reverb(canvas, 0.28, 0.7), gain=1.0)

    # B: celebratory bell/marimba cascade
    total = 1.7
    canvas = np.zeros(int(total*SR))
    melody = [('C5',0.0),('E5',0.09),('G5',0.18),('C6',0.27),('E6',0.36),('G6',0.46)]
    for nm, at in melody:
        place(canvas, marimba_note(note(nm), 0.7, decay=0.4)*0.9, at)
    place(canvas, chord([note('C5'),note('E5'),note('G5'),note('C6')],1.2,marimba_note,decay=0.6)*0.8, 0.55)
    place(canvas, sparkle(1.3, n=16)[:len(canvas)], 0.2)
    save('levelup_b_bells', reverb(canvas, 0.3, 0.8), gain=1.0)

    # C: warm synth "ta-daa" with choir shimmer
    total = 1.9
    canvas = np.zeros(int(total*SR))
    place(canvas, brass_note(note('G4'),0.22, a=0.01,d=0.06,s=0.7,r=0.1), 0.0)
    place(canvas, chord([note('C5'),note('E5'),note('G5'),note('C6')],1.4, brass_note, a=0.02,d=0.12,s=0.8,r=0.7)*1.05, 0.22)
    place(canvas, chord([note('C4'),note('C5'),note('G5')],1.5, choir_note)*0.5, 0.25)
    place(canvas, sparkle(1.4, n=12, fmin=3000, fmax=8000)[:len(canvas)], 0.3)
    save('levelup_c_choir', reverb(canvas, 0.32, 0.9), gain=1.0)

    # ===================== MILESTONE 99 (grand) =====================
    total = 2.8
    canvas = np.zeros(int(total*SR))
    fan = [('C5',0.0,0.16),('E5',0.14,0.16),('G5',0.28,0.16),('C6',0.42,0.16),('D6',0.56,0.2),('E6',0.7,0.6)]
    for nm, at, dur in fan:
        place(canvas, brass_note(note(nm), dur, a=0.008,d=0.06,s=0.72,r=0.18)*1.0, at)
    place(canvas, chord([note('C5'),note('E5'),note('G5'),note('C6'),note('E6')],1.8, brass_note, a=0.02,d=0.12,s=0.8,r=0.9)*1.1, 0.95)
    place(canvas, chord([note('C4'),note('G4'),note('C5')],2.0, choir_note)*0.5, 0.95)
    # fireworks sparkle bursts
    for at in (1.0, 1.4, 1.9, 2.2):
        place(canvas, sparkle(0.6, n=10, fmin=3000, fmax=9000)[:int(0.7*SR)], at)
    save('milestone99_a_grand', reverb(canvas, 0.34, 1.1), gain=1.0)

    # ===================== SUPERCHARGE activate =====================
    # A: rising energy whoosh + power chord (special-attack surge)
    total = 1.3
    canvas = np.zeros(int(total*SR))
    up = sweep(180, 1400, 0.55, 'saw') * adsr(int(0.55*SR), a=0.05, d=0.1, s=0.8, r=0.2)
    up = fft_filter(up, 'low', 3500, order=2)
    place(canvas, up*0.7, 0.0)
    air = fft_filter(noise(0.6), 'band', 800, 5000) * np.linspace(0,1,int(0.6*SR))**2
    place(canvas, air*0.4, 0.0)
    place(canvas, chord([note('C3'),note('C4'),note('G4'),note('C5')],0.8, brass_note, a=0.01,d=0.1,s=0.8,r=0.5)*1.0, 0.5)
    save('supercharge_a_surge', reverb(canvas, 0.25, 0.6), gain=1.0)

    # B: deep overload potion — bubbling power-up
    total = 1.4
    canvas = np.zeros(int(total*SR))
    base = sweep(90, 360, 1.0, 'saw') * adsr(int(1.0*SR), a=0.1, d=0.2, s=0.8, r=0.3)
    base = fft_filter(base, 'low', 1800, order=2)
    place(canvas, base*0.7, 0.0)
    for k in range(9):
        at = 0.1 + k*0.09
        bub = sweep(rng.uniform(300,500), rng.uniform(700,1100), 0.08,'sine')*perc_env(int(0.08*SR),0.002,0.08,3)
        place(canvas, bub*0.35, at)
    place(canvas, sparkle(0.9, n=10, fmin=1800, fmax=5000)[:len(canvas)-int(0.5*SR)], 0.5)
    save('supercharge_b_overload', reverb(canvas, 0.22, 0.5), gain=1.0)

    # ===================== ENERGY CELL =====================
    # A: potion "glug glug" + refresh sparkle
    total = 1.1
    canvas = np.zeros(int(total*SR))
    for k in range(3):
        at = 0.05 + k*0.14
        glug = sweep(rng.uniform(200,260), rng.uniform(120,160), 0.12,'sine')*perc_env(int(0.12*SR),0.004,0.12,2)
        place(canvas, fft_filter(glug,'low',900)*0.8, at)
    place(canvas, sparkle(0.6, n=12, fmin=2500, fmax=7000)[:int(0.7*SR)], 0.5)
    ding = bell(1200,0.5,decay=0.4)*adsr(int(0.5*SR),0.005,0.1,0.6,0.3)
    place(canvas, ding*0.5, 0.55)
    save('energycell_a_potion', reverb(canvas, 0.2, 0.4), gain=1.0)

    # B: electric recharge hum + zap
    total = 1.0
    canvas = np.zeros(int(total*SR))
    hum = (osc(120,0.7,'saw')+osc(180,0.7,'square')*0.3)
    hum = fft_filter(hum,'band',150,1200)*adsr(int(0.7*SR),0.02,0.1,0.7,0.3)
    place(canvas, hum*0.5, 0.0)
    zap = fft_filter(noise(0.25),'high',2500)*perc_env(int(0.25*SR),0.001,0.25,3)
    place(canvas, zap*0.6, 0.05)
    rise = sweep(400,2600,0.5,'square')*adsr(int(0.5*SR),0.02,0.1,0.6,0.2)*0.25
    place(canvas, fft_filter(rise,'low',4000), 0.1)
    save('energycell_b_electric', reverb(canvas, 0.18, 0.4), gain=1.0)

    # ===================== DOUBLE XP activate =====================
    # A: shimmering ascending magical power-up
    total = 1.5
    canvas = np.zeros(int(total*SR))
    scale = ['C5','D5','E5','G5','A5','C6','D6','E6']
    for i, nm in enumerate(scale):
        at = i*0.06
        place(canvas, bell(note(nm),0.6,decay=0.4)*adsr(int(0.6*SR),0.004,0.1,0.6,0.4)*0.7, at)
    place(canvas, chord([note('C6'),note('E6'),note('G6')],1.0,bell,decay=0.6)*0.6, 0.5)
    place(canvas, sparkle(1.2, n=20, fmin=3000, fmax=9000)[:len(canvas)], 0.1)
    save('doublexp_a_shimmer', reverb(canvas, 0.3, 0.8), gain=1.0)

    # B: triumphant short chime + magic swirl
    total = 1.2
    canvas = np.zeros(int(total*SR))
    place(canvas, chord([note('E5'),note('G#5'),note('B5')],0.5,marimba_note,decay=0.4)*0.9, 0.0)
    place(canvas, chord([note('A5'),note('C#6'),note('E6')],0.9,marimba_note,decay=0.5)*0.9, 0.22)
    swirl = sweep(600,2400,0.6,'sine')*adsr(int(0.6*SR),0.05,0.1,0.6,0.3)*0.3
    place(canvas, swirl, 0.1)
    place(canvas, sparkle(0.9, n=14, fmin=3500, fmax=9000)[:len(canvas)], 0.1)
    save('doublexp_b_chime', reverb(canvas, 0.28, 0.7), gain=1.0)

    # ===================== BANK / SLOT skill =====================
    # A: bank deposit "clunk" (chest thud + metal)
    total = 0.5
    canvas = np.zeros(int(total*SR))
    thud = (osc(90,0.25,'sine')+0.4*osc(140,0.25,'tri'))*perc_env(int(0.25*SR),0.001,0.24,4)
    place(canvas, thud*0.9, 0.0)
    metal = bell(900,0.25,decay=0.14,partials=(1,1.9,3.3),amps=(1,0.6,0.4))*perc_env(int(0.25*SR),0.001,0.2,3)
    place(canvas, metal*0.4, 0.02)
    save('bank_a_clunk', reverb(canvas, 0.15, 0.35), gain=1.0)

    # B: soft confirm chime (slot assigned)
    total = 0.6
    canvas = np.zeros(int(total*SR))
    place(canvas, marimba_note(note('E5'),0.35,decay=0.3)*0.9, 0.0)
    place(canvas, marimba_note(note('B5'),0.4,decay=0.35)*0.9, 0.09)
    save('slot_b_confirm', reverb(canvas, 0.2, 0.4), gain=1.0)

    # ===================== PURCHASE / COINS =====================
    # A: coin jingle "cha-ching"
    total = 0.9
    canvas = np.zeros(int(total*SR))
    for _ in range(10):
        at = rng.uniform(0, 0.45)
        f = rng.uniform(1800, 3600)
        c = bell(f, 0.28, decay=0.16, partials=(1,2.4,4.1), amps=(1,0.5,0.3))*perc_env(int(0.28*SR),0.0006,0.26,3)
        place(canvas, c*rng.uniform(0.3,0.6), at)
    place(canvas, chord([note('C6'),note('G6')],0.5,marimba_note,decay=0.35)*0.5, 0.4)
    save('coins_a_jingle', reverb(canvas, 0.18, 0.4), gain=1.0)

    # B: purchase success — register ding + sparkle
    total = 1.0
    canvas = np.zeros(int(total*SR))
    place(canvas, bell(1400,0.5,decay=0.35)*adsr(int(0.5*SR),0.002,0.1,0.6,0.3)*0.9, 0.0)
    place(canvas, bell(2100,0.5,decay=0.3)*adsr(int(0.5*SR),0.002,0.1,0.6,0.3)*0.7, 0.12)
    for _ in range(6):
        at = rng.uniform(0.05,0.5); f=rng.uniform(2000,3800)
        place(canvas, bell(f,0.2,decay=0.12)*perc_env(int(0.2*SR),0.0006,0.18,3)*rng.uniform(0.2,0.4), at)
    save('purchase_b_success', reverb(canvas, 0.22, 0.5), gain=1.0)

    # ===================== UI =====================
    # A: classic interface click
    c = fft_filter(noise(0.02), 'band', 1200, 3500)*perc_env(int(0.02*SR),0.0004,0.02,5)
    c2 = osc(1500,0.012,'sine')*perc_env(int(0.012*SR),0.0004,0.012,5)
    out = pad(c, 0.03)
    out[:len(c2)] += 0.5*c2
    save('ui_a_click', out, gain=0.85)

    # B: soft tab switch (two-tone blip)
    total = 0.18
    canvas = np.zeros(int(total*SR))
    place(canvas, osc(660,0.06,'sine')*perc_env(int(0.06*SR),0.002,0.06,3)*0.7, 0.0)
    place(canvas, osc(990,0.08,'sine')*perc_env(int(0.08*SR),0.002,0.08,3)*0.7, 0.05)
    save('ui_b_tab', canvas, gain=0.85)

    print("Done.")

def install():
    """Copy the CHOSEN option WAVs into the app bundle with their shipped names."""
    dst_dir = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                            '..', 'Sources', 'Resources', 'Sounds'))
    os.makedirs(dst_dir, exist_ok=True)
    for option, cue in CHOSEN.items():
        src = os.path.join(OUT, option + '.wav')
        dst = os.path.join(dst_dir, cue + '.wav')
        shutil.copyfile(src, dst)
        print(f"  installed {option+'.wav':28s} -> {cue}.wav")

if __name__ == '__main__':
    build()
    if '--install' in sys.argv:
        print("Installing chosen cues into the app bundle ->", )
        install()
