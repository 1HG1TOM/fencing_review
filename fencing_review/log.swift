//import SwiftUI
//import UniformTypeIdentifiers
//
//struct DocumentsListView: View {
//    // 現在表示中のフォルダ（nil なら Documents 直下）
//    let currentFolderURL: URL
//
//    init(currentFolderURL: URL? = nil) {
//        if let url = currentFolderURL {
//            self.currentFolderURL = url
//        } else {
//            self.currentFolderURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
//        }
//    }
//
//    @State private var entries: [URL] = [] // フォルダ＋ファイル
//    @State private var showImporter = false
//    @State private var importErrorMessage: String? = nil
//    @State private var showImportErrorAlert = false
//
//    // 名前変更
//    @State private var showRenameSheet = false
//    @State private var renameTargetURL: URL? = nil
//    @State private var renameNewName = ""
//    @State private var renameError: String?
//    @State private var showRenameError = false
//
//    // 新規作成
//    @State private var showNewFolderSheet = false
//    @State private var newFolderName = ""
//    @State private var showNewFileSheet = false
//    @State private var newFileName = ""
//    
//    // 移動
//    @State private var showMoveSheet = false
//    @State private var moveTargetURL: URL? = nil
//    @State private var selectedDestURL: URL? = nil
//
//    
//
//    var body: some View {
//        NavigationView {
//            List {
//                ForEach(entries, id: \.path) { url in
//                    if isDirectory(url) {
//                        NavigationLink(destination: DocumentsListView(currentFolderURL: url)) {
//                            HStack {
//                                Image(systemName: "folder")
//                                Text(url.lastPathComponent)
//                            }
//                        }
//                        .swipeActions(edge: .trailing) {
//                            Button("移動") {
//                                moveTargetURL = url
//                                selectedDestURL = currentFolderURL
//                                showMoveSheet = true
//                            }.tint(.orange)
//
//                            Button("名前変更") {
//                                renameTargetURL = url
//                                renameNewName = isDirectory(url) ? url.lastPathComponent
//                                                                 : url.deletingPathExtension().lastPathComponent
//                                showRenameSheet = true
//                            }.tint(.blue)
//                        }
//                        
//                        .swipeActions(edge: .leading) {
//                            Button(role: .destructive) {
//                                deleteMatch(url.lastPathComponent)
//                            } label: {
//                                Label("削除", systemImage: "trash")
//                            }
//                        }
//
//                    } else {
//                        NavigationLink(destination: DocumentDetailView(fileURL: url)) {
//                            HStack {
//                                Image(systemName: "doc.text")
//                                Text(url.lastPathComponent)
//                            }
//                        }
//                        .swipeActions(edge: .trailing) {
//                            Button("移動") {
//                                moveTargetURL = url
//                                selectedDestURL = currentFolderURL
//                                showMoveSheet = true
//                            }.tint(.orange)
//                            Button("名前変更") {
//                                renameTargetURL = url
//                                renameNewName = url.deletingPathExtension().lastPathComponent
//                                showRenameSheet = true
//                            }.tint(.blue)
//                        }
//                        
//                        .swipeActions(edge: .leading) {
//                            Button(role: .destructive) {
//                                deleteMatch(url.lastPathComponent)
//                            } label: {
//                                Label("削除", systemImage: "trash")
//                            }
//                        }
//                    }
//                }
//                .onDelete(perform: deleteEntries)
//            }
//            .navigationTitle(currentFolderURL == documentsRoot ? "保存ファイル一覧" : currentFolderURL.lastPathComponent)
//            .toolbar {
//                ToolbarItem(placement: .navigationBarTrailing) {
//                    HStack(spacing: 12) {
//                        Button { showImporter = true } label: {
//                            Image(systemName: "square.and.arrow.down")
//                        }
//                        .accessibilityLabel("ファイルを取り込む")
//
//                        Button {
//                            showNewFolderSheet = true
//                        } label: {
//                            Image(systemName: "folder.badge.plus")
//                        }
//                        .accessibilityLabel("フォルダを作成")
//
//                        Button {
//                            showNewFileSheet = true
//                        } label: {
//                            Image(systemName: "doc.badge.plus")
//                        }
//                        .accessibilityLabel("ファイルを作成")
//
//                        EditButton()
//                    }
//                }
//            }
//            .onAppear { loadEntries() }
//            .fileImporter(
//                isPresented: $showImporter,
//                allowedContentTypes: [.json],
//                allowsMultipleSelection: false
//            ) { result in
//                do {
//                    let urls = try result.get()
//                    guard let src = urls.first else { return }
//                    try importJSON(srcURL: src, into: currentFolderURL)
//                    loadEntries()
//                } catch {
//                    importErrorMessage = error.localizedDescription
//                    showImportErrorAlert = true
//                }
//            }
//            .alert("取り込みに失敗しました", isPresented: $showImportErrorAlert) {
//                Button("OK", role: .cancel) { }
//            } message: {
//                Text(importErrorMessage ?? "不明なエラー")
//            }
//            .sheet(isPresented: $showRenameSheet) {
//                NavigationView {
//                    Form {
//                        Section(header: Text("新しい名前")) {
//                            TextField("例: scores-20250818-120000", text: $renameNewName)
//                                .autocorrectionDisabled()
//                                .textInputAutocapitalization(.never)
//                        }
//                    }
//                    .navigationTitle("名前変更")
//                    .toolbar {
//                        ToolbarItem(placement: .cancellationAction) {
//                            Button("キャンセル") { showRenameSheet = false }
//                        }
//                        ToolbarItem(placement: .confirmationAction) {
//                            Button("保存") { renameEntry() }
//                                .disabled(renameNewName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
//                        }
//                    }
//                }
//            }
//            .alert("名前変更に失敗しました", isPresented: $showRenameError) {
//                Button("OK", role: .cancel) {}
//            } message: {
//                Text(renameError ?? "")
//            }
//            .sheet(isPresented: $showNewFolderSheet) {
//                NavigationView {
//                    Form {
//                        Section(header: Text("フォルダ名")) {
//                            TextField("例: 2025-09-13_試合A", text: $newFolderName)
//                                .autocorrectionDisabled()
//                                .textInputAutocapitalization(.never)
//                        }
//                    }
//                    .navigationTitle("新規フォルダ")
//                    .toolbar {
//                        ToolbarItem(placement: .cancellationAction) {
//                            Button("キャンセル") { showNewFolderSheet = false }
//                        }
//                        ToolbarItem(placement: .confirmationAction) {
//                            Button("作成") { createFolder() }
//                                .disabled(newFolderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
//                        }
//                    }
//                }
//            }
//            .sheet(isPresented: $showNewFileSheet) {
//                NavigationView {
//                    Form {
//                        Section(header: Text("ファイル名（.json）")) {
//                            TextField("例: flags-xxxxxx", text: $newFileName)
//                                .autocorrectionDisabled()
//                                .textInputAutocapitalization(.never)
//                        }
//                    }
//                    .navigationTitle("新規ファイル")
//                    .toolbar {
//                        ToolbarItem(placement: .cancellationAction) {
//                            Button("キャンセル") { showNewFileSheet = false }
//                        }
//                        ToolbarItem(placement: .confirmationAction) {
//                            Button("作成") { createEmptyJSON() }
//                                .disabled(newFileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
//                        }
//                    }
//                }
//                
//            }
//            .sheet(isPresented: $showMoveSheet) {
//                NavigationView {
//                    FolderPickerView(
//                        rootURL: documentsRoot,
//                        initialSelection: selectedDestURL ?? currentFolderURL,
//                        disabledUnder: moveTargetURL // 自分自身/子孫は選べないようにする
//                    ) { picked in
//                        selectedDestURL = picked
//                    }
//                    .navigationTitle("移動先を選択")
//                    .toolbar {
//                        ToolbarItem(placement: .cancellationAction) {
//                            Button("キャンセル") { showMoveSheet = false }
//                        }
//                        ToolbarItem(placement: .confirmationAction) {
//                            Button("移動") { performMove() }
//                                .disabled(selectedDestURL == nil)
//                        }
//                    }
//                }
//            }
//        }
//    }
//
//    // MARK: - Helpers
//
//    private var documentsRoot: URL {
//        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
//    }
//
//    private func isDirectory(_ url: URL) -> Bool {
//        (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
//    }
//
//    private func loadEntries() {
//        do {
//            let items = try FileManager.default.contentsOfDirectory(at: currentFolderURL, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])
//            // フォルダ→ファイルの順、ファイルは .json のみ表示
//            let folders = items.filter { isDirectory($0) }.sorted { $0.lastPathComponent < $1.lastPathComponent }
//            let files = items.filter { !$0.hasDirectoryPath && $0.pathExtension.lowercased() == "json" }
//                .sorted { $0.lastPathComponent < $1.lastPathComponent }
//            self.entries = folders + files
//        } catch {
//            print("ファイル読み込み失敗: \(error)")
//            self.entries = []
//        }
//    }
//
//    private func deleteEntries(at offsets: IndexSet) {
//        for index in offsets {
//            let url = entries[index]
//            try? FileManager.default.removeItem(at: url)
//        }
//        loadEntries()
//    }
//
//    private func importJSON(srcURL: URL, into destFolder: URL) throws {
//        let fm = FileManager.default
//        let needsStop = srcURL.startAccessingSecurityScopedResource()
//        defer { if needsStop { srcURL.stopAccessingSecurityScopedResource() } }
//
//        var destURL = destFolder.appendingPathComponent(srcURL.lastPathComponent)
//        if destURL.pathExtension.isEmpty {
//            destURL.deletePathExtension()
//            destURL.appendPathExtension("json")
//        }
//
//        // 衝突回避
//        if fm.fileExists(atPath: destURL.path) {
//            let stem = destURL.deletingPathExtension().lastPathComponent
//            let ext = destURL.pathExtension
//            var counter = 1
//            while fm.fileExists(atPath: destURL.path) {
//                destURL = destFolder.appendingPathComponent("\(stem)-\(counter).\(ext)")
//                counter += 1
//            }
//        }
//        try fm.copyItem(at: srcURL, to: destURL)
//    }
//
//    private func renameEntry() {
//        guard let target = renameTargetURL else { return }
//        let fm = FileManager.default
//
//        var newName = renameNewName.trimmingCharacters(in: .whitespacesAndNewlines)
//        if !isDirectory(target), !newName.lowercased().hasSuffix(".json") {
//            newName += ".json"
//        }
//
//        let dest = target.deletingLastPathComponent().appendingPathComponent(newName)
//        guard dest != target else { showRenameSheet = false; return }
//
//        if fm.fileExists(atPath: dest.path) {
//            renameError = "同名の項目が既に存在します。"
//            showRenameError = true
//            return
//        }
//
//        do {
//            try fm.moveItem(at: target, to: dest)
//            showRenameSheet = false
//            loadEntries()
//        } catch {
//            renameError = error.localizedDescription
//            showRenameError = true
//        }
//    }
//
//    private func createFolder() {
//        let fm = FileManager.default
//        let name = newFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
//        let url = currentFolderURL.appendingPathComponent(name, isDirectory: true)
//        do {
//            try fm.createDirectory(at: url, withIntermediateDirectories: true)
//            showNewFolderSheet = false
//            newFolderName = ""
//            loadEntries()
//        } catch {
//            importErrorMessage = error.localizedDescription
//            showImportErrorAlert = true
//        }
//    }
//
//    private func createEmptyJSON() {
//        var name = newFileName.trimmingCharacters(in: .whitespacesAndNewlines)
//        if !name.lowercased().hasSuffix(".json") { name += ".json" }
//        let url = currentFolderURL.appendingPathComponent(name)
//        do {
//            try Data("[]".utf8).write(to: url, options: .atomic)
//            showNewFileSheet = false
//            newFileName = ""
//            loadEntries()
//        } catch {
//            importErrorMessage = error.localizedDescription
//            showImportErrorAlert = true
//        }
//    }
//    // 移動実行
//    private func performMove() {
//        guard let target = moveTargetURL, let destFolder = selectedDestURL else {
//            showMoveSheet = false; return
//        }
//        // 同じ場所なら何もしない
//        if target.deletingLastPathComponent() == destFolder {
//            showMoveSheet = false; return
//        }
//        // フォルダ移動の自己包含チェック
//        if isDirectory(target), isDescendant(destFolder, of: target) {
//            importErrorMessage = "フォルダを自分自身または子フォルダへは移動できません。"
//            showImportErrorAlert = true
//            return
//        }
//
//        let fm = FileManager.default
//        var destURL = destFolder.appendingPathComponent(target.lastPathComponent)
//        destURL = uniqueURL(for: destURL)
//
//        do {
//            try fm.moveItem(at: target, to: destURL)
//            showMoveSheet = false
//            moveTargetURL = nil
//            selectedDestURL = nil
//            loadEntries()
//        } catch {
//            importErrorMessage = error.localizedDescription
//            showImportErrorAlert = true
//        }
//    }
//
//    // 衝突回避: foo.json -> foo-1.json, フォルダも同様
//    private func uniqueURL(for url: URL) -> URL {
//        let fm = FileManager.default
//        if !fm.fileExists(atPath: url.path) { return url }
//
//        let dir = url.deletingLastPathComponent()
//        let base = url.deletingPathExtension().lastPathComponent
//        let ext  = url.pathExtension
//        var i = 1
//        while true {
//            let name = ext.isEmpty ? "\(base)-\(i)" : "\(base)-\(i).\(ext)"
//            let candidate = dir.appendingPathComponent(name)
//            if !fm.fileExists(atPath: candidate.path) { return candidate }
//            i += 1
//        }
//    }
//
//    // urlA が urlB の子孫（直下含む）か判定
//    private func isDescendant(_ urlA: URL, of urlB: URL) -> Bool {
//        let a = urlA.standardizedFileURL.path
//        let b = urlB.standardizedFileURL.path
//        if a == b { return true }
//        return a.hasPrefix(b.hasSuffix("/") ? b : (b + "/"))
//    }
//    
//    private struct FolderPickerView: View {
//        let rootURL: URL
//        let initialSelection: URL?
//        let disabledUnder: URL?
//        let onPick: (URL) -> Void
//
//        @State private var folders: [URL] = []
//        @State private var selection: URL?
//
//        var body: some View {
//            List(folders, id: \.path) { url in
//                let disabled = isDisabled(url)
//                HStack {
//                    Image(systemName: "folder")
//                    Text(url == rootURL ? "Documents" : url.lastPathComponent)
//                    Spacer()
//                    if selection == url { Image(systemName: "checkmark") }
//                }
//                .contentShape(Rectangle())
//                .foregroundColor(disabled ? .secondary : .primary)
//                .onTapGesture {
//                    guard !disabled else { return }
//                    selection = url
//                    onPick(url)
//                }
//            }
//            .onAppear {
//                selection = initialSelection
//                loadFolders()
//            }
//        }
//
//        private func loadFolders() {
//            folders = collectFolders(start: rootURL)
//        }
//
//        // 再帰的にフォルダを収集（隠しは除外）
//        private func collectFolders(start: URL) -> [URL] {
//            var acc: [URL] = [start]
//            if let items = try? FileManager.default.contentsOfDirectory(at: start, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) {
//                for u in items where (try? u.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false {
//                    acc.append(contentsOf: collectFolders(start: u))
//                }
//            }
//            return acc
//        }
//
//        private func isDisabled(_ url: URL) -> Bool {
//            guard let dis = disabledUnder else { return false }
//            // dis 自身と子孫は選択不可
//            let a = url.standardizedFileURL.path
//            let b = dis.standardizedFileURL.path
//            return a == b || a.hasPrefix(b.hasSuffix("/") ? b : (b + "/"))
//        }
//    }
//
//
//}
//
//struct DocumentDetailView: View {
//    let fileURL: URL
//    @State private var fileContents: String = ""
//    @State private var showSaveAlert = false
//
//    var body: some View {
//        ScrollView {
//            VStack(alignment: .leading, spacing: 16) {
//                Text("ファイル名: \(fileURL.lastPathComponent)")
//                    .font(.headline)
//
//                TextEditor(text: $fileContents)
//                    .font(.body)
//                    .padding()
//                    .frame(minHeight: 300)
//                    .border(Color.gray.opacity(0.4))
//                    .cornerRadius(10)
//
//                Button("保存") {
//                    saveContent()
//                    showSaveAlert = true
//                }
//                .padding()
//
//                Spacer()
//            }
//            .padding()
//            .onAppear {
//                loadContent()
//            }
//        }
//        .navigationTitle("詳細")
//        .alert("保存しました", isPresented: $showSaveAlert) {
//            Button("OK", role: .cancel) {}
//        }
//    }
//
//    private func loadContent() {
//        if let loaded = try? String(contentsOf: fileURL) {
//            fileContents = loaded
//        } else {
//            fileContents = "読み込みに失敗しました"
//        }
//    }
//
//    private func saveContent() {
//        try? fileContents.write(to: fileURL, atomically: true, encoding: .utf8)
//    }
//}
