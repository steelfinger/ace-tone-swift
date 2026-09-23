# Rhythm Ace

A faithful simulator of the [Ace Tone FR-1](https://www.vintagesynth.com/misc/fr1.php) (1967), one of the earliest consumer drum machines. All sounds are synthesized in Swift — no samples, no third-party dependencies.

This is a native SwiftUI port of the original React Native / Expo app ([`ace-tone-sim`](../ace-tone-sim)), which this version is intended to **replace**. The panel layout, voices and presets are kept in parity with the RN app; the audio engine is rewritten as custom DSP on AVAudioEngine so the sequencer clock runs sample-accurately inside the render callback.

## Features

- **8 synthesized voices** — Bass Drum, Snare, Low Conga, High Conga, Cymbal, Claves, Cowbell, Maracas
- **16 factory presets** — Waltz, Dixieland, Western, Rock'n Roll, Slow Rock, Bosa Nova, Fox Trot, Swing, Tango, Beguine, Rhumba, Samba, Mambo, Cha-Cha, Sniffle, March
- **Pattern combining** — select multiple rhythm buttons to OR their patterns together, like the original diode matrix
- **Cancel buttons** — mute Bass, Cymbal, Claves or Cowbell mid-pattern
- **Tempo knob** — 40–240 BPM
- **Volume knob**
- **Downbeat lamp** — the power lamp pulses on every quarter note

## Requirements

- Xcode with the iOS 18 SDK
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

## Getting started

```bash
xcodegen generate
open RhythmAce.xcodeproj
```

`RhythmAce.xcodeproj` is generated from `project.yml` and gitignored. Re-run `xcodegen generate` after adding or removing files.

## Stack

- Swift 6, SwiftUI, `@Observable`
- `AVAudioEngine` + `AVAudioSourceNode` for custom DSP
- `Synchronization.Atomic` for UI ↔ audio-thread communication

## Project layout

```
RhythmAce/
  App/          entry point
  Audio/        voices (LayerSpec table + DSP), render-thread sequencer/mixer,
                atomic shared control, AVAudioEngine setup
  Patterns/     16 presets as UInt16 bitmasks, OR-combining
  State/        @Observable Sequencer — UI state pushed into the audio thread
  UI/           panel, knobs, buttons, power indicator, fonts
```

See [CLAUDE.md](CLAUDE.md) for the design decisions behind the audio engine (render-thread rules, Web Audio parity, voice definitions).

## Layout verification

The RN app is the layout reference. `scripts/screenshots.sh` builds once, screenshots the app on several simulator sizes and writes a contact sheet to `screenshots/contact-sheet.png`. Set `REF_APP=path/to/RN.app` to also capture the RN build next to this one.

```bash
scripts/screenshots.sh "iPhone 17 Pro" "iPhone SE (3rd generation)"
```

## Pattern accuracy

The 16 preset grids are transcribed by ear from FR-1 demos. The original pattern ROM was never published — treat them as a starting point and refine against reference recordings.
