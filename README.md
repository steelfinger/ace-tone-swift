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

## Deployment (Xcode Cloud)

Builds run on [Xcode Cloud](https://developer.apple.com/xcode-cloud/). In the repo, [`ci_scripts/ci_post_clone.sh`](ci_scripts/ci_post_clone.sh) installs XcodeGen, generates the project and stamps `CI_BUILD_NUMBER` into `CURRENT_PROJECT_VERSION` (App Store Connect rejects duplicate build numbers). The workflows live in Apple's UI, not in the repo.

### One-time setup

1. Make sure the app exists in [App Store Connect](https://appstoreconnect.apple.com) › Apps with bundle ID `fi.steelfinger.rhythmace`.
2. `xcodegen generate && open RhythmAce.xcodeproj`
3. Xcode › Product › Xcode Cloud › Create Workflow…
4. Pick the `RhythmAce` app, click **Grant Access** for GitHub and authorise `steelfinger/ace-tone-swift`.
5. Edit the workflow that opens:
   - **Name:** `Release`
   - **Start Conditions:** delete the default *Branch Changes*, add **Tag Changes** › tag name starts with `v`
   - **Actions:** delete the default, add **Archive** › Platform iOS, Scheme `RhythmAce`, Distribution *App Store Connect*
   - **Post-Actions:** add **TestFlight (Internal Testing)**, pick your internal group
6. Save. Then create a second workflow (Report navigator › Cloud tab › **+**): name `CI`, start on **Branch Changes** for `main`, action **Test** › scheme `RhythmAce`, an iPhone simulator.

### Each release

1. Bump `MARKETING_VERSION` in `project.yml`, commit, push.
2. `git tag v2.0.0 && git push origin v2.0.0`
3. Wait for the build in Xcode's Report navigator or App Store Connect › TestFlight, then run the checklist below.

## TestFlight checklist

Audio session behaviour can't be fully covered by unit tests. Before a release, check on a device:

- Music from another app keeps playing until START is pressed, and resumes after STOP
- Bluetooth headphones: connect, disconnect mid-play (playback stops, no blast from the speaker)
- Wired headphones: unplug mid-play (playback stops)
- Phone call / Siri interruption while playing: START releases, resumes only if the system says so
- Silent switch: audio still plays
- App switch and lock screen while playing: the beat continues (`UIBackgroundModes: audio`)
- STOP, then background the app: nothing keeps running, other apps' audio is unaffected
- Low Power Mode and an older device: no dropouts at 240 BPM with all voices active
- Larger Text (Settings › Accessibility): the plain layout appears from XXL up

## Pattern accuracy

The 16 preset grids are transcribed by ear from FR-1 demos. The original pattern ROM was never published — treat them as a starting point and refine against reference recordings.
