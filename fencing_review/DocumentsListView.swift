import SwiftUI

struct DocumentsListView: View {
    @State private var fileNames: [String] = []

    var body: some View {
        NavigationView {
            List {
                ForEach(fileNames, id: \.self) { file in
                    NavigationLink(destination: DocumentDetailView(fileName: file)) {
                        Text(file)
                    }
                }
                .onDelete(perform: deleteFiles)
            }
            .navigationTitle("保存ファイル一覧")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
            }
            .onAppear {
                loadFiles()
            }
        }
    }

    func loadFiles() {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        do {
            let files = try FileManager.default.contentsOfDirectory(at: documentsURL, includingPropertiesForKeys: nil)
            self.fileNames = files.filter { $0.pathExtension == "json" }.map { $0.lastPathComponent }
        } catch {
            print("ファイル読み込み失敗: \(error)")
        }
    }

    func deleteFiles(at offsets: IndexSet) {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        for index in offsets {
            let fileName = fileNames[index]
            let fileURL = documentsURL.appendingPathComponent(fileName)
            try? FileManager.default.removeItem(at: fileURL)
        }
        loadFiles()
    }
}

struct DocumentDetailView: View {
    let fileName: String
    @State private var fileContents: String = ""
    @State private var showSaveAlert = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("ファイル名: \(fileName)")
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

                Spacer()
            }
            .padding()
            .onAppear {
                loadContent()
            }
        }
        .navigationTitle("詳細")
        .alert("保存しました", isPresented: $showSaveAlert) {
            Button("OK", role: .cancel) {}
        }
    }

    func loadContent() {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentsURL.appendingPathComponent(fileName)
        if let loaded = try? String(contentsOf: fileURL) {
            fileContents = loaded
        } else {
            fileContents = "読み込みに失敗しました"
        }
    }

    func saveContent() {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentsURL.appendingPathComponent(fileName)
        try? fileContents.write(to: fileURL, atomically: true, encoding: .utf8)
    }
}
