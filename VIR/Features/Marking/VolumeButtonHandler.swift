import Foundation
import AVFoundation
import MediaPlayer
import UIKit
import os

/// Intercepts the hardware volume button presses to trigger key point marking.
/// Uses a hidden MPVolumeView + KVO on system volume to detect changes.
///
/// Note: This approach is fragile on modern iOS. Double-tap gesture is the
/// primary marking method; volume button is a bonus feature.
@MainActor
class VolumeButtonHandler: NSObject {
    private var volumeView: MPVolumeView?
    private var audioSession: AVAudioSession?
    private var initialVolume: Float = 0.5
    
    // Thread-safe state
    private let _isActive = OSAllocatedUnfairLock(initialState: false)
    
    // Non-isolated accessor for KVO
    nonisolated var isActive: Bool {
        _isActive.withLock { $0 }
    }

    var onVolumeDown: (() -> Void)?

    // MARK: - Activate / Deactivate

    func activate() {
        guard !isActive else { return }
        _isActive.withLock { $0 = true }

        // Set up audio session
        audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession?.setActive(true)
            try audioSession?.setCategory(.playback, options: .mixWithOthers)
        } catch {
            print("VolumeButtonHandler: Audio session error: \(error)")
        }

        // Store initial volume
        initialVolume = audioSession?.outputVolume ?? 0.5

        // Create hidden volume view to suppress HUD
        let frame = CGRect(x: -1000, y: -1000, width: 1, height: 1)
        volumeView = MPVolumeView(frame: frame)
        volumeView?.clipsToBounds = true

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.addSubview(volumeView!)
        }

        // Observe volume changes
        audioSession?.addObserver(
            self,
            forKeyPath: "outputVolume",
            options: [.new, .old],
            context: nil
        )
    }

    func deactivate() {
        guard isActive else { return }
        _isActive.withLock { $0 = false }

        audioSession?.removeObserver(self, forKeyPath: "outputVolume")
        volumeView?.removeFromSuperview()
        volumeView = nil

        // Restore volume
        setSystemVolume(initialVolume)
    }

    // MARK: - KVO

    override func observeValue(
        forKeyPath keyPath: String?,
        of object: Any?,
        change: [NSKeyValueChangeKey : Any]?,
        context: UnsafeMutableRawPointer?
    ) {
        guard keyPath == "outputVolume",
              let newVolume = change?[.newKey] as? Float,
              let oldVolume = change?[.oldKey] as? Float,
              isActive else { return }

        if newVolume < oldVolume {
            // Volume down pressed
            DispatchQueue.main.async { [weak self] in
                self?.onVolumeDown?()
            }
        }

        // Reset volume to prevent it from reaching 0 or 1
        // (which would stop generating events)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.setSystemVolume(0.5)
        }
    }

    // MARK: - Helpers

    private func setSystemVolume(_ volume: Float) {
        guard let slider = volumeView?.subviews.first(where: { $0 is UISlider }) as? UISlider else { return }
        slider.value = volume
    }

}
