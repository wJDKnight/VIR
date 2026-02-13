import SwiftUI
import SwiftData

@main
struct VIRApp: App {
    @State private var appState = AppState()
    private let settings = AppSettings.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .environment(settings)
                .modelContainer(for: [Session.self, Clip.self, ArrowHit.self])
        }
    }
}

/// Root content view that routes based on app mode.
struct ContentView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        NavigationStack {
            switch appState.mode {
            case .idle, .recording:
                MainCameraScreen()
            case .reviewing:
                PostSessionView()
            }
        }
        .preferredColorScheme(.dark)
    }
}
