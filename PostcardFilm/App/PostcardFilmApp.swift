import SwiftUI

@main
struct PostcardFilmApp: App {
    @StateObject private var store = PolaroidStore()
    @StateObject private var settingsStore = SettingsStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(settingsStore)
                .preferredColorScheme(.dark)
        }
    }
}
