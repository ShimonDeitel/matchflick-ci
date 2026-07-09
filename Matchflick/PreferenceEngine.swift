import Foundation

/// Learns the user's taste from every swipe: each genre's affinity score nudges up on a right
/// swipe (or Want to Watch/Maybe) and down on a left swipe. TMDBCatalog uses these scores to
/// bias which genres it pulls into the deck and how it ranks/orders results.
///
/// Honest framing: this is a content-based, on-device affinity model (per-genre scoring), not a
/// collaborative-filtering system like Spotify/YouTube's — those learn from hundreds of millions
/// of other users' behavior via a large backend, which a single-device app has no way to
/// replicate. What this DOES do for real: it tracks every swipe, and measurably shifts future
/// decks toward genres you say yes to and away from genres you reject.
enum PreferenceEngine {
    private static let scoresKey = "minder.genreAffinity"
    private static let quizTakenKey = "minder.algorithmQuizTaken"
    private static let seenKey = "minder.seenMovieIds"
    /// Clamp so one heavily-swiped genre can't permanently dominate every deck — keeps the model
    /// responsive to a taste shift instead of ossifying around whatever was swiped on first.
    private static let scoreClamp = 20.0
    /// Cap how many swiped ids we remember, so this can't grow forever — oldest drop off first.
    private static let maxSeenIds = 4000

    static var hasTakenQuiz: Bool {
        get { UserDefaults.standard.bool(forKey: quizTakenKey) }
        set { UserDefaults.standard.set(newValue, forKey: quizTakenKey) }
    }

    private static func loadScores() -> [String: Double] {
        guard let data = UserDefaults.standard.data(forKey: scoresKey),
              let dict = try? JSONDecoder().decode([String: Double].self, from: data) else { return [:] }
        return dict
    }

    private static func saveScores(_ dict: [String: Double]) {
        let clamped = dict.mapValues { min(max($0, -scoreClamp), scoreClamp) }
        guard let data = try? JSONEncoder().encode(clamped) else { return }
        UserDefaults.standard.set(data, forKey: scoresKey)
    }

    /// Call on every swipe (yes/no) and every Want to Watch / Maybe tag — the real learning step.
    static func recordSwipe(genres: [String], liked: Bool) {
        var scores = loadScores()
        let delta = liked ? 1.0 : -1.2
        for genre in genres {
            scores[genre, default: 0] += delta
        }
        saveScores(scores)
    }

    /// A stronger positive signal than a plain swipe — used for Want to Watch / Maybe taps.
    static func recordStrongLike(genres: [String]) {
        var scores = loadScores()
        for genre in genres { scores[genre, default: 0] += 2.0 }
        saveScores(scores)
    }

    /// Seed initial weights from the quick quiz in Settings.
    static func seed(favoriteGenres: [String], avoidedGenres: [String]) {
        var scores = loadScores()
        for g in favoriteGenres { scores[g, default: 0] += 4.0 }
        for g in avoidedGenres { scores[g, default: 0] -= 4.0 }
        saveScores(scores)
        hasTakenQuiz = true
    }

    static func reset() {
        UserDefaults.standard.removeObject(forKey: scoresKey)
        UserDefaults.standard.removeObject(forKey: seenKey)
        hasTakenQuiz = false
    }

    // MARK: Seen titles — so a swiped title doesn't keep resurfacing in future decks

    private static func loadSeen() -> [String] {
        UserDefaults.standard.stringArray(forKey: seenKey) ?? []
    }

    static var seenMovieIds: Set<String> { Set(loadSeen()) }

    static func recordSeen(movieId: String) {
        var seen = loadSeen()
        seen.removeAll { $0 == movieId }
        seen.append(movieId)
        if seen.count > maxSeenIds { seen.removeFirst(seen.count - maxSeenIds) }
        UserDefaults.standard.set(seen, forKey: seenKey)
    }

    /// Genres ranked best-to-worst by learned affinity, restricted to the given candidate set.
    static func rank(candidates: [String]) -> [String] {
        let scores = loadScores()
        return candidates.sorted { (scores[$0] ?? 0) > (scores[$1] ?? 0) }
    }

    /// Genres the user has consistently rejected — used to steer the discover query away.
    static func dislikedGenres(among candidates: [String], threshold: Double = -3) -> [String] {
        let scores = loadScores()
        return candidates.filter { (scores[$0] ?? 0) <= threshold }
    }

    /// Sum of learned affinity across a title's genres — used to bias which results from a
    /// broader pool get shown first.
    static func score(for genres: [String]) -> Double {
        let scores = loadScores()
        return genres.reduce(0) { $0 + (scores[$1] ?? 0) }
    }
}
