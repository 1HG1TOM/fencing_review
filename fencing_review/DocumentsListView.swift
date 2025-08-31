import SwiftUI
import UniformTypeIdentifiers

struct DocumentsListView: View {
    @State private var fileNames: [String] = []
    @State private var showImporter = false
    @State private var importErrorMessage: String? = nil
    @State private var showImportErrorAlert = false
    
    @State private var showRenameSheet = false
    @State private var renameOldName = ""
    @State private var renameNewName = ""
    @State private var renameError: String?
    @State private var showRenameError = false

    var body: some View {
        NavigationView {
            List {
                ForEach(fileNames, id: \.self) { file in
                    NavigationLink(destination: DocumentDetailView(fileName: file)) {
                        Text(file)
                    }
                    .swipeActions(edge: .trailing) {
                        Button("名前変更") {
                            renameOldName = file
                            renameNewName = file.replacingOccurrences(of: ".json", with: "")
                            showRenameSheet = true
                        }
                        .tint(.blue)
                    }
                }
                .onDelete(perform: deleteFiles)
            }
            .navigationTitle("保存ファイル一覧")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        Button { showImporter = true } label: {
                            Image(systemName: "square.and.arrow.down")
                        }
                        .accessibilityLabel("ファイルを取り込む")
                        EditButton()
                    }
                }
            }
            .onAppear { loadFiles() }
            .fileImporter(
                isPresented: $showImporter,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                do {
                    let urls = try result.get()
                    guard let src = urls.first else { return }
                    _ = try DataSaver.importExternalJSON(from: src)
                    loadFiles()
                } catch {
                    importErrorMessage = error.localizedDescription
                    showImportErrorAlert = true
                }
            }
            .alert("取り込みに失敗しました", isPresented: $showImportErrorAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(importErrorMessage ?? "不明なエラー")
            }
            .sheet(isPresented: $showRenameSheet) {
                NavigationView {
                    Form {
                        Section(header: Text("新しいファイル名")) {
                            TextField("例: scores-20250818-120000", text: $renameNewName)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                        }
                    }
                    .navigationTitle("名前変更")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("キャンセル") { showRenameSheet = false }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("保存") {
                                do {
                                    _ = try DataSaver.renameJSON(oldName: renameOldName, to: renameNewName)
                                    showRenameSheet = false
                                    loadFiles()
                                } catch {
                                    renameError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                                    showRenameError = true
                                }
                            }
                            .disabled(renameNewName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                }
            }
            .alert("名前変更に失敗しました", isPresented: $showRenameError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(renameError ?? "")
            }
        }
    }

    func loadFiles() {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        do {
            let files = try FileManager.default.contentsOfDirectory(at: documentsURL, includingPropertiesForKeys: nil)
            self.fileNames = files
                .filter { $0.pathExtension == "json" }
                .map { $0.lastPathComponent }
                .sorted()
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
