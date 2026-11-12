# RemoteMic for Windows

This directory contains the Windows port of RemoteMic. It keeps the macOS
v1.5.0 information architecture and behavior while isolating platform-specific
BLE, HID and audio code from the shared protocol/state-machine layer.

This is a source-complete preview: automated protocol tests, Release builds and
self-contained packaging pass, but the real-remote and clean-machine matrix in
[docs/VERIFY-CHECKLIST.md](docs/VERIFY-CHECKLIST.md) has not yet been completed.

## Implemented in this preview

- WPF console matching the 1000 x 690 audio and button-mapping pages, including
  light/dark themes, Simplified Chinese/English resources and a tray menu.
- Google ATVV 0.4/1.0 over WinRT GATT, including capability negotiation,
  MIC_OPEN/MIC_CLOSE/keep-alive, AUDIO_SYNC and 8/16 kHz ADPCM decoding.
- Remote-first audio routing at 48 kHz stereo. While the remote is speaking,
  local microphone audio is muted; when it stops, local capture returns.
- Output to either a future `RemoteMic Input` render endpoint or an independently
  installed `CABLE Input (VB-Audio Virtual Cable)` endpoint.
- Chromecast REV 011b Consumer Control reports and REV 0110 direct reports.
- Single/double/long gesture state machine with the same 280 ms / 600 ms timing
  and zero-delay path as v1.5.0.
- Voice-session coordination for Chromecast tap/hold, X6 reason-zero startup,
  stale host responses, persistent stream reopen and independent dual-remote
  stop state.
- Keyboard/media/scroll/app-launch mapping actions, start-at-login, status
  diagnostics and the existing model-scoped default mappings.

## Windows driver boundary

Two capabilities require signed Windows drivers for production-grade parity:

1. A virtual capture endpoint named `RemoteMic 2ch` that accepts PCM from the
   app. The current preview can use separately installed VB-CABLE instead; the
   project does not bundle or redistribute VB-CABLE.
2. A VID/PID-scoped HID lower filter that can suppress the original Chromecast
   button report while mapping is enabled. The current Raw Input backend is an
   observation backend: mapped actions are emitted, but Windows may also process
   the original media/navigation action.

Unsigned kernel drivers are intentionally not shipped and users are never asked
to disable Secure Boot or enable test-signing. See [Driver/README.md](Driver/README.md).
The preview EXE and ZIP are also not Authenticode-signed, so Windows may show a
SmartScreen warning. A production release requires application code signing in
addition to the two signed drivers.

## Requirements

- Windows 10 2004 (build 19041) or newer. CI currently publishes x64 only;
  `package.ps1` can produce ARM64, but that package is not yet hardware-verified.
- A paired supported remote:
  - Chromecast Voice Remote `18D1:9450`
  - X6 Remote `1D5A:C081`
- For the preview audio route, install VB-CABLE yourself and select
  `CABLE Output` as the microphone in the target input method or meeting app.
- .NET 8 SDK to build. Packaged preview builds are self-contained.

## Build and test

From PowerShell at the repository root:

```powershell
./Windows/run-self-tests.ps1
./Windows/build.ps1
./Windows/package.ps1 -Runtime win-x64
```

The package is written to `Windows/artifacts/RemoteMic-Windows-win-x64.zip`.
Extract it and run `RemoteMic.Windows.exe`. The ZIP includes this README, the
project MIT license and the .NET runtime license/third-party notices.

## Preview limitations

- Until the signed HID filter exists, mapped Raw Input actions cannot suppress
  the original Windows action from the same remote report.
- The voice-session state machine currently acknowledges a successful
  `SendInput` trigger as the intended target-recording state. A production build
  still needs a WASAPI target-capture activity monitor to confirm that the input
  method or meeting app actually started/stopped recording.
- Built-in app-launch defaults work, but the full macOS fixed-text, arbitrary
  fixed-text and multi-step mapping editors are not yet ported. Arbitrary EXE
  selection is available for the app-launch action.

## Project layout

- `RemoteMic.Core`: ATVV/ADPCM, HID normalization, gestures, mappings, action
  sequence models and audio route policy. It is platform-independent.
- `RemoteMic.Core.Tests`: dependency-free executable self-test suite.
- `RemoteMic.Platform.Windows`: WinRT GATT, AudioGraph/WASAPI-facing routing,
  Raw Input and Win32 action execution.
- `RemoteMic.Windows`: WPF UI, localization, tray and runtime composition.
- `Driver`: production driver contracts and release requirements.

## Hardware verification

Automated tests cover pure protocol and state-machine behavior. A release still
requires the real-device matrix in [docs/VERIFY-CHECKLIST.md](docs/VERIFY-CHECKLIST.md).
