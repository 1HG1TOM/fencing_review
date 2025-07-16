import SwiftUI

struct MatchListView: View {
    @State private var sessions: [RecordingSession] = []

    var body: some View {
        List(sessions) { session in
            NavigationLink(destination: MatchDetailView(session: session)) {
                Text(session.matchName)
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
}
