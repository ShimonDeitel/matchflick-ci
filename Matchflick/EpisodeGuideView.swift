import SwiftUI

/// Full season/episode guide for a TV show — pick a season, see every episode's title, air date,
/// and synopsis.
struct EpisodeGuideView: View {
    let show: Movie
    @AppStorage(GamePrefs.tmdbApiKeyKey) private var tmdbApiKey = GamePrefs.defaultTMDBApiKey

    @State private var seasons: [TMDBDetails.SeasonSummary] = []
    @State private var selectedSeason: TMDBDetails.SeasonSummary?
    @State private var episodes: [TMDBDetails.Episode] = []
    @State private var loadingSeasons = true
    @State private var loadingEpisodes = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                MatchflickBackground()
                if loadingSeasons {
                    ProgressView().controlSize(.large)
                } else if seasons.isEmpty {
                    Text("No episode guide found for this show.").foregroundStyle(.secondary)
                } else {
                    VStack(spacing: 0) {
                        seasonPicker
                        if loadingEpisodes {
                            Spacer()
                            ProgressView()
                            Spacer()
                        } else {
                            episodeList
                        }
                    }
                }
            }
            .navigationTitle(show.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
            .task {
                seasons = await TMDBDetails.fetchSeasons(forShowId: show.tmdbId ?? 0, apiKey: tmdbApiKey)
                loadingSeasons = false
                if let first = seasons.first { await select(first) }
            }
        }
    }

    private var seasonPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(seasons) { season in
                    let selected = selectedSeason?.id == season.id
                    Button {
                        Task { await select(season) }
                    } label: {
                        Text(season.name).font(.subheadline.weight(.medium))
                            .foregroundStyle(selected ? .white : .primary)
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(selected ? Color.matchflickAccent : Color.matchflickField, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
        }
    }

    private var episodeList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                ForEach(episodes) { ep in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("\(ep.episodeNumber). \(ep.name)").font(.body.weight(.bold))
                            Spacer()
                            if !ep.airDate.isEmpty {
                                Text(ep.airDate).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        if !ep.overview.isEmpty {
                            Text(ep.overview).font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.matchflickCard, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
            .padding(16)
        }
    }

    private func select(_ season: TMDBDetails.SeasonSummary) async {
        selectedSeason = season
        loadingEpisodes = true
        episodes = await TMDBDetails.fetchEpisodes(showId: show.tmdbId ?? 0, seasonNumber: season.seasonNumber, apiKey: tmdbApiKey)
        loadingEpisodes = false
    }
}
