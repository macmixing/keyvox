<p align="center">
  <img src="Resources/logo.png" width="128" alt="KeyVox Logo">
</p>

<h1 align="center">KeyVox</h1>

KeyVox is a local-first macOS dictation app. Hold your trigger key to record, release to transcribe with Whisper on-device, and insert text into the app you are currently using. Your custom dictionary, key dictation style settings, and weekly word total can also stay in sync across your devices with iCloud.

## Why KeyVox

- 🚀 Fast local transcription (no cloud transcription path)
- 🌍 Uses the Whisper multilingual base model (`ggml-base`)
- 🔒 Privacy-first workflow with on-device inference
- ⌨️ Global trigger-key dictation from anywhere on macOS
- 🧠 Smart post-processing for custom words, lists, and time formatting
- ☁️ iCloud sync for your custom dictionary and core dictation preferences
- 📊 See your weekly spoken-word total across devices
- 🪄 Reliable insertion flow with Accessibility-first + fallback paths

## Core Features

- 🎙️ Hold-to-talk dictation with optional hands-free mode
- 🧾 Custom dictionary with phonetic-aware matching and iCloud sync
- ⚙️ Configurable trigger binding (Option, Command, Control, or Fn), synced across devices
- 📓 Optional auto-paragraph splitting with Lists preferences with sync
- 🧱 Deterministic list formatting and safe text post-processing
- 📈 Weekly word count that reflects how much you talk across all devices
- 📍 Draggable recording overlay with persisted position
- 🔊 Optional system cue sounds with adjustable volume
- ⚠️ Recovery and warning overlays for insertion/audio edge cases

https://github.com/user-attachments/assets/0666c33f-eeb9-4058-8923-bd88ed04febc
## Quick Start

### Requirements

- macOS Ventura (13.5) or later
- Apple Silicon recommended (Intel supported)
- ~190 MB disk space for the base model

### Install and Run

### Recommended (Release DMG)

1. Download the `.dmg` from the [latest release](https://github.com/macmixing/keyvox/releases/latest).
2. Open the DMG and drag `KeyVox.app` to `Applications`.
3. Launch KeyVox and complete onboarding (Microphone, Accessibility, model setup).

### Build From Source (Optional)

1. Clone the repo:
   `git clone https://github.com/macmixing/keyvox.git`
2. Open:
   `KeyVox.xcodeproj`
3. Build and run in Xcode.
4. Complete onboarding:
   Microphone permission, Accessibility permission, and model setup.

## How to Use

1. Configure your trigger key in Settings (default is **Right Option ⌥**).
2. Hold trigger, speak, release to transcribe and insert.
3. Hold **Shift** while releasing to continue recording hands-free.
4. Press **Esc** to cancel an active recording/transcription session.
5. Automatic **Paragraphs** and **Lists** can be configured in Settings. (Enabled by default)
6. Your **Dictionary**, **Trigger Key**, **Paragraphs**, and **Lists** preferences can sync through iCloud, and Settings also shows your weekly total across devices.

## Troubleshooting

- ❌ No text inserted:
  Verify Accessibility permission in macOS System Settings.
- 🎤 No input audio:
  Verify microphone permission and selected input in Settings.
- 📦 Model missing:
  Open Settings and re-run model setup/download.

## Documentation

- 📘 Engineering details: [`Docs/ENGINEERING.md`](Docs/ENGINEERING.md)
- 🗺️ File/component map: [`Docs/CODEMAP.md`](Docs/CODEMAP.md)
- 📜 License terms: [`LICENSE.md`](LICENSE.md)
- 📄 Trademark policy: [`TRADEMARK.md`](TRADEMARK.md)
- 📎 Third-party notices: [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md)

## License

KeyVox uses a dual-license model:

- Source code is MIT-licensed.
- Branding and specified visual assets remain proprietary.
- Bundled third-party components/data/fonts remain under their original licenses.
