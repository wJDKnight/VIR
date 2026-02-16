# VIR — Video Instant Replay

## App Specification Document

**Version:** 1.0  
**Date:** 2026-02-12  
**Platform:** iOS (iPhone & iPad)  
**Minimum iOS Version:** 26.0  
**Language:** Swift  
**UI Framework:** SwiftUI + AVFoundation  
**Distribution:** Personal use (Xcode direct install / TestFlight)  
**Third-Party SDKs:** Allowed  

---

## 1. Product Overview

### 1.1 Vision
VIR (Video Instant Replay) is a hands-free, privacy-first iOS app that provides real-time delayed video feedback for sports coaching and self-analysis. It is specifically optimized for **archery** but broadly applicable to any activity requiring form analysis (sports rehabilitation, dance, physical education, etc.).

### 1.2 Value Proposition
- **Pro-grade features** trusted by major league teams
- **Instant visual feedback** — no stopping to review videos
- **Privacy-first** — videos never leave the device; no registration, no cloud uploads

### 1.3 Target Users

| Persona              | Use Case                                         |
| -------------------- | ------------------------------------------------ |
| Youth Sports Coaches | Visual feedback for teaching proper form         |
| PE Teachers          | Student self-assessment in class                 |
| Solo Athletes        | Technique analysis during individual training    |
| Physical Therapists  | Rebuilding proper movement patterns post-injury  |
| Performers           | Refining acting, dancing, or presentation skills |
| Archers (Primary)    | Shot cycle review with scoring integration       |

---

## 2. Core User Flow

```
┌──────────────────────────────────────────────────────────┐
│  1. SETUP                                                │
│     • Open app → Camera preview appears                  │
│     • Set buffer delay (e.g., 5 seconds)                 │
│     • Tap "Start" to begin delayed replay loop           │
│                                                          │
│  2. PERFORM                                              │
│     • Athlete performs action (e.g., shoots arrow)        │
│     • Live camera feed is buffered in RAM                 │
│                                                          │
│  3. REPLAY                                               │
│     • After the delay, playback appears on screen         │
│     • Athlete sees their own performance played back      │
│                                                          │
│  4. MARK (Optional)                                      │
│     • Double-tap screen OR press Volume Down              │
│     • Marks a key point in the video for later clipping   │
│                                                          │
│  5. ADJUST & REPEAT                                      │
│     • Athlete adjusts form based on what they saw         │
│     • Continuous loop — no manual intervention needed     │
│                                                          │
│  6. STOP & REVIEW                                        │
│     • Stop recording → video auto-clips at key marks      │
│     • Archery target popup → mark arrow hit locations     │
│     • Score the round; link clips to target hits          │
│     • Replay clips in slow-motion / frame-by-frame       │
└──────────────────────────────────────────────────────────┘
```

---

## 3. Feature Specification

### 3.1 Delay Mode (Primary Mode)

| Feature                    | Detail                                                                           |
| -------------------------- | -------------------------------------------------------------------------------- |
| Continuous Delayed Stream  | Live camera feed is displayed with a configurable delay                          |
| Configurable Delay         | User sets the delay duration (default: 5s, range: 1s–60s)                        |
| Buffer Capacity            | Up to 20 minutes @ 60 fps (device RAM dependent)                                 |
| Video Quality              | Up to 2K (1080p default; options: 480p, 720p, 1080p, custom)                     |
| Frame Rate                 | 30 fps or 60 fps (user selectable)                                               |
| Split Screen / Versus Mode | Side-by-side comparison of live feed vs. delayed replay, or two saved clips      |
| Quick Save                 | Save the current buffer content to device storage with one tap                   |
| Dynamic Buffer             | Automatically adjusts buffer size based on available RAM and selected resolution |
| Audio Toggle               | Disable audio capture so users can listen to music/podcasts from other apps      |



#### 3.1.2 Key Point Marking
- **Trigger Methods:**
  - Double-tap anywhere on screen
  - Press the hardware Volume Down button
- **Behavior:**
  - Inserts a timestamp marker into the buffer timeline
  - Visual + haptic feedback on mark
  - Markers are used to auto-clip the video upon stopping the session

### 3.2 Replay View

| Feature              | Detail                                                               |
| -------------------- | -------------------------------------------------------------------- |
| Frame-by-Frame       | Step forward/backward one frame at a time via swipe or buttons       |
| Slow-Motion Playback | Adjustable speed: 0.25x, 0.5x, 0.75x, 1x, 2x                         |
| Scrubber             | Timeline scrubber with frame-accurate seeking                        |
| Clip Navigation      | Jump between auto-clipped segments via markers                       |
| Annotations          | Draw, add text, or add arrows on freeze-frame                        |
| Trim & Export        | Trim clips and export to Camera Roll or share via system share sheet |

### 3.3 Analysis Tools

| Tool                  | Description                                                             |
| --------------------- | ----------------------------------------------------------------------- |
| On-Screen Drawing     | Freehand drawing overlay on video frame (color, thickness options)      |
| Angle Measurement     | Two-line goniometer tool — tap three points to measure joint/bow angles |
| Stopwatch             | Overlay timer to measure phase durations within a clip                  |
| Motion Detection Grid | Visual grid overlay that highlights areas of motion                     |
| Horizontal Flip       | Mirror the video view (useful for coaching perspective)                 |
| Rotation              | Rotate the video 90°/180°/270°                                          |
| Frame-by-Frame        | (Also available in Replay View)                                         |

### 3.4 Archery-Specific Features

#### 3.4.1 Target Scoring
- coinfiguration: target type (WA 122cm, 80cm, 40cm; Vegas 3-Spot, etc.) and arrow size (diameter of the arrow: 3.1mm to 9.9mm ), this is set in the settings
- **Trigger:** Automatically presented after stopping a recording session. this can be skipped
- **Target Face Popup:**
  - preset archery target face displayed 
  - a black circle (indicating the arrow hit position) with a radius of the arrow size is displayed on the center of the target face
  - User can move the black circle on the target face to mark where each arrow hit the target
  - based on the circle position, the app will calculate the score
  - after one circle is moved and placed, a new circle is displayed.
  - the number of total circles is the number of clips in the session

- **Scoring:**
  - Per-arrow score (X, 10, 9, … M)
  - Round total 
  - Score history saved locally

#### 3.4.2 Clip-to-Hit Linking
- Each marked key point (clip segment) can be linked to a specific arrow hit on the target based on the order of the clips and the order of the marked hits on the target face
- each clip is linked to one arrow hit
- each clip will have the metadata of the arrow hit, including the score, the position of the arrow hit on the target face.
- Enables reviewing the shot cycle (the clip) for a specific arrow hit
- Summary view: target face with arrows + linked clip thumbnails

---

## 4. Screens & Navigation

### 4.1 Screen Map

```
App Launch
├── Main Camera Screen (Delay Mode)
│   ├── Settings Overlay (buffer, resolution, fps, delay duration)
│   ├── Split Screen / Versus Mode
│   └── Stop → Post-Session Flow
│       ├── Auto-Clip Review List
│       ├── Target Scoring Screen
│       │   └── Clip-to-Hit Linking
│       └── Replay View
│           ├── Playback Controls
│           ├── Analysis Tools Panel
│           ├── Annotation Editor
│           └── Trim & Export
├── Session History (optional, local only)
│   ├── Past Sessions List
│   └── Session Detail (scores, clips, notes)
└── Settings Screen
    ├── Video Quality
    ├── Frame Rate
    ├── Default Delay
    ├── Audio Toggle
    ├── Target Face Selection
    └── About / Privacy Policy
```

### 4.2 Screen Descriptions

#### 4.2.1 Main Camera Screen
- Full-screen camera preview showing the **delayed** feed
- Minimal HUD overlay:
  - Current delay value (top-left)
  - Buffer remaining (top-right, progress bar)
  - Record indicator (red dot, top-center)
  - Mark button (bottom-center, also triggered by double-tap / volume down)
  - Settings gear icon (top-right corner)
  - Stop button (bottom-right)
- Landscape and portrait orientations supported

#### 4.2.2 Settings Overlay
- Slide-up sheet or sidebar:
  - Buffer delay slider (1s – 60s)
  - Resolution picker (480p / 720p / 1080p / custom)
  - Frame rate toggle (30 / 60 fps)
  - Audio capture toggle (on/off)
  - Camera selection (front / rear)
  - Dynamic buffer info display ("~12 min available at current settings")

#### 4.2.3 Post-Session: Auto-Clip Review
- List of auto-generated clips (split at key point markers)
- Thumbnail + timestamp for each clip
- Tap to open in Replay View
- Multi-select for batch export or delete

#### 4.2.4 Target Scoring Screen
- Full-screen target face
- Tap to place arrow markers
- Undo last placement
- Score readout per arrow and total
- "Link to Clip" button for each arrow
- Save & Done

#### 4.2.5 Replay View
- Video player with scrubber
- Playback speed control
- Frame step buttons (◄ frame | frame ►)
- Toolbar for Analysis Tools (drawing, angle, stopwatch, grid, flip, rotate)
- Share / Export button

#### 4.2.6 Session History
- List of past sessions with date, score summary, clip count
- Tap to view session detail: target + linked clips
- Delete sessions individually or in bulk

---

## 5. Technical Architecture

### 5.1 Tech Stack

| Layer                 | Technology                                                          |
| --------------------- | ------------------------------------------------------------------- |
| Language              | Swift 5.9+                                                          |
| UI Framework          | SwiftUI (primary), UIKit (camera integration)                       |
| Camera & Video        | AVFoundation (`AVCaptureSession`, `AVAssetWriter`)                  |
| Buffer Management     | Custom circular buffer backed by `CVPixelBuffer` ring in RAM        |
| Video Playback        | AVPlayer / AVPlayerViewController                                   |
| Drawing / Annotations | Core Graphics / PencilKit                                           |
| Angle Measurement     | Core Graphics + custom geometry                                     |
| Local Storage         | SwiftData (session metadata, scores) + FileManager (exported clips) |
| Hardware Events       | MediaPlayer framework (Volume button interception)                  |
| Haptics               | Core Haptics                                                        |

### 5.2 Architecture Pattern
- **MVVM** (Model-View-ViewModel) with SwiftUI
- Feature-based module organization:

```
VIR/
├── App/
│   ├── VIRApp.swift
│   └── AppState.swift
├── Features/
│   ├── Camera/
│   │   ├── CameraManager.swift           # AVCaptureSession setup & control
│   │   ├── CircularFrameBuffer.swift      # RAM ring buffer for delayed playback
│   │   ├── DelayedPlaybackView.swift      # SwiftUI view rendering delayed feed
│   │   ├── CameraViewModel.swift
│   │   └── CameraSettingsView.swift
│   ├── Marking/
│   │   ├── KeyPointMarker.swift           # Timestamp marking logic
│   │   ├── VolumeButtonHandler.swift      # Hardware volume button listener
│   │   └── MarkingFeedbackView.swift      # Visual + haptic feedback
│   ├── Replay/
│   │   ├── ReplayPlayerView.swift
│   │   ├── ReplayViewModel.swift
│   │   ├── PlaybackSpeedControl.swift
│   │   └── FrameStepperView.swift
│   ├── Analysis/
│   │   ├── DrawingOverlayView.swift
│   │   ├── AngleMeasurementTool.swift
│   │   ├── StopwatchOverlay.swift
│   │   ├── MotionDetectionGrid.swift
│   │   └── VideoTransformTools.swift      # Flip, rotate
│   ├── Scoring/
│   │   ├── TargetFaceView.swift           # Archery target rendering
│   │   ├── ArrowPlacementView.swift
│   │   ├── ScoringEngine.swift
│   │   ├── ClipToHitLinker.swift
│   │   └── ScoreboardView.swift
│   ├── ClipManagement/
│   │   ├── AutoClipper.swift              # Splits buffer at key point markers
│   │   ├── ClipListView.swift
│   │   ├── TrimView.swift
│   │   └── ExportManager.swift
│   └── SessionHistory/
│       ├── SessionListView.swift
│       ├── SessionDetailView.swift
│       └── SessionStore.swift             # SwiftData persistence
├── Models/
│   ├── Session.swift
│   ├── Clip.swift
│   ├── KeyPoint.swift
│   ├── ArrowHit.swift
│   └── AppSettings.swift
├── Shared/
│   ├── Extensions/
│   ├── Components/                        # Reusable UI components
│   └── Constants.swift
└── Resources/
    ├── Assets.xcassets
    └── TargetFaces/                       # Target face images
```

### 5.3 Circular Frame Buffer Design

The core of the delay mode is a **circular (ring) buffer** that holds video frames in RAM.

```
┌───────────────────────────────────────────────┐
│            Circular Frame Buffer              │
│                                               │
│   Write Head ──►  [Frame N]                   │
│                   [Frame N+1]                 │
│                   [Frame N+2]                 │
│                      ...                      │
│   Read Head  ──►  [Frame N - delay_frames]    │
│                                               │
│   delay_frames = delay_seconds × fps          │
│   e.g., 5s delay @ 60fps = 300 frames         │
│                                               │
│   Max buffer = available_RAM / frame_size      │
│   Frame size ≈ width × height × 4 bytes (BGRA)│
└───────────────────────────────────────────────┘
```

**Key Implementation Notes:**
- Use `CVPixelBuffer` for zero-copy GPU rendering
- Frames are rendered to a `CADisplayLink`-driven Metal view for low-latency display
- Write head always leads read head by exactly `delay_frames`
- When buffer wraps, oldest frames are overwritten (unless marked)

### 5.4 Memory Management Strategy

| Resolution        | Frame Size (BGRA) | 60fps Buffer (1 min) | 60fps Buffer (20 min) |
| ----------------- | ----------------- | -------------------- | --------------------- |
| 480p (640×480)    | ~1.2 MB           | ~4.3 GB              | ~86 GB                |
| 720p (1280×720)   | ~3.7 MB           | ~13.3 GB             | ~266 GB               |
| 1080p (1920×1080) | ~8.3 MB           | ~29.9 GB             | ~598 GB               |

> **Note:** Raw BGRA frames are not practical for long buffers at high resolution. The actual implementation must use **compressed frame storage**:

- **Approach:** Hardware-accelerated H.264/HEVC encoding via `VideoToolbox`
  - Compress each frame (or GOP) in real-time
  - Store compressed data in the ring buffer
  - Decode on-the-fly at the read head
  - Compressed frame size: ~5–50 KB per frame (vs. 1–8 MB raw)
  - 20 min @ 60fps @ 1080p ≈ **3.6–36 GB** compressed → feasible on devices with 6–8 GB RAM

- **Dynamic Buffer Calculation:**
  ```
  available_memory = os_proc_available_memory()
  safety_margin = 0.7  // use 70% of available
  usable_memory = available_memory * safety_margin
  avg_compressed_frame_size = estimate_from_sample_frames()
  max_frames = usable_memory / avg_compressed_frame_size
  max_duration = max_frames / fps
  ```

---

## 6. Hardware Integration

### 6.1 Volume Button as Marker
- Use `AVAudioSession` and `MPVolumeView` to intercept volume button presses
- Override system volume behavior while app is active in delay mode
- Restore normal volume behavior when exiting delay mode
- **Fallback:** If volume button interception is not reliable on certain iOS versions, provide an on-screen button + double-tap as primary

### 6.2 Camera
- Support front and rear cameras
- Auto-focus and auto-exposure
- Manual exposure lock option (for consistent outdoor lighting)

### 6.3 Device Orientation
- Support landscape left, landscape right, and portrait
- Lock orientation option in settings

---

---

## 8. Performance Requirements

| Metric                            | Target                                    |
| --------------------------------- | ----------------------------------------- |
| Camera-to-delayed-display latency | < 50ms overhead (beyond configured delay) |
| Frame drop rate                   | < 1% during buffer write + read           |
| App launch to camera ready        | < 2 seconds                               |
| Key point mark response           | < 100ms (visual + haptic)                 |
| Clip generation (post-stop)       | < 3 seconds for 20 clips                  |
| Memory headroom                   | ≥ 30% free RAM maintained at all times    |

---

## 9. Data Models

### 9.1 Session
```swift
@Model
class Session {
    var id: UUID
    var date: Date
    var duration: TimeInterval
    var resolution: VideoResolution
    var fps: Int
    var delaySeconds: Double
    var clips: [Clip]
    var arrowHits: [ArrowHit]
    var totalScore: Int?
    var targetFaceType: TargetFaceType
}
```

### 9.2 Clip
```swift
@Model
class Clip {
    var id: UUID
    var sessionId: UUID
    var startTime: TimeInterval
    var endTime: TimeInterval
    var fileURL: URL?           // nil until exported
    var linkedArrowHit: ArrowHit?
    var annotations: [Annotation]?
}
```

### 9.3 ArrowHit
```swift
@Model
class ArrowHit {
    var id: UUID
    var sessionId: UUID
    var position: CGPoint       // normalized (0...1) on target face
    var ringScore: Int          // 0 (miss) to 10, or 11 for X
    var arrowIndex: Int         // order within the round
    var linkedClipId: UUID?
}
```

### 9.4 KeyPoint
```swift
struct KeyPoint {
    var timestamp: TimeInterval  // position in buffer timeline
    var frameIndex: Int
    var source: MarkSource       // .doubleTap | .volumeButton | .onScreenButton
}
```

---

## 10. Non-Functional Requirements

### 10.1 Supported Devices
- **iPhone:** iPhone 12 and later (A14 Bionic+)
- **iPad:** iPad (9th gen) and later, iPad Air (4th gen)+, iPad Pro (M1+)
- **Minimum RAM:** 4 GB (6 GB+ recommended for 1080p @ 60fps long buffers)

### 10.2 Distribution
- **Personal use only** — deploy via Xcode to personal device or TestFlight
- No App Store submission required (free Apple Developer account sufficient)
- App size target: < 50 MB

### 10.3 Accessibility
- VoiceOver support for all interactive elements
- Dynamic Type support for all text
- High contrast mode support
- Haptic feedback for key actions (marking, scoring)

### 10.4 Localization
- v1.0: English only
- Architecture supports `String(localized:)` for future localization

---

## 11. Testing Strategy

| Test Type         | Scope                                                                   |
| ----------------- | ----------------------------------------------------------------------- |
| Unit Tests        | Buffer logic, scoring engine, clip splitting, data models               |
| UI Tests          | Full user flow (setup → record → mark → stop → score → replay)          |
| Performance Tests | Buffer write/read throughput, memory pressure handling                  |
| Device Tests      | Physical device testing on iPhone 12, 14 Pro, 16 Pro Max; iPad Pro M2   |
| Memory Tests      | Long-duration sessions (20 min) at all resolution/fps combos            |
| Edge Cases        | App backgrounding mid-session, low memory warnings, camera interruption |

---

## 12. Milestones & Phases

### Phase 1 — MVP (Core Delay Mode)
- [x] Camera setup and preview
- [x] Circular frame buffer with configurable delay
- [x] Delayed playback view
- [x] Start / Stop controls
- [x] Key point marking (double-tap + volume button)
- [x] Auto-clipping on stop
- [x] Basic replay view (play, pause, scrub)
- [x] Settings (delay, resolution, fps)
- [x] save session (video clips) to file
- [x] load session from file
- [x] show the storage size of all the files
- [x] enable the user to delete the files
- [x] enable the user to output clips to photo library

### Phase 2 — Analysis & Scoring
- [x] Slow-motion playback (0.25x–2x)
- [x] Frame-by-frame stepping
- [x] Archery target scoring screen
- [x] Clip-to-hit linking
- [ ] On-screen drawing overlay
- [ ] Angle measurement tool
- [ ] Trim & export clips

### Phase 3 — Advanced Features
- [ ] Split screen / versus mode
- [ ] Stopwatch overlay
- [ ] Motion detection grid
- [ ] Horizontal flip and rotation
- [ ] Session history with SwiftData persistence
- [ ] Annotation saving

### Phase 4 — Polish & Launch
- [ ] UI/UX refinement and animations
- [ ] Accessibility audit
- [ ] Performance optimization
- [ ] App Store assets (screenshots, description, preview video)
- [ ] Privacy policy
- [ ] TestFlight beta
- [ ] App Store submission

---

## 13. Open Questions & Decisions

| #   | Question                                           | Options                                            | Decision                                |
| --- | -------------------------------------------------- | -------------------------------------------------- | --------------------------------------- |
| 1   | Business model?                                    | Personal use only (no monetization needed)         | **Personal use**                        |
| 2   | Volume button interception reliability on iOS 17+? | Test on physical devices; may need fallback        | Needs research                          |
| 3   | Maximum practical buffer at 1080p/60fps?           | Depends on device RAM; need real-device benchmarks | Needs testing                           |
| 4   | Support for external cameras (via USB-C)?          | Nice-to-have for tripod setups                     | Deferred to v2                          |
| 5   | Apple Watch companion for remote marking?          | Could use WatchConnectivity for remote tap-to-mark | Deferred to v2                          |
| 6   | Multiple target face types?                        | WA standard, Vegas, NFAA, custom                   | v1: WA standard; expand later           |
| 7   | Cloud sync for session history?                    | iCloud via CloudKit                                | Deferred (conflicts with privacy-first) |

---

## 14. Glossary

| Term             | Definition                                                                   |
| ---------------- | ---------------------------------------------------------------------------- |
| Buffer           | In-memory storage of video frames for delayed playback                       |
| Delay            | Time gap between live capture and playback display                           |
| Key Point / Mark | User-defined timestamp in the video for clipping                             |
| Clip             | Video segment between two key point markers                                  |
| Target Face      | The circular archery target used for scoring                                 |
| Ring Score       | Scoring value (0–10, X=11) based on arrow position on target                 |
| Circular Buffer  | Data structure where the write pointer wraps around, overwriting oldest data |
| GOP              | Group of Pictures — a set of frames in video compression                     |
| CVPixelBuffer    | Apple's pixel buffer type for efficient video frame handling                 |
