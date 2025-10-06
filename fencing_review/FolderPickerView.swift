import SwiftUI

struct FolderPickerView: View {
    let rootURL: URL
    let initialSelection: URL?
    let disabledUnder: URL?
    let onPick: (URL) -> Void

    @State private var folders: [URL] = []
    @State private var selection: URL?

    var body: some View {
        List(folders, id: \.path) { url in
            let disabled = isDisabled(url)
            HStack {
                Image(systemName: "folder")
                Text(url == rootURL ? "Documents" : url.lastPathComponent)
                Spacer()
                if selection == url { Image(systemName: "checkmark") }
            }
            .contentShape(Rectangle())
            .foregroundColor(disabled ? .secondary : .primary)
            .onTapGesture {
                guard !disabled else { return }
                selection = url
                onPick(url)
            }
        }
        .onAppear {
            selection = initialSelection
            loadFolders()
        }
    }

    private func loadFolders() {
        folders = collectFolders(start: rootURL)
    }

    private func collectFolders(start: URL) -> [URL] {
        var acc: [URL] = [start]
        if let items = try? FileManager.default.contentsOfDirectory(at: start, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) {
            for u in items where (try? u.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false {
                acc.append(contentsOf: collectFolders(start: u))
            }
        }
        return acc
    }

    private func isDisabled(_ url: URL) -> Bool {
        guard let dis = disabledUnder else { return false }
        let a = url.standardizedFileURL.path
        let b = dis.standardizedFileURL.path
        return a == b || a.hasPrefix(b.hasSuffix("/") ? b : (b + "/"))
    }
}
