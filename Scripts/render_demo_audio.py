#!/usr/bin/env python3
"""Render original demo audio and the app icon for Matthew Finley Music Player.

The pieces in App/Audio are synthesized by this script. They are not the
public catalog, and they are not recordings of existing songs. Re-run from
the repository root:

    python3 Scripts/render_demo_audio.py
"""

from __future__ import annotations

import math
import struct
import wave
import zlib
from pathlib import Path

import numpy as np

SR = 44100
SECONDS = 12
N = SR * SECONDS
ROOT = Path(__file__).resolve().parents[1]
AUDIO_DIR = ROOT / "App" / "Audio"
ICON_PATH = ROOT / "App" / "Assets.xcassets" / "AppIcon.appiconset" / "AppIcon.png"


def timebase() -> np.ndarray:
    return np.arange(N, dtype=np.float64) / SR


def sine(freq: np.ndarray | float, t: np.ndarray, phase: float = 0.0) -> np.ndarray:
    return np.sin(2.0 * math.pi * freq * t + phase)


def one_pole_lowpass(x: np.ndarray, cutoff: float) -> np.ndarray:
    alpha = 1.0 - math.exp(-2.0 * math.pi * cutoff / SR)
    y = np.empty_like(x)
    acc = 0.0
    for i, sample in enumerate(x):
        acc += alpha * (sample - acc)
        y[i] = acc
    return y


def one_pole_highpass(x: np.ndarray, cutoff: float) -> np.ndarray:
    dt = 1.0 / SR
    rc = 1.0 / (2.0 * math.pi * cutoff)
    alpha = rc / (rc + dt)
    y = np.empty_like(x)
    prev_y = 0.0
    prev_x = 0.0
    for i, sample in enumerate(x):
        prev_y = alpha * (prev_y + sample - prev_x)
        prev_x = sample
        y[i] = prev_y
    return y


def fade(n: int = N, fade_in: float = 0.35, fade_out: float = 1.8) -> np.ndarray:
    env = np.ones(n, dtype=np.float64)
    a = int(fade_in * SR)
    r = int(fade_out * SR)
    if a > 0:
        env[:a] = np.linspace(0.0, 1.0, a)
    if r > 0:
        env[-r:] = np.linspace(1.0, 0.0, r)
    return env


def soft_clip(x: np.ndarray, drive: float = 1.35) -> np.ndarray:
    return np.tanh(x * drive) / math.tanh(drive)


def write_wav(path: Path, left: np.ndarray, right: np.ndarray) -> None:
    peak = max(float(np.max(np.abs(left))), float(np.max(np.abs(right))), 1e-9)
    gain = 0.89 / peak
    left = np.clip(left * gain, -1.0, 1.0)
    right = np.clip(right * gain, -1.0, 1.0)
    interleaved = np.empty(left.size * 2, dtype=np.float64)
    interleaved[0::2] = left
    interleaved[1::2] = right
    pcm = (interleaved * 32767.0).astype(np.int16)
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as handle:
        handle.setnchannels(2)
        handle.setsampwidth(2)
        handle.setframerate(SR)
        handle.writeframes(pcm.tobytes())
    low_l = one_pole_lowpass(left, 100.0)
    low_r = one_pole_lowpass(right, 100.0)
    correlation = float(np.corrcoef(low_l, low_r)[0, 1])
    rms = float(np.sqrt(np.mean(0.5 * (left * left + right * right))))
    print(f"{path.name}: peak {peak * gain:.3f} rms {rms:.3f} sub-correlation {correlation:.4f}")


def plucks(t: np.ndarray, hits: list[tuple[float, float, float]]) -> tuple[np.ndarray, np.ndarray]:
    """hits: (time seconds, frequency, amplitude). Soft mallet, stereo by a few cents."""
    left = np.zeros(N, dtype=np.float64)
    right = np.zeros(N, dtype=np.float64)
    for index, (when, freq, amp) in enumerate(hits):
        start = int(when * SR)
        if start >= N:
            continue
        length = min(N - start, int(0.55 * SR))
        local = np.arange(length, dtype=np.float64) / SR
        env = np.exp(-local * 7.5)
        bend = 1.0 + (0.0015 if index % 2 == 0 else -0.0015)
        left[start : start + length] += amp * env * np.sin(2.0 * math.pi * freq * local)
        right[start : start + length] += amp * env * np.sin(2.0 * math.pi * freq * bend * local)
    return left, right


def amber_room(t: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    bass_f = 73.42  # D2
    bass = 0.72 * sine(bass_f, t) + 0.38 * sine(bass_f / 2.0, t)
    bass += 0.08 * sine(bass_f * 1.5, t)  # a fifth still under 120 Hz
    bass *= 0.34 * (0.92 + 0.08 * sine(0.08, t))
    pad_freqs = [146.83, 174.61, 220.00, 261.63, 329.63]  # Dm9
    left = bass.copy()
    right = bass.copy()
    for index, freq in enumerate(pad_freqs):
        amp = 0.055 if index < 3 else 0.035
        left += amp * sine(freq, t, phase=index * 0.4)
        right += amp * sine(freq + 0.12, t, phase=index * 0.4)
    left = bass + soft_clip(one_pole_lowpass(left - bass, 1400.0), 1.5)
    right = bass + soft_clip(one_pole_lowpass(right - bass, 1400.0), 1.5)
    bpm = 70.0
    beat = 60.0 / bpm
    pattern = [293.66, 349.23, 440.0, 523.25, 329.63, 523.25, 440.0, 349.23]
    hits = []
    for step in range(int(SECONDS / beat)):
        hits.append((step * beat, pattern[step % len(pattern)], 0.07))
    pl, pr = plucks(t, hits)
    pl = one_pole_highpass(pl, 180.0)
    pr = one_pole_highpass(pr, 180.0)
    return (left + pl) * fade(), (right + pr) * fade()


def gold_hour(t: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    bpm = 86.0
    beat = 60.0 / bpm
    # Root-fifth bass motion, every note under 120 Hz.
    bass_notes = [49.00, 49.00, 73.42, 49.00]
    bass = np.zeros(N, dtype=np.float64)
    for step in range(int(SECONDS / beat) + 1):
        start = int(step * beat * SR)
        end = min(N, int((step + 1) * beat * SR))
        if start >= N:
            break
        local_t = t[start:end]
        freq = bass_notes[step % len(bass_notes)]
        edge = np.minimum(1.0, np.arange(end - start) / (0.03 * SR))
        bass[start:end] += edge * (0.75 * np.sin(2 * math.pi * freq * local_t) + 0.28 * np.sin(2 * math.pi * freq * 0.5 * local_t))
    bass *= 0.36
    pulse = 0.82 + 0.18 * (0.5 + 0.5 * sine(bpm / 60.0, t))
    pad_freqs = [196.00, 246.94, 293.66, 369.99]  # Gmaj7
    mid_l = np.zeros(N)
    mid_r = np.zeros(N)
    for index, freq in enumerate(pad_freqs):
        amp = 0.06
        mid_l += amp * sine(freq * 0.999, t)
        mid_r += amp * sine(freq * 1.001, t, phase=0.2 * index)
    mid_l = soft_clip(one_pole_lowpass(mid_l, 1600.0), 1.6) * pulse
    mid_r = soft_clip(one_pole_lowpass(mid_r, 1600.0), 1.6) * pulse
    sparkle_hits = []
    for step in range(int(SECONDS / beat)):
        if step % 2 == 1:
            sparkle_hits.append((step * beat, 783.99 if step % 4 == 1 else 987.77, 0.045))
    sl, sr = plucks(t, sparkle_hits)
    sl = one_pole_highpass(sl, 200.0)
    sr = one_pole_highpass(sr, 200.0)
    env = fade(fade_in=0.25, fade_out=1.5)
    return (bass + mid_l + sl) * env, (bass + mid_r + sr) * env


def soft_circuit(t: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    bpm = 104.0
    step = 60.0 / bpm / 2.0  # eighth notes
    bass_line = [55.0, 55.0, 65.41, 55.0, 73.42, 65.41, 49.0, 55.0]
    bass = np.zeros(N, dtype=np.float64)
    for index in range(int(SECONDS / step) + 1):
        start = int(index * step * SR)
        end = min(N, int((index + 0.92) * step * SR))
        if start >= N:
            break
        local = np.arange(end - start, dtype=np.float64) / SR
        freq = bass_line[index % len(bass_line)]
        env = np.exp(-local * 5.5)
        bass[start:end] += env * (0.85 * np.sin(2 * math.pi * freq * (t[start] + local)) + 0.25 * np.sin(math.pi * freq * (t[start] + local)))
    bass *= 0.4
    # Short chord stabs on each bar.
    bar = 60.0 / bpm * 4.0
    stab_l = np.zeros(N)
    stab_r = np.zeros(N)
    chord = [220.0, 261.63, 329.63, 392.0]  # Am7
    for bar_index in range(int(SECONDS / bar) + 1):
        start = int(bar_index * bar * SR)
        length = min(N - start, int(0.45 * SR))
        if length <= 0:
            break
        local = np.arange(length, dtype=np.float64) / SR
        env = np.exp(-local * 6.0)
        for tone in chord:
            stab_l[start : start + length] += 0.05 * env * np.sin(2 * math.pi * tone * local)
            stab_r[start : start + length] += 0.05 * env * np.sin(2 * math.pi * tone * 1.002 * local)
    stab_l = soft_clip(one_pole_highpass(stab_l, 160.0), 1.4)
    stab_r = soft_clip(one_pole_highpass(stab_r, 160.0), 1.4)
    ticks = []
    sixteenth = step / 2.0
    for index in range(int(SECONDS / sixteenth)):
        if index % 2 == 1:
            ticks.append((index * sixteenth, 1760.0, 0.03))
    tl, tr = plucks(t, ticks)
    tl = one_pole_highpass(tl, 400.0) * 0.7
    tr = one_pole_highpass(tr, 400.0) * 0.7
    env = fade(fade_in=0.08, fade_out=1.1)
    return (bass + stab_l + tl) * env, (bass + stab_r + tr) * env


def harbor_glass(t: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    bass_f = 43.65  # F1
    swell = 0.85 + 0.15 * sine(0.05, t)
    bass = swell * 0.3 * (0.8 * sine(bass_f, t) + 0.35 * sine(bass_f * 2.0, t))
    pad_freqs = [174.61, 220.0, 261.63, 329.63, 392.0]  # Fmaj9
    mid_l = np.zeros(N)
    mid_r = np.zeros(N)
    for index, freq in enumerate(pad_freqs):
        amp = 0.05 * (0.75 + 0.25 * np.sin(2 * math.pi * (0.03 + index * 0.01) * t + index))
        mid_l += amp * sine(freq, t, phase=index * 0.7)
        mid_r += amp * sine(freq + 0.08, t, phase=index * 0.7 + 0.4)
    mid_l = soft_clip(one_pole_lowpass(mid_l, 900.0), 1.25)
    mid_r = soft_clip(one_pole_lowpass(mid_r, 900.0), 1.25)
    # A slow bloom on the downbeat of a very slow pulse.
    blooms = []
    for when in np.arange(0.6, SECONDS, 3.4):
        blooms.append((float(when), 523.25, 0.04))
        blooms.append((float(when) + 1.1, 659.25, 0.028))
    bl, br = plucks(t, blooms)
    bl = one_pole_lowpass(one_pole_highpass(bl, 180.0), 2200.0)
    br = one_pole_lowpass(one_pole_highpass(br, 180.0), 2200.0)
    env = fade(fade_in=1.2, fade_out=2.4)
    return (bass + mid_l + bl) * env, (bass + mid_r + br) * env


def png_chunk(tag: bytes, data: bytes) -> bytes:
    return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)


def write_icon(path: Path) -> None:
    size = 1024
    rgb = np.zeros((size, size, 3), dtype=np.uint8)
    rgb[:, :] = (18, 15, 13)
    yy, xx = np.mgrid[0:size, 0:size]
    cx = cy = (size - 1) / 2.0
    dist = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2)
    disc = dist <= 430
    rgb[disc] = (232, 166, 74)
    inner = dist <= 318
    rgb[inner] = (22, 18, 16)
    # Five waveform bars, centered.
    bars = [150, 230, 320, 230, 160]
    bar_w = 46
    gap = 28
    total = len(bars) * bar_w + (len(bars) - 1) * gap
    left = int(cx - total / 2)
    for index, height in enumerate(bars):
        x0 = left + index * (bar_w + gap)
        y0 = int(cy - height / 2)
        rgb[y0 : y0 + height, x0 : x0 + bar_w] = (244, 214, 170)
    raw = b"".join(b"\x00" + rgb[row].tobytes() for row in range(size))
    ihdr = struct.pack(">IIBBBBB", size, size, 8, 2, 0, 0, 0)
    png = b"\x89PNG\r\n\x1a\n" + png_chunk(b"IHDR", ihdr) + png_chunk(b"IDAT", zlib.compress(raw, 9)) + png_chunk(b"IEND", b"")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(png)
    print(f"{path.relative_to(ROOT)}: {len(png)} bytes")


def main() -> None:
    t = timebase()
    tracks = {
        "amber-room.wav": amber_room,
        "gold-hour.wav": gold_hour,
        "soft-circuit.wav": soft_circuit,
        "harbor-glass.wav": harbor_glass,
    }
    for name, render in tracks.items():
        left, right = render(t)
        write_wav(AUDIO_DIR / name, left, right)
    write_icon(ICON_PATH)


if __name__ == "__main__":
    main()
