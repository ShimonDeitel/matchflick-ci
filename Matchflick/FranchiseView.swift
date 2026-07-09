import SwiftUI

/// "The entire franchise" — every movie in the same TMDB collection as the one currently being
/// previewed, tap any to open its own full preview (which can chain further if it also belongs
/// to a collection).
struct FranchiseView: View {
    let collectionName: String
    let collectionId: Int
    @AppStorage(GamePrefs.tmdbApiKeyKey) private var tmdbApiKey = GamePrefs.defaultTMDBApiKey

    @State private var movies: [Movie] = []
    @State private var loading = true
    @State private var detailMovie: Movie?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                MatchflickBackground()
                if loading {
                    ProgressView().controlSize(.large)
                } else if movies.isEmpty {
                    Text("Couldn't load this collection.").foregroundStyle(.secondary)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(movies) { movie in
                                Button {
                                    Haptics.tap(); detailMovie = movie
                                } label: {
                                    HStack(spacing: 12) {
                                        PosterView(movie: movie)
                                            .frame(width: 70, height: 100)
                                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(movie.title).font(.body.weight(.bold)).foregroundStyle(.primary)
                                            Text(String(movie.year)).font(.caption).foregroundStyle(.secondary)
                                            Text(movie.premise).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                                        }
                                        Spacer(minLength: 0)
                                    }
                                    .padding(12)
                                    .background(Color.matchflickCard, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .navigationTitle(collectionName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
            .sheet(item: $detailMovie) { movie in MovieDetailView(movie: movie) }
            .task {
                movies = await TMDBDetails.fetchCollectionMovies(collectionId: collectionId, apiKey: tmdbApiKey)
                loading = false
            }
        }
    }
}
