import Foundation
import SwiftData
import SwiftUI

/// App state: owns the SwiftData store, Watch History (Pro feature), boards, and the
/// Want to Watch / Maybe watchlists (free, with Pro-only custom boards).
@MainActor
final class AppModel: ObservableObject {
    let container: ModelContainer
    weak var store: Store?
    let sync = LocalSyncService()

    @Published private(set) var history: [MatchRecord] = []
    @Published private(set) var watchlist: [WatchlistEntry] = []
    @Published private(set) var boards: [WatchBoard] = []

    init(container: ModelContainer) {
        self.container = container
        refresh()
        seedDefaultBoardsIfNeeded()
        sync.makeLocalSnapshot = { [weak self] in self?.makeSyncSnapshot() ?? SyncSnapshot(entries: [], boards: []) }
        sync.onReceiveSnapshot = { [weak self] snapshot in self?.mergeSyncSnapshot(snapshot) }
        if UserDefaults.standard.bool(forKey: "minder.nearbySyncEnabled") { sync.start() }
    }

    // MARK: Nearby sync (local Wi-Fi only — see LocalSyncService)

    private func makeSyncSnapshot() -> SyncSnapshot {
        SyncSnapshot(
            entries: watchlist.map { .init(id: $0.id, movieId: $0.movieId, title: $0.title, year: $0.year,
                                            mediaTypeRaw: $0.mediaTypeRaw, statusRaw: $0.statusRaw,
                                            boardID: $0.boardID, addedAt: $0.addedAt) },
            boards: boards.map { .init(id: $0.id, name: $0.name, symbol: $0.symbol, kindRaw: $0.kindRaw,
                                        isDefault: $0.isDefault, createdAt: $0.createdAt) }
        )
    }

    /// Additive-only merge: inserts anything the peer has that we don't, by id. Never deletes or
    /// overwrites local data — see LocalSyncService's doc comment for why.
    private func mergeSyncSnapshot(_ snapshot: SyncSnapshot) {
        let existingBoardIDs = Set(boards.map(\.id))
        for b in snapshot.boards where !existingBoardIDs.contains(b.id) {
            container.mainContext.insert(WatchBoard(id: b.id, name: b.name, symbol: b.symbol,
                                                      kindRaw: b.kindRaw, isDefault: b.isDefault, createdAt: b.createdAt))
        }
        let existingEntryIDs = Set(watchlist.map(\.id))
        for e in snapshot.entries where !existingEntryIDs.contains(e.id) {
            container.mainContext.insert(WatchlistEntry(id: e.id, movieId: e.movieId, title: e.title, year: e.year,
                                                          mediaTypeRaw: e.mediaTypeRaw, statusRaw: e.statusRaw,
                                                          boardID: e.boardID, addedAt: e.addedAt))
        }
        try? container.mainContext.save()
        refresh()
    }

    func setNearbySyncEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: "minder.nearbySyncEnabled")
        if enabled { sync.start() } else { sync.stop() }
    }

    static func makeContainer() -> ModelContainer {
        let schema = Schema([MatchRecord.self, WatchlistEntry.self, WatchBoard.self])
        if FileManager.default.ubiquityIdentityToken != nil {
            let cloud = ModelConfiguration(schema: schema, cloudKitDatabase: .automatic)
            if let c = try? ModelContainer(for: schema, configurations: cloud) { return c }
        }
        let local = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
        if let c = try? ModelContainer(for: schema, configurations: local) { return c }
        let mem = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try! ModelContainer(for: schema, configurations: mem)
    }

    func refresh() {
        let d = FetchDescriptor<MatchRecord>(sortBy: [SortDescriptor(\.matchedAt, order: .reverse)])
        history = (try? container.mainContext.fetch(d)) ?? []
        let w = FetchDescriptor<WatchlistEntry>(sortBy: [SortDescriptor(\.addedAt, order: .reverse)])
        watchlist = (try? container.mainContext.fetch(w)) ?? []
        let b = FetchDescriptor<WatchBoard>(sortBy: [SortDescriptor(\.createdAt, order: .forward)])
        boards = (try? container.mainContext.fetch(b)) ?? []
    }

    private func seedDefaultBoardsIfNeeded() {
        guard boards.isEmpty else { return }
        let want = WatchBoard(id: WatchBoard.defaultWantID, name: "Want to Watch",
                               symbol: "checkmark.circle.fill", kindRaw: WatchlistStatus.wantToWatch.rawValue, isDefault: true)
        let maybe = WatchBoard(id: WatchBoard.defaultMaybeID, name: "Maybe",
                                symbol: "cube.fill", kindRaw: WatchlistStatus.maybe.rawValue, isDefault: true)
        container.mainContext.insert(want)
        container.mainContext.insert(maybe)
        try? container.mainContext.save()
        refresh()
    }

    func boards(for kind: WatchlistStatus) -> [WatchBoard] {
        boards.filter { $0.kind == kind }
    }

    func defaultBoard(for kind: WatchlistStatus) -> WatchBoard? {
        boards.first { $0.kind == kind && $0.isDefault }
    }

    /// Pro-only: create a new board of the given kind.
    func createBoard(name: String, symbol: String, kind: WatchlistStatus) {
        container.mainContext.insert(WatchBoard(name: name, symbol: symbol, kindRaw: kind.rawValue))
        try? container.mainContext.save()
        refresh()
        sync.broadcastLocalState()
    }

    /// Removes a custom board and any entries filed into it (default boards can't be deleted).
    func deleteBoard(_ board: WatchBoard) {
        guard !board.isDefault else { return }
        let boardID = board.id
        let entriesInBoard = watchlist.filter { $0.boardID == boardID }
        for entry in entriesInBoard { container.mainContext.delete(entry) }
        container.mainContext.delete(board)
        try? container.mainContext.save()
        refresh()
    }

    /// Recording history is a Pro perk (see spec) — caller checks `store.isPro` before calling.
    func recordMatch(title: String, year: Int, chemistry: Int, playerCount: Int) {
        container.mainContext.insert(MatchRecord(movieTitle: title, movieYear: year, chemistry: chemistry, playerCount: playerCount))
        try? container.mainContext.save()
        refresh()
    }

    func delete(_ m: MatchRecord) {
        container.mainContext.delete(m)
        try? container.mainContext.save()
        refresh()
    }

    // MARK: Watchlist (free)

    func watchlistStatus(for movieId: String) -> WatchlistStatus? {
        watchlist.first { $0.movieId == movieId }?.status
    }

    func watchlistEntry(for movieId: String) -> WatchlistEntry? {
        watchlist.first { $0.movieId == movieId }
    }

    /// Files (or un-files, if status is nil) a movie. `boardID` nil means "the default board of
    /// that kind" — used everywhere except the custom-board picker.
    func setWatchlistStatus(_ status: WatchlistStatus?, for movie: Movie, boardID: UUID? = nil) {
        if let existing = watchlist.first(where: { $0.movieId == movie.id }) {
            if let status {
                existing.status = status
                existing.boardID = boardID ?? defaultBoard(for: status)?.id
            } else {
                container.mainContext.delete(existing)
            }
        } else if let status {
            container.mainContext.insert(WatchlistEntry(
                movieId: movie.id, title: movie.title, year: movie.year,
                mediaTypeRaw: movie.mediaType.rawValue, statusRaw: status.rawValue,
                boardID: boardID ?? defaultBoard(for: status)?.id))
        }
        try? container.mainContext.save()
        refresh()
        sync.broadcastLocalState()
    }

    func deleteWatchlistEntry(_ entry: WatchlistEntry) {
        container.mainContext.delete(entry)
        try? container.mainContext.save()
        refresh()
    }

    func moveWatchlistEntry(_ entry: WatchlistEntry, to status: WatchlistStatus, boardID: UUID? = nil) {
        entry.status = status
        entry.boardID = boardID ?? defaultBoard(for: status)?.id
        try? container.mainContext.save()
        refresh()
    }

    /// "I Watched This" from a Want to Watch card: drops it into Watch History (free — see
    /// HistoryView) and removes it from the watchlist.
    func markWatched(_ entry: WatchlistEntry) {
        container.mainContext.insert(MatchRecord(movieTitle: entry.title, movieYear: entry.year, isSelfLogged: true))
        container.mainContext.delete(entry)
        try? container.mainContext.save()
        refresh()
    }

    /// Erase all on-device data (used by Delete Account).
    func deleteAllData() {
        try? container.mainContext.delete(model: MatchRecord.self)
        try? container.mainContext.delete(model: WatchlistEntry.self)
        try? container.mainContext.delete(model: WatchBoard.self)
        try? container.mainContext.save()
        refresh()
        seedDefaultBoardsIfNeeded()
    }
}
