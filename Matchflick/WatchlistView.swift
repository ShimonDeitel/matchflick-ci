import SwiftUI

/// Shows titles the user tagged from the detail preview, one board at a time, as cards — tap
/// any card for the full preview, swipe left to delete or right to move to the other list, or
/// use the three per-card buttons. Creating and removing custom boards is free — Pro's only
/// benefit is unlimited swiping (see SwipeLimiter).
struct WatchlistView: View {
    let status: WatchlistStatus

    @EnvironmentObject var appModel: AppModel
    @State private var selectedBoardID: UUID?
    @State private var showNewBoard = false
    @State private var detailMovie: Movie?
    @State private var watchedAnimatingID: UUID?
    @State private var recommendFor: Movie?

    private var otherStatus: WatchlistStatus { status == .wantToWatch ? .maybe : .wantToWatch }

    private var boardsForKind: [WatchBoard] { appModel.boards(for: status) }
    private var selectedBoard: WatchBoard? {
        boardsForKind.first { $0.id == selectedBoardID } ?? boardsForKind.first
    }
    private var entries: [WatchlistEntry] {
        guard let board = selectedBoard else { return [] }
        return appModel.watchlist.filter { $0.status == status && ($0.boardID == board.id || $0.boardID == nil) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                MatchflickBackground()
                VStack(spacing: 0) {
                    boardPicker
                    if entries.isEmpty {
                        Spacer()
                        VStack(spacing: 12) {
                            Image(systemName: selectedBoard?.symbol ?? "tray")
                                .font(.system(size: 44, weight: .light)).foregroundStyle(.secondary)
                            Text("Nothing here yet").font(.headline)
                            Text("Tap the info button on any card during swiping to add one.")
                                .font(.subheadline).foregroundStyle(.secondary)
                                .multilineTextAlignment(.center).padding(.horizontal, 40)
                        }
                        Spacer()
                    } else {
                        List {
                            ForEach(entries) { entry in
                                watchlistCard(entry)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 7)
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                    }
                }
            }
            .navigationTitle(selectedBoard?.name ?? (status == .wantToWatch ? "Want to Watch" : "Maybe"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Haptics.tap(); showNewBoard = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                    .accessibilityIdentifier("new-board-\(status.rawValue)")
                }
            }
            .sheet(isPresented: $showNewBoard) { NewBoardView(kind: status) }
            .sheet(item: $detailMovie) { movie in MovieDetailView(movie: movie) }
            .sheet(item: $recommendFor) { movie in RecommendationsView(watched: movie) }
        }
    }

    private func watchlistCard(_ entry: WatchlistEntry) -> some View {
        let movie = entry.asMovie
        return VStack(spacing: 0) {
            Button {
                Haptics.tap(); detailMovie = movie
            } label: {
                HStack(alignment: .top, spacing: 12) {
                    PosterView(movie: movie)
                        .frame(width: 76, height: 108)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    VStack(alignment: .leading, spacing: 6) {
                        Text(entry.title).font(.body.weight(.bold)).foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)
                        Text(String(entry.year)).font(.subheadline).foregroundStyle(.secondary)
                        Label(entry.mediaType.label, systemImage: entry.mediaType.symbol)
                            .font(.caption.weight(.semibold)).foregroundStyle(Color.matchflickAccent)
                    }
                    Spacer(minLength: 0)
                }
            }
            .buttonStyle(.plain)
            .padding(14)

            if status == .wantToWatch {
                // Maybe cards drop these two buttons — swipe right to move to Want to Watch,
                // swipe left to delete (see swipeActions below) is the only interaction there now.
                HStack(spacing: 10) {
                    cardActionButton(symbol: "trash.fill", label: "Delete", tint: .red) {
                        appModel.deleteWatchlistEntry(entry)
                    }
                    cardActionButton(symbol: "cube.fill", label: "Maybe", tint: Color.matchflickAccent) {
                        appModel.moveWatchlistEntry(entry, to: otherStatus)
                    }
                }
                .padding(.horizontal, 14).padding(.bottom, 14)
            }

            if status == .wantToWatch {
                Button {
                    watchThis(entry, movie: movie)
                } label: {
                    Text("I Watched This")
                        .font(.subheadline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .background(Color.matchflickAccent)
                .accessibilityIdentifier("watched-\(entry.id)")
            }
        }
        .background(Color.matchflickCard, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .offset(y: watchedAnimatingID == entry.id ? 600 : 0)
        .opacity(watchedAnimatingID == entry.id ? 0 : 1)
        .animation(.easeIn(duration: 0.55), value: watchedAnimatingID)
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                appModel.moveWatchlistEntry(entry, to: otherStatus)
            } label: {
                Label(otherStatus == .wantToWatch ? "Want to Watch" : "Maybe",
                      systemImage: otherStatus == .wantToWatch ? "checkmark.circle.fill" : "cube.fill")
            }
            .tint(Color.matchflickAccent)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                appModel.deleteWatchlistEntry(entry)
            } label: {
                Label("Delete", systemImage: "trash.fill")
            }
        }
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets())
    }

    /// Big satisfying drop animation, then the entry becomes a Watch History record and a
    /// non-swipe recommendations list appears — "here's what else you might like."
    private func watchThis(_ entry: WatchlistEntry, movie: Movie) {
        Haptics.success()
        withAnimation(.easeIn(duration: 0.55)) { watchedAnimatingID = entry.id }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            appModel.markWatched(entry)
            watchedAnimatingID = nil
            recommendFor = movie
        }
    }

    private func cardActionButton(symbol: String, label: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: { Haptics.tap(); action() }) {
            cardActionButtonLabel(symbol: symbol, label: label, tint: tint)
        }
        .buttonStyle(.plain)
    }

    private func cardActionButtonLabel(symbol: String, label: String, tint: Color) -> some View {
        VStack(spacing: 3) {
            Image(systemName: symbol).font(.body).foregroundStyle(tint)
            Text(label).font(.caption2.weight(.semibold)).foregroundStyle(.secondary).lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.matchflickField, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    @ViewBuilder
    private var boardPicker: some View {
        if boardsForKind.count > 1 {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(boardsForKind) { board in
                        boardChip(board)
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 10)
            }
        }
    }

    private func boardChip(_ board: WatchBoard) -> some View {
        let selected = selectedBoard?.id == board.id
        return Button {
            Haptics.tap(); selectedBoardID = board.id
        } label: {
            HStack(spacing: 6) {
                Image(systemName: board.symbol).font(.caption)
                Text(board.name).font(.subheadline.weight(.medium))
            }
            .foregroundStyle(selected ? .white : .primary)
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(selected ? Color.matchflickAccent : Color.matchflickField, in: Capsule())
        }
        .buttonStyle(.plain)
        .contextMenu {
            if !board.isDefault {
                Button("Delete Board", role: .destructive) { appModel.deleteBoard(board) }
            }
        }
    }
}

/// Free board creator: a name field and a curated symbol palette.
private struct NewBoardView: View {
    let kind: WatchlistStatus
    @EnvironmentObject var appModel: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var symbol = WatchBoard.symbolPalette.first!

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("e.g. Date Night, Horror Marathon", text: $name)
                }
                Section("Icon") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                        ForEach(WatchBoard.symbolPalette, id: \.self) { s in
                            Button {
                                symbol = s
                            } label: {
                                Image(systemName: s)
                                    .font(.title3)
                                    .frame(width: 40, height: 40)
                                    .foregroundStyle(symbol == s ? .white : .primary)
                                    .background(symbol == s ? Color.matchflickAccent : Color.matchflickField,
                                                in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
            .navigationTitle("New Board")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Create") {
                        appModel.createBoard(name: name.isEmpty ? "New Board" : name, symbol: symbol, kind: kind)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

/// "Because you watched X" — a plain scrollable list, not a swipe deck, shown right after
/// marking something watched. Tapping a card opens the same full preview as everywhere else.
private struct RecommendationsView: View {
    let watched: Movie
    @Environment(\.dismiss) private var dismiss
    @AppStorage(GamePrefs.tmdbApiKeyKey) private var tmdbApiKey = GamePrefs.defaultTMDBApiKey
    @State private var recommendations: [Movie] = []
    @State private var loading = true
    @State private var detailMovie: Movie?

    var body: some View {
        NavigationStack {
            ZStack {
                MatchflickBackground()
                if loading {
                    ProgressView().controlSize(.large)
                } else if recommendations.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "sparkles").font(.system(size: 36)).foregroundStyle(.secondary)
                        Text("No recommendations found").font(.subheadline).foregroundStyle(.secondary)
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 10) {
                            Text("Because you watched \(watched.title)")
                                .font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                                .padding(.top, 8)
                            ForEach(recommendations) { movie in
                                Button {
                                    Haptics.tap(); detailMovie = movie
                                } label: {
                                    HStack(spacing: 12) {
                                        PosterView(movie: movie)
                                            .frame(width: 64, height: 92)
                                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(movie.title).font(.body.weight(.semibold)).foregroundStyle(.primary)
                                            Text(String(movie.year)).font(.caption).foregroundStyle(.secondary)
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
            .navigationTitle("Watched!")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
            .sheet(item: $detailMovie) { movie in MovieDetailView(movie: movie) }
            .task {
                recommendations = await TMDBCatalog.fetchRecommendations(for: watched, apiKey: tmdbApiKey)
                loading = false
            }
        }
    }
}
