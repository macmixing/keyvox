# KeyVox 🎙️

**KeyVox** is a premium, high-performance macOS application that brings seamless, local voice-to-text transcription to your fingertips. Built with a focus on speed, privacy, and rich aesthetics, KeyVox allows you to dictate text into any application instantly using OpenAI's Whisper model—running entirely on your machine.

---

## ✨ Features

### 🚀 Performance & AI
- **Instant Trigger**: Hold a configurable modifier key (Option, Command, Control, or Fn) to record, release to transcribe.
- **Universal Acceleration**: Leverages **CoreML** (Neural Engine) on Apple Silicon and **Accelerate Framework** on Intel Macs for high-performance inference.
- **Model Pre-warming**: Eliminates "first-run" latency by keeping the model warm in memory.
- **Local & Private**: 100% on-device processing using `whisper.cpp`. No data is ever sent to the cloud.
- **Speed Profiling**: Built-in latency tracking for audio buffering, inference, and injection to ensure sub-second response times.

### 🎨 Premium User Experience
- **Interactive Visuals**: A beautiful, audio-reactive floating overlay with glassmorphism aesthetics and ripple animations.
- **Aesthetic Settings**: A minimalist settings dashboard featuring animated wave headers and interactive hover states.
- **Intelligent Audio Cues**: Low-latency Morse-code ("Morse") and Frog ("Frog") sound feedback for non-visual recording status.
- **Real-time Feedback**: Live audio level visualization with precise RMS-based reactive bars.

### ⌨️ Smart Text Injection
- **Accessibility First**: Uses the macOS Accessibility API for surgical text injection into native application fields.
- **Intelligent Fallback**: Automatic "Menu Bar Paste" simulation for web-based editors or restricted apps.
- **State Preservation**: Temporarily manages clipboard state to restore your original data after injection.
- **Verification Logic**: Uses range-movement detection to confirm successful text entry.

---

## 🛠️ Architecture

KeyVox follows a modular, service-oriented architecture designed for low-latency performance:

- **`TranscriptionManager`**: The central coordinator managing the state machine (IDLE → RECORDING → TRANSCRIBING).
- **`WhisperService`**: Manages the Whisper GGML/CoreML model lifecycle and inference threading (optimized for 4 P-core threads).
- **`AudioRecorder`**: Captures high-fidelity 16kHz mono audio directly into memory buffers (no temporary files).
- **`PasteService`**: A sophisticated injection engine that bridges native accessibility and UI-simulated fallbacks.
- **`KeyboardMonitor`**: A global event tap using `NSEvent.addGlobalMonitorForEvents` to catch triggers without stealing focus.
- **`ModelDownloader`**: Handles parallel downloads of GGML and CoreML model weights from HuggingFace.

---

## 🚀 Getting Started

### Prerequisites
- **macOS 15.0 or later** (Project deployment target)
- **Intel or Apple Silicon Mac**: Optimized for both architectures (Neural Engine used on M1/M2/M3).
- **Accessibility Permissions**: Required for both global key monitoring and text injection.

### Installation
1. Clone the repository:
   ```bash
   git clone https://github.com/macmixing/keyvox.git
   ```
2. Open `KeyVox.xcodeproj` in Xcode.
3. Build and Run the application.
4. On first launch, grant **Accessibility Permissions** through the prompted system dialog.
5. Open **Settings** from the menu bar status icon to download the **Base Whisper model and CoreML assets** (~142MB + CoreML weights).

---

## 📖 Usage

1. **Configure**: Open Settings to set your preferred **Trigger Key** (Default: Left Option).
2. **Start**: Press and hold your trigger key. The floating overlay will appear.
3. **Speak**: The bars will react to your voice. If you stop speaking, the overlay enters a subtle "transcribe ripple" mode.
4. **Release**: Let go of the key. KeyVox instantly transcribes and pastes the text at your cursor.

---

## 🔧 Troubleshooting

- **Text not pasting?** Check *System Settings > Privacy & Security > Accessibility*. KeyVox must be toggled ON.
- **Permissions Error?** Use the "Grant Permission..." button in the Menu Bar to re-trigger the system prompt.
- **Audio Issues?** Ensure your default system input is set to the correct microphone in System Settings.

---

## 📄 License

This project is licensed under the MIT License.

---

Developed with ❤️ for the macOS community.
