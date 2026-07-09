import Foundation

/// Fetches poster artwork via Apple's own public iTunes Search API — no account, no API key,
/// no third-party service. Movies use a general search filtered to feature-movie results; TV
/// shows use the tvSeason entity to get the show's own artwork instead of an episode still.
actor PosterService {
    static let shared = PosterService()

    private var cache: [String: URL] = [:]
    private var inFlight: [String: Task<URL?, Never>] = [:]

    func posterURL(for movie: Movie) async -> URL? {
        // TMDB-sourced cards already carry their own poster path — skip the iTunes lookup.
        if let posterPath = movie.posterPath {
            return URL(string: "https://image.tmdb.org/t/p/w500\(posterPath)")
        }
        if let cached = cache[movie.id] { return cached }
        if let existing = inFlight[movie.id] { return await existing.value }

        let task = Task<URL?, Never> { [movie] in
            let url = await Self.fetch(movie: movie)
            return url
        }
        inFlight[movie.id] = task
        let result = await task.value
        inFlight[movie.id] = nil
        if let result { cache[movie.id] = result }
        return result
    }

    private static func fetch(movie: Movie) async -> URL? {
        var components = URLComponents(string: "https://itunes.apple.com/search")!
        components.queryItems = [
            URLQueryItem(name: "term", value: movie.title),
            URLQueryItem(name: "country", value: "us"),
            URLQueryItem(name: "limit", value: "10")
        ]
        if movie.mediaType == .tv {
            components.queryItems?.append(URLQueryItem(name: "entity", value: "tvSeason"))
        }
        guard let url = components.url else { return nil }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoded = try JSONDecoder().decode(ITunesResponse.self, from: data)
            let match: ITunesResult?
            if movie.mediaType == .tv {
                match = decoded.results.first
            } else {
                match = decoded.results.first { $0.kind == "feature-movie" } ?? decoded.results.first
            }
            guard let artwork = match?.artworkUrl100 else { return nil }
            let highRes = artwork.replacingOccurrences(of: "100x100bb", with: "600x600bb")
            return URL(string: highRes)
        } catch {
            return nil
        }
    }
}

private struct ITunesResponse: Decodable {
    let results: [ITunesResult]
}

private struct ITunesResult: Decodable {
    let kind: String?
    let artworkUrl100: String?
}
