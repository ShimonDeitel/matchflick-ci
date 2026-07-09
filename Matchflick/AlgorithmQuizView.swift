import SwiftUI

/// A short, retakeable quiz that seeds the genre-affinity model (see PreferenceEngine) — the
/// same idea as Instagram's "manage your recommendations" settings, scaled to what an on-device
/// app can actually do: it directly sets initial weights, it doesn't call out to any service.
struct AlgorithmQuizView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var favorites: Set<String> = []
    @State private var avoided: Set<String> = []

    private let allGenres = [
        "Comedy", "Drama", "Action", "Horror", "Romance", "Sci-Fi", "Thriller", "Fantasy",
        "Crime", "Mystery", "Family", "Adventure", "Documentary", "Animation"
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Pick a few genres you love and a few you'd rather skip. This directly sets your starting recommendations — every swipe after that keeps tuning it.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                Section("I love...") {
                    genreGrid(selection: $favorites, exclude: avoided)
                }
                Section("Not for me...") {
                    genreGrid(selection: $avoided, exclude: favorites)
                }
            }
            .navigationTitle("Tune Your Algorithm")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        PreferenceEngine.seed(favoriteGenres: Array(favorites), avoidedGenres: Array(avoided))
                        Haptics.success()
                        dismiss()
                    }
                    .disabled(favorites.isEmpty && avoided.isEmpty)
                }
            }
        }
    }

    private func genreGrid(selection: Binding<Set<String>>, exclude: Set<String>) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            ForEach(allGenres, id: \.self) { genre in
                let selected = selection.wrappedValue.contains(genre)
                let disabled = exclude.contains(genre)
                Button {
                    Haptics.tap()
                    if selected { selection.wrappedValue.remove(genre) } else { selection.wrappedValue.insert(genre) }
                } label: {
                    Text(genre)
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .foregroundStyle(selected ? .white : (disabled ? .secondary : .primary))
                        .background(selected ? Color.matchflickAccent : Color.matchflickField,
                                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(disabled)
                .opacity(disabled ? 0.4 : 1)
            }
        }
        .padding(.vertical, 4)
    }
}
