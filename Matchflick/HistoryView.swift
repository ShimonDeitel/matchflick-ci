import SwiftUI

/// Free — logs every group match result. Pro's only benefit is unlimited swiping.
struct HistoryView: View {
    @EnvironmentObject var appModel: AppModel

    var body: some View {
        NavigationStack {
            ZStack {
                MatchflickBackground()
                if appModel.history.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "clock")
                            .font(.system(size: 44, weight: .light)).foregroundStyle(.secondary)
                        Text("No matches yet").font(.headline)
                        Text("Every movie your group matches on will be saved here.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                } else {
                    List {
                        ForEach(appModel.history) { record in
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(record.movieTitle) (\(String(record.movieYear)))").font(.body.weight(.semibold))
                                if record.isSelfLogged {
                                    Text("Marked as watched")
                                        .font(.caption).foregroundStyle(.secondary)
                                } else {
                                    Text("Chemistry \(record.chemistry)% · \(record.playerCount) people")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                        .onDelete { idx in
                            idx.map { appModel.history[$0] }.forEach(appModel.delete)
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Watch History")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
