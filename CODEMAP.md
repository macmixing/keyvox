# KeyVox Code Map

## Project Overview

KeyVox is a macOS voice-to-text application that provides real-time transcription using OpenAI's Whisper model. The app runs as a menu bar application and allows users to trigger voice recording by holding the Right Option key, then automatically transcribes and injects the text into the active application.

## Architecture

The application follows a modular architecture with clear separation of concerns:

- **Core Services**: Audio recording, transcription, and text injection
- **UI Components**: Menu bar interface, recording overlay, and settings
- **Utilities**: Model management, keyboard monitoring, and accessibility integration

## File Tree

```
KeyVox/
├── KeyVox.xcodeproj/          # Xcode project configuration
├── KeyVox/                    # Main application source
│   ├── KeyVoxApp.swift        # App entry point & menu bar setup
│   ├── ContentView.swift      # Placeholder main view (unused)
│   ├── TranscriptionManager.swift # Core transcription workflow
│   ├── AudioRecorder.swift    # Audio capture & processing
│   ├── WhisperService.swift   # AI transcription service
│   ├── ModelDownloader.swift  # Model download & management
│   ├── PasteService.swift     # Smart text injection
│   ├── KeyboardMonitor.swift  # Global key monitoring
│   ├── RecordingOverlay.swift # Visual feedback overlay
│   ├── SettingsView.swift     # Settings interface
│   └── Assets.xcassets/       # App assets & icons
└── ExploreAX.swift            # Accessibility debugging utility
```

## Core Components

### 1. Application Entry Point
**`KeyVoxApp.swift`** - Main app structure and menu bar interface
- Manages `TranscriptionManager` and `ModelDownloader` state objects
- Creates menu bar extra with status indicators
- Handles accessibility permission requests
- Manages settings window lifecycle

### 2. Transcription Workflow
**`TranscriptionManager.swift`** - Central coordinator for the transcription pipeline
- **States**: `idle`, `recording`, `transcribing`, `error`
- **Flow**: Keyboard trigger → Audio recording → Whisper transcription → Text injection
- **Performance**: Includes detailed speed profiling for optimization
- **Audio Feedback**: Plays start/stop sounds (Morse/Frog)

### 3. Audio Processing
**`AudioRecorder.swift`** - Real-time audio capture and processing
- **Format**: 16kHz mono float32 (Whisper optimal)
- **Real-time**: Live audio level visualization with RMS calculation
- **Conversion**: Automatic sample rate conversion from system input
- **Memory**: Direct-to-memory recording (no temporary files)

### 4. AI Transcription
**`WhisperService.swift`** - Whisper model integration
- **Model**: Base English model (ggml-base.en.bin)
- **Optimization**: Pre-warming to eliminate cold-start latency
- **Hardware**: CoreML acceleration support for Neural Engine
- **Threading**: 4 threads optimized for M-series P-cores

### 5. Model Management
**`ModelDownloader.swift`** - Model download and lifecycle management
- **Sources**: HuggingFace model repository
- **Parallel**: Downloads GGML and CoreML models simultaneously
- **Cleanup**: Automatic removal of outdated tiny models
- **Progress**: Real-time download progress tracking

### 6. Text Injection
**`PasteService.swift`** - Smart text injection with fallback strategies
- **Primary**: Surgical accessibility API injection
- **Fallback**: Menu bar paste simulation
- **Verification**: Range movement detection to confirm injection
- **Clipboard**: Temporary clipboard state preservation

### 7. Input Monitoring
**`KeyboardMonitor.swift`** - Global keyboard event monitoring
- **Trigger**: Right Option key (NX_DEVICERIGHTOPTIONKEYMASK)
- **Scope**: Both global and local event monitoring
- **State**: Published `isTriggerKeyPressed` for UI binding

### 8. Visual Feedback
**`RecordingOverlay.swift`** - Floating overlay with audio visualization
- **Animation**: Audio-reactive bars with ripple effects
- **States**: Recording vs transcribing visual modes
- **Position**: Bottom-center floating panel
- **Manager**: Singleton `OverlayManager` for lifecycle

### 9. Settings Interface
**`SettingsView.swift`** - Model management interface
- **Status**: Model download/ready indicators
- **Progress**: Download progress visualization
- **Controls**: Model download initiation
- **Window**: Modal settings window management

## Key Features

### Performance Optimizations
- **Model Pre-warming**: Eliminates cold-start latency
- **Direct Memory**: No temporary audio files
- **Hardware Acceleration**: CoreML Neural Engine support
- **Smart Threading**: Optimized for M-series architecture

### Smart Text Injection
- **Accessibility First**: Direct API injection for native apps
- **Fallback Strategy**: Menu bar simulation for web apps
- **Verification Logic**: Range movement detection
- **Clipboard Safety**: State preservation and restoration

### User Experience
- **Visual Feedback**: Real-time audio level visualization
- **Audio Cues**: Start/stop sound feedback
- **Status Indicators**: Menu bar status display
- **Permission Handling**: Accessibility permission guidance

## Dependencies

### External Libraries
- **SwiftWhisper**: Whisper model inference
- **Combine**: Reactive programming for state management
- **AVFoundation**: Audio processing and capture
- **ApplicationServices**: Accessibility API integration

### System Requirements
- **macOS**: Accessibility permissions required
- **Hardware**: Optimized for Apple Silicon (M-series)
- **Storage**: ~142MB for Whisper Base model
- **Memory**: Model loaded into RAM for performance

## Development Notes

### Debugging Tools
**`ExploreAX.swift`** - Accessibility API debugging utility
- Menu structure exploration
- Attribute inspection
- Application compatibility testing

### Performance Monitoring
The app includes detailed speed profiling:
- Audio capture timing
- Whisper inference latency
- Text injection speed
- End-to-end latency measurement

### Error Handling
- Graceful fallbacks for text injection
- Model download error recovery
- Audio engine failure handling
- Accessibility permission management

## Future Enhancements

### Potential Improvements
- **Multi-language**: Support for additional Whisper languages
- **Custom Models**: User-selectable model sizes
- **Hotkeys**: Configurable trigger keys
- **Voice Commands**: Custom command recognition
- **Cloud Models**: Optional cloud-based transcription

### Architecture Considerations
- **Plugin System**: Extensible transcription providers
- **Settings Persistence**: User preference storage
- **Telemetry**: Anonymous usage analytics
- **Updates**: Automatic model updates
