# VIR — Video Instant Replay

VIR (Video Instant Replay) is a hands-free, privacy-first iOS app that provides real-time delayed video feedback for sports coaching and self-analysis. It is specifically optimized for **archery** but broadly applicable to any activity requiring form analysis.

## Features

- **Continuous Delayed Stream**: Live camera feed is displayed with a configurable delay (1s-60s), allowing athletes to perform an action and then watch it without touching the device.
- **Key Point Marking**: Mark key moments during the session using the volume button or on-screen tap.
- **Auto-Clipping**: Automatically generates video clips based on key points.
- **Archery Target Scoring**: Score archery rounds with interactive target faces and link clips to specific arrow hits.
- **Analysis Tools**: 
  - Freehand drawing annotations
  - Angle measurement tool
  - Slow-motion playback (0.25x to 2x)
  - Frame-by-frame stepping
- **Session History**: Save, review, and manage past sessions with SwiftData persistence.
- **Export**: Export clips to the Photo Library with scores and metadata.

## Requirements

- iOS 26.0+
- Swift 5.9+

## Architecture

VIR is built using **SwiftUI**, **AVFoundation**, and **SwiftData** following an **MVVM** architecture.

Key Modules:
- **Camera**: Handles video capture, compressed frame buffers (`CompressedFrameBuffer`), and delayed playback.
- **Replay**: Provides sophisticated video playback with speed control and scrubbing.
- **Analysis**: Includes drawing tools and angle measurements implemented using `PencilKit` and custom SwiftUI overlays.
- **Scoring**: Archery-specific logic for placing hits on structured targets.
- **SessionHistory**: Persistence layer managing `SwiftData` records and video file storage on disk (`SessionManager`).

For more comprehensive architectural and design details, see [SPEC.md](SPEC.md).

## Privacy

VIR is a **privacy-first** application. All video processing, buffer management, and clip file storage are performed entirely on-device. No registration is required, and videos/data never leave your device unless explicitly exported by the user.

## License

This project is for personal use. All rights reserved.
