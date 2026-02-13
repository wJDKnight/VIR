import Foundation
import CoreVideo

// MARK: - TimeInterval Formatting

extension TimeInterval {
    /// Formats as "M:SS" (e.g., 5:07)
    var minuteSecondText: String {
        let minutes = Int(self) / 60
        let seconds = Int(self) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    /// Formats as "MM:SS.f" (e.g., 05:07.3)
    var preciseText: String {
        let minutes = Int(self) / 60
        let seconds = Int(self) % 60
        let fraction = Int((self.truncatingRemainder(dividingBy: 1)) * 10)
        return String(format: "%02d:%02d.%d", minutes, seconds, fraction)
    }
}

// MARK: - CVPixelBuffer Helpers

extension CVPixelBuffer {
    /// Returns the size in bytes of this pixel buffer
    var dataSize: Int {
        CVPixelBufferGetDataSize(self)
    }

    /// Returns the dimensions as (width, height)
    var dimensions: (width: Int, height: Int) {
        (CVPixelBufferGetWidth(self), CVPixelBufferGetHeight(self))
    }

    /// Creates a deep copy of this pixel buffer
    func deepCopy() -> CVPixelBuffer? {
        let width = CVPixelBufferGetWidth(self)
        let height = CVPixelBufferGetHeight(self)
        let format = CVPixelBufferGetPixelFormatType(self)

        var copyOut: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            format,
            nil,
            &copyOut
        )

        guard status == kCVReturnSuccess, let copy = copyOut else { return nil }

        CVPixelBufferLockBaseAddress(self, .readOnly)
        CVPixelBufferLockBaseAddress(copy, [])
        defer {
            CVPixelBufferUnlockBaseAddress(self, .readOnly)
            CVPixelBufferUnlockBaseAddress(copy, [])
        }

        let srcPlaneCount = CVPixelBufferGetPlaneCount(self)
        if srcPlaneCount > 0 {
            for plane in 0..<srcPlaneCount {
                guard let srcAddr = CVPixelBufferGetBaseAddressOfPlane(self, plane),
                      let dstAddr = CVPixelBufferGetBaseAddressOfPlane(copy, plane) else { continue }
                let srcBytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(self, plane)
                let height = CVPixelBufferGetHeightOfPlane(self, plane)
                memcpy(dstAddr, srcAddr, srcBytesPerRow * height)
            }
        } else {
            guard let srcAddr = CVPixelBufferGetBaseAddress(self),
                  let dstAddr = CVPixelBufferGetBaseAddress(copy) else { return nil }
            let bytesPerRow = CVPixelBufferGetBytesPerRow(self)
            memcpy(dstAddr, srcAddr, bytesPerRow * height)
        }

        return copy
    }
}
