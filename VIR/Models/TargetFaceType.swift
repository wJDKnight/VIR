import Foundation
import SwiftUI

extension TargetFaceType {
    var diameterCm: Double {
        switch self {
        case .wa122: return 122.0
        case .wa80: return 80.0
        case .wa40, .vegas3Spot: return 40.0
        }
    }
    
    /// The size of the 10-ring in cm
    var tenRingDiameterCm: Double {
        switch self {
        case .wa122: return 12.2
        case .wa80: return 8.0
        case .wa40, .vegas3Spot: return 4.0
        }
    }
    
    /// The size of the Inner 10 (X) ring in cm
    var xRingDiameterCm: Double {
        return tenRingDiameterCm / 2.0
    }
}
