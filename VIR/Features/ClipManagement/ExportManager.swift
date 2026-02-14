import Photos
import UIKit

enum ExportError: LocalizedError {
    case permissionDenied
    case saveFailed
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Photo Library access was denied. Please enable it in Settings."
        case .saveFailed:
            return "Failed to save video to Photos."
        }
    }
}

class ExportManager {
    static func saveVideoToPhotoLibrary(url: URL) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        
        guard status == .authorized || status == .limited else {
            throw ExportError.permissionDenied
        }
        
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
        }
    }
}
