import SwiftUI

struct DocumentDetailView: View {
    let fileURL: URL
    @State private var fileContents: String = ""
    @State private var showSaveAlert = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("ファイル名: \(fileURL.lastPathComponent)")
                    .font(.headline)

                TextEditor(text: $fileContents)
                    .font(.body)
                    .padding()
                    .frame(minHeight: 300)
                    .border(Color.gray.opacity(0.4))
                    .cornerRadius(10)

                Button("保存") {
                    saveContent()
                    showSaveAlert = true
                }
                .padding()
            }
            .padding()
            .onAppear { loadContent() }
        }
        .navigationTitle("詳細")
        .alert("保存しました", isPresented: $showSaveAlert) {
            Button("OK", role: .cancel) {}
        }
    }

    private func loadContent() {
        if let loaded = try? String(contentsOf: fileURL) {
            fileContents = loaded
        } else {
            fileContents = "読み込みに失敗しました"
        }
    }

    private func saveContent() {
        try? fileContents.write(to: fileURL, atomically: true, encoding: .utf8)
    }
}
