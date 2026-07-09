import Foundation

enum MediaType: String, CaseIterable, Identifiable, Codable {
    case movie, tv
    var id: String { rawValue }
    var label: String { self == .movie ? "Movies" : "TV Shows" }
    var symbol: String { self == .movie ? "film.fill" : "tv.fill" }
}

enum MediaFilter: String, CaseIterable, Identifiable {
    case movies, tv, both
    var id: String { rawValue }
    var label: String {
        switch self {
        case .movies: return "Movies"
        case .tv: return "TV"
        case .both: return "Both"
        }
    }
    func matches(_ type: MediaType) -> Bool {
        switch self {
        case .movies: return type == .movie
        case .tv: return type == .tv
        case .both: return true
        }
    }
}

/// A movie/show card. Poster art is fetched live from Apple's iTunes Search API (see
/// PosterService); this struct only carries the text metadata used for matching and display.
struct Movie: Identifiable, Equatable, Hashable, Codable {
    let id: String
    let title: String
    let year: Int
    let genres: [String]
    let premise: String
    let moodTags: [String]
    let runtimeMins: Int
    let mediaType: MediaType
    /// Set when this card came from the live TMDB catalog — lets PosterService skip the iTunes
    /// lookup and RatingsService skip its own search, since we already have the TMDB id/artwork.
    let tmdbId: Int?
    let posterPath: String?

    init(id: String, title: String, year: Int, genres: [String], premise: String,
         moodTags: [String], runtimeMins: Int, mediaType: MediaType = .movie,
         tmdbId: Int? = nil, posterPath: String? = nil) {
        self.id = id
        self.title = title
        self.year = year
        self.genres = genres
        self.premise = premise
        self.moodTags = moodTags
        self.runtimeMins = runtimeMins
        self.mediaType = mediaType
        self.tmdbId = tmdbId
        self.posterPath = posterPath
    }

    /// A YouTube search results link for the title's trailer — no video-ID database or API key
    /// required, so it always resolves to something relevant even without curated data.
    var trailerSearchURL: URL {
        let query = "\(title) \(year) \(mediaType == .tv ? "official trailer" : "trailer")"
        var components = URLComponents(string: "https://www.youtube.com/results")!
        components.queryItems = [URLQueryItem(name: "search_query", value: query)]
        return components.url!
    }

    /// The hand-authored `moodTags` cover the original six moods. The ten newer moods are
    /// inferred from genre/year/runtime/existing-tag signals so every title in the library
    /// works with the expanded mood list without re-tagging all ~270 entries by hand.
    var effectiveMoodTags: Set<String> {
        var tags = Set(moodTags)
        for g in genres {
            switch g {
            case "Adventure": tags.insert("adventurous")
            case "Horror": tags.insert("dark"); tags.insert("chilling")
            case "Crime": tags.insert("gritty"); tags.insert("dark")
            case "History": tags.insert("epic")
            case "Fantasy": tags.insert("epic")
            case "War": tags.insert("gritty"); tags.insert("epic")
            case "Family": tags.insert("heartwarming"); tags.insert("feelgood")
            case "Comedy": tags.insert("feelgood")
            case "Mystery": tags.insert("mindbending")
            case "Sci-Fi": tags.insert("mindbending")
            case "Musical", "Music": tags.insert("feelgood")
            default: break
            }
        }
        if moodTags.contains("weird") { tags.insert("quirky"); tags.insert("mindbending") }
        if moodTags.contains("cozy") { tags.insert("heartwarming") }
        if moodTags.contains("tense") { tags.insert("chilling") }
        if moodTags.contains("exciting") { tags.insert("adventurous") }
        if year < 2000 { tags.insert("nostalgic") }
        if runtimeMins >= 135 { tags.insert("epic") }
        return tags
    }
}

/// A mood-tagged deck of movies. Free decks ship with the app; Pro unlocks the rest.
struct MovieDeck: Identifiable, Equatable {
    let id: String
    let name: String
    let symbol: String
    let isFree: Bool
    let movies: [Movie]

    static func deck(id: String) -> MovieDeck? { all.first { $0.id == id } }

    static let all: [MovieDeck] = [cozy, funny, tense, weird, romantic, exciting, family, prestige, classics]
}

enum MoodTag: String, CaseIterable, Identifiable {
    case cozy, funny, tense, weird, romantic, exciting
    case adventurous, dark, nostalgic, mindbending, feelgood, epic, quirky, chilling, heartwarming, gritty
    var id: String { rawValue }
    var label: String { self == .mindbending ? "Mind-Bending" : rawValue.capitalized }
    var symbol: String {
        switch self {
        case .cozy: return "cup.and.saucer.fill"
        case .funny: return "face.smiling.fill"
        case .tense: return "bolt.fill"
        case .weird: return "sparkle"
        case .romantic: return "heart.fill"
        case .exciting: return "play.rectangle.fill"
        case .adventurous: return "map.fill"
        case .dark: return "moon.stars.fill"
        case .nostalgic: return "clock.arrow.circlepath"
        case .mindbending: return "brain.head.profile"
        case .feelgood: return "sun.max.fill"
        case .epic: return "crown.fill"
        case .quirky: return "questionmark.circle.fill"
        case .chilling: return "eye.fill"
        case .heartwarming: return "figure.2.and.child.holdinghands"
        case .gritty: return "flame.fill"
        }
    }
}
