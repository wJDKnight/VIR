import Foundation
import SwiftUI

/// App settings backed by UserDefaults for persistence across launches.
@Observable
@MainActor
class AppSettings {
    static let shared = AppSettings()

    private let defaults = UserDefaults.standard

    // MARK: - Keys
    private enum Keys {
        static let delaySeconds = "vir_delaySeconds"
        static let resolution = "vir_resolution"
        static let frameRate = "vir_frameRate"
        static let audioEnabled = "vir_audioEnabled"
        static let cameraSelection = "vir_cameraSelection"
        static let targetFaceType = "vir_targetFaceType"
    }

    // MARK: - Properties

    var delaySeconds: Double {
        didSet { defaults.set(delaySeconds, forKey: Keys.delaySeconds) }
    }

    var resolution: VideoResolution {
        didSet { defaults.set(resolution.rawValue, forKey: Keys.resolution) }
    }

    var frameRate: FrameRate {
        didSet { defaults.set(frameRate.rawValue, forKey: Keys.frameRate) }
    }

    var audioEnabled: Bool {
        didSet { defaults.set(audioEnabled, forKey: Keys.audioEnabled) }
    }

    var cameraSelection: CameraSelection {
        didSet { defaults.set(cameraSelection.rawValue, forKey: Keys.cameraSelection) }
    }

    var targetFaceType: TargetFaceType {
        didSet { defaults.set(targetFaceType.rawValue, forKey: Keys.targetFaceType) }
    }

    // MARK: - Computed

    var delayFrameCount: Int {
        Int(delaySeconds) * frameRate.rawValue
    }

    // MARK: - Init

    private init() {
        // Load from UserDefaults with defaults
        self.delaySeconds = defaults.object(forKey: Keys.delaySeconds) as? Double ?? 5.0
        self.resolution = VideoResolution(rawValue: defaults.string(forKey: Keys.resolution) ?? "") ?? .p720
        self.frameRate = FrameRate(rawValue: defaults.object(forKey: Keys.frameRate) as? Int ?? 30) ?? .fps30
        self.audioEnabled = defaults.object(forKey: Keys.audioEnabled) as? Bool ?? false
        self.cameraSelection = CameraSelection(rawValue: defaults.string(forKey: Keys.cameraSelection) ?? "") ?? .rear
        self.targetFaceType = TargetFaceType(rawValue: defaults.string(forKey: Keys.targetFaceType) ?? "") ?? .wa122
    }
}
