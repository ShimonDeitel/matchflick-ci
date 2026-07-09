import Foundation

struct MovieRatingInfo {
    let voteAverage: Double
    let voteCount: Int
    let providers: [String]
    /// The TMDB "where to watch" page for this title (JustWatch-sourced) — a real, working link.
    let watchLink: URL?
}

/// Ratings + "where to watch" data via TMDB (the same account/key used for the live catalog).
actor RatingsService {
    static let shared = RatingsService()
    private var cache: [String: MovieRatingInfo?] = [:]

    func info(for movie: Movie, apiKey: String) async -> MovieRatingInfo? {
        guard !apiKey.isEmpty else { return nil }
        let cacheKey = "\(apiKey.prefix(6))-\(movie.id)"
        if let cached = cache[cacheKey] { return cached }

        let result = await Self.fetch(movie: movie, apiKey: apiKey)
        cache[cacheKey] = result
        return result
    }

    private static func fetch(movie: Movie, apiKey: String) async -> MovieRatingInfo? {
        let path = movie.mediaType == .tv ? "tv" : "movie"

        // Cards from the live TMDB catalog already know their id — skip the search step.
        var tmdbId = movie.tmdbId
        var voteAverage: Double = 0
        var voteCount: Int = 0

        if tmdbId == nil {
            var search = URLComponents(string: "https://api.themoviedb.org/3/search/\(path)")!
            search.queryItems = [
                URLQueryItem(name: "api_key", value: apiKey),
                URLQueryItem(name: "query", value: movie.title)
            ]
            guard let searchURL = search.url,
                  let (data, _) = try? await URLSession.shared.data(from: searchURL),
                  let decoded = try? JSONDecoder().decode(TMDBSearchResponse.self, from: data),
                  let first = decoded.results.first else { return nil }
            tmdbId = first.id
            voteAverage = first.voteAverage ?? 0
            voteCount = first.voteCount ?? 0
        } else {
            var detail = URLComponents(string: "https://api.themoviedb.org/3/\(path)/\(tmdbId!)")!
            detail.queryItems = [URLQueryItem(name: "api_key", value: apiKey)]
            if let detailURL = detail.url,
               let (data, _) = try? await URLSession.shared.data(from: detailURL),
               let decoded = try? JSONDecoder().decode(TMDBTitle.self, from: data) {
                voteAverage = decoded.voteAverage ?? 0
                voteCount = decoded.voteCount ?? 0
            }
        }

        guard let id = tmdbId else { return nil }
        var providersComponents = URLComponents(string: "https://api.themoviedb.org/3/\(path)/\(id)/watch/providers")!
        providersComponents.queryItems = [URLQueryItem(name: "api_key", value: apiKey)]
        var providerNames: [String] = []
        var link: URL?
        if let providersURL = providersComponents.url,
           let (pData, _) = try? await URLSession.shared.data(from: providersURL),
           let decodedProviders = try? JSONDecoder().decode(TMDBWatchProvidersResponse.self, from: pData),
           let usInfo = decodedProviders.results["US"] {
            providerNames = (usInfo.flatrate ?? []).map(\.providerName)
            link = usInfo.link.flatMap(URL.init)
        }

        return MovieRatingInfo(voteAverage: voteAverage, voteCount: voteCount, providers: providerNames, watchLink: link)
    }
}

private struct TMDBSearchResponse: Decodable {
    let results: [TMDBTitle]
}
private struct TMDBTitle: Decodable {
    let id: Int
    let voteAverage: Double?
    let voteCount: Int?
    enum CodingKeys: String, CodingKey {
        case id
        case voteAverage = "vote_average"
        case voteCount = "vote_count"
    }
}
private struct TMDBWatchProvidersResponse: Decodable {
    let results: [String: TMDBCountryProviders]
}
private struct TMDBCountryProviders: Decodable {
    let flatrate: [TMDBProvider]?
    let link: String?
}
private struct TMDBProvider: Decodable {
    let providerName: String
    enum CodingKeys: String, CodingKey {
        case providerName = "provider_name"
    }
}
