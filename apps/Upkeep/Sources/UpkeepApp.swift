import SwiftUI
import UpkeepCore

@main
struct UpkeepApp: App {
    @State private var store = AppStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ThemedRoot()
                .environment(store)
                .preferredColorScheme(store.data.settings.theme.colorScheme)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                store.refreshToday()
                store.scheduleReminders()
            }
        }
    }
}

/// Builds the Material palette for the current light/dark appearance.
private struct ThemedRoot: View {
    @Environment(AppStore.self) private var store
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = M3Theme(seed: store.data.settings.accent, dark: colorScheme == .dark)
        RootView()
            .environment(\.m3, theme)
            .tint(theme.primary)
    }
}
