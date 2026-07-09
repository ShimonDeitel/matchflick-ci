import SwiftUI

/// Drives the full pass-the-phone round: handoff screen -> swipe deck -> (repeat per player) ->
/// elimination -> match reveal.
struct GameView: View {
    @ObservedObject var engine: GameEngine
    var onDismiss: () -> Void

    var body: some View {
        ZStack {
            MatchflickBackground()
            Group {
                switch engine.phase {
                case .setup:
                    // HomeView's own onAppear is the sole authority for what happens here (it
                    // decides between resuming a persisted round and starting a fresh one) — this
                    // case must NOT also trigger onDismiss itself, or it races HomeView's restore
                    // and clobbers it once its async deck fetch resolves.
                    Color.clear
                case .handoff(let player):
                    HandoffView(playerName: engine.players.indices.contains(player) ? engine.players[player] : "",
                                playerNumber: player + 1, total: engine.totalPlayers, round: engine.roundNumber) {
                        engine.beginSwiping()
                    }
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)))
                case .swiping:
                    SwipeStackView(engine: engine)
                        .transition(.opacity)
                case .revealingElimination:
                    ProgressView().controlSize(.large)
                        .transition(.opacity)
                case .matched(let movie, let chemistry):
                    MatchResultView(movie: movie, chemistry: chemistry, playerCount: engine.totalPlayers, onDone: onDismiss)
                        .transition(.scale(scale: 0.85).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.45, dampingFraction: 0.85), value: phaseTag)
        }
    }

    private var phaseTag: Int {
        switch engine.phase {
        case .setup: return 0
        case .handoff: return 1
        case .swiping: return 2
        case .revealingElimination: return 3
        case .matched: return 4
        }
    }
}

private struct HandoffView: View {
    let playerName: String
    let playerNumber: Int
    let total: Int
    let round: Int
    let onReveal: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "hand.point.up.left.fill")
                .font(.system(size: 48, weight: .semibold))
                .foregroundStyle(Color.matchflickAccent)
            Text(round == 2 ? "Round 2 - Tiebreaker" : "Pass to")
                .font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
            Text(playerName)
                .font(.largeTitle.weight(.bold))
            Text("Player \(playerNumber) of \(total)")
                .font(.subheadline).foregroundStyle(.secondary)
            Spacer()
            Button("I'm Ready") { Haptics.tap(); onReveal() }
                .prominentButton()
                .accessibilityIdentifier("handoff-ready")
            Spacer(minLength: 40)
        }
        .padding(28)
    }
}

private struct SwipeStackView: View {
    @ObservedObject var engine: GameEngine
    @EnvironmentObject var appModel: AppModel
    @EnvironmentObject var store: Store
    @GestureState private var dragOffset: CGSize = .zero
    @State private var flingOffset: CGSize = .zero
    @State private var detailMovie: Movie?
    @State private var maybeToast = false
    @State private var savedToast = false
    @State private var showLimitPaywall = false

    var body: some View {
        VStack(spacing: 16) {
            Text("\(engine.currentPlayerName) - card \(engine.cardIndex + 1) of \(engine.roundDeck.count)")
                .font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                .matchflickPill()
                .padding(.top, 24)

            Spacer(minLength: 8)

            ZStack {
                if let next = engine.nextCard {
                    movieCard(next, interactive: false)
                        .scaleEffect(0.94)
                        .offset(y: 10)
                        .opacity(0.6)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
                if let movie = engine.currentCard {
                    movieCard(movie)
                        .overlay(alignment: .topLeading) { stamp(text: "NOPE", color: .red, visible: dragOffset.width < -12 && abs(dragOffset.height) < abs(dragOffset.width))
                            .rotationEffect(.degrees(-18)).padding(28) }
                        .overlay(alignment: .topTrailing) { stamp(text: "LIKE", color: Color.matchflickAccent, visible: dragOffset.width > 12 && abs(dragOffset.height) < abs(dragOffset.width))
                            .rotationEffect(.degrees(18)).padding(28) }
                        .overlay(alignment: .bottom) { stamp(text: "MAYBE", color: .white, visible: dragOffset.height > 12 && dragOffset.height > abs(dragOffset.width))
                            .padding(.bottom, 28) }
                        .offset(x: dragOffset.width + flingOffset.width, y: min(dragOffset.height, 40) + flingOffset.height)
                        .rotationEffect(.degrees(Double(dragOffset.width / 20)))
                        .gesture(
                            DragGesture()
                                .updating($dragOffset) { value, state, _ in state = value.translation }
                                .onEnded { value in handleSwipeEnd(value.translation, movie: movie) }
                        )
                        .simultaneousGesture(TapGesture().onEnded {
                            Haptics.tap(); detailMovie = movie
                        })
                        .animation(.easeOut(duration: 0.2), value: dragOffset)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.9).combined(with: .opacity),
                            removal: .identity))
                        .id(movie.id)
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: engine.cardIndex)
            .overlay(alignment: .top) {
                if maybeToast {
                    Label("Saved to Maybe", systemImage: "cube.fill")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(.ultraThinMaterial, in: Capsule())
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .padding(.top, 8)
                } else if savedToast {
                    Label("Saved to Want to Watch", systemImage: "checkmark.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(.ultraThinMaterial, in: Capsule())
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .padding(.top, 8)
                }
            }

            Spacer()

            HStack(spacing: 24) {
                destinationBin(symbol: "trash.fill", label: "No", color: .red,
                               highlighted: dragOffset.width < -12 && abs(dragOffset.height) < abs(dragOffset.width),
                               identifier: "swipe-no") { vote(false, movie: engine.currentCard) }
                destinationBin(symbol: "cube.fill", label: "Maybe", color: .white, tint: Color.matchflickField,
                               highlighted: dragOffset.height > 12 && dragOffset.height > abs(dragOffset.width),
                               identifier: "swipe-maybe") {
                    if let movie = engine.currentCard { markMaybe(movie) }
                }
                destinationBin(symbol: "checkmark.seal.fill", label: "Want to Watch", color: .white, tint: Color.matchflickAccent,
                               highlighted: dragOffset.width > 12 && abs(dragOffset.height) < abs(dragOffset.width),
                               identifier: "swipe-yes") { vote(true, movie: engine.currentCard) }
            }
            .padding(.bottom, 12)
        }
        .padding(.bottom, 8)
        .sheet(item: $detailMovie) { movie in MovieDetailView(movie: movie) }
        .sheet(isPresented: $showLimitPaywall) { PaywallView() }
    }

    private func destinationBin(symbol: String, label: String, color: Color, tint: Color = .clear,
                                 highlighted: Bool, identifier: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: symbol)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(tint == .clear ? color : .white)
                    .frame(width: 60, height: 60)
                    .background(tint == .clear ? Color.matchflickCard : tint, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .scaleEffect(highlighted ? 1.15 : 1)
                Text(label).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
            }
        }
        .buttonStyle(BouncyButtonStyle())
        .animation(.spring(response: 0.25, dampingFraction: 0.6), value: highlighted)
        .accessibilityIdentifier(identifier)
        .accessibilityLabel(label)
    }

    private func markMaybe(_ movie: Movie) {
        Haptics.tap()
        appModel.setWatchlistStatus(.maybe, for: movie)
        PreferenceEngine.recordStrongLike(genres: movie.genres)
        withAnimation { maybeToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            withAnimation { maybeToast = false }
        }
        vote(false, movie: movie, flingDown: true)
    }

    private func stamp(text: String, color: Color, visible: Bool) -> some View {
        Text(text)
            .font(.title.weight(.heavy))
            .foregroundStyle(color)
            .padding(.horizontal, 14).padding(.vertical, 6)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(color, lineWidth: 4))
            .opacity(visible ? 1 : 0)
            .animation(.easeOut(duration: 0.15), value: visible)
    }

    private func movieCard(_ movie: Movie, interactive: Bool = true) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            PosterView(movie: movie)
                .frame(height: 230)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .overlay(alignment: .topLeading) {
                    Label(movie.mediaType.label, systemImage: movie.mediaType.symbol)
                        .font(.caption2.weight(.bold)).foregroundStyle(.white)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color.matchflickAccent, in: Capsule())
                        .padding(12)
                }
                .overlay(alignment: .topTrailing) {
                    if interactive {
                        Button { Haptics.tap(); detailMovie = movie } label: {
                            Image(systemName: "info.circle.fill")
                                .font(.title2).foregroundStyle(.white)
                                .padding(8)
                                .background(.black.opacity(0.35), in: Circle())
                        }
                        .padding(12)
                        .accessibilityIdentifier("card-info")
                    } else {
                        Image(systemName: "info.circle.fill")
                            .font(.title2).foregroundStyle(.white)
                            .padding(8)
                            .background(.black.opacity(0.35), in: Circle())
                            .padding(12)
                    }
                }

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(movie.title).font(.title2.weight(.bold))
                    Spacer()
                    Text(String(movie.year)).font(.subheadline).foregroundStyle(.secondary)
                }
                HStack(alignment: .top, spacing: 6) {
                    FlowLayout(spacing: 6) {
                        ForEach(movie.genres, id: \.self) { g in
                            Text(g).font(.caption.weight(.semibold)).foregroundStyle(Color.matchflickAccent)
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .background(Color.matchflickField, in: Capsule())
                        }
                    }
                    Spacer(minLength: 8)
                    if movie.runtimeMins > 0 {
                        Text("\(movie.runtimeMins)m").font(.caption).foregroundStyle(.secondary)
                    }
                }
                Text(movie.premise)
                    .font(.subheadline).foregroundStyle(.secondary)
                    .lineLimit(2)
                HStack(spacing: 16) {
                    Link(destination: movie.trailerSearchURL) {
                        Label("Trailer", systemImage: "play.rectangle.fill")
                            .font(.caption.weight(.semibold))
                    }
                    .accessibilityIdentifier("trailer-link")
                    ShareLink(item: "\(movie.title) (\(movie.year)) — swiping on Minder") {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .font(.caption.weight(.semibold))
                    }
                    .accessibilityIdentifier("share-title")
                }
            }
            .padding(18)
        }
        .frame(maxWidth: .infinity, maxHeight: 420, alignment: .top)
        .background(Color.matchflickCard, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .padding(.horizontal, 20)
    }

    private func vote(_ liked: Bool, movie: Movie?, flingDown: Bool = false) {
        if SwipeLimiter.hasReachedLimit(isPro: store.isPro) {
            showLimitPaywall = true
            return
        }
        Haptics.tap()
        SwipeLimiter.recordSwipe()
        if let movie {
            PreferenceEngine.recordSwipe(genres: movie.genres, liked: liked)
            PreferenceEngine.recordSeen(movieId: movie.id)
            // A right swipe is a "yes" for the group match AND saves it to Want to Watch —
            // otherwise "swipe right" silently did nothing to the watchlist, which read as broken.
            if liked {
                appModel.setWatchlistStatus(.wantToWatch, for: movie)
                withAnimation { savedToast = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
                    withAnimation { savedToast = false }
                }
            }
        }
        flingOffset = flingDown ? CGSize(width: 0, height: 500) : CGSize(width: liked ? 500 : -500, height: 0)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            flingOffset = .zero
            engine.swipe(liked: liked)
        }
    }

    private func handleSwipeEnd(_ translation: CGSize, movie: Movie) {
        if translation.height > 100 && translation.height > abs(translation.width) {
            markMaybe(movie)
        } else if translation.width > 100 {
            vote(true, movie: movie)
        } else if translation.width < -100 {
            vote(false, movie: movie)
        }
    }
}

private struct MatchResultView: View {
    let movie: Movie
    let chemistry: Int
    let playerCount: Int
    let onDone: () -> Void

    @EnvironmentObject var appModel: AppModel
    @State private var saved = false
    @State private var sealScale: CGFloat = 0.3
    @State private var burst = false

    var body: some View {
        ScrollView {
        VStack(spacing: 20) {
            Spacer(minLength: 20)
            ZStack {
                if burst { ConfettiBurst() }
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(Color.matchflickAccent)
                    .scaleEffect(sealScale)
            }
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.55)) { sealScale = 1 }
                withAnimation(.easeOut(duration: 0.6).delay(0.1)) { burst = true }
            }
            Text("It's a Match").font(.largeTitle.weight(.heavy))

            VStack(spacing: 0) {
                PosterView(movie: movie)
                    .frame(height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .padding([.horizontal, .top], 16)
                VStack(spacing: 10) {
                    Text(movie.title).font(.title.weight(.bold)).multilineTextAlignment(.center)
                    Text(String(movie.year)).font(.subheadline).foregroundStyle(.secondary)
                    Text(movie.premise).font(.body).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center).padding(.horizontal, 12)
                        .lineLimit(3)
                    Text("Chemistry: \(chemistry)%")
                        .font(.headline).foregroundStyle(Color.matchflickAccent)
                        .padding(.top, 6)
                    Link(destination: movie.trailerSearchURL) {
                        Label("Watch Trailer", systemImage: "play.rectangle.fill")
                            .font(.caption.weight(.semibold))
                    }
                    Text("Matched on Minder").font(.caption2).foregroundStyle(.secondary)
                }
                .padding(20)
            }
            .matchflickCard(cornerRadius: 28)
            .padding(.horizontal, 20)
            .accessibilityIdentifier("match-card")

            Spacer()

            Button(saved ? "Saved to Watch History" : "Save to Watch History") {
                guard !saved else { return }
                appModel.recordMatch(title: movie.title, year: movie.year, chemistry: chemistry, playerCount: playerCount)
                saved = true
                Haptics.success()
            }
            .softButton()
            .disabled(saved)

            ShareLink(item: "We matched on \u{201C}\(movie.title)\u{201D} (\(chemistry)% chemistry) using Minder.") {
                Label("Share Match", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(.plain)
            .padding(.top, 4)

            Button("Done") { onDone() }
                .prominentButton()
                .accessibilityIdentifier("match-done")
                .padding(.top, 8)
            Spacer(minLength: 20)
        }
        .padding(20)
        }
    }
}

/// A small flat-shape burst (no gradients) radiating out from the match seal — the one moment
/// in the app that earns a little celebration.
private struct ConfettiBurst: View {
    @State private var expanded = false
    private let symbols = ["star.fill", "circle.fill", "star.fill", "circle.fill", "star.fill", "circle.fill",
                            "star.fill", "circle.fill", "star.fill", "circle.fill", "star.fill", "circle.fill"]

    var body: some View {
        ZStack {
            ForEach(Array(symbols.enumerated()), id: \.offset) { index, symbol in
                let angle = Double(index) / Double(symbols.count) * 2 * Double.pi
                Image(systemName: symbol)
                    .font(.system(size: 10))
                    .foregroundStyle(Color.matchflickAccent)
                    .offset(x: expanded ? cos(angle) * 60 : 0, y: expanded ? sin(angle) * 60 : 0)
                    .opacity(expanded ? 0 : 1)
            }
        }
        .frame(width: 140, height: 140)
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.easeOut(duration: 0.7)) { expanded = true }
        }
    }
}
