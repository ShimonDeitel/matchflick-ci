import Foundation

/// Fetches the deeper detail TMDB doesn't return from a discover/recommendations call: a movie's
/// franchise/collection (other entries you can click through to) and a TV show's full season and
/// episode guide. Kept separate from TMDBCatalog since these are per-title lookups, not deck-building.
enum TMDBDetails {
    struct CollectionInfo {
        let id: Int
        let name: String
        let posterPath: String?
    }

    struct SeasonSummary: Identifiable {
        let id: Int
        let seasonNumber: Int
        let name: String
        let episodeCount: Int
        let posterPath: String?
    }

    struct Episode: Identifiable {
        let id: Int
        let episodeNumber: Int
        let name: String
        let overview: String
        let airDate: String
        let stillPath: String?
    }

    /// Looks up the collection (franchise) a movie belongs to, if any.
    static func fetchCollection(forMovieId tmdbId: Int, apiKey: String) async -> CollectionInfo? {
        guard !apiKey.isEmpty else { return nil }
        var components = URLComponents(string: "https://api.themoviedb.org/3/movie/\(tmdbId)")!
        components.queryItems = [URLQueryItem(name: "api_key", value: apiKey)]
        guard let url = components.url,
              let (data, _) = try? await URLSession.shared.data(from: url),
              let decoded = try? JSONDecoder().decode(MovieDetailResponse.self, from: data),
              let collection = decoded.belongsToCollection else { return nil }
        return CollectionInfo(id: collection.id, name: collection.name, posterPath: collection.posterPath)
    }

    /// All movies in a collection/franchise, as swipeable Movie cards you can tap through.
    static func fetchCollectionMovies(collectionId: Int, apiKey: String) async -> [Movie] {
        guard !apiKey.isEmpty else { return [] }
        var components = URLComponents(string: "https://api.themoviedb.org/3/collection/\(collectionId)")!
        components.queryItems = [URLQueryItem(name: "api_key", value: apiKey)]
        guard let url = components.url,
              let (data, _) = try? await URLSession.shared.data(from: url),
              let decoded = try? JSONDecoder().decode(CollectionResponse.self, from: data) else { return [] }
        return decoded.parts.compactMap { item -> Movie? in
            guard let title = item.title else { return nil }
            let year = Int((item.releaseDate ?? "").prefix(4)) ?? 2000
            return Movie(id: "tmdb-movie-\(item.id)", title: title, year: year, genres: [],
                         premise: item.overview?.isEmpty == false ? item.overview! : "No description available.",
                         moodTags: [], runtimeMins: 0, mediaType: .movie, tmdbId: item.id, posterPath: item.posterPath)
        }
    }

    /// The season list for a TV show — tap a season to load its episodes.
    static func fetchSeasons(forShowId tmdbId: Int, apiKey: String) async -> [SeasonSummary] {
        guard !apiKey.isEmpty else { return [] }
        var components = URLComponents(string: "https://api.themoviedb.org/3/tv/\(tmdbId)")!
        components.queryItems = [URLQueryItem(name: "api_key", value: apiKey)]
        guard let url = components.url,
              let (data, _) = try? await URLSession.shared.data(from: url),
              let decoded = try? JSONDecoder().decode(TVDetailResponse.self, from: data) else { return [] }
        return (decoded.seasons ?? [])
            .filter { $0.seasonNumber > 0 }
            .map { SeasonSummary(id: $0.id, seasonNumber: $0.seasonNumber, name: $0.name,
                                 episodeCount: $0.episodeCount ?? 0, posterPath: $0.posterPath) }
    }

    static func fetchEpisodes(showId: Int, seasonNumber: Int, apiKey: String) async -> [Episode] {
        guard !apiKey.isEmpty else { return [] }
        var components = URLComponents(string: "https://api.themoviedb.org/3/tv/\(showId)/season/\(seasonNumber)")!
        components.queryItems = [URLQueryItem(name: "api_key", value: apiKey)]
        guard let url = components.url,
              let (data, _) = try? await URLSession.shared.data(from: url),
              let decoded = try? JSONDecoder().decode(SeasonDetailResponse.self, from: data) else { return [] }
        return (decoded.episodes ?? []).map {
            Episode(id: $0.id, episodeNumber: $0.episodeNumber, name: $0.name,
                    overview: $0.overview ?? "", airDate: $0.airDate ?? "", stillPath: $0.stillPath)
        }
    }
}

private struct MovieDetailResponse: Decodable {
    let belongsToCollection: BelongsToCollection?
    enum CodingKeys: String, CodingKey { case belongsToCollection = "belongs_to_collection" }
}

private struct BelongsToCollection: Decodable {
    let id: Int
    let name: String
    let posterPath: String?
    enum CodingKeys: String, CodingKey { case id, name; case posterPath = "poster_path" }
}

private struct CollectionResponse: Decodable {
    let parts: [CollectionPart]
}

private struct CollectionPart: Decodable {
    let id: Int
    let title: String?
    let overview: String?
    let releaseDate: String?
    let posterPath: String?
    enum CodingKeys: String, CodingKey {
        case id, title, overview
        case releaseDate = "release_date"
        case posterPath = "poster_path"
    }
}

private struct TVDetailResponse: Decodable {
    let seasons: [TVSeason]?
}

private struct TVSeason: Decodable {
    let id: Int
    let seasonNumber: Int
    let name: String
    let episodeCount: Int?
    let posterPath: String?
    enum CodingKeys: String, CodingKey {
        case id, name
        case seasonNumber = "season_number"
        case episodeCount = "episode_count"
        case posterPath = "poster_path"
    }
}

private struct SeasonDetailResponse: Decodable {
    let episodes: [TVEpisode]?
}

private struct TVEpisode: Decodable {
    let id: Int
    let episodeNumber: Int
    let name: String
    let overview: String?
    let airDate: String?
    let stillPath: String?
    enum CodingKeys: String, CodingKey {
        case id, name, overview
        case episodeNumber = "episode_number"
        case airDate = "air_date"
        case stillPath = "still_path"
    }
}
