# Rhythm Ace (native Swift) — Claude Guidelines

Native SwiftUI port of the Ace Tone FR-1 simulator (RN/Expo original lives in `../ace-tone-sim`). All sounds are synthesized in Swift — no samples, no third-party dependencies.

## Stack

- iOS 18+, Swift 6, SwiftUI, `@Observable`
- AVAudioEngine + AVAudioSourceNode (custom DSP)
- `Synchronization.Atomic` for UI ↔ audio-thread communication
- XcodeGen (`project.yml`) — `RhythmAce.xcodeproj` is generated and gitignored

## Architecture

```
RhythmAce/
  App/RhythmAceApp.swift     entry point, owns the Sequencer
  Audio/
    Voices.swift             VoiceID, LayerSpec table (the 8 voices), Biquad, LayerVoice DSP
    SynthCore.swift          render-thread sequencer clock + voice mixer
    SharedControl.swift      atomics: bpm, volume, running, mutes, packed pattern, lamp
    AudioEngine.swift        AVAudioEngine/session setup, rebuild on route change/interruption
  Patterns/Patterns.swift    16 presets as UInt16 bitmasks + CombinedPattern (OR-combine)
  State/Sequencer.swift      @Observable UI state; pushes every change into SharedControl
  UI/                        PanelView, KnobView, Buttons, PowerIndicator, Fonts
```

## Key design decisions

- **Sequencer runs inside the render callback** — steps fire on the exact sample. No lookahead scheduler, no timers.
- **Render thread rules** — no allocation, locks, ObjC or MainActor calls in `SynthCore.render`. The render block is built in a `nonisolated static` func so Swift 6 doesn't infer MainActor isolation (which would crash on the audio thread).
- **Voices are data** — each voice is one or two `LayerSpec`s (source, pitch sweep, biquad, envelope) mirroring the RN Web Audio graphs. Tweak sound there.
- **Web Audio parity** — exponential envelopes 0.0001→peak in 2 ms →0.0001 at `decay`; HP filter Q = 1 dB; bandpass is constant-0 dB-peak; each noise hit reads the shared 2 s noise table from the start; 8-voice polyphony per layer so tails overlap.
- **Cancel buttons** hard-mute the voice (tails included), like the RN bus gain.
- **Power lamp** — render thread sets `lampLit` for 80 ms on each quarter note; `PowerIndicator` polls it via `TimelineView(.animation)` only while running.

## Dev workflow

```bash
xcodegen generate
open RhythmAce.xcodeproj
```

Re-run `xcodegen generate` after adding/removing files.

## Layout verification

`scripts/screenshots.sh [device names…]` builds once, screenshots the app on several simulator sizes and writes `screenshots/contact-sheet.png` (gitignored). Set `REF_APP=path/to/RN.app` to also shoot the RN build on each device, next to ours. The RN app is the layout reference: `PanelView` reproduces its percentage-based Yoga layout, including the quirks documented in `GridMetrics`.
