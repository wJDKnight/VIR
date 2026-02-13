import SwiftUI

/// Visual feedback overlay shown briefly when a key point is marked.
struct MarkingFeedbackView: View {
    let isVisible: Bool
    let markCount: Int

    var body: some View {
        ZStack {
            // Full-screen flash
            if isVisible {
                Color.white.opacity(0.3)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .animation(.easeOut(duration: VIRConstants.markFlashDuration), value: isVisible)

                // Mark badge
                VStack {
                    Image(systemName: "flag.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.yellow)

                    Text("MARK #\(markCount)")
                        .font(.headline.bold())
                        .foregroundStyle(.white)
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .allowsHitTesting(false)
    }
}
