import SwiftUI

/// The app opens directly into swiping using whatever defaults are set in Settings — no setup
/// screen on launch. Settings holds player count, media filter, moods, and the decade range.
/// Decks are built live from the full TMDB catalog and fall back to the bundled library if
/// there's no key or the request fails (so the app still works offline).
struct HomeView: View {
    @EnvironmentObject var appModel: AppModel
    @EnvironmentObject var store: Store
    @StateObject private var engine = GameEngine()

    @AppStorage(GamePrefs.playerCountKey) private var playerCount = 2
    @AppStorage(GamePrefs.moodsKey) private var moodsRaw = GamePrefs.defaultMoodsRaw
    @AppStorage(GamePrefs.mediaFilterKey) private var mediaFilterRaw = MediaFilter.both.rawValue
    @AppStorage(GamePrefs.yearMinKey) private var yearMin = GamePrefs.earliestYear
    @AppStorage(GamePrefs.yearMaxKey) private var yearMax = GamePrefs.latestYear
    @AppStorage(GamePrefs.tmdbApiKeyKey) private var tmdbApiKey = GamePrefs.defaultTMDBApiKey
    @AppStorage(GamePrefs.maxMaturityKey) private var maxMaturityIndex = GamePrefs.defaultMaxMaturityIndex

    @State private var noMoviesMatch = false
    @State private var loadingDeck = false

    var body: some View {
        ZStack {
            MatchflickBackground()
            GameView(engine: engine, onDismiss: { startNewRound() })
            if loadingDeck {
                ProgressView().controlSize(.large)
            }
        }
        .alert("No matches for these filters", isPresented: $noMoviesMatch) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Try widening the decade range or picking a different mood in the Settings tab.")
        }
        .onAppear {
            if case .setup = engine.phase {
                // Resume a round in progress (e.g. app was quit mid-swipe) before falling back
                // to starting a brand new one.
                if !engine.restoreIfAvailable() { startNewRound() }
            }
        }
    }

    private func startNewRound() {
        let moods = Set(moodsRaw.split(separator: ",").compactMap { MoodTag(rawValue: String($0)) })
        let filter = MediaFilter(rawValue: mediaFilterRaw) ?? .both
        Task {
            loadingDeck = true
            let deck = await buildDeck(moods: moods, filter: filter)
            loadingDeck = false
            guard !deck.isEmpty else { noMoviesMatch = true; return }
            engine.start(players: (1...max(playerCount, 1)).map { "Player \($0)" }, deck: deck)
        }
    }

    private func buildDeck(moods: Set<MoodTag>, filter: MediaFilter) async -> [Movie] {
        let effectiveMoods = moods.isEmpty ? [MoodTag.cozy] : Array(moods)
        // Primary source: the live TMDB catalog — effectively every movie/show ever made,
        // filtered by mood/media/decade, with real posters and availability.
        let maturity = GamePrefs.maturityLevels.indices.contains(maxMaturityIndex) ? GamePrefs.maturityLevels[maxMaturityIndex] : nil
        if let liveDeck = await TMDBCatalog.fetchDeck(
            moods: Set(effectiveMoods), filter: filter, yearRange: yearMin...yearMax, apiKey: tmdbApiKey, maxMaturity: maturity
        ), !liveDeck.isEmpty {
            return liveDeck
        }
        // Fallback: the bundled library, for offline use or if TMDB is unreachable.
        let unlockedDecks = MovieDeck.all.filter { $0.isFree || store.isPro }
        let movies = unlockedDecks.flatMap { $0.movies }
            .filter { movie in !movie.effectiveMoodTags.isDisjoint(with: effectiveMoods.map(\.rawValue)) }
            .filter { filter.matches($0.mediaType) }
            .filter { (yearMin...yearMax).contains($0.year) }
        return Array(Set(movies)).shuffled().prefix(20).map { $0 }
    }
}
