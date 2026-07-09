import SwiftUI

/// Tap-to-preview sheet: poster, info, an embedded trailer search, ratings/where-to-watch
/// (via TMDB), and the triage buttons (with a board picker if Pro custom boards exist).
struct MovieDetailView: View {
    let movie: Movie

    @EnvironmentObject var appModel: AppModel
    @Environment(\.dismiss) private var dismiss
    @AppStorage(GamePrefs.tmdbApiKeyKey) private var tmdbApiKey = GamePrefs.defaultTMDBApiKey

    @State private var showTrailer = false
    @State private var ratingInfo: MovieRatingInfo?
    @State private var loadingRatings = false
    @State private var collectionInfo: TMDBDetails.CollectionInfo?
    @State private var showEpisodeGuide = false
    @State private var showFranchise = false

    private var currentEntry: WatchlistEntry? { appModel.watchlistEntry(for: movie.id) }
    private var currentStatus: WatchlistStatus? { currentEntry?.status }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    PosterHeaderImage(movie: movie)
                    infoSection
                    ratingsSection
                    triageButtons
                }
                .padding(20)
            }
            .navigationTitle(movie.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
            .task {
                await loadRatings()
                if movie.mediaType == .movie, let tmdbId = movie.tmdbId {
                    collectionInfo = await TMDBDetails.fetchCollection(forMovieId: tmdbId, apiKey: tmdbApiKey)
                }
            }
        }
        .sheet(isPresented: $showTrailer) {
            NavigationStack {
                TrailerWebView(movie: movie)
                    .navigationTitle("Trailer")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) { Button("Done") { showTrailer = false } }
                    }
            }
        }
        .sheet(isPresented: $showEpisodeGuide) { EpisodeGuideView(show: movie) }
        .sheet(isPresented: $showFranchise) {
            if let collectionInfo {
                FranchiseView(collectionName: collectionInfo.name, collectionId: collectionInfo.id)
            }
        }
    }

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(movie.mediaType.label, systemImage: movie.mediaType.symbol)
                    .font(.caption.weight(.bold)).foregroundStyle(.white)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Color.matchflickAccent, in: Capsule())
                Text(String(movie.year)).font(.subheadline).foregroundStyle(.secondary)
                if movie.runtimeMins > 0 {
                    Text("\(movie.runtimeMins)m").font(.subheadline).foregroundStyle(.secondary)
                }
            }
            FlowLayout(spacing: 6) {
                ForEach(movie.genres, id: \.self) { g in
                    Text(g).font(.caption.weight(.semibold)).foregroundStyle(Color.matchflickAccent)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color.matchflickField, in: Capsule())
                }
            }
            Text(movie.premise).font(.body).foregroundStyle(.secondary)
            HStack(spacing: 12) {
                Button { showTrailer = true } label: {
                    Label("Watch Trailer", systemImage: "play.rectangle.fill")
                }
                .softButton()
                .accessibilityIdentifier("detail-trailer")

                ShareLink(item: "\(movie.title) (\(movie.year)) — swiping on Minder") {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                .softButton()
                .accessibilityIdentifier("detail-share")
            }
            if movie.mediaType == .tv, movie.tmdbId != nil {
                Button { showEpisodeGuide = true } label: {
                    Label("Episode Guide", systemImage: "list.number")
                }
                .softButton()
                .accessibilityIdentifier("detail-episode-guide")
            } else if let collectionInfo {
                Button { showFranchise = true } label: {
                    Label("More in \(collectionInfo.name)", systemImage: "square.stack.fill")
                }
                .softButton()
                .accessibilityIdentifier("detail-franchise")
            }
        }
    }

    @ViewBuilder
    private var ratingsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if loadingRatings {
                ProgressView()
            } else if let ratingInfo {
                HStack {
                    Image(systemName: "star.fill").foregroundStyle(Color.matchflickAccent)
                    Text(String(format: "%.1f / 10", ratingInfo.voteAverage)).font(.headline)
                    Text("(\(ratingInfo.voteCount) votes)").font(.caption).foregroundStyle(.secondary)
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                Label("Where to Watch", systemImage: "tv.and.mediabox.fill").font(.subheadline.weight(.semibold))
                if let ratingInfo, !ratingInfo.providers.isEmpty {
                    FlowLayout(spacing: 8) {
                        ForEach(ratingInfo.providers, id: \.self) { provider in
                            HStack(spacing: 4) {
                                Image(systemName: "play.tv.fill").font(.caption2)
                                Text(provider).font(.caption.weight(.semibold))
                            }
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(Color.matchflickAccent.opacity(0.15), in: Capsule())
                            .foregroundStyle(Color.matchflickAccent)
                        }
                    }
                    if let link = ratingInfo.watchLink {
                        Link(destination: link) {
                            Label("See All Streaming Options", systemImage: "arrow.up.right.square.fill")
                                .font(.caption.weight(.semibold))
                        }
                        .padding(.top, 2)
                        .accessibilityIdentifier("watch-link")
                    }
                } else if !loadingRatings {
                    Text("No streaming availability found for your region.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .padding(14)
            .background(Color.matchflickCard2, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private var triageButtons: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                triageButton(.wantToWatch, label: "Want to Watch", symbol: "checkmark.circle.fill")
                triageButton(.maybe, label: "Maybe", symbol: "cube.fill")
                Button {
                    Haptics.tap()
                    appModel.setWatchlistStatus(nil, for: movie)
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "xmark.circle.fill").font(.title3)
                        Text("Not Interested").font(.caption2)
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(currentStatus == nil ? .secondary : .primary)
                    .padding(.vertical, 10)
                    .background(Color.matchflickField, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            if hasCustomBoards {
                Menu {
                    ForEach(appModel.boards) { board in
                        Button {
                            Haptics.tap()
                            appModel.setWatchlistStatus(board.kind, for: movie, boardID: board.id)
                            PreferenceEngine.recordStrongLike(genres: movie.genres)
                        } label: {
                            Label(board.name, systemImage: board.symbol)
                        }
                    }
                } label: {
                    Label("Choose a Specific Board…", systemImage: "list.bullet")
                        .font(.caption.weight(.semibold))
                }
            }
        }
    }

    private var hasCustomBoards: Bool { appModel.boards.contains { !$0.isDefault } }

    private func triageButton(_ status: WatchlistStatus, label: String, symbol: String) -> some View {
        let selected = currentStatus == status
        return Button {
            Haptics.tap()
            appModel.setWatchlistStatus(selected ? nil : status, for: movie)
            if !selected { PreferenceEngine.recordStrongLike(genres: movie.genres) }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: symbol).font(.title3)
                Text(label).font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .foregroundStyle(selected ? .white : .primary)
            .padding(.vertical, 10)
            .background(selected ? Color.matchflickAccent : Color.matchflickField,
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("triage-\(status.rawValue)")
    }

    private func loadRatings() async {
        guard !tmdbApiKey.isEmpty else { return }
        loadingRatings = true
        ratingInfo = await RatingsService.shared.info(for: movie, apiKey: tmdbApiKey)
        loadingRatings = false
    }
}

private struct PosterHeaderImage: View {
    let movie: Movie
    @State private var url: URL?

    var body: some View {
        Group {
            if let url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image): image.resizable().scaledToFill()
                    default: placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(height: 260)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.15), radius: 10, y: 4)
        .task(id: movie.id) { url = await PosterService.shared.posterURL(for: movie) }
    }

    private var placeholder: some View {
        Rectangle().fill(Color.matchflickCard2)
            .overlay(Image(systemName: movie.mediaType.symbol).font(.system(size: 40)).foregroundStyle(.secondary))
    }
}
