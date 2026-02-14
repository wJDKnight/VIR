import SwiftUI

/// The primary screen: full-screen delayed camera feed with HUD overlay.
struct MainCameraScreen: View {
    @Environment(AppState.self) private var appState
    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = CameraViewModel()
    @State private var volumeHandler = VolumeButtonHandler()
    @State private var showSettings = false
    @State private var showHistory = false
    @State private var showDebug = false

    var body: some View {
        ZStack {
            // MARK: - Background: Live Camera Preview (always visible underneath)
            CameraPreviewView(session: viewModel.cameraManager.captureSession)
                .ignoresSafeArea()

            // MARK: - Delayed Video Playback Overlay
            // When delay has elapsed, this covers the live preview with the delayed feed
            if viewModel.isRecording, viewModel.delayReady, let buffer = viewModel.compressedBuffer {
                DelayedPlaybackView(compressedBuffer: buffer)
                    .ignoresSafeArea()
            }

            // MARK: - Debug Overlay (triple-tap to toggle)
            if showDebug {
                VStack {
                    HStack {
                        DebugOverlay(viewModel: viewModel)
                        Spacer()
                    }
                    Spacer()
                }
                .padding(.top, 50)
                .padding(.leading, 8)
            }

            // MARK: - Camera Permission Overlay
            if !viewModel.permissionGranted {
                Color.black.ignoresSafeArea()
                    .overlay {
                        VStack(spacing: 16) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 48))
                                .foregroundStyle(.gray)
                            Text("Camera access required")
                                .font(.headline)
                                .foregroundStyle(.gray)
                            Text("Enable camera access in Settings to use VIR.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                    }
            }

            // MARK: - Error Overlay
            if let error = viewModel.cameraManager.error {
                Color.black.opacity(0.7).ignoresSafeArea()
                    .overlay {
                        VStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 40))
                                .foregroundStyle(.yellow)
                            Text(error)
                                .font(.subheadline)
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                    }
            }

            // MARK: - Mark Flash Overlay
            MarkingFeedbackView(
                isVisible: viewModel.showMarkFlash,
                markCount: viewModel.markCount
            )

            // MARK: - Delay Countdown
            if viewModel.isRecording, !viewModel.delayReady {
                VStack {
                    Spacer()
                    Text("Delay starts in \(max(0, Int(settings.delaySeconds) - Int(viewModel.elapsedTime)))s…")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.black.opacity(0.5))
                        .clipShape(Capsule())
                    Spacer().frame(height: 100)
                }
            }

            // MARK: - HUD Overlay
            VStack {
                // Top bar
                HStack {
                    // Delay indicator
                    HUDBadge(
                        icon: "timer",
                        text: "\(Int(settings.delaySeconds))s"
                    )

                    Spacer()

                    // Recording indicator
                    if viewModel.isRecording {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(.red)
                                .frame(width: 10, height: 10)
                                .shadow(color: .red, radius: 4)

                            Text(viewModel.elapsedTime.minuteSecondText)
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.black.opacity(0.5))
                        .clipShape(Capsule())

                        // Mark Count Badge
                        if viewModel.markCount > 0 {
                            HUDBadge(
                                icon: "flag.fill",
                                text: "\(viewModel.markCount)"
                            )
                        }
                    }

                    Spacer()

                    // Settings button
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.title3)
                            .foregroundStyle(.white)
                            .padding(10)
                            .background(.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    .disabled(viewModel.isRecording)
                    .opacity(viewModel.isRecording ? 0.4 : 1)
                }
                .padding(.horizontal, VIRConstants.hudPadding)
                .padding(.top, 8)

                // Buffer fill bar (when recording)
                if viewModel.isRecording {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(.white.opacity(0.2))
                                .frame(height: 4)

                            RoundedRectangle(cornerRadius: 2)
                                .fill(bufferColor)
                                .frame(width: geo.size.width * viewModel.bufferFillLevel, height: 4)
                        }
                    }
                    .frame(height: 4)
                    .padding(.horizontal, VIRConstants.hudPadding)
                }

                Spacer()

                // Bottom bar
                HStack {
                    // History Button (Left)
                    Button {
                        showHistory = true
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.title3)
                            .foregroundStyle(.white)
                            .padding(10)
                            .background(.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    .disabled(viewModel.isRecording)
                    .opacity(viewModel.isRecording ? 0.4 : 1)

                    Spacer()

                    // Mark button (center-left)
                    if viewModel.isRecording {
                        Button {
                            viewModel.addMark(source: .onScreenButton, appState: appState)
                        } label: {
                            Image(systemName: "flag.fill")
                                .font(.title2)
                                .foregroundStyle(.yellow)
                                .frame(width: VIRConstants.buttonSize, height: VIRConstants.buttonSize)
                                .background(.black.opacity(0.6))
                                .clipShape(Circle())
                                .overlay {
                                    Circle()
                                        .strokeBorder(.yellow.opacity(0.5), lineWidth: 2)
                                }
                        }
                    } else {
                         // Spacer to balance layout when not recording
                         Spacer().frame(width: VIRConstants.buttonSize)
                    }

                    Spacer()

                    // Start / Stop button (Center)
                    Button {
                        if viewModel.isRecording {
                            stopSession()
                        } else {
                            startSession()
                        }
                    } label: {
                        if viewModel.isRecording {
                            // Stop button
                            RoundedRectangle(cornerRadius: 8)
                                .fill(.red)
                                .frame(width: 36, height: 36)
                                .padding(12)
                                .background(.black.opacity(0.6))
                                .clipShape(Circle())
                        } else {
                            // Start button
                            Circle()
                                .fill(.red)
                                .frame(width: 48, height: 48)
                                .overlay {
                                    Circle()
                                        .strokeBorder(.white, lineWidth: 3)
                                        .frame(width: 56, height: 56)
                                }
                                .padding(4)
                                .background(.black.opacity(0.6))
                                .clipShape(Circle())
                        }
                    }

                    Spacer()
                    
                    // Mark count badge (Hidden placeholder to balance layout)
                     Spacer().frame(width: VIRConstants.buttonSize)

                     Spacer()

                    // Settings button (Right) -> moved to bottom right for symmetry? 
                    // No, let's keep Settings top right and put History top left? 
                    // Actually, let's put History bottom left.
                }
                .padding(.horizontal, VIRConstants.hudPadding)
                .padding(.bottom, 20)
            }
        }
        .onTapGesture(count: 3) {
            withAnimation { showDebug.toggle() }
        }
        .onTapGesture(count: 2) {
            if viewModel.isRecording {
                viewModel.addMark(source: .doubleTap, appState: appState)
            }
        }
        .onAppear {
            viewModel.setup(settings: settings)
            setupVolumeHandler()
        }
        .onDisappear {
            volumeHandler.deactivate()
            viewModel.cleanup()
        }
        .sheet(isPresented: $showSettings) {
            CameraSettingsView(
                maxBufferDuration: viewModel.maxBufferDuration,
                onSettingsChanged: {
                    viewModel.configureCamera(settings: settings)
                },
                onDelayChanged: { newDelay in
                    viewModel.updateDelay(newDelay, fps: settings.frameRate.rawValue)
                }
            )
        }
        .sheet(isPresented: $showHistory) {
            NavigationStack {
                SessionListView()
            }
        }
        .statusBarHidden(viewModel.isRecording)
        .persistentSystemOverlays(viewModel.isRecording ? .hidden : .automatic)
    }

    // MARK: - Actions

    private func startSession() {
        appState.startNewSession(settings: settings)
        viewModel.startRecording()
        volumeHandler.activate()
    }

    private func stopSession() {
        volumeHandler.deactivate()
        let keyPoints = appState.currentKeyPoints
        guard let session = appState.currentSession else { return }
        
        Task {
            await viewModel.stopRecording()
            appState.recordingFileURL = viewModel.recordingFileURL
            appState.stopSession()

            // Generate clips from the saved recording file
            await viewModel.generateClips(keyPoints: keyPoints, sessionId: session.id)
            let clips = viewModel.savedClips
            appState.savedClips = clips
            
            // Update Session and Save to SwiftData
            session.clips = clips
            session.duration = viewModel.elapsedTime
            // session.totalScore = ... (future)
            
            modelContext.insert(session)
            try? modelContext.save()
            print("Session saved with \(clips.count) clips")
        }
    }

    private func setupVolumeHandler() {
        volumeHandler.onVolumeDown = { [weak viewModel] in
            viewModel?.addMark(source: .volumeButton, appState: appState)
        }
    }

    // MARK: - Helpers

    private var bufferColor: Color {
        if viewModel.bufferFillLevel > VIRConstants.memoryWarningThreshold {
            return .red
        } else if viewModel.bufferFillLevel > 0.5 {
            return .orange
        } else {
            return .green
        }
    }
}

// MARK: - HUD Badge Component

struct HUDBadge: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
            Text(text)
                .font(.caption.monospacedDigit().bold())
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.black.opacity(0.5))
        .clipShape(Capsule())
    }
}
