import Foundation

// MARK: - Video Resolution

enum VideoResolution: String, Codable, CaseIterable, Identifiable {
    case p480 = "480p"
    case p720 = "720p"
    case p1080 = "1080p"

    var id: String { rawValue }

    var width: Int {
        switch self {
        case .p480: return 640
        case .p720: return 1280
        case .p1080: return 1920
        }
    }

    var height: Int {
        switch self {
        case .p480: return 480
        case .p720: return 720
        case .p1080: return 1080
        }
    }

    /// Approximate raw BGRA frame size in bytes
    var rawFrameSize: Int {
        width * height * 4
    }

    var displayName: String { rawValue }
}

// MARK: - Frame Rate

enum FrameRate: Int, Codable, CaseIterable, Identifiable {
    case fps30 = 30
    case fps60 = 60

    var id: Int { rawValue }
    var displayName: String { "\(rawValue) fps" }
}

// MARK: - Target Face Type

enum TargetFaceType: String, Codable, CaseIterable, Identifiable {
    case wa122 = "WA 122cm"
    case wa80 = "WA 80cm"
    case wa40 = "WA 40cm"
    case vegas3Spot = "Vegas 3-Spot"

    var id: String { rawValue }
    var displayName: String { rawValue }
}

// MARK: - Mark Source

enum MarkSource: String, Codable {
    case doubleTap
    case volumeButton
    case onScreenButton
}

// MARK: - App Mode

enum AppMode: Equatable {
    case idle
    case recording
    case reviewing
}

// MARK: - Camera Position

enum CameraSelection: String, Codable, CaseIterable, Identifiable {
    case front
    case rear

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .front: return "Front"
        case .rear: return "Rear"
        }
    }
}
