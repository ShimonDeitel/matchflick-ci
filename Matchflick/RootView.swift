import SwiftUI

struct RootView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var appModel: AppModel
    @AppStorage("matchflick.theme") private var themeRaw = AppTheme.system.rawValue

    private var theme: AppTheme { AppTheme(rawValue: themeRaw) ?? .system }

    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Swipe", systemImage: "rectangle.stack.fill") }
            WatchlistView(status: .wantToWatch)
                .tabItem { Label("Want to Watch", systemImage: "checkmark.circle.fill") }
            WatchlistView(status: .maybe)
                .tabItem { Label("Maybe", systemImage: "cube.fill") }
            HistoryView()
                .tabItem { Label("History", systemImage: "clock.fill") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
        .tint(Color.matchflickAccent)
        .preferredColorScheme(theme.colorScheme)
        .onChange(of: store.isPro) { _, _ in appModel.refresh() }
    }
}
