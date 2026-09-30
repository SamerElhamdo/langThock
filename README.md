# LangThock

LangThock is a fork of [Thock](https://github.com/kamillobinski/thock) (MIT) — a native macOS utility that plays
mechanical-keyboard sounds — with one new core feature:

> **The keyboard sound changes automatically with the current macOS Input Source, so you can tell the keyboard
> language by ear.** Type in Arabic → Arabic sounds. Type in English → English sounds.

Everything else is Thock: the low-latency `AudioQueue` engine, preloaded PCM buffers, soundpacks, per-key sounds,
pitch variation, menu-bar UI. LangThock extends it; it does not replace it. See `LICENSE` (Thock's MIT license is kept).

## The problem it solves

You type Arabic, press the language shortcut, and keep typing immediately. macOS sometimes takes a moment to
switch, and you only notice from the wrong characters. With LangThock each language *sounds* different, and the
sound follows the Input Source **before** the very next key press is voiced.

## How it works

```text
macOS Input Source
        │
        ▼
InputSourceMonitor          (TIS: TISCopyCurrentKeyboardInputSource +
        │                    kTISNotifySelectedKeyboardInputSourceChanged — no polling)
        ▼
SoundProfileResolver        (Input Source ID → Sound Profile, editable mapping)
        │
        ▼
Current Sound Profile       (SoundProfileManager, in-memory)
        │
        ▼
CGEvent Keyboard Monitor    (KeyboardEventTracker, unchanged tap)
        │
        ▼
Low-Latency Audio Engine    (SoundManager / AudioQueue, preloaded buffers)
        │
        ▼
Keyboard Sound
```

### Input Source detection
* The **Input Source**, not the typed character, decides the language: `com.apple.keylayout.Arabic`,
  `com.apple.keylayout.ABC`, `com.apple.keylayout.US`, …
* Detection is event-driven: macOS posts `kTISNotifySelectedKeyboardInputSourceChanged` and LangThock re-reads the source with TIS.
* **No delay / race handling:** on the first press of every key, the event tap (main thread, where TIS is allowed)
  re-reads the current Input Source *before* choosing the sound. If you switch and type instantly and the system
  notification has not arrived yet, that key press still gets the correct profile. No sleep, no debounce. The
  check is skipped entirely when no profile has its own soundpack and switch sounds are off.

### Mapping
Resolution order: exact Input Source ID → primary language of the source (`ar`, `en`, …) → *Default* profile.
Defaults: `Arabic`, `Arabic-QWERTY`, `ArabicPC` → **Arabic**; `ABC`, `US`, `USExtended` → **English**; anything else → **Default**.
Change it in **Settings → Languages → Input Sources** (lists the sources enabled on your Mac).
The mapping lives in `UserDefaults` (`languageSoundConfiguration`, JSON) — never hard-coded in the key path.

### Sound Profiles
A profile = a name + one installed **keyboard soundpack** (or "current keyboard soundpack"). This reuses Thock's
soundpack format, so per-key sounds, several random variations per key, and key-up sounds all work.
Built-in profiles: **Default**, **Arabic**, **English**; you can create **Custom** ones. Each profile has
▶ Preview buttons (Key / Space / Enter / Backspace) that use the same audio engine.

### Language switch sound
Settings → Languages → Language Switch: ☑ *Play sound when input source changes*, plus a sound file and a shared
volume. It plays the sound of the profile you switch **to** (Arabic → English plays the English switch sound).
It is not played when both sources use the same profile (ABC → U.S.) and not at launch.

## Adding sounds

Soundpacks live in `~/Library/Application Support/Thock/Soundpacks/<pack-folder>/` (path kept from Thock).
Each folder has `config.json` and the audio files (`.wav`/`.mp3`):

```json
{
  "id": "PUT-A-UNIQUE-UUID-HERE",
  "metadata": { "name": "My Arabic", "brand": "Me", "author": "Me", "category": "keyboard", "supportsKeyUp": false },
  "license": { "type": "CC0", "url": "https://creativecommons.org/publicdomain/zero/1.0/" },
  "sounds": {
    "default": { "down": ["arabic-key-01.wav", "arabic-key-02.wav", "arabic-key-03.wav"], "up": [] },
    "space":   { "down": ["arabic-space.wav"],     "up": [] },
    "enter":   { "down": ["arabic-enter.wav"],     "up": [] },
    "del":     { "down": ["arabic-backspace.wav"], "up": [] }
  }
}
```

* One random file from the list is chosen per press. Keys without an entry fall back to `default`.
* Key names: letters/digits/symbols themselves, `space`, `enter`, `del`, `tab`, `esc`, `capsLock`, `command`,
  `shiftLeft`/`shiftRight`, `optionLeft`/`optionRight`, `ctrlLeft`, `fn`, `arrLeft`/`arrRight`/`arrUp`/`arrDown`,
  `home`, `end`, `pgUp`, `pgDn`, `f1`…`f12` (see `Thock/Helpers/KeyMapper.swift`).
* **Arabic sounds:** make/copy a pack as above (e.g. folder `my-arabic`), then Settings → Languages → Sound Profiles → *Arabic* → pick it.
* **English sounds:** same, pick it for the *English* profile.
* **Try it right now:** `python3 scripts/make_sample_language_packs.py` generates two synthetic packs
  (`Sample Arabic` deep thock, `Sample English` bright click) and switch sounds (`arabic-switch.wav`, `english-switch.wav`
  inside the pack folders). Then assign them to the Arabic/English profiles. Existing Mechvibes packs convert with `scripts/mechvibes2thock.py`.
* **Change mapping:** Settings → Languages → Input Sources → choose the profile per source.

## Permissions

* **Accessibility** — required. The keyboard monitor is a CGEvent tap that must be able to swallow keys (Cleaning Mode).
  On first launch LangThock shows an explanation and a button that opens *System Settings → Privacy & Security → Accessibility*.
* Nothing else: reading the Input Source needs no permission; no Input Monitoring, no notifications, no network.

## Privacy

Strictly local. Key events are used only to choose a sound: no text is stored, logged or transmitted; no key
logging, analytics, telemetry or cloud. There are **no network requests**: the upstream update check and online
soundpack downloads were removed. Install packs by copying folders.

## Performance

The key path is: key event → current profile (lock + copy) → preloaded PCM buffer → play. No disk I/O, JSON parsing,
logging or allocation beyond Thock's existing path while typing. Profile soundpacks and switch sounds are decoded at launch and
whenever profiles change, on a background queue. `AudioQueue`, buffer sizes and idle handling are untouched.
Tip: set `ENABLE_LATENCY_MEASUREMENT` in `LatencyMeasurement.swift` to measure end-to-end latency.

## Build & run

Requires macOS 13.5+ and Xcode 16+ (Swift 5, SwiftPM dependency: KeyboardShortcuts).

```sh
open Thock.xcodeproj                      # scheme "Thock", product LangThock.app
xcodebuild -project Thock.xcodeproj -scheme Thock -configuration Release build
xcodebuild -project Thock.xcodeproj -scheme Thock test        # unit tests (ThockTests)
```

The project still carries upstream's development team; select your own signing team in Xcode
(Signing & Capabilities). Run `LangThock.app`, grant Accessibility, open the menu-bar icon → Settings → Languages.

### Launch at login
Settings → General → *Launch at Login* (or menu → Quick Settings). Manually: System Settings → General → Login Items → `+` → LangThock.app.

## Menu bar

```text
LangThock  (toggle)          ← Keyboard Sounds on/off
Current Input Source:  ● Arabic
Current Sound Profile: ● Arabic
✓ Language Switch Sounds
Volume ──●──   Pitch …   Soundpacks …   Quick Settings   Settings…   Quit
```

## Credits & license
Based on Thock by Kamil Łobiński — MIT License (see `LICENSE`).
