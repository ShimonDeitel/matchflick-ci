import Foundation

/// Default swipe settings, editable in Settings. The app opens straight into swiping using
/// whatever was last configured here — no setup screen on launch.
enum GamePrefs {
    static let playerCountKey = "minder.playerCount"
    static let moodsKey = "minder.moods"
    static let mediaFilterKey = "minder.mediaFilter"
    static let yearMinKey = "minder.yearMin"
    static let yearMaxKey = "minder.yearMax"
    static let tmdbApiKeyKey = "minder.tmdbApiKey"
    static let maxMaturityKey = "minder.maxMaturity"

    static let earliestYear = 1930
    static let latestYear = 2026

    /// US movie certifications, in order of increasing maturity. The slider picks a maximum —
    /// TMDB's discover/movie endpoint supports certification.lte directly. TMDB's discover/tv
    /// endpoint has no equivalent certification filter, so this only narrows movie results.
    static let maturityLevels = ["G", "PG", "PG-13", "R", "NC-17"]
    static let defaultMaxMaturityIndex = maturityLevels.count - 1

    static var defaultMoodsRaw: String { MoodTag.cozy.rawValue }

    /// The owner's own TMDB API key, provided directly by them for this app — baked in as the
    /// default so ratings/streaming data work out of the box. Still editable in Settings.
    static let defaultTMDBApiKey = "c6aada4948663492f1cdfc09aa58c767"
}
