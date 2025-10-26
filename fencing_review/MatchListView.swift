import SwiftUI

struct MatchListView: View {
    @State private var sessions: [RecordingSession] = []

    // 日付ごとにグループ化してソート
    private var groupedSessions: [(date: Date, sessions: [RecordingSession])] {
        let grouped = Dictionary(grouping: sessions) { session in
            Calendar.current.startOfDay(for: session.creationDate)
        }

        // 日付は降順（新しい日が上）、時間は昇順（古い順）
        return grouped
            .sorted { $0.key > $1.key } // 日付降順
            .map { (date: $0.key,
                    sessions: $0.value.sorted { $0.creationDate < $1.creationDate }) } // 同日内は昇順
    }

    var body: some View {
        List {
            ForEach(groupedSessions, id: \.date) { group in
                Section(header: Text(dateFormatter.string(from: group.date))) {
                    ForEach(group.sessions) { session in
                        NavigationLink(destination: MatchDetailView(session: session)) {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(session.matchName)
                                        .font(.headline)
                                    Text("フラグ数: \(DataSaver.countFlags(inMatch: session.matchName))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Text(session.creationDate, style: .time)
                                    .font(.caption)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("試合一覧")
        .onAppear {
            loadSessions()
        }
    }

    private func loadSessions() {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentsURL.appendingPathComponent("recording_sessions.json")
        do {
            let data = try Data(contentsOf: fileURL)
            let decoded = try JSONDecoder().decode([RecordingSession].self, from: data)
            self.sessions = decoded
        } catch {
            print("セッション読み込み失敗: \(error)")
        }
    }

    private var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateStyle = .long
        f.locale = Locale(identifier: "ja_JP")
        return f
    }
}
