"""Measure the opening beat grid and make its short, original impact cue.

Run from the project root. ffmpeg is only used to decode the existing menu track.
No music is replaced or re-encoded in the game.
"""
import json
import subprocess
import wave
from pathlib import Path

import numpy as np
from scipy.signal import find_peaks

rate = 22050
raw = subprocess.check_output([
    "ffmpeg", "-v", "error", "-i", "audio/music/menu_pulsing.mp3",
    "-t", "52", "-f", "f32le", "-ar", str(rate), "-ac", "1", "pipe:1",
])
samples = np.frombuffer(raw, dtype="<f4")
hop = 220
envelope = np.sqrt(np.mean(samples[:len(samples)//hop*hop].reshape(-1, hop)**2, axis=1))
onsets, _ = find_peaks(np.maximum(0, np.diff(envelope)), distance=40, prominence=.12)
times = (onsets + 1) * hop / rate
# First eight seconds have a clean, isolated four-on-the-floor kick pattern.
times = times[times < 8]
period, offset = np.polyfit(np.arange(len(times)), times, 1)
result = {
    "track": "res://audio/music/menu_pulsing.mp3",
    "measured_bpm": float(60 / period),
    "measured_first_beat": float(offset),
    "authored_bpm": 128,
    "authored_first_beat": .03,
    "scene_beats": [0, 10, 20, 30, 40, 50, 60, 72, 82, 92],
    "logo_beat": 96,
    "logo_seconds": .03 + 96 * 60 / 128,
    "not_impact_beat": 100,
    "start_prompt_beat": 104,
    "not_delay_seconds": 4 * 60 / 128,
}
# Verify the owner's drop against the waveform, rather than guessing a timestamp.
drop_window = np.flatnonzero((np.arange(len(envelope)) * hop / rate >= 44.8) &
                            (np.arange(len(envelope)) * hop / rate < 45.3))
rise = np.diff(envelope)
drop_index = drop_window[np.argmax(rise[drop_window - 1])]
result["measured_drop_onset_seconds"] = float(drop_index * hop / rate)
def beat_rms(beat):
    start = int((.03 + beat * 60 / 128) * rate)
    segment = samples[start:start + int(.25 * rate)]
    return float(np.sqrt(np.mean(segment ** 2)))
result["pre_drop_rms"] = (beat_rms(94) + beat_rms(95)) / 2
result["drop_rms"] = beat_rms(96)
assert abs(result["measured_drop_onset_seconds"] - result["logo_seconds"]) < .05
Path("assets/video/opening/music-cues.json").write_text(json.dumps(result, indent=2) + "\n")

# A downward bass impulse plus a brief wooden crack; deterministic, no clipping.
sr = 44100
t = np.arange(int(sr * 1.15)) / sr
rng = np.random.default_rng(128)
phase = 2 * np.pi * (40 * t + 100 * .045 * (1 - np.exp(-t / .045)))
low = np.sin(phase) * np.exp(-t * 7)
crack = rng.uniform(-1, 1, len(t)) * np.exp(-t * 55)
wood = np.sin(2 * np.pi * 165 * t) * np.exp(-t * 18)
signal = (low * .70 + crack * .25 + wood * .20) * np.minimum(t / .0015, 1)
signal = signal / max(1, np.max(np.abs(signal))) * .9
with wave.open("audio/sfx/opening_thud.wav", "wb") as out:
    out.setnchannels(1)
    out.setsampwidth(2)
    out.setframerate(sr)
    out.writeframes((signal * 32767).astype("<i2").tobytes())
print(json.dumps(result, indent=2))
