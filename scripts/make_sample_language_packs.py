#!/usr/bin/env python3
"""Generate two synthetic sample soundpacks (Arabic / English) plus switch sounds.

Purpose: let you hear the language-aware behaviour immediately, and show the on-disk format.
They are deliberately different (deep "thock" vs. bright "click") so the language is obvious by ear.
Replace them with real recordings for actual use (see README, "Adding sounds").

    python3 scripts/make_sample_language_packs.py [output_dir]

Default output_dir: ~/Library/Application Support/Thock/Soundpacks
"""
import json, math, os, random, struct, sys, uuid, wave

RATE = 44100


def write_wav(path, samples):
    with wave.open(path, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(RATE)
        frames = bytearray()
        for s in samples:
            v = int(max(-1.0, min(1.0, s)) * 32767)
            frames += struct.pack("<hh", v, v)
        w.writeframes(bytes(frames))


def click(freq, decay, length=0.12, noise=0.25, seed=0):
    rnd = random.Random(seed)
    n = int(RATE * length)
    out = []
    for i in range(n):
        t = i / RATE
        env = math.exp(-t * decay)
        tone = math.sin(2 * math.pi * freq * t)
        out.append(env * (tone * (1 - noise) + rnd.uniform(-1, 1) * noise) * 0.8)
    return out


def chirp(f0, f1, length=0.18):
    n = int(RATE * length)
    out = []
    for i in range(n):
        t = i / RATE
        f = f0 + (f1 - f0) * (i / n)
        out.append(math.sin(2 * math.pi * f * t) * math.exp(-t * 12) * 0.6)
    return out


def make_pack(root, name, key, base, switch):
    folder = os.path.join(root, name.lower().replace(" ", "-"))
    os.makedirs(folder, exist_ok=True)
    prefix = name.split()[-1].lower()
    sounds = {}

    def group(label, freq, decay, count, up=False):
        files = []
        for i in range(count):
            fn = f"{prefix}-{label}-{i + 1:02d}.wav"
            write_wav(os.path.join(folder, fn), click(freq * (1 + 0.04 * i), decay, seed=i * 7 + len(label)))
            files.append(fn)
        return files

    sounds["default"] = {"down": group("key", base, 45, 3), "up": []}
    sounds["space"] = {"down": group("space", base * 0.6, 30, 1), "up": []}
    sounds["enter"] = {"down": group("enter", base * 0.75, 35, 1), "up": []}
    sounds["del"] = {"down": group("backspace", base * 0.85, 40, 1), "up": []}

    config = {
        "id": str(uuid.uuid5(uuid.NAMESPACE_URL, "langthock-sample-" + prefix)),
        "metadata": {"name": name, "brand": "LangThock Samples", "author": "LangThock",
                     "category": "keyboard", "supportsKeyUp": False},
        "license": {"type": "CC0", "url": "https://creativecommons.org/publicdomain/zero/1.0/"},
        "sounds": sounds,
    }
    with open(os.path.join(folder, "config.json"), "w") as f:
        json.dump(config, f, indent=2)
    write_wav(os.path.join(folder, f"{prefix}-switch.wav"), chirp(*switch))
    return folder


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.expanduser("~/Library/Application Support/Thock/Soundpacks")
    os.makedirs(out, exist_ok=True)
    for path in (make_pack(out, "Sample Arabic", "ar", 170, (300, 520)),
                 make_pack(out, "Sample English", "en", 900, (520, 300))):
        print("wrote", path)
