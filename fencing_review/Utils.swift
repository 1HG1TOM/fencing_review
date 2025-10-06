import Foundation

func sanitizeFileName(_ name: String) -> String {
    let invalid = CharacterSet(charactersIn: "/\\?%*|\"<>:\n\r\t")
    let cleaned = name.components(separatedBy: invalid).joined(separator: "-")
    let trimmed = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? "untitled" : trimmed
}

func folderURL(for videoName: String) -> URL {
    let safeName = sanitizeFileName(videoName)
    guard !safeName.isEmpty else {
        fatalError("folderURL: videoName が空です")
    }
    let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    return docs.appendingPathComponent(safeName, isDirectory: true)
}
