import Foundation

/// Free tier: 100 swipes/day, resetting at midnight. Pro: unlimited. This is the ONLY thing Pro
/// unlocks — moods, boards, Watch History, and Nearby Sync are all free. No visible counter is
/// shown while swiping; hitting the limit simply surfaces the upgrade paywall.
enum SwipeLimiter {
    static let freeDailyLimit = 100
    private static let countKey = "minder.swipeCount"
    private static let dayKey = "minder.swipeCountDay"

    private static var today: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    static var countToday: Int {
        let storedDay = UserDefaults.standard.string(forKey: dayKey)
        if storedDay != today { return 0 }
        return UserDefaults.standard.integer(forKey: countKey)
    }

    static func recordSwipe() {
        if UserDefaults.standard.string(forKey: dayKey) != today {
            UserDefaults.standard.set(today, forKey: dayKey)
            UserDefaults.standard.set(0, forKey: countKey)
        }
        UserDefaults.standard.set(countToday + 1, forKey: countKey)
    }

    static func hasReachedLimit(isPro: Bool) -> Bool {
        guard !isPro else { return false }
        return countToday >= freeDailyLimit
    }
}
