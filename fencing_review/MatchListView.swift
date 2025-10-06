import SwiftUI

struct MatchListView: View {
    @State private var sessions: [RecordingSession] = []

    var body: some View {
        List(sessions) { session in
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
                    Text(session.creationDate, style: .date)
                }
            }
        }
        .navigationTitle("試合一覧") // ← タイトルは残す
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
}
