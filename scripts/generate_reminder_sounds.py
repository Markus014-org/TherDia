#!/usr/bin/env python3
"""Create two short PCM WAV reminder sounds for TherDia's iOS bundle."""
from pathlib import Path
import math
import struct
import wave

OUT = Path(__file__).resolve().parents[1] / "TherDia" / "Resources"
OUT.mkdir(parents=True, exist_ok=True)
RATE = 22050

def write(name, profile):
    samples = []
    for i in range(int(1.6 * RATE)):
        t = i / RATE
        attack = min(1.0, t / 0.025)
        fade = max(0.0, (1.6 - t) / 0.35)
        envelope = min(attack, fade)
        signal = profile(t)
        amplitude = int(max(-1, min(1, signal * envelope)) * 10500)
        samples.append(struct.pack("<h", amplitude))
    path = OUT / name
    with wave.open(str(path), "wb") as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(RATE)
        output.writeframes(b"".join(samples))
    print("Generated", path)

# Warm, two-tone chime; separated notes with a soft fade.
write("TherDiaGentle.wav",
      lambda t: (0.60 * math.sin(2 * math.pi * 523.25 * t) +
                 0.24 * math.sin(2 * math.pi * 659.25 * t)) *
                 (0.70 if t < 0.65 else 0.48))
# Brighter notification bell.
write("TherDiaBell.wav",
      lambda t: (0.54 * math.sin(2 * math.pi * 880 * t) +
                 0.23 * math.sin(2 * math.pi * 1320 * t) +
                 0.11 * math.sin(2 * math.pi * 1760 * t)) *
                 math.exp(-0.85 * t))
