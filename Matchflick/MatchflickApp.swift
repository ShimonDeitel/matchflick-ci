import SwiftUI
import SwiftData

@main
struct MatchflickApp: App {
    @StateObject private var store: Store
    @StateObject private var appModel: AppModel
    private let container: ModelContainer

    init() {
        // UI tests opt into a clean slate — without this, a round left in progress by a prior
        // test (now correctly resumable, see GameEngine.persist) would leak into unrelated tests.
        if ProcessInfo.processInfo.environment["MATCHFLICK_RESET_GAME"] == "1" {
            GameEngine.clearPersistedRound()
        }
        let c = AppModel.makeContainer()
        let s = Store()
        let m = AppModel(container: c)
        m.store = s
        self.container = c
        _store = StateObject(wrappedValue: s)
        _appModel = StateObject(wrappedValue: m)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(appModel)
                .modelContainer(container)
        }
    }
}
