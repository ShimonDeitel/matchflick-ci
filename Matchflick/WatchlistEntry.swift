import Foundation
import SwiftData

enum WatchlistStatus: String, Codable {
    case wantToWatch, maybe
}

/// A title the user tagged from the detail preview. Free feature — separate from the Pro-only
/// Watch History (which logs *group match results*, not personal triage). `boardID` files the
/// entry into a specific board (defaults to the built-in Want to Watch/Maybe board of that kind
/// when nil, so existing entries from before boards existed keep working).
@Model
final class WatchlistEntry {
    var id: UUID = UUID()
    var movieId: String = ""
    var title: String = ""
    var year: Int = 0
    var mediaTypeRaw: String = MediaType.movie.rawValue
    var statusRaw: String = WatchlistStatus.wantToWatch.rawValue
    var boardID: UUID?
    var addedAt: Date = Date.now

    var status: WatchlistStatus {
        get { WatchlistStatus(rawValue: statusRaw) ?? .wantToWatch }
        set { statusRaw = newValue.rawValue }
    }
    var mediaType: MediaType {
        MediaType(rawValue: mediaTypeRaw) ?? .movie
    }

    init(id: UUID = UUID(), movieId: String = "", title: String = "", year: Int = 0,
         mediaTypeRaw: String = MediaType.movie.rawValue, statusRaw: String = WatchlistStatus.wantToWatch.rawValue,
         boardID: UUID? = nil, addedAt: Date = .now) {
        self.id = id
        self.movieId = movieId
        self.title = title
        self.year = year
        self.mediaTypeRaw = mediaTypeRaw
        self.statusRaw = statusRaw
        self.boardID = boardID
        self.addedAt = addedAt
    }

    /// Rebuilds a minimal Movie for the detail preview/poster/ratings lookups. Genres, premise,
    /// and runtime aren't stored on the entry (only the identity fields are), but the TMDB id is
    /// recoverable from movieId's "tmdb-<type>-<id>" format (see TMDBCatalog.toMovie), which is
    /// enough for PosterService/RatingsService to fetch everything else live.
    var asMovie: Movie {
        var tmdbId: Int?
        let parts = movieId.split(separator: "-")
        if parts.count == 3, parts[0] == "tmdb", let n = Int(parts[2]) { tmdbId = n }
        return Movie(id: movieId, title: title, year: year, genres: [], premise: "",
                     moodTags: [], runtimeMins: 0, mediaType: mediaType, tmdbId: tmdbId)
    }
}
