import SwiftUI

struct ContentView: View {
    var body: some View {
        #if DEBUG && targetEnvironment(simulator)
        if ScreenshotHarness.isActive {
            ScreenshotRoot()
        } else {
            HomeView()
        }
        #else
        HomeView()
        #endif
    }
}

#Preview {
    ContentView()
        .environmentObject(PolaroidStore())
        .environmentObject(SettingsStore())
}
