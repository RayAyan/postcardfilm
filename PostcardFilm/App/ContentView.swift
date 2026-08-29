import SwiftUI

struct ContentView: View {
    var body: some View {
        #if DEBUG
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
