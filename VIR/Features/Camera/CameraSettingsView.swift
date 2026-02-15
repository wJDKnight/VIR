import SwiftUI

/// Settings overlay sheet for camera configuration.
struct CameraSettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss
    let maxBufferDuration: TimeInterval
    /// Called when camera-related settings changed (resolution, fps, camera)
    var onSettingsChanged: (() -> Void)?
    /// Called when only the delay changed (no camera reconfiguration needed)
    var onDelayChanged: ((Double) -> Void)?

    // Track initial values to detect what actually changed
    @State private var initialResolution: VideoResolution?
    @State private var initialFrameRate: FrameRate?
    @State private var initialCamera: CameraSelection?
    @State private var initialDelay: Double?

    var body: some View {
        @Bindable var settings = settings
        NavigationStack {
            Form {
                // MARK: - Delay
                Section("Delay") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Delay Duration")
                            Spacer()
                            Text("\(Int(settings.delaySeconds))s")
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                        Slider(
                            value: $settings.delaySeconds,
                            in: VIRConstants.minDelay...VIRConstants.maxDelay,
                            step: 1
                        )
                    }
                }

                // MARK: - Video Quality
                Section("Video Quality") {
                    Picker("Resolution", selection: $settings.resolution) {
                        ForEach(VideoResolution.allCases) { res in
                            Text(res.displayName).tag(res)
                        }
                    }

                    Picker("Frame Rate", selection: $settings.frameRate) {
                        ForEach(FrameRate.allCases) { fps in
                            Text(fps.displayName).tag(fps)
                        }
                    }
                }

                // MARK: - Camera
                Section("Camera") {
                    Picker("Camera", selection: $settings.cameraSelection) {
                        ForEach(CameraSelection.allCases) { cam in
                            Text(cam.displayName).tag(cam)
                        }
                    }

                    Toggle("Audio Capture", isOn: $settings.audioEnabled)
                }

                // MARK: - Buffer Info
                Section("Buffer Information") {
                    HStack {
                        Image(systemName: "memorychip")
                        Text("~\(Int(maxBufferDuration / 60)) min available")
                            .foregroundStyle(.secondary)
                    }

                    Text("Buffer duration depends on device RAM and selected resolution/fps.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                // MARK: - Archery
                Section("Archery") {
                    Picker("Target Face", selection: $settings.targetFaceType) {
                        ForEach(TargetFaceType.allCases) { face in
                            Text(face.displayName).tag(face)
                        }
                    }
                    
                    HStack {
                        Text("Arrow Diameter")
                        Spacer()
                        Text(String(format: "%.1f mm", settings.arrowDiameterMm))
                            .foregroundStyle(.secondary)
                        Stepper("", value: $settings.arrowDiameterMm, in: 3.0...10.0, step: 0.1)
                            .labelsHidden()
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        applyChanges()
                        dismiss()
                    }
                }
            }
            .onAppear {
                initialResolution = settings.resolution
                initialFrameRate = settings.frameRate
                initialCamera = settings.cameraSelection
                initialDelay = settings.delaySeconds
            }
        }
    }

    private func applyChanges() {
        let cameraChanged = settings.resolution != initialResolution
            || settings.frameRate != initialFrameRate
            || settings.cameraSelection != initialCamera

        if cameraChanged {
            onSettingsChanged?()
        } else if settings.delaySeconds != initialDelay {
            onDelayChanged?(settings.delaySeconds)
        }
    }
}
