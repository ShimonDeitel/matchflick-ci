import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appModel: AppModel
    @EnvironmentObject var store: Store

    @AppStorage("matchflick.theme") private var themeRaw = AppTheme.system.rawValue
    @AppStorage("matchflick.haptics") private var hapticsEnabled = true

    @AppStorage(GamePrefs.playerCountKey) private var playerCount = 2
    @AppStorage(GamePrefs.moodsKey) private var moodsRaw = GamePrefs.defaultMoodsRaw
    @AppStorage(GamePrefs.mediaFilterKey) private var mediaFilterRaw = MediaFilter.both.rawValue
    @AppStorage(GamePrefs.yearMinKey) private var yearMin = GamePrefs.earliestYear
    @AppStorage(GamePrefs.yearMaxKey) private var yearMax = GamePrefs.latestYear
    @AppStorage(GamePrefs.maxMaturityKey) private var maxMaturityIndex = GamePrefs.defaultMaxMaturityIndex

    @State private var showPaywall = false
    @State private var showDeleteConfirm = false
    @State private var showAlgorithmQuiz = false
    @State private var restoreMessage: String?

    private var version: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        return "Minder \(v)"
    }

    private var selectedMoods: Set<MoodTag> {
        Set(moodsRaw.split(separator: ",").compactMap { MoodTag(rawValue: String($0)) })
    }
    // Every mood is free — Pro's only benefit is unlimited swipes (see SwipeLimiter).
    private var moodLimit: Int { MoodTag.allCases.count }

    var body: some View {
        NavigationStack {
            Form {
                swipeSettingsSection
                moodSection
                decadeSection
                maturitySection
                algorithmSection
                nearbySyncSection
                proSection
                appearanceSection
                dataSection
                aboutSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .tint(Color.matchflickAccent)
            .sheet(isPresented: $showPaywall) { PaywallView() }
            .sheet(isPresented: $showAlgorithmQuiz) { AlgorithmQuizView() }
            .alert("Erase All Data?", isPresented: $showDeleteConfirm) {
                Button("Erase", role: .destructive) { appModel.deleteAllData() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently erases your Watch History and Want to Watch/Maybe lists on this device. This can't be undone.")
            }
        }
    }

    // MARK: Swipe

    private var swipeSettingsSection: some View {
        Section {
            Stepper(value: $playerCount, in: 1...8) {
                Label("\(playerCount) \(playerCount == 1 ? "person" : "people")", systemImage: "person.2.fill")
            }
            .accessibilityIdentifier("player-stepper")

            VStack(alignment: .leading, spacing: 8) {
                Label("Movies, TV, or both?", systemImage: "film.fill")
                Picker("", selection: Binding(
                    get: { MediaFilter(rawValue: mediaFilterRaw) ?? .both },
                    set: { mediaFilterRaw = $0.rawValue }
                )) {
                    ForEach(MediaFilter.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .accessibilityIdentifier("media-filter")
            }
            .padding(.vertical, 2)
        } header: {
            Text("Swipe Defaults")
        } footer: {
            Text("Applied the next time you open the app or start a new round.")
        }
    }

    private var moodSection: some View {
        Section {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(MoodTag.allCases) { mood in
                    moodChip(mood)
                }
            }
            .padding(.vertical, 6)
        } header: {
            Text("Moods")
        } footer: {
            Text("All 16 moods are free — pick as many as you like.")
        }
    }

    private func moodChip(_ mood: MoodTag) -> some View {
        let selected = selectedMoods.contains(mood)
        return Button {
            Haptics.tap()
            var moods = selectedMoods
            if selected {
                moods.remove(mood)
            } else if moods.count < moodLimit {
                moods.insert(mood)
            }
            moodsRaw = moods.map(\.rawValue).joined(separator: ",")
        } label: {
            HStack(spacing: 6) {
                Image(systemName: mood.symbol).font(.caption)
                Text(mood.label).font(.subheadline.weight(.medium)).lineLimit(1).minimumScaleFactor(0.8)
                Spacer(minLength: 0)
            }
            .foregroundStyle(selected ? .white : .primary)
            .padding(.vertical, 10).padding(.horizontal, 12)
            .frame(maxWidth: .infinity)
            .background(selected ? Color.matchflickAccent : Color.matchflickField,
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("mood-\(mood.rawValue)")
    }

    private var decadeSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label("Decade", systemImage: "calendar")
                    Spacer()
                    Text("\(yearMin) - \(yearMax)")
                        .font(.subheadline.weight(.semibold)).foregroundStyle(Color.matchflickAccent)
                }
                YearRangeSlider(lowerValue: $yearMin, upperValue: $yearMax,
                                bounds: GamePrefs.earliestYear...GamePrefs.latestYear)
                    .accessibilityIdentifier("decade-slider")
            }
            .padding(.vertical, 6)
        }
    }

    private var maturitySection: some View {
        Section {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label("Maximum Rating", systemImage: "figure.child")
                    Spacer()
                    Text(GamePrefs.maturityLevels[maxMaturityIndex])
                        .font(.subheadline.weight(.semibold)).foregroundStyle(Color.matchflickAccent)
                }
                Slider(
                    value: Binding(
                        get: { Double(maxMaturityIndex) },
                        set: { maxMaturityIndex = Int($0.rounded()) }
                    ),
                    in: 0...Double(GamePrefs.maturityLevels.count - 1),
                    step: 1
                )
                .tint(Color.matchflickAccent)
                .accessibilityIdentifier("maturity-slider")
            }
            .padding(.vertical, 6)
        } footer: {
            Text("Movies rated above this won't show up while swiping. TMDB doesn't support the same rating filter for TV shows, so this only narrows movies.")
        }
    }

    private var algorithmSection: some View {
        Section {
            Button {
                Haptics.tap(); showAlgorithmQuiz = true
            } label: {
                Label("Tune Your Algorithm", systemImage: "slider.horizontal.3")
            }
        } header: {
            Text("Algorithm")
        } footer: {
            Text("Take a quick quiz to set your starting taste, or just keep swiping — every yes and no nudges what shows up next. This is an on-device genre model, not a large-scale recommendation service.")
        }
    }

    // MARK: Nearby Sync

    private var nearbySyncSection: some View {
        Section {
            Toggle(isOn: Binding(
                get: { appModel.sync.isRunning },
                set: { appModel.setNearbySyncEnabled($0) }
            )) {
                Label("Sync with nearby devices", systemImage: "wifi")
            }
            if appModel.sync.isRunning {
                HStack {
                    Text(appModel.sync.connectedPeerCount > 0 ? "Connected" : "Looking for nearby devices…")
                    Spacer()
                    if appModel.sync.connectedPeerCount > 0 {
                        Text("\(appModel.sync.connectedPeerCount) device\(appModel.sync.connectedPeerCount == 1 ? "" : "s")")
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.subheadline)
            }
        } header: {
            Text("Nearby Sync")
        } footer: {
            Text("Free. Works over your local Wi-Fi network only — new Want to Watch and Maybe saves appear on the Minder app running on your other nearby devices while this is on and they're on the same network. This is not full iCloud sync: it doesn't sync in the background over the internet like Notes does, and removing a title on one device doesn't remove it on the other yet.")
        }
    }

    // MARK: Pro

    @ViewBuilder
    private var proSection: some View {
        Section {
            if store.isPro {
                Label("Minder Pro", systemImage: "sparkles")
                    .badge("Unlocked")
            } else {
                Button {
                    Haptics.tap(); showPaywall = true
                } label: {
                    HStack {
                        Label("Unlock Minder Pro", systemImage: "sparkles")
                        Spacer()
                        Text("\(store.displayPrice)/mo").foregroundStyle(.secondary)
                    }
                }
                .accessibilityIdentifier("unlock-pro-row")
                Button {
                    Task {
                        await store.restore()
                        restoreMessage = store.isPro ? "Restored." : "No previous purchase found."
                    }
                } label: {
                    Label("Restore Purchase", systemImage: "arrow.clockwise")
                }
                if let restoreMessage {
                    Text(restoreMessage).font(.footnote).foregroundStyle(.secondary)
                }
            }
        } footer: {
            if !store.isPro {
                Text("Monthly subscription. The only thing Pro unlocks: unlimited swiping (free is 100/day). Everything else — moods, boards, Watch History, Nearby Sync — is free. Cancel anytime in the App Store.")
            }
        }
    }

    // MARK: Appearance & data

    private var appearanceSection: some View {
        Section("Appearance") {
            Picker(selection: $themeRaw) {
                ForEach(AppTheme.allCases) { Text($0.label).tag($0.rawValue) }
            } label: {
                Label("Theme", systemImage: "circle.lefthalf.filled")
            }
            .pickerStyle(.segmented)

            Toggle(isOn: $hapticsEnabled) {
                Label("Haptics", systemImage: "waveform")
            }
        }
    }

    private var dataSection: some View {
        Section {
            Button(role: .destructive) { showDeleteConfirm = true } label: {
                Label("Erase My Data", systemImage: "trash")
            }
        } header: {
            Text("Data")
        } footer: {
            Text("No account is required to use Minder — everything is stored only on this device.")
        }
    }

    private var aboutSection: some View {
        Section {
            Link(destination: URL(string: "https://shimondeitel.github.io/matchflick-site/privacy.html")!) {
                Label("Privacy Policy", systemImage: "hand.raised.fill")
            }
        } footer: {
            VStack(spacing: 4) {
                Text(version)
                Text("Poster art, ratings, and streaming data via TMDB. This product uses the TMDB API but is not endorsed or certified by TMDB.")
                    .font(.caption2)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 4)
        }
    }
}
