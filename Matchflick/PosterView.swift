import SwiftUI

/// Loads poster art from Apple's iTunes Search API (see PosterService), falling back to a flat
/// icon placeholder if no artwork is found or the request fails. Shared by the swipe deck, the
/// match screen, and the Want to Watch / Maybe card lists.
struct PosterView: View {
    let movie: Movie
    @State private var url: URL?
    @State private var failed = false

    var body: some View {
        ZStack {
            if let url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .failure:
                        placeholder
                    default:
                        placeholder.overlay(ProgressView())
                    }
                }
            } else if failed {
                placeholder
            } else {
                placeholder.overlay(ProgressView())
            }
        }
        .frame(maxWidth: .infinity)
        .background(Color.matchflickCard2)
        .task(id: movie.id) {
            url = nil; failed = false
            let result = await PosterService.shared.posterURL(for: movie)
            if let result { url = result } else { failed = true }
        }
    }

    private var placeholder: some View {
        Rectangle()
            .fill(Color.matchflickCard2)
            .overlay(Image(systemName: movie.mediaType.symbol).font(.system(size: 40)).foregroundStyle(.secondary))
    }
}
