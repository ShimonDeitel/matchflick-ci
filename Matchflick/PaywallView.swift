import SwiftUI

struct PaywallView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var working = false
    @State private var restoreMessage: String?

    private let benefits: [(String, String, String)] = [
        ("infinity", "Unlimited swiping", "Free is 100 swipes a day. Pro removes the limit entirely — swipe as much as you want."),
        ("xmark.circle", "Cancel anytime", "Manage or cancel your subscription anytime in the App Store.")
    ]

    var body: some View {
        ZStack {
            MatchflickBackground()
            ScrollView {
                VStack(spacing: 22) {
                    VStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 40, weight: .semibold))
                            .foregroundStyle(Color.matchflickAccent)
                        Text("Minder Pro").font(.largeTitle.weight(.heavy))
                        Text("Moods, boards, Watch History, and Nearby Sync are already free. Pro is just for unlimited swiping.")
                            .font(.subheadline).foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 28)

                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(benefits, id: \.0) { item in
                            HStack(alignment: .top, spacing: 14) {
                                Image(systemName: item.0)
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(Color.matchflickAccent)
                                    .frame(width: 28)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.1).font(.headline)
                                    Text(item.2).font(.subheadline).foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 0)
                            }
                        }
                    }
                    .matchflickCard()
                    .padding(.horizontal)

                    VStack(spacing: 12) {
                        Button { Task { await buy() } } label: {
                            HStack {
                                if working { ProgressView().tint(.white) }
                                Text(working ? "Unlocking…" : "Subscribe · \(store.displayPrice)/mo")
                                    .font(.headline)
                            }
                            .frame(maxWidth: .infinity).padding(.vertical, 6)
                        }
                        .prominentButton()
                        .accessibilityIdentifier("paywall-unlock")
                        .disabled(working)

                        Button("Restore Purchase") { Task { await restore() } }
                            .font(.subheadline).tint(.secondary)

                        if let restoreMessage {
                            Text(restoreMessage).font(.footnote).foregroundStyle(.secondary)
                        }

                        Text("Minder never tracks you. Your favorites stay on your device.")
                            .font(.footnote).foregroundStyle(.secondary)
                            .multilineTextAlignment(.center).padding(.top, 4)
                    }
                    .padding(.horizontal).padding(.bottom, 30)
                }
            }
        }
        .overlay(alignment: .topTrailing) {
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill").font(.title2)
                    .foregroundStyle(.secondary).padding()
            }
            .accessibilityIdentifier("paywall-close")
            .accessibilityLabel("Close")
        }
        .onChange(of: store.isPro) { _, newValue in if newValue { dismiss() } }
    }

    private func buy() async {
        working = true
        let ok = await store.purchase()
        working = false
        if ok { Haptics.success(); dismiss() }
    }

    private func restore() async {
        await store.restore()
        if store.isPro { Haptics.success(); dismiss() }
        else { restoreMessage = "No previous purchase found on this Apple ID." }
    }
}
