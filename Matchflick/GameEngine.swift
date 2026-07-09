import Foundation

/// Drives the pass-the-phone elimination game: round 1 requires unanimous "yes", round 2 falls
/// back to a plurality vote among the closest survivors so the group always lands on a pick.
@MainActor
final class GameEngine: ObservableObject {
    enum Phase: Equatable {
        case setup
        case handoff(player: Int)
        case swiping(player: Int)
        case revealingElimination
        case matched(Movie, chemistry: Int)
    }

    @Published private(set) var phase: Phase = .setup
    @Published private(set) var players: [String] = []
    @Published private(set) var roundDeck: [Movie] = []
    @Published private(set) var cardIndex = 0
    @Published private(set) var roundNumber = 1

    /// movieId -> [vote per player index], filled in as each player swipes.
    private var votes: [String: [Bool]] = [:]

    var totalPlayers: Int { players.count }
    var currentPlayerName: String {
        switch phase {
        case .handoff(let p), .swiping(let p): return players.indices.contains(p) ? players[p] : ""
        default: return ""
        }
    }
    var currentCard: Movie? { roundDeck.indices.contains(cardIndex) ? roundDeck[cardIndex] : nil }
    var nextCard: Movie? { roundDeck.indices.contains(cardIndex + 1) ? roundDeck[cardIndex + 1] : nil }

    // MARK: Persistence — resume a round in progress after the app is quit and reopened.

    private static let snapshotKey = "minder.gameSnapshot"

    /// UI tests use this to guarantee a clean slate — see MatchflickApp's MATCHFLICK_RESET_GAME.
    static func clearPersistedRound() {
        UserDefaults.standard.removeObject(forKey: snapshotKey)
    }

    private struct Snapshot: Codable {
        var players: [String]
        var roundDeck: [Movie]
        var cardIndex: Int
        var roundNumber: Int
        var votes: [String: [Bool]]
        var phaseKind: String // "handoff" or "swiping"
        var phasePlayer: Int
    }

    /// Call once at launch, before deciding whether to start a fresh round. Returns true if a
    /// round in progress was found and restored.
    @discardableResult
    func restoreIfAvailable() -> Bool {
        guard let data = UserDefaults.standard.data(forKey: Self.snapshotKey),
              let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data),
              !snapshot.roundDeck.isEmpty, !snapshot.players.isEmpty else { return false }
        players = snapshot.players
        roundDeck = snapshot.roundDeck
        cardIndex = snapshot.cardIndex
        roundNumber = snapshot.roundNumber
        votes = snapshot.votes
        switch snapshot.phaseKind {
        case "swiping": phase = .swiping(player: snapshot.phasePlayer)
        default: phase = .handoff(player: snapshot.phasePlayer)
        }
        return true
    }

    /// Only mid-round phases (handoff/swiping) are worth resuming — a completed match or the
    /// brief elimination-reveal spinner have nothing left to lose by starting fresh.
    private func persist() {
        let phaseKind: String
        let phasePlayer: Int
        switch phase {
        case .handoff(let p): phaseKind = "handoff"; phasePlayer = p
        case .swiping(let p): phaseKind = "swiping"; phasePlayer = p
        default:
            UserDefaults.standard.removeObject(forKey: Self.snapshotKey)
            return
        }
        let snapshot = Snapshot(players: players, roundDeck: roundDeck, cardIndex: cardIndex,
                                 roundNumber: roundNumber, votes: votes, phaseKind: phaseKind, phasePlayer: phasePlayer)
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults.standard.set(data, forKey: Self.snapshotKey)
    }

    func start(players: [String], deck: [Movie]) {
        self.players = players
        self.roundDeck = deck.shuffled()
        self.roundNumber = 1
        self.cardIndex = 0
        self.votes = [:]
        for movie in roundDeck { votes[movie.id] = [] }
        phase = players.isEmpty ? .setup : .handoff(player: 0)
        persist()
    }

    func beginSwiping() {
        guard case .handoff(let p) = phase else { return }
        phase = .swiping(player: p)
        persist()
    }

    /// Record the current player's vote on the current card and advance.
    func swipe(liked: Bool) {
        guard case .swiping(let p) = phase, let movie = currentCard else { return }
        votes[movie.id, default: []].append(liked)
        if cardIndex < roundDeck.count - 1 {
            cardIndex += 1
        } else {
            // This player finished the whole deck.
            if p < players.count - 1 {
                cardIndex = 0
                phase = .handoff(player: p + 1)
            } else {
                resolveRound()
            }
        }
        persist()
    }

    private func resolveRound() {
        phase = .revealingElimination
        let n = players.count

        if roundNumber == 1 {
            let unanimous = roundDeck.filter { movie in
                let v = votes[movie.id] ?? []
                return v.count == n && v.allSatisfy { $0 }
            }
            if let winner = unanimous.first, unanimous.count == 1 {
                finish(winner, allYes: true)
                return
            }
            if unanimous.count > 1 {
                // Multiple unanimous survivors: pick the one with the fewest total "no"s across
                // the field as a fun differentiator tiebreak, defaulting to the first if tied.
                let winner = unanimous.min { noCount(of: $0) < noCount(of: $1) } ?? unanimous[0]
                finish(winner, allYes: true)
                return
            }
            // Zero unanimous survivors: round 2 — replay with the closest calls (fewest no's).
            let ranked = roundDeck.sorted { noCount(of: $0) < noCount(of: $1) }
            let carryOver = Array(ranked.prefix(min(4, ranked.count)))
            roundNumber = 2
            roundDeck = carryOver
            cardIndex = 0
            votes = [:]
            for movie in roundDeck { votes[movie.id] = [] }
            phase = .handoff(player: 0)
            persist()
            return
        }

        // Round 2: plurality winner (most "yes" votes wins; chemistry reflects the ratio).
        let winner = roundDeck.max { yesCount(of: $0) < yesCount(of: $1) } ?? roundDeck[0]
        finish(winner, allYes: false)
    }

    private func yesCount(of movie: Movie) -> Int { (votes[movie.id] ?? []).filter { $0 }.count }
    private func noCount(of movie: Movie) -> Int { (votes[movie.id] ?? []).filter { !$0 }.count }

    private func finish(_ movie: Movie, allYes: Bool) {
        let n = max(players.count, 1)
        let yes = yesCount(of: movie)
        let chemistry = allYes ? 100 : Int((Double(yes) / Double(n) * 100).rounded())
        phase = .matched(movie, chemistry: max(chemistry, 1))
        persist()
    }

    func reset() {
        phase = .setup
        players = []
        roundDeck = []
        cardIndex = 0
        roundNumber = 1
        votes = [:]
        UserDefaults.standard.removeObject(forKey: Self.snapshotKey)
    }
}
