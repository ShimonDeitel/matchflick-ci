import Foundation
import SwiftData

/// A named list a title can be filed into. Every install ships with two undeletable defaults
/// (Want to Watch, Maybe); Pro users can create additional boards of either kind.
@Model
final class WatchBoard {
    var id: UUID = UUID()
    var name: String = ""
    var symbol: String = "square.stack.3d.up.fill"
    var kindRaw: String = WatchlistStatus.wantToWatch.rawValue
    var isDefault: Bool = false
    var createdAt: Date = Date.now

    var kind: WatchlistStatus {
        get { WatchlistStatus(rawValue: kindRaw) ?? .wantToWatch }
        set { kindRaw = newValue.rawValue }
    }

    init(id: UUID = UUID(), name: String = "", symbol: String = "square.stack.3d.up.fill",
         kindRaw: String = WatchlistStatus.wantToWatch.rawValue, isDefault: Bool = false, createdAt: Date = .now) {
        self.id = id
        self.name = name
        self.symbol = symbol
        self.kindRaw = kindRaw
        self.isDefault = isDefault
        self.createdAt = createdAt
    }

    static let defaultWantID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    static let defaultMaybeID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!

    /// Curated symbols for new custom boards — distinct, easy to tell apart at a glance.
    static let symbolPalette = [
        "checkmark.circle.fill", "cube.fill", "star.fill", "flame.fill", "moon.stars.fill",
        "sparkles", "heart.fill", "bolt.fill", "leaf.fill", "crown.fill", "gift.fill", "popcorn.fill"
    ]
}
