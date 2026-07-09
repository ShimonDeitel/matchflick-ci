import Foundation

/// Builds a swipe deck live from the full TMDB catalog (effectively "every movie/show ever
/// made") instead of the small bundled library — filtered by mood (mapped to TMDB genres),
/// media type, and decade. Falls back to the bundled library if there's no key or the request
/// fails, so the app still works offline or if TMDB is unreachable.
enum TMDBCatalog {
    private static let movieGenres: [MoodTag: [Int]] = [
        .cozy: [35, 10751], .funny: [35], .tense: [53, 80], .weird: [9648, 878],
        .romantic: [10749], .exciting: [28, 12], .adventurous: [12], .dark: [27, 80],
        .nostalgic: [18], .mindbending: [878, 9648], .feelgood: [35, 10751],
        .epic: [12, 14, 36], .quirky: [35], .chilling: [27, 53], .heartwarming: [10751, 18],
        .gritty: [80, 10752]
    ]
    private static let tvGenres: [MoodTag: [Int]] = [
        .cozy: [35, 10751], .funny: [35], .tense: [80, 9648], .weird: [9648, 10765],
        .romantic: [10749], .exciting: [10759], .adventurous: [10759], .dark: [80, 9648],
        .nostalgic: [18], .mindbending: [10765, 9648], .feelgood: [35, 10751],
        .epic: [10759, 10765], .quirky: [35], .chilling: [9648, 80], .heartwarming: [10751, 18],
        .gritty: [80, 10768]
    ]
    private static let genreNames: [Int: String] = [
        28: "Action", 12: "Adventure", 16: "Animation", 35: "Comedy", 80: "Crime", 99: "Documentary",
        18: "Drama", 10751: "Family", 14: "Fantasy", 36: "History", 27: "Horror", 10402: "Music",
        9648: "Mystery", 10749: "Romance", 878: "Sci-Fi", 53: "Thriller", 10752: "War", 37: "Western",
        10759: "Action & Adventure", 10765: "Sci-Fi & Fantasy", 10768: "War & Politics", 10762: "Kids",
        10764: "Reality", 10766: "Soap", 10767: "Talk", 10763: "News"
    ]

    static func fetchDeck(moods: Set<MoodTag>, filter: MediaFilter, yearRange: ClosedRange<Int>,
                          apiKey: String, maxMaturity: String? = nil, limit: Int = 20) async -> [Movie]? {
        guard !apiKey.isEmpty else { return nil }
        var pool: [(movie: Movie, voteAverage: Double)] = []
        if filter.matches(.movie) {
            // Fan out across several random pages concurrently so a single deck draws from a much
            // wider slice of the catalog instead of always the same handful of top-popularity pages.
            let pages = randomPages()
            let batches = await withTaskGroup(of: [(Movie, Double)].self) { group -> [[(Movie, Double)]] in
                for page in pages {
                    group.addTask {
                        await fetchOne(mediaType: .movie, moods: moods, yearRange: yearRange, apiKey: apiKey,
                                       maxMaturity: maxMaturity, page: page) ?? []
                    }
                }
                var results: [[(Movie, Double)]] = []
                for await batch in group { results.append(batch) }
                return results
            }
            pool += batches.flatMap { $0 }
        }
        if filter.matches(.tv) {
            // Note: TMDB's discover/tv endpoint has no certification filter, so the maturity
            // slider only narrows movie results — there's no equivalent to apply to TV here.
            let pages = randomPages()
            let batches = await withTaskGroup(of: [(Movie, Double)].self) { group -> [[(Movie, Double)]] in
                for page in pages {
                    group.addTask {
                        await fetchOne(mediaType: .tv, moods: moods, yearRange: yearRange, apiKey: apiKey,
                                       maxMaturity: nil, page: page) ?? []
                    }
                }
                var results: [[(Movie, Double)]] = []
                for await batch in group { results.append(batch) }
                return results
            }
            pool += batches.flatMap { $0 }
        }
        guard !pool.isEmpty else { return nil }

        // Never resurface something already swiped on — the single biggest practical complaint
        // with a "deck" model is seeing the same titles again.
        let seen = PreferenceEngine.seenMovieIds
        var byId: [String: (movie: Movie, voteAverage: Double)] = [:]
        for entry in pool where !seen.contains(entry.movie.id) { byId[entry.movie.id] = entry }

        // Rank by a blend of learned genre affinity AND actual quality (TMDB's vote average),
        // so it's not purely genre-chasing — within a liked genre, better-rated titles surface
        // first. Affinity is on a roughly -20...20 scale; vote average is 0...10, weighted down
        // so a single strong affinity swipe still outweighs a marginal rating difference.
        let ranked = byId.values.sorted { a, b in
            let scoreA = PreferenceEngine.score(for: a.movie.genres) + a.voteAverage * 0.6
            let scoreB = PreferenceEngine.score(for: b.movie.genres) + b.voteAverage * 0.6
            return scoreA > scoreB
        }
        let topSlice = Array(ranked.prefix(max(limit * 3, 30)))
        return topSlice.shuffled().prefix(limit).map { $0.movie }
    }

    /// Several distinct random pages (instead of one) so a single deck build already spans a
    /// wide slice of the catalog — supports genuinely surfacing "every title ever made" rather
    /// than looping over the same handful of top-popularity pages.
    private static func randomPages(count: Int = 4, upperBound: Int = 40) -> [Int] {
        var pages = Set<Int>()
        while pages.count < count { pages.insert(Int.random(in: 1...upperBound)) }
        return Array(pages)
    }

    private static func fetchOne(mediaType: MediaType, moods: Set<MoodTag>, yearRange: ClosedRange<Int>,
                                  apiKey: String, maxMaturity: String? = nil, page: Int) async -> [(Movie, Double)]? {
        let genreMap = mediaType == .movie ? movieGenres : tvGenres
        let genreIDs = Set(moods.flatMap { genreMap[$0] ?? [] })
        let path = mediaType == .movie ? "movie" : "tv"
        var components = URLComponents(string: "https://api.themoviedb.org/3/discover/\(path)")!
        var items = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "sort_by", value: "popularity.desc"),
            // Lower than before (was 20) so lesser-known titles can surface too — still enough
            // of a floor to filter out zero-data junk entries.
            URLQueryItem(name: "vote_count.gte", value: "5"),
            URLQueryItem(name: "page", value: String(page))
        ]
        if !genreIDs.isEmpty {
            // Pipe = OR, so any of the mood's mapped genres qualify (e.g. "cozy" = Comedy OR Family).
            items.append(URLQueryItem(name: "with_genres", value: genreIDs.map(String.init).joined(separator: "|")))
        }
        // The real learning step: steer away from genres the user has consistently swiped no on.
        let candidateNames = genreIDs.compactMap { genreNames[$0] }
        let avoided = PreferenceEngine.dislikedGenres(among: candidateNames)
        if !avoided.isEmpty {
            let avoidedIDs = genreIDs.filter { genreNames[$0].map(avoided.contains) ?? false }
            if !avoidedIDs.isEmpty {
                items.append(URLQueryItem(name: "without_genres", value: avoidedIDs.map(String.init).joined(separator: "|")))
            }
        }
        let dateField = mediaType == .movie ? "primary_release_date" : "first_air_date"
        items.append(URLQueryItem(name: "\(dateField).gte", value: "\(yearRange.lowerBound)-01-01"))
        items.append(URLQueryItem(name: "\(dateField).lte", value: "\(yearRange.upperBound)-12-31"))
        if mediaType == .movie, let maxMaturity, maxMaturity != GamePrefs.maturityLevels.last {
            items.append(URLQueryItem(name: "certification_country", value: "US"))
            items.append(URLQueryItem(name: "certification.lte", value: maxMaturity))
        }
        components.queryItems = items
        guard let url = components.url else { return nil }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoded = try JSONDecoder().decode(TMDBDiscoverResponse.self, from: data)
            return decoded.results.compactMap { item -> (Movie, Double)? in
                guard let movie = toMovie(item, mediaType: mediaType) else { return nil }
                return (movie, item.voteAverage ?? 0)
            }
        } catch {
            return nil
        }
    }

    /// "Because you watched X" — TMDB's own recommendations endpoint when we have a TMDB id
    /// (the common case, since decks come from the live catalog), falling back to a genre-based
    /// discover query when the title only has an offline/bundled id.
    static func fetchRecommendations(for movie: Movie, apiKey: String, limit: Int = 8) async -> [Movie] {
        guard !apiKey.isEmpty else { return [] }
        if let tmdbId = movie.tmdbId {
            let path = movie.mediaType == .movie ? "movie" : "tv"
            var components = URLComponents(string: "https://api.themoviedb.org/3/\(path)/\(tmdbId)/recommendations")!
            components.queryItems = [URLQueryItem(name: "api_key", value: apiKey)]
            if let url = components.url,
               let (data, _) = try? await URLSession.shared.data(from: url),
               let decoded = try? JSONDecoder().decode(TMDBDiscoverResponse.self, from: data) {
                let recs = decoded.results.compactMap { toMovie($0, mediaType: movie.mediaType) }
                if !recs.isEmpty { return Array(recs.prefix(limit)) }
            }
        }
        // Fallback: genre-based discover using whatever genre names we have on hand.
        guard !movie.genres.isEmpty else { return [] }
        let genreIDs = Set(movie.genres.compactMap { name in genreNames.first { $0.value == name }?.key })
        guard !genreIDs.isEmpty else { return [] }
        let path = movie.mediaType == .movie ? "movie" : "tv"
        var components = URLComponents(string: "https://api.themoviedb.org/3/discover/\(path)")!
        components.queryItems = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "sort_by", value: "popularity.desc"),
            URLQueryItem(name: "with_genres", value: genreIDs.map(String.init).joined(separator: "|"))
        ]
        guard let url = components.url,
              let (data, _) = try? await URLSession.shared.data(from: url),
              let decoded = try? JSONDecoder().decode(TMDBDiscoverResponse.self, from: data) else { return [] }
        return decoded.results.compactMap { toMovie($0, mediaType: movie.mediaType) }
            .filter { $0.id != movie.id }
            .prefix(limit)
            .map { $0 }
    }

    private static func toMovie(_ item: TMDBDiscoverItem, mediaType: MediaType) -> Movie? {
        guard let title = item.title ?? item.name else { return nil }
        let dateString = item.releaseDate ?? item.firstAirDate ?? ""
        let year = Int(dateString.prefix(4)) ?? 2000
        let genres = (item.genreIds ?? []).compactMap { genreNames[$0] }
        return Movie(
            id: "tmdb-\(mediaType.rawValue)-\(item.id)",
            title: title,
            year: year,
            genres: genres,
            premise: item.overview?.isEmpty == false ? item.overview! : "No description available.",
            moodTags: [],
            runtimeMins: 0,
            mediaType: mediaType,
            tmdbId: item.id,
            posterPath: item.posterPath
        )
    }
}

private struct TMDBDiscoverResponse: Decodable {
    let results: [TMDBDiscoverItem]
}

private struct TMDBDiscoverItem: Decodable {
    let id: Int
    let title: String?
    let name: String?
    let overview: String?
    let releaseDate: String?
    let firstAirDate: String?
    let posterPath: String?
    let genreIds: [Int]?
    let voteAverage: Double?

    enum CodingKeys: String, CodingKey {
        case id, title, name, overview
        case releaseDate = "release_date"
        case firstAirDate = "first_air_date"
        case posterPath = "poster_path"
        case genreIds = "genre_ids"
        case voteAverage = "vote_average"
    }
}
