import SwiftUI
import UniformTypeIdentifiers

struct DocumentsListView: View {
    let currentFolderURL: URL

    init(currentFolderURL: URL? = nil) {
        if let url = currentFolderURL {
            self.currentFolderURL = url
        } else {
            self.currentFolderURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        }
    }

    @State private var entries: [URL] = []
    @State private var showImporter = false
    @State private var importErrorMessage: String?
    @State private var showImportErrorAlert = false

    // 状態管理
    @State private var renameTargetURL: URL?
    @State private var renameNewName = ""
    @State private var showRenameSheet = false
    @State private var showNewFolderSheet = false
    @State private var showNewFileSheet = false
    @State private var showMoveSheet = false

    @State private var newFolderName = ""
    @State private var newFileName = ""
    @State private var moveTargetURL: URL?
    @State private var selectedDestURL: URL?

    var body: some View {
        NavigationView {
            List {
                ForEach(entries, id: \.path) { url in
                    let isDir = isDirectory(url)
                    NavigationLink(destination: isDir ?
                        AnyView(DocumentsListView(currentFolderURL: url)) :
                        AnyView(DocumentDetailView(fileURL: url))
                    ) {
                        HStack {
                            Image(systemName: isDir ? "folder" : "doc.text")
                            Text(url.lastPathComponent)
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button("移動") {
                            moveTargetURL = url
                            selectedDestURL = currentFolderURL
                            showMoveSheet = true
                        }.tint(.orange)

                        Button("名前変更") {
                            renameTargetURL = url
                            renameNewName = url.deletingPathExtension().lastPathComponent
                            showRenameSheet = true
                        }.tint(.blue)
                    }
                    .swipeActions(edge: .leading) {
                        Button(role: .destructive) {
                            deleteItem(url)
                        } label: {
                            Label("削除", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle(currentFolderURL == documentsRoot ? "保存ファイル一覧" : currentFolderURL.lastPathComponent)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        Button { showImporter = true } label: { Image(systemName: "square.and.arrow.down") }
                        Button { showNewFolderSheet = true } label: { Image(systemName: "folder.badge.plus") }
                        Button { showNewFileSheet = true } label: { Image(systemName: "doc.badge.plus") }
                        EditButton()
                    }
                }
            }
            .onAppear { loadEntries() }
            .fileImporter(isPresented: $showImporter,
                          allowedContentTypes: [.json],
                          allowsMultipleSelection: false,
                          onCompletion: handleImport)
            .alert("取り込みに失敗しました", isPresented: $showImportErrorAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(importErrorMessage ?? "")
            }
            .sheet(isPresented: $showRenameSheet) {
                RenameSheet(
                    isPresented: $showRenameSheet,
                    renameNewName: $renameNewName,
                    onSave: renameEntry
                )
            }
            .sheet(isPresented: $showNewFolderSheet) {
                NewItemSheet(title: "新規フォルダ", placeholder: "例: 2025-09-13_試合A", text: $newFolderName) {
                    createFolder()
                }
            }
            .sheet(isPresented: $showNewFileSheet) {
                NewItemSheet(title: "新規ファイル", placeholder: "例: flags-xxxxxx", text: $newFileName) {
                    createEmptyJSON()
                }
            }
            .sheet(isPresented: $showMoveSheet) {
                FolderPickerView(
                    rootURL: documentsRoot,
                    initialSelection: selectedDestURL ?? currentFolderURL,
                    disabledUnder: moveTargetURL
                ) { picked in
                    selectedDestURL = picked
                }
                .navigationTitle("移動先を選択")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("キャンセル") { showMoveSheet = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("移動") { performMove() }
                            .disabled(selectedDestURL == nil)
                    }
                }
            }
        }
    }
}

// MARK: - Subviews
private struct RenameSheet: View {
    @Binding var isPresented: Bool
    @Binding var renameNewName: String
    let onSave: () -> Void

    var body: some View {
        NavigationView {
            Form {
                TextField("新しい名前", text: $renameNewName)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }
            .navigationTitle("名前変更")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { onSave(); isPresented = false }
                        .disabled(renameNewName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

private struct NewItemSheet: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    let onSave: () -> Void

    var body: some View {
        NavigationView {
            Form {
                TextField(placeholder, text: $text)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { text = "" }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("作成") { onSave(); text = "" }
                        .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

// MARK: - Core Logic
extension DocumentsListView {
    private var documentsRoot: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private func isDirectory(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
    }

    private func loadEntries() {
        do {
            let items = try FileManager.default.contentsOfDirectory(at: currentFolderURL, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])
            let folders = items.filter { isDirectory($0) }.sorted { $0.lastPathComponent < $1.lastPathComponent }
            let files = items.filter { !$0.hasDirectoryPath && $0.pathExtension.lowercased() == "json" }
                .sorted { $0.lastPathComponent < $1.lastPathComponent }
            self.entries = folders + files
        } catch {
            print("❌ ファイル読み込み失敗: \(error)")
            self.entries = []
        }
    }

    private func deleteItem(_ url: URL) {
        do {
            try FileManager.default.removeItem(at: url)
            print("🗑️ 削除完了: \(url.lastPathComponent)")
            loadEntries()
        } catch {
            print("⚠️ 削除失敗: \(error)")
        }
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        do {
            let urls = try result.get()
            guard let src = urls.first else { return }
            try importJSON(srcURL: src, into: currentFolderURL)
            loadEntries()
        } catch {
            importErrorMessage = error.localizedDescription
            showImportErrorAlert = true
        }
    }

    private func importJSON(srcURL: URL, into destFolder: URL) throws {
        let fm = FileManager.default
        let needsStop = srcURL.startAccessingSecurityScopedResource()
        defer { if needsStop { srcURL.stopAccessingSecurityScopedResource() } }

        var destURL = destFolder.appendingPathComponent(srcURL.lastPathComponent)
        if destURL.pathExtension.isEmpty { destURL.appendPathExtension("json") }

        var counter = 1
        while fm.fileExists(atPath: destURL.path) {
            let base = destURL.deletingPathExtension().lastPathComponent
            let ext = destURL.pathExtension
            destURL = destFolder.appendingPathComponent("\(base)-\(counter).\(ext)")
            counter += 1
        }
        try fm.copyItem(at: srcURL, to: destURL)
    }

    private func renameEntry() {
        guard let target = renameTargetURL else { return }
        let fm = FileManager.default
        var newName = renameNewName.trimmingCharacters(in: .whitespaces)
        if !isDirectory(target), !newName.lowercased().hasSuffix(".json") {
            newName += ".json"
        }
        let dest = target.deletingLastPathComponent().appendingPathComponent(newName)
        guard dest != target else { return }
        do {
            try fm.moveItem(at: target, to: dest)
            loadEntries()
        } catch {
            print("⚠️ 名前変更失敗: \(error)")
        }
    }

    private func createFolder() {
        let fm = FileManager.default
        let name = newFolderName.trimmingCharacters(in: .whitespaces)
        let url = currentFolderURL.appendingPathComponent(name)
        do {
            try fm.createDirectory(at: url, withIntermediateDirectories: true)
            loadEntries()
        } catch {
            print("⚠️ フォルダ作成失敗: \(error)")
        }
    }

    private func createEmptyJSON() {
        var name = newFileName.trimmingCharacters(in: .whitespaces)
        if !name.lowercased().hasSuffix(".json") { name += ".json" }
        let url = currentFolderURL.appendingPathComponent(name)
        do {
            try Data("[]".utf8).write(to: url)
            loadEntries()
        } catch {
            print("⚠️ ファイル作成失敗: \(error)")
        }
    }

    private func performMove() {
        guard let target = moveTargetURL, let destFolder = selectedDestURL else { return }
        let fm = FileManager.default
        var dest = destFolder.appendingPathComponent(target.lastPathComponent)
        dest = uniqueURL(for: dest)
        do {
            try fm.moveItem(at: target, to: dest)
            loadEntries()
        } catch {
            print("⚠️ 移動失敗: \(error)")
        }
    }

    private func uniqueURL(for url: URL) -> URL {
        let fm = FileManager.default
        if !fm.fileExists(atPath: url.path) { return url }
        let dir = url.deletingLastPathComponent()
        let base = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension
        var i = 1
        while true {
            let newName = ext.isEmpty ? "\(base)-\(i)" : "\(base)-\(i).\(ext)"
            let candidate = dir.appendingPathComponent(newName)
            if !fm.fileExists(atPath: candidate.path) { return candidate }
            i += 1
        }
    }
}
