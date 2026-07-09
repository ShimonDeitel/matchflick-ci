import Foundation
import SwiftData

/// A past match result, saved to Watch History (Pro feature). CloudKit-mirroring compatible
/// (defaulted properties, no unique constraints).
@Model
final class MatchRecord {
    var id: UUID = UUID()
    var movieTitle: String = ""
    var movieYear: Int = 0
    var chemistry: Int = 0
    var playerCount: Int = 0
    var matchedAt: Date = Date.now
    /// True when this came from tapping "I Watched This" on a Want to Watch card, rather than
    /// a group swipe match — HistoryView displays these without the chemistry/player-count line.
    var isSelfLogged: Bool = false

    init(id: UUID = UUID(), movieTitle: String = "", movieYear: Int = 0, chemistry: Int = 0,
         playerCount: Int = 0, matchedAt: Date = .now, isSelfLogged: Bool = false) {
        self.id = id
        self.movieTitle = movieTitle
        self.movieYear = movieYear
        self.chemistry = chemistry
        self.playerCount = playerCount
        self.matchedAt = matchedAt
        self.isSelfLogged = isSelfLogged
    }
}
